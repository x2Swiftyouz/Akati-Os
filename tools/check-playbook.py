#!/usr/bin/env python3
"""Check src/playbook.conf for errors that make AME Wizard refuse to load the playbook.

Usage: python3 tools/check-playbook.py [path/to/playbook.conf]
"""
import sys
import xml.etree.ElementTree as ET

# AME Wizard: "RadioPage with a TopLine or BottomLine must not have more than 3 options".
# AtlasOS never puts more than 3 options on a RadioPage or CheckboxPage, so we keep that limit for both.
MAX_OPTIONS = 3

path = sys.argv[1] if len(sys.argv) > 1 else 'src/playbook.conf'
try:
    root = ET.parse(path).getroot()
except ET.ParseError as e:
    sys.exit(f'error: {path} is not valid XML: {e}')

errors = []
names = {}
for page_tag in ('RadioPage', 'CheckboxPage', 'RadioImagePage'):
    for page in root.iter(page_tag):
        desc = (page.get('Description') or '')[:50]
        options = page.find('Options')
        opts = list(options) if options is not None else []
        if not opts:
            errors.append(f'{page_tag} "{desc}": no options')
        if page_tag != 'RadioImagePage' and len(opts) > MAX_OPTIONS:
            errors.append(f'{page_tag} "{desc}": {len(opts)} options, max is {MAX_OPTIONS}')
        page_names = [o.findtext('Name') for o in opts]
        for n in page_names:
            if not n:
                errors.append(f'{page_tag} "{desc}": option without <Name>')
            elif n in names:
                errors.append(f'option name "{n}" is used twice')
            else:
                names[n] = page_tag
        default = page.get('DefaultOption')
        if default and default not in page_names:
            errors.append(f'{page_tag} "{desc}": DefaultOption "{default}" is not one of its options')

for e in errors:
    print(f'error: {e}', file=sys.stderr)
if errors:
    sys.exit(1)
print(f'{path}: OK ({len(names)} options)')
