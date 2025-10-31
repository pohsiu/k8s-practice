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
│   ├── deployment-pr-dev-1.yml    # Example deployment for pr-dev-1
│   ├── service-pr-dev-1.yml       # Example service for pr-dev-1
│   ├── ingress-pr-dev-1.yml      # Example ingress for pr-dev-1
│   └── generate-pr-manifests.sh   # Script to generate manifests for new PR branches
└── README.md
```

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
# Request with matching header
curl -H "x-multi-env: pr-dev-1" http://your-actual-domain.com/

# Request without matching header (will return 404)
curl http://your-actual-domain.com/
```

## How It Works

1. **Deployment**: Each PR branch gets its own deployment with labels matching the PR branch name
2. **Service**: Service selects pods by matching labels (`app: express-app` and `branch: <pr-branch>`)
3. **Ingress**: Ingress uses nginx annotations to check the `x-multi-env` header:
   - If header matches the PR branch name (e.g., `x-multi-env: pr-dev-1`), traffic routes to that service
   - If header doesn't match, returns 404

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
