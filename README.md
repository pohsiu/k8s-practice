# k8s-practice

A simple Express web server with Kubernetes PR-based deployment setup.

## Overview

This project demonstrates how to deploy Express applications to Kubernetes with PR-based deployments. Each PR branch gets its own deployment, service, and ingress that routes traffic based on the `x-multi-env` header.

## Features

- Express web server with health check endpoint
- Kubernetes manifests for PR-based deployments
- Header-based routing using nginx ingress controller
- Docker image support for containerized deployments

## Project Structure

```
.
├── server.js              # Express application
├── Dockerfile             # Docker image definition
├── package.json           # Node.js dependencies
├── k8s/
│   ├── deployment-template.yml    # Deployment template
│   ├── service-template.yml       # Service template
│   ├── ingress-template.yml       # Ingress template
│   ├── deployment-default.yml     # Default deployment (no branch label)
│   ├── service-default.yml        # Default service (no branch label)
│   ├── ingress-default.yml        # Default ingress for requests without PR header
│   ├── deployment-pr-dev-1.yml    # Example deployment for pr-dev-1
│   ├── service-pr-dev-1.yml       # Example service for pr-dev-1
│   ├── ingress-pr-dev-1.yml      # Example ingress for pr-dev-1
│   └── generate-pr-manifests.sh   # Script to generate manifests for new PR branches
├── scripts/
│   ├── setup-minikube.sh              # Setup minikube script
│   ├── deploy-default-to-minikube.sh  # Deploy default service to minikube
│   ├── deploy-to-minikube.sh          # Deploy PR branch to minikube
│   └── update-ingress-for-minikube.sh # Update ingress host for minikube
└── README.md
```

## Setup

### Deploy Default Service

First, deploy the default service that handles requests without PR branch headers:

```bash
# Build default image
docker build -t express-app:latest .

# Deploy default service
kubectl apply -f k8s/deployment-default.yml
kubectl apply -f k8s/service-default.yml
kubectl apply -f k8s/ingress-default.yml
```

The default service uses:
- **Deployment**: `express-app-default` with labels `app: express-app` and `type: default` (no branch label)
- **Service**: `express-app-default` that selects pods with `app: express-app` and `type: default`
- **Ingress**: Routes to default service when no PR branch header is present

## Setup for PR-Based Deployments

### 1. Build Docker Image

First, build the Docker image for your PR branch:

```bash
# Build image with PR branch tag
docker build -t express-app:pr-dev-1 .

# Or if using a container registry:
docker build -t your-registry/express-app:pr-dev-1 .
docker push your-registry/express-app:pr-dev-1
```

### 2. Generate Kubernetes Manifests

When a PR is created (e.g., branch `pr-dev-1`), generate the Kubernetes manifests:

```bash
cd k8s
./generate-pr-manifests.sh pr-dev-1
```

This will create:
- `deployment-pr-dev-1.yml`
- `service-pr-dev-1.yml`
- `ingress-pr-dev-1.yml`

### 3. Update Ingress Host

Edit the generated ingress file and update the `host` field in the ingress rules to your actual domain:

```yaml
spec:
  ingressClassName: nginx
  rules:
  - host: your-actual-domain.com  # Update this
```

### 4. Deploy to Kubernetes

Apply the manifests to your Kubernetes cluster:

```bash
kubectl apply -f k8s/deployment-pr-dev-1.yml
kubectl apply -f k8s/service-pr-dev-1.yml
kubectl apply -f k8s/ingress-pr-dev-1.yml
```

### 5. Test the Deployment

Test the deployment by sending a request with the `x-multi-env` header:

```bash
# Request with matching PR branch header (routes to PR service)
curl -H "x-multi-env: pr-dev-1" http://your-actual-domain.com/

# Request without PR branch header (routes to default service)
curl http://your-actual-domain.com/
```

## How It Works

### Default Service
- **Deployment**: `express-app-default` with labels `app: express-app` and `type: default` (no branch label)
- **Service**: Routes to pods with `app: express-app` and `type: default` (ensures PR branch pods don't match)
- **Ingress**: Default ingress routes traffic when no PR branch header matches

### PR Branch Services
1. **Deployment**: Each PR branch gets its own deployment with labels (`app: express-app` and `branch: <pr-branch>`)
2. **Service**: Service selects pods by matching labels (`app: express-app` and `branch: <pr-branch>`)
3. **Ingress**: Ingress uses nginx annotations to check the `x-multi-env` header:
   - If header matches the PR branch name (e.g., `x-multi-env: pr-dev-1`), traffic routes to that PR service
   - If header doesn't match, request falls through to default service

## Quick Start with Minikube

### Prerequisites
- [minikube](https://minikube.sigs.k8s.io/docs/start/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed

### Setup Minikube

1. **Initialize minikube:**
   ```bash
   chmod +x scripts/*.sh
   ./scripts/setup-minikube.sh
   ```

2. **Deploy default service (no branch label):**
   ```bash
   ./scripts/deploy-default-to-minikube.sh
   ```

3. **Test the default service:**
   ```bash
   MINIKUBE_IP=$(minikube ip)
   curl http://$MINIKUBE_IP.nip.io/
   curl http://$MINIKUBE_IP.nip.io/health
   ```

### Deploy PR Branch to Minikube

1. **Deploy PR branch service:**
   ```bash
   ./scripts/deploy-to-minikube.sh pr-dev-1
   ```

2. **Test with PR branch header:**
   ```bash
   MINIKUBE_IP=$(minikube ip)
   # Routes to PR branch service
   curl -H "x-multi-env: pr-dev-1" http://$MINIKUBE_IP.nip.io/
   # Routes to default service
   curl http://$MINIKUBE_IP.nip.io/
   ```

### Manual Deployment (Alternative)

1. **Start minikube:**
   ```bash
   minikube start
   minikube addons enable ingress
   ```

2. **Set Docker environment:**
   ```bash
   eval $(minikube docker-env)
   ```

3. **Build and deploy default service:**
   ```bash
   # Build default image
   docker build -t express-app:latest .
   
   # Update ingress host
   MINIKUBE_IP=$(minikube ip)
   sed -i.bak "s/your-domain.com/$MINIKUBE_IP.nip.io/" k8s/ingress-default.yml
   
   # Deploy
   kubectl apply -f k8s/deployment-default.yml
   kubectl apply -f k8s/service-default.yml
   kubectl apply -f k8s/ingress-default.yml
   ```

4. **Build and deploy PR branch service:**
   ```bash
   # Build PR branch image
   docker build -t express-app:pr-dev-1 .
   
   # Generate manifests if needed
   cd k8s && ./generate-pr-manifests.sh pr-dev-1 && cd ..
   
   # Update ingress host
   MINIKUBE_IP=$(minikube ip)
   sed -i.bak "s/your-domain.com/$MINIKUBE_IP.nip.io/" k8s/ingress-pr-dev-1.yml
   
   # Deploy
   kubectl apply -f k8s/deployment-pr-dev-1.yml
   kubectl apply -f k8s/service-pr-dev-1.yml
   kubectl apply -f k8s/ingress-pr-dev-1.yml
   ```

### Useful Commands

```bash
# View logs
kubectl logs -l type=default  # Default service
kubectl logs -l branch=pr-dev-1  # PR branch service

# Check status
kubectl get pods
kubectl get svc
kubectl get ingress

# Port forward for local testing
kubectl port-forward svc/express-app-default 3000:80

# Delete deployments
kubectl delete -f k8s/deployment-default.yml
kubectl delete -f k8s/service-default.yml
kubectl delete -f k8s/ingress-default.yml

# Stop minikube
minikube stop

# Delete minikube cluster
minikube delete
```

## Local Development

Run the Express server locally:

```bash
npm install
npm start
```

Server will run on `http://localhost:3000`

## Endpoints

- `GET /` - Returns welcome message
- `GET /health` - Health check endpoint

## Requirements

- Kubernetes cluster with nginx ingress controller installed
- kubectl configured to access your cluster
- Docker (for building images)
