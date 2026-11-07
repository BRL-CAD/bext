"""Installed subsets must retain valid legacy SPDX file integrity."""

import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]


class SpdxRefreshTests(unittest.TestCase):
    def test_selected_files_and_external_hashes_are_refreshed(self):
        with tempfile.TemporaryDirectory(prefix='spdx-subset-') as temporary:
            root = Path(temporary)
            (root / 'sbom').mkdir()
            (root / 'kept').write_text('payload')
            files = []
            for name in ('kept', 'omitted'):
                files.append(f'FileName: ./{name}\nSPDXID: SPDXRef-PackagedFile-{name}\n'
                             'FileType: BINARY\nFileChecksum: SHA1: ' + '0' * 40 + '\n'
                             'LicenseConcluded: NOASSERTION\nFileCopyrightText: NOASSERTION\n\n'
                             f'Relationship: SPDXRef-Package-core CONTAINS SPDXRef-PackagedFile-{name}\n'
                             f'Relationship: SPDXRef-PackagedFile-{name} GENERATED_FROM NOASSERTION\n\n')
            document = root / 'sbom/core.spdx'
            document.write_text('DocumentNamespace: https://example.invalid/core\n\n'
                                'PackageName: core\nSPDXID: SPDXRef-Package-core\n'
                                'PackageVerificationCode: ' + '0' * 40 + '\n\n' + ''.join(files))
            dependent = root / 'sbom/dependent.spdx'
            dependent.write_text('DocumentNamespace: https://example.invalid/dependent\n'
                                 'ExternalDocumentRef: DocumentRef-core https://example.invalid/core SHA1: '
                                 + '0' * 40 + '\n')
            script = root / 'refresh.cmake'
            prefix = root.as_posix()
            script.write_text(f'include("{(MODULE / "RefreshSpdx.cmake").as_posix()}")\n'
                              f'bext_refresh_spdx("{prefix}")\n')
            original = document.read_bytes()
            result = subprocess.run(['cmake', '-P', str(script)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(original, document.read_bytes())
            script.write_text(script.read_text().replace(f'("{prefix}")', f'("{prefix}" PRUNE_MISSING)'))
            subprocess.run(['cmake', '-P', str(script)], check=True, capture_output=True)
            content = document.read_text()
            self.assertNotIn('omitted', content)
            checksum = hashlib.sha1(b'payload').hexdigest()
            self.assertIn('FileChecksum: SHA1: ' + checksum, content)
            self.assertIn('PackageVerificationCode: ' + hashlib.sha1(checksum.encode()).hexdigest(), content)
            self.assertIn(hashlib.sha1(document.read_bytes()).hexdigest(), dependent.read_text())
            first = document.read_bytes(), dependent.read_bytes()
            subprocess.run(['cmake', '-P', str(script)], check=True, capture_output=True)
            self.assertEqual(first, (document.read_bytes(), dependent.read_bytes()))
            (root / 'kept').unlink()
            subprocess.run(['cmake', '-P', str(script)], check=True, capture_output=True)
            self.assertNotIn('FileName:', document.read_text())
            self.assertIn('PackageVerificationCode: ' + hashlib.sha1(b'').hexdigest(), document.read_text())


if __name__ == '__main__':
    unittest.main()
