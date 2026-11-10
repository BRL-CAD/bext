"""Review and checkout independence of Qt's security-critical attributions."""

import json
import unittest
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SOURCE / 'CMake/tests'))

from source_inventory_fixture import SourceInventoryFixture


def populate_inventory_sources(fixture):
    manifest = json.loads((fixture.repository / 'qt/attributions.json').read_text(encoding='utf-8'))
    for entry in manifest['components']:
        fixture.copy_evidence('qt/attributions/' + entry['snapshot'],
                              'qt/qt/qtbase/' + entry['path'] + '/qt_attribution.json')
    fixture.copy_evidence('qt/licenses/pcre2.txt', 'qt/qt/qtbase/src/3rdparty/pcre2/LICENCE.md')


class QtAttributionTests(SourceInventoryFixture):
    def setUp(self):
        super().setUp()
        self.attributions = json.loads((self.repository / 'qt/attributions.json').read_text(encoding='utf-8'))

    def test_snapshot_hashes_and_source_revision_are_required(self):
        for name, expected_error in (
            ('qt/attributions/pcre2.json', 'Qt snapshot attribution'),
        ):
            with self.subTest(snapshot=name):
                path = self.repository / name
                original = path.read_bytes()
                path.write_bytes(original + b'changed evidence\n')
                self.git('add', name)
                self.git('commit', '-qm', 'Exercise changed evidence')
                self.assertIn(expected_error, self.generate(success=False))
                path.write_bytes(original)
                self.git('add', name)
                self.git('commit', '-qm', 'Restore reviewed evidence')
        manifest = self.repository / 'qt/attributions.json'
        document = dict(self.attributions, reviewedRevision='0' * 40)
        manifest.write_text(json.dumps(document), encoding='utf-8')
        self.git('add', 'qt/attributions.json')
        self.git('commit', '-qm', 'Exercise stale attribution review')
        self.assertIn('was reviewed at', self.generate(success=False))

    def test_snapshot_reads_ignore_unstaged_attribution_changes(self):
        (self.repository / 'qt/attributions.json').write_text('Invalid working metadata\n', encoding='utf-8')
        for entry in self.attributions['components']:
            (self.repository / 'qt/attributions' / entry['snapshot']).unlink()
        for mode in ('HEAD', 'INDEX'):
            with self.subTest(snapshot=mode):
                self.inventory(mode)

    def test_available_upstream_evidence_remains_verified(self):
        for snapshot, source, expected_error in (
            ('qt/attributions/pcre2.json', 'qt/qt/qtbase/src/3rdparty/pcre2/qt_attribution.json',
             'Qt upstream attribution'),
            ('qt/licenses/pcre2.txt', 'qt/qt/qtbase/src/3rdparty/pcre2/LICENCE.md',
             'Source license for qt/qt#qtbase/src/3rdparty/pcre2 changed'),
        ):
            with self.subTest(source=source):
                path = self.copy_evidence(snapshot, source)
                path.write_bytes(path.read_bytes() + b'changed upstream evidence\n')
                self.assertIn(expected_error, self.generate(success=False))
                path.unlink()

    def test_new_qt_security_critical_packages_require_review(self):
        attribution = self.repository / 'qt/qt/qtbase/src/3rdparty/unreviewed/qt_attribution.json'
        attribution.parent.mkdir(parents=True)
        attribution.write_text('{"SecurityCritical":true}', encoding='utf-8')
        self.assertIn('has no installed-SBOM feature mapping', self.generate(success=False))

    def test_refresh_reads_committed_attributions_and_rejects_unreviewed_packages(self):
        tool = [sys.executable, self.repository / 'qt/RefreshSbomAttributions.py']
        self.assertIn('Initialize the Qt source checkout', self.command(*tool, success=False))
        populate_inventory_sources(self)
        vendor = self.repository / 'qt/qt'

        def git(*arguments):
            return self.command('git', '-C', vendor, *arguments)

        git('init', '-q')
        git('config', 'user.name', 'Qt Attribution Test')
        git('config', 'user.email', 'test@example.invalid')
        git('config', 'commit.gpgsign', 'false')
        git('add', '.')
        git('commit', '-qm', 'Prepare attribution sources')
        revision = git('rev-parse', 'HEAD').strip()
        first = self.attributions['components'][0]
        dirty = vendor / 'qtbase' / first['path'] / 'qt_attribution.json'
        dirty.write_text('Uncommitted attribution changes\n', encoding='utf-8')
        self.command(*tool)
        manifest = self.repository / 'qt/attributions.json'
        refreshed = json.loads(manifest.read_text(encoding='utf-8'))
        self.assertEqual(refreshed['reviewedRevision'], revision)
        self.assertEqual(refreshed['components'], self.attributions['components'])
        git('checkout', '--', str(dirty.relative_to(vendor)))
        unknown = vendor / 'qtbase/src/3rdparty/unreviewed/qt_attribution.json'
        unknown.parent.mkdir(parents=True)
        unknown.write_text('{"SecurityCritical":true}', encoding='utf-8')
        git('add', '.')
        git('commit', '-qm', 'Exercise an unreviewed source component')
        before = manifest.read_bytes()
        self.assertIn('Review Qt component mappings', self.command(*tool, success=False))
        self.assertEqual(manifest.read_bytes(), before)

if __name__ == '__main__':
    unittest.main()
