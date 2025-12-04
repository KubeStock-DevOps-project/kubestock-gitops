# KubeStock GitOps

GitOps repository for KubeStock Kubernetes deployments using ArgoCD.

## Structure

```
├── applications/          # ArgoCD Application manifests
│   ├── production/       # Production environment apps
│   └── staging/          # Staging environment apps
├── base/                  # Base Kubernetes manifests
│   ├── services/         # Microservice deployments
│   └── gateway/          # API Gateway configuration
├── overlays/              # Kustomize overlays
│   ├── production/       # Production-specific patches
│   └── staging/          # Staging-specific patches
└── projects/              # ArgoCD Project definitions
```

## Services

- **ms-product** - Product Catalog Service
- **ms-inventory** - Inventory Management Service
- **ms-supplier** - Supplier Management Service
- **ms-order-management** - Order Management Service
- **ms-identity** - Identity/User Management Service
- **kubestock-frontend** - React Frontend Application

## Deployment Strategy

This repository follows GitOps principles:
- All Kubernetes manifests are version controlled
- ArgoCD syncs cluster state with this repository
- Changes are deployed via Pull Requests
- Automatic sync for staging, manual approval for production
