
## Contents & structure

```
helm/myapp/
  Chart.yaml
  values.yaml
  dashboards/
    app-metrics-dashboard.json
    a4-decision-dashboard.json
  templates/
    _helpers.tpl
    alertmanager-config.yaml
    app-*.yaml (deployment/service/ingress/configmap/secret)
    grafana-*.yaml
    prometheusrule.yaml
    servicemonitor.yaml
```

## Prerequisites

- Kubernetes ≥ 1.27
- Helm ≥ 3.10
- A working Ingress controller (or Gateway) if `.Values.app.ingress.enabled` stays true
- HostPath support for `/mnt/shared` (defaults to the VirtualBox shared folder)


### Prerequisite for alertmanager

The alertmanager requires an email to send the emails. This requires an app password. In this example Gmail is used.

1. Enable 2-Factor Authentication on the Gmail of your choice (required)
3. Go to: https://myaccount.google.com/apppasswords using your Gmail account. Or scroll at the bottom of the 2FA page and click on app passwords.
4. Generate the password which should be a 16-character password: XXXX XXXX XXXX XXXX
5. In the [alertmanager config](./templates/alertmanager-config.yaml) change the emails according to your needs.

## Setup

```
helm install myapp ./helm/myapp/ \
  -n monitoring \
  --create-namespace \
  --set alertmanager.smtpPassword='XXXX XXXX XXXX XXXX'
```

Running the command above (or using `helm upgrade --install`) is the single entrypoint for deploying the stack into any Kubernetes cluster (Minikube, kind, managed cloud, etc.). Choose the namespace you want to create by replacing `monitoring` with \<any-namespace\>. It takes a few **minutes** for everything to load correctly.

> **Note:** `myapp` above is the Helm release name. If you pick a different release name (e.g. `helm upgrade --install sms-stack ./operation/helm/myapp ...`), replace `myapp` everywhere accordingly. Many resource names are `<release>-<component>`, so use `kubectl get svc -n sms-stack` to see the exact service names before port-forwarding.

## Testing out alertmanager
Check if pods are running:
`kubectl get pods -n monitoring`

Expected result to be similar to:
```
NAME                                                     READY   STATUS    RESTARTS         AGE
alertmanager-myapp-kube-prometheus-stac-alertmanager-0   2/2     Running   0                94m
app-service-577466f9c5-g556f                             1/1     Running   2 (27h ago)      28h
myapp-grafana-788d5cf5b5-5bcf7                           3/3     Running   2 (27h ago)      27h
myapp-kube-prometheus-stac-operator-7c6b9888bf-xpvtl     1/1     Running   54 (3m58s ago)   28h
myapp-kube-state-metrics-6b94d669b5-z72h8                1/1     Running   48 (4m14s ago)   28h
myapp-prometheus-node-exporter-v8stj                     1/1     Running   52 (4m17s ago)   28h
prometheus-myapp-kube-prometheus-stac-prometheus-0       2/2     Running   42 (3m57s ago)   28h
```

---

Check if alertmanager is ready:
`kubectl get alertmanager -n monitoring`

Expected result to be similar to:
```
NAME                                      VERSION   REPLICAS   READY   RECONCILED   AVAILABLE   AGE
myapp-kube-prometheus-stac-alertmanager   v0.29.0   1          1       True         True        23h
```

---

Check the config to see if your emails have been applied correctly:
`kubectl exec -n monitoring alertmanager-myapp-kube-prometheus-stac-alertmanager-0 -c alertmanager -- cat /etc/alertmanager/config_out/alertmanager.env.yaml`

Expected result:
```
route:
  receiver: "null"
  group_by:
  - alertname
  routes:
  - receiver: devs
    match:
      alertname: TooManyRequests
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 12h
receivers:
- name: "null"
- name: devs
  email_configs:
  - send_resolved: true
    to: your@email.com
templates: []
```

---

Access Prometheus: `# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/myapp-kube-prometheus-stac-prometheus 9090:9090`
Wait a few a bit, then open: http://localhost:9090/alerts

When you open the page you should see the top row with:
```
alert-rules
TooManyRequests
```

The TooManyRequests should be currently `inactive`. The alert fires when the service receives >15 requests/minute for 2 minutes straight.

Open a new terminal and port forward to the application:
`kubectl port-forward -n monitoring svc/app-service 8080:8080`

To trigger the alert we will be spamming requests/generate traffic. In another terminal execute:
```
for i in {1..90}; do
  curl -X POST http://localhost:8080/sms \
    -H "Content-Type: application/json" \
    -d '{"sms":"Test message '$i'"}'
  sleep 2
done
```

This generates ~30 requests/minute for 3 minutes.

In http://localhost:9090/alerts you should be able to see the previous `inactive` TooManyRequests turn into `pending` and eventually `firing`. The email you have configured should now have an email with something similar to:

`[FIRING:1] TooManyRequests`

It will also send a second email a few minutes later saying the alert has been `resolved`.

> **Note:** make sure to check your spam/junk mail.


---

All knobs live in `values.yaml`. Key sections:

- `global.domain` / `global.tlsEnabled`: control default hostnames and TLS blocks across the chart.
- `app.*`: image, replica count, env vars, ConfigMap data, SMTP credentials (stored via stringData), and the ingress/service definition. By default the ingress renders both a **stable** host (enabled) and a **preview** host (disabled) via `app.ingress.hosts`. Leave `app.secret.smtpPassword` empty (with `autogenerate: true`) to have Helm create a random password during install.
- `storage.hostPath.*`: path on the node and mount path inside the pod (defaults to `/mnt/shared`).
- `kube-prometheus-stack`: collection which contains prometheus and the alertmanager.
- `alertmanager`: placeholder for the required (secret) app password.
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

## Troubleshooting tips

- `kubectl -n sms-stack port-forward svc/<release>-myapp-app-svc 8080:80` for quick local validation.
    
- `kubectl -n sms-stack logs deploy/<release>-myapp-prometheus` to inspect Prometheus scrape errors.
- If dashboards fail to load, verify the `grafana-dashboard-configmap` exists and the Grafana pod mounts `/var/lib/grafana/dashboards`.

