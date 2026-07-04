#!/bin/bash
set -euo pipefail

MYSQL_DATA_DIR="${MYSQL_DATA_DIR:-/var/lib/mysql}"
DB_DATABASE="${DB_DATABASE:-piprapay}"
DB_USERNAME="${DB_USERNAME:-piprapay}"
DB_PASSWORD="${DB_PASSWORD:-strongpassword}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-strongrootpassword}"
PORT="${PORT:-80}"

echo "==> Ensuring correct ownership of ${MYSQL_DATA_DIR}"
mkdir -p "${MYSQL_DATA_DIR}"
chown -R mysql:mysql "${MYSQL_DATA_DIR}"

# ---------------------------------------------------------------------------
# First-boot MySQL initialization. If the disk (or container fs) already has
# a populated data dir -- e.g. a Render persistent disk from a prior deploy --
# this whole block is skipped and existing data is preserved.
# ---------------------------------------------------------------------------
if [ -z "$(ls -A "${MYSQL_DATA_DIR}" 2>/dev/null)" ]; then
    echo "==> No existing MySQL data found in ${MYSQL_DATA_DIR}. Initializing..."

    gosu mysql mysql_install_db --datadir="${MYSQL_DATA_DIR}" --auth-root-authentication-method=normal >/dev/null

    echo "==> Starting mysqld temporarily to run bootstrap SQL"
    gosu mysql /usr/sbin/mysqld --datadir="${MYSQL_DATA_DIR}" --skip-networking --socket=/tmp/mysql_init.sock &
    MYSQL_PID=$!

    # Wait for the temp instance to come up
    for i in $(seq 1 30); do
        if mysqladmin --socket=/tmp/mysql_init.sock ping >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    mysql --socket=/tmp/mysql_init.sock -u root <<-EOSQL
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        CREATE DATABASE IF NOT EXISTS \`${DB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USERNAME}'@'%';
        FLUSH PRIVILEGES;
EOSQL

    echo "==> Bootstrap SQL applied. Shutting down temporary mysqld."
    mysqladmin --socket=/tmp/mysql_init.sock -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait "${MYSQL_PID}" 2>/dev/null || true
else
    echo "==> Existing MySQL data found in ${MYSQL_DATA_DIR}. Skipping initialization."
fi

# ---------------------------------------------------------------------------
# Render injects $PORT and expects the app to listen on it. Apache's own
# config files don't expand env vars, so rewrite them here at container start.
# ---------------------------------------------------------------------------
echo "==> Configuring Apache to listen on port ${PORT}"
sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/:80>/:${PORT}>/" /etc/apache2/sites-available/000-default.conf

echo "==> Handing off to: $*"
exec "$@"
