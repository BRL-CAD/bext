#!/usr/bin/env python3
"""Offline regressions for source SBOM formats and advisory projections."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE))
from ProjectSbom import project_inventory, read_aliases
from ValidateSbom import check_parity, component_index


def source_inventory():
    packages = []
    for name in ('parent', 'child', 'nested'):
        packages.append({
            'SPDXID': 'SPDXRef-' + name, 'name': name, 'versionInfo': '1.0',
            'downloadLocation': f'https://example.invalid/{name}/source.tar.gz',
            'filesAnalyzed': False, 'primaryPackagePurpose': 'LIBRARY',
            'licenseDeclared': 'MIT AND LicenseRef-Custom',
            'licenseConcluded': 'NOASSERTION', 'copyrightText': 'NOASSERTION',
            'packageSourceInfo': 'Upstream source at a pinned revision',
            'comment': 'Quotes " and slash \\; tabs\t and newlines\nUnicode: café',
            'externalRefs': [{'referenceCategory': 'PACKAGE-MANAGER',
                              'referenceType': 'purl',
                              'referenceLocator': f'pkg:github/example/{name}@v1.0'}],
        })
    return {
        'spdxVersion': 'SPDX-2.3', 'dataLicense': 'CC0-1.0',
        'SPDXID': 'SPDXRef-DOCUMENT', 'name': 'bext-dependencies',
        'documentNamespace': 'https://example.invalid/sbom/revision/inventory',
        'creationInfo': {'created': '2026-01-01T00:00:00Z',
                         'creators': ['Tool: bext-GenerateSbom.cmake']},
        'packages': packages,
        'hasExtractedLicensingInfos': [
            {'licenseId': 'LicenseRef-Custom', 'name': 'Custom "license"',
             'extractedText': 'Custom license; preserve \\ and " and\nnewlines.'}],
        'relationships': [
            {'spdxElementId': 'SPDXRef-DOCUMENT', 'relationshipType': 'DESCRIBES',
             'relatedSpdxElement': 'SPDXRef-' + name}
            for name in ('parent', 'child', 'nested')
        ] + [
            {'spdxElementId': 'SPDXRef-parent', 'relationshipType': 'CONTAINS',
             'relatedSpdxElement': 'SPDXRef-child'},
            {'spdxElementId': 'SPDXRef-child', 'relationshipType': 'CONTAINS',
             'relatedSpdxElement': 'SPDXRef-nested'},
            {'spdxElementId': 'SPDXRef-nested', 'relationshipType': 'DEPENDS_ON',
             'relatedSpdxElement': 'SPDXRef-parent'},
        ],
    }


class SbomFormatTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-sbom-test-')
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.inventory = source_inventory()
        self.input = self.directory / 'source.spdx.json'
        self.output = self.directory / 'source.cdx.json'
        self.script = self.directory / 'emit.cmake'
        self.script.write_text(
            'cmake_minimum_required(VERSION 3.26)\n'
            f'include("{MODULE / "BextCycloneDx.cmake"}")\n'
            f'file(READ "{self.input}" inventory)\n'
            f'bext_write_cyclonedx("{self.output}" "${{inventory}}")\n')

    def emit(self, success=True):
        self.input.write_text(json.dumps(self.inventory))
        result = subprocess.run(['cmake', '-P', str(self.script)], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if not success:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            return result.stdout
        self.assertEqual(result.returncode, 0, result.stdout)
        return json.loads(self.output.read_text())

    def test_identity_evidence_hierarchy_and_graph_parity(self):
        bom = self.emit()
        self.assertEqual(check_parity(self.inventory, bom), (3, 1, 2))
        self.assertEqual(len(bom['components']), 1)
        dependency = next(item for item in bom['dependencies']
                          if item['ref'] == 'SPDXRef-parent')
        self.assertEqual(dependency['dependsOn'], [])

    def test_reproducible_output_and_source_aggregate_type(self):
        self.inventory['packages'][0]['primaryPackagePurpose'] = 'CONTAINER'
        first = self.emit()
        self.assertEqual(first['components'][0]['type'], 'library')
        first_bytes = self.output.read_bytes()
        self.emit()
        self.assertEqual(first_bytes, self.output.read_bytes())

    def test_scanner_positive_control_has_no_dependency_or_license_evidence(self):
        fixture = MODULE / 'tests/fixtures/vulnerable-zlib.spdx.json'
        self.inventory = json.loads(fixture.read_text())
        bom = self.emit()
        self.assertEqual(check_parity(self.inventory, bom), (1, 0, 0))

    def test_unknown_and_absent_license_assertions(self):
        for package in self.inventory['packages']:
            package['licenseDeclared'] = 'NOASSERTION'
            package['licenseConcluded'] = 'NONE'
        bom = self.emit()
        for component in component_index(bom)[0].values():
            self.assertNotIn('licenses', component)
            self.assertNotIn('evidence', component)
        check_parity(self.inventory, bom)

    def test_reject_containment_cycle(self):
        self.inventory['relationships'].append({
            'spdxElementId': 'SPDXRef-nested', 'relationshipType': 'CONTAINS',
            'relatedSpdxElement': 'SPDXRef-parent'})
        self.assertIn('Cyclic SBOM containment', self.emit(success=False))

    def test_reject_multiple_parents_and_unknown_endpoints(self):
        self.inventory['relationships'].append({
            'spdxElementId': 'SPDXRef-parent', 'relationshipType': 'CONTAINS',
            'relatedSpdxElement': 'SPDXRef-nested'})
        self.assertIn('Multiple containment parents', self.emit(success=False))
        self.inventory['relationships'][-1]['relatedSpdxElement'] = 'SPDXRef-missing'
        self.assertIn('Unknown SBOM relationship endpoint', self.emit(success=False))

    def test_parity_detects_missing_edges_and_changed_identity(self):
        bom = self.emit()
        changed = copy.deepcopy(bom)
        next(item for item in changed['dependencies']
             if item['ref'] == 'SPDXRef-nested')['dependsOn'] = []
        with self.assertRaisesRegex(ValueError, 'dependency edges differ'):
            check_parity(self.inventory, changed)
        bom['components'][0]['purl'] = 'pkg:github/example/different@v1.0'
        with self.assertRaisesRegex(ValueError, 'purl differs'):
            check_parity(self.inventory, bom)

    def aliases(self):
        return {'pkg:github/example/parent@v1.0': {
            'sourcePurl': 'pkg:github/example/parent@v1.0',
            'targetPurl': 'pkg:conan/parent@1.0',
            'evidence': ['https://example.invalid/recipe/revision'],
            'reason': 'The recipe identifies the same upstream release',
        }}

    def test_spdx_projection_preserves_input_and_original_purl(self):
        self.inventory['packages'][0]['name'] = 'Parent Library'
        original = copy.deepcopy(self.inventory)
        projected, report = project_inventory(self.inventory, self.aliases(), 'conan', 'hash')
        self.assertEqual(original, self.inventory)
        self.assertEqual(report['mappedPackages'], 1)
        self.assertEqual(report['unmappedPackages'], 2)
        references = projected['packages'][0]['externalRefs']
        self.assertEqual(references[0]['referenceLocator'], 'pkg:conan/parent@1.0')
        self.assertEqual(references[1], original['packages'][0]['externalRefs'][0])
        self.assertEqual(projected['packages'][0]['name'], 'parent')
        self.assertEqual(report['mapped'][0]['sourceName'], 'Parent Library')
        self.assertNotEqual(projected['documentNamespace'], original['documentNamespace'])
        with self.assertRaisesRegex(ValueError, 'already a scanner projection'):
            project_inventory(projected, self.aliases(), 'conan', 'hash')

    def test_cyclonedx_projection_preserves_nested_packages(self):
        bom = self.emit()
        original = copy.deepcopy(bom)
        projected, report = project_inventory(bom, self.aliases(), 'conan', 'hash')
        self.assertEqual(bom, original)
        self.assertEqual(component_index(projected)[0].keys(), component_index(bom)[0].keys())
        self.assertEqual(len(projected['components']), 3)
        self.assertTrue(all('components' not in item for item in projected['components']))
        self.assertEqual(component_index(projected)[1], component_index(bom)[1])
        self.assertEqual(projected['dependencies'][:-1], bom['dependencies'][:-1])
        self.assertEqual(report['mappedPackages'], 1)
        properties = projected['components'][0]['properties']
        self.assertIn({'name': 'bext:source:purl',
                       'value': 'pkg:github/example/parent@v1.0'}, properties)
        projected_spdx, _ = project_inventory(self.inventory, self.aliases(), 'conan', 'hash')
        self.assertEqual(check_parity(projected_spdx, projected), (3, 1, 2))

    def test_projection_rejects_version_guessing(self):
        aliases = self.aliases()
        aliases[next(iter(aliases))]['targetPurl'] = 'pkg:conan/parent@2.0'
        with self.assertRaisesRegex(ValueError, 'alias version differs'):
            project_inventory(self.inventory, aliases, 'conan', 'hash')

    def test_alias_table_rejects_ambiguity_missing_evidence_and_profiles(self):
        path = self.directory / 'aliases.json'
        alias = next(iter(self.aliases().values()))
        data = {'schemaVersion': 1, 'profiles': {'conan': ['conan']}, 'aliases': [alias]}
        path.write_text(json.dumps(data))
        self.assertEqual(len(read_aliases(path, 'conan')[0]), 1)
        with self.assertRaisesRegex(ValueError, 'Unknown or empty alias profile'):
            read_aliases(path, 'missing')
        data['aliases'].append(alias)
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'Ambiguous alias'):
            read_aliases(path, 'conan')
        data['aliases'] = [{**alias, 'evidence': []}]
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'requires evidence'):
            read_aliases(path, 'conan')

    def test_dependency_alias_discovery_deduplicates_and_rejects_conflicts(self):
        root = self.directory / 'catalogs'
        (root / 'CMake').mkdir(parents=True)
        (root / 'CMake/SbomScanProfiles.json').write_text(json.dumps({
            'schemaVersion': 1, 'profiles': {'conan': ['conan']}}))
        alias = next(iter(self.aliases().values()))
        for owner in ('first', 'second'):
            (root / owner).mkdir()
            (root / owner / 'SbomScanAliases.json').write_text(json.dumps({
                'schemaVersion': 1, 'aliases': [alias]}))
        actual, original_digest = read_aliases(root, 'conan')
        self.assertEqual(actual, self.aliases())
        (root / 'second/SbomScanAliases.json').unlink()
        self.assertEqual(read_aliases(root, 'conan')[1], original_digest)
        changed = {**alias, 'targetPurl': 'pkg:conan/different@1.0'}
        (root / 'second/SbomScanAliases.json').write_text(json.dumps({
            'schemaVersion': 1, 'aliases': [changed]}))
        with self.assertRaisesRegex(ValueError, 'Ambiguous alias'):
            read_aliases(root, 'conan')


if __name__ == '__main__':
    unittest.main()
