import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from disable_legacy_chrome_autostart import disable


class LegacyAutostartTest(unittest.TestCase):
    def test_migrates_user_and_system_entries_without_touching_other_apps(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            user = root / 'home' / '.config' / 'autostart'
            system = root / 'system'
            user.mkdir(parents=True)
            system.mkdir()
            old = user / 'renamed.desktop'
            old.write_text('[Desktop Entry]\nName=AutoDarts (Chrome)\nExec=google-chrome-stable --start-fullscreen\nHidden=false\n')
            (system / 'legacy.desktop').write_text('[Desktop Entry]\nExec=chromium --app=https://play.autodarts.io/\n')
            other = user / 'browser.desktop'
            other.write_text('[Desktop Entry]\nName=Browser\nExec=chromium https://example.com\n')
            watchdog = user / 'autodarts-chrome-watchdog.desktop'
            watchdog.write_text('[Desktop Entry]\nExec=systemctl --user start autodarts-chrome.service\n')
            disable(root / 'home', [system], 'https://play.autodarts.io/')
            disable(root / 'home', [system], 'https://play.autodarts.io/')
            self.assertEqual(old.read_text().count('Hidden=true'), 1)
            self.assertNotIn('Hidden=false', old.read_text())
            self.assertIn('Hidden=true', (user / 'legacy.desktop').read_text())
            self.assertNotIn('Hidden=', other.read_text())
            self.assertNotIn('Hidden=', watchdog.read_text())
            self.assertNotIn('Hidden=', (system / 'legacy.desktop').read_text())

    def test_user_override_is_not_replaced_by_system_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            user = root / 'home' / '.config' / 'autostart'
            system = root / 'system'
            user.mkdir(parents=True)
            system.mkdir()
            (user / 'browser.desktop').write_text('[Desktop Entry]\nExec=chromium https://example.com\n')
            (system / 'browser.desktop').write_text('[Desktop Entry]\nExec=chromium --app=https://play.autodarts.io/\n')
            disable(root / 'home', [system], 'https://play.autodarts.io/')
            self.assertNotIn('Hidden=', (user / 'browser.desktop').read_text())
