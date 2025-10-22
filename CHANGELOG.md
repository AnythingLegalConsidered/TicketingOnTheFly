# Journal de Bord - Système de Ticketing Intégré

Ce fichier documente toutes les actions, commandes et modifications effectuées sur le projet TicketingOnTheFly.

---

## 2025-10-22 - Initialisation du Projet

### Actions Préliminaires

#### Nettoyage et Réorganisation du Dépôt Git
**Objectif :** Remplacer l'ancien contenu du dépôt par le travail local actuel

```bash
# Ajout de tous les changements locaux
git add -A

# Commit du nouveau contenu
git commit -m "Replace entire project with local work"

# Push forcé pour remplacer le contenu distant
git push origin main --force
```

**Résultat :** Le dépôt distant contient maintenant uniquement la structure locale simplifiée.

---

#### Ajout du Dossier de Documentation
**Objectif :** Ajouter le dossier `Doc` contenant toute la documentation du projet

```bash
# Ajout du dossier Doc au staging
git add -A Doc

# Commit
git commit -m "Add Doc directory"

# Push
git push origin main
```

**Fichiers ajoutés :**
- 10 fichiers Markdown de documentation (00 à 09)
- 1 image (Pasted image 20251021213622.png)

---

#### Configuration des Fins de Ligne
**Objectif :** Normaliser les fins de ligne (LF) et éviter les warnings Git sur Windows

**Fichier créé :** `.gitattributes`

```gitattributes
# Normalize line endings
*.md text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.sh text eol=lf
*.py text eol=lf
# Binary files
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
```

```bash
# Ajout et commit
git add .gitattributes
git commit -m "Add .gitattributes to normalize EOL"
git push origin main
```

---

#### Renommage Doc → doc
**Objectif :** Uniformiser la casse (minuscule) pour le dossier de documentation

```bash
# Étape 1 : Renommage temporaire (nécessaire sur systèmes case-insensitive)
git mv Doc Doc_tmp
git commit -m "Temp rename Doc -> Doc_tmp to change case"

# Étape 2 : Renommage final
git mv Doc_tmp doc
git commit -m "Rename Doc to doc (lowercase)"

# Push
git push origin main
```

**Résultat :** Le dossier est maintenant `doc/` dans le dépôt.

---

#### Création de la Branche de Sauvegarde
**Objectif :** Créer un point de restauration avant l'ajout du dossier doc

```bash
# Création de la branche pointant sur le commit précédent
git branch backup-before-doc fc8174b

# Push de la branche
git push origin backup-before-doc
```

**Branches disponibles :**
- `main` : branche principale de développement
- `backup-before-doc` : sauvegarde de l'état initial (commit fc8174b)

---

## 2025-10-22 - Phase 1-3 : Infrastructure de Base

### Correction des Liens Portainer
**Objectif :** Résoudre le problème des liens Portainer pointant vers 0.0.0.0 (invalide)

**Problème identifié :**
- Portainer génère des liens comme `http://0.0.0.0:8081` qui ne fonctionnent pas
- Les ports Docker étaient exposés sur toutes les interfaces (0.0.0.0)

**Solution :** Lier explicitement les ports à `127.0.0.1` (localhost)

**Fichier modifié :** `docker-compose.yml`

```yaml
# Avant :
ports:
  - "8081:8080"

# Après :
ports:
  - "127.0.0.1:8081:8080"
```

**Ports modifiés :**
- Zammad nginx: `127.0.0.1:8081:8080`
- Zammad railsserver: `127.0.0.1:8082:3000`
- phpLDAPadmin: `127.0.0.1:8080:80`
- Portainer: `127.0.0.1:9000:9000` et `127.0.0.1:9443:9443`

```bash
# Arrêt des conteneurs
docker-compose down

# Redémarrage avec nouvelle configuration
docker-compose up -d

# Vérification
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Commit et push
git add docker-compose.yml
git commit -m "Fix Portainer links: bind ports to 127.0.0.1 instead of 0.0.0.0"
git push origin main
```

**Résultat :** 
- Les liens Portainer fonctionnent maintenant correctement
- Amélioration de la sécurité (services accessibles uniquement depuis localhost)

---

## 2025-10-22 - Phase 4 : Inventaire et Gestion du Parc (OCS Inventory)

### Objectif de cette Phase
Déployer OCS Inventory pour l'inventaire automatisé du parc informatique, avec préparation pour l'intégration future avec Zammad.

### Étapes Réalisées

#### 1. Ajout des Variables d'Environnement
**Fichier modifié :** `.env`

```bash
# Ajout des variables pour OCS Inventory
OCS_DB_NAME=ocsdb
OCS_DB_USER=ocs
OCS_DB_PASSWORD=SecureOCSPassword789
MARIADB_ROOT_PASSWORD=VeryStrongMariaDBRootPass321
```

**Note de sécurité :** Ces mots de passe sont des exemples. En production, utilisez des mots de passe forts générés aléatoirement.

---

#### 2. Ajout des Services OCS au docker-compose.yml
**Fichier modifié :** `docker-compose.yml`

**Services ajoutés :**

1. **ocs-db** (Base de données MariaDB)
   - Image: `mariadb:10.11`
   - Port interne: 3306
   - Volume: `ocs_db_data`
   
2. **ocs-server** (Serveur OCS Inventory)
   - Image: `ocsinventory/ocsinventory-docker-image:latest`
   - Port exposé: `127.0.0.1:8083:80`
   - Volumes:
     - `ocs_data` : données des rapports
     - `ocs_perlcomdata` : configuration Perl
     - `ocs_ocsreportsdata` : données des rapports OCS

**Variables d'environnement OCS :**
```yaml
environment:
  - OCS_DBSERVER_READ=ocs-db
  - OCS_DBSERVER_WRITE=ocs-db
  - OCS_DBNAME=${OCS_DB_NAME}
  - OCS_DBUSER=${OCS_DB_USER}
  - OCS_DBPASS=${OCS_DB_PASSWORD}
  - TZ=${TZ}
```

---

#### 3. Résolution des Problèmes de Démarrage

**Problème rencontré :** L'image `ocsinventory/ocsinventory-docker-image:2.12.1` causait des erreurs de configuration Apache/Perl.

**Solution appliquée :**
```bash
# Tentatives avec différentes versions
# Version 2.12.1 -> Erreur de configuration Perl
# Version 2.12.0 -> Image non trouvée
# Version latest -> ✅ Fonctionne correctement
```

**Commandes de dépannage :**
```bash
# Vérifier les logs du conteneur
docker logs ocs-server --tail 30

# Redémarrer le service avec la nouvelle configuration
docker-compose down ocs-server
docker-compose up -d ocs-server

# Vérifier l'état final
docker-compose ps
```

---

#### 4. Vérification du Déploiement

```bash
# Vérifier que les conteneurs sont démarrés
docker-compose ps | Select-String -Pattern "ocs-"
```

**Résultat :**
```
ocs-db      mariadb:10.11                          Up      3306/tcp
ocs-server  ocsinventory/..:latest                 Up      127.0.0.1:8083->80/tcp
```

✅ **Les deux conteneurs OCS sont maintenant opérationnels.**

---

### Configuration Post-Installation OCS Inventory

#### Accès à l'Interface Web
- **URL:** `http://localhost:8083/ocsreports`
- **Port:** 8083 (lié à 127.0.0.1 pour la sécurité)

#### Étapes de Configuration Initiale

1. **Premier accès - Assistant d'installation**
   ```
   Ouvrir : http://localhost:8083/ocsreports
   ```
   
2. **Informations de connexion à la base de données**
   - MySQL Server: `ocs-db`
   - MySQL User: `ocs` (valeur de OCS_DB_USER)
   - MySQL Password: La valeur définie dans OCS_DB_PASSWORD
   - Database Name: `ocsdb` (valeur de OCS_DB_NAME)
   
3. **Lancer l'installation**
   - Cliquer sur "Send"
   - L'installeur crée la structure de la base de données
   
4. **Connexion initiale**
   - Utilisateur par défaut: `admin`
   - Mot de passe par défaut: `admin`

#### ⚠️ ÉTAPES DE SÉCURITÉ CRITIQUES

**1. Supprimer le fichier d'installation**
```bash
# Commande à exécuter IMMÉDIATEMENT après l'installation
docker-compose exec ocs-server rm /usr/share/ocsinventory-reports/ocsreports/install.php
```

**2. Changer le mot de passe administrateur**
- Se connecter avec `admin` / `admin`
- Menu utilisateur (icône en haut à droite) > "User profile"
- Changer immédiatement le mot de passe

**3. Vérifier la suppression**
```bash
# Vérifier que install.php n'existe plus
docker-compose exec ocs-server ls -la /usr/share/ocsinventory-reports/ocsreports/ | grep install
```

---

### Prochaines Étapes

1. **Déploiement des Agents OCS**
   - Installer les agents OCS sur les postes clients Windows/Linux/Mac
   - Configurer les agents pour pointer vers `http://[IP_SERVEUR]:8083/ocsinventory`

2. **Intégration avec Zammad**
   - Configurer le plugin d'intégration OCS dans Zammad
   - Associer les tickets aux machines de l'inventaire

3. **Configuration Avancée**
   - Définir les groupes de machines
   - Configurer les rapports automatiques
   - Mettre en place les règles d'inventaire

---

## 2025-10-22 - Phase 5 : Documentation Interne avec Wiki.js

### Objectif de cette Phase
Déployer Wiki.js comme plateforme de documentation interne pour l'équipe technique, distincte de la base de connaissances Zammad (orientée utilisateurs finaux).

### Distinction Documentation : Wiki.js vs Zammad
- **Base de connaissances Zammad** : Orientée client/utilisateur final, solutions simples aux problèmes courants
- **Wiki.js** : Orientée équipe technique, documentation d'infrastructure, procédures avancées, guides techniques

### Étapes Réalisées

#### 1. Ajout de la Variable d'Environnement
**Fichier modifié :** `.env`

```bash
# Ajout de la variable pour la base de données Wiki.js
WIKIJS_DB_NAME=wikijs
```

**Note :** Wiki.js partage le serveur PostgreSQL de Zammad mais utilise sa propre base de données pour une séparation logique des données.

---

#### 2. Ajout du Service Wiki.js au docker-compose.yml
**Fichier modifié :** `docker-compose.yml`

**Service ajouté :**

```yaml
wikijs:
  image: requarks/wiki:2
  container_name: wikijs
  restart: unless-stopped
  depends_on:
    - zammad-db
  environment:
    - DB_TYPE=postgres
    - DB_HOST=zammad-db
    - DB_PORT=5432
    - DB_USER=${POSTGRES_USER}
    - DB_PASS=${POSTGRES_PASSWORD}
    - DB_NAME=${WIKIJS_DB_NAME}
    - TZ=${TZ}
  ports:
    - "127.0.0.1:8084:3000"
  volumes:
    - wikijs_data:/wiki/data
  networks:
    - ticketing_network
```

**Volume ajouté :** `wikijs_data`

**⚠️ Changement de Port :** 
- Document original: Port 8083
- **Port utilisé: 8084** (8083 déjà utilisé par OCS Inventory)

---

#### 3. Création Manuelle de la Base de Données

**Problème rencontré :** Wiki.js ne crée pas automatiquement sa base de données dans PostgreSQL.

**Solution :**
```bash
# Créer la base de données wikijs dans PostgreSQL
docker-compose exec zammad-db psql -U admin -d postgres -c "CREATE DATABASE wikijs;"

# Redémarrer Wiki.js pour qu'il se connecte
docker-compose restart wikijs
```

**Résultat :** La connexion à la base de données a réussi et le serveur HTTP démarre correctement.

---

#### 4. Démarrage et Vérification

```bash
# Lancer Wiki.js
docker-compose up -d wikijs

# Vérifier l'état
docker-compose ps | Select-String -Pattern "wikijs"

# Vérifier les logs
docker logs wikijs --tail 30
```

**Logs de succès :**
```
2025-10-22T11:36:25.767Z [MASTER] info: Database Connection Successful [ OK ]
2025-10-22T11:36:25.860Z [MASTER] info: HTTP Server on port: [ 3000 ]
2025-10-22T11:36:25.862Z [MASTER] info: HTTP Server: [ RUNNING ]
2025-10-22T11:36:25.863Z [MASTER] info: Browse to http://YOUR-SERVER-IP:3000/ to complete setup!
```

✅ **Wiki.js est maintenant opérationnel et prêt pour la configuration initiale.**

---

### Configuration Post-Installation Wiki.js

#### Accès à l'Interface Web
- **URL:** `http://localhost:8084`
- **Port:** 8084 (lié à 127.0.0.1 pour la sécurité)

#### Étapes de Configuration Initiale

1. **Premier accès - Assistant d'installation**
   ```
   Ouvrir : http://localhost:8084
   ```

2. **Création du compte administrateur**
   - Adresse email (sera l'identifiant de connexion)
   - Mot de passe fort (minimum recommandé: 12 caractères)

3. **Configuration de l'URL du site**
   - URL de développement: `http://localhost:8084`
   - URL de production (avec Traefik): `https://wiki.mondomaine.com`

4. **Finaliser l'installation**
   - Cliquer sur "Install"
   - Se connecter avec les identifiants créés

---

### Configuration de l'Authentification LDAP

**Objectif :** Permettre aux utilisateurs de l'annuaire OpenLDAP de se connecter à Wiki.js

#### Procédure dans l'Interface Wiki.js

1. **Accéder à l'administration**
   - Menu en haut à droite > "Administration"

2. **Configurer LDAP**
   - Menu gauche > "Authentification"
   - Cliquer sur "LDAP / Active Directory"
   - Activer la stratégie (slider)

3. **Paramètres de connexion LDAP**
   ```
   Host: openldap
   Port: 389
   Bind DN: cn=admin,dc=localhost
   Password: [Valeur de LDAP_ADMIN_PASSWORD du .env]
   Base DN: ou=users,dc=localhost
   User Login Field: uid
   ```

4. **Profile Mapping (Correspondance des champs)**
   ```
   Username: uid
   Display Name: cn
   Email: mail
   ```

5. **Sauvegarder**
   - Cliquer sur "Appliquer" en haut à droite

6. **Tester**
   - Se déconnecter
   - Se reconnecter avec un utilisateur LDAP

---

### Récapitulatif des Ports (Mise à jour)

| Service          | Port Local      | URL                            |
|------------------|-----------------|--------------------------------|
| phpLDAPadmin     | 8080            | http://localhost:8080          |
| Zammad           | 8081            | http://localhost:8081          |
| Zammad Rails     | 8082            | http://localhost:8082          |
| OCS Inventory    | 8083            | http://localhost:8083/ocsreports |
| **Wiki.js**      | **8084**        | **http://localhost:8084**      |
| Portainer (HTTP) | 9000            | http://localhost:9000          |
| Portainer (HTTPS)| 9443            | https://localhost:9443         |

---

### Prochaines Étapes

1. **Configuration Post-Installation**
   - Créer le compte administrateur
   - Configurer l'authentification LDAP
   - Créer la structure initiale du wiki

2. **Phase 6 : Supervision**
   - Déployer Prometheus pour la collecte de métriques
   - Déployer Grafana pour la visualisation
   - Configurer les alertes

3. **Phase 7 : Reverse Proxy**
   - Configurer Traefik pour l'accès unifié
   - Mettre en place les certificats SSL/TLS automatiques
   - Configurer les noms de domaine

---

## 2025-10-22 - Phase 6 : Supervision et Monitoring avec Prometheus & Grafana

### Objectif de cette Phase
Déployer une pile de supervision complète pour surveiller la santé et les performances de tous les conteneurs Docker en temps réel. Passer d'un mode **réactif** à un mode **proactif**.

### Théorie : Pourquoi la Supervision est Critique

#### Surveillance Proactive vs Réactive
- **Mode réactif** (AVANT) : "Un utilisateur appelle car le site est lent"
- **Mode proactif** (APRÈS) : "Je vois que le CPU du serveur de BDD augmente dangereusement, j'investigue avant impact"

#### Indicateurs Clés Surveillés
- Santé des conteneurs (démarrés, arrêtés, redémarrages en boucle)
- Consommation ressources (CPU, RAM, I/O disque, réseau)
- Performances applicatives (temps de réponse, nombre de requêtes)

#### Architecture de Supervision

**Le Duo Prometheus & Grafana :**
1. **Prometheus** : Base de données optimisée pour séries temporelles
   - Fonctionne en "scraping" : interroge les cibles toutes les 15s sur `/metrics`
   - Stocke les métriques avec timestamp

2. **Grafana** : Interface de visualisation
   - Ne collecte pas de données
   - Se connecte à Prometheus
   - Crée des tableaux de bord interactifs

3. **cAdvisor** : Exportateur de métriques Docker
   - Expose automatiquement les métriques de TOUS les conteneurs
   - Prometheus scrape cAdvisor pour avoir vue complète

---

### Étapes Réalisées

#### 1. Création du Fichier de Configuration Prometheus

**Fichier créé :** `config/prometheus/prometheus.yml`

```yaml
# Fichier de configuration global de Prometheus
global:
  scrape_interval: 15s # Interroge les cibles toutes les 15 secondes
  evaluation_interval: 15s # Évalue les règles toutes les 15 secondes

# Liste des jobs de scraping
scrape_configs:
  # Job pour surveiller Prometheus lui-même
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Job pour surveiller les métriques des conteneurs via cAdvisor
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

**Explication :**
- **Job 1 (prometheus)** : Prometheus se surveille lui-même
- **Job 2 (cadvisor)** : Prometheus récupère les métriques de tous les conteneurs via cAdvisor

---

#### 2. Ajout des Services au docker-compose.yml

**Fichier modifié :** `docker-compose.yml`

**Services ajoutés :**

1. **Prometheus** (Collecteur de métriques)
```yaml
prometheus:
  image: prom/prometheus:v2.47.1
  container_name: prometheus
  restart: unless-stopped
  ports:
    - "127.0.0.1:9090:9090"
  volumes:
    - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
  networks:
    - ticketing_network
```

2. **Grafana** (Visualisation)
```yaml
grafana:
  image: grafana/grafana-oss:10.1.5
  container_name: grafana
  restart: unless-stopped
  environment:
    - TZ=${TZ}
  ports:
    - "127.0.0.1:8085:3000"
  volumes:
    - grafana_data:/var/lib/grafana
  networks:
    - ticketing_network
```

3. **cAdvisor** (Exportateur métriques Docker)
```yaml
cadvisor:
  image: gcr.io/cadvisor/cadvisor:v0.47.2
  container_name: cadvisor
  restart: unless-stopped
  privileged: true
  devices:
    - /dev/kmsg
  volumes:
    - /:/rootfs:ro
    - /var/run:/var/run:ro
    - /sys:/sys:ro
    - /var/lib/docker/:/var/lib/docker:ro
    - /dev/disk/:/dev/disk:ro
  networks:
    - ticketing_network
```

**Volumes ajoutés :**
- `prometheus_data` : Stockage des métriques
- `grafana_data` : Données Grafana

**⚠️ Gestion des Conflits de Ports :**
- Document original suggère port 8084 pour Grafana
- **Port utilisé: 8085** (8084 déjà pris par Wiki.js, 3000 interne de Grafana)

---

#### 3. Démarrage et Vérification

```bash
# Lancer tous les services
docker-compose up -d

# Vérifier l'état des services de supervision
docker-compose ps | Select-String -Pattern "prometheus|grafana|cadvisor"

# Vérifier les logs Prometheus
docker logs prometheus --tail 20
```

**Résultat :**
```
cadvisor     Up 34 seconds (healthy)   8080/tcp
grafana      Up 34 seconds             127.0.0.1:8085->3000/tcp
prometheus   Up 34 seconds             127.0.0.1:9090->9090/tcp
```

✅ **Tous les services de supervision sont opérationnels.**

---

### Configuration Post-Installation

#### Prometheus - Vérification des Targets

1. **Accéder à Prometheus**
   ```
   URL: http://localhost:9090
   ```

2. **Vérifier les targets (CRITIQUE)**
   - Menu: **Status > Targets**
   - Vérifier que les 2 jobs sont présents :
     - `prometheus` : État **UP** (vert)
     - `cadvisor` : État **UP** (vert)

3. **Explorer les métriques**
   - Barre de recherche : taper `container_`
   - Auto-complétion montre toutes les métriques cAdvisor disponibles
   - Exemples :
     - `container_cpu_usage_seconds_total`
     - `container_memory_usage_bytes`
     - `container_network_receive_bytes_total`

---

#### Grafana - Configuration Initiale

1. **Accéder à Grafana**
   ```
   URL: http://localhost:8085
   ```

2. **Première connexion**
   - Utilisateur par défaut: `admin`
   - Mot de passe par défaut: `admin`
   - **⚠️ Grafana force le changement de mot de passe immédiatement**

3. **Ajouter Prometheus comme Source de Données**
   - Icône engrenage (menu gauche) > "Data Sources"
   - Cliquer "Add data source"
   - Sélectionner "Prometheus"
   - **Prometheus server URL:** `http://prometheus:9090`
   - Cliquer "Save & test"
   - Message de succès : "Data source is working" (vert)

4. **Importer un Tableau de Bord Communautaire**
   - Icône 4 carrés (menu gauche) > "Dashboards"
   - Cliquer "Import"
   - **Import via grafana.com:** Entrer l'ID `13981`
   - Cliquer "Load"
   - Sélectionner la source de données Prometheus créée
   - Cliquer "Import"

**Dashboard 13981 :** Excellent tableau de bord communautaire pour cAdvisor
- Visualisation CPU, RAM, Réseau, I/O disque
- Vue par conteneur
- Temps réel

---

### Récapitulatif des Ports (Mise à jour)

| Service          | Port Local      | URL                            |
|------------------|-----------------|--------------------------------|
| phpLDAPadmin     | 8080            | http://localhost:8080          |
| Zammad           | 8081            | http://localhost:8081          |
| Zammad Rails     | 8082            | http://localhost:8082          |
| OCS Inventory    | 8083            | http://localhost:8083/ocsreports |
| Wiki.js          | 8084            | http://localhost:8084          |
| **Grafana**      | **8085**        | **http://localhost:8085**      |
| **Prometheus**   | **9090**        | **http://localhost:9090**      |
| Portainer (HTTP) | 9000            | http://localhost:9000          |
| Portainer (HTTPS)| 9443            | https://localhost:9443         |

**Note:** cAdvisor n'expose pas de port sur l'hôte (port 8080 interne uniquement, accessible par Prometheus)

---

### Métriques Disponibles

#### Exemples de Métriques cAdvisor

**Conteneurs :**
- `container_last_seen` : Dernier scrape réussi
- `container_start_time_seconds` : Timestamp de démarrage

**CPU :**
- `container_cpu_usage_seconds_total` : Utilisation CPU cumulée
- `container_cpu_system_seconds_total` : Temps CPU système

**Mémoire :**
- `container_memory_usage_bytes` : Utilisation mémoire actuelle
- `container_memory_max_usage_bytes` : Pic d'utilisation
- `container_memory_working_set_bytes` : Working set (mémoire active)

**Réseau :**
- `container_network_receive_bytes_total` : Octets reçus
- `container_network_transmit_bytes_total` : Octets envoyés
- `container_network_receive_errors_total` : Erreurs de réception

**Disque :**
- `container_fs_usage_bytes` : Utilisation disque
- `container_fs_limit_bytes` : Limite disque

---

## Phase 7 : Déploiement de Traefik - Reverse Proxy et HTTPS Automatique

**Date :** 2025-10-22
**Objectif :** Déployer Traefik comme reverse proxy pour unifier l'accès à tous les services sous des sous-domaines propres avec HTTPS automatique via Let's Encrypt

### Théorie et Concepts

#### 1. Le Problème : Chaos des Ports
Avant Traefik, l'accès aux services nécessitait de mémoriser de nombreux ports :
- Zammad : `http://localhost:8081`
- OCS Inventory : `http://localhost:8083`
- Wiki.js : `http://localhost:8084`
- Grafana : `http://localhost:8085`
- Prometheus : `http://localhost:9090`
- Portainer : `http://localhost:9443`
- phpLDAPadmin : `http://localhost:8080`

**Inconvénients :**
- Non professionnel et difficile à mémoriser
- Tout en HTTP non sécurisé
- Multiples ports exposés = surface d'attaque augmentée

#### 2. Solution : Reverse Proxy Traefik
**Traefik** agit comme un "chef d'orchestre" du trafic réseau :
- **Point d'entrée unique** : Seuls les ports 80 (HTTP) et 443 (HTTPS) sont exposés
- **Routage intelligent** : Traefik lit le nom de domaine demandé et dirige vers le bon service
- **Auto-découverte** : Détection automatique des conteneurs Docker via labels
- **HTTPS automatique** : Gestion complète des certificats Let's Encrypt

**Flux de requête :**
```
Utilisateur → https://zammad.domain.com
    ↓
Traefik (port 443) → Lit le domaine "zammad.domain.com"
    ↓
Traefik consulte ses labels Docker
    ↓
Traefik route vers conteneur zammad-nginx:8080
    ↓
Réponse retourne via Traefik → Utilisateur
```

#### 3. Avantages de Traefik

**Auto-découverte Docker :**
- Traefik écoute le socket Docker (`/var/run/docker.sock`)
- Détecte automatiquement les nouveaux conteneurs
- Lit les labels Docker pour créer les routes
- Aucune reconfiguration manuelle nécessaire

**Let's Encrypt Intégré :**
- Demande automatiquement un certificat HTTPS
- Prouve le contrôle du domaine (HTTP Challenge)
- Installe et renouvelle automatiquement les certificats
- Stockage sécurisé dans `acme.json`

**Sécurité :**
- Redirection automatique HTTP → HTTPS
- Isolation des services (pas de ports exposés directement)
- Authentification basique pour le dashboard Traefik
- Filtrage par `exposedByDefault: false`

---

### Étape 1 : Ajout des Variables d'Environnement

**Fichier `.env` :**
```bash
# Variables ajoutées pour Traefik
ACME_EMAIL=admin@${DOMAIN}
```

**Explication :**
- `ACME_EMAIL` : Email pour les notifications Let's Encrypt (expiration de certificats)
- Pour un vrai domaine, remplacer par une vraie adresse email valide

---

### Étape 2 : Création de la Configuration Traefik

#### Fichier `config/traefik/traefik.yml`

**Création du fichier :**
```bash
# Créer le dossier config/traefik (s'il n'existe pas)
mkdir -p config/traefik

# Créer le fichier de configuration
cat > config/traefik/traefik.yml <<'EOF'
# Configuration statique de Traefik
global:
  checkNewVersion: true
  sendAnonymousUsage: false

# Points d'entrée des requêtes (HTTP et HTTPS)
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

# Configuration de l'API et du Dashboard Traefik
api:
  dashboard: true
  insecure: false

# Comment Traefik découvre les autres services (via Docker)
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false # Important pour la sécurité !

# Configuration du résolveur de certificats Let's Encrypt
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: acme.json
      httpChallenge:
        entryPoint: web
EOF
```

**Explication des sections :**

**EntryPoints :**
- `web` (port 80) : Redirige automatiquement vers HTTPS
- `websecure` (port 443) : Point d'entrée HTTPS principal

**API Dashboard :**
- `dashboard: true` : Active le dashboard de Traefik
- `insecure: false` : Le dashboard nécessite une route et une authentification

**Providers Docker :**
- `endpoint` : Connexion au socket Docker pour détecter les conteneurs
- `exposedByDefault: false` : Seuls les services avec `traefik.enable=true` sont exposés

**CertificatesResolvers :**
- `letsencrypt` : Nom du résolveur de certificats
- `httpChallenge` : Méthode de validation (Let's Encrypt contacte le port 80 pour vérifier)
- `storage: acme.json` : Fichier de stockage des certificats

#### Fichier `acme.json`

**Création et sécurisation :**
```bash
# Créer le fichier vide
touch config/traefik/acme.json

# Sécuriser avec permissions 600 (lecture/écriture propriétaire uniquement)
chmod 600 config/traefik/acme.json
```

**Note Windows/WSL :**
```powershell
# Sur PowerShell, utiliser wsl pour chmod
wsl chmod 600 /home/ianis/TicketingOntheFly/config/traefik/acme.json
```

**Importance :** Les permissions 600 sont requises par Traefik pour raisons de sécurité (fichier contient les clés privées des certificats).

---

### Étape 3 : Modification du docker-compose.yml

#### Ajout du Service Traefik

**Commande :**
```yaml
# Ajout en début de fichier après "services:"
traefik:
  image: traefik:v2.10
  container_name: traefik
  restart: unless-stopped
  ports:
    # Seuls ports exposés publiquement
    - "80:80"
    - "443:443"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - ./config/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
    - ./config/traefik/acme.json:/acme.json
  networks:
    - ticketing_network
  labels:
    # Dashboard Traefik
    - "traefik.enable=true"
    - "traefik.http.routers.traefik.rule=Host(`traefik.${DOMAIN}`)"
    - "traefik.http.routers.traefik.entrypoints=websecure"
    - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
    - "traefik.http.routers.traefik.service=api@internal"
    # Authentification basique
    - "traefik.http.routers.traefik.middlewares=auth"
    - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$LM59Ds56$$5jf2lGXS1Q3tjdxGJw31i."
```

**Génération du mot de passe hashé :**
```bash
# Utiliser htpasswd via Docker
docker run --rm httpd:2.4-alpine htpasswd -nb admin TicketingAdmin2025

# Résultat : admin:$apr1$LM59Ds56$5jf2lGXS1Q3tjdxGJw31i.
# IMPORTANT : Dans docker-compose.yml, doubler les $ : $$
```

**Explication des volumes :**
- `/var/run/docker.sock` : Accès Docker en lecture seule (`:ro`)
- `traefik.yml` : Configuration statique en lecture seule
- `acme.json` : Fichier de certificats en lecture/écriture

#### Suppression des Ports et Ajout des Labels

**Pour chaque service à exposer, effectuer 2 modifications :**

**1. Supprimer la section `ports:`**
```yaml
# AVANT
ports:
  - "127.0.0.1:8081:8080"

# APRÈS : Section ports complètement supprimée
```

**2. Ajouter les labels Traefik**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.SERVICE.rule=Host(`SERVICE.${DOMAIN}`)"
  - "traefik.http.routers.SERVICE.entrypoints=websecure"
  - "traefik.http.routers.SERVICE.tls.certresolver=letsencrypt"
  - "traefik.http.services.SERVICE.loadbalancer.server.port=PORT_INTERNE"
```

**Services modifiés :**

| Service | Sous-domaine | Port interne | Labels ajoutés |
|---------|--------------|--------------|----------------|
| zammad-nginx | `zammad.${DOMAIN}` | 8080 | ✅ |
| ocs-server | `ocs.${DOMAIN}` | 80 | ✅ |
| wikijs | `wiki.${DOMAIN}` | 3000 | ✅ |
| phpldapadmin | `ldap.${DOMAIN}` | 80 | ✅ |
| prometheus | `prometheus.${DOMAIN}` | 9090 | ✅ |
| grafana | `grafana.${DOMAIN}` | 3000 | ✅ |
| portainer | `portainer.${DOMAIN}` | 9000 | ✅ |

**Services NON exposés (pas de labels) :**
- `zammad-db`, `ocs-db` : Bases de données (sécurité)
- `zammad-elasticsearch`, `zammad-redis` : Services internes
- `openldap` : Annuaire (accès via phpLDAPadmin)
- `cadvisor` : Métriques (accès via Prometheus)

---

### Étape 4 : Déploiement de Traefik

**Commande de déploiement :**
```bash
# Recréer tous les services avec la nouvelle configuration
docker-compose up -d
```

**Résultat observé :**
```
[+] Running 5/5
 ✔ traefik Pulled                                   9.1s
[+] Running 18/18
 ✔ Container traefik               Started          2.3s
 ✔ Container portainer             Recreated        1.0s
 ✔ Container prometheus            Recreated        1.2s
 ✔ Container grafana               Started          2.1s
 ✔ Container wikijs                Started          2.1s
 ✔ Container ocs-server            Started          2.2s
 ✔ Container phpldapadmin          Started          2.0s
 ✔ Container zammad-nginx          Started          1.4s
 ... (tous les autres services)
```

**Vérification de l'état :**
```bash
docker-compose ps | Select-String -Pattern "traefik|Up"
```

**Résultat :**
```
traefik    traefik:v2.10    Up 10 seconds    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
grafana    grafana/...      Up 10 seconds    3000/tcp
prometheus prom/...         Up 10 seconds    9090/tcp
wikijs     requarks/...     Up 10 seconds    3000/tcp
...
```

**Observations :**
- Seul Traefik expose les ports 80 et 443
- Tous les autres services n'ont plus de ports exposés sur l'hôte
- Les ports internes (3000, 8080, etc.) restent accessibles via Docker network

---

### Étape 5 : Vérification des Logs Traefik

**Commande :**
```bash
docker logs traefik --tail 30
```

**Logs observés :**
```
time="2025-10-22T11:55:42Z" level=info msg="Configuration loaded from file: /etc/traefik/traefik.yml"
time="2025-10-22T11:55:45Z" level=error msg="Unable to obtain ACME certificate for domains \"portainer.localhost\": 
  cannot get ACME client acme: error: 400 :: urn:ietf:params:acme:error:invalidContact :: 
  Error validating contact(s) :: unable to parse email address" 
  providerName=letsencrypt.acme routerName=portainer@docker
...
```

**Analyse :**
- ✅ Configuration chargée avec succès
- ✅ Traefik détecte tous les services (portainer, traefik, prometheus, wiki, grafana, ocs, ldap, zammad)
- ⚠️ Erreurs ACME attendues car :
  - `DOMAIN=localhost` → email devient `admin@localhost` (invalide)
  - Let's Encrypt ne peut pas émettre de certificats pour "localhost"

**Note :** Ces erreurs disparaîtront en production avec un vrai domaine et un vrai email.

---

### Étape 6 : Accès aux Services

#### En Développement Local (DOMAIN=localhost)

**Problème :** Les sous-domaines `*.localhost` ne fonctionnent pas par défaut dans les navigateurs.

**Solutions temporaires :**

**Option 1 : Modifier le fichier hosts**
```bash
# Sur Linux/Mac : /etc/hosts
# Sur Windows : C:\Windows\System32\drivers\etc\hosts

127.0.0.1 zammad.localhost
127.0.0.1 grafana.localhost
127.0.0.1 wiki.localhost
127.0.0.1 ocs.localhost
127.0.0.1 portainer.localhost
127.0.0.1 prometheus.localhost
127.0.0.1 ldap.localhost
127.0.0.1 traefik.localhost
```

**Option 2 : Utiliser un service DNS local comme dnsmasq**

**Option 3 : Tester avec curl**
```bash
curl -H "Host: zammad.localhost" http://localhost
```

**URLs d'accès (après configuration hosts) :**
- Dashboard Traefik : `http://traefik.localhost` (admin/TicketingAdmin2025)
- Zammad : `http://zammad.localhost`
- Grafana : `http://grafana.localhost`
- Wiki.js : `http://wiki.localhost`
- OCS Inventory : `http://ocs.localhost`
- Portainer : `http://portainer.localhost`
- Prometheus : `http://prometheus.localhost`
- phpLDAPadmin : `http://ldap.localhost`

**Note :** En local, tout est en HTTP car Let's Encrypt n'émet pas de certificats pour localhost.

#### En Production (avec un vrai domaine)

**Prérequis DNS :** Créer des enregistrements DNS de type A pointant vers l'IP publique du serveur :
```
zammad.mondomaine.com      A    <IP_PUBLIQUE_SERVEUR>
grafana.mondomaine.com     A    <IP_PUBLIQUE_SERVEUR>
wiki.mondomaine.com        A    <IP_PUBLIQUE_SERVEUR>
ocs.mondomaine.com         A    <IP_PUBLIQUE_SERVEUR>
portainer.mondomaine.com   A    <IP_PUBLIQUE_SERVEUR>
prometheus.mondomaine.com  A    <IP_PUBLIQUE_SERVEUR>
ldap.mondomaine.com        A    <IP_PUBLIQUE_SERVEUR>
traefik.mondomaine.com     A    <IP_PUBLIQUE_SERVEUR>
```

**Configuration .env pour production :**
```bash
DOMAIN=mondomaine.com
ACME_EMAIL=admin@mondomaine.com
```

**Processus automatique Let's Encrypt :**
1. Utilisateur accède à `https://zammad.mondomaine.com`
2. Traefik détecte qu'aucun certificat n'existe
3. Traefik demande un certificat à Let's Encrypt
4. Let's Encrypt contacte `http://zammad.mondomaine.com/.well-known/acme-challenge/` pour vérifier
5. Traefik répond au challenge
6. Let's Encrypt émet le certificat
7. Traefik installe le certificat et le stocke dans `acme.json`
8. Renouvellement automatique 30 jours avant expiration

**URLs d'accès (production) :**
- `https://zammad.mondomaine.com` ✅ Cadenas vert
- `https://grafana.mondomaine.com` ✅ Cadenas vert
- Toutes les requêtes HTTP sont redirigées vers HTTPS automatiquement

---

### Configuration des Labels Traefik - Explication Détaillée

**Anatomie d'un label Traefik :**
```yaml
labels:
  # 1. Activer Traefik pour ce conteneur
  - "traefik.enable=true"
  
  # 2. Définir la règle de routage (par nom de domaine)
  - "traefik.http.routers.SERVICE_NAME.rule=Host(`sous-domaine.${DOMAIN}`)"
  
  # 3. Spécifier le point d'entrée (websecure = HTTPS port 443)
  - "traefik.http.routers.SERVICE_NAME.entrypoints=websecure"
  
  # 4. Configurer le résolveur de certificats
  - "traefik.http.routers.SERVICE_NAME.tls.certresolver=letsencrypt"
  
  # 5. Indiquer le port interne du conteneur
  - "traefik.http.services.SERVICE_NAME.loadbalancer.server.port=PORT_INTERNE"
```

**Exemple concret - Grafana :**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.grafana.rule=Host(`grafana.${DOMAIN}`)"
  - "traefik.http.routers.grafana.entrypoints=websecure"
  - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
  - "traefik.http.services.grafana.loadbalancer.server.port=3000"
```

**Explication :**
- `traefik.enable=true` : Traefik doit gérer ce conteneur
- `Host(`grafana.${DOMAIN}`)` : Répondre aux requêtes pour grafana.localhost (ou grafana.domain.com)
- `entrypoints=websecure` : Utiliser le port 443 (HTTPS)
- `certresolver=letsencrypt` : Obtenir un certificat via Let's Encrypt
- `server.port=3000` : Grafana écoute sur le port 3000 à l'intérieur du conteneur

---

### Architecture Finale

**Schéma de l'infrastructure :**
```
Internet
   ↓
Ports 80/443 (Traefik)
   ↓
Docker Network: ticketing_network
   ├─ zammad-nginx:8080       → zammad.domain.com
   ├─ grafana:3000            → grafana.domain.com
   ├─ prometheus:9090         → prometheus.domain.com
   ├─ wikijs:3000             → wiki.domain.com
   ├─ ocs-server:80           → ocs.domain.com
   ├─ portainer:9000          → portainer.domain.com
   ├─ phpldapadmin:80         → ldap.domain.com
   ├─ cadvisor:8080           (interne, via prometheus)
   ├─ openldap:389            (interne, via phpldapadmin)
   └─ databases               (internes, inaccessibles depuis l'extérieur)
```

**Sécurité :**
- ✅ Un seul point d'entrée (ports 80/443)
- ✅ Redirection automatique HTTP → HTTPS
- ✅ Certificats SSL valides
- ✅ Services internes (DB, LDAP, cAdvisor) non exposés
- ✅ Dashboard Traefik protégé par authentification basique
- ✅ Filtrage par `exposedByDefault: false`

---

### Tableau Récapitulatif des URLs

| Service | Sous-domaine | URL Locale | URL Production |
|---------|--------------|------------|----------------|
| Dashboard Traefik | traefik | http://traefik.localhost | https://traefik.domain.com |
| Zammad | zammad | http://zammad.localhost | https://zammad.domain.com |
| Grafana | grafana | http://grafana.localhost | https://grafana.domain.com |
| Prometheus | prometheus | http://prometheus.localhost | https://prometheus.domain.com |
| Wiki.js | wiki | http://wiki.localhost | https://wiki.domain.com |
| OCS Inventory | ocs | http://ocs.localhost | https://ocs.domain.com |
| Portainer | portainer | http://portainer.localhost | https://portainer.domain.com |
| phpLDAPadmin | ldap | http://ldap.localhost | https://ldap.domain.com |

**Authentification Dashboard Traefik :**
- Utilisateur : `admin`
- Mot de passe : `TicketingAdmin2025`

---

### Prochaines Étapes

1. **Configuration DNS (Production uniquement)**
   - Acheter un nom de domaine
   - Configurer les enregistrements A dans le panneau DNS
   - Mettre à jour `.env` avec le vrai domaine et email

2. **Sécurisation Avancée**
   - Ajouter des middlewares pour IP whitelisting
   - Configurer des headers de sécurité (HSTS, CSP)
   - Limiter l'accès à phpLDAPadmin et Portainer par IP

3. **Monitoring Traefik**
   - Ajouter des métriques Traefik dans Prometheus
   - Créer un dashboard Grafana pour Traefik
   - Configurer des alertes sur les erreurs 502/503

4. **Phase 8 : Consolidation**
   - Sauvegardes automatiques
   - Tests de récupération
   - Documentation finale


---

