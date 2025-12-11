# Environment-Specific Overlays - overlays/

This directory contains Kustomize overlays that customize the base manifests for specific environments (staging and production).

## Directory Structure

```
overlays/
├── staging/                    # Staging environment configuration
│   ├── kustomization.yaml      # Main overlay file
│   ├── namespace.yaml          # Staging namespace
│   ├── external-secrets.yaml   # ExternalSecret resources
│   ├── kong/                   # Kong API Gateway config
│   │   ├── kustomization.yaml
│   │   ├── kong-config.yaml    # Staging Kong routes
│   │   └── rbac-binding.yaml
│   └── observability-stack/    # Observability for staging
│       ├── kustomization.yaml
│       └── prometheus-config.yaml
└── production/                 # Production environment configuration
    ├── kustomization.yaml      # Main overlay file
    ├── namespace.yaml          # Production namespace
    ├── external-secrets.yaml   # ExternalSecret resources
    ├── kong/                   # Kong API Gateway config
    │   ├── kustomization.yaml
    │   ├── kong-config.yaml    # Production Kong routes
    │   └── rbac-binding.yaml
    └── observability-stack/    # Observability for production
        ├── kustomization.yaml
        ├── prometheus-config.yaml
        └── alertmanager/       # Alertmanager (production only)
```

## What are Overlays?

Overlays extend the base manifests with environment-specific configurations without modifying the base files. They allow the same application to be deployed to different environments with different settings.

## ArgoCD Applications

Each overlay is deployed by a dedicated ArgoCD Application:

| ArgoCD App | Overlay Path | Namespace |
|------------|--------------|-----------|
| `kubestock-staging` | `overlays/staging` | `kubestock-staging` |
| `kubestock-production` | `overlays/production` | `kubestock-production` |
| `kong-staging` | `overlays/staging/kong` | `kong-staging` |
| `kong-production` | `overlays/production/kong` | `kong` |
| `observability-staging` | `overlays/staging/observability-stack` | `observability-staging` |
| `observability-production` | `overlays/production/observability-stack` | `observability-production` |

## Common Modifications in Overlays

Overlays typically modify:

1. **Replicas**: Production uses 2+ replicas, staging uses 1
2. **Resource limits**: Production has stricter limits, staging is more relaxed
3. **Environment variables**: Different API endpoints, feature flags per environment
4. **Secrets**: Managed via External Secrets (different per environment)
5. **Labels**: Add environment labels (environment: production/staging)
6. **NodePorts**: Different ports for staging vs production services

## Staging vs Production Key Differences

| Aspect | Staging | Production |
|--------|---------|-----------|
| Replicas | 1 (cost savings) | 2+ (high availability) |
| Resource requests | Lower | Higher |
| Kong NodePort | 30081 | 30080 |
| Prometheus NodePort | 31090 | 30090 |
| Grafana NodePort | 31300 | 30300 |
| Alertmanager | Not deployed | Deployed (30093) |
| Kong CORS origins | Wildcard (*) | kubestock.dpiyumal.me |

