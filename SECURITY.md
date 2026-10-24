# Security Policy

## Supported versions

Only the [latest release](https://github.com/mustafaabobakr/macos-pointer-colors/releases/latest) of the Mac app, and the live website, get security fixes.

## Reporting a vulnerability

Please report it privately through [GitHub's private vulnerability reporting](https://github.com/mustafaabobakr/macos-pointer-colors/security/advisories/new), not in a public issue.

Include what you found, the steps to reproduce it, and the app version and macOS version. You'll get a reply within 7 days, and a fix or a plan within 30 days for confirmed issues. You'll be credited in the release notes unless you'd rather not be.

## What the app does

So you know what's in scope:

- It changes only the pointer color, pointer size and shake-to-find settings in `com.apple.universalaccess`, the same ones as System Settings › Accessibility › Display › Pointer.
- It may ask for Full Disk Access, only because macOS protects that preferences file.
- It reads no other files and collects nothing. Its only network request is the optional update check against this repository's GitHub releases.
- The website is static, with no accounts, cookies or tracking.
