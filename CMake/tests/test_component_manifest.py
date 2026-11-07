#!/usr/bin/env python3
"""Validate the finalized component-manifest contract used by VEX consumers."""

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE))
from ValidateSbom import validate_component_manifest


@unittest.skipUnless(importlib.util.find_spec('jsonschema'), 'Install the SBOM validation requirements')
class ComponentManifestTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-component-schema-')
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / 'manifest.json'
        self.package = {'component': 'probe', 'id': 'probe/source',
                        'spdx_id': 'SPDXRef-Package-probe-source',
                        'primary': True, 'output': 'install'}
        self.document = {
            'schema': 'https://brlcad.org/schema/bext-component-manifest-v2',
            'platform': 'fixture', 'install_root': 'install', 'generated_by': 'bext',
            'files': [{'path': 'lib/probe', 'component': 'probe'}],
            'packages': [self.package],
        }

    def validate(self):
        self.path.write_text(json.dumps(self.document))
        validate_component_manifest(self.path)

    def test_installed_and_build_only_packages(self):
        for output in ('install', 'noinstall'):
            with self.subTest(output=output):
                self.package['output'] = output
                self.validate()

    def test_missing_unknown_and_misspelled_output_scope_are_rejected(self):
        for value in ('missing', 'typo', None):
            with self.subTest(value=value):
                self.package.pop('output', None)
                if value != 'missing':
                    self.package['output'] = value
                with self.assertRaises(ValueError):
                    self.validate()

    def test_downstream_package_remapping_preserves_original_identity(self):
        self.document['generated_by'] = 'brlcad'
        self.package['source_spdx_id'] = self.package['spdx_id']
        self.package['spdx_id'] = 'SPDXRef-imported'
        self.validate()
        self.package['source_spdx_id'] = 'invalid identity'
        with self.assertRaises(ValueError):
            self.validate()


if __name__ == '__main__':
    unittest.main()
