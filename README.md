# Operit Cyber Grid Theme

`operit.cyber_grid` is a declarative cyberpunk chat theme for Operit. It is distributed only as a GitHub Release `.otheme` artifact and is never bundled into the application.

## Install

1. Download `operit-cyber-grid-<version>.otheme` from the [Releases](https://github.com/luojiaping/operit-theme-cyber-grid/releases) page.
2. Open Operit settings, choose Themes, and import the archive.
3. Select Cyber Grid from the installed theme list.

The application validates the archive, manifest, scene contract, image types and declared SHA-256 values before installation.

## Assets and Attribution

The background is derived from the Hubble Ring Nebula image. The full credit and source URL are in [ATTRIBUTION.md](ATTRIBUTION.md) and the package manifest. The three frame PNGs are project-generated assets.

## Release

1. Update `operit-theme.json` and increment `version`.
2. Run `./scripts/package.sh`.
3. Verify `dist/operit-cyber-grid-<version>.otheme` and its checksum.
4. Commit, tag the matching `v<version>`, and push the tag.

The tag workflow packages the archive again and publishes the `.otheme` and `.sha256` as Release assets.

## License

The package source is licensed under LGPL-3.0-or-later. See [LICENSE](LICENSE).
