#!/usr/bin/env bash
set -euo pipefail
switchboard_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 "$switchboard_root/scripts/local_plugin.py" migrate "$@"
