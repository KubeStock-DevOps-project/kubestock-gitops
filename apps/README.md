# ArgoCD Applications - apps/

This directory contains ArgoCD Application definitions that tell ArgoCD what to deploy and where.

## Directory Structure

```
apps/
├── ebs-csi-driver.yaml        # AWS EBS CSI driver for persistent volumes
├── external-secrets.yaml      # External Secrets Operator
├── metrics-server.yaml        # Kubernetes Metrics Server (HPA, kubectl top)
├── shared-rbac.yaml           # Shared RBAC across namespaces
├── production/                # Production environment applications
│   ├── kong-production.yaml
│   ├── kubestock-production.yaml
│   ├── observability-production.yaml
│   └── README.md
└── staging/                   # Staging environment applications
    ├── kong-staging.yaml
    ├── kubestock-staging.yaml
    ├── observability-staging.yaml
    └── README.md
```

## Cluster-Level Applications

### metrics-server.yaml
**Purpose**: Kubernetes Metrics Server for resource metrics API
- **Enables**: `kubectl top nodes/pods`, Horizontal Pod Autoscaler (HPA)
- **Namespace**: kube-system
- **Deploy First**: Many components depend on this

### ebs-csi-driver.yaml
**Purpose**: AWS EBS CSI driver for persistent volume provisioning
- **Namespace**: kube-system

### external-secrets.yaml  
**Purpose**: Syncs secrets from AWS Secrets Manager to Kubernetes
- **Namespace**: external-secrets

### shared-rbac.yaml
**Purpose**: Shared RBAC rules across environments

## Environment-Specific Applications

### production/ & staging/
Each environment-specific application file defines:
- Source repository and path (pointing to overlays)
- Target namespace and cluster
- Sync policies and automation settings
- Notification preferences

## Deployment Order

For a new cluster, deploy in this order:
1. `ebs-csi-driver.yaml` - Storage provisioning
2. `metrics-server.yaml` - Resource metrics
3. `external-secrets.yaml` - Secrets sync
4. `production/observability-production.yaml` - Creates shared observability resources
5. `staging/observability-staging.yaml` - Staging observability config
6. Environment apps (kong, kubestock)

## Usage

When ArgoCD sees these Application definitions, it:
1. Monitors the specified Git repository paths
2. Automatically detects changes
3. Syncs manifests to the specified namespaces
4. Reports status back to the cluster

