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

## Récapitulatif des Ports

| Service          | Port Local      | URL                            |
|------------------|-----------------|--------------------------------|
| phpLDAPadmin     | 8080            | http://localhost:8080          |
| Zammad           | 8081            | http://localhost:8081          |
| Zammad Rails     | 8082            | http://localhost:8082          |
| OCS Inventory    | 8083            | http://localhost:8083/ocsreports |
| Portainer (HTTP) | 9000            | http://localhost:9000          |
| Portainer (HTTPS)| 9443            | https://localhost:9443         |

---

## Ordre de Configuration Recommandé

1. ✅ **Portainer** - Pour surveiller l'état de tous les services
2. ✅ **phpLDAPadmin** - Créer la structure LDAP et les premiers utilisateurs
3. ✅ **OCS Inventory** - Configuration initiale et sécurisation
4. ✅ **Zammad** - Configuration et intégration LDAP
5. 📝 **Wiki.js** - À configurer dans la Phase 5

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
- `postgres_data` (Zammad)
- `zammad_data`
- `ocs_db_data`
- `ocs_data`, `ocs_perlcomdata`, `ocs_ocsreportsdata`

---

## Support et Documentation

- **Docker Compose:** https://docs.docker.com/compose/
- **Zammad:** https://docs.zammad.org/
- **OCS Inventory:** https://wiki.ocsinventory-ng.org/
- **OpenLDAP:** https://www.openldap.org/doc/
- **Portainer:** https://docs.portainer.io/

