"""Exercise the actual external-project patch list for both manual settings."""

from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2]


@unittest.skipUnless((SOURCE / 'itk/itk/configure').is_file() and shutil.which('patch'),
                     'Requires the bundled Itk source and native patch utility')
class ItkDocumentationTests(unittest.TestCase):
    def test_manual_option_preserves_runtime_installation_and_all_patches(self):
        wrapper = (SOURCE / 'itk/CMakeLists.txt').read_text()
        start = wrapper.index('  set(ITK_PATCH_FILES\n')
        selection = wrapper[start:wrapper.index('  git_submodule_init(', start)]
        start = wrapper.index('  set(ITK_PATCH_LIST_SEPARATOR ')
        command = wrapper[start:wrapper.index('  if (NOT MSVC)', start)]
        for docs in ('ON', 'OFF'):
            with self.subTest(docs=docs), tempfile.TemporaryDirectory(prefix='bext-itk-docs-') as temporary:
                root = Path(temporary)
                staged = root / 'staged'
                shutil.copytree(SOURCE / 'itk/itk', staged, ignore=shutil.ignore_patterns('.git'))
                cmake = '''
cmake_minimum_required(VERSION 3.26)
project(itk_documentation NONE)
include(ExternalProject)
set(BEXT_TCL_ENABLE_DOCS @DOCS@)
set(PATCH_NATIVE_EXECUTABLE "@PATCH@")
set(PATCH_CHECK_OPTION --dry-run)
set(PATCH_REJECT_DIR "${CMAKE_BINARY_DIR}/patch-rejects")
@SELECTION@
@COMMAND@
ExternalProject_Add(ITK_DOCS
  SOURCE_DIR "@STAGED@"
  DOWNLOAD_COMMAND ""
  UPDATE_COMMAND ""
  LIST_SEPARATOR "${ITK_PATCH_LIST_SEPARATOR}"
  PATCH_COMMAND ${ITK_PATCH_COMMAND}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND "")
'''.replace('@DOCS@', docs).replace('@PATCH@', Path(shutil.which('patch')).as_posix())
                cmake = cmake.replace('@STAGED@', staged.as_posix()).replace('@SELECTION@', selection)
                cmake = cmake.replace('@COMMAND@', command).replace('<SOURCE_DIR>', staged.as_posix())
                cmake = cmake.replace('${CMAKE_CURRENT_SOURCE_DIR}', (SOURCE / 'itk').as_posix())
                (root / 'CMakeLists.txt').write_text(cmake)
                for arguments in (['cmake', '-S', str(root), '-B', str(root / 'build')],
                                  ['cmake', '--build', str(root / 'build'), '--target', 'ITK_DOCS']):
                    result = subprocess.run(arguments, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                    self.assertEqual(result.returncode, 0, result.stdout)
                unix = (staged / 'Makefile.in').read_text()
                windows = (staged / 'win/makefile.vc').read_text()
                unix_install = re.search(r'^install:.*$', unix, re.M).group()
                windows_install = re.search(r'^install:.*$', windows, re.M).group()
                self.assertEqual('install-doc' in unix_install, docs == 'ON')
                self.assertEqual('default-install-docs-n' in windows_install, docs == 'ON')
                self.assertIn('install-itk-class-library', windows_install)
                self.assertIn('$(LIBDIR)\\*.itk', windows)
                self.assertIn('$(LIBDIR)\\tclIndex', windows)


if __name__ == '__main__':
    unittest.main()
