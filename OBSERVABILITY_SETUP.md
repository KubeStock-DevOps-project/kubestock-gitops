# 🎯 Observability Setup Guide for KubeStock

Complete guide to deploy Prometheus and Grafana monitoring for your cluster.

## 📋 What You're Deploying

- **Prometheus**: Metrics collection and storage (observability namespace)
- **Grafana**: Visualization dashboards (observability namespace)
- **Monitoring**: All 6 microservices + Kong Gateway

## 🚀 Deployment Steps

### Step 1: Deploy Observability Stack via ArgoCD

From your bastion or dev server:

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f gitops/apps/staging/observability-staging.yaml

# Verify the application is created
kubectl get applications -n argocd | grep observability
```

### Step 2: Sync the Application

```bash
# Sync via kubectl
kubectl patch app observability-staging -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# OR sync via ArgoCD CLI (if installed)
argocd app sync observability-staging
```

### Step 3: Verify Deployment

```bash
# Check pods in observability namespace
kubectl get pods -n observability

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# prometheus-xxxxxxxxx-xxxxx    1/1     Running   0          2m
# grafana-xxxxxxxxx-xxxxx       1/1     Running   0          2m

# Check services
kubectl get svc -n observability

# Check PVCs
kubectl get pvc -n observability
```

### Step 4: Access Prometheus

```bash
# Port-forward from bastion/dev server
kubectl port-forward -n observability svc/prometheus 9090:9090

# From your local machine (if using SSH tunnel):
ssh -L 9090:localhost:9090 -i ~/.ssh/kubestock-key ubuntu@<BASTION_IP>

# Open browser: http://localhost:9090
```

**Verify Targets:**
- Go to Status → Targets
- Should see: ms-product, ms-inventory, ms-supplier, ms-order-management, ms-identity, kong-gateway

### Step 5: Access Grafana

```bash
# Port-forward from bastion/dev server
kubectl port-forward -n observability svc/grafana 3000:3000

# From your local machine (if using SSH tunnel):
ssh -L 3000:localhost:3000 -i ~/.ssh/kubestock-key ubuntu@<BASTION_IP>

# Open browser: http://localhost:3000
# Login: admin / kubestock@2025
```

## 📊 Configure Grafana Dashboards

### Import Kubernetes Dashboards

1. Login to Grafana
2. Click **+** → **Import Dashboard**
3. Enter these dashboard IDs one by one:

```
Kubernetes Cluster Monitoring: 7249
Node Exporter Full: 1860
Kubernetes Pods: 6417
Kong Gateway: 7424
```

4. Select **Prometheus** as datasource
5. Click **Import**

### Create Custom Dashboard for KubeStock Services

In Grafana:
1. Click **+** → **Create Dashboard**
2. Add panels with these queries:

**Service Health:**
```promql
up{namespace="kubestock-staging"}
```

**Request Rate:**
```promql
rate(http_requests_total{namespace="kubestock-staging"}[5m])
```

**Response Time:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Memory Usage:**
```promql
container_memory_usage_bytes{namespace="kubestock-staging"}
```

**CPU Usage:**
```promql
rate(container_cpu_usage_seconds_total{namespace="kubestock-staging"}[5m])
```

## 🔧 Add Metrics to Your Microservices

Your services need to expose `/metrics` endpoint for Prometheus to scrape.

### For Node.js Services

**1. Install prom-client:**

```bash
cd modules/ms-product  # (or any other service)
npm install prom-client
```

**2. Update `src/server.js`:**

```javascript
const express = require('express');
const promClient = require('prom-client');

const app = express();

// Create a Registry
const register = new promClient.Registry();

// Collect default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics({ 
  register,
  prefix: 'nodejs_'
});

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Middleware to track requests
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.labels(req.method, req.route?.path || req.path, res.statusCode).observe(duration);
    httpRequestTotal.labels(req.method, req.route?.path || req.path, res.statusCode).inc();
  });
  
  next();
});

// Your existing routes...
app.get('/health', (req, res) => res.json({ status: 'healthy' }));

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const PORT = process.env.PORT || 3002;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

**3. Test locally:**

```bash
npm start
curl http://localhost:3002/metrics
```

**4. Rebuild and push Docker image:**

```bash
# Build
docker build -t ms-product:latest .

# Tag for ECR
docker tag ms-product:latest 478468757808.dkr.ecr.ap-south-1.amazonaws.com/ms-product:latest

# Push
docker push 478468757808.dkr.ecr.ap-south-1.amazonaws.com/ms-product:latest
```

**5. Restart pod to pull new image:**

```bash
kubectl rollout restart deployment/ms-product -n kubestock-staging
```

**Repeat for all microservices**: ms-inventory, ms-supplier, ms-order-management, ms-identity

## 🎯 Verify Metrics Collection

After adding metrics to services:

**1. Check Prometheus targets:**
```bash
kubectl port-forward -n observability svc/prometheus 9090:9090
# Visit: http://localhost:9090/targets
# All should show "UP" status
```

**2. Query metrics in Prometheus:**
```promql
# Check service is up
up{job="ms-product"}

# Check requests
rate(http_requests_total{namespace="kubestock-staging"}[5m])

# Check memory
process_resident_memory_bytes{namespace="kubestock-staging"}
```

## 📈 Monitoring Architecture

```
┌───────────────────────────────────────────────────────┐
│          KubeStock Microservices Pods                 │
│   (kubestock-staging namespace)                       │
│                                                       │
│   ms-product:3002/metrics                            │
│   ms-inventory:3003/metrics                          │
│   ms-supplier:3004/metrics                           │
│   ms-order-management:3005/metrics                   │
│   ms-identity:3006/metrics                           │
└──────────────────┬────────────────────────────────────┘
                   │ Prometheus scrapes every 30s
                   ↓
┌───────────────────────────────────────────────────────┐
│          Prometheus (observability namespace)         │
│   - Collects and stores metrics                      │
│   - 15 days retention                                │
│   - 10GB storage (PVC)                               │
│   - Port: 9090                                       │
└──────────────────┬────────────────────────────────────┘
                   │ Grafana queries
                   ↓
┌───────────────────────────────────────────────────────┐
│          Grafana (observability namespace)            │
│   - Visualizes metrics via dashboards                │
│   - Pre-configured Prometheus datasource             │
│   - 5GB storage (PVC)                                │
│   - Port: 3000                                       │
│   - Credentials: admin / kubestock@2025              │
└───────────────────────────────────────────────────────┘
```

## 🔍 Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n observability

# Check pod logs
kubectl logs -n observability deployment/prometheus
kubectl logs -n observability deployment/grafana

# Describe pod for events
kubectl describe pod -n observability <pod-name>
```

### PVC issues

```bash
# Check PVC status
kubectl get pvc -n observability

# If stuck in Pending, check storage class
kubectl get storageclass

# Describe PVC for errors
kubectl describe pvc prometheus-storage -n observability
```

### Metrics not showing

```bash
# Test service metrics endpoint directly
kubectl exec -n kubestock-staging deployment/ms-product -- curl localhost:3002/metrics

# Check Prometheus config
kubectl get configmap prometheus-config -n observability -o yaml

# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

### Grafana datasource not working

```bash
# Check Grafana can reach Prometheus
kubectl exec -n observability deployment/grafana -- wget -O- http://prometheus:9090/api/v1/status/config

# Check Grafana logs
kubectl logs -n observability deployment/grafana
```

## 🎓 Next Steps

1. **Add metrics to all microservices** (see section above)
2. **Create custom dashboards** for your specific services
3. **Set up alerts** (optional: add Alertmanager)
4. **Configure Slack notifications** for alerts
5. **Add business metrics** (orders/sec, inventory changes, etc.)

## 📚 Resources

- Prometheus Documentation: https://prometheus.io/docs/
- Grafana Documentation: https://grafana.com/docs/
- PromQL Tutorial: https://prometheus.io/docs/prometheus/latest/querying/basics/
- prom-client GitHub: https://github.com/siimon/prom-client
