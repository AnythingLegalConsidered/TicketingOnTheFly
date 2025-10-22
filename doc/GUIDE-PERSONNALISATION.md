# 🎨 Guide de Personnalisation - TicketingOntheFly

**Guide complet pour adapter le projet à votre organisation**

---

## 📋 Table des Matières

1. [Avant de Commencer](#avant-de-commencer)
2. [Configuration Initiale Obligatoire](#configuration-initiale-obligatoire)
3. [Personnalisation LDAP](#personnalisation-ldap)
4. [Personnalisation Zammad](#personnalisation-zammad)
5. [Personnalisation Traefik et DNS](#personnalisation-traefik-et-dns)
6. [Sécurité et Mots de Passe](#sécurité-et-mots-de-passe)
7. [Gestion des Utilisateurs](#gestion-des-utilisateurs)
8. [Gestion des Groupes](#gestion-des-groupes)
9. [Configuration Email](#configuration-email)
10. [Personnalisation Avancée](#personnalisation-avancée)

---

## 🚀 Avant de Commencer

### Prérequis

- ✅ Infrastructure déployée (`./init.sh` exécuté)
- ✅ Accès à un éditeur de texte (`nano`, `vim`, ou VS Code)
- ✅ Droits d'accès aux fichiers du projet
- ✅ Connaissance basique de YAML

### Philosophie de Configuration

Le projet TicketingOnTheFly utilise **deux niveaux de configuration** :

1. **Configuration d'infrastructure** (`.env`, `docker-compose.yml`)
   - Défini au déploiement
   - Rarement modifié après
   
2. **Configuration applicative** (`config.yaml`)
   - Modifiable à tout moment
   - Rechargeable via `./configure-all.sh`

---

## ⚙️ Configuration Initiale Obligatoire

### 1. Fichier `.env` - Configuration du Domaine

**📁 Fichier** : `.env` (à la racine du projet)

**À modifier OBLIGATOIREMENT avant le déploiement :**

```bash
#=============================================================================
# DOMAINE ET ENVIRONNEMENT
#=============================================================================

# Votre nom de domaine principal
# - Pour le développement : localhost
# - Pour la production : monentreprise.com
DOMAIN=localhost  # ← MODIFIER ICI

# Environnement d'exécution
# - dev : Développement local (HTTP, certificats auto-signés)
# - prod : Production (HTTPS, Let's Encrypt)
ENVIRONMENT=dev  # ← MODIFIER ICI si production
```

**Exemples selon votre cas :**

| Cas d'usage | DOMAIN | ENVIRONMENT |
|-------------|--------|-------------|
| Test local sur PC | `localhost` | `dev` |
| Serveur interne entreprise | `ticketing.intranet.local` | `dev` |
| Production publique | `ticketing.monentreprise.com` | `prod` |

⚠️ **Important** : Modifier ces valeurs nécessite de relancer `./init.sh`

---

### 2. Fichier `.env` - Mots de Passe Administrateurs

**SÉCURITÉ CRITIQUE** : Changer TOUS ces mots de passe avant la mise en production !

```bash
#=============================================================================
# MOTS DE PASSE ADMINISTRATEURS
#=============================================================================

# OpenLDAP - Administrateur LDAP
# Utilisé pour : Gestion des utilisateurs et groupes
LDAP_ADMIN_PASSWORD=changeThisPassword123!  # ← MODIFIER

# Zammad - Base de données PostgreSQL
# Utilisé pour : Stockage des tickets et données Zammad
POSTGRES_PASSWORD=zammdPostgresPass456!  # ← MODIFIER
ZAMMAD_DB_PASS=zammdPostgresPass456!     # ← MODIFIER (même valeur)

# PostgreSQL Admin (Adminer)
# Utilisé pour : Accès interface web base de données
POSTGRES_ADMIN_PASSWORD=adminPostgresPass789!  # ← MODIFIER

# Grafana - Tableau de bord
# Utilisé pour : Accès interface Grafana
GF_SECURITY_ADMIN_PASSWORD=grafanaAdminPass012!  # ← MODIFIER

# Portainer - Gestion Docker
# Le mot de passe est défini à la première connexion
```

**Génération de mots de passe sécurisés :**

```bash
# Générer un mot de passe aléatoire de 20 caractères
openssl rand -base64 20

# Générer 5 mots de passe différents
for i in {1..5}; do openssl rand -base64 20; done
```

**Politique de mots de passe recommandée :**
- ✅ Minimum 16 caractères
- ✅ Mélange de majuscules, minuscules, chiffres, symboles
- ✅ Différent pour chaque service
- ✅ Stocké dans un gestionnaire de mots de passe

---

### 3. Fichier `.env` - Emails et Notifications

```bash
#=============================================================================
# EMAIL ET NOTIFICATIONS
#=============================================================================

# Email de l'administrateur système
# Utilisé pour : Notifications, certificats SSL, alertes
ADMIN_EMAIL=admin@localhost  # ← MODIFIER

# Configuration SMTP (si production)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=votre-email@gmail.com  # ← MODIFIER
SMTP_PASSWORD=votre-mot-de-passe-app  # ← MODIFIER
SMTP_FROM=ticketing@monentreprise.com  # ← MODIFIER
```

**Pour Gmail :**
1. Activer l'authentification à 2 facteurs
2. Générer un "Mot de passe d'application"
3. Utiliser ce mot de passe dans `SMTP_PASSWORD`

**Pour serveur SMTP interne :**
```bash
SMTP_HOST=mail.monentreprise.local
SMTP_PORT=25
SMTP_USER=ticketing@monentreprise.local
SMTP_PASSWORD=MotDePasseSMTP
```

---

## 🔐 Personnalisation LDAP

### Fichier de Configuration

**📁 Fichier** : `scripts/config.yaml`

### 1. Modifier les Groupes LDAP

```yaml
ldap:
  groups:
    # Groupe 1 : Support Niveau 1
    - name: "support-n1"                      # Nom technique (pas d'espaces, minuscules)
      description: "Support Niveau 1"         # Description lisible
    
    # Groupe 2 : Support Niveau 2
    - name: "support-n2"
      description: "Support Niveau 2 - Experts techniques"
    
    # Groupe 3 : Administrateurs
    - name: "administrateurs"
      description: "Administrateurs système et support"
    
    # Groupe 4 : Utilisateurs
    - name: "utilisateurs"
      description: "Utilisateurs finaux de l'organisation"
```

**Ajouter un nouveau groupe :**

```yaml
ldap:
  groups:
    # ... groupes existants ...
    
    # Nouveau groupe : Support VIP
    - name: "support-vip"
      description: "Support prioritaire pour clients VIP"
    
    # Nouveau groupe : Développement
    - name: "developpeurs"
      description: "Équipe de développement interne"
```

**Règles de nommage :**
- ✅ Pas d'espaces (utiliser tirets : `support-vip`)
- ✅ Minuscules uniquement
- ✅ Pas de caractères spéciaux (sauf `-` et `_`)
- ✅ Descriptif et court

---

### 2. Modifier les Utilisateurs LDAP

```yaml
ldap:
  users:
    # Utilisateur 1
    - uid: "tech1"                           # Identifiant de connexion (unique)
      firstName: "Pierre"                     # Prénom
      lastName: "Martin"                      # Nom de famille
      email: "pierre.martin@localhost"        # Email
      password: "TechN1Pass123!"              # Mot de passe
      groups: ["support-n1"]                  # Groupes (liste)
    
    # Utilisateur 2
    - uid: "tech2"
      firstName: "Marie"
      lastName: "Dubois"
      email: "marie.dubois@localhost"
      password: "TechN1Pass123!"
      groups: ["support-n1"]
```

**Ajouter un utilisateur :**

```yaml
ldap:
  users:
    # ... utilisateurs existants ...
    
    # Nouvel utilisateur
    - uid: "nouveau.tech"
      firstName: "Jean"
      lastName: "Nouveau"
      email: "jean.nouveau@monentreprise.com"
      password: "SecurePass456!"
      groups: ["support-n2"]  # Peut appartenir à un groupe
```

**Utilisateur avec plusieurs groupes :**

```yaml
ldap:
  users:
    # Administrateur membre de plusieurs groupes
    - uid: "admin.principal"
      firstName: "Admin"
      lastName: "Principal"
      email: "admin@monentreprise.com"
      password: "AdminSecure789!"
      groups: 
        - "administrateurs"
        - "support-n2"
        - "support-n1"  # Peut voir tous les niveaux
```

---

### 3. Personnaliser le Domaine LDAP

Le domaine LDAP est automatiquement généré depuis `.env` :

```bash
# Dans .env
DOMAIN=monentreprise.com

# Sera converti en LDAP :
dc=monentreprise,dc=com
```

**Exemples :**

| DOMAIN | Base DN LDAP |
|--------|--------------|
| `localhost` | `dc=localhost` |
| `monentreprise.com` | `dc=monentreprise,dc=com` |
| `ticketing.interne.local` | `dc=ticketing,dc=interne,dc=local` |

⚠️ Modification rare, nécessite redéploiement complet

---

## 🎫 Personnalisation Zammad

### 1. Groupes Zammad (Mapping 1:1)

**Principe** : Les groupes Zammad doivent avoir **le même nom** que les groupes LDAP.

```yaml
zammad:
  groups:
    # Groupe 1 : Correspond à LDAP "support-n1"
    - name: "support-n1"                     # ← Même nom que LDAP
      display_name: "Support Niveau 1"       # Nom affiché dans Zammad
      note: "Techniciens de premier niveau"  # Description
      email_address: "support-n1@localhost"  # Email du groupe
      assignment_timeout: 120                # Timeout en minutes
      follow_up_possible: "yes"              # Réouverture de tickets
      active: true                           # Groupe actif
```

**Ajouter un groupe Zammad :**

```yaml
zammad:
  groups:
    # ... groupes existants ...
    
    # Nouveau groupe (correspondant à LDAP "support-vip")
    - name: "support-vip"                    # ← Même nom que groupe LDAP
      display_name: "Support VIP Prioritaire"
      note: "Clients prioritaires - Réponse < 15 minutes"
      email_address: "vip@monentreprise.com"
      assignment_timeout: 15                 # 15 minutes
      follow_up_possible: "yes"
      active: true
```

**Paramètres détaillés :**

| Paramètre | Description | Valeurs |
|-----------|-------------|---------|
| `name` | Nom technique (identique LDAP) | Texte sans espaces |
| `display_name` | Nom affiché dans Zammad | Texte libre |
| `note` | Description du groupe | Texte libre |
| `email_address` | Email pour créer des tickets | Email valide |
| `assignment_timeout` | Délai avant réassignation (minutes) | Nombre ou `null` (∞) |
| `follow_up_possible` | Autoriser réouverture tickets | `"yes"` ou `"no"` |
| `active` | Groupe actif | `true` ou `false` |

---

### 2. Configuration LDAP Integration

```yaml
zammad:
  ldap_integration:
    enabled: true                             # Activer/désactiver LDAP
    host: "openldap"                          # Host (nom du conteneur)
    port: 389                                 # Port LDAP (389 standard)
    ssl: false                                # SSL (true pour LDAPS 636)
    bind_user: "cn=admin,dc=localhost"        # DN de l'admin LDAP
    base_dn: "ou=users,dc=localhost"          # Base de recherche
    
    user_attributes:
      login: "uid"                            # LDAP uid → Zammad login
      firstname: "givenName"                  # LDAP givenName → prénom
      lastname: "sn"                          # LDAP sn → nom
      email: "mail"                           # LDAP mail → email
    
    group_sync:
      enabled: true                           # Synchroniser les groupes
      base: "ou=groups,dc=localhost"          # Base groupes LDAP
      filter: "(objectClass=groupOfNames)"    # Filtre recherche
    
    role_mapping:
      support-n1: "Agent"                     # Groupe LDAP → Rôle Zammad
      support-n2: "Agent"
      administrateurs: "Admin"
      utilisateurs: "Customer"
```

**Mapping des rôles Zammad :**

| Groupe LDAP | Rôle Zammad | Permissions |
|-------------|-------------|-------------|
| `support-n1` | `Agent` | Voir/traiter tickets assignés |
| `support-n2` | `Agent` | Voir/traiter tickets assignés |
| `administrateurs` | `Admin` | Toutes permissions + configuration |
| `utilisateurs` | `Customer` | Créer/voir ses propres tickets |

**Personnaliser le mapping :**

```yaml
role_mapping:
  support-n1: "Agent"
  support-n2: "Agent"
  support-vip: "Agent"              # Nouveau groupe → Agent
  developpeurs: "Agent"             # Développeurs → Agent
  administrateurs: "Admin"
  direction: "Admin"                # Direction → Admin
  utilisateurs: "Customer"
  utilisateurs-externes: "Customer" # Externes → Customer
```

---

## 🌐 Personnalisation Traefik et DNS

### 1. Sous-domaines et URLs

**Configuration** : Les sous-domaines sont définis dans `docker-compose.yml`

**URLs par défaut :**

| Service | URL par défaut | Configurable dans |
|---------|----------------|-------------------|
| Traefik | `http://traefik.localhost` | `docker-compose.yml` → service `traefik` |
| Zammad | `http://zammad.localhost` | `docker-compose.yml` → service `zammad-nginx` |
| Wiki.js | `http://wiki.localhost` | `docker-compose.yml` → service `wikijs` |
| Grafana | `http://grafana.localhost` | `docker-compose.yml` → service `grafana` |
| Prometheus | `http://prometheus.localhost` | `docker-compose.yml` → service `prometheus` |
| phpLDAPadmin | `http://ldap.localhost` | `docker-compose.yml` → service `phpldapadmin` |
| Portainer | `http://portainer.localhost` | `docker-compose.yml` → service `portainer` |
| MailHog | `http://mail.localhost` | `docker-compose.yml` → service `mailhog` |

**Modifier un sous-domaine :**

```yaml
# Dans docker-compose.yml

services:
  zammad-nginx:
    labels:
      - "traefik.enable=true"
      # Modifier ici ↓
      - "traefik.http.routers.zammad.rule=Host(`tickets.${DOMAIN}`)"
      #                                           ↑
      #                          Remplacer "zammad" par "tickets"
```

**Exemples de personnalisation :**

| Service | Sous-domaine par défaut | Personnalisé |
|---------|-------------------------|--------------|
| Zammad | `zammad.localhost` | `tickets.monentreprise.com` |
| Wiki.js | `wiki.localhost` | `docs.monentreprise.com` |
| Grafana | `grafana.localhost` | `monitoring.monentreprise.com` |

---

### 2. Certificats SSL (Production)

**Pour activer HTTPS en production :**

```bash
# 1. Modifier .env
ENVIRONMENT=prod
DOMAIN=monentreprise.com
ADMIN_EMAIL=admin@monentreprise.com

# 2. S'assurer que le DNS pointe vers votre serveur
# tickets.monentreprise.com → IP de votre serveur
# wiki.monentreprise.com → IP de votre serveur
# etc.

# 3. Vérifier config/traefik/traefik.yml
certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@monentreprise.com  # ← Email valide
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

**Traefik générera automatiquement les certificats Let's Encrypt !**

---

## 🔒 Sécurité et Mots de Passe

### 1. Changer les Mots de Passe par Défaut

**OBLIGATOIRE avant la production !**

#### Mots de Passe Infrastructure (`.env`)

```bash
# Éditer .env
nano .env

# Modifier ces lignes :
LDAP_ADMIN_PASSWORD=VotreNouveauMotDePasse123!
POSTGRES_PASSWORD=AutreMotDePasseSecure456!
ZAMMAD_DB_PASS=AutreMotDePasseSecure456!
POSTGRES_ADMIN_PASSWORD=MotDePasseAdmin789!
GF_SECURITY_ADMIN_PASSWORD=GrafanaSecure012!
```

**Après modification** : Redémarrer les services concernés

```bash
docker-compose down
docker-compose up -d
```

#### Mots de Passe Utilisateurs (`config.yaml`)

```yaml
# Éditer scripts/config.yaml
nano scripts/config.yaml

ldap:
  users:
    - uid: "tech1"
      # ... autres champs ...
      password: "NouveauMotDePasse123!"  # ← Modifier ici
```

**Après modification** : Relancer la configuration

```bash
./configure-all.sh
```

---

### 2. Générer des Mots de Passe Sécurisés

**Méthode 1 : OpenSSL (aléatoire complet)**

```bash
# Mot de passe de 20 caractères
openssl rand -base64 20

# Exemple de sortie :
# 8KpQx2Vy+3mJ9WnL4RtA5Zc=
```

**Méthode 2 : pwgen (mémorisable)**

```bash
# Installer pwgen
sudo apt install pwgen

# Générer 5 mots de passe de 16 caractères
pwgen -s 16 5

# Exemple de sortie :
# vK2mP9xWq3nL5RtA
# 7JzC4hYu8FpD1BnE
```

**Méthode 3 : Gestionnaire de mots de passe**

Recommandé : **Bitwarden**, **1Password**, **KeePassXC**

---

### 3. Politique de Mots de Passe Recommandée

| Type d'utilisateur | Longueur | Complexité | Rotation |
|--------------------|----------|------------|----------|
| **Administrateurs** | 20+ caractères | Aléatoire complet | 90 jours |
| **Agents support** | 16+ caractères | Mélange fort | 120 jours |
| **Utilisateurs** | 12+ caractères | Mélange moyen | 180 jours |
| **Services** | 32+ caractères | Aléatoire complet | 365 jours |

---

## 👥 Gestion des Utilisateurs

### 1. Ajouter un Utilisateur

**Méthode recommandée : Via `config.yaml`**

```yaml
# Éditer scripts/config.yaml
nano scripts/config.yaml

ldap:
  users:
    # ... utilisateurs existants ...
    
    # Nouvel utilisateur
    - uid: "nouveau.utilisateur"
      firstName: "Prénom"
      lastName: "Nom"
      email: "prenom.nom@monentreprise.com"
      password: "MotDePasseSecure123!"
      groups: ["support-n1"]  # ou ["utilisateurs"], etc.
```

**Appliquer les changements :**

```bash
./configure-all.sh
```

---

### 2. Modifier un Utilisateur

**Changer le mot de passe :**

```yaml
ldap:
  users:
    - uid: "tech1"
      firstName: "Pierre"
      lastName: "Martin"
      email: "pierre.martin@localhost"
      password: "NouveauMotDePasse456!"  # ← Modifier ici
      groups: ["support-n1"]
```

**Changer les groupes :**

```yaml
ldap:
  users:
    - uid: "tech1"
      firstName: "Pierre"
      lastName: "Martin"
      email: "pierre.martin@localhost"
      password: "TechN1Pass123!"
      groups: 
        - "support-n1"
        - "support-n2"  # ← Ajouter un groupe
```

**Appliquer :**

```bash
./configure-all.sh
```

---

### 3. Supprimer un Utilisateur

**Méthode 1 : Via phpLDAPadmin (interface web)**

```
1. Aller sur http://ldap.localhost
2. Login : cn=admin,dc=localhost
3. Password : (LDAP_ADMIN_PASSWORD depuis .env)
4. Naviguer : ou=users → cliquer sur l'utilisateur
5. Cliquer "Delete this entry"
```

**Méthode 2 : Via ligne de commande**

```bash
# Supprimer un utilisateur LDAP
docker-compose exec openldap ldapdelete \
  -x -D "cn=admin,dc=localhost" \
  -w "$(grep LDAP_ADMIN_PASSWORD .env | cut -d'=' -f2)" \
  "uid=utilisateur.a.supprimer,ou=users,dc=localhost"
```

**Méthode 3 : Supprimer de `config.yaml` et relancer**

```yaml
# Commenter ou supprimer l'utilisateur
ldap:
  users:
    # - uid: "ancien.utilisateur"
    #   firstName: "Ancien"
    #   lastName: "Utilisateur"
    #   ...
```

⚠️ Cette méthode ne supprime PAS l'utilisateur existant en LDAP, elle évite seulement de le recréer.

---

## 👨‍👩‍👧‍👦 Gestion des Groupes

### 1. Ajouter un Groupe

**Étape 1 : Créer le groupe LDAP**

```yaml
# Dans scripts/config.yaml

ldap:
  groups:
    # ... groupes existants ...
    
    - name: "nouveau-groupe"
      description: "Description du nouveau groupe"
```

**Étape 2 : Créer le groupe Zammad (mapping 1:1)**

```yaml
zammad:
  groups:
    # ... groupes existants ...
    
    - name: "nouveau-groupe"  # ← Même nom que LDAP
      display_name: "Nouveau Groupe"
      note: "Description du groupe dans Zammad"
      email_address: "nouveau-groupe@monentreprise.com"
      assignment_timeout: 120
      follow_up_possible: "yes"
      active: true
```

**Étape 3 : Ajouter le mapping de rôle**

```yaml
zammad:
  ldap_integration:
    role_mapping:
      # ... mappings existants ...
      nouveau-groupe: "Agent"  # ou "Admin" ou "Customer"
```

**Appliquer :**

```bash
./configure-all.sh
```

---

### 2. Modifier un Groupe

**Changer la description :**

```yaml
ldap:
  groups:
    - name: "support-n1"
      description: "Nouvelle description du groupe"  # ← Modifier
```

**Changer le timeout d'assignation (Zammad) :**

```yaml
zammad:
  groups:
    - name: "support-n1"
      # ... autres champs ...
      assignment_timeout: 60  # ← Changer de 120 à 60 minutes
```

---

### 3. Supprimer un Groupe

⚠️ **Attention** : Supprimer un groupe nécessite de gérer les utilisateurs membres.

**Avant de supprimer :**

1. Lister les membres du groupe
2. Réassigner les membres à d'autres groupes
3. Supprimer le groupe

**Via phpLDAPadmin :**

```
1. http://ldap.localhost
2. Naviguer : ou=groups → cliquer sur le groupe
3. Vérifier qu'aucun utilisateur n'est membre
4. "Delete this entry"
```

---

## 📧 Configuration Email

### 1. Email → Ticket (Développement)

**MailHog est préconfiguré pour le développement.**

**Tester l'envoi d'email → ticket :**

```bash
# Envoyer un email de test
docker-compose exec mailhog mail \
  -s "Test Ticket" \
  -f "utilisateur@localhost" \
  support-n1@localhost <<< "Ceci est un test de création de ticket par email."
```

**Vérifier :**

1. Interface MailHog : `http://mail.localhost`
2. Zammad : Le ticket doit être créé dans le groupe correspondant

---

### 2. Email → Ticket (Production)

**Configurer un compte IMAP dans Zammad :**

```yaml
# Dans scripts/config.yaml

email_to_ticket:
  mode: "imap"  # Changer de "mailhog" à "imap"
  
  imap:
    host: "imap.gmail.com"
    port: 993
    ssl: true
    user: "ticketing@monentreprise.com"
    password: "MotDePasseApp123!"
    folder: "INBOX"
```

**Appliquer :**

```bash
./configure-all.sh
```

**Ou manuellement dans Zammad :**

```
Admin → Channels → Email → Add Account
Type : IMAP
Host : imap.gmail.com
Port : 993
SSL : Yes
User : ticketing@monentreprise.com
Password : ***
Folder : INBOX
Group : support-n1  (ou groupe par défaut)
```

---

### 3. Envoi d'Email depuis Zammad

**Configuration SMTP :**

```yaml
# Dans scripts/config.yaml

email_sending:
  smtp:
    host: "smtp.gmail.com"
    port: 587
    user: "ticketing@monentreprise.com"
    password: "MotDePasseApp123!"
    authentication: "login"
    enable_starttls_auto: true
```

**Ou dans Zammad Admin :**

```
Admin → Channels → Email → Configure Outbound
Type : SMTP
Host : smtp.gmail.com
Port : 587
User : ticketing@monentreprise.com
Password : ***
```

---

## 🚀 Personnalisation Avancée

### 1. Ajouter un Nouveau Service Docker

**Exemple : Ajouter Nextcloud**

```yaml
# Dans docker-compose.yml

services:
  # ... services existants ...
  
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    networks:
      - ticketing_network
    volumes:
      - ./data/nextcloud:/var/www/html
    environment:
      - MYSQL_HOST=postgres
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=${NEXTCLOUD_DB_PASS}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`cloud.${DOMAIN}`)"
      - "traefik.http.routers.nextcloud.entrypoints=web"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
```

**Ajouter dans `.env` :**

```bash
# Nextcloud
NEXTCLOUD_DB_PASS=NextcloudSecure123!
```

**Déployer :**

```bash
docker-compose up -d nextcloud
```

---

### 2. Personnaliser les Métriques Prometheus

**Ajouter un nouveau scrape job :**

```yaml
# Dans config/prometheus/prometheus.yml

scrape_configs:
  # ... jobs existants ...
  
  - job_name: 'mon-application'
    static_configs:
      - targets: ['mon-app:9090']
    scrape_interval: 15s
```

---

### 3. Personnaliser les Dashboards Grafana

**Importer un dashboard :**

```
1. Aller sur http://grafana.localhost
2. Login : admin / (GF_SECURITY_ADMIN_PASSWORD)
3. Create → Import
4. Entrer l'ID du dashboard (ex: 1860 pour Node Exporter)
5. Select Prometheus datasource
6. Import
```

---

### 4. Personnaliser Wiki.js

**Configuration initiale :**

```
1. http://wiki.localhost
2. Setup : choisir langue, créer admin
3. Admin → Storage → Configure Git (optionnel)
4. Admin → Theme → Personnaliser apparence
```

---

## 📝 Checklist de Personnalisation

### Avant le Déploiement

- [ ] Modifier `DOMAIN` dans `.env`
- [ ] Modifier `ENVIRONMENT` (dev/prod) dans `.env`
- [ ] Changer tous les mots de passe dans `.env`
- [ ] Modifier `ADMIN_EMAIL` dans `.env`
- [ ] Configurer SMTP si production

### Après le Déploiement

- [ ] Personnaliser `scripts/config.yaml` (groupes, utilisateurs)
- [ ] Exécuter `./configure-all.sh`
- [ ] Tester la connexion LDAP dans Zammad
- [ ] Configurer les emails entrants (IMAP)
- [ ] Configurer les emails sortants (SMTP)
- [ ] Personnaliser les sous-domaines si nécessaire
- [ ] Importer les dashboards Grafana
- [ ] Configurer Wiki.js
- [ ] Tester la création de tickets

### Sécurité Production

- [ ] Tous les mots de passe changés
- [ ] Certificats SSL actifs (Let's Encrypt)
- [ ] Firewall configuré (ports 80, 443 uniquement)
- [ ] Sauvegardes automatiques activées
- [ ] Monitoring actif (Prometheus + Grafana)
- [ ] Alertes configurées
- [ ] Logs centralisés

---

## 🆘 Support et Documentation

### Fichiers de Documentation

| Fichier | Description |
|---------|-------------|
| `README.md` | Vue d'ensemble du projet |
| `doc/POST-INSTALLATION.md` | Guide post-installation |
| `doc/GUIDE-PERSONNALISATION.md` | Ce fichier |
| `doc/00 - TicketOnTheFly.md` | Architecture globale |
| `doc/10 - Configuration Automatisée.md` | Phase 10 détaillée |
| `scripts/README.md` | Documentation des scripts |

### Commandes Utiles

```bash
# Vérifier l'état des services
docker-compose ps

# Voir les logs d'un service
docker-compose logs -f zammad-nginx

# Redémarrer un service
docker-compose restart zammad-nginx

# Reconfigurer LDAP et Zammad
./configure-all.sh

# Sauvegarder les données
./backup.sh

# Vérifier la configuration LDAP
docker-compose exec openldap ldapsearch -x -b "dc=localhost"
```

---

## ✅ Conclusion

Ce guide vous permet de personnaliser complètement TicketingOnTheFly pour l'adapter à votre organisation. Les modifications les plus courantes sont :

1. ✅ **Domaine et SSL** (`.env`)
2. ✅ **Mots de passe** (`.env` et `config.yaml`)
3. ✅ **Groupes et utilisateurs** (`config.yaml`)
4. ✅ **Email** (SMTP et IMAP)

**Bonnes pratiques :**
- Toujours tester en développement (`ENVIRONMENT=dev`) avant la production
- Sauvegarder avant toute modification majeure (`./backup.sh`)
- Versionner votre `config.yaml` personnalisé (hors Git pour sécurité)
- Documenter vos modifications spécifiques

---

**Besoin d'aide ?** Consultez les autres fichiers de documentation dans `doc/`.
