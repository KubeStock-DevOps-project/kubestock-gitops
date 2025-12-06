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
**Purpose**: AppProject definition for the production environment with blue-green deployment support

**Defines**:
- Allowed source repositories (restricted to kubestock-core)
- Multiple destination namespaces:
  - `kubestock-production`: Live production traffic
  - `kubestock-blue`: Blue deployment for zero-downtime updates
  - `kubestock-green`: Green deployment for traffic switching
  - `argocd`: ArgoCD system namespace
- Stricter RBAC policies and resource restrictions for production
- Blue-green deployment strategy support

**Use case**: Production environment with high availability and zero-downtime deployments

## Key Differences

| Aspect | Staging | Production |
|--------|---------|-----------|
| Repositories | Multiple sources allowed | Only kubestock-core |
| Namespaces | Limited staging namespaces | Multiple with blue-green support |
| Strategy | Standard rolling updates | Blue-green for zero-downtime |
| Risk Level | Lower, for testing | Higher, requires strict controls |

