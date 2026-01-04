
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
    model-*.yaml
    prometheusrule.yaml
    servicemonitor.yaml
```

Keep in mind, the Grafana part of the helm charts is NOT yet implemented. If you start the implementation, you can delete/change/add any and all Grafana related
files you deem necessary

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


## Testing out Traffic Management
In order to test out the traffic management, please follow the following steps:
1. Install Istio and run `istioctl install` after having started a minikube cluster 
2. Create the namespace in which you want to work, in our case it will be `sms-stack`: `kubectl create namespace sms-stack`
3. Enable Istio in this namespace `kubectl label namespace sms-stack istio-injection=enabled`
4. Install the Helm Chart (`helm install myapp ./helm/myapp/ -n sms-stack`)
5. Run `minikube tunnel`
6. Find out the external IP of your ingress gateway by running `kubectl get service -n istio-system`
You should get something similar to the following, but the external IP can differ. There will likely also be
other rows returned but these are not relevant for this.
```
NAME                          TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                                          AGE
istio-ingressgateway          LoadBalancer   10.98.37.197     10.98.37.197   15021:30870/TCP,80:30522/TCP,443:32060/TCP       3d19h
```
7. Access the external IP in the browser. With a 90% chance, you will see the stable version of the app/model. This version
should work exactly as expected and should not contain any abnormal behaviour. With a 10% chance, you will see the experimental version.
This version has a different message on the base URL, namely 'Hello World from outer space!'. Furthermore, when you access {URL}/sms, any message you will classify should *always* return spam. Once you access the app and get specific version, you are stuck with it
for a certain amount of time. You can see which version you have in your cookies, these are named v1 and v2, and you can delete these 
and refresh your page as often as you want in order to be convinced the 90/10 split is correctly implemented.
8. We can do the same using curl requests, but this works a little differently. Classifying a message using
`curl -X POST http://{EXTERNAL_IP}/sms/   -H "Content-Type: application/json"  -d '{"sms": "hi"}'` should return the correct
output 90% of the time (`{"classifier":null,"result":"ham","sms":"hi","guess":null}` in the case of our message), 
and spam 10% of the time (`{"classifier":null,"result":"spam","sms":"hi","guess":null}`). When we add the Canary "bypass" header, 
`curl -X POST http://{EXTERNAL_IP}/sms/   -H "Content-Type: application/json" -H "canary: enabled"  -d '{"sms": "hi"}'`, you should
*always* get `{"classifier":null,"result":"spam","sms":"hi","guess":null}` regardless of the message.
9. For the home page: `curl -X GET http://{EXTERNAL_IP}/` should return `Hello World!  lib-version=0.1.0` 90% of the time and
`Hello World from outer space!  lib-version=0.1.0` 10% of the time. `curl -X GET http://{EXTERNAL_IP}/ -H "canary: enabled"`
should *always* return `Hello World from outer space!  lib-version=0.1.0`


General information:
The default Ingress Gateway selector is set to `ingressgateway`. If deploying to a cluster where the Istio Ingress Gateway 
has a different label, override the `istio.selectorLabels.istio` value in `values.yaml`.

TODO: Once an actual experimental version of the model/app has been implemented, their description should be changed here.

---

All knobs live in `values.yaml`. Key sections:

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
- `grafana.*`: manages Grafana image, admin credentials, service type, and which dashboard file should act as the default home. To be correctly implemented!

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

## Troubleshooting tips

- `kubectl -n sms-stack port-forward svc/<release-name>-app-svc 8080:80` for quick local validation of the app
- `kubectl -n sms-stack port-forward svc/<release-name>-kube-prometheus-stac-prometheus 9090:9090` for quick local validation of the app
    
- `kubectl -n sms-stack logs deploy/<release-name>-myapp-prometheus` to inspect Prometheus scrape errors.
- If dashboards fail to load, verify the `grafana-dashboard-configmap` exists and the Grafana pod mounts `/var/lib/grafana/dashboards`.

