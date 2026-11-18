# Django Todo App on Kubernetes — Setup Guide

## 1. Overview

This project deploys a Django Todo application and PostgreSQL database to a local Kubernetes cluster using Minikube.

### Architecture

- **Django:** Two application replicas
- **PostgreSQL:** One database replica
- **Service:** Internal `ClusterIP` service for Django
- **Ingress:** NGINX Ingress controller for HTTP routing
- **Local hostname:** `todo.test`
- **Development environment:** WSL2, Debian 12, Docker driver, Minikube

Request flow:

```text
Browser
   |
   | http://todo.test:8080
   v
NGINX Ingress Controller
   |
   | django-service:8000
   v
Django Application Pods
   |
   v
PostgreSQL Service / Pod
```

## 2. Prerequisites

Ensure the following tools are installed:

- WSL2 with Debian 12
- Docker
- Minikube
- kubectl

Verify the installations:

```bash
docker --version
minikube version
kubectl version --client
```

Start Docker if it is not already running.

## 3. Start the Minikube Cluster

Start a local Kubernetes cluster using the Docker driver:

```bash
minikube start --driver=docker
```

Verify the cluster:

```bash
minikube status
kubectl cluster-info
kubectl get nodes
```

Confirm that the node is `Ready`:

```bash
kubectl get nodes -o wide
```

Check the Kubernetes version:

```bash
kubectl version
```

## 4. Navigate to the Kubernetes Manifests

Move to the directory containing the Kubernetes YAML files:

```bash
cd ~/lab/broadway-labs/day10/kubernetes/k8s_file
```

List the available manifests:

```bash
ls -la
```

The directory contains the deployment, Service, and Ingress manifests used by the application.

## 5. Deploy the Application

Apply the Kubernetes manifests.

If the manifests are in separate files, apply them individually:

```bash
kubectl apply -f postgres-deployment.yaml
kubectl apply -f django-deployment.yaml
kubectl apply -f django-service.yaml
```

Apply the database Service manifest as well if the database deployment uses a separate Service file:

```bash
kubectl apply -f postgres-service.yaml
```

> **Note:** Use the actual filenames present in the repository. If the manifests are organized into a single directory, you can apply all supported YAML manifests with `kubectl apply -f <directory>/`, provided the files are intended to be deployed together.

Check the resources in the application namespace:

```bash
kubectl get all -n todo-app
```

Check the deployments:

```bash
kubectl get deployments -n todo-app
```

Check the pods:

```bash
kubectl get pods -n todo-app -o wide
```

Check the application logs:

```bash
kubectl logs -n todo-app deployment/django-app
```

The expected state is two ready Django replicas and one ready PostgreSQL replica.

## 6. Understand the Django Service

The Django Service provides a stable internal endpoint for the application pods.

Example Service configuration (`django-service.yaml`):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: django-service
  namespace: todo-app
spec:
  selector:
    app: django-app
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 8000
  type: ClusterIP
```

Apply the Service:

```bash
kubectl apply -f django-service.yaml
```

Verify it:

```bash
kubectl get svc django-service -n todo-app
kubectl describe svc django-service -n todo-app
```

Check the Service endpoints:

```bash
kubectl get endpoints django-service -n todo-app
```

On newer Kubernetes versions, EndpointSlices are the preferred alternative:

```bash
kubectl get endpointslices -n todo-app
```

Check the Django pod labels:

```bash
kubectl get pods -n todo-app --show-labels
```

The Service selector `app: django-app` must match the Django pod label `app=django-app`.

The Service should have endpoints corresponding to the running Django pods.

### Test the Service from inside Kubernetes

Run a temporary curl container:

```bash
kubectl run curl-test \
  -n todo-app \
  --rm -it \
  --image=curlimages/curl \
  --restart=Never \
  -- curl -i http://django-service:8000/
```

A `302` redirect to the login page can be expected if the Django home page requires authentication.

A `ClusterIP` Service is intended for internal cluster access. It is not automatically exposed to the Windows host browser.

## 7. Enable the NGINX Ingress Controller

Enable Minikube's Ingress add-on:

```bash
minikube addons enable ingress
```

Verify the controller pods:

```bash
kubectl get pods -n ingress-nginx
```

Check the controller Service:

```bash
kubectl get svc -n ingress-nginx
```

Wait until the controller is ready before proceeding.

## 8. Configure the Ingress Resource

Create or edit `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: django-ingress
  namespace: todo-app
spec:
  ingressClassName: nginx
  rules:
    - host: todo.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: django-service
                port:
                  number: 8000
```

This configuration routes requests for `todo.test` to `django-service` on port `8000`.

No rewrite annotation is required for this basic setup. Keeping the original request paths allows Django routes such as `/accounts/login/` to work correctly.

Apply the Ingress:

```bash
kubectl apply -f ingress.yaml
```

Verify the resource:

```bash
kubectl get ingress -n todo-app
kubectl describe ingress django-ingress -n todo-app
```

Confirm that the host is `todo.test` and the backend is `django-service:8000`.

## 9. Access Ingress from WSL2

With the Minikube Docker driver under WSL2, the node's IP address may not be directly accessible from the Windows browser. A local port-forward provides a convenient development route.

Run:

```bash
kubectl port-forward \
  -n ingress-nginx \
  service/ingress-nginx-controller \
  8080:80
```

Keep this terminal open while using the application.

The command forwards local port `8080` to port `80` on the NGINX Ingress controller.

### Test Ingress routing

Open another WSL2 terminal and run:

```bash
curl -i -H "Host: todo.test" http://127.0.0.1:8080/
```

The `Host` header is important because the Ingress rule matches the hostname `todo.test`.

A `200 OK` response or a `302` redirect to the Django login page indicates that the request reached the application.

## 10. Configure the Windows Hosts File

To access the application using the hostname in a Windows browser, edit the Windows hosts file as Administrator:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add:

```text
127.0.0.1 todo.test
```

Save the file.

Ensure that the Ingress port-forward command is still running, then open:

**http://todo.test:8080**

The port `8080` is required because the local port-forward maps `8080` to the Ingress controller's HTTP port `80`.

## 11. Useful Verification Commands

### Kubernetes cluster

```bash
minikube status
kubectl get nodes
kubectl cluster-info
```

### Application resources

```bash
kubectl get all -n todo-app
kubectl get pods -n todo-app -o wide
kubectl get deployments -n todo-app
kubectl get svc -n todo-app
```

### Django logs

```bash
kubectl logs -n todo-app deployment/django-app
```

Follow logs continuously:

```bash
kubectl logs -f -n todo-app deployment/django-app
```

### PostgreSQL logs

```bash
kubectl logs -n todo-app deployment/postgres
```

### Service and endpoints

```bash
kubectl describe svc django-service -n todo-app
kubectl get endpointslices -n todo-app
```

### Ingress resources and controller

```bash
kubectl get ingress -n todo-app
kubectl describe ingress django-ingress -n todo-app
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50
```

## 12. Troubleshooting

### Django pods are not ready

```bash
kubectl get pods -n todo-app
kubectl describe pods -n todo-app
kubectl logs -n todo-app deployment/django-app
```

Look for database connection failures, migration errors, image pull failures, or application startup errors.

### Django Service has no endpoints

```bash
kubectl get pods -n todo-app --show-labels
kubectl describe svc django-service -n todo-app
kubectl get endpointslices -n todo-app
```

Verify that the Service selector matches the Django pod labels and that the pods are ready.

### Ingress is not working

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingress -n todo-app
kubectl describe ingress django-ingress -n todo-app
```

Check controller logs:

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50
```

Ensure the port-forward is still running and test the hostname explicitly:

```bash
curl -i -H "Host: todo.test" http://127.0.0.1:8080/
```

### Django redirects to the login page

A redirect such as:

```text
/accounts/login/?next=/
```

is expected if the home page requires authentication. It is not, by itself, a Kubernetes or Ingress error.

### Port-forward fails because the port is occupied

Choose another local port, such as `8081`:

```bash
kubectl port-forward \
  -n ingress-nginx \
  service/ingress-nginx-controller \
  8081:80
```

Then use `http://todo.test:8081`.

## 13. Cleanup

To remove the application resources deployed from the manifests:

```bash
kubectl delete -f ingress.yaml
kubectl delete -f django-service.yaml
kubectl delete -f django-deployment.yaml
kubectl delete -f postgres-deployment.yaml
```

Delete the PostgreSQL Service as well if it was created from a separate manifest.

If you want to disable the Ingress add-on:

```bash
minikube addons disable ingress
```

**Warning:** Deleting deployments, Services, or persistent volume claims can affect application data. Inspect your storage resources before deleting them.

## 14. Key Concepts

| Resource | Purpose |
|---|---|
| Deployment | Manages and replaces application pods |
| Pod | Runs a Django or PostgreSQL container |
| ClusterIP Service | Provides stable internal networking |
| EndpointSlice | Tracks pod endpoints selected