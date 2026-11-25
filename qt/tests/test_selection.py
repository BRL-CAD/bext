"""Selection and integration checks for qt."""

import unittest
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SOURCE / 'CMake/tests'))

from dependency_selection_fixture import DependencySelectionFixture


class QtSelectionTests(DependencySelectionFixture):
    def test_qt_off_wins_over_components_enable_all_and_xmin_profile(self):
        (self.wrapper / 'CMakeLists.txt').write_text(
            'set(ENABLE_QT OFF CACHE BOOL "Disable Qt")\n'
            'set(BRLCAD_COMPONENTS libqtcad)\nset(BEXT_XMIN_ROOT "unused-sdk")\n'
            'set(QT_XMIN_ROOT "unused-sdk" CACHE PATH "Qt SDK")\n'
            'include("' + SOURCE.as_posix() + '/qt/CMakeLists.txt")\n'
            'if(TARGET Qt6_BLD OR ENABLE_QT)\nmessage(FATAL_ERROR "Qt was explicitly disabled")\nendif()\n')
        self.configure('OFF', '-DENABLE_ALL=ON')

if __name__ == '__main__':
    unittest.main()
