#!/usr/bin/env python3
"""Add Chrome + QTerminal to LXQt panel quicklaunch (idempotent)."""

import configparser
import os
import sys


NEW_APPS = [
    "/usr/share/applications/google-chrome.desktop",
    "/usr/share/applications/qterminal.desktop",
]


def update_quick_launch() -> int:
    path = os.path.expanduser("~/.config/lxqt/panel.conf")
    if not os.path.exists(path):
        print(f"panel.conf not found at {path}", file=sys.stderr)
        return 1

    parser = configparser.RawConfigParser()
    parser.optionxform = str
    parser.read(path)

    section = "quicklaunch"
    if section not in parser:
        parser.add_section(section)
        parser[section]["alignment"] = "Left"
        parser[section]["apps\\size"] = "0"

    size = int(parser[section].get("apps\\size", "0"))
    existing = {
        parser[section].get(f"apps\\{i}\\desktop")
        for i in range(1, size + 1)
    }

    changed = False
    for app in NEW_APPS:
        if app in existing:
            continue
        size += 1
        parser[section][f"apps\\{size}\\desktop"] = app
        changed = True

    if not changed:
        print("Quick Launch already contains target apps.")
        return 0

    parser[section]["apps\\size"] = str(size)
    with open(path, "w") as f:
        parser.write(f, space_around_delimiters=False)
    print(f"Quick Launch updated ({size} entries).")
    return 0


if __name__ == "__main__":
    raise SystemExit(update_quick_launch())
