# Cluster Autoscaler

This directory contains Kubernetes Cluster Autoscaler manifests for AWS Auto Scaling Groups.

## Overview

Cluster Autoscaler automatically adjusts the size of the Kubernetes cluster when:
- **Scale Up**: Pods fail to schedule due to insufficient resources
- **Scale Down**: Nodes are underutilized for an extended period

## Features

- **Auto-discovery**: Discovers ASGs via tags (`k8s.io/cluster-autoscaler/enabled`, `k8s.io/cluster-autoscaler/kubestock`)
- **Least-waste expander**: Chooses the node group with the least idle resources after scaling
- **Balance similar node groups**: Distributes nodes evenly across similar node groups
- **Scale down protection**: Respects PodDisruptionBudgets and gracefully drains nodes
- **Prometheus metrics**: Exposes metrics on port 8085 for monitoring

## Configuration

### Scale Up Parameters
- Triggers immediately when pods are unschedulable
- Max node provision time: 15 minutes
- Balance similar node groups: enabled

### Scale Down Parameters
- **Enabled**: Yes
- **Unneeded time**: 10 minutes (node must be idle for this duration)
- **Delay after add**: 10 minutes (prevents thrashing after scale-up)
- **Delay after delete**: 10 seconds
- **Delay after failure**: 3 minutes
- **Utilization threshold**: 0.5 (50% - nodes below this are candidates for removal)
- **Max graceful termination**: 600 seconds (10 minutes)

## ASG Requirements

The Auto Scaling Group must have these tags:
```
k8s.io/cluster-autoscaler/enabled = true
k8s.io/cluster-autoscaler/kubestock = owned
```

These are already configured in the Terraform ASG definition.

## IAM Permissions

Required IAM permissions (already configured in `kubestock-node-role`):
- `autoscaling:DescribeAutoScalingGroups`
- `autoscaling:DescribeAutoScalingInstances`
- `autoscaling:DescribeLaunchConfigurations`
- `autoscaling:DescribeScalingActivities`
- `autoscaling:DescribeTags`
- `autoscaling:SetDesiredCapacity`
- `autoscaling:TerminateInstanceInAutoScalingGroup`
- `ec2:DescribeInstances`
- `ec2:DescribeInstanceTypes`
- `ec2:DescribeLaunchTemplateVersions`

## Monitoring

### Metrics
Prometheus metrics exposed at `:8085/metrics`:
- `cluster_autoscaler_nodes_count` - Current node count
- `cluster_autoscaler_unschedulable_pods_count` - Pods waiting for scale-up
- `cluster_autoscaler_scaled_up_nodes_total` - Total scale-up events
- `cluster_autoscaler_scaled_down_nodes_total` - Total scale-down events
- `cluster_autoscaler_failed_scale_ups_total` - Failed scale-up attempts

### Logs
```bash
kubectl logs -n cluster-autoscaler -l app=cluster-autoscaler -f
```

### Status
```bash
kubectl get deployment -n cluster-autoscaler
kubectl get pods -n cluster-autoscaler
kubectl describe cm cluster-autoscaler-status -n cluster-autoscaler
```

## Testing

### Trigger Scale Up
Deploy a resource-intensive workload:
```bash
kubectl create deployment scale-test --image=nginx --replicas=20
kubectl set resources deployment scale-test --requests=cpu=500m,memory=512Mi
```

Watch nodes scale up:
```bash
watch kubectl get nodes
```

### Trigger Scale Down
Delete the workload:
```bash
kubectl delete deployment scale-test
```

After 10 minutes of idle time (configurable), nodes will be removed.

## Troubleshooting

### Check Autoscaler Status
```bash
kubectl get configmap cluster-autoscaler-status -n cluster-autoscaler -o yaml
```

### Common Issues

**Scale-up not happening:**
- Check logs for errors
- Verify ASG tags are correct
- Ensure IAM permissions are attached to node role
- Check max ASG capacity is not reached

**Scale-down not happening:**
- Check if nodes have system pods (can be configured)
- Verify utilization is below threshold (50%)
- Check PodDisruptionBudgets aren't blocking drains
- Ensure scale-down-unneeded-time has elapsed (10m)

**Thrashing (rapid scale up/down):**
- Increase `scale-down-delay-after-add` (currently 10m)
- Increase `scale-down-unneeded-time` (currently 10m)
- Adjust `scale-down-utilization-threshold` (currently 0.5)

## Version Compatibility

- Cluster Autoscaler: v1.31.0
- Kubernetes: v1.31+ (should also work with v1.30)
- Ensure Cluster Autoscaler version matches your Kubernetes minor version

## References

- [Official Documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [AWS Cloud Provider](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)
- [FAQ](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md)
