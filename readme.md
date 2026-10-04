# SAE 5.1 - Déploiement et automatisation de Dolibarr

## 1. Présentation du projet

Ce projet est réalisé dans le cadre de la SAE 5.1 du BUT Réseaux & Télécommunications.

L'objectif est de mettre en place une solution Dolibarr permettant de gérer les tiers d'une entreprise, notamment les clients et les fournisseurs.

Le projet comprend :

- l'installation de Dolibarr ;
- l'utilisation d'une base de données MariaDB ;
- la conteneurisation avec Docker ;
- l'import automatisé de données depuis des fichiers CSV ;
- la sauvegarde et la restauration des données ;
- la documentation et le suivi du projet.

Le périmètre fonctionnel est limité à la gestion des tiers : clients et fournisseurs.

---

## 2. Architecture

La solution repose sur deux conteneurs Docker :

- **Dolibarr** : application web ERP/CRM ;
- **MariaDB** : système de gestion de base de données.

Les données persistantes sont stockées dans le dossier `volumes/`.

Architecture :

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
3. Prérequis

Pour utiliser le projet, il faut disposer de :

Docker ;
Docker Compose ;
Git ;
Python 3 ;
un environnement Linux ou compatible Bash.
4. Configuration

Le projet utilise un fichier .env pour les paramètres sensibles.

Créer le fichier à partir du modèle :

cp .env.example .env

Puis modifier .env avec les valeurs adaptées à l'environnement.

Le fichier .env ne doit pas être versionné.

5. Installation

L'installation automatisée est réalisée avec :

./scripts/install.sh

Le script :

vérifie la présence du fichier .env ;
vérifie Docker et Docker Compose ;
crée les dossiers nécessaires ;
démarre MariaDB ;
attend que MariaDB soit disponible ;
démarre Dolibarr.

Après installation, Dolibarr est accessible à :

http://localhost:8080
6. Import des données

Les données d'exemple sont stockées dans :

data/clients.csv
data/fournisseurs.csv

L'import est automatisé avec :

./scripts/import_csv.sh

Le script utilise l'API REST de Dolibarr afin de créer les tiers à partir des fichiers CSV.

Le script évite également de recréer un tiers déjà présent.

7. Sauvegarde

La sauvegarde est réalisée avec :

./scripts/backup.sh

Une sauvegarde contient notamment :

la base MariaDB ;
les documents Dolibarr ;
les modules personnalisés ;
la configuration Docker ;
une copie du fichier .env.

Les sauvegardes sont stockées dans :

backups/

Les sauvegardes ne sont pas versionnées dans Git.

8. Restauration

Pour restaurer une sauvegarde :

./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS

Exemple :

./scripts/restore.sh backups/2026-10-03_19-42-59

La procédure restaure :

la base de données ;
les documents ;
les modules personnalisés.
9. Structure du projet
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
10. Scripts principaux
Script	Fonction
install.sh	Installation et démarrage de la solution
import_csv.sh	Import des clients et fournisseurs
backup.sh	Sauvegarde de la solution
restore.sh	Restauration d'une sauvegarde
import_csv.py	Communication avec l'API REST de Dolibarr
11. Sécurité

Les informations sensibles ne doivent pas être présentes dans le dépôt Git.

Le fichier suivant est donc exclu du versionnement :

.env

Un fichier .env.example est fourni afin de présenter les variables nécessaires sans exposer les véritables mots de passe ou clés API.

12. Limites du projet

Le projet constitue un prototype (POC) réalisé dans le cadre de la SAE.

Le périmètre fonctionnel est volontairement limité à la gestion des tiers :

clients ;
fournisseurs.

Les autres fonctionnalités de Dolibarr ne font pas partie du périmètre principal du projet.
