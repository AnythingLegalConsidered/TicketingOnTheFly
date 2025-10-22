#!/bin/bash

#=============================================================================
# SCRIPT DE CONFIGURATION OPENLDAP - TicketingOnTheFly
#=============================================================================
# Ce script configure automatiquement OpenLDAP avec :
# - Structure LDAP (ou=users, ou=groups)
# - Groupes depuis config.yaml
# - Utilisateurs depuis config.yaml
# - Assignation des utilisateurs aux groupes
#=============================================================================

set -e  # Arrêt si erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

#=============================================================================
# FONCTIONS UTILITAIRES
#=============================================================================

print_banner() {
    echo ""
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${CYAN}  Configuration OpenLDAP - TicketingOnTheFly${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}[$1] $2${NC}"
}

print_success() {
    echo -e "${GREEN}   ✅ $1${NC}"
}

print_info() {
    echo -e "${CYAN}   $1${NC}"
}

print_error() {
    echo -e "${RED}   ❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}   ⚠️  $1${NC}"
}

#=============================================================================
# VÉRIFICATION DES PRÉREQUIS
#=============================================================================

check_prerequisites() {
    print_step "1/6" "Vérification des prérequis..."
    
    # Vérifier docker-compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose n'est pas installé"
        exit 1
    fi
    
    # Vérifier que le conteneur OpenLDAP est démarré
    if ! docker-compose -f "$PROJECT_ROOT/docker-compose.yml" ps openldap | grep -q "Up"; then
        print_error "Le conteneur OpenLDAP n'est pas démarré"
        print_info "Exécutez d'abord : ./init.sh"
        exit 1
    fi
    
    # Vérifier que config.yaml existe
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Fichier config.yaml introuvable : $CONFIG_FILE"
        exit 1
    fi
    
    # Vérifier que yq est installé (pour parser YAML)
    if ! command -v yq &> /dev/null; then
        print_warning "yq n'est pas installé (parser YAML)"
        print_info "Installation de yq..."
        
        # Installation via snap si disponible
        if command -v snap &> /dev/null; then
            sudo snap install yq
        else
            # Installation via wget
            print_info "Téléchargement de yq..."
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            sudo chmod +x /usr/local/bin/yq
        fi
        
        if ! command -v yq &> /dev/null; then
            print_error "Impossible d'installer yq"
            exit 1
        fi
    fi
    
    print_success "Tous les prérequis sont satisfaits"
}

#=============================================================================
# RÉCUPÉRATION DE LA CONFIGURATION
#=============================================================================

get_domain() {
    print_step "2/6" "Configuration du domaine..."
    
    # Lire le domaine depuis .env
    if [ -f "$PROJECT_ROOT/.env" ]; then
        DOMAIN=$(grep "^DOMAIN=" "$PROJECT_ROOT/.env" | cut -d'=' -f2)
        LDAP_ADMIN_PASSWORD=$(grep "^LDAP_ADMIN_PASSWORD=" "$PROJECT_ROOT/.env" | cut -d'=' -f2)
    else
        print_error "Fichier .env introuvable"
        exit 1
    fi
    
    # Convertir le domaine en DN LDAP
    # Exemple : localhost → dc=localhost
    # Exemple : monentreprise.com → dc=monentreprise,dc=com
    BASE_DN=$(echo "$DOMAIN" | sed 's/\./,dc=/g' | sed 's/^/dc=/')
    
    print_info "Domaine : $DOMAIN"
    print_info "Base DN : $BASE_DN"
}

#=============================================================================
# CRÉATION DE LA STRUCTURE LDAP
#=============================================================================

create_ldap_structure() {
    print_step "3/6" "Création de la structure LDAP..."
    
    # Créer le fichier LDIF pour la structure
    cat > /tmp/ldap-structure.ldif <<EOF
# Unité organisationnelle : users
dn: ou=users,$BASE_DN
objectClass: organizationalUnit
ou: users
description: Utilisateurs du système

# Unité organisationnelle : groups
dn: ou=groups,$BASE_DN
objectClass: organizationalUnit
ou: groups
description: Groupes du système
EOF
    
    # Appliquer le LDIF (ignorer si déjà existe)
    docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
        ldapadd -x -D "cn=admin,$BASE_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -f /tmp/ldap-structure.ldif 2>/dev/null || true
    
    print_success "Structure LDAP créée"
}

#=============================================================================
# CRÉATION DES GROUPES LDAP
#=============================================================================

create_ldap_groups() {
    print_step "4/6" "Création des groupes LDAP..."
    
    # Récupérer le nombre de groupes
    GROUP_COUNT=$(yq eval '.ldap.groups | length' "$CONFIG_FILE")
    
    for ((i=0; i<$GROUP_COUNT; i++)); do
        GROUP_NAME=$(yq eval ".ldap.groups[$i].name" "$CONFIG_FILE")
        GROUP_DESC=$(yq eval ".ldap.groups[$i].description" "$CONFIG_FILE")
        
        print_info "📁 Groupe : $GROUP_NAME"
        
        # Créer le fichier LDIF pour le groupe
        cat > /tmp/ldap-group-$GROUP_NAME.ldif <<EOF
dn: cn=$GROUP_NAME,ou=groups,$BASE_DN
objectClass: groupOfNames
cn: $GROUP_NAME
description: $GROUP_DESC
member: cn=placeholder
EOF
        
        # Appliquer le LDIF (ignorer si déjà existe)
        docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
            ldapadd -x -D "cn=admin,$BASE_DN" -w "$LDAP_ADMIN_PASSWORD" \
            -f /tmp/ldap-group-$GROUP_NAME.ldif 2>/dev/null || true
    done
    
    print_success "$GROUP_COUNT groupe(s) créé(s)"
}

#=============================================================================
# CRÉATION DES UTILISATEURS LDAP
#=============================================================================

create_ldap_users() {
    print_step "5/6" "Création des utilisateurs LDAP..."
    
    # Récupérer le nombre d'utilisateurs
    USER_COUNT=$(yq eval '.ldap.users | length' "$CONFIG_FILE")
    
    for ((i=0; i<$USER_COUNT; i++)); do
        UID=$(yq eval ".ldap.users[$i].uid" "$CONFIG_FILE")
        FIRST_NAME=$(yq eval ".ldap.users[$i].firstName" "$CONFIG_FILE")
        LAST_NAME=$(yq eval ".ldap.users[$i].lastName" "$CONFIG_FILE")
        EMAIL=$(yq eval ".ldap.users[$i].email" "$CONFIG_FILE")
        PASSWORD=$(yq eval ".ldap.users[$i].password" "$CONFIG_FILE")
        
        print_info "👤 Utilisateur : $UID ($FIRST_NAME $LAST_NAME)"
        
        # Hasher le mot de passe
        HASHED_PASSWORD=$(docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
            slappasswd -s "$PASSWORD")
        
        # Créer le fichier LDIF pour l'utilisateur
        cat > /tmp/ldap-user-$UID.ldif <<EOF
dn: uid=$UID,ou=users,$BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: $UID
cn: $FIRST_NAME $LAST_NAME
givenName: $FIRST_NAME
sn: $LAST_NAME
mail: $EMAIL
userPassword: $HASHED_PASSWORD
uidNumber: $((10000 + i))
gidNumber: $((10000 + i))
homeDirectory: /home/$UID
loginShell: /bin/bash
EOF
        
        # Appliquer le LDIF (ignorer si déjà existe)
        docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
            ldapadd -x -D "cn=admin,$BASE_DN" -w "$LDAP_ADMIN_PASSWORD" \
            -f /tmp/ldap-user-$UID.ldif 2>/dev/null || true
    done
    
    print_success "$USER_COUNT utilisateur(s) créé(s)"
}

#=============================================================================
# ASSIGNATION DES UTILISATEURS AUX GROUPES
#=============================================================================

assign_users_to_groups() {
    print_step "6/6" "Assignation des utilisateurs aux groupes..."
    
    USER_COUNT=$(yq eval '.ldap.users | length' "$CONFIG_FILE")
    
    for ((i=0; i<$USER_COUNT; i++)); do
        UID=$(yq eval ".ldap.users[$i].uid" "$CONFIG_FILE")
        GROUPS_COUNT=$(yq eval ".ldap.users[$i].groups | length" "$CONFIG_FILE")
        
        for ((j=0; j<$GROUPS_COUNT; j++)); do
            GROUP_NAME=$(yq eval ".ldap.users[$i].groups[$j]" "$CONFIG_FILE")
            
            print_info "🔗 $UID → groupe $GROUP_NAME"
            
            # Créer le fichier LDIF pour ajouter le membre
            cat > /tmp/ldap-member-$UID-$GROUP_NAME.ldif <<EOF
dn: cn=$GROUP_NAME,ou=groups,$BASE_DN
changetype: modify
add: member
member: uid=$UID,ou=users,$BASE_DN
EOF
            
            # Appliquer le LDIF (ignorer si déjà membre)
            docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
                ldapmodify -x -D "cn=admin,$BASE_DN" -w "$LDAP_ADMIN_PASSWORD" \
                -f /tmp/ldap-member-$UID-$GROUP_NAME.ldif 2>/dev/null || true
        done
    done
    
    # Supprimer les placeholders des groupes
    GROUP_COUNT=$(yq eval '.ldap.groups | length' "$CONFIG_FILE")
    for ((i=0; i<$GROUP_COUNT; i++)); do
        GROUP_NAME=$(yq eval ".ldap.groups[$i].name" "$CONFIG_FILE")
        
        cat > /tmp/ldap-remove-placeholder-$GROUP_NAME.ldif <<EOF
dn: cn=$GROUP_NAME,ou=groups,$BASE_DN
changetype: modify
delete: member
member: cn=placeholder
EOF
        
        docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
            ldapmodify -x -D "cn=admin,$BASE_DN" -w "$LDAP_ADMIN_PASSWORD" \
            -f /tmp/ldap-remove-placeholder-$GROUP_NAME.ldif 2>/dev/null || true
    done
    
    print_success "Utilisateurs assignés aux groupes"
}

#=============================================================================
# FONCTION PRINCIPALE
#=============================================================================

main() {
    print_banner
    
    check_prerequisites
    get_domain
    create_ldap_structure
    create_ldap_groups
    create_ldap_users
    assign_users_to_groups
    
    echo ""
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${GREEN}  ✅ Configuration OpenLDAP terminée avec succès !${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo ""
    echo -e "${CYAN}Vérification :${NC}"
    echo -e "  • Interface web : ${YELLOW}http://ldap.$DOMAIN${NC}"
    echo -e "  • Login : ${YELLOW}cn=admin,$BASE_DN${NC}"
    echo -e "  • Password : ${YELLOW}(voir LDAP_ADMIN_PASSWORD dans .env)${NC}"
    echo ""
    echo -e "${CYAN}Commande de vérification :${NC}"
    echo -e "  ${YELLOW}docker-compose exec openldap ldapsearch -x -b \"ou=users,$BASE_DN\"${NC}"
    echo ""
}

# Exécuter le script
main "$@"
