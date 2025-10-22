# 📜 Scripts de Configuration Automatisée - TicketingOnTheFly

Documentation des scripts de la Phase 10 pour la configuration automatique de LDAP et Zammad.

---

## 📁 Structure

```
scripts/
├── config.yaml           # Configuration centralisée (À PERSONNALISER)
├── config.yaml.example   # Exemple avec valeurs par défaut
├── .gitignore            # Protection des mots de passe
├── setup-ldap.sh         # Configuration automatique OpenLDAP
├── setup-zammad.sh       # Configuration automatique Zammad
└── README.md             # Cette documentation

configure-all.sh          # Script orchestrateur principal (à la racine)
```

---

## 🚀 Utilisation Rapide

### 1. Déployer l'infrastructure

```bash
./init.sh
```

### 2. Personnaliser la configuration (optionnel)

```bash
nano scripts/config.yaml
```

Modifier :
- Groupes LDAP (support-n1, support-n2, etc.)
- Utilisateurs LDAP (uid, mot de passe, groupes)
- Groupes Zammad (mapping 1:1)

### 3. Lancer la configuration automatique

```bash
./configure-all.sh
```

**Le script va :**
- ✅ Créer la structure LDAP (ou=users, ou=groups)
- ✅ Créer les groupes LDAP
- ✅ Créer les utilisateurs LDAP
- ✅ Assigner les utilisateurs aux groupes
- ✅ Créer les groupes Zammad
- ✅ Configurer l'intégration LDAP
- ✅ Vérifier la configuration

⏱️ **Temps d'exécution :** 2-3 minutes

---

## 📋 Configuration par Défaut

### Groupes LDAP (4)

| Nom | Description | Utilisateurs par défaut |
|-----|-------------|-------------------------|
| support-n1 | Support Niveau 1 | tech1, tech2 |
| support-n2 | Support Niveau 2 | expert1, expert2, admin.support |
| administrateurs | Administrateurs système | admin.support |
| utilisateurs | Utilisateurs finaux | user1, user2, user3 |

### Utilisateurs LDAP (8)

| UID | Nom | Email | Mot de passe | Groupes |
|-----|-----|-------|--------------|---------|
| tech1 | Pierre Martin | pierre.martin@localhost | TechN1Pass123! | support-n1 |
| tech2 | Marie Dubois | marie.dubois@localhost | TechN1Pass123! | support-n1 |
| expert1 | Jean Dupont | jean.dupont@localhost | TechN2Pass123! | support-n2 |
| expert2 | Sophie Bernard | sophie.bernard@localhost | TechN2Pass123! | support-n2 |
| admin.support | Admin Support | admin.support@localhost | AdminPass123! | administrateurs, support-n2 |
| user1 | Alice Leclerc | alice.leclerc@localhost | UserPass123! | utilisateurs |
| user2 | Bob Rousseau | bob.rousseau@localhost | UserPass123! | utilisateurs |
| user3 | Claire Moreau | claire.moreau@localhost | UserPass123! | utilisateurs |

⚠️ **Important :** Changer les mots de passe avant la production !

---

## 🔧 Personnalisation

### Ajouter un utilisateur

```yaml
# Dans scripts/config.yaml

ldap:
  users:
    # ... utilisateurs existants ...
    
    # Nouvel utilisateur
    - uid: "nouveau.tech"
      firstName: "Nouveau"
      lastName: "Technicien"
      email: "nouveau.tech@monentreprise.com"
      password: "SecurePass456!"
      groups: ["support-n2"]
```

Relancer : `./configure-all.sh`

### Ajouter un groupe

```yaml
# Dans scripts/config.yaml

# 1. Groupe LDAP
ldap:
  groups:
    - name: "support-vip"
      description: "Support prioritaire VIP"

# 2. Groupe Zammad (mapping 1:1 - MÊME NOM)
zammad:
  groups:
    - name: "support-vip"  # ← Même nom que LDAP
      display_name: "Support VIP"
      note: "Clients prioritaires"
      email_address: "vip@monentreprise.com"
      assignment_timeout: 15
      follow_up_possible: "yes"
      active: true

# 3. Mapping de rôle
zammad:
  ldap_integration:
    role_mapping:
      support-vip: "Agent"  # Ou "Admin" ou "Customer"
```

Relancer : `./configure-all.sh`

### Modifier un mot de passe

```yaml
# Dans scripts/config.yaml

ldap:
  users:
    - uid: "tech1"
      # ... autres champs ...
      password: "NouveauMotDePasse123!"  # ← Modifier ici
```

Relancer : `./configure-all.sh`

---

## 🔍 Vérification

### Via phpLDAPadmin (Interface web)

```
URL : http://ldap.localhost
Login : cn=admin,dc=localhost
Password : (LDAP_ADMIN_PASSWORD du fichier .env)

Naviguer :
• dc=localhost
  ├── ou=users (voir tous les utilisateurs)
  └── ou=groups (voir tous les groupes)
```

### Via ligne de commande

```bash
# Lister tous les utilisateurs
docker-compose exec openldap ldapsearch -x -b "ou=users,dc=localhost"

# Lister tous les groupes
docker-compose exec openldap ldapsearch -x -b "ou=groups,dc=localhost"

# Vérifier qu'un utilisateur existe
docker-compose exec openldap ldapsearch -x -b "ou=users,dc=localhost" "(uid=tech1)"
```

### Via Zammad

```
1. Se connecter sur http://zammad.localhost
2. Admin → Manage → Groups (vérifier que les groupes existent)
3. Admin → Manage → Security → LDAP (vérifier la connexion)
4. Synchroniser : Admin → Manage → Security → LDAP → Synchronize
```

---

## 🐛 Dépannage

### yq n'est pas installé

```bash
# Installation automatique lors du premier lancement
# Ou installation manuelle :

# Via snap
sudo snap install yq

# Ou via wget
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### Les utilisateurs LDAP ne se synchronisent pas dans Zammad

```bash
# 1. Vérifier que la source LDAP est active
docker-compose exec zammad-railsserver rails r "puts Ldap.all.pluck(:name, :active)"

# 2. Forcer la synchronisation
docker-compose exec zammad-railsserver rails r "Ldap.first.preferences[:sync] = true; Ldap.first.save"

# 3. Relancer Zammad
docker-compose restart zammad-railsserver zammad-websocket
```

### Erreur "Can't connect to LDAP"

```bash
# Vérifier qu'OpenLDAP est accessible
docker-compose exec zammad-railsserver ping -c 3 openldap

# Vérifier les logs OpenLDAP
docker-compose logs openldap

# Vérifier le mot de passe admin LDAP
grep LDAP_ADMIN_PASSWORD .env
```

### Groupes créés mais vides

```bash
# Les utilisateurs doivent être assignés manuellement après création
# Relancer le script complet :
./configure-all.sh

# Ou assigner manuellement via phpLDAPadmin
```

---

## 📚 Documentation Complète

Pour plus de détails, consulter :

- **doc/10 - Configuration Automatisée.md** : Documentation technique complète
- **doc/GUIDE-PERSONNALISATION.md** : Guide de personnalisation complet
- **doc/QUICK-START.md** : Guide de démarrage rapide
- **CHANGELOG.md** : Historique complet du projet

---

## 🔒 Sécurité

### Protection des mots de passe

Le fichier `config.yaml` contient des mots de passe en clair et est **exclus de Git** via `.gitignore`.

**Bonnes pratiques :**

1. ✅ Ne jamais committer `config.yaml` avec des vrais mots de passe
2. ✅ Utiliser `config.yaml.example` comme template
3. ✅ Changer TOUS les mots de passe avant la production
4. ✅ Utiliser des mots de passe forts (≥16 caractères)

### Générer des mots de passe sécurisés

```bash
# Générer un mot de passe aléatoire
openssl rand -base64 20

# Générer plusieurs mots de passe
for i in {1..5}; do openssl rand -base64 20; done
```

---

## ✅ Checklist

### Avant d'exécuter les scripts

- [ ] Infrastructure déployée (`./init.sh` exécuté)
- [ ] Fichier `config.yaml` personnalisé
- [ ] Mots de passe modifiés
- [ ] Groupes et utilisateurs définis

### Après exécution

- [ ] OpenLDAP : Structure créée (ou=users, ou=groups)
- [ ] OpenLDAP : Groupes créés
- [ ] OpenLDAP : Utilisateurs créés
- [ ] Zammad : Groupes créés
- [ ] Zammad : Intégration LDAP active
- [ ] Zammad : Utilisateurs synchronisés
- [ ] Test de connexion avec un utilisateur LDAP

---

**TicketingOnTheFly - Configuration automatisée en 2-3 minutes** 🚀
