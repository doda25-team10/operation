# Deployment Documentation

## 1. High-Level Overview

In this document, we outline the deployment structure of the SMS Checker application (`sms-stack`). The system is designed as a cloud-native application running on Kubernetes, utilizing **Istio** for traffic management and **Helm** for centralized configuration.

Based on the latter stages of the assignments, the deployment focuses on observability and experimentation, featuring a monitoring stack and a canary release strategy managed via Istio VirtualServices. Note that these features have not yet been fully implmented, and are therefore not yet described in detail in this document.

## 2. Access & Connectivity

The application is exposed through an Istio Ingress Gateway. Below are the entry points for the system:

| Service                             | URL / Access Method                   | Description                                           |
| :---------------------------------- | :------------------------------------ | :---------------------------------------------------- |
| **Web Application (Stable)**  | `https://myapp.example.com`         | The main user interface for the SMS Checker.          |
| **Web Application (Preview)** | `https://preview.myapp.example.com` | (Optional) Direct access to the experimental version. |
| **Grafana Dashboard**         | *[Not yet implemented]*             | Visualization of app metrics and experiment data.     |
| **Prometheus**                | `https://localhost:9090`            | Metric collection and querying.                       |
