"""Validate the approved existing-art iOS exports without image-library dependencies."""
import hashlib
import json
import pathlib
import struct
import unittest
from decimal import Decimal

ROOT = pathlib.Path(__file__).resolve().parents[3]
MANIFEST = ROOT / 'tool/store_assets/ios_icon_export_manifest.json'


def png_chunks(data):
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Not a PNG')
    offset = 8
    chunks = {}
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunks[kind] = data[offset + 8:offset + 8 + length]
        offset += length + 12
    return chunks


class IOSIconExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text())
        cls.catalog_path = ROOT / cls.manifest['catalog']['path']
        cls.catalog = json.loads(cls.catalog_path.read_text())

    def test_approved_source_and_catalog_are_pinned(self):
        source = self.manifest['source']
        self.assertEqual(source['git_blob'], '129a43e1714d0653dfd9acce5cc316f533f53b4a')
        self.assertEqual(source['sha256'], 'c98b6247509b8c4c156f4e292e3b8ea2eb2e2517cebe83c5112abaf9a9635671')
        self.assertEqual(hashlib.sha256(self.catalog_path.read_bytes()).hexdigest(), self.manifest['catalog']['sha256'])
        self.assertEqual(len(self.catalog['images']), 19)
        self.assertEqual(len(self.manifest['records']), 15)

    def test_every_catalog_entry_has_exact_size_rgb_and_no_transparency(self):
        for entry in self.catalog['images']:
            with self.subTest(file=entry['filename'], idiom=entry['idiom']):
                chunks = png_chunks((self.catalog_path.parent / entry['filename']).read_bytes())
                scale = Decimal(entry['scale'].removesuffix('x'))
                expected = tuple(int(Decimal(n) * scale) for n in entry['size'].split('x'))
                self.assertEqual(struct.unpack('>IIBB', chunks[b'IHDR'][:10]), (*expected, 8, 2))
                self.assertNotIn(b'tRNS', chunks)
                self.assertEqual(chunks[b'sRGB'], b'\0')

    def test_export_bytes_match_reviewed_manifest(self):
        for record in self.manifest['records']:
            with self.subTest(file=record['file']):
                data = (ROOT / record['file']).read_bytes()
                self.assertEqual(len(data), record['bytes'])
                self.assertEqual(hashlib.sha256(data).hexdigest(), record['sha256'])
        self.assertEqual({p.name for p in self.catalog_path.parent.glob('*.png')},
                         {pathlib.Path(r['file']).name for r in self.manifest['records']})

    def test_only_marketing_export_is_upscaled_and_caveat_is_preserved(self):
        upscaled = [r for r in self.manifest['records'] if r['upscaled']]
        self.assertEqual(len(upscaled), 1)
        self.assertEqual(upscaled[0]['pixels'], [1024, 1024])
        self.assertEqual(upscaled[0]['resample_scale'], 2)
        self.assertIn('not a native 1024px', self.manifest['export']['upscale_caveat'])


if __name__ == '__main__':
    unittest.main()
