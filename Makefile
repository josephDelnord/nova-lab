# Makefile : orchestration de bout en bout de nova-lab (TP15)
# Usage : sur la VM ctrl, dans /vagrant
#   make all          -> reconstruction complete sans intervention manuelle
#   make keys secrets -> (re)genere mots de passe Vault et jetons de demo
#   make help         -> cette aide

PROJECT       := nova-lab
ANSIBLE_DIR   := ansible
VAULT_HOME    := /home/vagrant
VAULT_PREPROD := $(VAULT_HOME)/.vault_pass_preprod
VAULT_PROD    := $(VAULT_HOME)/.vault_pass_prod
ANSIBLE       := cd $(ANSIBLE_DIR) &&

.PHONY: help all keys secrets deps lint ping baseline cluster harden deploy audit smoke \
        vagrant-up vagrant-halt vagrant-destroy clean

help: ## Affiche cette aide
	@echo "Orchestration nova-lab"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[32m%-12s\033[0m %s\n", $$1, $$2}'

# ----------------------------------------------------------------------------
# Reconstruction complete : UNE commande, zero intervention manuelle
# ----------------------------------------------------------------------------
all: deps keys secrets ping baseline cluster harden deploy audit smoke ## Reconstruit et prouve : lint -> secrets -> k3s -> durcissement -> release -> audit vert

# ----------------------------------------------------------------------------
# Secrets : HORS depot (/home/vagrant), requis par les identites Vault
# ----------------------------------------------------------------------------
keys: ## Genere les secrets locaux absents (mots de passe Vault + cles nominatives de demo)
	# Secrets Vault : jamais commits, disparaissent avec les VM detruites
	@test -f $(VAULT_PREPROD) || (umask 077 && openssl rand -base64 24 | tr -d '\n' > $(VAULT_PREPROD))
	@test -f $(VAULT_PROD)    || (umask 077 && openssl rand -base64 24 | tr -d '\n' > $(VAULT_PROD))
	@chmod 600 $(VAULT_PREPROD) $(VAULT_PROD)
	# Identites nominatives utilisées par le role access (TP14) : cles de DEMO
	# generees une fois sur ctrl ; en production elles viennent du gestionnaire
	# d'identites, jamais d'un Makefile.
	@mkdir -p $(VAULT_HOME)/.ssh
	@for u in alice bob; do \
	  test -f $(VAULT_HOME)/.ssh/$$u || ssh-keygen -q -t ed25519 -N "" -C "$$u@nova-lab" -f $(VAULT_HOME)/.ssh/$$u ; \
	done
	@echo "Mots de passe Vault et cles nominatives en place (hors depot)."

# Apres une reconstruction, les vault.yml committes ne sont plus dechiffrables :
# les anciens mots de passe ont disparu avec la VM detruite. On regenere donc des
# jetons de demonstration chiffres avec les NOUVELLES identites (pratique labo ;
# en production ils viendront d'un gestionnaire de secrets).
secrets: keys ## (Re)genere les vault.yml (jetons de demo chiffres, un par environnement)
	@cd $(ANSIBLE_DIR) && \
	  printf 'vault_nova_api_token: "tok-preprod-demo-001"\n' > /tmp/v-preprod.yml && \
	  printf 'vault_nova_api_token: "tok-prod-demo-001"\n'    > /tmp/v-prod.yml && \
	  ansible-vault encrypt --encrypt-vault-id preprod --output inventories/group_vars/preprod/vault.yml /tmp/v-preprod.yml && \
	  ansible-vault encrypt --encrypt-vault-id prod    --output inventories/group_vars/prod/vault.yml    /tmp/v-prod.yml && \
	  rm -f /tmp/v-preprod.yml /tmp/v-prod.yml && echo "Vaults regeneres (jetons de demo chiffres)."

# ----------------------------------------------------------------------------
# Cibles individuelles (rejouables seules - idempotence du socle)
# ----------------------------------------------------------------------------
deps: ## Installe les collections Ansible requises
	$(ANSIBLE) ansible-galaxy collection install ansible.posix community.general kubernetes.core >/dev/null

lint: ## Qualite : yamllint + ansible-lint
	yamllint -c /vagrant/.yamllint $(ANSIBLE_DIR)
	$(ANSIBLE) ansible-lint -c /vagrant/.ansible-lint playbooks roles

ping: ## Test de connectivite Ansible
	$(ANSIBLE) ansible nova -m ping -o | head -3

baseline: ## Socle commun (TP2/TP3)
	$(ANSIBLE) ansible-playbook playbooks/baseline.yml

cluster: ## k3s + Helm sur les noeuds (TP5)
	$(ANSIBLE) ansible-playbook playbooks/cluster.yml

harden: ## Acces + durcissement (TP11/TP14)
	$(ANSIBLE) ansible-playbook playbooks/harden.yml

deploy: ## Release nova-hello (TP9/TP10), non interactif
	$(ANSIBLE) ansible-playbook playbooks/deploy.yml -e nova_require_approval=false

audit: ## Audit de conformite Goss (TP12) - doit etre VERT
	$(ANSIBLE) ansible-playbook playbooks/audit.yml

smoke: ## Test utilisateur : les 2 pages Hello
	@curl -fs -H "Host: hello.preprod.nova.local" http://192.168.56.21/ | grep -q "preprod" && echo "preprod : OK"
	@curl -fs -H "Host: hello.prod.nova.local"    http://192.168.56.22/ | grep -q "Production" && echo "prod : OK"

# ----------------------------------------------------------------------------
# Gestion des VM ( cibles a lancer depuis L'HOTE : PowerShell / Git Bash, pas ctrl )
# ----------------------------------------------------------------------------
vagrant-up: ## (hote) demarre les 3 VM
	vagrant up

vagrant-halt: ## (hote) arrete les 3 VM
	vagrant halt

vagrant-destroy: ## (hote) DETRUIT les 3 VM (prelude de la reconstruction)
	vagrant destroy -f

clean: ## Nettoyage des artefacts locaux
	find . -type f \( -name '*.tmp' -o -name '*.retry' -o -name '*.log' \) -delete
