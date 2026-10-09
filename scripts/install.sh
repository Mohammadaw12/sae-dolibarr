#!/bin/bash
set -Eeuo pipefail

# ==========================================================
# SAE 5.1 - Installation automatique de Dolibarr
# ==========================================================

# Se placer à la racine du projet
cd "$(dirname "$0")/.."

echo "=========================================="
echo " Installation automatique de Dolibarr"
echo "=========================================="

# ----------------------------------------------------------
# 1. Vérifier les droits administrateur
# ----------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "ERREUR : lance le script avec sudo."
    echo "Commande : sudo ./scripts/install.sh"
    exit 1
fi

# ----------------------------------------------------------
# 2. Installer Docker et Compose si nécessaire (Debian)
# ----------------------------------------------------------

if ! command -v docker >/dev/null 2>&1 || \
   ! docker compose version >/dev/null 2>&1; then

    echo "Installation de Docker et Docker Compose..."

    . /etc/os-release

    if [ "${ID:-}" != "debian" ]; then
        echo "ERREUR : ce script d'installation automatique est prévu pour Debian."
        exit 1
    fi

    apt-get update
    apt-get install -y ca-certificates curl

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update

    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    systemctl enable --now docker

    echo "Docker est installé."
fi

# Vérifier que le service Docker fonctionne
if ! systemctl is-active --quiet docker; then
    systemctl enable --now docker
fi

# ----------------------------------------------------------
# 3. Vérifier le fichier .env
# ----------------------------------------------------------

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        chmod 600 .env

        echo
        echo "Le fichier .env vient d'être créé."
        echo "Configure les mots de passe dans .env puis relance :"
        echo "sudo ./scripts/install.sh"
        exit 1
    else
        echo "ERREUR : .env.example est introuvable."
        exit 1
    fi
fi

# Charger les variables d'environnement
set -a
source .env
set +a

# ----------------------------------------------------------
# 4. Vérifier les variables obligatoires
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
        echo "ERREUR : variable $variable absente ou vide dans .env."
        exit 1
    fi
done

# ----------------------------------------------------------
# 5. Vérifier la configuration Docker Compose
# ----------------------------------------------------------

echo "Vérification de docker-compose.yml..."
docker compose config -q

# ----------------------------------------------------------
# 6. Créer les dossiers nécessaires
# ----------------------------------------------------------

mkdir -p \
    volumes/mariadb \
    volumes/dolibarr_documents \
    volumes/dolibarr_custom \
    backups

# ----------------------------------------------------------
# 7. Démarrer MariaDB
# ----------------------------------------------------------

echo
echo "Démarrage de MariaDB..."
docker compose up -d mariadb

echo "Attente de MariaDB..."

DB_READY=false

for i in $(seq 1 60); do
    if docker compose exec -T mariadb sh -c \
        'mariadb-admin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
        >/dev/null 2>&1; then
        DB_READY=true
        break
    fi

    sleep 3
done

if [ "$DB_READY" != true ]; then
    echo "ERREUR : MariaDB ne répond pas."
    docker compose logs --tail=80 mariadb
    exit 1
fi

echo "MariaDB est prête."

# ----------------------------------------------------------
# 8. Démarrer Dolibarr
# ----------------------------------------------------------

echo
echo "Démarrage de Dolibarr..."
docker compose up -d dolibarr

# ----------------------------------------------------------
# 9. Attendre que Dolibarr réponde
# ----------------------------------------------------------

echo "Attente du démarrage de Dolibarr..."

DOLIBARR_READY=false

for i in $(seq 1 60); do
    if curl -fsS http://localhost:8080/ >/dev/null 2>&1; then
        DOLIBARR_READY=true
        break
    fi

    sleep 5
done

if [ "$DOLIBARR_READY" != true ]; then
    echo "ERREUR : Dolibarr ne répond pas sur le port 8080."
    docker compose logs --tail=100 dolibarr
    exit 1
fi

# ----------------------------------------------------------
# 10. Afficher le résultat
# ----------------------------------------------------------

echo
echo "=========================================="
echo " Dolibarr répond correctement"
echo "=========================================="
echo "Adresse : $DOLI_URL_ROOT"
echo "Identifiant configuré : $DOLI_ADMIN_LOGIN"
echo "Mot de passe : celui défini dans .env"
echo
echo "Afficher les journaux :"
echo "docker compose logs -f"
echo
echo "Arrêter les services :"
echo "docker compose down"
echo
echo "Les données sont conservées dans volumes/."
echo "=========================================="