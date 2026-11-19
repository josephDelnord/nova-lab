# Registre des décisions d'architecture et dérogations

## Décisions (ADR)

| Réf. | Décision | Justification (mise en œuvre) |
|---|---|---|
| **ADR-01** | Ansible tourne dans une VM dédiée (`ctrl`), pas sur Windows | Ansible ne s'exécute pas nativement sous Windows ; la VM Linux garantit un environnement identique pour tous. Concrètement : Vagrant provisionne `ctrl` avec ansible-core 2.17 (dernière branche compatible Python 3.10), la config est épinglée par `ANSIBLE_CONFIG` dans `/etc/profile.d/nova-ansible.sh`. |
| **ADR-02** | k3s mono-nœud par environnement | Un Kubernetes complet en 2 Go de RAM avec Ingress Traefik fourni ; la complexité reste dans l'architecture (preprod/prod isolés), pas dans l'installation. Le rôle `k3s` n'installe que si le binaire est absent (`stat` + `when`), le nœud attendu `Ready`. |
| **ADR-03** | Les variables `nova_*` forment un **contrat d'inventaire** partagé | Une seule source de vérité (`group_vars/<env>`) lue par **Ansible** (déploiement), **Helm** (`values.yaml.j2` ≥ `from_yaml`, types préservés) et **Goss** (`vars.yaml`, valeurs attendues). Exemple : `replicas` pilote à la fois le Helm release et l'audit `replicas_available`. Les `skip_list` d'ansible-lint se justifient par écrit (var-naming, décision assumée). |
| **ADR-04** | Helm s'exécute **sur le nœud**, via `kubernetes.core.helm` + kubeconfig local (`/etc/rancher/k3s/k3s.yaml`) | Évite de distribuer des kubeconfig (le kubeconfig ne quitte jamais la VM). Coût : pip + git sur chaque nœud (kubernetes, PyYAML, plugin helm-diff 3.9.14 épinglé — incompatible au-delà avec Helm 3.16). En production : registre OCI + accès API depuis un runner. |
| **ADR-05** | **Goss** pour l'audit Compliance-as-Code | Binaire unique, YAML lisible, exécution en < 1 s par spec. Installation **conditionnelle** (stat + when) : l'audit ne dépend pas du réseau. Alternatives citées : InSpec, OpenSCAP. L'audit a détecté deux dérives réelles (socket :80 absent de `ss` → test comportemental ; `fs.suid_dumpable` réarmé par apport → remediation codée). |

## Dérogations

| Réf. | Écart au référentiel | Raison | Mesure compensatoire | Test | Revue |
|---|---|---|---|---|---|
| **DER-01** | `net.ipv4.ip_forward = 1` (CIS demande 0) | Routage des pods par k3s (CNI flanel + DNAT klipper-lb) | Pare-feu **liste blanche** (ufw défaut deny in, seuls 22/80/443/6443 depuis sources nommées) ; **NetworkPolicy** en prod (PSSI-08) ; isolation preprod↔prod en `deny out` à la source | Vérifiée par Goss : `KernelParam net.ipv4.ip_forward` attendu `1` (convaincu du vrai sens : la dérogation est *testée*) | À chaque montée de version de k3s |

## Dérogations pratiques secondaires (documentées dans les scripts, non CIS)

- Miroir apt basculé en HTTPS `mirrors.edge.kernel.org` **si** le port 80 sortant est bloqué (détection `/dev/tcp` au provision) — dérogation au miroir officiel, même contenu, même signature GPG.
- Clés SSH nominatives `alice`/`bob` **générées de démo** par `make keys` (labo uniquement) ; en production elles viennent du gestionnaire d'identités.
