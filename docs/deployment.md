# Deployment Documentation

## 1. High-Level Overview

In this document, we outline the deployment structure of the SMS Checker application (`sms-stack`). The system is designed as a cloud-native application running on Kubernetes, utilising **Istio** for traffic management and **Helm** for centralised configuration of our two services: the **App Service** (frontend/API) and the **Model Service** (ML backend).

Generally, the architecture is split into two distinct services: , which facilitates independent scaling and deployment. Configuration is centralised using a single Helm chart.

In the latter stages of the assignments, the deployment focuses on observability and experimentation, featuring a monitoring stack and a canary release strategy managed via Istio VirtualServices. Note that these features have not yet been fully implmented, and are therefore not yet described in detail in this document.

## 2. Access & Connectivity

The application is exposed through an Istio Ingress Gateway. Below are the entry points for the system:

| Service                             | URL / Access Method                   | Description                                                                                                                                              |
| :---------------------------------- | :------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Web Application (Stable)**  | `https://myapp.example.com`         | The main user interface for the SMS Checker.                                                                                                             |
| **Web Application (Preview)** | `https://preview.myapp.example.com` | Direct access to the experimental version of the SMS Checker.                                                                                            |
| **Grafana Dashboard**         | `https://localhost:3000`            | Visualisation of app metrics and experiment data.<br />*Note that Grafana support has not yet been fully <br />implemented and is currently disabled.* |
| **Prometheus**                | `https://localhost:9090`            | Metric collection and querying.                                                                                                                          |

> **Note:** Accessing `myapp.example.com` requires these entries to be present in the `/etc/hosts` file on your local machine, mapping them to the LoadBalancer IP of the cluster (e.g., `192.168.56.100`). For local testing, the main app service can simply be accessed at `https://localhost:8080`.

## 3. Deployment Structure

The application is deployed using a single, unified Helm chart (`sms-stack`) which manages all workloads, services, and the monitoring stack.

### **Core Workloads**

The system is composed of two primary microservices, communicating internally:

1. **App Service (`sms-stack-app-service`):**

   * **Function:** Serves the frontend and acts as the API gateway.
   * **Replicas:** 2 replicas for high availability.
   * **Connectivity:** Communicates with the Model Service via its internal Kubernetes DNS name (`sms-stack-model-service`) on port 8081.
   * **Storage:** Mounts the shared volume (`/mnt/storage`) for shared data or configuration.
2. **Model Service (`sms-stack-model-service`):**

   * **Function:** Houses the ML model logic.
   * **Replicas:** 1 replica.
   * **Exposure:** Accessed internally via a ClusterIP Service on target port 8081.

### **Observability Stack**

* **Prometheus:** Deployed internally, configured to scrape metrics from the App service.
  * **Scrape Configuration:** The `ServiceMonitor` targets the app pods on the path `/sms/metrics` every **5 seconds**.
* **Grafana:** Currently **disabled** (`enabled: false`), but the definition is ready for future activation.

## 4. Request Flow & Traffic Management

### **Path of a Typical Request**

1. **Client Entry:** A user request is sent to `https://myapp.example.com`.
2. **Istio Gateway:** The request enters the Istio Ingress Gateway.
3. **VirtualService Routing:** The VirtualService intercepts the request and applies the canary release rules.
4. **Canary Split:** The request is routed to either the V1 (`stable`) or V2 (`preview`) subset of the App Service Deployment based on weight.
5. **Service Call:** The App Service calls the Model Service internally.
6. **Response:** The prediction is returned to the App Service, which then returns the final response to the user.

This flow is illustrated in the figure below.

![Figure 1. Typical data flow](images/dataflow.jpg "Figure 1. Typical data flow")

To monitor our application internally, we implement a monitoring stack with Prometheus and Grafana. While client requests travel through the Istio Ingress Gateway to the app-service and model-service pods, Prometheus continuously scrapes metrics from the app-service `/sms/metrics `endpoint, as well as from supporting sources like kube-state-metrics and node-exporter. Although the latter are not used in our dashboards, they can provide information on pod status and node-level metrics such as CPU usage. On the other hand, the app-service metrics are processed and visualised in Grafana, providing a real-time view of application latency as well as aggregated insights into the predictions made by the machine learning model. The Alertmanager listens for critical thresholds, providing notifications for incidents or unusual results.

![Figure 2. Typical data flow](images/monitoring_stack.jpg "Figure 2. Typical data flow")

Lastly, the figure below illustrates the physical deployment of our application, showing the Vagrant VMs that host the Kubernetes cluster, including the control plane and worker nodes, and how the pods and services are distributed across them. Since all VMs share the same private subnet, they can easily communicate between each other.

![Figure 3. Physical structure of the VMs](images/vm_structure.jpg "Figure 3. Physical structure of the VMs")

### Continuous Experimentation

*Work in progress. Not yet complete.*

### Additional Use Case

*Work in progress. Not yet complete.*
