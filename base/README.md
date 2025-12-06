# Base Kustomize Manifests - base/

This directory contains the base Kubernetes manifests and Kustomize configurations that are shared across all environments.

## Directory Structure

```
base/
├── kustomization.yaml      # Main Kustomize file that aggregates all base resources
├── kong/                   # Kong API Gateway manifests
│   ├── kustomization.yaml
│   ├── deployment.yaml     # Kong Gateway deployment
│   ├── service.yaml        # Kong services (proxy and admin)
│   ├── config.yaml         # Kong configuration
│   └── rbac.yaml           # RBAC for Kong
├── namespaces/             # Kubernetes namespace definitions
│   ├── kustomization.yaml
│   ├── kong.yaml           # Kong namespace
│   ├── production.yaml     # Production namespace
│   └── staging.yaml        # Staging namespace
└── services/               # Microservice deployments
    ├── frontend/           # React frontend
    ├── ms-identity/        # Identity/Auth microservice
    ├── ms-inventory/       # Inventory management microservice
    ├── ms-order-management/ # Order management microservice
    ├── ms-product/         # Product catalog microservice
    └── ms-supplier/        # Supplier management microservice
```

## Files Overview

### kustomization.yaml (root)
**Purpose**: Main Kustomize aggregation file

**Includes**:
- `namespaces/`: All namespace definitions
- `kong/`: Kong API Gateway
- `services/`: All microservices in dependency order

**Use case**: Defines the complete base resource structure that gets overlayed for each environment

### kong/
- **deployment.yaml**: Kong Gateway deployment with 2 replicas, rolling update strategy, and Prometheus metrics
- **service.yaml**: Kong services (NodePort services for proxy and admin API)
- **config.yaml**: Kong configuration (routes, upstreams, plugins)
- **rbac.yaml**: RBAC rules for Kong service account
- **kustomization.yaml**: Kustomize aggregation for Kong resources

### namespaces/
- **kong.yaml**: Kong namespace definition
- **production.yaml**: Production environment namespace
- **staging.yaml**: Staging environment namespace
- **kustomization.yaml**: Aggregates all namespace definitions

### services/
Each service directory contains:
- **deployment.yaml**: Service deployment specification
- **service.yaml**: Kubernetes service for internal/external access
- **kustomization.yaml**: Kustomize aggregation for the service

**Included services**:
- **frontend/**: React-based user interface
- **ms-identity/**: User authentication and authorization
- **ms-inventory/**: Inventory tracking and management
- **ms-order-management/**: Order processing and management
- **ms-product/**: Product catalog and information
- **ms-supplier/**: Supplier management and information

## Key Concepts

1. **Base vs Overlays**: These are base definitions without environment-specific values. Environment-specific settings are applied via overlays.
2. **Kustomize Aggregation**: Each `kustomization.yaml` aggregates child resources
3. **Shared Configuration**: All resources here are inherited by both staging and production overlays
4. **No Secrets**: Base files should NOT contain secrets (those go in overlays)

## Deployment Order

When applied, resources are deployed in this order:
1. Namespaces (kong, production, staging)
2. Kong API Gateway
3. Microservices (in the order specified in kustomization.yaml)

