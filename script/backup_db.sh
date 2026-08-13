#!/usr/bin/env bash
# Tägliches Backup der Produktions-Datenbank (Postgres-Accessory-Container von Kamal).
# Läuft NICHT im Rails-Container, sondern direkt auf dem Server per Cron:
#   0 3 * * * /home/ubuntu/btv_anmeldung/script/backup_db.sh >> /home/ubuntu/backups/btv_anmeldung/backup.log 2>&1
#
# Legt gzip-komprimierte pg_dump-Backups ab und behält die letzten $RETENTION_DAYS Tage.
set -euo pipefail

CONTAINER="btv_anmeldung-db"
DB_USER="btv_app"
DB_NAME="btv_anmeldung_production"
BACKUP_DIR="/home/ubuntu/backups/btv_anmeldung"
RETENTION_DAYS=14

mkdir -p "$BACKUP_DIR"

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
dump_file="$BACKUP_DIR/btv_anmeldung_${timestamp}.sql.gz"

docker exec "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$dump_file"

echo "$(date -Iseconds) Backup erstellt: $dump_file ($(du -h "$dump_file" | cut -f1))"

# Alte Backups aufräumen (älter als RETENTION_DAYS)
find "$BACKUP_DIR" -name "btv_anmeldung_*.sql.gz" -mtime "+${RETENTION_DAYS}" -delete
