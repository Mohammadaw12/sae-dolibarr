#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -f ".env" ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Usage : ./scripts/import_csv.sh <clients.csv> <fournisseurs.csv>"
    exit 1
fi

CLIENTS_FILE="$1"
FOURNISSEURS_FILE="$2"

if [ ! -f "$CLIENTS_FILE" ]; then
    echo "ERREUR : fichier clients absent : $CLIENTS_FILE"
    exit 1
fi

if [ ! -f "$FOURNISSEURS_FILE" ]; then
    echo "ERREUR : fichier fournisseurs absent : $FOURNISSEURS_FILE"
    exit 1
fi

set -a
source .env
set +a

export DOLI_API_KEY
export DOLI_URL="http://localhost:8080"

echo "======================================"
echo " IMPORT DES CLIENTS"
echo "======================================"

python3 tools/import_csv.py "$CLIENTS_FILE" client

echo
echo "======================================"
echo " IMPORT DES FOURNISSEURS"
echo "======================================"

python3 tools/import_csv.py "$FOURNISSEURS_FILE" supplier

echo
echo "======================================"
echo " IMPORT TERMINE"
echo "======================================"
