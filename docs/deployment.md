# Deployment Documentation

## 1. High-Level Overview

In this document, we outline the deployment structure of the SMS Checker application (`sms-stack`). The system is designed as a cloud-native application running on Kubernetes, utilising **Istio** for traffic management and **Helm** for centralised configuration of our two services: the **App Service** (frontend/API) and the **Model Service** (ML backend).

Generally, the architecture is split into two distinct services: , which facilitates independent scaling and deployment. Configuration is centralised using a single Helm chart.

In the latter stages of the assignments, the deployment focuses on observability and experimentation, featuring a monitoring stack and a canary release strategy managed via Istio VirtualServices.

## 2. Access & Connectivity

The application is exposed through an Istio Ingress Gateway. Below are the entry points for the system:

| Service                             | URL / Access Method                   | Description                                                                                                                                              |
| :---------------------------------- | :------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Web Application (Stable)**  | `https://myapp.example.com`         | The main user interface for the SMS Checker.                                                                                                             |
| **Web Application (Preview)** | `https://preview.myapp.example.com` | Direct access to the experimental version of the SMS Checker.                                                                                            |
| **Grafana Dashboard**         | `https://localhost:3000`            | Visualisation of app metrics and experiment data. |
| **Prometheus**                | `https://localhost:9090`            | Metric collection and querying.                                                                                                                          |

> **Note:** Accessing `myapp.example.com` requires these entries to be present in the `/etc/hosts` file on your local machine, mapping them to the LoadBalancer IP of the cluster (e.g., `192.168.56.100`). For local testing, the main app service can simply be accessed at `https://localhost:8080`.

## 3. Deployment Structure

The application is deployed using a single, unified Helm chart (`myapp`) which manages all workloads, services, and the monitoring stack.

### **Core Workloads**

The system is composed of two primary microservices, communicating internally:

1. **App Service (`myapp-app-svc`):**

   * **Function:** Serves the frontend and acts as the API gateway.
   * **Replicas:** 2 replicas for versioning, randomly determined by an Istio VirtualService with a default 90-10% split.
   * **Connectivity:** Communicates with the Model Service via its internal Kubernetes DNS name (`myapp-model-service`) on port 8081.
   * **Storage:** Mounts the shared volume (`/mnt/storage`) for shared data or configuration.
2. **Model Service (`myapp-model-service`):**

   * **Function:** Houses the ML model logic.
   * **Replicas:** 2 replicas for versioning.
   * **Exposure:** Accessed internally via a ClusterIP Service on target port 8081.

### **Observability Stack**

* **Prometheus:** Deployed internally, configured to scrape metrics from the App service.
  * **Scrape Configuration:** The `ServiceMonitor` targets the app pods on the path `/sms/metrics` every **5 seconds**.
* **Grafana:** Enables collected app and model metrics to be visualised with the provided dashboards.

## 4. Request Flow & Traffic Management

### Path of a Typical Request

1. **Client Entry:** A user request is sent to `https://myapp.example.com`.
2. **Istio Gateway:** The request enters the Istio Ingress Gateway.
3. **Ingress VirtualService Routing:** The gateway-facing VirtualService (`myapp-istio-vs`) intercepts the request.
4. **App Service Selection (Canary Logic):** The request is routed to either the V1 (stable) or V2 (preview) subset of the App Service Deployment based on weight. This random selection can be bypassed by using the `canary: enabled` header to select the preview version.
5. **Internal Model Service Call:** The App Service calls the Model Service (`myapp-model-service`).
6. **Model VirtualService Routing:** The `myapp-model-vs` VirtualService applies routing rules:
   - Requests with label `version: v2` are routed to the V2 subset (`preview`) of the Model Service, which has been modified to always predict spam for any given message.
   - All other requests are routed to the V1 subset (`stable`) of the Model Service, which runs the normal prediction pipeline.
7. **Response:** The Model Service returns the prediction to the App Service, which then returns the final response to the user.

This flow is illustrated in the figure below.

![Figure 1. Typical data flow](images/dataflow.jpg "Figure 1. Typical data flow")

To monitor our application internally, we implement a monitoring stack with Prometheus and Grafana. While client requests travel through the Istio Ingress Gateway to the app-service and model-service pods, Prometheus continuously scrapes metrics from the app-service `/sms/metrics` endpoint, as well as from supporting sources like kube-state-metrics and node-exporter. Although the latter are not used in our dashboards, they can provide information on pod status and node-level metrics such as CPU usage. On the other hand, the app-service metrics are processed and visualised in Grafana, providing a real-time view of application latency as well as aggregated insights into the predictions made by the machine learning model. The Alertmanager listens for critical thresholds, providing notifications for incidents or unusual results.

![Figure 2. Typical data flow](images/monitoring_stack.jpg "Figure 2. Typical data flow")

Lastly, the figure below illustrates the physical deployment of our application, showing the Vagrant VMs that host the Kubernetes cluster, including the control plane and worker nodes, and how the pods and services are distributed across them. Since all VMs share the same private subnet, they can easily communicate between each other.

![Figure 3. Physical structure of the VMs](images/vm_structure.jpg "Figure 3. Physical structure of the VMs")

### Continuous Experimentation

*Work in progress. Not yet complete.*

### Additional Use Case

*Work in progress. Not yet complete.*
