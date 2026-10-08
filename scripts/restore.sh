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

# Vérifie qu'un chemin vers une sauvegarde a été fourni
if [ -z "$1" ]; then
    echo "Usage : ./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS"
    exit 1
fi

# Définit le chemin complet du dossier de sauvegarde
BACKUP_DIR="$PROJECT_DIR/$1"

# Vérifie que le dossier de sauvegarde existe
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERREUR : dossier de sauvegarde absent."
    exit 1
fi

# Vérifie que le fichier de sauvegarde de la base de données existe
if [ ! -f "$BACKUP_DIR/database.sql" ]; then
    echo "ERREUR : database.sql absent."
    exit 1
fi

# Charge les variables présentes dans le fichier .env
set -a
source .env
set +a

# Affiche le titre du processus de restauration
echo "======================================"
echo " RESTAURATION DOLIBARR"
echo "======================================"

# Étape 1 : arrêt du conteneur Dolibarr
echo "[1/5] Arrêt de Dolibarr..."

# Arrête le conteneur Dolibarr avant de restaurer les données
docker compose stop dolibarr

# Étape 2 : réinitialisation de la base de données
echo "[2/5] Réinitialisation de la base..."

# Supprime la base existante puis la recrée
# avec l'encodage UTF-8 et la collation utf8mb4
docker compose exec -T mariadb \
    sh -c 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'

# Étape 3 : restauration de la base de données
echo "[3/5] Restauration de la base..."

# Envoie le fichier database.sql vers MariaDB
# afin de restaurer les données sauvegardées
cat "$BACKUP_DIR/database.sql" | \
docker compose exec -T mariadb \
    sh -c 'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"'

# Étape 4 : restauration des documents Dolibarr
echo "[4/5] Restauration des documents..."