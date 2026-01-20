#!/bin/bash
# Build script for Plinth - loads environment from .env if present

set -e

# Load .env if it exists
if [ -f .env ]; then
    echo "Loading environment from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# Run make with provided arguments
make "$@"
