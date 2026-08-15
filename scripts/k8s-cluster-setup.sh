#!/bin/bash

set -euo pipefail


# ============================================================
# Configuration
# ============================================================
REGION="us-east-1"
K8S_VERSION="v1.36"
CALICO_VERSION="v3.28.0"

KUBELET_VERSION="1.36.3-1.1"
KUBEADM_VERSION="1.36.3-1.1"
KUBECTL_VERSION="1.36.3-1.1"

POD_CIDR="10.1.0.0/16"
SSM_PARAM_NAME="/k8s/join-command"

CONTAINERD_CONFIG="/etc/containerd/config.toml"
K8S_REPO_FILE="/etc/apt/sources.list.d/kubernetes.list"
K8S_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"

# Calico Manifest URL constructed dynamically
CALICO_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"


# ============================================================
# Utility
# ============================================================

run_command() {
    echo
    echo "Running: $*"

    if "$@"; then
        echo "SUCCESS: $*"
    else
        echo "FAILED: $*"
        return 1
    fi
}


# ============================================================
# Disable Swap
# ============================================================

disable_swap() {
    echo
    echo "=========================================="
    echo " Disabling Swap"
    echo "=========================================="

    if swapon --show | grep -q .; then
        echo "Swap is enabled."
        run_command swapoff -a

        if grep -q 'swap' /etc/fstab; then
            echo "Removing swap entry from /etc/fstab"
            sed -i '/swap/d' /etc/fstab
        else
            echo "No swap entry found in /etc/fstab."
        fi
    else
        echo "Swap is already disabled."
    fi
}


# ============================================================
# Kernel Configuration
# ============================================================

configure_kernel() {
    echo
    echo "=========================================="
    echo " Configuring Kernel"
    echo "=========================================="

    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    run_command sysctl --system

    if [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]]; then
        echo "IPv4 forwarding enabled."
    else
        echo "ERROR: IPv4 forwarding is not enabled."
        exit 1
    fi
}


# ============================================================
# Install containerd
# ============================================================

install_containerd() {
    echo
    echo "=========================================="
    echo " Installing containerd"
    echo "=========================================="

    run_command apt-get update
    run_command apt-get install -y containerd
    run_command mkdir -p /etc/containerd

    echo "Generating containerd configuration..."
    containerd config default > "$CONTAINERD_CONFIG"

    echo "Enabling SystemdCgroup..."
    sed -i \
        's/SystemdCgroup = false/SystemdCgroup = true/' \
        "$CONTAINERD_CONFIG"

    if grep -q 'SystemdCgroup = true' "$CONTAINERD_CONFIG"; then
        echo "SystemdCgroup successfully enabled."
    else
        echo "ERROR: Failed to enable SystemdCgroup."
        exit 1
    fi

    run_command systemctl restart containerd
    run_command systemctl enable containerd

    if systemctl is-active --quiet containerd; then
        echo "containerd is running."
    else
        echo "ERROR: containerd is not running."
        exit 1
    fi
}

un_command systemctl enable kubelet
}


# ============================================================
# Install Kubernetes
# ============================================================

install_kubernetes() {
    echo
    echo "=========================================="
    echo " Installing Kubernetes & AWS CLI"
    echo "=========================================="

    # 1. Update apt and install basic dependencies
    run_command apt-get update
    run_command apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gpg \
        unzip

    # 2. Install AWS CLI v2 official binary if not present
    if ! command -v aws &> /dev/null; then
        echo "Installing AWS CLI v2..."
        curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        unzip -q /tmp/awscliv2.zip -d /tmp
        /tmp/awscliv2.zip_extracted/install --bin-dir /usr/bin --install-dir /usr/local/aws-cli || /tmp/aws/install --bin-dir /usr/bin --install-dir /usr/local/aws-cli
        rm -rf /tmp/awscliv2.zip /tmp/aws
    else
        echo "AWS CLI is already installed."
    fi

    run_command mkdir -p -m 755 /etc/apt/keyrings

    echo "Adding Kubernetes GPG key..."
    curl -fsSL \
        "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
        | gpg --yes --dearmor -o "$K8S_KEYRING"

    echo "Adding Kubernetes repository..."
    cat > "$K8S_REPO_FILE" <<EOF
deb [signed-by=${K8S_KEYRING}] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /
EOF

    run_command apt-get update
    run_command apt-get install -y \
        "kubelet=${KUBELET_VERSION}" \
        "kubeadm=${KUBEADM_VERSION}" \
        "kubectl=${KUBECTL_VERSION}"

    run_command apt-mark hold kubelet kubeadm kubectl
    run_command systemctl enable kubelet
}

# ============================================================
# Create OS User with Sudo Access
# ============================================================

create_node_user() {
    local USERNAME="$1"
    local PASSWORD='@dMin4#@1'

    echo
    echo "=========================================="
    echo " Creating User: ${USERNAME}"
    echo "=========================================="

    if id "$USERNAME" &>/dev/null; then
        echo "User ${USERNAME} already exists."
    else
        useradd -m -s /bin/bash "$USERNAME"
        echo "${USERNAME}:${PASSWORD}" | chpasswd
        usermod -aG sudo "$USERNAME"
        echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"
        chmod 0440 "/etc/sudoers.d/${USERNAME}"

        echo "User ${USERNAME} created and granted sudo privileges."
    fi
}


# ============================================================
# Master Initialization
# ============================================================

initialize_master() {
    echo
    echo "=========================================="
    echo " Initializing Kubernetes Control Plane"
    echo "=========================================="

    create_node_user "k8s-admin"

    kubeadm init \
        --pod-network-cidr="$POD_CIDR" \
        | tee /k8s-init.txt

    echo
    echo "Control plane initialized."

    # Set up kubeconfig for k8s-admin user
    echo "Setting up admin kubeconfig for k8s-admin and root..."
    mkdir -p /home/k8s-admin/.kube
    cp -i /etc/kubernetes/admin.conf /home/k8s-admin/.kube/config
    chown -R k8s-admin:k8s-admin /home/k8s-admin/.kube

    # Also set up kubeconfig for root user
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
    export KUBECONFIG=/etc/kubernetes/admin.conf

    # Install Calico CNI Plugin
    echo
    echo "=========================================="
    echo " Installing Calico CNI Plugin (${CALICO_VERSION})"
    echo "=========================================="

    echo "Downloading and tailoring Calico manifest for Pod CIDR (${POD_CIDR})..."
    curl -sSL "$CALICO_MANIFEST_URL" -o /tmp/calico.yaml
    sed -i "s|192.168.0.0/16|${POD_CIDR}|g" /tmp/calico.yaml

    kubectl apply -f /tmp/calico.yaml

    echo "Waiting for Calico node pods to stabilize..."
    kubectl rollout status daemonset/calico-node -n kube-system --timeout=120s || true

    publish_join_information
}


# ============================================================
# Master: Publish Join Information
# ============================================================

publish_join_information() {
    echo
    echo "=========================================="
    echo " Publishing Kubernetes Join Information"
    echo "=========================================="

    JOIN_CMD=$(kubeadm token create --print-join-command)

    aws ssm put-parameter \
        --name "$SSM_PARAM_NAME" \
        --type "SecureString" \
        --value "$JOIN_CMD" \
        --overwrite \
        --region "${REGION}"

    echo
    echo "Kubernetes join information published successfully."
}


# ============================================================
# Worker Join
# ============================================================

join_worker() {
    echo
    echo "=========================================="
    echo " Joining Worker Node"
    echo "=========================================="

    create_node_user "k8s-worker"

    echo "Fetching join command from SSM Parameter Store..."
    
    # Retry loop (attempts to fetch token for up to 5 minutes)
    JOIN_CMD=""
    for i in {1..30}; do
        JOIN_CMD=$(aws ssm get-parameter \
            --name "$SSM_PARAM_NAME" \
            --with-decryption \
            --query "Parameter.Value" \
            --output text \
            --region "${REGION}" 2>/dev/null || true)

        if [[ -n "$JOIN_CMD" ]]; then
            echo "Successfully retrieved join command."
            break
        fi

        echo "Waiting for control plane to publish join command (Attempt $i/30)..."
        sleep 10
    done

    if [[ -z "$JOIN_CMD" ]]; then
        echo "ERROR: Timed out waiting for join command from SSM Parameter Store."
        exit 1
    fi

    eval "$JOIN_CMD"
}


# ============================================================
# Main
# ============================================================

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Script must be run as root."
    echo
    echo "Usage:"
    echo "  sudo ./setup.sh master"
    echo "  sudo ./setup.sh worker"
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "ERROR: Role is required."
    echo
    echo "Usage:"
    echo "  sudo ./setup.sh master"
    echo "  sudo ./setup.sh worker"
    exit 1
fi

ROLE="$1"


# ============================================================
# Common Setup
# ============================================================

echo
echo "=========================================="
echo " Kubernetes Node Setup"
echo " Role: $ROLE"
echo "=========================================="

disable_swap
configure_kernel
install_containerd
install_kubernetes


# ============================================================
# Role Specific Setup
# ============================================================

case "$ROLE" in
    master)
        initialize_master
        ;;
    worker)
        join_worker
        ;;
    *)
        echo "ERROR: Invalid role '$ROLE'"
        echo
        echo "Valid roles:"
        echo "  master"
        echo "  worker"
        exit 1
        ;;
esac

echo
echo "=========================================="
echo " Kubernetes Setup Completed"
echo "=========================================="