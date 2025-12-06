# ArgoCD Applications - apps/

This directory contains ArgoCD Application definitions that tell ArgoCD what to deploy and where.

## Directory Structure

```
apps/
├── kong.yaml              # Kong API Gateway application
├── production/            # Production environment applications
│   ├── kubestock-production.yaml
│   └── README.md
└── staging/               # Staging environment applications
    ├── kubestock-staging.yaml
    └── README.md
```

## Files Overview

### kong.yaml
**Purpose**: Defines the Kong API Gateway application for ArgoCD

**Specifies**:
- Source: Points to the Kong configuration in the base directory
- Destination: Kong namespace in the cluster
- Sync policy: When and how ArgoCD syncs changes

### production/ & staging/
Each environment-specific application file defines:
- Source repository and path (pointing to overlays)
- Target namespace and cluster
- Sync policies and automation settings
- Notification preferences

## Usage

When ArgoCD sees these Application definitions, it:
1. Monitors the specified Git repository paths
2. Automatically detects changes
3. Syncs manifests to the specified namespaces
4. Reports status back to the cluster

