# Changelog

What changed in each release of the Pointer Colors Mac app. Downloads are on the
[releases page](https://github.com/mustafaabobakr/macos-pointer-colors/releases).

## 0.3.3 — 2026-10-25

- **Pointer highlight for demos and recordings.** A pulse on each click, a laser pointer that draws a fading trail as you drag, and a ring around the pointer. Turn the pulse and laser on from the menu's new Highlight section; both can be on at once. A new Highlight tab in Preferences has the ring switch, preview pictures, a pad to try it out, and settings for size, length, trail and colors. The highlight takes the pointer pair's colors unless you pick your own.
- **Update checks on a schedule.** Choose how often in Preferences: never, every day, every week or every month (every day by default). Opening the menu shows the last result without asking GitHub unless a check is due; **Check for Updates…** still checks right away.
- **What's new before you update.** When a new version is available, the menu and Preferences show what changed in it.
- **Runs on Intel Macs too.** The app is now one download for Apple silicon and Intel.
- **Resizable Preferences.** Drag the Preferences window taller or shorter; tabs that don't fit scroll.

## 0.3.2 — 2026-10-24

- **One clickable update item.** The status sits inside the item at the bottom of the menu, so clicking anywhere on it checks, installs or opens the download.
- **The version is always visible** in the update item, and "You're up to date" includes it.
- **No more squeezed footer at large text sizes.** The menu now opens tall enough for all its rows.

## 0.3.1 — 2026-10-24

- **Opening the menu checks for updates**, reusing a check from the last five minutes.
- **"You're up to date" goes away when the menu closes.** An available update stays until you install it.

## 0.3.0 — 2026-10-24

- **Install updates from inside the app.** **Install Update and Relaunch** downloads the new version, swaps it in and reopens, without the macOS security prompt for each new version. Only a version signed with the same certificate is installed.
- **The download opens again.** The 0.2.0 disk image could be refused with "Pointer-Colors.dmg Not Opened"; it's no longer signed, so it opens normally.
- **Clear message when an update can't install**, such as when the app runs from the disk image or hasn't been moved to Applications.

## 0.2.0 — 2026-10-24

- **Display switches apply as the pointer crosses**, instead of up to 0.4 s later.
- **Size and colors change together** when the pointer moves to another display.
- **App pairs can follow the pointer:** an app's pair applies while the pointer is over its windows. The old behavior is in **Preferences › Automation › Apps › Applies when › The app is in front**.

## 0.1.0 — 2026-10-23

First release: a menu-bar app that applies pointer outline and fill colors in one click.

- Every pair from [macos-pointer-colors.pages.dev](https://macos-pointer-colors.pages.dev), plus your own
- Pointer size slider, a separate color and size for each display, and a pair for each app
- Switches pairs with light and dark appearance
- Keyboard shortcuts, contrast warnings, English and Arabic
