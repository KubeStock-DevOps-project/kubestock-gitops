# KubeStock GitOps

GitOps repository for KubeStock Kubernetes deployments using ArgoCD.

## Directory Structure

```
gitops/
├── README.md
├── argocd/                    # ArgoCD configuration
│   ├── projects/              # AppProject definitions
│   │   ├── staging.yaml
│   │   └── production.yaml
│   └── config/                # ArgoCD ConfigMaps
│       └── argocd-cm.yaml
├── apps/                      # ArgoCD Application definitions (skeleton)
│   ├── staging/               # Staging environment apps
│   └── production/            # Production environment apps
├── base/                      # Base Kustomize manifests
│   ├── namespaces/
│   ├── postgres/              # PostgreSQL StatefulSet
│   └── services/              # Microservice deployments
│       ├── ms-product/
│       ├── ms-inventory/
│       ├── ms-supplier/
│       ├── ms-order-management/
│       ├── ms-identity/
│       └── frontend/
└── overlays/                  # Environment-specific overlays
    ├── staging/               # Staging overlay
    └── production/            # Production overlay (blue-green)
        ├── blue/
        └── green/
```

## Services

- **ms-product** - Product Catalog Service
- **ms-inventory** - Inventory Management Service
- **ms-supplier** - Supplier Management Service
- **ms-order-management** - Order Management Service
- **ms-identity** - Identity/User Management Service
- **kubestock-frontend** - React Frontend Application

## Deployment Workflow

### Stage 4: Deploy to Staging
1. Push changes to `gitops/overlays/staging/`
2. ArgoCD syncs changes to `kubestock-staging` namespace
3. Run smoke tests via CI/CD pipeline

### Stage 5: Manual Approval for Production
1. Staging tests pass
2. Manual approval in GitHub Actions / ArgoCD UI
3. Promote to production

### Stage 6: Production Deployment (Blue-Green)
1. Deploy to inactive color (e.g., green)
2. Run smoke tests on green
3. Switch traffic from blue to green via Service selector
4. Keep blue as rollback target

## Access ArgoCD UI

From your local machine, SSH tunnel through bastion to the NLB:

```bash
# Get NLB DNS from Terraform output
cd infrastructure/terraform/prod
terraform output -raw nlb_dns_name

# SSH tunnel to ArgoCD UI (port 8443 on NLB routes to NodePort 30443)
ssh -L 8443:<NLB_DNS>:8443 -i ~/.ssh/kubestock-key ubuntu@<BASTION_IP>

# Access UI at https://localhost:8443 in your browser
# Username: admin
# Password: 1qK4StYU6Fs0W2l3
```

**Or use the tunnel script:**
```bash
# Edit infrastructure/scripts/ssh-tunnels/tunnel-argocd.sh with your NLB DNS and bastion IP
./infrastructure/scripts/ssh-tunnels/tunnel-argocd.sh
```

To retrieve admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Access Staging Environment

From your local machine, SSH tunnel through bastion to the NLB:

```bash
# Get NLB DNS from Terraform output
cd infrastructure/terraform/prod
terraform output -raw nlb_dns_name

# SSH tunnel for HTTP (port 80 on NLB routes to NodePort 30080)
ssh -L 5173:<NLB_DNS>:80 -i ~/.ssh/kubestock-key ubuntu@<BASTION_IP>

# OR for HTTPS (port 443 on NLB routes to NodePort 30444)
ssh -L 5173:<NLB_DNS>:443 -i ~/.ssh/kubestock-key ubuntu@<BASTION_IP>

# Access staging frontend at http://localhost:5173 or https://localhost:5173
# All API requests will route through Kong Gateway to backend services
```

**Or use the tunnel scripts:**
```bash
# Edit infrastructure/scripts/ssh-tunnels/tunnel-staging-frontend.sh with your NLB DNS and bastion IP
./infrastructure/scripts/ssh-tunnels/tunnel-staging-frontend.sh         # For HTTP
./infrastructure/scripts/ssh-tunnels/tunnel-staging-frontend-https.sh  # For HTTPS
```

### Via kubectl port-forward (alternative method)

Forward frontend to localhost:
```bash
kubectl port-forward -n kubestock-staging svc/kubestock-frontend 8080:80
# Access at http://localhost:8080
```

Forward individual microservices:
```bash
# Product service
kubectl port-forward -n kubestock-staging svc/ms-product 3002:3002
# Inventory service
kubectl port-forward -n kubestock-staging svc/ms-inventory 3003:3003
# Supplier service
kubectl port-forward -n kubestock-staging svc/ms-supplier 3004:3004
# Order management service
kubectl port-forward -n kubestock-staging svc/ms-order-management 3005:3005
# Identity service
kubectl port-forward -n kubestack-staging svc/ms-identity 3006:3006
```

### Via kubectl exec (from bastion)

Test services from within the cluster:
```bash
# Test frontend
kubectl exec -n kubestock-staging deploy/kubestock-frontend -- curl -s http://localhost:80

# Test backend services
kubectl exec -n kubestock-staging deploy/ms-product -- curl -s http://localhost:3002/health
kubectl exec -n kubestock-staging deploy/ms-inventory -- curl -s http://localhost:3003/health
kubectl exec -n kubestock-staging deploy/ms-supplier -- curl -s http://localhost:3004/health
kubectl exec -n kubestock-staging deploy/ms-order-management -- curl -s http://localhost:3005/health
kubectl exec -n kubestock-staging deploy/ms-identity -- curl -s http://localhost:3006/health
```

## Sync Policy

| Environment | Auto-Sync | Prune | Self-Heal | Approval |
|-------------|-----------|-------|-----------|----------|
| Staging     | ✅ On     | ✅ On  | ✅ On     | Not required |
| Production  | ❌ Off    | ❌ Off | ❌ Off    | Required |

> **Note**: Staging has auto-sync enabled for rapid iteration. Production requires manual approval for safety.

This repository follows GitOps principles:
- All Kubernetes manifests are version controlled
- ArgoCD syncs cluster state with this repository
- Changes are deployed via Pull Requests
- Automatic sync for staging, manual approval for production
