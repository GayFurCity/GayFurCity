#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <old_version> <new_version>"
  echo "Example: $0 15.7 17.5"
  exit 1
fi

OLD_VERSION="$1"
NEW_VERSION="$2"

OLD_VOLUME="gayfurcity_pg${OLD_VERSION}"
NEW_VOLUME="gayfurcity_pg${NEW_VERSION}"
OLD_IMAGE="postgres:${OLD_VERSION}-alpine"
NEW_IMAGE="postgres:${NEW_VERSION}-alpine"
DUMP_FILE="./pg${OLD_VERSION}_dump.sql"

wait_for_postgres() {
  local container="$1"
  until docker exec "$container" pg_isready -U gayfurcity >/dev/null 2>&1; do
    sleep 1
  done
}

cleanup() {
  docker rm -f "$OLD_VOLUME" "$NEW_VOLUME" >/dev/null 2>&1 || true
}
trap cleanup ERR EXIT

echo "==> Backup Old Data"
docker volume create "$OLD_VOLUME"
docker run --rm -v gayfurcity_db_data:/old -v "$OLD_VOLUME":/new busybox sh -c "cp -r /old/* /new/"

echo "==> Dump Old Data"
docker run --rm -v gayfurcity_db_data:/var/lib/postgresql/data -e POSTGRES_USER=gayfurcity -e POSTGRES_DB=gayfurcity_development -e POSTGRES_HOST_AUTH_METHOD=trust -d --name "$OLD_VOLUME" "$OLD_IMAGE"
wait_for_postgres "$OLD_VOLUME"
docker exec "$OLD_VOLUME" pg_dumpall -U gayfurcity > "$DUMP_FILE"
docker rm -f "$OLD_VOLUME"

echo "==> Import Old Data"
docker volume create "$NEW_VOLUME"
docker run --rm -v "$NEW_VOLUME":/var/lib/postgresql/data -e POSTGRES_USER=gayfurcity -e POSTGRES_DB=gayfurcity_development -e POSTGRES_HOST_AUTH_METHOD=trust -d --name "$NEW_VOLUME" "$NEW_IMAGE"
wait_for_postgres "$NEW_VOLUME"
docker exec -i "$NEW_VOLUME" psql -U gayfurcity -d postgres < "$DUMP_FILE"
docker rm -f "$NEW_VOLUME"

read -rp "About to replace gayfurcity_db_data with the upgraded data. Continue? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted before replacing data. Intermediate volumes $OLD_VOLUME and $NEW_VOLUME were left in place."
  exit 1
fi

echo "==> Replace Old Data"
docker run --rm -v gayfurcity_db_data:/old busybox sh -c "rm -rf /old/*"
docker run --rm -v "$NEW_VOLUME":/old -v gayfurcity_db_data:/new busybox sh -c "cp -r /old/* /new/"

echo "==> Remove Intermediate Volume"
docker volume rm "$NEW_VOLUME"

echo "==> Remove Backup Data"
docker volume rm "$OLD_VOLUME"

echo "==> Done"
