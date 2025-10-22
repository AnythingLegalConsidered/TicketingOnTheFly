Bien sûr. Nous arrivons aux outils qui rendent la vie d'un administrateur système plus simple au quotidien. Maintenant que l'infrastructure est fonctionnelle, nous allons ajouter les services qui facilitent sa gestion et son débogage, notamment pour les fonctionnalités qui envoient des notifications.

### **Partie 8 : Gestion et Développement**

**Objectif :** Finaliser l'infrastructure avec deux outils de confort : ré-introduire Portainer comme interface de gestion centrale accessible via Traefik, et déployer MailHog pour intercepter et visualiser tous les e-mails envoyés par nos applications (Zammad, Grafana, etc.) en environnement de test.

---

### **Théorie Détaillée**

#### 1. L'Interface de Gestion Visuelle : Portainer
Nous avons installé Portainer dès la première étape comme un moyen de vérifier que Docker fonctionnait. Maintenant, il prend son rôle final : celui de tableau de bord de gestion pour toute notre pile de conteneurs.

*   **Pourquoi l'utiliser ?** Alors que la ligne de commande est puissante, une interface visuelle est imbattable pour des actions rapides et des vérifications d'état :
    *   **Visualisation globale :** Voir en un clin d'œil tous les conteneurs, leur état (démarré, arrêté), et leur consommation de ressources (CPU/RAM).
    *   **Gestion simplifiée :** Redémarrer un conteneur qui semble bloqué en un seul clic.
    *   **Accès aux logs :** Consulter les logs d'un service sans avoir à taper `docker-compose logs <service>` dans le terminal.
    *   **Console d'urgence :** Ouvrir un terminal directement à l'intérieur d'un conteneur depuis le navigateur pour des opérations de débogage avancées.

Maintenant que nous avons Traefik, nous allons cesser d'y accéder via son port `9443` et lui donner une URL propre et sécurisée comme tous les autres services.

#### 2. Le Piège à E-mails pour le Développement : MailHog
Zammad est conçu pour envoyer des dizaines de notifications par e-mail : "nouveau ticket créé", "une réponse a été ajoutée", "le ticket est clos", etc. Grafana peut aussi envoyer des alertes par e-mail.

*   **Le problème :** En phase de développement ou de test, configurer un vrai serveur SMTP est complexe et risqué. Une mauvaise configuration pourrait envoyer des centaines d'e-mails de test à de vrais utilisateurs, ou vos e-mails pourraient être bloqués comme spam. Comment vérifier que les e-mails sont bien formatés et qu'ils sont bien envoyés au bon moment ?
*   **La solution :** MailHog est un faux serveur SMTP. On configure nos applications (Zammad) pour qu'elles envoient leurs e-mails à MailHog. MailHog ne transmet **jamais** les e-mails à l'extérieur. Il les "capture" et les affiche dans une interface web très simple. C'est l'outil parfait pour :
    *   Vérifier que Zammad envoie bien une notification quand une action est effectuée.
    *   Voir à quoi ressemble l'e-mail reçu par l'utilisateur.
    *   Déboguer les problèmes d'envoi sans impacter qui que ce soit.

---

### **Mise en Pratique**

#### Étape 1 : Mise à jour du Fichier d'Environnement (`.env`)

Pour rendre la configuration de Zammad plus flexible, nous allons externaliser ses paramètres SMTP dans notre fichier `.env`.

```dotenv
# ... (variables existantes) ...

# --- Configuration SMTP pour Zammad (vers MailHog) ---
# En production, il faudra remplacer ces valeurs par celles d'un vrai serveur SMTP
ZAMMAD_SMTP_HOST=mailhog
ZAMMAD_SMTP_PORT=1025
ZAMMAD_SMTP_USER=
ZAMMAD_SMTP_PASSWORD=
ZAMMAD_SMTP_DOMAIN=${DOMAIN}
```

#### Étape 2 : Mise à jour du Fichier `docker-compose.yml`

Nous allons ajouter le service `mailhog` et mettre à jour le service `zammad` pour qu'il utilise nos nouvelles variables d'environnement.

```yaml
version: '3.8'

services:
  # ... (Traefik, bases de données, etc. ne changent pas) ...

  # --- Service de Ticketing : Zammad ---
  zammad:
    # ... (les lignes image, container_name, restart, depends_on sont inchangées) ...
    environment:
      - POSTGRES_HOST=zammad-db
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - ELASTICSEARCH_URL=http://zammad-elasticsearch:9200
      # NOUVELLES LIGNES POUR LE SMTP
      - SMTP_HOST=${ZAMMAD_SMTP_HOST}
      - SMTP_PORT=${ZAMMAD_SMTP_PORT}
      - SMTP_USER=${ZAMMAD_SMTP_USER}
      - SMTP_PASSWORD=${ZAMMAD_SMTP_PASSWORD}
      - SMTP_DOMAIN=${ZAMMAD_SMTP_DOMAIN}
    volumes:
      - zammad_data:/opt/zammad/
    networks:
      - systeme-ticketing-net
    labels:
      # ... (les labels Traefik pour Zammad sont inchangés) ...

  # --- Serveur SMTP de test : MailHog ---
  mailhog:
    image: mailhog/mailhog:latest
    container_name: mailhog
    restart: unless-stopped
    networks:
      - systeme-ticketing-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mailhog.rule=Host(`mailhog.${DOMAIN}`)"
      - "traefik.http.routers.mailhog.entrypoints=websecure"
      - "traefik.http.routers.mailhog.tls.certresolver=letsencrypt"
      - "traefik.http.services.mailhog.loadbalancer.server.port=8025"

  # --- Rappel de la configuration de Portainer ---
  # Le service a été défini dans la partie 1 et les labels dans la partie 7.
  # Assurez-vous que sa configuration est bien présente.
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: -H unix:///var/run/docker.sock
    restart: unless-stopped
    volumes:
      - portainer_data:/data
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - systeme-ticketing-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN}`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.services.portainer.loadbalancer.server.port=9443"
      - "traefik.http.services.portainer.loadbalancer.server.scheme=https"

  # ... (tous les autres services : ocs, wikijs, grafana, prometheus, etc.)

# ... (définition des volumes et réseaux inchangée) ...
```
**Explication des changements :**
1.  Nous avons ajouté un service `mailhog` très simple, qui expose son interface web sur le port 8025.
2.  Nous avons ajouté les labels Traefik correspondants pour le rendre accessible via `https://mailhog.mondomaine.com`.
3.  Nous avons injecté les variables d'environnement SMTP dans le conteneur Zammad. Au démarrage, Zammad lira ces variables et se configurera automatiquement pour utiliser `mailhog` comme serveur de messagerie.

#### Étape 3 : Lancement et Vérification

Appliquez la mise à jour :
```bash
docker-compose up -d```
Vérifiez que le nouveau conteneur `mailhog` est bien démarré :
```bash
docker-compose ps
```

#### Étape 4 : Utilisation et Test

1.  **Accédez à Portainer :** Ouvrez `https://portainer.mondomaine.com` dans votre navigateur. Explorez l'interface et familiarisez-vous avec la visualisation de vos conteneurs, y compris le nouveau service `mailhog`.
2.  **Accédez à MailHog :** Ouvrez `https://mailhog.mondomaine.com`. Vous devriez voir une interface très simple avec le message "Waiting for mail...".
3.  **Déclenchez un e-mail dans Zammad :**
    *   Connectez-vous à votre instance Zammad (`https://zammad.mondomaine.com`).
    *   Allez dans un ticket existant ou créez-en un nouveau.
    *   Ajoutez une note ou une réponse.
4.  **Vérifiez la réception dans MailHog :**
    *   Retournez sur l'onglet de MailHog. Presque instantanément, un nouvel e-mail devrait apparaître dans la liste.
    *   Cliquez dessus pour voir l'expéditeur, le destinataire, le sujet et le contenu complet de la notification Zammad.

C'est la preuve que toute la chaîne fonctionne : Zammad a bien détecté l'événement, a généré la notification, l'a envoyée au serveur SMTP (MailHog), qui l'a capturée et vous l'a affichée.

---

### **Documentation de cette Étape**

1.  **Outils de Gestion et Développement :**
    *   Créez une section pour ces outils qui facilitent la vie de l'administrateur.
2.  **Portainer (Gestion Visuelle) :**
    *   **Rôle :** "Interface web pour visualiser et gérer l'état des conteneurs."
    *   **Accès :** `https://portainer.mondomaine.com`.
3.  **MailHog (Débogage E-mail) :**
    *   **Rôle :** "Serveur SMTP factice pour intercepter et visualiser les e-mails envoyés par les applications en phase de test."
    *   **Accès :** `https://mailhog.mondomaine.com`.
    *   **Usage :** Expliquez brièvement la procédure de test : effectuer une action dans Zammad, puis vérifier la réception dans l'interface MailHog.

Vous avez maintenant une infrastructure complète, sécurisée, supervisée et dotée d'outils de gestion et de débogage robustes. Le projet est techniquement terminé. La dernière partie concernerait la consolidation, la sauvegarde et la mise en production.


Explique en détail tout ce que tu as fais et intègre ça à un journal