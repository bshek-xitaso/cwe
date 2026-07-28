#!/usr/bin/env bash
set -euxo pipefail

# Usage:
#   bash scripts/update_all_cwes.sh --env linux|mac
#     - updates all available CWE versions from the MITRE archive page.
#     - --env: specify environment (linux for CI, mac for macOS)

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository." >&2
  exit 1
}
cd "$REPO_ROOT"

if [[ -z "${1:-}" ]] || [[ "$1" != "--env" ]]; then
  echo "Error: --env argument is required" >&2
  exit 1
fi

if [[ -z "${2:-}" ]]; then
  echo "Error: --env value is required (linux or mac)" >&2
  exit 1
fi
ENV=$2

if [[ "$ENV" != "linux" && "$ENV" != "mac" ]]; then
  echo "Error: --env must be 'linux' or 'mac', got '$ENV'" >&2
  exit 1
fi

python3 scripts/extract_cwe_versions.py \
  | while IFS= read -r version; do
    bash scripts/update_cwe.sh "${version}" --env "$ENV"
  done