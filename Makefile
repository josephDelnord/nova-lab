# TP15: Orchestration de bout en bout pour nova-lab
# Ce Makefile permet de gérer l'ensemble du workflow DevOps

.PHONY: help

# ============================================
# Variables
# ============================================
PROJECT := nova-lab
ANSIBLE_DIR := ansible
CHART_DIR := charts/nova-hello
SCRIPTS_DIR := scripts

# ============================================
# Aide
# ============================================
help: ## Affiche cette aide
	@echo "Makefile pour orchestrer le projet $(PROJECT)"
	@echo ""
	@echo "Cibles disponibles:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ============================================
# TP0: Gestion des VM Vagrant
# ============================================
vagrant-up: ## Démarre toutes les VM Vagrant
	@echo "🚀 Démarrage des VM Vagrant..."
	vagrant up

vagrant-up-ctrl: ## Démarre uniquement la VM ctrl
	@echo "🚀 Démarrage de la VM ctrl..."
	vagrant up ctrl

vagrant-up-nodes: ## Démarre uniquement les VM preprod et prod
	@echo "🚀 Démarrage des VM preprod et prod..."
	vagrant up preprod prod

vagrant-halt: ## Arrête toutes les VM
	@echo "⏹️  Arrêt des VM Vagrant..."
	vagrant halt

vagrant-destroy: ## Détruit toutes les VM
	@echo "💥 Destruction des VM Vagrant..."
	vagrant destroy -f

vagrant-provision: ## Re-provisionne toutes les VM
	@echo "🔄 Re-provisionnement des VM..."
	vagrant provision

vagrant-ssh-ctrl: ## Se connecte à la VM ctrl
	@echo "🔑 Connexion SSH à ctrl..."
	vagrant ssh ctrl

vagrant-ssh-preprod: ## Se connecte à la VM preprod
	@echo "🔑 Connexion SSH à preprod..."
	vagrant ssh preprod

vagrant-ssh-prod: ## Se connecte à la VM prod
	@echo "🔑 Connexion SSH à prod..."
	vagrant ssh prod

# ============================================
# TP1: Configuration de base
# ============================================
ansible-ping: ## Teste la connectivité Ansible avec toutes les VM
	@echo "🏓 Test de connectivité Ansible..."
	cd $(ANSIBLE_DIR) && ansible all -m ping

ansible-ping-ctrl: ## Teste la connectivité avec ctrl
	@echo "🏓 Test de connectivité avec ctrl..."
	cd $(ANSIBLE_DIR) && ansible ctrl -m ping

ansible-ping-nodes: ## Teste la connectivité avec preprod et prod
	@echo "🏓 Test de connectivité avec les nodes..."
	cd $(ANSIBLE_DIR) && ansible nodes -m ping

# ============================================
# TP3: Baseline des nœuds
# ============================================
ansible-baseline: ## Applique la configuration de base sur tous les nœuds
	@echo "📦 Application de la baseline..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/baseline.yml

ansible-baseline-nodes: ## Applique la baseline sur preprod et prod
	@echo "📦 Application de la baseline sur les nodes..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/baseline.yml --limit nodes

# ============================================
# TP5: Déploiement du cluster k3s
# ============================================
k3s-install: ## Installe k3s sur les nœuds
	@echo "☸️  Installation de k3s..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/cluster.yml

k3s-verify: ## Vérifie l'état du cluster k3s
	@echo "✅ Vérification du cluster k3s..."
	ssh -p 2222 vagrant@localhost "kubectl get nodes -o wide"

# ============================================
# TP6-TP8: Déploiement avec Helm
# ============================================
helm-deploy-dev: ## Déploie l'application en mode développement
	@echo "🚀 Déploiement de l'application (dev)..."
	cd $(CHART_DIR) && helm upgrade --install nova-hello . -f values-preprod.yaml --namespace nova-hello --create-namespace

helm-deploy-prod: ## Déploie l'application en production
	@echo "🚀 Déploiement de l'application (prod)..."
	cd $(CHART_DIR) && helm upgrade --install nova-hello . -f values-prod.yaml --namespace nova-hello --create-namespace

helm-delete: ## Supprime le déploiement
	@echo "🗑️  Suppression du déploiement..."
	helm uninstall nova-hello --namespace nova-hello

helm-status: ## Affiche le statut du déploiement
	@echo "📊 Statut du déploiement..."
	helm status nova-hello --namespace nova-hello

helm-list: ## Liste les releases Helm
	@echo "📋 Liste des releases..."
	helm list --all-namespaces

# ============================================
# TP9-TP10: Ansible pilote Helm
# ============================================
ansible-helm-deploy: ## Déploie via Ansible (pilotage de Helm)
	@echo "🎯 Déploiement via Ansible + Helm..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy.yml

ansible-helm-rollback: ## Effectue un rollback via Ansible
	@echo "⏪ Rollback via Ansible + Helm..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy.yml --tags rollback

# ============================================
# TP11: Hardening
# ============================================
ansible-harden: ## Applique le hardening sur les nœuds
	@echo "🔒 Application du hardening..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/harden.yml

# ============================================
# TP12: Audit de conformité
# ============================================
ansible-audit: ## Effectue un audit de conformité
	@echo "🔍 Audit de conformité..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/audit.yml

# ============================================
# TP14: Rotation des secrets
# ============================================
rotate-tokens: ## Rotation des tokens/secrets
	@echo "🔄 Rotation des tokens..."
	cd $(SCRIPTS_DIR) && ./rotate-token.sh

# ============================================
# TP15: Orchestration complète
# ============================================
full-deploy: vagrant-up ansible-baseline k3s-install ansible-helm-deploy ## Déploiement complet de bout en bout
	@echo "✅ Déploiement complet terminé !"

full-destroy: helm-delete k3s-verify ansible-baseline vgagrant-halt ## Destruction complète
	@echo "✅ Tout a été nettoyé !"

full-refresh: full-destroy full-deploy ## Rafraîchissement complet

# ============================================
# Gestion du chart Helm
# ============================================
helm-lint: ## Vérifie la syntaxe du chart
	@echo "🔍 Vérification du chart..."
	cd $(CHART_DIR) && helm lint .

helm-template: ## Génère les manifests Kubernetes
	@echo "📄 Génération des manifests..."
	cd $(CHART_DIR) && helm template . -f values-preprod.yaml > manifests.yaml

helm-package: ## Package le chart
	@echo "📦 Packaging du chart..."
	cd $(CHART_DIR) && helm package .

helm-dependency-update: ## Met à jour les dépendances du chart
	@echo "🔄 Mise à jour des dépendances..."
	cd $(CHART_DIR) && helm dependency update

# ============================================
# Gestion des tests
# ============================================
tests-goss: ## Exécute les tests Goss
	@echo "🧪 Exécution des tests Goss..."
	cd tests/goss && goss validate

# ============================================
# Utilitaires
# ============================================
clean: ## Nettoie les fichiers temporaires
	@echo "🧹 Nettoyage..."
	find . -type f -name "*.tmp" -delete
	find . -type f -name "*.log" -delete
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "terraform.tfstate*" -delete 2>/dev/null || true

logs: ## Affiche les logs des pods
	@echo "📜 Affichage des logs..."
	kubectl -n nova-hello logs -l app.kubernetes.io/instance=nova-hello --all-containers=true

# ============================================
# Cibles par défaut
# ============================================
.PHONY: default
default: help
