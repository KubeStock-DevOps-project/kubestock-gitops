# Supplier Service - base/services/ms-supplier/

This directory contains the deployment configuration for the KubeStock Supplier Management microservice.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates ms-supplier service resources

**Includes**:
- deployment.yaml
- service.yaml

### deployment.yaml
**Purpose**: Supplier service deployment specification

**Defines**:
- **Container image**: Supplier service backend
- **Replicas**: Base configuration (customized by overlays)
- **Port**: 8080 (default microservice port)
- **Health checks**: Liveness and readiness probes
- **Environment variables**: Database connection (injected by overlays)
- **Service account**: Supplier service identity
- **Resource limits**: CPU and memory constraints

**Responsibilities**:
- Manage supplier information and contacts
- Track supplier performance metrics
- Manage supplier agreements and contracts
- Handle supplier payments
- Track inbound shipments from suppliers
- Maintain supplier catalog and pricing

### service.yaml
**Purpose**: Kubernetes service for ms-supplier access

**Defines**:
- **Type**: ClusterIP (internal service)
- **Port**: 8080
- **Selector**: Routes to ms-supplier pods
- **Service name**: `ms-supplier`

**Use case**: Internal service for inventory and procurement operations

## Service Responsibilities

### Supplier Management
```
GET /suppliers                 → List all suppliers
GET /suppliers/{id}            → Get supplier details
POST /suppliers                → Create new supplier
PUT /suppliers/{id}            → Update supplier info
DELETE /suppliers/{id}         → Deactivate supplier
```

### Supplier Contacts
```
GET /suppliers/{id}/contacts   → Get supplier contacts
POST /suppliers/{id}/contacts  → Add contact person
PUT /suppliers/{id}/contacts/{contact_id} → Update contact
```

### Supplier Performance
```
GET /suppliers/{id}/performance → Get delivery and quality metrics
GET /suppliers/{id}/orders      → Get orders from this supplier
GET /suppliers/{id}/payments    → Get payment history
```

### Supplier Pricing
```
GET /suppliers/{id}/pricing     → Get supplier pricing for products
POST /suppliers/{id}/pricing    → Update pricing
```

## Data Model

```
Supplier {
  id: UUID
  name: string
  email: string
  phone: string
  address: string
  city: string
  country: string
  payment_terms: string (NET30, NET60, COD, etc.)
  status: ACTIVE|INACTIVE|SUSPENDED
  rating: decimal (1-5)
  created_at: timestamp
  updated_at: timestamp
}

SupplierContact {
  id: UUID
  supplier_id: UUID
  name: string
  title: string
  email: string
  phone: string
  primary: boolean
}

SupplierPricing {
  id: UUID
  supplier_id: UUID
  product_id: UUID
  unit_price: decimal
  minimum_order_quantity: integer
  lead_time_days: integer
  valid_from: timestamp
  valid_to: timestamp
}

SupplierPerformance {
  supplier_id: UUID
  total_orders: integer
  on_time_delivery_percent: decimal
  quality_rating: decimal
  average_lead_time_days: decimal
  last_order_date: timestamp
}
```

## Dependencies

- **Database**: PostgreSQL (supplier data)
- **ms-inventory**: For inbound shipment tracking
- **ms-product**: Links products to suppliers

## Service Communication

```
Procurement/Admin
     ↓
ms-supplier (Port 8080)
     ↓
Supplier Pod
     ↓
PostgreSQL Database
     ↓
ms-inventory (inbound tracking)
ms-product (product linking)
```

## Supplier Workflow

### Onboarding New Supplier
```
1. Add supplier with basic info (name, contact, address)
2. Define payment terms and lead times
3. Set up initial pricing for products
4. Create supplier contacts
5. Verify contact information
6. Supplier status: ACTIVE
```

### Purchasing Process
```
1. Procurement needs inventory
2. Check supplier pricing and availability
3. Create purchase order (via inventory service)
4. Supplier ships products (inbound logistics)
5. Update shipment tracking
6. Receive goods in warehouse
7. Update inventory with received quantity
8. Process supplier payment
9. Update supplier performance metrics
```

### Supplier Performance Tracking
```
- On-time delivery: % of orders delivered by promised date
- Quality: % of defect-free items received
- Lead time: Average days from order to delivery
- Responsiveness: Response time to inquiries
- Overall rating: Combined metric for supplier selection
```

## Environment-Specific Customizations

Overlays customize:
- **Replicas**: Production (2), Staging (1)
- **Image tag**: Different versions per environment
- **Database credentials**: Different database per environment
- **Supplier master data**: Test vs production suppliers
- **Resources**: CPU/memory limits per environment

## Key Supplier Information

- **Company details**: Legal name, registration, tax ID
- **Contact persons**: Multiple contacts for different functions
- **Payment info**: Bank account, payment terms, invoicing
- **Agreements**: Contract terms, minimum orders, pricing
- **Performance history**: Delivery, quality, responsiveness
- **Product catalog**: What products can be ordered from them

## Debugging Supplier Service

```bash
# View service logs
kubectl logs -n kubestock-production deployment/ms-supplier -f

# List all suppliers
kubectl port-forward -n kubestock-production svc/ms-supplier 8080:8080
# Then: curl http://localhost:8080/suppliers

# Get specific supplier details
curl http://localhost:8080/suppliers/{supplier_id}

# Check supplier performance
curl http://localhost:8080/suppliers/{supplier_id}/performance

# Database consistency check
kubectl exec -it <pod> -n kubestock-production -- psql $DATABASE_URL -c \
  "SELECT name, status, rating FROM suppliers ORDER BY rating DESC;"
```

## Integration with Other Services

- **Inventory**: Tracks inbound shipments from suppliers
- **Product**: Suppliers provide products
- **Order Management**: Orders placed with suppliers for restocking
- **Frontend**: Suppliers viewable to admin users
