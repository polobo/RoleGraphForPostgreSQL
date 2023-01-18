#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

SELF_DIR="$(cd $(dirname $0) && pwd)"

PSQLRC="${SELF_DIR}/.psqlrc" psql -qf "${SELF_DIR}"/lib/install-schema-and-views.psql
if [[ $? -eq 0 ]]; then
    echo "Installation successful."
else
    echo "Installation failed."
fi
