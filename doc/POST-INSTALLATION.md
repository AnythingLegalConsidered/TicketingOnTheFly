# Guide de Configuration Post-Installation

Ce document décrit les étapes de configuration nécessaires après le premier démarrage de l'infrastructure TicketingOnTheFly.

---

## ⚠️ Note Importante sur l'Accès aux Services avec Traefik

**L'infrastructure TicketingOnTheFly utilise Traefik comme reverse proxy.**

### En Environnement de Développement Local (DOMAIN=localhost)

**Problème :** Les navigateurs ne résolvent pas automatiquement les sous-domaines `*.localhost`.

**Solution 1 : Modification du fichier hosts (Recommandé)**

Sur **Windows** : Éditer `C:\Windows\System32\drivers\etc\hosts` en tant qu'administrateur
Sur **Linux/Mac** : Éditer `/etc/hosts` avec `sudo`

Ajouter les lignes suivantes :
```
127.0.0.1 traefik.localhost
127.0.0.1 zammad.localhost
127.0.0.1 grafana.localhost
127.0.0.1 prometheus.localhost
127.0.0.1 wiki.localhost
127.0.0.1 ocs.localhost
127.0.0.1 portainer.localhost
127.0.0.1 ldap.localhost
127.0.0.1 mailhog.localhost
```

**Après modification**, vous pouvez accéder aux services :
- Dashboard Traefik : `http://traefik.localhost`
- Zammad : `http://zammad.localhost`
- Grafana : `http://grafana.localhost`
- Etc.

**Solution 2 : Test avec curl**
```bash
curl -H "Host: zammad.localhost" http://localhost
```

**Note :** En local, tout est en HTTP car Let's Encrypt n'émet pas de certificats pour "localhost".

### En Environnement de Production (avec un vrai domaine)

**Prérequis OBLIGATOIRES :**

1. **Acheter un nom de domaine** (OVH, Gandi, Cloudflare, etc.)

2. **Configurer les enregistrements DNS de type A** pour chaque service :
   ```
   traefik.mondomaine.com      A    <IP_PUBLIQUE_DU_SERVEUR>
   zammad.mondomaine.com       A    <IP_PUBLIQUE_DU_SERVEUR>
   grafana.mondomaine.com      A    <IP_PUBLIQUE_DU_SERVEUR>
   prometheus.mondomaine.com   A    <IP_PUBLIQUE_DU_SERVEUR>
   wiki.mondomaine.com         A    <IP_PUBLIQUE_DU_SERVEUR>
   ocs.mondomaine.com          A    <IP_PUBLIQUE_DU_SERVEUR>
   portainer.mondomaine.com    A    <IP_PUBLIQUE_DU_SERVEUR>
   ldap.mondomaine.com         A    <IP_PUBLIQUE_DU_SERVEUR>
   mailhog.mondomaine.com      A    <IP_PUBLIQUE_DU_SERVEUR>
   ```

3. **Modifier le fichier `.env`** :
   ```bash
   DOMAIN=mondomaine.com
   ACME_EMAIL=votre-email@mondomaine.com
   ```

4. **Redémarrer les services** :
   ```bash
   docker-compose down
   docker-compose up -d
   ```

5. **Vérifier les certificats** (peut prendre 1-2 minutes) :
   ```bash
   docker logs traefik | grep -i "certificate"
   ```

**Après configuration DNS**, tous les services seront accessibles en HTTPS avec certificats valides :
- `https://zammad.mondomaine.com` ✅ Certificat SSL valide
- `https://grafana.mondomaine.com` ✅ Certificat SSL valide
- Etc.

---

## Traefik - Reverse Proxy et HTTPS

### Accès au Dashboard Traefik
**URL Locale :** `http://traefik.localhost` (après modification du fichier hosts)
**URL Production :** `https://traefik.mondomaine.com`

**Authentification :**
- Utilisateur : `admin`
- Mot de passe : `TicketingAdmin2025`

### Fonctionnalités du Dashboard

1. **HTTP > Routers**
   - Voir tous les routeurs configurés
   - Vérifier les règles de routage (Host)
   - Statut des services backend

2. **HTTP > Services**
   - Liste des services détectés
   - Adresses des serveurs backend
   - État de santé (health checks)

3. **HTTP > Middlewares**
   - Middleware d'authentification basique
   - Redirections HTTP → HTTPS

### Vérification du Fonctionnement

**Vérifier les logs Traefik :**
```bash
docker logs traefik --tail 50
```

**Vérifier la détection des services :**
```bash
docker logs traefik | grep -i "Creating router"
```

**Tester une route spécifique :**
```bash
# Test local
curl -H "Host: zammad.localhost" http://localhost

# Test production
curl https://zammad.mondomaine.com
```

### Gestion des Certificats Let's Encrypt

**Fichier de stockage :** `config/traefik/acme.json`

**Vérifier les certificats obtenus :**
```bash
# Voir le contenu (format JSON)
cat config/traefik/acme.json

# Vérifier la taille (0 = aucun certificat)
ls -lh config/traefik/acme.json
```

**Réinitialiser les certificats (si problème) :**
```bash
# Arrêter Traefik
docker-compose stop traefik

# Vider le fichier acme.json
echo "{}" > config/traefik/acme.json
chmod 600 config/traefik/acme.json

# Redémarrer Traefik
docker-compose up -d traefik

# Suivre l'obtention des nouveaux certificats
docker logs traefik -f
```

### Sécurisation Avancée (Optionnel)

**Limiter l'accès au dashboard par IP :**

Modifier `docker-compose.yml`, ajouter un middleware IP whitelist :
```yaml
traefik:
  labels:
    - "traefik.http.middlewares.ipwhitelist.ipwhitelist.sourcerange=127.0.0.1/32,192.168.1.0/24"
    - "traefik.http.routers.traefik.middlewares=auth,ipwhitelist"
```

**Ajouter des headers de sécurité :**
```yaml
traefik:
  labels:
    - "traefik.http.middlewares.security-headers.headers.stsSeconds=31536000"
    - "traefik.http.middlewares.security-headers.headers.stsIncludeSubdomains=true"
    - "traefik.http.middlewares.security-headers.headers.stsPreload=true"
```

### Dépannage Traefik

**Service inaccessible (502 Bad Gateway) :**
```bash
# Vérifier que le service backend est démarré
docker-compose ps SERVICE_NAME

# Vérifier les logs du service
docker logs SERVICE_NAME

# Vérifier les logs Traefik
docker logs traefik | grep -i SERVICE_NAME
```

**Certificat Let's Encrypt non obtenu :**
```bash
# Vérifier la configuration DNS
nslookup sous-domaine.mondomaine.com

# Vérifier que les ports 80/443 sont ouverts
sudo netstat -tlnp | grep -E ':80|:443'

# Vérifier les logs d'erreur ACME
docker logs traefik | grep -i acme
```

**Redirect loop (trop de redirections) :**
- Vérifier que le service backend ne fait pas aussi de redirection HTTPS
- Vérifier la configuration des entrypoints dans `traefik.yml`

---

## OCS Inventory - Configuration Initiale

### Accès à l'Interface
**URL Locale :** `http://ocs.localhost/ocsreports` (après modification hosts)
**URL Production :** `https://ocs.mondomaine.com/ocsreports`

### Assistant d'Installation (Premier démarrage uniquement)

1. **Ouvrir l'URL** dans votre navigateur
   
2. **Renseigner les paramètres de base de données :**
   - **MySQL Server:** `ocs-db`
   - **MySQL User:** `ocs`
   - **MySQL Password:** Voir la variable `OCS_DB_PASSWORD` dans votre fichier `.env`
   - **Database Name:** `ocsdb`

3. **Cliquer sur "Send"** pour lancer la création de la base de données

4. **Connexion initiale :**
   - Utilisateur: `admin`
   - Mot de passe: `admin`

### ⚠️ SÉCURISATION IMMÉDIATE (OBLIGATOIRE)

#### 1. Supprimer le fichier d'installation

**Cette commande doit être exécutée immédiatement après la première connexion :**

```bash
docker-compose exec ocs-server rm /usr/share/ocsinventory-reports/ocsreports/install.php
```

**Vérifier la suppression :**
```bash
docker-compose exec ocs-server ls -la /usr/share/ocsinventory-reports/ocsreports/ | grep install
```

Si la commande ne retourne rien, le fichier a bien été supprimé.

#### 2. Changer le mot de passe administrateur

1. Se connecter avec `admin` / `admin`
2. Cliquer sur l'icône utilisateur en haut à droite
3. Sélectionner "User profile"
4. Dans l'onglet "Password", définir un nouveau mot de passe fort
5. Sauvegarder

**⚠️ NE JAMAIS** laisser le mot de passe `admin` par défaut en production.

---

## Wiki.js - Configuration Initiale

### Accès à l'Interface
**URL:** `http://localhost:8084`

### Assistant d'Installation (Premier démarrage uniquement)

1. **Ouvrir l'URL** dans votre navigateur

2. **Créer le compte administrateur :**
   - **Email:** Votre adresse email (sera l'identifiant de connexion)
   - **Mot de passe:** Un mot de passe fort (minimum 12 caractères recommandés)
   - **Confirmer le mot de passe**

3. **Configurer l'URL du site :**
   - Pour le développement : `http://localhost:8084`
   - Pour la production (avec Traefik) : `https://wiki.votre-domaine.com`

4. **Finaliser l'installation :**
   - Cliquer sur "Install"
   - Attendre que l'installation se termine
   - Vous serez automatiquement connecté

### Configuration de l'Authentification LDAP

**Objectif :** Permettre aux utilisateurs de l'annuaire OpenLDAP de se connecter à Wiki.js

#### Étapes

1. **Accéder à l'administration**
   - Cliquer sur votre avatar en haut à droite
   - Sélectionner "Administration"

2. **Aller dans Authentification**
   - Dans le menu de gauche : "Authentification"
   - Cliquer sur "LDAP / Active Directory"

3. **Activer et configurer LDAP**
   - Activer le slider pour activer cette méthode d'authentification

4. **Renseigner les paramètres de connexion :**
   ```
   Host: openldap
   Port: 389
   Bind DN: cn=admin,dc=localhost
   Password: Voir LDAP_ADMIN_PASSWORD dans le fichier .env
   Base DN: ou=users,dc=localhost
   User Login Field: uid
   ```

5. **Configuration du Profile Mapping :**
   ```
   Username Field: uid
   Display Name Field: cn
   Email Field: mail
   ```

6. **Sauvegarder la configuration**
   - Cliquer sur "Apply" en haut à droite

7. **Tester la connexion LDAP**
   - Se déconnecter de Wiki.js
   - Tenter de se reconnecter avec un compte utilisateur LDAP

### Premières Pages à Créer

1. **Page d'accueil**
   - Créer une page d'accueil personnalisée
   - Expliquer l'objet du wiki (documentation technique interne)

2. **Structure recommandée :**
   - `/infrastructure` - Documentation de l'infrastructure
   - `/procedures` - Procédures opérationnelles
   - `/troubleshooting` - Guides de dépannage
   - `/onboarding` - Guide d'intégration nouveaux membres

---

## Zammad - Configuration Initiale

### Accès à l'Interface
**URL:** `http://localhost:8081`

### Configuration au Premier Démarrage

#### 1. Création du Compte Administrateur

Au premier accès, Zammad vous guidera pour créer le compte administrateur principal.

1. **Informations de base :**
   - Prénom et Nom
   - Adresse email (sera l'identifiant de connexion)
   - Mot de passe fort

2. **Configuration de l'Organisation :**
   - Nom de l'organisation
   - URL du système (peut être modifié plus tard)

#### 2. Configuration Email (Optionnel au départ)

Vous pouvez configurer l'envoi/réception d'emails plus tard via :
- **Paramètres** > **Canaux** > **Email**

#### 3. Intégration LDAP (À faire après OpenLDAP)

Une fois OpenLDAP configuré :
1. **Paramètres** > **Sécurité** > **Authentification Tierce**
2. Sélectionner **LDAP**
3. Configurer :
   - Host: `openldap`
   - Port: `389`
   - Base DN: `dc=localhost` (ou votre domaine configuré)
   - Bind DN: `cn=admin,dc=localhost`
   - Bind Password: Valeur de `LDAP_ADMIN_PASSWORD` du fichier `.env`

---

## phpLDAPadmin - Accès à l'Annuaire

### Accès à l'Interface
**URL:** `http://localhost:8080`

### Connexion

1. Cliquer sur "login" dans le menu de gauche
2. **Login DN:** `cn=admin,dc=localhost`
3. **Password:** Valeur de `LDAP_ADMIN_PASSWORD` du fichier `.env`

### Première Configuration

#### Créer une Unité Organisationnelle pour les Utilisateurs

1. Cliquer sur `dc=localhost` dans l'arbre à gauche
2. Sélectionner "Create a child entry"
3. Choisir "Generic: Organisational Unit"
4. **ou (Organisational Unit):** `users`
5. Créer

#### Créer un Premier Utilisateur

1. Cliquer sur `ou=users,dc=localhost`
2. "Create a child entry"
3. Choisir "Default: inetOrgPerson"
4. Remplir les champs obligatoires :
   - **cn (Common Name):** ex: "Jean Dupont"
   - **sn (Surname):** ex: "Dupont"
   - **uid:** ex: "jdupont"
   - **userPassword:** Définir un mot de passe

---

## Portainer - Accès à la Gestion Docker

### Accès à l'Interface
**URL:** `https://localhost:9443`

**Note:** Utiliser HTTPS (le HTTP sur le port 9000 est également disponible)

### Premier Accès

1. **Créer le compte administrateur**
   - Utilisateur: choisir un nom (ex: `admin`)
   - Mot de passe: minimum 12 caractères

2. **Sélectionner l'environnement**
   - Choisir "Get Started"
   - Sélectionner "local" (Docker local)

### Navigation dans Portainer

- **Containers:** Voir tous les conteneurs en cours d'exécution
- **Images:** Gérer les images Docker
- **Volumes:** Voir les volumes de données
- **Networks:** Gérer les réseaux Docker
- **Stacks:** Voir la pile Docker Compose (TicketingOnTheFly)

**Astuce:** Les liens vers les conteneurs dans Portainer fonctionnent maintenant correctement (127.0.0.1 au lieu de 0.0.0.0).

---

## Prometheus & Grafana - Supervision et Monitoring

### Prometheus - Collecte des Métriques

#### Vérification du Démarrage
**URL:** `http://localhost:9090`

1. **Vérifier les Cibles (Targets)**
   - Aller dans **Status > Targets**
   - Vérifier que les 2 jobs sont **UP** :
     - `prometheus` (auto-monitoring)
     - `cadvisor` (métriques des conteneurs Docker)

2. **Tester des Requêtes PromQL**
   - Aller dans **Graph**
   - Exemples de requêtes :
     - `up` : statut de tous les targets
     - `container_memory_usage_bytes` : utilisation mémoire des conteneurs
     - `container_cpu_usage_seconds_total` : utilisation CPU

#### Fichier de Configuration
- **Emplacement:** `config/prometheus/prometheus.yml`
- **Intervalle de scraping:** 15 secondes
- **Targets configurées:**
  - Prometheus lui-même (localhost:9090)
  - cAdvisor (cadvisor:8080)

**Note:** Pour ajouter de nouvelles cibles, modifier `prometheus.yml` et redémarrer le conteneur :
```bash
docker-compose restart prometheus
```

### Grafana - Visualisation des Métriques

#### Premier Accès
**URL:** `http://localhost:8085`

1. **Connexion Initiale**
   - Utilisateur: `admin`
   - Mot de passe: `admin`
   - **Important:** Changez le mot de passe à la première connexion

2. **Ajouter la Source de Données Prometheus**
   - Aller dans **Configuration > Data Sources** (icône engrenage à gauche)
   - Cliquer sur **Add data source**
   - Sélectionner **Prometheus**
   - Configurer :
     - **Name:** Prometheus
     - **URL:** `http://prometheus:9090`
     - Laisser les autres paramètres par défaut
   - Cliquer sur **Save & test**
   - Vérifier le message vert : "Data source is working"

3. **Importer un Dashboard pour Docker**
   - Aller dans **Dashboards > Import** (icône + à gauche)
   - Entrer l'ID du dashboard : **13981** (Docker cAdvisor Dashboard)
   - Cliquer sur **Load**
   - Sélectionner la source de données **Prometheus**
   - Cliquer sur **Import**
   - Le dashboard affiche maintenant les métriques des conteneurs Docker

#### Dashboards Recommandés

| Dashboard ID | Nom                              | Description                          |
|--------------|----------------------------------|--------------------------------------|
| 13981        | Docker Container & Host Metrics  | Métriques détaillées des conteneurs  |
| 193          | Docker Monitoring                | Vue d'ensemble Docker                |
| 1860         | Node Exporter Full               | Métriques système (si node_exporter) |
| 3662         | Prometheus 2.0 Overview          | Métriques Prometheus lui-même        |

#### Création d'Alertes
- Aller dans **Alerting > Alert rules**
- Exemples d'alertes utiles :
  - Conteneur arrêté : `up{job="cadvisor"} == 0`
  - Mémoire élevée : `container_memory_usage_bytes > 1GB`
  - CPU élevé : `rate(container_cpu_usage_seconds_total[5m]) > 0.8`

### Métriques Disponibles

#### Métriques Conteneurs (via cAdvisor)
- `container_cpu_usage_seconds_total` : Utilisation CPU cumulée
- `container_memory_usage_bytes` : Utilisation mémoire actuelle
- `container_network_receive_bytes_total` : Octets réseau reçus
- `container_network_transmit_bytes_total` : Octets réseau envoyés
- `container_fs_usage_bytes` : Utilisation disque du conteneur

#### Métriques Prometheus
- `prometheus_tsdb_storage_blocks_bytes` : Taille des blocs de stockage
- `prometheus_http_requests_total` : Nombre de requêtes HTTP
- `prometheus_target_scrapes_total` : Nombre de scrapes effectués

### Dépannage

#### Prometheus ne démarre pas
```bash
# Vérifier les logs
docker logs prometheus

# Vérifier la syntaxe du fichier de configuration
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

#### cAdvisor n'apparaît pas dans les Targets
```bash
# Vérifier que cAdvisor est en cours d'exécution
docker-compose ps cadvisor

# Vérifier les logs de cAdvisor
docker logs cadvisor

# Tester l'accès aux métriques depuis Prometheus
docker-compose exec prometheus wget -O- http://cadvisor:8080/metrics
```

#### Grafana ne peut pas se connecter à Prometheus
```bash
# Vérifier que Prometheus est accessible depuis Grafana
docker-compose exec grafana wget -O- http://prometheus:9090/api/v1/query?query=up

# Vérifier le réseau Docker
docker network inspect systeme-ticketing-net
```

---

## MailHog - Serveur SMTP de Test

### Accès à l'Interface
**URL Locale :** `http://mailhog.localhost`
**URL Production :** `https://mailhog.mondomaine.com`

**Authentification :** Aucune

### Description

MailHog est un serveur SMTP factice qui capture tous les emails envoyés par les applications sans les transmettre réellement. Parfait pour le développement et les tests.

### Fonctionnement

1. **Les applications envoient des emails** (Zammad, Grafana, etc.)
2. **MailHog intercepte** tous les emails sur le port SMTP 1025
3. **Les emails sont affichés** dans l'interface web sur le port 8025
4. **Aucun email n'est envoyé** vers l'extérieur

### Utilisation

#### Visualiser les Emails Capturés

1. Accéder à `http://mailhog.localhost`
2. L'interface affiche la liste de tous les emails reçus
3. Cliquer sur un email pour voir :
   - Expéditeur (From)
   - Destinataire(s) (To)
   - Sujet (Subject)
   - Contenu HTML et texte brut

#### Tester l'Envoi depuis Zammad

1. Se connecter à Zammad : `http://zammad.localhost`
2. Créer un nouveau ticket
3. Ajouter une réponse à un ticket existant
4. Vérifier immédiatement dans MailHog : `http://mailhog.localhost`
5. L'email de notification apparaît instantanément

#### Fonctionnalités de l'Interface

- **Search** : Rechercher par expéditeur, destinataire ou sujet
- **Clear** : Supprimer tous les emails
- **Preview** : Visualiser le rendu HTML
- **Source** : Voir le code source brut de l'email
- **MIME** : Examiner la structure MIME

### Configuration SMTP dans Zammad

La configuration est automatique via les variables d'environnement :

```bash
# .env
ZAMMAD_SMTP_HOST=mailhog
ZAMMAD_SMTP_PORT=1025
ZAMMAD_SMTP_USER=
ZAMMAD_SMTP_PASSWORD=
ZAMMAD_SMTP_DOMAIN=localhost
```

Ces variables sont injectées automatiquement dans tous les services Zammad.

### Transition vers Production

**⚠️ Important :** MailHog ne doit PAS être utilisé en production.

**En production, modifier `.env` :**
```bash
# Exemple avec SendGrid
ZAMMAD_SMTP_HOST=smtp.sendgrid.net
ZAMMAD_SMTP_PORT=587
ZAMMAD_SMTP_USER=apikey
ZAMMAD_SMTP_PASSWORD=SG.votre_cle_api_sendgrid
ZAMMAD_SMTP_DOMAIN=mondomaine.com
```

**Ou avec Gmail :**
```bash
ZAMMAD_SMTP_HOST=smtp.gmail.com
ZAMMAD_SMTP_PORT=587
ZAMMAD_SMTP_USER=notifications@gmail.com
ZAMMAD_SMTP_PASSWORD=votre_mot_de_passe_application
ZAMMAD_SMTP_DOMAIN=gmail.com
```

**Désactiver MailHog en production :**
```yaml
# docker-compose.yml
# mailhog:
#   # Service désactivé en production
```

### Dépannage

#### Aucun email n'apparaît dans MailHog

```bash
# Vérifier que MailHog est démarré
docker-compose ps mailhog

# Vérifier les logs de MailHog
docker logs mailhog

# Vérifier la configuration SMTP de Zammad
docker-compose exec zammad-railsserver env | grep SMTP
```

#### MailHog inaccessible

```bash
# Vérifier que Traefik a détecté MailHog
docker logs traefik | grep -i mailhog

# Vérifier le réseau
docker network inspect systeme-ticketing-net | grep mailhog
```

---

## Récapitulatif des URLs d'Accès

### Environnement Local (après modification du fichier hosts)

| Service | URL Locale | Authentification |
|---------|------------|------------------|
| **Traefik Dashboard** | http://traefik.localhost | admin / TicketingAdmin2025 |
| **Zammad** | http://zammad.localhost | Configuration initiale requise |
| **Grafana** | http://grafana.localhost | admin / admin (à changer) |
| **Prometheus** | http://prometheus.localhost | Aucune |
| **Wiki.js** | http://wiki.localhost | Configuration initiale requise |
| **OCS Inventory** | http://ocs.localhost/ocsreports | admin / admin (à changer) |
| **Portainer** | http://portainer.localhost | Création compte à la 1ère connexion |
| **phpLDAPadmin** | http://ldap.localhost | cn=admin,dc=localhost / LDAP_ADMIN_PASSWORD |
| **MailHog** | http://mailhog.localhost | Aucune |

### Environnement Production (avec domaine configuré)

| Service | URL Production | Protocole |
|---------|----------------|-----------|
| **Traefik Dashboard** | https://traefik.mondomaine.com | HTTPS + Auth |
| **Zammad** | https://zammad.mondomaine.com | HTTPS |
| **Grafana** | https://grafana.mondomaine.com | HTTPS |
| **Prometheus** | https://prometheus.mondomaine.com | HTTPS |
| **Wiki.js** | https://wiki.mondomaine.com | HTTPS |
| **OCS Inventory** | https://ocs.mondomaine.com/ocsreports | HTTPS |
| **Portainer** | https://portainer.mondomaine.com | HTTPS |
| **phpLDAPadmin** | https://ldap.mondomaine.com | HTTPS |
| **MailHog** | https://mailhog.mondomaine.com | HTTPS (dev uniquement) |

**Note :** Tous les certificats SSL sont obtenus automatiquement via Let's Encrypt.

### Anciens Ports (Avant Traefik - Obsolètes)

**⚠️ Ces ports ne sont PLUS exposés depuis l'implémentation de Traefik :**

| Service (Obsolète) | Ancien Port | Nouveau Accès |
|--------------------|-------------|---------------|
| phpLDAPadmin | 8080 | http://ldap.localhost |
| Zammad | 8081 | http://zammad.localhost |
| Zammad Rails | 8082 | (interne uniquement) |
| OCS Inventory | 8083 | http://ocs.localhost |
| Wiki.js | 8084 | http://wiki.localhost |
| Grafana | 8085 | http://grafana.localhost |
| Portainer (HTTP) | 9000 | http://portainer.localhost |
| Prometheus | 9090 | http://prometheus.localhost |
| Portainer (HTTPS) | 9443 | http://portainer.localhost |

---

## Ordre de Configuration Recommandé

1. ✅ **Traefik** - Configurer le domaine et vérifier les routes (Dashboard)
2. ✅ **Portainer** - Pour surveiller l'état de tous les services
3. ✅ **phpLDAPadmin** - Créer la structure LDAP et les premiers utilisateurs
4. ✅ **OCS Inventory** - Configuration initiale et sécurisation
5. ✅ **Zammad** - Configuration et intégration LDAP
6. ✅ **Wiki.js** - Configuration et intégration LDAP
7. ✅ **Prometheus & Grafana** - Ajouter la datasource Prometheus et importer les dashboards

---

## Troubleshooting

### Un service ne répond pas

```bash
# Vérifier l'état de tous les conteneurs
docker-compose ps

# Voir les logs d'un service spécifique
docker-compose logs [nom-du-service]

# Redémarrer un service
docker-compose restart [nom-du-service]

# Redémarrer tous les services
docker-compose restart
```

### Réinitialiser un service

```bash
# Arrêter le service
docker-compose stop [nom-du-service]

# Supprimer le conteneur (les données dans les volumes sont préservées)
docker-compose rm [nom-du-service]

# Recréer et redémarrer
docker-compose up -d [nom-du-service]
```

### Accès aux logs en temps réel

```bash
# Suivre les logs de tous les services
docker-compose logs -f

# Suivre les logs d'un service spécifique
docker-compose logs -f [nom-du-service]
```

---

## Sauvegarde des Données

Tous les services utilisent des volumes Docker pour la persistance des données :

```bash
# Lister tous les volumes
docker volume ls | grep ticketingonthefly

# Sauvegarder un volume (exemple pour ocs_db_data)
docker run --rm -v ticketingonthefly_ocs_db_data:/data -v ${PWD}/backup:/backup ubuntu tar czf /backup/ocs_db_backup.tar.gz -C /data .
```

**Volumes importants à sauvegarder régulièrement :**
- `portainer_data`
- `ldap_data` et `ldap_config`
- `postgres_data` (Zammad + Wiki.js)
- `zammad_data`
- `ocs_db_data`
- `ocs_data`, `ocs_perlcomdata`, `ocs_ocsreportsdata`
- `wikijs_data`
- `prometheus_data`
- `grafana_data`

---

## Support et Documentation

- **Docker Compose:** https://docs.docker.com/compose/
- **Zammad:** https://docs.zammad.org/
- **OCS Inventory:** https://wiki.ocsinventory-ng.org/
- **OpenLDAP:** https://www.openldap.org/doc/
- **Wiki.js:** https://docs.requarks.io/
- **Portainer:** https://docs.portainer.io/
- **Prometheus:** https://prometheus.io/docs/
- **Grafana:** https://grafana.com/docs/

