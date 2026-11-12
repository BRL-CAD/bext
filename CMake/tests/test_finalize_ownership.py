"""Finalization attributes native and explicitly claimed files consistently."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2]


class FinalizeOwnershipTests(unittest.TestCase):
    def test_active_rules_override_native_ownership_and_inactive_rules_are_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            install, build, source, noinstall = (root / name for name in
                                                 ('install', 'build', 'source', 'noinstall'))
            for path in (install / 'man', build / 'native', source / 'CMake', noinstall):
                path.mkdir(parents=True)
            for name in ('native', 'override', 'explicit', 'stale'):
                (install / 'man' / name).write_text(name)
            (build / 'native' / 'install_manifest.txt').write_text(
                '\n'.join(str(install / 'man' / name) for name in ('native', 'override')))
            (build / 'active').write_text('native\nowner\n')
            (build / 'rules').write_text('inactive|^man/.*\nowner|^man/(override|explicit)$\n')
            (build / 'exclude').write_text('')
            (build / 'selectors').write_text('set(BEXT_SBOM_SELECTOR_IDS)\n')
            (build / 'sbom').write_text('{}')
            (source / 'CMake' / 'BextDependencyInventory.cmake').write_text(
                'function(bext_collect_dependency_inventory)\nendfunction()\n'
                'function(bext_inventory_package_records out)\n'
                '  set(${out} "" PARENT_SCOPE)\nendfunction()\n')
            variables = {
                'BEXT_INSTALL_ROOT': install, 'BEXT_MANIFEST': root / 'manifest.json',
                'BEXT_INSTALL_EXCLUDE_MANIFEST': root / 'excluded.json',
                'BEXT_COMPONENT_MANIFEST': root / 'components.json',
                'BEXT_INSTALL_EXCLUDE_RULES': build / 'exclude',
                'BEXT_COMPONENT_OWNERSHIP_RULES': build / 'rules',
                'BEXT_ACTIVE_COMPONENTS': build / 'active',
                'BEXT_SBOM_SELECTORS': build / 'selectors', 'BEXT_SBOM': build / 'sbom',
                'BEXT_SOURCE_ROOT': source, 'BEXT_BINARY_ROOT': build,
                'BEXT_NOINSTALL_ROOT': noinstall, 'BEXT_STRCLEAR': 'unused',
                'BEXT_SYSTEM_NAME': 'Linux', 'BIN_DIR': 'bin', 'LIB_DIR': 'lib',
            }
            result = subprocess.run(['cmake', *(f'-D{k}={v}' for k, v in variables.items()),
                                     '-P', str(SOURCE / 'CMake' / 'FinalizeInstall.cmake')],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            manifest = json.loads((root / 'components.json').read_text())
            self.assertEqual({item['path']: item['component'] for item in manifest['files']},
                             {'man/native': 'native', 'man/override': 'owner',
                              'man/explicit': 'owner'})
            excluded = json.loads((root / 'excluded.json').read_text())
            self.assertEqual(excluded['files'], ['man/stale'])


if __name__ == '__main__':
    unittest.main()
