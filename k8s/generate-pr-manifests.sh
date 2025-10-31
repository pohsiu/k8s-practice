#!/bin/bash

# Script to generate Kubernetes manifests for a PR branch
# Usage: ./generate-pr-manifests.sh <pr-branch-name>
# Example: ./generate-pr-manifests.sh pr-dev-1

if [ -z "$1" ]; then
  echo "Error: PR branch name is required"
  echo "Usage: $0 <pr-branch-name>"
  echo "Example: $0 pr-dev-1"
  exit 1
fi

PR_BRANCH="$1"

echo "Generating Kubernetes manifests for PR branch: $PR_BRANCH"

# Generate deployment
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" deployment-template.yml > "deployment-$PR_BRANCH.yml"

# Generate service
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" service-template.yml > "service-$PR_BRANCH.yml"

# Generate ingress
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" ingress-template.yml > "ingress-$PR_BRANCH.yml"

echo "Manifests generated:"
echo "  - deployment-$PR_BRANCH.yml"
echo "  - service-$PR_BRANCH.yml"
echo "  - ingress-$PR_BRANCH.yml"

