# Istio Service Mesh Configuration for KubeStock

## Overview

This document outlines the Istio service mesh setup for KubeStock, including automatic mTLS encryption between all microservices.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    kubestock-staging Namespace              │
│  (Istio Sidecar Injection Enabled)                          │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Frontend    │  │ ms-identity  │  │ ms-inventory │      │
│  │  (Port 3000) │  │ (Port 3006)  │  │ (Port 3001)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                │                    │             │
│         └────────────────┼────────────────────┘             │
│                          │                                   │
│              Istio Control Plane (Envoy Proxies)            │
│              - mTLS Enforcement (STRICT mode)               │
│              - Traffic Routing (VirtualServices)            │
│              - Circuit Breaking & Retries                   │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         │                │                │                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ ms-product   │  │ ms-supplier  │  │ms-order-mgmt │      │
│  │ (Port 3003)  │  │ (Port 3004)  │  │ (Port 3002)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Key Components Configured

### 1. Namespace Labels

- **File**: `gitops/base/namespaces/staging.yaml`
- **Label**: `istio-injection: enabled`
- **Effect**: Automatically injects Envoy sidecars into all pods

### 2. mTLS Configuration (STRICT mode)

- **File**: `gitops/base/istio/peer-authentication-strict.yaml`
- **Policy**: All pod-to-pod communication requires mutual TLS
- **Scope**: Cluster-wide enforcement

**YAML:**

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

### 3. DestinationRules (per service)

Each microservice has a `DestinationRule` that specifies mTLS requirements:

**File Pattern**: `gitops/base/services/{service}/istio-destinationrule.yaml`

**Example (ms-identity):**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: ms-identity-destination
  labels:
    app: ms-identity
spec:
  host: ms-identity
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL # Enables mTLS between envoy sidecars
```

### 4. VirtualServices (per service)

Each microservice has a `VirtualService` for traffic routing and resilience:

**File Pattern**: `gitops/base/services/{service}/istio-virtualservice.yaml`

**Example (ms-identity):**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ms-identity
spec:
  hosts:
    - ms-identity
  http:
    - route:
        - destination:
            host: ms-identity
            port:
              number: 3006
          weight: 100
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
```

## Services Configured

| Service             | Port | DestinationRule | VirtualService |
| ------------------- | ---- | --------------- | -------------- |
| ms-identity         | 3006 | ✓               | ✓              |
| ms-inventory        | 3001 | ✓               | ✓              |
| ms-product          | 3003 | ✓               | ✓              |
| ms-supplier         | 3004 | ✓               | ✓              |
| ms-order-management | 3002 | ✓               | ✓              |
| frontend            | 3000 | ✓               | ✓              |

## Installation Prerequisites

### 1. Install Istio

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with default profile
istioctl install --set profile=demo -y
```

### 2. Verify Istio Installation

```bash
# Check Istio namespaces
kubectl get namespaces | grep istio

# Verify control plane is running
kubectl get pods -n istio-system

# Verify Istio CRDs
kubectl api-resources | grep istio
```

## Deployment Flow

### Step 1: Apply Base Configuration

```bash
# Deploy the base kustomization (includes istio configs)
kubectl apply -k gitops/base/
```

### Step 2: Apply Staging Overlay

```bash
# Deploy staging overlay with service configurations
kubectl apply -k gitops/overlays/staging/
```

### Step 3: Verify Sidecars

```bash
# Check if sidecars are injected
kubectl get pods -n kubestock-staging -o jsonpath='{.items[*].spec.containers[*].name}' | tr ' ' '\n' | sort | uniq

# Should see output like: istio-proxy, ms-identity, etc.
```

### Step 4: Test mTLS

```bash
# Check if mTLS is enforced by examining sidecar configuration
kubectl exec -it <pod-name> -n kubestock-staging -c istio-proxy -- \
  curl localhost:15000/config_dump | grep mtls
```

## File Structure

```
gitops/
├── base/
│   ├── istio/
│   │   ├── kustomization.yaml
│   │   └── peer-authentication-strict.yaml
│   └── services/
│       ├── ms-identity/
│       │   ├── istio-destinationrule.yaml
│       │   ├── istio-virtualservice.yaml
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       ├── ms-inventory/
│       │   ├── istio-destinationrule.yaml
│       │   ├── istio-virtualservice.yaml
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       ├── ms-product/
│       ├── ms-supplier/
│       ├── ms-order-management/
│       └── frontend/
├── namespaces/
│   └── staging.yaml (with istio-injection: enabled label)
```

## Security Properties

### mTLS Features

- ✅ Automatic certificate generation and rotation
- ✅ Pod-to-pod encryption in transit
- ✅ Service identity verification
- ✅ Prevents unauthorized service communication

### Traffic Management

- ✅ Automatic retries (3 attempts, 10s timeout per attempt)
- ✅ Circuit breaking ready via DestinationRule enhancements
- ✅ Timeout enforcement (30s per request)
- ✅ Load balancing (round-robin by default)

## Monitoring & Observability

### Verify mTLS Status

```bash
# Check PeerAuthentication policy
kubectl get peerauthentication -A

# Check DestinationRules
kubectl get destinationrules -n kubestock-staging

# Check VirtualServices
kubectl get virtualservices -n kubestock-staging
```

### Debug Connectivity Issues

```bash
# Test pod-to-pod communication
kubectl exec -it <source-pod> -n kubestock-staging -- \
  curl http://ms-identity:3006/health

# Check sidecar logs
kubectl logs <pod-name> -n kubestock-staging -c istio-proxy

# Check control plane connectivity
kubectl exec -it <pod-name> -n kubestock-staging -c istio-proxy -- \
  curl localhost:15000/config_dump | grep "ms-identity"
```

## Production Considerations

### 1. Network Policies (Optional)

Consider adding Kubernetes NetworkPolicies alongside Istio for defense-in-depth.

### 2. Resource Requests/Limits

Sidecars add resource overhead (~50MB memory per pod). Ensure node resources are adequate.

### 3. Service Entry for External Services

If services need to communicate with external APIs, create ServiceEntry resources.

### 4. Mesh Observability

Deploy Kiali, Jaeger, and Prometheus for full mesh observability:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.x/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.x/samples/addons/jaeger.yaml
```

### 5. Certificate Rotation

Istio automatically manages certificate rotation. No manual intervention needed.

## Troubleshooting

### Issue: Sidecars not injected

**Solution**: Verify `istio-injection: enabled` label on namespace

```bash
kubectl label namespace kubestock-staging istio-injection=enabled --overwrite
```

### Issue: mTLS connection refused

**Solution**: Ensure `PeerAuthentication` mode matches service expectations

```bash
kubectl get peerauthentication -n istio-system -o yaml
```

### Issue: High latency after mesh deployment

**Solution**:

- Check sidecar resource requests/limits
- Verify network policies aren't blocking traffic
- Monitor sidecar CPU/memory usage

## Next Steps

1. **ArgoCD Integration**: Update ArgoCD Application manifests to include Istio configs
2. **Service Entries**: Add ServiceEntry for external service integrations
3. **Rate Limiting**: Implement RequestAuthentication + AuthorizationPolicy
4. **Observability**: Deploy Kiali and Jaeger for visualization
5. **Circuit Breaker**: Add OutlierDetection to DestinationRules for resilience

## References

- [Istio Official Documentation](https://istio.io/latest/docs/)
- [mTLS Configuration](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)
- [Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Authorization Policies](https://istio.io/latest/docs/tasks/security/authorization/authz-of-tcp-traffic/)
