"""Selection and discovery checks for OpenVDB."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[2]


class OpenVDBDiscoveryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-openvdb-discovery-')
        self.addCleanup(temporary.cleanup)
        self.source = Path(temporary.name)
        shutil.copytree(SOURCE / 'CMake/OpenVDB', self.source / 'CMake/OpenVDB')
        wrapper = self.source / 'openvdb'
        (wrapper / 'openvdb').mkdir(parents=True)
        shutil.copyfile(SOURCE / 'openvdb/CMakeLists.txt', wrapper / 'CMakeLists.txt')
        (wrapper / 'openvdb/CMakeLists.txt').write_text('project(bundled_openvdb NONE)\n')
        (wrapper / 'openvdb/LICENSE').write_text('test license\n')
        (self.source / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(openvdb_selection LANGUAGES CXX)
include(ExternalProject)
include("@SOURCE@/CMake/Utils.cmake")

set(OpenVDB_ROOT "${CMAKE_BINARY_DIR}/openvdb-prefix")
file(MAKE_DIRECTORY "${OpenVDB_ROOT}/include/openvdb" "${OpenVDB_ROOT}/lib")
file(WRITE "${OpenVDB_ROOT}/include/openvdb/version.h" [=[
#define OPENVDB_LIBRARY_MAJOR_VERSION_NUMBER 13
#define OPENVDB_LIBRARY_MINOR_VERSION_NUMBER 0
#define OPENVDB_LIBRARY_PATCH_VERSION_NUMBER 1
#define OPENVDB_ABI_VERSION_NUMBER 13
]=])
if(DELAYED_LOADING)
  file(APPEND "${OpenVDB_ROOT}/include/openvdb/version.h" "#define OPENVDB_USE_DELAYED_LOADING\\n")
endif()
file(WRITE "${OpenVDB_ROOT}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}openvdb${CMAKE_STATIC_LIBRARY_SUFFIX}" "")

if(WITHOUT_TBB_INSTALL)
  set(CMAKE_FIND_ROOT_PATH "${CMAKE_BINARY_DIR}")
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
else()
  set(TBB_DIR "${CMAKE_BINARY_DIR}/tbb-prefix")
  file(MAKE_DIRECTORY "${TBB_DIR}")
  file(WRITE "${TBB_DIR}/TBBConfig.cmake" "add_library(TBB::tbb INTERFACE IMPORTED)\\n")
endif()
if(WITH_SYSTEM_BOOST)
  set(Boost_DIR "${CMAKE_BINARY_DIR}/boost-prefix")
  file(MAKE_DIRECTORY "${Boost_DIR}")
  file(WRITE "${Boost_DIR}/BoostConfig.cmake" "add_library(Boost::iostreams INTERFACE IMPORTED)\\n")
endif()
set(DISABLE_CMAKE_SEARCH_PATHS ON)

if(WITH_OPENVDB_CONFIG)
  file(MAKE_DIRECTORY "${OpenVDB_ROOT}/lib/cmake/OpenVDB")
  file(WRITE "${OpenVDB_ROOT}/lib/cmake/OpenVDB/OpenVDBConfig.cmake" [=[
add_library(OpenVDB::openvdb INTERFACE IMPORTED)
set(OPENVDB_TEST_CONFIG_USED ON CACHE INTERNAL "")
]=])
endif()

if(REQUIRE_OPENVDB)
  list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake/OpenVDB")
  set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)
  find_package(OpenVDB REQUIRED)
  return()
endif()

function(git_submodule_init)
endfunction()
function(RegisterDeps)
endfunction()
function(TargetInstallDeps)
endfunction()
set(CMAKE_BUNDLE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")
set(DOC_LICENSE_DIR "${CMAKE_BUNDLE_INSTALL_PREFIX}/share/doc/legal/other")
add_subdirectory(openvdb)
if(TARGET OPENVDB_BLD)
  message(STATUS "OpenVDB provider: bundled")
elseif(OPENVDB_TEST_CONFIG_USED)
  message(STATUS "OpenVDB provider: config")
else()
  message(STATUS "OpenVDB provider: module")
endif()
'''.replace('@SOURCE@', SOURCE.as_posix()))

    def configure(self, name, *options):
        return subprocess.run(
            ['cmake', '-S', str(self.source), '-B', str(self.source / name), *options],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )

    def test_openvdb_reuses_module_only_install(self):
        result = self.configure('module')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('OpenVDB provider: module', result.stdout)

    def test_openvdb_prefers_config_when_both_are_usable(self):
        result = self.configure('config', '-DWITH_OPENVDB_CONFIG=ON')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('OpenVDB provider: config', result.stdout)

    def test_openvdb_falls_back_when_tbb_search_finds_nothing(self):
        result = self.configure('no-tbb', '-DWITHOUT_TBB_INSTALL=ON')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('OpenVDB provider: bundled', result.stdout)

    def test_openvdb_reuses_system_boost_when_needed(self):
        result = self.configure('system-boost', '-DDELAYED_LOADING=ON', '-DWITH_SYSTEM_BOOST=ON')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('OpenVDB provider: module', result.stdout)

    def test_openvdb_reports_missing_dependencies_according_to_caller(self):
        for dependency, options in [('TBB', ()), ('Boost', ('-DDELAYED_LOADING=ON',))]:
            with self.subTest(dependency=dependency):
                unavailable = f'-DCMAKE_DISABLE_FIND_PACKAGE_{dependency}=ON'
                result = self.configure(f'optional-{dependency}', unavailable, *options)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn('OpenVDB provider: bundled', result.stdout)

                result = self.configure(f'required-{dependency}', unavailable,
                                        '-DREQUIRE_OPENVDB=ON', *options)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(f'Missing OpenVDB dependencies: {dependency}', result.stdout)


if __name__ == '__main__':
    unittest.main()
