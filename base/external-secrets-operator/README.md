# External Secrets Operator - Deployment Guide

## Architecture

The External Secrets setup is split into three ArgoCD Applications for proper dependency management:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ArgoCD Applications                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. external-secrets-operator (Sync Wave: -3)                       │
│     └── Helm Chart: external-secrets/external-secrets v0.9.19      │
│         - Deploys CRDs                                              │
│         - Deploys operator pods                                     │
│         - Deploys webhook                                           │
│                                                                     │
│  2. external-secrets-prereqs (Sync Wave: -2)                        │
│     └── base/external-secrets-operator/                             │
│         - namespace.yaml (external-secrets namespace)               │
│         - aws-credentials-secret.yaml (AWS IAM credentials)         │
│                                                                     │
│  3. external-secrets-config (Sync Wave: -1)                         │
│     └── base/external-secrets/                                      │
│         - clustersecretstore-aws.yaml (AWS Secrets Manager)         │
│         - ecr-generator-central.yaml (ECR token distribution)       │
│         - ecr-credentials-rbac.yaml (Cross-namespace RBAC)          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
gitops/
├── apps/
│   ├── external-secrets-operator.yaml  # Helm-based operator deployment
│   ├── external-secrets-prereqs.yaml   # Prerequisites (credentials)
│   └── external-secrets.yaml           # Configuration resources
│
└── base/
    ├── external-secrets-operator/      # Prerequisites
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── aws-credentials-secret.yaml # ⚠️ Contains AWS credentials
    │   └── values.yaml                 # Reference Helm values
    │
    └── external-secrets/               # Configuration
        ├── kustomization.yaml
        ├── clustersecretstore-aws.yaml
        ├── ecr-generator-central.yaml
        └── ecr-credentials-rbac.yaml
```

## AWS Credentials

The `aws-credentials-secret.yaml` contains AWS IAM credentials for:
- **SecretsManager**: Reading application secrets
- **ECR**: Generating pull tokens for private container images

### Security Considerations

⚠️ **The credentials are stored in plaintext in git.** For production, consider:

1. **AWS IRSA** (Recommended): Use IAM Roles for Service Accounts
   - Annotate the external-secrets ServiceAccount with the IAM role ARN
   - No static credentials needed

2. **SealedSecrets**: Encrypt the secret before committing
   ```bash
   kubeseal --format yaml < aws-credentials-secret.yaml > aws-credentials-sealed.yaml
   ```

3. **Bootstrap Script**: Apply credentials manually during cluster setup
   - Remove from git, apply via bootstrap script

## Cluster Recreation

During cluster recreation:

1. **ArgoCD sync order is automatic** via sync-wave annotations
2. **Credentials are applied first** (sync-wave -2)
3. **Operator deploys with CRDs** (sync-wave -3, but Helm chart handles CRD ordering)
4. **Configuration applied last** (sync-wave -1)

## Upgrading External Secrets

To upgrade the operator:

1. Update `targetRevision` in `apps/external-secrets-operator.yaml`
2. Commit and push
3. ArgoCD will sync the new version

```yaml
spec:
  source:
    targetRevision: 0.10.0  # Change version here
```

## Troubleshooting

### CRDs not ready
If you see "no matches for kind" errors, the operator hasn't finished installing CRDs.
Wait for the operator pod to be ready, or manually sync the operator app first.

### AWS credentials not found
Ensure `external-secrets-prereqs` synced successfully before `external-secrets-config`.

### ECR tokens not pushing
Check:
1. RBAC roles exist in target namespaces
2. SecretStores are healthy: `kubectl get secretstores -n external-secrets`
3. PushSecrets status: `kubectl get pushsecrets -n external-secrets`
