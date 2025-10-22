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

