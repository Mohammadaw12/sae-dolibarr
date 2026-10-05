# SAE 5.1 — Déploiement et automatisation de Dolibarr

## 1. Présentation

Ce projet a été réalisé dans le cadre de la SAE 5.1 du BUT Réseaux & Télécommunications.

L'objectif est de déployer une solution **Dolibarr ERP/CRM** permettant la gestion des tiers, principalement :

* les clients ;
* les fournisseurs.

Le projet comprend :

* une phase d'installation manuelle de Dolibarr afin de comprendre son fonctionnement ;
* une automatisation du déploiement avec Docker ;
* une automatisation de l'import de clients et fournisseurs depuis des fichiers CSV ;
* une sauvegarde de la base et des données ;
* une restauration permettant de mettre en œuvre un plan de reprise d'activité (PRA) ;
* une documentation et un versionnement complet avec Git.

---

# 2. Architecture

L'architecture automatisée repose sur deux conteneurs Docker :

```text
                    Navigateur
                        |
                        | HTTP :8080
                        v
              +----------------------+
              |      Dolibarr        |
              |    Apache / PHP      |
              |     Port 80          |
              +----------+-----------+
                         |
                         | Réseau Docker
                         v
              +----------------------+
              |       MariaDB        |
              |     Base de données  |
              +----------------------+
```

Les données persistantes sont stockées dans des volumes locaux :

```text
volumes/
├── mariadb/
├── dolibarr_documents/
└── dolibarr_custom/
```

---

# 3. Prérequis

Le projet a été testé sur Debian 12.

Les éléments nécessaires sont :

* Debian 12 ;
* Docker ;
* Docker Compose ;
* Git ;
* Python 3 ;
* un navigateur web.

Vérifier Docker :

```bash
docker --version
```

Vérifier Docker Compose :

```bash
docker compose version
```

---

# 4. Récupération du projet

Cloner le dépôt Git :

```bash
git clone <URL_DU_DEPOT>
```

Entrer dans le projet :

```bash
cd sae-dolibarr
```

Le dépôt contient notamment :

```text
sae-dolibarr/
├── data/
├── scripts/
├── tools/
├── volumes/
├── backups/
├── .env.example
├── .gitignore
├── docker-compose.yml
├── readme.md
├── sources.md
└── suivi_projet.md
```

---

# 5. Configuration du fichier .env

Le fichier `.env` contient les paramètres sensibles du projet.

Il n'est volontairement pas versionné dans Git.

Créer le fichier à partir du modèle :

```bash
cp .env.example .env
```

Modifier ensuite le fichier :

```bash
nano .env
```

Exemple de configuration :

```env
MYSQL_ROOT_PASSWORD=CHANGE_ME
MYSQL_DATABASE=dolidb
MYSQL_USER=dolidbuser
MYSQL_PASSWORD=CHANGE_ME

DOLI_ADMIN_LOGIN=admin
DOLI_ADMIN_PASSWORD=CHANGE_ME
DOLI_URL_ROOT=http://localhost:8080

DOLI_API_KEY=CHANGE_ME
```

Les valeurs `CHANGE_ME` doivent être remplacées par les valeurs adaptées à l'environnement.

La clé API sera renseignée après la configuration de l'API REST.

⚠️ Le fichier `.env` contient des informations sensibles et ne doit jamais être publié sur GitHub.

---

# 6. Installation automatisée

L'installation complète est réalisée à l'aide du script :

```text
scripts/install.sh
```

Depuis la racine du projet :

```bash
./scripts/install.sh
```

Le script :

1. vérifie la présence du fichier `.env` ;
2. vérifie que Docker est installé ;
3. vérifie que Docker Compose est disponible ;
4. crée les répertoires nécessaires ;
5. démarre MariaDB ;
6. attend que MariaDB soit disponible ;
7. démarre Dolibarr ;
8. affiche l'état des conteneurs.

À la fin de l'installation, Dolibarr est accessible à :

```text
http://localhost:8080
```

Vérifier l'état des conteneurs :

```bash
docker compose ps
```

Les deux services doivent être `Up` :

```text
sae-dolibarr-db
sae-dolibarr-web
```

---

# 7. Première connexion à Dolibarr

Après l'installation, ouvrir :

```text
http://localhost:8080
```

Utiliser les identifiants administrateur définis dans le fichier `.env` :

```env
DOLI_ADMIN_LOGIN=admin
DOLI_ADMIN_PASSWORD=...
```

---

# 8. Configuration de l'API REST

L'import automatisé des clients et fournisseurs utilise l'API REST de Dolibarr.

## Activation

Dans Dolibarr :

```text
Configuration → Modules/Applications
```

Rechercher :

```text
API REST
```

Puis activer le module.

---

# 9. Création de l'utilisateur d'import

Créer un utilisateur dédié à l'import des données.

Dans Dolibarr :

```text
Utilisateurs & Groupes → Nouvel utilisateur
```

Exemple :

```text
Nom : Import CSV
Login : import
```

L'utilisateur doit disposer des droits nécessaires pour :

* consulter les tiers ;
* créer les tiers ;
* modifier les tiers.

Le droit de suppression des tiers n'est pas nécessaire.

Une clé API doit ensuite être générée pour cet utilisateur.

---

# 10. Configuration de la clé API

Dans le compte de l'utilisateur `Import CSV`, générer une clé API.

La clé doit ensuite être renseignée dans le fichier `.env` :

```env
DOLI_API_KEY=VOTRE_CLE_API
```

⚠️ Ne jamais publier cette clé dans Git ou dans le dépôt.

---

# 11. Test de l'API REST

Après configuration de la clé, charger les variables :

```bash
set -a
source .env
set +a
```

Tester l'accès à l'API :

```bash
curl -H "DOLAPIKEY: $DOLI_API_KEY" \
http://localhost:8080/api/index.php/thirdparties
```

Si aucun tiers n'existe encore, Dolibarr peut retourner :

```text
404 Not Found: No third parties found
```

Ce résultat signifie que l'API fonctionne mais qu'aucun tiers n'est encore enregistré.

---

# 12. Import des clients et fournisseurs

L'import est réalisé automatiquement grâce à :

```text
scripts/import_csv.sh
```

Le script utilise :

```text
tools/import_csv.py
```

Le script Python communique avec Dolibarr via l'API REST.

---

# 13. Format des fichiers CSV

Les fichiers CSV doivent contenir les colonnes suivantes :

```text
name,address,zip,town,phone,email
```

Exemple :

```csv
name,address,zip,town,phone,email
Entreprise Alpha,10 rue de Paris,76000,Rouen,0600000001,alpha@example.com
Entreprise Beta,20 rue de Lille,59000,Lille,0600000002,beta@example.com
```

Le script utilise les mêmes colonnes pour les clients et les fournisseurs.

---

# 14. Lancement de l'import

Le script accepte deux fichiers CSV en paramètres :

```bash
./scripts/import_csv.sh <fichier_clients.csv> <fichier_fournisseurs.csv>
```

Exemple avec les fichiers fournis dans le projet :

```bash
./scripts/import_csv.sh data/clients.csv data/fournisseurs.csv
```

Il est également possible d'utiliser ses propres fichiers :

```bash
./scripts/import_csv.sh mes_clients.csv mes_fournisseurs.csv
```

Le script :

1. charge les paramètres du fichier `.env` ;
2. récupère la clé API ;
3. importe les clients ;
4. importe les fournisseurs ;
5. vérifie si un tiers portant le même nom existe déjà ;
6. évite ainsi de créer des doublons.

---

# 15. Vérification de l'import

Après l'import, les clients et fournisseurs peuvent être vérifiés directement dans Dolibarr.

Dans Dolibarr, consulter la gestion des :

```text
Tiers
```

Les tiers importés doivent apparaître avec leurs informations :

* nom ;
* adresse ;
* code postal ;
* ville ;
* téléphone ;
* adresse e-mail.

---

# 16. Test de reproductibilité avec des fichiers CSV externes

Afin de vérifier que le script ne dépend pas uniquement des fichiers fournis dans le dépôt, des fichiers CSV de test différents ont été utilisés.

Exemple :

```text
test_clients.csv
test_fournisseurs.csv
```

Puis :

```bash
./scripts/import_csv.sh test_clients.csv test_fournisseurs.csv
```

Les clients et fournisseurs de test ont bien été créés dans Dolibarr.

Cette étape permet de vérifier que l'import fonctionne avec des fichiers externes respectant le format défini.

---

# 17. Sauvegarde

La sauvegarde est automatisée avec :

```text
scripts/backup.sh
```

Lancer :

```bash
./scripts/backup.sh
```

Une sauvegarde horodatée est créée dans :

```text
backups/AAAA-MM-JJ_HH-MM-SS/
```

La sauvegarde contient :

```text
database.sql
documents.tar.gz
custom.tar.gz
docker-compose.yml
env.backup
```

## Contenu des sauvegardes

### database.sql

Contient une sauvegarde de la base MariaDB de Dolibarr.

### documents.tar.gz

Contient les documents persistants de Dolibarr.

### custom.tar.gz

Contient les modules ou personnalisations présents dans :

```text
volumes/dolibarr_custom/
```

### docker-compose.yml

Permet de conserver la configuration Docker utilisée au moment de la sauvegarde.

### env.backup

Conserve une copie de la configuration `.env`.

⚠️ Les sauvegardes contenant des informations sensibles doivent être protégées et ne doivent pas être publiées dans Git.

---

# 18. Restauration / PRA

La restauration est automatisée avec :

```text
scripts/restore.sh
```

Utilisation :

```bash
./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS
```

Exemple :

```bash
./scripts/restore.sh backups/2026-10-05_10-48-43
```

Le script :

1. arrête temporairement Dolibarr ;
2. réinitialise la base MariaDB ;
3. restaure la base depuis `database.sql` ;
4. restaure les documents ;
5. restaure les modules personnalisés ;
6. redémarre Dolibarr ;
7. affiche l'état des conteneurs.

Après restauration :

```bash
docker compose ps
```

Puis ouvrir :

```text
http://localhost:8080
```

Les données présentes avant la restauration doivent être retrouvées.

---

# 19. Validation du PRA

Le fonctionnement de la restauration a été testé sur une installation propre du projet.

Le scénario de validation est :

```text
Clone du dépôt
      ↓
Configuration .env
      ↓
Installation Docker
      ↓
Déploiement Dolibarr
      ↓
Import de clients/fournisseurs
      ↓
Sauvegarde
      ↓
Restauration
      ↓
Vérification des données
```

Après restauration, les conteneurs MariaDB et Dolibarr sont opérationnels et les données importées sont toujours accessibles dans Dolibarr.

---

# 20. Installation manuelle de découverte

Avant l'automatisation Docker, une installation manuelle de Dolibarr a été réalisée sur Debian afin de comprendre les composants nécessaires.

Cette phase a notamment permis d'identifier :

* Apache ;
* PHP ;
* MariaDB ;
* les extensions PHP nécessaires ;
* la base de données Dolibarr ;
* la configuration de Dolibarr ;
* le fonctionnement des utilisateurs et permissions ;
* l'utilisation de l'API REST.

Cette installation manuelle a servi de base pour concevoir ensuite le déploiement automatisé avec Docker.

---

# 21. Tests réalisés

Plusieurs tests ont été réalisés :

### Test 1 — Installation

```bash
./scripts/install.sh
```

Résultat :

```text
MariaDB : fonctionnement OK
Dolibarr : fonctionnement OK
```

### Test 2 — API REST

```bash
curl -H "DOLAPIKEY: $DOLI_API_KEY" \
http://localhost:8080/api/index.php/thirdparties
```

Résultat attendu lorsqu'aucun tiers n'existe :

```text
404 Not Found: No third parties found
```

### Test 3 — Import CSV

```bash
./scripts/import_csv.sh test_clients.csv test_fournisseurs.csv
```

Résultat :

```text
Clients créés
Fournisseurs créés
```

### Test 4 — Anti-doublon

Le script a été exécuté une seconde fois avec les mêmes données.

Les tiers existants ne sont pas recréés.

### Test 5 — Sauvegarde

```bash
./scripts/backup.sh
```

Une sauvegarde complète est créée.

### Test 6 — Restauration

```bash
./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS
```

Les données sont retrouvées après restauration.

### Test 7 — Reproductibilité

Le dépôt a été cloné sur une installation Debian propre et l'ensemble du déploiement a été reproduit avec succès.

---

# 22. Structure du projet

```text
sae-dolibarr/
│
├── data/
│   ├── clients.csv
│   └── fournisseurs.csv
│
├── scripts/
│   ├── install.sh
│   ├── import_csv.sh
│   ├── backup.sh
│   └── restore.sh
│
├── tools/
│   └── import_csv.py
│
├── volumes/
│   ├── mariadb/
│   ├── dolibarr_documents/
│   └── dolibarr_custom/
│
├── backups/
│
├── .env
├── .env.example
├── .gitignore
├── docker-compose.yml
├── readme.md
├── suivi_projet.md
└── sources.md
```

Les répertoires suivants ne sont pas versionnés :

```text
.env
volumes/
backups/
```

---

# 23. Scripts disponibles

| Script                  | Fonction                                            |
| ----------------------- | --------------------------------------------------- |
| `scripts/install.sh`    | Installation et démarrage de la solution            |
| `scripts/import_csv.sh` | Import des clients et fournisseurs                  |
| `scripts/backup.sh`     | Sauvegarde de la solution                           |
| `scripts/restore.sh`    | Restauration de la solution                         |
| `tools/import_csv.py`   | Communication avec l'API REST et création des tiers |

---

# 24. Sécurité

Les informations sensibles sont volontairement exclues du dépôt Git.

Le fichier :

```text
.env
```

est ignoré grâce au `.gitignore`.

Le dépôt contient uniquement :

```text
.env.example
```

avec des valeurs fictives :

```env
CHANGE_ME
```

La clé API Dolibarr ne doit jamais être publiée.

Les droits de l'utilisateur `Import CSV` sont limités aux opérations nécessaires à l'import des tiers.

Le droit de suppression des tiers n'est pas nécessaire pour le fonctionnement du script.

---

# 25. Versionnement

Le projet est versionné avec Git.

Les différentes étapes du projet ont été enregistrées dans l'historique Git :

* initialisation du projet ;
* ajout des scripts ;
* ajout de la documentation ;
* amélioration de l'import CSV ;
* documentation de l'API REST ;
* tests de fonctionnement.

Le dépôt peut être récupéré sur GitHub puis déployé sur une nouvelle machine.

---

# 26. Limites du projet

Le périmètre fonctionnel est volontairement limité à la gestion des tiers :

* clients ;
* fournisseurs.

Les autres fonctionnalités de Dolibarr ne font pas partie du périmètre principal de cette SAE.

L'API REST est utilisée comme interface d'automatisation entre les fichiers CSV et Dolibarr.

---

# 27. Procédure complète de démonstration

Pour reproduire rapidement le projet sur une nouvelle machine :

```bash
git clone <URL_DU_DEPOT>
cd sae-dolibarr
```

Créer la configuration :

```bash
cp .env.example .env
nano .env
```

Lancer l'installation :

```bash
./scripts/install.sh
```

Accéder à :

```text
http://localhost:8080
```

Configurer ensuite dans Dolibarr :

```text
API REST
Utilisateur Import CSV
Permissions
Clé API
```

Renseigner la clé dans :

```text
.env
```

Tester l'API :

```bash
set -a
source .env
set +a

curl -H "DOLAPIKEY: $DOLI_API_KEY" \
http://localhost:8080/api/index.php/thirdparties
```

Importer les données :

```bash
./scripts/import_csv.sh data/clients.csv data/fournisseurs.csv
```

Créer une sauvegarde :

```bash
./scripts/backup.sh
```

Puis tester une restauration :

```bash
./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS
```

Enfin vérifier :

```bash
docker compose ps
```

et accéder à :

```text
http://localhost:8080
```

---

# 28. Conclusion

Le projet permet de déployer une instance Dolibarr de manière reproductible avec Docker, d'importer automatiquement des clients et fournisseurs à partir de fichiers CSV et de sauvegarder/restaurer les données.

L'ensemble du processus a été testé sur une installation propre afin de vérifier la reproductibilité de la solution.

Le projet répond ainsi aux principaux objectifs de la SAE :

* compréhension de l'installation manuelle ;
* automatisation du déploiement ;
* séparation de Dolibarr et MariaDB ;
* automatisation de l'import des données ;
* sauvegarde ;
* restauration / PRA ;
* documentation ;
* versionnement Git.

---

# 29. Sources

## Dolibarr

Documentation officielle :

https://wiki.dolibarr.org/

API REST :

https://wiki.dolibarr.org/index.php/Module_Web_Services_API_REST_(developer)

Import des données :

https://wiki.dolibarr.org/index.php/Imports

## Docker

Documentation officielle :

https://docs.docker.com/

Docker Compose :

https://docs.docker.com/compose/

## MariaDB

Documentation officielle :

https://mariadb.com/docs/
