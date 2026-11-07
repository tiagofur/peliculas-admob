#!/usr/bin/env bash
# Restore a backup into the running database. Stops the API while it runs.
# Usage (on the server, in /opt/peliculas): deploy/restore.sh backups/peliculas-YYYYmmdd-HHMMSS.dump
set -euo pipefail
file="${1:?usage: restore.sh <file.dump>}"
[[ -f "$file" ]] || { echo "no such file: $file" >&2; exit 1; }

read -r -p "This REPLACES all data with $file. Type 'restore' to continue: " answer
[[ "$answer" == restore ]] || { echo "cancelled"; exit 1; }

docker compose stop api
docker compose exec -T db pg_restore -U peliculas -d peliculas --clean --if-exists --no-owner <"$file"
docker compose start api
echo "restored $file"
