# SAE 5.1 - Déploiement et automatisation de Dolibarr

## 1. Présentation du projet

Ce projet est réalisé dans le cadre de la SAE 5.1 du BUT Réseaux & Télécommunications.

L'objectif est de mettre en place une solution Dolibarr permettant de gérer les tiers d'une entreprise, notamment les clients et les fournisseurs.

Le projet comprend :

* l'installation de Dolibarr ;
* l'utilisation d'une base de données MariaDB ;
* la conteneurisation avec Docker ;
* l'import automatisé de données depuis des fichiers CSV ;
* l'utilisation de l'API REST de Dolibarr ;
* la sauvegarde et la restauration des données ;
* la documentation et le suivi du projet.

Le périmètre fonctionnel est limité à la gestion des tiers : clients et fournisseurs.

---

## 2. Architecture

La solution repose sur deux conteneurs Docker :

* **Dolibarr** : application web ERP/CRM ;
* **MariaDB** : système de gestion de base de données.

Les données persistantes sont stockées dans les volumes Docker.

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



Pour l'import automatisé :

              Fichier CSV
                   |
                   v
            import csv.sh
                   |
                   v
             API REST
             Dolibarr
                   |
                   v
              Dolibarr
                   |
                   v
       Tiers : clients / fournisseurs
3. Prérequis

Pour utiliser le projet, il faut disposer de :

Docker ;
Docker Compose ;
Git ;
une connexion Internet.

Vérifier que Docker est installé :

docker --version

Vérifier que Docker Compose est disponible :

docker compose version

Vérifier que Git est installé :

git --version
4. Récupération du projet

Cloner le dépôt GitHub :

git clone https://github.com/mohammad/sae-dolibarr.git

Entrer dans le projet :

cd sae-dolibarr
5. Installation

Rendre le script d'installation exécutable :

chmod +x install.sh

Lancer l'installation :

./install.sh

Le script permet de mettre en place automatiquement l'environnement nécessaire au fonctionnement du projet.

Une fois l'installation terminée, accéder à Dolibarr depuis un navigateur :

http://localhost:8080
6. Première configuration de Dolibarr

Lors de la première connexion, terminer la configuration de Dolibarr depuis l'interface web.

Créer le compte superadmin permettant d'administrer Dolibarr.

Créer également un utilisateur destiné à l'utilisation de l'API.

Le projet utilise principalement la fonctionnalité de gestion des Tiers, correspondant aux clients et fournisseurs.

7. Configuration de l'API REST

L'import automatisé des fichiers CSV utilise l'API REST de Dolibarr.

7.1 Activer l'API REST

Dans Dolibarr, accéder à :

Configuration
→ Modules/Applications
→ API REST

Activer le module permettant l'utilisation de l'API REST.

7.2 Utilisateur API

Utiliser l'utilisateur créé précédemment pour effectuer les imports.

Cet utilisateur doit disposer des droits nécessaires pour créer et gérer les tiers.

7.3 Générer la clé API

Depuis la fiche de l'utilisateur :

Utilisateurs & Groupes
→ Utilisateur
→ Modifier / Fiche utilisateur

Générer une clé API.

Cette clé permet au script d'import de s'authentifier auprès de Dolibarr.

Ne jamais publier une vraie clé API sur GitHub.

8. Configuration du fichier .env

Le projet utilise un fichier .env pour stocker les paramètres nécessaires à l'utilisation de l'API.

Si un fichier .env.example est fourni, créer le fichier .env à partir de celui-ci :

cp .env.example .env

Modifier ensuite le fichier :

nano .env

Renseigner les paramètres nécessaires.

Exemple :

DOLIBARR_URL=http://localhost:8080
DOLIBARR_API_KEY=VOTRE_CLE_API

Remplacer :

VOTRE_CLE_API

par la clé API générée dans Dolibarr.

Le fichier .env contient des informations sensibles.

Il ne doit donc pas être publié sur GitHub.

Le fichier .env doit être présent dans .gitignore.

9. Préparation des fichiers CSV

Les fichiers CSV utilisés pour les tests sont placés dans le dossier prévu à cet effet, généralement :

data/

Les fichiers peuvent contenir les informations des tiers, par exemple :

Nom
Email
Téléphone
Adresse
Code postal
Ville

Les fichiers CSV utilisés dans le cadre du projet peuvent être des données virtuelles de test.

10. Import automatisé des données

Une fois :

Dolibarr installé ;
Dolibarr configuré ;
l'API REST activée ;
l'utilisateur API créé ;
la clé API générée ;
le fichier .env configuré ;

le script d'import peut être lancé.

Rendre le script exécutable si nécessaire :

chmod +x "import csv.sh"

Lancer ensuite :

./import\ csv.sh

Le script utilise l'API REST de Dolibarr pour communiquer avec l'ERP et importer automatiquement les données.

Les données concernent principalement les Tiers :

clients ;
fournisseurs.

Après l'import, vérifier dans Dolibarr :

Tiers
→ Liste des tiers

Les données importées doivent apparaître dans la liste.

11. Fonctionnement général

Le fonctionnement du projet est le suivant :

+----------------+
|  Fichier CSV   |
+----------------+
        |
        v
+----------------+
| import csv.sh  |
+----------------+
        |
        v
+----------------+
|  API REST      |
|   Dolibarr     |
+----------------+
        |
        v
+----------------+
|   Dolibarr     |
+----------------+
        |
        v
+----------------+
| Tiers clients  |
| fournisseurs   |
+----------------+

L'utilisation de l'API permet d'automatiser l'import des données sans devoir effectuer manuellement chaque import depuis l'interface graphique de Dolibarr.

12. Sauvegarde et restauration

Les données de Dolibarr et MariaDB sont stockées dans des volumes Docker persistants.

Une sauvegarde doit être réalisée afin de pouvoir restaurer les données en cas de problème.

L'objectif est de pouvoir :

sauvegarder les données ;
supprimer l'environnement ;
recréer l'environnement ;
restaurer les données ;
retrouver un Dolibarr fonctionnel.

Les procédures de sauvegarde et de restauration sont documentées dans le dossier :

docs/
13. Structure du projet
sae-dolibarr/
│
├── data/              # Fichiers CSV de test
├── docs/              # Documentation complémentaire
├── sources/           # Scripts et fichiers sources
├── tests/             # Tests
├── volumes/           # Données persistantes Docker
│
├── .env.example       # Exemple de configuration
├── .gitignore         # Fichiers exclus du dépôt Git
│
├── install.sh         # Script principal d'installation
├── import csv.sh      # Script d'import CSV
│
├── readme.md          # Documentation principale
└── suivi_projet.md    # Journal de bord
14. Test complet du projet

Le projet doit être testé depuis un environnement propre afin de vérifier qu'un nouvel utilisateur peut l'utiliser uniquement avec le dépôt et la documentation.

Étape 1 : cloner le projet
git clone https://github.com/mohammad/sae-dolibarr.git
cd sae-dolibarr
Étape 2 : vérifier les prérequis
docker --version
docker compose version
git --version
Étape 3 : lancer l'installation
chmod +x install.sh
./install.sh
Étape 4 : accéder à Dolibarr

Ouvrir :

http://localhost:8080

Terminer la configuration initiale de Dolibarr.

Étape 5 : créer l'utilisateur API

Créer un utilisateur destiné à l'import des données.

Étape 6 : activer l'API

Activer le module API REST depuis :

Configuration
→ Modules/Applications
→ API REST
Étape 7 : générer la clé API

Générer une clé API pour l'utilisateur créé.

Étape 8 : configurer .env

Créer le fichier :

cp .env.example .env

Puis renseigner la clé API :

nano .env

Exemple :

DOLIBARR_URL=http://localhost:8080
DOLIBARR_API_KEY=VOTRE_CLE_API
Étape 9 : lancer l'import
chmod +x "import csv.sh"
./import\ csv.sh
Étape 10 : vérifier les résultats

Dans Dolibarr :

Tiers
→ Liste des tiers

Vérifier que les données présentes dans les fichiers CSV ont bien été importées.

15. Sécurité

Les informations sensibles ne doivent pas être présentes dans le dépôt GitHub.

Il ne faut notamment pas publier :

les clés API ;
les mots de passe MariaDB ;
les mots de passe Dolibarr ;
les fichiers .env.

Le fichier .env doit être exclu du dépôt grâce au fichier .gitignore.

Un fichier .env.example peut être fourni afin d'indiquer les paramètres nécessaires sans exposer les informations sensibles.

16. Résultat attendu

À la fin de l'installation, l'utilisateur doit pouvoir :

lancer l'environnement Dolibarr ;
accéder à l'interface web ;
configurer un utilisateur ;
activer l'API REST ;
générer une clé API ;
configurer le fichier .env ;
lancer le script import csv.sh ;
importer automatiquement les données CSV ;
retrouver les clients et fournisseurs dans Dolibarr ;
sauvegarder et restaurer les données.
17. Conclusion

Ce projet permet de mettre en place une solution ERP/CRM Dolibarr hébergée en interne et de simplifier son déploiement.

L'utilisation de Docker permet d'isoler Dolibarr et MariaDB.

Les scripts permettent d'automatiser l'installation et l'import des données.

L'API REST de Dolibarr permet au script d'import de communiquer automatiquement avec l'ERP.

Le projet est ainsi reproductible à partir du dépôt GitHub et peut être testé sur une nouvelle installation en suivant les étapes présentées dans ce README.
