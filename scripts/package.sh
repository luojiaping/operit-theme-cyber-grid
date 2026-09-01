#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v jq >/dev/null
command -v zip >/dev/null
command -v sha256sum >/dev/null

manifest="operit-theme.json"
test -f "$manifest"

# V3 契约：完整 Material 投影、组件皮肤、日常 surface 与可调参数都是包的强制部分。
jq -e '
   def no_unknown_keys($allowed):
     type == "object" and ((keys - $allowed) | length == 0);
   def valid_stroke:
     type == "object" and
     no_unknown_keys(["token", "widthDp"]) and
     (.token | type == "string" and length > 0) and
     (.widthDp | type == "number" and . >= 0.25 and . <= 16);
   def valid_optional_stroke: . == null or valid_stroke;
  def required_surface_ids:
    ["app.shell", "app.navigation", "chat.main", "chat.floating",
     "chat.permission_overlay", "browser.shell", "web_chat.main",
     "memory.graph_library", "market.home", "market.category",
     "market.entry_detail", "market.publisher_console", "market.artifact_editor",
     "market.repository_editor", "packages.manager", "workflow.library",
     "workflow.canvas_editor", "files.browser", "assistant.profile",
     "persona.card_studio", "prompt_tag.market", "settings.index", "settings.form",
     "settings.statistics", "toolbox.index", "toolbox.tool", "terminal.shell",
     "media.shell", "plugin.host_shell", "overlay.dialog", "overlay.sheet",
     "overlay.menu", "overlay.snackbar", "overlay.toast", "state.loading",
     "state.empty", "state.error"];
  def required_component_ids:
    ["app_bar", "navigation", "page", "section", "list_item", "button",
     "icon_button", "input", "composer", "message_user", "message_assistant",
     "dialog", "sheet", "menu", "snackbar", "status"];
  def expected_surface_kind($surface):
    if $surface == "app.shell" or $surface == "chat.main" then
      "SCENE"
    elif $surface == "browser.shell" or $surface == "terminal.shell" or
         $surface == "media.shell" or $surface == "plugin.host_shell" then
      "HOST_SHELL"
    else
      "TEMPLATE"
    end;
   def valid_surface:
    type == "object" and
    no_unknown_keys(["surfaceId", "kind", "sceneId"]) and
    (.surfaceId | type == "string") and
    (.surfaceId as $surface | required_surface_ids | index($surface) != null) and
     (.surfaceId as $surface | .kind == expected_surface_kind($surface)) and
     (if .kind == "SCENE" then .sceneId == .surfaceId else .sceneId == null end);
   def valid_semver:
     type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$");
   def valid_basis:
     . == null or
     (type == "object" and
      no_unknown_keys(["packageId", "version", "archiveSha256"]) and
      (.packageId | type == "string" and test("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")) and
      (.version | valid_semver) and
      (.archiveSha256 | type == "string" and test("^[0-9a-f]{64}$")));
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
   def valid_localized_text:
     type == "object" and
     no_unknown_keys(["values"]) and
     (.values | type == "object" and has("*") and all(.[]; type == "string" and length > 0));
   def valid_member_id:
     type == "string" and test("^[a-z][a-z0-9_]*$");
   def valid_token_id:
     type == "string" and test("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)*$");
   def valid_color_effect:
     type == "object" and
     (if .type == "accent_palette" then
        no_unknown_keys(["type"])
      elif .type == "token_color" then
        no_unknown_keys(["type", "tokenIds"]) and
        (.tokenIds | type == "array" and length > 0 and
          all(valid_token_id) and length == (unique | length))
      else false end);
   def valid_color_parameter:
     (.defaultValue | type == "object" and no_unknown_keys(["type", "argb"]) and .type == "color" and
       (.argb | type == "number" and . >= 0 and . <= 4294967295)) and
     (.control | type == "object" and no_unknown_keys(["type", "presetArgb", "allowCustom"]) and .type == "color_palette") and
     (.control.presetArgb | type == "array" and
       all(type == "number" and . >= 4278190080 and . <= 4294967295) and
       length == (unique | length)) and
     (.control.allowCustom | type == "boolean") and
     ((.control.presetArgb | length) > 0 or .control.allowCustom) and
     all(.effects[]; valid_color_effect) and
     (.defaultValue.argb >= 4278190080);
   def valid_image_parameter:
     (.defaultValue | type == "object" and no_unknown_keys(["type"]) and .type == "unset") and
     (.control | type == "object" and no_unknown_keys(["type", "mimeTypes"]) and .type == "image_picker") and
     (.control.mimeTypes | type == "array" and length > 0 and
       all(IN("image/jpeg", "image/png", "image/webp")) and
       length == (unique | length)) and
     all(.effects[];
       type == "object" and .type == "stage_image" and
       no_unknown_keys(["type", "surfaceIds", "fit", "opacity"]) and
       (.surfaceIds | type == "array" and length > 0 and
         all(. == "app.shell" or . == "chat.main") and
         length == (unique | length)) and
       (.fit | IN("FILL", "FIT", "CROP")) and
       (.opacity | type == "number" and . >= 0 and . <= 1));
   def valid_parameter:
     type == "object" and
     no_unknown_keys(["id", "type", "defaultValue", "label", "description", "control", "effects"]) and
     (.id | valid_member_id) and
     (.type | type == "string" and IN("COLOR", "IMAGE_URI")) and
     (.label | valid_localized_text) and
     (.description == null or (.description | valid_localized_text)) and
     (.control | type == "object" and (.type | type == "string")) and
     (.effects | type == "array" and length > 0) and
     (if .type == "COLOR" then
        valid_color_parameter
      else valid_image_parameter
      end);
   type == "object" and
   no_unknown_keys(["schemaVersion", "packageId", "version", "displayName", "author", "description", "attribution", "basis", "variants", "parameters", "assets", "tokens", "scenes", "surfaces", "presentation"]) and
   .schemaVersion == 3 and
   (.packageId | test("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")) and
   (.version | valid_semver) and
   (.displayName | valid_localized_text) and
   (.author == null or (.author | valid_localized_text)) and
   (.description == null or (.description | valid_localized_text)) and
   (.basis | valid_basis) and
   (.presentation | type == "object") and
   ((.presentation.material == null) or (.presentation.material.colors | type == "object")) and
   ((.presentation.componentSkins // {}) | type == "object") and
   ((.presentation.componentSkins // {})
      | to_entries
      | all(
           .value
           | (.normal != null and .normal.frame != null and (.normal.frame | valid_frame)) and
             ([.disabled, .selected, .focused, .error]
              | map(select(. != null))
              | all(has("frame") and (.frame | valid_frame)))
         )) and
    ((.surfaces // []) | type == "array" and all(valid_surface)) and
    ((.surfaces // []) | map(.surfaceId)) as $surface_ids |
    ((($surface_ids - required_surface_ids) | length) == 0) and
    ((.presentation.componentSkins // {}) | keys) as $component_ids |
    ((($component_ids - required_component_ids) | length) == 0) and
    (((.presentation.componentSkins // {}) | has("input") | not) or
     (.presentation.componentSkins.input.focused != null and
      .presentation.componentSkins.input.error != null)) and
    (((.presentation.componentSkins // {}) | has("status") | not) or
     .presentation.componentSkins.status.error != null) and
    ((.parameters // []) | type == "array" and
      (map(.id) | length == (unique | length)) and
      all(valid_parameter)) and
    (if .basis == null then
       (.presentation.material.colors | type == "object") and
       ((.presentation.componentSkins // {}) | length > 0) and
       (($surface_ids | length) > 0) and
       (($surface_ids | sort) == (required_surface_ids | sort)) and
       (($component_ids | sort) == (required_component_ids | sort))
     else
       true
     end) and
    ((.scenes // []) | type == "array") and
   ((.scenes // []) | map(.sceneId) | . == unique)
' "$manifest" >/dev/null

# 场景型 surface 必须能找到对应场景定义。
while IFS=$'\t' read -r surface scene; do
  test -n "$surface"
  test "$surface" = "$scene"
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
(
  cd dist
  sha256sum "$archive_name" > "$archive_name.sha256"
)
printf '%s\n' "$archive"
