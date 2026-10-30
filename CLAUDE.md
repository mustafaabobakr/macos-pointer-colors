# Pointer Colors

## Feature clips (always)

Every feature of the Mac app has a short marketing clip, an animated WebP in
`docs/features/<id>.webp`, listed in `docs/features/features.json`. Each one shows a Mac desktop
(macOS Sonoma's picture, read from this Mac when recording, never stored in the repo) with the
menu or a Preferences window, the feature's title, caption and `use` line over it, then zooms in
while a scripted pointer in the pair's colors uses the feature. Release notes on the GitHub
releases page show them; `CHANGELOG.md` does not.

- **New feature:** mark its view with `.featureSpot("<id>")` (in `mac/Sources/PointerColors/Views/`),
  write its demo in `mac/Sources/PointerColors/FeatureClipScripts.swift` (mark any control the
  pointer goes to with `.featureSpot("clip-…")`), and add an entry to
  `docs/features/features.json`: `id`, `screen` (`menu`, `preferences-<tab>` or `update`), `spot`,
  `since` (the version it ships in), a short `title`, a one-line `caption` saying what it does
  and a `use` line saying when to use it, in the voice of the release notes, and the `sources`
  files that draw it. If its screen needs demo data to look right, add it to
  `mac/scripts/feature-demo-settings.json`.
- **Changed feature:** a change to any file in a feature's `sources` (or to how it looks or
  behaves) means its clip is recorded again at the next release, overwriting
  `docs/features/<id>.webp`, and its demo script updated if it no longer shows the feature. Update
  its title, caption, `use` and `sources` if they no longer fit. A removed feature loses its entry,
  its script and its clip, and its clip comes out of every release that shows it (otherwise those
  images break).
- **When releasing** (not before): ask first whether to record clips at all, and which ones; a
  fix-only release usually has none. Only on a yes, run `mac/scripts/feature-clips.sh` (or
  `… <id> …` for some), watch each new or changed one, and commit them with the version bump. The
  app records offscreen with demo settings in the bare build's own defaults domain, so it never
  touches the installed app's settings, the real pointer or the mouse.
- **Release notes:** under each new or changed feature's bullet, embed its clip straight from
  `docs/features` on `main`, never an uploaded copy, so every release always shows the current
  clip. A blank line before it, indented under the bullet:
  `  ![<title>](https://raw.githubusercontent.com/mustafaabobakr/macos-pointer-colors/main/docs/features/<id>.webp)`
  Every published release already does this for the features it introduced or changed. The app
  drops these lines when it shows release notes (`UpdateChecker.whatsNew`).

## Releasing

When asked to release, first ask which version, with these choices and one marked recommended
from the changes since the last release: a patch (`0.4.x`, fixes only), a minor (`0.5.0`, new
features) or a major (`1.0.0`). Also ask before recording any clips or screenshots (above). Then:
bump the version and `CHANGELOG.md` on `feat/macos-app`, merge it into `main`, push, build and
sign the DMG, and publish the GitHub release from `main`.

Releases are signed with the "Pointer Colors Dev" certificate; see the README's build section and
`mac/scripts/signing.sh`. Quit any copy running from `mac/build/` before building (the build script
does this) and test updates from the copy in `/Applications`.
