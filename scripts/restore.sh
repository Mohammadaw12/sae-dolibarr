
#!/bin/bash

# Arrête le script si une commande échoue
set -e

# Récupère le chemin absolu du répertoire racine du projet
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Se place dans le répertoire racine du projet
cd "$PROJECT_DIR"

# Vérifie que le fichier de configuration .env existe
if [ ! -f ".env" ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

# Vérifie qu'un chemin vers une sauvegarde a été fourni en argument
if [ -z "$1" ]; then
    echo "Usage : ./scripts/restore.sh backups/AAAA-MM-JJ_HH-MM-SS"
    exit 1
fi

# Construit le chemin complet du dossier de sauvegarde
BACKUP_DIR="$PROJECT_DIR/$1"

# Vérifie que le dossier de sauvegarde existe
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERREUR : dossier de sauvegarde absent."
    exit 1
fi

# Vérifie que le fichier SQL contenant la sauvegarde de la base existe
if [ ! -f "$BACKUP_DIR/database.sql" ]; then
    echo "ERREUR : database.sql absent."
    exit 1
fi

# Exporte les variables du fichier .env pour les rendre disponibles
# aux commandes exécutées ensuite
set -a
source .env
set +a

# Affiche le titre de la procédure de restauration
echo "======================================"
echo " RESTAURATION DOLIBARR"
echo "======================================"

# Étape 1 : arrêt du conteneur Dolibarr
echo "[1/5] Arrêt de Dolibarr..."

# Arrête l'application pendant la restauration
docker compose stop dolibarr

# Étape 2 : réinitialisation de la base de données
echo "[2/5] Réinitialisation de la base..."

# Supprime la base existante puis la recrée
# avec l'encodage UTF-8 et la collation utf8mb4
# ATTENTION : les données actuelles de cette base seront supprimées
docker compose exec -T mariadb \
    sh -c 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'

# Étape 3 : restauration de la base de données
echo "[3/5] Restauration de la base..."

# Lit le fichier database.sql et transmet son contenu à MariaDB
# pour réimporter les données sauvegardées
cat "$BACKUP_DIR/database.sql" | \
docker compose exec -T mariadb \
    sh -c 'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"'

# Étape 4 : restauration des documents Dolibarr
echo "[4/5] Restauration des documents..."

# Vérifie si l'archive des documents existe
if [ -f "$BACKUP_DIR/documents.tar.gz" ]; then

    # Supprime les fichiers actuellement présents dans le dossier
    # des documents avant de restaurer ceux de la sauvegarde
    rm -rf volumes/dolibarr_documents/*

    # Extrait l'archive des documents dans le répertoire racine du projet
    tar -xzf "$BACKUP_DIR/documents.tar.gz" -C "$PROJECT_DIR"
fi

# Étape 5 : restauration des modules personnalisés
echo "[5/5] Restauration des modules personnalisés..."

# Vérifie si l'archive des personnalisations existe
if [ -f "$BACKUP_DIR/custom.tar.gz" ]; then

    # Supprime les fichiers actuellement présents dans le dossier
    # des modules personnalisés
    rm -rf volumes/dolibarr_custom/*

    # Extrait l'archive des personnalisations dans le répertoire
    # racine du projet
    tar -xzf "$BACKUP_DIR/custom.tar.gz" -C "$PROJECT_DIR"
fi

# Redémarre le conteneur Dolibarr après la restauration
docker compose start dolibarr

# Affiche une ligne vide pour améliorer la lisibilité
echo

# Affiche le message de fin de restauration
echo "======================================"
echo " RESTAURATION TERMINEE"
echo "======================================"

# Affiche l'état des services Docker Compose
# pour vérifier si les conteneurs sont démarrés
docker compose ps
