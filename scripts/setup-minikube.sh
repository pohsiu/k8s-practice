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
echo "   1. Build Docker image: docker build -t express-app:pr-dev-1 ."
echo "   2. Update ingress host in k8s/ingress-pr-dev-1.yml to use minikube IP"
echo "   3. Deploy: kubectl apply -f k8s/deployment-pr-dev-1.yml -f k8s/service-pr-dev-1.yml -f k8s/ingress-pr-dev-1.yml"
echo "   4. Get minikube IP: minikube ip"
echo "   5. Test: curl -H 'x-multi-env: pr-dev-1' http://\$(minikube ip)/"