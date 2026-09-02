# Operit Cyber Grid Theme

`operit.cyber_grid` is a schema-4 declarative cyberpunk theme for Operit. It is distributed only as a GitHub Release `.otheme` artifact and is never bundled into the application.

## Install

1. Use the exact default basis `operit.default@3.0.0`: `operit-default-3.0.0.otheme` with SHA-256 `5a96abf521ec22a8c486ccb5b4d7f561a4bed4f6f90dfe742647024eb79db91f`.
2. Download the matching Cyber Grid archive from the [Releases](https://github.com/luojiaping/operit-theme-cyber-grid/releases) page.
3. Open Operit settings, choose Themes, import the archive, and select Cyber Grid.

The application validates the archive, manifest, surface coverage, scene contracts, image types and declared SHA-256 values before installation.

## Package

- Schema: 4 with an explicit basis on `operit.default@3.0.0`; the required basis archive is `operit-default-3.0.0.otheme` with SHA-256 `5a96abf521ec22a8c486ccb5b4d7f561a4bed4f6f90dfe742647024eb79db91f`.
- `app.shell` and `chat.main` are full scenes: Hubble nebula backdrop, a neon top bar, and measured host slots without fixed percentage positioning.
- The page-level outer shell remains a nine-slice asset. Component skins declare their own `round_rect`, `cut_corners`, `hud_notched`, `corner_brackets`, or `segmented_rail` frame geometry.
- Chat uses HUD notches for the composer, segmented rails for the role bar, open brackets for AI messages, and cut corners for user messages.
- The status skin declares normal and error states so operation results retain their semantic color and cut-corner frame.
- Surface overrides follow the same host contract as the default package: `app.shell` and `chat.main` keep their matching scene IDs, while inherited template and host-shell surfaces remain host-owned.
- User-visible parameters use unique `cyber_` IDs: cyan and magenta neon colors; custom background image and opacity; typography scale; avatar visibility, bubble width, and avatar shape.
- Cyan and magenta controls use `token_color` only for the Cyber-owned `cyber.cyan` and `cyber.magenta` tokens. Background images stage only on Cyber-owned `app.shell` and `chat.main` scenes, and frame or inset effects target Cyber-owned component skins.
- `presentation.behavior` declares the complete static baseline for background, typography, conversation, composer, and chrome. Shape, composer, chrome, frame and inset values remain AUTHOR-only package parameters and do not appear in app settings.

## Assets and Attribution

The background is derived from the Hubble Ring Nebula image. The full credit and source URL are in [ATTRIBUTION.md](ATTRIBUTION.md) and the package manifest. The outer shell PNG is a project-generated asset.

## Release

1. Update `operit-theme.json` and increment `version`; retain the exact `operit.default@3.0.0` basis coordinate and its required archive SHA-256 until the Cyber Grid dependency is intentionally updated.
2. Run `./scripts/package.sh`.
3. Verify `dist/operit-cyber-grid-<version>.otheme` and its checksum.
   Run `cd dist && sha256sum -c operit-cyber-grid-<version>.otheme.sha256` to validate a release download.
4. Commit, tag the matching `v<version>`, and push the tag.

## License

The package source is licensed under LGPL-3.0-or-later. See [LICENSE](LICENSE).
