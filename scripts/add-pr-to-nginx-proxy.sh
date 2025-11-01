#!/bin/bash

# Add a new PR branch to nginx proxy routing
# Usage: ./scripts/add-pr-to-nginx-proxy.sh <pr-branch-name> [--skip-checks]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
  echo -e "${RED}❌ Error: PR branch name is required${NC}"
  echo "Usage: $0 <pr-branch-name> [--skip-checks]"
  echo "Example: $0 pr-dev-3"
  exit 1
fi

PR_BRANCH=$1
SKIP_CHECKS=false

if [ "$2" == "--skip-checks" ]; then
  SKIP_CHECKS=true
fi

echo "🚀 Adding PR branch: $PR_BRANCH to nginx proxy..."
echo ""

# Check if backend service exists
if [ "$SKIP_CHECKS" = false ]; then
  echo "🔍 Checking prerequisites..."
  
  if kubectl get service express-app-$PR_BRANCH &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Backend service express-app-$PR_BRANCH exists"
  else
    echo -e "  ${RED}✗${NC} Backend service express-app-$PR_BRANCH NOT found"
    echo ""
    echo -e "${YELLOW}⚠️  Warning: Backend service doesn't exist yet${NC}"
    echo ""
    echo "Nginx will fail to start if the service doesn't exist when it tries to load the configuration."
    echo ""
    echo "To deploy the backend service first:"
    echo "  ./scripts/deploy-to-minikube.sh $PR_BRANCH"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Operation cancelled."
      exit 1
    fi
  fi
  echo ""
fi

# Generate PR-specific ConfigMap from template
echo "📝 Generating ConfigMap for $PR_BRANCH..."
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/nginx-proxy/pr-template.yml > k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# Apply the ConfigMap
echo "✅ Creating ConfigMap..."
kubectl apply -f k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

echo "💾 Saved to k8s/nginx-proxy/pr-$PR_BRANCH-config.yml"

# Check if deployment.yml already has this PR mounted
echo ""
echo "🔍 Checking if deployment.yml needs update..."
DEPLOYMENT_FILE="k8s/nginx-proxy/deployment.yml"

if grep -q "name: $PR_BRANCH-config" "$DEPLOYMENT_FILE"; then
  echo -e "  ${GREEN}✓${NC} deployment.yml already has $PR_BRANCH-config mounted"
else
  echo -e "  ${YELLOW}⚠${NC} Updating deployment.yml to mount $PR_BRANCH ConfigMap..."
  
  # Backup deployment.yml
  cp "$DEPLOYMENT_FILE" "$DEPLOYMENT_FILE.backup"
  
  # Find the line number where we need to insert volumeMounts
  # Look for the last route config volumeMount line
  LAST_ROUTE_LINE=$(grep -n "subPath: route.conf" "$DEPLOYMENT_FILE" | tail -1 | cut -d: -f1)
  
  if [ -z "$LAST_ROUTE_LINE" ]; then
    echo -e "  ${RED}✗${NC} Could not find insertion point in deployment.yml"
    echo "  Please manually add the following to deployment.yml:"
    echo ""
    echo "    # Mount $PR_BRANCH upstream config"
    echo "    - name: $PR_BRANCH-config"
    echo "      mountPath: /etc/nginx/conf.d/upstreams/$PR_BRANCH.conf"
    echo "      subPath: upstream.conf"
    echo "    # Mount $PR_BRANCH route config"
    echo "    - name: $PR_BRANCH-config"
    echo "      mountPath: /etc/nginx/conf.d/routes/$PR_BRANCH.conf"
    echo "      subPath: route.conf"
    echo ""
  else
    # Insert volumeMounts after the last route config
    VOLUME_MOUNT_TEXT="        # Mount $PR_BRANCH upstream config\n        - name: $PR_BRANCH-config\n          mountPath: /etc/nginx/conf.d/upstreams/$PR_BRANCH.conf\n          subPath: upstream.conf\n        # Mount $PR_BRANCH route config\n        - name: $PR_BRANCH-config\n          mountPath: /etc/nginx/conf.d/routes/$PR_BRANCH.conf\n          subPath: route.conf"
    
    # Use sed to insert after the line
    sed -i.tmp "${LAST_ROUTE_LINE}a\\
        # Mount $PR_BRANCH upstream config\\
        - name: $PR_BRANCH-config\\
          mountPath: /etc/nginx/conf.d/upstreams/$PR_BRANCH.conf\\
          subPath: upstream.conf\\
        # Mount $PR_BRANCH route config\\
        - name: $PR_BRANCH-config\\
          mountPath: /etc/nginx/conf.d/routes/$PR_BRANCH.conf\\
          subPath: route.conf
" "$DEPLOYMENT_FILE"
    
    # Find the last volume definition line
    LAST_VOLUME_LINE=$(grep -n "optional: true" "$DEPLOYMENT_FILE" | tail -1 | cut -d: -f1)
    
    # Insert volume definition after the last volume
    sed -i.tmp "${LAST_VOLUME_LINE}a\\
      # ConfigMap for $PR_BRANCH\\
      - name: $PR_BRANCH-config\\
        configMap:\\
          name: nginx-proxy-$PR_BRANCH-config\\
          optional: true
" "$DEPLOYMENT_FILE"
    
    # Remove temporary file
    rm -f "$DEPLOYMENT_FILE.tmp"
    
    echo -e "  ${GREEN}✓${NC} Updated deployment.yml with $PR_BRANCH mounts"
  fi
fi

# Apply updated deployment
echo ""
echo "📦 Applying updated deployment..."
kubectl apply -f "$DEPLOYMENT_FILE"

# Restart nginx proxy to reload configuration
echo ""
echo "🔄 Restarting nginx proxy to load new configuration..."
kubectl rollout restart deployment/nginx-proxy

echo "⏳ Waiting for deployment to be ready..."
if kubectl rollout status deployment/nginx-proxy --timeout=90s; then
  echo -e "${GREEN}✅ PR branch $PR_BRANCH added successfully!${NC}"
else
  echo -e "${RED}❌ Deployment failed${NC}"
  echo ""
  echo "Check logs with:"
  echo "  kubectl logs -l app=nginx-proxy --tail=50"
  exit 1
fi

echo ""
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ConfigMap has been mounted and is available via include directives"
echo ""
echo "🧪 Test command:"
echo "  curl -H \"x-multi-env: $PR_BRANCH\" http://$MINIKUBE_IP.nip.io/"
echo ""
echo "📋 Verify nginx config:"
echo "  kubectl exec -it \$(kubectl get pod -l app=nginx-proxy -o name) -- cat /etc/nginx/conf.d/upstreams/$PR_BRANCH.conf"
echo "  kubectl exec -it \$(kubectl get pod -l app=nginx-proxy -o name) -- cat /etc/nginx/conf.d/routes/$PR_BRANCH.conf"
echo ""
echo "💡 Tip: A backup of deployment.yml was created as deployment.yml.backup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

