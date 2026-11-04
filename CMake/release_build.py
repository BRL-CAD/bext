#!/usr/bin/env python3
"""Build bext dependencies sequentially, retaining outputs instead of work trees."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import uuid


def inside(path, root):
    return path == root or root in path.parents


def overlaps(left, right):
    return inside(left, right) or inside(right, left)


def write_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def work_paths(plan, project):
    """Only generated source/build directories can be disposable."""
    root = Path(plan['build_root']).resolve()
    logical_root = Path(plan['build_root']).absolute()
    protected = [Path(plan['source_root']).resolve()]
    protected += [Path(value).resolve() for value in plan['install_roots']]
    protected += [root / 'CMakeFiles', root / 'bext-release-logs']
    for item in plan['projects']:
        protected += [Path(item[key]).resolve() for key in ('stamp_dir', 'tmp_dir', 'log_dir')]
        upstream = Path(item['upstream'])
        if upstream.is_dir():
            protected.append(upstream.resolve())
    paths = []
    for key in ('binary_dir', 'source_dir'):
        path = Path(project[key])
        # Source directories outside the build tree belong to the checkout.
        resolved = path.resolve()
        if not inside(path.absolute(), logical_root) and not inside(resolved, root):
            continue
        if not inside(resolved, root) or resolved == root or path.is_symlink():
            raise ValueError('Unsafe working directory: ' + str(path))
        for keep in protected:
            # An out-of-source build may itself be below the source root.
            if keep == Path(plan['source_root']).resolve():
                unsafe = inside(keep, resolved)
            else:
                unsafe = overlaps(resolved, keep)
            if unsafe:
                raise ValueError('Working directory overlaps retained files: ' + str(path))
        if resolved not in paths:
            paths.append(resolved)
    return paths


def remove_readonly(function, path, exc_info):
    """Retry Windows file deletion after clearing a read-only attribute."""
    error = exc_info[1]
    if (os.name != 'nt' or not isinstance(error, PermissionError)
            or function not in (os.unlink, os.remove)):
        raise error
    mode = os.lstat(path).st_mode
    if not stat.S_ISREG(mode) or mode & stat.S_IWRITE:
        raise error
    os.chmod(path, mode | stat.S_IWRITE)
    function(path)


def discard(plan, project):
    # Recheck after the build, since a dependency could have created symlinks.
    for path in work_paths(plan, project):
        if path.exists():
            print('Discarding ' + str(path), flush=True)
            # onerror supports the driver's Python 3.8 minimum (onexc needs 3.12).
            shutil.rmtree(path, onerror=remove_readonly)


def signature(plan):
    digest = hashlib.sha256(json.dumps(plan, sort_keys=True).encode())
    cache = Path(plan['build_root']) / 'CMakeCache.txt'
    for line in cache.read_text(encoding='utf-8').splitlines():
        # Find modules add diagnostic INTERNAL entries on later configures.
        # User options and tool paths remain part of the immutable recipe.
        if line and not line.startswith(('#', '//')) and ':INTERNAL=' not in line:
            digest.update((line + '\n').encode())
    for name in ('CC', 'CXX', 'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS',
                 'INCLUDE', 'LIB', 'LIBPATH', 'SDKROOT', 'MACOSX_DEPLOYMENT_TARGET'):
        digest.update((name + '=' + os.environ.get(name, '') + '\n').encode())
    for name in plan['inputs']:
        digest.update(Path(name).read_bytes())
    # Include dependency revisions and local edits without hashing large clean
    # checkouts (notably LLVM) on every invocation.
    upstreams = {str(Path(item['upstream']).resolve()) for item in plan['projects']
                 if Path(item['upstream']).is_dir()}
    for upstream in sorted(upstreams):
        revision = subprocess.run(['git', '-C', upstream, 'rev-parse', 'HEAD'],
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        tracked = subprocess.run(['git', '-C', upstream, 'ls-files', '-z', '--', '.'],
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        # Git discovery can find an enclosing repository even when upstream
        # is an ignored source archive rather than one of its tracked trees.
        if revision.returncode == 0 and tracked.returncode == 0 and tracked.stdout:
            digest.update(revision.stdout)
            edits = subprocess.run(['git', '-C', upstream, 'diff', '--no-ext-diff',
                                    '--binary', 'HEAD', '--', '.'],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            digest.update(edits.stdout)
            untracked = subprocess.run(['git', '-C', upstream, 'ls-files', '--others',
                                        '--exclude-standard', '-z', '--', '.'],
                                       stdout=subprocess.PIPE, check=True)
            files = [Path(upstream) / os.fsdecode(name)
                     for name in untracked.stdout.split(b'\0') if name]
        else:
            files = sorted(Path(upstream).rglob('*'))
        for path in files:
            if path.is_symlink():
                digest.update(str(path).encode() + os.fsencode(os.readlink(path)))
            elif path.is_file():
                digest.update(str(path).encode() + path.read_bytes())
    return digest.hexdigest()


def inventory(plan):
    result = []
    for directory in plan['install_roots']:
        root = Path(directory)
        for path in sorted(root.rglob('*')):
            if path.is_symlink():
                result.append([str(path), 'symlink', os.readlink(path)])
            elif path.is_file():
                result.append([str(path), 'file', path.stat().st_size])
    return result


def build(plan):
    root = Path(plan['build_root'])
    state_file = root / 'bext-release-state.json'
    receipt = Path(plan['prefix']) / 'bext-discard-receipt.json'
    for project in plan['projects']:
        work_paths(plan, project)  # Validate every deletion before starting.
    identity = signature(plan)
    if state_file.exists():
        state = json.loads(state_file.read_text(encoding='utf-8'))
        if state['signature'] != identity:
            raise ValueError('Build inputs changed; use a fresh build directory with BEXT_DISCARD_WORK')
        owner = {'build_root': str(root.resolve()), 'id': state['id']}
        if not receipt.is_file() or json.loads(receipt.read_text(encoding='utf-8')) != owner:
            raise ValueError('Installed dependency prefix was removed or replaced; use a fresh build directory')
        if state.get('finalized'):
            if inventory(plan) != state['inventory']:
                raise ValueError('Installed dependency files changed; use a fresh build directory')
            print('Finalized dependencies are up to date.', flush=True)
            return
    else:
        if receipt.exists() and json.loads(receipt.read_text(encoding='utf-8'))['build_root'] != str(root.resolve()):
            raise ValueError('Install prefix belongs to another build; use a fresh install prefix')
        state = {'signature': identity, 'id': uuid.uuid4().hex, 'completed': [], 'finalized': False}
        receipt.parent.mkdir(parents=True, exist_ok=True)
        write_json(receipt, {'build_root': str(root.resolve()), 'id': state['id']})
        write_json(state_file, state)

    environment = os.environ.copy()
    environment['CMAKE_BUILD_PARALLEL_LEVEL'] = str(plan['jobs'])
    # Our own child builds must not inherit a parent make's jobserver or flags.
    environment.pop('MAKEFLAGS', None)
    environment.pop('MFLAGS', None)
    logs = root / 'bext-release-logs'
    logs.mkdir(exist_ok=True)

    def run(target, build_target=None):
        command = [plan['cmake'], '--build', str(root), '--target', build_target or target,
                   '--parallel', '1']
        if plan['config']:
            command += ['--config', plan['config']]
        print('Building ' + target, flush=True)
        with (logs / (target + '.log')).open('ab') as output:
            process = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT)
            with process.stdout:
                for line in iter(process.stdout.readline, b''):
                    output.write(line)
                    output.flush()
                    sys.stdout.buffer.write(line)
                    sys.stdout.buffer.flush()
            if process.wait():
                raise RuntimeError(target + ' failed; working files and logs were retained')

    for project in plan['projects']:
        if project['name'] in state['completed']:
            continue
        run(project['name'], project['build_target'])
        if not project['deferred']:
            discard(plan, project)
        state['completed'].append(project['name'])
        write_json(state_file, state)
        print('Available disk: {:.2f} GiB'.format(shutil.disk_usage(root).free / 1024**3), flush=True)

    run('bext_finalize')
    for project in plan['projects']:
        if project['deferred']:
            discard(plan, project)
    state['inventory'] = inventory(plan)
    state['finalized'] = True
    write_json(state_file, state)


def main():
    try:
        build(json.loads(Path(sys.argv[1]).read_text(encoding='utf-8')))
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print('bext release build: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
