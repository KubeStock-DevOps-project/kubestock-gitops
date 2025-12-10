# Staging Applications - apps/staging/

This directory contains ArgoCD Application definitions for the staging environment.

## Files Overview

### kubestock-staging.yaml
**Purpose**: Defines the main KubeStock application deployment for staging

**Specifies**:
- **Source**: Points to `overlays/staging/` for staging-specific configurations
- **Destination**: Deploys to `kubestock-staging` namespace
- **Sync Policy**: 
  - Auto-sync enabled: Automatically syncs when Git changes are detected
  - Self-heal enabled: Corrects drift from desired state
- **Project**: References the `kubestock-staging` AppProject for access control
- **Application components**:
  - All microservices (ms-product, ms-inventory, ms-supplier, ms-order-management, ms-identity)
  - Frontend application
  - Kong API Gateway
  - Secrets and configuration

### observability-staging.yaml
**Purpose**: Staging-specific observability configuration

**Specifies**:
- **Source**: Points to `overlays/staging/observability/` 
- **Destination**: Deploys to `observability` namespace (shared with production)
- **Sync Policy**: Auto-sync enabled
- **Dependencies**: Requires `observability-production` to be deployed first (creates namespace and RBAC)
- **Components**: 
  - Prometheus config with staging namespace scrape targets
  - Grafana, Loki, Promtail use shared resources

**Note**: Cluster-scoped resources (Namespace, StorageClass, ClusterRoles) are managed by the production overlay only to avoid ArgoCD shared resource conflicts.

**Monitored by ArgoCD**: Any push to `gitops/overlays/staging/` triggers an automatic sync

## Deployment Strategy

This application uses:
- **Rolling updates** with 1 replica (cost optimized for staging)
- **Staging namespaces**: `kubestock-staging`
- **Environment labels**: `environment: staging` applied to all resources
- **Configuration source**: Staging-specific overlays with test environment variables and secrets

## Services Deployed

Staging includes:
- **ms-product** - Product Catalog Service (1 replica)
- **ms-inventory** - Inventory Management Service (1 replica)  
- **ms-supplier** - Supplier Management Service (1 replica)
- **ms-order-management** - Order Management Service (1 replica)
- **ms-identity** - Identity/User Management Service (1 replica)
- **frontend** - React Frontend Application (1 replica)
- **Kong** - API Gateway for routing and traffic control

## Database

- **Type**: PostgreSQL (staging instance or shared dev database)
- **Credentials**: Stored in `overlays/staging/secrets.yaml`
- **Connection**: All services use staging database credentials from secrets

## Accessing Staging Applications

```bash
# View staging deployments
kubectl get deployments -n kubestock-staging

# View staging services
kubectl get services -n kubestock-staging

# Check pod status
kubectl get pods -n kubestock-staging -o wide

# View staging frontend
https://staging.example.com (or http://localhost based on ingress config)

# View staging Kong admin
kubectl port-forward -n kong svc/kong-admin 8001:8001
# Then: http://localhost:8001
```

## Staging Use Cases

- **Feature testing**: Test new features before production release
- **Regression testing**: Validate that fixes don't break existing functionality
- **Performance testing**: Measure application behavior under load
- **Integration testing**: Test microservice interactions
- **UAT (User Acceptance Testing)**: Allow stakeholders to validate features
- **Database migration testing**: Safe schema change validation

## Key Staging Characteristics

- **Cost optimized**: Single replica deployments to save resources
- **Development friendly**: Relaxed CORS and security policies
- **Testing purpose**: Validates application before production
- **Shared access**: Multiple developers may deploy simultaneously
- **Auto-sync**: Changes automatically deployed when pushed to Git

## Debugging in Staging

```bash
# View logs for a specific service
kubectl logs -n kubestock-staging deployment/ms-product -f

# Execute commands in a pod
kubectl exec -n kubestock-staging -it <pod-name> -- /bin/sh

# Port-forward to debug locally
kubectl port-forward -n kubestock-staging svc/ms-product 8080:8080
```
