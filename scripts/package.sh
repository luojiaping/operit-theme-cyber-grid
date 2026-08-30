#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v jq >/dev/null
command -v zip >/dev/null
command -v sha256sum >/dev/null

manifest="operit-theme.json"
test -f "$manifest"

jq -e '
  .schemaVersion == 1 and
  (.packageId | test("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")) and
  (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+([-.+][0-9A-Za-z.-]+)?$")) and
  (.capabilities.hostSurfaces | type == "array" and length > 0) and
  (.capabilities.scenes | type == "array" and length > 0) and
  (.scenes | type == "array" and length > 0)
' "$manifest" >/dev/null

while IFS=$'\t' read -r path expected_sha expected_size; do
  test -n "$path"
  test "${path#/}" = "$path"
  test -f "$path"
  actual_sha="$(sha256sum "$path" | cut -d ' ' -f 1)"
  actual_size="$(wc -c < "$path" | tr -d ' ')"
  test "$actual_sha" = "$expected_sha"
  test "$actual_size" = "$expected_size"
done < <(jq -r '(.assets // [])[] | [.path, .sha256, (.byteSize | tostring)] | @tsv' "$manifest")

package_id="$(jq -r '.packageId' "$manifest")"
version="$(jq -r '.version' "$manifest")"
archive_prefix="${package_id//./-}"
archive_prefix="${archive_prefix//_/-}"
archive_name="${archive_prefix}-${version}.otheme"
mkdir -p dist
archive="dist/$archive_name"
entries=("$manifest")

if test -f ATTRIBUTION.md; then
  entries+=("ATTRIBUTION.md")
fi

while IFS= read -r path; do
  entries+=("$path")
done < <(jq -r '(.assets // [])[] | .path' "$manifest")

rm -f "$archive" "$archive.sha256"
zip -X -q "$archive" "${entries[@]}"
printf '%s\n' 'Operit Theme Package' | zip -z -q "$archive"
sha256sum "$archive" > "$archive.sha256"
printf '%s\n' "$archive"
