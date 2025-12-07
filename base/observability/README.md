# =============================================================================
# Observability Stack - README
# =============================================================================

# Observability Stack for KubeStock

Modern Prometheus and Grafana setup aligned with current GitOps architecture.

## Components

### Prometheus
- **Version**: v2.48.0
- **Namespace**: observability
- **Storage**: 10Gi PVC with 15-day retention
- **Port**: 9090

### Grafana
- **Version**: v10.2.3
- **Namespace**: observability
- **Storage**: 5Gi PVC
- **Port**: 3000
- **Default Credentials**: admin / kubestock@2025

## Monitored Services

Prometheus scrapes metrics from:
- **ms-product** (kubestock-staging:3002)
- **ms-inventory** (kubestock-staging:3003)
- **ms-supplier** (kubestock-staging:3004)
- **ms-order-management** (kubestock-staging:3005)
- **ms-identity** (kubestock-staging:3006)
- **kong-gateway** (kong namespace)
- **Kubernetes nodes and pods**

## Deployment

Deploy via ArgoCD:

```bash
kubectl apply -f ../../apps/staging/observability-staging.yaml
```

Or manually:

```bash
kubectl apply -k .
```

## Access

### Prometheus UI

```bash
kubectl port-forward -n observability svc/prometheus 9090:9090
# Access: http://localhost:9090
```

### Grafana UI

```bash
kubectl port-forward -n observability svc/grafana 3000:3000
# Access: http://localhost:3000
# Login: admin / kubestock@2025
```

## Adding Metrics to Microservices

Your Node.js services need to expose `/metrics` endpoint.

### Install prom-client

```bash
npm install prom-client
```

### Add to server.js

```javascript
const promClient = require('prom-client');

// Create registry
const register = new promClient.Registry();

// Collect default metrics
promClient.collectDefaultMetrics({ register });

// Custom metrics example
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

## Grafana Dashboards

Recommended dashboard IDs to import:

1. **Kubernetes Cluster Monitoring**: 7249
2. **Node Exporter Full**: 1860
3. **Kubernetes Pods**: 6417
4. **Kong Dashboard**: 7424

Import via: Dashboards → Import → Enter ID → Select Prometheus datasource

## Architecture

```
┌─────────────────────────────────────────────┐
│     Microservices (kubestock-staging)       │
│   ms-product, ms-inventory, ms-supplier,    │
│   ms-order-management, ms-identity          │
│   (expose /metrics on their ports)          │
└──────────────┬──────────────────────────────┘
               │ scrape every 30s
               ↓
┌─────────────────────────────────────────────┐
│  Prometheus (observability namespace)       │
│  - Scrapes metrics from all services        │
│  - Stores 15 days of data                   │
│  - 10GB persistent storage                  │
└──────────────┬──────────────────────────────┘
               │ query
               ↓
┌─────────────────────────────────────────────┐
│  Grafana (observability namespace)          │
│  - Visualizes metrics via dashboards        │
│  - Pre-configured Prometheus datasource     │
│  - 5GB persistent storage                   │
└─────────────────────────────────────────────┘
```

## Troubleshooting

### Check Prometheus targets

```bash
kubectl port-forward -n observability svc/prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

### View Prometheus logs

```bash
kubectl logs -n observability deployment/prometheus -f
```

### View Grafana logs

```bash
kubectl logs -n observability deployment/grafana -f
```

### Check PVC status

```bash
kubectl get pvc -n observability
```

## Scaling for Production

For production environment:
- Increase Prometheus replicas to 2
- Use higher retention (30d)
- Add Alertmanager for alerting
- Configure remote storage (S3, Thanos)
- Add authentication for external access
