---
feature: Perso/Projets informatique/TicketOnTheFly/Pasted image 20251021213622.png
thumbnail: thumbnails/resized/fb6658ece021f69b9fddb994ce4dd1f9_86cf658e.webp
---
Absolument ! Entrons dans le vif du sujet avec la première partie. Nous allons mettre en place les fondations solides sur lesquelles reposeront tous les autres services.

### **Partie 1 : Fondations de l'Infrastructure et Conteneurisation**

**Objectif :** Créer un environnement de base standardisé, reproductible et facile à gérer avec Docker et Docker Compose. À la fin de cette partie, vous aurez une structure de projet propre et un premier service (Portainer) fonctionnel pour visualiser et gérer votre environnement.

---

### **Théorie Détaillée**

#### 1. La Conteneurisation avec Docker
Imaginez un conteneur comme une petite boîte hermétique qui contient tout ce dont une application a besoin pour fonctionner : le code, les bibliothèques, les dépendances, etc. L'avantage est que cette "boîte" fonctionnera de la même manière, quel que soit l'ordinateur sur lequel vous la placez (votre PC, un serveur, etc.).

*   **Image Docker :** C'est le plan de construction de notre boîte. Une image est un fichier en lecture seule qui contient les instructions pour créer un conteneur. Par exemple, il y aura une image pour Zammad, une pour OpenLDAP, etc.
*  **Conteneur Docker :** C'est une instance en cours d'exécution d'une image. C'est notre "boîte" en fonctionnement. On peut en créer, démarrer, arrêter, et supprimer autant qu'on veut à partir d'une seule image.

#### 2. L'Orchestration avec Docker Compose
Gérer un seul conteneur est simple. Mais votre projet en a presque dix ! Ils doivent communiquer entre eux, partager des réseaux, et être lancés dans un certain ordre. C'est le rôle de Docker Compose.

*   **Le fichier `docker-compose.yml` :** C'est le cœur de notre projet. C'est un fichier texte au format YAML qui agit comme un "chef d'orchestre". On y décrit tous nos services (Zammad, Grafana...), les réseaux qu'ils utilisent, les volumes de données dont ils ont besoin, et comment ils sont liés. Une seule commande (`docker-compose up`) suffira pour lire ce fichier et construire toute votre infrastructure.

#### 3. Structure du Projet et Persistance des Données
Une bonne organisation est essentielle. Nous allons adopter une structure de dossiers claire :

*   **Persistance des données :** Un conteneur est par nature "éphémère". Si vous le supprimez, toutes les données à l'intérieur sont perdues. Pour éviter cela, nous utiliserons des **volumes Docker**. Un volume est un dossier sur votre machine hôte (le serveur) qui est "monté" à l'intérieur du conteneur. Ainsi, les données de votre base Zammad ou de votre Wiki seront stockées en toute sécurité sur le disque de l'hôte, même si le conteneur est recréé.

#### 4. Gestion de la Configuration
Il est crucial de ne jamais écrire de mots de passe ou d'informations sensibles directement dans le fichier `docker-compose.yml`. Nous utiliserons un fichier `.env` pour stocker toutes nos variables de configuration (noms d'utilisateur, mots de passe, noms de domaine...). Le fichier `docker-compose.yml` lira automatiquement ce fichier `.env` pour récupérer les configurations.

---

### **Mise en Pratique**

#### Étape 1 : Installation des Prérequis

Avant tout, assurez-vous que Docker et Docker Compose sont installés sur votre machine de travail ou votre serveur.

*   **Pour installer Docker :** Suivez les instructions officielles pour votre système d'exploitation sur le [site de Docker](https://docs.docker.com/engine/install/).
*   **Pour installer Docker Compose :** Suivez le [guide d'installation de Docker Compose](https://docs.docker.com/compose/install/).

Pour vérifier que l'installation est réussie, ouvrez un terminal et tapez :
```bash
docker --version
docker-compose --version
```
Vous devriez voir les versions respectives s'afficher sans erreur.

#### Étape 2 : Création de l'Arborescence du Projet

Créez un dossier principal pour votre projet, puis organisez les sous-dossiers. Cette structure nous sera très utile par la suite pour stocker les configurations et les données persistantes de chaque service.

```bash
# Créez le dossier principal du projet
mkdir systeme-ticketing
cd systeme-ticketing

# Créez des dossiers pour les données et configurations
# Nous n'allons pas tous les créer maintenant, mais c'est pour montrer la structure cible
mkdir -p ./config/traefik
mkdir -p ./data/zammad
mkdir -p ./data/openldap
mkdir -p ./data/wikijs
mkdir -p ./data/prometheus
mkdir -p ./data/grafana
mkdir -p ./data/portainer
```

#### Étape 3 : Créer le Fichier d'Environnement (`.env`)

À la racine de votre projet (`systeme-ticketing`), créez un fichier nommé `.env`. C'est ici que nous centraliserons toutes nos variables.

```bash
# Créez le fichier .env
touch .env
```

Ouvrez ce fichier `.env` avec un éditeur de texte et ajoutez-y le contenu suivant. **Personnalisez les valeurs entre chevrons `<...>`**.

```dotenv
# Fichier de configuration global pour le projet de ticketing

# --- Domaines ---
# Domaine principal utilisé pour accéder aux services
# Exemple: DOMAIN=mondomaine.com
DOMAIN=<VOTRE_DOMAINE_ICI>

# --- Fuseau horaire ---
# Important pour que tous les services aient la même heure (logs, etc.)
# Exemple: TZ=Europe/Paris
TZ=<VOTRE_FUSEAU_HORAIRE_ICI>

# --- Identifiants de la base de données (utilisés par Zammad, WikiJS etc.) ---
# Nous les définissons maintenant pour plus tard
POSTGRES_USER=admin
POSTGRES_PASSWORD=<UN_MOT_DE_PASSE_SOLIDE_POUR_POSTGRES>
POSTGRES_DB=main_db

```

#### Étape 4 : Créer le Fichier `docker-compose.yml`

Toujours à la racine du projet, créez le fichier `docker-compose.yml`. Nous allons commencer par y ajouter un seul service pour vérifier que tout fonctionne : **Portainer**. C'est une interface web qui permet de gérer facilement votre environnement Docker.

```bash
# Créez le fichier docker-compose.yml
touch docker-compose.yml
```

Ouvrez ce fichier et collez-y le code suivant :

```yaml
services:
  # --- Service de gestion Docker : Portainer ---
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: -H unix:///var/run/docker.sock
    restart: unless-stopped
    ports:
      # Port pour accéder à l'interface web de Portainer.
      # NE PAS exposer ce port sur internet directement. L'accès se fera via Traefik plus tard.
      - "9443:9443"
      - "9000:9000"
    volumes:
      # Volume pour stocker les données de Portainer de manière persistante
      - portainer_data:/data
      # Donne à Portainer l'accès à Docker pour qu'il puisse gérer les autres conteneurs
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - default # Nous utiliserons un réseau plus spécifique plus tard

# --- Définition des volumes nommés ---
# Les volumes permettent de sauvegarder les données même si les conteneurs sont supprimés.
volumes:
  portainer_data:

# --- Définition des réseaux ---
# Créer un réseau dédié permettra à nos conteneurs de communiquer de manière isolée.
networks:
  default:
    name: systeme-ticketing-net
```

#### Étape 5 : Lancement et Vérification

Votre structure de base est prête ! Depuis la racine de votre projet (`systeme-ticketing`), lancez la pile de conteneurs en mode détaché (`-d`) :

```bash
docker-compose up -d
```

Docker va télécharger l'image de Portainer (si ce n'est pas déjà fait) et démarrer le conteneur.

Pour vérifier que le conteneur est bien en cours d'exécution, tapez :
```bash
docker-compose ps
```
Vous devriez voir une sortie similaire à celle-ci, avec un statut "Up" ou "running" :
```
  Name                 Command               State                  Ports
-----------------------------------------------------------------------------------------
portainer   /portainer -H unix:///va ...   Up (healthy)   8000/tcp, 9000/tcp, 9443/tcp
```

#### Étape 6 : Premier Accès

Ouvrez votre navigateur web et allez à l'adresse : `https://localhost:9443` (ou remplacez `localhost` par l'adresse IP de votre serveur).

Votre navigateur affichera probablement un avertissement de sécurité car le certificat est auto-signé. C'est normal. Acceptez le risque et continuez.

Portainer vous demandera de créer un compte administrateur. **Faites-le et conservez bien ce mot de passe.** Une fois connecté, vous verrez votre environnement Docker et le conteneur Portainer en cours d'exécution.

Portainer fonctionne parfaitement :

![[Pasted image 20251021213622.png]]
---

### **Documentation de cette Étape**

C'est le moment parfait pour commencer à documenter. Dans votre projet, créez un fichier `README.md` ou un dossier `docs/` et commencez à noter :

1.  **Objectif de l'infrastructure :** Expliquez brièvement le rôle de Docker et Docker Compose dans ce projet.
2.  **Structure du projet :** Décrivez l'arborescence des dossiers et à quoi sert chaque dossier (`config`, `data`).
3.  **Configuration initiale :** Expliquez le rôle du fichier `.env` et listez les variables qu'il contient.
4.  **Lancement du projet :** Notez la commande `docker-compose up -d` et la commande de vérification `docker-compose ps`.
5.  **Accès aux services :** Notez l'URL de Portainer (`https://localhost:9443`) et la procédure de création du compte administrateur.

Vous avez maintenant une base saine, versionnable et facilement reproductible. Nous sommes prêts à ajouter notre premier service clé dans la partie suivante : l'annuaire OpenLDAP.


Explique en détail tout ce que tu as fais et intègre ça à un journal