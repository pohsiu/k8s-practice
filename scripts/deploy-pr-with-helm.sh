#!/bin/bash

# Deploy PR branch using Helm
# Usage: ./deploy-pr-with-helm.sh <pr-branch-name>
# Example: ./deploy-pr-with-helm.sh pr-dev-1

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

echo "🚀 Deploying PR branch: $PR_BRANCH using Helm..."

# Set Docker environment for minikube
eval $(minikube docker-env)

# Build Docker image
echo "📦 Building Docker image..."
docker build -t express-app:$PR_BRANCH .

# Create temporary values file with PR branch
TEMP_VALUES=$(mktemp)
cat > "$TEMP_VALUES" <<EOF
global:
  host: $MINIKUBE_IP.nip.io

prBranches:
  $PR_BRANCH:
    enabled: true
    image:
      repository: express-app
      tag: $PR_BRANCH
    replicaCount: 1
    service:
      type: ClusterIP
EOF

# Deploy using Helm
echo "🚀 Deploying to Kubernetes using Helm..."
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  -f helm/express-app/values-minikube.yaml \
  -f "$TEMP_VALUES" \
  --wait \
  --timeout 5m

# Cleanup temp file
rm -f "$TEMP_VALUES"

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/express-app-$PR_BRANCH --timeout=120s

echo "✅ Deployment complete!"
echo ""
echo "🧪 Test your deployment:"
echo "   curl -H 'x-multi-env: $PR_BRANCH' http://$MINIKUBE_IP.nip.io/"
echo ""
echo "📊 Check status:"
echo "   kubectl get pods -l branch=$PR_BRANCH"
echo "   kubectl get svc express-app-$PR_BRANCH"
echo "   kubectl get ingress express-app-$PR_BRANCH"

