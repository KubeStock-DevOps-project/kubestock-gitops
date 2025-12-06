# Inventory Service - base/services/ms-inventory/

This directory contains the deployment configuration for the KubeStock Inventory Management microservice.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates ms-inventory service resources

**Includes**:
- deployment.yaml
- service.yaml

### deployment.yaml
**Purpose**: Inventory service deployment specification

**Defines**:
- **Container image**: Inventory service backend
- **Replicas**: Base configuration (customized by overlays)
- **Port**: 8080 (default microservice port)
- **Health checks**: Liveness and readiness probes
- **Environment variables**: Database connection (injected by overlays)
- **Service account**: Inventory service identity
- **Resource limits**: CPU and memory constraints

**Responsibilities**:
- Track product stock levels
- Monitor inventory movements
- Update quantities on orders
- Generate inventory reports
- Alert on low stock
- Manage warehouse locations

### service.yaml
**Purpose**: Kubernetes service for ms-inventory access

**Defines**:
- **Type**: ClusterIP (internal service)
- **Port**: 8080
- **Selector**: Routes to ms-inventory pods
- **Service name**: `ms-inventory`

**Use case**: Internal service for order and product services to check/update inventory

## Service Responsibilities

### Inventory Operations
```
GET /inventory/{product_id}        → Get current stock level
POST /inventory/{product_id}       → Adjust stock quantity
POST /inventory/reserve            → Reserve stock for order
POST /inventory/release            → Release reserved stock
POST /inventory/restock            → Record inbound stock
```

### Stock Tracking
```
GET /inventory/low-stock           → Get products below reorder level
GET /inventory/movements           → Get stock movement history
GET /inventory/locations           → Get inventory by warehouse
GET /inventory/reports             → Generate inventory reports
```

### Inventory Data
```
- Product ID and SKU
- Current quantity in stock
- Quantity reserved for orders
- Quantity available for sale
- Warehouse/location details
- Reorder level and quantity
- Last updated timestamp
- Movement history (in/out/adjustment)
```

## Data Model

```
Inventory {
  product_id: UUID
  warehouse_id: UUID
  quantity_on_hand: integer
  quantity_reserved: integer
  quantity_available: integer (on_hand - reserved)
  reorder_level: integer
  reorder_quantity: integer
  last_counted: timestamp
  created_at: timestamp
  updated_at: timestamp
}

StockMovement {
  id: UUID
  product_id: UUID
  movement_type: IN|OUT|ADJUSTMENT|RESERVE|RELEASE
  quantity: integer
  reason: string
  reference_order_id: UUID (optional)
  user_id: UUID
  timestamp: timestamp
}
```

## Dependencies

- **Database**: PostgreSQL (inventory tracking)
- **ms-product**: For product information
- **ms-order-management**: For order-driven stock adjustments
- **ms-supplier**: For inbound shipment tracking

## Service Communication

```
Order Management Service
     ↓ (reserves/deducts stock)
Inventory Service (Port 8080)
     ↓
Inventory Pod
     ↓
PostgreSQL Database
```

## Inventory Operations Flow

### Order Placement
```
1. Order Service calls ms-inventory/reserve
2. Inventory checks available quantity
3. If sufficient: reserve stock (quantity_reserved++)
4. If insufficient: reject order
```

### Order Fulfillment
```
1. Order shipped
2. Order Service calls ms-inventory/release_and_deduct
3. Inventory decrements on_hand, decrements reserved
4. Updates movement history
```

### Stock Recount/Adjustment
```
1. Physical inventory count performed
2. Adjustment request submitted
3. Inventory recalculates quantities
4. Movement history recorded
5. Low stock alerts triggered if needed
```

## Environment-Specific Customizations

Overlays customize:
- **Replicas**: Production (2), Staging (1)
- **Image tag**: Different versions per environment
- **Database credentials**: Different database per environment
- **Reorder thresholds**: Business-specific reorder levels
- **Resources**: CPU/memory limits per environment

## Critical Considerations

- **Concurrency**: Multiple orders may request same product simultaneously
- **Transactions**: Stock updates must be atomic (all or nothing)
- **Audit trail**: All movements must be logged for compliance
- **Accuracy**: Real-time stock must match physical inventory
- **Alerts**: Notify when stock falls below reorder level

## Debugging Inventory Service

```bash
# View service logs
kubectl logs -n kubestock-production deployment/ms-inventory -f

# Check current stock level
kubectl port-forward -n kubestock-production svc/ms-inventory 8080:8080
# Then: curl http://localhost:8080/inventory/{product_id}

# View inventory movement history
curl http://localhost:8080/inventory/movements

# Check low stock items
curl http://localhost:8080/inventory/low-stock

# Database consistency check
kubectl exec -it <pod> -n kubestock-production -- psql $DATABASE_URL -c \
  "SELECT product_id, quantity_on_hand FROM inventory WHERE quantity_on_hand < reorder_level;"
```

## Integration with Other Services

- **Order Management**: Reserves/releases stock
- **Product**: Gets product information for stock
- **Supplier**: Tracks inbound stock from suppliers
- **Frontend**: Displays product availability to customers
