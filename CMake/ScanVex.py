#!/usr/bin/env python3
"""Keep baseline and OpenVEX-filtered scanner reports with an audit summary."""

import argparse
import copy
import datetime
import itertools
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

from BextVex import file_digest, json_text, purls, read_json
from ValidateSbom import component_index
from SupplyChainTools import publish_files, tool_version


SCAN_TIMEOUT_SECONDS = 1800
TESTED_SCANNER_VERSIONS = {'grype': '0.121.2', 'trivy': '0.76.2'}


def inventory_packages(document):
    if document.get('spdxVersion') == 'SPDX-2.3':
        return [{'id': package['SPDXID'], 'name': package['name'],
                 'purls': purls(package)} for package in document['packages']]
    if document.get('bomFormat') == 'CycloneDX':
        return [{'id': identifier, 'name': package['name'],
                 'purls': [package['purl']] if package.get('purl') else []}
                for identifier, package in component_index(document)[0].items()]
    raise ValueError('Expected an SPDX or CycloneDX inventory')


def scan_coverage(inventory, recognized):
    packages = inventory_packages(read_json(inventory))
    recognized = {lookup_identity(purl) for purl in recognized if purl}
    missing = [package for package in packages
               if not {lookup_identity(purl) for purl in package['purls']}.intersection(recognized)]
    return {'inputPackages': len(packages), 'recognizedPackages': len(packages) - len(missing),
            'unrecognizedPackages': missing,
            'status': 'empty' if not packages else 'partial' if missing else 'complete',
            'note': 'Package recognition does not establish advisory coverage or absence of vulnerabilities.'}


def lookup_identity(purl):
    # GitHub names are case-insensitive; source revisions and build qualifiers
    # retain their case. This comparison does not rewrite inventory identities.
    if purl.startswith('pkg:github/'):
        name, separator, revision = purl.partition('@')
        return name.lower() + separator + revision
    return purl


def trivy_partitions(inventory, directory):
    document = read_json(inventory)
    is_spdx = document.get('spdxVersion') == 'SPDX-2.3'
    if is_spdx:
        packages = document['packages']
    elif document.get('bomFormat') == 'CycloneDX':
        packages = list(component_index(document)[0].values())
    else:
        raise ValueError('Expected an SPDX or CycloneDX inventory')
    groups = {}
    for package in packages:
        identifiers = purls(package) if is_spdx else [package.get('purl', '')]
        purl = identifiers[0] if identifiers else ''
        # Trivy deduplicates advisory lookups by ecosystem/name/version. Build
        # qualifiers distinguish evidence but do not prevent that deduplication.
        lookup = purl.split('?', 1)[0].split('#', 1)[0].rsplit('@', 1)[0]
        key = (lookup or package['name'], package.get('versionInfo', package.get('version')))
        groups.setdefault(key, []).append(package)
    count = max((len(group) for group in groups.values()), default=1)
    if count == 1:
        return [inventory]
    outputs = []
    for index in range(count):
        selected = [group[index % len(group)] for group in groups.values()]
        part = copy.deepcopy(document)
        if is_spdx:
            identifiers = {package['SPDXID'] for package in selected}
            part['packages'] = selected
            part['documentNamespace'] += f'/trivy-partition/{index + 1}'
            part['name'] += f'-trivy-partition-{index + 1}'
            part['relationships'] = [
                relation for relation in part.get('relationships', [])
                if relation['relatedSpdxElement'] in identifiers and
                (relation['spdxElementId'] in identifiers or
                 relation['spdxElementId'] == 'SPDXRef-DOCUMENT')]
        else:
            identifiers = {package['bom-ref'] for package in selected}
            part['components'] = copy.deepcopy(selected)
            for component in part['components']:
                component.pop('components', None)
                component['properties'] = [
                    item for item in component.get('properties', [])
                    if item['name'] != 'bext:source:parent' or item['value'] in identifiers]
            root = part['metadata']['component']['bom-ref']
            part['dependencies'] = [
                {**item, 'dependsOn': [value for value in item.get('dependsOn', []) if value in identifiers]}
                for item in part.get('dependencies', []) if item['ref'] in identifiers | {root}]
            part['serialNumber'] = 'urn:uuid:' + str(uuid.uuid5(
                uuid.NAMESPACE_URL, part['serialNumber'] + f'/trivy-partition/{index + 1}'))
        path = directory / f'trivy.part-{index + 1}.sbom.json'
        path.write_text(json_text(part), encoding='utf-8')
        outputs.append(path)
    return outputs


def merge_trivy(documents):
    result = copy.deepcopy(documents[0])
    merged = {}
    for document in documents:
        for report in document.get('Results', []):
            key = (report['Target'], report.get('Class'), report.get('Type'))
            if key not in merged:
                merged[key] = copy.deepcopy(report)
                continue
            destination = merged[key]
            for field in ('Vulnerabilities', 'Packages'):
                if field not in report:
                    continue
                items = {json_text(item): item for item in destination.get(field, [])}
                items.update({json_text(item): item for item in report[field]})
                destination[field] = list(items.values())
    result['Results'] = list(merged.values())
    return result


def findings(scanner, document):
    records = {}
    if scanner == 'grype':
        for match in document['matches']:
            package = match['artifact']
            record = {'vulnerability': match['vulnerability']['id'],
                      'package': package['name'], 'version': package['version'],
                      'purl': package.get('purl') or '', 'id': package['id']}
            records[tuple(record.values())] = record
    else:
        for result in document.get('Results', []):
            for vulnerability in result.get('Vulnerabilities', []):
                record = {'vulnerability': vulnerability['VulnerabilityID'],
                          'package': vulnerability['PkgName'],
                          'version': vulnerability['InstalledVersion'],
                          'purl': (vulnerability.get('PkgIdentifier') or {}).get('PURL') or '',
                          'id': vulnerability.get('PkgID') or ''}
                records[tuple(record.values())] = record
    return records


def scan(scanner, inventory, vex, directory, offline, timeout=SCAN_TIMEOUT_SECONDS):
    if not shutil.which(scanner):
        raise ValueError(f'{scanner} is not on PATH; use the documented local tool environment')
    environment = dict(os.environ, GRYPE_CHECK_FOR_APP_UPDATE='false')
    version = tool_version(scanner)
    # Scanner-wide VEX/ignore settings must not silently alter the baseline.
    for variable in ('GRYPE_VEX_DOCUMENTS', 'GRYPE_VEX_ADD', 'GRYPE_IGNORE',
                     'GRYPE_ONLY_FIXED', 'GRYPE_ONLY_NOTFIXED', 'GRYPE_IGNORE_STATES',
                     'GRYPE_FAIL_ON_SEVERITY', 'TRIVY_VEX', 'TRIVY_IGNORE_UNFIXED',
                     'TRIVY_IGNORE_STATUS', 'TRIVY_IGNORE_POLICY',
                     'TRIVY_SEVERITY', 'TRIVY_EXIT_CODE'):
        environment.pop(variable, None)
    partitions = trivy_partitions(inventory, directory) if scanner == 'trivy' else [inventory]
    by_mode = {False: [], True: []}
    with tempfile.TemporaryDirectory(prefix='scanner-', dir=directory) as temporary:
        config = Path(temporary) / 'config.json'
        config.write_text('{}\n')
        ignore = Path(temporary) / 'ignore'
        ignore.write_text('')
        if scanner == 'grype':
            command = [scanner, '--config', str(config), '-o', 'json']
        else:
            command = [scanner, '--config', str(config), 'sbom', '--ignorefile', str(ignore),
                       '--format', 'json', '--list-all-pkgs']
        for (index, partition), filtered in itertools.product(enumerate(partitions), (False, True)):
            label = 'filtered' if filtered else 'raw'
            stem = scanner if len(partitions) == 1 else f'{scanner}.part-{index + 1}'
            path = directory / f'{stem}.{label}.json'
            if filtered and (not vex or not vex.exists()):
                shutil.copyfile(directory / f'{stem}.raw.json', path)
                by_mode[True].append(by_mode[False][-1])
                continue
            arguments = command + [('sbom:' if scanner == 'grype' else '') + str(partition)]
            if scanner == 'grype':
                if not filtered:
                    arguments.extend(['--output', 'cyclonedx-json=' + str(directory / 'grype.packages.cdx.json')])
                if offline or filtered:
                    environment['GRYPE_DB_AUTO_UPDATE'] = 'false'
            elif offline or filtered or index > 0:
                arguments.extend(['--skip-db-update', '--skip-java-db-update'])
            if filtered:
                arguments.extend(['--vex', str(vex)])
            with path.open('w') as output, (directory / f'{stem}.{label}.log').open('w') as log:
                subprocess.run(arguments, env=environment, stdout=output, stderr=log, check=True, timeout=timeout)
            by_mode[filtered].append(read_json(path))
    results = []
    for filtered in (False, True):
        documents = by_mode[filtered]
        merged = merge_trivy(documents) if len(documents) > 1 else documents[0]
        if len(documents) > 1:
            label = 'filtered' if filtered else 'raw'
            (directory / f'{scanner}.{label}.json').write_text(json_text(merged), encoding='utf-8')
        results.append(merged)
    baseline, filtered = [findings(scanner, document) for document in results]
    if scanner == 'grype':
        catalog = read_json(directory / 'grype.packages.cdx.json')
        recognized = {package.get('purl') for package in component_index(catalog)[0].values()}
        database = copy.deepcopy(results[0].get('descriptor', {}).get('db'))
        if isinstance(database, dict) and isinstance(database.get('status'), dict):
            database['status'].pop('path', None)
    else:
        recognized = {package.get('Identifier', {}).get('PURL')
                      for result in results[0].get('Results', []) for package in result.get('Packages', [])}
        database = tool_version(scanner)
    coverage = scan_coverage(inventory, recognized)
    vex_document = read_json(vex) if vex and vex.exists() else None
    suppressed = []
    for key in sorted(baseline.keys() - filtered.keys()):
        finding = baseline[key]
        decisions = [statement for statement in vex_document['statements']
                     if statement['vulnerability'].get('name') == finding['vulnerability']
                     and any(lookup_identity(product['@id']) == lookup_identity(finding['purl'])
                             for product in statement['products'])]
        suppressed.append({**finding, 'vexStatements': decisions})
    return {'scanner': scanner, 'toolVersion': version, 'testedVersion': TESTED_SCANNER_VERSIONS[scanner],
            'database': database, 'coverage': coverage,
            'status': 'incomplete' if coverage['inputPackages'] and not coverage['recognizedPackages'] else 'complete',
            'checkedAt': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'vexApplied': vex_document is not None,
            'vexSha256': file_digest(vex) if vex_document else None,
            'inputSha256': file_digest(inventory), 'partitions': len(partitions),
            'rawMatches': len(baseline), 'filteredMatches': len(filtered),
            'suppressed': suppressed,
            'added': [filtered[key] for key in sorted(filtered.keys() - baseline.keys())]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--vex', type=Path)
    parser.add_argument('--scanner', choices=('grype', 'trivy'), default='grype')
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--timeout', type=int, default=SCAN_TIMEOUT_SECONDS, metavar='SECONDS')
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('Timeout must be positive seconds')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    owned = re.compile(re.escape(args.scanner) +
                       r'\.(summary\.json|packages\.cdx\.json|(?:part-[0-9]+\.)?(?:(?:raw|filtered)\.(?:json|log)|sbom\.json))')
    for path in (args.input, args.vex):
        if (path and path.resolve().parent == args.output_dir.resolve()
                and owned.fullmatch(path.resolve().name)):
            parser.error('Scan inputs must be separate from its outputs')
    for path in args.output_dir.iterdir():
        if owned.fullmatch(path.name):
            path.unlink()
    summary = args.output_dir / f'{args.scanner}.summary.json'
    try:
        result = scan(args.scanner, args.input.resolve(),
                      args.vex.resolve() if args.vex else None, args.output_dir.resolve(), args.offline, args.timeout)
        publish_files(args.output_dir, {summary.name: json_text(result)}, completion=summary.name)
        print(f'{args.scanner}: {result["rawMatches"]} baseline, '
              f'{result["filteredMatches"]} after VEX, {len(result["suppressed"])} suppressed')
        coverage = result['coverage']
        print(f'Package recognition: {coverage["recognizedPackages"]}/{coverage["inputPackages"]}; '
              'see the summary for coverage gaps')
        return int(result['status'] != 'complete')
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(f'VEX scan failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
