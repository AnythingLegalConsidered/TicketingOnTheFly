Parfait, continuons sur notre lancée. Nous allons maintenant mettre en place le cerveau de notre gestion d'utilisateurs : l'annuaire OpenLDAP. Tous les autres services viendront piocher dans cet annuaire pour authentifier les utilisateurs.

### **Partie 2 : Gestion Centralisée des Identités avec OpenLDAP**

**Objectif :** Déployer un serveur OpenLDAP conteneurisé et une interface web (phpLDAPadmin) pour le gérer. À la fin de cette étape, nous aurons un annuaire fonctionnel, prêt à stocker nos utilisateurs et nos groupes de manière centralisée.

---

### **Théorie Détaillée**

#### 1. Qu'est-ce que LDAP ?
LDAP (Lightweight Directory Access Protocol) est un protocole permettant d'interroger et de modifier des informations dans un annuaire. Pensez à cet annuaire comme un carnet d'adresses très structuré et optimisé pour la lecture. Au lieu de contacts, il stocke des "entrées" qui peuvent être des utilisateurs, des groupes, des ordinateurs, etc. OpenLDAP est l'implémentation open-source la plus populaire de ce service d'annuaire.

#### 2. Pourquoi est-ce essentiel pour notre projet ?
Sans annuaire centralisé, vous devriez créer un compte pour "Jean Dupont" dans Zammad, puis un autre dans Wiki.js, puis un autre dans Grafana... S'il change de mot de passe ou quitte l'entreprise, vous devriez le modifier ou le supprimer partout. C'est ingérable.
Avec OpenLDAP, vous créez "Jean Dupont" une seule fois. Les autres services sont configurés pour demander à OpenLDAP : "Est-ce que cet utilisateur existe et son mot de passe est-il correct ?". La gestion est centralisée, simplifiée et sécurisée.

#### 3. Les Concepts Clés d'OpenLDAP (simplifiés)
La structure d'un annuaire LDAP peut sembler complexe au début. Voici les termes essentiels :

*   **DN (Distinguished Name) :** C'est l'identifiant unique et complet d'une entrée dans l'annuaire. C'est comme le chemin complet d'un fichier sur un ordinateur.
    *   Exemple : `cn=jdupont,ou=users,dc=mondomaine,dc=com`
*   **DC (Domain Component) :** Il correspond aux composantes de votre nom de domaine. Si votre domaine est `mondomaine.com`, votre base d'annuaire sera `dc=mondomaine,dc=com`.
*   **OU (Organizational Unit) :** C'est un "dossier" pour organiser vos entrées. Nous allons en créer deux principaux : `ou=users` et `ou=groups`.
*   **CN (Common Name) :** C'est le nom commun de l'entrée, par exemple le nom d'utilisateur (`jdupont`) ou le nom d'un groupe (`support-technique`).

Pour gérer notre annuaire, nous utiliserons **phpLDAPadmin**, une interface web qui nous évitera d'avoir à taper des lignes de commande complexes pour ajouter un utilisateur.

---

### **Mise en Pratique**

#### Étape 1 : Mise à jour du Fichier d'Environnement (`.env`)

Nous devons ajouter des variables de configuration spécifiques à OpenLDAP. Ouvrez votre fichier `.env` et ajoutez les lignes suivantes à la fin, en personnalisant les valeurs.

```dotenv
# --- Configuration OpenLDAP ---
# Le mot de passe pour l'administrateur de l'annuaire LDAP (cn=admin,dc=...)
LDAP_ADMIN_PASSWORD=<UN_MOT_DE_PASSE_TRES_SOLIDE_POUR_LDAP>

# Le nom de votre organisation
ORGANISATION_NAME=<NOM_DE_VOTRE_ENTREPRISE_OU_ECOLE>
```
**Note :** Le `DOMAIN` que vous avez défini dans la partie 1 sera automatiquement réutilisé pour configurer la base de l'annuaire.

#### Étape 2 : Mise à jour du Fichier `docker-compose.yml`

Maintenant, nous allons ajouter les services `openldap` et `phpldapadmin` à notre fichier `docker-compose.yml`.

```yaml
version: '3.8'

services:
  # --- Service d'annuaire : OpenLDAP ---
  openldap:
    image: osixia/openldap:1.5.0
    container_name: openldap
    restart: unless-stopped
    environment:
      # Utilise le domaine défini dans le fichier .env
      - LDAP_DOMAIN=${DOMAIN}
      # Utilise le mot de passe admin défini dans le fichier .env
      - LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD}
      # Configuration pour la réplication (non utilisée ici mais bonne pratique)
      - LDAP_CONFIG_PASSWORD=${LDAP_ADMIN_PASSWORD}
      # Supprime la base de données existante au démarrage si le volume est vide,
      # pour assurer une installation propre.
      - LDAP_REMOVE_CONFIG_AFTER_SETUP=true
    volumes:
      # Volume pour la base de données LDAP
      - ldap_data:/var/lib/ldap
      # Volume pour la configuration de slapd (le démon LDAP)
      - ldap_config:/etc/ldap/slapd.d
    networks:
      - systeme-ticketing-net

  # --- Interface de gestion pour OpenLDAP : phpLDAPadmin ---
  phpldapadmin:
    image: osixia/phpldapadmin:0.9.0
    container_name: phpldapadmin
    restart: unless-stopped
    environment:
      # Indique à phpLDAPadmin où trouver le serveur LDAP
      - PHPLDAPADMIN_LDAP_HOSTS=openldap
      # Permet de se connecter avec le DN complet (plus sécurisé)
      - PHPLDAPADMIN_LDAP_CLIENT_TLS=false
      # Le DN de base pour les recherches
      - PHPLDAPADMIN_LDAP_BASE_DN=dc=${DOMAIN//./,dc=} # Transforme mondomaine.com en dc=mondomaine,dc=com
    ports:
      # Port pour accéder à l'interface web. NE PAS exposer sur internet.
      - "8080:80"
    depends_on:
      - openldap
    networks:
      - systeme-ticketing-net

  # --- Service de gestion Docker : Portainer ---
  # (Celui de la partie 1, on ne le modifie pas)
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: -H unix:///var/run/docker.sock
    restart: unless-stopped
    ports:
      - "9443:9443"
      - "9000:9000"
    volumes:
      - portainer_data:/data
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - systeme-ticketing-net # Assurez-vous qu'il est sur le bon réseau

# --- Définition des volumes nommés ---
volumes:
  portainer_data:
  ldap_data:
  ldap_config:

# --- Définition des réseaux ---
networks:
  systeme-ticketing-net:
    name: systeme-ticketing-net
```

**Explications des changements :**
*   Nous avons ajouté deux nouveaux services : `openldap` et `phpldapadmin`.
*   Ils utilisent les variables du fichier `.env` pour se configurer dynamiquement.
*   Ils sont placés sur le même réseau (`systeme-ticketing-net`) pour pouvoir communiquer entre eux. Le nom du conteneur `openldap` est utilisé comme nom d'hôte pour la connexion.
*   Nous avons explicitement nommé notre réseau `systeme-ticketing-net` pour plus de clarté.
*   `depends_on: - openldap` garantit que `phpldapadmin` ne démarrera pas avant que `openldap` soit prêt.

#### Étape 3 : Lancement et Vérification

Depuis la racine de votre projet, mettez à jour votre pile de services :
```bash
docker-compose up -d
```
Docker va télécharger les nouvelles images et démarrer les deux nouveaux conteneurs.

Vérifiez que tout est bien lancé :
```bash
docker-compose ps
```
Vous devriez maintenant voir `openldap`, `phpldapadmin` et `portainer`, tous avec le statut "Up" ou "running". Si un conteneur ne démarre pas, vous pouvez inspecter ses logs avec la commande `docker-compose logs <nom_du_conteneur>`.

#### Étape 4 : Première Connexion et Configuration de Base

1.  **Accédez à phpLDAPadmin :** Ouvrez votre navigateur et allez à l'adresse `http://localhost:8080` (ou remplacez `localhost` par l'IP de votre serveur).

2.  **Connectez-vous :**
    *   **Login DN :** C'est ici que la théorie devient pratique. Votre DN d'administrateur a été créé automatiquement. Il est de la forme `cn=admin,dc=mondomaine,dc=com`. Remplacez `mondomaine.com` par le domaine que vous avez mis dans votre fichier `.env`.
    *   **Password :** C'est le mot de passe que vous avez défini dans la variable `LDAP_ADMIN_PASSWORD` de votre fichier `.env`.

3.  **Créez la structure de base :**
    *   Une fois connecté, vous verrez votre base `dc=mondomaine,dc=com` sur la gauche. Cliquez dessus.
    *   Cliquez sur "Create new entry here".
    *   Sélectionnez le modèle "Generic: Organisational Unit".
    *   Dans le champ "ou", tapez `users` et cliquez sur "Create Object", puis "Commit".
    *   Revenez à la racine de votre domaine (en cliquant sur `dc=mondomaine,dc=com`) et répétez l'opération pour créer une deuxième OU nommée `groups`.

Vous avez maintenant un annuaire LDAP fonctionnel avec une structure de base prête à accueillir vos utilisateurs et vos groupes.

---

### **Documentation de cette Étape**

Ajoutez une nouvelle section à votre documentation :

1.  **Service d'Annuaire OpenLDAP :**
    *   **Rôle :** Expliquez que c'est la base de données centrale pour toutes les identités.
    *   **Configuration :** Listez les nouvelles variables ajoutées au fichier `.env` (`LDAP_ADMIN_PASSWORD`, `ORGANISATION_NAME`).
    *   **Accès à l'administration :** Notez l'URL de phpLDAPadmin (`http://localhost:8080`).
    *   **Identifiants par défaut :** Documentez le DN de l'administrateur (`cn=admin,dc=...`) et où trouver son mot de passe (dans le `.env`).
    *   **Structure de base :** Mentionnez la création des OUs `users` et `groups` comme étant la structure standard du projet.

Nous sommes maintenant prêts à passer à l'étape suivante : déployer le cœur de notre système, Zammad, et le connecter à notre tout nouvel annuaire OpenLDAP.


Explique en détail tout ce que tu as fais et intègre ça à un journal