# Environment-Specific Overlays - overlays/

This directory contains Kustomize overlays that customize the base manifests for specific environments (staging and production).

## Directory Structure

```
overlays/
├── staging/                # Staging environment configuration
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── secrets.yaml
│   ├── kong-config.yaml
│   └── README.md
└── production/             # Production environment configuration
    ├── kustomization.yaml
    ├── namespace.yaml
    ├── secrets.yaml
    ├── kong-config.yaml
    └── README.md
```

## What are Overlays?

Overlays extend the base manifests with environment-specific configurations without modifying the base files. They allow the same application to be deployed to different environments with different settings.

## Common Modifications in Overlays

Overlays typically modify:

1. **Replicas**: Production uses 2+ replicas, staging uses 1
2. **Resource limits**: Production has stricter limits, staging is more relaxed
3. **Environment variables**: Different API endpoints, feature flags per environment
4. **Secrets**: Database passwords, API keys (different per environment)
5. **Ingress/Routes**: Different hostnames and SSL certs
6. **Labels**: Add environment labels (environment: production/staging)
7. **Patches**: Modify specific fields in base manifests

## Deployment Workflow

```
1. Base Manifests (base/)
           ↓ (patched and customized by)
2. Overlay Configuration (overlays/staging or overlays/production)
           ↓ (processed by)
3. Kustomize
           ↓ (generates)
4. Final Kubernetes Manifests
           ↓ (applied to)
5. Kubernetes Cluster
```

## Key Files in Each Overlay

### kustomization.yaml
- References base manifests
- Applies patches
- Sets namespace
- Defines image tags
- Adds labels

### namespace.yaml
- Environment-specific namespace definition
- Can include resource quotas
- Network policies

### secrets.yaml
- Environment-specific secrets (database passwords, API keys)
- Should be encrypted/sealed in production

### kong-config.yaml
- Kong-specific routing and plugin configurations
- Environment-specific routes (different backends per environment)
- CORS settings for staging vs production

## Staging vs Production Key Differences

| Aspect | Staging | Production |
|--------|---------|-----------|
| Replicas | 1 (cost savings) | 2+ (high availability) |
| Resource requests | Lower | Higher |
| Resource limits | Relaxed | Strict |
| Update strategy | Immediate | Careful, rolling |
| Secrets | Development/test secrets | Real production secrets |
| Kong config | Test routes | Production routes |
| Monitoring | Basic | Comprehensive |

