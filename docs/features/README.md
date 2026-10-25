# Feature screenshots

One marketing picture per feature of the Mac app. The release notes on the
[releases page](https://github.com/mustafaabobakr/macos-pointer-colors/releases) link to these
files on `main` directly, so a retaken picture shows up in every release that has it.
[`features.json`](features.json) lists each feature, the screen and view it's taken from, and the
source files whose changes mean it must be retaken.

Retake them all when releasing:

```sh
mac/scripts/feature-screenshots.sh
```

The app draws the menu and each Preferences tab offscreen with the demo settings in
[`mac/scripts/feature-demo-settings.json`](../../mac/scripts/feature-demo-settings.json), and
[`docs/art/make_feature_shots.py`](../art/make_feature_shots.py) zooms into each feature's
`.featureSpot` and frames it. The rules for agents are in [`CLAUDE.md`](../../CLAUDE.md).
