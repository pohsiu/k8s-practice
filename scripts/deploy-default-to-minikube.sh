#!/bin/bash

# Deploy default service to minikube script
# Usage: ./deploy-default-to-minikube.sh

set -e

MINIKUBE_IP=$(minikube ip)

if [ -z "$MINIKUBE_IP" ]; then
    echo "❌ Minikube is not running. Start it with: minikube start"
    exit 1
fi

echo "🚀 Deploying default service to minikube..."

# Set Docker environment for minikube
eval $(minikube docker-env)

# Build Docker image
echo "📦 Building Docker image for default service..."
docker build -t express-app:latest .

# Update ingress host
echo "🔧 Updating default ingress for minikube..."
sed -i.bak "s/host: .*/host: $MINIKUBE_IP.nip.io/" k8s/ingress-default.yml
rm -f k8s/ingress-default.yml.bak

echo "✅ Updated k8s/ingress-default.yml to use host: $MINIKUBE_IP.nip.io"

# Deploy to Kubernetes
echo "🚀 Deploying default service to Kubernetes..."
kubectl apply -f k8s/deployment-default.yml

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/express-app-default --timeout=60s

echo "✅ Default service deployment complete!"
echo ""
echo "🧪 Test your deployment:"
echo "   curl http://$MINIKUBE_IP.nip.io/"
echo "   curl http://$MINIKUBE_IP.nip.io/health"
echo ""
echo "📊 Check status:"
echo "   kubectl get pods -l type=default"
echo "   kubectl get svc express-app-default"
echo "   kubectl get ingress express-app-default"
echo ""
echo "💡 Note: Requests without 'x-multi-env' header will route to this default service"

