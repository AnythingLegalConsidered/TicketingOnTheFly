# 🚀 Guide de Démarrage Rapide - TicketingOnTheFly

**Déployer l'infrastructure complète en 10 minutes**

---

## ⚡ Prérequis (5 minutes)

### Installation Docker

```bash
# Installer Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Redémarrer la session
newgrp docker

# Vérifier
docker --version
docker-compose --version
```

---

## 🎯 Déploiement (5 minutes)

### 1. Cloner le projet

```bash
git clone https://github.com/AnythingLegalConsidered/TicketingOnTheFly.git
cd TicketingOnTheFly
```

### 2. Configurer le domaine

```bash
# Éditer .env
nano .env

# Modifier cette ligne :
DOMAIN=localhost  # ← Remplacer par votre domaine si nécessaire
```

**Pour des tests locaux :** Garder `localhost`  
**Pour la production :** Utiliser votre domaine (ex: `ticketing.monentreprise.com`)

### 3. Déployer l'infrastructure

```bash
# Lancer le script d'initialisation
chmod +x init.sh
./init.sh
```

**Le script va :**
- ✅ Créer les répertoires nécessaires
- ✅ Générer les fichiers de configuration
- ✅ Démarrer 19 services Docker
- ✅ Attendre que tout soit prêt

**⏱️ Temps d'attente :** 3-5 minutes

### 4. Vérifier le déploiement

```bash
# Voir l'état des services
docker-compose ps

# Tous les services doivent afficher "Up"
```

---

## 🌐 Accès aux Services

### URLs de développement (localhost)

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Zammad** (Ticketing) | http://zammad.localhost | À créer au 1er accès |
| **Wiki.js** (Documentation) | http://wiki.localhost | À créer au 1er accès |
| **Grafana** (Monitoring) | http://grafana.localhost | admin / GF_SECURITY_ADMIN_PASSWORD |
| **phpLDAPadmin** (LDAP) | http://ldap.localhost | cn=admin,dc=localhost / LDAP_ADMIN_PASSWORD |
| **Portainer** (Docker) | http://portainer.localhost | À créer au 1er accès |
| **Traefik** (Proxy) | http://traefik.localhost | - |
| **Prometheus** (Métriques) | http://prometheus.localhost | - |
| **MailHog** (Emails dev) | http://mail.localhost | - |

**💡 Astuce :** Les mots de passe sont dans le fichier `.env`

---

## 🔧 Configuration Initiale (Obligatoire)

### 1. Zammad - Premier accès

```
1. Aller sur http://zammad.localhost
2. Créer le compte administrateur :
   - Email : admin@localhost
   - Mot de passe : (choisir un mot de passe fort)
   - Nom : Admin Support
3. Configurer l'organisation :
   - Nom : Votre Entreprise
   - URL : http://zammad.localhost
4. Terminer la configuration initiale
```

### 2. Wiki.js - Premier accès

```
1. Aller sur http://wiki.localhost
2. Choisir la langue : Français
3. Créer le compte administrateur :
   - Email : admin@localhost
   - Mot de passe : (choisir un mot de passe fort)
4. Configuration terminée !
```

### 3. Portainer - Premier accès

```
1. Aller sur http://portainer.localhost
2. Créer le compte administrateur :
   - Nom d'utilisateur : admin
   - Mot de passe : (minimum 12 caractères)
3. Sélectionner "Docker" comme environnement
4. Se connecter à l'environnement local
```

---

## 👥 Créer des Utilisateurs (Manuel)

### Via phpLDAPadmin

```
1. Aller sur http://ldap.localhost
2. Se connecter :
   - Login : cn=admin,dc=localhost
   - Password : (LDAP_ADMIN_PASSWORD du .env)

3. Créer la structure :
   - Clic droit sur dc=localhost → Create new entry
   - Template : Organisational Unit
   - Name : users
   - Répéter pour "groups"

4. Créer un groupe :
   - Clic droit sur ou=groups → Create new entry
   - Template : groupOfNames
   - Name : support-n1

5. Créer un utilisateur :
   - Clic droit sur ou=users → Create new entry
   - Template : inetOrgPerson
   - Remplir : uid, cn, sn, mail, password
```

### Via Zammad (après LDAP)

```
1. Aller sur http://zammad.localhost
2. Admin → Manage → Security → LDAP
3. Add LDAP Source :
   - Name : OpenLDAP
   - Host : openldap
   - Port : 389
   - Bind User : cn=admin,dc=localhost
   - Bind Password : (LDAP_ADMIN_PASSWORD)
   - Base DN : dc=localhost
4. Configurer le mapping utilisateurs
5. Synchroniser
```

---

## 🎫 Créer un Premier Ticket

### En tant qu'utilisateur

```
1. Se connecter sur http://zammad.localhost
2. Cliquer sur "New Ticket"
3. Remplir :
   - Title : Mon premier ticket de test
   - Group : Support (par défaut)
   - Customer : Votre nom
   - Text : Ceci est un ticket de test
4. Cliquer "Submit"
```

### Par email (avec MailHog)

```bash
# Envoyer un email qui créera un ticket
docker-compose exec mailhog mail \
  -s "Problème de connexion" \
  -f "user@localhost" \
  support@localhost <<< "Je n'arrive pas à me connecter."

# Vérifier dans MailHog
# http://mail.localhost

# Le ticket sera créé automatiquement dans Zammad
```

---

## 📊 Surveillance et Monitoring

### Grafana - Créer un dashboard

```
1. http://grafana.localhost
2. Login : admin / (GF_SECURITY_ADMIN_PASSWORD)
3. Create → Import
4. Import via grafana.com :
   - ID : 1860 (Node Exporter Full)
   - Select Prometheus datasource
   - Import
5. Dashboard opérationnel !
```

### Prometheus - Vérifier les métriques

```
1. http://prometheus.localhost
2. Aller dans "Status" → "Targets"
3. Vérifier que tous les targets sont "UP"
4. Explorer les métriques disponibles
```

---

## 🔒 Sécurité Rapide

### Changements OBLIGATOIRES avant production

```bash
# Éditer .env
nano .env

# Changer ces mots de passe :
LDAP_ADMIN_PASSWORD=NouveauMotDePasse123!
POSTGRES_PASSWORD=AutreMotDePasse456!
ZAMMAD_DB_PASS=AutreMotDePasse456!
GF_SECURITY_ADMIN_PASSWORD=GrafanaSecure789!

# Redémarrer les services
docker-compose down
docker-compose up -d
```

### Générer des mots de passe sécurisés

```bash
# Générer 5 mots de passe aléatoires
for i in {1..5}; do openssl rand -base64 20; done
```

---

## 🛠️ Commandes Utiles

### Gestion des services

```bash
# Voir l'état
docker-compose ps

# Voir les logs d'un service
docker-compose logs -f zammad-nginx

# Redémarrer un service
docker-compose restart zammad-nginx

# Arrêter tout
docker-compose down

# Démarrer tout
docker-compose up -d

# Supprimer tout (ATTENTION : perte de données)
docker-compose down -v
```

### Sauvegarde

```bash
# Sauvegarder toutes les données
./backup.sh

# Les sauvegardes sont dans :
# backups/backup-YYYYMMDD-HHMMSS/
```

### Restauration

```bash
# Arrêter les services
docker-compose down

# Restaurer depuis une sauvegarde
cp -r backups/backup-YYYYMMDD-HHMMSS/data/* data/

# Redémarrer
docker-compose up -d
```

---

## 🐛 Dépannage Rapide

### Un service ne démarre pas

```bash
# Voir les logs
docker-compose logs nom-du-service

# Redémarrer le service
docker-compose restart nom-du-service

# Si problème persiste, recréer le conteneur
docker-compose up -d --force-recreate nom-du-service
```

### Problème d'accès aux URLs

```bash
# Vérifier que Traefik est démarré
docker-compose ps traefik

# Voir les logs Traefik
docker-compose logs -f traefik

# Pour Windows : Ajouter dans C:\Windows\System32\drivers\etc\hosts
127.0.0.1 zammad.localhost
127.0.0.1 wiki.localhost
127.0.0.1 grafana.localhost
# etc.
```

### Base de données corrompue

```bash
# Arrêter les services
docker-compose down

# Supprimer UNIQUEMENT les volumes de la base concernée
docker volume rm ticketingonthefly_postgres_data

# Restaurer depuis backup
cp -r backups/backup-YYYYMMDD-HHMMSS/data/postgres data/

# Redémarrer
docker-compose up -d
```

### Manque d'espace disque

```bash
# Nettoyer Docker
docker system prune -a --volumes

# Attention : Supprime les images/conteneurs/volumes non utilisés
# Sauvegarder avant !
```

---

## 📚 Documentation Complète

Pour aller plus loin :

| Document | Description |
|----------|-------------|
| **README.md** | Vue d'ensemble du projet |
| **doc/POST-INSTALLATION.md** | Configuration détaillée après déploiement |
| **doc/GUIDE-PERSONNALISATION.md** | Personnaliser le projet (domaine, groupes, users) |
| **doc/10 - Configuration Automatisée.md** | Scripts d'automatisation Phase 10 |
| **CHANGELOG.md** | Historique complet de toutes les phases |

---

## ✅ Checklist de Démarrage

### Installation
- [ ] Docker installé
- [ ] Projet cloné
- [ ] `.env` configuré (DOMAIN)
- [ ] `./init.sh` exécuté
- [ ] Tous les services "Up"

### Configuration Initiale
- [ ] Zammad : Admin créé
- [ ] Wiki.js : Admin créé
- [ ] Portainer : Admin créé
- [ ] phpLDAPadmin : Connecté et structure créée

### Premiers Pas
- [ ] Utilisateur LDAP créé
- [ ] Groupe LDAP créé
- [ ] Zammad : LDAP configuré et synchronisé
- [ ] Premier ticket créé
- [ ] Dashboard Grafana importé

### Sécurité
- [ ] Tous les mots de passe .env changés
- [ ] Backup testé
- [ ] Accès restreints configurés

---

## 🎉 Félicitations !

Votre infrastructure de ticketing est opérationnelle !

**Prochaines étapes :**
1. ✅ Créer vos groupes LDAP (support-n1, support-n2, etc.)
2. ✅ Créer vos utilisateurs LDAP
3. ✅ Configurer l'intégration LDAP dans Zammad
4. ✅ Configurer les emails entrants/sortants
5. ✅ Personnaliser Wiki.js avec votre documentation
6. ✅ Configurer les alertes Grafana

**Besoin d'aide ?**
- Consultez la documentation complète dans `doc/`
- Vérifiez le CHANGELOG.md pour les détails techniques

---

**TicketingOnTheFly - De zéro à production-ready en 10 minutes** 🚀
