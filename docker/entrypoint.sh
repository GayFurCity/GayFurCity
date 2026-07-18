#!/bin/sh
set -e

PATCHES_DIR="${PATCHES_DIR:-/patches}"

# Default failure behavior for patches that don't opt into one via filename suffix (see below)
# Set to "warn" to log and continue instead of aborting startup
# Defaults to "fail" to preserve prior behavior
PATCH_ON_FAILURE="${PATCH_ON_FAILURE:-fail}"
case "$PATCH_ON_FAILURE" in
  fail | warn) ;;
  *)
    echo "WARNING: invalid PATCH_ON_FAILURE '$PATCH_ON_FAILURE', defaulting to 'fail'" >&2
    PATCH_ON_FAILURE="fail"
    ;;
esac

if [ -d "$PATCHES_DIR" ]; then
  for patch in $(find "$PATCHES_DIR" -maxdepth 1 -name "*.patch" | sort); do
    # Per-patch override via filename suffix, e.g. "foo.optional.patch" or "foo.required.patch"
    # Plain "*.patch" files fall back to $PATCH_ON_FAILURE
    case "$patch" in
      *.optional.patch) mode="warn" ;;
      *.required.patch) mode="fail" ;;
      *) mode="$PATCH_ON_FAILURE" ;;
    esac

    if git apply --check "$patch" 2>/dev/null; then
      echo "Applying patch: $patch"
      git apply "$patch"
    elif git apply -R --check "$patch" 2>/dev/null; then
      echo "Patch already applied, skipping: $patch"
    elif [ "$mode" = "warn" ]; then
      echo "WARNING: Failed to apply patch, continuing: $patch" >&2
      git apply --check "$patch" >&2 || true
    else
      echo "ERROR: Failed to apply patch: $patch" >&2
      git apply --check "$patch" >&2 || true
      exit 1
    fi
  done
fi

exec "$@"
