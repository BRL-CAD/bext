#!/usr/bin/env python3
"""Generate dependency checks from source identities and run local Renovate lookups."""

import argparse
from collections import Counter
import csv
import datetime
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote

from BextVex import checked_fields, digest, file_digest, json_text, purls, read_json, relative_name
from DependencyUpdateGit import ANCESTRY_TIMEOUT_SECONDS, compare_commits, source_repositories
from SupplyChainTools import package_membership, publish_files, tool_command, tool_version, UNGROUPED


SCHEMA_VERSION = 1
DEFAULT_VERSIONING = 'semver-coerced'
RELEASE_REF = re.compile(r'v?[0-9]+(?:\.[0-9]+){1,3}(?:[-+][A-Za-z0-9.-]+)?')
QUERY_FIELDS = ('depName', 'packageName', 'datasource', 'currentValue', 'versioning',
                'extractVersion', 'depType', 'currentDigest')
COMMIT_ID = re.compile(r'[0-9a-f]{40}')
LOOKUP_TIMEOUT_SECONDS = 1800
TESTED_RENOVATE_VERSION = '44.221.6'
CANDIDATE_STATUSES = {'updates_available', 'commit_changed'}
CSV_FIELDS = ('groups', 'component', 'package', 'kind', 'status', 'scope', 'current',
              'candidates', 'sourcePurl', 'managedBy', 'reason')
CHECK_FIELDS = {
    'release': {'datasource', 'packageName', 'currentValueFrom', 'versioning', 'extractVersion', 'baseline'},
    'commit': {'branch'}, 'parent': {'coveredBy'}, 'manual': set(),
}
FAILED_LOOKUPS = {'not_reported', 'lookup_failed'}
RENOVATE_FLAGS = ('--platform=local', '--dry-run=lookup', '--onboarding=false',
                  '--require-config=required', '--autodiscover=false',
                  '--allow-scripts=false', '--allow-plugins=false', '--binary-source=global')


def package_id(source):
    return 'SPDXRef-Package-' + re.sub(r'[^A-Za-z0-9.-]', '-', source)


def release_rules(root):
    rules = {}
    for path in sorted(root.glob('*/UpdateChecks.json')):
        document = read_json(path)
        checked_fields(document, ('schemaVersion', 'rules'), (), 'Release-check catalog')
        if document['schemaVersion'] != SCHEMA_VERSION or not isinstance(document['rules'], list):
            raise ValueError(f'Invalid release-check catalog: {path.parent.name}')
        for rule in document['rules']:
            checked_fields(rule, ('source',),
                           ('kind', 'reason', *set().union(*CHECK_FIELDS.values())),
                           'Release-check rule')
            source = relative_name(rule['source'])
            if source.split('/', 1)[0] != path.parent.name:
                raise ValueError('A release rule must belong to its dependency folder')
            kind = rule.get('kind', 'release')
            if not isinstance(kind, str) or kind not in CHECK_FIELDS:
                raise ValueError(f'Unknown update-check kind: {source}')
            if rule.keys() - CHECK_FIELDS[kind] - {'source', 'kind', 'reason'}:
                raise ValueError(f'Fields do not apply to the {kind} check: {source}')
            if not all(isinstance(value, str) and value for key, value in rule.items() if key != 'coveredBy'):
                raise ValueError(f'Invalid release-check values: {source}')
            if rule.get('currentValueFrom', 'ref') not in ('ref', 'version'):
                raise ValueError(f'Unknown currentValueFrom: {source}')
            if rule.get('datasource', 'git-tags') != 'git-tags':
                raise ValueError(f'Release checks currently support git-tags: {source}')
            if 'packageName' in rule and not rule['packageName'].startswith('https://'):
                raise ValueError(f'Release checks require an HTTPS repository: {source}')
            if rule.get('baseline', 'release') not in ('release', 'snapshot'):
                raise ValueError(f'Unknown release baseline: {source}')
            if kind == 'commit':
                branch = rule.get('branch', '')
                check = subprocess.run(['git', 'check-ref-format', 'refs/heads/' + branch],
                                       capture_output=True)
                if not branch or branch.startswith('-') or check.returncode:
                    raise ValueError(f'Commit checks require an explicit branch: {source}')
            if kind == 'manual' and not rule.get('reason'):
                raise ValueError(f'Manual checks require a reason: {source}')
            if kind == 'parent':
                targets = rule.get('coveredBy')
                if (not isinstance(targets, list) or not targets
                        or not all(isinstance(target, str) for target in targets)):
                    raise ValueError(f'Parent checks require coveredBy source paths: {source}')
                for target in targets:
                    relative_name(target)
                if len(set(targets)) != len(targets):
                    raise ValueError(f'Duplicate coveredBy sources: {source}')
            identifier = package_id(source)
            if identifier in rules:
                raise ValueError(f'Duplicate release-check rule: {source}')
            rules[identifier] = rule
    return rules


def upstream_git(purl):
    body = purl.partition('#')[0].partition('?')[0]
    base, separator, ref = body.rpartition('@')
    if not separator:
        return None, None
    if base.startswith('pkg:github/'):
        project = unquote(base[len('pkg:github/'):])
        return 'https://github.com/' + project + '.git', unquote(ref)
    if base.startswith('pkg:git/'):
        return 'https://' + unquote(base[len('pkg:git/'):]), unquote(ref)
    return None, None


def group_tags(record):
    return record['groups'] or [UNGROUPED]


def release_queries(source, root, only=(), groups=()):
    if source.get('spdxVersion') != 'SPDX-2.3':
        raise ValueError('A canonical SPDX 2.3 source inventory is required')
    rules = release_rules(root)
    membership = {package['SPDXID']: package_membership(package) for package in source['packages']}
    known_groups = {group for _, tags in membership.values() for group in (tags or [UNGROUPED])}
    if set(groups) - known_groups:
        raise ValueError('Unknown consumer group: ' + ', '.join(sorted(set(groups) - known_groups)))
    dependencies, coverage, found = [], [], set()
    wrappers = [path.parent.name for path in root.glob('*/BextPackage.cmake')]
    identifiers = {package['SPDXID'] for package in source['packages']}
    parents = {}
    for relation in source.get('relationships', []):
        if relation['relationshipType'] == 'CONTAINS':
            child = relation['relatedSpdxElement']
            if child in parents:
                raise ValueError(f'Multiple containing packages: {child}')
            parents[child] = relation['spdxElementId']
    repositories = source_repositories(root) if any(
        rule.get('kind') == 'commit' for rule in rules.values()) else {}
    unknown = rules.keys() - identifiers
    if unknown:
        raise ValueError('Release rules name absent source packages: ' + ', '.join(sorted(unknown)))
    for package in source['packages']:
        identifier = package['SPDXID']
        identity = purls(package)
        if len(identity) != 1 or 'bext_build=' in identity[0]:
            raise ValueError(f'{identifier}: expected one canonical source PURL')
        # Wrapper names can contain hyphens. Resolve ownership against folders.
        owners = [name for name in wrappers
                  if identifier.startswith('SPDXRef-Package-' + name + '-')]
        if len(owners) != 1:
            raise ValueError(f'{identifier}: expected one owning dependency folder')
        owner = owners[0]
        declared_owner, consumer_tags = membership[identifier]
        if declared_owner != owner:
            raise ValueError(f'{identifier}: consumer-group metadata names a different component')
        if only and owner not in only:
            continue
        found.add(owner)
        if groups and not set(groups).intersection(consumer_tags or [UNGROUPED]):
            continue
        record = {'package': identifier, 'component': owner, 'name': package['name'],
                  'version': package['versionInfo'], 'sourcePurl': identity[0], 'groups': consumer_tags}
        if identifier in parents:
            record['managedBy'] = parents[identifier]
        repository, ref = upstream_git(identity[0])
        rule = rules.get(identifier, {})
        kind = rule.get('kind', 'release')
        record['checkKind'] = kind
        if 'reason' in rule:
            record['reason'] = rule['reason']
        if kind == 'manual':
            record['status'] = 'manual_import'
        elif kind == 'parent':
            record.update(status='parent_managed', coveredBy=[package_id(path) for path in rule['coveredBy']])
        elif kind == 'commit':
            origin = repositories.get(rule['source'])
            if not origin or not origin['repository'].startswith('https://'):
                raise ValueError(f'{identifier}: commit checks require an HTTPS gitlink repository')
            if ref != origin['commit']:
                raise ValueError(f'{identifier}: the source PURL does not match the committed gitlink')
            query = {'depName': identifier, 'depType': owner, 'packageName': origin['repository'],
                     'datasource': 'git-refs', 'currentValue': rule['branch'],
                     'currentDigest': origin['commit'], 'versioning': 'git'}
            dependencies.append(query)
            record.update(status='pending', query=query)
        else:
            _release_query(record, rule, repository, ref, dependencies)
            if record['status'] == 'not_checked' and identifier in parents:
                record.update(checkKind='parent', status='parent_managed', coveredBy=[parents[identifier]],
                              reason='Update through the containing source package')
        coverage.append(record)
    _validate_coverage(coverage, identifiers, rules)
    if set(only) - found:
        raise ValueError('Unknown dependency selection: ' + ', '.join(sorted(set(only) - found)))
    if groups and not coverage:
        raise ValueError('The selected dependencies and consumer groups do not overlap')
    return dependencies, coverage


def _release_query(record, rule, repository, ref, dependencies):
    repository = rule.get('packageName', repository)
    current = record['version'] if rule.get('currentValueFrom') == 'version' else ref
    if not repository or not current:
        record.update(checkKind='unconfigured', status='not_checked', reason='An upstream release rule is needed')
    elif COMMIT_ID.fullmatch(current):
        record.update(checkKind='unconfigured', status='not_checked',
                      reason='A commit is not a release baseline; use a reviewed version or a commit check')
    elif not rule and not RELEASE_REF.fullmatch(current):
        record.update(checkKind='unconfigured', status='not_checked',
                      reason='A revision or nonstandard tag needs a release rule')
    else:
        query = {'depName': record['package'], 'depType': record['component'], 'packageName': repository,
                 'datasource': 'git-tags', 'currentValue': current,
                 'versioning': rule.get('versioning', DEFAULT_VERSIONING)}
        if 'extractVersion' in rule:
            query['extractVersion'] = rule['extractVersion']
        dependencies.append(query)
        record.update(status='pending', query=query, baseline=rule.get('baseline', 'release'))


def _validate_coverage(coverage, identifiers, rules):
    records = {identifier: {'coveredBy': [package_id(path) for path in rule['coveredBy']]}
               for identifier, rule in rules.items() if rule.get('kind') == 'parent'}
    records.update({record['package']: record for record in coverage})

    def visit(identifier, pending):
        if identifier not in identifiers:
            raise ValueError(f'Coverage names an absent source package: {identifier}')
        if identifier in pending:
            raise ValueError(f'Cyclic parent coverage: {identifier}')
        record = records.get(identifier, {})
        for target in record.get('coveredBy', []):
            visit(target, pending | {identifier})

    for identifier in records:
        visit(identifier, set())


def resolve_coverage(coverage):
    records = {record['package']: record for record in coverage}

    def leaves(identifier):
        record = records.get(identifier)
        if not record:
            return {identifier: 'outside_selection'}
        if record['checkKind'] != 'parent':
            return {identifier: record['status']}
        results = {}
        for target in record['coveredBy']:
            results.update(leaves(target))
        return results

    for record in coverage:
        if record['checkKind'] == 'parent':
            record['coveredChecks'] = leaves(record['package'])


def renovate_config():
    query = 'dependencies.{' + ', '.join('"' + field + '": ' + field for field in QUERY_FIELDS) + '}'
    return {'enabledManagers': ['custom.jsonata'], 'dependencyDashboard': False,
            'automerge': False, 'customManagers': [{
                'customType': 'jsonata', 'fileFormat': 'json',
                'managerFilePatterns': ['/^dependency-updates\\.json$/'],
                'matchStrings': [query]}]}


def logged_dependencies(value):
    if isinstance(value, dict):
        if isinstance(value.get('deps'), list):
            for dependency in value['deps']:
                if isinstance(dependency, dict) and 'depName' in dependency:
                    yield dependency
        for child in value.values():
            yield from logged_dependencies(child)
    elif isinstance(value, list):
        for child in value:
            yield from logged_dependencies(child)


def collect_results(log, coverage, ancestry_directory=None, ancestry_timeout=ANCESTRY_TIMEOUT_SECONDS):
    import json

    latest = {}
    diagnostics = []
    log_errors = []
    empty_repositories = set()
    for line in log.read_text(encoding='utf-8').splitlines():
        try:
            entry = json.loads(line)
        except ValueError:
            log_errors.append('Malformed JSON in the Renovate result log')
            continue
        if not isinstance(entry, dict):
            continue
        for dependency in logged_dependencies(entry):
            if 'updates' in dependency or 'skipReason' in dependency:
                latest[dependency['depName']] = dependency
        if entry.get('level', 0) >= 40:
            diagnostics.append(entry.get('msg', 'Renovate diagnostic'))
        if entry.get('level', 0) >= 50:
            log_errors.append(entry.get('msg', 'Renovate error'))
        if entry.get('msg') == 'Found no results from datasource that look like a version':
            empty_repositories.add(entry.get('dependency'))
    for record in coverage:
        if record['status'] != 'pending':
            continue
        result = latest.get(record['package'])
        if log_errors:
            record.update(status='lookup_failed', reason='; '.join(sorted(set(log_errors))))
        elif result is None:
            record.update(status='not_reported', reason='Renovate did not report a lookup result')
        elif result.get('skipReason') or result.get('warnings') or result.get('errors'):
            record.update(status='lookup_failed', reason=result.get('skipReason', 'Lookup warning'),
                          details=result)
        elif not isinstance(result.get('updates'), list) or not all(
                isinstance(update, dict) for update in result['updates']):
            record.update(status='lookup_failed', reason='Renovate returned malformed updates', details=result)
        elif record.get('query', {}).get('packageName') in empty_repositories:
            record.update(status='lookup_failed', reason='No releases matched the configured version rule')
        else:
            updates = result['updates']
            record['updates'] = updates
            if record['checkKind'] == 'commit':
                _commit_result(record, updates, ancestry_directory, ancestry_timeout)
            else:
                if not all(isinstance(update.get('newValue', update.get('newVersion')), str)
                           and update.get('newValue', update.get('newVersion')) for update in updates):
                    record.update(status='lookup_failed', reason='Release candidates have no version', details=result)
                    continue
                current = 'snapshot_no_newer_release' if record.get('baseline') == 'snapshot' else 'current'
                record['status'] = 'updates_available' if updates else current
    return diagnostics


def _commit_result(record, updates, directory, timeout):
    query = record['query']
    candidates = [update.get('newDigest') for update in updates] if updates else [query['currentDigest']]
    if not all(isinstance(value, str) and COMMIT_ID.fullmatch(value) for value in candidates) or len(set(candidates)) != 1:
        record.update(status='lookup_failed', reason='Renovate did not report one full candidate commit')
        return
    candidate = candidates[0]
    if candidate == query['currentDigest']:
        record.update(status='commit_current', commitCandidate=candidate,
                      ancestry={'relation': 'same', 'ahead': 0, 'behind': 0})
        return
    ancestry = {'relation': 'unknown', 'reason': 'Ancestry was not checked'}
    if directory is not None:
        ancestry = compare_commits(query['packageName'], query['currentDigest'], candidate, directory, timeout)
    record.update(status='commit_changed', commitCandidate=candidate, ancestry=ancestry)


def run_lookup(executable, directory, dependencies, config, timeout=LOOKUP_TIMEOUT_SECONDS):
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(('RENOVATE_', 'LOG_')) and key not in (
                       'GITHUB_TOKEN', 'GITHUB_COM_TOKEN', 'GH_TOKEN', 'GITLAB_TOKEN', 'GITEA_TOKEN')}
    environment.update(LOG_LEVEL='debug', LOG_FORMAT='json')
    log = directory / 'renovate.log.jsonl'
    # An ignored build directory can inherit the enclosing repository's file
    # filtering. Keep this plain directory outside the source checkout.
    with tempfile.TemporaryDirectory(prefix='bext-release-lookup-') as temporary:
        work = Path(temporary)
        (work / 'dependency-updates.json').write_text(json_text({'dependencies': dependencies}))
        (work / 'renovate.json').write_text(json_text(config))
        with log.open('w', encoding='utf-8') as output, (directory / 'renovate.stderr.log').open('w') as error:
            result = subprocess.run([*tool_command(executable), *RENOVATE_FLAGS,
                                     '--cache-dir=' + str(directory / 'cache')], cwd=work,
                                    env=environment, stdout=output, stderr=error, timeout=timeout)
    return result.returncode


def installation_help(host=sys.platform):
    windows = host == 'win32'
    if windows:
        setup = ('Windows: extract a supported Node.js Windows ZIP into a user-owned directory '
                 'and add it to PATH in PowerShell. Use the renovate.cmd npm launcher.')
    elif host.startswith('freebsd'):
        setup = ('FreeBSD: use an available Node 24/npm installation (node24/npm-node24), '
                 'or build Node into a user-owned prefix; no global npm install is needed.')
    elif host == 'darwin':
        setup = ('macOS: extract the Node.js archive for the host architecture into a user-owned '
                 'directory and add its bin directory to PATH; an existing Homebrew Node also works.')
    else:
        setup = ('Linux/Unix: extract a supported Node.js archive into a user-owned directory '
                 'and add its bin directory to PATH.')
    launcher = 'renovate.cmd' if windows else 'renovate'
    return '\n'.join([
        setup, 'Renovate 44.221.6 supports Node ^24.11.0 or ^26.13.0.',
        'Download Node: https://nodejs.org/en/download',
        'From the bext checkout, install the optional CLI without administrator access:',
        '  npm install --prefix build/renovate-tools --ignore-scripts --omit=optional --no-audit --no-fund renovate@44.221.6',
        'Then reconfigure the existing build (substitute its directory for <build>):',
        '  cmake -S . -B <build> -DBEXT_RENOVATE_EXECUTABLE="' +
        ('$PWD/build/renovate-tools/node_modules/.bin/' + launcher) + '"',
        'Retry: cmake --build <build> --target dependency_update_report',
        'Setup guide: MAINTAINING.md#setting-up-the-external-supply-chain-tools',
        'Offline alternative: cmake --build <build> --target dependency_update_inputs',
    ])


def summarize(records):
    candidates = [record for record in records if record['status'] in CANDIDATE_STATUSES]
    return {
        'packageCount': len(records),
        'counts': dict(sorted(Counter(record['status'] for record in records).items())),
        'checkKinds': dict(sorted(Counter(record['checkKind'] for record in records).items())),
        'candidates': {
            'topLevelReleases': sum(record['checkKind'] == 'release' and not record.get('managedBy')
                                    for record in candidates),
            'embeddedReleases': sum(record['checkKind'] == 'release' and bool(record.get('managedBy'))
                                    for record in candidates),
            'commitChanges': sum(record['checkKind'] == 'commit' for record in candidates),
        },
    }


def candidate_values(record):
    if record['status'] == 'commit_changed':
        return [record['commitCandidate']]
    if record['status'] != 'updates_available':
        return []
    return [update.get('newValue', update.get('newVersion', '?')) for update in record.get('updates', [])]


def write_report(directory, report):
    resolve_coverage(report['packages'])
    report.update(summarize(report['packages']))
    groups = sorted({group for record in report['packages'] for group in group_tags(record)})
    selected_groups = report.get('selection', {}).get('groups', [])
    report['byGroup'] = {
        group: summarize([record for record in report['packages'] if group in group_tags(record)])
        for group in groups if not selected_groups or group in selected_groups
    }
    lines = ['Dependency update lookup: ' + report['status'],
             'Coverage: ' + ', '.join(f'{count} {status}' for status, count in report['counts'].items()),
             'Checks: ' + ', '.join(f'{count} {kind}' for kind, count in report['checkKinds'].items()),
             'Source inventory includes embedded packages that a build may exclude.',
             'Candidates require mirror verification, integration tests, and review.',
             'Groups are declared memberships, overlap, and do not imply a complete build profile.',
             'Include supporting groups when reviewing a build; UNGROUPED denotes no declared consumer group.',
             '', 'Candidates by consumer group:']
    for group, summary in report['byGroup'].items():
        counts = summary['candidates']
        lines.append(f'  {group}: {counts["topLevelReleases"]} top-level releases, '
                     f'{counts["embeddedReleases"]} embedded releases, {counts["commitChanges"]} commit changes')
    lines.extend(['', 'Package details:'])
    for record in report['packages']:
        updates = ', '.join(candidate_values(record))
        detail = updates or record.get('reason', '')
        if record['checkKind'] == 'commit':
            query = record['query']
            detail = query['currentValue'] + ': ' + query['currentDigest']
            if 'commitCandidate' in record:
                detail += ' -> ' + record['commitCandidate'] + ' (' + record['ancestry']['relation'] + ')'
            if record.get('reason'):
                detail += '; ' + record['reason']
        elif record['checkKind'] == 'parent':
            detail = '; '.join(identifier + ': ' + status
                               for identifier, status in record['coveredChecks'].items())
        notes = [detail] if detail else []
        if record.get('baseline') == 'snapshot':
            notes.append('comparison baseline is a development snapshot')
        if record.get('managedBy'):
            notes.append('update through ' + record['managedBy'])
        detail = '; '.join(notes)
        lines.append('[' + ', '.join(group_tags(record)) + '] ' +
                     f'{record["component"]}: {record["name"]} {record["version"]}: '
                     f'{record["checkKind"]}/{record["status"]}' + (': ' + detail if detail else ''))
    stream = io.StringIO(newline='')
    writer = csv.DictWriter(stream, fieldnames=CSV_FIELDS)
    writer.writeheader()
    for record in report['packages']:
        writer.writerow({
            'groups': ';'.join(group_tags(record)), 'component': record['component'],
            'package': record['name'], 'kind': record['checkKind'], 'status': record['status'],
            'scope': 'embedded' if record.get('managedBy') else 'top-level',
            'current': record['query']['currentDigest'] if record['checkKind'] == 'commit' else record['version'],
            'candidates': ', '.join(candidate_values(record)), 'sourcePurl': record['sourcePurl'],
            'managedBy': record.get('managedBy', ''), 'reason': record.get('reason', ''),
        })
    publish_files(directory, {
        'dependency-update-report.json': json_text(report),
        'dependency-update-report.txt': '\n'.join(lines) + '\n',
        'dependency-update-report.csv': stream.getvalue(),
    }, completion='dependency-update-report.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sbom', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renovate', default='renovate')
    parser.add_argument('--only', action='append', default=[], metavar='DEPENDENCY')
    parser.add_argument('--group', action='append', default=[], metavar='GROUP')
    parser.add_argument('--generate-only', action='store_true')
    parser.add_argument('--lookup-timeout', type=int, default=LOOKUP_TIMEOUT_SECONDS, metavar='SECONDS')
    parser.add_argument('--ancestry-timeout', type=int, default=ANCESTRY_TIMEOUT_SECONDS, metavar='SECONDS')
    args = parser.parse_args()
    if args.lookup_timeout <= 0 or args.ancestry_timeout <= 0:
        parser.error('Timeouts must be positive seconds')
    directory = args.output_dir.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    names = ('dependency-updates.json', 'renovate.json', 'dependency-update-report.json',
             'dependency-update-report.txt', 'dependency-update-report.csv',
             'renovate.log.jsonl', 'renovate.stderr.log')
    if args.sbom.resolve() in {directory / name for name in names}:
        parser.error('The source inventory must be separate from generated outputs')
    for name in names:
        (directory / name).unlink(missing_ok=True)
    try:
        source = read_json(args.sbom)
        dependencies, coverage = release_queries(source, args.source_root, args.only, args.group)
        config = renovate_config()
        for name, document in [('dependency-updates.json', {'dependencies': dependencies}),
                               ('renovate.json', config)]:
            (directory / name).write_text(json_text(document), encoding='utf-8')
        report = {'schemaVersion': SCHEMA_VERSION, 'sourceDocument': source['documentNamespace'],
                  'selection': {'components': sorted(set(args.only)), 'groups': sorted(set(args.group))},
                  'checkedAt': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                  'sourceSha256': file_digest(args.sbom),
                  'policySha256': digest({'queries': dependencies, 'coverage': coverage, 'config': config}),
                  'tool': {'name': 'renovate', 'version': None,
                           'testedVersion': TESTED_RENOVATE_VERSION},
                  'packages': coverage, 'status': 'generated', 'diagnostics': []}
        result = 0
        if not args.generate_only:
            executable = shutil.which(args.renovate)
            if not executable or not shutil.which('node'):
                report['status'] = 'tool_unavailable'
                report['diagnostics'].append('Renovate and Node.js must both be available')
                result = 1
            else:
                try:
                    report['tool']['version'] = tool_version(executable)
                    if dependencies:
                        result = run_lookup(executable, directory, dependencies, config, args.lookup_timeout)
                except (subprocess.TimeoutExpired, subprocess.CalledProcessError, OSError, ValueError) as error:
                    result = 1
                    report['diagnostics'].append('Renovate failed: ' + str(error))
                    if report['tool']['version'] is None:
                        report['status'] = 'tool_unavailable'
                log = directory / 'renovate.log.jsonl'
                if log.exists():
                    report['diagnostics'].extend(collect_results(
                        log, coverage, directory / 'cache' / 'ancestry', args.ancestry_timeout))
                else:
                    for record in coverage:
                        if record['status'] == 'pending':
                            record.update(status='not_reported', reason='Renovate did not produce a result log')
                incomplete = any(record['status'] in FAILED_LOOKUPS or
                                 (record.get('ancestry', {}).get('relation') == 'unknown')
                                 for record in coverage)
                if report['status'] != 'tool_unavailable':
                    report['status'] = 'failed' if result else 'incomplete' if incomplete else 'complete'
                result = result or int(incomplete)
        report['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        write_report(directory, report)
        print('Dependency update lookup: ' + report['status'])
        print('Report: ' + str(directory / 'dependency-update-report.txt'))
        if report['status'] == 'tool_unavailable':
            print('\n'.join(report['diagnostics']), file=sys.stderr)
            print(installation_help(), file=sys.stderr)
        return result
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        print(f'Dependency update lookup failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
