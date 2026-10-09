
#!/bin/bash

# Arrête le script si une commande échoue
set -e

# Affiche les commandes avec des erreurs plus faciles à identifier
set -o pipefail

# Définit le répertoire racine du projet
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "======================================"
echo " IMPORT CSV - DOLIBARR"
echo "======================================"

# Vérifie la présence du fichier .env
if [ ! -f ".env" ]; then
    echo "ERREUR : le fichier .env est absent."
    exit 1
fi

# Vérifie le nombre de paramètres
if [ "$#" -ne 2 ]; then
    echo "Usage :"
    echo "  ./scripts/import_csv.sh <fichier.csv> <client|supplier>"
    echo
    echo "Exemples :"
    echo "  ./scripts/import_csv.sh data/clients.csv client"
    echo "  ./scripts/import_csv.sh data/fournisseurs.csv supplier"
    exit 1
fi

# Récupère les paramètres
CSV_FILE="$1"
TYPE="$2"

# Vérifie le type de tiers
if [ "$TYPE" != "client" ] && [ "$TYPE" != "supplier" ]; then
    echo "ERREUR : le type doit être client ou supplier."
    exit 1
fi

# Vérifie que le fichier CSV existe
if [ ! -f "$CSV_FILE" ]; then
    echo "ERREUR : fichier CSV introuvable : $CSV_FILE"
    exit 1
fi

# Vérifie que Python 3 est installé
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERREUR : Python 3 n'est pas installé."
    exit 1
fi

# Vérifie que le script Python existe
if [ ! -f "tools/import_csv.py" ]; then
    echo "ERREUR : tools/import_csv.py est introuvable."
    exit 1
fi

echo "Fichier CSV : $CSV_FILE"
echo "Type de tiers : $TYPE"

# Charge les variables du fichier .env
echo "Chargement de la configuration..."
set -a
source .env
set +a

# Vérifie la présence de la clé API
if [ -z "${DOLI_API_KEY:-}" ]; then
    echo "ERREUR : DOLI_API_KEY n'est pas défini dans .env."
    exit 1
fi

# Définit l'adresse de Dolibarr
export DOLI_URL="http://localhost:8080"
export DOLI_API_KEY

# Vérifie que Dolibarr répond
echo "Vérification de Dolibarr..."

if ! curl -fsS --max-time 5 "$DOLI_URL/" >/dev/null 2>&1; then
    echo "ERREUR : Dolibarr ne répond pas à $DOLI_URL."
    echo "Vérifie que les conteneurs Docker sont démarrés."
    exit 1
fi

# Affiche le type d'importation
echo
if [ "$TYPE" = "client" ]; then
    echo "Début de l'importation des clients..."
else
    echo "Début de l'importation des fournisseurs..."
fi

# Lance le script Python et affiche son résultat
python3 -u tools/import_csv.py "$CSV_FILE" "$TYPE"

echo
echo "======================================"
echo " IMPORT TERMINE AVEC SUCCES"
echo "======================================"
