"""Validate the reviewed Tcl SQLite binding notice with optional sources."""

import unittest
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SOURCE / 'CMake/tests'))

from source_inventory_fixture import SourceInventoryFixture

NOTICE = 'tcl/licenses/sqlite3-binding.txt'
UPSTREAM_NOTICE = 'tcl/tcl/pkgs/sqlite3.53.0/license.terms'


def populate_inventory_sources(fixture):
    fixture.copy_evidence(NOTICE, UPSTREAM_NOTICE)


class TclEvidenceTests(SourceInventoryFixture):
    def test_reviewed_notice_hash_is_required(self):
        notice = self.repository / NOTICE
        notice.write_bytes(notice.read_bytes() + b'changed evidence\n')
        self.git('add', NOTICE)
        self.git('commit', '-qm', 'Exercise changed evidence')
        self.assertIn('License file for tcl/tcl#pkgs/sqlite3.53.0 changed', self.generate(success=False))

    def test_available_upstream_notice_remains_verified(self):
        populate_inventory_sources(self)
        notice = self.repository / UPSTREAM_NOTICE
        notice.write_bytes(notice.read_bytes() + b'changed upstream evidence\n')
        self.assertIn('Source license for tcl/tcl#pkgs/sqlite3.53.0 changed', self.generate(success=False))

    def test_snapshot_reads_ignore_unstaged_notice_removal(self):
        (self.repository / NOTICE).unlink()
        for mode in ('HEAD', 'INDEX'):
            with self.subTest(snapshot=mode):
                self.inventory(mode)


if __name__ == '__main__':
    unittest.main()
