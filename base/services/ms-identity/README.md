# Identity Service - base/services/ms-identity/

This directory contains the deployment configuration for the KubeStock Identity/Authentication microservice.

## Files Overview

### kustomization.yaml
**Purpose**: Aggregates ms-identity service resources

**Includes**:
- deployment.yaml
- service.yaml

### deployment.yaml
**Purpose**: Identity service deployment specification

**Defines**:
- **Container image**: Identity service backend (Go, Java, or Node.js)
- **Replicas**: Base configuration (customized by overlays)
- **Port**: 8080 (default microservice port)
- **Health checks**: Liveness and readiness probes
- **Environment variables**: Database connection, JWT secrets (injected by overlays)
- **Service account**: Identity service identity
- **Resource limits**: CPU and memory constraints

**Responsibilities**:
- User registration and account creation
- User login and authentication
- JWT token generation and management
- Password reset and account recovery
- User profile management
- Role and permission assignment

### service.yaml
**Purpose**: Kubernetes service for ms-identity access

**Defines**:
- **Type**: ClusterIP (internal service)
- **Port**: 8080
- **Selector**: Routes to ms-identity pods
- **Service name**: `ms-identity`

**Use case**: Internal service for Kong and other services to communicate with identity service

## Service Responsibilities

### Authentication Endpoints
```
POST /users/register        → Create new user account
POST /users/login           → Authenticate user, return JWT token
POST /users/refresh-token   → Refresh expired JWT
POST /users/logout          → Invalidate user session
```

### User Management
```
GET /users/{id}             → Get user profile
PUT /users/{id}             → Update user profile
DELETE /users/{id}          → Delete user account
GET /users/{id}/permissions → Get user permissions/roles
```

### Password Management
```
POST /users/change-password → Change user password
POST /users/forgot-password → Initiate password reset
POST /users/reset-password  → Complete password reset
```

## Dependencies

- **Database**: PostgreSQL (connection details in secrets)
- **JWT Secret**: For signing and validating tokens (in secrets)
- **Redis** (optional): Session caching

## Environment-Specific Customizations

Overlays customize:
- **Replicas**: Production (2), Staging (1)
- **Image tag**: Different versions per environment
- **Database credentials**: Different database per environment
- **JWT secret**: Environment-specific JWT signing key
- **CORS origins**: Which frontends can call this service
- **Resources**: CPU/memory limits per environment

## Service Communication

```
Frontend/Kong
     ↓
ms-identity Service (Port 8080)
     ↓
Identity Pod
     ↓
PostgreSQL Database
```

## JWT Token Flow

1. User submits credentials to POST /users/login
2. Service validates against database
3. Service generates JWT token (signed with JWT secret)
4. Service returns JWT to client
5. Client includes JWT in subsequent API requests (Authorization header)
6. Kong/other services validate JWT signature using JWT secret
7. Services trust user identity from JWT claims

## Key Security Considerations

- **Password hashing**: Passwords never stored in plain text (bcrypt/Argon2)
- **JWT secrets**: Must be strong and kept in secrets (not in code)
- **Token expiration**: Tokens expire after configured duration
- **HTTPS only**: Should only accept secure connections
- **Rate limiting**: Protect login endpoint from brute force attacks
- **User isolation**: Users can only access their own data

## Debugging Identity Service

```bash
# View service logs
kubectl logs -n kubestock-production deployment/ms-identity -f

# Check service connectivity
kubectl exec -it <pod> -n kubestock-production -- curl http://ms-identity:8080/health

# Test login endpoint
kubectl port-forward -n kubestock-production svc/ms-identity 8080:8080
# Then: curl -X POST http://localhost:8080/users/login -d "{...}"
```
