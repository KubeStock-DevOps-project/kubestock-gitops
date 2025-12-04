# ArgoCD Applications for Production
# Blue-Green deployment strategy

# Application structure:
# - kubestock-production.yaml - Shared resources (DB, traffic router)
# - kubestock-blue.yaml - Blue deployment slot
# - kubestock-green.yaml - Green deployment slot

# Deployment workflow:
# 1. Deploy to inactive slot (e.g., green if blue is active)
# 2. Run smoke tests against green
# 3. Update traffic-router.yaml selector from 'blue' to 'green'
# 4. ArgoCD syncs the change, traffic switches to green
# 5. Blue remains as rollback target

# Rollback:
# 1. Update traffic-router.yaml selector back to 'blue'
# 2. ArgoCD syncs, traffic switches back to blue
