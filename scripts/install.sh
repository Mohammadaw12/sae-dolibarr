#!/bin/bash
set -Eeuo pipefail

# ==========================================================
# Installation automatique de Dolibarr pour la SAE 5.1
# ==========================================================

cd "$(dirname "$0")/.."

echo "=========================================="
echo " Installation de Dolibarr"
echo "=========================================="

# Vérifier les prérequis
if ! command -v docker >/dev/null 2>&1; then
    echo "ERREUR : Docker n'est pas installé."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "ERREUR : Docker Compose n'est pas disponible."
    exit 1
fi

# Vérifier le fichier de configuration
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "Fichier .env créé à partir de .env.example."
        echo "Modifie les mots de passe dans .env, puis relance ce script."
        exit 1
    else
        echo "ERREUR : le fichier .env.example est introuvable."
        exit 1
    fi
fi

# Charger les variables d'environnement
set -a
source .env
set +a

# Vérifier les variables indispensables
for variable in MYSQL_ROOT_PASSWORD MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD DOLI_ADMIN_LOGIN DOLI_ADMIN_PASSWORD DOLI_URL_ROOT; do
    if [ -z "${!variable:-}" ]; then
        echo "ERREUR : la variable $variable est absente du fichier .env."
        exit 1
    fi
done

# Vérifier la configuration Docker Compose
docker compose config -q

# Créer les répertoires nécessaires
mkdir -p volumes/mariadb
mkdir -p volumes/dolibarr_documents
mkdir -p volumes/dolibarr_custom
mkdir -p backups

echo "Démarrage de MariaDB..."
docker compose up -d mariadb

# Attendre que MariaDB soit prête
echo "Attente du démarrage de MariaDB..."
for i in $(seq 1 60); do
    if docker compose exec -T mariadb sh -c \
        'mariadb-admin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
        >/dev/null 2>&1; then
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "ERREUR : MariaDB ne démarre pas."
        docker compose logs --tail=80 mariadb
        exit 1
    fi

    sleep 3
done

echo "MariaDB est prête."

echo "Démarrage de Dolibarr..."
docker compose up -d dolibarr

echo "Attente du démarrage de Dolibarr..."
for i in $(seq 1 60); do
    if curl -fsS http://localhost:8080/ >/dev/null 2>&1; then
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "ERREUR : Dolibarr ne répond pas sur le port 8080."
        docker compose logs --tail=100 dolibarr
        exit 1
    fi

    sleep 5
done

echo
echo "=========================================="
echo " Installation terminée"
echo "=========================================="
echo "Adresse : $DOLI_URL_ROOT"
echo "Identifiant administrateur : $DOLI_ADMIN_LOGIN"
echo "Mot de passe : celui défini dans .env"
echo
echo "Pour consulter les journaux :"
echo "docker compose logs -f"
echo
echo "Pour arrêter les services :"
echo "docker compose down"