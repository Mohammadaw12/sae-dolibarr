
#!/bin/bash

# Active plusieurs options de sécurité :
# -E : transmet les pièges ERR aux fonctions et sous-shells.
# -e : arrête le script lorsqu'une commande échoue.
# -u : signale l'utilisation d'une variable non définie.
# -o pipefail : considère un pipeline en échec si une de ses commandes échoue.
set -Eeuo pipefail

# ==========================================================
# SAE 5.1 - Installation automatique de Dolibarr
# Compatible Debian
# ==========================================================

# Se placer à la racine du projet, quel que soit le répertoire
# depuis lequel le script est lancé.
# readlink -f récupère le chemin absolu du script.
# dirname identifie son répertoire, puis /.. remonte à la racine.
cd "$(dirname "$(readlink -f "$0")")/.."

# Affiche le titre de l'installation dans le terminal.
echo "=========================================="
echo " Installation automatique de Dolibarr"
echo "=========================================="

# ----------------------------------------------------------
# 1. Vérifier les droits administrateur
# ----------------------------------------------------------

# id -u retourne l'identifiant de l'utilisateur actuel.
# L'identifiant 0 correspond à l'utilisateur root.
if [ "$(id -u)" -ne 0 ]; then
    # Affiche un message si le script n'est pas lancé en administrateur.
    echo "ERREUR : lance le script avec sudo."
    echo "Commande : sudo bash scripts/install.sh"

    # Arrête le script avec un code d'erreur.
    exit 1
fi

# ----------------------------------------------------------
# 2. Vérifier le système
# ----------------------------------------------------------

# Vérifie que le fichier contenant les informations du système existe.
if [ ! -f /etc/os-release ]; then
    echo "ERREUR : système Linux non reconnu."
    exit 1
fi

# Charge les informations du système :
# ID, VERSION_ID, VERSION_CODENAME, etc.
. /etc/os-release

# Vérifie que le système utilisé est Debian.
# ${ID:-} évite une erreur si la variable ID n'est pas définie.
if [ "${ID:-}" != "debian" ]; then
    echo "ERREUR : ce script est prévu pour Debian."
    exit 1
fi

# ----------------------------------------------------------
# 3. Installer Docker et Compose si nécessaire
# ----------------------------------------------------------

# Vérifie si Docker est installé et si la commande
# Docker Compose fonctionne.
# >/dev/null 2>&1 masque les sorties et les erreurs.
# Si l'une des vérifications échoue, le bloc d'installation est exécuté.
if ! command -v docker >/dev/null 2>&1 || \
   ! docker compose version >/dev/null 2>&1; then

    echo "Installation de Docker et Docker Compose..."

    # Actualise la liste des paquets disponibles.
    # Installe les certificats et curl, nécessaires au téléchargement.
    apt-get update
    apt-get install -y ca-certificates curl

    # Crée le répertoire destiné aux clés des dépôts APT.
    # -m 0755 définit les permissions du répertoire.
    install -m 0755 -d /etc/apt/keyrings

    # Télécharge la clé GPG officielle du dépôt Docker pour Debian.
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc

    # Autorise la lecture de la clé par les utilisateurs et les outils APT.
    chmod a+r /etc/apt/keyrings/docker.asc

    # Récupère l'architecture du système, par exemple amd64 ou arm64.
    ARCH=$(dpkg --print-architecture)

    # Ajoute le dépôt officiel Docker à la configuration APT.
    # L'architecture et la clé GPG sont précisées pour vérifier les paquets.
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list

    # Actualise la liste des paquets en incluant le nouveau dépôt.
    apt-get update

    # Installe Docker Engine, ses outils en ligne de commande,
    # le runtime de conteneurs et les extensions Compose et Buildx.
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    echo "Docker et Docker Compose installés."
fi

# ----------------------------------------------------------
# 4. Installer curl si nécessaire
# ----------------------------------------------------------

# Vérifie si la commande curl est disponible.
# Elle sera utilisée plus tard pour tester l'accès à Dolibarr.
if ! command -v curl >/dev/null 2>&1; then

    # Met à jour les dépôts et installe curl s'il manque.
    apt-get update
    apt-get install -y curl
fi

# ----------------------------------------------------------
# 5. Démarrer Docker
# ----------------------------------------------------------

echo "Vérification du service Docker..."

# Configure Docker pour démarrer automatiquement au démarrage
# du système et le démarre immédiatement.
systemctl enable --now docker

# Vérifie que le démon Docker répond correctement.
# Si docker info échoue, le script s'arrête.
if ! docker info >/dev/null 2>&1; then
    echo "ERREUR : le service Docker ne fonctionne pas."
    exit 1
fi

# ----------------------------------------------------------
# 6. Vérifier les fichiers du projet
# ----------------------------------------------------------

# Vérifie que le fichier Docker Compose existe à la racine du projet.
# Il définit les services, les images, les ports et les volumes.
if [ ! -f docker-compose.yml ]; then
    echo "ERREUR : docker-compose.yml est introuvable."
    exit 1
fi

# ----------------------------------------------------------
# 7. Vérifier le fichier .env
# ----------------------------------------------------------

# Vérifie si le fichier .env contenant les paramètres
# et les mots de passe du projet existe.
if [ ! -f .env ]; then

    # Si .env est absent, vérifie qu'un modèle est disponible.
    if [ ! -f .env.example ]; then
        echo "ERREUR : .env.example est introuvable."
        exit 1
    fi

    # Copie le modèle pour créer le fichier de configuration local.
    cp .env.example .env

    # Limite les permissions du fichier au propriétaire.
    # Cela protège notamment les mots de passe qu'il contient.
    chmod 600 .env

    # Informe l'utilisateur qu'il doit compléter la configuration.
    echo
    echo "Le fichier .env a été créé."
    echo "Configure les mots de passe puis relance :"
    echo "sudo bash scripts/install.sh"

    # Arrête l'installation afin de laisser le temps
    # de configurer les variables dans .env.
    exit 1
fi

# Charge les variables définies dans .env dans l'environnement du script.
# set -a exporte automatiquement les variables déclarées ensuite.
set -a
source .env
# Désactive l'export automatique après le chargement.
set +a

# ----------------------------------------------------------
# 8. Vérifier les variables obligatoires
# ----------------------------------------------------------

# Parcourt la liste des variables nécessaires au déploiement.
for variable in \
    MYSQL_ROOT_PASSWORD \
    MYSQL_DATABASE \
    MYSQL_USER \
    MYSQL_PASSWORD \
    DOLI_ADMIN_LOGIN \
    DOLI_ADMIN_PASSWORD \
    DOLI_URL_ROOT
do
    # Vérifie si chaque variable est absente ou vide.
    # ${!variable} récupère la valeur de la variable dont le nom
    # est contenu dans la variable "variable".
    if [ -z "${!variable:-}" ]; then
        echo "ERREUR : variable ${variable} absente ou vide dans .env."
        exit 1
    fi
done

# ----------------------------------------------------------
# 9. Vérifier Docker Compose
# ----------------------------------------------------------

echo "Vérification de docker-compose.yml..."

# Vérifie la validité de la configuration Docker Compose.
# -q effectue le contrôle sans afficher toute la configuration.
docker compose config -q

# ----------------------------------------------------------
# 10. Créer les dossiers nécessaires
# ----------------------------------------------------------

# Crée les répertoires nécessaires au stockage des données.
# -p crée également les répertoires parents si nécessaire
# et ne renvoie pas d'erreur s'ils existent déjà.
mkdir -p \
    volumes/mariadb \
    volumes/dolibarr_documents \
    volumes/dolibarr_custom \
    backups

# volumes/mariadb : fichiers de la base de données MariaDB.
# volumes/dolibarr_documents : documents gérés par Dolibarr.
# volumes/dolibarr_custom : modules et fichiers personnalisés.
# backups : sauvegardes de la base et des fichiers.

# ----------------------------------------------------------
# 11. Démarrer MariaDB
# ----------------------------------------------------------

echo
echo "Démarrage de MariaDB..."

# Crée et démarre le service MariaDB en arrière-plan.
# -d permet de rendre la main au script sans attendre sa fermeture.
docker compose up -d mariadb

echo "Attente du démarrage de MariaDB..."

# Initialise l'indicateur d'état à false.
# Il passera à true dès que MariaDB répondra.
DB_READY=false

# Effectue jusqu'à 60 tentatives de connexion.
# Chaque tentative est espacée de 3 secondes.
for i in $(seq 1 60); do

    # Exécute mariadb-admin ping à l'intérieur du conteneur MariaDB.
    # -T désactive l'allocation d'un pseudo-terminal.
    # Le test utilise les identifiants root et le mot de passe
    # transmis par la variable MYSQL_ROOT_PASSWORD du conteneur.
    if docker compose exec -T mariadb sh -c \
        'mariadb-admin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
        >/dev/null 2>&1; then

        # MariaDB répond : mémorise que la base est prête.
        DB_READY=true
        break
    fi

    # Affiche le numéro de la tentative en cours.
    echo "Attente de MariaDB : ${i}/60"

    # Attend trois secondes avant de réessayer.
    sleep 3
done

# Si aucune tentative n'a réussi, affiche les journaux
# du conteneur pour faciliter le diagnostic.
if [ "$DB_READY" != true ]; then
    echo "ERREUR : MariaDB ne répond pas."
    docker compose logs --tail=100 mariadb
    exit 1
fi

echo "MariaDB est prête."

# ----------------------------------------------------------
# 12. Démarrer Dolibarr
# ----------------------------------------------------------

echo
echo "Démarrage de Dolibarr..."

# Crée et démarre le service Dolibarr en arrière-plan.
# La configuration Compose prévoit que MariaDB soit démarrée
# et en bonne santé avant le lancement de Dolibarr.
docker compose up -d dolibarr

# ----------------------------------------------------------
# 13. Attendre que Dolibarr réponde
# ----------------------------------------------------------

echo
echo "Attente du démarrage de Dolibarr..."

# Initialise l'indicateur de disponibilité de Dolibarr.
DOLIBARR_READY=false

# Effectue jusqu'à 90 tentatives de vérification.
# Chaque tentative est espacée de 5 secondes.
for i in $(seq 1 90); do

    # Envoie une requête HTTP à l'adresse locale de Dolibarr.
    # -f considère les réponses HTTP d'erreur comme un échec.
    # -s masque la progression et -S affiche les erreurs éventuelles.
    # --max-time 5 limite la durée de chaque requête à cinq secondes.
    if curl -fsS --max-time 5 \
        http://127.0.0.1:8080/ >/dev/null 2>&1; then

        # Une réponse HTTP valide a été obtenue.
        DOLIBARR_READY=true
        break
    fi

    # Informe l'utilisateur que l'application démarre encore.
    echo "Dolibarr initialise ses services : ${i}/90"

    # Attend cinq secondes avant la prochaine vérification.
    sleep 5
done

# ----------------------------------------------------------
# 14. Diagnostics si Dolibarr ne répond pas
# ----------------------------------------------------------

# Si Dolibarr n'a pas répondu après les tentatives,
# affiche plusieurs informations pour identifier la panne.
if [ "$DOLIBARR_READY" != true ]; then

    echo
    echo "ERREUR : Dolibarr ne répond pas."

    # Affiche l'état de tous les conteneurs, y compris ceux arrêtés.
    echo
    echo "État des conteneurs :"
    docker ps -a

    # Affiche les 100 dernières lignes des journaux de Dolibarr.
    echo
    echo "Derniers journaux de Dolibarr :"
    docker compose logs --tail=100 dolibarr

    # Affiche les 60 dernières lignes des journaux de MariaDB.
    echo
    echo "Derniers journaux de MariaDB :"
    docker compose logs --tail=60 mariadb

    # Effectue un test HTTP détaillé pour aider à diagnostiquer
    # un problème de connexion sur le port local 8080.
    echo
    echo "Test de connexion locale :"
    curl -v --max-time 5 http://127.0.0.1:8080/ || true

    # Signale que cette étape n'a pas désactivé UFW.
    echo
    echo "UFW n'a pas été désactivé par cette étape."

    # Termine le script avec un code d'erreur.
    exit 1
fi

# ----------------------------------------------------------
# 15. Activer le module API REST
# ----------------------------------------------------------

echo
echo "Vérification du module API REST..."

# Initialise l'indicateur indiquant si les tables nécessaires
# ont été trouvées dans la base de données.
API_TABLES_OK=false

# Vérifie l'existence des tables llx_const et llx_user.
# llx_const contient notamment des paramètres de configuration.
# llx_user contient les comptes utilisateurs de Dolibarr.
# grep -qx vérifie que la sortie correspond exactement au nom attendu.
# Le && impose la réussite des deux vérifications.
if docker compose exec -T mariadb sh -c \
    'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -Nse "SHOW TABLES LIKE '\''llx_const'\'';"' \
    2>/dev/null | grep -qx 'llx_const' \
    && docker compose exec -T mariadb sh -c \
    'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -Nse "SHOW TABLES LIKE '\''llx_user'\'';"' \
    2>/dev/null | grep -qx 'llx_user'; then

    # Les deux tables sont présentes.
    API_TABLES_OK=true
fi

# Ne tente l'activation que si les tables ont été trouvées.
if [ "$API_TABLES_OK" = true ]; then

    # Exécute une requête SQL pour activer la constante
    # MAIN_MODULE_API dans la table de configuration de Dolibarr.
    # INSERT ajoute la constante si elle n'existe pas.
    # ON DUPLICATE KEY UPDATE met sa valeur à jour si elle existe.
    # Le bloc SQL est transmis à MariaDB par l'entrée standard.
    if docker compose exec -T mariadb sh -c \
        'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' \
        >/dev/null 2>&1 <<'SQL'
INSERT INTO llx_const
    (name, entity, value, type, visible, note)
VALUES
    ('MAIN_MODULE_API', 0, '1', 'yes', 0, 'Activation API REST')
ON DUPLICATE KEY UPDATE
    value = '1',
    type = 'yes';
SQL
    then
        # La requête SQL a été exécutée sans signaler d'erreur.
        echo "Activation de la constante du module API effectuée."
    else
        # Informe l'utilisateur si l'activation automatique échoue.
        echo "ATTENTION : activation automatique de l'API impossible."
        echo "Active le module API REST depuis l'interface Dolibarr."
    fi

else
    # Si les tables n'existent pas, la base n'est peut-être
    # pas encore initialisée ou son installation est incomplète.
    echo "ATTENTION : les tables llx_const ou llx_user sont absentes."
    echo "La base Dolibarr n'est peut-être pas initialisée correctement."
    echo "Le module API n'a pas été activé automatiquement."
fi

# ----------------------------------------------------------
# 16. Autoriser le port 8080 puis désactiver UFW à la fin
# ----------------------------------------------------------

echo
echo "Configuration finale du pare-feu..."

# Vérifie si l'outil UFW est installé.
if command -v ufw >/dev/null 2>&1; then

    # Ajoute une règle autorisant les connexions TCP sur le port 8080.
    # Ce port est utilisé par Dolibarr dans la configuration du projet.
    ufw allow 8080/tcp
    echo "Port 8080/tcp autorisé."

    # Désactive complètement le pare-feu UFW sans demander confirmation.
    # ATTENTION : cela réduit la protection du système.
    # Cette commande n'est pas recommandée sur un serveur exposé
    # ou en environnement de production.
    ufw --force disable
    echo "Pare-feu UFW désactivé."

fi

# ----------------------------------------------------------
# 17. Message final minimal
# ----------------------------------------------------------

# Affiche un message indiquant que les étapes du script
# sont terminées sans erreur bloquante.
# Cela ne garantit pas à lui seul que toutes les fonctionnalités
# de Dolibarr, notamment la connexion à l'interface, sont opérationnelles.
echo
echo "=========================================="
echo " INSTALLATION TERMINÉE AVEC SUCCÈS"
echo "=========================================="
