#!/bin/bash
# TP0: Script de provisionnement de la VM ctrl
# Installe Ansible, Helm, kubectl et configure les clés SSH

set -e

# ============================================
# Variables
# ============================================
USER="vagrant"
HOME_DIR="/home/$USER"

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
    python3-venv \
    openssh-client \
    openssh-server \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# ============================================
# Installation de Docker (pour k3s)
# ============================================
echo "🐳 Installation de Docker..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# ============================================
# Installation de Python virtualenv pour Ansible
# ============================================
echo "🐍 Configuration de Python pour Ansible..."
python3 -m venv $HOME_DIR/venv
source $HOME_DIR/venv/bin/activate
pip install --upgrade pip

# ============================================
# Installation d'Ansible
# ============================================
echo "🎯 Installation d'Ansible..."
pip install --upgrade ansible ansible-core ansible-lint yamllint

# Vérifier l'installation
ansible --version
ansible-lint --version

# ============================================
# Installation de kubectl
# ============================================
echo "☸️  Installation de kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# ============================================
# Installation de Helm
# ============================================
echo "⚓ Installation de Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# ============================================
# Configuration SSH
# ============================================
echo "🔑 Configuration SSH..."

# Créer le répertoire .ssh
mkdir -p $HOME_DIR/.ssh
chmod 700 $HOME_DIR/.ssh

# Générer une clé SSH si elle n'existe pas
if [ ! -f $HOME_DIR/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f $HOME_DIR/.ssh/id_rsa -N "" -C "vagrant@ctrl"
fi

# Configurer la clé SSH pour les nodes
cat $HOME_DIR/.ssh/id_rsa.pub | sudo tee -a $HOME_DIR/.ssh/authorized_keys

# Copier la clé publique pour les connections aux nodes
sudo mkdir -p /root/.ssh
sudo cp $HOME_DIR/.ssh/id_rsa.pub /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

# Configurer SSH pour ne pas demander de confirmation
cat > $HOME_DIR/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    User vagrant
    IdentityFile ~/.ssh/id_rsa
EOF

chmod 600 $HOME_DIR/.ssh/config

# ============================================
# Configuration pour Ansible
# ============================================
echo "📝 Configuration pour Ansible..."

# Créer le répertoire ansible
mkdir -p $HOME_DIR/ansible

# Créer un inventaire par défaut
cat > $HOME_DIR/ansible/hosts.ini << 'EOF'
[ctrl]
127.0.0.1 ansible_connection=local

[preprod]
192.168.56.20

[prod]
192.168.56.30

[nodes:children]
preprod
prod

[all:vars]
ansible_user=vagrant
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
EOF

# ============================================
# Configuration pour kubectl
# ============================================
echo "📝 Configuration pour kubectl..."
mkdir -p $HOME_DIR/.kube

# ============================================
# Installation de k3s (lightweight Kubernetes)
# ============================================
echo "☸️  Installation de k3s (pour le développement local)..."
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# ============================================
# Configuration du PATH
# ============================================
echo "📌 Mise à jour du PATH..."
cat >> $HOME_DIR/.bashrc << 'EOF'

# Ajout des binaires
if [ -d "$HOME/venv/bin" ]; then
    PATH="$HOME/venv/bin:$PATH"
fi

# Alias utiles
alias k="kubectl"
alias h="helm"
alias ans="ansible"
alias tf="terraform"

# Auto-complétion
source <(kubectl completion bash)
source <(helm completion bash)
EOF

cat >> $HOME_DIR/.zshrc << 'EOF'

# Ajout des binaires
if [ -d "$HOME/venv/bin" ]; then
    PATH="$HOME/venv/bin:$PATH"
fi

# Alias utiles
alias k="kubectl"
alias h="helm"
alias ans="ansible"
alias tf="terraform"

# Auto-complétion
if command -v kubectl &> /dev/null; then
    source <(kubectl completion zsh)
fi
if command -v helm &> /dev/null; then
    source <(helm completion zsh)
fi
EOF

# ============================================
# Message de fin
# ============================================
echo ""
echo "✅ Provisionnement de la VM ctrl terminé !"
echo ""
echo "Informations utiles :"
echo "  - Ansible : $(ansible --version | head -n1)"
echo "  - Helm : $(helm version | head -n1)"
echo "  - kubectl : $(kubectl version --client --short | head -n1)"
echo "  - Docker : $(docker --version)"
echo ""
echo "Pour commencer, connectez-vous avec : vagrant ssh ctrl"
