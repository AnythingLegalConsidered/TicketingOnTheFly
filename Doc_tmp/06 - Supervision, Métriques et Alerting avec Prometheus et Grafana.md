Excellent. Maintenant que nous avons déployé la majorité de nos services applicatifs, il est temps de mettre en place les outils qui vont nous permettre de les surveiller. Un système qui n'est pas supervisé est une boîte noire ; nous allons l'éclairer.

### **Partie 6 : Supervision, Métriques et Alerting avec Prometheus et Grafana**

**Objectif :** Déployer une pile de supervision complète. Prometheus collectera les métriques de santé et de performance de tous nos conteneurs, et Grafana nous fournira des tableaux de bord visuels pour interpréter ces données en temps réel.

---

### **Théorie Détaillée**

#### 1. Pourquoi la Supervision est-elle Non Négociable ?
La supervision nous permet de passer d'un mode **réactif** ("un utilisateur m'appelle pour me dire que le site est lent") à un mode **proactif** ("je vois que l'utilisation du CPU sur le serveur de base de données augmente dangereusement, je vais investiguer avant que cela n'impacte les utilisateurs").
Nous allons surveiller des indicateurs clés :
*   **La santé des conteneurs :** Sont-ils démarrés ou arrêtés ? Redémarrent-ils en boucle ?
*   **La consommation des ressources :** Combien de CPU et de RAM chaque service utilise-t-il ? Un service a-t-il une fuite de mémoire ?
*   **Les performances applicatives :** (Plus avancé) Combien de tickets sont ouverts par minute ? Quel est le temps de réponse de l'API de Zammad ?

#### 2. La Pile Prometheus & Grafana : Le Duo Gagnant
*   **Prometheus : Le Collecteur de Données.** Prometheus est une base de données optimisée pour stocker des séries temporelles (des chiffres avec une étiquette de temps). Son fonctionnement principal est le "scraping" : à intervalle régulier (toutes les 15 secondes, par exemple), il va interroger des "cibles" (nos services) sur une URL spécifique (`/metrics`) pour récupérer leurs métriques actuelles et les stocker.
*   **Grafana : Le Tableau de Bord.** Grafana ne collecte aucune donnée. Son rôle est de se connecter à des sources de données (comme Prometheus) et de permettre la création de magnifiques tableaux de bord interactifs. On peut y créer des graphiques, des jauges, des alertes visuelles, etc. C'est notre cockpit de pilotage pour toute l'infrastructure.

#### 3. Comment surveiller des conteneurs Docker ?
Nos services (Zammad, OCS...) n'exposent pas nativement des métriques sur leur consommation de ressources. Pour cela, nous allons utiliser un outil formidable de Google appelé **cAdvisor (Container Advisor)**. Nous le déploierons comme un simple conteneur, et il exposera automatiquement une page `/metrics` contenant des informations détaillées sur TOUS les autres conteneurs en cours d'exécution sur la machine (CPU, RAM, réseau, I/O disque...). Prometheus n'aura plus qu'à "scraper" cAdvisor pour avoir une vue complète de l'état de notre pile Docker.

---

### **Mise en Pratique**

#### Étape 1 : Création du Fichier de Configuration de Prometheus

Prometheus a besoin d'un fichier de configuration pour savoir quelles cibles il doit surveiller.

1.  À la racine de votre projet, créez le dossier `config/prometheus` s'il n'existe pas.
2.  À l'intérieur de `config/prometheus`, créez un fichier nommé `prometheus.yml` et collez-y le contenu suivant :

```yaml
# Fichier de configuration global de Prometheus
global:
  scrape_interval: 15s # Par défaut, interroge les cibles toutes les 15 secondes.

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

Ce fichier est très simple : il définit deux "jobs". Le premier demande à Prometheus de se surveiller lui-même, et le second lui dit d'aller chercher les métriques des conteneurs en interrogeant le service `cadvisor` (que nous allons créer) sur son port `8080`.

#### Étape 2 : Mise à jour du Fichier `docker-compose.yml`

Nous allons ajouter trois nouveaux services : `prometheus`, `grafana`, et l'indispensable `cadvisor`.

```yaml
# ... (début du fichier, services zammad, ocs, wikijs, etc.) ...
services:
  # ... (tous les services précédents) ...

  # --- Collecteur de métriques : Prometheus ---
  prometheus:
    image: prom/prometheus:v2.47.1
    container_name: prometheus
    restart: unless-stopped
    ports:
      # Port pour l'interface web de Prometheus
      - "9090:9090"
    volumes:
      # Montage du fichier de configuration que nous venons de créer
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      # Volume pour stocker les données des métriques
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    networks:
      - systeme-ticketing-net

  # --- Visualisation des métriques : Grafana ---
  grafana:
    image: grafana/grafana-oss:10.1.5
    container_name: grafana
    restart: unless-stopped
    ports:
      # Port pour l'interface web de Grafana.
      # Note: 3000 est déjà pris par wikijs, nous utilisons donc 8084 sur l'hôte.
      - "8084:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - systeme-ticketing-net

  # --- Exportateur de métriques Docker : cAdvisor ---
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.2
    container_name: cadvisor
    restart: unless-stopped
    volumes:
      # Accès requis pour que cAdvisor puisse lire les informations des conteneurs
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - systeme-ticketing-net

  # ... (service portainer) ...

# --- Définition des volumes nommés ---
volumes:
  # ... (tous les volumes existants) ...
  prometheus_data:
  grafana_data:

# --- Définition des réseaux ---
# ... (inchangé) ...
```
**Attention au port de Grafana :** Le port par défaut de Grafana est `3000`. Nous l'avons déjà mappé sur l'hôte pour Wiki.js (`8083:3000`). Nous mappons donc le port `3000` interne de Grafana sur le port `8084` de notre machine hôte pour éviter tout conflit.

#### Étape 3 : Lancement et Vérification

Mettez à jour votre pile avec les nouveaux services de supervision :
```bash
docker-compose up -d
```
Vérifiez que les trois nouveaux conteneurs (`prometheus`, `grafana`, `cadvisor`) sont bien démarrés avec `docker-compose ps`.

#### Étape 4 : Exploration de Prometheus

1.  **Accédez à Prometheus :** Ouvrez votre navigateur et allez à `http://localhost:9090`.
2.  **Vérifiez les cibles :** C'est l'étape la plus importante. Allez dans le menu **"Status" -> "Targets"**. Vous devriez voir vos deux jobs, `prometheus` et `cadvisor`. Leur état ("State") doit être **UP** (en vert). Si ce n'est pas le cas, il y a un problème de configuration ou de réseau.
3.  Vous pouvez déjà explorer les métriques. Dans la barre de recherche principale, commencez à taper `container_` et profitez de l'auto-complétion pour voir toutes les métriques que cAdvisor collecte !

#### Étape 5 : Configuration de Grafana

1.  **Accédez à Grafana :** Ouvrez votre navigateur et allez à `http://localhost:8084`.
2.  **Connexion :** Les identifiants par défaut sont :
    *   **Utilisateur :** `admin`
    *   **Mot de passe :** `admin`
    Grafana vous demandera immédiatement de changer le mot de passe. Faites-le.
3.  **Ajouter Prometheus comme Source de Données :**
    *   Cliquez sur l'icône d'engrenage (Configuration) dans le menu de gauche, puis sur "Data Sources".
    *   Cliquez sur "Add data source" et sélectionnez "Prometheus".
    *   Dans le champ **"Prometheus server URL"**, entrez `http://prometheus:9090`. C'est le seul champ à remplir.
    *   Cliquez sur "Save & test" en bas. Un message vert "Data source is working" doit apparaître.
4.  **Importer un Tableau de Bord Prêt à l'Emploi :**
    *   Cliquez sur l'icône des quatre carrés (Dashboards) dans le menu de gauche.
    *   Sur la page des tableaux de bord, cliquez sur "Import".
    *   Dans le champ "Import via grafana.com", collez l'ID `13981`. C'est un excellent tableau de bord communautaire pour visualiser les métriques de cAdvisor.
    *   Cliquez sur "Load".
    *   Sur la page suivante, en bas, assurez-vous de sélectionner votre source de données Prometheus que vous venez de créer.
    *   Cliquez sur "Import".

Et voilà ! Vous avez maintenant un tableau de bord complet qui vous montre en temps réel la consommation CPU, RAM, réseau et bien plus pour chaque conteneur de votre projet.

---

### **Documentation de cette Étape**

1.  **Pile de Supervision :**
    *   **Rôle :** Expliquez le rôle de chaque composant : Prometheus (collecte), Grafana (visualisation), cAdvisor (exportateur de métriques Docker).
    *   **Configuration :** Mentionnez l'emplacement du fichier `prometheus.yml` et son rôle.
2.  **Accès aux Services :**
    *   URL de Prometheus : `http://localhost:9090`.
    *   URL de Grafana : `http://localhost:8084`.
    *   Notez les identifiants par défaut de Grafana (`admin`/`admin`) et l'obligation de les changer.
3.  **Procédure de Configuration de Grafana :**
    *   Détaillez la procédure pour ajouter la source de données Prometheus (URL : `http://prometheus:9090`).
    *   Notez l'ID du tableau de bord importé (`13981`) comme un "starter pack" pour la supervision Docker.

Votre projet est maintenant non seulement fonctionnel, mais aussi entièrement supervisé. La prochaine étape sera de tout rendre accessible de manière propre et sécurisée depuis l'extérieur grâce au reverse proxy Traefik.


Explique en détail tout ce que tu as fais et intègre ça à un journal