# Deployment Documentation

> **Purpose:** This document explains the SMS Checker deployment architecture. After reading this, a new team member should understand the system design well enough to contribute to architectural discussions.

---

## Table of Contents

1. [High-Level Overview](#1-high-level-overview)
2. [Access & Connectivity](#2-access--connectivity)
3. [Deployment Structure](#3-deployment-structure)
4. [Request Flow & Traffic Routing](#4-request-flow--traffic-routing)
5. [Additional Use Case: Rate Limiting](#5-additional-use-case-rate-limiting)
6. [Observability Stack](#6-observability-stack)
7. [Infrastructure Overview](#7-infrastructure-overview)

---

## 1. High-Level Overview

The **SMS Checker** is a cloud-native spam detection application deployed on Kubernetes with **Istio** service mesh for traffic management. The system consists of two core microservices: the **App Service** (Java/Spring Boot) serving the frontend and API, and the **Model Service** (Python/FastAPI) providing ML-based spam classification.

All resources are deployed via a single **Helm chart** (`myapp`) into the `sms-stack` namespace. For implementation details, see the [Helm chart](https://github.com/doda25-team10/operation/tree/main/helm/myapp).

---

## 2. Access & Connectivity

The application is exposed through an Istio Ingress Gateway. Below are the entry points for the system:

| Service | URL / Access Method | Description |
|:--------|:--------------------|:------------|
| **Web Application (Stable)** | `http://myapp.example.com` | The main user interface for the SMS Checker |
| **Web Application (Preview)** | `http://preview.myapp.example.com` | Direct access to the experimental version |
| **Grafana Dashboard** | `http://localhost:3000` | Visualisation of app metrics and experiment data |
| **Prometheus** | `http://localhost:9090` | Metric collection and querying |

> **Note:** Accessing `myapp.example.com` requires entries in `/etc/hosts` mapping to the LoadBalancer IP (e.g., `192.168.56.100`). For local testing, use `kubectl port-forward` or access via the gateway IP directly. The preview version can also be accessed by adding the `canary: enabled` header to any request. After your first visit, a `user_group` cookie is set to ensure you're routed to the same version on subsequent requests (sticky sessions).

---

## 3. Deployment Structure

The application is deployed using a single Helm chart (`myapp`) which manages all workloads, services, and the monitoring stack — making it easy to deploy consistently across environments. All resources are documented in the [Helm chart](https://github.com/doda25-team10/operation/tree/main/helm/myapp).


### Core Workloads

The system runs two primary microservices, each with two deployment versions (v1 stable, v2 experimental):

- **App Service (`myapp-app-svc`):** Serves the frontend and acts as the API gateway. Runs 2 replicas per version for high availability, communicating with the Model Service via internal DNS (`myapp-model-service:8081`).

- **Model Service (`myapp-model-service`):** Houses the ML model logic. Runs 1 replica per version, accessed internally via ClusterIP on port 8081.

### Istio Resources

Traffic management is handled by Istio custom resources: a **Gateway** for external entry, **VirtualServices** for routing decisions (including the 90/10 canary split), and **DestinationRules** defining v1/v2 subsets for both services.

### Observability Stack

* **Prometheus:** Deployed internally, configured to scrape metrics from the App Service.
  * **Scrape Configuration:** The `ServiceMonitor` targets the app pods on the path `/sms/metrics` every **5 seconds**.
* **Grafana:** Enables collected app and model metrics to be visualised with the provided dashboards.
* **Alertmanager:** Handles notifications for critical thresholds.

---

## 4. Request Flow & Traffic Routing

The diagram below shows the complete journey of a user request:

![Figure 1. Request Data Flow](images/dataflow.jpg)

### Path of a Typical Request

1. **Client Entry:** A user request is sent to `https://myapp.example.com`.
2. **Istio Gateway:** The request enters the Istio Ingress Gateway.
3. **Rate Limiting Enforcement:** At the Istio Ingress Gateway, before any VirtualService routing is evaluated, the request is checked against rate limiting rules:
   - **Within Limit:** If the user's request limit has not been exceeded, the request proceeds through the normal VirtualService routing logic.
   - **Limit Exceeded:** If the rate limit is exceeded, the request is rejected immediately with `HTTP 429 Too Many Requests`.
4. **Ingress VirtualService Routing:** The gateway-facing VirtualService (`myapp-istio-vs`) intercepts the request.
5. **App Service Selection (Canary Logic):** The request is routed to either the V1 (stable) or V2 (preview) subset of the App Service based on weight (90/10). This random selection can be bypassed by using the `canary: enabled` header to select the preview version.
6. **Internal Model Service Call:** The App Service calls the Model Service (`myapp-model-service`).
7. **Model VirtualService Routing:** The `myapp-model-vs` VirtualService applies routing rules:
   - Requests from pods with `version: v2` label are routed to the V2 subset (preview) of the Model Service, which has been modified to always predict spam.
   - All other requests are routed to the V1 subset (stable), which runs the normal prediction pipeline.
8. **Response:** The Model Service returns the prediction to the App Service, which then returns the final response to the user.

### Canary Release & Traffic Split

The **90/10 traffic split** is configured in [`values.yaml`](https://github.com/doda25-team10/operation/blob/main/helm/myapp/values.yaml) under `istio.virtualService.weightStable` and `istio.virtualService.weightExperiment`. The routing decision is made by **VirtualService `myapp-istio-vs`**, evaluated at the Istio Ingress Gateway.

The VirtualService first checks for a `canary: enabled` header (routes to v2), then checks for existing session cookies (`user_group=v1` or `user_group=v2`), and finally falls back to the weighted 90/10 split for new users. When a new user is assigned to a version, a cookie is set to ensure **sticky sessions**—subsequent requests from the same user are routed to the same version for the duration of the experiment (24 hours).

To ensure consistent behaviour, **App v1 always calls Model v1, and App v2 always calls Model v2**. This is enforced by `myapp-model-vs` which routes based on the calling pod's `version` label.

---

## 5. Additional Use Case: Rate Limiting

We implemented **per-user rate limiting** to protect the system from abuse while allowing fair access. Rate limiting is enforced at the Istio Ingress Gateway using two mechanisms:

1. **Local Rate Limiting (Global):** A token-bucket rate limiter applied directly on the Envoy proxy (1000 req/min) as a first line of defense against traffic spikes.

2. **External Rate Limit Service (Per-User):** An RLS backed by Redis tracks request counts per user based on the `x-user-id` header, allowing individual users to be throttled independently (10 req/min per user).

Users are identified via a self-declared header. When making a request, clients include their identifier:

```bash
curl -H "x-user-id: user123" http://myapp.example.com/sms/
```

When rate limited, clients receive `HTTP 429 Too Many Requests`.

### Components

| Component | Description |
|-----------|-------------|
| **EnvoyFilter (Local)** | Applies global rate limiting directly on the ingress gateway |
| **EnvoyFilter (RLS)** | Integrates the external RLS with the gateway |
| **Rate Limit Service** | Envoy-compatible gRPC service for distributed rate limiting |
| **Redis** | Backend storage for tracking per-user request counts |

### Behaviour

| Limit Type | Threshold | Scope |
|------------|-----------|-------|
| Global | 1000 req/min | All traffic |
| Per-user | 10 req/min | Per `x-user-id` header value |

---

## 6. Observability Stack

![Figure 2. Monitoring Stack](images/monitoring_stack.jpg)

To monitor the application internally, we implement a monitoring stack with Prometheus and Grafana. Prometheus continuously scrapes metrics from the app-service `/sms/metrics` endpoint every 5 seconds, as well as from supporting sources like kube-state-metrics and node-exporter for pod status and node-level metrics.


The app-service metrics are visualised in Grafana through two dashboards: **MyApp Metrics** (prediction traffic, latency histogram, SMS length) and **A4 Decision Dashboard** (experiment comparison between v1 and v2). The Alertmanager listens for critical thresholds, such as the `TooManyRequests` alert which fires when request rate exceeds 15 req/min for 2 minutes, triggering email notifications.

---

## 7. Infrastructure Overview

![Figure 3. VM Structure](images/vm_structure.jpg)

The deployment runs on Vagrant VMs hosting the Kubernetes cluster:

| VM | Role | Key Components |
|----|------|----------------|
| **ctrl** | Control Plane | Kubernetes API, etcd, scheduler |
| **node-1** | Worker | App pods, Model pods, Prometheus |
| **node-2** | Worker | App pods, Grafana, Redis, RLS |

> **Note:** Pod distribution across workers is managed by the Kubernetes scheduler and may vary.

The network configuration includes the VM network (`192.168.56.0/24`) for inter-VM communication, pod network (`10.244.0.0/16`) via Flannel, service network (`10.96.0.0/12`) for ClusterIP services, and a MetalLB LoadBalancer pool (`192.168.56.200-210`).

---

## Further Reading

- [Helm Chart Documentation](https://github.com/doda25-team10/operation/tree/main/helm/myapp)
- [Continuous Experimentation](./continuous-experimentation.md)
- [Extension Proposal](./extension.md)
