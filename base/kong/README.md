# Kong API Gateway - base/kong/

This directory contains the Kong API Gateway configuration for the KubeStock platform.

## Architecture Overview

Kong serves as the **sole ingress controller** for all external traffic:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Traffic Flow                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Internet → NLB → Kong (30080/30081) → Service → Istio Sidecar → App        │
│                                                                              │
│  Kong handles:                    │  Istio handles:                         │
│  ├─ Path routing (/api/*)         │  ├─ mTLS between services               │
│  ├─ Path stripping                │  ├─ JWT signature verification          │
│  ├─ CORS                          │  └─ Authorization policies              │
│  ├─ Rate limiting                 │                                          │
│  └─ JWT aud/iss claim check       │                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Security Layers

1. **Kong (Edge)**: Checks JWT aud/iss claims (fast reject for wrong audience)
2. **Istio Sidecar**: Verifies JWT signature using JWKS endpoint
3. **AuthorizationPolicy**: Denies requests without valid requestPrincipal

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
  - 9542: Prometheus metrics
- **Health checks**: Liveness and readiness probes
- **Monitoring**: Prometheus scrape annotations

### service.yaml
**Purpose**: Kong service definitions for traffic routing

**Defines**:

1. **kong-proxy** (Main Service)
   - Type: NodePort
   - Port 80 → 8000 (HTTP proxy, exposed on node port 30080 prod / 30081 staging)
   - Port 443 → 8443 (HTTPS proxy, exposed on node port 30444 prod / 30445 staging)
   - Used for all API traffic from clients

2. **kong-admin** (Admin Service)
   - Type: ClusterIP (internal only)
   - Port 8001 (HTTP admin API)
   - Used for Kong status checks

3. **kong-metrics** (Metrics Service)
   - Type: ClusterIP
   - Port 9542
   - Used for Prometheus scraping

### config.yaml
**Purpose**: Kong declarative configuration (routes, plugins)

**Contains**:
- Route definitions with path stripping
- Rate limiting per service
- CORS configuration
- JWT aud/iss claim validation (pre-function plugin)
- Prometheus metrics plugin

### rbac.yaml
**Purpose**: Kubernetes RBAC for Kong

**Defines**:
- **ServiceAccount**: Kong identity in the cluster
- ClusterRole/Binding managed in overlays

## Environment Overlays

### Production (overlays/production/kong/)
- NodePort: 30080 (HTTP), 30444 (HTTPS)
- CORS: https://kubestock.dpiyumal.me
- Namespace: kong

### Staging (overlays/staging/kong/)
- NodePort: 30081 (HTTP), 30445 (HTTPS)
- CORS: * (wildcard for dev access)
- Namespace: kong-staging

## JWT Validation

Kong validates JWT claims **without signature verification**:
- Checks `iss` matches Asgardeo issuer
- Checks `aud` includes valid application client IDs
- Fast rejection of tokens meant for other applications

Signature verification is handled by Istio sidecars using JWKS.

## Traffic Flow

1. **External requests** → NLB (port 80/81) → Kong NodePort
2. **Kong** → Routes to service, strips path prefix
3. **Service** → Pods with Istio sidecar
4. **Istio sidecar** → mTLS + JWT verification → Application

