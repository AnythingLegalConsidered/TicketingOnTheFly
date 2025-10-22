# TicketingOnTheFly 

[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Système de ticketing intégré professionnel avec gestion centralisée des identités, documentation, supervision et inventaire.**

---

##  Vue d'Ensemble

**TicketingOnTheFly** est une infrastructure complète open-source pour la gestion de support IT, déployable en quelques minutes grâce à Docker. Le projet intègre 9 services essentiels qui communiquent ensemble pour offrir une solution professionnelle clé-en-main.

###  Objectifs du Projet

-  **Installation rapide** : Déploiement automatisé en une commande
-  **Infrastructure as Code** : Configuration versionnable et reproductible  
-  **Authentification centralisée** : Single Sign-On partiel via OpenLDAP
-  **Sécurité renforcée** : HTTPS automatique, isolation des services
-  **Supervision intégrée** : Métriques et alerting temps réel
-  **Production-ready** : Stratégie de sauvegarde et haute disponibilité

---

##  Architecture des Services

| Service | Rôle | Port(s) |
|---------|------|---------|
| **Zammad** | Plateforme de ticketing et base de connaissances | 8081 |
| **OpenLDAP** | Annuaire centralisé des utilisateurs (LDAP) | 389 |
| **phpLDAPadmin** | Interface web de gestion LDAP | 8080 |
| **Wiki.js** | Documentation technique interne | - |
| **OCS Inventory** | Inventaire automatisé du parc informatique | - |
| **Prometheus** | Collecte et stockage des métriques | 9090 |
| **Grafana** | Tableaux de bord et visualisation | 3000 |
| **Traefik** | Reverse proxy, routage et SSL automatique | 80, 443 |
| **Portainer** | Gestion de l'environnement Docker | 9443 |
| **MailHog** | Serveur SMTP de test (développement) | 8025 |

**Dépendances :**
- PostgreSQL (Zammad, Wiki.js)
- MariaDB (OCS Inventory)
- Redis (Zammad cache)
- Elasticsearch (Zammad search)
- cAdvisor (métriques Docker)

###  Schéma d'Architecture

```
                                Internet
                                    |
                                    v
                            +---------------+
                            |    Traefik    |   Reverse Proxy + SSL
                            |  (80/443)     |
                            +-------+-------+
                                    |
            +-----------------------+-----------------------+
            |                       |                       |
            v                       v                       v
    +---------------+       +---------------+       +---------------+
    |    Zammad     |       |    Wiki.js    |       |     OCS       |
    | (Ticketing)   |       |(Documentation)|       |  (Inventaire) |
    +-------+-------+       +-------+-------+       +-------+-------+
            |                       |                       |
            v                       v                       v
    +---------------+       +---------------+       +---------------+
    |   PostgreSQL  |       |     LDAP      |       |    MariaDB    |
    +---------------+       +---------------+       +---------------+
                                    ^
                                    |
                        +-----------+-----------+
                        |                       |
                   Grafana                  Portainer
                (Supervision)            (Gestion Docker)
```

---

##  Guide de Déploiement Rapide

###  Prérequis

- **Système d'exploitation** : Linux (Debian, Ubuntu, CentOS...) ou WSL2
- **Docker** : Version 20.10 ou supérieure
- **Docker Compose** : Version 2.0 ou supérieure
- **Ressources recommandées** :
  - CPU : 4 cœurs minimum
  - RAM : 8 GB minimum (16 GB recommandé)
  - Disque : 50 GB d'espace disponible

#### Vérification des prérequis

```bash
docker --version        # Doit afficher >= 20.10
docker-compose --version  # Doit afficher >= 2.0
docker info             # Vérifie que Docker fonctionne
```

###  Démarrage Ultra-Rapide (10 minutes)

**Pour une installation immédiate avec configuration automatique :**

```bash
# 1. Cloner le projet
git clone https://github.com/VotreNom/TicketingOntheFly.git
cd TicketingOntheFly

# 2. Configurer l'environnement
cp .env.example .env
nano .env  # Éditez les variables (domaine, mots de passe)

# 3. Déployer l'infrastructure
./init.sh

# 4. Configuration automatique (OpenLDAP + Zammad)
./configure-all.sh
```

Le script `configure-all.sh` (Phase 10) configure automatiquement :
-  **OpenLDAP** : Structure, groupes et utilisateurs
-  **Zammad** : Groupes et intégration LDAP
-  **Comptes par défaut** : 8 utilisateurs prêts à l'emploi
-  **Mapping 1:1** : Groupes LDAP synchronisés avec Zammad

**Temps total** : 10 minutes | **Configuration manuelle évitée** : 1-2 heures

 **Consultez le guide de démarrage rapide** : [doc/QUICK-START.md](doc/QUICK-START.md)

###  Installation Automatisée (Recommandée)

**Déploiement complet en 3 étapes :**

```bash
# 1. Cloner le projet
git clone https://github.com/VotreNom/TicketingOntheFly.git
cd TicketingOntheFly

# 2. Configurer l'environnement
cp .env.example .env
nano .env  # Éditez les variables (domaine, mots de passe)

# 3. Lancer le script d'initialisation
./init.sh
```

Le script `init.sh` effectue automatiquement :
-  Vérification des prérequis (Docker, Docker Compose)
-  Création de l'arborescence de dossiers
-  Création des fichiers de configuration nécessaires
-  Téléchargement des images Docker
-  Démarrage de tous les services

**Temps de déploiement estimé** : 10-15 minutes (selon votre connexion internet)

###  Installation Manuelle

Si vous préférez contrôler chaque étape :

```bash
# 1. Créer le fichier .env
cp .env.example .env
nano .env

# 2. Créer les répertoires nécessaires
mkdir -p config/{traefik,prometheus}
mkdir -p data/{zammad,openldap,wikijs,grafana,prometheus,portainer}
touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

# 3. Télécharger les images
docker-compose pull

# 4. Démarrer les services
docker-compose up -d

# 5. Vérifier l'état
docker-compose ps
```

---

##  Accès aux Services

###  En Développement (Local)

| Service | URL | Identifiants par défaut |
|---------|-----|------------------------|
| Zammad | `http://zammad.localhost` | À créer au 1er accès |
| OCS Inventory | `http://ocs.localhost` | `admin` / `admin`  |
| Wiki.js | `http://wiki.localhost` | À créer au 1er accès |
| Grafana | `http://grafana.localhost` | `admin` / `admin`  |
| Portainer | `http://portainer.localhost` | À créer au 1er accès |
| MailHog | `http://mailhog.localhost` | Aucune authentification |
| phpLDAPadmin | `http://ldap.localhost` | `cn=admin,dc=localhost` / (voir `.env`) |
| Prometheus | `http://prometheus.localhost` | Aucune authentification |
| Traefik Dashboard | `http://traefik.localhost` | `admin` / (voir `docker-compose.yml`) |

 **Changez OBLIGATOIREMENT les mots de passe par défaut après le premier accès !**

###  En Production

| Service | URL | Sécurité |
|---------|-----|----------|
| Zammad | `https://zammad.mondomaine.com` | HTTPS (Let's Encrypt) |
| OCS Inventory | `https://ocs.mondomaine.com` | HTTPS + Auth |
| Wiki.js | `https://wiki.mondomaine.com` | HTTPS + Auth LDAP |
| Grafana | `https://grafana.mondomaine.com` | HTTPS + Auth LDAP |
| Portainer | `https://portainer.mondomaine.com` | HTTPS + Auth forte |
| MailHog |  (développement uniquement) | - |
| phpLDAPadmin | `https://ldap.mondomaine.com` | HTTPS + Restriction IP |
| Prometheus | `https://prometheus.mondomaine.com` | HTTPS + BasicAuth |
| Traefik Dashboard | `https://traefik.mondomaine.com` | HTTPS + BasicAuth |

**Configuration DNS requise** : Créez des enregistrements A pointant vers l'IP de votre serveur pour chaque sous-domaine.

---

##  Configuration Post-Installation

Après le déploiement, vous avez deux options :

### Option 1 :  Configuration Automatisée (Recommandée)

Utilisez le script de configuration automatique pour OpenLDAP et Zammad :

```bash
./configure-all.sh
```

Ce script (Phase 10) :
-  Crée automatiquement la structure LDAP (ou=users, ou=groups)
-  Crée 4 groupes par défaut (support-n1, support-n2, administrateurs, utilisateurs)
-  Crée 8 utilisateurs prêts à l'emploi avec mots de passe
-  Configure l'intégration LDAP dans Zammad
-  Synchronise les groupes LDAP avec Zammad (mapping 1:1)

**Personnalisation possible** : Éditez `scripts/config.yaml` avant d'exécuter le script.

 **Documentation complète** : [scripts/README.md](scripts/README.md) | [doc/QUICK-START.md](doc/QUICK-START.md)

### Option 2 : Configuration Manuelle

Pour une configuration manuelle détaillée : **[doc/POST-INSTALLATION.md](doc/POST-INSTALLATION.md)**

**Ordre de configuration recommandé :**

1.  **Portainer** : Créer le compte admin (interface de gestion Docker)
2.  **OpenLDAP** : Créer la structure (ou=users, ou=groups) via phpLDAPadmin
3.  **Zammad** : Configuration initiale + intégration LDAP
4.  **OCS Inventory** : Configuration + déploiement des agents
5.  **Wiki.js** : Création admin + intégration LDAP + première page
6.  **Grafana** : Intégration Prometheus + dashboards + LDAP
7.  **MailHog** : Tests d'envoi d'emails depuis Zammad

**Temps de configuration estimé** : 
- Configuration automatique : 2-3 minutes
- Configuration manuelle : 2-3 heures

---

##  Commandes Utiles

### Gestion des Services

```bash
# Voir l'état de tous les services
docker-compose ps

# Démarrer tous les services
docker-compose up -d

# Arrêter tous les services
docker-compose down

# Redémarrer un service spécifique
docker-compose restart zammad-nginx

# Voir les logs d'un service
docker-compose logs -f zammad-railsserver

# Voir les logs de tous les services
docker-compose logs -f

# Mettre à jour les images
docker-compose pull
docker-compose up -d --remove-orphans
```

### Maintenance et Monitoring

```bash
# Espace disque utilisé par Docker
docker system df

# Nettoyer les ressources inutilisées
docker system prune -a

# Voir les ressources consommées
docker stats

# Accéder au shell d'un conteneur
docker-compose exec zammad-railsserver bash

# Sauvegarder l'infrastructure
./backup.sh

# Consulter les métriques Prometheus
curl http://localhost:9090/metrics
```

---

##  Stratégie de Sauvegarde

### Script de Sauvegarde Automatisé

Le projet inclut un script `backup.sh` qui sauvegarde :

-  **Bases de données** : PostgreSQL (Zammad, Wiki.js) et MariaDB (OCS)
-  **Volumes persistants** : Zammad, Wiki.js, Grafana, Prometheus, OpenLDAP, Portainer
-  **Certificats SSL** : acme.json de Traefik
-  **Configuration** : .env, docker-compose.yml, fichiers de config

#### Utilisation du script

```bash
# Sauvegarde manuelle
./backup.sh

# Sauvegarde vers un répertoire spécifique
./backup.sh /mnt/external/backups

# Automatiser avec cron (tous les jours à 2h du matin)
crontab -e
# Ajouter cette ligne :
0 2 * * * /home/user/TicketingOntheFly/backup.sh >> /var/log/ticketing-backup.log 2>&1
```

#### Politique de Rétention

- Le script conserve automatiquement les **7 dernières sauvegardes**
- Les sauvegardes plus anciennes sont supprimées automatiquement
- **Recommandation** : Copier régulièrement les sauvegardes sur un stockage distant (NAS, cloud)

### Restauration

Pour restaurer une sauvegarde, consultez : **[doc/POST-INSTALLATION.md](doc/POST-INSTALLATION.md#restauration-de-sauvegarde)**

---

##  Sécurité et Bonnes Pratiques

###  Checklist de Sécurité

- [ ] Changer TOUS les mots de passe par défaut
- [ ] Ne JAMAIS committer le fichier `.env` (déjà dans `.gitignore`)
- [ ] Activer HTTPS en production (Let's Encrypt via Traefik)
- [ ] Restreindre l'accès à phpLDAPadmin et Prometheus (IP whitelisting)
- [ ] Configurer l'authentification LDAP pour tous les services
- [ ] Activer les sauvegardes automatiques quotidiennes
- [ ] Mettre en place un monitoring des alertes Grafana
- [ ] Configurer un pare-feu (ufw, iptables)
- [ ] Limiter les ports exposés (seulement 80/443 en production)
- [ ] Activer les logs d'audit sur les services critiques

###  Gestion des Secrets

**Mots de passe forts recommandés :**
```bash
# Générer un mot de passe aléatoire sécurisé
openssl rand -base64 32
```

**Variables sensibles dans `.env` :**
- `POSTGRES_PASSWORD` : Base de données principale
- `LDAP_ADMIN_PASSWORD` : Administrateur LDAP
- `MARIADB_ROOT_PASSWORD` : Root MariaDB
- `OCS_DB_PASSWORD` : Base OCS Inventory

---

##  Supervision et Alerting

### Dashboards Grafana Pré-configurés

Le projet inclut des dashboards pour :
-  **Métriques Docker** : CPU, RAM, réseau de chaque conteneur
-  **Métriques système** : Charge serveur, disque, uptime
-  **Métriques applicatives** : Temps de réponse Zammad, requêtes PostgreSQL
-  **Alertes** : Notifications Slack/Email en cas de problème

### Configuration des Alertes

Consultez : **[doc/06 - Supervision, Métriques et Alerting.md](doc/06%20-%20Supervision,%20Métriques%20et%20Alerting%20avec%20Prometheus%20et%20Grafana.md)**

---

##  Dépannage

### Problèmes Courants

#### Erreur "port already in use"

```bash
# Identifier le processus qui utilise le port
sudo lsof -i :8081

# Arrêter le processus ou changer le port dans docker-compose.yml
```

#### Zammad ne démarre pas

```bash
# Vérifier les logs d'initialisation
docker-compose logs zammad-init

# Si problème de migration DB, réinitialiser
docker-compose down
docker volume rm ticketingonthefly_postgres_data
docker-compose up -d
```

#### Elasticsearch n'a pas assez de mémoire

```bash
# Augmenter vm.max_map_count (Linux/WSL)
sudo sysctl -w vm.max_map_count=262144

# Rendre permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

#### Traefik ne détecte pas les services

```bash
# Vérifier que les labels Docker sont corrects
docker-compose config

# Redémarrer Traefik
docker-compose restart traefik

# Consulter les logs Traefik
docker-compose logs traefik
```

### Ressources de Dépannage

- **Documentation détaillée** : [doc/POST-INSTALLATION.md](doc/POST-INSTALLATION.md)
- **Logs de tous les services** : `docker-compose logs -f`
- **Portainer** : Interface graphique pour inspecter les conteneurs
- **CHANGELOG.md** : Historique complet des commandes et décisions

---

##  Documentation Complète

### Guides Utilisateur

| Document | Description |
|----------|-------------|
| [QUICK-START.md](doc/QUICK-START.md) |  **Guide de démarrage rapide** - Déploiement en 10 minutes |
| [POST-INSTALLATION.md](doc/POST-INSTALLATION.md) | Guide de configuration post-déploiement de chaque service |
| [GUIDE-PERSONNALISATION.md](doc/GUIDE-PERSONNALISATION.md) |  Guide de personnalisation avancée du projet |
| [CHANGELOG.md](CHANGELOG.md) | Journal de bord complet de toutes les phases du projet |

### Documentation des Scripts

| Document | Description |
|----------|-------------|
| [scripts/README.md](scripts/README.md) |  **Phase 10** - Configuration automatisée OpenLDAP et Zammad |
| [scripts/config.yaml](scripts/config.yaml.example) | Fichier de configuration YAML (groupes, utilisateurs, intégration) |

### Documentation Technique

| Document | Description |
|----------|-------------|
| [00 - TicketOnTheFly.md](doc/doc_creation/00%20-%20TicketOnTheFly.md) | Vision globale et théorique du projet |
| [01 - Fondations.md](doc/doc_creation/01%20-%20Fondations%20de%20l'Infrastructure%20et%20Conteneurisation.md) | Docker, Docker Compose, Infrastructure as Code |
| [02 - OpenLDAP.md](doc/doc_creation/02%20-%20Gestion%20Centralisée%20des%20Identités%20avec%20OpenLDAP.md) | Configuration de l'annuaire LDAP |
| [03 - Zammad.md](doc/doc_creation/03%20-%20Ticketing%20et%20Base%20de%20Connaissances%20avec%20Zammad.md) | Déploiement et intégration Zammad |
| [04 - OCS Inventory.md](doc/doc_creation/04%20-%20Inventaire%20et%20Gestion%20du%20Parc%20Informatique%20avec%20OCS%20Inventory.md) | Inventaire automatisé |
| [05 - Wiki.js.md](doc/doc_creation/05%20-%20Documentation%20Interne%20et%20Procédures%20avec%20Wiki.js.md) | Documentation technique |
| [06 - Prometheus & Grafana.md](doc/doc_creation/06%20-%20Supervision,%20Métriques%20et%20Alerting%20avec%20Prometheus%20et%20Grafana.md) | Supervision et métriques |
| [07 - Traefik.md](doc/doc_creation/07%20-%20Accès,%20Sécurité%20et%20Routage%20avec%20Traefik.md) | Reverse proxy et SSL |
| [08 - Gestion et Développement.md](doc/doc_creation/08%20-%20Gestion%20et%20Développement.md) | Portainer et MailHog |
| [09 - Consolidation.md](doc/doc_creation/09%20-%20Consolidation,%20Sauvegarde%20et%20Bonnes%20Pratiques.md) | Scripts d'automatisation et stratégie de sauvegarde |
| [10 - Configuration Automatisée.md](doc/doc_creation/10%20-%20Configuration%20Automatisée.md) | Documentation technique de la Phase 10 |

---

##  État du Projet

###  Phases Complétées

- [x] **Phase 1** : Fondations (Docker Compose, Portainer)
- [x] **Phase 2** : OpenLDAP et phpLDAPadmin
- [x] **Phase 3** : Zammad (Ticketing)
- [x] **Phase 4** : OCS Inventory (Inventaire)
- [x] **Phase 5** : Wiki.js (Documentation)
- [x] **Phase 6** : Prometheus & Grafana (Supervision)
- [x] **Phase 7** : Traefik (Reverse Proxy & SSL)
- [x] **Phase 8** : MailHog (SMTP de test) & Portainer finalisé
- [x] **Phase 9** : Consolidation, scripts d'automatisation et documentation finale
- [x] **Phase 10** : Configuration automatisée OpenLDAP et Zammad

###  Projet Complet et Production-Ready !

**19 services déployés** | **Configuration automatisée** | **Documenté de A à Z**

---

##  Contribution

Les contributions sont bienvenues ! N'hésitez pas à :
-  Signaler des bugs via les Issues
-  Proposer des améliorations
-  Améliorer la documentation
-  Soumettre des Pull Requests

### Comment Contribuer

1. Fork le projet
2. Créez une branche (`git checkout -b feature/amelioration`)
3. Committez vos changements (`git commit -m 'Ajout fonctionnalité X'`)
4. Poussez vers la branche (`git push origin feature/amelioration`)
5. Ouvrez une Pull Request

---

##  Licence

Ce projet est sous licence **MIT**. Consultez le fichier [LICENSE](LICENSE) pour plus de détails.

---

##  Auteur

**Ianis**

-  Email : [votre-email@example.com]
-  GitHub : [@VotreUsername](https://github.com/VotreUsername)

---

##  Remerciements

Ce projet utilise les excellents logiciels open-source suivants :
- [Zammad](https://zammad.org/) - Plateforme de ticketing
- [OpenLDAP](https://www.openldap.org/) - Serveur LDAP
- [Wiki.js](https://js.wiki/) - Solution de documentation moderne
- [OCS Inventory](https://ocsinventory-ng.org/) - Inventaire IT
- [Prometheus](https://prometheus.io/) - Monitoring et alerting
- [Grafana](https://grafana.com/) - Visualisation de métriques
- [Traefik](https://traefik.io/) - Reverse proxy moderne
- [Portainer](https://www.portainer.io/) - Gestion Docker
- [MailHog](https://github.com/mailhog/MailHog) - Test SMTP

---

** Si ce projet vous a été utile, n'hésitez pas à lui donner une étoile sur GitHub !**

---

**Dernière mise à jour** : Octobre 2025 | **Version** : 1.0.0
