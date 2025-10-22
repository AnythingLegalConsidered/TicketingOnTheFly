Absolument. C'est l'étape qui va transformer votre projet d'un ensemble de services locaux en une véritable application web professionnelle, accessible et sécurisée. Nous allons mettre en place Traefik, notre "chef d'orchestre" du trafic réseau.

### **Partie 7 : Accès, Sécurité et Routage avec Traefik**

**Objectif :** Déployer Traefik comme reverse proxy pour unifier l'accès à tous nos services sous des sous-domaines propres (ex: `zammad.mondomaine.com`), supprimer le fouillis des ports (`:8081`, `:8082`...), et automatiser entièrement la gestion des certificats HTTPS avec Let's Encrypt pour sécuriser toutes les communications.

---

### **Théorie Détaillée**

#### 1. Le Problème : Le Chaos des Ports
Actuellement, pour accéder à vos services, vous devez mémoriser une adresse IP et une liste de ports :
*   Zammad : `http://<IP>:8081`
*   OCS : `http://<IP>:8082`
*   Wiki.js : `http://<IP>:8083`
*   Grafana : `http://<IP>:8084`
*   ... et ainsi de suite.

Ceci est non seulement peu pratique, mais aussi très peu sécurisé : tout transite en clair (HTTP) et vous exposez une multitude de ports sur votre machine, augmentant la surface d'attaque.

#### 2. La Solution : Le Reverse Proxy
Un reverse proxy est un serveur qui se place en frontal de toutes vos applications. C'est le **seul et unique point d'entrée** pour tout le trafic venant de l'extérieur. Il fonctionne comme un réceptionniste intelligent :
1.  Une requête arrive pour `https://zammad.mondomaine.com`.
2.  Traefik la reçoit (car il est le seul à écouter sur les ports standards 80 et 443).
3.  Il regarde le nom de domaine demandé (`zammad.mondomaine.com`).
4.  Il consulte ses règles et voit que ce domaine doit être dirigé vers le conteneur Zammad.
5.  Il transmet la requête au conteneur Zammad de manière sécurisée sur le réseau interne Docker.
6.  La réponse du conteneur Zammad suit le chemin inverse.

#### 3. La Magie de Traefik : Auto-découverte et HTTPS Automatique
Nous choisissons Traefik car il est conçu pour les environnements conteneurisés :
*   **Découverte automatique des services :** Traefik écoute les événements Docker. Quand nous démarrons un nouveau conteneur avec des "étiquettes" (labels) spécifiques, Traefik le détecte automatiquement, lit les étiquettes pour savoir quel nom de domaine lui est associé, et crée la route correspondante sans aucune intervention manuelle. C'est le summum de l'automatisation.
*   **Intégration Let's Encrypt :** Nous allons configurer Traefik une seule fois en lui disant : "Tu es le gestionnaire de certificats pour `mondomaine.com`". Ensuite, pour chaque service que nous exposerons, Traefik va automatiquement :
    1.  Demander un certificat HTTPS valide à Let's Encrypt.
    2.  Prouver qu'il contrôle bien le nom de domaine.
    3.  Installer le certificat.
    4.  Le renouveler automatiquement avant son expiration.

---

### **Mise en Pratique**

#### Étape 0 : Prérequis - Configuration DNS
C'est une étape **extérieure** à notre serveur mais **obligatoire**. Vous devez vous connecter à l'interface de gestion de votre nom de domaine (OVH, Gandi, Cloudflare...) et créer des enregistrements DNS de type `A` pour chaque service, pointant vers l'adresse IP publique de votre serveur.

Par exemple :
*   `zammad.mondomaine.com` -> `A` -> `<IP_PUBLIQUE_DU_SERVEUR>`
*   `ocs.mondomaine.com` -> `A` -> `<IP_PUBLIQUE_DU_SERVEUR>`
*   `wiki.mondomaine.com` -> `A` -> `<IP_PUBLIQUE_DU_SERVEUR>`
*   `grafana.mondomaine.com` -> `A` -> `<IP_PUBLIQUE_DU_SERVEUR>`
*   `portainer.mondomaine.com` -> `A` -> `<IP_PUBLIQUE_DU_SERVEUR>`
*   ...et ainsi de suite pour chaque service que vous voulez exposer.

#### Étape 1 : Mise à jour du Fichier d'Environnement (`.env`)

Nous avons besoin d'une adresse email pour que Let's Encrypt puisse vous envoyer des notifications (par exemple, concernant l'expiration d'un certificat s'il n'arrive pas à le renouveler).

```dotenv
# ... (variables existantes) ...

# --- Configuration Traefik ---
# Email pour les certificats Let's Encrypt
ACME_EMAIL=<VOTRE_ADRESSE_EMAIL>
```

#### Étape 2 : Création des Fichiers de Configuration de Traefik

1.  À la racine de votre projet, dans le dossier `config/traefik`, créez un fichier nommé `traefik.yml`. C'est le fichier de configuration statique, qui ne changera pas.

    ```yaml
    # config/traefik/traefik.yml
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
    
    # Configuration de l'API et du Dashboard Traefik (pour le débogage)
    api:
      dashboard: true
      insecure: false # Le dashboard ne sera pas exposé sans routeur
    
    # Comment Traefik découvre les autres services (ici, via Docker)
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
    ```
2.  Toujours dans `config/traefik`, créez un fichier vide qui stockera les certificats.
    ```bash
    touch config/traefik/acme.json
    chmod 600 config/traefik/acme.json
    ```
    La commande `chmod` est une mesure de sécurité importante pour protéger ce fichier.

#### Étape 3 : Mise à Jour Majeure du `docker-compose.yml`

C'est ici que tout se met en place. Nous allons :
1.  Ajouter le service `traefik`.
2.  **Supprimer TOUTES les sections `ports`** des autres services (Zammad, Grafana, etc.).
3.  Ajouter des `labels` à chaque service pour que Traefik sache comment les router.

```yaml
version: '3.8'

services:
  # --- Reverse Proxy : Traefik ---
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./config/traefik/acme.json:/acme.json
    networks:
      - systeme-ticketing-net
    labels:
      # Expose le dashboard de Traefik lui-même
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.${DOMAIN}`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"
      # Ajoute une authentification basique au dashboard (changer les identifiants !)
      - "traefik.http.routers.traefik.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.users=admin:<MOT_DE_PASSE_HASHÉ_ICI>" # Important !

  # --- Service de Ticketing : Zammad ---
  zammad:
    # ... (toute la config de zammad reste la même) ...
    # SUPPRIMER la section "ports"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.zammad.rule=Host(`zammad.${DOMAIN}`)"
      - "traefik.http.routers.zammad.entrypoints=websecure"
      - "traefik.http.routers.zammad.tls.certresolver=letsencrypt"
      - "traefik.http.services.zammad.loadbalancer.server.port=80"

  # --- Serveur d'inventaire : OCS Inventory ---
  ocs-server:
    # ... (config inchangée) ...
    # SUPPRIMER la section "ports"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ocs.rule=Host(`ocs.${DOMAIN}`)"
      - "traefik.http.routers.ocs.entrypoints=websecure"
      - "traefik.http.routers.ocs.tls.certresolver=letsencrypt"
      - "traefik.http.services.ocs.loadbalancer.server.port=80"
      
  # --- Plateforme de Documentation : Wiki.js ---
  wikijs:
    # ... (config inchangée) ...
    # SUPPRIMER la section "ports"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wikijs.rule=Host(`wiki.${DOMAIN}`)"
      - "traefik.http.routers.wikijs.entrypoints=websecure"
      - "traefik.http.routers.wikijs.tls.certresolver=letsencrypt"
      - "traefik.http.services.wikijs.loadbalancer.server.port=3000"

  # --- Visualisation des métriques : Grafana ---
  grafana:
    # ... (config inchangée) ...
    # SUPPRIMER la section "ports"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.${DOMAIN}`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  # --- Service de gestion Docker : Portainer ---
  portainer:
    # ... (config inchangée) ...
    # SUPPRIMER la section "ports"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN}`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.services.portainer.loadbalancer.server.port=9443"
      # Indique à Traefik que le service backend est en HTTPS
      - "traefik.http.services.portainer.loadbalancer.server.scheme=https"

  # ... (tous les autres services comme prometheus, openldap, etc. qui n'ont pas besoin d'être exposés
  # n'ont PAS de labels traefik.enable=true, ils restent donc inaccessibles depuis l'extérieur)

# ... (définition des volumes et réseaux inchangée) ...
```
**TRÈS IMPORTANT :** Pour le mot de passe du dashboard Traefik, vous ne devez pas mettre un mot de passe en clair. Vous devez le "hasher". Vous pouvez utiliser un utilitaire en ligne ou la ligne de commande :
`echo $(htpasswd -nb admin VOTRE_MOT_DE_PASSE) | sed -e s/\\$/\\$\\$/g`
Copiez le résultat (ex: `admin:$$apr1$$...`) et collez-le dans le label.

#### Étape 4 : Lancement et Vérification

1.  Lancez la mise à jour finale de la pile :
    ```bash
    docker-compose up -d
    ```
2.  Surveillez les logs de Traefik pour voir la magie opérer. Vous devriez voir des messages concernant la détection des autres conteneurs et la demande de certificats.
    ```bash
    docker-compose logs -f traefik
    ```
    Attendez de voir des messages du type "Successfully obtained certificate for domains..."
3.  **Le test final :** Ouvrez votre navigateur et accédez à vos nouvelles URLs :
    *   `https://zammad.mondomaine.com`
    *   `https://grafana.mondomaine.com`
    *   `https://traefik.mondomaine.com` (pour le dashboard de Traefik)

Vous devriez arriver sur chaque service, avec un cadenas vert dans la barre d'adresse, indiquant que la connexion est sécurisée en HTTPS. Toutes les requêtes en HTTP simple seront automatiquement redirigées vers HTTPS.

---

### **Documentation de cette Étape**

1.  **Reverse Proxy Traefik :**
    *   **Rôle :** Expliquez son rôle de point d'entrée unique, de routeur et de gestionnaire de certificats.
    *   **Prérequis DNS :** Documentez l'obligation de configurer les enregistrements DNS de type `A` pour chaque sous-domaine.
2.  **Configuration :**
    *   Expliquez le rôle du fichier `traefik.yml` (statique) et du fichier `acme.json` (certificats).
    *   **Concept des `labels` Docker :** Expliquez que c'est la méthode de configuration dynamique de Traefik et donnez un exemple commenté.
3.  **Tableau des Accès :**
    *   Créez un tableau final récapitulant tous les services et leurs URL d'accès définitives et sécurisées.
    *   Mentionnez l'URL du dashboard Traefik et comment générer le mot de passe pour s'y connecter.

Votre infrastructure est maintenant complète, robuste, sécurisée et accessible de manière professionnelle. Les dernières étapes concerneront des outils de développement et la consolidation du tout.


Explique en détail tout ce que tu as fais et intègre ça à un journal