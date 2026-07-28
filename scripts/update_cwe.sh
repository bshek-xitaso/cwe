#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/update_cwe.sh VERSION --env linux|mac
#     - downloads CWE data for the given version using the URL https://cwe.mitre.org/data/xml/cwec_<VERSION>.xml.zip
#     - converts it to TSV and saves to assets/cwe/cwe_<XML_VERSION>_<XML_DATE>.tsv
#     - the output filename is derived from the XML Version/Catalog_Version
#       and Date/Catalog_Date attributes, NOT from the VERSION argument
#     - --env: specify environment (linux for CI, mac for macOS)

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

if [[ -z "${2:-}" ]] || [[ "$2" != "--env" ]]; then
  echo "Error: --env argument is required" >&2
  exit 1
fi

if [[ -z "${3:-}" ]]; then
  echo "Error: --env value is required (linux or mac)" >&2
  exit 1
fi
ENV=$3


# Set environment-specific security settings (macOS provides less xsltproc security flags and no ulimit -v support)
case "$ENV" in
  linux)
    XSLTPROC_ARGS=(
      --noxinclude   # Disable XInclude attacks
      --nonet        # Disable network access
      --nopython     # Disable Python extensions
      --nomodule     # Disable dynamic module loading
      --nodefdtd     # Disable DTD loading (against entity expansion attacks)
    )
    ULIMIT_V=100000  # Limit virtual memory to 100MB
    ULIMIT_T=60      # Limit CPU time to 60s
    ;;
  mac)
    XSLTPROC_ARGS=(
      --nonet        # Disable network access
      --novalid      # Skip DTD loading phase
    )
    ULIMIT_V=""      # macOS doesn't support -v flag
    ULIMIT_T=60      # Limit CPU time to 60s
    ;;
  *)
    echo "Error: ENV must be 'linux' or 'mac', got '$ENV'" >&2
    exit 1
    ;;
esac

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
uncompressed_size=$(unzip -l "$temp_dir/cwec.zip" | awk 'NR==4 {print $1}')

if [[ -z "$uncompressed_size" ]] || ! [[ "$uncompressed_size" =~ ^[0-9]+$ ]]; then
  echo "Error: Could not determine uncompressed size from archive" >&2
  exit 1
fi

if [[ $uncompressed_size -gt $max_size ]]; then
  echo "Error: Uncompressed XML exceeds size limit (${uncompressed_size} > ${max_size})" >&2
  exit 1
fi

# Extract and process with hardened xsltproc flags
unzip -p "$temp_dir/cwec.zip" \
  | (
    [[ -n "$ULIMIT_V" ]] && ulimit -v "$ULIMIT_V" || true
    ulimit -t "$ULIMIT_T"
    xsltproc "${XSLTPROC_ARGS[@]}" scripts/convert_cwe_to_tsv.xslt -
  ) \
  | (read -r header; sort -n > "${output_dir}/cwe_${header}.tsv")