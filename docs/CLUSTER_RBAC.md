# Cluster RBAC Configuration

This document provides a comprehensive overview of the Role-Based Access Control (RBAC) configuration currently deployed in the KubeStock Kubernetes cluster. The RBAC setup is managed through ArgoCD GitOps and includes infrastructure components, observability stack, and application namespaces.

**Last Updated:** December 15, 2025

## Table of Contents

- [Overview](#overview)
- [Namespaces](#namespaces)
- [Infrastructure Components](#infrastructure-components)
  - [ArgoCD](#argocd)
  - [Cluster Autoscaler](#cluster-autoscaler)
  - [External Secrets Operator](#external-secrets-operator)
  - [Istio Service Mesh](#istio-service-mesh)
  - [Kong API Gateway](#kong-api-gateway)
  - [Reloader](#reloader)
- [Observability Stack](#observability-stack)
- [Application Namespaces](#application-namespaces)
- [Summary](#summary)

---

## Overview

The cluster currently has **97 ClusterRoles** and **82 ClusterRoleBindings** deployed. This document focuses on the custom RBAC configurations specific to KubeStock infrastructure and applications.

All RBAC resources are managed via ArgoCD GitOps, as indicated by the `argocd.argoproj.io/tracking-id` annotations on most resources.

---

## Namespaces

The following namespaces contain RBAC-related resources:

| Namespace | Purpose | Age |
|-----------|---------|-----|
| `argocd` | GitOps continuous delivery | 11 days |
| `cluster-autoscaler` | Kubernetes cluster autoscaling | 20 hours |
| `external-secrets` | External secrets management | 9 days |
| `istio-system` | Service mesh control plane | 24 hours |
| `kong` | API Gateway for production | 11 days |
| `kong-staging` | API Gateway for staging | 6 days 6 hours |
| `kubestock-production` | Production application workloads | 6 days 6 hours |
| `kubestock-staging` | Staging application workloads | 11 days |
| `observability-production` | Monitoring and logging stack | 19 hours |
| `reloader` | ConfigMap/Secret change detection | 20 hours |

---

## Infrastructure Components

### ArgoCD

**Purpose:** GitOps continuous delivery platform managing all cluster resources.

#### ClusterRoles

##### `argocd-application-controller`
- **Scope:** Cluster-wide
- **Permissions:** Full cluster administrator access (`*.*` with `*` verbs)
- **Justification:** ArgoCD needs to create, update, and delete any resource type across all namespaces
- **Labels:**
  - `app.kubernetes.io/component=application-controller`
  - `app.kubernetes.io/name=argocd-application-controller`
  - `app.kubernetes.io/part-of=argocd`

##### `argocd-server`
- **Scope:** Cluster-wide
- **Permissions:** Read access to cluster resources for UI/API

##### `argocd-applicationset-controller`
- **Scope:** Cluster-wide
- **Permissions:** Manage ApplicationSet resources

#### Namespace Roles (in `argocd` namespace)

1. **`argocd-application-controller`** - Application lifecycle management
2. **`argocd-applicationset-controller`** - ApplicationSet management
3. **`argocd-dex-server`** - SSO/authentication
4. **`argocd-notifications-controller`** - Event notifications
5. **`argocd-redis`** - Cache management
6. **`argocd-server`** - API server operations

#### ServiceAccounts

- `argocd-application-controller`
- `argocd-applicationset-controller`
- `argocd-dex-server`
- `argocd-notifications-controller`
- `argocd-redis`
- `argocd-repo-server`
- `argocd-server`

---

### Cluster Autoscaler

**Purpose:** Automatically adjusts cluster size based on pod resource requests.

#### ClusterRole: `cluster-autoscaler`

**Key Permissions:**
- **Nodes:** `watch`, `list`, `get`, `update` - Monitor and update node status
- **Pods:** `watch`, `list`, `get` - Track pod scheduling and resource usage
- **Pods/eviction:** `create` - Evict pods during scale-down
- **PersistentVolumes/PersistentVolumeClaims:** `watch`, `list`, `get` - Handle storage constraints
- **Workload Controllers:** `watch`, `list`, `get` for:
  - Deployments, StatefulSets, DaemonSets (apps)
  - ReplicaSets (apps/extensions)
  - Jobs, CronJobs (batch)
- **Storage:** `watch`, `list`, `get` for:
  - StorageClasses
  - CSIDrivers, CSINodes, CSIStorageCapacities
- **PodDisruptionBudgets:** `watch`, `list` - Respect disruption constraints
- **Coordination:**
  - Endpoints: `create`, `patch`, `get`, `update` (for `cluster-autoscaler` endpoint)
  - Leases: `create`, `get`, `update` (for leader election)
- **Events:** `create`, `patch` - Log autoscaling decisions

**Labels:**
- `app=cluster-autoscaler`
- `app.kubernetes.io/component=autoscaler`
- `app.kubernetes.io/name=cluster-autoscaler`
- `app.kubernetes.io/part-of=infrastructure`

#### ServiceAccount
- **Name:** `cluster-autoscaler`
- **Namespace:** `cluster-autoscaler`
- **Bound to:** ClusterRole `cluster-autoscaler`

---

### External Secrets Operator

**Purpose:** Synchronizes secrets from AWS Secrets Manager into Kubernetes Secrets.

#### ClusterRole: `external-secrets-controller`

**Key Permissions:**
- **Secrets:** Full CRUD (`get`, `list`, `watch`, `create`, `update`, `delete`, `patch`)
- **ExternalSecrets CRDs:** Full management for:
  - `externalsecrets.external-secrets.io`
  - `clusterexternalsecrets.external-secrets.io`
  - `secretstores.external-secrets.io`
  - `clustersecretstores.external-secrets.io`
  - `pushsecrets.external-secrets.io`
- **Generator CRDs:** Read access for:
  - `passwords.generators.external-secrets.io`
  - `acraccesstokens.generators.external-secrets.io`
  - `ecrauthorizationtokens.generators.external-secrets.io`
  - `gcraccesstokens.generators.external-secrets.io`
  - `githubaccesstokens.generators.external-secrets.io`
  - `vaultdynamicsecrets.generators.external-secrets.io`
  - `webhooks.generators.external-secrets.io`
  - `fakes.generators.external-secrets.io`
- **ServiceAccounts:** `get`, `list`, `watch`, and create tokens
- **ConfigMaps:** `get`, `list`, `watch`
- **Namespaces:** `get`, `list`, `watch`
- **Events:** `create`, `patch`

**Additional ClusterRoles:**
- `external-secrets-cert-controller` - Certificate management
- `external-secrets-view` - Read-only access
- `external-secrets-edit` - Edit access for ESO resources
- `external-secrets-servicebindings` - Service binding integration

#### Namespace Roles (in `external-secrets` namespace)
- `external-secrets-leaderelection` - Leader election for controller HA

#### ServiceAccounts
- `external-secrets` - Main controller service account
- `external-secrets-cert-controller` - Certificate controller
- `external-secrets-webhook` - Webhook service account

---

### Istio Service Mesh

**Purpose:** Service mesh providing traffic management, security, and observability.

#### ClusterRole: `istiod-clusterrole-istio-system`

**Key Permissions:**
- **Core Resources:**
  - ConfigMaps: `create`, `get`, `list`, `watch`, `update`
  - Endpoints, Namespaces, Nodes, Pods, Services: `get`, `list`, `watch`
  - Secrets: `get`, `watch`, `list`
- **Networking:**
  - Ingresses: `get`, `list`, `watch`
  - IngressClasses: `get`, `list`, `watch`
  - Ingress Status: Full control (`*`)
  - Service Status: Full CRUD
- **Gateway API:**
  - GatewayClasses: `create`, `update`, `patch`, `delete`
  - All Gateway API resources: `get`, `watch`, `list`
  - Status subresources: `update`, `patch` for:
    - BackendTLSPolicies
    - GatewayClasses
    - Gateways
    - HTTPRoutes, GRPCRoutes, TCPRoutes, TLSRoutes, UDPRoutes
    - ReferenceGrants
- **Istio CRDs:** Full read access (`get`, `watch`, `list`) for:
  - `*.authentication.istio.io`
  - `*.config.istio.io`
  - `*.extensions.istio.io`
  - `*.networking.istio.io`
  - `*.rbac.istio.io`
  - `*.security.istio.io`
  - `*.telemetry.istio.io`
- **Specific Istio Resources:** Full CRUD for:
  - `authorizationpolicies.security.istio.io/status`
  - `serviceentries.networking.istio.io/status`
  - `workloadentries.networking.istio.io` and status
- **Multi-cluster:**
  - ServiceExports: Full CRUD
  - ServiceImports: `get`, `watch`, `list`
- **Admission Control:**
  - MutatingWebhookConfigurations: `get`, `list`, `watch`, `update`, `patch`
  - ValidatingWebhookConfigurations: `get`, `list`, `watch`, `update`
- **Authentication:**
  - TokenReviews: `create`
  - SubjectAccessReviews: `create`
- **Discovery:**
  - EndpointSlices: `get`, `list`, `watch`
- **CRDs:**
  - CustomResourceDefinitions: `get`, `list`, `watch`

**Other ClusterRoles:**
- `istio-reader-clusterrole-istio-system` - Read-only access for monitoring
- `istiod-gateway-controller-istio-system` - Gateway controller permissions

**Labels:**
- `app=istiod`
- `app.kubernetes.io/instance=istiod`
- `app.kubernetes.io/managed-by=Helm`
- `app.kubernetes.io/name=istiod`
- `app.kubernetes.io/part-of=istio`
- `app.kubernetes.io/version=1.24.0`

#### Namespace Roles (in `istio-system` namespace)
- `istiod` - Control plane operations within the namespace

#### ServiceAccounts
- `istiod` - Main Istio control plane service account
- `istio-reader-service-account` - Read-only monitoring account
- `kiali` - Kiali service mesh dashboard

---

### Kong API Gateway

**Purpose:** Ingress controller and API Gateway for routing external traffic.

#### ClusterRole: `kong-ingress`

**Key Permissions:**
- **Core Resources:**
  - Endpoints: `get`, `list`, `watch`
  - Services: `get`, `list`, `watch`
  - Secrets: `get`, `list`, `watch`
- **Ingress:**
  - `ingresses.networking.k8s.io`: `get`, `list`, `watch`
  - `ingresses.networking.k8s.io/status`: `update`
- **Kong CRDs:**
  - `kongconsumers.configuration.konghq.com`: `get`, `list`, `watch`
  - `kongcredentials.configuration.konghq.com`: `get`, `list`, `watch`
  - `kongingresses.configuration.konghq.com`: `get`, `list`, `watch`
  - `kongplugins.configuration.konghq.com`: `get`, `list`, `watch`

**Annotation:**
- `argocd.argoproj.io/tracking-id: shared-rbac:rbac.authorization.k8s.io/ClusterRole:default/kong-ingress`

#### ClusterRoleBindings

##### `kong-ingress-production`
- **ServiceAccount:** `kong/kong`
- **ClusterRole:** `kong-ingress`
- **Namespace:** `kong`
- **Purpose:** Production API Gateway permissions

##### `kong-ingress-staging`
- **ServiceAccount:** `kong-staging/kong`
- **ClusterRole:** `kong-ingress`
- **Namespace:** `kong-staging`
- **Purpose:** Staging API Gateway permissions

#### ServiceAccounts
- `kong` in namespace `kong` (production)
- `kong` in namespace `kong-staging` (staging)

---

### Reloader

**Purpose:** Automatically restarts workloads when ConfigMaps or Secrets change.

#### ClusterRole: `reloader-role`

**Key Permissions:**
- **ConfigMaps & Secrets:** `get`, `list`, `watch` - Monitor for changes
- **Workloads:** `get`, `list`, `patch`, `update` for:
  - Deployments
  - StatefulSets
  - DaemonSets
- **Pods:** `get`, `list` - Check pod status
- **Events:** `create`, `patch` - Log reload events

**Labels:**
- `app.kubernetes.io/managed-by=argocd`
- `app.kubernetes.io/name=reloader`
- `app.kubernetes.io/part-of=kubestock-infrastructure`

#### ServiceAccount
- **Name:** `reloader`
- **Namespace:** `reloader`
- **Bound to:** ClusterRole `reloader-role`

---

## Observability Stack

**Namespace:** `observability-production`

### ClusterRole: `prometheus-production`

**Key Permissions:**
- **Core Resources:**
  - Endpoints: `get`, `list`, `watch`
  - Nodes: `get`, `list`, `watch`
  - Node Metrics: `get`, `list`, `watch` for `/metrics` and `/metrics/cadvisor`
  - Node Proxy: `get`, `list`, `watch`
  - Pods: `get`, `list`, `watch`
  - Services: `get`, `list`, `watch`
- **Networking:**
  - Ingresses: `get`, `list`, `watch`
- **Configuration:**
  - ConfigMaps: `get`
- **Non-Resource URLs:**
  - `/metrics`: `get` - Scrape API server metrics
  - `/metrics/cadvisor`: `get` - Scrape container metrics

**Labels:**
- `app=prometheus`
- `app.kubernetes.io/managed-by=argocd`
- `app.kubernetes.io/part-of=kubestock-observability`
- `environment=production`

### ServiceAccounts

- `prometheus` - Prometheus server
- `promtail` - Log collection agent
- `kube-state-metrics` - Kubernetes metrics exporter

**Note:** Additional RBAC for kube-state-metrics and promtail are configured but not detailed here.

---

## Application Namespaces

### Production: `kubestock-production`
- **ServiceAccounts:** Only `default` service account present
- **Roles/RoleBindings:** None currently configured
- **Status:** Application pods run with default service account and no additional RBAC

### Staging: `kubestock-staging`
- **ServiceAccounts:** Only `default` service account present
- **Roles/RoleBindings:** None currently configured
- **Status:** Application pods run with default service account and no additional RBAC

**Security Note:** Application workloads currently use the default service account. Consider creating dedicated service accounts with minimal permissions for each microservice as a security best practice.

---

## Summary

### RBAC Configuration Overview

| Component | ClusterRoles | ClusterRoleBindings | Namespace Roles | ServiceAccounts |
|-----------|--------------|---------------------|-----------------|-----------------|
| ArgoCD | 3 | 3 | 6 | 7 |
| Cluster Autoscaler | 1 | 1 | 0 | 1 |
| External Secrets | 5 | 3 | 1 | 3 |
| Istio | 3 | 3 | 1 | 4 |
| Kong | 1 | 2 | 0 | 2 (one per env) |
| Reloader | 1 | 1 | 0 | 1 |
| Observability | 1 | 1 | 0 | 3 |

### Security Posture

#### Strengths
1. **GitOps Managed:** All RBAC is version-controlled and deployed via ArgoCD
2. **Namespace Isolation:** Separate namespaces for different components and environments
3. **Service Account Per Component:** Each infrastructure component has dedicated service accounts
4. **Least Privilege for Most Components:** Most components have scoped permissions for their specific needs

#### Areas for Improvement
1. **ArgoCD Broad Permissions:** ArgoCD application controller has full cluster admin access (`*.*` with `*` verbs)
   - **Recommendation:** Consider scoping to specific resource types if possible, or accept this as necessary for GitOps
2. **Application Service Accounts:** Production and staging applications use default service accounts
   - **Recommendation:** Create dedicated service accounts per microservice with minimal required permissions
3. **Network Policies:** RBAC is complemented by network policies but not documented here
   - **Recommendation:** Document network policies in conjunction with RBAC for complete security posture

### Compliance Notes

- **Audit Trail:** All resources have ArgoCD tracking IDs for change tracking
- **GitOps Principle:** RBAC drift from Git state would be automatically corrected by ArgoCD
- **Version Information:** All Helm-deployed components include version labels

---

## Related Documentation

- [SECRET_MANAGEMENT.md](../SECRET_MANAGEMENT.md) - How secrets are managed with External Secrets Operator
- [BOOTSTRAP.md](../BOOTSTRAP.md) - Initial cluster bootstrap process
- [OBSERVABILITY_SETUP.md](../OBSERVABILITY_SETUP.md) - Monitoring and logging configuration

---

**Document Generated:** December 15, 2025  
**Data Source:** `kubectl` commands executed against live cluster  
**Cluster Context:** KubeStock Production Cluster
