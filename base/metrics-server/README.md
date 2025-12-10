# =============================================================================
# Metrics Server - README
# =============================================================================

# Kubernetes Metrics Server

The Metrics Server provides the resource metrics API (metrics.k8s.io) for Kubernetes.

## Purpose

This component is essential for:

1. **Horizontal Pod Autoscaler (HPA)** - Scales pods based on CPU/memory usage
2. **Vertical Pod Autoscaler (VPA)** - Recommends resource requests/limits
3. **kubectl top** - View node and pod resource usage
4. **Kubernetes Dashboard** - Display resource metrics

## Components

- **ServiceAccount**: `metrics-server` in kube-system
- **ClusterRole/Binding**: Access to nodes and pods metrics
- **Deployment**: Single replica metrics-server pod
- **Service**: Internal service on port 443
- **APIService**: Registers metrics.k8s.io/v1beta1 API

## Deployment

```bash
# Via ArgoCD
kubectl apply -f gitops/apps/metrics-server.yaml

# Verify deployment
kubectl get pods -n kube-system -l app=metrics-server

# Test the API
kubectl top nodes
kubectl top pods -n kubestock-staging
```

## Configuration Notes

### --kubelet-insecure-tls

This flag is enabled because kubelets typically use self-signed certificates. In production environments with proper PKI, you can:

1. Remove `--kubelet-insecure-tls`
2. Mount the kubelet CA certificate
3. Add `--kubelet-certificate-authority=/path/to/ca.crt`

### Resource Requirements

Default resource settings:
- **Requests**: 100m CPU, 200Mi memory
- **Limits**: 500m CPU, 512Mi memory

Adjust in the deployment.yaml if needed for larger clusters.

## Troubleshooting

### Metrics not available

```bash
# Check metrics-server pod status
kubectl get pods -n kube-system -l app=metrics-server
kubectl logs -n kube-system -l app=metrics-server

# Check APIService registration
kubectl get apiservice v1beta1.metrics.k8s.io

# Test API directly
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

### Common Issues

1. **APIService showing False**: Check if metrics-server pod is running
2. **Connection refused**: Verify service endpoint resolves
3. **Certificate errors**: Ensure `--kubelet-insecure-tls` is set or proper CA configured

## Integration with Prometheus

Metrics Server provides real-time resource metrics. For historical data and advanced querying, use Prometheus alongside (deployed in observability namespace).

```promql
# Prometheus can scrape similar metrics via cAdvisor
container_cpu_usage_seconds_total
container_memory_usage_bytes
```

## Related Components

- **Prometheus** - Long-term metrics storage and alerting
- **Grafana** - Visualization and dashboards
- **HPA** - Uses metrics-server for scaling decisions
