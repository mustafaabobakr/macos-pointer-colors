"""Copies an Icon Composer icon with its Dark appearance as the only one.

Usage: python3 -I dark-icon.py <AppIcon.icon> <out.icon>

Icon Composer keeps a per-appearance value as `<key>-specializations`, a list of
{"appearance": ..., "value": ...} with the default having no appearance. Compiled on its own, the
copy gives a flat AppIconDark.icns, which Preferences › Appearance › App icon shows in the Dock.
"""
import json
import shutil
import sys

SUFFIX = "-specializations"


def dark_only(node):
    """`node` with every specialized value replaced by its dark one, or its default without one."""
    if isinstance(node, list):
        return [dark_only(item) for item in node]
    if not isinstance(node, dict):
        return node
    result = {}
    for key, value in node.items():
        if not key.endswith(SUFFIX):
            result[key] = dark_only(value)
            continue
        default = next((v["value"] for v in value if "appearance" not in v), None)
        dark = next((v["value"] for v in value if v.get("appearance") == "dark"), default)
        if dark is not None:
            result[key[: -len(SUFFIX)]] = dark_only(dark)
    return result


def main(source, target):
    shutil.rmtree(target, ignore_errors=True)
    shutil.copytree(source, target)
    with open(f"{source}/icon.json") as file:
        icon = json.load(file)
    with open(f"{target}/icon.json", "w") as file:
        json.dump(dark_only(icon), file, indent=2)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
