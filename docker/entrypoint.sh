#!/bin/sh
set -e

PATCHES_DIR="${PATCHES_DIR:-/patches}"

if [ -d "$PATCHES_DIR" ]; then
  for patch in $(find "$PATCHES_DIR" -maxdepth 1 -name "*.patch" | sort); do
    if git apply --check "$patch" 2>/dev/null; then
      echo "Applying patch: $patch"
      git apply "$patch"
    elif git apply -R --check "$patch" 2>/dev/null; then
      echo "Patch already applied, skipping: $patch"
    else
      echo "ERROR: Failed to apply patch: $patch" >&2
      git apply --check "$patch" >&2 || true
      exit 1
    fi
  done
fi

exec "$@"
