#!/bin/bash

# Deploy custom nginx reverse proxy for multi-PR routing
# This script deploys a custom nginx service that routes traffic based on x-multi-env header
# Usage: ./deploy-nginx-proxy.sh [--skip-checks]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get minikube IP
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")

echo "🚀 Deploying custom nginx reverse proxy..."
echo ""

# Check if skip-checks flag is set
SKIP_CHECKS=false
if [ "$1" == "--skip-checks" ]; then
    SKIP_CHECKS=true
    echo "⚠️  Skipping prerequisite checks (--skip-checks flag provided)"
    echo ""
fi

# Function to check if a resource exists
check_resource() {
    local resource_type=$1
    local resource_name=$2
    if kubectl get $resource_type $resource_name &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $resource_type/$resource_name exists"
        return 0
    else
        echo -e "  ${RED}✗${NC} $resource_type/$resource_name NOT found"
        return 1
    fi
}

# Prerequisites check
if [ "$SKIP_CHECKS" = false ]; then
    echo "🔍 Checking prerequisites..."
    echo ""
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Is minikube running?${NC}"
        echo "   Try: minikube start"
        exit 1
    fi
    
    echo "📋 Checking backend services..."
    MISSING_SERVICES=0
    
    # Check for default service
    if ! check_resource "service" "express-app-default"; then
        MISSING_SERVICES=$((MISSING_SERVICES + 1))
    fi
    
    # Check for PR services configured in PR ConfigMaps
    for pr_config in k8s/nginx-proxy/pr-dev-*-config.yml; do
        if [ -f "$pr_config" ]; then
            # Extract PR branch name from filename
            pr_branch=$(basename "$pr_config" | sed 's/pr-\(.*\)-config\.yml/\1/')
            pr_branch="pr-$pr_branch"
            if ! check_resource "service" "express-app-$pr_branch"; then
                MISSING_SERVICES=$((MISSING_SERVICES + 1))
            fi
        fi
    done
    
    echo ""
    
    if [ $MISSING_SERVICES -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Warning: $MISSING_SERVICES backend service(s) not found${NC}"
        echo ""
        echo "Nginx will fail to start if upstream services don't exist."
        echo ""
        echo "To deploy backend services first:"
        echo "  ./scripts/deploy-default-to-minikube.sh          # Deploy default service"
        echo "  ./scripts/deploy-to-minikube.sh pr-dev-1         # Deploy PR service"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled."
            exit 1
        fi
        echo ""
    else
        echo -e "${GREEN}✅ All backend services are ready!${NC}"
        echo ""
    fi
fi

# Step 1: Apply ConfigMap with nginx configuration
echo "📝 Step 1/5: Creating nginx proxy ConfigMap..."
kubectl apply -f k8s/nginx-proxy/configmap.yml

# Step 2: Apply PR ConfigMaps
echo ""
echo "📝 Step 2/5: Creating PR ConfigMaps..."
for pr_config in k8s/nginx-proxy/pr-dev-*-config.yml; do
    if [ -f "$pr_config" ]; then
        echo "  → Applying $(basename $pr_config)"
        kubectl apply -f "$pr_config"
    fi
done

# Step 3: Deploy nginx proxy
echo ""
echo "🔧 Step 3/5: Deploying nginx proxy..."
kubectl apply -f k8s/nginx-proxy/deployment.yml

# Step 4: Create service
echo ""
echo "🌐 Step 4/5: Creating nginx proxy Service..."
kubectl apply -f k8s/nginx-proxy/service.yml

# Step 5: Create ingress
echo ""
echo "🔀 Step 5/5: Creating Ingress..."
kubectl apply -f k8s/nginx-proxy/ingress.yml

# Wait for deployment to be ready
echo ""
echo "⏳ Waiting for nginx proxy to be ready..."
if kubectl rollout status deployment/nginx-proxy --timeout=90s; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
else
    echo -e "${RED}❌ Deployment failed or timed out${NC}"
    echo ""
    echo "Check logs with:"
    echo "  kubectl logs -l app=nginx-proxy --tail=50"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Nginx proxy deployed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Current status:"
kubectl get pods -l app=nginx-proxy
echo ""
kubectl get svc nginx-proxy
echo ""
kubectl get ingress nginx-proxy-ingress
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Test commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  # Health check:"
echo "  curl http://$MINIKUBE_IP.nip.io/nginx-health"
echo ""

# Show test commands for each PR
for pr_config in k8s/nginx-proxy/pr-dev-*-config.yml; do
    if [ -f "$pr_config" ]; then
        pr_branch=$(basename "$pr_config" | sed 's/\(pr-dev-[0-9]*\)-config\.yml/\1/')
        echo "  # Route to $pr_branch:"
        echo "  curl -H \"x-multi-env: $pr_branch\" http://$MINIKUBE_IP.nip.io/"
        echo ""
    fi
done

echo "  # Default routing (no header):"
echo "  curl http://$MINIKUBE_IP.nip.io/"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 Documentation:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  README:      k8s/nginx-proxy/README.md"
echo "  Quick Start: k8s/nginx-proxy/QUICKSTART.md"
echo "  Usage Guide: k8s/nginx-proxy/USAGE.md"
echo ""

