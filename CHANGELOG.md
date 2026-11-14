# Changelog

What changed in each release of the Pointer Colors Mac app. Downloads are on the
[releases page](https://github.com/mustafaabobakr/macos-pointer-colors/releases).

## 0.8.0 — Unreleased

- **Smart zoom in every app (beta).** Double-tap the Magic Mouse with one finger to zoom in on what's under the pointer, in any app and on any display, the way macOS Smart Zoom does in Safari. Double-tap again, or press Esc, to zoom back out. Turn it on in the new **Preferences › Mouse › Zoom** page.
  - **Whole screen or lens.** **Whole screen** zooms the display and, with **Stay where you zoomed**, holds the view still like macOS Smart Zoom, keeping the pointer 10 pt inside the display's edges; or choose **Follow the pointer**. **Lens** magnifies an area that follows the pointer, as a **Rectangle**, **Square** or **Circle** up to 2000 pt wide, outlined in **White**, the **Pointer pair**'s color or a **Custom** color.
  - **Zoom amount** from 1.5× to 5×, and an **Animation length** from 0 to 600 ms.
  - **Show zoom when sharing your screen**, so people in a Slack huddle, Google Meet or other call see what you zoomed into when you share your whole screen.
  - **macOS Smart Zoom where it's better.** In Safari, Google Chrome, Brave Browser, Preview and Photos a double tap still zooms the page, document or image the way macOS does, and Pointer Colors stays out of the way. **Add App…** and **Remove** change the list.
  - **Detected like macOS does it.** By default a zoom starts only when macOS itself recognizes the double tap, the same recognizer Safari and Chrome use. **Advanced › Detect double taps with** also offers **Pointer Colors only**, which reads your fingers itself, and **Both**, which needs the two to agree. This needs Smart zoom on in **System Settings › Mouse**, and the page tells you when it's off.
  - **Tap limits** for Pointer Colors' own detection, in **Advanced**: **Double-tap within**, **Shortest tap**, **Longest tap**, **Pointer movement during a tap**, **Lightest tap** and **Wait after a flicker**, each set from logged real taps and stray touches, with **Reset**.
  - **Enlarge the picture your way**, in **Advanced**: **Smooth** (the default) blends pixels as before, while **Sharp** and **Sharper** keep text and thin lines crisper. Each is a card with a sample drawn at your zoom amount, and its upsides and downsides.
  - Zoom needs **Screen Recording**, to draw the zoomed picture, and **Accessibility**, to hear macOS's double tap and keep the pointer inside a still zoom. **General › Permissions** lists both under **Magic Mouse smart zoom**.
- **A screenshot of each laser drawing.** **Preferences › Laser › Screenshots** captures the area around a finished trail, with a **Margin around the trail** of 0–400 pt, with or without the laser in it. Each shot can be **copied to the clipboard**, **saved to a folder** (the Desktop by default) and **opened** in the default app, Shottr or CleanShot X, each shown with its icon. Shots only opened, not saved, are kept in the app's Screenshots folder, with **Show in Finder** and **Delete All…**.
- **Laser and zoom together.** **Hold still for the laser** stops a lens or a following zoom from moving while you hold the laser's keys or draw, so the drawing stays on what it marks. While zoomed, **Capture the whole zoom while zoomed** takes everything the zoom shows, **Only while zoomed** takes screenshots only with a zoom up, and **Zoom out after the screenshot** ends a whole-screen zoom, a lens, or both.
- **Every permission in one place.** **Preferences › General › Permissions** shows Full Disk Access, Accessibility, Screen Recording and Notifications, each under the feature that needs it and saying why, with an **Allowed** or **Allow…** status.
- **Easier settings.** A choice of up to four options is now a row of side-by-side buttons; more options stay a menu. Sliders have buttons to nudge them one step and icons at their ends.

**Export all…** saves every new setting, and **Import…** puts them back.

## 0.7.0 — 2026-11-11

- **Battery, your levels.** **Preferences › Battery** shows the level next to the menu-bar icon, on the Dock icon or under the pointer **Always** or **When low**, with one **When low means below** slider (5–50%). The pointer label goes **below or above, right or left**, with a real-size picture of it, and turns red below your alert level.
- **Low-battery notifications your way.** **Notify me** below any level from 5% to 50%, with or without **Sound**, and **Remind me again** every 1–10% lower until the mouse charges.
- **Battery health settings.** **Wear tip after**, **Use counted over** and **Estimate chart** sliders set when the wear tip shows, how many days of use the averages take, and how far back the chart goes.
- **Pointer locator.** **Animation length**, **Start size**, **End size**, **Line width** and **Time between presses**, under **Show pointer location** in **Preferences › Automation**, with a real-size picture of the ring.
- **Hover focus.** **Focus after** sets how long the pointer rests before a window takes focus, and **Pause while holding** picks which of ⌃ ⌥ ⇧ ⌘ pass over windows.
- **Buttons.** Record which mouse buttons go **back and forward**, give the Magic Mouse's **sideways swipe** its own switch and a **Swipe distance**, and have the double-click fix cover **Left only** or **Left and right**.
- **Size step and apply sound.** **Preferences › Shortcuts** has a **Size change per press** slider, and **General** lets you pick the **Sound** played when a pair is applied.

Your old battery choices carry over. **Export all…** saves every new setting, and **Import…** puts them back.

## 0.6.0 — 2026-11-10

- **Highlight, a page for each.** **Preferences › Highlight** is now four pages, **Ring**, **Pulse**, **Laser** and **Press**, each with a picture at the top drawn by the same code as the real effect. The Ring, Pulse and Laser pictures show it at its real size, at your pointer size. Hover a setting's choices to see a picture of each.
- **Shape every highlight.** About 25 new settings, each starting at what the effect drew before:
  - **Ring:** a **Color** of its own (the pair's or one you pick), **Fill**, **Line width** and **Line opacity**. **Ring size** now goes down to 0.1×.
  - **Pulse:** for the Ring style, **Line width**, **Grows to** and **Starting opacity**; for Ripple, **Waves**, **Grows to**, **Gap between waves**, **Line width** and **Starting opacity**. **Long presses** has its own section: how long a press must last, and the held ring's size, fill, line width and breathing.
  - **Laser:** **Dot fades after**; for Classic, **Trail opacity**, **Glow** and **Middle lightness**; for GoodNotes, **Fade-out** and **Edge width**.
- **Sliders that say what they do.** Time sliders run from a tortoise (longer) to a hare (shorter); the others show small and large, thin and thick, or faint and solid at their ends.
- **Only the settings that apply.** Rows that depend on another setting are hidden until it's on, on every Preferences page, and open with a smooth motion that pushes the rest down.
- **Block clicks while drawing is on by default** and now sits above **Draw only while holding**, so a held-key laser drag draws without selecting anything underneath. If you turned it off, it stays off.
- **Highlight colors follow the pair on each display.** The **Pair colors** page is gone: with **Color** set to **Pointer pair**, the ring, pulse and laser use the pair shown on each display. Colors set for single pairs before are no longer used.

**Export all…** saves every new setting, and **Import…** puts them back.

## 0.5.4 — 2026-11-10

- **Block clicks while drawing, now a choice.** **Preferences › Highlight › Laser** has a new **Block clicks while drawing** switch under **Keys to hold**. With **Draw only while holding** on, a held-key drag now draws the laser *and* reaches the app underneath, so you can point at something while you select or drag it. Turn **Block clicks while drawing** on to get the old behavior back, where the drag only draws and nothing underneath is clicked or selected. It's off by default, so after updating, a ⌥-drag selects text again until you turn it on.
- **A steadier drain report.** **Preferences › Battery › Battery health › Drain report** is now worked out once a day, from the last 7 whole days, so it no longer jumps with every 1% drop. A new chart shows how the estimate moved each day, or any of the three numbers behind it, with all four on hover. Long durations read in days and months, like 1d 21h 12m.
- **Preferences in a new order.** The Pointer pages now read General, Pairs, Highlight, Automation, Appearance.

**Export all…** saves the new switch, and **Import…** puts it back.

## 0.5.3 — 2026-11-06

- **An outline for the GoodNotes laser.** **Preferences › Highlight › Laser › Outline** now works with the GoodNotes look too, so the laser shows on light backgrounds: a thin edge in the pair's dark color (or the laser color) around the glowing line and the dot. It keeps its width on a fast, thin stroke, and the glow spreads beyond it without tinting it. Choose **None** for the plain GoodNotes look. As **Outline** defaults to the pair's dark color, the GoodNotes look now has the edge unless you turn it off.
- **Outline opacity.** A new **Outline opacity** slider under **Outline** sets how solid the edge is, in both looks, from 5% to 100% in 5% steps.

**Export all…** saves the outline opacity, and **Import…** puts it back.

## 0.5.2 — 2026-11-06

- **A GoodNotes laser.** **Preferences › Highlight › Laser › Look** now offers **GoodNotes** next to **Classic**: a glowing line around a white core and a solid dot, with no outline. The line is thick while you move slowly and thins on a fast stroke, tapering smoothly between the two, and the trail stays whole for a moment before it fades. Its widths, glow and timing were measured from the GoodNotes laser itself.
- **A laser drag no app can take.** With **Draw only while holding** on and Accessibility allowed, the drag now goes through the app's event tap, so even a game that reads the mouse on its own doesn't see it or select anything.
- **Where your battery goes.** **Preferences › Battery › Battery health** has a new **Drain report** for each mouse: how fast it drains in use and while idle, how long a full charge lasts the way you use it, your hours in use and idle, and each day of the charge as a bar of the two. Tips suggest switching the mouse off when you're away once idle drain passes a share you choose in **Suggest switching it off**, and warn when charges get shorter. The history now records whether the mouse was in use at each check; history from 0.5.1 and before still reads.
- **Ring size.** **Preferences › Highlight › Ring size** makes the ring around the pointer smaller or bigger, from 0.5× to 2×.
- **Press in Highlight.** **Shrink the pointer on click** is now a third picture next to Pulse and Laser, and clicking it turns it on or off.
- **Side buttons in Finder and Claude.** **Preferences › Buttons** now lists Finder and the Claude app with ⌘[ and ⌘], next to Slack. They're added once, so if you remove one it stays removed.
- **One copy at a time.** Opening Pointer Colors quits any other copy that's running, so an update replaces the one in the menu bar instead of adding a second icon.
- **A new pair: Neon flame**, a bright orange-red outline on a deep ember fill, for 48 pairs in all.

**Export all…** saves the laser look, the ring size and the drain report settings, and **Import…** puts them back.

## 0.5.1 — 2026-10-31

- **See when your mouse is charging.** Plug the cable in and a bolt shows next to the level, by the menu bar icon, on the Dock icon and under the pointer, and the Battery page says it's charging. The low-battery notification waits while it charges. The level is checked every minute, so the bolt shows within a minute of plugging in.
- **Battery health counts only real use.** Time on the cable no longer counts as a charge draining: the charge before it is kept, and the next one starts counting once you unplug.
- **Your battery history stays through updates.** It's now kept in its own file on your Mac, in `~/Library/Application Support/com.mustafaabobakr.PointerColors/battery-history.json`, instead of with the app's preferences. Your history so far moves there by itself. **Export all…** still saves it, and **Import…** puts it back.

## 0.5.0 — 2026-10-31

- **A new Preferences window.** Its pages sit in a sidebar grouped by Pointer, Mouse and App, each a column of cards, Liquid Glass on macOS 26 and later. **Search** in the sidebar finds any setting and jumps straight to it, and back and forward work from the toolbar, ⌘[ and ⌘], or your mouse's side buttons. The menu's theme, glass, tint and text size move to a new **Appearance** page.
- **A tidier menu.** Each part of the menu sits in its own card under a small heading. The big picture of the current pair at the top is now off, since the previews already show it; turn on **Preferences › Appearance › Menu › Show current pair at the top** to bring it back with its hex code buttons. Contrast warnings still show under the previews.
- **Your mouse's battery.** A new **Battery** page shows the level next to the menu bar icon, on the Dock icon or in a small label under the pointer, each off, below 10%, below 20% or always. A notification comes once each time the mouse drops below 5%, 10% or 20%.
- **Battery health.** The Battery page records every charge of every mouse: how many days a full charge lasts, how fast it drains, a chart of each charge against the average, and whether charges are getting shorter.
- **Side buttons in Slack and other apps.** **Preferences › Buttons** lists apps that go back and forward with their own keys, Slack's ⌘[ and ⌘] to start with. Over one of them, the side buttons and the Magic Mouse's sideways swipe press those keys. Add your own apps and shortcuts, or turn one off.
- **Pulses in both of the pair's colors.** Every pulse line, ripple and long-press ring now has an outline in the pair's dark color, so it shows on light backgrounds. Turn it off or set its width in **Preferences › Highlight › Pulse**.
- **Pick the app icon.** **Preferences › Appearance › App icon** keeps the Dock icon in its light Default or black Dark design, or lets it follow your Mac's icon style.
- **What's New.** A new Preferences page lists every release and what it changed, newest first.
- **Star on GitHub.** **Preferences › About** has a button to star the project, with its star count.
- **Mouse speed after the lid opens.** macOS sometimes put its own acceleration and speed back several seconds after a wake. The app now puts yours back again a few times over the first 20 seconds.

**Export all…** saves every new setting, and **Import…** puts them back. The low-battery notification needs permission to notify, which **Preferences › General › Permission** asks for.

## 0.4.9 — 2026-10-30

- **Your mouse speed stays after the Mac sleeps.** Closing and reopening the lid, or logging back in, put macOS's own acceleration and speed back. The app now notices whenever macOS resets them and puts yours straight back, as LinearMouse does.
- **A sound on every pair change.** With **Play a sound when a pair is applied** on, changing pairs quickly one after another now plays the sound each time, instead of staying silent until the last one finished.

## 0.4.8 — 2026-10-30

- **The app no longer quits when you close its menu.** In 0.4.7, clicking the menu bar icon a second time to close the menu quit Pointer Colors. It now just closes the menu. **Show in menu bar** still hides and shows the icon.

## 0.4.7 — 2026-10-30

- **Mouse acceleration and speed.** A new **Speed** tab in Preferences sets the mouse's **Acceleration** anywhere from 0 to 40 and its **Pointer speed**, beyond what System Settings offers, each with a ↺ button that puts back the default. Turn on **Disable pointer acceleration** and the pointer moves exactly as far as the mouse, however fast you move it. The app keeps these on every mouse, including one that connects later or after the Mac wakes.
- **Press twice to find the pointer.** Press Control twice and a ring in your pair's colors closes in on the pointer. Choose another key, or turn it off, in **Preferences › Automation › Finding the pointer**.
- **Menu bar, battery and Dock.** **Preferences › General** can show your mouse's battery next to the menu bar icon (always, or only when it's low), hide the icon, or keep the app in the Dock. With the icon hidden, open the app again to get to Preferences.
- **Side buttons go back and forward.** Turn on **Preferences › Buttons › Side buttons** and your mouse's back and forward buttons work in Safari, Finder and Apple's other apps, not just in browsers.
- **No more accidental double-clicks.** **Preferences › Buttons › Clicks** ignores a click that comes a few milliseconds after the last one, so a worn button clicks once. Choose how close together counts as a bounce.
- **Focus follows the pointer.** Turn on **Preferences › Automation › Windows › Focus the window under the pointer** and the window under the pointer takes your typing after a moment, without coming to the front. Hold a modifier key to pass over windows without changing focus.
- **Lighter clicks with Shrink the pointer on click.** A press now only redraws the pointer, instead of making every app reload its mouse settings many times a second.

The side buttons, double-click fix and focus need Accessibility: the app asks for it when you turn one on. **Export all…** saves all the new settings.

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
