# ArgoCD Projects - projects/

This directory contains AppProject definitions that control what can be deployed to each environment.

## Files Overview

### infrastructure.yaml
**Purpose**: AppProject for cluster-wide infrastructure components

**Manages**:
- EBS CSI Driver (kube-system)
- Metrics Server (kube-system)
- External Secrets Operator (external-secrets)
- Observability components (observability namespace)

**Allowed cluster-scoped resources**: Namespace, StorageClass, CSIDriver, ClusterRole, ClusterRoleBinding, CRDs, APIService

### staging.yaml
**Purpose**: AppProject definition for the staging environment

**Destination namespaces**:
- `kubestock-staging`: Microservices
- `kong-staging`: Kong API Gateway
- `observability-staging`: Observability stack
- `external-secrets`: Shared secret store

**Sync policy**: Auto-sync enabled (24/7)

### production.yaml
**Purpose**: AppProject definition for the production environment

**Destination namespaces**:
- `kubestock-production`: Microservices
- `kong`: Kong API Gateway
- `observability-production`: Observability stack

**Sync windows**: 
- Deny: 10 PM - 6 AM (manual override allowed)
- Allow: 6 AM - 10 PM (Monday-Friday)

## Key Differences

| Aspect | Infrastructure | Staging | Production |
|--------|---------------|---------|------------|
| Namespaces | kube-system, observability | kubestock-staging | kubestock-production |
| Cluster Resources | Full access | Limited | Limited |
| Sync Windows | Always | Always | Business hours |
| Risk Level | Medium | Low | High |

