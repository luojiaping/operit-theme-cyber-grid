# Operit Cyber Grid Theme

`operit.cyber_grid` is a V2 declarative cyberpunk theme for Operit. It is distributed only as a GitHub Release `.otheme` artifact and is never bundled into the application.

## Install

1. Download `operit-cyber-grid-<version>.otheme` from the [Releases](https://github.com/luojiaping/operit-theme-cyber-grid/releases) page.
2. Make sure the matching `operit.default` release version is installed (the app bundles it).
3. Open Operit settings, choose Themes, import the archive, and select Cyber Grid.

The application validates the archive, manifest, surface coverage, scene contracts, image types and declared SHA-256 values before installation.

## Package

- Schema: V2 with an explicit basis on `operit.default` at the exact release coordinate; everything not overridden here is inherited from the base theme.
- `app.shell` and `chat.main` are full scenes: Hubble nebula backdrop, a neon top bar, and measured host slots without fixed percentage positioning.
- The page-level outer shell remains a nine-slice asset. Component skins declare their own `round_rect`, `cut_corners`, `hud_notched`, `corner_brackets`, or `segmented_rail` frame geometry.
- Chat uses HUD notches for the composer, segmented rails for the role bar, open brackets for AI messages, and cut corners for user messages.
- Surface overrides follow the same host contract as the default package: `app.shell` and `chat.main` keep their matching scene IDs, while inherited template and host-shell surfaces remain host-owned.

## Assets and Attribution

The background is derived from the Hubble Ring Nebula image. The full credit and source URL are in [ATTRIBUTION.md](ATTRIBUTION.md) and the package manifest. The outer shell PNG is a project-generated asset.

## Release

1. Update `operit-theme.json` and increment `version`; keep the basis coordinate pointing at the exact `operit.default` release you tested against.
2. Run `./scripts/package.sh`.
3. Verify `dist/operit-cyber-grid-<version>.otheme` and its checksum.
4. Commit, tag the matching `v<version>`, and push the tag.

## License

The package source is licensed under LGPL-3.0-or-later. See [LICENSE](LICENSE).
