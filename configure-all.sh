#!/bin/bash

#=============================================================================
# SCRIPT D'ORCHESTRATION - Configuration Automatisée TicketingOnTheFly
#=============================================================================
# Ce script orchestre la configuration complète de :
# - OpenLDAP (groupes et utilisateurs)
# - Zammad (groupes et intégration LDAP)
# - Vérification de la configuration
#=============================================================================

set -e  # Arrêt si erreur

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

#=============================================================================
# BANNIÈRE ASCII
#=============================================================================

print_main_banner() {
    clear
    echo -e "${MAGENTA}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║        ████████╗██╗ ██████╗██╗  ██╗███████╗████████╗██╗███╗   ██╗ ║
║        ╚══██╔══╝██║██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝██║████╗  ██║ ║
║           ██║   ██║██║     █████╔╝ █████╗     ██║   ██║██╔██╗ ██║ ║
║           ██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║██║╚██╗██║ ║
║           ██║   ██║╚██████╗██║  ██╗███████╗   ██║   ██║██║ ╚████║ ║
║           ╚═╝   ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ║
║                                                                    ║
║              Configuration Automatisée - Phase 10                  ║
╚════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_separator() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
}

#=============================================================================
# VÉRIFICATION DE L'INFRASTRUCTURE
#=============================================================================

check_infrastructure() {
    echo ""
    print_separator
    echo -e "${CYAN}  Vérification de l'infrastructure${NC}"
    print_separator
    echo ""
    
    cd "$PROJECT_ROOT"
    
    # Vérifier que docker-compose est disponible
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ docker-compose n'est pas installé${NC}"
        exit 1
    fi
    
    # Vérifier les services critiques
    local services=("openldap" "zammad-nginx" "zammad-railsserver")
    local all_up=true
    
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            echo -e "${GREEN}✅${NC} $service est démarré"
        else
            echo -e "${RED}❌${NC} $service n'est pas démarré"
            all_up=false
        fi
    done
    
    if [ "$all_up" = false ]; then
        echo ""
        echo -e "${RED}Certains services ne sont pas démarrés.${NC}"
        echo -e "${YELLOW}Exécutez d'abord : ./init.sh${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}✅ Infrastructure prête${NC}"
}

#=============================================================================
# AFFICHAGE DU RÉSUMÉ DE CONFIGURATION
#=============================================================================

show_configuration_summary() {
    echo ""
    print_separator
    echo -e "${CYAN}  📊 Résumé de la configuration${NC}"
    print_separator
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/config.yaml" ]; then
        echo -e "${RED}❌ Fichier config.yaml introuvable${NC}"
        exit 1
    fi
    
    # Vérifier que yq est installé
    if ! command -v yq &> /dev/null; then
        echo -e "${YELLOW}Installation de yq en cours...${NC}"
        if command -v snap &> /dev/null; then
            sudo snap install yq
        else
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            sudo chmod +x /usr/local/bin/yq
        fi
    fi
    
    LDAP_GROUPS=$(yq eval '.ldap.groups | length' "$SCRIPT_DIR/config.yaml")
    LDAP_USERS=$(yq eval '.ldap.users | length' "$SCRIPT_DIR/config.yaml")
    ZAMMAD_GROUPS=$(yq eval '.zammad.groups | length' "$SCRIPT_DIR/config.yaml")
    
    echo -e "   ${CYAN}Groupes LDAP :${NC} $LDAP_GROUPS"
    echo -e "   ${CYAN}Utilisateurs LDAP :${NC} $LDAP_USERS"
    echo -e "   ${CYAN}Groupes Zammad :${NC} $ZAMMAD_GROUPS"
    echo -e "   ${CYAN}Mapping :${NC} 1:1 (LDAP ↔ Zammad)"
    echo ""
    echo -e "${CYAN}📝 Groupes qui seront créés :${NC}"
    
    for ((i=0; i<$LDAP_GROUPS; i++)); do
        GROUP_NAME=$(yq eval ".ldap.groups[$i].name" "$SCRIPT_DIR/config.yaml")
        echo -e "   • $GROUP_NAME"
    done
    
    echo ""
}

#=============================================================================
# DEMANDE DE CONFIRMATION
#=============================================================================

ask_confirmation() {
    echo ""
    print_separator
    echo -e "${YELLOW}  ⚠️  Confirmation${NC}"
    print_separator
    echo ""
    echo -e "${YELLOW}Cette opération va configurer OpenLDAP et Zammad${NC}"
    echo -e "Les données existantes seront conservées, seules les nouvelles"
    echo -e "entrées seront ajoutées."
    echo ""
    read -p "Continuer ? (o/N) : " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        echo ""
        echo -e "${RED}Configuration annulée${NC}"
        exit 0
    fi
}

#=============================================================================
# CONFIGURATION OPENLDAP
#=============================================================================

configure_openldap() {
    echo ""
    print_separator
    echo -e "${CYAN}  Configuration OpenLDAP${NC}"
    print_separator
    echo ""
    
    chmod +x "$SCRIPT_DIR/setup-ldap.sh"
    
    if "$SCRIPT_DIR/setup-ldap.sh"; then
        echo -e "${GREEN}✅ OpenLDAP configuré avec succès${NC}"
    else
        echo -e "${RED}❌ Erreur lors de la configuration d'OpenLDAP${NC}"
        exit 1
    fi
}

#=============================================================================
# CONFIGURATION ZAMMAD
#=============================================================================

configure_zammad() {
    echo ""
    print_separator
    echo -e "${CYAN}  Configuration Zammad${NC}"
    print_separator
    echo ""
    
    chmod +x "$SCRIPT_DIR/setup-zammad.sh"
    
    if "$SCRIPT_DIR/setup-zammad.sh"; then
        echo -e "${GREEN}✅ Zammad configuré avec succès${NC}"
    else
        echo -e "${RED}❌ Erreur lors de la configuration de Zammad${NC}"
        exit 1
    fi
}

#=============================================================================
# VÉRIFICATION DE LA CONFIGURATION
#=============================================================================

verify_configuration() {
    echo ""
    print_separator
    echo -e "${CYAN}  Vérification de la configuration${NC}"
    print_separator
    echo ""
    
    # Lire le domaine
    DOMAIN=$(grep "^DOMAIN=" "$PROJECT_ROOT/.env" | cut -d'=' -f2)
    BASE_DN=$(echo "$DOMAIN" | sed 's/\./,dc=/g' | sed 's/^/dc=/')
    
    # Compter les groupes LDAP
    LDAP_GROUPS_COUNT=$(docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
        ldapsearch -x -b "ou=groups,$BASE_DN" "(objectClass=groupOfNames)" dn 2>/dev/null | grep -c "^dn:" || echo "0")
    
    # Compter les utilisateurs LDAP
    LDAP_USERS_COUNT=$(docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T openldap \
        ldapsearch -x -b "ou=users,$BASE_DN" "(objectClass=inetOrgPerson)" dn 2>/dev/null | grep -c "^dn:" || echo "0")
    
    # Compter les groupes Zammad
    ZAMMAD_GROUPS_COUNT=$(docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T zammad-railsserver \
        rails r "puts Group.count" 2>/dev/null | tail -n 1 || echo "0")
    
    echo -e "   ${CYAN}Groupes LDAP créés :${NC} $LDAP_GROUPS_COUNT"
    echo -e "   ${CYAN}Utilisateurs LDAP créés :${NC} $LDAP_USERS_COUNT"
    echo -e "   ${CYAN}Groupes Zammad créés :${NC} $ZAMMAD_GROUPS_COUNT"
    echo ""
    
    if [ "$LDAP_GROUPS_COUNT" -gt 0 ] && [ "$LDAP_USERS_COUNT" -gt 0 ] && [ "$ZAMMAD_GROUPS_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ Configuration vérifiée avec succès${NC}"
    else
        echo -e "${YELLOW}⚠️  Vérification partielle - Certaines entrées peuvent être manquantes${NC}"
    fi
}

#=============================================================================
# AFFICHAGE DU RÉSUMÉ FINAL
#=============================================================================

show_final_summary() {
    DOMAIN=$(grep "^DOMAIN=" "$PROJECT_ROOT/.env" | cut -d'=' -f2)
    
    echo ""
    print_separator
    echo -e "${GREEN}  ✅ Configuration terminée avec succès !${NC}"
    print_separator
    echo ""
    echo -e "${CYAN}🌐 Accès aux services :${NC}"
    echo ""
    echo -e "   ${YELLOW}Zammad :${NC} http://zammad.$DOMAIN"
    echo -e "   ${YELLOW}phpLDAPadmin :${NC} http://ldap.$DOMAIN"
    echo -e "   ${YELLOW}Wiki.js :${NC} http://wiki.$DOMAIN"
    echo -e "   ${YELLOW}Grafana :${NC} http://grafana.$DOMAIN"
    echo ""
    echo -e "${CYAN}👥 Comptes créés :${NC}"
    echo ""
    
    # Afficher les 5 premiers utilisateurs
    USER_COUNT=$(yq eval '.ldap.users | length' "$SCRIPT_DIR/config.yaml")
    local max_display=$((USER_COUNT < 5 ? USER_COUNT : 5))
    
    for ((i=0; i<$max_display; i++)); do
        UID=$(yq eval ".ldap.users[$i].uid" "$SCRIPT_DIR/config.yaml")
        PASSWORD=$(yq eval ".ldap.users[$i].password" "$SCRIPT_DIR/config.yaml")
        GROUPS=$(yq eval ".ldap.users[$i].groups | join(\", \")" "$SCRIPT_DIR/config.yaml")
        
        echo -e "   ${YELLOW}$UID${NC}"
        echo -e "     Mot de passe : $PASSWORD"
        echo -e "     Groupes : $GROUPS"
        echo ""
    done
    
    if [ "$USER_COUNT" -gt 5 ]; then
        echo -e "   ${CYAN}... et $((USER_COUNT - 5)) autre(s) utilisateur(s)${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}📚 Documentation :${NC}"
    echo -e "   • Guide rapide : ${YELLOW}doc/QUICK-START.md${NC}"
    echo -e "   • Personnalisation : ${YELLOW}doc/GUIDE-PERSONNALISATION.md${NC}"
    echo -e "   • Phase 10 : ${YELLOW}doc/10 - Configuration Automatisée.md${NC}"
    echo ""
    print_separator
    echo ""
}

#=============================================================================
# FONCTION PRINCIPALE
#=============================================================================

main() {
    print_main_banner
    check_infrastructure
    show_configuration_summary
    ask_confirmation
    configure_openldap
    configure_zammad
    verify_configuration
    show_final_summary
}

# Exécuter le script
main "$@"
