# 🌟 Nova-Lab - Projet DevOps/Infrastructure as Code

> **Projet complet pour la gestion d'infrastructure avec Vagrant, Ansible, Kubernetes (k3s) et Helm**

Ce dépôt contient une **infrastructure complète** pour déployer et gérer des applications conteneurisées sur Kubernetes en utilisant les meilleurs outils DevOps.

---

## 📋 **Structure du projet**

```
nova-lab/
├── Vagrantfile                      # TP0: 3 VM (ctrl, preprod, prod)
├── Makefile                         # TP15: Orchestration complète
├── .editorconfig                    # Configuration de l'éditeur
├── .gitattributes                   # Attributs Git
├── .gitignore                       # Fichiers ignorés par Git
├── .yamllint                        # Configuration yamllint
├── .ansible-lint                    # Configuration ansible-lint
│
├── scripts/                         # Scripts de provisionnement
│   ├── provision-ctrl.sh            # TP0: Installe Ansible, Helm, kubectl
│   ├── provision-node.sh            # TP0: Prépare preprod et prod (k3s)
│   └── rotate-token.sh              # TP14: Rotation des secrets
│
├── ansible/                         # Configuration Ansible
│   ├── ansible.cfg                  # Configuration globale Ansible
│   ├── requirements.yml             # Collections Ansible
│   │
│   ├── inventories/                 # Inventaire Ansible
│   │   ├── hosts.yml                # Groupes (ctrl, preprod, prod)
│   │   └── group_vars/              # Variables par environnement
│   │       ├── all/main.yml         # Variables communes
│   │       ├── preprod/main.yml     # Variables preprod
│   │       ├── preprod/vault.yml    # Secrets preprod (à chiffrer)
│   │       ├── prod/main.yml        # Variables prod
│   │       └── prod/vault.yml       # Secrets prod (à chiffrer)
│   │
│   ├── playbooks/                   # Playbooks Ansible
│   │   ├── baseline.yml             # TP1: Configuration de base
│   │   ├── cluster.yml              # TP5: Déploiement du cluster k3s
│   │   ├── harden.yml               # TP11: Hardening des nœuds
│   │   ├── deploy.yml               # TP9-10: Déploiement avec Helm
│   │   ├── audit.yml                # TP12: Audit de conformité
│   │   └── site.yml                 # Orchestration de tous les playbooks
│   │
│   └── roles/                       # Rôles Ansible
│       ├── common/                  # TP3: Configuration commune
│       ├── k3s/                     # TP5: Installation de k3s
│       ├── helm_cli/                # TP5: Installation de Helm
│       ├── nova_release/            # TP9-10: Déploiement de l'application
│       ├── hardening/               # TP11: Hardening
│       ├── access/                  # TP14: Gestion des accès
│       └── compliance/              # TP12: Vérification de conformité
│
├── charts/nova-hello/               # TP6-8: Chart Helm de l'application
│   ├── Chart.yaml                   # Métadonnées du chart
│   ├── values.yaml                  # Valeurs par défaut
│   ├── values-preprod.yaml          # Valeurs pour preprod
│   ├── values-prod.yaml             # Valeurs pour prod
│   ├── values.schema.json           # Schéma de validation JSON
│   │
│   └── templates/                   # Templates Kubernetes
│       ├── _helpers.tpl            # Fonctions utiles
│       ├── configmap.yaml           # ConfigMap
│       ├── deployment.yaml          # Deployment
│       ├── hpa.yaml                 # HorizontalPodAutoscaler
│       ├── ingress.yaml             # Ingress
│       ├── namespace.yaml           # Namespace
│       ├── networkpolicy.yaml       # NetworkPolicy
│       ├── pdb.yaml                 # PodDisruptionBudget
│       ├── secret.yaml              # Secret
│       ├── service.yaml             # Service
│       ├── serviceaccount.yaml      # ServiceAccount
│       └── tests/test-connection.yaml # Tests Helm
│
└── tests/goss/                      # TP12: Tests de conformité
    └── ...                          # Spécifications Goss
```

---

## 🚀 **Démarrage rapide**

### 1️⃣ **Prérequis**

- **VirtualBox** installé sur Windows (visible depuis WSL2)
- **Vagrant** installé (sur Windows ou dans WSL2)
- **Git** installé

### 2️⃣ **Lancer les VM**

```bash
# Depuis le répertoire nova-lab
cd nova-lab

# Démarrer toutes les VM
vagrant up

# Ou démarrer sélectivement
vagrant up ctrl        # Machine de contrôle
vagrant up preprod     # Environnement de préproduction
vagrant up prod        # Environnement de production
```

### 3️⃣ **Se connecter aux VM**

```bash
# Se connecter à la machine de contrôle
vagrant ssh ctrl

# Se connecter à preprod
vagrant ssh preprod

# Se connecter à prod
vagrant ssh prod
```

### 4️⃣ **Utiliser le Makefile pour orchestrer**

```bash
# Affiche l'aide (liste de toutes les commandes)
make

# Exécuter la configuration complète
make full-deploy

# Vérifier la connectivité Ansible
make ansible-ping

# Déployer l'application
make helm-deploy-dev
make helm-deploy-prod

# Effectuer un audit
make ansible-audit

# Nettoyer tout
make full-destroy
```

---

## 📊 **TP par TP**

### **TP0: Mise en place des VM avec Vagrant**
- ✅ **Vagrantfile** : Configuration de 3 VM (ctrl, preprod, prod)
- ✅ **scripts/provision-ctrl.sh** : Installe Ansible, Helm, kubectl, Docker
- ✅ **scripts/provision-node.sh** : Prépare les nœuds k3s

**Commandes:**
```bash
vagrant up
vagrant ssh ctrl
```

---

### **TP1: Configuration Ansible de base**
- ✅ **ansible/inventories/hosts.yml** : Inventaire avec les 3 groupes
- ✅ **ansible/inventories/group_vars/** : Variables par environnement
- ✅ **ansible/ansible.cfg** : Configuration globale
- ✅ **ansible/requirements.yml** : Collections nécessaires

**Commandes:**
```bash
cd ansible
ansible all -m ping
```

---

### **TP3: Rôle common pour la configuration de base**
- ✅ **ansible/roles/common/** : Configuration système commune
- ✅ Baseline système, utilisateurs, SSH, sécurité

**Commandes:**
```bash
make ansible-baseline
```

---

### **TP5: Déploiement du cluster Kubernetes avec k3s**
- ✅ **ansible/roles/k3s/** : Installation et configuration de k3s
- ✅ **ansible/roles/helm_cli/** : Installation de Helm
- ✅ **ansible/playbooks/cluster.yml** : Orchestration du cluster

**Commandes:**
```bash
make k3s-install
kubectl get nodes
```

---

### **TP6-8: Création du chart Helm nova-hello**
- ✅ **charts/nova-hello/** : Chart Helm complet
- ✅ **values.yaml** : Valeurs par défaut
- ✅ **values-preprod.yaml** : Configuration preprod
- ✅ **values-prod.yaml** : Configuration prod
- ✅ **templates/** : Tous les manifests Kubernetes

**Commandes:**
```bash
cd charts/nova-hello
helm lint .
helm template . -f values-preprod.yaml
```

---

### **TP9-10: Ansible pilote Helm**
- ✅ **ansible/roles/nova_release/** : Déploiement via Ansible
- ✅ **ansible/playbooks/deploy.yml** : Orchestration du déploiement

**Commandes:**
```bash
make ansible-helm-deploy
```

---

### **TP11: Hardening des nœuds**
- ✅ **ansible/roles/hardening/** : Application des bonnes pratiques
- ✅ **ansible/playbooks/harden.yml** : Orchestration du hardening

**Commandes:**
```bash
make ansible-harden
```

---

### **TP12: Audit de conformité avec Goss**
- ✅ **ansible/roles/compliance/** : Vérification de conformité
- ✅ **ansible/playbooks/audit.yml** : Orchestration de l'audit
- ✅ **tests/goss/** : Spécifications Goss

**Commandes:**
```bash
make ansible-audit
```

---

### **TP14: Rotation des secrets**
- ✅ **scripts/rotate-token.sh** : Script de rotation
- ✅ **ansible/roles/access/** : Gestion des accès
- ✅ **ansible/inventories/group_vars/*/vault.yml** : Secrets chiffrés

**Commandes:**
```bash
./scripts/rotate-token.sh --environment preprod
./scripts/rotate-token.sh --environment prod --dry-run
```

---

### **TP15: Orchestration de bout en bout**
- ✅ **Makefile** : Orchestration complète
- ✅ **ansible/playbooks/site.yml** : Playbook principal

**Commandes:**
```bash
# Déploiement complet
make full-deploy

# Nettoyage complet
make full-destroy

# Rafraîchissement complet
make full-refresh
```

---

## 🔐 **Gestion des secrets**

### Chiffrer les fichiers vault.yml

```bash
# Chiffrer le fichier vault pour preprod
ansible-vault encrypt ansible/inventories/group_vars/preprod/vault.yml

# Chiffrer le fichier vault pour prod
ansible-vault encrypt ansible/inventories/group_vars/prod/vault.yml

# Éditer un fichier chiffré
ansible-vault edit ansible/inventories/group_vars/preprod/vault.yml
```

### Déchiffrer les fichiers vault.yml

```bash
# Déchiffrer pour exécution
ansible-playbook playbooks/deploy.yml --ask-vault-pass

# Utiliser un fichier de mot de passe
ansible-playbook playbooks/deploy.yml --vault-password-file ~/.vault_pass.txt
```

---

## 🎯 **Commandes utiles**

### Gestion des VM

```bash
# Démarrer toutes les VM
vagrant up

# Arrêter toutes les VM
vagrant halt

# Détruire toutes les VM
vagrant destroy -f

# Re-provisionner
vagrant provision

# Se connecter
vagrant ssh ctrl
vagrant ssh preprod
vagrant ssh prod
```

### Gestion Kubernetes

```bash
# Voir les nœuds
kubectl get nodes

# Voir les pods
kubectl get pods -A

# Voir les services
kubectl get svc -A

# Voir les namespaces
kubectl get ns
```

### Gestion Helm

```bash
# Lister les releases
helm list -A

# Voir le statut
helm status nova-hello -n nova-hello-preprod

# Mettre à jour
helm upgrade nova-hello charts/nova-hello -n nova-hello-preprod -f values-preprod.yaml

# Rollback
helm rollback nova-hello 1 -n nova-hello-preprod
```

### Gestion Ansible

```bash
# Tester la connectivité
ansible all -m ping

# Exécuter un playbook
ansible-playbook playbooks/baseline.yml

# Voir l'inventaire
ansible-inventory --graph

# Lister les hôtes
ansible all --list-hosts
```

---

## 📚 **Documentation supplémentaire**

### Guides de référence

Le dépôt contient également des guides complets pour chaque outil :

- **COMMANDES_VIRTUALBOX.md** : Gestion des VM VirtualBox
- **COMMANDES_VAGRANT.md** : Provisionnement avec Vagrant
- **COMMANDES_ANSIBLE.md** : Configuration avec Ansible
- **COMMANDES_HELM.md** : Gestion des applications Kubernetes
- **COMMANDES_TERRAFORM.md** : Infrastructure as Code

### Ressources externes

- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [k3s Documentation](https://docs.k3s.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Goss Documentation](https://github.com/aelsabbahy/goss)

---

## 🤝 **Contribuer**

1. Forker le projet
2. Créer une branche de fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commiter vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Pousser vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📄 **Licence**

Ce projet est sous licence **MIT** - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

## 🙏 **Remerciements**

- HashiCorp (Vagrant, Terraform)
- Red Hat (Ansible)
- Rancher (k3s)
- Helm Community
- Tous les contributeurs open source

---

*Créé avec ❤️ pour la formation DevOps*
