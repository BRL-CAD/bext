#!/usr/bin/env python3
"""Capture source and staged-file facts after an ExternalProject build."""

import argparse
import datetime
import fnmatch
from pathlib import Path
import subprocess
import sys

from BextVex import (SCHEMA_VERSION, file_digest, inside, json_text, read_json,
                     validate_catalog, load_evidence, digest, exported_evidence)


def source_facts(root, name):
    path = inside(root, name)
    revision = subprocess.run(['git', '-C', str(path), 'rev-parse', 'HEAD'],
                              capture_output=True, text=True)
    status = subprocess.run(['git', '-C', str(path), 'status', '--porcelain',
                             '--untracked-files=normal'], capture_output=True, text=True)
    return {'revision': revision.stdout.strip() if not revision.returncode else None,
            'clean': not status.returncode and not status.stdout.strip()}


def capture(config):
    catalog = validate_catalog(read_json(config['reviews']))
    if catalog['component'] != config['component']:
        raise ValueError('Capture configuration and review component differ')
    root = Path(config['sourceRoot']).resolve()
    inputs, revisions, errors = {}, [], []
    for state_path in config['sourceStates']:
        lines = Path(state_path).read_text().splitlines()
        if not lines:
            raise ValueError('Empty tracked source state')
        revisions.append(lines[0])
        for line in lines[1:]:
            filename, separator, expected = line.rpartition(':')
            if not separator:
                raise ValueError('Invalid tracked source input')
            try:
                relative = Path(filename).resolve().relative_to(root).as_posix()
            except ValueError as error:
                raise ValueError('Tracked source input is outside the repository') from error
            path = inside(root, relative)
            actual = file_digest(path) if path.is_file() else None
            if actual != expected:
                errors.append(f'Source input changed after configure: {relative}')
            if relative in inputs and inputs[relative] != expected:
                raise ValueError(f'Conflicting source input: {relative}')
            inputs[relative] = expected
    source_names = set()
    stage_names = set()
    for review in catalog['reviews']:
        source_names.update(review['conditions']['sources'])
        stage_names.update(review['conditions']['stagedFiles'])
    sources = {name: source_facts(root, name) for name in sorted(source_names)}
    actual_revisions = {fact['revision'] for fact in sources.values()}
    if not set(revisions) <= actual_revisions:
        errors.append('Tracked source revision differs from the current checkout')
    staged = {}
    for name in sorted(stage_names):
        path = inside(config['stageRoot'], name)
        staged[name] = file_digest(path) if path.is_file() else None
    patterns = {pattern for review in catalog['reviews']
                for alternatives in review['conditions']['requiredArtifacts']
                for pattern in alternatives}
    install_root = Path(config['installRoot']).resolve()
    native_manifest = Path(config['buildRoot']) / 'install_manifest.txt'
    installed = {}
    if native_manifest.is_file():
        candidates = []
        for filename in native_manifest.read_text().splitlines():
            path = Path(filename)
            try:
                relative = (path.parent.resolve() / path.name).relative_to(install_root).as_posix()
            except ValueError:
                # The shell and other build tools deliberately use noinstall.
                continue
            candidates.append(relative)
        for name in candidates:
            path = inside(install_root, name)
            if path.is_file() and any(fnmatch.fnmatchcase(name, pattern) for pattern in patterns):
                installed[name] = file_digest(path)
    else:
        # Autotools/NMake do not publish a CMake install manifest. Require the
        # installed module's bytes to match a file in its successful build.
        candidates = [path for path in install_root.rglob('*')
                      if path.is_file() and any(fnmatch.fnmatchcase(
                          path.relative_to(install_root).as_posix(), pattern)
                          for pattern in patterns)]
        names = {path.name for path in candidates}
        built = set()
        for build_root in {Path(config['buildRoot']), Path(config['stageRoot'])}:
            for path in build_root.rglob('*'):
                if path.name in names and path.is_file():
                    built.add(file_digest(path))
        for candidate in candidates:
            name = candidate.relative_to(install_root).as_posix()
            value = file_digest(inside(install_root, name))
            if value in built:
                installed[name] = value
    return {'schemaVersion': SCHEMA_VERSION, 'component': config['component'],
            'capturedAt': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'sources': sources, 'inputs': inputs, 'stagedFiles': staged,
            'installedArtifacts': installed, 'errors': errors}


def before_finalize(registry, install_root, previous=None):
    result = {}
    previous_components = exported_evidence(previous) if previous else {}
    for component, entry in load_evidence(registry).items():
        capture = entry['capture']
        if not capture:
            continue
        artifacts = {}
        for name in capture['installedArtifacts']:
            path = inside(install_root, name)
            artifacts[name] = file_digest(path) if path.is_file() else None
        result[component] = {'captureDigest': digest(capture), 'artifacts': artifacts}
        old = previous_components.get(component)
        if old and old['capture'] and digest(old['capture']) == digest(capture):
            result[component]['previous'] = {
                'appliedReviews': old['appliedReviews'],
                'artifacts': {item['path']: item['sha256'] for item in old['files']},
            }
    return {'schemaVersion': SCHEMA_VERSION, 'components': result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--config', type=Path)
    mode.add_argument('--before-finalize', type=Path, metavar='REGISTRY')
    parser.add_argument('--install-root', type=Path)
    parser.add_argument('--previous-evidence', type=Path)
    parser.add_argument('--previous-vex', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.config and (args.previous_evidence or args.previous_vex):
        parser.error('Previous publications apply only to --before-finalize')
    args.output.unlink(missing_ok=True)
    try:
        if args.config:
            facts = capture(read_json(args.config))
        else:
            if not args.install_root:
                raise ValueError('--before-finalize requires --install-root')
            previous = None
            if args.previous_evidence:
                try:
                    if args.previous_evidence.exists():
                        previous = read_json(args.previous_evidence)
                finally:
                    # This entry point is used by bext finalization. Invalidate
                    # prior assertions even if processing or generation fails.
                    args.previous_evidence.unlink(missing_ok=True)
                    if args.previous_vex:
                        args.previous_vex.unlink(missing_ok=True)
            facts = before_finalize(read_json(args.before_finalize), args.install_root, previous)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_suffix('.tmp')
        temporary.write_text(json_text(facts), encoding='utf-8')
        temporary.replace(args.output)
    except (ValueError, KeyError, OSError) as error:
        print(f'VEX evidence capture failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
