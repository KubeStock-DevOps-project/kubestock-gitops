# ArgoCD Configuration

This directory contains ArgoCD configuration files for managing deployments across different environments (staging and production).

## Directory Structure

```
argocd/
├── config/                    # ArgoCD system configuration
│   └── argocd-cm.yaml        # ArgoCD ConfigMap with custom settings
└── projects/                  # AppProject definitions
    ├── infrastructure.yaml   # Infrastructure components project
    ├── staging.yaml          # Staging environment project
    └── production.yaml       # Production environment project
```

## Files Overview

### config/
- **argocd-cm.yaml**: ArgoCD ConfigMap containing system-wide configuration including:
  - Repository settings for kubestock-gitops
  - Resource customizations and health checks (Ingress, StatefulSet)
  - Kustomize build options
  - Resource exclusions

### projects/
- **infrastructure.yaml**: AppProject for cluster-wide infrastructure components (EBS CSI, Metrics Server, etc.)
- **staging.yaml**: AppProject for staging environment, allowing deployments to kubestock-staging namespace
- **production.yaml**: AppProject for production environment with sync windows and stricter controls

## Usage

These files are applied directly to the `argocd` namespace and define:
1. What repositories ArgoCD can access (kubestock-gitops)
2. What namespaces and clusters can be deployed to per project
3. Cluster-scoped resource whitelists per project
4. Sync windows for production (business hours only)
5. RBAC roles for different team members

