#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/update_cwe.sh VERSION
#     - downloads and converts CWE data for the given version.
#     - saves to assets/cwe/cwe_<VERSION>_<DATE>.tsv

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository." >&2
  exit 1
}
cd "$REPO_ROOT"

if [[ -z "${1:-}" ]]; then
  echo "Error: VERSION argument is required" >&2
  exit 1
fi
VERSION=$1

output_dir="assets/cwe"
mkdir -p "$output_dir"

curl -fS \
  -H "User-Agent: cwe-version-extractor/1.0 (+https://github.com/csaf-rs/cwe)" \
  https://cwe.mitre.org/data/xml/cwec_${VERSION}.xml.zip \
  | funzip \
  | xsltproc scripts/convert_cwe_to_tsv.xslt - \
  | (read -r header; sort -n > "${output_dir}/cwe_${header}.tsv")