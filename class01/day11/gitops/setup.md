# Argo CD on Minikube: Setup and GitOps Deployment of a Django Todo App

A hands-on lab that installs Argo CD on a local Minikube cluster, exposes it through an NGINX Ingress with a custom domain, and uses it to deploy a Django + PostgreSQL todo application straight from Git.

> **Environment used:** Minikube (Docker driver) inside WSL2 on Windows, browser on Windows.
> Linux/macOS users can skip the WSL-specific steps.

---

## Table of Contents

1. [Architecture](#1-architecture)
2. [Prerequisites](#2-prerequisites)
3. [Start Minikube](#3-start-minikube)
4. [Install Argo CD](#4-install-argo-cd)
5. [Expose Argo CD with Ingress and a domain](#5-expose-argo-cd-with-ingress-and-a-domain)
6. [Log in to Argo CD](#6-log-in-to-argo-cd)
7. [Repository layout](#7-repository-layout)
8. [Create the Argo CD Application](#8-create-the-argo-cd-application)
9. [Access the Django app](#9-access-the-django-app)
10. [Test the GitOps loop](#10-test-the-gitops-loop)
11. [Delete and recreate an Application](#11-delete-and-recreate-an-application)
12. [Troubleshooting](#12-troubleshooting)
13. [Cleanup](#13-cleanup)
14. [Key takeaways](#14-key-takeaways)

---

## 1. Architecture

```
Developer ──git push──▶ GitHub (main)
                           ▲
                           │ pulls every ~3 min (or on refresh)
                    ┌──────┴────────┐
                    │    Argo CD    │  (namespace: argocd)
                    └──────┬────────┘
                           │ applies manifests
                           ▼
              Namespace: todo-app
              ├── django-app (Deployment, 2 replicas)
              ├── postgres (Deployment + PVC)
              ├── Services, Secrets
              └── django-ingress (todo.local)

Browser ─▶ hosts file ─▶ 127.0.0.1:8081 ─▶ kubectl port-forward
        ─▶ ingress-nginx controller ─▶ routes by hostname:
              argocd.local ─▶ argocd-server
              todo.local   ─▶ django service
```

Argo CD runs **inside** the cluster and **pulls** from Git, so the cluster credentials never leave the cluster.

---

## 2. Prerequisites

- Docker, `kubectl`, `minikube`
- At least 2 CPUs and 4 GB RAM free
- A GitHub repository with your Kubernetes manifests (public, or add credentials in Argo CD)
- A Docker Hub image of the app (here: `98543218/todo-web:latest`)

---

## 3. Start Minikube

```bash
minikube start --cpus=2 --memory=4096 --driver=docker
kubectl get nodes
```

---

## 4. Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

If the `applicationsets` CRD fails with `metadata.annotations: Too long`, use server-side apply:

```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

## 5. Expose Argo CD with Ingress and a domain

`minikube service argocd-server -n argocd --url` only works while that terminal stays open (Docker driver on Linux). An Ingress with a hostname is the permanent solution.

### 5.1 Enable the ingress controller

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

### 5.2 Run Argo CD in HTTP mode behind the ingress

Argo CD serves HTTPS by default and redirects HTTP to HTTPS, which loops behind an ingress. For a lab, switch it to insecure mode and let the ingress handle traffic:

```bash
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment argocd-server -n argocd
```

### 5.3 Create the Ingress

`argocd-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
```

```bash
kubectl apply -f argocd-ingress.yaml
kubectl get ingress -n argocd
```

### 5.4 Map the domain to an IP

**Inside WSL / native Linux** (Minikube IP is reachable):

```bash
echo "$(minikube ip) argocd.local" | sudo tee -a /etc/hosts
curl -I http://argocd.local
```

**Windows browser with Minikube in WSL.** The Minikube IP (e.g. `192.168.49.2`) lives on a Docker network inside WSL and is **not reachable from Windows**. Forward the ingress controller instead.

1. Run this in WSL and keep it open:

   ```bash
   kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80 --address 0.0.0.0
   ```

   To run it in the background:

   ```bash
   nohup kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80 --address 0.0.0.0 > /tmp/ingress-pf.log 2>&1 &
   ```

2. Edit `C:\Windows\System32\drivers\etc\hosts` (Notepad as Administrator) and add:

   ```
   127.0.0.1 argocd.local todo.local
   ```

3. Open **http://argocd.local:8081**.

> **Why `:8081`?** It comes from the `port-forward` command (`8081:80` means local port 8081 to port 80 of the ingress controller), not from any Ingress YAML. One forward serves every app, because the controller routes by the `Host` header.

> To avoid the port number, forward local port 80 instead:
> `sudo kubectl --kubeconfig $HOME/.kube/config port-forward -n ingress-nginx svc/ingress-nginx-controller 80:80 --address 0.0.0.0`
> (make sure no other service, such as a stray local nginx, is using port 80).

---

## 6. Log in to Argo CD

Username: `admin`

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Optional CLI:

```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/
argocd login argocd.local:8081 --grpc-web --insecure --username admin
```

Change the password and remove the initial secret:

```bash
argocd account update-password
kubectl -n argocd delete secret argocd-initial-admin-secret
```

---

## 7. Repository layout

```
broadway-labs/
├── day10/
│   └── kubernetes/
│       └── k8s_file/                 # watched by Argo CD
│           ├── namespace.yaml
│           ├── django-deployment.yaml
│           ├── django-service.yaml
│           ├── django-secret.yaml
│           ├── postgres-deployment.yaml
│           ├── postgres-service.yaml
│           ├── postgres-secret.yaml
│           ├── postgres-pv.yaml
│           ├── postgres-pvc.yaml
│           └── ingress.yaml
└── day11/
    └── backend-app.yaml              # the Argo CD Application (NOT in the watched folder)
```

Important points:

- Argo CD applies **every YAML file** in the `source.path` folder (not subfolders).
- Keep the Application manifest **outside** the watched path.
- Do not duplicate resources: two files defining the same Service name will conflict.
- Resources should use `namespace: todo-app` or no namespace at all.
- The Deployment must use an image the cluster can pull:

  ```yaml
  image: 98543218/todo-web:latest
  imagePullPolicy: Always
  ```

---

## 8. Create the Argo CD Application

`day11/backend-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: django-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io   # deleting the app also deletes its resources
spec:
  project: default

  source:
    repoURL: https://github.com/Sakshi9111/broadway-labs.git
    targetRevision: main
    path: day10/kubernetes/k8s_file

  destination:
    server: https://kubernetes.default.svc
    namespace: todo-app

  syncPolicy:
    automated:
      prune: true        # delete resources removed from Git
      selfHeal: true     # revert manual changes in the cluster
    syncOptions:
      - CreateNamespace=true
```

Apply and verify:

```bash
kubectl apply -f day11/backend-app.yaml
kubectl get applications -n argocd
kubectl get pods,svc,ingress -n todo-app
```

In the Argo CD UI the app should show **Synced** and **Healthy**.

### Field reference

| Field | Meaning |
|---|---|
| `source.repoURL` / `targetRevision` / `path` | Where the manifests live in Git |
| `destination.server` | `https://kubernetes.default.svc` means the same cluster Argo CD runs in |
| `destination.namespace` | Namespace the resources are deployed into |
| `automated` | Sync without clicking when Git changes |
| `prune` | Remove cluster resources that were deleted from Git |
| `selfHeal` | Revert manual drift back to the Git state |
| `CreateNamespace=true` | Create the namespace if it does not exist |

---

## 9. Access the Django app

Ingress for the app (`ingress.yaml`) uses host `todo.local`. With the hosts file entry from step 5.4 (`127.0.0.1 todo.local`) and the port-forward running:

**http://todo.local:8081**

From WSL you can verify without a browser:

```bash
echo "$(minikube ip) todo.local" | sudo tee -a /etc/hosts
curl -I http://todo.local
# HTTP/1.1 302 Found  ->  Location: /accounts/login/?next=/
```

A `302` to `/accounts/login/` is Django's normal response for a page that requires login, so the ingress, service and pods are all working.

Both domains share one forward:

```bash
curl -I -H "Host: argocd.local" http://localhost:8081
curl -I -H "Host: todo.local"   http://localhost:8081
```

If the browser shows `Bad Request (400)`, add the domain to Django:

```python
ALLOWED_HOSTS = ["todo.local", "localhost"]
CSRF_TRUSTED_ORIGINS = ["http://todo.local:8081"]
```

---

## 10. Test the GitOps loop

**Git to cluster:**

1. Change `replicas` in `django-deployment.yaml`.
2. Commit and push to `main`:

   ```bash
   git add day10/kubernetes/k8s_file/django-deployment.yaml
   git commit -m "Scale django to 3 replicas"
   git push origin main
   ```

3. Argo CD syncs automatically (polls about every 3 minutes), or force it:

   ```bash
   kubectl annotate application django-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
   ```

   or click **Refresh** then **Sync** in the UI.

**Self-heal:**

```bash
kubectl scale deployment django-app -n todo-app --replicas=1
kubectl get pods -n todo-app -w
```

Argo CD reverts the replica count back to the value in Git.

**Rollback:** `git revert <commit>` and push, or use **History and Rollback** in the UI (rollback is blocked while auto-sync is on, so revert in Git).

---


C:\Windows\System32\drivers\etc

echo "192.168.49.2 todo.local" | sudo tee -a /etc/hosts