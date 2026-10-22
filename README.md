<p align="center"><img src="favicon.svg" width="72" alt="Pointer colors icon"></p>

<h1 align="center">Pointer colors for macOS</h1>

A small gallery of pointer outline and fill color pairs for macOS, with a live preview. Pick a pair, move your mouse over the fake desktop to try it, then copy the two hex codes into System Settings.

![Screenshot of the pointer color gallery](docs/screenshot.png)

## Features

- 12 hand-picked outline/fill pairs, plus color pickers to mix your own
- Live pointer preview on a macOS-style desktop with Colorful, Light, Dark and Busy wallpapers
- Pointer size slider
- Visibility tiles: light page, dark app, photo and spreadsheet
- One-click copy of each hex code (without the `#`, ready for the macOS Hex field)

## Apply a pair on your Mac

1. Open **System Settings › Accessibility › Display** and scroll to **Pointer**.
2. Click **Pointer outline color**, choose the sliders tab, set it to **Hex Color**, and paste the outline code.
3. Do the same for **Pointer fill color**.
4. Use **Reset** to go back to black and white.

## Run locally

It's a single static file with no build step:

```sh
open index.html
```

## Deploy

Hosted on Cloudflare Pages straight from this repo: no framework preset, no build command, build output directory `/`.
