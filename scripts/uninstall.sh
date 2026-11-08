#!/usr/bin/env bash
set -euo pipefail
switchboard_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: ./scripts/uninstall.sh'
  echo 'Remove this installation and its managed bindings; restore any pre-existing plugin.'
  exit 0
fi
if (( $# )); then echo 'Usage: ./scripts/uninstall.sh' >&2; exit 2; fi
python3 "$switchboard_root/scripts/local_plugin.py" uninstall
