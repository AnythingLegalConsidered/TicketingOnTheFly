Parfaitement. Nous allons maintenant construire la bibliothèque de connaissance de votre équipe technique. Alors que la base de connaissances de Zammad s'adresse aux utilisateurs finaux, Wiki.js sera la source unique de vérité pour vos procédures internes, vos guides et votre documentation d'infrastructure.

### **Partie 5 : Documentation Interne et Procédures avec Wiki.js**

**Objectif :** Déployer une plateforme de wiki moderne, la connecter à l'annuaire OpenLDAP pour une gestion unifiée des accès, et établir un espace dédié à la documentation technique de l'équipe.

---

### **Théorie Détaillée**

#### 1. Le Double Système de Documentation : Pourquoi ?
Il est crucial de bien distinguer les deux outils de documentation de votre projet :
*   **Base de connaissances Zammad :** Elle est **orientée client/utilisateur final**. Son but est de réduire le nombre de tickets en offrant des solutions simples et directes aux problèmes courants (ex: "Comment configurer ma signature d'email ?", "La procédure pour demander un nouvel équipement"). Le langage y est simple et accessible.
*   **Wiki.js :** Il est **orienté équipe technique**. Son but est de capitaliser le savoir-faire de l'équipe, de standardiser les procédures et de faciliter l'intégration de nouveaux membres. Le contenu y est technique (ex: "Procédure de restauration de la base de données Zammad", "Schéma réseau détaillé du datacenter", "Guide de dépannage avancé du serveur LDAP").

Cette séparation garantit que chaque public trouve l'information qui lui est pertinente, sans être "pollué" par des détails inutiles.

#### 2. Wiki.js : Une Plateforme Moderne
Nous choisissons Wiki.js pour plusieurs raisons :
*   **Éditeur Markdown :** Permet d'écrire de la documentation de manière simple, rapide et structurée.
*   **Gestion des droits fine :** On peut définir très précisément qui a le droit de lire ou de modifier telle ou telle page ou section du wiki.
*   **Intégration :** Il s'intègre nativement avec de nombreux systèmes d'authentification, dont LDAP, ce qui est parfait pour notre architecture.
*   **Moteur de recherche puissant :** Retrouver une procédure au milieu de centaines de pages est un jeu d'enfant.

#### 3. Réutilisation de l'Infrastructure
Pour optimiser les ressources, nous n'allons pas déployer une nouvelle base de données. Wiki.js est compatible avec PostgreSQL. Nous allons donc le configurer pour qu'il utilise le serveur PostgreSQL déjà déployé pour Zammad, mais en créant sa propre base de données à l'intérieur de ce serveur, assurant ainsi une séparation logique et propre des données.

---

### **Mise en Pratique**

#### Étape 1 : Mise à jour du Fichier d'Environnement (`.env`)

Nous devons simplement définir le nom de la base de données que Wiki.js utilisera. Ajoutez cette ligne à votre fichier `.env` :

```dotenv
# ... (variables existantes) ...

# --- Configuration Wiki.js ---
WIKIJS_DB_NAME=wikijs
```
Nous réutiliserons les identifiants `POSTGRES_USER` et `POSTGRES_PASSWORD` existants, car cet utilisateur a les droits suffisants sur le serveur PostgreSQL pour créer une nouvelle base de données.

#### Étape 2 : Mise à jour du Fichier `docker-compose.yml`

Ajoutons le service `wikijs` à notre fichier de composition.

```yaml
# ... (début du fichier, services zammad, ocs, etc.) ...
services:
  # ... (tous les services précédents) ...

  # --- Plateforme de Documentation : Wiki.js ---
  wikijs:
    image: requarks/wiki:2
    container_name: wikijs
    restart: unless-stopped
    depends_on:
      # S'assure que le serveur de BDD est démarré avant le wiki
      - zammad-db
    environment:
      - DB_TYPE=postgres
      - DB_HOST=zammad-db
      - DB_PORT=5432
      - DB_USER=${POSTGRES_USER}
      - DB_PASS=${POSTGRES_PASSWORD}
      - DB_NAME=${WIKIJS_DB_NAME}
    ports:
      # Port pour l'interface web. Sera géré par Traefik plus tard.
      - "8083:3000"
    volumes:
      - wikijs_data:/wiki/data
    networks:
      - systeme-ticketing-net

  # ... (service portainer) ...

# --- Définition des volumes nommés ---
volumes:
  # ... (tous les volumes existants) ...
  wikijs_data:

# --- Définition des réseaux ---
# ... (inchangé) ...```
**Explications des changements :**
*   Le service `wikijs` utilise l'image officielle `requarks/wiki:2`.
*   Il dépend de `zammad-db`, notre serveur PostgreSQL partagé.
*   Les variables d'environnement lui indiquent comment se connecter à la base de données, en réutilisant les identifiants existants mais avec le nouveau nom de base `wikijs`.
*   Un volume `wikijs_data` est créé pour stocker tout le contenu du wiki de manière persistante.

#### Étape 3 : Lancement et Vérification

Appliquez les nouveaux changements à votre infrastructure :
```bash
docker-compose up -d
```
Attendez que l'image soit téléchargée et que le conteneur démarre. Vous pouvez suivre les logs pour voir la progression :
```bash
docker-compose logs -f wikijs
```
Une fois que les logs indiquent que le serveur est démarré (`HTTP Server listening on port 3000`), vous pouvez passer à l'étape suivante. Vérifiez avec `docker-compose ps` que le conteneur `wikijs` est bien "Up".

#### Étape 4 : Configuration Initiale de Wiki.js

1.  **Accédez à Wiki.js :** Ouvrez votre navigateur et allez à `http://localhost:8083`.
2.  **Assistant d'installation :**
    *   **Administrateur :** Créez le compte administrateur principal du wiki. Entrez une adresse email et un mot de passe très solide.
    *   **URL du site :** Entrez l'URL finale à laquelle le wiki sera accessible. Pour l'instant, vous pouvez mettre `http://localhost:8083`, mais il est conseillé de mettre l'URL cible qui sera utilisée avec Traefik, par exemple `https://wiki.mondomaine.com`.
    *   Finalisez l'installation.
3.  **Première connexion :** Connectez-vous avec les identifiants que vous venez de créer.

#### Étape 5 : Intégration avec OpenLDAP

Comme pour Zammad, nous allons lier Wiki.js à notre annuaire central.

1.  Une fois connecté en tant qu'administrateur, cliquez sur **"Administration"** dans le menu en haut à droite.
2.  Dans le menu de gauche, allez dans **"Authentification"** et cliquez sur **"LDAP / Active Directory"**.
3.  Activez la stratégie en cliquant sur le slider, puis remplissez le formulaire :
    *   **Host :** `openldap`
    *   **Port :** `389`
    *   **Bind DN :** `cn=admin,dc=mondomaine,dc=com` (adaptez avec votre domaine)
    *   **Password :** Votre mot de passe admin LDAP (`${LDAP_ADMIN_PASSWORD}`)
    *   **Base DN :** `ou=users,dc=mondomaine,dc=com` (adaptez)
    *   **User Login Field :** `uid`
4.  **Profile Mapping (Correspondance des champs) :**
    *   **Username :** `uid`
    *   **Display Name :** `cn`
    *   **Email :** `mail`
5.  Cliquez sur **"Appliquer"** en haut à droite pour sauvegarder la configuration.
6.  Vous pouvez maintenant vous déconnecter et essayer de vous connecter avec un utilisateur qui existe dans votre annuaire LDAP.

---

### **Documentation de cette Étape**

C'est une partie importante à documenter pour vos collègues.

1.  **Plateforme de Documentation Wiki.js :**
    *   **Rôle et Public Cible :** Insistez sur la distinction cruciale entre Wiki.js (interne, technique) et la base de connaissances Zammad (externe, fonctionnelle).
    *   **Accès :** Notez l'URL `http://localhost:8083`.
    *   **Procédure de création du compte admin.**
2.  **Configuration de l'Authentification LDAP :**
    *   Détaillez la procédure pour activer l'authentification LDAP.
    *   Faites un tableau ou une capture d'écran des paramètres de configuration (Host, Bind DN, Base DN) et surtout de la section "Profile Mapping". Cette configuration est essentielle et doit être facilement retrouvable.

Vous disposez maintenant d'un espace dédié et sécurisé pour construire la mémoire technique de votre projet et de votre équipe. La prochaine étape consistera à mettre en place la supervision de tous ces services.


Explique en détail tout ce que tu as fais et intègre ça à un journal