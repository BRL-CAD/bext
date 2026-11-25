"""Selection and integration checks for tk."""

import unittest
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SOURCE / 'CMake/tests'))

from dependency_selection_fixture import DependencySelectionFixture


class TkSelectionTests(DependencySelectionFixture):
    def test_tk_off_is_respected_without_brlcad_group(self):
        (self.wrapper / 'CMakeLists.txt').write_text(
            'set(USE_BRLCAD OFF)\nset(ENABLE_TK OFF CACHE BOOL "Disable Tk")\n'
            'set(BEXT_XMIN_ROOT "unused-sdk")\n'
            'include("' + SOURCE.as_posix() + '/tk/CMakeLists.txt")\n'
            'if(TARGET TK_BLD)\nmessage(FATAL_ERROR "Tk was explicitly disabled")\nendif()\n')
        self.configure('OFF', '-DENABLE_ALL=ON')

if __name__ == '__main__':
    unittest.main()
