#!/usr/bin/env python3
"""Offline regressions for reviewed evidence and finalized VEX generation."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE))
from BextVex import (build_purl, digest, file_digest, generate, inside,
                     json_text, read_json, split_build_purl, exported_evidence,
                     validate_catalog)
from CaptureVexEvidence import before_finalize, capture
from ProjectSbom import project_inventory
from ValidateSbom import check_parity


class VexGenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bext-vex-generation-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.install = self.root / 'install'
        self.binary = self.root / 'binary'
        self.stage = self.root / 'stage'
        self.source = self.root / 'probe' / 'source'
        for directory in (self.install / 'lib', self.binary, self.stage, self.source):
            directory.mkdir(parents=True)
        self.engine = self.stage / 'engine.c'
        self.engine.write_text('reviewed source\n')
        (self.source / 'engine.c').write_text(self.engine.read_text())
        self.git('init', '-q')
        self.git('add', 'engine.c')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-qm', 'Initial fixture')
        self.revision = self.git('rev-parse', 'HEAD').strip()
        self.patch = self.root / 'probe' / 'fix.patch'
        self.patch.write_text('reviewed patch\n')
        self.library = self.install / 'lib' / 'libz.so'
        self.library.write_bytes(b'reviewed binary fixture')
        (self.binary / 'install_manifest.txt').write_text(str(self.library) + '\n')
        self.state = self.binary / 'source-state.txt'
        self.state.write_text(self.revision + '\n' + str(self.patch) + ':' + file_digest(self.patch))
        self.source_sbom = read_json(Path(__file__).with_name('fixtures') / 'vulnerable-zlib.spdx.json')
        self.purl = self.source_sbom['packages'][0]['externalRefs'][0]['referenceLocator']
        self.review = {
            'id': 'synthetic-code-absence', 'package': 'SPDXRef-zlib',
            'sourcePurl': self.purl, 'vulnerability': 'CVE-2018-25032',
            'status': 'not_affected', 'scope': 'component',
            'justification': 'vulnerable_code_not_present',
            'impactStatement': 'Synthetic evidence fixture, not a release assertion.',
            'reviewedAt': '2026-01-01T00:00:00Z',
            'references': ['https://example.invalid/advisory'],
            'conditions': {
                'sources': {'probe/source': self.revision},
                'inputs': {'probe/fix.patch': file_digest(self.patch)},
                'requiredInputs': ['probe/fix.patch'],
                'stagedFiles': {'engine.c': file_digest(self.engine)},
                'requiredArtifacts': [['lib/libz.so']],
                'forbiddenArtifacts': ['bin/sqlite3'],
            },
        }
        self.catalog = {'schemaVersion': 1, 'component': 'probe', 'target': 'PROBE_BLD',
                        'reviews': [self.review]}
        self.catalog_path = self.root / 'probe' / 'VexReviews.json'
        self.catalog_path.write_text(json_text(self.catalog))
        self.config = {
            'component': 'probe', 'sourceRoot': str(self.root),
            'stageRoot': str(self.stage), 'buildRoot': str(self.binary),
            'installRoot': str(self.install), 'reviews': str(self.catalog_path),
            'sourceStates': [str(self.state)],
        }
        self.captured = capture(self.config)
        self.evidence = {'probe': {'component': 'probe', 'capture': self.captured,
                                   'reviews': [self.review]}}
        self.manifest = {
            'schema': 'https://brlcad.org/schema/bext-component-manifest-v2',
            'platform': 'fixture', 'files': [{'path': 'lib/libz.so', 'component': 'probe'}],
            'packages': [{'spdx_id': 'SPDXRef-zlib', 'component': 'probe', 'output': 'install'}],
        }

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.source), *args], text=True)

    def run_generation(self, **kwargs):
        return generate(self.source_sbom, self.manifest, self.install, self.evidence,
                        {}, 'fixture', 'https://example.invalid/', **kwargs)

    def assert_review_needed(self, **kwargs):
        _, vex, _, report = self.run_generation(**kwargs)
        self.assertEqual(vex['statements'][0]['status'], 'under_investigation')
        self.assertEqual(report['decisions'][0]['result'], 'review_needed')

    def test_valid_scoped_statement_and_determinism(self):
        original = copy.deepcopy(self.source_sbom)
        result = self.run_generation()
        self.assertEqual(result, self.run_generation())
        inventory, vex, exported, report = result
        self.assertEqual(self.source_sbom, original)
        product = vex['statements'][0]['products'][0]['@id']
        base, build = split_build_purl(product)
        self.assertEqual(base, self.purl)
        self.assertEqual(len(build), 64)
        self.assertEqual(product, inventory['packages'][0]['externalRefs'][0]['referenceLocator'])
        self.assertEqual(report['decisions'][0]['result'], 'applied')
        self.assertEqual(exported['components'][0]['appliedReviews'], [self.review['id']])

    def test_changed_artifact_requires_review(self):
        self.library.write_bytes(b'changed binary')
        self.assert_review_needed()

    def test_missing_capture_requires_review(self):
        self.evidence['probe']['capture'] = None
        self.assert_review_needed()

    def test_changed_source_patch_stage_and_extra_patch_require_review(self):
        changes = [
            lambda: self.captured['sources']['probe/source'].update(clean=False),
            lambda: self.captured['sources']['probe/source'].update(revision='0' * 40),
            lambda: self.captured['stagedFiles'].update({'engine.c': '0' * 64}),
            lambda: self.captured['inputs'].update({'probe/fix.patch': '0' * 64}),
            lambda: self.captured['inputs'].update({'probe/extra.patch': '0' * 64}),
            lambda: self.captured['inputs'].clear(),
        ]
        for change in changes:
            with self.subTest(change=change):
                saved = copy.deepcopy(self.captured)
                change()
                self.assert_review_needed()
                self.captured.clear()
                self.captured.update(saved)

    def test_installed_identity_must_match_review(self):
        self.review['sourcePurl'] = 'pkg:conan/zlib@1.2.10'
        self.assert_review_needed()

    def test_missing_required_artifact_and_forbidden_cli_require_review(self):
        self.review['conditions']['requiredArtifacts'] = [['lib/missing.so']]
        self.assert_review_needed()
        self.review['conditions']['requiredArtifacts'] = [['lib/libz.so']]
        path = self.install / 'bin' / 'sqlite3'
        path.parent.mkdir()
        path.write_bytes(b'CLI fixture')
        self.manifest['files'].append({'path': 'bin/sqlite3', 'component': 'probe'})
        self.assert_review_needed()

    def test_preprocessing_proof_binds_capture_and_allows_finalization(self):
        path = self.root / 'capture.json'
        path.write_text(json_text(self.captured))
        registry = {'schemaVersion': 1, 'components': [{
            'component': 'probe', 'reviews': str(self.catalog_path), 'evidence': str(path)}]}
        proof = before_finalize(registry, self.install)['components']
        self.library.write_bytes(b'finalized binary fixture')
        self.assertEqual(self.run_generation(proof=proof)[1]['statements'][0]['status'], 'not_affected')
        self.assert_review_needed()
        proof['probe']['captureDigest'] = '0' * 64
        self.assert_review_needed(proof=proof)

    def test_change_before_preprocessing_is_not_certified(self):
        self.library.write_bytes(b'changed before processing')
        proof = {'probe': {'captureDigest': digest(self.captured),
                           'artifacts': {'lib/libz.so': file_digest(self.library)}}}
        self.assert_review_needed(proof=proof)

    def test_repeated_finalization_reuses_only_verified_unchanged_bytes(self):
        path = self.root / 'capture.json'
        path.write_text(json_text(self.captured))
        registry = {'schemaVersion': 1, 'components': [{
            'component': 'probe', 'reviews': str(self.catalog_path), 'evidence': str(path)}]}
        first = before_finalize(registry, self.install)['components']
        self.library.write_bytes(b'finalized binary')
        _, _, exported, _ = self.run_generation(proof=first)
        second = before_finalize(registry, self.install, exported)['components']
        self.assertEqual(self.run_generation(proof=second)[1]['statements'][0]['status'], 'not_affected')
        self.library.write_bytes(b'tampered finalized binary')
        third = before_finalize(registry, self.install, exported)['components']
        self.assert_review_needed(proof=third)

    def test_no_installed_review_does_not_emit_empty_openvex(self):
        self.manifest['packages'].clear()
        inventory, vex, _, report = self.run_generation()
        self.assertIsNone(vex)
        self.assertFalse(inventory['packages'])
        self.assertEqual(report['decisions'][0]['result'], 'not_installed')

    def test_noinstall_package_is_not_part_of_build_inventory(self):
        self.manifest['packages'][0]['output'] = 'noinstall'
        self.assertFalse(self.run_generation()[0]['packages'])

    def test_downstream_import_verifies_bytes_and_remapped_package(self):
        _, _, exported, _ = self.run_generation()
        self.evidence = exported_evidence(exported)
        self.source_sbom['packages'][0]['SPDXID'] = 'SPDXRef-downstream'
        self.source_sbom['relationships'][0]['relatedSpdxElement'] = 'SPDXRef-downstream'
        self.manifest['packages'][0].update(spdx_id='SPDXRef-downstream', source_spdx_id='SPDXRef-zlib')
        self.assertEqual(self.run_generation(imported=True)[1]['statements'][0]['status'], 'not_affected')
        self.library.write_bytes(b'different downstream library')
        self.assert_review_needed(imported=True)

    def test_import_cannot_promote_an_unproven_export(self):
        self.captured['installedArtifacts'].clear()
        _, _, exported, _ = self.run_generation()
        self.evidence = exported_evidence(exported)
        self.assert_review_needed(imported=True)

    def test_product_review_does_not_transfer_to_another_product(self):
        context = self.run_generation()[3]['productContext']
        self.review.update(scope='product', product='fixture')
        self.review['conditions']['productContext'] = context
        _, vex, exported, _ = self.run_generation()
        self.assertEqual(vex['statements'][0]['status'], 'not_affected')
        self.evidence = exported_evidence(exported)
        self.assert_review_needed(imported=True)

    def test_qualified_projection_keeps_scope(self):
        inventory, vex, _, _ = self.run_generation()
        source_purl = 'pkg:github/madler/zlib@v1.2.11'
        build_id = split_build_purl(inventory['packages'][0]['externalRefs'][0]['referenceLocator'])[1]
        inventory['packages'][0]['externalRefs'][0]['referenceLocator'] = build_purl(source_purl, build_id)
        alias = {'sourcePurl': source_purl, 'targetPurl': self.purl,
                 'evidence': ['https://example.invalid/recipe'], 'reason': 'Fixture'}
        projected, _ = project_inventory(inventory, {source_purl: alias}, 'fixture', '0' * 64)
        first = projected['packages'][0]['externalRefs'][0]['referenceLocator']
        self.assertEqual(first, vex['statements'][0]['products'][0]['@id'])

    def test_path_escape_and_ambiguous_build_qualifier_are_rejected(self):
        for name in ('../escape', '/absolute', 'a/../b', 'C:/escape'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                inside(self.install, name)
        with self.assertRaises(ValueError):
            split_build_purl(self.purl + '?bext_build=a&bext_build=b')
        qualified = build_purl('pkg:generic/thing@1?download_url=https%3A%2F%2Fexample.invalid%2Fsrc#part', 'a' * 64)
        self.assertEqual(split_build_purl(qualified),
                         ('pkg:generic/thing@1?download_url=https%3A%2F%2Fexample.invalid%2Fsrc#part', 'a' * 64))

    def test_capture_detects_changed_inputs_and_dirty_sources(self):
        self.patch.write_text('changed patch')
        self.assertTrue(capture(self.config)['errors'])
        (self.source / 'engine.c').write_text('dirty source')
        self.assertFalse(capture(self.config)['sources']['probe/source']['clean'])

    def test_malformed_reviews_and_exported_evidence_are_rejected(self):
        for field, value in [('status', []), ('requiredInputs', [{}]),
                             ('requiredArtifacts', 'lib/*')]:
            catalog = copy.deepcopy(self.catalog)
            target = catalog['reviews'][0]
            if field != 'status':
                target = target['conditions']
            target[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_catalog(catalog)
        _, _, exported, _ = self.run_generation()
        for field, value in [('files', [{'path': '../escape', 'sha256': 'a' * 64}]),
                             ('appliedReviews', ['unknown']), ('capture', None)]:
            document = copy.deepcopy(exported)
            document['components'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                exported_evidence(document)
        duplicate = self.root / 'duplicate.json'
        duplicate.write_text('{"schemaVersion": 1, "schemaVersion": 2}')
        with self.assertRaises(ValueError):
            read_json(duplicate)

    def test_cli_outputs_formats_and_removes_stale_assertions_on_error(self):
        output = self.root / 'output'
        source = self.root / 'source.json'
        manifest = self.root / 'manifest.json'
        registry = self.root / 'registry.json'
        receipt = self.root / 'receipt.json'
        source.write_text(json_text(self.source_sbom))
        manifest.write_text(json_text(self.manifest))
        receipt.write_text(json_text(self.captured))
        registry.write_text(json_text({'schemaVersion': 1, 'components': [{
            'component': 'probe', 'reviews': str(self.catalog_path), 'evidence': str(receipt)}]}))
        command = [sys.executable, str(MODULE / 'GenerateVex.py'), '--sbom', str(source),
                   '--manifest', str(manifest), '--registry', str(registry),
                   '--install-root', str(self.install), '--output-dir', str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        spdx, cdx = read_json(output / 'bext.build.spdx.json'), read_json(output / 'bext.build.cdx.json')
        check_parity(spdx, cdx)
        self.assertEqual(cdx['metadata']['lifecycles'], [{'phase': 'post-build'}])
        self.assertTrue((output / 'bext.openvex.json').exists())
        manifest.write_text(json_text({**self.manifest, 'packages': [], 'files': []}))
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((output / 'bext.openvex.json').exists())
        check_parity(read_json(output / 'bext.build.spdx.json'), read_json(output / 'bext.build.cdx.json'))
        manifest.write_text(json_text(self.manifest))
        self.catalog['reviews'][0]['status'] = 'invalid'
        self.catalog_path.write_text(json_text(self.catalog))
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((output / 'bext.openvex.json').exists())
        self.assertFalse((output / 'bext-vex-evidence.json').exists())


if __name__ == '__main__':
    unittest.main()
