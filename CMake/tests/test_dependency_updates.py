#!/usr/bin/env python3
"""Offline checks for release discovery inputs and the local-only CLI adapter."""

import copy
import csv
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


MODULE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE))
from DependencyUpdates import (collect_results, release_queries, renovate_config,
                               resolve_coverage, run_lookup, write_report, installation_help, main)
from DependencyUpdateGit import compare_commits
from SupplyChainTools import tool_command


class DependencyUpdateTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-release-check-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / 'source'
        self.wrapper = self.source / 'probe'
        self.wrapper.mkdir(parents=True)
        (self.wrapper / 'BextPackage.cmake').write_text('')
        self.output = self.root / 'output'
        self.output.mkdir()
        self.package = {'SPDXID': 'SPDXRef-Package-probe-source', 'name': 'Probe',
                        'comment': 'bext project: probe; groups: BRLCAD, APPLESEED; output: install;',
                        'annotations': [{'annotator': 'Tool: bext:membership', 'comment': json.dumps({
                            'schemaVersion': 1, 'component': 'probe', 'groups': ['BRLCAD', 'APPLESEED']})}],
                        'versionInfo': '1.2.3', 'externalRefs': [{
                            'referenceType': 'purl', 'referenceLocator': 'pkg:github/example/probe@v1.2.3'}]}
        self.sbom = {'spdxVersion': 'SPDX-2.3', 'documentNamespace': 'https://example.invalid/source',
                     'packages': [self.package]}

    def queries(self, only=(), groups=()):
        return release_queries(self.sbom, self.source, only, groups)

    def policy(self, **fields):
        (self.wrapper / 'UpdateChecks.json').write_text(json.dumps({
            'schemaVersion': 1, 'rules': [{'source': 'probe/source', **fields}]}))

    def provider(self):
        wrapper = self.source / 'provider'
        wrapper.mkdir()
        (wrapper / 'BextPackage.cmake').write_text('')
        package = copy.deepcopy(self.package)
        package.update(SPDXID='SPDXRef-Package-provider-source', name='Provider',
                       comment='bext project: provider; groups: GDAL; output: install;')
        self.membership(package, component='provider', groups=['GDAL'])
        self.sbom['packages'].append(package)
        return package

    def membership(self, package=None, **fields):
        package = package if package is not None else self.package
        package['annotations'] = [{'annotator': 'Tool: bext:membership', 'comment': json.dumps({
            'schemaVersion': 1, 'component': 'probe', 'groups': [], **fields})}]

    def committed_source(self):
        def git(*arguments):
            return subprocess.check_output(['git', '-C', str(self.source), *arguments], text=True).strip()

        git('init', '-q')
        git('config', 'user.name', 'Fixture')
        git('config', 'user.email', 'fixture@example.invalid')
        (self.source / 'seed').write_text('seed')
        git('add', 'seed')
        git('commit', '-qm', 'Seed')
        pin = git('rev-parse', 'HEAD')
        (self.source / '.gitmodules').write_text(
            '[submodule "probe/source"]\npath = probe/source\nurl = https://example.invalid/consumed.git\n'
            '    ignore = dirty\n    shallow = true\n')
        git('add', '.gitmodules')
        git('update-index', '--add', '--cacheinfo', '160000,' + pin + ',probe/source')
        git('commit', '-qm', 'Pin source')
        self.package['externalRefs'][0]['referenceLocator'] = 'pkg:github/example/probe@' + pin
        return pin

    def test_versions_and_upstream_repository_come_from_source_inventory(self):
        queries, coverage = self.queries()
        self.assertEqual(queries[0]['packageName'], 'https://github.com/example/probe.git')
        self.assertEqual(queries[0]['currentValue'], 'v1.2.3')
        self.assertEqual(coverage[0]['status'], 'pending')
        self.package['versionInfo'] = '2.0.0'
        self.package['externalRefs'][0]['referenceLocator'] = 'pkg:github/example/probe@v2.0.0'
        self.assertEqual(self.queries()[0][0]['currentValue'], 'v2.0.0')

    def test_arbitrary_revisions_and_nonstandard_tags_need_a_rule(self):
        for ref in ('a' * 40, 'release-1-2-3'):
            with self.subTest(ref=ref):
                self.package['externalRefs'][0]['referenceLocator'] = 'pkg:github/example/probe@' + ref
                queries, coverage = self.queries()
                self.assertFalse(queries)
                self.assertEqual(coverage[0]['status'], 'not_checked')

    def test_local_rule_supports_maintained_sources_without_another_version_pin(self):
        self.package['externalRefs'][0]['referenceLocator'] = 'pkg:generic/probe@1.2.3'
        self.policy(packageName='https://example.invalid/probe.git', currentValueFrom='version')
        queries, _ = self.queries()
        self.assertEqual(queries[0]['currentValue'], '1.2.3')
        self.package['versionInfo'] = '2.0.0'
        self.assertEqual(self.queries()[0][0]['currentValue'], '2.0.0')

    def test_unknown_selection_and_misplaced_rules_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unknown dependency'):
            self.queries(only=['missing'])
        path = self.wrapper / 'UpdateChecks.json'
        path.write_text(json.dumps({'schemaVersion': 1, 'rules': [{'source': 'other/source'}]}))
        with self.assertRaisesRegex(ValueError, 'dependency folder'):
            self.queries()

    def test_groups_preserve_shared_membership_and_filter_by_union_and_component_intersection(self):
        self.provider()
        _, coverage = self.queries(groups=['BRLCAD'])
        self.assertEqual([record['component'] for record in coverage], ['probe'])
        self.assertEqual(coverage[0]['groups'], ['APPLESEED', 'BRLCAD'])
        _, coverage = self.queries(groups=['BRLCAD', 'GDAL'])
        self.assertEqual(len(coverage), 2)
        _, coverage = self.queries(only=['provider'], groups=['BRLCAD', 'GDAL'])
        self.assertEqual([record['component'] for record in coverage], ['provider'])
        with self.assertRaisesRegex(ValueError, 'do not overlap'):
            self.queries(only=['probe'], groups=['GDAL'])
        with self.assertRaisesRegex(ValueError, 'Unknown consumer group'):
            self.queries(groups=['missing'])

    def test_explicitly_empty_groups_are_distinct_from_missing_or_invalid_metadata(self):
        self.membership(groups=[])
        self.package['comment'] = 'Wording can change without changing membership.'
        _, coverage = self.queries(groups=['UNGROUPED'])
        self.assertEqual(coverage[0]['groups'], [])
        for fields, message in [({'groups': ['BRLCAD', 'BRLCAD']}, 'invalid'),
                                ({'groups': ['bad/group']}, 'invalid'),
                                ({'groups': ['UNGROUPED']}, 'invalid'),
                                ({'groups': 'BRLCAD'}, 'invalid'),
                                ({'component': 'provider', 'groups': ['GDAL']}, 'different component')]:
            with self.subTest(fields=fields):
                self.membership(**fields)
                with self.assertRaisesRegex(ValueError, message):
                    self.queries()
        self.package.pop('annotations')
        with self.assertRaisesRegex(ValueError, 'regenerate the source SBOM'):
            self.queries()

    def test_commit_checks_use_the_committed_pin_and_consumed_repository(self):
        pin = self.committed_source()
        self.policy(kind='commit', branch='main')
        queries, coverage = self.queries()
        self.assertEqual(queries[0]['datasource'], 'git-refs')
        self.assertEqual(queries[0]['packageName'], 'https://example.invalid/consumed.git')
        self.assertEqual(queries[0]['currentValue'], 'main')
        self.assertEqual(queries[0]['currentDigest'], pin)
        self.assertEqual(coverage[0]['checkKind'], 'commit')
        self.package['externalRefs'][0]['referenceLocator'] = 'pkg:github/example/probe@' + 'a' * 40
        with self.assertRaisesRegex(ValueError, 'committed gitlink'):
            self.queries()

    def test_commit_checks_reject_implicit_or_invalid_branch_and_repository_overrides(self):
        for fields in ({'branch': ''}, {'branch': '../escape'},
                       {'branch': 'main', 'packageName': 'https://example.invalid/other.git'}):
            with self.subTest(fields=fields):
                self.policy(kind='commit', **fields)
                with self.assertRaises(ValueError):
                    self.queries()

    def test_contained_snapshots_follow_parent_while_release_checks_stay_independent(self):
        child = copy.deepcopy(self.package)
        child['SPDXID'] = 'SPDXRef-Package-probe-source-child'
        child['externalRefs'][0]['referenceLocator'] = 'pkg:github/example/probe@' + 'a' * 40 + '#child'
        self.sbom['packages'].append(child)
        self.sbom['relationships'] = [{'relationshipType': 'CONTAINS',
                                       'spdxElementId': self.package['SPDXID'],
                                       'relatedSpdxElement': child['SPDXID']}]
        queries, coverage = self.queries()
        self.assertEqual(len(queries), 1)
        self.assertEqual(coverage[1]['status'], 'parent_managed')
        coverage[0]['status'] = 'updates_available'
        resolve_coverage(coverage)
        self.assertEqual(coverage[1]['coveredChecks'], {self.package['SPDXID']: 'updates_available'})
        child['externalRefs'][0]['referenceLocator'] = 'pkg:github/example/independent@v1.2.3'
        queries, coverage = self.queries()
        self.assertEqual(len(queries), 2)
        self.assertEqual(coverage[1]['managedBy'], self.package['SPDXID'])
        self.assertEqual(coverage[1]['checkKind'], 'release')

    def test_parent_coverage_rejects_cycles_and_missing_sources(self):
        for target, message in [('probe/source', 'Cyclic'), ('probe/missing', 'absent')]:
            with self.subTest(target=target):
                self.policy(kind='parent', coveredBy=[target])
                with self.assertRaisesRegex(ValueError, message):
                    self.queries()

    def test_aggregate_coverage_can_follow_multiple_modules_and_filtered_selections(self):
        module = copy.deepcopy(self.package)
        module['SPDXID'] = 'SPDXRef-Package-probe-source-module'
        self.sbom['packages'].append(module)
        provider = self.provider()
        self.policy(kind='parent', coveredBy=['probe/source/module', 'provider/source'])
        queries, coverage = self.queries(only=['probe'])
        self.assertEqual(len(queries), 1)
        coverage[1]['status'] = 'updates_available'
        resolve_coverage(coverage)
        self.assertEqual(coverage[0]['coveredChecks'], {
            module['SPDXID']: 'updates_available', provider['SPDXID']: 'outside_selection'})
        _, coverage = self.queries(groups=['BRLCAD'])
        resolve_coverage(coverage)
        self.assertEqual(coverage[0]['coveredChecks'][provider['SPDXID']], 'outside_selection')

    def test_regular_reports_include_shared_groups_unique_totals_and_full_commit_digests(self):
        self.provider()
        _, coverage = self.queries()
        coverage[0].update(status='updates_available', updates=[{'newValue': 'v1.3.0'}])
        child = copy.deepcopy(coverage[0])
        child.update(package=coverage[0]['package'] + '-child', managedBy=coverage[0]['package'])
        coverage.append(child)
        coverage[1].update(checkKind='commit', groups=[], status='commit_changed',
                           query={'currentValue': 'main', 'currentDigest': 'a' * 40},
                           commitCandidate='b' * 40, ancestry={'relation': 'ahead'})
        report = {'status': 'complete', 'packages': coverage}
        write_report(self.output, report)
        saved = json.loads((self.output / 'dependency-update-report.json').read_text())
        self.assertEqual(saved['packageCount'], 3)
        self.assertEqual(saved['candidates'], {
            'topLevelReleases': 1, 'embeddedReleases': 1, 'commitChanges': 1})
        self.assertEqual(saved['byGroup']['BRLCAD']['packageCount'], 2)
        self.assertEqual(saved['byGroup']['APPLESEED'], saved['byGroup']['BRLCAD'])
        self.assertEqual(saved['byGroup']['UNGROUPED']['candidates']['commitChanges'], 1)
        text = (self.output / 'dependency-update-report.txt').read_text()
        self.assertIn('BRLCAD: 1 top-level releases, 1 embedded releases, 0 commit changes', text)
        self.assertIn('[APPLESEED, BRLCAD] probe:', text)
        self.assertIn('[UNGROUPED] provider:', text)
        with (self.output / 'dependency-update-report.csv').open(newline='') as stream:
            rows = list(csv.DictReader(stream))
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0]['groups'], 'APPLESEED;BRLCAD')
        self.assertEqual(rows[0]['candidates'], 'v1.3.0')
        self.assertEqual(rows[2]['scope'], 'embedded')
        self.assertEqual(rows[1]['groups'], 'UNGROUPED')
        self.assertEqual(rows[1]['current'], 'a' * 40)
        self.assertEqual(rows[1]['candidates'], 'b' * 40)
        report['selection'] = {'groups': ['BRLCAD']}
        report['packages'] = [coverage[0], child]
        write_report(self.output, report)
        self.assertEqual(list(report['byGroup']), ['BRLCAD'])
        self.assertEqual(report['packages'][0]['groups'], ['APPLESEED', 'BRLCAD'])

    def test_failed_commit_lookup_does_not_export_branch_as_candidate(self):
        _, coverage = self.queries()
        coverage[0].update(checkKind='commit', status='lookup_failed',
                           query={'currentValue': 'main', 'currentDigest': 'a' * 40},
                           updates=[{'newValue': 'main'}])
        write_report(self.output, {'status': 'incomplete', 'packages': coverage})
        with (self.output / 'dependency-update-report.csv').open(newline='') as stream:
            self.assertEqual(next(csv.DictReader(stream))['candidates'], '')

    def test_ancestry_failure_is_visible_without_claiming_a_newer_commit(self):
        self.committed_source()
        self.policy(kind='commit', branch='main')
        _, coverage = self.queries()
        log = self.output / 'commit.jsonl'
        log.write_text(json.dumps({'deps': [{'depName': self.package['SPDXID'],
                                           'updates': [{'newDigest': 'b' * 40}]}]}))
        with mock.patch('DependencyUpdates.compare_commits', return_value={
                'relation': 'unknown', 'reason': 'History unavailable'}):
            collect_results(log, coverage, self.output / 'ancestry')
        self.assertEqual(coverage[0]['status'], 'commit_changed')
        self.assertEqual(coverage[0]['ancestry']['relation'], 'unknown')

    def test_unknown_ancestry_makes_the_cli_report_incomplete(self):
        self.committed_source()
        self.policy(kind='commit', branch='main')
        path = self.root / 'source.json'
        path.write_text(json.dumps(self.sbom))
        arguments = ['DependencyUpdates.py', '--sbom', str(path), '--source-root', str(self.source),
                     '--output-dir', str(self.output)]

        def lookup(*args):
            (self.output / 'renovate.log.jsonl').write_text(json.dumps({'deps': [{
                'depName': self.package['SPDXID'], 'updates': [{'newDigest': 'b' * 40}]}]}))
            return 0

        with mock.patch.object(sys, 'argv', arguments):
            with mock.patch('DependencyUpdates.shutil.which', return_value='fixture'):
                with mock.patch('DependencyUpdates.tool_version', return_value='44.221.6'), \
                        mock.patch('DependencyUpdates.run_lookup', side_effect=lookup):
                    with mock.patch('DependencyUpdates.compare_commits', return_value={'relation': 'unknown'}):
                        self.assertEqual(main(), 1)
        report = json.loads((self.output / 'dependency-update-report.json').read_text())
        self.assertEqual(report['status'], 'incomplete')

    def test_snapshot_comparison_does_not_claim_a_current_release(self):
        self.policy(baseline='snapshot')
        _, coverage = self.queries()
        log = self.output / 'snapshot.jsonl'
        log.write_text(json.dumps({'deps': [{'depName': self.package['SPDXID'], 'updates': []}]}))
        collect_results(log, coverage)
        self.assertEqual(coverage[0]['status'], 'snapshot_no_newer_release')

    def test_manual_import_is_an_explained_gap(self):
        self.policy(kind='manual', reason='An upstream import needs review')
        queries, coverage = self.queries()
        self.assertFalse(queries)
        self.assertEqual(coverage[0]['status'], 'manual_import')
        self.policy(kind='manual')
        with self.assertRaisesRegex(ValueError, 'require a reason'):
            self.queries()

    def test_commit_results_preserve_direction_and_missing_digest_failures(self):
        self.committed_source()
        self.policy(kind='commit', branch='main')
        _, coverage = self.queries()
        log = self.output / 'commit.jsonl'
        log.write_text(json.dumps({'deps': [{'depName': self.package['SPDXID'],
                                           'updates': [{'newDigest': 'b' * 40}]}]}))
        ancestry = {'relation': 'behind', 'ahead': 0, 'behind': 2}
        with mock.patch('DependencyUpdates.compare_commits', return_value=ancestry):
            collect_results(log, coverage, self.output / 'ancestry')
        self.assertEqual(coverage[0]['status'], 'commit_changed')
        self.assertEqual(coverage[0]['ancestry']['relation'], 'behind')
        log.write_text(json.dumps({'deps': [{'depName': self.package['SPDXID'],
                                           'updates': [{'newDigest': 'short'}]}]}))
        _, coverage = self.queries()
        collect_results(log, coverage)
        self.assertEqual(coverage[0]['status'], 'lookup_failed')
        log.write_text(json.dumps({'deps': [{'depName': self.package['SPDXID'],
                                           'updates': [{'newDigest': coverage[0]['query']['currentDigest']}]}]}))
        _, coverage = self.queries()
        collect_results(log, coverage)
        self.assertEqual(coverage[0]['status'], 'commit_current')

    def test_ancestry_cache_compares_advances_rewinds_divergence_and_unrelated_history(self):
        repository = self.root / 'history'
        repository.mkdir()

        def git(*arguments):
            return subprocess.check_output(['git', '-C', str(repository), *arguments], text=True).strip()

        git('init', '-q')
        git('config', 'user.name', 'Fixture')
        git('config', 'user.email', 'fixture@example.invalid')

        def commit(text):
            (repository / 'file').write_text(text)
            git('add', 'file')
            git('commit', '-qm', text)
            return git('rev-parse', 'HEAD')

        base = commit('base')
        advance = commit('advance')
        git('checkout', '-q', '-b', 'side', base)
        side = commit('side')
        git('checkout', '-q', '--orphan', 'other')
        other = commit('unrelated')
        cache = self.output / 'ancestry'
        for current, candidate, expected in [(base, advance, 'ahead'), (advance, base, 'behind'),
                                              (advance, side, 'diverged'), (base, other, 'unrelated')]:
            with self.subTest(expected=expected):
                comparison = compare_commits(str(repository), current, candidate, cache)
                self.assertEqual(comparison['relation'], expected, comparison)
        self.assertEqual(git('rev-parse', 'HEAD'), other)

    def test_local_lookup_is_isolated_and_ambient_platform_config_is_removed(self):
        queries, _ = self.queries()

        def simulate(command, **kwargs):
            self.assertIn('--platform=local', command)
            self.assertIn('--dry-run=lookup', command)
            self.assertIn('--allow-scripts=false', command)
            self.assertNotIn('RENOVATE_PLATFORM', kwargs['env'])
            self.assertNotIn('RENOVATE_CONFIG', kwargs['env'])
            self.assertNotIn('GITHUB_TOKEN', kwargs['env'])
            work = kwargs['cwd']
            self.assertNotIn(self.source, work.parents)
            self.assertFalse((work / '.git').exists())
            self.assertEqual({path.name for path in work.iterdir()},
                             {'renovate.json', 'dependency-updates.json'})
            result = {**queries[0], 'updates': [{'newValue': 'v1.3.0', 'updateType': 'minor'}]}
            kwargs['stdout'].write(json.dumps({'level': 20, 'config': {'custom.jsonata': [{'deps': [result]}]}}))
            return SimpleNamespace(returncode=0)

        with mock.patch.dict(os.environ, {'RENOVATE_PLATFORM': 'github',
                                          'RENOVATE_CONFIG': '{}', 'GITHUB_TOKEN': 'fixture'}):
            with mock.patch('DependencyUpdates.subprocess.run', side_effect=simulate):
                self.assertEqual(run_lookup('fixture', self.output, queries, renovate_config()), 0)
        _, coverage = self.queries()
        collect_results(self.output / 'renovate.log.jsonl', coverage)
        self.assertEqual(coverage[0]['status'], 'updates_available')

    def test_missing_or_failed_lookup_is_never_reported_as_current(self):
        log = self.output / 'log.jsonl'
        for payload, status in [({}, 'not_reported'),
                                ({'deps': [{'depName': self.package['SPDXID'], 'updates': [],
                                            'skipReason': 'lookup-failed'}]}, 'lookup_failed')]:
            with self.subTest(status=status):
                log.write_text(json.dumps(payload))
                _, coverage = self.queries()
                collect_results(log, coverage)
                self.assertEqual(coverage[0]['status'], status)

    def test_malformed_error_and_empty_release_results_fail_explicitly(self):
        log = self.output / 'lookup.jsonl'
        for updates, fields in [(None, {}), ({}, {}), ([None], {}), ([{}], {}),
                                ([], {'errors': ['Lookup failed']})]:
            with self.subTest(updates=updates, fields=fields):
                log.write_text(json.dumps({'deps': [{'depName': self.package['SPDXID'],
                                                     'updates': updates, **fields}]}))
                _, coverage = self.queries()
                collect_results(log, coverage)
                self.assertEqual(coverage[0]['status'], 'lookup_failed')
        for diagnostic in [{'level': 50, 'msg': 'Datasource failed'},
                           {'dependency': 'https://github.com/example/probe.git',
                            'msg': 'Found no results from datasource that look like a version'}]:
            log.write_text(json.dumps(diagnostic) + '\n' + json.dumps({'deps': [
                {'depName': self.package['SPDXID'], 'updates': []}]}))
            _, coverage = self.queries()
            collect_results(log, coverage)
            self.assertEqual(coverage[0]['status'], 'lookup_failed')

    def test_cli_timeout_keeps_a_failed_report_with_input_provenance(self):
        path = self.root / 'source.json'
        path.write_text(json.dumps(self.sbom))
        arguments = ['DependencyUpdates.py', '--sbom', str(path), '--source-root', str(self.source),
                     '--output-dir', str(self.output), '--lookup-timeout', '1']
        with mock.patch.object(sys, 'argv', arguments), \
                mock.patch('DependencyUpdates.shutil.which', return_value='fixture'), \
                mock.patch('DependencyUpdates.tool_version', return_value='44.221.6'), \
                mock.patch('DependencyUpdates.run_lookup', side_effect=subprocess.TimeoutExpired('fixture', 1)) as run:
            self.assertEqual(main(), 1)
        self.assertEqual(run.call_args.args[-1], 1)
        report = json.loads((self.output / 'dependency-update-report.json').read_text())
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(report['tool']['version'], '44.221.6')
        self.assertEqual(len(report['sourceSha256']), 64)
        self.assertEqual(len(report['policySha256']), 64)
        self.assertTrue(report['finishedAt'])

    def test_recorded_cli_results_preserve_the_tested_adapter_contract(self):
        fixture = json.loads((MODULE / 'tests/fixtures/renovate-44.221.6-results.json').read_text())
        log = self.output / 'recorded.jsonl'
        log.write_text(json.dumps({'deps': [case['result'] for case in fixture['cases']]}))
        coverage = [dict(case['coverage'], status='pending') for case in fixture['cases']]
        collect_results(log, coverage)
        self.assertEqual([record['status'] for record in coverage],
                         [case['expectedStatus'] for case in fixture['cases']])

    def test_ancestry_timeout_is_reported_as_unknown_with_a_diagnostic(self):
        run = subprocess.run

        def timeout_fetch(command, **options):
            if 'fetch' in command:
                raise subprocess.TimeoutExpired(command, options['timeout'])
            return run(command, **options)

        with mock.patch('DependencyUpdateGit.subprocess.run', side_effect=timeout_fetch) as commands:
            result = compare_commits('https://example.invalid/source.git', 'a' * 40, 'b' * 40,
                                     self.output / 'ancestry', timeout=1)
        self.assertEqual(result['relation'], 'unknown')
        self.assertEqual(commands.call_args.kwargs['timeout'], 1)
        self.assertIn('exceeded the timeout', (self.output / 'ancestry/ancestry.log').read_text())

    def test_cli_generates_inputs_and_reports_a_missing_optional_tool(self):
        path = self.root / 'source.json'
        path.write_text(json.dumps(self.sbom))
        command = [sys.executable, str(MODULE / 'DependencyUpdates.py'), '--sbom', str(path),
                   '--source-root', str(self.source), '--output-dir', str(self.output)]
        result = subprocess.run(command + ['--generate-only'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run(command + ['--renovate', str(self.root / 'absent')],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        report = json.loads((self.output / 'dependency-update-report.json').read_text())
        self.assertEqual(report['status'], 'tool_unavailable')
        self.assertIn('npm install --prefix', result.stderr)
        self.assertIn('MAINTAINING.md#setting-up', result.stderr)

    def test_missing_node_fails_with_setup_help_but_offline_inputs_still_work(self):
        path = self.root / 'source.json'
        path.write_text(json.dumps(self.sbom))
        arguments = ['DependencyUpdates.py', '--sbom', str(path), '--source-root', str(self.source),
                     '--output-dir', str(self.output)]
        with mock.patch('DependencyUpdates.shutil.which', side_effect=lambda name: None if name == 'node' else 'fixture'), \
                mock.patch('sys.stderr', new_callable=io.StringIO) as error:
            with mock.patch.object(sys, 'argv', arguments):
                self.assertEqual(main(), 1)
            self.assertIn('npm install --prefix', error.getvalue())
            self.assertIn('dependency_update_inputs', error.getvalue())
            with mock.patch.object(sys, 'argv', arguments + ['--generate-only']):
                self.assertEqual(main(), 0)
            self.policy(kind='manual', reason='The release feed needs review')
            with mock.patch.object(sys, 'argv', arguments):
                self.assertEqual(main(), 1)

    def test_installation_help_matches_platform_and_windows_npm_entry_is_used_directly(self):
        for host, label in [('win32', 'Windows'), ('freebsd14', 'FreeBSD'),
                            ('darwin', 'macOS'), ('linux', 'Linux/Unix')]:
            help_text = installation_help(host)
            self.assertIn(label + ':', help_text)
            self.assertIn('npm install --prefix', help_text)
            if host == 'win32':
                self.assertIn('renovate.cmd', help_text)
        launcher = self.root / 'node_modules/.bin/renovate.cmd'
        launcher.parent.mkdir(parents=True)
        entry = self.root / 'node_modules/renovate/dist/renovate.js'
        entry.parent.mkdir(parents=True)
        entry.write_text('')
        self.assertEqual(tool_command(launcher), ['node', str(entry)])

    def test_broken_runtime_or_incomplete_npm_installation_gets_setup_instructions(self):
        path = self.root / 'source.json'
        path.write_text(json.dumps(self.sbom))
        arguments = ['DependencyUpdates.py', '--sbom', str(path), '--source-root', str(self.source),
                     '--output-dir', str(self.output)]
        with mock.patch.object(sys, 'argv', arguments), \
                mock.patch('DependencyUpdates.shutil.which', return_value='fixture'), \
                mock.patch('DependencyUpdates.tool_version', side_effect=ValueError('Cannot launch Renovate')), \
                mock.patch('sys.stderr', new_callable=io.StringIO) as error:
            self.assertEqual(main(), 1)
        self.assertIn('Cannot launch Renovate', error.getvalue())
        self.assertIn('npm install --prefix', error.getvalue())
        report = json.loads((self.output / 'dependency-update-report.json').read_text())
        self.assertEqual(report['status'], 'tool_unavailable')

    def test_cli_group_selection_filters_queries_and_removes_stale_reports_on_failure(self):
        self.provider()
        path = self.root / 'source.json'
        path.write_text(json.dumps(self.sbom))
        command = [sys.executable, str(MODULE / 'DependencyUpdates.py'), '--sbom', str(path),
                   '--source-root', str(self.source), '--output-dir', str(self.output), '--generate-only']
        result = subprocess.run(command + ['--group', 'BRLCAD'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        inputs = json.loads((self.output / 'dependency-updates.json').read_text())
        self.assertEqual([query['depType'] for query in inputs['dependencies']], ['probe'])
        report = json.loads((self.output / 'dependency-update-report.json').read_text())
        self.assertEqual(report['selection'], {'components': [], 'groups': ['BRLCAD']})
        self.assertEqual(list(report['byGroup']), ['BRLCAD'])
        self.assertEqual(report['packages'][0]['groups'], ['APPLESEED', 'BRLCAD'])
        result = subprocess.run(command + ['--group', 'missing'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        for extension in ('json', 'txt', 'csv'):
            self.assertFalse((self.output / ('dependency-update-report.' + extension)).exists())


if __name__ == '__main__':
    unittest.main()
