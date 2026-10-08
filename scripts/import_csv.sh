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

# Vérifie que deux fichiers CSV ont bien été fournis en paramètres
if [ "$#" -ne 2 ]; then
    echo "Usage : ./scripts/import_csv.sh <clients.csv> <fournisseurs.csv>"
    exit 1
fi

# Récupère le premier paramètre correspondant au fichier des clients
CLIENTS_FILE="$1"

# Récupère le deuxième paramètre correspondant au fichier des fournisseurs
FOURNISSEURS_FILE="$2"

# Vérifie que le fichier clients existe
if [ ! -f "$CLIENTS_FILE" ]; then
    echo "ERREUR : fichier clients absent : $CLIENTS_FILE"
    exit 1
fi

# Vérifie que le fichier fournisseurs existe
if [ ! -f "$FOURNISSEURS_FILE" ]; then
    echo "ERREUR : fichier fournisseurs absent : $FOURNISSEURS_FILE"
    exit 1
fi

# Charge les variables présentes dans le fichier .env
set -a
source .env
set +a

# Rend la clé API Dolibarr disponible pour le script Python
export DOLI_API_KEY

# Définit l'adresse de l'API Dolibarr
export DOLI_URL="http://localhost:8080"

# Affiche le début de l'importation des clients
echo "======================================"
echo " IMPORT DES CLIENTS"
echo "======================================"

# Lance le script Python pour importer les clients
# Le paramètre "client" indique qu'il s'agit de tiers de type client
python3 tools/import_csv.py "$CLIENTS_FILE" client

# Affiche le début de l'importation des fournisseurs
echo
echo "======================================"
echo " IMPORT DES FOURNISSEURS"
echo "======================================"

# Lance le script Python pour importer les fournisseurs
# Le paramètre "supplier" indique qu'il s'agit de tiers de type fournisseur
python3 tools/import_csv.py "$FOURNISSEURS_FILE" supplier

# Affiche un message lorsque les deux imports sont terminés
echo
echo "======================================"
echo " IMPORT TERMINE"
echo "======================================"