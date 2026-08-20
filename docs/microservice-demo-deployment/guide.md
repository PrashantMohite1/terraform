# Step-by-Step Guide: Deploying Online Boutique on Kubeadm AWS with NLB

Follow these exact steps in sequence to ensure a clean, error-free deployment of the Google Online Boutique microservices demo on a self-managed `kubeadm` Kubernetes cluster on AWS.

---

## Prerequisites & Baseline Checklist

Ensure your EC2 instances meet the minimum hardware and network requirements before beginning:

* **Node Specifications:** Minimum 2 x Worker Nodes (`t3.medium` or higher: 2 vCPU, 4GB+ RAM).
* **Storage:** EBS Root Volumes attached to worker nodes must be at least **20 GB (gp3)**.
* **IAM Permissions:** The master node/controller must have an IAM Role with permissions to manage Elastic Load Balancing (`elasticloadbalancing:*`) and EC2 Describe actions (`ec2:Describe*`).
* **Subnet Tagging:** Ensure your public AWS Subnets are tagged so the controller can auto-discover them:
  * Key: `kubernetes.io/role/elb`
  * Value: `1`

---

## Step 1: Prepare Worker Nodes & Validate Disk Space

Prevent `DiskPressure` taints and image pull failures by ensuring adequate storage on all nodes.

1. Verify disk space on master and worker nodes:
   ```bash
   df -h /
   ```
2. If root volumes were recently expanded in AWS, resize the file system on each node:
   ```bash
   sudo growpart /dev/nvme0n1 1
   sudo xfs_growfs /   # Use resize2fs / for ext4
   ```
3. Restart `kubelet` to ensure node conditions clear:
   ```bash
   sudo systemctl restart kubelet
   ```

---

## Step 2: Configure AWS `providerID` on All Nodes

Self-managed `kubeadm` nodes do not automatically attach cloud provider metadata. Without `providerID`, the AWS Load Balancer Controller will fail to register targets.

1. Fetch the EC2 Instance ID and Availability Zone for each worker node from instance metadata:
   ```bash
   # Run this directly on each worker node
   INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
   AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
   echo "Node Metadata: $AZ / $INSTANCE_ID"
   ```
2. Apply the patch from your **Master Node** for each worker node:
   ```bash
   # Replace <NODE_NAME>, <AZ>, and <INSTANCE_ID> accordingly
   kubectl patch node <NODE_NAME> -p '{"spec":{"providerID":"aws:///<AZ>/<INSTANCE_ID>"}}'
   ```
   *Example:*
   ```bash
   kubectl patch node ip-10-0-4-13 -p '{"spec":{"providerID":"aws:///us-east-1a/i-0a1b2c3d4e5f67890"}}'
   ```

---

## Step 3: Deploy Application with Topology Distribution

Deploy the Online Boutique application microservices while enforcing high availability across worker nodes to prevent CPU/memory saturation on a single host.

1. Apply the core microservices manifests:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml
   ```
2. Patch key deployments (such as `frontend` and `recommendationservice`) with `topologySpreadConstraints` to ensure pods spread evenly across all nodes:
   ```yaml
   spec:
     template:
       spec:
         topologySpreadConstraints:
         - maxSkew: 1
           topologyKey: kubernetes.io/hostname
           whenUnsatisfiable: ScheduleAnyway
           labelSelector:
             matchLabels:
               app: frontend
   ```
3. Scale down non-essential load testing components if compute resources are constrained:
   ```bash
   kubectl scale deployment loadgenerator --replicas=0
   ```

---

## Step 4: Configure AWS Worker Security Groups

Allow the AWS NLB to forward external traffic to the dynamically generated NodePorts on your instances.

1. Open **AWS Console** $
ightarrow$ **EC2** $
ightarrow$ **Security Groups**.
2. Select the Security Group attached to your **Worker Nodes**.
3. Add an **Inbound Rule**:
   * **Type:** Custom TCP
   * **Port Range:** `30000 - 32767`
   * **Source:** `0.0.0.0/0` (or your VPC CIDR `10.0.0.0/16`)

---

## Step 5: Deploy Public AWS Network Load Balancer (NLB)

Note -: before this step make aws load balancer controller is installed, if not install it using aws-nlb-controller-installation.md then only you will be able to create load balancer with below yaml file 

Expose the `frontend` service via a custom LoadBalancer manifest using instance-mode targeting.

1. Save the following manifest as `external-svc-nlb.yaml`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: frontend-external-nlb
     annotations:
       service.beta.kubernetes.io/aws-load-balancer-type: external
       service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
       service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
   spec:
     type: LoadBalancer
     ports:
     - name: http
       port: 80
       targetPort: 8080
       protocol: TCP
     selector:
       app: frontend
   ```
2. Apply the manifest:
   ```bash
   kubectl apply -f external-svc-nlb.yaml
   ```

---

## Step 6: Trigger Synchronization & Validate Access

1. Restart the AWS Load Balancer Controller to process the patched nodes and new service:
   ```bash
   kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
   ```
2. Check controller logs to ensure zero reconciliation errors:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50
   ```
3. Confirm Target Group status in AWS:
   * Navigate to **EC2** $
ightarrow$ **Target Groups** $
ightarrow$ **Targets**.
   * Verify all worker nodes appear and display a status of **Healthy**.
4. Retrieve the external DNS URL and test external access:
   ```bash
   kubectl get svc frontend-external-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
5. Paste the returned hostname into your browser (`http://<NLB-DNS-NAME>`) to verify the Online Boutique application loads correctly.