"""Keep OpenImageIO's custom license available without its optional checkout."""

import json
import unittest
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SOURCE / 'CMake/tests'))

from source_inventory_fixture import SourceInventoryFixture

NOTICE = 'openimageio/licenses/oiio.txt'
UPSTREAM_NOTICE = 'openimageio/oiio/THIRD-PARTY.md'


def populate_inventory_sources(fixture):
    fixture.copy_evidence(NOTICE, UPSTREAM_NOTICE)


class OpenImageIOEvidenceTests(SourceInventoryFixture):
    def test_custom_license_is_available_without_upstream_checkout(self):
        self.generate()
        spdx = json.loads(self.spdx.read_text(encoding='utf-8'))
        cyclonedx = json.loads(self.cyclonedx.read_text(encoding='utf-8'))
        notice = (self.repository / NOTICE).read_text(encoding='utf-8')
        self.assertIn(notice, [entry['extractedText'] for entry in spdx['hasExtractedLicensingInfos']])
        packages = [package for package in spdx['packages'] if package['name'] == 'OpenImageIO']
        self.assertEqual(len(packages), 1)
        children = [edge for edge in spdx['relationships']
                    if edge['spdxElementId'] == packages[0]['SPDXID'] and edge['relationshipType'] == 'CONTAINS']
        self.assertEqual(len(children), 4)
        component = next(component for component in cyclonedx['components'] if component['name'] == 'OpenImageIO')
        self.assertEqual(component['evidence']['licenses'][0]['license']['text']['content'], notice)

    def test_reviewed_notice_hash_is_required(self):
        notice = self.repository / NOTICE
        notice.write_bytes(notice.read_bytes() + b'changed evidence\n')
        self.git('add', NOTICE)
        self.git('commit', '-qm', 'Exercise changed evidence')
        self.assertIn('License file for openimageio/oiio changed', self.generate(success=False))

    def test_available_upstream_notice_remains_verified(self):
        populate_inventory_sources(self)
        notice = self.repository / UPSTREAM_NOTICE
        notice.write_bytes(notice.read_bytes() + b'changed upstream evidence\n')
        self.assertIn('Source license for openimageio/oiio changed', self.generate(success=False))


if __name__ == '__main__':
    unittest.main()
