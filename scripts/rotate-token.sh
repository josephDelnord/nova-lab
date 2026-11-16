#!/bin/bash
# TP14: Script de rotation des tokens/secrets
# Ce script permet de rotater les secrets utilisés dans l'infrastructure

set -e

# ============================================
# Variables
# ============================================
ANSIBLE_DIR="$(cd $(dirname ${BASH_SOURCE[0]})/.. && pwd)/ansible"
CHART_DIR="$(cd $(dirname ${BASH_SOURCE[0]})/.. && pwd)/charts/nova-hello"
NAMESPACE="nova-hello"
SCRIPT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"

# ============================================
# Fonctions utiles
# ============================================

function usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -h, --help            Affiche cette aide
  -e, --environment     Environnement (preprod, prod). Default: all
  -d, --dry-run        Mode simulation (ne fait pas de modifications)
  -v, --verbose         Mode verbeux

Exemples:
  $0                              # Rotate tous les environnements
  $0 -e preprod                   # Rotate uniquement preprod
  $0 -e prod --dry-run            # Simulation pour prod
  $0 --verbose                    # Mode verbeux
EOF
    exit 0
}

function log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case $level in
        "INFO")
            echo -e "[\033[34m${timestamp}\033[0m] [\033[32mINFO\033[0m] ${message}"
            ;;
        "WARN")
            echo -e "[\033[34m${timestamp}\033[0m] [\033[33mWARN\033[0m] ${message}"
            ;;
        "ERROR")
            echo -e "[\033[34m${timestamp}\033[0m] [\033[31mERROR\033[0m] ${message}"
            ;;
        "SUCCESS")
            echo -e "[\033[34m${timestamp}\033[0m] [\033[32mSUCCESS\033[0m] ${message}"
            ;;
        *)
            echo -e "[\033[34m${timestamp}\033[0m] [\033[36mDEBUG\033[0m] ${message}"
            ;;
    esac
}

function check_dependencies() {
    log "INFO" "Vérification des dépendances..."
    
    local missing=0
    
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl n'est pas installé"
        missing=$((missing + 1))
    fi
    
    if ! command -v helm &> /dev/null; then
        log "ERROR" "helm n'est pas installé"
        missing=$((missing + 1))
    fi
    
    if ! command -v ansible &> /dev/null; then
        log "ERROR" "ansible n'est pas installé"
        missing=$((missing + 1))
    fi
    
    if ! command -v openssl &> /dev/null; then
        log "ERROR" "openssl n'est pas installé"
        missing=$((missing + 1))
    fi
    
    if [ $missing -gt 0 ]; then
        log "ERROR" "Il manque $missing dépendance(s). Veuillez les installer avant de continuer."
        exit 1
    fi
    
    log "SUCCESS" "Toutes les dépendances sont installées."
}

function generate_new_token() {
    # Générer un token sécurisé
    local token
    token=$(openssl rand -hex 32)
    echo "$token"
}

function generate_new_password() {
    # Générer un mot de passe sécurisé
    local password
    password=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
    echo "$password"
}

function rotate_ansible_vault() {
    local environment="$1"
    local dry_run="$2"
    
    log "INFO" "Rotation des secrets Ansible Vault pour $environment..."
    
    if [ "$dry_run" == "true" ]; then
        log "WARN" "Mode dry-run: simulation uniquement"
        return 0
    fi
    
    # Générer de nouveaux secrets
    local new_token=$(generate_new_token)
    local new_password=$(generate_new_password)
    
    # Remplacer dans les fichiers vault.yml
    if [ "$environment" == "all" ] || [ "$environment" == "preprod" ]; then
        # Pour preprod
        if [ -f "$ANSIBLE_DIR/inventories/group_vars/preprod/vault.yml" ]; then
            # Sauvegarder l'ancien fichier
            cp "$ANSIBLE_DIR/inventories/group_vars/preprod/vault.yml" \
               "$ANSIBLE_DIR/inventories/group_vars/preprod/vault.yml.bak.$(date +%Y%m%d%H%M%S)"
            
            # Remplacer les valeurs (exemple avec sed)
            sed -i "s/old_token_placeholder/$new_token/g" \
                "$ANSIBLE_DIR/inventories/group_vars/preprod/vault.yml"
            sed -i "s/old_password_placeholder/$new_password/g" \
                "$ANSIBLE_DIR/inventories/group_vars/preprod/vault.yml"
            
            log "SUCCESS" "Secrets Ansible Vault pour preprod mis à jour"
        fi
    fi
    
    if [ "$environment" == "all" ] || [ "$environment" == "prod" ]; then
        # Pour prod
        if [ -f "$ANSIBLE_DIR/inventories/group_vars/prod/vault.yml" ]; then
            # Sauvegarder l'ancien fichier
            cp "$ANSIBLE_DIR/inventories/group_vars/prod/vault.yml" \
               "$ANSIBLE_DIR/inventories/group_vars/prod/vault.yml.bak.$(date +%Y%m%d%H%M%S)"
            
            # Remplacer les valeurs
            sed -i "s/old_token_placeholder/$new_token/g" \
                "$ANSIBLE_DIR/inventories/group_vars/prod/vault.yml"
            sed -i "s/old_password_placeholder/$new_password/g" \
                "$ANSIBLE_DIR/inventories/group_vars/prod/vault.yml"
            
            log "SUCCESS" "Secrets Ansible Vault pour prod mis à jour"
        fi
    fi
}

function rotate_helm_secrets() {
    local environment="$1"
    local dry_run="$2"
    
    log "INFO" "Rotation des secrets Helm pour $environment..."
    
    if [ "$dry_run" == "true" ]; then
        log "WARN" "Mode dry-run: simulation uniquement"
        return 0
    fi
    
    # Déterminer le fichier values
    local values_file=""
    if [ "$environment" == "preprod" ]; then
        values_file="$CHART_DIR/values-preprod.yaml"
    elif [ "$environment" == "prod" ]; then
        values_file="$CHART_DIR/values-prod.yaml"
    else
        # Rotater les deux
        rotate_helm_secrets preprod "$dry_run"
        rotate_helm_secrets prod "$dry_run"
        return 0
    fi
    
    if [ ! -f "$values_file" ]; then
        log "WARN" "Fichier $values_file introuvable, on passe"
        return 0
    fi
    
    # Sauvegarder l'ancien fichier
    cp "$values_file" "${values_file}.bak.$(date +%Y%m%d%H%M%S)"
    
    # Générer de nouveaux secrets
    local new_token=$(generate_new_token)
    local new_password=$(generate_new_password)
    
    # Mettre à jour le fichier values (utiliser yq si disponible, sinon sed)
    if command -v yq &> /dev/null; then
        # Utiliser yq pour modifier le YAML
        yq eval ".secretToken = \"$new_token\"" -i "$values_file"
        yq eval ".dbPassword = \"$new_password\"" -i "$values_file"
    else
        # Utiliser sed (moins fiable pour le YAML)
        sed -i "s/secretToken: .*/secretToken: \"$new_token\"/" "$values_file"
        sed -i "s/dbPassword: .*/dbPassword: \"$new_password\"/" "$values_file"
    fi
    
    log "SUCCESS" "Secrets Helm pour $environment mis à jour"
}

function rotate_kubernetes_secrets() {
    local environment="$1"
    local dry_run="$2"
    
    log "INFO" "Rotation des secrets Kubernetes pour $environment..."
    
    if [ "$dry_run" == "true" ]; then
        log "WARN" "Mode dry-run: simulation uniquement"
        return 0
    fi
    
    # Vérifier la connexion au cluster
    if ! kubectl get nodes &> /dev/null; then
        log "ERROR" "Impossible de se connecter au cluster Kubernetes"
        return 1
    fi
    
    # Obtenir les secrets du namespace
    local secrets
    secrets=$(kubectl -n $NAMESPACE get secrets -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$secrets" ]; then
        log "INFO" "Aucun secret trouvé dans le namespace $NAMESPACE"
        return 0
    fi
    
    log "INFO" "Rotation des secrets Kubernetes: $secrets"
    
    # Pour chaque secret, le recréer avec une nouvelle valeur
    for secret in $secrets; do
        # Récupérer le type de secret
        local secret_type
        secret_type=$(kubectl -n $NAMESPACE get secret $secret -o jsonpath='{.type}')
        
        if [ "$secret_type" == "Opaque" ]; then
            # Générer une nouvelle valeur
            local new_value=$(generate_new_token)
            
            # Supprimer et recréer le secret
            kubectl -n $NAMESPACE delete secret $secret
            kubectl -n $NAMESPACE create secret generic $secret --from-literal=value="$new_value"
            
            log "SUCCESS" "Secret $secret recréé"
        fi
    done
}

function deploy_after_rotation() {
    local environment="$1"
    local dry_run="$2"
    
    log "INFO" "Redéploiement après rotation pour $environment..."
    
    if [ "$dry_run" == "true" ]; then
        log "WARN" "Mode dry-run: simulation uniquement"
        return 0
    fi
    
    # Redéployer avec les nouveaux secrets
    if [ "$environment" == "preprod" ]; then
        log "INFO" "Redéploiement de l'application en preprod..."
        cd "$CHART_DIR" && helm upgrade --install nova-hello . -f values-preprod.yaml --namespace $NAMESPACE --atomic --wait
    elif [ "$environment" == "prod" ]; then
        log "INFO" "Redéploiement de l'application en prod..."
        cd "$CHART_DIR" && helm upgrade --install nova-hello . -f values-prod.yaml --namespace $NAMESPACE --atomic --wait
    else
        # Redéployer les deux
        deploy_after_rotation preprod "$dry_run"
        deploy_after_rotation prod "$dry_run"
    fi
}

# ============================================
# Parsing des arguments
# ============================================
ENVIRONMENT="all"
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "❌ Option inconnue: $1"
            usage
            ;;
    esac
done

# ============================================
# Exécution principale
# ============================================
echo "========================================"
echo "  TP14: Rotation des tokens/secrets"
echo "========================================"
echo ""

# Vérifier les dépendances
check_dependencies

echo ""

# Afficher les paramètres
log "INFO" "Environnement: $ENVIRONMENT"
log "INFO" "Mode dry-run: $DRY_RUN"
log "INFO" "Mode verbeux: $VERBOSE"
echo ""

# Rotation des secrets
if [ "$ENVIRONMENT" == "all" ] || [ "$ENVIRONMENT" == "preprod" ]; then
    log "INFO" "Traitement de l'environnement preprod..."
    rotate_ansible_vault preprod "$DRY_RUN"
    rotate_helm_secrets preprod "$DRY_RUN"
    rotate_kubernetes_secrets preprod "$DRY_RUN"
    deploy_after_rotation preprod "$DRY_RUN"
fi

if [ "$ENVIRONMENT" == "all" ] || [ "$ENVIRONMENT" == "prod" ]; then
    log "INFO" "Traitement de l'environnement prod..."
    rotate_ansible_vault prod "$DRY_RUN"
    rotate_helm_secrets prod "$DRY_RUN"
    rotate_kubernetes_secrets prod "$DRY_RUN"
    deploy_after_rotation prod "$DRY_RUN"
fi

echo ""
log "SUCCESS" "Rotation des secrets terminée avec succès !"
echo ""
log "INFO" "Pensez à :"
log "INFO" "  1. Sauvegarder les anciens secrets avant de les supprimer"
log "INFO" "  2. Vérifier les logs des applications après redéploiement"
log "INFO" "  3. Tester que tout fonctionne correctement"
