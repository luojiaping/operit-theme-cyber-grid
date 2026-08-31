#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v jq >/dev/null
command -v zip >/dev/null
command -v sha256sum >/dev/null

manifest="operit-theme.json"
test -f "$manifest"

# V2 契约：完整 Material 投影 + 组件皮肤 + 日常 surface 覆盖是包的强制部分。
jq -e '
  def valid_stroke:
    type == "object" and
    (.token | type == "string" and length > 0) and
    (.widthDp | type == "number" and . >= 0.25 and . <= 16);
  def valid_optional_stroke: . == null or valid_stroke;
  def valid_frame:
    type == "object" and
    (.type | type == "string") and
    (if .type == "none" then
       true
     elif .type == "round_rect" then
       (.cornerRadiusDp | type == "number" and . >= 0 and . <= 96) and
       (.border | valid_optional_stroke)
     elif .type == "cut_corners" then
       (.cutSizeDp | type == "number" and . >= 0.5 and . <= 48) and
       (.border | valid_stroke) and
       (.accent | valid_optional_stroke)
     elif .type == "hud_notched" then
       (.cutSizeDp | type == "number" and . >= 0.5 and . <= 48) and
       (.notchWidthFraction | type == "number" and . >= 0.1 and . <= 0.7) and
       (.notchDepthDp | type == "number" and . >= 0.5 and . <= 48) and
       (.border | valid_stroke) and
       (.accent | valid_optional_stroke)
     elif .type == "corner_brackets" then
       (.cornerCutDp | type == "number" and . >= 0 and . <= 48) and
       (.bracketLengthDp | type == "number" and . >= 4 and . <= 96) and
       (.border | valid_stroke) and
       (.accent | valid_optional_stroke)
     elif .type == "segmented_rail" then
       (.cornerCutDp | type == "number" and . >= 0 and . <= 48) and
       (.railInsetDp | type == "number" and . >= 0 and . <= 48) and
       (.segmentLengthDp | type == "number" and . >= 4 and . <= 160) and
       (.border | valid_stroke) and
       (.accent | valid_stroke)
     else
       false
     end);
   .schemaVersion == 2 and
  (.packageId | test("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")) and
  (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+([-.+][0-9A-Za-z.-]+)?$")) and
   (.presentation.material.colors | type == "object") and
   (.presentation.componentSkins | type == "object" and length > 0) and
   (.presentation.componentSkins
      | to_entries
      | all(
          .value
          | [.normal, .disabled, .selected, .focused, .error]
          | map(select(. != null))
          | all(has("frame") and (.frame | valid_frame))
        )) and
   (.surfaces | type == "array" and length > 0) and
  (.scenes | type == "array") and
  (.scenes | map(.sceneId) | . == unique)
' "$manifest" >/dev/null

# 场景型 surface 必须能找到对应场景定义。
while IFS=$'\t' read -r surface scene; do
  test -n "$surface"
  jq -e --arg scene "$scene" 'any(.scenes[]; .sceneId == $scene)' "$manifest" >/dev/null ||
    { echo "surface $surface references missing scene $scene" >&2; exit 1; }
done < <(jq -r '(.surfaces // [])[] | select(.kind == "SCENE") | [.surfaceId, (.sceneId // "")] | @tsv' "$manifest")

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
stage="$(mktemp -d "${TMPDIR:-/tmp}/operit-theme-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
for entry in "${entries[@]}"; do
  staged_entry="$stage/$entry"
  mkdir -p "$(dirname "$staged_entry")"
  cp "$entry" "$staged_entry"
  TZ=UTC touch -t 198001010000 "$staged_entry"
  chmod 0644 "$staged_entry"
done
(
  export TZ=UTC
  cd "$stage"
  zip -X -q "$repo_root/$archive" "${entries[@]}"
  printf '%s\n' 'Operit Theme Package' | zip -z -q "$repo_root/$archive"
)
sha256sum "$archive" > "$archive.sha256"
printf '%s\n' "$archive"
