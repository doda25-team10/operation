
## Contents & structure

```
helm/myapp/
  Chart.yaml
  values.yaml
  dashboards/
    app-metrics-dashboard.json
    a4-decision-dashboard.json
  prometheus/
    prometheus-config.yaml
    alerting-rules.yaml
  templates/
    _helpers.tpl
    app-*.yaml (deployment/service/ingress/configmap/secret)
    grafana-*.yaml
    servicemonitor.yaml
```

Running `helm install myapp ./helm/myapp/ -n <any-namespace> --create-namespace` (or `helm upgrade --install`) is the single entrypoint for deploying the stack into any Kubernetes cluster (Minikube, kind, managed cloud, etc.). Choose the cluster you want to install in by replacing \<any-namespace\> with any (new) cluster's name.

## Prerequisites

- Kubernetes ≥ 1.27
- Helm ≥ 3.10
- A working Ingress controller (or Gateway) if `.Values.app.ingress.enabled` stays true
- HostPath support for `/mnt/shared` (defaults to the VirtualBox shared folder)

## Configuring the chart

All knobs live in `values.yaml`. Key sections:

- `global.domain` / `global.tlsEnabled`: control default hostnames and TLS blocks across the chart.
- `app.*`: image, replica count, env vars, ConfigMap data, SMTP credentials (stored via stringData), and the ingress/service definition. By default the ingress renders both a **stable** host (enabled) and a **preview** host (disabled) via `app.ingress.hosts`. Leave `app.secret.smtpPassword` empty (with `autogenerate: true`) to have Helm create a random password during install.
- `storage.hostPath.*`: path on the node and mount path inside the pod (defaults to `/mnt/shared`).
- `grafana.*`: manages Grafana image, admin credentials, service type, and which dashboard file should act as the default home.
- `experiments.preview.*`: future Assignment 4 knobs (currently disabled) that will control preview traffic weight, image overrides, or extra env vars once experimentation features are added.

Example production overlay:

```yaml
global:
  domain: "prod.example.com"
app:
  image:
    tag: "2025.12.04"
  ingress:
    hosts:
      - name: stable
        enabled: true
        host: "spam.prod.example.com"
        tlsSecretName: "spam-tls"
      - name: preview
        enabled: true
        host: "canary.prod.example.com"
        tlsSecretName: "spam-preview-tls"
experiments:
  preview:
    enabled: true
    weight: 50
storage:
  hostPath:
    pathOnHost: "/var/lib/myapp/shared"
prometheus:
  serviceMonitor:
    namespace: observability
grafana:
  adminPassword: "use-a-secret-manager"
```

Install with:

```bash
# from the repo root
helm upgrade --install myapp ./operation/helm/myapp \
  --namespace sms-stack \
  --create-namespace \
  -f values.prod.yaml
```

> **Note:** `myapp` above is the Helm release name. If you pick a different release name (e.g. `helm upgrade --install sms-stack ./operation/helm/myapp ...`), replace `myapp` everywhere accordingly. Many resource names are `<release>-<component>`, so use `kubectl get svc -n sms-stack` to see the exact service names before port-forwarding.

## Troubleshooting tips

- `kubectl -n sms-stack port-forward svc/<release>-myapp-app-svc 8080:80` for quick local validation.
    
- `kubectl -n sms-stack logs deploy/<release>-myapp-prometheus` to inspect Prometheus scrape errors.
- If dashboards fail to load, verify the `grafana-dashboard-configmap` exists and the Grafana pod mounts `/var/lib/grafana/dashboards`.

