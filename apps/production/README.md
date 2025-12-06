# Production Applications - apps/production/

This directory contains ArgoCD Application definitions for the production environment.

## Files Overview

### kubestock-production.yaml
**Purpose**: Defines the main KubeStock application deployment for production

**Specifies**:
- **Source**: Points to `overlays/production/` for production-specific configurations
- **Destination**: Deploys to `kubestock-production` namespace
- **Sync Policy**: 
  - Auto-sync enabled: Automatically syncs when Git changes are detected
  - Self-heal enabled: Corrects drift from desired state
- **Project**: References the `kubestock-production` AppProject for access control
- **Application components**:
  - All microservices (ms-product, ms-inventory, ms-supplier, ms-order-management, ms-identity)
  - Frontend application
  - Kong API Gateway
  - Secrets and configuration

**Monitored by ArgoCD**: Any push to `gitops/overlays/production/` triggers an automatic sync

## Deployment Strategy

This application uses:
- **Rolling updates** with 2 replicas for high availability
- **Production namespaces**: `kubestock-production`
- **Environment labels**: `environment: production` applied to all resources
- **Configuration source**: Production-specific overlays with environment variables and secrets
- **Zero-downtime deployment**: maxSurge: 1, maxUnavailable: 0 ensures rolling updates without service disruption

## Services Deployed

Production includes:
- **ms-product** - Product Catalog Service (2 replicas)
- **ms-inventory** - Inventory Management Service (2 replicas)  
- **ms-supplier** - Supplier Management Service (2 replicas)
- **ms-order-management** - Order Management Service (2 replicas)
- **ms-identity** - Identity/User Management Service (2 replicas)
- **frontend** - React Frontend Application (2 replicas)
- **Kong** - API Gateway for routing and traffic control

## Database

- **Type**: AWS RDS PostgreSQL (managed service)
- **Credentials**: Stored in `overlays/production/secrets.yaml`
- **Connection**: All services use `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` from secrets

## Accessing Production Applications

```bash
# View production deployments
kubectl get deployments -n kubestock-production

# View production services
kubectl get services -n kubestock-production

# Check pod replicas
kubectl get pods -n kubestock-production -o wide

# View production frontend
https://kubestock.dpiyumal.me

# View Kong admin (if accessible)
kubectl port-forward -n kong svc/kong-admin 8001:8001
# Then: http://localhost:8001
```

## Production Safeguards

- **Manual sync**: Requires explicit approval for production changes
- **RBAC**: Strict access control via AppProject
- **Monitoring**: Continuous monitoring of application health
- **Automatic rollback**: Failed deployments automatically roll back
- **Health checks**: Liveness and readiness probes on all services
