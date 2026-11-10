"""Shared fixture for complete inventories without fetching dependency sources."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2]


class SourceInventoryFixture(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bext-inventory-checkouts-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repository = self.root / 'source'
        self.repository.mkdir()
        files = set(self.command('git', '-C', SOURCE, 'ls-files', '--cached',
                                 '--others', '--exclude-standard', '-z').split('\0')) - {''}
        for name in sorted(files):
            source = SOURCE / name
            if not source.is_file():
                continue
            destination = self.repository / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Source Inventory Test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        self.git('add', '--force', '--all')
        entries = self.command('git', '-C', SOURCE, 'ls-files', '--stage').splitlines()
        links = []
        self.submodules = []
        for entry in entries:
            metadata, name = entry.split('\t', 1)
            mode, revision, stage = metadata.split()
            if mode == '160000':
                self.assertEqual(stage, '0', f'Resolve the staged submodule conflict: {name}')
                links.append(f'{mode} {revision}\t{name}\n')
                self.submodules.append(name)
                (self.repository / name).mkdir(parents=True, exist_ok=True)
        self.git('update-index', '--index-info', input=''.join(links))
        self.git('commit', '-qm', 'Prepare source inventory fixture')
        self.spdx = self.root / 'inventory.spdx.json'
        self.cyclonedx = self.root / 'inventory.cdx.json'

    def command(self, *arguments, input=None, success=True):
        result = subprocess.run([str(argument) for argument in arguments], input=input,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def git(self, *arguments, **options):
        return self.command('git', '-C', self.repository, *arguments, **options)

    def generate(self, success=True):
        return self.command('cmake', f'-DBEXT_SOURCE_DIR={self.repository}',
                            f'-DBEXT_SBOM_OUTPUT={self.spdx}',
                            f'-DBEXT_CYCLONEDX_OUTPUT={self.cyclonedx}',
                            '-DBEXT_SBOM_ALLOW_DIRTY=OFF', '-P', SOURCE / 'CMake/GenerateSbom.cmake',
                            success=success)

    def copy_evidence(self, source, destination):
        destination = self.repository / destination
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(self.repository / source, destination)
        return destination

    def inventory(self, mode, success=True):
        script = self.root / 'inventory.cmake'
        script.write_text('cmake_minimum_required(VERSION 3.26)\n'
                          'include("@MODULE@/CMake/BextDependencyInventory.cmake")\n'
                          'bext_collect_dependency_inventory("${BEXT_SOURCE_DIR}")\n'
                          .replace('@MODULE@', SOURCE.as_posix()), encoding='utf-8')
        return self.command('cmake', f'-DBEXT_SOURCE_DIR={self.repository}',
                            f'-DBEXT_INVENTORY_MODE={mode}', '-P', script, success=success)
