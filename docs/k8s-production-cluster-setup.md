


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

---
### Installing kubeadm, kubelet and kubectl


we need to make sure kubeadm, kubelet and kubectl should have same version other wise will get version skew and will cause setup gives unexpected errors.
kubeadm init --kubernetes-version=v1.26.x 

CRI version support
Your container runtime must support v1 of the container runtime interface.

Kubernetes starting v1.26 only works with v1 of the CRI API. If a container runtime does not support the v1 API, the kubelet will not register as a node


### Install Kubectl 

```
Update the apt package index and install packages needed to use the Kubernetes apt repository:

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:
# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
```

Add the appropriate Kubernetes apt repository. If you want to use Kubernetes version different than v1.36, replace v1.36 with the desired minor version in the command below:

This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
```
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to 
```

Update apt package index, then install kubectl:
```
sudo apt-get update
sudo apt-get install -y kubectl
```

