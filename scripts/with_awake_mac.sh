#!/usr/bin/env bash
set -euo pipefail

# Assertions belong to this debugging command, not persistent power settings.
# PreventSystemSleep (-s) is effective on AC; -i also prevents idle sleep.
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 command [args...]" >&2
  exit 64
fi

if [[ ! -x /usr/bin/caffeinate ]]; then
  echo "This debugging wrapper requires macOS caffeinate." >&2
  exit 1
fi

exec /usr/bin/caffeinate -is "$@"
