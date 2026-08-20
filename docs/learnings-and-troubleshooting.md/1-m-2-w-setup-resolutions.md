# Kubernetes & AWS NLB Deployment Troubleshooting Guide

## 1. Node Disk Pressure & Pod Evictions
* **Problem:** Pods stuck in `Pending` or `Failed` status with `DiskPressure` node taints.
* **Reason:** Worker node EBS root volume (7 GB) filled up during initial image pulls and container execution.
* **Resolution:** Upgraded root EBS volume sizes to 20 GB (gp3) on worker nodes and restarted `kubelet`.

---

## 2. Resource Overcommitment & CPU/Memory Saturation
* **Problem:** Worker node memory limits reached 168% and CPU limits reached 151%, causing potential OOM kills and high resource contention.
* **Reason:** All 11 Online Boutique microservices, system pods, and `loadgenerator` were scheduled onto a single worker node (`ip-10-0-4-12`).
* **Resolution:** Added a second worker node (`ip-10-0-4-13`) to the cluster and temporarily scaled down `loadgenerator` to rebalance CPU and memory load.

---

## 3. Uneven Pod Scheduling Across Cluster Nodes
* **Problem:** Newly created pods stacked entirely onto the newly added worker node (`ip-10-0-4-13`) instead of spreading across both available nodes.
* **Reason:** Kubernetes default scheduler assigns pods based on available node capacity at creation time without enforcing distribution constraints.
* **Resolution:** Applied `topologySpreadConstraints` and cordoned nodes temporarily during `rollout restart` to force equal pod distribution across hosts.

---

## 4. AWS Load Balancer Controller Target Group Registration Failure
* **Problem:** AWS Load Balancer Controller threw reconciler error: `providerID is not specified for node: ip-10-0-4-13`. NLB target group only contained 1 worker node.
* **Reason:** Worker node `ip-10-0-4-13` was joined manually via `kubeadm` without AWS cloud provider metadata, leaving its `.spec.providerID` field empty.
* **Resolution:** Patched the node's spec with its EC2 Instance ID and Availability Zone:
  ```bash
  kubectl patch node ip-10-0-4-13 -p '{"spec":{"providerID":"aws:///<AZ>/<INSTANCE_ID>"}}'
  ```
  Restarted `aws-load-balancer-controller` deployment to trigger target group re-sync.

---

## 5. External Load Balancer Unreachable Over Internet
* **Problem:** Public NLB DNS timed out or failed to serve application traffic despite internal `curl` working on NodePort (`:32148`).
* **Reason:** Worker node Security Groups blocked incoming traffic from the NLB on the assigned NodePort range, and health checks failed.
* **Resolution:** Added an Inbound Rule to the worker node AWS Security Group for TCP port range `30000-32767` from `0.0.0.0/0` and confirmed Target Group health status turned `Healthy`.