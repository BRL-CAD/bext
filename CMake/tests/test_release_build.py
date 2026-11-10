#!/usr/bin/env python3
"""Offline integration checks using real ExternalProject builds and cleanup."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest
from unittest import mock


MODULE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_build', MODULE / 'release_build.py')
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class ReleaseBuildTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bext-release-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.build = self.root / 'build'
        self.prefix = self.root / 'output'
        self.failure = self.root / 'fail-install'
        self.final_failure = self.root / 'fail-finalize'

    def run_command(self, *command, success=True):
        result = subprocess.run([str(item) for item in command], stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def fixture(self, deferred=False, nested=False):
        (self.source / 'SbomSelection.cmake').write_text(
            'function(fixture_packages)\nendfunction()\n')
        names = ['FIRST', 'SECOND'] + (['PROVIDER_A', 'PROVIDER_B', 'CONSUMER'] if deferred else [])
        for name in names:
            upstream = self.source / name.lower()
            upstream.mkdir()
            checks = ''
            extra = ''
            body = 'return 42;'
            if name == 'SECOND':
                checks = '''
if(EXPECT_DISCARD AND EXISTS "${FIRST_WORK}")
  message(FATAL_ERROR "First dependency working tree was not discarded")
endif()
find_library(first_library first PATHS "${CMAKE_INSTALL_PREFIX}/lib" NO_DEFAULT_PATH REQUIRED)
'''
                extra = 'target_link_libraries(second PRIVATE "${first_library}")\n'
                body = 'return first();'
            if name == 'CONSUMER':
                checks = '''
if(NOT EXISTS "${PROVIDER_A_WORK}" OR NOT EXISTS "${PROVIDER_B_WORK}")
  message(FATAL_ERROR "Deferred dependency was discarded too early")
endif()
'''
            code = '''cmake_minimum_required(VERSION 3.26)
project(@NAME@ C)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
@CHECKS@
set_property(GLOBAL APPEND PROPERTY JOB_POOLS upstream=1)
add_library(@name@ SHARED @name@.c)
@EXTRA@
install(TARGETS @name@ DESTINATION lib)
install(CODE "if(EXISTS \\"${FAIL_SWITCH}\\")\nmessage(FATAL_ERROR \\"Requested install failure\\")\nendif()")
'''.replace('@NAME@', name).replace('@name@', name.lower()).replace('@CHECKS@', checks).replace('@EXTRA@', extra)
            (upstream / 'CMakeLists.txt').write_text(code)
            (upstream / (name.lower() + '.c')).write_text(
                'extern int first(void);\nint ' + name.lower() + '(void) {' + body + '}\n')
        cmake = '''cmake_minimum_required(VERSION 3.26)
project(fixture NONE)
set(BEXT_BUILD_JOBS 2 CACHE STRING "Jobs")
set(EXT_BUILD_ALWAYS ON)
set(CMAKE_BUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/install")
set(CMAKE_NOBUNDLE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/noinstall")
file(MAKE_DIRECTORY "${CMAKE_NOBUNDLE_INSTALL_PREFIX}")
include("@MODULE@/BextReleaseBuild.cmake")
include("@MODULE@/Utils.cmake")
'''.replace('@MODULE@', MODULE.as_posix())
        for index, name in enumerate(names):
            failure = self.failure if name == 'SECOND' else self.root / 'never-fail'
            wrapper = '''ExternalProject_Add(@NAME@_BLD
  URL "${CMAKE_SOURCE_DIR}/@name@"
  PREFIX "${CMAKE_BINARY_DIR}/@NAME@_BLD-prefix"
  BUILD_ALWAYS ${EXT_BUILD_ALWAYS}
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BUNDLE_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DEXPECT_DISCARD=${BEXT_DISCARD_WORK}
    -DFIRST_WORK=${CMAKE_BINARY_DIR}/FIRST_BLD-prefix/src/FIRST_BLD-build
    -DPROVIDER_A_WORK=${CMAKE_BINARY_DIR}/PROVIDER_A_BLD-prefix/src/PROVIDER_A_BLD-build
    -DPROVIDER_B_WORK=${CMAKE_BINARY_DIR}/PROVIDER_B_BLD-prefix/src/PROVIDER_B_BLD-build
    -DFAIL_SWITCH=@FAILURE@
  STEP_TARGETS install LOG_CONFIGURE ON LOG_BUILD ON LOG_INSTALL ON LOG_OUTPUT_ON_FAILURE ON)
'''.replace('@NAME@', name).replace('@name@', name.lower()).replace('@FAILURE@', failure.as_posix())
            if index:
                wrapper += 'ExternalProject_Add_StepDependencies(' + name + '_BLD configure ' + names[index - 1] + '_BLD-install)\n'
            if deferred and name in ('PROVIDER_A', 'PROVIDER_B', 'CONSUMER'):
                wrapper += f'set_property(TARGET {name}_BLD PROPERTY BEXT_RETAIN_WORK_UNTIL_FINALIZE TRUE)\n'
            if nested:
                directory = self.source / 'wrappers' / name.lower()
                directory.mkdir(parents=True)
                (directory / 'CMakeLists.txt').write_text(wrapper)
                cmake += 'add_subdirectory(wrappers/' + name.lower() + ' EXCLUDE_FROM_ALL)\n'
            else:
                cmake += wrapper
            if name == 'FIRST':
                cmake += '''bext_sbom_selector(first
  TARGET FIRST_BLD
  SCRIPT "${CMAKE_SOURCE_DIR}/SbomSelection.cmake"
  FUNCTION fixture_packages
  CACHE "${CMAKE_BINARY_DIR}/FIRST_BLD-prefix/src/FIRST_BLD-build/CMakeCache.txt")
'''
        finalize = '''
if(EXPECT_DISCARD)
  file(GLOB_RECURSE native_manifests "@BUILD@/*/install_manifest.txt")
  list(LENGTH native_manifests native_manifest_count)
  if(native_manifest_count LESS @COUNT@)
    message(FATAL_ERROR "Native install manifests were lost before finalization")
  endif()
  file(GLOB selector_caches "@BUILD@/CMakeFiles/bext-sbom-selector-caches/*.cache")
  list(LENGTH selector_caches selector_cache_count)
  if(NOT selector_cache_count EQUAL 1)
    message(FATAL_ERROR "Expected one preserved selector cache")
  endif()
  file(READ "${selector_caches}" selector_cache)
  if(NOT selector_cache MATCHES "CMAKE_PROJECT_NAME:STATIC=FIRST")
    message(FATAL_ERROR "Preserved selector cache is invalid")
  endif()
endif()
if(@DEFERRED@)
  foreach(name PROVIDER_A PROVIDER_B CONSUMER)
    if(NOT EXISTS "@BUILD@/${name}_BLD-prefix/src/${name}_BLD-build")
      message(FATAL_ERROR "Missing deferred tree at finalization")
    endif()
  endforeach()
endif()
if(EXISTS "@FAIL_FINALIZE@")
  message(FATAL_ERROR "Requested finalization failure")
endif()
file(WRITE "@PREFIX@/finalized" "done")
'''.replace('@COUNT@', str(len(names))).replace('@DEFERRED@', 'TRUE' if deferred else 'FALSE').replace('@BUILD@', self.build.as_posix()).replace('@PREFIX@', self.prefix.as_posix()).replace('@FAIL_FINALIZE@', self.final_failure.as_posix())
        (self.source / 'finalize.cmake').write_text(finalize)
        cmake += '''
set(finalize_all ALL)
if(BEXT_DISCARD_WORK)
  set(finalize_all)
endif()
add_custom_target(bext_finalize ${finalize_all}
  COMMAND ${CMAKE_COMMAND} -DEXPECT_DISCARD=${BEXT_DISCARD_WORK}
    -P "${CMAKE_SOURCE_DIR}/finalize.cmake"
  DEPENDS @INSTALLS@)
bext_configure_release_build()
'''.replace('@INSTALLS@', ' '.join(name + '_BLD-install' for name in names))
        (self.source / 'CMakeLists.txt').write_text(cmake)

    def configure(self, discard=True, generator='Ninja', extra=()):
        return self.run_command('cmake', '-S', self.source, '-B', self.build, '-G', generator,
                                '-DBEXT_DISCARD_WORK=' + ('ON' if discard else 'OFF'),
                                '-DCMAKE_INSTALL_PREFIX=' + str(self.prefix),
                                '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_CONFIGURATION_TYPES=Release', *extra)

    def compile(self, success=True, target=None):
        command = ['cmake', '--build', self.build, '--config', 'Release', '--parallel', '16']
        if target:
            command += ['--target', target]
        return self.run_command(*command, success=success)

    def plan(self):
        return json.loads((self.build / 'bext-release-Release.json').read_text())

    def test_discard_preserves_installs_controls_logs_and_noop_reconfigure(self):
        self.fixture()
        self.configure()
        self.compile()
        plan = self.plan()
        for project in plan['projects']:
            for key in ('source_dir', 'binary_dir'):
                self.assertFalse(Path(project[key]).exists())
            self.assertTrue(Path(project['stamp_dir']).is_dir())
            self.assertTrue(Path(project['tmp_dir']).is_dir())
            manifest = Path(project['preserved_install_manifest'])
            self.assertTrue(manifest.is_file())
            for name in manifest.read_text().splitlines():
                self.assertTrue(Path(name).exists())
        self.assertTrue((self.source / 'first/first.c').is_file())
        self.assertTrue(list((self.prefix / 'install/lib').glob('*first*')))
        self.assertTrue((self.build / 'bext-release-logs/FIRST_BLD.log').is_file())
        log = (self.build / 'bext-release-logs/FIRST_BLD.log').read_bytes()
        self.assertIn('up to date', self.compile())
        self.configure()
        self.assertIn('up to date', self.compile())
        self.assertEqual(log, (self.build / 'bext-release-logs/FIRST_BLD.log').read_bytes())

    def test_install_failure_retains_work_and_resumes(self):
        self.fixture()
        self.failure.touch()
        self.configure()
        self.assertIn('working files and logs were retained', self.compile(success=False))
        self.assertFalse((self.build / 'FIRST_BLD-prefix/src/FIRST_BLD-build').exists())
        self.assertTrue((self.build / 'SECOND_BLD-prefix/src/SECOND_BLD-build').is_dir())
        self.assertTrue((self.build / 'SECOND_BLD-prefix/src/SECOND_BLD/second.c').is_file())
        log = (self.build / 'bext-release-logs/FIRST_BLD.log').read_bytes()
        self.failure.unlink()
        self.compile()
        self.assertEqual(log, (self.build / 'bext-release-logs/FIRST_BLD.log').read_bytes())
        self.assertFalse((self.build / 'SECOND_BLD-prefix/src/SECOND_BLD-build').exists())

    def test_discard_removes_readonly_test_fixture(self):
        self.fixture()
        with (self.source / 'first/CMakeLists.txt').open('a') as output:
            output.write('''
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/tests/testfiles")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/tests/testfiles/readonly.txt" "Read_only")
file(CHMOD "${CMAKE_CURRENT_BINARY_DIR}/tests/testfiles/readonly.txt"
  PERMISSIONS OWNER_READ GROUP_READ WORLD_READ)
''')
        self.configure()
        self.compile()
        self.assertFalse((self.build / 'FIRST_BLD-prefix/src/FIRST_BLD-build').exists())
        self.assertTrue(list((self.prefix / 'install/lib').glob('*first*')))
        self.assertIn('up to date', self.compile())

    def test_readonly_cleanup_retries_windows_deletion(self):
        path = self.root / 'readonly.txt'
        path.write_text('Read_only')
        path.chmod(stat.S_IREAD)
        self.addCleanup(lambda: path.exists() and path.chmod(stat.S_IREAD | stat.S_IWRITE))
        error = PermissionError('Access is denied')
        # Exercise Windows recovery on every host; actual deletion is still real.
        with mock.patch.object(driver, 'os', wraps=os) as windows:
            windows.name = 'nt'
            driver.remove_readonly(windows.unlink, path, (PermissionError, error, None))
            windows.unlink.assert_called_once_with(path)
        self.assertFalse(path.exists())

    def test_readonly_cleanup_preserves_other_errors(self):
        path = self.root / 'writable.txt'
        path.write_text('Writable')
        for error in (PermissionError('File is locked'), OSError('Other error')):
            with self.subTest(error=error):
                with mock.patch.object(driver, 'os', wraps=os) as windows:
                    windows.name = 'nt'
                    with self.assertRaises(type(error)) as raised:
                        driver.remove_readonly(windows.unlink, path,
                                               (type(error), error, None))
                    self.assertIs(raised.exception, error)
                    windows.chmod.assert_not_called()
                    windows.unlink.assert_not_called()
        self.assertTrue(path.exists())

    def test_deferred_dependency_chain_survives_until_finalization(self):
        self.fixture(deferred=True)
        self.configure()
        self.compile()
        self.assertTrue((self.prefix / 'finalized').is_file())
        for name in ('PROVIDER_A', 'PROVIDER_B', 'CONSUMER'):
            self.assertFalse((self.build / (name + '_BLD-prefix/src/' + name + '_BLD-build')).exists())

    def test_failed_finalization_retains_deferred_work_for_retry(self):
        self.fixture(deferred=True)
        self.configure()
        self.final_failure.touch()
        self.compile(success=False)
        for name in ('PROVIDER_A', 'PROVIDER_B', 'CONSUMER'):
            self.assertTrue((self.build / (name + '_BLD-prefix/src/' + name + '_BLD-build')).is_dir())
        self.final_failure.unlink()
        self.compile()
        for name in ('PROVIDER_A', 'PROVIDER_B', 'CONSUMER'):
            self.assertFalse((self.build / (name + '_BLD-prefix/src/' + name + '_BLD-build')).exists())

    def test_default_prefix_inside_build_tree_is_retained(self):
        self.prefix = self.build
        self.fixture()
        self.configure()
        self.compile()
        self.assertTrue((self.prefix / 'install/lib').is_dir())
        self.assertTrue((self.prefix / 'noinstall').is_dir())
        self.assertIn('up to date', self.compile())

    def test_normal_mode_preserves_incremental_work_and_pools(self):
        self.fixture()
        self.configure(discard=False)
        self.compile()
        self.assertTrue((self.build / 'FIRST_BLD-prefix/src/FIRST_BLD-build').is_dir())
        rules = (self.build / 'FIRST_BLD-prefix/src/FIRST_BLD-build/CMakeFiles/rules.ninja').read_text()
        for pool in ('bext_compile', 'bext_link', 'upstream'):
            self.assertIn('pool ' + pool, rules)
        self.assertIn('pool = bext_compile', (self.build / 'FIRST_BLD-prefix/src/FIRST_BLD-build/build.ninja').read_text())
        self.assertFalse((self.build / 'bext-release-state.json').exists())
        self.compile()

    def test_changed_options_are_rejected_after_discard(self):
        self.fixture()
        self.configure()
        self.compile()
        self.configure(extra=('-DBEXT_BUILD_JOBS=3',))
        self.assertIn('Build inputs changed', self.compile(success=False))

    def test_changed_sources_are_rejected_after_discard(self):
        self.fixture()
        self.configure()
        self.compile()
        with (self.source / 'first/first.c').open('a') as output:
            output.write('\n/* Changed dependency. */\n')
        self.assertIn('Build inputs changed', self.compile(success=False))

    def test_archived_sources_in_an_ignored_git_directory_are_tracked(self):
        self.fixture()
        self.run_command('git', 'init', '-q', self.source)
        (self.source / '.gitignore').write_text('first/\nsecond/\n')
        self.run_command('git', '-C', self.source, 'add', 'CMakeLists.txt', '.gitignore')
        self.run_command('git', '-C', self.source, '-c', 'user.name=Build Test',
                         '-c', 'user.email=build-test@example.invalid',
                         'commit', '-q', '-m', 'Initialize fixture')
        self.configure()
        self.compile()
        with (self.source / 'first/first.c').open('a') as output:
            output.write('\n/* Changed archived dependency. */\n')
        self.assertIn('Build inputs changed', self.compile(success=False))

    def test_missing_installed_outputs_are_rejected(self):
        self.fixture()
        self.configure()
        self.compile()
        next((self.prefix / 'install/lib').glob('*first*')).unlink()
        self.assertIn('Installed dependency files changed', self.compile(success=False))

    def test_clean_allows_a_complete_rebuild(self):
        self.fixture()
        self.configure()
        self.compile()
        self.compile(target='clean')
        self.assertFalse((self.build / 'bext-release-state.json').exists())
        self.compile()
        self.assertIn('up to date', self.compile())

    def test_multiconfig(self):
        self.fixture()
        self.configure(generator='Ninja Multi-Config')
        self.compile()
        self.assertIn('up to date', self.compile())

    def check_excluded_wrappers(self, generator, config):
        self.source = self.root / ('source-' + config)
        self.source.mkdir()
        self.build = self.root / ('build-' + config)
        self.prefix = self.root / ('output-' + config)
        self.fixture(nested=True)
        self.configure(generator=generator, extra=(
            '-DCMAKE_BUILD_TYPE=' + config, '-DCMAKE_CONFIGURATION_TYPES=' + config))
        plan = json.loads((self.build / ('bext-release-' + config + '.json')).read_text())
        for project in plan['projects']:
            self.assertEqual(project['build_target'], 'bext_release_' + project['name'])
        if generator.startswith('Visual Studio'):
            for project in plan['projects']:
                self.assertTrue((self.build / (project['build_target'] + '.vcxproj')).is_file())
            self.assertFalse((self.build / 'FIRST_BLD.vcxproj').exists())
            self.assertTrue((self.build / 'wrappers/first/FIRST_BLD.vcxproj').is_file())
        output = self.run_command('cmake', '--build', self.build, '--config', config,
                                  '--parallel', '1')
        self.assertIn('Building FIRST_BLD', output)
        self.assertIn('Building SECOND_BLD', output)
        self.assertTrue((self.prefix / 'finalized').is_file())
        for project in plan['projects']:
            self.assertFalse(Path(project['source_dir']).exists())
            self.assertFalse(Path(project['binary_dir']).exists())
        self.assertIn('up to date', self.run_command(
            'cmake', '--build', self.build, '--config', config, '--parallel', '1'))

    def test_excluded_wrappers_multiconfig(self):
        for config in ('Release', 'Debug'):
            with self.subTest(config=config):
                self.check_excluded_wrappers('Ninja Multi-Config', config)

    @unittest.skipUnless(os.name == 'nt', 'Visual Studio requires Windows')
    def test_excluded_wrappers_visual_studio(self):
        capabilities = json.loads(self.run_command('cmake', '-E', 'capabilities'))
        generators = [item['name'] for item in capabilities['generators']
                      if item['name'].startswith('Visual Studio')]
        self.assertTrue(generators, 'CMake must support a Visual Studio generator')
        generator = max(generators, key=lambda name: int(name.split()[2]))
        for config in ('Release', 'Debug'):
            with self.subTest(config=config):
                self.check_excluded_wrappers(generator, config)

    @unittest.skipUnless(shutil.which('gmake') or shutil.which('make'), 'make is required')
    def test_makefiles(self):
        self.fixture()
        self.configure(generator='Unix Makefiles')
        self.compile()
        self.assertIn('up to date', self.compile())

    @unittest.skipUnless(shutil.which('gmake') or shutil.which('make'), 'make is required')
    def test_cmake_steps_do_not_inherit_parent_make_flags(self):
        self.fixture()
        project = self.source / 'CMakeLists.txt'
        project.write_text(project.read_text().replace(
            '  CMAKE_ARGS ', '  CMAKE_GENERATOR "Unix Makefiles"\n  CMAKE_ARGS '))
        self.configure(discard=False)
        # A BSD make jobserver uses flags that GNU make cannot parse.
        with mock.patch.dict(os.environ, {'MAKEFLAGS': '-J 3,4 -j 2',
                                          'MFLAGS': '-J 3,4 -j 2'}):
            self.compile()
        self.assertTrue((self.prefix / 'finalized').is_file())

    def test_unsafe_work_directory_is_rejected(self):
        self.fixture()
        self.configure()
        plan = self.plan()
        plan['projects'][0]['binary_dir'] = str(self.build)
        with self.assertRaisesRegex(ValueError, 'Unsafe working directory'):
            driver.work_paths(plan, plan['projects'][0])
        plan['projects'][0]['binary_dir'] = str(self.build / 'CMakeFiles')
        with self.assertRaisesRegex(ValueError, 'overlaps retained files'):
            driver.work_paths(plan, plan['projects'][0])

        plan['projects'][0]['binary_dir'] = str(self.prefix / 'install')
        # Outside the build tree is retained, never considered for deletion.
        self.assertNotIn(self.prefix / 'install', driver.work_paths(plan, plan['projects'][0]))
        plan['install_roots'][0] = str(self.build / 'keep-install')
        plan['projects'][0]['binary_dir'] = plan['install_roots'][0]
        with self.assertRaisesRegex(ValueError, 'overlaps retained files'):
            driver.work_paths(plan, plan['projects'][0])
        plan['projects'][0]['binary_dir'] = str(self.prefix / 'install')
        plan['projects'][0]['source_dir'] = str(self.build / 'link')
        (self.build / 'link').symlink_to(self.source, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Unsafe working directory'):
            driver.work_paths(plan, plan['projects'][0])

    def test_symlink_work_directory_below_a_build_alias_is_rejected(self):
        self.fixture()
        self.configure()
        alias = self.root / 'build-alias'
        alias.symlink_to(self.build, target_is_directory=True)
        retained = self.build / 'retained'
        retained.mkdir()
        (self.build / 'work-link').symlink_to(retained, target_is_directory=True)
        plan = self.plan()
        plan['build_root'] = str(alias)
        plan['projects'][0]['binary_dir'] = str(alias / 'work-link')
        with self.assertRaisesRegex(ValueError, 'Unsafe working directory'):
            driver.work_paths(plan, plan['projects'][0])

    def test_prefix_owned_by_another_build_is_rejected(self):
        self.fixture()
        self.configure()
        self.compile()
        state = self.build / 'bext-release-state.json'
        state.unlink()
        receipt = self.prefix / 'bext-discard-receipt.json'
        receipt.write_text(json.dumps({'build_root': str(self.root / 'other'), 'id': 'other'}))
        self.assertIn('Install prefix belongs to another build', self.compile(success=False))

    def test_concurrent_prefix_use_is_rejected(self):
        self.fixture()
        self.configure()
        script = self.root / 'hold-prefix.cmake'
        script.write_text('''file(LOCK "@PREFIX@/bext-release-prefix.lock" GUARD PROCESS TIMEOUT 0)
execute_process(COMMAND "${CMAKE_COMMAND}" --build "@BUILD@" --config Release
  RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error)
if(result STREQUAL "0" OR NOT "${output}${error}" MATCHES "Another build is using")
  message(FATAL_ERROR "Prefix lock failed: ${output}${error}")
endif()
'''.replace('@PREFIX@', self.prefix.as_posix()).replace('@BUILD@', self.build.as_posix()))
        self.run_command('cmake', '-P', script)

    def test_global_ninja_pool_serializes_independent_expensive_steps(self):
        lock_script = self.source / 'step.cmake'
        lock_script.write_text('''file(LOCK "${CMAKE_CURRENT_LIST_DIR}/active" GUARD PROCESS TIMEOUT 0)
execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 0.1)
''')
        cmake = '''cmake_minimum_required(VERSION 3.26)
project(pools NONE)
set(BEXT_BUILD_JOBS 2)
include("@MODULE@/BextReleaseBuild.cmake")
foreach(name A B C)
  ExternalProject_Add(${name}_BLD DOWNLOAD_COMMAND ""
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/step.cmake"
    BUILD_COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/step.cmake"
    INSTALL_COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/step.cmake"
    STEP_TARGETS install)
endforeach()
'''.replace('@MODULE@', MODULE.as_posix())
        (self.source / 'CMakeLists.txt').write_text(cmake)
        self.configure(discard=False)
        self.compile()


if __name__ == '__main__':
    unittest.main()
