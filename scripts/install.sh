#!/bin/bash

# Arrête le script immédiatement si une commande retourne une erreur
set -e

# Définit le répertoire racine du projet
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Affiche le titre du processus d'installation
echo "======================================"
echo " SAE DOLIBARR - INSTALLATION"
echo "======================================"

# Vérifie que le fichier .env existe
if [ ! -f ".env" ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

# Charge les variables présentes dans le fichier .env
set -a
source .env
set +a

# Vérifie que Docker est installé
if ! command -v docker >/dev/null 2>&1; then
    echo "ERREUR : Docker n'est pas installé."
    exit 1
fi

# Vérifie que Docker Compose est disponible
if ! docker compose version >/dev/null 2>&1; then
    echo "ERREUR : Docker Compose n'est pas disponible."
    exit 1
fi

# Étape 1 : création des dossiers nécessaires au projet
echo "[1/4] Création des dossiers..."

# Dossier contenant les fichiers CSV
mkdir -p data

# Dossier contenant les sauvegardes
mkdir -p backups

# Dossier contenant les données de MariaDB
mkdir -p volumes/mariadb

# Dossier contenant les documents de Dolibarr
mkdir -p volumes/dolibarr_documents

# Dossier contenant les modules personnalisés de Dolibarr
mkdir -p volumes/dolibarr_custom

# Étape 2 : vérification du fonctionnement de Docker
echo "[2/4] Vérification de Docker..."

# Vérifie que le moteur Docker est bien accessible
docker info >/dev/null

# Étape 3 : démarrage du conteneur MariaDB
echo "[3/4] Démarrage de MariaDB..."

# Démarre le service MariaDB en arrière-plan
docker compose up -d mariadb

# Attend que MariaDB soit opérationnelle
echo "Attente de MariaDB..."

# Effectue jusqu'à 60 tentatives pour vérifier que MariaDB répond
for i in $(seq 1 60); do
    if docker compose exec -T mariadb \
        mariadb-admin ping \
        -uroot \
        -p"${MYSQL_ROOT_PASSWORD}" \
        --silent >/dev/null 2>&1