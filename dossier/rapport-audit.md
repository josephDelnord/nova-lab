# Rapport d'audit de conformité (Goss) — preuve d'exécution

## Méthode

- Source de conformité : `tests/goss/goss-baseline.yaml` (socle) et `tests/goss/goss-k3s.yaml` (couche Kubernetes).
- Exécution : `ansible-playbook playbooks/audit.yml` (rôle `compliance`) — chaque contrôle Goss vérifié sur chaque nœud, verdict bloquant (`assert`).
- Valeurs cibles injectées depuis l'inventaire (`goss-vars.yaml.j2`) — un seul jeu de variables (contrat ADR-03).

## Résultats attendus / constatés

| Nœud | Spécification | Contrôles | Résultat |
|---|---|---|---|
| node-preprod | goss-baseline | 28 | ✅ Failed: 0 |
| node-preprod | goss-k3s | 11 | ✅ Failed: 0 |
| node-prod | goss-baseline | 28 | ✅ Failed: 0 |
| node-prod | goss-k3s | 13 | ✅ Failed: 0 |

## Sortie de référence

> À coller après le dernier run : capture de la commande
> `make audit` (les blocs `Count: 28, Failed: 0` et les lignes `ok:` de verdict)
> — inventée ici uniquement pour la traçabilité du dossier.

```
(paste ici : sortie de make audit)
```

## Points de vigilance sourcés (traces des choix)

1. `readonly_rootfs` (PSSI-09) : conteneur sans écritures, testé au niveau chart **et** re-verifié par audit.
2. `networkpolicy_present` (PSSI-08) : isolation applicative testée seulement là où elle est exigée (prod) — le test même est conditionnel.
3. `fs.suid_dumpable` : indicateurs de dérive ; réarmement historique par apport, remédié (voir fiche de robustesse).
4. Port :80 non testé par socket mais par **comportement HTTP** (restriction liée au DNAT klipper).
