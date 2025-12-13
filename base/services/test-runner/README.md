# Test Runner Service - Kubernetes Base Configuration

## Overview
The test-runner service provides automated smoke and load testing capabilities using k6.
It integrates with Asgardeo for authentication and can be triggered manually or via ArgoCD hooks.

## Features
- **Smoke Tests**: Quick health checks through Kong Gateway
- **Load Tests**: Performance testing with configurable VUs and stages
- **k6 Integration**: Native Grafana/Prometheus metrics support
- **ArgoCD Hooks**: Post-deployment automated testing

## Configuration

### Secrets Required
The service requires a `test-runner-secret` with the following keys:
- `ASGARDEO_TOKEN_URL`: Token endpoint URL
- `ASGARDEO_TEST_CLIENT_ID`: OAuth client ID (password grant enabled)
- `ASGARDEO_TEST_CLIENT_SECRET`: OAuth client secret
- `ASGARDEO_USERNAME`: Test user email/username
- `ASGARDEO_PASSWORD`: Test user password

### Environment Variables
- `GATEWAY_URL`: Kong Gateway URL (defaults to staging Kong service)
- Service URLs are auto-configured based on namespace

## Usage

### Manual Test Execution
```bash
kubectl exec -n kubestock-staging deployment/test-runner -- \
  curl -X POST http://localhost:3007/api/tests/run \
  -H "Content-Type: application/json" \
  -d '{"testType": "smoke"}'
```

### ArgoCD Hook
Tests are automatically triggered after successful deployments via ArgoCD hooks.

## Metrics
The service exposes Prometheus-compatible metrics on port 3007 at `/metrics`.
k6 test results are also available in Prometheus format.
