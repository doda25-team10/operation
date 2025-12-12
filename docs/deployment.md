# Deployment Documentation

## 1. High-Level Overview

In this document, we outline the deployment structure of the SMS Checker application (`sms-stack`). The system is designed as a cloud-native application running on Kubernetes, utilizing **Istio** for traffic management and **Helm** for centralised configuration.

In the latter stages of the assignments, the deployment focuses on observability and experimentation, featuring a monitoring stack and a canary release strategy managed via Istio VirtualServices. Note that these features have not yet been fully implmented, and are therefore not yet described in detail in this document.

## 2. Access & Connectivity

The application is exposed through an Istio Ingress Gateway. Below are the entry points for the system:

| Service                             | URL / Access Method                   | Description                                           |
| :---------------------------------- | :------------------------------------ | :---------------------------------------------------- |
| **Web Application (Stable)**  | `https://myapp.example.com`         | The main user interface for the SMS Checker.          |
| **Web Application (Preview)** | `https://preview.myapp.example.com` | (Optional) Direct access to the experimental version. |
| **Grafana Dashboard**         | *[Not yet implemented]*             | Visualization of app metrics and experiment data.     |
| **Prometheus**                | `https://localhost:9090`            | Metric collection and querying.                       |

> **Note:** Accessing `myapp.example.com` requires these entries to be present in the `/etc/hosts` file on your local machine, mapping them to the LoadBalancer IP of the cluster (e.g., `192.168.56.100`). For local testing, the app service can simply be accessed at https://localhost:8080.

## 3. Deployment Structure

The deployment is orchestrated using a single Helm chart that manages both the application workloads and the observability stack.

### **Core Components**

* **Frontend Service (`sms-stack`):**

  * **Workload:** A Deployment running **2 replicas** of the `ghcr.io/doda25-team10/app-service` container.
  * **Configuration:** Configured via Environment Variables (e.g., `DB_URL`, `METRICS_ENABLED`) and Kubernetes Secrets for sensitive data (SMTP credentials).
  * **Storage:** A `hostPath` volume is mounted at `/mnt/shared` to allow data persistence and sharing across the cluster nodes.
* **Observability Stack:**

  * **Prometheus:** Deployed as a stateful workload. It automatically discovers the application pods via `ServiceMonitors` to scrape metrics every 5s.
  * **Grafana:** Pre-configured with an `app-metrics-dashboard.json` to visualize key performance indicators (KPIs) such as request rates and error counts.
