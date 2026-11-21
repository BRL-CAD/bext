#!/usr/bin/env python3
"""Check repeated ELF RPATH edits with the plief built by bext."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


PLIEF = os.environ.get('BEXT_TEST_PLIEF')


@unittest.skipUnless(
    PLIEF and sys.platform.startswith('linux') and shutil.which('cc'),
    'Set BEXT_TEST_PLIEF to the bundled plief executable on Linux',
)
class PliefRpathTests(unittest.TestCase):
    def run_command(self, *command):
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def test_rpath_rewrites_reuse_dynamic_string_table_capacity(self):
        plief = str(Path(PLIEF).resolve())
        with tempfile.TemporaryDirectory(prefix='bext-plief-rpath-') as directory:
            root = Path(directory)
            dependency_name = 'libplief_rpath_dep.so'
            dependency_source = root / 'dependency.c'
            dependency_source.write_text('int dependency(void) { return 42; }\n')
            dependency = root / dependency_name
            self.run_command(
                'cc', '-shared', '-fPIC', dependency_source,
                f'-Wl,-soname,{dependency_name}', '-o', dependency,
            )
            subject_source = root / 'subject.c'
            subject_source.write_text(
                'int dependency(void); int answer(void) { return dependency(); }\n',
            )
            original = root / 'original.so'
            self.run_command(
                'cc', '-shared', '-fPIC', subject_source, dependency, '-o', original,
            )

            for tag, options in [('RUNPATH', ()), ('RPATH', ('--force-rpath',))]:
                with self.subTest(tag=tag):
                    subject = root / f'{tag}.so'
                    shutil.copyfile(original, subject)
                    first_rewrite_size = None
                    initial_dir = root / 'lib'
                    configure_dir = root / 'configure-library-path'
                    for library_dir in (
                        initial_dir, configure_dir, initial_dir,
                        configure_dir / 'install-library-path',
                    ):
                        library_dir.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(dependency, library_dir / dependency_name)
                        self.run_command(plief, *options, '--set-rpath', library_dir, subject)
                        actual_path = self.run_command(plief, *options, '--print-rpath', subject)
                        self.assertEqual(actual_path, str(library_dir))

                        size = subject.stat().st_size
                        if first_rewrite_size is None:
                            first_rewrite_size = size
                        else:
                            self.assertLessEqual(size, first_rewrite_size)

                        self.run_command(
                            sys.executable, '-c',
                            'import ctypes, sys; '
                            'sys.exit(ctypes.CDLL(sys.argv[1]).answer() != 42)',
                            subject,
                        )


if __name__ == '__main__':
    unittest.main()
