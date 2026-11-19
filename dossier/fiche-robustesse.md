# Fiche de robustesse (TP13-TP15) — problèmes rencontrés, diagnostics, remédiations

Chaque ligne suit le même schéma : **symptôme → diagnostic → remédiation codée → leçon**.
L'esprit TP13 : la robustesse se **code** dans l'automatisation, elle ne se dépanne pas à la main.

## 1. Secrets sur le montage partagé (`/vagrant` = vboxsf)

- **Symptôme** : `Exec format error` sur les fichiers de mot de passe Vault.
- **Diagnostic** : vboxsf marque tous les fichiers exécutables → Ansible croit lancer un script.
- **Remédiation** : mots de passe Vault dans `/home/vagrant/.vault_pass_*` (hors dépôt, `chmod 600`, `.gitignore ansible/.vault_pass_*`), générés par `make keys` s'ils sont absents.
- **Leçon** : *les secrets vivent en dehors de tout partage, la code se régénère depuis le Makefile*.

## 2. Réseau campus intermittent (DNS + port 80)

- **Symptôme** : `Temporary failure in name resolution`, puis `Connection refused` sur les miroirs apt Ubuntu (port 80), de façon **intermittente** (KO à 11 h, OK à 15 h, re-KO ensuite).
- **Diagnostic** : `/dev/tcp/<hôte>/<port>` : ICMP et DNS OK, TCP 80 muet vers archive.ubuntu.com, TCP 443 ouvert.
- **Remédiation codée** : `scripts/provision-*.sh` **détectent** la capacité au moment de l'exécution et basculent les sources apt vers `https://mirrors.edge.kernel.org/ubuntu` (même contenu, HTTPS). Toutes les étapes réseau sont bornées : apt 30 essais/10 s, pip et Helm 5 essais, `exit 1` explicite — jamais de boucle infinie.
- **Leçon** : *la tolérance aux pannes doit couvrir chaque étape réseau indépendamment (un retry sur `apt update` ne protège pas `apt install`), et une étape bloquante doit toujours finir par un échec explicite, comment ou incarné*.

## 3. Timeout de privilege escalation Ansible

- **Symptôme** : `Timeout (12s → 62s) waiting for privilege escalation prompt` sur des tâches sudo, de façon aléatoire.
- **Diagnostic** : nœuds 2 Go chargés (k3s + pull d'image en fond) ; la 1re tâche sudo passe, la suivante butte.
- **Remédiation** : `ansible.cfg` : `timeout = 180`.
- **Leçon** : *un timeout est un compromis — trop court il tue des opérations saines, trop long il masque les vraies pannes. 180 s = marge pour le pire nœud du labo*.

## 4. Timeout Helm sur premier pull d'image

- **Symptôme** : le déploiement échoue sur un lab reconstruit (preprod au 1er passage), alors que le re-run passe.
- **Diagnostic** : `no_log` masque tout ; avec `-e nova_show_diff=true` : timeout du `--wait` pendant le cold-pull depuis Docker Hub (réseau lent), image en cache au 2e essai.
- **Remédiation** : `timeout: 15m` dans le rôle (et format **durée Go** : `15m`, pas `900` — Helm refuse un entier nu ; leçon apprise sur prod, seule machine qui exécutait réellement la commande).
- **Leçon** : *le timeout d'attente doit couvrir le pire cas réseau (premier pull), pas le cas nominal ; et une tâche « ok/idempotent » peut cacher un non-passage — seule la vraie exécution prouve un drapeau*.

## 5. Dérogation annulée au reboot (apport) — détecté par l'audit

- **Symptôme** : Goss rouge après un reboot de prod : `fs.suid_dumpable = 2` au lieu de 0, alors que `/etc/sysctl.d/90-nova-hardening.conf` contient bien 0.
- **Diagnostic** : `grep -rn suid_dumpable` → aucun fichier persistant ne force 2 → service **apport** d'Ubuntu qui écrit la valeur en mémoire **à chaque boot** (collecte des cores setuid). Preprod (jamais rebootée) intacte : bombe à retardement symétrique.
- **Remédiation** : rôle `hardening` neutralise apport **avant** d'appliquer les sysctl (ordre volontaire) + `apport`/`whoopsie` retirés (CIS). L'audit en rouge a détecté la dérive ; la remediation est **codée**.
- **Leçon** : *c'est le contrat Compliance-as-Code : le contrôle détecte, le code corrige — reproductible*.

## 6. VM prod « capricieuse » après hard reboot

- **Symptôme** : `Connection closed by 192.168.56.22 port 22` de façon épisodique (2×, dont le TP15).
- **Diagnostic** : charge mémoire (k3s serveur + churn de pods pendant une fenêtre Trouble), jamais une faute de config — preprod, même recette, saine.
- **Remédiation** : redémarrage propre **par Vagrant** (`vagrant halt prod && vagrant up prod`), jamais via l'UI VirtualBox ; le provision reprendre de façon idempotente.
- **Leçon** : *les redémarrages font partie du pipeline, pas du folklore : l'automate sait reconverger après*.

## 7. Chaînes DNAT vs sockets (comportement ≠ implémentation)

- k3s (klipper-lb/svclb) expose le port 80 par **règles iptables DNAT**, sans socket hôte → un contrôle Goss `port: tcp:80` est aberrant ; remplacé par un test **comportemental** (`curl -w %{http_code}` → 200). De même `:6443` cliché wildcard dualstack via `ss -tln | grep`.
- **Leçon** : *teste le comportement attendu de l'utilisateur, pas une particularité d'implémentation*.

## 8. Rotation des secrets (preuve TP14)

Commandes exécutées et sorties conservées dans le carnet :

```bash
# Avant rotation : empreinte du jeton en base (prod)
ansible node-prod -b -m shell -a "k3s kubectl -n nova get secret nova-hello-secret -o jsonpath='{.data.API_TOKEN}' | base64 -d | sha256sum"
# 896dad270502d0bc04e879349929b17ef89ff8d704081451fd5251251461d986 -

# Rotation : nouveaux jeton, chiffrement Vault, redéploiement
cd /vagrant && bash scripts/rotate-token.sh prod
ansible-playbook playbooks/deploy.yml --limit prod -e nova_require_approval=false
# -> après : empreinte DIFFÉRENTE (le secret a tourné sans interruption de service)
```

- **Leçon** : *la rotation est un script (`scripts/rotate-token.sh`), pas une procédure : elle rejouable, le secret ne transite jamais en clair dans le dépôt (tmp local, shred), le re-chiffrement utilise l'identité Vault de l'environnement ciblé*.

## Récapitulatif pour la soutenance

| Thème | Preuve à montrer |
|---|---|
| Reproductibilité | `vagrant destroy -f && vagrant up && make all` → lab complet depuis Git seul |
| Conformité | `make audit` vert : 28+28 baseline, 11+13 k3s |
| Robustesse | les 8 entrées ci-dessus : chaque panne → un code versionné |
| Ansible × Helm | `values.yaml.j2` + `from_yaml` : un inventaire, trois consommateurs |
