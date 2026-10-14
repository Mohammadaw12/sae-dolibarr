# SAE 5.1 — Déploiement et automatisation de Dolibarr

## 1. Présentation

Ce projet a été réalisé dans le cadre de la SAE 5.1 du BUT Réseaux & Télécommunications.

L'objectif est de déployer une solution **Dolibarr ERP/CRM** permettant la gestion des tiers, principalement :

- les clients ;
- les fournisseurs.

Le projet comprend :

- une phase d'installation manuelle de Dolibarr afin de comprendre son fonctionnement ;
- une automatisation du déploiement avec Docker ;
- une automatisation de l'import de clients et fournisseurs depuis des fichiers CSV ;
- une sauvegarde de la base de données et des données persistantes ;
- une restauration permettant de mettre en œuvre un plan de reprise d'activité (PRA) ;
- une documentation et un versionnement complet avec Git.

---

## 2. Architecture

L'architecture automatisée repose sur deux conteneurs Docker.

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

Le navigateur accède à Dolibarr sur le port 8080 de la machine hôte. Docker redirige ce port vers le port 80 du conteneur Dolibarr.

Les données persistantes sont stockées dans des répertoires locaux :

```text
volumes/
├── mariadb/
├── dolibarr_documents/
└── dolibarr_custom/
```

- `volumes/mariadb/` : données de la base MariaDB.
- `volumes/dolibarr_documents/` : documents persistants de Dolibarr.
- `volumes/dolibarr_custom/` : modules et personnalisations.

Cette organisation permet de conserver les données même lorsque les conteneurs sont arrêtés ou recréés, tant que les répertoires persistants ne sont pas supprimés.

---

## 3. Prérequis

Le projet a été testé sur Debian 12.

Les éléments nécessaires sont :

- Debian ;
- Docker Engine ;
- Docker Compose ;
- Git pour récupérer le dépôt ;
- Python 3 pour l'import CSV ;
- un navigateur web.

Le script `scripts/install.sh` vérifie le système utilisé et les droits administrateur. Si Docker ou le plugin Docker Compose n'est pas installé, il tente de les installer depuis le dépôt officiel Docker pour Debian.

L'installation nécessite une connexion Internet et des droits administrateur.

Vérifier Docker :

```bash
docker --version
```

Vérifier Docker Compose :

```bash
docker compose version
```

Vérifier Python :

```bash
python3 --version
```

---

## 4. Récupération du projet

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
├── .env.example
├── .gitignore
├── docker-compose.yml
├── readme.md
├── sources.md
└── suivi_projet.md
```

Les répertoires `volumes/` et `backups/` sont créés par les scripts lorsque cela est nécessaire.

---

## 5. Configuration du fichier .env

Le fichier `.env` contient les paramètres de configuration et les informations sensibles du projet, notamment les mots de passe de MariaDB et de l'administrateur Dolibarr.

Il n'est pas destiné à être publié dans Git.

Le script `scripts/install.sh` vérifie automatiquement la présence de ce fichier.

Si `.env` est absent, le script le crée à partir de `.env.example`, applique des permissions restrictives, puis arrête l'installation pour permettre de renseigner les paramètres.

Créer ou modifier la configuration manuellement :

```bash
cp .env.example .env
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

Les valeurs doivent être adaptées à l'environnement. Les mots de passe fictifs doivent être remplacés par des mots de passe robustes.

Le script vérifie que les variables obligatoires sont présentes et non vides avant de poursuivre.

La clé API sera renseignée après la configuration de l'utilisateur d'import et de l'API REST.

**Attention :** le fichier `.env` contient des secrets. Il ne doit jamais être publié dans Git.

---

## 6. Installation automatisée

L'installation est réalisée à l'aide du script :

```text
scripts/install.sh
```

Depuis la racine du projet, lancer :

```bash
sudo bash scripts/install.sh
```

Le script réalise les opérations suivantes :

1. Se place à la racine du projet.
2. Vérifie les droits administrateur et confirme que le système est Debian.
3. Vérifie la présence de Docker et Docker Compose et tente de les installer si nécessaire.
4. Vérifie la présence de `curl` et l'installe si nécessaire.
5. Démarre le service Docker et vérifie son fonctionnement.
6. Vérifie la présence de `docker-compose.yml`.
7. Vérifie le fichier `.env` et les variables obligatoires.
8. Valide la configuration Docker Compose.
9. Crée les répertoires nécessaires aux volumes et aux sauvegardes.
10. Démarre MariaDB et attend qu'elle réponde.
11. Démarre Dolibarr et teste son accès HTTP sur le port 8080.
12. Affiche les journaux des conteneurs en cas d'échec du démarrage de Dolibarr.
13. Vérifie la présence de certaines tables de la base Dolibarr et tente d'activer la constante de l'API REST.
14. Exécute la configuration finale du pare-feu prévue dans le script.

Si le fichier `.env` n'existe pas, le script crée d'abord ce fichier à partir de `.env.example`, puis s'arrête. Il faut compléter la configuration et relancer la commande.

À la fin, Dolibarr est accessible à l'adresse suivante :

```text
http://localhost:8080
```

Vérifier l'état des conteneurs :

```bash
docker compose ps
```

Consulter les journaux en cas de problème :

```bash
docker compose logs --tail=100 dolibarr
docker compose logs --tail=100 mariadb
```

**Remarque :** le message final indique que les étapes du script se sont terminées sans erreur bloquante. Il reste nécessaire de vérifier la connexion à l'interface et le fonctionnement des fonctionnalités attendues.

---

## 7. Première connexion à Dolibarr

Après le démarrage de l'application, ouvrir :

```text
http://localhost:8080
```

Lors de la première installation, suivre l'assistant d'installation de Dolibarr s'il apparaît.

Les variables suivantes sont définies dans le fichier `.env` :

```env
DOLI_ADMIN_LOGIN=admin
DOLI_ADMIN_PASSWORD=...
```

Elles sont destinées à la configuration de l'administrateur, mais leur présence dans `.env` ne garantit pas à elle seule que le compte a été créé ou que le mot de passe est celui attendu.

Vérifier la première connexion directement dans Dolibarr et finaliser l'installation si nécessaire.

---

## 8. Configuration de l'API REST

L'import automatisé des clients et fournisseurs utilise l'API REST de Dolibarr.

### Activation

Le script `scripts/install.sh` tente d'activer la constante `MAIN_MODULE_API` dans la table `llx_const`, à condition que les tables `llx_const` et `llx_user` existent.

Cette opération constitue une tentative d'activation automatique. Elle ne remplace pas la vérification du module dans l'interface Dolibarr.

Dans Dolibarr, accéder à :

```text
Configuration → Modules/Applications
```

Rechercher le module API REST et vérifier qu'il est activé.

Si l'activation automatique échoue ou si la base n'est pas encore correctement initialisée, effectuer la vérification et l'activation depuis l'interface.

La clé API sera ensuite générée pour l'utilisateur dédié à l'import CSV.

---

## 9. Création de l'utilisateur d'import

Créer un utilisateur dédié à l'import des données.

Dans Dolibarr, accéder à :

```text
Utilisateurs & Groupes → Nouvel utilisateur
```

Exemple :

```text
Nom : Import CSV
Login : import
```

L'utilisateur doit disposer des droits nécessaires pour :

- consulter les tiers ;
- créer les tiers ;
- modifier les tiers, si cette opération est nécessaire à l'utilisation prévue.

Le droit de suppression des tiers n'est pas nécessaire au fonctionnement normal de l'import présenté dans ce projet.

Une clé API doit ensuite être générée pour cet utilisateur.

---

## 10. Configuration de la clé API

Dans le compte de l'utilisateur `Import CSV`, générer une clé API.

Renseigner ensuite cette clé dans le fichier `.env` :

```env
DOLI_API_KEY=VOTRE_CLE_API
```

La clé doit être conservée confidentiellement et ne doit jamais être publiée dans Git ou dans le dépôt.

Après modification de `.env`, les scripts qui chargent ce fichier pourront utiliser la nouvelle valeur.

---

## 11. Test de l'API REST

Après configuration de la clé, charger les variables d'environnement :

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

Si aucun tiers n'existe encore, Dolibarr peut retourner une réponse indiquant qu'aucun tiers n'a été trouvé.

Exemple de message possible :

```text
404 Not Found: No third parties found
```

Ce message peut indiquer qu'aucun tiers n'est enregistré, mais un code HTTP 404 peut aussi signaler un problème de route ou de configuration. Il faut donc vérifier la réponse réelle de l'API et, si nécessaire, tester avec un tiers existant.

---

## 12. Import des clients et fournisseurs

L'import est réalisé à l'aide du script :

```text
scripts/import_csv.sh
```

Ce script utilise :

```text
tools/import_csv.py
```

Le script shell vérifie les prérequis et charge la configuration. Le programme Python lit les fichiers CSV et communique avec Dolibarr via l'API REST.

Les tiers sont créés dans Dolibarr à travers cette API, et non par une insertion directe dans la base MariaDB.

---

## 13. Format des fichiers CSV

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

Les noms des colonnes doivent respecter le format attendu par le programme Python.

Les fichiers CSV doivent être encodés dans un format compatible avec la lecture du script. Celui-ci utilise `utf-8-sig`, ce qui permet notamment de gérer certains fichiers UTF-8 avec marqueur BOM.

---

## 14. Lancement de l'import

Le script accepte deux fichiers CSV en paramètres :

```bash
./scripts/import_csv.sh <fichier_clients.csv> <fichier_fournisseurs.csv>
```

Exemple avec les fichiers fournis dans le projet :

```bash
./scripts/import_csv.sh data/clients.csv data/fournisseurs.csv
```

Il est également possible d'utiliser ses propres fichiers, à condition qu'ils respectent le format attendu :

```bash
./scripts/import_csv.sh mes_clients.csv mes_fournisseurs.csv
```

Le script :

1. vérifie les arguments et les fichiers fournis ;
2. charge les paramètres du fichier `.env` ;
3. récupère la clé API ;
4. vérifie que Dolibarr répond ;
5. lance le programme Python pour importer les données ;
6. traite les clients et les fournisseurs ;
7. recherche un tiers portant le même nom avant d'en créer un nouveau.

La détection des doublons repose sur le nom du tiers. Elle ne constitue donc pas une garantie d'unicité absolue si des noms sont identiques ou si les données sont mal normalisées.

---

## 15. Vérification de l'import

Après l'import, les clients et fournisseurs peuvent être vérifiés directement dans Dolibarr.

Dans Dolibarr, consulter la gestion des tiers et les catégories clients ou fournisseurs.

Les tiers importés doivent apparaître avec les informations disponibles dans le CSV :

- nom ;
- adresse ;
- code postal ;
- ville ;
- téléphone ;
- adresse e-mail.

En cas d'échec, consulter le message affiché par le script et vérifier la clé API, les permissions de l'utilisateur et le format du fichier CSV.

---

## 16. Test de reproductibilité avec des fichiers CSV externes

Afin de vérifier que le script ne dépend pas uniquement des fichiers fournis dans le dépôt, des fichiers CSV de test différents peuvent être utilisés.

Exemples :

```text
test_clients.csv
test_fournisseurs.csv
```

Lancer ensuite :

```bash
./scripts/import_csv.sh test_clients.csv test_fournisseurs.csv
```

Les fichiers externes doivent respecter le format défini dans la section 13.

Cette étape permet de vérifier que le mécanisme d'import fonctionne avec d'autres données et ne dépend pas exclusivement des fichiers d'exemple.

Le résultat doit être contrôlé dans Dolibarr après chaque test.

---

## 17. Sauvegarde

La sauvegarde est automatisée avec :

```text
scripts/backup.sh
```

Lancer :

```bash
./scripts/backup.sh
```

Une sauvegarde horodatée est créée dans un répertoire de la forme :

```text
backups/AAAA-MM-JJ_HH-MM-SS/
```

La sauvegarde contient normalement les éléments suivants :

```text
database.sql
documents.tar.gz
custom.tar.gz
docker-compose.yml
env.backup
```

### Contenu des sauvegardes

**`database.sql`**

Contient un export de la base MariaDB de Dolibarr.

**`documents.tar.gz`**

Contient une archive des documents persistants de Dolibarr.

**`custom.tar.gz`**

Contient une archive des fichiers présents dans :

```text
volumes/dolibarr_custom/
```

**`docker-compose.yml`**

Permet de conserver la configuration Docker utilisée au moment de la sauvegarde.

**`env.backup`**

Conserve une copie de la configuration `.env`.

Cette dernière peut contenir des mots de passe et des clés sensibles. Elle doit être protégée.

**Attention :** une sauvegarde stockée uniquement sur la même machine ne protège pas contre toutes les pannes. Pour un PRA réel, il est préférable de conserver une copie sur un support ou un emplacement séparé.

---

## 18. Restauration / PRA

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

Le chemin doit correspondre à un répertoire de sauvegarde existant contenant au minimum `database.sql`.

Le script :

1. vérifie la présence du fichier `.env` ;
2. vérifie le chemin de sauvegarde et la présence de `database.sql` ;
3. charge les variables d'environnement ;
4. arrête temporairement Dolibarr ;
5. supprime puis recrée la base de données ;
6. restaure la base depuis `database.sql` ;
7. restaure les documents si `documents.tar.gz` existe ;
8. restaure les personnalisations si `custom.tar.gz` existe ;
9. redémarre Dolibarr ;
10. affiche l'état des conteneurs.

**Attention : la restauration est destructive pour la base actuelle.** La commande SQL `DROP DATABASE` supprime la base existante avant sa recréation. Les contenus des répertoires de documents et de personnalisations sont également supprimés avant l'extraction des archives correspondantes.

Il faut donc vérifier le répertoire choisi et la validité de la sauvegarde avant de lancer le script.

Après restauration :

```bash
docker compose ps
```

Puis ouvrir :

```text
http://localhost:8080
```

Vérifier que les tiers et les documents attendus sont bien présents.

---

## 19. Validation du PRA

La validation du PRA consiste à vérifier que les données sauvegardées peuvent être récupérées après une restauration.

Le scénario de test est le suivant :

```text
Installation de Dolibarr
        ↓
Import de clients et fournisseurs
        ↓
Vérification des données
        ↓
Création d'une sauvegarde
        ↓
Restauration de la sauvegarde
        ↓
Vérification des données restaurées
```

Pour valider le PRA, vérifier notamment :

- que les conteneurs démarrent correctement ;
- que l'interface Dolibarr est accessible ;
- que les tiers présents avant la sauvegarde sont retrouvés ;
- que les documents attendus sont disponibles ;
- que les personnalisations nécessaires sont présentes.

Le test ne doit être déclaré réussi qu'après une restauration réelle et une vérification des données. Il est préférable d'effectuer les essais sur un environnement de test, car la restauration remplace les données actuelles.

---

## 20. Installation manuelle de découverte

Avant l'automatisation Docker, une installation manuelle de Dolibarr a été réalisée sur Debian afin de comprendre les composants nécessaires.

Cette phase a notamment permis d'identifier :

- Apache ;
- PHP ;
- MariaDB ;
- les extensions PHP nécessaires ;
- la base de données Dolibarr ;
- la configuration de Dolibarr ;
- le fonctionnement des utilisateurs et permissions ;
- l'utilisation de l'API REST.

Cette installation manuelle a servi de base pour concevoir ensuite le déploiement automatisé avec Docker.

---

## 21. Tests réalisés

Les tests ci-dessous permettent de vérifier le fonctionnement du projet. Les résultats doivent être renseignés en fonction des essais réellement effectués.

### Test 1 — Installation

Commande :

```bash
sudo bash scripts/install.sh
```

Points à vérifier :

- démarrage de MariaDB ;
- démarrage de Dolibarr ;
- réponse HTTP sur le port 8080 ;
- absence d'erreurs bloquantes dans les journaux.

### Test 2 — API REST

Commande :

```bash
set -a
source .env
set +a

curl -i -H "DOLAPIKEY: $DOLI_API_KEY" \
http://localhost:8080/api/index.php/thirdparties
```

Le résultat dépend de l'état de la base, de la route appelée et des permissions de la clé API. Une réponse 404 ne suffit pas à prouver à elle seule que toute l'API fonctionne correctement.

### Test 3 — Import CSV

Commande :

```bash
./scripts/import_csv.sh data/clients.csv data/fournisseurs.csv
```

Vérifier que les tiers attendus sont visibles dans Dolibarr et que les erreurs éventuelles sont examinées.

### Test 4 — Anti-doublon

Relancer l'import avec les mêmes données.

Vérifier que les tiers portant déjà le même nom ne sont pas recréés.

### Test 5 — Sauvegarde

Commande :

```bash
./scripts/backup.sh
```

Vérifier la création du répertoire horodaté et la présence des fichiers de sauvegarde attendus.

### Test 6 — Restauration

Commande :

```bash
./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS
```

Vérifier ensuite l'état des conteneurs, l'accès à Dolibarr et la présence des données restaurées.

### Test 7 — Reproductibilité

Récupérer le dépôt sur une installation Debian de test, configurer `.env`, puis lancer les scripts nécessaires.

La reproductibilité doit être considérée comme validée après vérification effective du déploiement, de l'import et, si prévu dans le périmètre des tests, de la restauration.

---

## 22. Structure du projet

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

Les répertoires `volumes/` et `backups/` contiennent des données générées localement. Ils ne doivent pas être versionnés s'ils contiennent des données réelles ou des informations sensibles.

Le fichier `.env` doit également être ignoré par Git. Seul le modèle `.env.example` est destiné à être partagé.

---

## 23. Scripts disponibles

| Script | Fonction |
|---|---|
| `scripts/install.sh` | Vérification de l'environnement, installation éventuelle de Docker et démarrage de Dolibarr et MariaDB |
| `scripts/import_csv.sh` | Vérification des prérequis et lancement de l'import CSV |
| `scripts/backup.sh` | Sauvegarde de la base et des fichiers persistants |
| `scripts/restore.sh` | Restauration de la base et des fichiers à partir d'une sauvegarde |
| `tools/import_csv.py` | Lecture des CSV, communication avec l'API REST et création des tiers |

---

## 24. Sécurité

Les informations sensibles sont volontairement exclues du dépôt Git.

Le fichier `.env` contient notamment :

- les mots de passe de MariaDB ;
- les identifiants prévus pour l'administrateur Dolibarr ;
- la clé API utilisée pour l'import.

Il doit rester privé et être protégé par des permissions adaptées.

Le dépôt contient uniquement `.env.example`, qui sert de modèle avec des valeurs fictives.

Les sauvegardes peuvent également contenir des informations sensibles. En particulier, `env.backup` contient une copie de la configuration `.env` et doit être protégé.

L'utilisateur `Import CSV` doit disposer uniquement des permissions nécessaires à l'import des tiers.

### Point de vigilance concernant le pare-feu

Le script `scripts/install.sh` autorise le port TCP 8080 avec UFW, puis désactive complètement UFW s'il est installé.

Cette configuration a été utilisée dans l'environnement de test, mais elle réduit la protection du système. Elle n'est pas recommandée sur un serveur exposé ou en production.

En environnement réel, il est préférable de conserver le pare-feu actif et d'autoriser uniquement les connexions nécessaires.

Il faut également éviter d'utiliser les mots de passe fictifs de `.env.example` sur une installation réelle.

---

## 25. Versionnement

Le projet est versionné avec Git.

L'historique du dépôt permet de conserver les différentes étapes du développement, notamment :

- l'initialisation du projet ;
- l'ajout des scripts ;
- l'ajout de la documentation ;
- l'amélioration de l'import CSV ;
- la documentation de l'API REST ;
- les corrections et tests.

Le dépôt peut être récupéré sur GitHub puis utilisé pour reproduire le déploiement sur une nouvelle machine, sous réserve de configurer l'environnement et de vérifier les prérequis.

---

## 26. Limites du projet

Le périmètre fonctionnel est volontairement limité à la gestion des tiers :

- clients ;
- fournisseurs.

Les autres fonctionnalités de Dolibarr ne font pas partie du périmètre principal de cette SAE.

L'API REST est utilisée comme interface d'automatisation entre les fichiers CSV et Dolibarr.

La détection des doublons repose sur le nom du tiers. Elle ne permet pas d'identifier tous les doublons possibles lorsque les noms diffèrent légèrement.

Les fichiers CSV doivent respecter les colonnes attendues par le script.

L'installation automatisée dépend du bon fonctionnement de Docker, de MariaDB, de Dolibarr et de l'API REST.

Enfin, une sauvegarde n'est réellement utile au PRA que si elle est valide, conservée en lieu sûr et accompagnée de tests de restauration.

---

## 27. Procédure complète de démonstration

Pour reproduire le projet sur une nouvelle machine Debian :

### Étape 1 — Récupérer le dépôt

```bash
git clone <URL_DU_DEPOT>
cd sae-dolibarr
```

### Étape 2 — Configurer l'environnement

```bash
cp .env.example .env
nano .env
```

Remplacer les valeurs fictives par les valeurs adaptées à l'installation.

### Étape 3 — Lancer l'installation

```bash
sudo bash scripts/install.sh
```

Si le script crée `.env` puis s'arrête parce qu'il était absent, compléter le fichier et relancer la commande.

### Étape 4 — Accéder à Dolibarr

Ouvrir :

```text
http://localhost:8080
```

Finaliser l'installation initiale si nécessaire, puis vérifier la connexion à l'interface.

### Étape 5 — Configurer l'API REST

Dans Dolibarr, vérifier l'activation du module API REST, créer l'utilisateur `Import CSV`, lui attribuer les permissions nécessaires et générer une clé API.

Renseigner la clé dans `.env` :

```env
DOLI_API_KEY=VOTRE_CLE_API
```

### Étape 6 — Tester l'API

```bash
set -a
source .env
set +a

curl -i -H "DOLAPIKEY: $DOLI_API_KEY" \
http://localhost:8080/api/index.php/thirdparties
```

Interpréter la réponse en fonction du contenu de la base et de la configuration de l'API.

### Étape 7 — Importer les données

```bash
./scripts/import_csv.sh data/clients.csv data/fournisseurs.csv
```

Vérifier ensuite les tiers dans Dolibarr.

### Étape 8 — Créer une sauvegarde

```bash
./scripts/backup.sh
```

Noter le nom du répertoire créé dans `backups/`.

### Étape 9 — Tester une restauration

Choisir un répertoire de sauvegarde existant et valide :

```bash
./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS
```

**Attention :** cette opération remplace la base de données actuelle et peut supprimer les fichiers présents dans les répertoires restaurés. Vérifier la sauvegarde avant de lancer la commande.

### Étape 10 — Vérifier le résultat

```bash
docker compose ps
```

Consulter ensuite l'interface Dolibarr à l'adresse :

```text
http://localhost:8080
```

Contrôler que les données attendues sont toujours présentes après la restauration.

---

## 28. Conclusion

Le projet permet de déployer une instance Dolibarr de manière reproductible avec Docker, d'importer des clients et fournisseurs à partir de fichiers CSV et de mettre en place des mécanismes de sauvegarde et de restauration.

Il met en œuvre plusieurs compétences du BUT Réseaux & Télécommunications :

- compréhension d'une installation manuelle ;
- automatisation du déploiement ;
- utilisation de Docker et Docker Compose ;
- séparation de l'application et de la base de données ;
- automatisation de l'import de données par API REST ;
- sauvegarde et restauration ;
- documentation technique ;
- versionnement avec Git.

La validation finale repose sur les tests réellement effectués et sur la vérification du bon fonctionnement de l'application après déploiement et restauration.

---

## 29. Sources

### Dolibarr

Documentation officielle :

https://wiki.dolibarr.org/

API REST :

https://wiki.dolibarr.org/index.php/Module_Web_Services_API_REST_(developer)

Import des données :

https://wiki.dolibarr.org/index.php/Imports

Dépôt officiel :

https://github.com/Dolibarr/dolibarr

### Docker

Documentation officielle :

https://docs.docker.com/

Docker Compose :

https://docs.docker.com/compose/

Gestion du stockage :

https://docs.docker.com/engine/storage/volumes/

### MariaDB

Documentation officielle :

https://mariadb.com/docs/

Commande `mariadb-dump` :

https://mariadb.com/kb/en/mariadb-dump/

### Python

Documentation du module CSV :

https://docs.python.org/3/library/csv.html

Documentation du module urllib :

https://docs.python.org/3/library/urllib.request.html

### GNU tar

Documentation officielle :

https://www.gnu.org/software/tar/manual/tar.html
