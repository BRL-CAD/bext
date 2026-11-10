"""Discover regression tests beside dependency build logic."""

import importlib.util
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[2]


def dependency_test_modules():
    for path in sorted(SOURCE.glob('*/tests/test_*.py')):
        if not (path.parents[1] / 'BextPackage.cmake').is_file():
            continue
        name = 'dependency_' + '_'.join(path.relative_to(SOURCE).with_suffix('').parts)
        if name not in sys.modules:
            spec = importlib.util.spec_from_file_location(name, path)
            module = importlib.util.module_from_spec(spec)
            sys.modules[name] = module
            spec.loader.exec_module(module)
        yield sys.modules[name]
