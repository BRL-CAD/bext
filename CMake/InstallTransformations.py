"""Bind reviewed dependency inputs to controlled install transformations."""

import argparse
from pathlib import Path
import re
import sys

from BextVex import (SCHEMA_VERSION, checked_fields, exported_evidence, file_digest,
                     inside, json_text, read_json, relative_name)


PIPELINE_STEPS = ('installPostprocess', 'installPrivacy', 'captureHelper')


def is_hash(value):
    return isinstance(value, str) and re.fullmatch(r'[0-9a-f]{64}', value)


def read_transformations(path, evidence_sha256):
    document = read_json(path)
    checked_fields(document, ('schemaVersion', 'sourceEvidenceSha256', 'pipeline', 'files'), (),
                   'Install transformations')
    if type(document['schemaVersion']) is not int or document['schemaVersion'] != SCHEMA_VERSION:
        raise ValueError('Unsupported install transformation schema')
    if document['sourceEvidenceSha256'] != evidence_sha256:
        raise ValueError('Install transformations belong to different source evidence')
    checked_fields(document['pipeline'], PIPELINE_STEPS, (), 'Install transformation pipeline')
    if not all(is_hash(value) for value in document['pipeline'].values()):
        raise ValueError('Invalid install pipeline digest')
    result = {}
    if not isinstance(document['files'], list):
        raise ValueError('Install transformation files must be an array')
    for record in document['files']:
        checked_fields(record, ('component', 'path', 'sourceSha256', 'beforeSha256', 'sha256'), (),
                       'Install transformation record')
        component = record['component']
        if not isinstance(component, str) or not re.fullmatch(r'[a-z][a-z0-9_-]*', component):
            raise ValueError('Invalid install transformation component')
        key = component, relative_name(record['path'])
        if key in result or not all(is_hash(record[field])
                                    for field in ('sourceSha256', 'beforeSha256', 'sha256')):
            raise ValueError('Duplicate or invalid install transformation')
        result[key] = record
    return result


def postprocess_receipts(directory):
    result = set()
    for path in sorted(directory.glob('*.receipt')):
        fields = path.read_text(encoding='utf-8').splitlines()
        if (len(fields) != 5 or not all(is_hash(value) for value in fields[2:4])
                or not fields[4].startswith(('binary-postprocess|', 'strclear-replace|'))):
            raise ValueError(f'Invalid install postprocess receipt: {path.name}')
        source, installed = (Path(value).resolve() for value in fields[:2])
        result.add((source, installed, fields[2], fields[3]))
    return result


def capture(evidence_path, stage_root, install_root, stamp_dir, postprocess, privacy):
    evidence = exported_evidence(read_json(evidence_path))
    receipts = postprocess_receipts(stamp_dir)
    records = []
    for component, entry in sorted(evidence.items()):
        for artifact in entry['files']:
            name = artifact['path']
            source, installed = inside(stage_root, name), inside(install_root, name)
            if not source.is_file() or not installed.is_file():
                continue
            source_hash = file_digest(source)
            if source_hash != artifact['sha256']:
                continue
            installed_hash = file_digest(installed)
            # Ordinary copies retain their bytes. Changed copies must be bound
            # to a successful installer operation, rather than accepted by name.
            receipt = source.resolve(), installed.resolve(), source_hash, installed_hash
            if installed_hash != source_hash and receipt not in receipts:
                continue
            records.append({'component': component, 'path': name,
                            'sourceSha256': source_hash, 'beforeSha256': installed_hash})
    return {'schemaVersion': SCHEMA_VERSION, 'sourceEvidenceSha256': file_digest(evidence_path),
            'pipeline': {'installPostprocess': file_digest(postprocess),
                         'installPrivacy': file_digest(privacy), 'captureHelper': file_digest(__file__)},
            'files': records}


def finalize(snapshot, evidence_path, install_root):
    if snapshot['sourceEvidenceSha256'] != file_digest(evidence_path):
        raise ValueError('Source evidence changed during installation')
    result = dict(snapshot, files=[])
    for original in snapshot['files']:
        record = dict(original, sha256=file_digest(inside(install_root, original['path'])))
        if record['sha256'] != record['sourceSha256']:
            result['files'].append(record)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('capture', 'finalize'))
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--install-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--snapshot', type=Path)
    parser.add_argument('--stage-root', type=Path)
    parser.add_argument('--stamp-dir', type=Path)
    parser.add_argument('--postprocess', type=Path)
    parser.add_argument('--privacy', type=Path)
    args = parser.parse_args()
    if args.mode == 'capture' and not all((args.stage_root, args.stamp_dir, args.postprocess, args.privacy)):
        parser.error('capture needs --stage-root, --stamp-dir, --postprocess, and --privacy')
    if args.mode == 'finalize' and not args.snapshot:
        parser.error('finalize needs --snapshot')
    if any(path and path.resolve() == args.output.resolve()
           for path in (args.evidence, args.snapshot, args.postprocess, args.privacy)):
        parser.error('Install evidence output must be separate from its inputs')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.unlink(missing_ok=True)
    try:
        result = (capture(args.evidence, args.stage_root, args.install_root, args.stamp_dir,
                          args.postprocess, args.privacy) if args.mode == 'capture'
                  else finalize(read_json(args.snapshot), args.evidence, args.install_root))
        temporary = args.output.with_suffix('.tmp')
        temporary.write_text(json_text(result), encoding='utf-8')
        temporary.replace(args.output)
    except (ValueError, KeyError, OSError) as error:
        print(f'Install evidence failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
