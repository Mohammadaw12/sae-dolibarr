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

export DOLI_API_KEY
export DOLI_URL="http://localhost:8080"

echo "======================================"
echo " IMPORT DES CLIENTS"
echo "======================================"

python3 tools/import_csv.py data/clients.csv client

echo
echo "======================================"
echo " IMPORT DES FOURNISSEURS"
echo "======================================"

python3 tools/import_csv.py data/fournisseurs.csv supplier

echo
echo "======================================"
echo " IMPORT TERMINE"
echo "======================================"
