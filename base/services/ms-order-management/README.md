# Order Management Service - base/services/ms-order-management/

This directory contains the deployment configuration for the KubeStock Order Management microservice.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates ms-order-management service resources

**Includes**:
- deployment.yaml
- service.yaml

### deployment.yaml
**Purpose**: Order management service deployment specification

**Defines**:
- **Container image**: Order management service backend
- **Replicas**: Base configuration (customized by overlays)
- **Port**: 8080 (default microservice port)
- **Health checks**: Liveness and readiness probes
- **Environment variables**: Database connection (injected by overlays)
- **Service account**: Order management service identity
- **Resource limits**: CPU and memory constraints

**Responsibilities**:
- Create and manage customer orders
- Track order status and lifecycle
- Coordinate with inventory and payment services
- Generate order confirmations and invoices
- Handle order cancellations and returns
- Generate order reports and analytics

### service.yaml
**Purpose**: Kubernetes service for ms-order-management access

**Defines**:
- **Type**: ClusterIP (internal service)
- **Port**: 8080
- **Selector**: Routes to ms-order-management pods
- **Service name**: `ms-order-management`

**Use case**: Internal service for order processing and management

## Service Responsibilities

### Order Operations
```
POST /orders                      → Create new order
GET /orders/{id}                  → Get order details
GET /orders (user auth required)  → Get user's orders
PUT /orders/{id}                  → Update order (admin)
DELETE /orders/{id}               → Cancel order
```

### Order Processing
```
POST /orders/{id}/checkout        → Process payment and ship
POST /orders/{id}/ship            → Mark as shipped
POST /orders/{id}/deliver         → Mark as delivered
POST /orders/{id}/return          → Process return request
```

### Order Information
```
GET /orders/{id}/invoice          → Get order invoice
GET /orders/{id}/tracking         → Get shipping tracking
GET /orders/status/{status}       → Get orders by status
```

## Order Lifecycle

```
PENDING (new order, waiting for payment)
  ↓
PAID (payment received)
  ↓
PROCESSING (preparing for shipment)
  ↓
SHIPPED (in transit)
  ↓
DELIVERED (reached customer)
  ↓
COMPLETED (fulfilled)

OR at any point:
  ↓
CANCELLED (customer or system cancelled)
```

## Data Model

```
Order {
  id: UUID
  order_number: string (unique)
  customer_id: UUID
  status: PENDING|PAID|PROCESSING|SHIPPED|DELIVERED|COMPLETED|CANCELLED
  total_amount: decimal
  subtotal: decimal
  tax: decimal
  shipping_cost: decimal
  created_at: timestamp
  updated_at: timestamp
}

OrderItem {
  id: UUID
  order_id: UUID
  product_id: UUID
  quantity: integer
  unit_price: decimal
  subtotal: decimal (quantity * unit_price)
}

OrderShipment {
  id: UUID
  order_id: UUID
  tracking_number: string
  carrier: string
  shipped_at: timestamp
  delivered_at: timestamp
}
```

## Dependencies

- **Database**: PostgreSQL (order storage)
- **ms-inventory**: Reserve/deduct stock on order
- **ms-identity**: Authenticate users, get customer info
- **ms-product**: Get product details and pricing
- **Payment Service** (external): Process credit card payments
- **Shipping Service** (external): Generate shipping labels

## Service Communication

```
Frontend (user places order)
     ↓
Kong Gateway
     ↓
ms-order-management (Port 8080)
     ↓
Parallel calls to:
  - ms-inventory (reserve stock)
  - ms-identity (get customer info)
  - ms-product (get product details)
  - Payment API (process payment)
  - Shipping API (generate label)
```

## Order Flow

### Creating an Order
```
1. Frontend submits order with items and customer info
2. Order Service creates order in PENDING status
3. Order Service calls ms-inventory to reserve stock
4. If inventory unavailable: reject and return error
5. If successful: return order ID, wait for payment
```

### Checkout and Payment
```
1. Customer initiates checkout
2. Order Service calculates totals (subtotal, tax, shipping)
3. Order Service requests payment from payment API
4. If payment fails: cancel order, release inventory
5. If payment succeeds: update order to PAID status
6. Move to fulfillment
```

### Fulfillment and Shipping
```
1. Order Service marks order as PROCESSING
2. Warehouse picks and packs items
3. Order Service requests shipping label from carrier
4. Shipping label printed and scanned
5. Order Service marks as SHIPPED, stores tracking number
6. Customer receives tracking link
7. When delivered: Order Service marks DELIVERED
8. After return window closes: Order Service marks COMPLETED
```

## Environment-Specific Customizations

Overlays customize:
- **Replicas**: Production (2), Staging (1)
- **Image tag**: Different versions per environment
- **Database credentials**: Different database per environment
- **Payment API**: Test vs production payment gateway
- **Shipping API**: Test vs production shipping service
- **Resources**: CPU/memory limits per environment

## Error Handling

- **Inventory unavailable**: Reject order before payment
- **Payment failure**: Rollback order, release inventory
- **Shipping failure**: Keep order in PAID, retry shipping
- **Delivery failure**: Keep order in SHIPPED, retry delivery

## Debugging Order Service

```bash
# View service logs
kubectl logs -n kubestock-production deployment/ms-order-management -f

# Create test order
kubectl port-forward -n kubestock-production svc/ms-order-management 8080:8080
# Then: curl -X POST http://localhost:8080/orders -d "{...}"

# View order details
curl http://localhost:8080/orders/{order_id}

# Check pending orders
curl http://localhost:8080/orders/status/PENDING

# Database consistency check
kubectl exec -it <pod> -n kubestock-production -- psql $DATABASE_URL -c \
  "SELECT COUNT(*) as pending_orders FROM orders WHERE status = 'PENDING' AND created_at < NOW() - INTERVAL '1 day';"
```

## Integration with Other Services

- **Inventory**: Manages product stock for orders
- **Product**: Provides product details and pricing
- **Identity**: Authenticates customers, stores user data
- **Supplier**: Manages inventory replenishment
- **Frontend**: Displays orders and tracking to customers
- **Payment API**: Processes payments (external)
- **Shipping**: Generates labels and tracking (external)
