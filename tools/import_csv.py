#!/usr/bin/env python3

# Importe le module permettant de lire les fichiers CSV
import csv

# Permet de manipuler les données au format JSON
import json

# Permet d'accéder aux variables d'environnement et aux fichiers
import os

# Permet de récupérer les arguments passés au script
import sys

# Permet de construire les paramètres des URLs
import urllib.parse

# Permet d'envoyer des requêtes HTTP vers l'API Dolibarr
import urllib.request

# Permet de gérer les erreurs liées aux requêtes HTTP
import urllib.error

# Récupère l'adresse de Dolibarr depuis la variable d'environnement DOLI_URL
# Utilise localhost:8080 par défaut si la variable n'est pas définie
BASE_URL = os.environ.get("DOLI_URL", "http://localhost:8080").rstrip("/")

# Récupère la clé API permettant de s'authentifier auprès de Dolibarr
API_KEY = os.environ.get("DOLI_API_KEY")

# Vérifie que la clé API est bien définie
if not API_KEY:
    print("ERREUR : DOLI_API_KEY n'est pas définie.")
    sys.exit(1)

# Définit l'adresse de base de l'API REST de Dolibarr
API_URL = BASE_URL + "/api/index.php"


# Fonction permettant d'envoyer une requête à l'API Dolibarr
def api_request(method, endpoint, data=None, params=None):

    # Construit l'URL complète de l'endpoint demandé
    url = API_URL + "/" + endpoint

    # Ajoute les paramètres à l'URL s'ils sont présents
    if params:
        url += "?" + urllib.parse.urlencode(params)

    # Définit les en-têtes HTTP utilisés pour la requête
    headers = {
        "DOLAPIKEY": API_KEY,
        "Accept": "application/json"
    }

    # Initialise le contenu de la requête
    body = None

    # Si des données sont fournies, elles sont converties en JSON
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"

    # Crée la requête HTTP avec la méthode, les données et les en-têtes
    request = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method=method
    )

    # Tente d'envoyer la requête à l'API
    try:
        with urllib.request.urlopen(request) as response:
            content = response.read().decode("utf-8")

            # Si l'API renvoie du contenu, le convertit depuis JSON
            if content:
                return json.loads(content)

            # Retourne None si l'API ne renvoie aucun contenu
            return None

    # Gère les erreurs HTTP retournées par l'API
    except urllib.error.HTTPError as error:
        message = error.read().decode("utf-8")
        raise RuntimeError(f"HTTP {error.code}: {message}")


# Fonction permettant de rechercher un tiers dans Dolibarr
def find_thirdparty(name):

    # Définit les paramètres de recherche
    params = {
        "limit": 100,
        "sqlfilters": f"(t.nom:=:'{name}')"
    }

    # Effectue la recherche dans l'API
    try:
        result = api_request(
            "GET",
            "thirdparties",
            params=params
        )

        # Si le résultat est une liste, la retourne
        if isinstance(result, list):
            return result

        # Sinon, retourne une liste vide
        return []

    # Gère les erreurs rencontrées pendant la recherche
    except RuntimeError as error:

        # Si l'API renvoie une erreur 404, considère qu'aucun tiers n'existe
        if "404" in str(error):
            return []

        # Pour les autres erreurs, transmet l'erreur
        raise


# Fonction permettant de créer un client ou un fournisseur
def create_thirdparty(row, kind):

    # Récupère et nettoie le nom du tiers
    name = row["name"].strip()

    # Vérifie si le tiers existe déjà dans Dolibarr
    existing = find_thirdparty(name)

    # Si le tiers existe déjà, ne le recrée pas
    if existing:
        print(f"[EXISTE] {kind} déjà présent : {name}")
        return

    # Prépare les informations du tiers à envoyer à Dolibarr
    data = {
        "name": name,
        "address": row.get("address", "").strip(),
        "zip": row.get("zip", "").strip(),
        "town": row.get("town", "").strip(),
        "phone": row.get("phone", "").strip(),
        "email": row.get("email", "").strip()
    }

    # Indique que le tiers est un client
    if kind == "client":
        data["client"] = "1"

    # Indique que le tiers est un fournisseur
    elif kind == "supplier":
        data["supplier"] = "1"

    # Envoie les informations à l'API pour créer le tiers
    result = api_request(
        "POST",
        "thirdparties",
        data=data
    )

    # Affiche le résultat de la création
    print(f"[OK] {kind} créé : {name} -> ID {result}")


# Fonction permettant d'importer les données depuis un fichier CSV
def import_csv(filename, kind):

    # Ouvre le fichier CSV avec l'encodage UTF-8
    with open(
        filename,
        newline="",
        encoding="utf-8-sig"
    ) as csvfile:

        # Transforme chaque ligne du CSV en dictionnaire
        reader = csv.DictReader(csvfile)

        # Définit les colonnes obligatoires du fichier CSV
        required_columns = {
            "name",
            "address",
            "zip",
            "town",
            "phone",
            "email"
        }

        # Vérifie que toutes les colonnes nécessaires sont présentes
        if not required_columns.issubset(reader.fieldnames):
            print("ERREUR : colonnes CSV incorrectes.")
            print("Colonnes attendues :", required_columns)
            sys.exit(1)

        # Parcourt chaque ligne du fichier CSV
        for row in reader:

            # Récupère le nom du tiers
            name = row.get("name", "").strip()

            # Vérifie que le nom du tiers est renseigné
            if not name:
                print("[ERREUR] Nom du tiers absent.")
                continue

            # Tente de créer le tiers dans Dolibarr
            try:
                create_thirdparty(row, kind)

            # Affiche l'erreur si la création échoue
            except Exception as error:
                print(f"[ERREUR] {name} : {error}")


# Point d'entrée principal du programme
if __name__ == "__main__":

    # Vérifie que le script reçoit exactement deux arguments
    if len(sys.argv) != 3:

        print(
            "Usage : python3 tools/import_csv.py "
            "<fichier.csv> <client|supplier>"
        )

        sys.exit(1)

    # Récupère le nom du fichier CSV fourni en argument
    filename = sys.argv[1]

    # Récupère le type de tiers fourni en argument
    kind = sys.argv[2]

    # Vérifie que le type est bien client ou supplier
    if kind not in ("client", "supplier"):

        print("ERREUR : le type doit être client ou supplier.")
        sys.exit(1)

    # Vérifie que le fichier CSV existe
    if not os.path.isfile(filename):

        print(f"ERREUR : fichier absent : {filename}")
        sys.exit(1)

    # Lance l'importation du fichier CSV
    import_csv(filename, kind)