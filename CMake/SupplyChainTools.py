"""Publication and tool provenance shared by the supply-chain CLIs."""

from pathlib import Path
import json
import re
import subprocess
import tempfile

from BextVex import checked_fields


VERSION_TIMEOUT_SECONDS = 30
MEMBERSHIP_ANNOTATOR = 'Tool: bext:membership'
UNGROUPED = 'UNGROUPED'


def package_membership(package):
    annotations = [item for item in package.get('annotations', [])
                   if item.get('annotator') == MEMBERSHIP_ANNOTATOR]
    if len(annotations) != 1:
        raise ValueError(f'{package["SPDXID"]}: expected one membership annotation; regenerate the source SBOM')
    membership = json.loads(annotations[0]['comment'])
    checked_fields(membership, ('schemaVersion', 'component', 'groups'), (), 'Package membership')
    component, groups = membership['component'], membership['groups']
    if (membership['schemaVersion'] != 1 or not isinstance(component, str)
            or not re.fullmatch(r'[a-z0-9][a-z0-9_-]*', component)
            or not isinstance(groups, list) or not all(
                isinstance(group, str) and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', group)
                and group != UNGROUPED for group in groups) or len(groups) != len(set(groups))):
        raise ValueError(f'{package["SPDXID"]}: invalid consumer-group metadata')
    return component, sorted(groups)


def tool_version(executable):
    result = subprocess.run([*tool_command(executable), '--version'], capture_output=True, text=True,
                            check=True, timeout=VERSION_TIMEOUT_SECONDS)
    value = result.stdout.strip()
    if not value:
        raise ValueError('The tool did not report its version')
    return value


def tool_command(executable):
    path = Path(executable)
    if path.suffix.lower() == '.cmd':
        # Invoke npm's JavaScript entry directly instead of relying on the
        # Windows command processor to quote a batch launcher and its arguments.
        candidates = (path.parent.parent / 'renovate/dist/renovate.js',
                      path.parent / 'node_modules/renovate/dist/renovate.js')
        for entry in candidates:
            if entry.is_file():
                return ['node', str(entry)]
        raise ValueError('Cannot find the Renovate entry point beside its npm launcher')
    return [str(executable)]


def publish_files(directory, documents, completion):
    # Stage every document before replacing any destination; publish the
    # completion document last so an interrupted run cannot advertise success.
    with tempfile.TemporaryDirectory(prefix='report-', dir=directory) as temporary:
        staged = Path(temporary)
        for name, text in documents.items():
            with (staged / name).open('w', encoding='utf-8', newline='') as stream:
                stream.write(text)
        for name in sorted(documents, key=lambda name: name == completion):
            (staged / name).replace(directory / name)
