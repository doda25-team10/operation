# Extension Proposal: Adopting GitOps for Automated Deployment using Argo CD

## 1. Identified Shortcoming: Imperative Deployment (ClickOps)

As documented in the `operation/README.md`, the current deployment process for the `sms-stack` relies on manual imperative execution. Developers are required to manually run `helm upgrade --install` commands from their local machines or the controller VM to deploy changes. Currently, the kubeconfig file located at `operation/kubeconfig` must be accessible to anyone performing deployments, which violates the principle of least privilege. While it is sufficient for a prototype (assignment of the DODA course), this approach generally called "ClickOps" and it presents severe release engineering risks:

- **Configuration Drift:** There is no guarantee that the state of the cluster matches the configuration in the git repository. If an administrator manually edits a resource (e.g., via `kubectl edit`), the change is invisible to the version control system and persists until the next manual Helm run overwrites it.
- **Security Risks:** The current model requires developers to have direct write access to the production cluster credentials (kubeconfig) to run Helm commands ("violation of "Least Privilidge" paradigm).
- **Lack of Auditability:** There is no centralized audit trail of *who* deployed *what* and *when*, other than the potential logs on a developer's local terminal.
- **Scalability Bottlenecks:** As the number of microservices grows (currently our `app` service deployed from `ghcr.io/doda25-team10/app:latest` and `model-service` from `ghcr.io/doda25-team10/model-service:latest`), manually managing Helm releases for each service becomes unmaintainable and prone to human error.

## 2. Proposed Extension: GitOps with Argo CD

We propose refactoring the release pipeline to adopt **GitOps** principles using **Argo CD**. GitOps is an operational framework that takes DevOps best practices used for application development, such as version control, collaboration, and compliance, and applies them to infrastructure automation. In this model, the Git repository becomes the "Single Source of Truth." A GitOps controller (Argo CD) running inside the cluster constantly monitors the repository and automatically synchronizes the cluster state to match the git configuration. The pipeline provided in the image below:

<div align="center">
  <img 
    src="./images/argocd_architecture.webp" 
    alt="Argo CD Architecture Diagram"
    style="display: block; margin: 12 auto;"
  />
</div>

### How it may work in our project

- **Development & Code Push:** A developer writes code for the `app` or `model-service` and pushes their changes to the GitHub repository at `github.com/doda25-team10`.
- **CI Pipeline Execution:** The existing GitHub Actions workflow (defined in `.github/workflows/`) builds the Docker image and runs tests. Upon success, it pushes the image to the GitHub Container Registry.
- **Config Update:** Crucially, **instead of manually running Helm commands, the CI pipeline commits a change back to the Git Repository**. It updates the `operation/helm/myapp/values.yaml` file with the new image tag (e.g., updating `app.image.tag: "v1.2.3"`).
- **Automated Sync (Pull):** The Argo CD Controller, running inside our Kubernetes cluster on the `ctrl` node, continuously monitors the `operation/helm/myapp` directory in the repository.
- **Reconciliation:** Argo CD pulls the new configuration and automatically syncs the `app-deployment.yaml` and `model-deployment.yaml` resources defined in `operation/helm/myapp/templates/` to match the desired state.
- **Drift Detection:** Post-deployment, Argo CD continues to watch the application. If any manual changes occur via `kubectl edit` that don't match the Git configuration, Argo CD detects them and can automatically revert to the version-controlled state.

## 3. Expected Outcome & Benefits

Implementing GitOps provides several key advantages for maintaining a stable and secure system. One of the most important features is self-healing infrastructure; if someone manually changes or deletes a resource in the cluster, Argo CD will detect this "drift" and immediately revert the cluster to the correct state defined in Git. This approach also improves security because the CI pipeline no longer needs to store sensitive cluster secrets; instead, the Argo CD controller handles everything from inside the cluster. Finally, managing releases becomes much easier, as performing a rollback after a bad deployment is as simple as running a "git revert" command in the repository.

## 4. Assumptions and Potential Downsides

### Assumptions:
We have few assumptions in mind such that the team has sufficient Kubernetes expertise to operate and troubleshoot Argo CD. In addition, we also assume that the cluster has adequate resources to run Argo CD and it has a reliable network connectivity with Git repository.

### Potential Downsides:
One of the most obvious potential downsides is that team members need to learn Argo CD concepts which implies dealing with a learning curve. In addition, it is definitely adds complexity to the project. If something bad happens, developers need to understand both Helm and Argo CD layers before debugging. Lastly, the inital setup might take some time and this upfront cost may not be justified for short-lived projects.

## 5. Implementation Plan (To-Do List)

**Day 1: Setup Argo CD**
- Install Argo CD in the cluster using Helm or manifests
- Configure RBAC and create projects
- Set up Git repository access (SSH keys or HTTPS tokens)

**Day 2: Create Application Manifests**
- Define Argo CD Application resources for our `app` (frontend) and `model-service` (ML backend) deployments
- Reference the existing Helm chart at `operation/helm/myapp`
- Configure sync policies (automated vs. manual)
- Set up health checks and sync waves for proper ordering

**Day 3: CI Pipeline Integration**
- Modify GitHub Actions to update image tags in values.yaml instead of running Helm
- Implement automatic commit and push to trigger Argo CD sync
- Add image updater or use Argo CD Image Updater for automated image tag updates

**Day 4: Monitoring and Alerting**
- Integrate Argo CD metrics with our existing Prometheus/Grafana stack (configured in `operation/helm/myapp/templates/prometheus-deployment.yaml` and `operation/helm/myapp/templates/grafana-deployment.yaml`)
- Extend the existing dashboards in `operation/helm/myapp/dashboards/` to include Argo CD sync status and deployment frequency
- Leverage the existing ServiceMonitor configuration in `operation/helm/myapp/templates/servicemonitor.yaml` to scrape Argo CD metrics


**Day 5: Documentation and Validation**
- Update operation/README.md with new deployment workflow
- Run experiment (drift recovery test)
- Train team on Argo CD UI and troubleshooting

## 6. Experimental Setup:

To compare our current setup with the proposed GitOps approach, we will perform a recovery speed test. In the baseline measurement, we simulate a failure by deleting the app deployment (`kubectl delete deployment app -n sms-stack`) and timing how long it takes an operator to fix it. This manual process involves receiving an alert from our Prometheus/Grafana monitoring stack, SSHing into the `ctrl` node using the private keys in `operation/provisioning/ssh-keys/`, finding the correct Helm commands in `operation/README.md`, and running the upgrade.

We expect this to take between 15 minutes at least, as it depends heavily on human response time. By switching to GitOps with Argo CD, the system becomes automated. Once the deployment is deleted, Argo CD detects the "OutOfSync" state and recreates the resources automatically without any human intervention, which should reduce the recovery time to less than 5 minutes.

Beyond recovery time, we will also track key DORA metrics to measure the long-term success of the project. We will monitor the "Change Failure Rate" by comparing manual Helm errors against Argo CD’s built-in sync tracking, aiming for a failure rate of less than 15%. Additionally, we will track "Deployment Frequency" to see how often we push updates to the cluster. The goal is to show that because GitOps makes deployments easier and safer, we can deploy more frequently, leading to faster feedback loops and a more stable environment overall.

## 7. Generalizability

Beyond our specific SMS spam detection project deployed in the `sms-stack` namespace, this GitOps extension is highly generalizable across various environments. Since it is based on Kubernetes, it can be adopted by any containerized application regardless of the programming language, whether it is Java for our frontend `app` service or Python for our machine learning `model-service`. The approach is also flexible enough to work with common CI/CD tools like GitHub Actions or Jenkins, allowing teams to migrate their services gradually rather than all at once. According to the CNCF 2023 GitOps Microsurvey, 73% of organizations use GitOps in production, and ArgoCD and Flux were the most widely used CNCF GitOps projects, validating its universal applicability.

## 8. References

- **GitOps.tech.** "GitOps is Continuous Deployment for cloud native applications." [https://www.gitops.tech/]
- **Google Cloud (DORA).** "DORA's software delivery metrics: the four keys." [https://dora.dev/guides/dora-metrics-four-keys/]
- **Datadog.** "Understanding GitOps: key principles and components for Kubernetes environments." [https://www.datadoghq.com/blog/gitops-principles-and-components/]
- **Argo CD.** "Overview of Argo CD." [https://argo-cd.readthedocs.io/en/stable/]
- **Google Cloud.** "GitOps-style continuous delivery with Cloud Build" [https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/gitops-cloud-build]
- **Cloud Native Computing Foundation.** "Learning on the job as GitOps goes mainstream." [https://www.cncf.io/wp-content/uploads/2023/11/CNCF_GitOps-Microsurvey_Final.pdf]
