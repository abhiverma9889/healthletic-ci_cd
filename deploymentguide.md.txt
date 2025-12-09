# DEPLOYMENT_GUIDE.md – Healthletic

## 📌 Overview

This guide explains how the **Healthletic DevOps CI/CD pipeline** works, how to deploy manually, required prerequisites, troubleshooting steps, and rollback procedures. Use this as reference for HR and technical evaluation.

---

## 🧱 Technology Stack

| Component         | Description                                            |
| ----------------- | ------------------------------------------------------ |
| GitHub Actions    | CI/CD automation for build, scan, push, deploy         |
| Docker            | Containerization of backend service                    |
| Docker Hub        | Container registry used for pushing application images |
| Kubernetes (Kind) | Deployment environment inside GitHub runner            |
| Helm              | Blue/Green deployment orchestration                    |
| Trivy             | Security vulnerability scan                            |

---

## 🔐 Prerequisites & Secrets Required

Before running the pipeline, configure the following secrets in **GitHub → Settings → Secrets → Actions**:

| Secret Name       | Value                       |
| ----------------- | --------------------------- |
| `DOCKER_USERNAME` | Docker Hub username         |
| `DOCKER_PASSWORD` | Docker Hub password / token |

### Local prerequisites

* Docker Desktop with Kubernetes enabled OR Kind installed
* kubectl CLI installed
* Helm installed

---

## ⚙️ How the GitHub Actions Workflow Works (Execution Flow)

### Pipeline Stages

1. **Checkout Code** – Pull project source from GitHub repo
2. **Build Docker Image** – Uses Buildx and tags with version `v1.${{ github.run_number }}`
3. **Scan image** – Runs Trivy to detect vulnerabilities
4. **Push image to Docker Hub**
5. **Create Kind cluster in GitHub Runner** for testing deployment
6. **Apply Kubernetes manifests** and create namespace `ci`
7. **Helm deploy with Blue/Green** strategy
8. **Smoke test** using port‑forward
9. **Traffic switch** to new version if successful

---

## 📦 Manual Deployment Script (Local)

### 1️⃣ Build & push Docker image

```sh
docker build -t <username>/backend:v1 .
docker push <username>/backend:v1
```

### 2️⃣ Start Kind cluster

```sh
kind create cluster --name kind
```

### 3️⃣ Apply Kubernetes manifests

```sh
kubectl apply -f k8s/ -n ci
```

### 4️⃣ Deploy with Helm

```sh
helm upgrade --install backend-blue helm/backend --set color=blue --namespace ci --create-namespace
```

### 5️⃣ Forward port

```sh
kubectl port-forward svc/backend -n ci 8080:5000
```

---

## 🛠 Troubleshooting Common Failures

### ❌ ImagePullBackOff / Pull Access Denied

**Cause:** Docker image not found or private registry

```sh
docker login
docker pull <username>/backend:v1
```

Make sure Docker Hub repo is **Public**.

### ❌ Pod stuck in Pending

```sh
kubectl describe pod <pod-name> -n ci
```

Look for scheduling or image errors.

### ❌ Helm Deployment Errors

```sh
helm uninstall backend-blue -n ci
helm dependency update helm/backend
```

### ❌ Service returns no endpoints

Check label selectors:

```sh
kubectl get pods -n ci --show-labels
kubectl get svc backend -n ci
```

---

## 🔄 Rollback Procedures

### Automatic rollback in Blue/Green

If smoke test fails, keep active color unchanged.

### Manual rollback

```sh
kubectl patch svc backend -n ci -p '{"spec":{"selector":{"color":"blue"}}}'
```

Or revert via Helm:

```sh
helm rollback backend-blue 1 -n ci
```

---

## 📍 Evaluation Metrics

| Category                | Expected Result                                       |
| ----------------------- | ----------------------------------------------------- |
| CI/CD Workflow          | Executes build, scan, push, deploy reliably           |
| Kubernetes Deployment   | Pods start successfully and traffic flows via service |
| Blue/Green Strategy     | Zero‑downtime switching between versions              |
| Troubleshooting Ability | Can diagnose ImagePullBackOff, Pending, Helm errors   |
| Project Documentation   | Clear deployment and rollback instructions            |

---

## 🎉 Final Notes

Healthletic demonstrates an end‑to‑end production‑style DevOps workflow using automation, Kubernetes orchestration, and Blue/Green rollout. This system ensures safe deploys, rollback options, and continuous delivery.
