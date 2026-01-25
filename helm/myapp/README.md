## Contents & structure

```
helm/myapp/
  .helmignore
  Chart.yaml
  README.md
  values.yaml
  charts/
  dashboards/
    a4-decision-dashboard.json
    app-metrics-dashboard.json
  templates/
    _helpers.tpl
    alertmanager-config.yaml
    app-configmap.yaml
    app-deployment.yaml
    app-ingress.yaml
    app-secret.yaml
    app-service.yaml
    grafana-dashboard-configmap.yaml
    grafana-deployment.yaml
    grafana-service.yaml
    model-configmap.yaml
    model-deployment.yaml
    model-service.yaml
    prometheusrule.yaml
    servicemonitor.yaml
```

## File descriptions

- `.helmignore`: Files and patterns excluded when packaging the Helm chart.
- `Chart.yaml`: Chart metadata (name, version, and chart dependencies).
- `values.yaml`: Default configuration values that drive the rendered templates.
- `charts/`: Directory for any bundled subcharts or chart dependencies.
- `dashboards/*.json`: Grafana dashboard JSON files, mounted into Grafana via a ConfigMap so dashboards appear automatically.
- `templates/_helpers.tpl`: Template helper functions used by other templates (name/label helpers, common snippets).
- `templates/alertmanager-config.yaml`: Renders the Alertmanager configuration with SMTP/email settings and routing.
- `templates/app-configmap.yaml`: Application configuration injected into pods as a ConfigMap (env vars, config files, templates).
- `templates/app-deployment.yaml`: Kubernetes Deployment for the application (containers, resources, replicas).
- `templates/app-ingress.yaml`: Ingress resource for exposing the application under the configured hostnames.
- `templates/app-secret.yaml`: Kubernetes Secret for sensitive values (for example SMTP/app passwords) created from `values.yaml` or auto-generated data.
- `templates/app-service.yaml`: Service fronting the application Deployment for internal/external access.
- `templates/grafana-dashboard-configmap.yaml`: ConfigMap that holds the dashboard JSON and makes it available to the Grafana pod.
- `templates/grafana-deployment.yaml`: Deployment for Grafana (includes dashboard provisioning).
- `templates/grafana-service.yaml`: Service that exposes Grafana to the cluster or via the Ingress.
- `templates/model-configmap.yaml`: Configuration for the model component (environment or startup config) delivered as a ConfigMap.
- `templates/model-deployment.yaml`: Deployment for the model-serving container(s) which serve predictions.
- `templates/model-service.yaml`: Service exposing the model deployment to other in-cluster components (and optionally the app).
- `templates/prometheusrule.yaml`: PrometheusRule resources defining alerting rules (e.g. TooManyRequests) consumed by Prometheus.
- `templates/servicemonitor.yaml`: ServiceMonitor resource for Prometheus to scrape metrics from the application and model services.

## Prerequisites

- Kubernetes ≥ 1.27
- Helm ≥ 3.10
- A working Ingress controller (or Gateway) if `.Values.app.ingress.enabled` stays true
- HostPath support for `/mnt/shared` (defaults to the VirtualBox shared folder)

---

## Knobs in `values.yaml`

Key sections:

- `global.domain`: control default hostnames
- `global.storage.hostPath`: path on the node and mount path inside the pod (defaults to `/mnt/shared`).
- `app.*`: image, replica count, env vars, ConfigMap data, SMTP credentials (stored via stringData), and the ingress/service definition. By default the ingress renders both a **stable** host (enabled) and a **preview** host (disabled) via `app.ingress.hosts`. Leave `app.secret.smtpPassword` empty (with `autogenerate: true`) to have Helm create a random password during install.
- `model.*`: Values similar to the app, without any ingress or secrets.
- `prometheus`: Prometheus config, installed through kube-promeheus-stack
- `kube-prometheus-stack`: collection which contains prometheus and the alertmanager.
- `alertmanager`: placeholder for the required (secret) app password.
- `grafana.*`: manages Grafana image, admin credentials, service type, and which dashboard file should act as the default home.
- `experiments.preview.*`: future Assignment 4 knobs (currently disabled) that will control preview traffic weight, image overrides, or extra env vars once experimentation features are added.
- `prometheus.*`: toggles the standalone Prometheus deployment/service, scrape interval and ServiceMonitor emission
- `grafana.*`: manages Grafana image, admin credentials, service type, and which dashboard file should act as the default home.

Example production overlay:

```yaml
global:
  domain: "example.com"
  storage:
    enabled: true
    hostPath: "/mnt/shared"
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
prometheus:
  serviceMonitor:
    namespace: observability
grafana:
  adminPassword: "use-a-secret-manager"
```

---

### Prerequisites for alertmanager

The alertmanager requires an email to send the emails. This requires an app password. In this example Gmail is used.

1. Enable 2-Factor Authentication on the Gmail of your choice (required)
2. Go to: https://myaccount.google.com/apppasswords using your Gmail account. Or scroll at the bottom of the 2FA page and click on app passwords.
3. Generate the password which should be a 16-character password: XXXX XXXX XXXX XXXX
4. In the [alertmanager config](./templates/alertmanager-config.yaml) change the emails according to your needs.

## Install with

```
helm install myapp ./helm/myapp/ \
  -n sms-stack \
  --create-namespace \
  --set alertmanager.smtpPassword='XXXX XXXX XXXX XXXX'
```

Running the command above (or using `helm upgrade --install`) is the single entrypoint for deploying the stack into any Kubernetes cluster (Minikube, kind, managed cloud, etc.). Choose the namespace you want to create by replacing `sms-stack` with \<any-namespace\>. It takes a few **minutes** for everything to load correctly.

Before being able to run this however, it might be necessary to run `helm dependency build ./helm/myapp` if you get an error.

> **Note:** `myapp` above is the Helm release name. If you pick a different release name (e.g. `helm install sms-stack ./helm/myapp --namespace sms-stack --create-namespace`), replace `myapp` everywhere accordingly. Many resource names are `<release>-<component>`, so use `kubectl get svc -n sms-stack` to see the exact service names before port-forwarding.

## Testing out alertmanager

Check if pods are running:
`kubectl get pods -n sms-stack`

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
`kubectl get alertmanager -n sms-stack`

Expected result to be similar to:

```
NAME                                      VERSION   REPLICAS   READY   RECONCILED   AVAILABLE   AGE
myapp-kube-prometheus-stac-alertmanager   v0.29.0   1          1       True         True        23h
```

---

Check the config to see if your emails have been applied correctly:
`kubectl exec -n sms-stack alertmanager-myapp-kube-prometheus-stac-alertmanager-0 -c alertmanager -- cat /etc/alertmanager/config_out/alertmanager.env.yaml`

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

Access Prometheus: `kubectl port-forward -n sms-stack svc/myapp-kube-prometheus-stac-prometheus 9090:9090`
Wait a bit, then open: http://localhost:9090/alerts

When you open the page you should see the top row with:

```
alert-rules
TooManyRequests
```

The TooManyRequests should be currently `inactive`. The alert fires when the service receives >15 requests/minute for 2 minutes straight.

Open a new terminal and port forward to the application:
`kubectl port-forward -n sms-stack svc/myapp-app-svc 8080:80`

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

## Testing out Grafana dashboards

Apply the latest Helm chart changes:

```bash
helm upgrade myapp ./helm/myapp --namespace sms-stack --create-namespace
# OR for a fresh install:
# helm install myapp ./helm/myapp --namespace sms-stack --create-namespace
```

## Testing out Traffic Management
In order to test out the traffic management, please follow the following steps:
1. Optional: Run `minikube delete` to start off completely fresh, might be needed if the traffic management doesn't work after following these instructions
2. Run `minikube start` and then `minikube addons enable ingress`
3. Install Istio and run `istioctl install`
4. Create the namespace in which you want to work, in our case it will be `sms-stack`: `kubectl create namespace sms-stack`
5. Enable Istio by running `kubectl label ns default istio-injection=enabled` and `kubectl label ns sms-stack istio-injection=enabled`. 
6. Install the Helm Chart (`helm upgrade --install myapp ./helm/myapp/ -n sms-stack`)
7. Wait until all pods are ready, you can check this by running `kubectl get pods -n sms-stack` and checking the READY column
8. Run `minikube tunnel`
9. Find out the external IP of your ingress gateway by running `kubectl get service -n istio-system`
You should get something similar to the following, but the external IP can differ. There will likely also be
other rows returned but these are not relevant for this.
```
NAME                          TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                                          AGE
istio-ingressgateway          LoadBalancer   10.98.37.197     10.98.37.197   15021:30870/TCP,80:30522/TCP,443:32060/TCP       3d19h
```
10. Access the external IP in the browser. With a 90% chance, you will see the stable version of the app/model. This version
should work exactly as expected and should not contain any abnormal behaviour. With a 10% chance, you will see the experimental version.
When you access {URL}/sms from the experimental version, the UI should be different and any message you will classify should *always* return spam. 
The classification always returning spam is simply so we can show the experimental app and model go hand in hand.
Once you access the app and a get specific version, you are stuck with it for a certain amount of time. 
You can see which version you have in your cookies, these are named v1 and v2, and you can delete these 
and refresh your page as often as you want in order to be convinced the 90/10 split is correctly implemented.
11. We can do the same using curl requests, but this works a little differently. Classifying a message using the
stable Canary header `curl -X POST http://{EXTERNAL_IP}/sms/ -H "Content-Type: application/json" -H "canary stable" -d '{"sms": "hi"}'` 
should *always* return the correct output (`{"classifier":null,"result":"ham","sms":"hi","guess":null}` in the case of our message).
When we add the experimental header, `curl -X POST http://{EXTERNAL_IP}/sms/   -H "Content-Type: application/json" -H "canary: experimental" -d '{"sms": "hi"}'`, you should
*always* get `{"classifier":null,"result":"spam","sms":"hi","guess":null}` regardless of the message.
When we don't add any Canary header, you should get a 90/10 split of ham/spam returned. 

General information:
The default Ingress Gateway selector is set to `ingressgateway`. If deploying to a cluster where the Istio Ingress Gateway 
has a different label, override the `istio.selectorLabels.istio` value in `values.yaml`.

---

Open 2 separate terminal tabs and run the following port-forward commands:

**Tab 1: Application (to generate traffic)**

```bash
kubectl -n sms-stack port-forward svc/myapp-app-svc 8080:80
```

**Tab 2: Grafana (to view dashboards)**

```bash
kubectl -n sms-stack port-forward svc/myapp-grafana-svc 3000:3000
```

---

Open your browser or use curl to send some prediction requests. This will generate the metrics data.

* **Web UI:** Go to `http://localhost:8080/sms` and classify a few messages (mix of Spam and Ham).
* **Curl:**
  ```bash
  curl -X POST http://localhost:8080/sms/classify -d "message=Free money now"
  curl -X POST http://localhost:8080/sms/classify -d "message=Hello friend how are you"
  ```

---

1. Navigate to **[[http://localhost:3000]](http://localhost:3000)** (Login: `admin` / `admin`).
2. Open the **"MyApp Metrics"** dashboard.
3. Ensure the "Data Source" dropdown at the top left is set to **Prometheus**.
4. You should see live data populating the charts (it may take 15-30 seconds for Prometheus to scrape the new data).

---

**Dashboard Overview: "MyApp Metrics"**

| Panel                        | Type                  | Metric Used                                | Description                                                                                                                                                                                                                              |
| :--------------------------- | :-------------------- | :----------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Last SMS Length**    | **Gauge**       | `sms_last_text_length`                   | Displays the character count of the longest SMS recently processed by any pod. Visualizes the "Gauge" metric requirement.                                                                                                                |
| **Prediction Traffic** | **Time Series** | `sms_predictions_total`                  | Shows the rate of prediction requests per second. The query `sum by (result)` aggregates data from all pods and splits the line by classification type (**ham** vs **spam**). Visualizes the "Counter" metric requirement. |
| **Prediction Latency** | **Heatmap**     | `sms_prediction_duration_seconds_bucket` | A heatmap showing the distribution of processing times. Brighter blocks indicate more requests falling into that specific latency bucket. Visualizes the "Histogram" metric requirement.                                                 |
| **Average Latency**    | **Time Series** | *Calculated*                             | Uses a PromQL function to calculate the average duration per request:`rate(sum) / rate(count)`.                                                                                                                                        |

---

## Troubleshooting tips

- `kubectl -n sms-stack port-forward svc/<release-name>-app-svc 8080:80` for quick local validation of the app
- `kubectl -n sms-stack port-forward svc/<release-name>-kube-prometheus-stac-prometheus 9090:9090` for quick local validation of the app
- `kubectl -n sms-stack logs deploy/<release-name>-myapp-prometheus` to inspect Prometheus scrape errors.
- If dashboards fail to load, verify the `grafana-dashboard-configmap` exists and the Grafana pod mounts `/var/lib/grafana/dashboards`.
