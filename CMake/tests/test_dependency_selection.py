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
        (self.wrapper / 'BextPackage.cmake').write_text('bext_package(probe OUTPUT install GROUPS BRLCAD)\n')
        (self.source / '.gitmodules').write_text('')
        (self.source / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(selection NONE)
include(ExternalProject)
include("@SOURCE@/CMake/Utils.cmake")
include("@SOURCE@/CMake/BextDependencyInventory.cmake")
option(USE_BRLCAD "BRL-CAD dependencies" ON)
set(CMAKE_BUNDLE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")
set(DOC_LICENSE_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/share/doc/legal/other")
add_project(probe GROUPS "BRLCAD")
bext_write_sbom_selectors("${CMAKE_BINARY_DIR}/sbom-selectors.cmake")
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

    def test_wrapper_serializes_installed_sbom_selector(self):
        selector = self.wrapper / 'SbomSelection.cmake'
        selector.write_text('function(probe_selected_packages output cache)\nendfunction()\n')
        wrapper = self.wrapper / 'CMakeLists.txt'
        wrapper.write_text(wrapper.read_text().replace(
            '  configure_file(snapshot/LICENSE "${DOC_LICENSE_DIR}/probe.txt" COPYONLY)\n',
            '  configure_file(snapshot/LICENSE "${DOC_LICENSE_DIR}/probe.txt" COPYONLY)\n'
            '  bext_sbom_selector(probe\n'
            '    TARGET PROBE_BLD\n'
            '    SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/SbomSelection.cmake"\n'
            '    FUNCTION probe_selected_packages\n'
            '    CACHE "${CMAKE_CURRENT_BINARY_DIR}/probe-cache.txt"\n'
            '    ARGUMENTS first second)\n'))
        self.snapshot()
        self.configure('ON')
        probe = self.root / 'selector-probe.cmake'
        probe.write_text('''
cmake_minimum_required(VERSION 3.26)
include("@REGISTRY@")
list(LENGTH BEXT_SBOM_SELECTOR_IDS selector_count)
if(NOT selector_count EQUAL 1)
  message(FATAL_ERROR "Expected one selector, found ${selector_count}")
endif()
list(GET BEXT_SBOM_SELECTOR_IDS 0 selector_id)
set(prefix "BEXT_SBOM_SELECTOR_${selector_id}")
if(NOT "${${prefix}_COMPONENT}" STREQUAL "probe" OR
   NOT "${${prefix}_TARGET}" STREQUAL "PROBE_BLD" OR
   NOT "${${prefix}_FUNCTION}" STREQUAL "probe_selected_packages" OR
   NOT "${${prefix}_ARGUMENTS}" STREQUAL "first;second")
  message(FATAL_ERROR "Serialized selector fields are incorrect")
endif()
'''.replace('@REGISTRY@', (self.build / 'sbom-selectors.cmake').as_posix()))
        self.run_command('cmake', '-P', probe)

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
        self.run_command('git', 'init', '-q', self.source)
        self.run_command('git', '-C', self.source, 'add', '.')
        self.run_command('git', '-C', self.source, '-c', 'user.name=Selection Test',
                         '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'Snapshot wrapper')
        script = self.root / 'inventory.cmake'
        script.write_text('''
cmake_minimum_required(VERSION 3.26)
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

    def component_wrapper(self, local=True):
        wrapper = self.wrapper / 'CMakeLists.txt'
        text = wrapper.read_text()
        if local:
            text = 'cad_enable(PROBE "libgcv")\n' + text
        else:
            declaration = text.splitlines()[1]
            text = text.replace(declaration, 'cad_enable(PROBE "libgcv")\nbext_enable(PROBE)')
            modules = self.source / 'CMake'
            modules.mkdir()
            (modules / 'FindPROBE.cmake').write_text('set(PROBE_FOUND FALSE)\n')
            text = 'list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/CMake")\n' + text
        wrapper.write_text(text)
        self.snapshot()

    def test_snapshot_off_wins_over_components_enable_all_and_group_changes(self):
        self.component_wrapper()
        self.configure('OFF', '-DENABLE_PROBE=OFF', '-DENABLE_ALL=ON', '-DBRLCAD_COMPONENTS=libgcv')
        self.configure('OFF', '-DBRLCAD_COMPONENTS=other')
        self.configure('OFF', '-DUSE_BRLCAD=OFF')
        self.configure('OFF', '-DUSE_BRLCAD=ON', '-DBRLCAD_COMPONENTS=other:libgcv')
        self.assertIn('ENABLE_PROBE:BOOL=OFF', (self.build / 'CMakeCache.txt').read_text())

    def test_normal_wrapper_off_wins_over_components_and_enable_all(self):
        self.component_wrapper(local=False)
        self.configure('OFF', '-DENABLE_PROBE=OFF', '-DENABLE_ALL=ON', '-DBRLCAD_COMPONENTS=libgcv')
        self.configure('OFF', '-UBRLCAD_COMPONENTS')
        self.assertRegex((self.build / 'CMakeCache.txt').read_text(), r'ENABLE_PROBE:[^=\n]+=OFF')

    def test_component_exclusions_do_not_become_cached_package_preferences(self):
        self.component_wrapper(local=False)
        self.configure('OFF', '-DBRLCAD_COMPONENTS=other')
        self.configure('ON', '-DBRLCAD_COMPONENTS=libgcv')
        self.configure('OFF', '-DBRLCAD_COMPONENTS=other')
        self.configure('ON', '-UBRLCAD_COMPONENTS')

    def test_custom_wrapper_component_exclusion_does_not_cache_off(self):
        self.component_wrapper()
        wrapper = self.wrapper / 'CMakeLists.txt'
        text = wrapper.read_text()
        declaration = next(line for line in text.splitlines() if line.startswith('bext_local_source('))
        text = text.replace(declaration, '''
if(NOT DEFINED ENABLE_PROBE AND NOT DISABLE_PROBE)
  set(ENABLE_PROBE ON)
endif()
set(ENABLE_PROBE "${ENABLE_PROBE}" CACHE BOOL "Build custom dependency")
set(DISABLE_PROBE "${DISABLE_PROBE}" CACHE BOOL "Disable custom dependency")
''')
        wrapper.write_text(text)
        self.configure('OFF', '-DBRLCAD_COMPONENTS=other')
        self.configure('ON', '-DBRLCAD_COMPONENTS=libgcv')
        self.configure('OFF', '-DENABLE_PROBE=OFF', '-DENABLE_ALL=ON')
        self.configure('OFF', '-DBRLCAD_COMPONENTS=other')
        self.configure('OFF', '-DBRLCAD_COMPONENTS=libgcv')

    def test_component_selection_preserves_explicit_disable(self):
        self.component_wrapper()
        self.configure('OFF', '-DDISABLE_PROBE=ON', '-DENABLE_ALL=ON', '-DBRLCAD_COMPONENTS=libgcv')
        self.configure('OFF', '-DBRLCAD_COMPONENTS=other:libgcv')
        self.configure('ON', '-DDISABLE_PROBE=OFF')

    def test_tk_off_is_respected_without_brlcad_group(self):
        (self.wrapper / 'CMakeLists.txt').write_text(
            'set(USE_BRLCAD OFF)\nset(ENABLE_TK OFF CACHE BOOL "Disable Tk")\n'
            'set(BEXT_XMIN_ROOT "unused-sdk")\n'
            'include("' + SOURCE.as_posix() + '/tk/CMakeLists.txt")\n'
            'if(TARGET TK_BLD)\nmessage(FATAL_ERROR "Tk was explicitly disabled")\nendif()\n')
        self.configure('OFF', '-DENABLE_ALL=ON')

    def test_qt_off_wins_over_components_enable_all_and_xmin_profile(self):
        (self.wrapper / 'CMakeLists.txt').write_text(
            'set(ENABLE_QT OFF CACHE BOOL "Disable Qt")\n'
            'set(BRLCAD_COMPONENTS libqtcad)\nset(BEXT_XMIN_ROOT "unused-sdk")\n'
            'set(QT_XMIN_ROOT "unused-sdk" CACHE PATH "Qt SDK")\n'
            'include("' + SOURCE.as_posix() + '/qt/CMakeLists.txt")\n'
            'if(TARGET Qt6_BLD OR ENABLE_QT)\nmessage(FATAL_ERROR "Qt was explicitly disabled")\nendif()\n')
        self.configure('OFF', '-DENABLE_ALL=ON')

    def test_netpbm_imported_target_supports_installed_header_layout(self):
        provider = self.root / 'provider'
        provider.mkdir()
        (provider / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(netpbm_provider C)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
add_library(netpbm SHARED probe.c)
install(TARGETS netpbm RUNTIME DESTINATION bin LIBRARY DESTINATION lib ARCHIVE DESTINATION lib)
install(FILES pam.h pm.h DESTINATION include/netpbm)
''')
        (provider / 'probe.c').write_text('int netpbm_probe(void) { return 42; }\n')
        (provider / 'pam.h').write_text('#include "netpbm/pm.h"\n')
        (provider / 'pm.h').write_text('int netpbm_probe(void);\n')
        prefix = self.root / 'installed'
        self.run_command('cmake', '-S', provider, '-B', self.root / 'provider-build',
                         '-DCMAKE_INSTALL_PREFIX=' + str(prefix), '-DCMAKE_BUILD_TYPE=Release')
        self.run_command('cmake', '--build', self.root / 'provider-build', '--config', 'Release',
                         '--target', 'install', '--parallel', '2')
        consumer = self.root / 'consumer'
        consumer.mkdir()
        (consumer / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(netpbm_consumer C)
list(APPEND CMAKE_MODULE_PATH "@SOURCE@/CMake")
find_package(NETPBM REQUIRED)
add_executable(consumer main.c)
target_link_libraries(consumer PRIVATE NETPBM::NETPBM)
'''.replace('@SOURCE@', SOURCE.as_posix()))
        # Both established include spellings and nested package includes work.
        (consumer / 'main.c').write_text(
            '#include <netpbm/pam.h>\n#include <pam.h>\n'
            'int main(void) { return netpbm_probe() == 42 ? 0 : 1; }\n')
        build = self.root / 'consumer-build'
        self.run_command('cmake', '-S', consumer, '-B', build, '-DNETPBM_ROOT=' + str(prefix),
                         '-DCMAKE_BUILD_TYPE=Release')
        self.run_command('cmake', '--build', build, '--config', 'Release', '--parallel', '2')


if __name__ == '__main__':
    unittest.main()
