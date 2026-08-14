
# first handson - two master node and one worker node 
# one lb (ha proxy on one vm ), 2 master node , 2 worker nodes . 


#open  ports 
#https://kubernetes.io/docs/reference/networking/ports-and-protocols/


#permanently disable swap 
sudo vi /etc/fstab
# find swap entry and comment it 
sudo swapoff -a

# install containerd 
sudo apt update
sudo apt install -y containerd
sudo systemctl enable --now containerd   

#Enable IPV4 packet forwarding
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# verify output should 1
sysctl net.ipv4.ip_forward



# set systemd as cgroup manager for kubelet and container runtime on ALL NODES

# check cgroup 
# cgroup_version = stat -fc %T /sys/fs/cgroup/


# Open or create the configuration file at /etc/containerd/config.toml.
# if not exist 
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml   

vi /etc/containerd/config.toml

# change SystemdCgroup = true in containerd.runtimes.runc.options 
sudo systemctl restart containerd   




#install kubelet, kubeadm, kubectl 
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet=1.36.3-1.1 kubeadm=1.36.3-1.1 kubectl=1.36.3-1.1
sudo apt-mark hold kubelet kubeadm kubectl

kubeadm init --pod-network-cidr=10.1.0.0/16
# set systemd as cgroup for kubelet 
# Note 1 : kubeadm init automatically detects containerd and writes the correct systemd configuration to the kubelet.
# Note 2 : kubeadm join pulls the cluster configuration from the master and automatically configures the local kubelet to match.

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

################### calico installation #################################

### 1. Install Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml

### 2. Wait for Operator Pod to be Ready
kubectl get pods -n tigera-operator -w
# (Press Ctrl+C once the tigera-operator pod shows STATUS: Running)

### 3. Download and Patch Custom Resources to Match Cluster Pod CIDR (10.1.0.0/16)
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources.yaml
sed -i 's|192.168.0.0/16|10.1.0.0/16|g' custom-resources.yaml

### 4. Apply Patched Custom Resources
kubectl apply -f custom-resources.yaml

### 5. Verify Calico Installation
kubectl get tigerastatus
kubectl get nodes

##################### join command 
kubeadm join LOAD_BALANCER_DNS:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <key> \
  --apiserver-advertise-address=10.0.1.12




