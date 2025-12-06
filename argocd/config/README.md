# ArgoCD Configuration - config/

This directory contains the main ArgoCD system configuration.

## Files Overview

### argocd-cm.yaml
**Purpose**: ArgoCD ConfigMap for system-wide configuration

**Contains**:
- **repositories**: Git repository URLs and credentials that ArgoCD can access (kubestock-core repository)
- **resource.customizations**: Custom health check logic for Kubernetes resources like Ingress, StatefulSet, and other resources
- **RBAC configuration**: Role-based access control settings for different teams/users
- **UI customization**: Custom branding and settings for the ArgoCD UI

**When to modify**: 
- Adding new Git repositories
- Updating health check logic for specific resource types
- Changing RBAC policies
- Customizing the ArgoCD UI appearance

