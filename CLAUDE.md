# Pointer Colors

## Feature screenshots (always)

Every feature of the Mac app has a marketing screenshot in `docs/features/<id>.png`, listed in
`docs/features/features.json`. Release notes on the GitHub releases page show them; `CHANGELOG.md`
does not.

- **New feature:** mark its view with `.featureSpot("<id>")` (in `mac/Sources/PointerColors/Views/`)
  and add an entry to `docs/features/features.json`: `id`, `screen` (`menu` or
  `preferences-<tab>`), `spot`, `since` (the version it ships in), a short `title` and one-line
  `caption` in the voice of the release notes, and the `sources` files that draw it. If its screen
  needs demo data to look right, add it to `mac/scripts/feature-demo-settings.json`.
- **Changed feature:** a change to any file in a feature's `sources` (or to how it looks) means
  its screenshot is retaken at the next release, overwriting `docs/features/<id>.png`. Update its
  title, caption and `sources` if they no longer fit. A removed feature loses its entry and its PNG.
- **When releasing** (not before): run `mac/scripts/feature-screenshots.sh` to retake every
  screenshot (or `… <id> …` for some), look at each new or changed PNG, and commit them with the
  version bump. The script renders offscreen with demo settings in the bare build's own defaults
  domain, so it never touches the installed app's settings or the real pointer.
- **Release notes:** under each new or changed feature's bullet, embed its screenshot pinned to the
  release tag, so later retakes don't change old releases:
  `![<title>](https://raw.githubusercontent.com/mustafaabobakr/macos-pointer-colors/v<version>/docs/features/<id>.png)`

## Releasing

Releases are signed with the "Pointer Colors Dev" certificate; see the README's build section and
`mac/scripts/signing.sh`. Quit any copy running from `mac/build/` before building (the build script
does this) and test updates from the copy in `/Applications`.
