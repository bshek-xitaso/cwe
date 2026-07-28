#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/update_cwe.sh VERSION
#     - downloads CWE data for the given version using the URL https://cwe.mitre.org/data/xml/cwec_<VERSION>.xml.zip
#     - converts it to TSV and saves to assets/cwe/cwe_<XML_VERSION>_<XML_DATE>.tsv
#     - the output filename is derived from the XML Version/Catalog_Version
#       and Date/Catalog_Date attributes, NOT from the VERSION argument

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

# temporary directory for downloads and validation
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Download the CWE data
curl -fS \
  -H "User-Agent: cwe-version-extractor/1.0 (+https://github.com/csaf-rs/cwe)" \
  https://cwe.mitre.org/data/xml/cwec_${VERSION}.xml.zip \
  -o "$temp_dir/cwec.zip"

# Validate uncompressed size to detect XML bombing attacks (limit set to 25MB)
max_size=$((25 * 1024 * 1024))
uncompressed_size=$(unzip -l "$temp_dir/cwec.zip" | awk 'NR==2 {print $1}')

if [[ $uncompressed_size -gt $max_size ]]; then
  echo "Error: Uncompressed XML exceeds size limit (${uncompressed_size} > ${max_size})" >&2
  exit 1
fi

# Extract and process with hardened xsltproc flags
# Flags:
#   --noxinclude: disable XInclude attacks
#   --nonet: disable network access
#   --nopython: disable Python extensions
#   --nomodule: disable dynamic module loading
#   --nodefdtd: disable DTD loading (against entity expansion attacks)
unzip -p "$temp_dir/cwec.zip" \
  | (
    ulimit -v 100000  # Limit virtual memory to 100MB
    timeout 60 # Limit time to 60s
    xsltproc \
      --noxinclude \
      --nonet \
      --nopython \
      --nomodule \
      --nodefdtd \
      scripts/convert_cwe_to_tsv.xslt -
  ) \
  | (read -r header; sort -n > "${output_dir}/cwe_${header}.tsv")