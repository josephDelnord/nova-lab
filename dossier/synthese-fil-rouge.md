# Synthèse du fil rouge (TP1 → TP15)

## Ce que j'ai construit

Un laboratoire complet d'infrastructure as code, reproductible depuis le dépôt Git seul : trois machines virtuelles Vagrant/VirtualBox (un automate **ctrl**, deux environnements **preprod** et **prod**), configurées de bout en bout par **Ansible**. L'automate installe et gère un **cluster Kubernetes k3s** par environnement avec son Ingress **Traefik**, y déploie l'application de démonstration **nova-hello** via **Helm** (révisions versionnées, rollback automatique en cas d'échec du smoke test), durcit les nœuds (SSH, sysctl, pare-feu ufw en liste blanche, isolation réseau PSSI-08), gère les accès nominatifs et chiffre les secrets par environnement avec **ansible-vault**. Chaque changement passe par le même chemin : un rôle ou un playbook idempotent, relu par ansible-lint et yamllint, prouvé par un audit de conformité **Goss** qui doit rester vert.

Le tout s'orchestre en une commande : `vagrant up` pour les VM, puis `make all` sur ctrl pour le reste — provision, cluster, durcissement, déploiement, audit. La robustesse n'est pas un vœu mais un ensemble de mécanismes codés : timeouts dimensionnés (sudo 180 s, Helm 15 min pour le premier téléchargement d'images), alternatives HTTPS quand le réseau du campus filtre le port 80, détection de dérive par l'audit.

## Mes choix

- **Ansible en push, agentless, sur une VM Linux dédiée** plutôt que sur le poste hôte : même environnement pour tous, exécution reproductible (ADR-01).
- **k3s mono-nœud par environnement** : un Kubernetes complet en 2 Go de RAM ; la complexité reste dans l'architecture, pas dans l'installation (ADR-02).
- **Un seul contrat de variables (`nova_*`)** partagé entre Ansible, Helm et Goss : une seule source de vérité, trois consommateurs (ADR-03).
- **Helm exécuté sur le nœud** avec le kubeconfig local : le kubeconfig ne quitte jamais la VM (ADR-04).
- **Goss pour l'audit Compliance-as-Code** : le contrôle détecte, le code corrige ; toute dérive est détectée à chaque exécution (ADR-05).
- **Le pare-feu en liste blanche assumé** (PSSI-08), avec la dérogation documentée et testée (DER-01 : `ip_forward=1` imposé par k3s, compensé par NetworkPolicy et filtrage à la source).

## Les limites que j'identifie

- **Un seul nœud par environnement** : pas de haute disponibilité réelle ; la panne d'une VM est celle de l'environnement.
- **2 Go de RAM par nœud** : le premier déploiement dépend de la latence réseau (téléchargement d'images) ; d'où les timeouts généreux codés dans les rôles.
- **Réseau du campus intermittent** : le port 80 sortant est filtré par intermittence ; les provisions basculent sur un miroir HTTPS, mais cela reste une contrainte de l'environnement, pas du design.
- **Pas de GitOps** (type Argo CD) : le déploiement est piloté par Ansible, pas par réconciliation continue ; c'est un choix assumé pour rester dans le périmètre des TP, pas une impasse technique.
- **Pas de supervision centralisée** : l'audit Goss détecte les dérives de configuration, mais il n'y a ni métriques ni alerting en continu — première extension naturelle du labo.
- **Secrets de démonstration** : les clés SSH et jetons générés par `make keys` sont des artefacts de labo ; en production, ils viendraient d'un gestionnaire de secrets.

---

*Fil rouge réalisé sur les TP1 à TP15 — dépôt `nova-lab`, branche `main`.*
