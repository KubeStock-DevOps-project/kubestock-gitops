# Quick Bootstrap Reference

**For detailed information, see [BOOTSTRAP_READINESS_REPORT.md](BOOTSTRAP_READINESS_REPORT.md)**

## TL;DR - Bootstrap a New Cluster

```bash
# 1. Run the complete bootstrap script
cd gitops
./bootstrap-complete.sh

# The script will:
# - Install ArgoCD v2.9.3
# - Create repository and AWS secrets
# - Install External Secrets Operator
# - Deploy all infrastructure and applications via ArgoCD
```

## Prerequisites

✅ **Required:**
- Kubernetes cluster (v1.25+)
- `kubectl` configured with cluster-admin access
- AWS CLI configured
- `helm` (v3+)
- `jq` installed

✅ **Credentials Needed:**
- GitHub Personal Access Token (repo access)
- AWS Access Key ID (for External Secrets)
- AWS Secret Access Key (for External Secrets)

## Bootstrap Scripts

| Script | Purpose | Prerequisites |
|--------|---------|---------------|
| `bootstrap-complete.sh` | **RECOMMENDED** - Full bootstrap including ArgoCD | Kubernetes cluster, kubectl, AWS CLI, helm |
| `bootstrap.sh` | Partial bootstrap (assumes ArgoCD installed) | ArgoCD already running |

## Manual Bootstrap Steps

If you prefer manual installation, follow these steps in order:

### 1. Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Expose ArgoCD
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 32001}, {"port": 443, "nodePort": 30443}]}}'

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Create ArgoCD Repository Secret
```bash
kubectl create secret generic kubestock-gitops-repo -n argocd \
  --from-literal=url=https://github.com/KubeStock-DevOps-project/kubestock-gitops.git \
  --from-literal=password=<GITHUB_PAT_TOKEN> \
  --from-literal=username=git \
  --from-literal=type=git
```

### 3. Apply ArgoCD Configuration
```bash
kubectl apply -f gitops/argocd/config/argocd-cm.yaml
```

### 4. Install External Secrets Operator
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
kubectl create namespace external-secrets
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --version 0.9.19 \
  --wait
```

### 5. Create AWS Credentials Secret
```bash
kubectl create secret generic aws-external-secrets-creds -n external-secrets \
  --from-literal=access-key-id=<AWS_ACCESS_KEY_ID> \
  --from-literal=secret-access-key=<AWS_SECRET_ACCESS_KEY>
```

### 6. Apply ArgoCD Projects
```bash
kubectl apply -f gitops/argocd/projects/infrastructure.yaml
kubectl apply -f gitops/argocd/projects/production.yaml
kubectl apply -f gitops/argocd/projects/staging.yaml
```

### 7. Deploy Applications
```bash
# Critical apps first
kubectl apply -f gitops/apps/external-secrets.yaml
kubectl apply -f gitops/apps/shared-rbac.yaml

# Wait a moment
sleep 10

# All infrastructure apps
kubectl apply -f gitops/apps/*.yaml

# Environment-specific apps
kubectl apply -f gitops/apps/production/*.yaml
kubectl apply -f gitops/apps/staging/*.yaml
```

## Verification

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check application health
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# Check ClusterSecretStore
kubectl get clustersecretstore aws-secretsmanager

# Check all pods
kubectl get pods -A

# Check external secrets
kubectl get externalsecrets -A
```

## Common Issues

### ArgoCD Applications Not Syncing
```bash
# Check repository connection
kubectl get secret kubestock-gitops-repo -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Manual sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {"revision": "HEAD"}}}'
```

### External Secrets Not Syncing
```bash
# Check AWS credentials
kubectl get secret aws-external-secrets-creds -n external-secrets

# Check ESO logs
kubectl logs -n external-secrets deployment/external-secrets

# Check ClusterSecretStore
kubectl describe clustersecretstore aws-secretsmanager
```

### Missing Dependencies
```bash
# Install jq (Ubuntu/Debian)
sudo apt-get install jq

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## ArgoCD Access

**URL:** `http://<node-ip>:32001`  
**Username:** `admin`  
**Password:** Run to get:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Infrastructure Components Deployed

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| ArgoCD | argocd | GitOps CD platform |
| External Secrets Operator | external-secrets | AWS Secrets Manager sync |
| Istio (Base + Istiod) | istio-system | Service mesh |
| Kong | kong, kong-staging | API Gateway |
| Cluster Autoscaler | cluster-autoscaler | Auto-scaling |
| EBS CSI Driver | kube-system | AWS EBS volumes |
| Metrics Server | kube-system | Resource metrics |
| Reloader | reloader | ConfigMap/Secret reload |
| Observability Stack | observability-production | Prometheus, Loki, Grafana |

## Expected Timeline

- **ArgoCD Installation:** 2-3 minutes
- **External Secrets Operator:** 1-2 minutes
- **Infrastructure Apps Sync:** 5-10 minutes
- **Total Bootstrap Time:** 10-15 minutes

## Next Steps After Bootstrap

1. ✅ Verify all applications are synced and healthy
2. ✅ Access ArgoCD UI to monitor deployments
3. ✅ Check application logs for any issues
4. ✅ Verify secrets are syncing from AWS Secrets Manager
5. ✅ Test application endpoints through Kong Gateway
6. ✅ Review observability dashboards (Grafana)

## Documentation

- **Full Report:** [BOOTSTRAP_READINESS_REPORT.md](BOOTSTRAP_READINESS_REPORT.md)
- **Detailed Guide:** [BOOTSTRAP.md](BOOTSTRAP.md)
- **RBAC Details:** [CLUSTER_RBAC.md](CLUSTER_RBAC.md)
- **Secrets Management:** [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)
- **Observability:** [OBSERVABILITY_SETUP.md](OBSERVABILITY_SETUP.md)

## Support

If you encounter issues:
1. Check the logs of the failing component
2. Verify prerequisites are met
3. Review the detailed bootstrap report
4. Check ArgoCD application status and events
