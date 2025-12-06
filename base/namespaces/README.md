# Kubernetes Namespaces - base/namespaces/

This directory contains namespace definitions that logically separate resources in the cluster.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates all namespace definitions

**Includes**:
- kong.yaml
- production.yaml
- staging.yaml

### kong.yaml
**Purpose**: Kubernetes namespace for Kong API Gateway

**Creates**: `kong` namespace

**Contains**:
- Kong deployment
- Kong services (proxy and admin)
- Kong configuration and RBAC

**Use case**: Isolates Kong gateway infrastructure from application services

### production.yaml
**Purpose**: Kubernetes namespace for production environment

**Creates**: `kubestock-production` namespace

**Contains**:
- All production microservices
- Production ConfigMaps and Secrets
- Production ingress rules
- Production replicated services

**Use case**: Isolates production applications from other environments, enables different RBAC policies

### staging.yaml
**Purpose**: Kubernetes namespace for staging environment

**Creates**: `kubestock-staging` namespace

**Contains**:
- All staging microservices
- Staging ConfigMaps and Secrets
- Staging test ingress rules
- Staging services

**Use case**: Isolates staging/testing environment from production, allows developers to test safely

## Namespace Isolation Benefits

1. **Resource isolation**: Each namespace has separate resource quotas
4. **RBAC separation**: Different access policies per namespace
5. **Network policies**: Can restrict traffic between namespaces
6. **Easier management**: Services with same names can exist in different namespaces
7. **Cost tracking**: Can track resource usage per namespace

## Viewing Namespaces

```bash
kubectl get namespaces
kubectl get all -n kubestock-production
kubectl get all -n kubestock-staging
kubectl get all -n kong
```

