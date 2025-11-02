#!/bin/bash

# Deploy to minikube script
# Usage: ./deploy-to-minikube.sh <pr-branch-name>
# Example: ./deploy-to-minikube.sh pr-dev-1

set -e

if [ -z "$1" ]; then
    echo "Error: PR branch name is required"
    echo "Usage: $0 <pr-branch-name>"
    echo "Example: $0 pr-dev-1"
    exit 1
fi

PR_BRANCH="$1"
MINIKUBE_IP=$(minikube ip)

if [ -z "$MINIKUBE_IP" ]; then
    echo "❌ Minikube is not running. Start it with: minikube start"
    exit 1
fi

echo "🚀 Deploying PR branch: $PR_BRANCH to minikube..."

# Set Docker environment for minikube
eval $(minikube docker-env)

# Build Docker image
echo "📦 Building Docker image..."
docker build -t express-app:$PR_BRANCH .

# Generate manifests from templates
echo "📝 Generating manifests from templates..."
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/deployment-template.yml > k8s/deployment-$PR_BRANCH.yml
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/service-template.yml > k8s/service-$PR_BRANCH.yml

# Deploy to Kubernetes
echo "🚀 Deploying to Kubernetes..."
kubectl apply -f k8s/deployment-$PR_BRANCH.yml
kubectl apply -f k8s/service-$PR_BRANCH.yml

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/express-app-$PR_BRANCH --timeout=60s

echo "✅ Deployment complete!"
echo ""
echo "📊 Check status:"
echo "   kubectl get pods -l branch=$PR_BRANCH"
echo "   kubectl get svc express-app-$PR_BRANCH"
echo ""
echo "🧪 Access your service via nginx proxy:"
echo "   curl -H 'x-multi-env: $PR_BRANCH' http://$MINIKUBE_IP.nip.io/"