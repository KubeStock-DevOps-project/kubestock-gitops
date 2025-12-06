# ArgoCD Projects - projects/

This directory contains AppProject definitions that control what can be deployed to each environment.

## Files Overview

### staging.yaml
**Purpose**: AppProject definition for the staging environment

**Defines**:
- Allowed source repositories (which Git repos can be synced)
- Allowed destination clusters and namespaces for staging deployments
- Resource restrictions and RBAC policies for staging
- Cluster role bindings for the staging project

**Use case**: Staging environment deployments with relaxed restrictions for testing

### production.yaml
**Purpose**: AppProject definition for the production environment

**Defines**:
- Allowed source repositories (restricted to kubestock-core)
- Destination namespaces:
  - `kubestock-production`: Production environment
  - `argocd`: ArgoCD system namespace
- Stricter RBAC policies and resource restrictions for production
- Rolling update deployment strategy

**Use case**: Production environment with high availability and zero-downtime deployments

## Key Differences

| Aspect | Staging | Production |
|--------|---------|------------|
| Repositories | Multiple sources allowed | Only kubestock-core |
| Namespaces | kubestock-staging | kubestock-production |
| Strategy | Rolling updates | Rolling updates |
| Risk Level | Lower, for testing | Higher, requires strict controls |

