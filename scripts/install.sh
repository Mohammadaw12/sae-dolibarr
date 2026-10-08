#!/bin/bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "======================================"
echo " SAE DOLIBARR - INSTALLATION"
echo "======================================"

# 1. Vérifier la configuration
if [ ! -f .env ]; then
    echo "ERREUR : fichier .env absent."
    exit 1
fi

set -a
source .env
set +a

for var in MYSQL_ROOT_PASSWORD MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD \
           DOLI_ADMIN_LOGIN DOLI_ADMIN_PASSWORD DOLI_URL_ROOT; do
    if [ -z "${!var:-}" ] || [[ "${!var}" == "CHANGE_ME" ]]; then
        echo "ERREUR : configure $var dans .env."
        exit 1
    fi
done

docker compose config -q

# 2. Créer les dossiers sans effacer les données
echo "[1/7] Vérification des dossiers..."
mkdir -p data backups volumes/mariadb \
    volumes/dolibarr_documents volumes/dolibarr_custom

# 3. Démarrer MariaDB et attendre qu'elle soit prête
echo "[2/7] Démarrage de MariaDB..."
docker compose up -d mariadb

READY=0
for i in $(seq 1 60); do
    if docker compose exec -T mariadb sh -c \
        'mariadb-admin ping -h127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
        >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 2
done

if [ "$READY" -ne 1 ]; then
    echo "ERREUR : MariaDB ne répond pas."
    docker compose logs --tail=80 mariadb
    exit 1
fi

echo "MariaDB est prête."

# 4. Sauvegarder la base existante avant de poursuivre
echo "[3/7] Sauvegarde de la base..."
BACKUP="backups/${MYSQL_DATABASE}-$(date +%Y%m%d-%H%M%S).sql"

if ! docker compose exec -T mariadb sh -c \
    'mariadb-dump --single-transaction -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' \
    > "$BACKUP" || [ ! -s "$BACKUP" ]; then
    rm -f "$BACKUP"
    echo "ERREUR : sauvegarde impossible. Arrêt par sécurité."
    exit 1
fi

echo "Sauvegarde créée : $BACKUP"

# 5. Démarrer Dolibarr
echo "[4/7] Démarrage de Dolibarr..."
docker compose up -d dolibarr

echo "Attente de la fin du démarrage de Dolibarr..."
WEB_READY=0

# Apache ne démarre qu'après le traitement de démarrage de l'image.
for i in $(seq 1 120); do
    if docker compose exec -T dolibarr sh -c \
        'ps -ef 2>/dev/null | grep -q "[a]pache2"' \
        >/dev/null 2>&1; then
        WEB_READY=1
        break
    fi
    sleep 2
done

if [ "$WEB_READY" -ne 1 ]; then
    echo "ERREUR : Dolibarr n'a pas terminé son démarrage."
    docker compose logs --tail=120 dolibarr
    echo "Consulte aussi volumes/dolibarr_documents/initdb.log."
    exit 1
fi

echo "Dolibarr a terminé son démarrage."

# 6. Compléter l'initialisation et synchroniser l'administrateur
# On utilise les identifiants du .env.
# Aucune table ni aucun volume n'est supprimé.
echo "[5/7] Vérification de l'initialisation et de l'administrateur..."

docker compose exec -T dolibarr php <<'PHP'
<?php
$host = getenv('DOLI_DB_HOST') ?: 'mariadb';
$port = getenv('DOLI_DB_HOST_PORT') ?: '3306';
$dbname = getenv('DOLI_DB_NAME');
$dbuser = getenv('DOLI_DB_USER');
$dbpass = getenv('DOLI_DB_PASSWORD');
$login = getenv('DOLI_ADMIN_LOGIN');
$password = getenv('DOLI_ADMIN_PASSWORD');

if (!$dbname || !$dbuser || !$login || !$password) {
    fwrite(STDERR, "ERREUR : variables Dolibarr manquantes.\n");
    exit(1);
}

try {
    $pdo = new PDO(
        "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4",
        $dbuser,
        $dbpass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Vérifier que l'initialisation a créé les tables nécessaires.
    foreach (['llx_user', 'llx_const'] as $table) {
        $check = $pdo->query("SHOW TABLES LIKE '$table'");
        if (!$check->fetchColumn()) {
            throw new RuntimeException(
                "Table $table absente : initialisation incomplète."
            );
        }
    }

    // Compléter les constantes de première installation si elles manquent.
    $setConstIfMissing = function (
        string $name,
        string $value,
        int $entity
    ) use ($pdo): void {
        $check = $pdo->prepare(
            'SELECT rowid FROM llx_const WHERE name = ? AND entity = ? LIMIT 1'
        );
        $check->execute([$name, $entity]);

        if (!$check->fetchColumn()) {
            $insert = $pdo->prepare(
                'INSERT INTO llx_const
                 (name, value, type, visible, note, entity)
                 VALUES (?, ?, ?, 0, ?, ?)'
            );
            $insert->execute([
                $name,
                $value,
                'chaine',
                'Initialisation automatique Docker',
                $entity
            ]);
        }
    };

    $setConstIfMissing('MAIN_VERSION_LAST_INSTALL', '24.0.1', 0);
    $setConstIfMissing('MAIN_LANG_DEFAULT', 'auto', 1);
    $setConstIfMissing('SYSTEMTOOLS_MYSQLDUMP', '/usr/bin/mysqldump', 0);

    // Supprimer l'indicateur éventuel signalant que Dolibarr n'est pas installé.
    $delete = $pdo->prepare(
        "DELETE FROM llx_const WHERE name = 'MAIN_NOT_INSTALLED'"
    );
    $delete->execute();

    // Retrouver le compte configuré dans .env.
    $check = $pdo->prepare(
        'SELECT rowid FROM llx_user WHERE login = ? LIMIT 1'
    );
    $check->execute([$login]);
    $userId = $check->fetchColumn();

    // Même mécanisme de mot de passe que celui utilisé par l'image Docker.
    $cryptedPassword = md5($password);

    if ($userId) {
        // Le .env reste la référence pour les identifiants de cet administrateur.
        $update = $pdo->prepare(
            'UPDATE llx_user
             SET pass_crypted = ?, pass = NULL, admin = 1, statut = 1
             WHERE rowid = ?'
        );
        $update->execute([$cryptedPassword, $userId]);

        echo "Compte administrateur synchronisé : $login\n";
    } else {
        $insert = $pdo->prepare(
            'INSERT INTO llx_user
             (entity, login, pass_crypted, lastname, admin, statut)
             VALUES (0, ?, ?, ?, 1, 1)'
        );
        $insert->execute([$login, $cryptedPassword, 'SuperAdmin']);

        echo "Compte administrateur créé : $login\n";
    }
} catch (Throwable $e) {
    fwrite(STDERR, "ERREUR d'initialisation : " . $e->getMessage() . "\n");
    exit(1);
}
PHP

# Activer le module Utilisateurs, comme le fait l'image Docker officielle.
echo "Activation du module Utilisateurs..."
docker compose exec -T -w /var/www/scripts dolibarr php docker-init.php

# 7. Vérification finale
echo "[6/7] Vérification finale..."

docker compose exec -T dolibarr sh -c '
set -eu
mysql -N -s \
    -u"$DOLI_DB_USER" -p"$DOLI_DB_PASSWORD" \
    -h"$DOLI_DB_HOST" -P"${DOLI_DB_HOST_PORT:-3306}" \
    "$DOLI_DB_NAME" \
    -e "SELECT CONCAT(\"Compte : \", login,
                      \" | Administrateur : \", admin,
                      \" | Actif : \", statut)
        FROM llx_user
        WHERE login = \"$(printf "%s" "$DOLI_ADMIN_LOGIN" | sed "s/\\/\\\\/g; s/\"/\\\\\"/g")\";" 
'

docker compose exec -T dolibarr sh -c '
mysql -N -s \
    -u"$DOLI_DB_USER" -p"$DOLI_DB_PASSWORD" \
    -h"$DOLI_DB_HOST" -P"${DOLI_DB_HOST_PORT:-3306}" \
    "$DOLI_DB_NAME" \
    -e "SELECT value FROM llx_const
        WHERE name = \"MAIN_VERSION_LAST_INSTALL\" AND entity = 0
        LIMIT 1;" | grep -q .
' || {
    echo "ERREUR : la version d'installation n'est pas enregistrée."
    exit 1
}

echo "[7/7] État des services..."
docker compose ps

echo
echo "======================================"
echo " INSTALLATION TERMINEE"
echo "======================================"
echo "Adresse : ${DOLI_URL_ROOT}"
echo "Identifiant : ${DOLI_ADMIN_LOGIN}"
echo "Mot de passe : celui défini dans .env"
echo "Sauvegarde : ${BACKUP}"
EOF

chmod +x scripts/install.sh