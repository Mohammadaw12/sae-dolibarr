#!/usr/bin/env python3

import csv
import json
import os
import sys
import urllib.parse
import urllib.request
import urllib.error

BASE_URL = os.environ.get("DOLI_URL", "http://localhost:8080").rstrip("/")
API_KEY = os.environ.get("DOLI_API_KEY")

if not API_KEY:
    print("ERREUR : DOLI_API_KEY n'est pas définie.")
    sys.exit(1)

API_URL = BASE_URL + "/api/index.php"


def api_request(method, endpoint, data=None, params=None):

    url = API_URL + "/" + endpoint

    if params:
        url += "?" + urllib.parse.urlencode(params)

    headers = {
        "DOLAPIKEY": API_KEY,
        "Accept": "application/json"
    }

    body = None

    if data is not None:
        body = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method=method
    )

    try:
        with urllib.request.urlopen(request) as response:
            content = response.read().decode("utf-8")

            if content:
                return json.loads(content)

            return None

    except urllib.error.HTTPError as error:
        message = error.read().decode("utf-8")
        raise RuntimeError(f"HTTP {error.code}: {message}")


def find_thirdparty(name):

    params = {
        "limit": 100,
        "sqlfilters": f"(t.nom:=:'{name}')"
    }

    try:
        result = api_request(
            "GET",
            "thirdparties",
            params=params
        )

        if isinstance(result, list):
            return result

        return []

    except RuntimeError as error:

        if "404" in str(error):
            return []

        raise


def create_thirdparty(row, kind):

    name = row["name"].strip()

    existing = find_thirdparty(name)

    if existing:
        print(f"[EXISTE] {kind} déjà présent : {name}")
        return

    data = {
        "name": name,
        "address": row.get("address", "").strip(),
        "zip": row.get("zip", "").strip(),
        "town": row.get("town", "").strip(),
        "phone": row.get("phone", "").strip(),
        "email": row.get("email", "").strip()
    }

    if kind == "client":
        data["client"] = "1"

    elif kind == "supplier":
        data["supplier"] = "1"

    result = api_request(
        "POST",
        "thirdparties",
        data=data
    )

    print(f"[OK] {kind} créé : {name} -> ID {result}")


def import_csv(filename, kind):

    with open(
        filename,
        newline="",
        encoding="utf-8-sig"
    ) as csvfile:

        reader = csv.DictReader(csvfile)

        required_columns = {
            "name",
            "address",
            "zip",
            "town",
            "phone",
            "email"
        }

        if not required_columns.issubset(reader.fieldnames):
            print("ERREUR : colonnes CSV incorrectes.")
            print("Colonnes attendues :", required_columns)
            sys.exit(1)

        for row in reader:

            name = row.get("name", "").strip()

            if not name:
                print("[ERREUR] Nom du tiers absent.")
                continue

            try:
                create_thirdparty(row, kind)

            except Exception as error:
                print(f"[ERREUR] {name} : {error}")


if __name__ == "__main__":

    if len(sys.argv) != 3:

        print(
            "Usage : python3 tools/import_csv.py "
            "<fichier.csv> <client|supplier>"
        )

        sys.exit(1)

    filename = sys.argv[1]
    kind = sys.argv[2]

    if kind not in ("client", "supplier"):

        print("ERREUR : le type doit être client ou supplier.")
        sys.exit(1)

    if not os.path.isfile(filename):

        print(f"ERREUR : fichier absent : {filename}")
        sys.exit(1)

    import_csv(filename, kind)
