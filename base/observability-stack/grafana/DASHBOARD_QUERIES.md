# Grafana Dashboard - Test Runner Metrics Reference

## Dashboard Access
- **Name**: KubeStock - K6 Test Metrics
- **UID**: k6-performance-metrics
- **Namespace**: observability

## Panel Queries Reference

### 1. Test Execution Timeline (Loki)
```logql
{namespace="test-runner", app="test-runner"} 
|~ "Running (Staging|Production) (Smoke|Load) Tests|Finished at|Exit Code"
```
**Shows**: Real-time test execution logs

### 2. Test Success Rate (Prometheus)
```promql
sum(k6_checks{environment="$environment", test_type=~"$test_type", check=~".*status is 200"}) 
/ 
sum(k6_checks{environment="$environment", test_type=~"$test_type"}) 
* 100
```
**Shows**: Percentage of successful checks  
**Unit**: Percent (0-100)  
**Thresholds**: Red <95%, Yellow 95-99%, Green >99%

### 3. HTTP Request Rate (Prometheus)
```promql
sum(rate(k6_http_reqs{environment="$environment", test_type=~"$test_type"}[1m])) by (name)
```
**Shows**: Requests per second by service  
**Unit**: req/s  
**Legend**: {{name}}

### 4. Virtual Users (Prometheus)
```promql
k6_vus{environment="$environment", test_type=~"$test_type"}
```
**Shows**: Active virtual users over time  
**Unit**: Count  
**Legend**: VUs - {{test_type}}

### 5. Response Time Percentiles (Prometheus)

**p95 (95th percentile):**
```promql
histogram_quantile(0.95, 
  sum(rate(k6_http_req_duration_bucket{environment="$environment", test_type=~"$test_type"}[1m])) 
  by (le, name)
)
```

**p50 (Median):**
```promql
histogram_quantile(0.50, 
  sum(rate(k6_http_req_duration_bucket{environment="$environment", test_type=~"$test_type"}[1m])) 
  by (le, name)
)
```

**p99 (99th percentile):**
```promql
histogram_quantile(0.99, 
  sum(rate(k6_http_req_duration_bucket{environment="$environment", test_type=~"$test_type"}[1m])) 
  by (le, name)
)
```
**Shows**: Response time distribution  
**Unit**: Milliseconds  
**Legend**: p50/p95/p99 - {{name}}  
**Thresholds**: Green <500ms, Yellow 500-1000ms, Red >1000ms

### 6. HTTP Failure Rate (Prometheus)
```promql
sum(rate(k6_http_req_failed{environment="$environment", test_type=~"$test_type"}[1m])) by (name) * 100
```
**Shows**: Failed request percentage  
**Unit**: Percent  
**Legend**: {{name}}  
**Thresholds**: Green 0%, Yellow 1%, Red >5%

### 7. Test Checks Status (Prometheus)
```promql
k6_checks{environment="$environment", test_type=~"$test_type"}
```
**Shows**: Detailed check results  
**Format**: Table  
**Columns**: Timestamp, Environment, Test Type, Check Name, Result

### 8. Recent Test Executions (Loki)
```logql
{namespace="test-runner"} 
|~ "(Running|Finished at|Exit Code)" 
| json 
| line_format "{{.timestamp}} | {{.environment}} | {{.test_type}} | {{.message}}"
```
**Shows**: Test execution history with parsed fields

## Dashboard Variables

### $environment
- **Type**: Custom
- **Values**: staging, production
- **Default**: staging
- **Multi-select**: No

### $test_type
- **Type**: Custom
- **Values**: smoke, load
- **Default**: All
- **Multi-select**: Yes (with All option)

## Useful Ad-Hoc Queries

### Check Test Execution Count
```promql
count(k6_checks{environment="staging"})
```

### Average Response Time
```promql
avg(rate(k6_http_req_duration_sum{environment="staging"}[5m]))
```

### Total Requests by Service
```promql
sum(k6_http_reqs{environment="staging"}) by (name)
```

### Test Failures in Last Hour
```promql
sum(increase(k6_http_req_failed{environment="staging"}[1h]))
```

### Current Virtual Users
```promql
k6_vus{environment="staging", test_type="load"}
```

## Alert Rules (Example)

### High Failure Rate
```yaml
alert: HighK6FailureRate
expr: |
  sum(rate(k6_http_req_failed[5m])) by (environment) * 100 > 5
for: 2m
labels:
  severity: warning
annotations:
  summary: "High k6 test failure rate"
  description: "{{ $labels.environment }} has {{ $value }}% failure rate"
```

### Slow Response Time
```yaml
alert: SlowK6ResponseTime
expr: |
  histogram_quantile(0.95, 
    sum(rate(k6_http_req_duration_bucket[5m])) by (le, environment)
  ) > 1000
for: 5m
labels:
  severity: warning
annotations:
  summary: "Slow k6 response time"
  description: "{{ $labels.environment }} p95 latency is {{ $value }}ms"
```

### Test Checks Failing
```yaml
alert: K6ChecksFailing
expr: |
  sum(k6_checks{environment="production"}) by (check) < 1
for: 1m
labels:
  severity: critical
annotations:
  summary: "Production k6 check failing"
  description: "Check '{{ $labels.check }}' is failing"
```

## Metric Labels Reference

### Standard Labels
```yaml
environment: "staging" | "production"
test_type: "smoke" | "load"
name: "<service-name>"
check: "<check-description>"
namespace: "staging" | "production"
```

### Example Metric with Labels
```promql
k6_checks{
  environment="staging",
  test_type="smoke",
  check="Product Service UP (via Gateway)"
} = 1
```

## Time Range Recommendations

- **Real-time monitoring**: Last 5 minutes
- **Post-deployment review**: Last 30 minutes
- **Daily analysis**: Last 24 hours
- **Trend analysis**: Last 7 days

## Export & Sharing

### Export Dashboard
```bash
# Get dashboard JSON
kubectl get configmap grafana-dashboard-k6-metrics \
  -n observability \
  -o jsonpath='{.data.k6-metrics\.json}' > dashboard.json

# Import to another Grafana
curl -X POST http://grafana:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @dashboard.json
```

### Share Panel
1. Click panel title
2. Share → Link
3. Copy URL with time range

## Refresh Rates

- **Dashboard**: Auto-refresh every 10s
- **Prometheus scrape**: 30s interval
- **Loki ingestion**: Real-time
- **Panel queries**: On refresh

## Performance Tips

1. Use shorter time ranges for faster queries
2. Limit test_type filter to specific type when possible
3. Use recording rules for complex queries
4. Set appropriate refresh intervals

## Troubleshooting Queries

### No Data Showing
```promql
# Check if any k6 metrics exist
count({__name__=~"k6_.*"})

# Check Prometheus targets
up{job="k6"}

# Check recent scrapes
scrape_duration_seconds{job="k6"}
```

### Metrics Missing Labels
```promql
# Show all labels for k6_checks
k6_checks
```

### Verify Data Source
```bash
# Test Prometheus connection
kubectl port-forward -n observability svc/prometheus 9090:9090

# Open: http://localhost:9090
# Query: k6_checks
```
