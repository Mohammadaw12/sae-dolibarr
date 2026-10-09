#!/bin/bash
set -Eeuo pipefail

# ==========================================================
# SAE 5.1 - Installation automatique de Dolibarr
# Compatible Debian
# ==========================================================

# Se placer à la racine du projet
cd "$(dirname "$(readlink -f "$0")")/.."

echo "=========================================="
echo " Installation automatique de Dolibarr"
echo "=========================================="

# ----------------------------------------------------------
# 1. Vérifier les droits administrateur
# ----------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "ERREUR : lance le script avec sudo."
    echo "Commande : sudo bash scripts/install.sh"
    exit 1
fi

# ----------------------------------------------------------
# 2. Vérifier le système
# ----------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    echo "ERREUR : système Linux non reconnu."
    exit 1
fi

. /etc/os-release

if [ "${ID:-}" != "debian" ]; then
    echo "ERREUR : ce script est prévu pour Debian."
    exit 1
fi

# ----------------------------------------------------------
# 3. Installer Docker et Compose si nécessaire
# ----------------------------------------------------------

if ! command -v docker >/dev/null 2>&1 || \
   ! docker compose version >/dev/null 2>&1; then

    echo "Installation de Docker et Docker Compose..."

    apt-get update
    apt-get install -y ca-certificates curl

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    ARCH=$(dpkg --print-architecture)

    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update

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

if ! command -v curl >/dev/null 2>&1; then
    apt-get update
    apt-get install -y curl
fi

# ----------------------------------------------------------
# 5. Démarrer Docker
# ----------------------------------------------------------

echo "Vérification du service Docker..."

systemctl enable --now docker

if ! docker info >/dev/null 2>&1; then
    echo "ERREUR : le service Docker ne fonctionne pas."
    exit 1
fi

# ----------------------------------------------------------
# 6. Vérifier les fichiers du projet
# ----------------------------------------------------------

if [ ! -f docker-compose.yml ]; then
    echo "ERREUR : docker-compose.yml est introuvable."
    exit 1
fi

# ----------------------------------------------------------
# 7. Vérifier le fichier .env
# ----------------------------------------------------------

if [ ! -f .env ]; then

    if [ ! -f .env.example ]; then
        echo "ERREUR : .env.example est introuvable."
        exit 1
    fi

    cp .env.example .env
    chmod 600 .env

    echo
    echo "Le fichier .env a été créé."
    echo "Configure les mots de passe puis relance :"
    echo "sudo bash scripts/install.sh"
    exit 1
fi

# Charger les variables d'environnement
set -a
source .env
set +a

# ----------------------------------------------------------
# 8. Vérifier les variables obligatoires
# ----------------------------------------------------------

for variable in \
    MYSQL_ROOT_PASSWORD \
    MYSQL_DATABASE \
    MYSQL_USER \
    MYSQL_PASSWORD \
    DOLI_ADMIN_LOGIN \
    DOLI_ADMIN_PASSWORD \
    DOLI_URL_ROOT
do
    if [ -z "${!variable:-}" ]; then
        echo "ERREUR : variable ${variable} absente ou vide dans .env."
        exit 1
    fi
done

# ----------------------------------------------------------
# 9. Vérifier Docker Compose
# ----------------------------------------------------------

echo "Vérification de docker-compose.yml..."

docker compose config -q

# ----------------------------------------------------------
# 10. Créer les dossiers nécessaires
# ----------------------------------------------------------

mkdir -p \
    volumes/mariadb \
    volumes/dolibarr_documents \
    volumes/dolibarr_custom \
    backups

# ----------------------------------------------------------
# 11. Démarrer MariaDB
# ----------------------------------------------------------

echo
echo "Démarrage de MariaDB..."

docker compose up -d mariadb

echo "Attente du démarrage de MariaDB..."

DB_READY=false

for i in $(seq 1 60); do

    if docker compose exec -T mariadb sh -c \
        'mariadb-admin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
        >/dev/null 2>&1; then

        DB_READY=true
        break
    fi

    echo "Attente de MariaDB : ${i}/60"
    sleep 3
done

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

docker compose up -d dolibarr

# ----------------------------------------------------------
# 13. Attendre que Dolibarr réponde
# ----------------------------------------------------------

echo
echo "Attente du démarrage de Dolibarr..."

DOLIBARR_READY=false

for i in $(seq 1 90); do

    if curl -fsS --max-time 5 \
        http://127.0.0.1:8080/ >/dev/null 2>&1; then

        DOLIBARR_READY=true
        break
    fi

    echo "Dolibarr initialise ses services : ${i}/90"
    sleep 5
done

# ----------------------------------------------------------
# 14. Diagnostics si Dolibarr ne répond pas
# ----------------------------------------------------------

if [ "$DOLIBARR_READY" != true ]; then

    echo
    echo "ERREUR : Dolibarr ne répond pas."

    echo
    echo "État des conteneurs :"
    docker ps -a

    echo
    echo "Derniers journaux de Dolibarr :"
    docker compose logs --tail=100 dolibarr

    echo
    echo "Derniers journaux de MariaDB :"
    docker compose logs --tail=60 mariadb

    echo
    echo "Test de connexion locale :"
    curl -v --max-time 5 http://127.0.0.1:8080/ || true

    echo
    echo "UFW n'a pas été désactivé par cette étape."
    exit 1
fi

# ----------------------------------------------------------
# 15. Activer le module API REST
# ----------------------------------------------------------

echo
echo "Vérification du module API REST..."

API_TABLES_OK=false

if docker compose exec -T mariadb sh -c \
    'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -Nse "SHOW TABLES LIKE '\''llx_const'\'';"' \
    2>/dev/null | grep -qx 'llx_const' \
    && docker compose exec -T mariadb sh -c \
    'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -Nse "SHOW TABLES LIKE '\''llx_user'\'';"' \
    2>/dev/null | grep -qx 'llx_user'; then

    API_TABLES_OK=true
fi

if [ "$API_TABLES_OK" = true ]; then

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
        echo "Activation de la constante du module API effectuée."
    else
        echo "ATTENTION : activation automatique de l'API impossible."
        echo "Active le module API REST depuis l'interface Dolibarr."
    fi

else
    echo "ATTENTION : les tables llx_const ou llx_user sont absentes."
    echo "La base Dolibarr n'est peut-être pas initialisée correctement."
    echo "Le module API n'a pas été activé automatiquement."
fi

# ----------------------------------------------------------
# 16. Autoriser le port 8080 puis désactiver UFW à la fin
# ----------------------------------------------------------

echo
echo "Configuration finale du pare-feu..."

if command -v ufw >/dev/null 2>&1; then

    ufw allow 8080/tcp
    echo "Port 8080/tcp autorisé."

    ufw --force disable
    echo "Pare-feu UFW désactivé."

fi

# ----------------------------------------------------------
# 17. Message final minimal
# ----------------------------------------------------------

echo
echo "=========================================="
echo " INSTALLATION TERMINÉE AVEC SUCCÈS"
echo "=========================================="
