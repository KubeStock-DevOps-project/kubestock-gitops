# ArgoCD Configuration

This directory contains ArgoCD configuration files for managing deployments across different environments (staging and production).

## Directory Structure

```
argocd/
├── config/                    # ArgoCD system configuration
│   └── argocd-cm.yaml        # ArgoCD ConfigMap with custom settings
└── projects/                  # AppProject definitions
    ├── staging.yaml          # Staging environment project
    └── production.yaml       # Production environment project
```

## Files Overview

### config/
- **argocd-cm.yaml**: ArgoCD ConfigMap containing system-wide configuration including:
  - Repository settings and authentication
  - Resource customizations and health checks
  - RBAC policies
  - UI customizations

### projects/
- **staging.yaml**: AppProject definition for the staging environment, restricting what repositories and namespaces can be deployed
- **production.yaml**: AppProject definition for the production environment with blue-green deployment support, restricting access to production namespaces

## Usage

These files are applied directly to the `argocd` namespace and define:
1. What repositories ArgoCD can access
2. What namespaces and clusters can be deployed to
3. How health checks work for different Kubernetes resources
4. Custom RBAC policies for different teams

