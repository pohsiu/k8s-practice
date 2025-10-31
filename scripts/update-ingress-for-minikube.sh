#!/bin/bash

# Script to update ingress host to minikube IP
# Usage: ./update-ingress-for-minikube.sh <pr-branch-name>
# Example: ./update-ingress-for-minikube.sh pr-dev-1

if [ -z "$1" ]; then
    echo "Error: PR branch name is required"
    echo "Usage: $0 <pr-branch-name>"
    echo "Example: $0 pr-dev-1"
    exit 1
fi

PR_BRANCH="$1"
INGRESS_FILE="k8s/ingress-$PR_BRANCH.yml"

if [ ! -f "$INGRESS_FILE" ]; then
    echo "Error: Ingress file $INGRESS_FILE not found"
    exit 1
fi

# Get minikube IP
MINIKUBE_IP=$(minikube ip)

if [ -z "$MINIKUBE_IP" ]; then
    echo "Error: Could not get minikube IP. Is minikube running?"
    exit 1
fi

# Update ingress file
sed -i.bak "s/host: .*/host: $MINIKUBE_IP.nip.io/" "$INGRESS_FILE"
rm -f "${INGRESS_FILE}.bak"

echo "✅ Updated $INGRESS_FILE to use host: $MINIKUBE_IP.nip.io"
echo "   (nip.io is a DNS service that resolves *.nip.io to the IP)"