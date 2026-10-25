# Feature screenshots

One marketing picture per feature of the Mac app, used in the release notes on the
[releases page](https://github.com/mustafaabobakr/macos-pointer-colors/releases).
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
