"""Shared CMake fixture for dependency selection regression checks."""

from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2]
REVISION = '0123456789abcdef0123456789abcdef01234567'


class DependencySelectionFixture(unittest.TestCase):
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

    def run_command(self, *command, success=True):
        result = subprocess.run([str(item) for item in command],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
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
