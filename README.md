# 🌟 Nova-Lab — Infrastructure as Code (fil rouge)

> **Laboratoire complet** : Vagrant + Ansible + k3s + Helm + Goss — du dépôt Git au cluster déployé, reproductible par une seule commande.

Ce dépôt reconstruit **tout** l'environnement à partir de Git seul : trois VM, un cluster Kubernetes, le durcissement, le déploiement applicatif et l'audit de conformité.

---

## 🏗️ Architecture

Schéma complet : [`dossier/architecture.md`](dossier/architecture.md)

| Composant | Rôle |
|---|---|
| **ctrl** (192.168.56.10) | Automate Ansible : playbooks, Vault, qualité (lint) |
| **preprod / prod** | k3s mono-nœud chacun, Traefik ingress, app `nova-hello` |
| **Vagrant + VirtualBox** | Provision des 3 VM (Vagrantfile déclaratif) |
| **ansible-vault** | Secrets chiffrés, une identité par environnement |
| **Goss** | Audit de conformité (Compliance-as-Code) |

---

## 🚀 Démarrage rapide

### Prérequis

- VirtualBox + Vagrant
- ~4 Go de RAM disponibles pour les VM

### Reconstruction complète (from scratch)

```bash
# 1. Créer les VM (10-15 min au premier passage)
vagrant up

# 2. Déployer et vérifier l'infrastructure complète
cd /vagrant
make all    # deps -> keys -> secrets -> ping -> baseline -> cluster -> harden -> deploy -> audit -> smoke
```

Le `make all` enchaîne tout : provision des VM, configuration du socle, cluster k3s + Helm, durcissement, déploiement applicatif et audit de conformité. **Verdict final attendu** : `preprod : OK` / `prod : OK`.

### Cibles principales

| Cible | Rôle |
|---|---|
| `make all` | Reconstruction complète depuis le dépôt Git seul |
| `make lint` | Qualité : yamllint + ansible-lint |
| `make audit` | Audit de conformité (Goss) — doit être vert |
| `make smoke` | Test utilisateur : les 2 pages Hello |
| `make help` | Liste de toutes les cibles disponibles |

---

## 📂 Structure du dépôt

```
nova-lab/
├── Vagrantfile                  # 3 VM : ctrl, preprod, prod (bento/ubuntu-22.04)
├── Makefile                     # Orchestration : make all, audit, smoke...
├── ansible/
│   ├── ansible.cfg              # Config (timeout, vault identities)
│   ├── inventories/             # Inventaire + vars d'environnement (group_vars)
│   │   └── group_vars/<env>/vault.yml   # Secrets chiffrés par environnement
│   ├── roles/
│   │   ├── common/              # Socle : paquets, timezone, chrony, bannière
│   │   ├── k3s/                 # # Installation k3s (idempotente)
│   │   ├── helm_cli/            # Helm + plugin helm-diff
│   │   ├── nova_release/        # Déploiement Helm + smoke test + rollback
│   │   ├── hardening/           # SSH durci, sysctl, firewall ufw, PSSI-08
│   │   ├── access/              # Comptes nominatifs + sudo + clés SSH
│   │   └── compliance/          # Audit Goss (spécs dans tests/goss/)
│   └── playbooks/               # baseline, cluster, harden, deploy, audit
├── charts/nova-hello/           # Chart Helm (values, schema, templates)
├── scripts/
│   ├── provision-ctrl.sh        # Ansible + Helm sur ctrl (idempotent)
│   ├── provision-node.sh        # Prépare les nœuds k3s
│   └── rotate-token.sh          # Rotation des secrets (Vault)
├── tests/goss/                  # Spécifications de conformité
└── dossier/                     # Livrables : architecture, ADR, robustesse, audit
```

---

## 🔐 Secrets & sécurité

| Principe | Mise en œuvre |
|---|---|
| Secrets chiffrés | `ansible-vault` — identité par environnement (`vault_identity_list`) |
| Accès nominatifs | Rôle `access` : comptes dédiés, clés SSH, sudo restreint |
| Durcissement | Rôle `hardening` : SSH drop-in, sysctl durci, firewall ufw en liste blanche |
| Réseau cloisonné | PSSI-08 : `deny out` preprod↔prod, NetworkPolicy côté k8s |
| Rotation | `scripts/rotate-token.sh` : génération + chiffrement Vault, sans interruption |

Pour rejouer la rotation :

```bash
bash scripts/rotate-token.sh prod
# Puis redéployer :
ansible-playbook playbooks/deploy.yml --limit prod -e nova_require_approval=false
```

---

## 📚 Documentation

- **Architecture & flux** : [`dossier/architecture.md`](dossier/architecture.md)
- **Décisions d'archi (ADR-01..05, DER-01)** : [`dossier/registre-decisions.md`](dossier/registre-decisions.md)
- **Fiche de robustesse** (réseau, timeouts, dépannage) : [`dossier/fiche-robustesse.md`](dossier/fiche-robustesse.md)
- **Audit de conformité** : [`dossier/rapport-audit.md`](dossier/rapport-audit.md)

---

## 🛠️ Dépannage rapide

| Symptôme | Cause probable | Action |
|---|---|---|
| Connexion SSH perdue après provision | Réseau campus / timeout | `vagrant halt <vm> && vagrant up <vm>` |
| Ansible timeout au sudo | Nœud chargé (k3s + cold pull) | Rejouer — `timeout=180` en place |
| Deploy échoue (`no_log`) | Vérifier logs détaillés | Ajouter `-e nova_show_diff=true` |
| Goss rouge après reboot | Service apport re-armé | Vérifier role `hardening` appliqué : `make harden` |
| Port 80 inaccessible | ufw | `sudo ufw status numbered` sur le nœud |

---

## 📄 Licence

MIT — voir [LICENSE](LICENSE).
