# Changelog

What changed in each release of the Pointer Colors Mac app. Downloads are on the
[releases page](https://github.com/mustafaabobakr/macos-pointer-colors/releases).

## 0.4.6 — 2026-10-29

- **Clicks you can feel.** Turn on **Preferences › Highlight › Press › Shrink the pointer on click** and the pointer gets smaller while the button is down, then grows back when you let go. Choose the **Pressed size**, how fast it shrinks and grows back, the **Animation** (**Ease out**, **Bounce** or **Linear**), and whether right-clicks count. It's off unless you turn it on, and it needs a pointer bigger than the smallest size. **Export all…** saves these settings too.
- **Pulses grow out of the click.** Every pulse now starts as a dot right under the pointer and spreads from there, so it reads as coming from the click.

## 0.4.5 — 2026-10-28

- **A laser that stands out on light backgrounds.** The thin edge around the laser dot and along its trail now takes the pair's dark color, like the black outline of Highlighter. Choose it in **Preferences › Highlight › Laser › Outline**: **Pair's dark color**, **Laser color** (the look before), or **None**.
- **Lighter display switches.** Moving to a display with its own pair and size, the app no longer watches the pointer every millisecond to switch both at once. The size changes right away and the new colors follow a moment later, when macOS redraws them.

## 0.4.4 — 2026-10-26

- **Choose the keys that draw the laser.** **Preferences › Highlight › Laser › Keys to hold** sets which keys **Draw only while holding** waits for: ⌘, ⌥, ⌃ or ⇧, alone or together. Click it, press the keys, and let go. It stays ⌥ Option unless you change it.
- **Launch at login is backed up.** **Export all…** now saves **Launch at login** with the rest of your settings, and **Import…** puts it back.

## 0.4.3 — 2026-10-26

- **The laser and the ring keep up across displays.** Moving to another display, the laser dot and the ring around the pointer no longer lag behind. A laser trail that crosses to a display with another pair carries on in that pair's colors.
- **Choose when the laser dot shows.** **Preferences › Highlight › Laser › Dot** has **Always** (as before), **While drawing**, which shows the dot only at the tip of a trail, and **Hide**.
- **Highlight pictures in the menu.** The menu's Highlight section shows the pulse and laser pictures from Preferences; click one to turn it on or off.
- **App pairs on fast moves.** A quick move to another display no longer brings the last display's app pair along when pairs follow the app under the pointer.

## 0.4.2 — 2026-10-25

- **A proper update window.** When a new version is out, a window shows what changed, with **Skip This Version**, **Install on Quit** and **Install and Relaunch**. A skipped version isn't offered again unless you choose **Check for Updates…**.
- **Automatic updates.** Turn on **Automatically download and install updates in the future** in the update window, or **Install updates automatically** in **Preferences › About**. New versions then download by themselves and install when you quit.

## 0.4.1 — 2026-10-25

- **Back up and move all your settings.** **Preferences › General › Backup** has **Export all…**, which saves every setting to one file: custom pairs, automation, highlight, shortcuts and appearance. **Import…** puts them back on this Mac or another one, then relaunches the app.

## 0.4.0 — 2026-10-25

- **Smooth pulses.** Clicking no longer stutters, including right after the pointer moves to another display. Pulses are now animated by macOS itself, and switching displays no longer makes macOS redraw the pointer twice. When displays use different pointer sizes, macOS still pauses briefly to resize the pointer as it crosses.
- **Ripple pulse.** Choose the pulse style in **Preferences › Highlight › Pulse**: **Ring**, a single ring as before, or **Ripple**, three waves spreading out one after another.
- **Long presses.** Turn on **Show long presses** to keep a small filled ring under the pointer while you hold the button, with a pulse when you let go, so a press looks different from a click. Off by default.
- **Highlight colors that show up.** Pairs with a black outline, like Highlighter and Gold, no longer pulse in black: the highlight uses the more colorful of the pair's two colors. **Colors for each pair** in Preferences sets a pulse and a laser color for any pair.
- **Draw with the laser without selecting text.** Turn on **Draw only while holding ⌥ Option**: a ⌥-drag draws the laser and the app underneath gets no click, so no text is selected.
- **One pair menu everywhere.** Every place you pick a pair now uses the same list with pointer previews, including the light and dark appearance pairs.

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
