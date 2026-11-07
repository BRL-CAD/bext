#!/usr/bin/env python3
"""Validate SBOM specifications and parity of bext's two serializations."""

import argparse
import json
from pathlib import Path
import re
import sys


PRESERVED_FIELDS = (
    'primaryPackagePurpose', 'packageSourceInfo', 'comment',
    'licenseDeclared', 'licenseConcluded', 'copyrightText',
)


def component_index(bom):
    components = {}
    containment = set()

    def visit(items, parent=None):
        for component in items:
            identifier = component['bom-ref']
            if identifier in components:
                raise ValueError(f'Duplicate CycloneDX component {identifier}')
            components[identifier] = component
            if parent is not None:
                containment.add((parent, identifier))
            for item in component.get('properties', []):
                if item['name'] == 'bext:source:parent':
                    containment.add((item['value'], identifier))
            visit(component.get('components', []), identifier)

    visit(bom.get('components', []))
    for parent, _ in containment:
        if parent not in components:
            raise ValueError(f'Unknown CycloneDX containment parent {parent}')
    return components, containment


def check_parity(spdx, cyclonedx):
    packages = {package['SPDXID']: package for package in spdx['packages']}
    components, containment = component_index(cyclonedx)
    if packages.keys() != components.keys():
        raise ValueError('SPDX and CycloneDX package identifiers differ')
    metadata = cyclonedx['metadata']
    if (metadata['timestamp'] != spdx['creationInfo']['created'] or
            metadata['component']['name'] != spdx['name'] or
            metadata['component']['bom-ref'] != spdx['documentNamespace']):
        raise ValueError('SPDX and CycloneDX document provenance differs')
    extracted = {license['licenseId']: license['extractedText']
                 for license in spdx.get('hasExtractedLicensingInfos', [])}
    for identifier, package in packages.items():
        component = components[identifier]
        properties = {item['name']: item['value']
                      for item in component.get('properties', [])}
        memberships = [item['comment'] for item in package.get('annotations', [])
                       if item.get('annotator') == 'Tool: bext:membership']
        if len(memberships) > 1:
            raise ValueError(f'{identifier}: duplicate package membership')
        if properties.get('bext:membership') != (memberships[0] if memberships else None):
            raise ValueError(f'{identifier}: consumer-group membership differs')
        for field in PRESERVED_FIELDS:
            if properties.get('bext:spdx:' + field) != package[field]:
                raise ValueError(f'{identifier}: {field} differs')
        for source, target in [('name', 'name'), ('versionInfo', 'version')]:
            if component.get(target) != package[source]:
                raise ValueError(f'{identifier}: {source} differs')
        copyright_text = package['copyrightText']
        expected_copyright = None if copyright_text == 'NOASSERTION' else copyright_text
        if component.get('copyright') != expected_copyright:
            raise ValueError(f'{identifier}: copyright differs')
        references = {}
        for reference in package.get('externalRefs', []):
            references.setdefault(reference['referenceType'], reference['referenceLocator'])
        for source, target in [('purl', 'purl'), ('cpe23Type', 'cpe')]:
            if references.get(source) != component.get(target):
                raise ValueError(f'{identifier}: {source} differs')
        distributions = [ref['url'] for ref in component.get('externalReferences', [])
                         if ref['type'] == 'distribution']
        expected = ([] if package['downloadLocation'] in ('NONE', 'NOASSERTION')
                    else [package['downloadLocation']])
        if distributions != expected:
            raise ValueError(f'{identifier}: source download differs')
        expression = package['licenseConcluded']
        acknowledgement = 'concluded'
        if expression == 'NOASSERTION':
            expression = package['licenseDeclared']
            acknowledgement = 'declared'
        licenses = ([] if expression in ('NONE', 'NOASSERTION') else
                    [{'expression': expression, 'acknowledgement': acknowledgement}])
        if component.get('licenses', []) != licenses:
            raise ValueError(f'{identifier}: effective license differs')
        evidence = {}
        for item in component.get('evidence', {}).get('licenses', []):
            license = item['license']
            for alias in license['licensing']['altIds']:
                evidence[alias] = license['text']['content']
        required_licenses = set(re.findall(
            r'LicenseRef-[A-Za-z0-9.-]+',
            package['licenseDeclared'] + ' ' + package['licenseConcluded']))
        if evidence != {identifier: extracted[identifier] for identifier in required_licenses}:
            raise ValueError(f'{identifier}: extracted license evidence differs')

    expected_containment = {(rel['spdxElementId'], rel['relatedSpdxElement'])
                            for rel in spdx['relationships']
                            if rel['relationshipType'] == 'CONTAINS'}
    if containment != expected_containment:
        raise ValueError('SPDX and CycloneDX containment differs')
    root = metadata['component']['bom-ref']
    expected_edges = {(rel['spdxElementId'], rel['relatedSpdxElement'])
                      for rel in spdx['relationships']
                      if rel['relationshipType'] == 'DEPENDS_ON'}
    dependency_ids = [item['ref'] for item in cyclonedx['dependencies']]
    if (len(dependency_ids) != len(set(dependency_ids)) or
            set(dependency_ids) != set(components) | {root}):
        raise ValueError('CycloneDX dependency nodes are incomplete or duplicated')
    edges = set()
    root_targets = set()
    for item in cyclonedx['dependencies']:
        targets = item.get('dependsOn', [])
        if len(targets) != len(set(targets)):
            raise ValueError(f"Duplicate dependencies for {item['ref']}")
        for target in targets:
            if target not in components:
                raise ValueError(f'Unknown CycloneDX dependency {target}')
            if item['ref'] != root:
                edges.add((item['ref'], target))
            else:
                root_targets.add(target)
    if root_targets != set(components) - {child for _, child in containment}:
        raise ValueError('CycloneDX inventory root dependencies differ')
    if edges != expected_edges:
        raise ValueError('SPDX and CycloneDX dependency edges differ')
    return len(packages), len(edges), len(containment)


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
            '/'.join(map(str, error.absolute_path)) + ': ' + error.message for error in errors))
    print(f'Validated component manifest: {path.name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--spdx', type=Path)
    parser.add_argument('--cyclonedx', type=Path)
    parser.add_argument('--component-manifest', type=Path)
    args = parser.parse_args()
    if not (args.spdx or args.cyclonedx or args.component_manifest):
        parser.error('provide --spdx, --cyclonedx, and/or --component-manifest')
    try:
        if args.spdx:
            validate_spdx(args.spdx)
        if args.cyclonedx:
            validate_cyclonedx(args.cyclonedx)
        if args.component_manifest:
            validate_component_manifest(args.component_manifest)
        if args.spdx and args.cyclonedx:
            packages, edges, containment = check_parity(
                json.loads(args.spdx.read_text()), json.loads(args.cyclonedx.read_text()))
            print(f'Parity verified: {packages} packages, {edges} dependency edges, '
                  f'{containment} containment edges')
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
