#!/usr/bin/env bash
set -euo pipefail
switchboard_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: ./scripts/install.sh [--bindings | --no-bindings]'
  echo 'Build, check, deploy and enable the local plugin. Existing binding mode is preserved unless specified.'
  exit 0
fi
for switchboard_arg in "$@"; do
  case "$switchboard_arg" in --bindings|--no-bindings) ;; *) echo "Unknown option: $switchboard_arg" >&2; exit 2;; esac
done
cd -- "$switchboard_root"
npm run check
python3 "$switchboard_root/scripts/local_plugin.py" install "$@"
