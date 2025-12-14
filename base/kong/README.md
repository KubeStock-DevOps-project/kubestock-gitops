# Kong API Gateway - base/kong/

This directory contains the Kong API Gateway configuration for the KubeStock platform.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates Kong resources for Kustomize

**Includes**:
- rbac.yaml
- deployment.yaml
- service.yaml
- config.yaml

### deployment.yaml
**Purpose**: Kong Gateway Deployment specification

**Defines**:
- **Container**: Kong API Gateway image
- **Replicas**: 2 instances for high availability
- **Strategy**: Rolling updates (maxSurge: 1, maxUnavailable: 0) for zero-downtime updates
- **Ports**:
  - 8000: HTTP proxy (for API traffic)
  - 8443: HTTPS proxy (for secure API traffic)
  - 8001: Admin API (HTTP)
  - 8444: Admin API (HTTPS)
  - 9542: Prometheus metrics
- **Health checks**: Liveness and readiness probes
- **Monitoring**: Prometheus scrape annotations
- **Labels**: For traffic routing and identification

### service.yaml
**Purpose**: Kong service definitions for traffic routing

**Defines two services**:

1. **kong-proxy** (Main Service)
   - Type: NodePort
   - Port 80 → 8000 (HTTP proxy, exposed on node port 30080)
   - Port 443 → 8443 (HTTPS proxy, exposed on node port 30444)
   - Used for all API traffic from clients

2. **kong-admin** (Admin Service)
   - Type: ClusterIP (internal only)
   - Port 8001 (HTTP admin API)
   - Port 8444 (HTTPS admin API)
   - Used for Kong configuration management

### config.yaml
**Purpose**: Kong configuration (routes, upstreams, plugins)

**May contain**:
- Route definitions (HTTP routes to backend services)
- Upstream definitions (backend service groups)
- Plugin configurations (authentication, rate limiting, CORS, etc.)
- Rate limiting policies
- CORS settings for frontend

### rbac.yaml
**Purpose**: Kubernetes RBAC for Kong

**Defines**:
- **ServiceAccount**: Kong identity in the cluster
- **ClusterRole**: Permissions Kong needs (e.g., read ConfigMaps for configuration)
- **ClusterRoleBinding**: Binds the role to the Kong service account

**Permissions**: Kong needs to read ConfigMaps and Secrets for:
- Routes and plugin configuration
- TLS certificates
- Upstream service discovery

## How Kong Works in KubeStock

1. **Traffic Flow**: External requests → kong-proxy (NodePort 30080/30444) → Kong routes → Backend services
2. **Configuration**: Kong gets routes and plugins from Kubernetes ConfigMaps
3. **Admin API**: Used by CI/CD or management tools to configure Kong dynamically
4. **Monitoring**: Prometheus scrapes metrics from port 9542

## Common Modifications

- **Replica count**: Change in `deployment.yaml` for scaling
- **Routes/plugins**: Update in `config.yaml`
- **SSL certificates**: Add to Kong via TLS secrets
- **Rate limiting**: Configure in config.yaml plugins section

