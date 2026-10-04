#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -f ".env" ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

set -a
source .env
set +a

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$PROJECT_DIR/backups/$DATE"

mkdir -p "$BACKUP_DIR"

echo "======================================"
echo " SAUVEGARDE DOLIBARR"
echo "======================================"

echo "[1/4] Sauvegarde de la base MariaDB..."

docker compose exec -T mariadb \
    sh -c 'mariadb-dump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
    > "$BACKUP_DIR/database.sql"

echo "[2/4] Sauvegarde des documents..."

tar -czf "$BACKUP_DIR/documents.tar.gz" \
    volumes/dolibarr_documents

echo "[3/4] Sauvegarde des modules personnalisés..."

tar -czf "$BACKUP_DIR/custom.tar.gz" \
    volumes/dolibarr_custom

echo "[4/4] Sauvegarde de la configuration..."

cp docker-compose.yml "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/env.backup"

echo
echo "======================================"
echo " SAUVEGARDE TERMINEE"
echo "======================================"

echo "Sauvegarde disponible dans :"
echo "$BACKUP_DIR"
