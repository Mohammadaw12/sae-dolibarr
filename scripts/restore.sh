#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -f ".env" ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage : ./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS"
    exit 1
fi

BACKUP_DIR="$PROJECT_DIR/$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERREUR : dossier de sauvegarde absent."
    exit 1
fi

if [ ! -f "$BACKUP_DIR/database.sql" ]; then
    echo "ERREUR : database.sql absent."
    exit 1
fi

set -a
source .env
set +a

echo "======================================"
echo " RESTAURATION DOLIBARR"
echo "======================================"

echo "[1/5] Arrêt de Dolibarr..."

docker compose stop dolibarr

echo "[2/5] Réinitialisation de la base..."

docker compose exec -T mariadb \
    sh -c 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'

echo "[3/5] Restauration de la base..."

cat "$BACKUP_DIR/database.sql" | \
docker compose exec -T mariadb \
    sh -c 'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"'

echo "[4/5] Restauration des documents..."

if [ -f "$BACKUP_DIR/documents.tar.gz" ]; then
    rm -rf volumes/dolibarr_documents/*
    tar -xzf "$BACKUP_DIR/documents.tar.gz" -C "$PROJECT_DIR"
fi

echo "[5/5] Restauration des modules personnalisés..."

if [ -f "$BACKUP_DIR/custom.tar.gz" ]; then
    rm -rf volumes/dolibarr_custom/*
    tar -xzf "$BACKUP_DIR/custom.tar.gz" -C "$PROJECT_DIR"
fi

docker compose start dolibarr

echo
echo "======================================"
echo " RESTAURATION TERMINEE"
echo "======================================"

docker compose ps
