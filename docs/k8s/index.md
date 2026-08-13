# Kubernetes Documentation Index

## Overview
Complete reference guide for Kubernetes cluster setup, configuration management, and deployment automation tools.

---

## Documentation Index

| Topic | Description |
|-------|-------------|
| [**Cluster Setup Automation Tools**](available-tools-to-automate-k8s-cluster-setup.md) | Comparison of Cluster API, kOps, and Kubespray for automating self-managed Kubernetes cluster provisioning and bootstrapping across cloud providers. |
| [**Cluster Setup Script**](cluster-setup.sh) | Practical bash commands for setting up a multi-node Kubernetes cluster with 2 master and 2 worker nodes, including containerd installation, kubelet configuration, and kubeadm join procedures. |
| [**CNI Plugin Selection Guide**](cni-plugin-selection.md) | Comprehensive comparison of 5 popular CNI plugins (Cilium, Calico, Weave Net, Flannel, kube-router) with recommendations based on production needs, NetworkPolicy support, and learning curve. |
| [**Production Cluster Setup**](k8s-production-cluster-setup.md) | Essential configuration guidelines for production clusters including required ports, swap memory management, container runtime setup, version skew requirements, and cgroup configuration. |
| [**Kustomize Configuration Management**](kustomize.md) | In-depth guide to Kustomize templating-free approach using base and overlay patterns for managing Kubernetes manifests across multiple environments without duplication. |
| [**Skaffold Build & Deploy Automation**](skaffold.md) | Complete guide to Skaffold for automating the build-deploy loop, covering skaffold.yaml configuration, image building strategies (Jib, Dockerfile, Kaniko), and integration with Kustomize. |
| [**Taints, Tolerations & Node Selection**](taints-in-k8s.md) | Explanation of Kubernetes node scheduling mechanisms including taints for preventing pod placement, tolerations for pod exceptions, and nodeSelector for explicit node assignment. |
| [**Terraform Fundamentals**](notes.md) | Quick reference for Terraform concepts including locals block for variable declaration and output block for exposing module values. |

---


---
