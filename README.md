# TicketingOnTheFly 🎫

Système de ticketing intégré avec gestion des identités, documentation, supervision et inventaire.

## 📋 Vue d'ensemble

Ce projet met en place une infrastructure complète de gestion de support IT incluant :
- **Zammad** : Plateforme de ticketing
- **OpenLDAP** : Annuaire centralisé des utilisateurs
- **Wiki.js** : Documentation interne
- **Prometheus & Grafana** : Supervision et métriques
- **OCS Inventory** : Inventaire du parc informatique
- **Traefik** : Reverse proxy et gestion SSL
- **Portainer** : Gestion de l'environnement Docker

## 🏗️ Architecture

L'infrastructure utilise Docker et Docker Compose pour conteneuriser tous les services, garantissant :
- ✅ Isolation des applications
- ✅ Reproductibilité de l'environnement
- ✅ Déploiement simplifié
- ✅ Infrastructure as Code (IaC)

## 📁 Structure du projet

```
TicketingOntheFly/
├── config/                 # Fichiers de configuration
│   └── traefik/           # Configuration Traefik
├── data/                   # Données persistantes des services
│   ├── portainer/
│   ├── zammad/
│   ├── openldap/
│   ├── wikijs/
│   ├── prometheus/
│   └── grafana/
├── .env                    # Variables d'environnement (IMPORTANT: ne pas committer!)
├── docker-compose.yml      # Définition de tous les services
└── README.md              # Ce fichier
```

## 🚀 Prérequis

- **Docker** (version 20.10 ou supérieure)
- **Docker Compose** (version 2.0 ou supérieure)

### Vérification de l'installation

```bash
docker --version
docker-compose --version
```

## ⚙️ Configuration initiale

### 1. Configurer le fichier `.env`

Le fichier `.env` contient toutes les variables de configuration sensibles. **Personnalisez-le avant le premier lancement** :

```bash
# Modifiez les valeurs suivantes dans le fichier .env :
DOMAIN=votre-domaine.com          # Votre nom de domaine
TZ=Europe/Paris                    # Votre fuseau horaire
POSTGRES_PASSWORD=VotreMotDePasse  # Un mot de passe fort pour PostgreSQL
```

### 2. Lancer l'infrastructure

```bash
# Depuis la racine du projet
docker-compose up -d
```

Cette commande va :
- Télécharger les images Docker nécessaires
- Créer les volumes de données persistantes
- Créer le réseau Docker dédié
- Démarrer tous les conteneurs en arrière-plan

### 3. Vérifier l'état des conteneurs

```bash
docker-compose ps
```

Tous les services doivent être dans l'état "Up" ou "running".

## 🌐 Accès aux services

### Portainer (Gestion Docker)
- **URL** : https://localhost:9443
- **Premier accès** : Créez un compte administrateur (conservez bien le mot de passe!)
- **Description** : Interface web pour gérer vos conteneurs Docker

### phpLDAPadmin (Gestion OpenLDAP)
- **URL** : http://localhost:8080
- **Login DN** : `cn=admin,dc=localhost` (adaptez selon votre domaine dans `.env`)
- **Mot de passe** : Celui défini dans `LDAP_ADMIN_PASSWORD` du fichier `.env`
- **Description** : Interface web pour gérer l'annuaire LDAP (utilisateurs et groupes)

> ⚠️ **Note de sécurité** : Le certificat SSL de Portainer est auto-signé. Votre navigateur affichera un avertissement - c'est normal pour un environnement de développement local.

### Zammad (Ticketing)
- **URL** : http://localhost:8081
- **Premier accès** : Suivez l'assistant pour créer le compte administrateur Zammad
- **Note** : Le premier démarrage peut prendre 5–10 minutes (initialisation DB + indexation Elasticsearch)

## 🔧 Commandes utiles

### Consulter les logs d'un service

```bash
docker-compose logs -f portainer
```

### Arrêter tous les services

```bash
docker-compose down
```

### Redémarrer un service spécifique

```bash
docker-compose restart portainer
```

### Mettre à jour les images Docker

```bash
docker-compose pull
docker-compose up -d
```

## 🔍 Dépannage

### Erreur 403 sur phpLDAPadmin ou autres services
- Vérifiez que les services sont bien démarrés : `docker-compose ps`
- Assurez-vous d'utiliser HTTP (pas HTTPS) pour phpLDAPadmin
- Pour phpLDAPadmin, utilisez : http://localhost:8080

### Zammad ne démarre pas / zammad-init en boucle
- Vérifiez les logs : `docker logs zammad-init`
- **Attention** : Les mots de passe dans `.env` ne doivent PAS contenir de caractères spéciaux comme `!` qui peuvent être mal interprétés
- Si nécessaire, supprimez les volumes et redémarrez :
```bash
docker-compose down
docker volume rm ticketingonthefly_postgres_data ticketingonthefly_zammad_data
docker-compose up -d
```

### zammad-nginx affiche en boucle « waiting for init container to finish install or update… »
- Cause la plus fréquente: la variable d'environnement `REDIS_URL` manque sur le conteneur `zammad-nginx`.
- Correction: ajoutez cette ligne dans `docker-compose.yml` sous `zammad-nginx.environment`:
	- `REDIS_URL=redis://zammad-redis:6379`
- Recréez ensuite le conteneur nginx:
```bash
docker compose up -d zammad-nginx
```

### Vérifier qu'un conteneur a bien terminé son initialisation
```bash
# Voir si zammad-init s'est terminé avec succès
docker ps -a --filter "name=zammad-init"
# Le status doit être "Exited (0)" pour un succès
```

## 📖 Documentation détaillée

### Service OpenLDAP (Annuaire centralisé)

#### Rôle
OpenLDAP est la base de données centrale pour toutes les identités du système. Tous les autres services (Zammad, Wiki.js, Grafana) se connecteront à cet annuaire pour authentifier les utilisateurs, permettant une gestion centralisée des comptes.

#### Configuration
Nouvelles variables dans le fichier `.env` :
- `LDAP_ADMIN_PASSWORD` : Mot de passe de l'administrateur LDAP
- `ORGANISATION_NAME` : Nom de votre organisation
- `DOMAIN` : Utilisé pour construire la base DN (dc=localhost → dc=localhost)

#### Structure de base
Après le premier lancement, créez la structure suivante dans phpLDAPadmin :
- `ou=users` : Pour stocker les utilisateurs
- `ou=groups` : Pour stocker les groupes

**Procédure de création :**
1. Connectez-vous à phpLDAPadmin (http://localhost:8080)
2. Cliquez sur votre base (dc=localhost ou votre domaine)
3. "Create new entry here" → "Generic: Organisational Unit"
4. Créez `users` puis répétez pour `groups`

#### Identifiants par défaut
- **DN administrateur** : `cn=admin,dc=localhost` (adaptez selon votre `DOMAIN`)
- **Mot de passe** : Défini dans `LDAP_ADMIN_PASSWORD` du fichier `.env`

---

Pour plus d'informations sur chaque composant :
- [Partie 1 : Fondations et Conteneurisation](docs/01-fondations.md)
- [Partie 2 : Gestion des identités avec OpenLDAP](docs/02-openldap.md) *(à venir)*
- [Partie 3 : Zammad et ticketing](docs/03-zammad.md) *(à venir)*

### Service Zammad (Ticketing & Base de connaissances)

#### Accès
- URL : http://localhost:8081
- Premier lancement : l'initialisation peut prendre 5 à 10 minutes (préparation DB, indexation ES).

#### Dépendances
- Base de données PostgreSQL (conteneur `zammad-db`)
- Elasticsearch (conteneur `zammad-elasticsearch`)
- Redis (conteneur `zammad-redis`) - pour le cache et les sessions

#### Architecture multi-services
Zammad utilise une architecture distribuée :
- **zammad-init** : Initialise la DB et effectue les migrations (s'arrête après succès)
- **zammad-railsserver** : Application Rails principale
- **zammad-websocket** : Gère les communications temps réel
- **zammad-scheduler** : Traite les tâches en arrière-plan
- **zammad-nginx** : Proxy inverse et point d'entrée HTTP

#### Intégration LDAP (via OpenLDAP)
Après création de l'admin Zammad via l'assistant:
- Paramètres → Intégrations → LDAP → Ajouter un hôte LDAP
- Hôte: `openldap`, Port: `389`
- Bind DN: `cn=admin,dc=localhost` (adaptez à votre domaine)
- Mot de passe: valeur de `LDAP_ADMIN_PASSWORD`
- Base DN utilisateurs: `ou=users,dc=localhost` (adaptez)
- Mappage attributs recommandés: uid → Login, givenName → Prénom, sn → Nom, mail → E-mail

Notes:
- Si Elasticsearch ne démarre pas, vérifiez le paramètre kernel `vm.max_map_count` dans WSL2 (requis: 262144).

## 🔐 Sécurité

- ⚠️ **Ne jamais committer le fichier `.env`** - il contient des informations sensibles
- 🔒 Utilisez des mots de passe forts pour tous les services
- 🌐 En production, configurez Traefik avec Let's Encrypt pour des certificats SSL valides
- 🛡️ Limitez l'exposition des ports aux seuls nécessaires

## 🛠️ Maintenance

### Sauvegardes

Les données persistantes sont stockées dans les volumes Docker et le dossier `./data/`. 

Pour sauvegarder :
```bash
# Arrêter les services
docker-compose down

# Sauvegarder le dossier data
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# Redémarrer les services
docker-compose up -d
```

### Mises à jour

```bash
# Récupérer les dernières versions
docker-compose pull

# Recréer les conteneurs avec les nouvelles images
docker-compose up -d
```

## 📝 État actuel du projet

### ✅ Partie 1 : Fondations (Complétée)
- [x] Structure de dossiers
- [x] Configuration Docker Compose
- [x] Variables d'environnement
- [x] Service Portainer opérationnel

### ✅ Partie 2 : OpenLDAP (Complétée)
- [x] Service OpenLDAP configuré
- [x] Interface phpLDAPadmin opérationnelle
- [x] Configuration pour gestion centralisée des identités

### ✅ Partie 3 : Zammad (Déployé)
- [x] Services PostgreSQL et Elasticsearch démarrés
- [x] Zammad accessible sur http://localhost:8081
- [x] Intégration LDAP prête côté Zammad

### 🔄 À venir
- [ ] Partie 4 : OCS Inventory
- [ ] Partie 5 : Wiki.js
- [ ] Partie 6 : Prometheus & Grafana
- [ ] Partie 7 : Traefik
- [ ] Partie 8 : MailHog

## 🤝 Contribution

Ce projet est conçu de manière modulaire. Chaque service peut être ajouté indépendamment.

## 📄 Licence

[À définir]

---

**Auteur** : Ianis  
**Dernière mise à jour** : Octobre 2025
