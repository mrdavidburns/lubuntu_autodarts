#!/usr/bin/env python3
"""Add the kiosk escape shortcut without discarding existing labwc settings."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

path = Path(sys.argv[1])
tree = ET.parse(path)
root = tree.getroot()
namespace = root.tag.partition('}')[0] + '}' if root.tag.startswith('{') else ''
keyboard = root.find(namespace + 'keyboard')
if keyboard is None:
    keyboard = ET.SubElement(root, namespace + 'keyboard')
    ET.SubElement(keyboard, namespace + 'default')
for binding in list(keyboard.findall(namespace + 'keybind')):
    if binding.get('key', '').lower() == 'c-a-q':
        keyboard.remove(binding)
binding = ET.SubElement(keyboard, namespace + 'keybind', {'key': 'C-A-q'})
ET.SubElement(binding, namespace + 'action', {'name': 'Execute', 'command': '/usr/local/bin/exit-kiosk'})
tree.write(path, encoding='unicode', xml_declaration=True)
