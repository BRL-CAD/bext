#!/usr/bin/env python3
"""Generate finalized build SBOMs, OpenVEX, and reusable review evidence."""

import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from BextVex import (SCHEMA_VERSION, exported_evidence, generate, json_text,
                     file_digest, load_evidence, package_view, read_json)
from InstallTransformations import read_transformations
from ProjectSbom import DEFAULT_ALIASES, alias_sources, project_inventory, read_aliases
from ValidateSbom import component_index


def write_outputs(directory, prefix, inventory, vex, evidence, report,
                  aliases, alias_digest, profile, cmake):
    spdx = directory / f'{prefix}.build.spdx.json'
    cdx = directory / f'{prefix}.build.cdx.json'
    spdx.write_text(json_text(inventory), encoding='utf-8')
    subprocess.run([
        cmake, f'-DINPUT={spdx}', f'-DOUTPUT={cdx}', '-P',
        str(Path(__file__).with_name('WriteCycloneDx.cmake')),
    ], check=True, capture_output=True, text=True)
    cyclonedx = read_json(cdx)
    cyclonedx['metadata']['lifecycles'] = [{'phase': 'post-build'}]
    components, _ = component_index(cyclonedx)
    for identifier, component in components.items():
        identity = evidence['packageIdentities'][identifier]
        component.setdefault('properties', []).extend([
            {'name': 'bext:source:purl', 'value': identity['sourcePurl']},
            {'name': 'bext:build:id', 'value': identity['id']},
        ])
    cdx.write_text(json_text(cyclonedx), encoding='utf-8')
    for format_name, document in [('spdx', inventory), ('cdx', cyclonedx)]:
        projected, coverage = project_inventory(document, aliases, profile, alias_digest)
        name = f'{prefix}.build.{profile}.{format_name}'
        (directory / (name + '.json')).write_text(json_text(projected), encoding='utf-8')
        (directory / (name + '.coverage.json')).write_text(json_text(coverage), encoding='utf-8')
    (directory / f'{prefix}-vex-evidence.json').write_text(json_text(evidence), encoding='utf-8')
    report['vexGenerated'] = vex is not None
    (directory / f'{prefix}-vex-report.json').write_text(json_text(report), encoding='utf-8')
    if vex:
        (directory / f'{prefix}.openvex.json').write_text(json_text(vex), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sbom', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--install-root', type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--registry', type=Path)
    mode.add_argument('--import-evidence', type=Path)
    parser.add_argument('--proof', type=Path)
    parser.add_argument('--import-transformations', type=Path,
                        help='Captured install transformations bound to the imported evidence')
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--product', default='bext')
    parser.add_argument('--author', default='https://brlcad.org/')
    parser.add_argument('--aliases', type=Path, default=DEFAULT_ALIASES)
    parser.add_argument('--profile', default='conan')
    parser.add_argument('--cmake', default='cmake')
    parser.add_argument('--package-view', action='store_true',
                        help='Generate package views; retain the original file-level input inventory separately')
    args = parser.parse_args()
    if args.import_transformations and not args.import_evidence:
        parser.error('--import-transformations requires --import-evidence')
    if not re.fullmatch(r'[a-z][a-z0-9_-]*', args.product):
        parser.error('--product must be a lowercase product name')
    if not re.fullmatch(r'[a-z][a-z0-9_-]*', args.profile):
        parser.error('--profile must be a lowercase profile name')
    if not args.author.startswith('https://'):
        parser.error('--author must identify the issuing organization with an HTTPS URL')
    try:
        args.output_dir.resolve().relative_to(args.install_root.resolve())
    except ValueError:
        pass
    else:
        parser.error('VEX outputs must live outside the installed content tree')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    # Do not leave previous assertions or evidence available after an aborted
    # generation. Publish a new VEX only after all companion outputs succeed.
    names = [f'{args.product}.openvex.json', f'{args.product}-vex-evidence.json',
             f'{args.product}-vex-report.json']
    names += [f'{args.product}.build.{format_name}.json' for format_name in ('spdx', 'cdx')]
    names += [f'{args.product}.build.{args.profile}.{format_name}{suffix}.json'
              for format_name in ('spdx', 'cdx') for suffix in ('', '.coverage')]
    destinations = {(args.output_dir / name).resolve() for name in names}
    if any(path and path.resolve() in destinations
           for path in (args.sbom, args.manifest, args.registry, args.import_evidence,
                        args.proof, args.import_transformations, *alias_sources(args.aliases))):
        parser.error('Generation inputs must be separate from its outputs')
    for name in names:
        (args.output_dir / name).unlink(missing_ok=True)
    try:
        source = read_json(args.sbom)
        if source.get('spdxVersion') != 'SPDX-2.3':
            raise ValueError('A canonical SPDX 2.3 source inventory is required')
        file_inventory = None
        if args.package_view:
            file_inventory = {'document': source['documentNamespace'], 'sha256': file_digest(args.sbom)}
            source = package_view(source)
        elif source.get('files') or any(package.get('filesAnalyzed') for package in source['packages']):
            raise ValueError('Use --package-view with an installed file-level inventory; keep the original document')
        aliases, alias_digest = read_aliases(args.aliases, args.profile)
        if args.registry:
            evidence = load_evidence(read_json(args.registry))
        else:
            evidence = exported_evidence(read_json(args.import_evidence))
        transformations = (read_transformations(args.import_transformations, file_digest(args.import_evidence))
                           if args.import_transformations else None)
        proof = None
        if args.proof:
            if args.import_evidence:
                raise ValueError('Imported evidence must be checked against finalized bytes directly')
            document = read_json(args.proof)
            if document.get('schemaVersion') != SCHEMA_VERSION:
                raise ValueError('Unsupported finalization proof')
            proof = document['components']
        inventory, vex, exported, report = generate(
            source, read_json(args.manifest), args.install_root, evidence,
            aliases, args.product, args.author, imported=bool(args.import_evidence), proof=proof,
            transformations=transformations)
        if args.import_transformations:
            report['installTransformations'] = {'file': args.import_transformations.name,
                                              'sha256': file_digest(args.import_transformations),
                                              'files': len(transformations)}
        if file_inventory:
            report['fileInventory'] = file_inventory
            inventory['comment'] += (' This package view retains file-level checksums and ownership '
                                     'in its original inventory and companion ownership manifest.')
        with tempfile.TemporaryDirectory(prefix='vex-', dir=args.output_dir) as temporary:
            directory = Path(temporary)
            write_outputs(directory, args.product, inventory, vex, exported, report,
                          aliases, alias_digest, args.profile, args.cmake)
            for path in sorted(directory.iterdir(), key=lambda path: path.name.endswith('.openvex.json')):
                path.replace(args.output_dir / path.name)
        counts = {result: sum(item['result'] == result for item in report['decisions'])
                  for result in ('applied', 'review_needed', 'not_installed')}
        print('VEX reviews: ' + ', '.join(f'{count} {result}' for result, count in counts.items()))
        if vex is None:
            print('No installed reviewed packages; no OpenVEX document was emitted')
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f'VEX generation failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
