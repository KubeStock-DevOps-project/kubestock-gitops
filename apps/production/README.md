# Production ArgoCD Applications

## kubestock-production.yaml

Single application that deploys all production services:
- ms-product
- ms-inventory  
- ms-supplier
- ms-order-management
- ms-identity
- frontend

### Deployment Strategy
- Rolling update with `maxSurge: 1` and `maxUnavailable: 0`
- Zero-downtime deployments
- Automatic rollback on failure

### Database
- Uses AWS RDS PostgreSQL (managed)
- Connection via `db-secret`

### To Apply
```bash
kubectl apply -f kubestock-production.yaml
```
