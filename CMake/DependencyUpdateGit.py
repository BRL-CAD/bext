"""Read committed dependency pins and compare candidate commit histories."""

import hashlib
import os
import subprocess


ANCESTRY_TIMEOUT_SECONDS = 300


def source_repositories(root):
    modules = subprocess.run([
        'git', '-C', str(root), 'config', '--null', '--blob', 'HEAD:.gitmodules',
        '--get-regexp', r'^submodule\..*\.(path|url)$',
    ], capture_output=True, check=True).stdout
    config = {}
    for record in modules.split(b'\0'):
        if record:
            key, value = record.decode('utf-8').split('\n', 1)
            section, field = key.rsplit('.', 1)
            config.setdefault(section, {})[field] = value
    tree = subprocess.run(['git', '-C', str(root), 'ls-tree', '-rz', 'HEAD'],
                          capture_output=True, check=True).stdout
    pins = {}
    for record in tree.split(b'\0'):
        if not record:
            continue
        metadata, path = record.decode('utf-8').split('\t', 1)
        mode, _, commit = metadata.split()
        if mode == '160000':
            pins[path] = commit
    repositories = {}
    for section in config.values():
        path = section.get('path')
        if path in pins:
            if not section.get('url'):
                raise ValueError(f'Committed source repository URL is missing: {path}')
            repositories[path] = {'repository': section['url'], 'commit': pins[path]}
    return repositories


def compare_commits(repository, current, candidate, directory, timeout=ANCESTRY_TIMEOUT_SECONDS):
    if current == candidate:
        return {'relation': 'same', 'ahead': 0, 'behind': 0}
    cache = directory / hashlib.sha256(repository.encode('utf-8')).hexdigest()
    cache.parent.mkdir(parents=True, exist_ok=True)
    log = directory / 'ancestry.log'

    def git(*arguments):
        try:
            result = subprocess.run(['git', '--git-dir=' + str(cache), *arguments],
                                    capture_output=True, text=True, timeout=timeout,
                                    env=dict(os.environ, GIT_TERMINAL_PROMPT='0'))
        except subprocess.TimeoutExpired:
            result = subprocess.CompletedProcess(arguments, 1, '', 'Git ancestry command exceeded the timeout\n')
        if result.returncode:
            with log.open('a', encoding='utf-8') as output:
                output.write(result.stderr)
        return result

    if not cache.exists():
        result = git('init', '--bare', '--quiet')
        if result.returncode:
            return {'relation': 'unknown', 'reason': 'Cannot initialize the private ancestry cache'}
    elif git('rev-parse', '--is-bare-repository').stdout.strip() != 'true':
        return {'relation': 'unknown', 'reason': 'The private ancestry cache is not a bare repository'}
    # Commit ancestry needs no file contents. Fetch only into this private
    # cache, leaving the dependency checkout and its refs untouched.
    fetched = git('fetch', '--quiet', '--no-tags', '--filter=tree:0', repository, current, candidate)
    if fetched.returncode:
        return {'relation': 'unknown', 'reason': 'Cannot fetch history; see ancestry.log'}
    counts = git('rev-list', '--left-right', '--count', current + '...' + candidate)
    if counts.returncode:
        return {'relation': 'unknown', 'reason': 'Cannot compare history; see ancestry.log'}
    behind, ahead = map(int, counts.stdout.split())
    if not behind:
        relation = 'ahead'
    elif not ahead:
        relation = 'behind'
    else:
        common = git('merge-base', current, candidate)
        if common.returncode not in (0, 1):
            return {'relation': 'unknown', 'reason': 'Cannot establish ancestry; see ancestry.log'}
        relation = 'diverged' if common.returncode == 0 else 'unrelated'
    return {'relation': relation, 'ahead': ahead, 'behind': behind}
