#!/usr/bin/env python3
"""Offline checks for optional source snapshots and dependency profiles."""

import json
import shutil
import unittest


from dependency_selection_fixture import DependencySelectionFixture, REVISION, SOURCE


class DependencySelectionTests(DependencySelectionFixture):
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

    def test_summary_recognizes_a_wrapper_with_differently_named_build_targets(self):
        self.snapshot()
        (self.wrapper / 'CMakeLists.txt').write_text(
            'set(ENABLE_PROBE OFF)\n'
            'ExternalProject_Add(ALTERNATE_BLD URL "${CMAKE_CURRENT_SOURCE_DIR}/snapshot")\n')
        output = self.run_command('cmake', '-S', self.source, '-B', self.build)
        projects = next(line for line in output.splitlines() if '  local builds:' in line)
        self.assertEqual(projects.split(': ', 1)[1], 'probe')

    def test_wrapper_marks_all_declared_providers_as_handled(self):
        descriptor = self.wrapper / 'BextPackage.cmake'
        descriptor.write_text('bext_package(probe OUTPUT install GROUPS BRLCAD PROVIDERS parser lexer)\n')
        top = self.source / 'CMakeLists.txt'
        top.write_text(top.read_text() + '\n'
                       'if(NOT PROBE_ADDED OR NOT PARSER_ADDED OR NOT LEXER_ADDED)\n'
                       '  message(FATAL_ERROR "Declared providers were not marked handled")\n'
                       'endif()\n')
        self.configure('OFF')

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


if __name__ == '__main__':
    unittest.main()
