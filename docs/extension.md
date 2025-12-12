# Extension Proposal: Adopting GitOps for Automated Deployment using Argo CD

## 1. Identified Shortcoming: Imperative Deployment (ClickOps)

As documented in the `operation/README.md`, the current deployment process for the `sms-stack` relies on manual imperative execution. Developers are required to manually run `helm upgrade --install` commands from their local machines or the controller VM to deploy changes. While it is sufficient for a prototype (assignment of the DODA course), this approach generally called "ClickOps" and it presents severe release engineering risks:

- **Configuration Drift:** There is no guarantee that the state of the cluster matches the configuration in the git repository. If an administrator manually edits a resource (e.g., via `kubectl edit`), the change is invisible to the version control system and persists until the next manual Helm run overwrites it.
- **Security Risks:** The current model requires developers to have direct write access to the production cluster credentials (kubeconfig) to run Helm commands ("violation of "Least Privilidge" paradigm).
- **Lack of Auditability:** There is no centralized audit trail of *who* deployed *what* and *when*, other than the potential logs on a developer's local terminal.
- **Scalability Bottlenecks:** As the number of microservices grows (currently `app-service` and `model-service`), manually managing Helm releases for each service becomes unmaintainable and prone to human error.

## 2. Proposed Extension: GitOps with Argo CD

We propose refactoring the release pipeline to adopt **GitOps** principles using **Argo CD**. GitOps is an operational framework that takes DevOps best practices used for application development, such as version control, collaboration, and compliance, and applies them to infrastructure automation. In this model, the Git repository becomes the "Single Source of Truth." A GitOps controller (Argo CD) running inside the cluster constantly monitors the repository and automatically synchronizes the cluster state to match the git configuration.

<div align="center">
  <img 
    src="./images/argocd_architecture.webp" 
    alt="Argo CD Architecture Diagram"
    style="display: block; margin: 12 auto;"
  />
</div>

### How it may work:

- **Development & Code Push:** A developer writes code and pushes their changes to the central Git Repository. This action automatically triggers the Continuous Integration (CI) pipeline.
- **CI Pipeline Execution:** The CI Pipeline builds the application and runs tests. Upon success, it pushes the Docker image to the Container Registry.
- **Config Update:** Crucially, instead of deploying directly to the cluster, the CI pipeline commits a change back to the Git Repository. It updates the deployment manifest (e.g., values.yaml) with the new image tag.
- **Automated Sync (Pull):** The Argo CD Controller, running inside the Kubernetes Cluster, continuously monitors the Git repository. It detects the new commit containing the updated configuration.
- **Reconciliation:** Argo CD pulls the new configuration and automatically Syncs/Reconciles the live Application Deployment to match the desired state defined in Git.
- **Drift Detection:** Post-deployment, Argo CD continues to watch the application. If any manual changes occur in the cluster that do not match the Git configuration (drift), Argo CD detects them and can automatically revert the system to the secure, version-controlled state.

## 3. Expected Outcome & Benefits

- **Self-Healing Infrastructure:** If a resource is manually deleted or modified in the cluster, Argo CD will detect the drift and instantly revert it to the state defined in Git.
- **Enhanced Security:** The CI pipeline no longer needs cluster secrets. Only the Argo CD controller (running inside the cluster) needs permission to modify resources.
- **Instant Rollbacks:** Rolling back a bad release is as simple as running git revert on the configuration repository.

## 4. Evaluation & Experimentation

To objectively measure the improvement, we will use DORA Metrics, specifically Mean Time to Recovery (MTTR) and Change Failure Rate.

- **Hypothesis:** The adoption of GitOps will significantly reduce the MTTR for configuration drift incidents compared to the manual approach.
- **Metric:** 
    - Time (in seconds) from the occurrence of a configuration error to the restoration of the correct state. 
- **Procedure:**
    - Baseline (Manual): Manually delete the app-service deployment (kubectl delete deploy ...). Measure how long it takes for an operator to notice the outage, find the correct helm command, and re-apply the configuration.
    - Experiment (GitOps): With Argo CD running, manually delete the same deployment. Measure the time it takes for Argo CD to detect the "OutOfSync" state and automatically recreate the resource (typically seconds).
- **Success Criteria:** The extension is considered successful if the GitOps-managed recovery is fully automated and occurs within <1 minute, whereas the manual process is dependent on human reaction time (which most probably will be significantly larger).

## 5. Assumptions and Potential Downsides

## 6. Implementation Plan

## 7. References

- **GitOps.tech.** "GitOps is Continuous Deployment for cloud native applications." [https://www.gitops.tech/]
- **Google Cloud (DORA).** "DORA's software delivery metrics: the four keys." [https://dora.dev/guides/dora-metrics-four-keys/]
- **Datadog.** "Understanding GitOps: key principles and components for Kubernetes environments." [https://www.datadoghq.com/blog/gitops-principles-and-components/]
- **Argo CD.** "Overview of Argo CD." [https://argo-cd.readthedocs.io/en/stable/]
