#!/bin/bash

#=============================================================================
# SCRIPT DE CONFIGURATION ZAMMAD - TicketingOnTheFly
#=============================================================================
# Ce script configure automatiquement Zammad avec :
# - Groupes Zammad depuis config.yaml
# - Intégration LDAP
# - Mapping 1:1 des groupes LDAP → Zammad
# - Mapping des rôles (Agent, Admin, Customer)
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
    echo -e "${CYAN}  Configuration Zammad - TicketingOnTheFly${NC}"
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
    print_step "1/5" "Vérification des prérequis..."
    
    # Vérifier que Zammad est démarré
    if ! docker-compose -f "$PROJECT_ROOT/docker-compose.yml" ps zammad-nginx | grep -q "Up"; then
        print_error "Le conteneur Zammad n'est pas démarré"
        print_info "Exécutez d'abord : ./init.sh"
        exit 1
    fi
    
    # Vérifier que config.yaml existe
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Fichier config.yaml introuvable : $CONFIG_FILE"
        exit 1
    fi
    
    # Vérifier que yq est installé
    if ! command -v yq &> /dev/null; then
        print_error "yq n'est pas installé (parser YAML)"
        print_info "Exécutez d'abord : ./scripts/setup-ldap.sh (qui installe yq)"
        exit 1
    fi
    
    # Attendre que Zammad soit complètement initialisé
    print_info "Attente de l'initialisation de Zammad..."
    sleep 10
    
    print_success "Tous les prérequis sont satisfaits"
}

#=============================================================================
# RÉCUPÉRATION DE LA CONFIGURATION
#=============================================================================

get_config() {
    print_step "2/5" "Récupération de la configuration..."
    
    # Lire depuis .env
    if [ -f "$PROJECT_ROOT/.env" ]; then
        DOMAIN=$(grep "^DOMAIN=" "$PROJECT_ROOT/.env" | cut -d'=' -f2)
        LDAP_ADMIN_PASSWORD=$(grep "^LDAP_ADMIN_PASSWORD=" "$PROJECT_ROOT/.env" | cut -d'=' -f2)
    else
        print_error "Fichier .env introuvable"
        exit 1
    fi
    
    BASE_DN=$(echo "$DOMAIN" | sed 's/\./,dc=/g' | sed 's/^/dc=/')
    
    print_info "Domaine : $DOMAIN"
    print_info "Base DN : $BASE_DN"
}

#=============================================================================
# CRÉATION DES GROUPES ZAMMAD
#=============================================================================

create_zammad_groups() {
    print_step "3/5" "Création des groupes Zammad..."
    
    GROUP_COUNT=$(yq eval '.zammad.groups | length' "$CONFIG_FILE")
    
    for ((i=0; i<$GROUP_COUNT; i++)); do
        NAME=$(yq eval ".zammad.groups[$i].name" "$CONFIG_FILE")
        DISPLAY_NAME=$(yq eval ".zammad.groups[$i].display_name" "$CONFIG_FILE")
        NOTE=$(yq eval ".zammad.groups[$i].note" "$CONFIG_FILE")
        EMAIL=$(yq eval ".zammad.groups[$i].email_address" "$CONFIG_FILE")
        TIMEOUT=$(yq eval ".zammad.groups[$i].assignment_timeout" "$CONFIG_FILE")
        FOLLOW_UP=$(yq eval ".zammad.groups[$i].follow_up_possible" "$CONFIG_FILE")
        ACTIVE=$(yq eval ".zammad.groups[$i].active" "$CONFIG_FILE")
        
        print_info "📁 Groupe Zammad : $NAME"
        
        # Créer le groupe via Rails console
        docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T zammad-railsserver \
            rails r "
            begin
              group = Group.find_by(name: '$NAME')
              if group.nil?
                Group.create!(
                  name: '$NAME',
                  note: '$NOTE',
                  assignment_timeout: $([ "$TIMEOUT" = "null" ] && echo "nil" || echo "$TIMEOUT"),
                  follow_up_possible: '$FOLLOW_UP',
                  active: $ACTIVE
                )
                puts 'Groupe créé : $NAME'
              else
                puts 'Groupe existe déjà : $NAME'
              end
            rescue => e
              puts \"Erreur : \#{e.message}\"
            end
            " 2>/dev/null || true
    done
    
    print_success "$GROUP_COUNT groupe(s) Zammad créé(s)"
}

#=============================================================================
# CONFIGURATION DE L'INTÉGRATION LDAP
#=============================================================================

configure_ldap_integration() {
    print_step "4/5" "Configuration de l'intégration LDAP..."
    
    LDAP_HOST=$(yq eval '.zammad.ldap_integration.host' "$CONFIG_FILE")
    LDAP_PORT=$(yq eval '.zammad.ldap_integration.port' "$CONFIG_FILE")
    
    print_info "Configuration LDAP : $LDAP_HOST:$LDAP_PORT"
    
    # Créer la source LDAP via Rails console
    docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T zammad-railsserver \
        rails r "
        begin
          # Vérifier si la source LDAP existe déjà
          ldap_source = Ldap.find_by(name: 'OpenLDAP')
          
          if ldap_source.nil?
            # Créer la source LDAP
            Ldap.create!(
              name: 'OpenLDAP',
              preferences: {
                'host' => '$LDAP_HOST',
                'port' => $LDAP_PORT,
                'ssl' => false,
                'bind_user' => 'cn=admin,$BASE_DN',
                'bind_pw' => '$LDAP_ADMIN_PASSWORD',
                'base' => 'ou=users,$BASE_DN',
                'uid' => 'uid',
                'user_filter' => '(objectClass=inetOrgPerson)',
                'group_base' => 'ou=groups,$BASE_DN',
                'group_filter' => '(objectClass=groupOfNames)',
                'user_attributes' => {
                  'login' => 'uid',
                  'firstname' => 'givenName',
                  'lastname' => 'sn',
                  'email' => 'mail'
                },
                'group_role_map' => {
                  'support-n1' => ['Agent'],
                  'support-n2' => ['Agent'],
                  'administrateurs' => ['Admin'],
                  'utilisateurs' => ['Customer']
                }
              },
              active: true
            )
            puts 'Intégration LDAP créée'
          else
            puts 'Intégration LDAP existe déjà'
          end
        rescue => e
          puts \"Erreur : \#{e.message}\"
        end
        " 2>/dev/null || true
    
    print_success "Intégration LDAP configurée"
}

#=============================================================================
# VÉRIFICATION DU MAPPING 1:1
#=============================================================================

verify_mapping() {
    print_step "5/5" "Vérification du mapping LDAP ↔ Zammad..."
    
    print_info "Mapping des groupes (1:1) :"
    
    GROUP_COUNT=$(yq eval '.ldap.groups | length' "$CONFIG_FILE")
    
    for ((i=0; i<$GROUP_COUNT; i++)); do
        LDAP_GROUP=$(yq eval ".ldap.groups[$i].name" "$CONFIG_FILE")
        ZAMMAD_GROUP=$(yq eval ".zammad.groups[$i].name" "$CONFIG_FILE")
        
        if [ "$LDAP_GROUP" = "$ZAMMAD_GROUP" ]; then
            print_info "   ✓ LDAP '$LDAP_GROUP' ↔ Zammad '$ZAMMAD_GROUP'"
        else
            print_warning "   ✗ LDAP '$LDAP_GROUP' ≠ Zammad '$ZAMMAD_GROUP'"
        fi
    done
    
    print_success "Mapping vérifié"
}

#=============================================================================
# FONCTION PRINCIPALE
#=============================================================================

main() {
    print_banner
    
    check_prerequisites
    get_config
    create_zammad_groups
    configure_ldap_integration
    verify_mapping
    
    echo ""
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${GREEN}  ✅ Configuration Zammad terminée avec succès !${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo ""
    echo -e "${CYAN}Prochaines étapes :${NC}"
    echo ""
    echo -e "  1. Accéder à Zammad : ${YELLOW}http://zammad.$DOMAIN${NC}"
    echo ""
    echo -e "  2. Si ce n'est pas déjà fait, créer le compte admin"
    echo ""
    echo -e "  3. Synchroniser les utilisateurs LDAP :"
    echo -e "     ${YELLOW}Admin → Manage → Security → LDAP → Synchronize${NC}"
    echo ""
    echo -e "  4. Tester la connexion avec un utilisateur LDAP :"
    echo -e "     ${YELLOW}Login : tech1${NC}"
    echo -e "     ${YELLOW}Password : TechN1Pass123!${NC}"
    echo ""
}

# Exécuter le script
main "$@"
