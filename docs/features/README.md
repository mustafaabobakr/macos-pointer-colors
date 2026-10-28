# Feature clips

One short marketing clip per feature of the Mac app, an animated WebP that loops. The release
notes on the [releases page](https://github.com/mustafaabobakr/macos-pointer-colors/releases) link
to these files on `main` directly, so a clip recorded again shows up in every release that has it.
[`features.json`](features.json) lists each feature: the screen and view it's on, its title, what
it does (`caption`) and when to use it (`use`), and the source files whose changes mean it must be
recorded again.

Record them all when releasing:

```sh
mac/scripts/feature-clips.sh
```

For each feature the app plays its demo from
[`FeatureClipScripts.swift`](../../mac/Sources/PointerColors/FeatureClipScripts.swift) offscreen,
with the demo settings in
[`mac/scripts/feature-demo-settings.json`](../../mac/scripts/feature-demo-settings.json), and
[`docs/art/make_feature_clips.py`](../art/make_feature_clips.py) puts it on a Mac desktop: the
whole desktop with the feature's text, a zoom into the feature while the pointer uses it, and a
zoom back out. The desktop picture is macOS Sonoma's, read from the Mac recording, never stored
here. Needs `rsvg-convert` and `img2webp` (`brew install librsvg webp`). The rules for agents are
in [`CLAUDE.md`](../../CLAUDE.md).
