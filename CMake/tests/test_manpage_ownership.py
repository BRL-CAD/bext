"""Manual ownership follows installer output and rejects failed enumeration."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('sh'), 'Manual installers require a POSIX shell')
class ManpageOwnershipTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-manpage-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        (self.source / 'aliases.3').write_text('API manual\n')
        (self.source / 'command.n').write_text('Command manual\n')
        (self.source / 'installer.sh').write_text(
            'cp "$1" "$2/first.3"\nln "$2/first.3" "$2/second.3"\n')
        (self.source / 'CMakeLists.txt').write_text('''
cmake_minimum_required(VERSION 3.26)
project(manpage_ownership NONE)
include("@MODULE@/Utils.cmake")
bext_component_manpage_ownership(core
  INSTALL_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/installer.sh"
  "${CMAKE_CURRENT_SOURCE_DIR}/*.3")
bext_component_manpage_ownership(extension "${CMAKE_CURRENT_SOURCE_DIR}/*.n")
get_property(rules GLOBAL PROPERTY BEXT_COMPONENT_OWNERSHIP_RULES)
foreach(manual man/man3/first.3 share/man/man3/second.3 man/mann/command.n)
  set(owners)
  foreach(rule IN LISTS rules)
    string(REPLACE "|" ";" fields "${rule}")
    list(POP_FRONT fields owner)
    list(JOIN fields "|" pattern)
    if(manual MATCHES "${pattern}")
      list(APPEND owners "${owner}")
    endif()
  endforeach()
  list(LENGTH owners owner_count)
  if(NOT owner_count EQUAL 1)
    message(FATAL_ERROR "Expected one owner for ${manual}: ${owners}")
  endif()
endforeach()
foreach(manual man/man3/unrelated.3 man/man3/aliases.3)
  foreach(rule IN LISTS rules)
    string(REGEX REPLACE "^[^|]+[|]" "" pattern "${rule}")
    if(manual MATCHES "${pattern}")
      message(FATAL_ERROR "Ownership claimed an uninstalled page: ${manual}")
    endif()
  endforeach()
endforeach()
'''.replace('@MODULE@', MODULE.as_posix()))

    def configure(self):
        return subprocess.run(['cmake', '-S', str(self.source), '-B', str(self.root / 'build')],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    def test_installed_aliases_and_manual_sections_have_exact_ownership(self):
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.root / 'build/CMakeFiles/core-manpages').exists())

    def test_failed_installer_does_not_publish_partial_ownership(self):
        (self.source / 'installer.sh').write_text('echo failed-enumeration >&2\nexit 1\n')
        result = self.configure()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('Unable to enumerate manual ownership', result.stdout)
        self.assertIn('failed-enumeration', result.stdout)


if __name__ == '__main__':
    unittest.main()
