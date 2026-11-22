"""Configure LXQt menu branding and pcmanfm-qt desktop wallpaper."""

import re
import shutil
import sys
from pathlib import Path


def _set_section_keys(section: str, updates: dict[str, str]) -> str:
    for key, value in updates.items():
        line = f"{key}={value}"
        pattern = rf'^{re.escape(key)}\s*=.*$'
        if re.search(pattern, section, re.MULTILINE):
            section = re.sub(pattern, lambda _, l=line: l, section, flags=re.MULTILINE)
        else:
            section = section.rstrip() + "\n" + line + "\n\n"
    return section


def configure_panel(path: Path, icon: str) -> None:
    text = path.read_text()
    sections = re.split(r'(?=^\[[^\]]+\]\s*$)', text, flags=re.MULTILINE)
    found = False
    for index, section in enumerate(sections):
        if not re.search(r'^type\s*=\s*(?:mainmenu|fancymenu)\s*$', section, re.MULTILINE):
            continue
        found = True
        sections[index] = _set_section_keys(
            section,
            {
                "icon": icon,
                "ownIcon": "true",
                "showText": "true",
                "text": '" AUTODARTS"',
            },
        )
    if not found:
        raise ValueError("No LXQt mainmenu or fancymenu plugin found in panel.conf")
    updated = ''.join(sections)
    if updated != text:
        path.write_text(updated)


def configure_wallpaper(path: Path, wallpaper: str, mode: str = "stretch") -> None:
    text = path.read_text() if path.exists() else ""
    sections = re.split(r'(?=^\[[^\]]+\]\s*$)', text, flags=re.MULTILINE)
    updates = {
        "Wallpaper": wallpaper,
        "WallpaperMode": mode,
        "PerScreenWallpaper": "false",
    }
    found = False
    for index, section in enumerate(sections):
        if not re.match(r'^\[Desktop\]\s*$', section, re.MULTILINE):
            continue
        found = True
        sections[index] = _set_section_keys(section, updates)
        break
    if not found:
        desktop_block = "[Desktop]\n" + "\n".join(f"{k}={v}" for k, v in updates.items()) + "\n"
        if text and not text.endswith("\n\n"):
            desktop_block = "\n" + desktop_block
        sections.append(desktop_block)
    updated = ''.join(sections)
    if updated != text:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(updated)


def _ensure_config(target: Path, defaults: list[Path], label: str) -> bool:
    if target.exists():
        return True
    source = next((p for p in defaults if p.is_file()), None)
    if source is None:
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    return True


def main() -> int:
    home = Path.home()
    panel = home / '.config/lxqt/panel.conf'
    if not _ensure_config(
        panel,
        [
            Path('/etc/xdg/xdg-Lubuntu/lxqt/panel.conf'),
            Path('/etc/xdg/lubuntu/lxqt/panel.conf'),
            Path('/etc/xdg/lxqt/panel.conf'),
        ],
        'LXQt panel',
    ):
        print('No LXQt panel configuration found', file=sys.stderr)
        return 1

    pcmanfm = home / '.config/pcmanfm-qt/lxqt/settings.conf'
    _ensure_config(
        pcmanfm,
        [
            Path('/etc/xdg/xdg-Lubuntu/pcmanfm-qt/lxqt/settings.conf'),
            Path('/etc/xdg/lubuntu/pcmanfm-qt/lxqt/settings.conf'),
            Path('/etc/xdg/pcmanfm-qt/lxqt/settings.conf'),
        ],
        'pcmanfm-qt',
    )

    try:
        configure_panel(panel, str(home / '.local/share/icons/autodarts-favicon.png'))
        configure_wallpaper(
            pcmanfm,
            str(home / 'Pictures/winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png'),
        )
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
