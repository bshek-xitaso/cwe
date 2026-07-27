#!/usr/bin/env bash
set -euxo pipefail

# Usage:
#   bash scripts/update_all_cwes.sh
#     - updates all available CWE versions from the MITRE archive page.

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository." >&2
  exit 1
}
cd "$REPO_ROOT"

python3 scripts/extract_cwe_versions.py \
  | while IFS= read -r version; do
    bash scripts/update_cwe.sh "v${version}"
  done