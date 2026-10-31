# Monitoring Minikube with Prometheus and Grafana

This guide installs **kube-prometheus-stack** on Minikube with Helm and shows how to open Grafana and Prometheus.

The chart installs:

| Component | Purpose |
|---|---|
| Prometheus Operator | Manages Prometheus through CRDs |
| Prometheus | Scrapes and stores metrics |
| Alertmanager | Routes and groups alerts |
| Grafana | Dashboards (ready-made ones included) |
| node-exporter | Host CPU, memory, disk and network metrics |
| kube-state-metrics | State of pods, deployments and nodes |

## Prerequisites

- Docker, `minikube`, `kubectl` and `helm` installed
- At least 4 CPUs and 6 GB of memory free for Minikube

```bash
minikube version
kubectl version --client
helm version
```

## 1. Start Minikube

```bash
minikube start --driver=docker --cpus=4 --memory=6144
minikube status
```

Enable the ingress addon only if you want to reach Grafana through a domain (see [Option B](#option-b-domain-through-ingress)):

```bash
minikube addons enable ingress
```

## 2. Install the monitoring stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

- The release name `monitoring` gives service names such as `monitoring-grafana`.
- `serviceMonitorSelectorNilUsesHelmValues=false` lets Prometheus pick up ServiceMonitors from every namespace, not only this release.
- Change `admin123` to a stronger password for anything beyond a lab.

## 3. Verify the installation

```bash
kubectl get pods -n monitoring -w
```

Wait until every pod is `Running` (this can take a few minutes). Then check the services:

```bash
kubectl get svc -n monitoring
```

## 4. Fix the Minikube-only DOWN targets

On Minikube, etcd, kube-scheduler, kube-controller-manager and kube-proxy bind their metrics to `127.0.0.1`, so Prometheus shows them as **DOWN**. Turn those scrapers off to avoid false alerts:

```bash
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring \
  --reuse-values \
  --set kubeEtcd.enabled=false \
  --set kubeControllerManager.enabled=false \
  --set kubeScheduler.enabled=false \
  --set kubeProxy.enabled=false
```

On a real cluster these stay enabled.

## 5. Access Grafana and Prometheus

### Option A: port-forward (simplest)

Run each command in its own terminal and keep it running.

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Alertmanager (optional)
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
```

| Tool | URL | Login |
|---|---|---|
| Grafana | http://localhost:3000 | `admin` / `admin123` |
| Prometheus | http://localhost:9090 | none |
| Alertmanager | http://localhost:9093 | none |

In Prometheus, open **Status → Targets** to confirm targets are `UP`.

If you forget the Grafana password:

```bash
kubectl get secret -n monitoring monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

### Option B: domain through ingress

Create `grafana-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
```

```bash
kubectl apply -f grafana-ingress.yaml
```

Add the domain to your hosts file (`/etc/hosts`, or `C:\Windows\System32\drivers\etc\hosts` on Windows):

```text
127.0.0.1 grafana.local
```

With the Docker driver the ingress is not reachable directly, so forward the ingress controller:

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80
```

Then open http://grafana.local:8081.

## 6. Useful dashboards

Grafana ships with Kubernetes dashboards. Go to **Dashboards** and open:

- **Kubernetes / Compute Resources / Namespace (Pods)**: CPU and memory per pod
- **Node Exporter / Nodes**: host metrics

To import more, go to **Dashboards → New → Import** and enter an ID:

| ID | Dashboard |
|---|---|
| 1860 | Node Exporter Full |
| 15760 | Kubernetes / Views / Pods |


```bash
kubectl apply -f servicemonitor.yaml
```

The new target appears in **Status → Targets** within a minute.

## Lighter alternative: metrics-server only

If you only need quick resource numbers, skip the full stack:

```bash
minikube addons enable metrics-server
kubectl top nodes
kubectl top pods -A
```

## Troubleshooting

| Problem | Fix |
|---|---|
| etcd, scheduler or controller-manager targets are DOWN | Disable those scrapers (step 4) |
| Pods Pending or restarting | Minikube is short on memory; restart it with `--cpus=4 --memory=6144` |
| `minikube service` does not open on WSL | Use `kubectl port-forward` instead |
| Grafana shows "No data" | Check **Status → Targets** in Prometheus, then check the dashboard time range |
| ServiceMonitor target missing | Check its selector labels and port name against the Service |

## Cleanup

```bash
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

Helm does not remove the CRDs. To remove them as well:

```bash
kubectl get crd | grep monitoring.coreos.com | awk '{print $1}' | xargs kubectl delete crd
```