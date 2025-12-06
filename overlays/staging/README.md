# Staging Environment Overlay - overlays/staging/

This directory contains Kustomize overlays specific to the staging environment. These configurations customize the base manifests for testing and pre-production validation.

## Files Overview

### kustomization.yaml
**Purpose**: Main Kustomize configuration for staging

**Specifies**:
- **Base reference**: Points to `../../base/` for base manifests
- **Namespace**: `kubestock-staging` (all resources deployed here)
- **Labels**: Adds `environment: staging` label to all resources
- **Patches**: 
  - Reduces replicas to 1 for all deployments (cost savings)
  - Sets staging-specific environment variables
- **ConfigMaps**: Staging-specific application configuration
- **Image tags**: Staging image versions (may differ from production)

**Customizations applied**:
- All base microservices and Kong gateway are configured for staging
- Resources use staging container images
- Staging namespace isolation

### namespace.yaml
**Purpose**: Staging environment namespace definition

**Creates**: `kubestock-staging` namespace

**Includes**:
- Namespace metadata with staging labels
- Resource quotas (optional) to limit staging resource consumption
- Network policies (optional) to restrict traffic

**Use case**: Provides isolated namespace for staging deployments with proper labeling for tracking

### secrets.yaml
**Purpose**: Staging-specific secrets and configuration

**Contains** (typically):
- Database credentials (staging database)
- API keys for third-party services (staging versions)
- TLS certificates for staging domains
- Feature flags for staging
- Logging credentials

**Important**: Should be encrypted using Sealed Secrets or similar in production repositories

**Examples**:
- `POSTGRES_PASSWORD`: Staging database password
- `JWT_SECRET`: JWT signing key for staging
- `API_KEY`: Third-party API keys for staging environment

### kong-config.yaml
**Purpose**: Kong API Gateway configuration for staging

**Defines**:
- **Routes**: Routes to staging microservices (e.g., `staging-api.example.com/users` → ms-identity service)
- **Upstreams**: Backend service definitions
- **Plugins**: 
  - Rate limiting (staging limits)
  - CORS (staging domains: `localhost:3000`, `staging.example.com`)
  - Authentication (staging JWT validation)
  - Logging (staging log endpoints)
  - Prometheus metrics collection
- **CORS settings**: Allows requests from:
  - `http://localhost:3000` (local development)
  - `https://staging.example.com` (staging frontend)

**Example route**:
```
GET /staging/products → ms-product:8080/products
GET /staging/orders → ms-order-management:8080/orders
GET /staging/users → ms-identity:8080/users
```

## Staging Environment Characteristics

1. **Cost-optimized**: Single replica deployments
2. **Development-friendly**: Relaxed CORS and security policies
3. **Testing purpose**: Validates application behavior before production
4. **Shared resource**: Multiple developers may deploy simultaneously
5. **Auto-sync**: Changes to Git automatically deployed

## Common Staging Use Cases

- **Feature testing**: Test new features before production release
- **Regression testing**: Validate that fixes don't break existing functionality
- **Performance testing**: Measure application performance under load
- **Integration testing**: Test microservice interactions
- **UAT (User Acceptance Testing)**: Allow stakeholders to validate features
- **Database migrations**: Test schema changes safely

## Accessing Staging

```bash
# View staging deployments
kubectl get deployments -n kubestock-staging

# View staging services
kubectl get services -n kubestock-staging

# View staging pods
kubectl get pods -n kubestock-staging

# Access staging frontend
# https://staging.example.com (if ingress configured)
```

## CI/CD Integration

Typically:
1. Developers push to feature branch
2. CI/CD pipeline runs tests
3. Successful tests trigger staging deployment
4. Code review and QA testing in staging
5. After approval, merged to main
6. Main branch automatically synced to production

