Excellent, nous arrivons au cœur du projet. Nous allons maintenant installer Zammad, le système de ticketing, et le connecter à notre annuaire OpenLDAP pour qu'il puisse reconnaître nos utilisateurs.

### **Partie 3 : Le Cœur du Système : Ticketing et Base de Connaissances avec Zammad**

**Objectif :** Déployer Zammad avec ses dépendances (une base de données PostgreSQL et un moteur de recherche Elasticsearch), le rendre accessible, et le configurer pour qu'il utilise OpenLDAP comme source d'authentification pour les agents et les clients.

---

### **Théorie Détaillée**

#### 1. Le Rôle de Zammad
Zammad est bien plus qu'un simple outil de ticketing. Il va centraliser :
*   **La gestion des tickets :** Création, assignation, suivi des réponses, gestion des priorités.
*   **Les Accords de Niveau de Service (SLA) :** Définition de règles de temps de réponse et de résolution pour garantir une qualité de service.
*   **La Base de Connaissances :** Un espace où les utilisateurs (clients) peuvent trouver des réponses aux questions fréquentes, et où les techniciens peuvent documenter les solutions.

#### 2. Les Dépendances de Zammad
Une application aussi complète ne fonctionne pas seule. Elle s'appuie sur deux services critiques que nous allons également conteneuriser :

*   **PostgreSQL (Base de données) :** C'est ici que Zammad stockera toutes ses données persistantes : les tickets, les utilisateurs, les configurations, les articles de la base de connaissances, etc. Utiliser une base de données relationnelle robuste comme PostgreSQL est indispensable pour la cohérence des données.
*   **Elasticsearch (Moteur de recherche) :** Zammad gère une énorme quantité de texte. Pour que la recherche d'un ancien ticket ou d'un article de la base de connaissances soit quasi instantanée, il s'appuie sur Elasticsearch, un moteur de recherche extrêmement puissant. Sans lui, la recherche serait très lente.

#### 3. L'Intégration LDAP
C'est ici que notre architecture prend tout son sens. Au lieu de créer manuellement chaque utilisateur dans Zammad, nous allons lui dire : "Va chercher la liste des utilisateurs et des groupes dans le serveur OpenLDAP".
Cela nous permettra :
*   D'importer automatiquement les utilisateurs de l'annuaire dans Zammad.
*   De permettre aux utilisateurs de se connecter à Zammad avec le même mot de passe que pour les autres services.
*   De synchroniser les informations (nom, email, etc.) si elles sont modifiées dans l'annuaire.

---

### **Mise en Pratique**

#### Étape 1 : Mise à jour du Fichier d'Environnement (`.env`)

Nous avons déjà défini nos variables `POSTGRES_USER`, `POSTGRES_PASSWORD`, et `POSTGRES_DB` dans la partie 1. Nous allons maintenant nous assurer qu'elles sont bien présentes car Zammad va les utiliser. Votre fichier `.env` doit contenir ces lignes :

```dotenv
# ... (variables existantes) ...

# --- Identifiants de la base de données (utilisés par Zammad, WikiJS etc.) ---
POSTGRES_USER=admin
POSTGRES_PASSWORD=<UN_MOT_DE_PASSE_SOLIDE_POUR_POSTGRES>
POSTGRES_DB=main_db
```
Aucune nouvelle variable n'est nécessaire si vous avez suivi la partie 1, mais vérifiez que celles-ci sont bien définies.

#### Étape 2 : Mise à jour du Fichier `docker-compose.yml`

C'est la plus grosse mise à jour jusqu'à présent. Nous allons ajouter trois nouveaux services : la base de données (`zammad-db`), le moteur de recherche (`zammad-elasticsearch`), et l'application Zammad elle-même.

Modifiez votre fichier `docker-compose.yml` pour qu'il ressemble à ceci :

```yaml
version: '3.8'

services:
  # --- Dépendances pour Zammad ---
  zammad-db:
    image: postgres:15
    container_name: zammad-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - systeme-ticketing-net

  zammad-elasticsearch:
    image: elasticsearch:7.17.10
    container_name: zammad-elasticsearch
    restart: unless-stopped
    environment:
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m" # Limite la RAM pour un environnement de test
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - systeme-ticketing-net

  # --- Service de Ticketing : Zammad ---
  zammad:
    image: zammad/zammad-docker-compose:6.2.0-1
    container_name: zammad
    restart: unless-stopped
    depends_on:
      - zammad-db
      - zammad-elasticsearch
    environment:
      - POSTGRES_HOST=zammad-db
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - ELASTICSEARCH_URL=http://zammad-elasticsearch:9200
    ports:
      # Port pour accéder à Zammad. Sera géré par Traefik plus tard.
      - "8081:80"
    volumes:
      - zammad_data:/opt/zammad/
    networks:
      - systeme-ticketing-net

  # --- Service d'annuaire : OpenLDAP ---
  # (inchangé)
  openldap:
    # ... configuration d'openldap ...
    networks:
      - systeme-ticketing-net

  # --- Interface de gestion pour OpenLDAP : phpLDAPadmin ---
  # (inchangé)
  phpldapadmin:
    # ... configuration de phpldapadmin ...
    networks:
      - systeme-ticketing-net

  # --- Service de gestion Docker : Portainer ---
  # (inchangé)
  portainer:
    # ... configuration de portainer ...
    networks:
      - systeme-ticketing-net

# --- Définition des volumes nommés ---
volumes:
  portainer_data:
  ldap_data:
  ldap_config:
  postgres_data:
  elasticsearch_data:
  zammad_data:

# --- Définition des réseaux ---
networks:
  systeme-ticketing-net:
    name: systeme-ticketing-net
```

#### Étape 3 : Lancement et Vérification

Lancez la mise à jour de la pile. Docker va télécharger les trois nouvelles images, ce qui peut prendre un peu de temps.
```bash
docker-compose up -d
```
**Attention :** Zammad peut être assez long à démarrer pour la première fois car il doit initialiser la base de données. Soyez patient (cela peut prendre 5 à 10 minutes).

Pour suivre la progression du démarrage de Zammad, utilisez la commande suivante :
```bash
docker-compose logs -f zammad
```
Attendez de voir des messages indiquant que le serveur est prêt et à l'écoute (`Listening on...`). Une fois que les logs se calment, le service devrait être prêt. Vérifiez que tous les conteneurs sont bien démarrés avec `docker-compose ps`.

#### Étape 4 : Configuration Initiale de Zammad

1.  **Accédez à Zammad :** Ouvrez votre navigateur et allez à `http://localhost:8081`.
2.  **Assistant d'installation :** Vous serez accueilli par un assistant. Suivez les étapes pour créer votre premier compte administrateur. Entrez un nom, un prénom, une adresse email et un mot de passe. **Notez bien ces identifiants !**
3.  **Nom de l'organisation :** Donnez un nom à votre instance Zammad.
4.  **Configuration email :** Pour le moment, ignorez la configuration des emails en cliquant sur "Ignorer". Nous y reviendrons avec MailHog.

Une fois l'assistant terminé, vous arriverez sur le tableau de bord de Zammad.

#### Étape 5 : Intégration avec OpenLDAP

C'est l'étape cruciale. Nous allons connecter Zammad à notre annuaire.

1.  Connectez-vous à Zammad avec le compte admin que vous venez de créer.
2.  Cliquez sur l'icône d'engrenage en bas à gauche pour accéder aux **Paramètres**.
3.  Dans le menu de gauche, allez dans **Intégrations -> LDAP**.
4.  Cliquez sur "Ajouter un nouvel hôte LDAP" et remplissez le formulaire avec soin :
    *   **Nom :** `Annuaire Principal` (ou ce que vous voulez)
    *   **Hôte :** `openldap` (c'est le nom du service dans Docker Compose, Docker gère la résolution DNS)
    *   **Port :** `389`
    *   **DN de l'utilisateur (Bind DN) :** Le DN complet de votre administrateur LDAP. `cn=admin,dc=mondomaine,dc=com` (adaptez avec votre domaine).
    *   **Mot de passe :** Le mot de passe de l'admin LDAP (`${LDAP_ADMIN_PASSWORD}` de votre `.env`).
    *   **DN de base de l'utilisateur :** L'endroit où Zammad doit chercher les utilisateurs. `ou=users,dc=mondomaine,dc=com` (adaptez).
5.  **Mappage des attributs :** C'est ici que vous dites à Zammad quel champ LDAP correspond à quel champ Zammad.
    *   **UID :** `uid`
    *   **Prénom :** `givenName`
    *   **Nom de famille :** `sn`
    *   **E-Mail :** `mail`
    *   **Téléphone :** `telephoneNumber` (si vous l'utilisez)
    *   **Login :** `uid`
6.  **Groupes :** Vous pouvez laisser cette partie vide pour l'instant.
7.  En bas de la page, activez l'intégration et cliquez sur **Mettre à jour**.
8.  Allez dans l'onglet **"Synchronisation"** en haut et lancez une synchronisation manuelle.

Si tout est bien configuré, Zammad va se connecter à OpenLDAP, trouver les utilisateurs (pour l'instant, il n'y en a pas, nous devrions en ajouter un via phpLDAPadmin pour tester) et les importer. Vous pourrez alors les voir dans la section **"Utilisateurs"** de Zammad.

---

### **Documentation de cette Étape**

Ajoutez une section conséquente à votre documentation pour Zammad :

1.  **Service de Ticketing Zammad :**
    *   **Rôle :** Expliquez son rôle central (tickets, SLA, KB).
    *   **Dépendances :** Mentionnez qu'il requiert PostgreSQL pour les données et Elasticsearch pour la recherche.
    *   **Accès :** Notez l'URL `http://localhost:8081` et la procédure de création du compte admin.
2.  **Intégration LDAP :**
    *   **Objectif :** Expliquer que cette étape lie Zammad à l'annuaire central.
    *   **Procédure :** Faites une capture d'écran ou un tableau récapitulatif des paramètres de configuration LDAP (Hôte, Port, Bind DN, DN de base, et surtout le mappage des attributs). C'est une information cruciale pour la maintenance future.

Vous avez maintenant un système de ticketing professionnel, adossé à un annuaire centralisé. La prochaine étape sera de mettre en place un système d'inventaire pour savoir sur quel matériel portent les tickets.


Explique en détail tout ce que tu as fais et intègre ça à un journal