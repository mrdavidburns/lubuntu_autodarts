import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class DesktopTests(unittest.TestCase):
    def test_labwc_shortcut_preserves_settings_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / 'rc.xml'
            config.write_text('<labwc_config><keyboard><keybind key="W-Return"><action name="Execute" command="terminal"/></keybind></keyboard><theme><name>Pi</name></theme></labwc_config>')
            for _ in range(2):
                subprocess.run(['python3', str(ROOT / 'configure_labwc.py'), str(config)], check=True)
            root = ET.parse(config).getroot()
            self.assertEqual(root.find('theme/name').text, 'Pi')
            self.assertIsNotNone(root.find("keyboard/keybind[@key='W-Return']"))
            bindings = root.findall("keyboard/keybind[@key='C-A-q']")
            self.assertEqual(len(bindings), 1)
            self.assertEqual(bindings[0].find('action').get('command'), '/usr/local/bin/exit-kiosk')

    def test_desktop_override(self):
        for name in ('lxqt', 'labwc', 'wayfire'):
            result = subprocess.check_output(['bash', '-c', f'. lib/common.sh; AD_DESKTOP={name} ad_desktop nobody'], cwd=ROOT, text=True)
            self.assertEqual(result.strip(), name)

    def test_lxqt_session_takes_precedence_over_wayland_compositor(self):
        result = subprocess.check_output(
            ['bash', '-c', '. lib/common.sh; XDG_CURRENT_DESKTOP=LXQt:labwc ad_desktop nobody'],
            cwd=ROOT, text=True,
        )
        self.assertEqual(result.strip(), 'lxqt')


if __name__ == '__main__':
    unittest.main()
