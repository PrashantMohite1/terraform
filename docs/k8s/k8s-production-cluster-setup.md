


### k8s ports which we needs to be open - 
https://kubernetes.io/docs/reference/networking/ports-and-protocols/

command to check weather the port is open or not using netcat 
nc <ip-addr> 22 -zv -w 2

### Swap Memory 
if swap memory is enabled on nodes - k8s will gives us error 
The default behavior of a kubelet is to fail to start if swap memory is detected on a node. This means that swap should either be disabled or tolerated by kubelet.

### Container Runtime and container runtime Interface
- container runtime - : to run containers in pod it needs container runtime

The Container Runtime Interface (CRI) 
- is the main protocol for the communication between the kubelet and Container Runtime.
- The Kubernetes Container Runtime Interface (CRI) defines the main gRPC protocol for the communication between the node components kubelet and container runtime.

---

### Version skew 

Kubernetes versions are expressed as x.y.z, where x is the major version, y is the minor version, and z is the patch version. The Kubernetes project maintains release branches for the most recent three minor releases (1.36, 1.35, 1.34).

Applicable fixes, including security fixes, may be backported to those three release branches, depending on severity and feasibility.

**what does version skew means ?**
Different Kubernetes components in the same cluster are running different versions.
```
API Server = 1.36
             │
             ├── kubelet 1.36   ← no skew
             ├── kubelet 1.35   ← 1 minor version skew
             └── kubelet 1.34   ← 2 minor versions skew
```


**API Server version** - ( in prod there should be more than one api server - master node)
In highly-available (HA) clusters, the newest and oldest kube-apiserver instances must be within one minor version.

Example:
newest kube-apiserver is at 1.36
other kube-apiserver instances are supported at 1.36 and 1.35


**kubelet, kubeproxy, kube-controller-manager, kube-scheduler, and cloud-controller-manager Versions requirement**

should not be newer than api server version 

- kubelet may be up to three minor versions older than kube-apiserver (kubelet < 1.25 may only be up to two minor versions older than kube-apiserver).

- kube-proxy may be up to three minor versions older than kube-apiserver (kube-proxy < 1.25 may only be up to two minor versions older than kube-apiserver).

- kubectl is supported within one minor version (**older or newer**) of kube-apiserver.

- kube-controller-manager, kube-scheduler, and cloud-controller-manager must not be newer than the kube-apiserver instances they communicate with. They are expected to match the kube-apiserver minor version, but may be up to one minor version older (to allow live upgrades).

Example:

kube-apiserver is at 1.36
- kubelet is supported at 1.36, 1.35, 1.34, and 1.33
- kube-proxy is supported at 1.36, 1.35, 1.34, and 1.33
- kubectl is supported at 1.37, 1.36, and 1.35
- kube-controller-manager, kube-scheduler, and cloud-controller-manager are supported at 1.36, 1.35



### container runtime setup 

Kubernetes starting v1.26 only works with v1 of the CRI API. If a container runtime does not support the v1 API, the kubelet will not register as a node.
containerd version 1.6.0 or later supports the required v1 Container Runtime Interface (CRI) API.

By default, the Linux kernel does not allow IPv4 packets to be routed between interfaces. Most Kubernetes cluster networking implementations will change this setting (if needed), but some might expect the administrator to do it for them.

Enable IPv4 packet forwarding

```
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# verify output should 1
sysctl net.ipv4.ip_forward

```


### Control Groups 
On Linux, control groups constrain resources that are allocated to processes.
There are two versions of cgroups in Linux: cgroup v1 and cgroup v2. cgroup v2 is the new generation of the cgroup API.
cgroup v2 provides a unified control system with enhanced resource management capabilities.

Identify cgroups version in linux 
```
stat -fc %T /sys/fs/cgroup/
```

For cgroup v2, the output is cgroup2fs.
For cgroup v1, the output is tmpfs.


set systemd as cgroup manager for kubelet and container runtime 

When systemd is chosen as the init system for a Linux distribution, the init process generates and consumes a root control group (cgroup) and acts as a cgroup manager.
use systemd as the cgroup driver for the kubelet and the container runtime when systemd is the selected init system.

What does “systemd is the init system” mean?

When Linux boots, the first userspace process is started as PID 1.Its job is to start and manage other system processes/services.
On most modern Linux distributions, that PID 1 process is systemd.

command to check init system 
```
ps -p 1 -o comm=
```

Kubelet : edit kublet configuration yaml file 

```
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
...
cgroupDriver: systemd
```


Configuring the systemd cgroup driver
To use the systemd cgroup driver in /etc/containerd/config.toml with runc, set the following config based on your Containerd version

command to check cgroup version :
```
stat -fc %T /sys/fs/cgroup/
```

Containerd versions 1.x:

```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

Containerd versions 2.x:

```
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  ...
  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
    SystemdCgroup = true

```




---
### Installing kubeadm, kubelet and kubectl


we need to make sure kubeadm, kubelet and kubectl should have same version other wise will get version skew and will cause setup gives unexpected errors.
kubeadm init --kubernetes-version=v1.26.x 

CRI version support
Your container runtime must support v1 of the container runtime interface.

Kubernetes starting v1.26 only works with v1 of the CRI API. If a container runtime does not support the v1 API, the kubelet will not register as a node


Installation commands 

```
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


```

Add the appropriate Kubernetes apt repository. Please note that this repository have packages only for Kubernetes 1.36; for other Kubernetes minor versions, you need to change the Kubernetes minor version in the URL to match your desired minor version (you should also check that you are reading the documentation for the version of Kubernetes that you plan to install).

```
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

```

```
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```


### Initializing your control-plane node
```
kubeadm init <args>
```


init options : 
- (Recommended) If you have plans to upgrade this single control-plane kubeadm cluster to high availability you should specify the `--control-plane-endpoint` to set the shared endpoint for all control-plane nodes. Such an endpoint can be either a DNS name or an IP address of a load-balancer.
--control-plane-endpoint=cluster-endpoint

- Choose a Pod network add-on, and verify whether it requires any arguments to be passed to kubeadm init. Depending on which third-party provider you choose, you might need to set the `--pod-network-cidr` to a provider-specific value. See Installing a Pod network add-on.


```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```



### Install CRI (container runtime interface) - networking plugin 


CNI installation : 
in order to talk to containers , networking of container we need cni plugins. there are bunch of cni (container network interface) plugins such as
calico, flannel , cannel and many more. 

calico installation steps

```
# Install Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml

# Install Calico Custom Resources (requires custom-resources.yaml)
kubectl create -f custom-resources.yaml   
```

cilium installation 

```
# Add the repository
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install with default settings
helm install cilium cilium/cilium --version 1.20.0 --namespace kube-system

# Or use OCI registry (Recommended for reproducible deployments)
helm install cilium oci://quay.io/cilium/charts/cilium --version 1.20.0 --namespace kube-system   
```


### Join worker nodes to master node 

```
kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```







