# Test Runner - ArgoCD Integration & Grafana Monitoring

## Overview
Automated smoke and load testing integrated with ArgoCD PostSync hooks. Tests run automatically after successful deployments to staging and production environments.

## Architecture

### Components
1. **Test Runner Service**: k6-based testing service
2. **ArgoCD PostSync Hooks**: Kubernetes Jobs triggered after sync
3. **Kong API Gateway**: Rate-limit exemption for test-runner
4. **Grafana Dashboards**: Real-time test metrics and results
5. **Prometheus**: Metrics collection from k6

## ArgoCD Integration

### PostSync Hooks
After ArgoCD syncs an application, it automatically triggers:

#### Staging Environment
- **Smoke Tests**: Quick health checks through Kong Gateway
- **Load Tests**: Performance testing hitting services directly

#### Production Environment
- **Smoke Tests**: Conservative health checks
- **Load Tests**: Reduced load profile for safety

### Hook Configuration
Hooks are deployed as Kubernetes Jobs with annotations:
```yaml
annotations:
  argocd.argoproj.io/hook: PostSync
  argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

### Test Execution Flow
```
ArgoCD Sync Complete
    ↓
PostSync Hook Triggered
    ↓
k6 Job Starts
    ↓
├─ Smoke Test (Gateway)
│  └─ Health checks all services
│
└─ Load Test (Direct)
   └─ Performance testing
    ↓
Metrics → Prometheus
    ↓
Logs → Loki
    ↓
Visualization → Grafana
```

## Kong Rate Limiting Exemption

### Configuration
Test-runner is exempted from Kong rate limits using `X-Consumer-Username` header:

```yaml
# Kong Consumer
consumers:
  - username: test-runner
    custom_id: test-runner-service

# Rate Limiting Config
plugins:
  - name: rate-limiting
    config:
      header_name: X-Consumer-Username
```

### Test Scripts
Both smoke.js and load.js include the header:
```javascript
const KONG_CONSUMER_HEADER = __ENV.KONG_CONSUMER_HEADER || 'test-runner';
headers['X-Consumer-Username'] = KONG_CONSUMER_HEADER;
```

## Test Types

### Smoke Tests (smoke.js)
- **Purpose**: Quick health validation
- **Duration**: ~5 seconds
- **VUs**: 1 virtual user
- **Target**: Kong Gateway endpoints
- **Services Checked**:
  - Gateway Health
  - Product Service
  - Inventory Service
  - Supplier Service
  - Order Service
  - Identity Service

### Load Tests (load.js)
- **Purpose**: Performance validation
- **Target**: Direct service endpoints (bypass Kong)
- **Configurable Stages**: Via `STAGES` environment variable

#### Staging Profile
```json
[
  {"duration": "30s", "target": 10},
  {"duration": "1m", "target": 20},
  {"duration": "30s", "target": 0}
]
```

#### Production Profile (Conservative)
```json
[
  {"duration": "20s", "target": 5},
  {"duration": "40s", "target": 10},
  {"duration": "20s", "target": 0}
]
```

## Grafana Dashboards

### Dashboard: "KubeStock - K6 Test Metrics"
Location: Observability namespace
UID: `k6-performance-metrics`

#### Panels

1. **Test Execution Timeline**
   - Data Source: Loki
   - Shows: Test start/finish times, exit codes
   - Real-time log streaming

2. **Test Success Rate**
   - Data Source: Prometheus
   - Shows: Percentage of successful checks
   - Thresholds: 
     - Red: < 95%
     - Yellow: 95-99%
     - Green: > 99%

3. **HTTP Request Rate**
   - Data Source: Prometheus
   - Shows: Requests per second by service
   - Metric: `rate(k6_http_reqs[1m])`

4. **Virtual Users**
   - Data Source: Prometheus
   - Shows: Active VUs over time
   - Metric: `k6_vus`

5. **Response Time Percentiles**
   - Data Source: Prometheus
   - Shows: p50, p95, p99 response times
   - Thresholds:
     - Green: < 500ms
     - Yellow: 500-1000ms
     - Red: > 1000ms

6. **HTTP Failure Rate**
   - Data Source: Prometheus
   - Shows: Failed request percentage
   - Metric: `rate(k6_http_req_failed[1m])`

7. **Test Checks Status**
   - Data Source: Prometheus
   - Shows: Detailed check results in table format

8. **Recent Test Executions**
   - Data Source: Loki
   - Shows: Test execution history with timestamps

### Variables
- **$environment**: staging | production
- **$test_type**: smoke | load | All

## Metrics Collected

### k6 Metrics
```
k6_checks                      # Check pass/fail status
k6_http_reqs                   # HTTP request count
k6_http_req_duration           # Response time histogram
k6_http_req_failed             # Failed request count
k6_vus                         # Virtual users
k6_iterations                  # Test iterations
```

### Labels
```
environment = staging | production
test_type = smoke | load
check = <check_name>
name = <service_name>
```

## Viewing Test Results

### Real-Time Monitoring
1. Open Grafana: `http://<grafana-url>`
2. Navigate to: **KubeStock - K6 Test Metrics**
3. Select environment and test type
4. View live metrics as tests run

### Post-Deployment
1. **ArgoCD UI**: Check PostSync hook status
2. **Grafana**: View test execution timeline
3. **Logs**: Check pod logs for detailed output

### CLI Access
```bash
# View recent test jobs
kubectl get jobs -n test-runner

# View job logs (staging smoke test)
kubectl logs -n test-runner job/staging-smoke-test

# View job logs (production load test)
kubectl logs -n test-runner job/production-load-test

# Check test-runner service logs
kubectl logs -n test-runner deployment/test-runner -f
```

## Manual Test Execution

### Via test-runner Service
```bash
# Trigger smoke test
kubectl exec -n test-runner deployment/test-runner -- \
  curl -X POST http://localhost:3007/api/tests/run \
  -H "Content-Type: application/json" \
  -d '{"testType": "smoke"}'

# Trigger load test
kubectl exec -n test-runner deployment/test-runner -- \
  curl -X POST http://localhost:3007/api/tests/run \
  -H "Content-Type: application/json" \
  -d '{"testType": "load"}'
```

### Direct k6 Execution
```bash
# Run smoke test against staging
kubectl run k6-test --rm -it --restart=Never \
  --image=grafana/k6:0.48.0 \
  --namespace=test-runner \
  --env="GATEWAY_URL=http://kong-proxy.kong-staging.svc.kubestock" \
  --env="KONG_CONSUMER_HEADER=test-runner" \
  -- run - < /path/to/smoke.js
```

## Troubleshooting

### Tests Failing
1. Check service health: `kubectl get pods -n kubestock-staging`
2. Check Kong gateway: `kubectl get pods -n kong-staging`
3. Review test logs: `kubectl logs -n test-runner job/<job-name>`
4. Check Grafana metrics for specific failures

### Rate Limiting Issues
1. Verify Kong consumer: Check `config.yaml` for consumer definition
2. Verify header: Check test scripts include `X-Consumer-Username`
3. Test bypass: Run load tests directly to services (already configured)

### Metrics Not Showing
1. Check Prometheus: `kubectl get pods -n observability`
2. Verify k6 output config: `K6_PROMETHEUS_RW_SERVER_URL` in Jobs
3. Check Grafana datasource: Prometheus connection

### ArgoCD Hook Not Triggering
1. Check ArgoCD sync status: `argocd app get kubestock-staging`
2. Verify hook annotations in Job manifests
3. Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-server`

## Configuration Files

### Base Resources
```
gitops/base/services/test-runner/
├── namespace.yaml                    # test-runner namespace
├── serviceaccount.yaml               # Service account
├── deployment.yaml                   # test-runner service
├── service.yaml                      # ClusterIP service
├── configmap.yaml                    # Kong consumer config
├── k6-scripts-configmap.yaml         # k6 test scripts
├── externalsecret.yaml               # Asgardeo secrets
├── ecr-secret.yaml                   # ECR credentials
├── postsync-hook-staging.yaml        # Staging test hooks
├── postsync-hook-production.yaml     # Production test hooks
└── kustomization.yaml                # Kustomize config
```

### Grafana Dashboards
```
gitops/base/observability-stack/grafana/
├── dashboard-k6-metrics.yaml         # K6 performance metrics
└── dashboard-test-runner.yaml        # Test execution logs
```

## Best Practices

### Test Design
1. **Smoke Tests**: Always through Kong Gateway
2. **Load Tests**: Direct to services to avoid gateway bottleneck
3. **Production Tests**: Conservative load profiles
4. **Staging Tests**: More aggressive testing

### Monitoring
1. Set up alerts for test failures
2. Review response time trends
3. Monitor success rates over time
4. Track virtual user scaling

### Maintenance
1. Update test scripts in ConfigMap
2. Adjust load test stages per environment
3. Review and optimize thresholds
4. Keep k6 image version updated

## Next Steps

### Enhancements
- [ ] Add authentication tests with Asgardeo
- [ ] Implement CRUD operation tests
- [ ] Add custom metrics for business logic
- [ ] Create alerts for test failures
- [ ] Add Slack/email notifications
- [ ] Implement test result trending
- [ ] Add performance regression detection

### Integration
- [ ] Integrate with CI/CD pipeline
- [ ] Add pre-deployment tests
- [ ] Implement canary deployment testing
- [ ] Add chaos engineering tests
