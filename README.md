# DODA 2025 Team 10 - Operation

This repository contains the necessary configuration to run and operate the services developed by DODA 2025 Team 10.

1. [Project Repositories](#project-repositories)
2. [Overview of the Project Components](#overview-of-the-project-components)
3. [Getting Started with Docker](#getting-started-with-docker)
4. [Provisioning the Kubernetes Cluster](#provisioning-the-kubernetes-cluster)
5. [Helm-based Kubernetes Deployment](#helm-based-kubernetes-deployment)
6. [Documentation Map](#documentation-map)

---

## Project Repositories

| Repository                                                             | Description                                                                |
| :--------------------------------------------------------------------- | :------------------------------------------------------------------------- |
| **[model-service](https://github.com/doda25-team10/model-service)** | Serves predictions from a trained ML model via a REST API.                 |
| **[app](https://github.com/doda25-team10/app-service)**             | The backend API service and frontend controllers, built with Java.         |
| **[lib-version](https://github.com/doda25-team10/lib-version)**     | A lightweight library for managing and retrieving the application version. |
| **[operation](https://github.com/doda25-team10/operation)**         | Orchestrates all services.                                                 |

---

## Overview of the Project Components

This project relies on several key tools and technologies to manage development, deployment, and observability. Understanding their role will help you follow the steps in this README more easily.

| Component                          | Purpose / Role                                                                                                                                                                   |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Docker**                         | Containerizes the application and ML model. Used to build images and run services locally or in Kubernetes. You will use it first to start all services quickly on your machine. |
| **Docker Compose**                 | Orchestrates multiple Docker containers together. Provides a simple way to run the app, model, and monitoring stack without Kubernetes.                                          |
| **Vagrant & VirtualBox**           | Used to provision virtual machines that host the Kubernetes cluster. Vagrant automates VM creation; VirtualBox provides the hypervisor.                                          |
| **Ansible**                        | Automates the provisioning and configuration of the Kubernetes cluster and associated tools (MetalLB, Nginx Ingress, etc.). Runs on top of the Vagrant VMs.                      |
| **Kubernetes**                     | Container orchestration platform. Manages pods, services, and deployments for the app and model. Ensures high availability, scaling, and internal networking.                    |
| **Helm**                           | Kubernetes package manager. Simplifies deploying the app and model services along with Prometheus/Grafana using a single chart.                                                  |
| **Istio**                          | Service mesh for traffic management. Handles canary releases, request routing, and rate limiting at the network layer.                                                           |
| **Prometheus & Grafana**           | Observability stack. Prometheus collects metrics from services, and Grafana visualizes them in dashboards.                                                                       |
| **Argo CD (Optional / Extension)** | GitOps controller that can automate deployment by syncing the cluster state with the Helm chart in Git. Reduces manual Helm commands and ensures reproducibility.                |

---

## Getting Started with Docker

Use the following steps to startup the services.

### 1. Prerequisites

Make sure you have [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed on your machine.

In case you are using a custom model, create a new folder called model in the current root folder with the following files:

- model.joblib
- preprocessor.joblib
- preprocessed_data.joblib

### 2. Start the Containers

Open a terminal and navigate to the root folder of the **`operation`** repository.
Then start the containers with:

```bash
docker compose up
```

If you prefer to keep using the same terminal for other commands, run the containers in the background:

```bash
docker compose up -d
```

### 3. Access service

If everything ran properly, navigate to

```
http://localhost:8080
```

 which shows a page with "Hello World!" and the current library version.

To use the application go to

```
http://localhost:8080/sms
```

### Cleanup

To stop and remove both containers and images, run:

```bash
docker compose down --rmi all
```

To stop and remove the containers while leaving the images intact, run:

```bash
docker compose down 
```

To stop the containers temporarily while keeping them intact, run:

```bash
docker compose stop
```

---

## Provisioning the Kubernetes Cluster

### Prerequisites

* Vagrant
* VirtualBox
* kubectl on the host

### Provisioning

```
vagrant up
```

### Exploring the controller machine

SSH into the controller:

```
vagrant ssh ctrl

# Nodes
kubectl get nodes

# Pods in all namespaces
kubectl get pods -A
```

### Finalising the Cluster Setup

After provisioning the cluster, MetalLB (LoadBalancer), Nginx ingress controller, and the Kubernetes dashboard can be installed via the following command:

```
ansible-playbook -u vagrant -i 192.168.56.100, ./provisioning/finalization.yml --private-key {path-to-identityfile}
```

### Changing the .env file

The ```.env``` can be changed according to your preferences. Within it, you can change the versions of each image that will be used, and port and model configuration. The current set-up will, of course, work out-of-the-box using the latest images for the app and model.

---

## Helm-based Kubernetes Deployment

The automated provisioning (Ansible + Vagrant) bootstraps the Kubernetes nodes only. **It deliberately does _not_ install the application** so that reviewers can run the Helm chart on any compatible cluster (including Minikube/kind). More information can be found in the README inside the helm folder. Deploy the stack manually once the cluster is ready:

```bash
# From the repo root (host) or /vagrant inside the controller VM
helm upgrade --install myapp ./helm/myapp \
  -n sms-stack \
  --create-namespace
```

Adjustment tips:

- Override ingress hostnames/TLS or container images via `-f my-values.yaml` or `--set app.ingress.host=...`.
- To uninstall: `helm uninstall myapp -n sms-stack`.

Keep this flow separate from infrastructure provisioning so the same chart can be installed into other clusters without rerunning Vagrant.

### Application Monitoring

First, open a connection to the frontend ([http://localhost:8080](http://localhost:8080)):

```
kubectl -n sms-stack port-forward svc/myapp-app-svc 8080:80
```

To explore the metrics that are being collected by prometheus, run the following in a separate terminal ([http://localhost:9090](http://localhost:9090)):

```
kubectl port-forward -n sms-stack svc/myapp-kube-prometheus-stac-prometheus 9090:9090
```

And finally to view some dashboards to visualise the collected data, open another terminal to connect to grafana ([http://localhost:3000](http://localhost:3000)):

```
kubectl -n sms-stack port-forward svc/myapp-grafana-svc 3000:3000
```

**The username and password are both admin**. Note that there are two dashboard available: A4 decision dashboard, and MyApp metrics. The former is to visualise the effect of the experiment conducted as part of assignment A4, while the latter contains some generally useful monitoring metrics for the application.

---

## Documentation Map

This project contains several documents and READMEs to guide you through specific parts of the system. Use the links below to dive deeper into the topics that interest you:

| File                                                                                              | Description                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[operation/README.md](https://github.com/doda25-team10/operation/blob/main/README.md)**         | Step-by-step guide for running and operating the services locally using Docker, provisioning the Kubernetes cluster with Vagrant & Ansible, and deploying with Helm.                                                        |
| **[helm/myapp/README.md](https://github.com/doda25-team10/operation/blob/main/helm/myapp/README.md)**         | Explains the Helm chart structure, file contents, `values.yaml` configuration, and how to deploy and customize the app stack in Kubernetes. Includes details about Prometheus, Grafana dashboards, and traffic management.  |
| **[docs/deployment.md](https://github.com/doda25-team10/operation/blob/main/docs/deployment.md)** | Provides a high-level overview of the deployment architecture, request flow, canary release strategy, rate limiting, monitoring, and physical cluster setup. Good for understanding why the system works the way it does. |
| **[docs/extension.md](https://github.com/doda25-team10/operation/blob/main/docs/extension.md)**   | Proposes an optional GitOps extension using Argo CD for automated deployment. Explains motivation, architecture, implementation plan, and benefits like drift detection and improved release management.                    |
| **[docs/continuous-experimentation.md](https://github.com/doda25-team10/operation/blob/main/docs/continuous-experimentation.md)**   | Details the A/B testing experiment, including stable vs. experimental UI versions, hypothesis, metrics, and results. |
