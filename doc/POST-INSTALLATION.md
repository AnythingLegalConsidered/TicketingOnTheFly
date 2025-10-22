# Guide de Configuration Post-Installation

Ce document décrit les étapes de configuration nécessaires après le premier démarrage de l'infrastructure TicketingOnTheFly.

---

## OCS Inventory - Configuration Initiale

### Accès à l'Interface
**URL:** `http://localhost:8083/ocsreports`

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

## Récapitulatif des Ports

| Service          | Port Local      | URL                            |
|------------------|-----------------|--------------------------------|
| phpLDAPadmin     | 8080            | http://localhost:8080          |
| Zammad           | 8081            | http://localhost:8081          |
| Zammad Rails     | 8082            | http://localhost:8082          |
| OCS Inventory    | 8083            | http://localhost:8083/ocsreports |
| Wiki.js          | 8084            | http://localhost:8084          |
| Grafana          | 8085            | http://localhost:8085          |
| Portainer (HTTP) | 9000            | http://localhost:9000          |
| Prometheus       | 9090            | http://localhost:9090          |
| Portainer (HTTPS)| 9443            | https://localhost:9443         |

---

## Ordre de Configuration Recommandé

1. ✅ **Portainer** - Pour surveiller l'état de tous les services
2. ✅ **phpLDAPadmin** - Créer la structure LDAP et les premiers utilisateurs
3. ✅ **OCS Inventory** - Configuration initiale et sécurisation
4. ✅ **Zammad** - Configuration et intégration LDAP
5. ✅ **Wiki.js** - Configuration et intégration LDAP
6. ✅ **Prometheus & Grafana** - Ajouter la datasource Prometheus et importer les dashboards

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

