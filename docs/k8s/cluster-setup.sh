
# first handson - two master node and one worker node 
# one lb (ha proxy on one vm ), 2 master node , 2 worker nodes . 


#open  ports 
#https://kubernetes.io/docs/reference/networking/ports-and-protocols/


#permanently disable swap 
sudo vi /etc/fstab
# find swap entry and comment it 
sudo swapoff -a

# install containerd 

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
cgroup_version = stat -fc %T /sys/fs/cgroup/


# Open or create the configuration file at /etc/containerd/config.toml.
# if not exist 
containerd config default > /etc/containerd/config.toml

vi /etc/containerd/config.toml

# change SystemdCgroup = true in containerd.runtimes.runc.options 





#install kubelet, kubeadm, kubectl 

kubeadm join LOAD_BALANCER_DNS:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <key> \
  --apiserver-advertise-address=10.0.1.12

sudo apt-get install -y kubelet=1.36.3 kubeadm=1.36.3 kubectl=1.36.3

kubeam init --pod-network-cidr=10.1.0.0/16 --control-plane-endpoint string
# set systemd as cgroup for kubelet 
# Note 1 : kubeadm init automatically detects containerd and writes the correct systemd configuration to the kubelet.
# Note 2 : kubeadm join pulls the cluster configuration from the master and automatically configures the local kubelet to match.

vi /var/lib/kubelet/config.yaml
# change cgroupDriver: systemd




########### # kubeadm join On Worker nodes  #######################
