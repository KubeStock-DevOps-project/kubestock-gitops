# Product Service - base/services/ms-product/

This directory contains the deployment configuration for the KubeStock Product Catalog microservice.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates ms-product service resources

**Includes**:
- deployment.yaml
- service.yaml

### deployment.yaml
**Purpose**: Product service deployment specification

**Defines**:
- **Container image**: Product service backend
- **Replicas**: Base configuration (customized by overlays)
- **Port**: 8080 (default microservice port)
- **Health checks**: Liveness and readiness probes
- **Environment variables**: Database connection (injected by overlays)
- **Service account**: Product service identity
- **Resource limits**: CPU and memory constraints

**Responsibilities**:
- Maintain product catalog
- Manage product information (name, description, pricing)
- Handle product categorization
- Manage inventory connections
- Provide product search and filtering
- Track product availability

### service.yaml
**Purpose**: Kubernetes service for ms-product access

**Defines**:
- **Type**: ClusterIP (internal service)
- **Port**: 8080
- **Selector**: Routes to ms-product pods
- **Service name**: `ms-product`

**Use case**: Internal service for Kong and other services to access product data

## Service Responsibilities

### Product Endpoints
```
GET /products               → List all products (paginated)
GET /products/{id}         → Get specific product details
POST /products             → Create new product (admin only)
PUT /products/{id}         → Update product details (admin only)
DELETE /products/{id}      → Delete product (admin only)
```

### Product Catalog
```
GET /products/category/{cat}  → Get products by category
GET /products/search          → Search products by name/description
GET /products/active          → Get active products only
GET /products/{id}/inventory  → Get product inventory level
```

### Product Information
```
- Product ID and SKU
- Name and description
- Category and subcategory
- Pricing (base price, discounts)
- Availability status
- Supplier information
- Product images/assets
- Stock quantity and reorder level
```

## Data Model

```
Product {
  id: UUID
  name: string
  description: string
  sku: string
  category: string
  price: decimal
  cost: decimal
  supplier_id: UUID
  stock_quantity: integer
  reorder_level: integer
  status: ACTIVE|INACTIVE
  created_at: timestamp
  updated_at: timestamp
}
```

## Dependencies

- **Database**: PostgreSQL (product catalog)
- **ms-inventory**: For real-time stock levels
- **ms-supplier**: For supplier information
- **Authentication**: Via ms-identity for admin operations

## Service Communication

```
Frontend/Kong
     ↓
ms-product Service (Port 8080)
     ↓
Product Pod
     ↓
PostgreSQL Database
     ↓
ms-inventory (for stock info)
ms-supplier (for supplier info)
```

## Environment-Specific Customizations

Overlays customize:
- **Replicas**: Production (2), Staging (1)
- **Image tag**: Different versions per environment
- **Database credentials**: Different database per environment
- **Cache settings**: Redis cache configuration
- **Resources**: CPU/memory limits per environment

## Performance Considerations

- **Pagination**: Results paginated to avoid returning huge datasets
- **Caching**: Product catalog changes infrequently, good for caching
- **Database indexing**: SKU, category fields indexed for search
- **Search optimization**: Full-text search indexes for product names

## Debugging Product Service

```bash
# View service logs
kubectl logs -n kubestock-production deployment/ms-product -f

# Test product endpoint
kubectl port-forward -n kubestock-production svc/ms-product 8080:8080
# Then: curl http://localhost:8080/products

# Check database connection
kubectl exec -it <pod> -n kubestock-production -- psql $DATABASE_URL -c "SELECT COUNT(*) FROM products;"

# View service dependencies
kubectl get endpoints ms-product -n kubestock-production
```

## Integration with Other Services

- **Order Management**: Needs product details for orders
- **Inventory**: Tracks quantity for specific products
- **Supplier**: Links products to suppliers
- **Frontend**: Displays product catalog to users
