import configparser
import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'configure_raspberry_desktop.py'
spec = importlib.util.spec_from_file_location('raspberry_desktop', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RaspberryDesktopTests(unittest.TestCase):
    def test_wallpaper_updates_existing_monitors_without_removing_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            profile = home / '.config/pcmanfm/default'
            profile.mkdir(parents=True)
            monitor = profile / 'desktop-items-HDMI-A-1.conf'
            monitor.write_text('[*]\nwallpaper=old\nshow_trash=1\n[desktop]\nitem=kept\n')
            wallpaper = home / 'Pictures/branding.png'
            module.configure_wallpaper(home, wallpaper)
            for path in (monitor, profile / 'desktop-items-0.conf'):
                conf = configparser.ConfigParser(interpolation=None)
                conf.read(path)
                self.assertEqual(conf.get('*', 'wallpaper'), str(wallpaper))
                self.assertEqual(conf.get('*', 'wallpaper_mode'), 'stretch')
            saved = configparser.ConfigParser(interpolation=None)
            saved.read(monitor)
            self.assertEqual(saved.get('*', 'show_trash'), '1')
            self.assertEqual(saved.get('desktop', 'item'), 'kept')

    def test_theme_overrides_preserve_existing_icon_backup_on_rerun(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / 'home'
            icons = Path(tmp) / 'system'
            system_icon = icons / 'PiXtrix/32x32/places/start-here.png'
            system_icon.parent.mkdir(parents=True)
            system_icon.write_bytes(b'system')
            custom_icon = home / '.local/share/icons/PiXtrix/32x32/places/start-here.png'
            custom_icon.parent.mkdir(parents=True)
            custom_icon.write_bytes(b'original')
            new_icon = Path(tmp) / 'logo.png'
            new_icon.write_bytes(b'autodarts')
            for _ in range(2):
                self.assertEqual(module.configure_icons(home, new_icon, icons), 1)
            self.assertEqual(custom_icon.read_bytes(), b'autodarts')
            self.assertEqual(custom_icon.with_name('start-here.png.before-autodarts').read_bytes(), b'original')
            self.assertEqual(system_icon.read_bytes(), b'system')


if __name__ == '__main__':
    unittest.main()
