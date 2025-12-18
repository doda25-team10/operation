# DODA 2025 Team 10 - Operation

This repository contains the necessary configuration to run and operate the services developed by DODA 2025 Team 10.

1. [Project Repositories](#project-repositories)
2. [Project Structure](#project-structure)
3. [Getting Started](#getting-started)
4. [Cleanup](#cleanup)
5. [Assigment Comments](#comments-for-a3)

## Project Repositories

| Repository                                                             | Description                                                                |
| :--------------------------------------------------------------------- | :------------------------------------------------------------------------- |
| **[model-service](https://github.com/doda25-team10/model-service)** | Serves predictions from a trained ML model via a REST API.                 |
| **[app](https://github.com/doda25-team10/app-service)**             | The backend API service and frontend controllers, built with Java.         |
| **[lib-version](https://github.com/doda25-team10/lib-version)**     | A lightweight library for managing and retrieving the application version. |
| **[operation](https://github.com/doda25-team10/operation)**         | Orchestrates all services.                                                 |

---

## Project Structure

* [docker-compose.yml](/docker-compose.yml): Defines and starts the Docker containers by retrieving the required images.
* `README.md`: Provides instructions for startup, usage, and general information about the project.
* [Local model/ folder](/model/): Includes the trained model files when using a custom model as well as the output of the trained model.

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

---

To stop and remove the containers while leaving the images intact, run:

```bash
docker compose down 
```

---

To stop the containers temporarily while keeping them intact, run:

```bash
docker compose stop
```

---

## Provisioning  the Kubernetes cluster

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

After provisioning the cluster, MetalLB (LoadBalancer), Nginx ingress controller, and the Kuberenetes dashboard can be installed via the following command:

```
ansible-playbook -u vagrant -i 192.168.56.100, ./provisioning/finalization.yml
```

### Changing the .env file

The ```.env``` can be changed according to your preferences. Within it, you can change the versions of each image that will be used, and port and model configuration. The current set-up will, of course, work out-of-the-box using the latest images for the app and model.

---

## Helm-based Kubernetes deployment

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

## How to check if the correct version of conteinerd, runc and kubelet are downloaded:

Terminal 1:

```bash
vagrant up
vagrant provision 
```

(It should work for a bit and either give ok or changed for all of the tasks)

Terminal 2:
in the operation

```bash
Vagrant ssh ctrl
```

```bash
dpkg-query -W -f='${Version}\n' containerd 
```

This will show the version installed for containerd (should be 1.7.24)

```bash
dpkg-query -W -f='${Version}\n' runc 
```

This should also show the version installed for runc (should be 1.1.12)

```bash
apt-cache policy kubelet
```

Here, it should print the version of the kubernetes (should be 1.32.4)

```bash
systemctl is-enabled kubelet 
```

It should return enabled

```bash
systemctl is-active kubelet 
```

Should return activating
