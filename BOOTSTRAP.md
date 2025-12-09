# Cluster Bootstrap Guide

This guide explains how to fully recreate the KubeStock Kubernetes cluster from scratch.

## Prerequisites

1. Kubernetes cluster created via Kubespray (see `infrastructure/kubespray-inventory/`)
2. AWS credentials configured with access to:
   - ECR (Elastic Container Registry)
   - AWS Secrets Manager
3. GitHub access to the kubestock-gitops repository

## Bootstrap Order

The cluster components must be installed in the following order:

### 1. ArgoCD Installation

Install ArgoCD using the official manifest:

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD (latest stable version)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Expose ArgoCD server (NodePort)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 32001}, {"port": 443, "nodePort": 30443}]}}'
```

### 2. ArgoCD Repository Secret

Create the Git repository secret for ArgoCD to access the gitops repository:

```bash
# Create repository secret (replace with your PAT token)
kubectl create secret generic kubestock-gitops-repo -n argocd \
  --from-literal=url=https://github.com/KubeStock-DevOps-project/kubestock-gitops.git \
  --from-literal=password=<GITHUB_PAT_TOKEN> \
  --from-literal=username=git \
  --from-literal=type=git
```

### 3. Apply ArgoCD ConfigMap

```bash
kubectl apply -f gitops/argocd/config/argocd-cm.yaml
```

### 4. External Secrets Operator Installation

Install External Secrets Operator via Helm:

```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Create namespace
kubectl create namespace external-secrets

# Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --version 0.9.19 \
  --wait
```

### 5. AWS Credentials for External Secrets

Create the bootstrap secret for External Secrets to access AWS Secrets Manager:

```bash
# Create AWS credentials secret (replace with your credentials)
kubectl create secret generic aws-external-secrets-creds -n external-secrets \
  --from-literal=access-key-id=<AWS_ACCESS_KEY_ID> \
  --from-literal=secret-access-key=<AWS_SECRET_ACCESS_KEY>
```

### 6. Apply ArgoCD Projects

```bash
kubectl apply -f gitops/argocd/projects/staging.yaml
kubectl apply -f gitops/argocd/projects/production.yaml
```

### 7. Deploy Applications via ArgoCD

```bash
# Deploy Kong Gateway
kubectl apply -f gitops/apps/kong.yaml

# Deploy Staging Application
kubectl apply -f gitops/apps/staging/kubestock-staging.yaml
```

### 8. ECR Image Pull Secret (Optional - if not using ExternalSecret)

For manual ECR authentication (credentials expire every 12 hours):

```bash
# Get ECR login token and create secret
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=478468757808

aws ecr get-login-password --region $AWS_REGION | \
kubectl create secret docker-registry ecr-cred \
  --docker-server=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region $AWS_REGION) \
  -n kubestock-staging
```

**Note**: Consider setting up an ECR credential helper or CronJob for automatic credential refresh.

## AWS Secrets Manager Secrets

The following secrets must exist in AWS Secrets Manager:

### kubestock/staging/db
```json
{
  "DB_HOST": "<RDS_ENDPOINT>",
  "DB_USER": "<DB_USERNAME>",
  "DB_PASSWORD": "<DB_PASSWORD>",
  "DB_NAME": "postgres"
}
```

### kubestock/staging/asgardeo
```json
{
  "ASGARDEO_ORG_NAME": "<ORG_NAME>",
  "ASGARDEO_BASE_URL": "<BASE_URL>",
  "ASGARDEO_SCIM2_URL": "<SCIM2_URL>",
  "ASGARDEO_SPA_CLIENT_ID": "<SPA_CLIENT_ID>",
  "ASGARDEO_M2M_CLIENT_ID": "<M2M_CLIENT_ID>",
  "ASGARDEO_M2M_CLIENT_SECRET": "<M2M_SECRET>",
  "ASGARDEO_GROUP_ID_ADMIN": "<ADMIN_GROUP_ID>",
  "ASGARDEO_GROUP_ID_SUPPLIER": "<SUPPLIER_GROUP_ID>",
  "ASGARDEO_GROUP_ID_WAREHOUSE_STAFF": "<WAREHOUSE_STAFF_GROUP_ID>",
  "ASGARDEO_TOKEN_URL": "<TOKEN_URL>",
  "ASGARDEO_JWKS_URL": "<JWKS_URL>",
  "ASGARDEO_ISSUER": "<ISSUER>"
}
```

## Verification

After bootstrap, verify the cluster state:

```bash
# Check all namespaces
kubectl get namespaces

# Check ArgoCD applications
kubectl get applications -n argocd

# Check all services are running
kubectl get pods -n kubestock-staging
kubectl get pods -n kong
kubectl get pods -n external-secrets

# Check external secrets are synced
kubectl get externalsecrets -n kubestock-staging
kubectl get clustersecretstores
```

## Directory Structure

```
gitops/
├── apps/                      # ArgoCD Application definitions
│   ├── kong.yaml             # Kong Gateway application
│   ├── staging/              # Staging applications
│   └── production/           # Production applications
├── argocd/                   # ArgoCD configuration
│   ├── config/               # ArgoCD ConfigMaps
│   └── projects/             # AppProject definitions
├── base/                     # Base Kustomize resources
│   ├── external-secrets/     # External Secrets operator resources
│   ├── kong/                 # Kong Gateway resources
│   ├── namespaces/           # Namespace definitions
│   └── services/             # Microservice deployments
└── overlays/                 # Environment-specific overlays
    ├── staging/              # Staging configurations
    └── production/           # Production configurations
```

## Troubleshooting

### ArgoCD not syncing
```bash
# Force refresh
argocd app get <app-name> --refresh

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-repo-server
```

### External Secrets not syncing
```bash
# Check ClusterSecretStore status
kubectl get clustersecretstore aws-secretsmanager -o yaml

# Check ExternalSecret status
kubectl get externalsecret -n kubestock-staging -o wide
```

### Image pull errors
```bash
# Check ECR credentials
kubectl get secret ecr-cred -n kubestock-staging -o yaml

# Describe pod for pull errors
kubectl describe pod <pod-name> -n kubestock-staging
```

---

## Production Setup (HTTPS with ALB + WAF)

### DNS Configuration (Namecheap → Route 53)

Since the domain is hosted at Namecheap, we need to delegate DNS to AWS Route 53:

#### Step 1: Create Route 53 Hosted Zone via Terraform

```bash
cd infrastructure/terraform/prod

# Apply just the dns module first
terraform apply -target=module.dns

# This will output the NS records
```

#### Step 2: Configure Namecheap DNS

1. Log into Namecheap
2. Go to Domain List → Manage → Domain
3. Under "Nameservers", select "Custom DNS"
4. Enter the 4 NS records from Terraform output, e.g.:
   - ns-1234.awsdns-12.org
   - ns-567.awsdns-34.net
   - ns-890.awsdns-56.co.uk
   - ns-2345.awsdns-78.com

**Note:** DNS propagation can take up to 48 hours, but usually completes within 30 minutes.

#### Step 3: Verify DNS Propagation

```bash
# Check if NS records are propagated
dig +short NS kubestock.dpiyumal.me

# Should show AWS nameservers
```

#### Step 4: Apply Full Infrastructure

Once DNS is propagated, apply the complete infrastructure:

```bash
cd infrastructure/terraform/prod
terraform apply
```

This creates:
- ACM certificate (auto-validated via Route 53)
- ALB with HTTPS listener
- WAF Web ACL with rate limiting
- A record pointing domain to ALB

### Data Flow

```
Internet → WAF → ALB (HTTPS:443) → Worker Nodes (port 30080) → Kong Gateway → Pods
```

### Verification

```bash
# Test HTTPS access
curl -I https://kubestock.dpiyumal.me/health

# Expected: 200 OK with SSL certificate info
```
