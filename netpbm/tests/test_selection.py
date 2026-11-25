"""Selection and integration checks for netpbm."""

import unittest
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SOURCE / 'CMake/tests'))

from dependency_selection_fixture import DependencySelectionFixture


class NetpbmSelectionTests(DependencySelectionFixture):
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
