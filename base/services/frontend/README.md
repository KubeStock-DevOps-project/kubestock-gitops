# Frontend Service - base/services/frontend/

This directory contains the deployment configuration for the KubeStock React frontend application.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates frontend service resources

**Includes**:
- deployment.yaml
- service.yaml

### deployment.yaml
**Purpose**: Frontend application deployment specification

**Defines**:
- **Container image**: Nginx serving React static files
- **Replicas**: Base configuration (customized by overlays)
- **Port**: 80 (HTTP)
- **Health checks**: Liveness and readiness probes
- **Volume mounts**: Nginx configuration
- **Service account**: Frontend identity

**Responsibilities**:
- Serve the React single-page application
- Handle static assets (CSS, JavaScript, images)
- Proxy API requests to Kong gateway

### service.yaml
**Purpose**: Kubernetes service for frontend access

**Defines**:
- **Type**: ClusterIP (internal service)
- **Port**: 80
- **Selector**: Routes to frontend pods
- **Service name**: `frontend`

**Use case**: Internal service for Kong to route frontend requests

## Frontend Architecture

```
Client Browser
     ↓
  Kong Proxy (Port 30080)
     ↓
Frontend Service (Port 80)
     ↓
Nginx Pod serving React SPA
     ↓
React App (JavaScript)
     ↓
API calls back to Kong
```

## Environment-Specific Customizations

Overlays customize:
- **Replicas**: Production (2), Staging (1)
- **Image tag**: Different versions per environment
- **Environment variables**: API endpoints, feature flags
- **Resources**: CPU/memory limits per environment

## Key Features

- **Single Page Application**: React app loaded once, fast navigation
- **Static content**: CSS, JavaScript, images served by Nginx
- **API proxying**: Frontend makes API calls through Kong gateway
- **Responsive design**: Works on desktop, tablet, mobile
- **Asset optimization**: Static files can be cached by CDN

## Debugging Frontend Issues

```bash
# View frontend logs
kubectl logs -n kubestock-production deployment/frontend

# Check frontend service
kubectl get svc frontend -n kubestock-production

# Access frontend pod
kubectl exec -it <frontend-pod> -n kubestock-production -- /bin/sh

# Check Nginx configuration
kubectl exec -it <frontend-pod> -n kubestock-production -- cat /etc/nginx/nginx.conf
```
