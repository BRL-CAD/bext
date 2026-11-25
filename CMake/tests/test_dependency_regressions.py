"""Run dependency-local tests through the normal central test discovery."""

import unittest

from dependency_test_support import dependency_test_modules


def load_tests(loader, tests, pattern):
    for module in dependency_test_modules():
        tests.addTests(loader.loadTestsFromModule(module))
    return tests


if __name__ == '__main__':
    unittest.main()
