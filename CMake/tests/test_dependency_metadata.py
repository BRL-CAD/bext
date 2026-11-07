#!/usr/bin/env python3
"""Offline checks for committed and staged dependency metadata snapshots."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]


class DependencyMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bext-metadata-test-')
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Metadata Test')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.source / 'seed').write_text('Initial source revision\n')
        self.git('add', 'seed')
        self.git('commit', '-qm', 'Seed')
        self.first = self.git('rev-parse', 'HEAD').strip()
        modules = self.source / 'CMake'
        modules.mkdir()
        for name in ('BextDependencyInventory.cmake', 'GenerateDependencyDocs.cmake',
                     'GenerateSbom.cmake', 'ValidateSbom.cmake',
                     'BextSbomJson.cmake', 'BextCycloneDx.cmake'):
            shutil.copyfile(MODULE / name, modules / name)
        (self.source / 'CMakeLists.txt').write_text('add_project(probe GROUPS "BRLCAD;APPLESEED")\n')
        (self.source / '.gitmodules').write_text(
            '[submodule "probe/source"]\n\tpath = probe/source\n'
            '\turl = https://example.invalid/probe\n')
        self.wrapper('probe')
        (self.source / 'DEPENDENCIES.md').write_text(
            '# Dependencies\n\n<!-- BEGIN GENERATED PROJECT TABLE -->\n'
            '<!-- END GENERATED PROJECT TABLE -->\n')
        self.git('add', '.')
        self.pin('probe', self.first)
        self.docs('INDEX', 'WRITE')
        self.git('add', 'DEPENDENCIES.md')
        self.git('commit', '-qm', 'Integrate probe')
        self.second = self.git('rev-parse', 'HEAD').strip()

    def command(self, *args, success=True, input=None):
        result = subprocess.run([str(arg) for arg in args], cwd=self.source,
                                input=input, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def git(self, *args, **kwargs):
        return self.command('git', *args, **kwargs)

    def pin(self, project, revision):
        self.git('update-index', '--add', '--cacheinfo', f'160000,{revision},{project}/source')

    def wrapper(self, name):
        directory = self.source / name
        directory.mkdir()
        (directory / 'BextPackage.cmake').write_text(
            f'bext_package({name} OUTPUT install GROUPS BRLCAD APPLESEED)\n'
            f'bext_sbom_component("{name}/source")\n')
        (directory / 'CMakeLists.txt').write_text('''
git_submodule_init(source CMakeLists.txt)
ExternalProject_Add(PROBE_BLD
 CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX})
# License destination: DOC_LICENSE_DIR
''')
        (directory / (name + '.deps')).write_text('')

    def docs(self, mode='HEAD', action='CHECK', success=True):
        return self.command('cmake', f'-DBEXT_SOURCE_DIR={self.source}',
                            f'-DBEXT_INVENTORY_MODE={mode}', f'-DBEXT_DOC_MODE={action}',
                            '-P', MODULE / 'GenerateDependencyDocs.cmake', success=success)

    def inventory(self, mode, success=True):
        script = self.source / 'inventory.cmake'
        script.write_text('''
cmake_minimum_required(VERSION 3.26)
include("@MODULE@/BextDependencyInventory.cmake")
bext_collect_dependency_inventory("@SOURCE@")
foreach(project ${BEXT_INVENTORY_PROJECTS})
  bext_inventory_get(shas "${project}" SOURCE_SHAS)
  message(STATUS "PIN=${project}|${shas}")
endforeach()
'''.replace('@MODULE@', MODULE.as_posix()).replace('@SOURCE@', self.source.as_posix()))
        return self.command('cmake', f'-DBEXT_INVENTORY_MODE={mode}', '-P', script,
                            success=success)

    def test_index_uses_staged_pin_and_head_keeps_committed_pin(self):
        self.pin('probe', self.second)
        self.assertIn('PIN=probe|' + self.second, self.inventory('INDEX'))
        self.assertIn('PIN=probe|' + self.first, self.inventory('HEAD'))

    def test_new_submodule_validates_before_commit_without_checkout(self):
        self.wrapper('newdep')
        with (self.source / 'CMakeLists.txt').open('a') as output:
            output.write('add_project(newdep GROUPS "BRLCAD")\n')
        with (self.source / '.gitmodules').open('a') as output:
            output.write('[submodule "newdep/source"]\n\tpath = newdep/source\n'
                         '\turl = https://example.invalid/newdep\n')
        self.git('add', 'CMakeLists.txt', '.gitmodules', 'newdep')
        self.assertIn('its gitlink', self.inventory('INDEX', success=False))
        self.pin('newdep', self.second)
        self.assertIn('PIN=newdep|' + self.second, self.inventory('INDEX'))
        self.assertNotIn('PIN=newdep', self.inventory('HEAD'))
        self.assertIn('stale in INDEX', self.docs('INDEX', success=False))
        self.docs('INDEX', 'WRITE')
        # Generated prose must be staged before the staged check accepts it.
        self.docs('INDEX', success=False)
        self.git('add', 'DEPENDENCIES.md')
        self.docs('INDEX')
        self.docs('HEAD')

    def test_staged_inputs_are_isolated_from_unstaged_edits(self):
        with (self.source / '.gitmodules').open('w') as output:
            output.write('[submodule "probe/source"]\n\tpath = probe/source\n'
                         '\turl = https://example.invalid/changed\n')
        self.git('add', '.gitmodules')
        (self.source / 'CMakeLists.txt').write_text('add_project(missing GROUPS "INVALID")\n')
        (self.source / 'probe/CMakeLists.txt').write_text('broken wrapper\n')
        (self.source / 'probe/probe.deps').write_text('UNKNOWN\n')
        (self.source / '.gitmodules').write_text('unstaged invalid metadata\n')
        self.assertIn('PIN=probe|' + self.first, self.inventory('INDEX'))
        self.docs('INDEX', 'WRITE')
        content = (self.source / 'DEPENDENCIES.md').read_text()
        self.assertIn('https://example.invalid/changed', content)
        self.assertIn('`USE_BRLCAD`, `USE_APPLESEED`', content)
        self.git('add', 'DEPENDENCIES.md')
        self.docs('INDEX')
        self.docs('HEAD')

    def test_descriptors_and_license_evidence_use_the_selected_snapshot(self):
        evidence = self.source / 'probe/license.txt'
        license_text = 'Reviewed probe license \N{COPYRIGHT SIGN}\n'
        evidence.write_text(license_text, encoding='utf-8', newline='')
        digest = hashlib.sha256(license_text.encode()).hexdigest()
        descriptor = self.source / 'probe/BextPackage.cmake'
        descriptor.write_text(
            'bext_package(probe OUTPUT install GROUPS BRLCAD APPLESEED)\n'
            'bext_sbom_component("probe/source" NAME "Reviewed probe"\n'
            ' LICENSE "LicenseRef-Probe" LICENSE_NAME "Probe terms"\n'
            ' LICENSE_FILE "@/probe/license.txt"\n'
            f' LICENSE_SHA256 "{digest}" REVIEWED_REVISION "{self.first}")\n')
        self.git('add', 'probe/BextPackage.cmake', 'probe/license.txt')
        # INDEX uses staged descriptors and evidence even when they are absent
        # or invalid in the working tree. HEAD still uses the old descriptor.
        descriptor.write_text('invalid unstaged descriptor\n')
        evidence.unlink()
        self.inventory('INDEX')
        self.inventory('HEAD')
        self.git('commit', '-qm', 'Review probe license')
        output = self.source / 'sbom.json'
        cyclonedx_output = self.source / 'sbom.cdx.json'
        self.command('cmake', f'-DBEXT_SOURCE_DIR={self.source}',
                     f'-DBEXT_SBOM_OUTPUT={output}', '-DBEXT_SBOM_ALLOW_DIRTY=ON',
                     f'-DBEXT_CYCLONEDX_OUTPUT={cyclonedx_output}',
                     '-P', MODULE / 'GenerateSbom.cmake')
        document = json.loads(output.read_text(encoding='utf-8'))
        self.assertEqual(document['packages'][0]['name'], 'Reviewed probe')
        self.assertEqual(document['hasExtractedLicensingInfos'][0]['extractedText'],
                         license_text)
        cyclonedx = json.loads(cyclonedx_output.read_text())
        self.assertEqual(cyclonedx['components'][0]['name'], 'Reviewed probe')
        self.assertEqual(cyclonedx['components'][0]['evidence']['licenses'][0]
                         ['license']['text']['content'], license_text)

    def test_local_license_snapshot_requires_current_reviewed_revision(self):
        evidence = self.source / 'probe/license.txt'
        license_text = 'Reviewed probe license\n'
        evidence.write_text(license_text, newline='')
        digest = hashlib.sha256(license_text.encode()).hexdigest()
        descriptor = self.source / 'probe/BextPackage.cmake'
        metadata = (
            'bext_package(probe OUTPUT install GROUPS BRLCAD APPLESEED)\n'
            'bext_sbom_component("probe/source" LICENSE "LicenseRef-Probe"\n'
            ' LICENSE_NAME "Probe terms" LICENSE_FILE "@/probe/license.txt"\n'
            f' LICENSE_SHA256 "{digest}"{{}})\n')
        descriptor.write_text(metadata.format(''))
        self.git('add', 'probe/BextPackage.cmake', 'probe/license.txt')
        message = self.inventory('INDEX', success=False)
        self.assertIn('Repository-local license evidence', message)
        self.assertIn('REVIEWED_REVISION', message)

        descriptor.write_text(metadata.format(f' REVIEWED_REVISION "{self.first}"'))
        self.git('add', 'probe/BextPackage.cmake')
        self.inventory('INDEX')
        self.pin('probe', self.second)
        self.assertIn('but the pinned source is', self.inventory('INDEX', success=False))

    def test_unmerged_gitlink_is_rejected(self):
        self.git('update-index', '--force-remove', 'probe/source')
        self.git('update-index', '--index-info', input=(
            f'160000 {self.first} 1\tprobe/source\n'
            f'160000 {self.second} 2\tprobe/source\n'
            f'160000 {self.first} 3\tprobe/source\n'))
        self.assertIn('Unable to read pinned commit', self.inventory('INDEX', success=False))

    def test_sbom_uses_only_committed_metadata_and_rejects_index_mode(self):
        self.pin('probe', self.second)
        (self.source / 'CMakeLists.txt').write_text('add_project(missing)\n')
        self.git('add', 'CMakeLists.txt')
        output = self.source / 'sbom.json'
        self.command('cmake', f'-DBEXT_SOURCE_DIR={self.source}',
                     f'-DBEXT_SBOM_OUTPUT={output}', '-DBEXT_SBOM_ALLOW_DIRTY=ON',
                     '-P', MODULE / 'GenerateSbom.cmake')
        document = json.loads(output.read_text())
        self.assertIn('/' + self.second + '-dirty-', document['documentNamespace'])
        self.assertEqual(document['packages'][0]['versionInfo'], self.first)
        self.assertEqual(document['packages'][0]['name'], 'probe')
        message = self.command('cmake', f'-DBEXT_SOURCE_DIR={self.source}',
                               f'-DBEXT_SBOM_OUTPUT={output}', '-DBEXT_INVENTORY_MODE=INDEX',
                               '-P', MODULE / 'GenerateSbom.cmake', success=False)
        self.assertIn('requires BEXT_INVENTORY_MODE=HEAD', message)

    def test_invalid_inventory_mode_is_rejected(self):
        self.assertIn('expected HEAD or INDEX', self.inventory('WORKTREE', success=False))

    def test_sbom_target_refreshes_after_a_commit_changes_only_the_pin(self):
        # Use the production target so dependency freshness is tested, too.
        top = (MODULE.parent / 'CMakeLists.txt').read_text()
        start = top.index('add_custom_target(sbom\n')
        target = top[start:top.index('\n)\n', start) + 3]
        (self.source / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(sbom_fixture NONE)
function(add_project)
endfunction()
add_project(probe GROUPS "BRLCAD;APPLESEED")
set(BEXT_SBOM_OUTPUT "${CMAKE_BINARY_DIR}/bext.spdx.json")
set(BEXT_CYCLONEDX_OUTPUT "${CMAKE_BINARY_DIR}/bext.cdx.json")
set(BEXT_SBOM_ALLOW_DIRTY ON)
''' + target)
        self.git('add', 'CMakeLists.txt')
        self.git('commit', '-qm', 'Add production SBOM target')
        build = self.source / 'build'
        self.command('cmake', '-S', self.source, '-B', build, '-G', 'Ninja')
        self.command('cmake', '--build', build, '--target', 'sbom')
        first = json.loads((build / 'bext.spdx.json').read_text())
        first_cyclonedx = json.loads((build / 'bext.cdx.json').read_text())
        self.pin('probe', self.second)
        self.git('commit', '-qm', 'Update only the dependency pin')
        self.command('cmake', '--build', build, '--target', 'sbom')
        second = json.loads((build / 'bext.spdx.json').read_text())
        second_cyclonedx = json.loads((build / 'bext.cdx.json').read_text())
        self.assertNotEqual(first['documentNamespace'], second['documentNamespace'])
        self.assertEqual(second['packages'][0]['versionInfo'], self.second)
        self.assertNotEqual(first_cyclonedx['serialNumber'], second_cyclonedx['serialNumber'])
        self.assertEqual(second_cyclonedx['components'][0]['version'], self.second)
        self.assertIn('/' + self.git('rev-parse', 'HEAD').strip(), second['documentNamespace'])


if __name__ == '__main__':
    unittest.main()
