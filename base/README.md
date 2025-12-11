# Base Kustomize Manifests - base/

This directory contains the base Kubernetes manifests and Kustomize configurations that are shared across all environments.

## Directory Structure

```
base/
├── ebs-csi-driver/         # AWS EBS CSI Driver for persistent volumes
├── external-secrets/       # External Secrets configuration (ClusterSecretStore)
├── kong/                   # Kong API Gateway manifests
├── metrics-server/         # Kubernetes Metrics Server for HPA
├── observability-stack/    # Prometheus, Grafana, Loki, Promtail stack
├── services/               # Microservice deployments
│   ├── frontend/
│   ├── ms-identity/
│   ├── ms-inventory/
│   ├── ms-order-management/
│   ├── ms-product/
│   └── ms-supplier/
└── shared-rbac/            # Shared cluster-scoped RBAC resources
```

## Components

### Infrastructure Components (Deployed via separate ArgoCD Applications)

| Component | Path | Description |
|-----------|------|-------------|
| ebs-csi-driver | `base/ebs-csi-driver/` | AWS EBS CSI Driver for dynamic volume provisioning |
| external-secrets | `base/external-secrets/` | ClusterSecretStore for AWS Secrets Manager |
| metrics-server | `base/metrics-server/` | Metrics API for HPA and kubectl top |
| shared-rbac | `base/shared-rbac/` | Cluster-scoped RBAC shared across environments |

### Kong API Gateway
- **deployment.yaml**: Kong Gateway deployment with Prometheus metrics
- **service.yaml**: Kong services (NodePort for proxy and admin API)
- **config.yaml**: Default Kong configuration
- **rbac.yaml**: RBAC rules for Kong service account

### Observability Stack
Complete monitoring stack:
- **prometheus/**: Metrics collection
- **grafana/**: Dashboards and visualization
- **loki/**: Log aggregation
- **promtail/**: Log collection DaemonSet
- **kube-state-metrics/**: Kubernetes object metrics
- **node-exporter/**: Node-level metrics

### Services
Each microservice contains:
- **deployment.yaml**: Kubernetes Deployment
- **service.yaml**: ClusterIP Service
- **kustomization.yaml**: Kustomize aggregation

## Key Concepts

1. **Base vs Overlays**: Base definitions without environment-specific values. Overlays apply environment-specific settings.
2. **Modular Design**: Each component is self-contained and deployed via its own ArgoCD Application
3. **Shared Configuration**: Resources here are inherited by staging and production overlays
4. **No Secrets**: Base files should NOT contain secrets (those are managed via External Secrets)
3. Microservices (in the order specified in kustomization.yaml)

