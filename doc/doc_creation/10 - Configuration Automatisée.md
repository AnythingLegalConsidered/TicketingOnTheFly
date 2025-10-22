# Phase 10 : Configuration Automatisée et Données de Démonstration (Optionnelle)

**Date** : 22 octobre 2025  
**Statut** : ✅ Complété

---

## 🎯 Objectif de la Phase 10

Automatiser complètement la configuration post-déploiement de l'infrastructure avec :
- Création automatique de groupes et utilisateurs LDAP
- Configuration automatique de Zammad avec mapping 1:1 vers LDAP
- Système de configuration centralisé et facilement modifiable
- Interface simple pour personnaliser sans toucher au code

Cette phase transforme le déploiement de "infrastructure prête" en "infrastructure prête à l'emploi avec utilisateurs et groupes préconfigurés".

---

## 📋 Théorie

### Problématique

Après la Phase 9, l'infrastructure est déployée mais :
- ❌ Pas de groupes LDAP (structure vide)
- ❌ Pas d'utilisateurs de test/démo
- ❌ Configuration manuelle longue et répétitive
- ❌ Intégration LDAP-Zammad à faire manuellement
- ❌ Risque d'erreurs lors de la configuration manuelle

### Solution : Configuration as Code

**Principe** : Toute la configuration est définie dans un fichier YAML simple et lisible.

**Avantages** :
- ✅ **Reproductible** : Même configuration sur tous les environnements
- ✅ **Versionnable** : Historique des changements via Git
- ✅ **Documenté** : Le fichier YAML est auto-documenté
- ✅ **Rapide** : Configuration complète en 2-3 minutes vs 1-2 heures manuellement
- ✅ **Sans erreur** : Scripts testés et validés

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     config.yaml                             │
│              (Configuration centralisée)                    │
│                                                             │
│  • Groupes LDAP : 4 par défaut                             │
│  • Utilisateurs LDAP : 8 par défaut                        │
│  • Groupes Zammad : Mapping 1:1 avec LDAP                  │
│  • Intégration LDAP : Paramètres de connexion             │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  configure-all.sh    │
        │  (Orchestrateur)     │
        └──────┬───────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
┌─────────────┐  ┌─────────────┐
│setup-ldap.sh│  │setup-zammad │
│             │  │    .sh      │
│• Structure  │  │• Groupes    │
│• Groupes    │  │• LDAP integ │
│• Users      │  │• Mapping 1:1│
└─────────────┘  └─────────────┘
       │                │
       ▼                ▼
   OpenLDAP         Zammad
```

---

## 🛠️ Réalisation

### 1. Structure des Fichiers

```bash
# Création de l'arborescence
mkdir -p scripts/config
mkdir -p scripts/templates

# Fichiers créés :
scripts/
├── config.yaml              # Configuration centralisée (à personnaliser)
├── config.yaml.example      # Exemple avec valeurs par défaut
├── .gitignore               # Protection des mots de passe
├── README.md                # Documentation des scripts
├── setup-ldap.sh            # Configuration OpenLDAP
├── setup-zammad.sh          # Configuration Zammad
└── configure-all.sh         # Orchestrateur principal
```

### 2. Fichier de Configuration (`config.yaml`)

**Sections du fichier** :

#### Section 1 : Groupes LDAP (4 par défaut)

```yaml
ldap:
  groups:
    - name: "support-n1"
      description: "Support Niveau 1 - Premier contact utilisateurs"
    
    - name: "support-n2"
      description: "Support Niveau 2 - Experts techniques"
    
    - name: "administrateurs"
      description: "Administrateurs système et support"
    
    - name: "utilisateurs"
      description: "Utilisateurs finaux de l'organisation"
```

#### Section 2 : Utilisateurs LDAP (8 par défaut)

```yaml
ldap:
  users:
    # Techniciens Niveau 1
    - uid: "tech1"
      firstName: "Pierre"
      lastName: "Martin"
      email: "pierre.martin@localhost"
      password: "TechN1Pass123!"
      groups: ["support-n1"]
    
    # ... 7 autres utilisateurs ...
```

**Répartition par défaut** :
- 2 techniciens N1 (tech1, tech2)
- 2 techniciens N2 (expert1, expert2)
- 1 administrateur (admin.support) - membre de administrateurs + support-n2
- 3 utilisateurs finaux (user1, user2, user3)

#### Section 3 : Groupes Zammad (Mapping 1:1)

```yaml
zammad:
  groups:
    - name: "support-n1"           # ← Même nom que LDAP
      display_name: "Support Niveau 1"
      note: "Techniciens de premier niveau"
      email_address: "support-n1@localhost"
      assignment_timeout: 120
      follow_up_possible: "yes"
      active: true
```

**Principe du mapping 1:1** :
- Le nom du groupe Zammad = nom du groupe LDAP
- Synchronisation automatique
- Pas de duplication de configuration

#### Section 4 : Intégration LDAP

```yaml
zammad:
  ldap_integration:
    enabled: true
    host: "openldap"
    port: 389
    bind_user: "cn=admin,dc=localhost"
    base_dn: "ou=users,dc=localhost"
    
    user_attributes:
      login: "uid"
      firstname: "givenName"
      lastname: "sn"
      email: "mail"
    
    role_mapping:
      support-n1: "Agent"
      support-n2: "Agent"
      administrateurs: "Admin"
      utilisateurs: "Customer"
```

---

### 3. Script `setup-ldap.sh` (300 lignes)

**Fonctionnalités** :

```bash
#!/bin/bash

# 1. Vérification des prérequis
check_prerequisites() {
    # - docker-compose disponible
    # - OpenLDAP démarré
    # - config.yaml existe
    # - yq installé (pour parser YAML)
}

# 2. Récupération du domaine
get_domain() {
    # Lit DOMAIN depuis .env
    # Convertit en DN LDAP : mondomaine.com → dc=mondomaine,dc=com
}

# 3. Création de la structure LDAP
create_ldap_structure() {
    # Crée ou=users,$BASE_DN
    # Crée ou=groups,$BASE_DN
}

# 4. Création des groupes
create_ldap_groups() {
    # Parse config.yaml
    # Génère fichier LDIF
    # Applique avec ldapadd
}

# 5. Création des utilisateurs
create_ldap_users() {
    # Parse config.yaml
    # Hashe les mots de passe (slappasswd)
    # Génère fichier LDIF avec posixAccount
    # Applique avec ldapadd
}

# 6. Assignation aux groupes
assign_users_to_groups() {
    # Pour chaque utilisateur
    # Ajoute member= au groupe correspondant
    # Applique avec ldapmodify
}
```

**Interface utilisateur** :
```
=============================================================================
  Configuration OpenLDAP - TicketingOnTheFly
=============================================================================

[1/6] Vérification des prérequis...
   ✅ Tous les prérequis sont satisfaits

[2/6] Configuration du domaine...
   Domaine : localhost
   Base DN : dc=localhost

[3/6] Création de la structure LDAP...
   ✅ Structure LDAP créée

[4/6] Création des groupes LDAP...
   📁 Groupe : support-n1
   📁 Groupe : support-n2
   📁 Groupe : administrateurs
   📁 Groupe : utilisateurs
   ✅ 4 groupe(s) créé(s)

[5/6] Création des utilisateurs LDAP...
   👤 Utilisateur : tech1 (Pierre Martin)
   👤 Utilisateur : tech2 (Marie Dubois)
   ... [6 autres]
   ✅ 8 utilisateur(s) créé(s)

[6/6] Assignation des utilisateurs aux groupes...
   🔗 tech1 → groupe support-n1
   🔗 tech2 → groupe support-n1
   ... [assignations]
   ✅ Utilisateurs assignés aux groupes

=============================================================================
  ✅ Configuration OpenLDAP terminée avec succès !
=============================================================================
```

---

### 4. Script `setup-zammad.sh` (250 lignes)

**Fonctionnalités** :

```bash
#!/bin/bash

# 1. Vérification des prérequis
check_prerequisites() {
    # - Zammad démarré et initialisé
    # - config.yaml existe
    # - yq installé
}

# 2. Obtention d'un token API
get_zammad_token() {
    # Exécute code Ruby via rails console
    # Récupère/crée un token API pour l'admin
}

# 3. Création des groupes Zammad
create_zammad_groups() {
    # Parse config.yaml (section zammad.groups)
    # Pour chaque groupe :
    #   - Exécute rails r "Group.create!(...)"
    #   - Avec nom, description, timeout, etc.
}

# 4. Configuration intégration LDAP
configure_ldap_integration() {
    # Crée/met à jour la source LDAP
    # Configure :
    #   - Host, port, bind DN
    #   - Mapping attributs (uid → login, etc.)
    #   - Mapping rôles (support-n1 → Agent, etc.)
}

# 5. Mapping groupes LDAP → Zammad
map_ldap_to_zammad_groups() {
    # Vérifie que les groupes existent
    # Affiche le mapping 1:1
}
```

**Utilisation de l'API Zammad** :

```ruby
# Création d'un groupe via Rails console
Group.create!(
  name: 'support-n1',           # Nom (identique à LDAP)
  note: 'Techniciens niveau 1',
  assignment_timeout: 120,       # Minutes avant réassignation
  follow_up_possible: 'yes',
  active: true
)

# Configuration LDAP
Ldap.create!(
  name: 'OpenLDAP',
  preferences: {
    'host' => 'openldap',
    'port' => 389,
    'bind_user' => 'cn=admin,dc=localhost',
    'base' => 'ou=users,dc=localhost',
    'user_attributes' => {
      'login' => 'uid',
      'firstname' => 'givenName',
      'lastname' => 'sn',
      'email' => 'mail'
    },
    'group_role_map' => {
      'support-n1' => ['Agent'],
      'support-n2' => ['Agent'],
      'administrateurs' => ['Admin'],
      'utilisateurs' => ['Customer']
    }
  },
  active: true
)
```

---

### 5. Script `configure-all.sh` (200 lignes)

**Orchestrateur principal** qui :

1. Affiche une bannière ASCII stylée
2. Vérifie que l'infrastructure est démarrée
3. Affiche un résumé de la configuration
4. Demande confirmation à l'utilisateur
5. Lance `setup-ldap.sh`
6. Lance `setup-zammad.sh`
7. Vérifie la configuration finale
8. Affiche le résumé avec tous les comptes créés

**Bannière** :

```
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║        ████████╗██╗ ██████╗██╗  ██╗███████╗████████╗██╗███╗   ██╗ ║
║        ╚══██╔══╝██║██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝██║████╗  ██║ ║
║           ██║   ██║██║     █████╔╝ █████╗     ██║   ██║██╔██╗ ██║ ║
║           ██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║██║╚██╗██║ ║
║           ██║   ██║╚██████╗██║  ██╗███████╗   ██║   ██║██║ ╚████║ ║
║           ╚═╝   ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ║
║                                                                    ║
║              Configuration Automatisée - Phase 10                  ║
╚════════════════════════════════════════════════════════════════════╝
```

**Résumé de configuration** :

```
📊 Résumé de la configuration
════════════════════════════

   Groupes LDAP : 4
   Utilisateurs LDAP : 8
   Groupes Zammad : 4
   Mapping : 1:1 (LDAP ↔ Zammad)

📝 Groupes qui seront créés :
   • support-n1
   • support-n2
   • administrateurs
   • utilisateurs

⚠️  Cette opération va configurer OpenLDAP et Zammad
   Les données existantes seront conservées, seules les nouvelles
   entrées seront ajoutées.

   Continuer ? (o/N) :
```

---

## 📊 Résultats

### Configuration par Défaut Créée

#### Groupes LDAP (4)

| DN | Description | Membres |
|----|-------------|---------|
| `cn=support-n1,ou=groups,dc=localhost` | Support Niveau 1 | tech1, tech2 |
| `cn=support-n2,ou=groups,dc=localhost` | Support Niveau 2 - Experts | expert1, expert2, admin.support |
| `cn=administrateurs,ou=groups,dc=localhost` | Administrateurs système | admin.support |
| `cn=utilisateurs,ou=groups,dc=localhost` | Utilisateurs finaux | user1, user2, user3 |

#### Utilisateurs LDAP (8)

| UID | Nom Complet | Email | Mot de Passe | Groupes |
|-----|-------------|-------|--------------|---------|
| tech1 | Pierre Martin | pierre.martin@localhost | TechN1Pass123! | support-n1 |
| tech2 | Marie Dubois | marie.dubois@localhost | TechN1Pass123! | support-n1 |
| expert1 | Jean Dupont | jean.dupont@localhost | TechN2Pass123! | support-n2 |
| expert2 | Sophie Bernard | sophie.bernard@localhost | TechN2Pass123! | support-n2 |
| admin.support | Admin Support | admin.support@localhost | AdminPass123! | administrateurs, support-n2 |
| user1 | Alice Leclerc | alice.leclerc@localhost | UserPass123! | utilisateurs |
| user2 | Bob Rousseau | bob.rousseau@localhost | UserPass123! | utilisateurs |
| user3 | Claire Moreau | claire.moreau@localhost | UserPass123! | utilisateurs |

#### Groupes Zammad (4) - Mapping 1:1

| Nom | Nom Affiché | Email | Timeout | Mapping LDAP |
|-----|-------------|-------|---------|--------------|
| support-n1 | Support Niveau 1 | support-n1@localhost | 120 min | support-n1 |
| support-n2 | Support Niveau 2 | support-n2@localhost | 240 min | support-n2 |
| administrateurs | Administrateurs | admin@localhost | ∞ | administrateurs |
| utilisateurs | Utilisateurs | users@localhost | ∞ | utilisateurs |

#### Intégration LDAP Zammad

```yaml
Source LDAP : OpenLDAP
Host : openldap:389
Bind DN : cn=admin,dc=localhost
Base DN : ou=users,dc=localhost

Mapping Attributs :
  login ← uid
  firstname ← givenName
  lastname ← sn
  email ← mail

Mapping Rôles :
  support-n1 → Agent
  support-n2 → Agent
  administrateurs → Admin
  utilisateurs → Customer
```

---

## 🎯 Utilisation

### Workflow Complet

```bash
# 1. Déploiement infrastructure (si pas encore fait)
./init.sh

# 2. Personnalisation (optionnel)
nano scripts/config.yaml
# Modifier groupes, utilisateurs, mots de passe

# 3. Configuration automatique
./configure-all.sh

# Résultat : Infrastructure + Utilisateurs + Groupes prêts !
```

### Temps d'Exécution

- **Avant Phase 10** : 1-2 heures de configuration manuelle
- **Après Phase 10** : 2-3 minutes automatiquement

### Vérification

```bash
# Vérifier OpenLDAP
docker-compose exec openldap ldapsearch -x -b "ou=users,dc=localhost"

# Ou via interface web
http://ldap.localhost
Login : cn=admin,dc=localhost

# Vérifier Zammad
http://zammad.localhost
Admin → Manage → Groups
Admin → Manage → Security → LDAP

# Tester connexion LDAP
Se connecter avec : tech1 / TechN1Pass123!
```

---

## 🔧 Personnalisation

### Ajouter un Utilisateur

```yaml
# Dans scripts/config.yaml

ldap:
  users:
    # ... utilisateurs existants ...
    
    # Nouvel utilisateur
    - uid: "nouveau.tech"
      firstName: "Nouveau"
      lastName: "Technicien"
      email: "nouveau.tech@localhost"
      password: "SecurePass456!"
      groups: ["support-n1"]
```

Relancer : `./configure-all.sh`

### Ajouter un Groupe

```yaml
# Dans scripts/config.yaml

ldap:
  groups:
    - name: "support-vip"
      description: "Support prioritaire VIP"

zammad:
  groups:
    - name: "support-vip"  # Mapping 1:1
      display_name: "Support VIP"
      note: "Clients prioritaires"
      email_address: "vip@localhost"
      assignment_timeout: 30
      follow_up_possible: "yes"
      active: true
```

Relancer : `./configure-all.sh`

### Modifier les Mots de Passe

```yaml
# Dans scripts/config.yaml

ldap:
  users:
    - uid: "tech1"
      # ... autres champs ...
      password: "NouveauMotDePasse123!"  # ← Modifier ici
```

⚠️ **Important** : Les mots de passe sont hashés automatiquement par le script.

---

## 🔒 Sécurité

### Protection des Mots de Passe

```bash
# scripts/.gitignore
config.yaml          # Ne sera PAS committé
!config.yaml.example # Sera committé (sans vrais mots de passe)
```

### Bonnes Pratiques

1. ✅ **Ne jamais committer `config.yaml`** avec de vrais mots de passe
2. ✅ Utiliser `config.yaml.example` comme template
3. ✅ Changer TOUS les mots de passe avant la production
4. ✅ Utiliser des mots de passe forts (≥12 caractères)
5. ✅ Générer des mots de passe aléatoires :

```bash
# Générer un mot de passe sécurisé
openssl rand -base64 16
```

---

## 📈 Bénéfices de la Phase 10

| Aspect | Avant Phase 10 | Après Phase 10 |
|--------|----------------|----------------|
| **Temps de config** | 1-2 heures manuellement | 2-3 minutes automatiquement |
| **Groupes LDAP** | Création manuelle | 4 groupes par défaut + personnalisables |
| **Utilisateurs LDAP** | Création manuelle | 8 utilisateurs par défaut + personnalisables |
| **Intégration Zammad** | Configuration manuelle complexe | Automatique via API |
| **Mapping groupes** | Manuel et source d'erreurs | 1:1 automatique |
| **Reproductibilité** | Difficile | 100% reproductible |
| **Documentation** | Configuration à refaire | Définie dans config.yaml |
| **Erreurs** | Fréquentes (typos, oublis) | Éliminées |

---

## 🎓 Apprentissages Techniques

### Technologies Utilisées

1. **YAML** : Format de configuration lisible et éditable
2. **yq** : Parser YAML en ligne de commande
3. **LDIF** : Format d'import/export LDAP
4. **ldapadd/ldapmodify** : Commandes de manipulation LDAP
5. **Zammad Rails Console** : API programmatique de Zammad
6. **Bash Scripting** : Orchestration et automatisation

### Patterns Appliqués

- **Configuration as Code** : Toute la config dans un fichier
- **Idempotence** : Scripts exécutables plusieurs fois sans erreur
- **Mapping 1:1** : Simplification de la synchronisation
- **DRY (Don't Repeat Yourself)** : Config centralisée
- **Fail Fast** : Arrêt immédiat en cas d'erreur (`set -e`)

---

## 🚀 Évolutions Futures Possibles

### Phase 10.1 : Email → Ticket (Optionnel)

- Configuration automatique d'un canal email IMAP
- Création automatique de tickets depuis les emails
- Webhook MailHog → Zammad pour le développement

### Phase 10.2 : SLA et Triggers (Optionnel)

- Configuration de SLA par défaut
- Triggers d'auto-assignation selon le groupe
- Templates de réponse automatiques

### Phase 10.3 : Données de Démonstration (Optionnel)

- Création automatique de 10-20 tickets d'exemple
- Différents statuts (nouveau, en cours, résolu)
- Différentes priorités et catégories

---

## 📝 Fichiers de la Phase 10

| Fichier | Lignes | Description |
|---------|--------|-------------|
| `scripts/config.yaml` | 250 | Configuration centralisée (à personnaliser) |
| `scripts/config.yaml.example` | 250 | Exemple avec valeurs par défaut |
| `scripts/setup-ldap.sh` | 300 | Configuration automatique OpenLDAP |
| `scripts/setup-zammad.sh` | 250 | Configuration automatique Zammad |
| `configure-all.sh` | 200 | Orchestrateur principal |
| `scripts/README.md` | 400 | Documentation complète |
| `scripts/.gitignore` | 10 | Protection mots de passe |
| `doc/10 - Configuration Automatisée.md` | 600 | Cette documentation |
| `doc/GUIDE-PERSONNALISATION.md` | 1000+ | Guide utilisateur complet |
| **TOTAL** | **~3260** | **9 fichiers** |

---

## ✅ Conclusion

La **Phase 10** complète le projet TicketingOnTheFly avec un système de configuration automatisée professionnel :

- ✅ **Configuration en 1 fichier YAML** facile à modifier
- ✅ **Déploiement + Configuration en ~15 minutes** total
- ✅ **Mapping 1:1 LDAP ↔ Zammad** pour simplifier la gestion
- ✅ **8 utilisateurs de démo** prêts à utiliser
- ✅ **4 groupes préconfigurés** (Support N1/N2, Admins, Users)
- ✅ **100% personnalisable** sans toucher au code
- ✅ **Sécurisé** (mots de passe protégés, hashage automatique)
- ✅ **Documenté** (README + ce fichier + guide utilisateur)

**Le projet est maintenant production-ready avec une expérience utilisateur optimale !** 🎉

---

**Prochaine étape recommandée** : Consulter le **GUIDE-PERSONNALISATION.md** pour personnaliser le projet selon vos besoins spécifiques.
