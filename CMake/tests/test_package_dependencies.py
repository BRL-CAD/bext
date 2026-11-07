#!/usr/bin/env python3
"""Release archives must retain the matching supply-chain evidence."""

from pathlib import Path
import json
import subprocess
import tarfile
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]


class PackageDependenciesTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-archive-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.prefix = self.root / 'prefix'
        self.prefix.mkdir()
        for directory in ('install', 'noinstall'):
            (self.prefix / directory).mkdir()
        generator = self.prefix / 'noinstall/share/bext/supply-chain/CMake/GenerateVex.py'
        generator.parent.mkdir(parents=True)
        generator.write_text('')
        for name in ('bext-install-manifest.json', 'bext-install-exclude-manifest.json',
                     'bext-content-stamp', 'bext.spdx.json', 'bext.cdx.json', 'bext-component-manifest.json',
                     'bext-vex-evidence.json', 'bext-vex-report.json'):
            (self.prefix / name).write_text('{}')
        for format_name in ('spdx', 'cdx'):
            for name in (f'bext.build.{format_name}.json', f'bext.build.conan.{format_name}.json',
                         f'bext.build.conan.{format_name}.coverage.json'):
                (self.prefix / name).write_text('{}')
        self.archive = self.root / 'dependencies.tar.gz'
        (self.prefix / 'bext-install-manifest.json').write_text('{"files":[]}')
        (self.prefix / 'bext.spdx.json').write_text(json.dumps({'documentNamespace': 'https://example.invalid/source'}))
        (self.prefix / 'bext-vex-evidence.json').write_text(json.dumps({
            'sourceDocument': 'https://example.invalid/source', 'buildId': 'fixture-build'}))

    def package(self, vex):
        (self.prefix / 'bext-vex-report.json').write_text(json.dumps({
            'vexGenerated': vex, 'buildId': 'fixture-build'}))
        return subprocess.run(['cmake', f'-DBEXT_PACKAGE_ROOT={self.prefix}',
                               f'-DBEXT_PACKAGE_ARCHIVE={self.archive}', '-P',
                               str(MODULE / 'PackageDependencies.cmake')], capture_output=True, text=True)

    def test_archive_retains_evidence_and_accepts_a_build_without_reviews(self):
        result = self.package(False)
        self.assertEqual(result.returncode, 0, result.stderr)
        with tarfile.open(self.archive) as archive:
            names = archive.getnames()
        self.assertIn('bext-vex-evidence.json', names)
        self.assertIn('bext.build.cdx.json', names)
        self.assertIn('bext-component-manifest.json', names)
        self.assertIn('bext.spdx.json', names)
        self.assertIn('bext.cdx.json', names)
        self.assertIn('bext-install-exclude-manifest.json', names)
        self.assertIn('bext-content-stamp', names)
        self.assertNotIn('bext.openvex.json', names)

    def test_missing_evidence_or_required_vex_prevents_publication(self):
        result = self.package(True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.archive.exists())
        (self.prefix / 'bext.openvex.json').write_text('{}')
        self.assertEqual(self.package(True).returncode, 0)
        (self.prefix / 'bext-vex-evidence.json').unlink()
        self.assertNotEqual(self.package(True).returncode, 0)
        self.assertFalse(self.archive.exists())

    def test_changed_source_inventory_requires_refinalization(self):
        self.assertEqual(self.package(False).returncode, 0)
        (self.prefix / 'bext.spdx.json').write_text(json.dumps({
            'documentNamespace': 'https://example.invalid/new-source'}))
        result = self.package(False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('rerun bext_finalize', result.stderr)
        self.assertFalse(self.archive.exists())

    def test_archive_omits_unrecorded_installer_outputs(self):
        (self.prefix / 'install/owned').write_text('owned')
        (self.prefix / 'install/unrecorded').write_text('unrecorded')
        (self.prefix / 'bext-install-manifest.json').write_text('{"files":["owned"]}')
        result = self.package(False)
        self.assertEqual(result.returncode, 0, result.stderr)
        with tarfile.open(self.archive) as archive:
            names = archive.getnames()
        self.assertIn('install/owned', names)
        self.assertNotIn('install/unrecorded', names)


if __name__ == '__main__':
    unittest.main()
