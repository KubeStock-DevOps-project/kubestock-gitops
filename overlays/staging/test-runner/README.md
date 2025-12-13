# Test Runner Deployment Guide

## Overview
The test-runner service has been successfully configured for deployment to the Kubernetes cluster. It provides automated smoke testing capabilities using k6 and integrates with ArgoCD for post-deployment validation.

## Architecture

### Components
1. **Test Runner Service** - Node.js Express server that orchestrates k6 tests
2. **k6 Test Engine** - Embedded k6 for executing smoke and load tests
3. **External Secrets Operator** - Fetches credentials from AWS Secrets Manager
4. **ArgoCD Integration** - Post-sync hooks for automated testing
5. **Observability** - Prometheus metrics and Grafana dashboards

### Namespace
- **Staging**: `kubestock-staging`
- Test-runner is deployed as a separate microservice alongside other services

## Secrets Configuration

### AWS Secrets Manager
Credentials are stored in AWS Secrets Manager:
- **Path**: `kubestock/shared/test-runner`
- **Keys**:
  - `client_id` - Asgardeo OAuth client ID (password grant enabled)
  - `client_secret` - Asgardeo OAuth client secret
  - `username` - Test user email/username
  - `password` - Test user password

### Token URL
The `ASGARDEO_TOKEN_URL` is fetched from the existing staging Asgardeo secret:
- **Path**: `kubestock/staging/asgardeo`
- **Key**: `ASGARDEO_TOKEN_URL`
- **Value**: `https://api.asgardeo.io/t/kubestock/oauth2/token`

### ExternalSecret
The `test-runner-secret` ExternalSecret automatically syncs these values into Kubernetes.

## Deployment Structure

```
gitops/
├── base/services/test-runner/
│   ├── deployment.yaml          # Base deployment configuration
│   ├── service.yaml             # ClusterIP service
│   ├── kustomization.yaml       # Base kustomization
│   └── README.md                # Service documentation
├── overlays/staging/test-runner/
│   ├── kustomization.yaml       # Staging-specific configuration
│   ├── externalsecret.yaml      # AWS Secrets Manager integration
│   ├── post-sync-hook.yaml      # ArgoCD post-deployment test hook
│   └── k6-config.yaml           # k6 Prometheus configuration
└── apps/staging/
    └── test-runner-staging.yaml # ArgoCD Application manifest
```

## ArgoCD Integration

### Post-Deployment Hook
The `post-sync-hook.yaml` defines a Kubernetes Job that:
1. Runs after every successful ArgoCD sync of the staging environment
2. Waits 15 seconds for services to stabilize
3. Triggers smoke tests via the test-runner API
4. Reports success/failure to ArgoCD

### Hook Annotations
```yaml
argocd.argoproj.io/hook: PostSync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

## Smoke Tests

### Test Flow
1. Gateway health check (`/api/gateway/health`)
2. Product service (`/api/product`)
3. Inventory service (`/api/inventory`)
4. Supplier service (`/api/supplier`)
5. Order Management service (`/api/order`)
6. Identity service (`/api/identity/health`)

### Gateway URL
Tests run through Kong Gateway:
```
http://kong-proxy.kubestock-staging.svc.cluster.local:8000
```

## Observability Integration

### Prometheus Metrics
- Test-runner exposes metrics on port 3007 at `/metrics`
- Prometheus scrapes these metrics via pod annotations
- k6 test results are logged in structured format

### Grafana Dashboards
k6 metrics can be visualized in Grafana:
- Use Grafana's k6 dashboard (ID: 10660)
- Query Prometheus for test execution metrics
- View test logs in Loki

### Future Enhancement: k6 Prometheus Remote Write
To enable direct k6 metric export to Prometheus:
1. Update k6 command in server.js to include `--out experimental-prometheus-rw`
2. Configure remote write endpoint in k6
3. Metrics will appear directly in Prometheus

## Deployment Steps

### 1. Build and Push Docker Image
```bash
cd services/test-runner
docker build -t 478468757808.dkr.ecr.ap-south-1.amazonaws.com/kubestock/test-runner:latest .
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 478468757808.dkr.ecr.ap-south-1.amazonaws.com
docker push 478468757808.dkr.ecr.ap-south-1.amazonaws.com/kubestock/test-runner:latest
```

### 2. Deploy via ArgoCD
```bash
# Apply the ArgoCD Application
kubectl apply -f gitops/apps/staging/test-runner-staging.yaml

# Watch deployment
kubectl get app -n argocd test-runner-staging -w

# Check sync status
argocd app get test-runner-staging
```

### 3. Verify Deployment
```bash
# Check pods
kubectl get pods -n kubestock-staging -l app=test-runner

# Check external secret
kubectl get externalsecret -n kubestock-staging test-runner-secret
kubectl get secret -n kubestock-staging test-runner-secret

# Check service
kubectl get svc -n kubestock-staging test-runner

# View logs
kubectl logs -n kubestock-staging -l app=test-runner -f
```

### 4. Manual Test Execution
```bash
# Port forward to test-runner
kubectl port-forward -n kubestock-staging svc/test-runner 3007:3007

# Trigger smoke test
curl -X POST http://localhost:3007/api/tests/run \
  -H "Content-Type: application/json" \
  -d '{"testType":"smoke","vus":1,"duration":"10s"}'

# Check test status
curl http://localhost:3007/api/tests/<testId>/status

# Get test logs
curl http://localhost:3007/api/tests/<testId>/logs
```

## Automated Testing Flow

### Trigger Flow
1. CI/CD pipeline updates image tags in `overlays/staging/kustomization.yaml`
2. ArgoCD detects changes and syncs the staging environment
3. After successful sync, ArgoCD triggers the post-sync hook Job
4. Hook Job calls test-runner API to execute smoke tests
5. Test-runner authenticates with Asgardeo using test user credentials
6. k6 executes smoke tests through Kong Gateway
7. Results are logged and available via Prometheus/Grafana
8. ArgoCD marks deployment as successful/failed based on hook result

### Manual Trigger
You can also manually trigger tests:
```bash
kubectl exec -n kubestock-staging deployment/test-runner -- \
  curl -X POST http://localhost:3007/api/tests/run \
  -H "Content-Type: application/json" \
  -d '{"testType":"smoke"}'
```

## Monitoring and Troubleshooting

### Check External Secret Sync
```bash
kubectl describe externalsecret -n kubestock-staging test-runner-secret
kubectl get secret -n kubestock-staging test-runner-secret -o yaml
```

### View Test Results
```bash
# Via Prometheus
kubectl port-forward -n observability svc/prometheus 9090:9090
# Open http://localhost:9090 and query for test-runner metrics

# Via Grafana
kubectl port-forward -n observability svc/grafana 3000:3000
# Open http://localhost:3000 and view k6 dashboard
```

### Debug Failed Tests
```bash
# Check test-runner logs
kubectl logs -n kubestock-staging -l app=test-runner --tail=100

# Check post-sync hook Job
kubectl get jobs -n kubestock-staging
kubectl logs -n kubestock-staging job/post-sync-smoke-test

# Manually trigger test with debugging
kubectl exec -it -n kubestock-staging deployment/test-runner -- sh
# Inside container:
curl -X POST http://localhost:3007/api/tests/run \
  -H "Content-Type: application/json" \
  -d '{"testType":"smoke","vus":1,"duration":"5s"}'
```

## Security Considerations

### Credentials Management
- ✅ Secrets stored in AWS Secrets Manager
- ✅ External Secrets Operator manages sync
- ✅ Test user has minimal permissions (read-only on services)
- ✅ OAuth client uses password grant (enabled only for test client)

### Network Security
- Test-runner runs within cluster network
- Uses internal service DNS for communication
- Kong Gateway handles external traffic routing

## Future Enhancements

### 1. S3 Test Result Storage
- Store k6 results in S3 for long-term analysis
- Configure lifecycle policies for retention
- Enable historical trend analysis

### 2. Enhanced Prometheus Integration
- Implement k6 Prometheus remote write
- Create custom Prometheus recording rules
- Setup alerts for test failures

### 3. Grafana Dashboard
- Import k6 dashboard (ID: 10660)
- Create custom test result dashboard
- Setup notifications for test failures

### 4. Production Environment
- Create production overlay for test-runner
- Configure separate test credentials
- Adjust test frequency and thresholds

### 5. Load Testing
- Schedule periodic load tests
- Integrate with autoscaling policies
- Performance regression detection

## Maintenance

### Updating Test Scripts
1. Modify k6 scripts in `services/test-runner/src/k6/`
2. Rebuild Docker image
3. Push to ECR
4. ArgoCD will auto-sync the new image

### Rotating Credentials
1. Update AWS Secrets Manager secret
2. External Secrets Operator will auto-sync (1h refresh interval)
3. Restart test-runner pods if immediate refresh needed:
   ```bash
   kubectl rollout restart -n kubestock-staging deployment/test-runner
   ```

### Scaling
The test-runner service is designed to run as a single replica. For concurrent test execution:
- Scale horizontally: `kubectl scale deployment test-runner --replicas=2`
- Ensure proper load balancing of API requests
- Consider using a message queue for test job distribution

## Support

### Common Issues

**Issue**: ExternalSecret not syncing
```bash
kubectl describe externalsecret -n kubestock-staging test-runner-secret
# Check ClusterSecretStore
kubectl describe clustersecretstore aws-secretsmanager
```

**Issue**: Tests failing with 401 Unauthorized
- Verify Asgardeo credentials in AWS Secrets Manager
- Check token URL is correct
- Ensure test user exists and has proper permissions

**Issue**: Post-sync hook failing
- Check if test-runner is ready before hook execution
- Increase sleep time in hook if needed
- Verify service networking (DNS resolution)

## References
- [k6 Documentation](https://k6.io/docs/)
- [External Secrets Operator](https://external-secrets.io/)
- [ArgoCD Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
- [Prometheus k6 Extension](https://k6.io/docs/results-output/real-time/prometheus-remote-write/)
