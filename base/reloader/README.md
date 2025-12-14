# Stakater Reloader

## Overview

Reloader is a Kubernetes controller that watches for changes in ConfigMaps and Secrets, and automatically triggers rolling restarts on associated Deployments, StatefulSets, and DaemonSets.

## Why Reloader?

By default, Kubernetes does not restart pods when ConfigMaps or Secrets they mount are updated. This means:
- Dashboard changes in Grafana require manual restarts
- Configuration changes don't take effect until pods are restarted

Reloader solves this by watching for changes and triggering rolling updates automatically.

## Usage

### Auto Mode (Recommended)

Add this annotation to your Deployment/StatefulSet metadata:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

Reloader will watch **all** ConfigMaps and Secrets mounted by that workload and trigger a rolling update when any of them change.

### Specific Resources

To watch only specific ConfigMaps:

```yaml
metadata:
  annotations:
    configmap.reloader.stakater.com/reload: "configmap1,configmap2"
```

To watch only specific Secrets:

```yaml
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "secret1,secret2"
```

## Currently Configured

The following deployments have Reloader auto-reload enabled:

| Deployment | Namespace | ConfigMaps Watched |
|------------|-----------|-------------------|
| grafana | observability-* | All dashboard ConfigMaps |

## Verification

Check if Reloader is running:

```bash
kubectl get pods -n reloader
kubectl logs -n reloader -l app.kubernetes.io/name=reloader
```

Test the auto-reload:

```bash
# Update a ConfigMap
kubectl edit configmap grafana-dashboard-nodes -n observability-production

# Watch the Grafana pod restart
kubectl get pods -n observability-production -w
```

## Troubleshooting

### Pod not restarting after ConfigMap change

1. Verify Reloader is running:
   ```bash
   kubectl get pods -n reloader
   ```

2. Check Reloader logs:
   ```bash
   kubectl logs -n reloader -l app.kubernetes.io/name=reloader
   ```

3. Verify annotation is set:
   ```bash
   kubectl get deployment grafana -n observability-production -o yaml | grep reloader
   ```

4. Manual restart if needed:
   ```bash
   kubectl rollout restart deployment/grafana -n observability-production
   ```

## References

- [Stakater Reloader GitHub](https://github.com/stakater/Reloader)
- [Documentation](https://github.com/stakater/Reloader/blob/master/README.md)
