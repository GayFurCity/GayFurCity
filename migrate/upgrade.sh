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
OLD_PGDATA_MOUNT="/var/lib/postgresql/data"
NEW_PGDATA_MOUNT="/var/lib/postgresql/data"

TOTAL_STEPS=8
STEP=0
SCRIPT_START=$(date +%s)
STEP_START=$SCRIPT_START
PROGRESS_INTERVAL="${PROGRESS_INTERVAL:-15}"
RESTORE_PROGRESS_LINES="${RESTORE_PROGRESS_LINES:-5000}"

postgres_major_version() {
  printf '%s\n' "${1%%.*}"
}

postgres_data_mount() {
  local major
  major="$(postgres_major_version "$1")"
  if ((major >= 18)); then
    printf '/var/lib/postgresql'
  else
    printf '/var/lib/postgresql/data'
  fi
}

fmt_duration() {
  local secs="$1"
  printf '%dm%02ds' "$((secs / 60))" "$((secs % 60))"
}

elapsed() {
  fmt_duration "$(($(date +%s) - STEP_START))"
}

step() {
  STEP=$((STEP + 1))
  local now
  now=$(date +%s)
  if [[ $STEP -gt 1 ]]; then
    echo "    (previous step took $(fmt_duration $((now - STEP_START))))"
  fi
  STEP_START=$now
  echo "==> [$STEP/$TOTAL_STEPS] $1 ($(date '+%H:%M:%S'))"
}

progress() {
  echo "    [$(date '+%H:%M:%S') +$(elapsed)] $*"
}

volume_exists() {
  docker volume inspect "$1" >/dev/null 2>&1
}

volume_size() {
  docker run --rm -v "$1":/v busybox du -sh /v 2>/dev/null | cut -f1
}

volume_file_count() {
  docker run --rm -v "$1":/v busybox find /v -type f 2>/dev/null | wc -l
}

dump_size() {
  if [[ -f "$DUMP_FILE" ]]; then
    printf '%s, %s lines' "$(du -sh "$DUMP_FILE" | cut -f1)" "$(wc -l < "$DUMP_FILE")"
  else
    printf 'not created yet'
  fi
}

postgres_activity() {
  local container="$1"
  local user="${2:-gayfurcity}"
  docker exec "$container" psql -At -U "$user" -d postgres -c \
    "select coalesce(wait_event_type || ':' || wait_event, state, 'unknown') from pg_stat_activity where pid <> pg_backend_pid() and usename = '$user' order by query_start nulls last limit 1" \
    2>/dev/null || true
}

container_state() {
  docker inspect "$1" --format 'status={{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}' 2>/dev/null || true
}

container_running() {
  [[ "$(docker inspect "$1" --format '{{.State.Running}}' 2>/dev/null || true)" == "true" ]]
}

print_container_failure() {
  local container="$1"
  echo "    postgres did not become ready in $container"
  echo "    container state: $(container_state "$container")"
  echo "    last container logs:"
  docker logs --tail 80 "$container" 2>&1 | sed 's/^/      /' || true
}

wait_for_postgres() {
  local container="$1"
  local user="${2:-gayfurcity}"
  local waited=0
  until docker exec "$container" pg_isready -U "$user" >/dev/null 2>&1; do
    if ! container_running "$container"; then
      print_container_failure "$container"
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
    if ((waited % 5 == 0)); then
      progress "waiting for postgres in $container (${waited}s)"
    fi
  done
  progress "postgres is ready in $container"
}

copy_volume() {
  local from="$1"
  local to="$2"
  local label="$3"
  local source_size
  local source_files

  source_size=$(volume_size "$from")
  source_files=$(volume_file_count "$from")
  progress "$label source: $from ($source_size, $source_files files)"

  docker run --rm -v "$from":/old:ro -v "$to":/new busybox sh -c "cp -a /old/. /new/" &
  local copy_pid=$!
  while kill -0 "$copy_pid" 2>/dev/null; do
    sleep "$PROGRESS_INTERVAL"
    if kill -0 "$copy_pid" 2>/dev/null; then
      progress "$label still copying; $to is $(volume_size "$to") ($(volume_file_count "$to") files)"
    fi
  done
  wait "$copy_pid"
  progress "$label complete; $to is $(volume_size "$to") ($(volume_file_count "$to") files)"
}

dump_old_data() {
  docker exec "$OLD_VOLUME" pg_dumpall -U gayfurcity --verbose > "$DUMP_FILE" &
  local dump_pid=$!
  while kill -0 "$dump_pid" 2>/dev/null; do
    sleep "$PROGRESS_INTERVAL"
    if kill -0 "$dump_pid" 2>/dev/null; then
      progress "dump still running; dump file is $(dump_size)"
    fi
  done
  wait "$dump_pid"
  progress "dump complete; dump file is $(dump_size)"
}

restore_dump() {
  local total_lines
  local total_bytes
  total_lines=$(wc -l < "$DUMP_FILE")
  total_bytes=$(wc -c < "$DUMP_FILE")

  progress "restore input: $DUMP_FILE ($(du -sh "$DUMP_FILE" | cut -f1), $total_lines lines)"
  (
    awk -v total_lines="$total_lines" -v total_bytes="$total_bytes" -v interval="$RESTORE_PROGRESS_LINES" '
      {
        bytes += length($0) + 1
        if (NR % interval == 0) {
          printf "    [%s] restore input consumed: %d/%d lines (%.1f%%), %.1f/%.1f MiB\n",
            strftime("%H:%M:%S"), NR, total_lines, (NR / total_lines) * 100,
            bytes / 1048576, total_bytes / 1048576 > "/dev/stderr"
        }
        print
      }
      END {
        printf "    [%s] restore input consumed: %d/%d lines (100.0%%), %.1f/%.1f MiB\n",
          strftime("%H:%M:%S"), NR, total_lines, bytes / 1048576, total_bytes / 1048576 > "/dev/stderr"
      }
    ' "$DUMP_FILE" | docker exec -i "$NEW_VOLUME" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null
  ) &
  local restore_pid=$!
  while kill -0 "$restore_pid" 2>/dev/null; do
    sleep "$PROGRESS_INTERVAL"
    if kill -0 "$restore_pid" 2>/dev/null; then
      progress "restore still applying; $NEW_VOLUME is $(volume_size "$NEW_VOLUME"); postgres activity: $(postgres_activity "$NEW_VOLUME" postgres)"
    fi
  done
  wait "$restore_pid"
  progress "restore complete; $NEW_VOLUME is $(volume_size "$NEW_VOLUME") ($(volume_file_count "$NEW_VOLUME") files)"
}

cleanup() {
  docker rm -f "$OLD_VOLUME" "$NEW_VOLUME" >/dev/null 2>&1 || true
}
trap cleanup ERR EXIT

OLD_PGDATA_MOUNT="$(postgres_data_mount "$OLD_VERSION")"
NEW_PGDATA_MOUNT="$(postgres_data_mount "$NEW_VERSION")"

for volume in "$OLD_VOLUME" "$NEW_VOLUME"; do
  if volume_exists "$volume"; then
    echo "Refusing to reuse existing intermediate volume $volume ($(volume_size "$volume"))."
    echo "Remove stale upgrade volumes first, then rerun:"
    echo "  docker volume rm $OLD_VOLUME $NEW_VOLUME"
    exit 1
  fi
done

step "Backup Old Data"
docker volume create "$OLD_VOLUME" >/dev/null
copy_volume "gayfurcity_db_data" "$OLD_VOLUME" "backup"

step "Dump Old Data"
progress "starting $OLD_IMAGE with gayfurcity_db_data mounted at $OLD_PGDATA_MOUNT"
docker run -v "gayfurcity_db_data:$OLD_PGDATA_MOUNT" -e POSTGRES_USER=gayfurcity -e POSTGRES_DB=gayfurcity_development -e POSTGRES_HOST_AUTH_METHOD=trust -d --name "$OLD_VOLUME" "$OLD_IMAGE" >/dev/null
wait_for_postgres "$OLD_VOLUME"
echo "    streaming dump progress below (one line per database/object):"
dump_old_data
docker rm -f "$OLD_VOLUME" >/dev/null

step "Import Old Data"
docker volume create "$NEW_VOLUME" >/dev/null
progress "starting $NEW_IMAGE with $NEW_VOLUME mounted at $NEW_PGDATA_MOUNT"
docker run -v "$NEW_VOLUME:$NEW_PGDATA_MOUNT" -e POSTGRES_HOST_AUTH_METHOD=trust -d --name "$NEW_VOLUME" "$NEW_IMAGE" >/dev/null
wait_for_postgres "$NEW_VOLUME" postgres
restore_dump
docker rm -f "$NEW_VOLUME" >/dev/null

step "Confirm Replacement"
if (( "$(postgres_major_version "$NEW_VERSION")" >= 18 )); then
  echo "PostgreSQL $NEW_VERSION stores data under a versioned directory below /var/lib/postgresql."
  echo "Before starting the upgraded database normally, update the postgres service volume mount to:"
  echo "  db_data:/var/lib/postgresql"
fi
read -rp "About to replace gayfurcity_db_data with the upgraded data. Continue? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted before replacing data. Intermediate volumes $OLD_VOLUME and $NEW_VOLUME were left in place."
  exit 1
fi

step "Replace Old Data"
docker run --rm -v gayfurcity_db_data:/old busybox sh -c "rm -rf /old/*"
copy_volume "$NEW_VOLUME" "gayfurcity_db_data" "replacement"

step "Remove Intermediate Volume"
docker volume rm "$NEW_VOLUME" >/dev/null

step "Remove Backup Data"
docker volume rm "$OLD_VOLUME" >/dev/null

step "Remove Dump File"
rm -f "$DUMP_FILE"

TOTAL_ELAPSED=$(($(date +%s) - SCRIPT_START))
echo "==> Done (total time: $(fmt_duration "$TOTAL_ELAPSED"))"
