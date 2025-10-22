Absolument. Passons à la gestion de parc. Avoir un système de ticketing, c'est bien. Savoir exactement de quel matériel on parle quand un ticket est ouvert, c'est encore mieux. C'est le rôle d'OCS Inventory.

### **Partie 4 : Inventaire et Gestion du Parc Informatique avec OCS Inventory**

**Objectif :** Déployer le serveur OCS Inventory qui collectera de manière centralisée et automatisée les informations sur le matériel et les logiciels de tout le parc informatique. Nous préparerons ainsi le terrain pour une intégration future avec Zammad.

---

### **Théorie Détaillée**

#### 1. Qu'est-ce que l'Inventaire Automatisé ?
OCS (Open Computers and Software) Inventory est une solution qui automatise le processus d'inventaire informatique. Fini les tableurs Excel remplis à la main ! Le principe est simple :
*   **Un serveur OCS :** C'est la partie que nous installons. Il centralise toutes les données dans une base de données et fournit une interface web pour les consulter.
*   **Des agents OCS :** Ce sont de petits programmes que l'on installe sur les machines des utilisateurs (PC Windows, Mac, Linux) et sur les serveurs. Périodiquement, ces agents scannent la machine sur laquelle ils sont installés et envoient un rapport détaillé au serveur OCS.

#### 2. L'Intérêt pour le Système de Ticketing
L'intégration entre OCS et Zammad est un véritable "game-changer" pour une équipe de support. Imaginez le scénario :

*   **Sans OCS :** Un utilisateur ouvre un ticket : "Mon PC est très lent". Le technicien doit commencer par poser une série de questions : "Quel est votre système d'exploitation ? Quelle quantité de RAM avez-vous ? Quels logiciels sont installés ?". C'est une perte de temps pour tout le monde.
*   **Avec l'intégration OCS/Zammad :** L'utilisateur ouvre le même ticket. Le technicien, dans Zammad, voit que le ticket est associé à l'utilisateur "Jean Dupont". En un clic, il peut afficher la fiche inventaire de la machine de Jean, remontée par OCS. Il voit immédiatement que le PC n'a que 4 Go de RAM et que le disque dur est plein à 98%. Le diagnostic est instantané.

#### 3. La Pile Technique d'OCS
Le serveur OCS est une application web qui repose, comme Zammad, sur plusieurs composants : un serveur web (Apache), un langage de programmation (PHP/Perl) et une base de données (typiquement MariaDB/MySQL). Une fois de plus, Docker va nous masquer toute cette complexité en nous permettant de déployer le tout en un seul bloc.

---

### **Mise en Pratique**

#### Étape 1 : Mise à jour du Fichier d'Environnement (`.env`)

Nous devons définir les identifiants pour la base de données qui sera dédiée à OCS. Ajoutez les lignes suivantes à votre fichier `.env` :

```dotenv
# ... (variables existantes) ...

# --- Configuration OCS Inventory ---
OCS_DB_NAME=ocsdb
OCS_DB_USER=ocs
OCS_DB_PASSWORD=<UN_MOT_DE_PASSE_SOLIDE_POUR_LA_BDD_OCS>
# Ce mot de passe root est pour la gestion du conteneur MariaDB lui-même
MARIADB_ROOT_PASSWORD=<UN_MOT_DE_PASSE_ROOT_TRES_SOLIDE>
```

#### Étape 2 : Mise à jour du Fichier `docker-compose.yml`

Nous ajoutons deux nouveaux services : `ocs-db` (la base de données MariaDB) et `ocs-server` (l'application OCS).

```yaml
# ... (début du fichier docker-compose.yml, services zammad, etc.) ...
services:
  # ... (services zammad-db, zammad-elasticsearch, zammad, openldap, etc.) ...

  # --- Base de données pour OCS Inventory ---
  ocs-db:
    image: mariadb:10.11
    container_name: ocs-db
    restart: unless-stopped
    environment:
      - MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MARIADB_DATABASE=${OCS_DB_NAME}
      - MARIADB_USER=${OCS_DB_USER}
      - MARIADB_PASSWORD=${OCS_DB_PASSWORD}
    volumes:
      - ocs_db_data:/var/lib/mysql
    networks:
      - systeme-ticketing-net

  # --- Serveur d'inventaire : OCS Inventory ---
  ocs-server:
    image: ocsinventory/ocsinventory-server:2.12.1
    container_name: ocs-server
    restart: unless-stopped
    depends_on:
      - ocs-db
    environment:
      - OCS_DB_SERVER=ocs-db
      - OCS_DB_NAME=${OCS_DB_NAME}
      - OCS_DB_USER=${OCS_DB_USER}
      - OCS_DB_PASS=${OCS_DB_PASSWORD}
    ports:
      # Port pour l'interface web. Sera géré par Traefik plus tard.
      - "8082:80"
    volumes:
      # Volume pour les rapports d'inventaire
      - ocs_reports_data:/var/lib/ocsinventory-reports
    networks:
      - systeme-ticketing-net

  # ... (services portainer, etc.) ...

# --- Définition des volumes nommés ---
volumes:
  # ... (volumes existants: portainer_data, ldap_data, postgres_data, etc.) ...
  ocs_db_data:
  ocs_reports_data:

# --- Définition des réseaux ---
networks:
  systeme-ticketing-net:
    name: systeme-ticketing-net
```
**Explications des changements :**
*   Nous avons créé un service `ocs-db` dédié. Il est préférable de ne pas utiliser la même base PostgreSQL que Zammad, car OCS est conçu pour fonctionner avec MySQL/MariaDB.
*   Le service `ocs-server` se connecte à `ocs-db` en utilisant les variables du fichier `.env`.
*   Nous avons ajouté les volumes `ocs_db_data` et `ocs_reports_data` pour assurer la persistance des données.

#### Étape 3 : Lancement et Vérification

Appliquez les changements à votre pile de services :
```bash
docker-compose up -d
```
Docker va télécharger les nouvelles images pour MariaDB et OCS Server, puis démarrer les conteneurs. Vérifiez que tout est en ordre :
```bash
docker-compose ps
```
Vous devriez voir `ocs-db` et `ocs-server` dans la liste avec le statut "Up".

#### Étape 4 : Configuration Post-Installation d'OCS

Le serveur OCS nécessite une petite configuration via son interface web après le premier lancement.

1.  **Accédez à l'installateur :** Ouvrez votre navigateur et allez à `http://localhost:8082/ocsreports`.
2.  **Assistant d'installation :**
    *   Vous serez accueilli par l'assistant d'installation d'OCS.
    *   Entrez les informations de connexion à la base de données :
        *   **MySQL Server :** `ocs-db` (le nom du service Docker)
        *   **MySQL User :** `ocs` (la valeur de `OCS_DB_USER`)
        *   **MySQL Password :** Le mot de passe que vous avez mis dans `OCS_DB_PASSWORD`.
        *   **Database Name :** `ocsdb` (la valeur de `OCS_DB_NAME`)
    *   Cliquez sur "Send". L'installeur va créer la structure de la base de données.
3.  **Finalisation :** Une fois l'installation terminée, l'interface de connexion s'affiche. L'identifiant par défaut est :
    *   **Utilisateur :** `admin`
    *   **Mot de passe :** `admin`
4.  **Sécurité : Supprimer le fichier d'installation**
    C'est une étape **critique** pour la sécurité. Le fichier `install.php` doit être supprimé. Nous pouvons le faire directement dans le conteneur avec une commande Docker :
    ```bash
    docker-compose exec ocs-server rm /usr/share/ocsinventory-reports/ocsreports/install.php
    ```
5.  **Changer le mot de passe par défaut :** Connectez-vous avec `admin`/`admin`, puis allez dans le menu en haut à droite (icône utilisateur) -> "User profile" et changez immédiatement le mot de passe.

Votre serveur OCS Inventory est maintenant fonctionnel et sécurisé, prêt à recevoir les données des agents que vous déploierez sur votre parc.

---

### **Documentation de cette Étape**

Mettez à jour votre fichier de documentation :

1.  **Service d'Inventaire OCS Inventory :**
    *   **Rôle :** Expliquez son but : collecter automatiquement les données matérielles et logicielles du parc. Précisez l'intérêt de l'intégration future avec Zammad.
    *   **Dépendances :** Mentionnez qu'il utilise sa propre base de données MariaDB.
    *   **Configuration :** Listez les nouvelles variables du fichier `.env` (`OCS_DB_*`, `MARIADB_ROOT_PASSWORD`).
2.  **Procédure d'Installation :**
    *   **Accès :** Notez l'URL `http://localhost:8082/ocsreports`.
    *   **Configuration initiale :** Détaillez les informations à fournir à l'assistant d'installation (hôte `ocs-db`, etc.).
    *   **Sécurité Post-Install :** Documentez en gras la commande `docker-compose exec ... rm ...` pour supprimer `install.php` et l'obligation de changer le mot de passe `admin` par défaut. C'est une information de sécurité vitale.

Nous avons maintenant un système de ticketing et un système d'inventaire. La prochaine étape sera de mettre en place la documentation interne pour votre équipe avec Wiki.js.


Explique en détail tout ce que tu as fais et intègre ça à un journal