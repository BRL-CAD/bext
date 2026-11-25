"""The complete source inventory must not depend on initialized submodules."""

import json
import shutil
import unittest

from dependency_test_support import dependency_test_modules
from source_inventory_fixture import SOURCE, SourceInventoryFixture


class SourceInventoryCheckoutTests(SourceInventoryFixture):
    def test_regression_outputs_describe_the_original_tree(self):
        sentinel = self.repository / 'sbom-dirty-provenance-test.tmp'
        sentinel.write_text('user data\n', encoding='utf-8')
        self.command('cmake', f'-DBEXT_SOURCE_DIR={self.repository}',
                     f'-DBEXT_SBOM_OUTPUT={self.spdx}',
                     f'-DBEXT_CYCLONEDX_OUTPUT={self.cyclonedx}',
                     '-P', SOURCE / 'CMake/TestSbom.cmake')
        namespace = json.loads(self.spdx.read_text())['documentNamespace']
        self.assertEqual(json.loads(self.cyclonedx.read_text())['metadata']['component']['bom-ref'],
                         namespace)
        self.assertEqual(sentinel.read_text(encoding='utf-8'), 'user data\n')
        self.assertEqual(list(self.repository.glob('sbom-dirty-provenance-*.tmp')), [sentinel])
        self.command('cmake', f'-DBEXT_SOURCE_DIR={self.repository}',
                     f'-DBEXT_SBOM_OUTPUT={self.spdx}', '-DBEXT_SBOM_ALLOW_DIRTY=ON',
                     '-P', SOURCE / 'CMake/GenerateSbom.cmake')
        self.assertEqual(json.loads(self.spdx.read_text())['documentNamespace'], namespace)

    def test_inventory_is_identical_with_absent_partial_and_available_metadata(self):
        self.generate()
        baseline = (self.spdx.read_bytes(), self.cyclonedx.read_bytes())
        self.command('cmake', f'-DBEXT_SBOM_INPUT={self.spdx}', '-P', SOURCE / 'CMake/ValidateSbom.cmake')
        providers = [(module.__name__, module.populate_inventory_sources)
                     for module in dependency_test_modules()
                     if hasattr(module, 'populate_inventory_sources')]
        cases = [(name, [populate]) for name, populate in providers]
        cases.extend([('all', [populate for _, populate in providers]), ('none', [])])
        for name, populate_sources in cases:
            with self.subTest(checkouts=name):
                for submodule in self.submodules:
                    path = self.repository / submodule
                    shutil.rmtree(path)
                    path.mkdir()
                for populate in populate_sources:
                    populate(self)
                self.assertEqual(self.git('status', '--porcelain'), '')
                self.generate()
                self.assertEqual((self.spdx.read_bytes(), self.cyclonedx.read_bytes()), baseline)


if __name__ == '__main__':
    unittest.main()
