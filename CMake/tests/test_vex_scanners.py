#!/usr/bin/env python3
"""Opt-in, offline scanner checks for build-specific OpenVEX matching.

Requires the documented scanner installations and populated local databases.
The statements are synthetic matching fixtures, never release assertions.
"""

import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE))
from ScanVex import findings, scan
FIXTURE = Path(__file__).with_name('fixtures') / 'vulnerable-zlib.spdx.json'
TARGET_CVE = 'CVE-2018-25032'
CONTROL_CVE = 'CVE-2022-37434'
BUILD_QUALIFIER = 'bext_build'
REVIEWED_BUILD = 'reviewed-build'
OTHER_BUILD = 'other-build'
SCANNER_TESTS_ENABLED = os.environ.get('BEXT_VEX_SCANNER_TESTS') == '1'


@unittest.skipUnless(SCANNER_TESTS_ENABLED,
                     'Set BEXT_VEX_SCANNER_TESTS=1 with cached scanner databases')
class VexScannerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bext-vex-test-')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.inventory = json.loads(FIXTURE.read_text())
        self.source_purl = next(
            ref['referenceLocator']
            for ref in self.inventory['packages'][0]['externalRefs']
            if ref['referenceType'] == 'purl')
        self.vex = self.directory / 'synthetic.openvex.json'
        self.vex.write_text(json.dumps({
            '@context': 'https://openvex.dev/ns/v0.2.0',
            '@id': 'https://example.invalid/vex/scanner-fixture',
            'author': 'https://example.invalid/',
            'timestamp': '2026-01-01T00:00:00Z',
            'version': 1,
            'statements': [{
                'vulnerability': {'name': TARGET_CVE},
                'products': [{'@id': self.build_purl(REVIEWED_BUILD)}],
                'status': 'not_affected',
                'justification': 'vulnerable_code_not_present',
                'impact_statement': (
                    'Synthetic identity-matching fixture only. '
                    'This is not an assertion about any distributed software.'),
            }],
        }))

    def build_purl(self, build):
        return f'{self.source_purl}?{BUILD_QUALIFIER}={build}'

    def write_inventory(self, format_name, build):
        inventory = copy.deepcopy(self.inventory)
        label = build or 'unqualified-source'
        inventory['documentNamespace'] += '/' + label
        if build:
            for ref in inventory['packages'][0]['externalRefs']:
                if ref['referenceType'] == 'purl':
                    ref['referenceLocator'] = self.build_purl(build)
        spdx_path = self.directory / f'{label}.spdx.json'
        spdx_path.write_text(json.dumps(inventory))
        if format_name == 'spdx':
            return spdx_path
        cdx_path = self.directory / f'{label}.cdx.json'
        converter = self.directory / 'convert.cmake'
        converter.write_text('''cmake_minimum_required(VERSION 3.26)
include("${MODULE}/BextCycloneDx.cmake")
file(READ "${INPUT}" inventory)
bext_write_cyclonedx("${OUTPUT}" "${inventory}")
''')
        subprocess.run([
            'cmake', f'-DMODULE={MODULE}', f'-DINPUT={spdx_path}',
            f'-DOUTPUT={cdx_path}', '-P', str(converter),
        ], check=True, capture_output=True, text=True)
        return cdx_path

    def scan(self, scanner, inventory, apply_vex):
        if scanner == 'grype':
            command = ['grype', 'sbom:' + str(inventory), '-o', 'json']
        else:
            command = ['trivy', 'sbom', '--skip-db-update',
                       '--skip-java-db-update', '--format', 'json', str(inventory)]
        if apply_vex:
            command.extend(['--vex', str(self.vex)])
        result = subprocess.run(
            command, capture_output=True, text=True,
            env=dict(os.environ, GRYPE_DB_AUTO_UPDATE='false',
                     GRYPE_CHECK_FOR_APP_UPDATE='false'))
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        if scanner == 'grype':
            return {match['vulnerability']['id'] for match in data['matches']}
        return {vulnerability['VulnerabilityID']
                for report in data.get('Results', [])
                for vulnerability in report.get('Vulnerabilities', [])}

    def check_scanner(self, scanner):
        if not shutil.which(scanner):
            self.skipTest(f'{scanner} is not on PATH')
        for format_name in ('spdx', 'cdx'):
            with self.subTest(scanner=scanner, format=format_name):
                reviewed = self.write_inventory(format_name, REVIEWED_BUILD)
                baseline = self.scan(scanner, reviewed, False)
                self.assertTrue({TARGET_CVE, CONTROL_CVE} <= baseline,
                                'Cached database must detect both control CVEs')
                filtered = self.scan(scanner, reviewed, True)
                self.assertNotIn(TARGET_CVE, filtered)
                self.assertIn(CONTROL_CVE, filtered)
                for build in (OTHER_BUILD, None):
                    inventory = self.write_inventory(format_name, build)
                    findings = self.scan(scanner, inventory, True)
                    self.assertTrue({TARGET_CVE, CONTROL_CVE} <= findings,
                                    f'VEX must not apply to {build or "source"}')

    def test_grype_build_scope(self):
        self.check_scanner('grype')

    def test_trivy_build_scope(self):
        self.check_scanner('trivy')

    def test_mixed_variants_do_not_hide_an_unreviewed_copy(self):
        for scanner in ('grype', 'trivy'):
            if not shutil.which(scanner):
                continue
            for format_name in ('spdx', 'cdx'):
                with self.subTest(scanner=scanner, format=format_name):
                    path = self.write_inventory(format_name, REVIEWED_BUILD)
                    document = json.loads(path.read_text())
                    if format_name == 'spdx':
                        other = copy.deepcopy(document['packages'][0])
                        other['SPDXID'] = 'SPDXRef-zlib-other'
                        for reference in other['externalRefs']:
                            if reference['referenceType'] == 'purl':
                                reference['referenceLocator'] = self.build_purl(OTHER_BUILD)
                        document['packages'].append(other)
                        document['relationships'].append({
                            'spdxElementId': 'SPDXRef-DOCUMENT',
                            'relationshipType': 'DESCRIBES',
                            'relatedSpdxElement': other['SPDXID']})
                    else:
                        other = copy.deepcopy(document['components'][0])
                        other['bom-ref'] = 'SPDXRef-zlib-other'
                        other['purl'] = self.build_purl(OTHER_BUILD)
                        document['components'].append(other)
                        document['dependencies'].append({'ref': other['bom-ref'], 'dependsOn': []})
                        root = document['metadata']['component']['bom-ref']
                        next(item for item in document['dependencies'] if item['ref'] == root)['dependsOn'].append(other['bom-ref'])
                    path.write_text(json.dumps(document))
                    output = self.directory / f'{scanner}-{format_name}-mixed'
                    output.mkdir()
                    summary = scan(scanner, path, self.vex, output, offline=True)
                    baseline = findings(scanner, json.loads((output / f'{scanner}.raw.json').read_text()))
                    filtered = findings(scanner, json.loads((output / f'{scanner}.filtered.json').read_text()))
                    original_pairs = {(item['vulnerability'], item['purl']) for item in baseline.values()}
                    remaining_pairs = {(item['vulnerability'], item['purl']) for item in filtered.values()}
                    self.assertIn((TARGET_CVE, self.build_purl(REVIEWED_BUILD)), original_pairs)
                    self.assertIn((TARGET_CVE, self.build_purl(OTHER_BUILD)), original_pairs)
                    self.assertNotIn((TARGET_CVE, self.build_purl(REVIEWED_BUILD)), remaining_pairs)
                    self.assertIn((TARGET_CVE, self.build_purl(OTHER_BUILD)), remaining_pairs)
                    for build in (REVIEWED_BUILD, OTHER_BUILD):
                        self.assertIn((CONTROL_CVE, self.build_purl(build)), remaining_pairs)
                    self.assertEqual(summary['partitions'], 2 if scanner == 'trivy' else 1)
                    self.assertEqual(len(summary['suppressed']), 1)
                    decisions = summary['suppressed'][0]['vexStatements']
                    self.assertEqual(decisions[0]['status'], 'not_affected')
                    self.assertTrue(summary['vexSha256'])


if __name__ == '__main__':
    unittest.main()
