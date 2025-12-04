# ArgoCD Applications for Staging
# These are skeleton files - actual Application manifests will be created
# when you're ready to deploy

# To create staging application:
# kubectl apply -f gitops/apps/staging/

# Application structure:
# - kubestock-staging.yaml - Main staging app (all services)
#
# OR individual apps:
# - postgres-staging.yaml
# - ms-product-staging.yaml
# - ms-inventory-staging.yaml
# - ms-supplier-staging.yaml
# - ms-order-management-staging.yaml
# - ms-identity-staging.yaml
# - frontend-staging.yaml
