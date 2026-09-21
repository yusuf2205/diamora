#!/bin/sh
# Runs once when the data directory is first initialised. Least-privilege role for the backup container.
set -eu
: "${BACKUP_DB_PASSWORD:?BACKUP_DB_PASSWORD must be set}"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
CREATE ROLE backup WITH LOGIN REPLICATION CREATEDB PASSWORD '${BACKUP_DB_PASSWORD}';
GRANT pg_read_all_data TO backup;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SQL
echo "backup role created"
