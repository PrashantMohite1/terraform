# Terraform

This repository helps automate the creation of production Kubernetes clusters using Terraform and bash scripts.

## Prerequisites

- AWS Console admin access configured
- AWS CLI installed and configured
- An S3 bucket for Terraform backend (update `backend.tf` with your bucket details)

## Commands 

```
cd aws/
terraform init     
terraform apply 
```

## Architecture 

```

                                [ INTERNET ]
                                       │
                                       │ (Public Traffic & Ingress)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ AWS VPC (10.0.0.0/16)                                                           │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ INTERNET GATEWAY (IGW) - Attaches VPC to External Internet              │   │
│   └────────────────────────────────────┬────────────────────────────────────┘   │
│                                        │                                        │
│ ┌──────────────────────────────────────┴──────────────────────────────────────┐ │
│ │ PUBLIC SUBNETS (AZ-A: 10.0.0.0/24 | AZ-B: 10.0.1.0/24 | AZ-C: 10.0.2.0/24)  │ │
│ │ Route Table: 0.0.0.0/0 -> IGW                                               │ │
│ │                                                                             │ │
│ │   ┌──────────────────────────────┐     ┌────────────────────────────────┐   │ │
│ │   │  AWS Network Load Balancer   │     │ NAT GATEWAY (Egress Router)    │   │ │
│ │   │  (k8s-control-plane-nlb)     │     │ (Allocated Elastic IP)         │   │ │
│ │   └──────────────┬───────────────┘     └───────────────▲────────────────┘   │ │
│ └──────────────────┼─────────────────────────────────────┼────────────────────┘ │
│                    │                                     │                      │
│                    │ (API Traffic :6443)                 │ (Outbound Internet:  │
│                    │                                     │  apt update, images) │
│ ┌──────────────────┼─────────────────────────────────────┼────────────────────┐ │
│ │ PRIVATE SUBNETS (AZ-A: 10.0.10.0/24 | AZ-B: 10.0.11.0/24 |AZ-C: 10.0.12.0/24| │
│ │ Route Table: 0.0.0.0/0 -> NAT Gateway                                       │ │
│ │                                                                             │ │
│ │   ┌─────────────────────────────────────────────────────────────────────┐   │ │
│ │   │ CONTROL PLANE (3 Masters)                                           │   │ │
│ │   │   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   │   │ │
│ │   │   │ Master 1 (AZ-A) │   │ Master 2 (AZ-B) │   │ Master 3 (AZ-C) │   │   │ │
│ │   │   └─────────────────┘   └─────────────────┘   └─────────────────┘   │   │ │
│ │   └─────────────────────────────────────────────────────────────────────┘   │ │
│ │                                                                             │ │
│ │   ┌─────────────────────────────────────────────────────────────────────┐   │ │
│ │   │ WORKER NODES & APPLICATION MESH (3 Workers)                         │   │ │
│ │   │   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   │   │ │
│ │   │   │ Worker 1 (AZ-A) │   │ Worker 2 (AZ-B) │   │ Worker 3 (AZ-C) │   │   │ │
│ │   │   │ ├─ Frontend     │   │ ├─ Frontend     │   │ ├─ Frontend     │   │   │ │
│ │   │   │ └─ Catalog v1   │   │ └─ Catalog v1   │   │ └─ Catalog v2   │   │   │ │
│ │   │   │    (90% traffic)│   │    (90% traffic)│   │    (10% canary) │   │   │ │
│ │   │   └─────────────────┘   └─────────────────┘   └─────────────────┘   │   │ │
│ │   └─────────────────────────────────────────────────────────────────────┘   │ │
│ └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘

```