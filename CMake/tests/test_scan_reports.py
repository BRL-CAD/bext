#!/usr/bin/env python3
"""Offline checks for scanner coverage and report publication."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


MODULE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE))
from ScanVex import scan, scan_coverage, main
from SupplyChainTools import publish_files


class ScanReportTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-scan-report-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.inventory = self.root / 'source.json'
        self.source = {'spdxVersion': 'SPDX-2.3', 'packages': [
            {'SPDXID': 'SPDXRef-probe', 'name': 'probe', 'externalRefs': [
                {'referenceType': 'purl', 'referenceLocator': 'pkg:conan/probe@1.0'}]}]}
        self.inventory.write_text(json.dumps(self.source))

    def test_coverage_distinguishes_empty_partial_and_complete_recognition(self):
        coverage = scan_coverage(self.inventory, set())
        self.assertEqual(coverage['recognizedPackages'], 0)
        self.assertEqual(coverage['unrecognizedPackages'][0]['id'], 'SPDXRef-probe')
        self.assertEqual(scan_coverage(self.inventory, {'pkg:conan/probe@1.0'})['status'], 'complete')
        self.inventory.write_text(json.dumps({'spdxVersion': 'SPDX-2.3', 'packages': []}))
        self.assertEqual(scan_coverage(self.inventory, set())['status'], 'empty')

    def test_github_name_case_is_normalized_without_changing_source_revisions(self):
        self.source['packages'][0]['externalRefs'][0]['referenceLocator'] = 'pkg:github/BRL-CAD/Probe@ReleaseA'
        self.inventory.write_text(json.dumps(self.source))
        recognized = scan_coverage(self.inventory, {'pkg:github/brl-cad/probe@ReleaseA'})
        self.assertEqual(recognized['recognizedPackages'], 1)
        mismatched = scan_coverage(self.inventory, {'pkg:github/brl-cad/probe@releasea'})
        self.assertEqual(mismatched['recognizedPackages'], 0)

    def test_successful_scanner_with_zero_packages_produces_incomplete_report_and_failure_exit(self):
        output = self.root / 'reports'
        arguments = ['ScanVex.py', '--input', str(self.inventory), '--output-dir', str(output)]

        def empty_scan(command, **options):
            options['stdout'].write(json.dumps({'matches': [], 'descriptor': {}}))
            catalog = next(arg.split('=', 1)[1] for arg in command if arg.startswith('cyclonedx-json='))
            Path(catalog).write_text(json.dumps({'components': []}))

        with mock.patch('ScanVex.shutil.which', return_value='fixture'), \
                mock.patch('ScanVex.tool_version', return_value='fixture-version'), \
                mock.patch('ScanVex.subprocess.run', side_effect=empty_scan), \
                mock.patch.object(sys, 'argv', arguments):
            self.assertEqual(main(), 1)
        report = json.loads((output / 'grype.summary.json').read_text())
        self.assertEqual(report['status'], 'incomplete')
        self.assertEqual(report['rawMatches'], 0)
        self.assertEqual(report['coverage']['inputPackages'], 1)

    def test_timeout_is_passed_to_scanner(self):
        with mock.patch('ScanVex.shutil.which', return_value='fixture'), \
                mock.patch('ScanVex.tool_version', return_value='fixture-version'), \
                mock.patch('ScanVex.subprocess.run', side_effect=subprocess.TimeoutExpired('fixture', 1)) as run:
            with self.assertRaises(subprocess.TimeoutExpired):
                scan('grype', self.inventory, None, self.root, True, timeout=1)
        self.assertEqual(run.call_args.kwargs['timeout'], 1)

    def test_publication_stages_every_output_and_publishes_completion_last(self):
        names = []
        replace = Path.replace

        def track(path, target):
            names.append(path.name)
            return replace(path, target)

        with mock.patch.object(Path, 'replace', track):
            publish_files(self.root, {'complete.json': '{}', 'data.txt': 'contents'}, 'complete.json')
        self.assertEqual(names, ['data.txt', 'complete.json'])
        self.assertEqual((self.root / 'data.txt').read_text(), 'contents')


if __name__ == '__main__':
    unittest.main()
