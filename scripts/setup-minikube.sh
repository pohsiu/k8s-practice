#!/bin/bash

# Setup script for minikube practice

set -e

echo "🚀 Setting up minikube for k8s-practice..."

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ minikube is not installed. Please install it first:"
    echo "   brew install minikube  # macOS"
    echo "   # Or visit: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Start minikube if not running
if ! minikube status &> /dev/null; then
    echo "📦 Starting minikube..."
    minikube start
else
    echo "✅ Minikube is already running"
fi

# Enable ingress addon
echo "🔧 Enabling ingress addon..."
minikube addons enable ingress

# Wait for ingress to be ready
echo "⏳ Waiting for ingress controller to be ready..."
sleep 10

# Set up Docker environment for minikube
echo "🐳 Setting up Docker environment for minikube..."
eval $(minikube docker-env)

echo "✅ Minikube setup complete!"
echo ""
echo "📝 Next steps:"
echo ""
echo "Option 1: Deploy default service (no branch label):"
echo "   ./scripts/deploy-default-to-minikube.sh"
echo ""
echo "Option 2: Deploy PR branch service:"
echo "   ./scripts/deploy-to-minikube.sh pr-dev-1"
echo ""
echo "Or manually:"
echo "   1. Build Docker image: docker build -t express-app:latest ."
echo "   2. Deploy default: kubectl apply -f k8s/deployment-default.yml -f k8s/service-default.yml -f k8s/ingress-default.yml"
echo "   3. Get minikube IP: minikube ip"
echo "   4. Test: curl http://\$(minikube ip).nip.io/"