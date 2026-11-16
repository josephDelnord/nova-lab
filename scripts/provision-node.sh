#!/bin/bash
# TP0: Script de provisionnement des VM preprod et prod
# Prépare les nœuds Kubernetes (k3s)

set -e

# ============================================
# Variables
# ============================================
ENVIRONMENT="${1:-unknown}"  # preprod ou prod
USER="vagrant"
HOME_DIR="/home/$USER"
NODE_NAME="$HOSTNAME"

# ============================================
# Validation
# ============================================
if [ "$ENVIRONMENT" != "preprod" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo "❌ Erreur: L'environnement doit être 'preprod' ou 'prod'"
    exit 1
fi

echo "🔄 Provisionnement du nœud $NODE_NAME ($ENVIRONMENT)..."

# ============================================
# Mise à jour du système
# ============================================
echo "🔄 Mise à jour du système..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# ============================================
# Installation des dépendances
# ============================================
echo "📦 Installation des dépendances..."
sudo apt-get install -y -qq \
    curl \
    wget \
    git \
    unzip \
    python3 \
    python3-pip \
    openssh-client \
    openssh-server \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    iptables \
    net-tools

# ============================================
# Désactiver le swap
# ============================================
echo "💾 Désactivation du swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# ============================================
# Configuration du kernel pour Kubernetes
# ============================================
echo "🔧 Configuration du kernel..."
cat > /tmp/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo cp /tmp/99-kubernetes-cri.conf /etc/sysctl.d/99-kubernetes-cri.conf
sudo sysctl --system

# ============================================
# Installation de containerd (pour k3s)
# ============================================
echo "📦 Installation de containerd..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -qq
sudo apt-get install -y -qq containerd.io

# Configurer containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# ============================================
# Installation de k3s
# ============================================
echo "☸️  Installation de k3s..."

if [ "$ENVIRONMENT" == "preprod" ]; then
    # Pour preprod, on installe un serveur k3s
    curl -sfL https://get.k3s.io | sh -s - server \
        --cluster-init \
        --tls-san "192.168.56.20" \
        --tls-san "preprod.novalab.local" \
        --node-name "preprod" \
        --disable traefik
else
    # Pour prod, on installe un serveur k3s
    curl -sfL https://get.k3s.io | sh -s - server \
        --cluster-init \
        --tls-san "192.168.56.30" \
        --tls-san "prod.novalab.local" \
        --node-name "prod" \
        --disable traefik
fi

# ============================================
# Configuration SSH
# ============================================
echo "🔑 Configuration SSH..."

# Créer le répertoire .ssh
mkdir -p $HOME_DIR/.ssh
chmod 700 $HOME_DIR/.ssh

# Configurer SSH pour ne pas demander de confirmation
cat > $HOME_DIR/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF

chmod 600 $HOME_DIR/.ssh/config

# ============================================
# Autoriser la connexion depuis ctrl
# ============================================
echo "🔓 Autorisation de la connexion depuis ctrl..."
sudo mkdir -p /root/.ssh
# On va récupérer la clé publique de ctrl plus tard via Ansible
# Pour l'instant, on autorise juste l'utilisateur vagrant
cat $HOME_DIR/.ssh/id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

# ============================================
# Configuration pour kubectl
# ============================================
echo "📝 Configuration pour kubectl..."
sudo mkdir -p $HOME_DIR/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME_DIR/.kube/config
sudo chown $USER:$USER $HOME_DIR/.kube/config
sudo chmod 600 $HOME_DIR/.kube/config

# Remplacer localhost par l'IP du nœud
sudo sed -i "s/127.0.0.1/$(hostname -I | awk '{print $1}')/" $HOME_DIR/.kube/config

# ============================================
# Installation de Python pour Ansible
# ============================================
echo "🐍 Installation de Python..."
sudo apt-get install -y -qq python3 python3-pip

# ============================================
# Installation de kubectl
# ============================================
echo "☸️  Installation de kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# ============================================
# Installation de Helm
# ============================================
echo "⚓ Installation de Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ============================================
# Configuration du PATH
# ============================================
echo "📌 Mise à jour du PATH..."
cat >> $HOME_DIR/.bashrc << 'EOF'

# Alias utiles
alias k="kubectl"
alias h="helm"

# Auto-complétion
source <(kubectl completion bash)
source <(helm completion bash)
EOF

cat >> $HOME_DIR/.zshrc << 'EOF'

# Alias utiles
alias k="kubectl"
alias h="helm"

# Auto-complétion
if command -v kubectl &> /dev/null; then
    source <(kubectl completion zsh)
fi
if command -v helm &> /dev/null; then
    source <(helm completion zsh)
fi
EOF

# ============================================
# Configuration réseau pour k3s
# ============================================
echo "🌐 Configuration réseau pour k3s..."
# Autoriser le trafic entre les nœuds
sudo ufw allow from 192.168.56.0/24
sudo ufw allow 6443/tcp  # Kubernetes API
sudo ufw allow 2379:2380/tcp  # etcd
sudo ufw allow 10250/tcp  # Kubelet API
sudo ufw allow 10251/tcp  # kube-scheduler
sudo ufw allow 10252/tcp  # kube-controller-manager
sudo ufw allow 8472/udp  # Flannel VXLAN

# ============================================
# Message de fin
# ============================================
echo ""
echo "✅ Provisionnement du nœud $NODE_NAME ($ENVIRONMENT) terminé !"
echo ""
echo "Informations utiles :"
echo "  - k3s : $(k3s --version)"
echo "  - kubectl : $(kubectl version --client --short | head -n1)"
echo "  - Helm : $(helm version | head -n1)"
echo ""
echo "Adresse IP: $(hostname -I | awk '{print $1}')"
echo "Nom du nœud: $NODE_NAME"
echo "Environnement: $ENVIRONMENT"
