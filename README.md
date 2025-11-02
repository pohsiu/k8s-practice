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
├── server.js                # Express application entry point
├── Dockerfile               # Docker image definition
├── package.json             # Node.js dependencies and scripts
├── k8s/
│   ├── deployment-template.yml      # Template for PR-based deployments
│   ├── service-template.yml         # Template for PR-based services
│   ├── deployment-default.yml       # Deployment for default service
│   ├── service-default.yml          # Service for default deployment
│   ├── deployment-pr-dev-1.yml      # [Example] Generated deployment for pr-dev-1
│   ├── service-pr-dev-1.yml         # [Example] Generated service for pr-dev-1
│   └── nginx-proxy/
│       ├── configmap.yml            # Main nginx config (imports upstreams/routes)
│       ├── deployment.yml           # Nginx proxy Deployment spec
│       ├── service.yml              # Service exposing nginx proxy
│       ├── ingress.yml              # Ingress resource for nginx proxy
│       ├── pr-template.yml      # [Example] PR config map snippet for nginx
│       └── pr-[branch-name]-config.yml          # [Generated] ConfigMaps for each PR branch
├── scripts/
│   ├── setup-minikube.sh                 # Minikube setup, enable addons
│   ├── deploy-default-to-minikube.sh     # Deploy default service to minikube
│   ├── deploy-to-minikube.sh             # Deploy PR branch: build, manifest, kubectl apply
│   ├── deploy-nginx-proxy.sh             # Deploy/rollout the nginx proxy
│   ├── add-pr-to-nginx-proxy.sh          # Add a PR branch config to nginx proxy and reload
│   └── add-pr-to-nginx-proxy-v2.sh       # Alternative script for PR→nginx update
└── README.md
```

*Notes*:
- All `*-pr-*` and `*-config.yml` files are generated per branch, not tracked directly.
- The `scripts/` directory includes all cluster and deployment automation.
- `k8s/nginx-proxy/` includes all infrastructure for routing requests based on PR environments.

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

When a PR is created (e.g., branch `pr-dev-1`), generate the Kubernetes manifests from templates:

```bash
# Generate deployment and service manifests
sed "s/{{PR_BRANCH}}/pr-dev-1/g" k8s/deployment-template.yml > k8s/deployment-pr-dev-1.yml
sed "s/{{PR_BRANCH}}/pr-dev-1/g" k8s/service-template.yml > k8s/service-pr-dev-1.yml
```

This will create:
- `deployment-pr-dev-1.yml`
- `service-pr-dev-1.yml`

### 3. Deploy to Kubernetes

Apply the manifests to your Kubernetes cluster:

```bash
kubectl apply -f k8s/deployment-pr-dev-1.yml
kubectl apply -f k8s/service-pr-dev-1.yml
```

### 4. Attach to nginx proxy
To route PR-based traffic via the custom nginx proxy, you need to register each PR branch with the nginx proxy system. This lets nginx dynamically pick up routing rules and upstreams for your PR.

You can do this automatically using the **add-pr-to-nginx-proxy** script:

```bash
# Run this after deploying the PR's deployment and service
./scripts/add-pr-to-nginx-proxy-v2.sh pr-dev-1
```

What this does:
- **Creates a ConfigMap**: Defines an nginx upstream for your PR service and a routing rule that checks for the `x-multi-env: pr-dev-1` header.
- **Labels the ConfigMap**: Allows easy management of PR configs.
- **Mounts the ConfigMap in the nginx proxy deployment**: The custom proxy picks up the new routing info without requiring a proxy restart.

_Note_: You must have already deployed the nginx proxy (`deploy-nginx-proxy.sh`), and the target PR branch service (`express-app-pr-dev-1`) must exist in your cluster.

If you add more PR branches, repeat the steps for each one (replace `pr-dev-1` as appropriate).


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
3. **Ingress**: Ingress uses nginx canary annotations for header-based routing (no server-snippet required):
   - Default ingress acts as the base
   - PR branch ingresses use canary annotations: `canary: "true"`, `canary-weight: "100"`, `canary-by-header: "x-multi-env"`
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
   # This script will build the image, generate manifests, and deploy
   ./scripts/deploy-to-minikube.sh pr-dev-1
   
   # Add the PR to nginx proxy for header-based routing
   ./scripts/add-pr-to-nginx-proxy.sh pr-dev-1
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
   
   # Generate manifests from templates
   sed "s/{{PR_BRANCH}}/pr-dev-1/g" k8s/deployment-template.yml > k8s/deployment-pr-dev-1.yml
   sed "s/{{PR_BRANCH}}/pr-dev-1/g" k8s/service-template.yml > k8s/service-pr-dev-1.yml
   
   # Deploy
   kubectl apply -f k8s/deployment-pr-dev-1.yml
   kubectl apply -f k8s/service-pr-dev-1.yml
   
   # Add to nginx proxy
   ./scripts/add-pr-to-nginx-proxy.sh pr-dev-1
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

## GitHub Actions CI/CD

This project includes GitHub Actions workflows for automated PR deployments:

### Workflows

1. **`pr-created.yaml`** - Automatically deploys PR environments when a PR is opened/updated
2. **`pr-close.yaml`** - Cleans up resources when a PR is closed
3. **`deploy.yaml`** - Deploys to the main environment on push to main branch

### Requirements for GitHub Actions

To use the PR deployment workflow, you need:

1. **Kubernetes Cluster Access**: Configure kubectl access in GitHub Actions
   - Add kubeconfig as a GitHub secret
   - Or use cloud provider actions (e.g., `azure/k8s-set-context`, `aws-actions/configure-aws-credentials`)

2. **Minikube Setup** (if using minikube in CI):
   ```yaml
   - name: Start minikube
     uses: medyagh/setup-minikube@master
   ```

3. **Container Registry** (for production):
   - Configure registry credentials
   - Update image references to use your registry

### Note on `deploy-to-minikube.sh`

The `deploy-to-minikube.sh` script is designed for local minikube environments. When using it in GitHub Actions:
- Ensure minikube is started first
- The script will automatically:
  - Build the Docker image using minikube's Docker daemon
  - Generate Kubernetes manifests from templates
  - Deploy to the cluster

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
