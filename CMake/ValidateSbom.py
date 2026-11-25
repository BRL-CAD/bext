#!/usr/bin/env python3
"""Run official third-party validators for generated supply-chain documents."""

import argparse
import json
from pathlib import Path
import sys


def validate_spdx(path):
    from spdx_tools.spdx.parser.error import SPDXParsingError
    from spdx_tools.spdx.parser.parse_anything import parse_file
    from spdx_tools.spdx.validation.document_validator import validate_full_spdx_document

    try:
        document = parse_file(str(path))
    except SPDXParsingError as error:
        raise ValueError('\n'.join(str(message) for message in error.get_messages())) from error
    errors = validate_full_spdx_document(document)
    if errors:
        raise ValueError('\n'.join(str(error) for error in errors))
    print(f'Validated SPDX 2.3: {path.name}')


def validate_cyclonedx(path):
    from cyclonedx.schema import SchemaVersion
    from cyclonedx.validation.json import JsonStrictValidator

    errors = list(JsonStrictValidator(SchemaVersion.V1_6).validate_str(
        path.read_text(), all_errors=True) or [])
    if errors:
        raise ValueError('\n'.join(str(error) for error in errors))
    print(f'Validated CycloneDX 1.6: {path.name}')


def validate_component_manifest(path):
    from jsonschema import Draft202012Validator

    schema = json.loads(Path(__file__).with_name('BextComponentManifest.schema.json').read_text())
    errors = list(Draft202012Validator(schema).iter_errors(json.loads(path.read_text())))
    if errors:
        raise ValueError('\n'.join(
            '/'.join(map(str, error.absolute_path)) + ': ' + error.message
            for error in errors))
    print(f'Validated component manifest: {path.name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--spdx', type=Path)
    parser.add_argument('--cyclonedx', type=Path)
    parser.add_argument('--component-manifest', type=Path)
    arguments = parser.parse_args()
    if not (arguments.spdx or arguments.cyclonedx or arguments.component_manifest):
        parser.error('provide --spdx, --cyclonedx, and/or --component-manifest')
    try:
        if arguments.spdx:
            validate_spdx(arguments.spdx)
        if arguments.cyclonedx:
            validate_cyclonedx(arguments.cyclonedx)
        if arguments.component_manifest:
            validate_component_manifest(arguments.component_manifest)
    except ImportError as error:
        print(f'{error}. Install CMake/sbom-requirements.txt in a virtual environment.',
              file=sys.stderr)
        return 1
    except (ValueError, KeyError, OSError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
