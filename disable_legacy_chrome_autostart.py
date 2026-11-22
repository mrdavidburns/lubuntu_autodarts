"""Disable old AutoDarts browser autostarts before enabling the watchdog."""

import configparser
import os
import re
import sys
from pathlib import Path


def is_legacy(path, url):
    if path.name == 'google-chrome-fullscreen.desktop':
        return True
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(path, encoding='utf-8')
        entry = parser['Desktop Entry']
        command = entry.get('Exec', '')
        name = entry.get('Name', '').lower()
        browser = re.search(r'(^|[/\s])(google-chrome(?:-stable)?|chromium(?:-browser)?)(?=\s|$)', command)
        return bool(browser and ('autodarts' in name or 'play.autodarts.io' in command or (url and url in command)))
    except (configparser.Error, KeyError, OSError, UnicodeError):
        return False


def disable(home, system_dirs, url):
    user_dir = home / '.config' / 'autostart'
    user_dir.mkdir(parents=True, exist_ok=True)
    # A user entry takes precedence over the system entry of the same name.
    entries = {p.name: p for p in user_dir.glob('*.desktop')}
    for directory in system_dirs:
        for path in directory.glob('*.desktop'):
            entries.setdefault(path.name, path)
    for name, path in entries.items():
        if name == 'autodarts-chrome-watchdog.desktop' or not is_legacy(path, url):
            continue
        target = user_dir / name
        if path != target:
            target.write_text('[Desktop Entry]\nType=Application\nHidden=true\n', encoding='utf-8')
        else:
            text = target.read_text(encoding='utf-8')
            lines = text.splitlines(keepends=True)
            in_entry = False
            result = []
            for line in lines:
                if line.startswith('['):
                    in_entry = line.strip() == '[Desktop Entry]'
                    if in_entry:
                        result.append(line if line.endswith('\n') else line + '\n')
                        result.append('Hidden=true\n')
                        continue
                if in_entry and re.match(r'^\s*Hidden\s*=', line):
                    continue
                result.append(line)
            target.write_text(''.join(result), encoding='utf-8')
        print(f'Disabled legacy Chrome autostart: {target}')


if __name__ == '__main__':
    directories = [Path(p) / 'autostart' for p in os.environ.get('XDG_CONFIG_DIRS', '/etc/xdg').split(':') if p]
    disable(Path.home(), directories, sys.argv[1])
