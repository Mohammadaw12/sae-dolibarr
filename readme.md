# SAE 5.1 - Déploiement et automatisation de Dolibarr

## 1. Présentation du projet

Ce projet est réalisé dans le cadre de la SAE 5.1 du BUT Réseaux & Télécommunications.

L'objectif est de mettre en place une solution Dolibarr permettant de gérer les tiers d'une entreprise, notamment les clients et les fournisseurs.

Le projet comprend :

* l'installation de Dolibarr ;
* l'utilisation d'une base de données MariaDB ;
* la conteneurisation avec Docker ;
* l'import automatisé de données depuis des fichiers CSV ;
* la sauvegarde et la restauration des données ;
* la documentation et le suivi du projet.

Le périmètre fonctionnel est limité à la gestion des tiers : clients et fournisseurs.

---

## 2. Architecture

La solution repose sur deux conteneurs Docker :

* **Dolibarr** : application web ERP/CRM ;
* **MariaDB** : système de gestion de base de données.

Les données persistantes sont stockées dans le dossier `volumes/`.

```text
                    Navigateur
                        |
                        | HTTP : 8080
                        v
              +-------------------+
              |     Dolibarr      |
              |     Container     |
              +-------------------+
                        |
                        | réseau Docker
                        v
              +-------------------+
              |      MariaDB      |
              |     Container     |
              +-------------------+
```

---

## 3. Prérequis

Pour utiliser le projet, il faut disposer de :

* Docker ;
* Docker Compose ;
* Git ;
* Python 3 ;
* un environnement Linux ou compatible Bash.

---

## 4. Configuration

Le projet utilise un fichier `.env` pour les paramètres sensibles.

Créer le fichier à partir du modèle :

```bash
cp .env.example .env
```

Puis modifier `.env` avec les valeurs adaptées à l'environnement.

Le fichier `.env` ne doit pas être versionné.

---

### Configuration de l'API REST : A faire apres l'installation 

L'import automatisé des clients et fournisseurs utilise l'API REST de Dolibarr.

### Activation de l'API

Après l'installation de Dolibarr :

1. Se connecter à Dolibarr avec un compte administrateur.
2. Aller dans **Configuration → Modules/Applications**.
3. Rechercher le module **API REST**.
4. Activer le module.

### Création de l'utilisateur d'import

Créer un utilisateur dédié à l'import des données, par exemple :

```text
Login : aw
Nom : aw


L'utilisateur doit disposer des droits nécessaires pour consulter et créer les tiers (clients et fournisseurs).

Une clé API doit ensuite être générée pour cet utilisateur.

Configuration de la clé API

La clé API générée doit être renseignée dans le fichier .env :

DOLI_API_KEY=VOTRE_CLE_API

La clé API est une information sensible et ne doit jamais être publiée dans le dépôt Git
Une fois l'API configurée, l'import peut être lancé avec :

./scripts/import_csv.sh data/clients.csv data/fournisseurs.csv

Le programme tools/import_csv.py utilise cette clé pour communiquer avec l'API REST de Dolibarr et créer les clients et fournisseurs à partir des fichiers CSV.

Documentation officielle de l'API REST :

https://wiki.dolibarr.org/index.php/Module_Web_Services_API_REST_(developer)



## 5. Installation

L'installation automatisée est réalisée avec :

```bash
./scripts/install.sh
```

Le script :

1. vérifie la présence du fichier `.env` ;
2. vérifie Docker et Docker Compose ;
3. crée les dossiers nécessaires ;
4. démarre MariaDB ;
5. attend que MariaDB soit disponible ;
6. démarre Dolibarr.

Après installation, Dolibarr est accessible à :

```text
http://localhost:8080
```

---

## 6. Import des données

Le projet permet d'importer automatiquement des clients et des fournisseurs dans Dolibarr à partir de fichiers CSV.

Des fichiers d'exemple sont fournis dans :

```text
data/clients.csv
data/fournisseurs.csv
```

Ces fichiers servent uniquement à tester et démontrer le fonctionnement de l'import.

### Format des fichiers CSV

Les fichiers CSV doivent contenir les colonnes suivantes :

```text
name,address,zip,town,phone,email
```

Exemple :

```csv
name,address,zip,town,phone,email
Entreprise ABC,15 rue Victor Hugo,75001,Paris,0102030405,contact@abc.fr
```

### Utiliser ses propres fichiers CSV

Il est possible d'utiliser d'autres fichiers CSV sans modifier le programme.

La commande est :

```bash
./scripts/import_csv.sh <fichier_clients.csv> <fichier_fournisseurs.csv>
```

Exemple :

```bash
./scripts/import_csv.sh mes_clients.csv mes_fournisseurs.csv
```

Le script :

1. vérifie la présence des deux fichiers ;
2. importe le premier fichier comme liste de clients ;
3. importe le second fichier comme liste de fournisseurs ;
4. utilise l'API REST de Dolibarr pour créer les tiers ;
5. vérifie qu'un tiers n'existe pas déjà afin d'éviter les doublons.

Les fichiers CSV utilisés peuvent donc être remplacés par ceux fournis par l'utilisateur, à condition de respecter le format attendu.

### Import avec les fichiers d'exemple

L'import peut être lancé avec :

```bash
./scripts/import_csv.sh data/clients.csv data/fournisseurs.csv
```

Le programme Python `tools/import_csv.py` assure la communication avec l'API REST de Dolibarr.

---

## 7. Sauvegarde

La sauvegarde est réalisée avec :

```bash
./scripts/backup.sh
```

Une sauvegarde contient notamment :

* la base MariaDB ;
* les documents Dolibarr ;
* les modules personnalisés ;
* la configuration Docker ;
* une copie du fichier `.env`.

Les sauvegardes sont stockées dans :

```text
backups/
```

Les sauvegardes ne sont pas versionnées dans Git.

---

## 8. Restauration

Pour restaurer une sauvegarde :

```bash
./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS
```

Exemple :

```bash
./scripts/restore.sh backups/2026-10-03_19-42-59
```

La procédure restaure :

* la base de données ;
* les documents ;
* les modules personnalisés.

---

## 9. Structure du projet

```text
sae-dolibarr/
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
├── docs/
│
├── docker-compose.yml
├── .env.example
├── .gitignore
├── readme.md
├── suivi_projet.md
└── sources.md
```

---

## 10. Scripts principaux

| Script          | Fonction                                  |
| --------------- | ----------------------------------------- |
| `install.sh`    | Installation et démarrage de la solution  |
| `import_csv.sh` | Import des clients et fournisseurs        |
| `backup.sh`     | Sauvegarde de la solution                 |
| `restore.sh`    | Restauration d'une sauvegarde             |
| `import_csv.py` | Communication avec l'API REST de Dolibarr |

---

## 11. Sécurité

Les informations sensibles ne doivent pas être présentes dans le dépôt Git.

Le fichier suivant est donc exclu du versionnement :

```text
.env
```

Un fichier `.env.example` est fourni afin de présenter les variables nécessaires sans exposer les véritables mots de passe ou clés API.

Les sauvegardes contenant potentiellement des informations sensibles doivent également être conservées dans un emplacement sécurisé.

---

## 12. Limites du projet

Le projet constitue un prototype (POC) réalisé dans le cadre de la SAE.

Le périmètre fonctionnel est volontairement limité à la gestion des tiers :

* clients ;
* fournisseurs.

Les autres fonctionnalités de Dolibarr ne font pas partie du périmètre principal du projet.
