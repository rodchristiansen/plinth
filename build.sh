#!/bin/bash
# Build script for Plinth - loads environment from .env if present

set -e

# Load .env if it exists
if [ -f .env ]; then
    echo "Loading environment from .env..."
    set -a
    # shellcheck source=.env
    source .env
    set +a
fi

# Translate convenience flags to make targets/variables
MAKE_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --intel)     MAKE_ARGS+=("intel") ;;
        --universal) MAKE_ARGS+=("universal") ;;
        *)           MAKE_ARGS+=("$arg") ;;
    esac
done

make "${MAKE_ARGS[@]}"
