#!/bin/bash

# Arrête le script immédiatement si une commande retourne une erreur
set -e

# Définit le répertoire racine du projet
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Vérifie que le fichier .env existe
if [ ! -f ".env" ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

# Charge les variables présentes dans le fichier .env
set -a
source .env
set +a

# Génère la date et l'heure de la sauvegarde
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

# Définit le dossier dans lequel sera stockée la sauvegarde
BACKUP_DIR="$PROJECT_DIR/backups/$DATE"

# Crée le dossier de sauvegarde s'il n'existe pas
mkdir -p "$BACKUP_DIR"

# Affiche le titre du processus de sauvegarde
echo "======================================"
echo " SAUVEGARDE DOLIBARR"
echo "======================================"

# Étape 1 : sauvegarde de la base de données MariaDB
echo "[1/4] Sauvegarde de la base MariaDB..."

# Exécute mariadb-dump dans le conteneur MariaDB
# Le résultat est enregistré dans un fichier database.sql
docker compose exec -T mariadb \
    sh -c 'mariadb-dump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
    > "$BACKUP_DIR/database.sql"

# Étape 2 : sauvegarde des documents Dolibarr
echo "[2/4] Sauvegarde des documents..."

# Crée une archive compressée contenant les documents de Dolibarr
# L'archive est enregistrée dans le dossier de sauvegarde
tar -czf "$BACKUP_DIR/documents.tar.gz" \
    volumes/dolibarr_documents

# Étape 3 : sauvegarde des modules personnalisés
echo "[3/4] Sauvegarde des modules personnalisés..."

# Crée une archive compressée contenant les modules personnalisés
tar -czf "$BACKUP_DIR/custom.tar.gz" \
    volumes/dolibarr_custom

# Étape 4 : sauvegarde de la configuration du projet
echo "[4/4] Sauvegarde de la configuration..."

# Copie le fichier Docker Compose dans le dossier de sauvegarde
cp docker-compose.yml "$BACKUP_DIR/"

# Copie le fichier .env sous le nom env.backup
cp .env "$BACKUP_DIR/env.backup"

# Affiche un message indiquant que la sauvegarde est terminée
echo
echo "======================================"
echo " SAUVEGARDE TERMINEE"
echo "======================================"

# Affiche l'emplacement du dossier contenant la sauvegarde
echo "Sauvegarde disponible dans :"
echo "$BACKUP_DIR"