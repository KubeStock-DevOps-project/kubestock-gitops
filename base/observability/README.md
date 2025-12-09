# =============================================================================
# Observability Stack - README
# =============================================================================

# Observability Stack for KubeStock

Modern observability stack providing metrics, logs, and alerting capabilities.

## Components

### Prometheus (Metrics)
- **Version**: v2.48.0
- **Purpose**: Metrics collection, storage, and alerting rules
- **Storage**: 10Gi PVC with configurable retention
- **Port**: 9090

### Grafana (Visualization)
- **Version**: v10.2.3
- **Purpose**: Dashboards and visualization
- **Storage**: 5Gi PVC
- **Port**: 3000
- **Default Credentials**: admin / kubestock@2025

### Loki (Logs)
- **Version**: 2.9.3
- **Purpose**: Log aggregation and querying
- **Storage**: 10Gi PVC (S3 backend in production for long-term)
- **Port**: 3100

### Promtail (Log Collector)
- **Version**: 2.9.3
- **Purpose**: DaemonSet that ships logs to Loki
- **Deployment**: Runs on every node

### Alertmanager (Production only)
- **Version**: v0.26.0
- **Purpose**: Alert routing and notifications
- **Port**: 9093

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Grafana                                  │
│                    (Visualization)                               │
└───────────────────────┬─────────────────────────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          │                           │
          ▼                           ▼
┌─────────────────┐         ┌─────────────────┐
│   Prometheus    │         │      Loki       │
│   (Metrics)     │         │     (Logs)      │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │                           │
         ▼                           ▼
┌─────────────────┐         ┌─────────────────┐
│  Microservices  │         │    Promtail     │
│   /metrics      │         │   (DaemonSet)   │
└─────────────────┘         └─────────────────┘
```

## Environment Differences

### Staging
- 7-day local retention
- Smaller resource limits
- No Alertmanager
- Scrapes `kubestock-staging` namespace

### Production  
- 15-day local retention + S3 for long-term
- Higher resource limits
- Alertmanager enabled with alert rules
- Scrapes `kubestock-production` namespace

## Deployment

Deploy via ArgoCD (recommended):

```bash
# Staging
kubectl apply -f apps/staging/observability-staging.yaml

# Production
kubectl apply -f apps/production/observability-production.yaml
```

Or manually with Kustomize:

```bash
# Staging
kubectl apply -k overlays/staging/observability/

# Production  
kubectl apply -k overlays/production/observability/
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

### Loki (via Grafana)
Loki is accessed through Grafana's Explore feature using the Loki datasource.

## AWS Infrastructure

The observability stack uses AWS resources provisioned by Terraform:

- **S3 Buckets**: Long-term storage for metrics (Thanos) and logs (Loki)
- **IAM Policies**: Access permissions for S3 buckets
- **EBS Volumes**: Dynamic provisioning via ebs-sc StorageClass

See `infrastructure/terraform/prod/modules/observability/` for details.

## Adding Metrics to Microservices

Your Node.js services need to expose `/metrics` endpoint:

```javascript
const promClient = require('prom-client');

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

## Configuring Alerts

Edit `overlays/production/observability/prometheus-config.yaml` to add custom alerts:

```yaml
groups:
  - name: custom-alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
```

Configure alert receivers in `alertmanager/configmap.yaml` (Slack, Email, PagerDuty, etc.).


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
