#!/usr/bin/env python3
"""Check the public legal URLs survive removal of the Flutter web build."""
import json
from pathlib import Path
from html.parser import HTMLParser

root = Path(__file__).resolve().parents[2]
config = json.loads((root / 'firebase.json').read_text())['hosting']
public = root / config['public']
rewrites = {row['source']: row['destination'] for row in config['rewrites']}

class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.heading = False
    def handle_starttag(self, tag, attrs):
        if tag == 'h1':
            self.heading = True
        if tag == 'a':
            self.links.extend(value for name, value in attrs if name == 'href')

for route in ('/privacy', '/terms', '/support'):
    destination = rewrites.get(route)
    if not destination:
        raise SystemExit(f'Missing public route: {route}')
    page_path = public / destination.lstrip('/')
    source = page_path.read_text()
    page = Page()
    page.feed(source)
    if not page.heading or 'flutter_bootstrap' in source:
        raise SystemExit(f'Invalid static legal page: {route}')
    for link in page.links:
        if link.startswith('/') and link not in rewrites:
            raise SystemExit(f'Broken internal link in {route}: {link}')
if '**' in rewrites:
    raise SystemExit('Obsolete Flutter catch-all rewrite is still present')
print('Privacy, terms and support routes are backed by standalone static pages.')
