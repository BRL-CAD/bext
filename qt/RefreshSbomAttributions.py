#!/usr/bin/env python3
"""Refresh reviewed Qt attribution snapshots from the checked-out source revision."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


def refresh_attributions():
    package = Path(__file__).resolve().parent
    source = package / 'qt'
    if not (source / '.git').exists():
        raise ValueError('Initialize the Qt source checkout before refreshing attribution snapshots')
    manifest_path = package / 'attributions.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    if not isinstance(manifest, dict) or manifest.get('schemaVersion') != 1:
        raise ValueError('Unsupported Qt attribution snapshot schema')

    def git(*arguments):
        return subprocess.check_output(['git', '-C', str(source), *arguments])

    revision = git('rev-parse', '--verify', 'HEAD').decode().strip()
    files = git('ls-tree', '-r', '--name-only', revision, '--', 'qtbase', 'qtsvg').decode().splitlines()
    critical = {}
    for name in files:
        if not name.endswith('/qt_attribution.json'):
            continue
        data = git('show', f'{revision}:{name}').replace(b'\r\n', b'\n')
        # Some noncritical Qt descriptions contain literal newlines and are
        # not valid JSON. They cannot contribute security-critical packages.
        if not re.search(rb'"SecurityCritical"\s*:\s*true', data):
            continue
        document = json.loads(data)
        entries = document if isinstance(document, list) else [document]
        if not all(isinstance(entry, dict) for entry in entries):
            raise ValueError(f'Invalid Qt attribution records: {name}')
        if any(entry.get('SecurityCritical') is True for entry in entries):
            critical[name] = data

    reviewed = {f'qtbase/{entry["path"]}/qt_attribution.json' for entry in manifest['components']}
    if len(reviewed) != len(manifest['components']):
        raise ValueError('Duplicate reviewed Qt attribution paths')
    if reviewed != critical.keys():
        added = ', '.join(sorted(critical.keys() - reviewed)) or 'none'
        removed = ', '.join(sorted(reviewed - critical.keys())) or 'none'
        raise ValueError(f'Review Qt component mappings before refreshing: added {added}; removed {removed}')

    snapshots = []
    for entry in manifest['components']:
        snapshot = Path(entry['snapshot'])
        if snapshot.name != entry['snapshot'] or snapshot.suffix != '.json':
            raise ValueError(f'Invalid Qt snapshot filename: {snapshot}')
        data = critical[f'qtbase/{entry["path"]}/qt_attribution.json']
        entry['sha256'] = hashlib.sha256(data).hexdigest()
        snapshots.append((package / 'attributions' / snapshot, data))
    manifest['reviewedRevision'] = revision
    for destination, data in snapshots:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    with manifest_path.open('w', encoding='utf-8', newline='\n') as output:
        output.write(json.dumps(manifest, indent=2) + '\n')
    print(f'Refreshed {len(snapshots)} Qt attribution snapshots at {revision}; review the changes before staging.')


if __name__ == '__main__':
    try:
        refresh_attributions()
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f'Unable to refresh Qt attribution snapshots: {error}', file=sys.stderr)
        raise SystemExit(1)
