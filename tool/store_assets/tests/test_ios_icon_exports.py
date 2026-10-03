"""Validate approved native-size iOS icon exports and metadata-only normalization."""
import hashlib
import json
import pathlib
import struct
import unittest
import zlib
from decimal import Decimal

ROOT = pathlib.Path(__file__).resolve().parents[3]
MANIFEST = ROOT / 'tool/store_assets/ios_icon_export_manifest.json'


def png_chunks(data):
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Not a PNG')
    offset = 8
    chunks = {}
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError('Truncated PNG chunk')
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + length + 12
        if end > len(data):
            raise ValueError('Truncated PNG payload')
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack('>I', data[end - 4:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError('Invalid PNG chunk CRC')
        if kind in chunks:
            raise ValueError('Unexpected duplicate PNG chunk')
        chunks[kind] = payload
        offset += length + 12
    if list(chunks) != [b'IHDR', b'sRGB', b'IDAT', b'IEND']:
        raise ValueError('Unexpected normalized PNG chunk layout')
    return chunks


class IOSIconExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text())
        cls.catalog_path = ROOT / cls.manifest['catalog']['path']
        cls.catalog = json.loads(cls.catalog_path.read_text())

    def test_approved_source_and_catalog_are_pinned(self):
        source = self.manifest['source']
        self.assertEqual(source['commit'], '981afecb2c609b811630ae42d0b118b21288e49c')
        self.assertEqual(source['git_blob'], '585dc6a1c884434d59802d9b34f62851d9bf733f')
        self.assertEqual(source['sha256'], 'a43ae036210326621429d25e8bb40c739dc6236b3e688caf631e0ebd5abae8b6')
        self.assertEqual(source['pixels'], [1024, 1024])
        self.assertEqual(source['renderer'], 'tool/icon/build_icons.mjs')
        marketing = next(r for r in self.manifest['records'] if r['file'] == source['path'])
        self.assertEqual(marketing['source_git_blob'], source['git_blob'])
        self.assertEqual(marketing['source_sha256'], source['sha256'])
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

    def test_metadata_normalization_preserves_every_approved_source_byte(self):
        for record in self.manifest['records']:
            with self.subTest(file=record['file']):
                data = (ROOT / record['file']).read_bytes()
                png_chunks(data)  # Includes CRC and exact chunk-layout checks.
                self.assertEqual(data[33:41], b'\x00\x00\x00\x01sRGB')
                # Remove only the 13-byte sRGB chunk, reconstructing the exact
                # approved per-size PNG, including unchanged IHDR and IDAT bytes.
                source = data[:33] + data[46:]
                self.assertEqual(len(source), record['source_bytes'])
                self.assertEqual(len(data), record['source_bytes'] + 13)
                self.assertEqual(hashlib.sha256(source).hexdigest(), record['source_sha256'])
                git_blob = b'blob ' + str(len(source)).encode() + b'\0' + source
                self.assertEqual(hashlib.sha1(git_blob).hexdigest(), record['source_git_blob'])

    def test_native_size_exports_are_not_upscaled(self):
        self.assertFalse(any(r['upscaled'] for r in self.manifest['records']))
        self.assertTrue(all(r['resample_scale'] == 1 for r in self.manifest['records']))
        self.assertIn('native-size vector render', self.manifest['export']['upscale_caveat'])

    def test_invalid_chunk_crc_is_rejected(self):
        data = bytearray((ROOT / self.manifest['records'][0]['file']).read_bytes())
        data[41] ^= 1
        with self.assertRaisesRegex(ValueError, 'CRC'):
            png_chunks(bytes(data))


if __name__ == '__main__':
    unittest.main()
