#!/bin/bash
set -euo pipefail

CONTAINER=$(docker run \
  --rm \
  -e POSTGRES_USER=femboyfans \
  -e POSTGRES_DB=femboyfans_development \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -v gayfurcity_db_data:/var/lib/postgresql/data \
  -d postgres:17.5-alpine3.20)

if [[ -z "$CONTAINER" ]]; then
  echo "[ERROR] Failed to start container" >&2
  exit 1
fi

echo "[OK] Container started: ${CONTAINER:0:12}"

cleanup() {
  echo "[INFO] Stopping container..."
  docker stop "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[INFO] Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
  if docker exec "$CONTAINER" pg_isready -U femboyfans -q 2>/dev/null; then
    echo "[OK] PostgreSQL is ready"
    break
  fi
  if [[ "$i" -eq 30 ]]; then
    echo "[ERROR] Timed out waiting for PostgreSQL" >&2
    exit 1
  fi
  sleep 1
done

run_sql() {
  local user="$1"
  local sql="$2"
  docker exec "$CONTAINER" psql -U "$user" -d postgres -v ON_ERROR_STOP=1 -c "$sql"
}

echo "[INFO] Renaming database and creating temp superuser..."
run_sql "femboyfans" "
  ALTER DATABASE femboyfans_development RENAME TO gayfurcity_development;
  CREATE ROLE temp_rename_admin WITH LOGIN SUPERUSER;
"

echo "[INFO] Renaming role femboyfans -> gayfurcity..."
run_sql "temp_rename_admin" "ALTER ROLE femboyfans RENAME TO gayfurcity;"

echo "[INFO] Dropping temporary superuser..."
run_sql "gayfurcity" "DROP ROLE temp_rename_admin;"

echo "[OK] Done. Database and role renamed successfully."
