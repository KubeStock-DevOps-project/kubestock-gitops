# Microservices - base/services/

This directory contains deployment configurations for all KubeStock microservices and the frontend application.

## Directory Structure

```
services/
├── frontend/               # React frontend application
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── ms-identity/           # Identity/Authentication service
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── ms-inventory/          # Inventory management service
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── ms-order-management/   # Order management service
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── ms-product/            # Product catalog service
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── ms-supplier/           # Supplier management service
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

## Service Overview

### frontend/
**Purpose**: React-based user interface for KubeStock

**Contains**:
- deployment.yaml: Nginx container serving the React static build
- service.yaml: ClusterIP service for internal access
- kustomization.yaml: Kustomize aggregation

**Port**: 80 (HTTP)

### ms-identity/
**Purpose**: User authentication, authorization, and identity management

**Contains**:
- deployment.yaml: Identity service backend
- service.yaml: ClusterIP service for inter-service communication
- kustomization.yaml: Kustomize aggregation

**Responsibilities**:
- User registration and login
- JWT token generation and validation
- User role and permission management
- Password reset and account management

### ms-inventory/
**Purpose**: Inventory tracking and stock management

**Contains**:
- deployment.yaml: Inventory service backend
- service.yaml: ClusterIP service for inter-service communication
- kustomization.yaml: Kustomize aggregation

**Responsibilities**:
- Track product stock levels
- Monitor inventory movements
- Generate inventory reports
- Update stock quantities

### ms-order-management/
**Purpose**: Order processing, tracking, and management

**Contains**:
- deployment.yaml: Order management service backend
- service.yaml: ClusterIP service for inter-service communication
- kustomization.yaml: Kustomize aggregation

**Responsibilities**:
- Create and manage customer orders
- Track order status
- Coordinate with inventory service
- Generate order reports

### ms-product/
**Purpose**: Product catalog and information management

**Contains**:
- deployment.yaml: Product service backend
- service.yaml: ClusterIP service for inter-service communication
- kustomization.yaml: Kustomize aggregation

**Responsibilities**:
- Maintain product catalog
- Product information management
- Category and pricing management
- Product search and filtering

### ms-supplier/
**Purpose**: Supplier management and vendor information

**Contains**:
- deployment.yaml: Supplier service backend
- service.yaml: ClusterIP service for inter-service communication
- kustomization.yaml: Kustomize aggregation

**Responsibilities**:
- Manage supplier information
- Track supplier contacts and agreements
- Monitor supplier performance
- Manage supplier payments

## Service Communication

```
External Traffic → Kong Gateway (kong namespace)
                 ↓
        Frontend (kubestock-production/staging)
        ↓                                  ↓
   ms-identity  ← → ms-product  ← → ms-inventory
                  ↓
           ms-order-management  ← → ms-supplier
```

## Common File Structure

Each service directory contains:

1. **deployment.yaml**
   - Container image and version
   - Environment variables
   - Resource requests/limits
   - Health checks
   - Replicas

2. **service.yaml**
   - Type: ClusterIP (for internal service-to-service communication)
   - Port definitions
   - Label selectors

3. **kustomization.yaml**
   - Aggregates deployment.yaml and service.yaml

## Environment-Specific Modifications

Base service files contain common configurations. Environment-specific changes (replicas, resources, env vars) are applied via overlays:
- `overlays/production/` for production-specific settings
- `overlays/staging/` for staging-specific settings

