#!/bin/bash
set -euo pipefail

: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
[[ "$MYSQL_DATABASE" =~ ^[a-zA-Z0-9_]+$ ]] || { echo "Invalid database name" >&2; exit 1; }
[[ "$MYSQL_USER" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Invalid database user" >&2; exit 1; }
[[ "$MYSQL_USER" != root ]] || { echo "Use a non-root database user" >&2; exit 1; }

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
[[ -n "$DB_PASSWORD" && -n "$DB_ROOT_PASSWORD" ]] || { echo "Empty database secret" >&2; exit 1; }
DB_PASSWORD_SQL=${DB_PASSWORD//\'/\'\'}
DB_ROOT_PASSWORD_SQL=${DB_ROOT_PASSWORD//\'/\'\'}

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -f /var/lib/mysql/.inception-initialized ]; then
    if [ ! -d /var/lib/mysql/mysql ]; then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    fi

    mysqld --user=mysql --skip-networking &
    init_pid=$!
    trap 'kill "$init_pid" 2>/dev/null || true; wait "$init_pid" 2>/dev/null || true' EXIT

    ready=false
    for ((attempt=0; attempt<60; attempt++)); do
        if mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then
            ready=true
            break
        fi
        kill -0 "$init_pid" 2>/dev/null || { echo "MariaDB initialization failed" >&2; exit 1; }
        sleep 1
    done
    "$ready" || { echo "MariaDB initialization timed out" >&2; exit 1; }

    mariadb -uroot <<EOF
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD_SQL}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD_SQL}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD_SQL}';
EOF

    MYSQL_PWD="$DB_ROOT_PASSWORD" mariadb-admin -uroot shutdown
    wait "$init_pid"
    trap - EXIT
    touch /var/lib/mysql/.inception-initialized
fi

exec mysqld --user=mysql
