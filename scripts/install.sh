#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "======================================"
echo " SAE DOLIBARR - INSTALLATION"
echo "======================================"

if [ ! -f ".env" ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

set -a
source .env
set +a

if ! command -v docker >/dev/null 2>&1; then
    echo "ERREUR : Docker n'est pas installé."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "ERREUR : Docker Compose n'est pas disponible."
    exit 1
fi

echo "[1/4] Création des dossiers..."

mkdir -p data
mkdir -p backups
mkdir -p volumes/mariadb
mkdir -p volumes/dolibarr_documents
mkdir -p volumes/dolibarr_custom

echo "[2/4] Vérification de Docker..."

docker info >/dev/null

echo "[3/4] Démarrage de MariaDB..."

docker compose up -d mariadb

echo "Attente de MariaDB..."

for i in $(seq 1 60); do
    if docker compose exec -T mariadb \
        mariadb-admin ping \
        -uroot \
        -p"${MYSQL_ROOT_PASSWORD}" \
        --silent >/dev/null 2>&1
    then
        echo "MariaDB est disponible."
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "ERREUR : MariaDB n'est pas disponible."
        docker compose logs mariadb
        exit 1
    fi

    sleep 2
done

echo "[4/4] Démarrage de Dolibarr..."

docker compose up -d dolibarr

echo
echo "======================================"
echo " INSTALLATION TERMINEE"
echo "======================================"

docker compose ps

echo
echo "Dolibarr : http://localhost:8080"
