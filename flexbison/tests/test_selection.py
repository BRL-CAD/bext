"""Resolve optional parser tools beside their build logic."""

from pathlib import Path
import sys
import unittest

SOURCE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SOURCE / 'CMake/tests'))
from dependency_selection_fixture import DependencySelectionFixture


class FlexBisonSelectionTests(DependencySelectionFixture):
    def wrapper_with_system_tools(self, found):
        modules = self.source / 'CMake'
        modules.mkdir(exist_ok=True)
        for tool in ('FLEX', 'BISON'):
            (modules / f'Find{tool}.cmake').write_text(f'set({tool}_FOUND {found})\n')
        (self.wrapper / 'CMakeLists.txt').write_text(
            'list(PREPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/CMake")\n'
            'include("' + SOURCE.as_posix() + '/flexbison/CMakeLists.txt")\n')

    def test_available_system_tools_do_not_build_local_sources(self):
        self.wrapper_with_system_tools('TRUE')
        self.configure('OFF')
        cache = (self.build / 'CMakeCache.txt').read_text()
        self.assertNotIn('ENABLE_FLEX:', cache)
        self.assertNotIn('ENABLE_BISON:', cache)

    def test_system_discovery_is_reconsidered_when_tools_disappear(self):
        self.wrapper_with_system_tools('TRUE')
        self.configure('OFF')
        self.wrapper_with_system_tools('FALSE')
        wrapper = self.wrapper / 'CMakeLists.txt'
        wrapper.write_text('function(git_submodule_init)\n'
                           '  message(FATAL_ERROR "Local tools requested: ${ENABLE_FLEX}/${ENABLE_BISON}")\n'
                           'endfunction()\n' + wrapper.read_text())
        output = self.run_command('cmake', '-S', self.source, '-B', self.build, success=False)
        self.assertIn('Local tools requested: ON/ON', output)

    def test_explicit_off_is_respected_when_system_tools_are_missing(self):
        self.wrapper_with_system_tools('FALSE')
        self.configure('OFF', '-DENABLE_FLEX=OFF', '-DENABLE_BISON=OFF', '-DENABLE_ALL=ON')


if __name__ == '__main__':
    unittest.main()
