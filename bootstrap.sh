#!/bin/bash
# =============================================================================
# KubeStock Cluster Bootstrap Script
# =============================================================================
# Bootstraps a fresh Kubernetes cluster with KubeStock infrastructure.
#
# Prerequisites:
# - kubectl configured with cluster access
# - AWS CLI configured
# - ArgoCD installed
# - External Secrets Operator installed (Helm)
#
# Usage: ./bootstrap.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    KubeStock Cluster Bootstrap                                ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"

# Step 1: Verify Prerequisites
echo -e "\n[1/4] Verifying prerequisites..."
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: kubectl not configured"; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || { echo "ERROR: AWS CLI not configured"; exit 1; }
echo "✓ Prerequisites verified"

# Step 2: Create ESO Bootstrap Secret
echo -e "\n[2/4] Setting up ESO bootstrap credentials..."
kubectl create namespace external-secrets 2>/dev/null || true

EXISTING_KEYS=$(aws iam list-access-keys --user-name kubestock-external-secrets --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_KEYS" ]; then
  echo "Creating new access key..."
  ACCESS_KEY_JSON=$(aws iam create-access-key --user-name kubestock-external-secrets)
  ACCESS_KEY_ID=$(echo $ACCESS_KEY_JSON | jq -r '.AccessKey.AccessKeyId')
  SECRET_ACCESS_KEY=$(echo $ACCESS_KEY_JSON | jq -r '.AccessKey.SecretAccessKey')
else
  echo "Access key exists: $EXISTING_KEYS"
  read -p "Enter AWS_ACCESS_KEY_ID: " ACCESS_KEY_ID
  read -s -p "Enter AWS_SECRET_ACCESS_KEY: " SECRET_ACCESS_KEY
  echo ""
fi

kubectl delete secret aws-external-secrets-creds -n external-secrets 2>/dev/null || true
kubectl create secret generic aws-external-secrets-creds \
  --from-literal=access-key-id="$ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$SECRET_ACCESS_KEY" \
  --namespace=external-secrets
echo "✓ Bootstrap secret created"

# Step 3: Apply ArgoCD Apps (in dependency order)
echo -e "\n[3/4] Applying ArgoCD applications..."

# First: External Secrets Operator (Helm) - installs CRDs and operator
echo "  → Applying External Secrets Operator..."
kubectl apply -f "$SCRIPT_DIR/apps/external-secrets-operator.yaml"

# Wait for operator to be ready before applying config that uses CRDs
echo "  → Waiting for External Secrets CRDs..."
sleep 15
kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=120s 2>/dev/null || echo "  (CRDs may still be syncing...)"

# Second: External Secrets Config (ClusterSecretStore, ECR generators)
echo "  → Applying External Secrets Config..."
kubectl apply -f "$SCRIPT_DIR/apps/external-secrets.yaml"
kubectl apply -f "$SCRIPT_DIR/apps/shared-rbac.yaml"
sleep 5

# Apply all other apps
for f in "$SCRIPT_DIR/apps/"*.yaml; do
  [ -f "$f" ] && kubectl apply -f "$f" 2>/dev/null || true
done
for f in "$SCRIPT_DIR/apps/production/"*.yaml; do
  [ -f "$f" ] && kubectl apply -f "$f" 2>/dev/null || true
done
for f in "$SCRIPT_DIR/apps/staging/"*.yaml; do
  [ -f "$f" ] && kubectl apply -f "$f" 2>/dev/null || true
done
echo "✓ ArgoCD apps applied"

# Step 4: Verify
echo -e "\n[4/4] Verifying deployment..."
sleep 10
kubectl get clustersecretstore aws-secretsmanager 2>/dev/null || echo "ClusterSecretStore pending..."
kubectl get applications -n argocd

echo -e "\n╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Bootstrap Complete!                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo "All secrets sync automatically from AWS Secrets Manager via ClusterSecretStore."
