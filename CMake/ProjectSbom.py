#!/usr/bin/env python3
"""Create a labelled vulnerability-matching projection of a source SBOM."""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import sys
import uuid
from urllib.parse import unquote


DEFAULT_ALIASES = Path(__file__).with_name('SbomScanAliases.json')
PROJECTION_COMMENT = (
    'Vulnerability-matching projection of the bext source inventory. '
    'Aliases identify upstream advisory candidates; they do not assert that '
    'ecosystem artifacts were installed or that findings apply to patched sources.'
)


def read_aliases(path, profile):
    data = json.loads(path.read_text())
    if data.get('schemaVersion') != 1:
        raise ValueError('Unsupported vulnerability alias schemaVersion')
    types = data.get('profiles', {}).get(profile)
    if not types or not isinstance(types, list):
        raise ValueError(f'Unknown or empty alias profile {profile}')
    aliases = {}
    for alias in data['aliases']:
        source, target = alias['sourcePurl'], alias['targetPurl']
        if (not re.fullmatch(r'pkg:[a-z0-9.+-]+/[^@]+@[^@]+', source) or
                not re.fullmatch(r'pkg:[a-z0-9.+-]+/[^@]+@[^@?#]+', target)):
            raise ValueError(f'Invalid versioned alias {source} -> {target}')
        if not alias.get('evidence') or not alias.get('reason'):
            raise ValueError(f'Alias {source} requires evidence and a reason')
        if not all(url.startswith('https://') for url in alias['evidence']):
            raise ValueError(f'Alias {source} requires HTTPS evidence URLs')
        target_type = target.split(':', 1)[1].split('/', 1)[0]
        if target_type not in types:
            continue
        if source in aliases:
            raise ValueError(f'Ambiguous alias for {source} in profile {profile}')
        aliases[source] = alias
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return aliases, digest


def project_inventory(inventory, aliases, profile, digest):
    result = copy.deepcopy(inventory)
    is_spdx = result.get('spdxVersion') == 'SPDX-2.3'
    if not is_spdx and result.get('bomFormat') != 'CycloneDX':
        raise ValueError('Expected SPDX 2.3 or CycloneDX JSON')
    if is_spdx:
        if '/scan-projection/' in result['documentNamespace']:
            raise ValueError('Input is already a scanner projection')
        namespace = result['documentNamespace']
        result['documentNamespace'] += f'/scan-projection/{profile}/{digest}'
        result['name'] += f'-scan-{profile}'
        result['comment'] = PROJECTION_COMMENT
        packages = result['packages']
    else:
        from ValidateSbom import component_index

        properties = result['metadata'].setdefault('properties', [])
        if any(item['name'] == 'bext:scan:profile' for item in properties):
            raise ValueError('Input is already a scanner projection')
        source_serial = result['serialNumber']
        namespace = result['metadata']['component']['bom-ref']
        projected_namespace = namespace + f'/scan-projection/{profile}/{digest}'
        result['metadata']['component']['bom-ref'] = projected_namespace
        result['metadata']['component']['name'] += f'-scan-{profile}'
        for dependency in result['dependencies']:
            if dependency['ref'] == namespace:
                dependency['ref'] = projected_namespace
        result['serialNumber'] = 'urn:uuid:' + str(uuid.uuid5(
            uuid.NAMESPACE_URL, projected_namespace))
        properties.extend([
            {'name': 'bext:scan:profile', 'value': profile},
            {'name': 'bext:scan:sourceSerialNumber', 'value': source_serial},
            {'name': 'bext:scan:componentLayout', 'value': 'flat'},
            {'name': 'bext:scan:comment', 'value': PROJECTION_COMMENT},
        ])
        components, containment = component_index(result)
        packages = list(components.values())
        # Some consumers read only top-level CycloneDX components. The scan
        # view flattens them and retains the original containment explicitly.
        for package in packages:
            package.pop('components', None)
        for parent, child in sorted(containment):
            components[child].setdefault('properties', []).append(
                {'name': 'bext:source:parent', 'value': parent})
        result['components'] = packages
    report = {'profile': profile, 'sourceDocument': namespace,
              'aliasTableSha256': digest, 'totalPackages': len(packages),
              'mapped': [], 'unmapped': []}
    for package in packages:
        if is_spdx:
            references = package.get('externalRefs', [])
            purls = [ref['referenceLocator'] for ref in references
                     if ref['referenceType'] == 'purl']
            identifier = package['SPDXID']
            version = package['versionInfo']
        else:
            purls = [package['purl']] if 'purl' in package else []
            identifier = package['bom-ref']
            version = package['version']
        matches = [aliases[purl] for purl in purls if purl in aliases]
        if not matches:
            report['unmapped'].append({'id': identifier, 'purls': purls,
                                       'reason': 'No reviewed alias for this profile'})
            continue
        if len(matches) != 1:
            raise ValueError(f'Multiple applicable aliases for {identifier}')
        alias = matches[0]
        target = alias['targetPurl']
        alias_version = target.rsplit('@', 1)[1]
        if version != alias_version:
            raise ValueError(f'{identifier}: alias version differs from source version')
        provenance = {'id': identifier, 'sourceName': package['name'], **alias}
        report['mapped'].append(provenance)
        # Ecosystem scanners can look up the package name as well as its PURL.
        # Preserve display names in provenance and use the alias's lookup name.
        package['name'] = unquote(target.rsplit('@', 1)[0].rsplit('/', 1)[1])
        if is_spdx:
            # Trivy selects the first PURL. Keep the source PURL as an additional
            # standard reference, with the advisory alias first in this view.
            references.insert(0, {'referenceCategory': 'PACKAGE-MANAGER',
                                  'referenceType': 'purl', 'referenceLocator': target})
            package.setdefault('annotations', []).append({
                'annotationDate': result['creationInfo']['created'],
                'annotationType': 'OTHER', 'annotator': 'Tool: bext-ProjectSbom.py',
                'comment': json.dumps(provenance, sort_keys=True),
            })
        else:
            package['purl'] = target
            package.setdefault('properties', []).extend([
                {'name': 'bext:source:name', 'value': provenance['sourceName']},
                {'name': 'bext:source:purl', 'value': alias['sourcePurl']},
                {'name': 'bext:scan:alias', 'value': json.dumps(provenance, sort_keys=True)},
            ])
    report['mappedPackages'] = len(report['mapped'])
    report['unmappedPackages'] = len(report['unmapped'])
    report['distinctMappedPurls'] = len({item['targetPurl'] for item in report['mapped']})
    return result, report


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    try:
        temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    parser.add_argument('--aliases', type=Path, default=DEFAULT_ALIASES)
    parser.add_argument('--profile', default='conan')
    args = parser.parse_args()
    paths = [args.input.resolve(), args.output.resolve(), args.report.resolve(),
             args.aliases.resolve()]
    if len(set(paths)) != len(paths):
        parser.error('input, aliases, output, and report must be distinct files')
    # Failed regeneration must not leave a stale report or scanner input.
    args.output.unlink(missing_ok=True)
    args.report.unlink(missing_ok=True)
    try:
        aliases, digest = read_aliases(args.aliases, args.profile)
        projected, report = project_inventory(
            json.loads(args.input.read_text()), aliases, args.profile, digest)
        write_json(args.output, projected)
        write_json(args.report, report)
        print(f"Alias coverage: {report['mappedPackages']}/{report['totalPackages']} "
              f"packages; {report['unmappedPackages']} unmapped")
    except (ValueError, KeyError, TypeError, OSError) as error:
        args.output.unlink(missing_ok=True)
        args.report.unlink(missing_ok=True)
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
