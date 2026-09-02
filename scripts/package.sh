#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v jq >/dev/null
command -v zip >/dev/null
command -v sha256sum >/dev/null

manifest="operit-theme.json"
test -f "$manifest"

# V4 contract: typed parameters, behavior, component skins, and daily surfaces are mandatory.
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
    def valid_integer:
      type == "number" and floor == .;
    def valid_argb:
      valid_integer and . >= 0 and . <= 4294967295;
    def valid_opaque_argb:
      valid_argb and . >= 4278190080;
    def valid_nullable_argb:
      . == null or valid_argb;
    def exact_keys($expected):
      type == "object" and (keys | sort) == ($expected | sort);
    def valid_system_font_family:
      type == "string" and IN("DEFAULT", "SANS_SERIF", "SERIF", "MONOSPACE", "CURSIVE");
    def valid_background_behavior:
      exact_keys(["enabled", "mediaType", "opacity", "blurEnabled", "blurRadiusDp", "videoMuted", "videoLoop"]) and
      (.enabled | type == "boolean") and
      (.mediaType | type == "string" and IN("NONE", "IMAGE", "VIDEO")) and
      (.opacity | type == "number" and . >= 0 and . <= 1) and
      (.blurEnabled | type == "boolean") and
      (.blurRadiusDp | type == "number" and . >= 0 and . <= 96) and
      (.videoMuted | type == "boolean") and
      (.videoLoop | type == "boolean") and
      ((.enabled | not) or .mediaType != "NONE");
    def valid_typography_behavior:
      exact_keys(["useCustomFont", "family", "scale"]) and
      (.useCustomFont | type == "boolean") and
      (.family | valid_system_font_family) and
      (.scale | type == "number" and . >= 0.5 and . <= 2);
    def valid_conversation_behavior:
      exact_keys([
        "cursorUserBubbleFollowTheme", "cursorUserBubbleLiquidGlass", "cursorUserBubbleWaterGlass",
        "cursorUserBubbleColorArgb", "bubbleShowAvatar", "bubbleWideLayout", "bubbleUserLiquidGlass",
        "bubbleUserWaterGlass", "bubbleAssistantLiquidGlass", "bubbleAssistantWaterGlass",
        "bubbleImageRenderMode", "bubbleUserRoundedCorners", "bubbleAssistantRoundedCorners",
        "bubbleUserColorArgb", "bubbleAssistantColorArgb", "bubbleUserTextColorArgb",
        "bubbleAssistantTextColorArgb", "bubbleUserUseCustomFont", "bubbleUserFontFamily",
        "bubbleAssistantUseCustomFont", "bubbleAssistantFontFamily", "avatarShape", "avatarCornerRadiusDp"
      ]) and
      (.cursorUserBubbleFollowTheme | type == "boolean") and
      (.cursorUserBubbleLiquidGlass | type == "boolean") and
      (.cursorUserBubbleWaterGlass | type == "boolean") and
      (.cursorUserBubbleColorArgb | valid_nullable_argb) and
      (.bubbleShowAvatar | type == "boolean") and
      (.bubbleWideLayout | type == "boolean") and
      (.bubbleUserLiquidGlass | type == "boolean") and
      (.bubbleUserWaterGlass | type == "boolean") and
      (.bubbleAssistantLiquidGlass | type == "boolean") and
      (.bubbleAssistantWaterGlass | type == "boolean") and
      (.bubbleImageRenderMode | type == "string" and IN("TILED_NINE_SLICE", "NINE_PATCH")) and
      (.bubbleUserRoundedCorners | type == "boolean") and
      (.bubbleAssistantRoundedCorners | type == "boolean") and
      (.bubbleUserColorArgb | valid_nullable_argb) and
      (.bubbleAssistantColorArgb | valid_nullable_argb) and
      (.bubbleUserTextColorArgb | valid_nullable_argb) and
      (.bubbleAssistantTextColorArgb | valid_nullable_argb) and
      (.bubbleUserUseCustomFont | type == "boolean") and
      (.bubbleUserFontFamily | valid_system_font_family) and
      (.bubbleAssistantUseCustomFont | type == "boolean") and
      (.bubbleAssistantFontFamily | valid_system_font_family) and
      (.avatarShape | type == "string" and IN("CIRCLE", "SQUARE", "ROUNDED")) and
      (.avatarCornerRadiusDp | type == "number" and . >= 0 and . <= 96);
    def valid_composer_behavior:
      exact_keys(["transparent", "floating", "liquidGlass", "waterGlass"]) and
      (.transparent | type == "boolean") and
      (.floating | type == "boolean") and
      (.liquidGlass | type == "boolean") and
      (.waterGlass | type == "boolean");
    def valid_chrome_behavior:
      exact_keys([
        "statusBarHidden", "statusBarTransparent", "statusBarColorArgb", "toolbarTransparent",
        "toolbarColorArgb", "navigationWaterGlass", "navigationButtonLiquidGlass",
        "navigationBackgroundColorArgb", "navigationAccentColorArgb", "chatHeaderTransparent",
        "chatHeaderOverlayMode", "appBarContentColorMode", "chatHeaderHistoryIconColorArgb",
        "chatHeaderPipIconColorArgb"
      ]) and
      (.statusBarHidden | type == "boolean") and
      (.statusBarTransparent | type == "boolean") and
      (.statusBarColorArgb | valid_nullable_argb) and
      (.toolbarTransparent | type == "boolean") and
      (.toolbarColorArgb | valid_nullable_argb) and
      (.navigationWaterGlass | type == "boolean") and
      (.navigationButtonLiquidGlass | type == "boolean") and
      (.navigationBackgroundColorArgb | valid_nullable_argb) and
      (.navigationAccentColorArgb | valid_nullable_argb) and
      (.chatHeaderTransparent | type == "boolean") and
      (.chatHeaderOverlayMode | type == "string" and IN("NONE", "OVERLAY")) and
      (.appBarContentColorMode | type == "string" and IN("AUTO", "LIGHT", "DARK")) and
      (.chatHeaderHistoryIconColorArgb | valid_nullable_argb) and
      (.chatHeaderPipIconColorArgb | valid_nullable_argb);
    def valid_presentation_behavior:
      exact_keys(["background", "typography", "conversation", "composer", "chrome"]) and
      (.background | valid_background_behavior) and
      (.typography | valid_typography_behavior) and
      (.conversation | valid_conversation_behavior) and
      (.composer | valid_composer_behavior) and
      (.chrome | valid_chrome_behavior);
    def valid_parameter_type:
      type == "string" and
      IN("COLOR", "COLOR_PAIR", "BOOLEAN", "OPTION", "FLOAT", "IMAGE_URI", "VIDEO_URI", "FONT_URI", "IMAGE_LAYOUT", "INSETS", "CORNER_RADIUS");
    def valid_parameter_visibility:
      type == "string" and IN("USER", "AUTHOR");
    def valid_parameter_section:
      type == "string" and IN("APPEARANCE", "CONVERSATION", "COMPOSER", "APP_CHROME");
    def valid_supported_surface_id:
      type == "string" and (. as $id | required_surface_ids | index($id) != null);
    def valid_scene_surface_id:
      valid_supported_surface_id and (. == "app.shell" or . == "chat.main");
    def valid_supported_component_id:
      type == "string" and (. as $id | required_component_ids | index($id) != null);
    def valid_choice_option:
      type == "object" and
      no_unknown_keys(["id", "label"]) and
      (.id | valid_member_id) and
      (.label | valid_localized_text);
    def valid_color_palette_control:
      type == "object" and
      no_unknown_keys(["type", "presetArgb", "allowCustom"]) and
      .type == "color_palette" and
      (if has("presetArgb") then
         (.presetArgb | type == "array" and all(valid_opaque_argb) and length == (unique | length))
       else true end) and
      (if has("allowCustom") then (.allowCustom | type == "boolean") else true end) and
      ((if has("presetArgb") then (.presetArgb | length) else 0 end) as $preset_count |
       (if has("allowCustom") then .allowCustom else true end) as $allow_custom |
       ($preset_count > 0 or $allow_custom));
    def valid_color_pair_palette_control:
      type == "object" and
      no_unknown_keys(["type", "lightPresetArgb", "darkPresetArgb", "allowCustom"]) and
      .type == "color_pair_palette" and
      (if has("lightPresetArgb") then
         (.lightPresetArgb | type == "array" and all(valid_argb) and length == (unique | length))
       else true end) and
      (if has("darkPresetArgb") then
         (.darkPresetArgb | type == "array" and all(valid_argb) and length == (unique | length))
       else true end) and
      (if has("allowCustom") then (.allowCustom | type == "boolean") else true end) and
      ((if has("lightPresetArgb") then (.lightPresetArgb | length) else 0 end) as $light_count |
       (if has("darkPresetArgb") then (.darkPresetArgb | length) else 0 end) as $dark_count |
       (if has("allowCustom") then .allowCustom else true end) as $allow_custom |
       ($light_count + $dark_count > 0 or $allow_custom));
    def valid_toggle_control:
      type == "object" and no_unknown_keys(["type"]) and .type == "toggle";
    def valid_choice_control:
      type == "object" and
      no_unknown_keys(["type", "options"]) and
      .type == "choice" and
      (.options | type == "array" and length > 0 and all(valid_choice_option) and
        (map(.id) | length == (unique | length)));
    def valid_slider_control:
      type == "object" and
      no_unknown_keys(["type", "minimum", "maximum", "step"]) and
      .type == "slider" and
      (.minimum | type == "number") and
      (.maximum | type == "number") and
      (.step | type == "number") and
      (.minimum < .maximum) and
      (.step > 0 and .step <= .maximum - .minimum);
    def valid_image_picker_control:
      type == "object" and
      no_unknown_keys(["type", "mimeTypes"]) and
      .type == "image_picker" and
      (if has("mimeTypes") then
         (.mimeTypes | type == "array" and length > 0 and
           all(IN("image/jpeg", "image/png", "image/webp")) and
           length == (unique | length))
       else true end);
    def valid_video_picker_control:
      type == "object" and
      no_unknown_keys(["type", "mimeTypes"]) and
      .type == "video_picker" and
      (if has("mimeTypes") then
         (.mimeTypes | type == "array" and length > 0 and
           all(IN("video/mp4", "video/webm")) and
           length == (unique | length))
       else true end);
    def valid_font_picker_control:
      type == "object" and
      no_unknown_keys(["type", "mimeTypes"]) and
      .type == "font_picker" and
      (if has("mimeTypes") then
         (.mimeTypes | type == "array" and length > 0 and
            all(IN("font/ttf", "font/otf")) and
           length == (unique | length))
       else true end);
    def valid_author_value_control:
      type == "object" and no_unknown_keys(["type"]) and .type == "author_value";
    def valid_parameter_control($parameter_type):
      type == "object" and
      (if .type == "color_palette" then
         $parameter_type == "COLOR" and valid_color_palette_control
       elif .type == "color_pair_palette" then
         $parameter_type == "COLOR_PAIR" and valid_color_pair_palette_control
       elif .type == "toggle" then
         $parameter_type == "BOOLEAN" and valid_toggle_control
       elif .type == "choice" then
         $parameter_type == "OPTION" and valid_choice_control
       elif .type == "slider" then
         $parameter_type == "FLOAT" and valid_slider_control
       elif .type == "image_picker" then
         $parameter_type == "IMAGE_URI" and valid_image_picker_control
       elif .type == "video_picker" then
         $parameter_type == "VIDEO_URI" and valid_video_picker_control
       elif .type == "font_picker" then
         $parameter_type == "FONT_URI" and valid_font_picker_control
       elif .type == "author_value" then
         valid_author_value_control
       else false end);
    def valid_image_layout_value:
      type == "object" and
      no_unknown_keys(["type", "cropLeft", "cropTop", "cropRight", "cropBottom", "repeatStart", "repeatEnd", "repeatYStart", "repeatYEnd", "scale"]) and
      .type == "image_layout" and
      ((if has("cropLeft") then .cropLeft else 0 end) as $crop_left |
       (if has("cropTop") then .cropTop else 0 end) as $crop_top |
       (if has("cropRight") then .cropRight else 1 end) as $crop_right |
       (if has("cropBottom") then .cropBottom else 1 end) as $crop_bottom |
       (if has("repeatStart") then .repeatStart else 0 end) as $repeat_start |
       (if has("repeatEnd") then .repeatEnd else 1 end) as $repeat_end |
       (if has("repeatYStart") then .repeatYStart else 0 end) as $repeat_y_start |
       (if has("repeatYEnd") then .repeatYEnd else 1 end) as $repeat_y_end |
       (if has("scale") then .scale else 1 end) as $scale |
       ($crop_left | type == "number" and . >= 0 and . <= 1) and
       ($crop_top | type == "number" and . >= 0 and . <= 1) and
       ($crop_right | type == "number" and . >= $crop_left and . <= 1) and
       ($crop_bottom | type == "number" and . >= $crop_top and . <= 1) and
       ($repeat_start | type == "number" and . >= 0 and . <= 1) and
       ($repeat_end | type == "number" and . >= $repeat_start and . <= 1) and
       ($repeat_y_start | type == "number" and . >= 0 and . <= 1) and
       ($repeat_y_end | type == "number" and . >= $repeat_y_start and . <= 1) and
       ($scale | type == "number" and . >= 0.1 and . <= 8));
    def valid_parameter_value($parameter_type):
      if . == null then true
      elif $parameter_type == "COLOR" then
        type == "object" and no_unknown_keys(["type", "argb"]) and .type == "color" and (.argb | valid_argb)
      elif $parameter_type == "COLOR_PAIR" then
        type == "object" and no_unknown_keys(["type", "lightArgb", "darkArgb"]) and .type == "color_pair" and
        (.lightArgb | valid_argb) and (.darkArgb | valid_argb)
      elif $parameter_type == "BOOLEAN" then
        type == "object" and no_unknown_keys(["type", "value"]) and .type == "boolean" and (.value | type == "boolean")
      elif $parameter_type == "OPTION" then
        type == "object" and no_unknown_keys(["type", "value"]) and .type == "option" and (.value | valid_member_id)
      elif $parameter_type == "FLOAT" then
        type == "object" and no_unknown_keys(["type", "value"]) and .type == "float" and (.value | type == "number")
      elif $parameter_type == "IMAGE_URI" then
        type == "object" and no_unknown_keys(["type", "uri"]) and .type == "image_uri" and
        (.uri | type == "string" and startswith("content://"))
      elif $parameter_type == "VIDEO_URI" then
        type == "object" and no_unknown_keys(["type", "uri"]) and .type == "video_uri" and
        (.uri | type == "string" and startswith("content://"))
      elif $parameter_type == "FONT_URI" then
        type == "object" and no_unknown_keys(["type", "uri"]) and .type == "font_uri" and
        (.uri | type == "string" and startswith("content://"))
      elif $parameter_type == "IMAGE_LAYOUT" then
        valid_image_layout_value
      elif $parameter_type == "INSETS" then
        type == "object" and no_unknown_keys(["type", "startDp", "topDp", "endDp", "bottomDp"]) and .type == "insets" and
        (.startDp | type == "number" and . >= 0 and . <= 96) and
        (.topDp | type == "number" and . >= 0 and . <= 96) and
        (.endDp | type == "number" and . >= 0 and . <= 96) and
        (.bottomDp | type == "number" and . >= 0 and . <= 96)
      elif $parameter_type == "CORNER_RADIUS" then
        type == "object" and no_unknown_keys(["type", "valueDp"]) and .type == "corner_radius" and
        (.valueDp | type == "number" and . >= 0 and . <= 96)
      else false end;
    def presentation_target_type($target):
      {
        "TYPOGRAPHY_USE_CUSTOM_FONT": "BOOLEAN",
        "TYPOGRAPHY_FAMILY": "OPTION",
        "TYPOGRAPHY_FONT_URI": "FONT_URI",
        "TYPOGRAPHY_SCALE": "FLOAT",
        "BACKGROUND_USE_IMAGE": "BOOLEAN",
        "BACKGROUND_MEDIA_TYPE": "OPTION",
        "BACKGROUND_IMAGE_URI": "IMAGE_URI",
        "BACKGROUND_VIDEO_URI": "VIDEO_URI",
        "BACKGROUND_OPACITY": "FLOAT",
        "BACKGROUND_BLUR_ENABLED": "BOOLEAN",
        "BACKGROUND_BLUR_RADIUS": "FLOAT",
        "BACKGROUND_VIDEO_MUTED": "BOOLEAN",
        "BACKGROUND_VIDEO_LOOP": "BOOLEAN",
        "CURSOR_USER_BUBBLE_FOLLOW_THEME": "BOOLEAN",
        "CURSOR_USER_BUBBLE_LIQUID_GLASS": "BOOLEAN",
        "CURSOR_USER_BUBBLE_WATER_GLASS": "BOOLEAN",
        "CURSOR_USER_BUBBLE_COLOR": "COLOR",
        "BUBBLE_SHOW_AVATAR": "BOOLEAN",
        "BUBBLE_WIDE_LAYOUT": "BOOLEAN",
        "BUBBLE_USER_LIQUID_GLASS": "BOOLEAN",
        "BUBBLE_USER_WATER_GLASS": "BOOLEAN",
        "BUBBLE_ASSISTANT_LIQUID_GLASS": "BOOLEAN",
        "BUBBLE_ASSISTANT_WATER_GLASS": "BOOLEAN",
        "BUBBLE_IMAGE_RENDER_MODE": "OPTION",
        "BUBBLE_USER_ROUNDED_CORNERS": "BOOLEAN",
        "BUBBLE_ASSISTANT_ROUNDED_CORNERS": "BOOLEAN",
        "BUBBLE_USER_COLOR": "COLOR",
        "BUBBLE_ASSISTANT_COLOR": "COLOR",
        "BUBBLE_USER_TEXT_COLOR": "COLOR",
        "BUBBLE_ASSISTANT_TEXT_COLOR": "COLOR",
        "BUBBLE_USER_USE_CUSTOM_FONT": "BOOLEAN",
        "BUBBLE_USER_FONT_FAMILY": "OPTION",
        "BUBBLE_USER_FONT_URI": "FONT_URI",
        "BUBBLE_ASSISTANT_USE_CUSTOM_FONT": "BOOLEAN",
        "BUBBLE_ASSISTANT_FONT_FAMILY": "OPTION",
        "BUBBLE_ASSISTANT_FONT_URI": "FONT_URI",
        "BUBBLE_USER_IMAGE_URI": "IMAGE_URI",
        "BUBBLE_ASSISTANT_IMAGE_URI": "IMAGE_URI",
        "BUBBLE_USER_IMAGE_LAYOUT": "IMAGE_LAYOUT",
        "BUBBLE_ASSISTANT_IMAGE_LAYOUT": "IMAGE_LAYOUT",
        "BUBBLE_USER_CONTENT_INSETS": "INSETS",
        "BUBBLE_ASSISTANT_CONTENT_INSETS": "INSETS",
        "AVATAR_SHAPE": "OPTION",
        "AVATAR_CORNER_RADIUS": "CORNER_RADIUS",
        "COMPOSER_TRANSPARENT": "BOOLEAN",
        "COMPOSER_FLOATING": "BOOLEAN",
        "COMPOSER_LIQUID_GLASS": "BOOLEAN",
        "COMPOSER_WATER_GLASS": "BOOLEAN",
        "CHROME_STATUS_BAR_HIDDEN": "BOOLEAN",
        "CHROME_STATUS_BAR_TRANSPARENT": "BOOLEAN",
        "CHROME_STATUS_BAR_COLOR": "COLOR",
        "CHROME_TOOLBAR_TRANSPARENT": "BOOLEAN",
        "CHROME_TOOLBAR_COLOR": "COLOR",
        "CHROME_NAVIGATION_WATER_GLASS": "BOOLEAN",
        "CHROME_NAVIGATION_BUTTON_LIQUID_GLASS": "BOOLEAN",
        "CHROME_NAVIGATION_BACKGROUND_COLOR": "COLOR",
        "CHROME_NAVIGATION_ACCENT_COLOR": "COLOR",
        "CHROME_CHAT_HEADER_TRANSPARENT": "BOOLEAN",
        "CHROME_CHAT_HEADER_OVERLAY_MODE": "OPTION",
        "CHROME_APP_BAR_CONTENT_COLOR_MODE": "OPTION",
        "CHROME_CHAT_HEADER_HISTORY_ICON_COLOR": "COLOR",
       "CHROME_CHAT_HEADER_PIP_ICON_COLOR": "COLOR"
       }[$target];
    def presentation_target_options($target):
      {
        "TYPOGRAPHY_FAMILY": ["default", "sans_serif", "serif", "monospace", "cursive"],
        "BACKGROUND_MEDIA_TYPE": ["none", "image", "video"],
        "BUBBLE_IMAGE_RENDER_MODE": ["tiled_nine_slice", "nine_patch"],
        "BUBBLE_USER_FONT_FAMILY": ["default", "sans_serif", "serif", "monospace", "cursive"],
        "BUBBLE_ASSISTANT_FONT_FAMILY": ["default", "sans_serif", "serif", "monospace", "cursive"],
        "AVATAR_SHAPE": ["circle", "square", "rounded"],
        "CHROME_CHAT_HEADER_OVERLAY_MODE": ["none", "overlay"],
        "CHROME_APP_BAR_CONTENT_COLOR_MODE": ["auto", "light", "dark"]
      }[$target];
    def valid_parameter_effect($parameter_type):
      type == "object" and
      (if .type == "accent_palette" then
         $parameter_type == "COLOR" and no_unknown_keys(["type"])
       elif .type == "token_color" then
         $parameter_type == "COLOR" and
         no_unknown_keys(["type", "tokenIds"]) and
         (.tokenIds | type == "array" and length > 0 and all(valid_token_id) and length == (unique | length))
       elif .type == "token_color_pair" then
         $parameter_type == "COLOR_PAIR" and
         no_unknown_keys(["type", "tokenIds"]) and
         (.tokenIds | type == "array" and length > 0 and all(valid_token_id) and length == (unique | length))
       elif .type == "stage_image" then
         $parameter_type == "IMAGE_URI" and
         no_unknown_keys(["type", "surfaceIds", "fit", "opacity"]) and
         (.surfaceIds | type == "array" and length > 0 and all(valid_scene_surface_id) and length == (unique | length)) and
         (if has("fit") then (.fit | type == "string" and IN("FILL", "FIT", "CROP")) else true end) and
         (if has("opacity") then (.opacity | type == "number" and . >= 0 and . <= 1) else true end)
       elif .type == "typography_scale" then
         $parameter_type == "FLOAT" and no_unknown_keys(["type"])
       elif .type == "shape_scale" then
         $parameter_type == "FLOAT" and no_unknown_keys(["type"])
       elif .type == "component_frame_scale" then
         $parameter_type == "FLOAT" and
         no_unknown_keys(["type", "componentIds"]) and
         (.componentIds | type == "array" and length > 0 and all(valid_supported_component_id) and length == (unique | length))
       elif .type == "component_content_insets" then
         $parameter_type == "INSETS" and
         no_unknown_keys(["type", "componentIds"]) and
         (.componentIds | type == "array" and length > 0 and all(valid_supported_component_id) and length == (unique | length))
       elif .type == "presentation" then
         no_unknown_keys(["type", "targets"]) and
         (.targets | type == "array" and length > 0 and length == (unique | length) and
           all(.[]; type == "string" and presentation_target_type(.) == $parameter_type))
       else false end);
    def valid_visible_when_condition:
      type == "object" and
      (if .type == "boolean_equals" then
         no_unknown_keys(["type", "parameterId", "expected"]) and
         (.parameterId | valid_member_id) and
         (.expected | type == "boolean")
       elif .type == "option_equals" then
         no_unknown_keys(["type", "parameterId", "expected"]) and
         (.parameterId | valid_member_id) and
         (.expected | valid_member_id)
       elif .type == "resource_present" then
         no_unknown_keys(["type", "parameterId"]) and
         (.parameterId | valid_member_id)
       else false end);
    def valid_parameter:
      type == "object" and
      no_unknown_keys(["id", "type", "defaultValue", "label", "description", "control", "effects", "visibility", "section", "order", "visibleWhen"]) and
      (.id | valid_member_id) and
      (.type | valid_parameter_type) and
      (.type as $parameter_type |
       (.label | valid_localized_text) and
       (.description == null or (.description | valid_localized_text)) and
       (.control | valid_parameter_control($parameter_type)) and
        (.effects | type == "array" and length > 0 and all(.[]; valid_parameter_effect($parameter_type))) and
        (if $parameter_type == "OPTION" then
           (.control.options | map(.id)) as $option_ids |
           ([.effects[] | select(.type == "presentation") | .targets[]] | unique) as $targets |
           ($targets | all(
             .[];
             . as $target |
             presentation_target_options($target) as $allowed |
             $allowed != null and
             ($option_ids | all(.[]; . as $option | ($allowed | index($option) != null)))
           ))
         else true end) and
       (if has("defaultValue") then (.defaultValue | valid_parameter_value($parameter_type)) else true end) and
       (if has("visibility") then (.visibility | valid_parameter_visibility) else true end) and
       (if has("section") then (.section == null or (.section | valid_parameter_section)) else true end) and
       (if has("order") then (.order | valid_integer) else true end) and
       (if has("visibleWhen") then (.visibleWhen | type == "array" and all(valid_visible_when_condition)) else true end) and
       (if $parameter_type == "IMAGE_URI" or $parameter_type == "VIDEO_URI" or $parameter_type == "FONT_URI" then
          ((has("defaultValue") | not) or .defaultValue == null)
        else true end) and
       (if .control.type == "color_palette" then
          (.defaultValue | type == "object" and .type == "color" and (.argb | valid_opaque_argb))
        else true end) and
       (if .control.type == "choice" then
          (.defaultValue | type == "object" and .type == "option" and (.value | valid_member_id)) and
          (.defaultValue.value as $default_option |
           (.control.options | any(.id == $default_option)))
        else true end) and
       (if .control.type == "slider" and has("defaultValue") and .defaultValue != null then
          (.defaultValue.value >= .control.minimum and .defaultValue.value <= .control.maximum)
        else true end) and
       (if (if has("visibility") then .visibility else "AUTHOR" end) == "USER" then
           (.section | valid_parameter_section) and
           .control.type != "author_value" and
           (.control.type == "color_palette" or
            .control.type == "toggle" or
            .control.type == "choice" or
            .control.type == "slider" or
            .control.type == "image_picker" or
            .control.type == "video_picker" or
            .control.type == "font_picker") and
           (if $parameter_type == "IMAGE_URI" or $parameter_type == "VIDEO_URI" or $parameter_type == "FONT_URI" then
             true
           else
             has("defaultValue") and .defaultValue != null
           end)
        else
          (.section == null) and .control.type == "author_value"
        end));
    def valid_parameter_conditions:
      . as $parameters |
      all(
        .[];
        . as $parameter |
        ($parameter | if has("visibleWhen") then .visibleWhen else [] end) as $conditions |
        ($conditions | all(
          .[];
          . as $condition |
          ($parameters | map(select(.id == $condition.parameterId)) | .[0]) as $dependency |
          if $condition.type == "boolean_equals" then
            $dependency != null and $dependency.type == "BOOLEAN"
          elif $condition.type == "option_equals" then
            $dependency != null and
            $dependency.type == "OPTION" and
            $dependency.control.type == "choice" and
            ($dependency.control.options | any(.id == $condition.expected))
          elif $condition.type == "resource_present" then
            $dependency != null and
            ($dependency.type == "IMAGE_URI" or $dependency.type == "VIDEO_URI" or $dependency.type == "FONT_URI")
          else
            false
          end
        ))
      );
    type == "object" and
    no_unknown_keys(["schemaVersion", "packageId", "version", "displayName", "author", "description", "attribution", "basis", "variants", "parameters", "assets", "tokens", "scenes", "surfaces", "presentation"]) and
    .schemaVersion == 4 and
    (.packageId | test("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")) and
    (.version | valid_semver) and
    (.displayName | valid_localized_text) and
    (.author == null or (.author | valid_localized_text)) and
    (.description == null or (.description | valid_localized_text)) and
    (.basis | valid_basis) and
    (.presentation | type == "object" and
      no_unknown_keys(["material", "componentSkins", "behavior"]) and
      has("behavior") and
      (.behavior | valid_presentation_behavior)) and
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
       all(valid_parameter) and
       valid_parameter_conditions) and
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

# Cyber Grid is a child package. Its parameters must stay within declarations owned here.
jq -e \
  --arg package_id "operit.cyber_grid" \
  --arg basis_package_id "operit.default" \
  --arg basis_version "3.0.0" \
  --arg basis_archive_sha256 "5a96abf521ec22a8c486ccb5b4d7f561a4bed4f6f90dfe742647024eb79db91f" \
  '
    def contains_all($values; $required):
      $required | all(.[]; . as $required_value | ($values | index($required_value) != null));
    . as $manifest |
    (.tokens.tokens | keys) as $owned_tokens |
    (.presentation.componentSkins | keys) as $owned_components |
    [(.surfaces // [])[] | select(.kind == "SCENE") | .surfaceId] as $owned_scene_surfaces |
    (.scenes | map(.sceneId)) as $owned_scenes |
    (.parameters | map(.id)) as $parameter_ids |
    .packageId == $package_id and
    .basis == {
      "packageId": $basis_package_id,
      "version": $basis_version,
      "archiveSha256": $basis_archive_sha256
    } and
    contains_all(
      $parameter_ids;
      [
        "cyber_cyan_color", "cyber_magenta_color", "cyber_background_image",
        "cyber_background_opacity", "cyber_typography_scale",
        "cyber_shape_scale", "cyber_show_avatars", "cyber_wide_bubbles", "cyber_avatar_shape",
        "cyber_composer_transparent", "cyber_composer_frame_scale", "cyber_app_chrome_frame_scale",
        "cyber_bubble_user_content_insets", "cyber_chrome_status_bar_transparent"
      ]
    ) and
    ($parameter_ids | all(.[]; startswith("cyber_"))) and
    ([.parameters[] | select(.id == "cyber_cyan_color") | .effects[]] ==
      [{"type": "token_color", "tokenIds": ["cyber.cyan"]}]) and
    ([.parameters[] | select(.id == "cyber_magenta_color") | .effects[]] ==
      [{"type": "token_color", "tokenIds": ["cyber.magenta"]}]) and
    ([.parameters[] | select(.id == "cyber_background_image") | .effects[]] ==
      [{"type": "stage_image", "surfaceIds": ["app.shell", "chat.main"], "fit": "CROP", "opacity": 0.22}]) and
    ([.parameters[] | select(.id == "cyber_bubble_user_content_insets") | .effects[]] ==
      [{"type": "component_content_insets", "componentIds": ["message_user"]}]) and
    ([.parameters[] | select(.id == "cyber_chrome_status_bar_transparent") | .effects[]] ==
      [{"type": "presentation", "targets": ["CHROME_STATUS_BAR_TRANSPARENT"]}]) and
    (.parameters | all(
      .[];
      .effects | all(
        .[];
        if .type == "token_color" or .type == "token_color_pair" then
          (.tokenIds | all(.[]; . as $target | ($owned_tokens | index($target) != null)))
        elif .type == "stage_image" then
          (.surfaceIds | all(.[]; . as $target |
            ($owned_scene_surfaces | index($target) != null) and
            ($owned_scenes | index($target) != null)))
        elif .type == "typography_scale" or .type == "shape_scale" then
          $manifest.presentation.material != null
        elif .type == "component_frame_scale" or .type == "component_content_insets" then
          (.componentIds | all(.[]; . as $target | ($owned_components | index($target) != null)))
        elif .type == "presentation" then
          $manifest.presentation.behavior != null
        else
          false
        end
      )
    ))
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
