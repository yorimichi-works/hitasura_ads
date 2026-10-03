// Renders the app icon (tool/icon/icon.mjs) for every platform.
//
//   node tool/icon/build_icons.mjs
//
// Needs Node 18+ and Playwright with a Chromium build
// (`npm i -g playwright && npx playwright install chromium`).
// SVG is rasterised by Chromium at each target size and encoded here with
// zlib, so iOS gets alpha-free PNGs and Windows gets a PNG-based .ico.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';
import { execSync } from 'node:child_process';
import { iconSvg } from './icon.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

async function loadPlaywright() {
  try {
    return await import('playwright');
  } catch {
    const globalRoot = execSync('npm root -g').toString().trim();
    return createRequire(join(globalRoot, 'noop.js'))('playwright');
  }
}

// ---- PNG / ICO encoding ----------------------------------------------------

const CRC = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}
function encodePng(rgba, size, { alpha = true } = {}) {
  const ch = alpha ? 4 : 3;
  const raw = Buffer.alloc((size * ch + 1) * size);
  for (let y = 0; y < size; y++) {
    const row = y * (size * ch + 1);
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4;
      const o = row + 1 + x * ch;
      raw[o] = rgba[i];
      raw[o + 1] = rgba[i + 1];
      raw[o + 2] = rgba[i + 2];
      if (alpha) raw[o + 3] = rgba[i + 3];
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = alpha ? 6 : 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}
function encodeIco(pngs) {
  const head = Buffer.alloc(6 + 16 * pngs.length);
  head.writeUInt16LE(1, 2);
  head.writeUInt16LE(pngs.length, 4);
  let offset = head.length;
  pngs.forEach(({ size, png }, i) => {
    const e = 6 + 16 * i;
    head[e] = size >= 256 ? 0 : size;
    head[e + 1] = size >= 256 ? 0 : size;
    head.writeUInt16LE(1, e + 4);
    head.writeUInt16LE(32, e + 6);
    head.writeUInt32LE(png.length, e + 8);
    head.writeUInt32LE(offset, e + 12);
    offset += png.length;
  });
  return Buffer.concat([head, ...pngs.map((p) => p.png)]);
}

// ---- Rendering --------------------------------------------------------------

const { chromium } = await loadPlaywright();
const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent('<html><body></body></html>');

const cache = new Map();
async function render(variant, size) {
  const key = JSON.stringify([variant, size]);
  if (!cache.has(key)) {
    const svg = iconSvg(variant);
    const data = await page.evaluate(async ({ svg, size }) => {
      const img = new Image();
      img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
      await img.decode();
      const c = document.createElement('canvas');
      c.width = c.height = size;
      const g = c.getContext('2d');
      g.imageSmoothingQuality = 'high';
      g.drawImage(img, 0, 0, size, size);
      return Array.from(g.getImageData(0, 0, size, size).data);
    }, { svg, size });
    cache.set(key, Uint8Array.from(data));
  }
  return cache.get(key);
}

let count = 0;
async function write(rel, variant, size, opts) {
  const path = join(root, rel);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, encodePng(await render(variant, size), size, opts));
  count++;
}

const FULL = { shape: 'square' };
const ROUND = { shape: 'round' };
const MAC = { shape: 'mac' };

// Web
await write('web/favicon.png', ROUND, 64);
await write('web/icons/Icon-192.png', ROUND, 192);
await write('web/icons/Icon-512.png', ROUND, 512);
await write('web/icons/Icon-maskable-192.png', { shape: 'square', scale: 0.78 }, 192);
await write('web/icons/Icon-maskable-512.png', { shape: 'square', scale: 0.78 }, 512);

// iOS: opaque full-bleed squares (the system applies the mask).
const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const ios = JSON.parse(readFileSync(join(root, iosDir, 'Contents.json'), 'utf8'));
for (const im of ios.images) {
  if (!im.filename) continue;
  const px = Math.round(parseFloat(im.size) * parseFloat(im.scale));
  await write(`${iosDir}/${im.filename}`, FULL, px, { alpha: false });
}

// macOS: rounded tile on the Big Sur icon grid.
const macDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const mac = JSON.parse(readFileSync(join(root, macDir, 'Contents.json'), 'utf8'));
for (const im of mac.images) {
  if (!im.filename) continue;
  const px = Math.round(parseFloat(im.size) * parseFloat(im.scale));
  await write(`${macDir}/${im.filename}`, MAC, px);
}

// Android: legacy launcher icon + adaptive layers (API 26+).
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
const res = 'android/app/src/main/res';
for (const [d, k] of Object.entries(densities)) {
  await write(`${res}/mipmap-${d}/ic_launcher.png`, ROUND, 48 * k);
  await write(`${res}/mipmap-${d}/ic_launcher_background.png`, { fg: false }, 108 * k);
  await write(`${res}/mipmap-${d}/ic_launcher_foreground.png`, { bg: false, scale: 0.7 }, 108 * k);
}

// Windows
const ico = [];
for (const size of [16, 24, 32, 48, 64, 256]) {
  ico.push({ size, png: encodePng(await render(ROUND, size), size) });
}
writeFileSync(join(root, 'windows/runner/resources/app_icon.ico'), encodeIco(ico));
count++;

// Source preview
writeFileSync(join(root, 'tool/icon/icon.svg'), iconSvg(ROUND));
count++;

await browser.close();
console.log(`wrote ${count} files`);
