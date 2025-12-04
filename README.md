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

From bastion host:
```bash
# SSH tunnel through bastion to any worker node
ssh -L 8443:<worker-private-ip>:30443 -i ~/.ssh/kubestock-key ubuntu@<bastion-public-ip>

# Access UI at https://localhost:8443
# Username: admin
# Password: (run on dev server)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Sync Policy

| Environment | Auto-Sync | Prune | Self-Heal | Approval |
|-------------|-----------|-------|-----------|----------|
| Staging     | ❌ Off    | ❌ Off | ❌ Off    | Not required |
| Production  | ❌ Off    | ❌ Off | ❌ Off    | Required |

> **Note**: Auto-sync is disabled for manual control. Enable via ArgoCD UI or CLI when ready.

This repository follows GitOps principles:
- All Kubernetes manifests are version controlled
- ArgoCD syncs cluster state with this repository
- Changes are deployed via Pull Requests
- Automatic sync for staging, manual approval for production
