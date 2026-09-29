#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for arg in "$@"; do
  case "$arg" in
    --release|--profile|-r)
      echo "This script only runs debug builds." >&2
      exit 1
      ;;
  esac
done

config_file="$(python3 - "$script_dir" <<'PY'
import json
import subprocess
import sys
import tempfile

result = subprocess.run(
    ['security', 'find-generic-password', '-s', 'smooth-markdown-deepseek-dev', '-w'],
    capture_output=True,
    text=True,
)
key = result.stdout.rstrip('\r\n')
if result.returncode != 0 or not key:
    raise SystemExit('DeepSeek Key was not found in macOS Keychain.')

with tempfile.NamedTemporaryFile(
    mode='w',
    prefix='.deepseek-dev.',
    suffix='.json',
    dir=sys.argv[1],
    delete=False,
) as config:
    json.dump({'DEEPSEEK_API_KEY': key}, config)
    print(config.name)
PY
)"
trap 'unlink "$config_file" 2>/dev/null || true' EXIT

cd "$script_dir"
flutter run --debug --dart-define-from-file="$config_file" "$@"
