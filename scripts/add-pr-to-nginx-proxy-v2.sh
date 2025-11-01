#!/bin/bash

# Add a new PR branch to nginx proxy routing (Version 2 - Dynamic ConfigMap update)
# Usage: ./scripts/add-pr-to-nginx-proxy-v2.sh <pr-branch-name>

set -e

if [ -z "$1" ]; then
  echo "❌ Error: PR branch name is required"
  echo "Usage: $0 <pr-branch-name>"
  echo "Example: $0 pr-dev-3"
  exit 1
fi

PR_BRANCH=$1

echo "🚀 Adding PR branch: $PR_BRANCH to nginx proxy..."

# Create separate ConfigMap for this PR
echo "📝 Creating ConfigMap for $PR_BRANCH..."
kubectl create configmap nginx-proxy-$PR_BRANCH-config \
  --from-literal=upstream.conf="upstream $PR_BRANCH {
  server express-app-$PR_BRANCH:80;
}" \
  --from-literal=route.conf="if (\$http_x_multi_env = \"$PR_BRANCH\") {
  set \$upstream \"$PR_BRANCH\";
}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Label the ConfigMap
kubectl label configmap nginx-proxy-$PR_BRANCH-config app=nginx-proxy pr-branch=$PR_BRANCH --overwrite

echo "✅ ConfigMap created"

# Add volume and volumeMount to deployment
echo "🔧 Updating deployment to mount new ConfigMap..."

# Add new volume
kubectl patch deployment nginx-proxy --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/volumes/-", "value": {
    "name": "'$PR_BRANCH'-config",
    "configMap": {
      "name": "nginx-proxy-'$PR_BRANCH'-config",
      "optional": true
    }
  }}
]'

# Add volumeMounts for upstream
kubectl patch deployment nginx-proxy --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {
    "name": "'$PR_BRANCH'-config",
    "mountPath": "/etc/nginx/conf.d/upstreams/'$PR_BRANCH'.conf",
    "subPath": "upstream.conf"
  }}
]'

# Add volumeMounts for route
kubectl patch deployment nginx-proxy --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {
    "name": "'$PR_BRANCH'-config",
    "mountPath": "/etc/nginx/conf.d/routes/'$PR_BRANCH'.conf",
    "subPath": "route.conf"
  }}
]'

echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/nginx-proxy --timeout=90s

echo ""
echo "✅ PR branch $PR_BRANCH added successfully!"
echo ""
echo "🧪 Test command:"
echo "  curl -H \"x-multi-env: $PR_BRANCH\" http://192.168.49.2.nip.io/"
echo ""
echo "📋 To verify:"
echo "  kubectl get configmap nginx-proxy-$PR_BRANCH-config"
echo "  kubectl exec -it \$(kubectl get pod -l app=nginx-proxy -o name) -- cat /etc/nginx/conf.d/upstreams/$PR_BRANCH.conf"
echo ""
echo "💡 Note: Make sure service express-app-$PR_BRANCH exists!"

