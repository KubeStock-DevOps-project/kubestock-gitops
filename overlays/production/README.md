# Production Environment Overlay - overlays/production/

This directory contains Kustomize overlays specific to the production environment. These configurations optimize the base manifests for performance, reliability, and security in production.

## Files Overview

### kustomization.yaml
**Purpose**: Main Kustomize configuration for production

**Specifies**:
- **Base reference**: Points to `../../base/` for base manifests
- **Namespace**: `kubestock-production` (all resources deployed here)
- **Labels**: Adds `environment: production` label to all resources
- **Patches**: 
  - Increases replicas to 2 for all deployments (high availability)
  - Sets production-specific environment variables
  - Applies resource requests and limits for stability
- **ConfigMaps**: Production-specific application configuration
- **Image tags**: Production image versions (stable, tested releases)
- **Rolling Update Strategy**: 
  - maxSurge: 1 (one extra pod during updates)
  - maxUnavailable: 0 (no downtime during updates)

**Customizations applied**:
- All microservices configured for production with 2+ replicas
- Kong gateway scaled for production traffic
- Production namespace isolation
- Strict resource management

### namespace.yaml
**Purpose**: Production environment namespace definition

**Creates**: `kubestock-production` namespace

**Includes**:
- Namespace metadata with production labels
- Resource quotas to control production resource consumption
- Network policies for security (restrict traffic to necessary services)
- RBAC configurations (limited admin access)

**Use case**: Isolates production from other environments with strict controls

### secrets.yaml
**Purpose**: Production-specific secrets and sensitive configuration

**Contains** (typically):
- **Database credentials**: Production RDS/PostgreSQL passwords
- **API keys**: Third-party service keys (production accounts)
- **TLS certificates**: SSL/TLS certs for production domains
- **JWT secrets**: Production JWT signing keys
- **Service credentials**: Database, cache, queue service credentials
- **Feature flags**: Production feature toggles

**Important**: 
- Should be encrypted using Sealed Secrets, Vault, or similar
- Never commit unencrypted secrets to Git
- Rotate regularly
- Audit access logs

**Examples**:
- `POSTGRES_HOST`: `prod-db.rds.amazonaws.com`
- `POSTGRES_PASSWORD`: [Encrypted production password]
- `JWT_SECRET`: [Encrypted production JWT key]
- `API_KEY_STRIPE`: [Encrypted Stripe API key]

### kong-config.yaml
**Purpose**: Kong API Gateway configuration for production

**Defines**:
- **Routes**: Production routes to microservices (e.g., `kubestock.dpiyumal.me/api/*` → services)
- **Upstreams**: Backend service groups with load balancing
- **Plugins**:
  - **Rate limiting**: Strict rate limits to prevent abuse
  - **CORS**: Limited to production domains only (`kubestock.dpiyumal.me`)
  - **Authentication**: JWT validation for protected endpoints
  - **Request validation**: Ensure incoming requests match expected format
  - **Response transformation**: Add security headers
  - **Logging**: Send logs to production logging service
  - **Prometheus metrics**: Metrics for monitoring and alerting
  - **API key authentication**: For service-to-service calls
- **SSL/TLS**: HTTPS enforcement with valid certificates

**Example route**:
```
GET https://kubestock.dpiyumal.me/api/products → ms-product service
GET https://kubestock.dpiyumal.me/api/orders → ms-order-management service
GET https://kubestock.dpiyumal.me/api/users → ms-identity service
POST https://kubestock.dpiyumal.me/api/inventory → ms-inventory service
```

**Security features**:
- CORS restricted to production domain
- Rate limiting per IP/API key
- HTTPS only
- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- API key validation for backend services

## Production Environment Characteristics

1. **High Availability**: 2+ replicas of each service
2. **Performance Optimized**: Adequate resource allocation
3. **Security Focused**: Encrypted secrets, strict CORS, rate limiting
4. **Reliability**: Rolling update strategy with zero downtime
5. **Monitoring**: Comprehensive logging and metrics
6. **Manual Control**: Careful rollout process (not auto-sync)

## Production Safeguards

```
Code Change
    ↓
Staging Deployment (tested here)
    ↓
Code Review & Approval (required)
    ↓
Manual Production Sync (careful rollout)
    ↓
Health Checks & Monitoring
    ↓
Production Live
```

## Key Production Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Replicas | 2+ | High availability |
| Update strategy | Rolling, 0 unavailable | Zero downtime |
| CORS | production domain only | Security |
| Rate limiting | Strict | Prevent abuse |
| Secrets | Encrypted | Protect credentials |
| Monitoring | Prometheus + logs | Visibility |
| Rollback | Available | Quick recovery from issues |

## Accessing Production

```bash
# View production deployments (if you have access)
kubectl get deployments -n kubestock-production

# Monitor production services
kubectl get services -n kubestock-production

# Check pod health
kubectl get pods -n kubestock-production

# View production logs (with proper RBAC)
kubectl logs -n kubestock-production -l app=ms-product
```

## Production Deployment Process

1. **Code merged to main** in source repository
2. **CI/CD pipeline runs tests** (unit, integration, security)
3. **Build production images** and push to registry
4. **ArgoCD detects changes** in gitops repo
5. **Manual approval required** (configured in ArgoCD)
6. **Rolling update begins** (one pod at a time)
7. **Health checks validate** each update
8. **Monitoring alerts** for any anomalies

## Monitoring & Alerts

Production monitoring includes:
- **Pod health**: CPU, memory, restart counts
- **Application metrics**: Response times, error rates
- **Security**: Failed auth attempts, rate limit violations
- **Database**: Connection pools, slow queries
- **Network**: Latency, packet loss
- **System**: Node health, disk space

