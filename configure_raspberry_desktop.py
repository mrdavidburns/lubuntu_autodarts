"""Configure Raspberry Pi PCManFM wallpaper and per-user panel icon overrides."""
import configparser
import shutil
import sys
from pathlib import Path


def configure_wallpaper(home: Path, wallpaper: Path) -> None:
    profile = home / '.config/pcmanfm/default'
    profile.mkdir(parents=True, exist_ok=True)
    configs = set(profile.glob('desktop-items-*.conf'))
    configs.add(profile / 'desktop-items-0.conf')
    for path in sorted(configs):
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        if path.exists():
            parser.read(path)
        if not parser.has_section('*'):
            parser.add_section('*')
        parser.set('*', 'wallpaper', str(wallpaper))
        parser.set('*', 'wallpaper_mode', 'stretch')
        parser.set('*', 'wallpaper_common', '1')
        with path.open('w') as stream:
            parser.write(stream, space_around_delimiters=False)


def configure_icons(home: Path, icon: Path, system_icons: Path) -> int:
    count = 0
    for source in system_icons.glob('*/**/start-here.*'):
        if source.suffix.lower() not in ('.png', '.svg', '.xpm'):
            continue
        target = (home / '.local/share/icons' / source.relative_to(system_icons)).with_suffix('.png')
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes() != icon.read_bytes():
            backup = target.with_name(target.name + '.before-autodarts')
            if not backup.exists():
                shutil.copy2(target, backup)
        shutil.copyfile(icon, target)
        count += 1
    return count


def main() -> int:
    home = Path.home()
    wallpaper = home / 'Pictures/winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png'
    icon = home / '.local/share/icons/autodarts-favicon.png'
    configure_wallpaper(home, wallpaper)
    count = configure_icons(home, icon, Path('/usr/share/icons'))
    if count:
        print(f'Installed {count} per-user start menu icon overrides.')
    else:
        print('WARN: No installed start-here theme icons found; menu icon was not changed.', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
