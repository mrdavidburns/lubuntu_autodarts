#!/usr/bin/env python3
"""Set LXQt's main-menu icon without disturbing other panel settings."""
import os
from pathlib import Path
import re
import shutil
import sys


def configure_panel(path: Path, icon: str) -> None:
    text = path.read_text()
    sections = re.split(r'(?=^\[[^\]]+\]\s*$)', text, flags=re.MULTILINE)
    found = False
    for index, section in enumerate(sections):
        if not re.search(r'^type\s*=\s*mainmenu\s*$', section, re.MULTILINE):
            continue
        found = True
        for key, value in (("icon", icon), ("ownIcon", "true")):
            line = f"{key}={value}"
            pattern = rf'^{key}\s*=.*$'
            if re.search(pattern, section, re.MULTILINE):
                section = re.sub(pattern, lambda _: line, section, flags=re.MULTILINE)
            else:
                section = section.rstrip() + "\n" + line + "\n\n"
        sections[index] = section
    if not found:
        raise ValueError("No LXQt main menu plugin found in panel.conf")
    updated = ''.join(sections)
    if updated != text:
        path.write_text(updated)


def main() -> int:
    home = Path.home()
    panel = home / '.config/lxqt/panel.conf'
    if not panel.exists():
        defaults = [Path('/etc/xdg/lubuntu/lxqt/panel.conf'), Path('/etc/xdg/lxqt/panel.conf')]
        source = next((p for p in defaults if p.is_file()), None)
        if source is None:
            print('No LXQt panel configuration found', file=sys.stderr)
            return 1
        panel.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, panel)
    try:
        configure_panel(panel, str(home / '.local/share/icons/winmau-autodarts-menu.png'))
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
