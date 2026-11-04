#!/usr/bin/env python3
"""Offline checks for optional source snapshots and dependency profiles."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2]
REVISION = '0123456789abcdef0123456789abcdef01234567'


class DependencySelectionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bext-selection-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.wrapper = self.source / 'probe'
        self.wrapper.mkdir(parents=True)
        self.build = self.root / 'build'
        (self.source / '.gitmodules').write_text('')
        (self.source / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(selection NONE)
include(ExternalProject)
include("@SOURCE@/CMake/Utils.cmake")
option(USE_BRLCAD "BRL-CAD dependencies" ON)
set(CMAKE_BUNDLE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")
set(DOC_LICENSE_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/share/doc/legal/other")
add_project(probe GROUPS "BRLCAD")
if(TARGET PROBE_BLD)
  file(WRITE "${CMAKE_BINARY_DIR}/selected.txt" "ON")
else()
  file(WRITE "${CMAKE_BINARY_DIR}/selected.txt" "OFF")
endif()
bext_print_configure_summary()
'''.replace('@SOURCE@', SOURCE.as_posix()))
        (self.wrapper / 'CMakeLists.txt').write_text('''
bext_local_source(PROBE snapshot https://example.invalid/probe @REVISION@)
if(ENABLE_PROBE)
  ExternalProject_Add(PROBE_BLD
    URL "${CMAKE_CURRENT_SOURCE_DIR}/snapshot"
    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    STEP_TARGETS install
  )
  configure_file(snapshot/LICENSE "${DOC_LICENSE_DIR}/probe.txt" COPYONLY)
endif()
'''.replace('@REVISION@', REVISION))

    def run_command(self, *command):
        result = subprocess.run([str(item) for item in command],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def snapshot(self):
        upstream = self.wrapper / 'snapshot'
        upstream.mkdir()
        (upstream / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(snapshot NONE)
install(FILES payload DESTINATION share/probe)
''')
        (upstream / 'payload').write_text('local snapshot artifact\n')
        (upstream / 'LICENSE').write_text('local snapshot license\n')

    def configure(self, selected, *options):
        output = self.run_command('cmake', '-S', self.source, '-B', self.build, *options)
        self.assertEqual((self.build / 'selected.txt').read_text(), selected, output)
        local_projects = next(line for line in output.splitlines() if '  local builds:' in line)
        self.assertEqual(local_projects.split(': ', 1)[1], 'probe' if selected == 'ON' else 'none')
        return output

    def test_source_can_appear_disappear_and_return_with_enable_all(self):
        self.configure('OFF', '-DENABLE_ALL=ON')
        self.snapshot()
        self.configure('ON')
        self.run_command('cmake', '--build', self.build, '--target', 'PROBE_BLD')
        self.assertEqual((self.build / 'install/share/probe/payload').read_text(),
                         'local snapshot artifact\n')
        shutil.rmtree(self.wrapper / 'snapshot')
        self.configure('OFF')
        self.snapshot()
        self.configure('ON')

    def test_explicit_off_survives_availability_changes_and_enable_all(self):
        self.configure('OFF', '-DENABLE_PROBE=OFF', '-DENABLE_ALL=ON')
        self.snapshot()
        self.configure('OFF')
        self.assertIn('ENABLE_PROBE:BOOL=OFF', (self.build / 'CMakeCache.txt').read_text())
        self.configure('ON', '-DENABLE_PROBE=ON')

    def test_disable_and_inactive_group_prevent_local_build(self):
        self.snapshot()
        self.configure('OFF', '-DENABLE_PROBE=ON', '-DDISABLE_PROBE=ON', '-DENABLE_ALL=ON')
        self.configure('ON', '-DDISABLE_PROBE=OFF')
        self.configure('OFF', '-DUSE_BRLCAD=OFF')

    def test_explicit_on_cannot_fetch_absent_source(self):
        output = self.configure('OFF', '-DENABLE_PROBE=ON')
        self.assertIn('local source snapshot is absent', output)

    def test_snapshot_provenance_and_bootstrap_without_submodule(self):
        script = self.root / 'inventory.cmake'
        script.write_text('''
include("@SOURCE@/CMake/BextDependencyInventory.cmake")
bext_collect_dependency_inventory("@FIXTURE@")
bext_inventory_get(urls probe SOURCE_URLS)
bext_inventory_get(revisions probe SOURCE_SHAS)
message(STATUS "PROVENANCE=${urls}|${revisions}")
'''.replace('@SOURCE@', SOURCE.as_posix()).replace('@FIXTURE@', self.source.as_posix()))
        output = self.run_command('cmake', '-P', script)
        self.assertIn(f'PROVENANCE=https://example.invalid/probe|{REVISION}', output)
        modules = self.source / 'CMake'
        modules.mkdir()
        for name in ('BextBootstrap.cmake', 'BextGit.cmake'):
            shutil.copyfile(SOURCE / 'CMake' / name, modules / name)
        for present in (False, True):
            if present:
                self.snapshot()
            output = self.run_command('cmake', '-DPROFILE=minimal', '-DLIST_ONLY=ON',
                                      '-P', modules / 'BextBootstrap.cmake')
            projects = next(line for line in output.splitlines()
                            if line.startswith('-- project submodules:'))
            self.assertNotIn('probe', projects)

    def test_profiles_use_unified_brlcad_group(self):
        presets = json.loads((SOURCE / 'CMakePresets.json').read_text())
        for preset in presets['configurePresets']:
            self.assertNotIn('USE_BRLCAD_EXTRA', preset.get('cacheVariables', {}))
        for profile in ('auto', 'bundled', 'minimal', 'everything'):
            output = self.run_command('cmake', f'-DPROFILE={profile}', '-DLIST_ONLY=ON',
                                      '-P', SOURCE / 'CMake/BextBootstrap.cmake')
            self.assertNotIn('BRLCAD_EXTRA', output)
            projects = next(line for line in output.splitlines()
                            if line.startswith('-- project submodules:'))
            names = projects.removeprefix('-- project submodules: ').split(', ')
            for name in ('stepcode', 'openvdb', 'opencv', 'bullet'):
                self.assertIn(name, names)
        output = self.configure('OFF', '-DUSE_BRLCAD_EXTRA=ON')
        groups = next(line for line in output.splitlines() if 'active USE_* groups:' in line)
        self.assertNotIn('BRLCAD_EXTRA', groups)


if __name__ == '__main__':
    unittest.main()
