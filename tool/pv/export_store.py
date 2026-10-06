"""Copy finished App Store media from build/ into store/app_store/ for commit.

    python tool/pv/export_store.py

Screenshots: build/store/<lang>/<device>/0X_*.png (raw_*.png are skipped)
  -> store/app_store/<lang>/<device>/0X_*.png, opaque RGB (App Store rejects alpha),
     plus a contact_sheet.jpg per folder for quick review.
Previews:    build/pv/out/PV_<lang>.mp4 -> store/app_store/pv/PV_<lang>.mp4
"""

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'build' / 'store'
DST = ROOT / 'store' / 'app_store'
SIZES = {'iphone_6_9': (1320, 2868), 'ipad_13': (2064, 2752)}


def main():
    count = 0
    for lang_dir in sorted(p for p in SRC.iterdir() if p.is_dir()):
        for device, size in SIZES.items():
            src = lang_dir / device
            shots = sorted(p for p in src.glob('0*.png'))
            if not shots:
                continue
            out = DST / lang_dir.name / device
            if out.exists():
                shutil.rmtree(out)
            out.mkdir(parents=True)
            thumbs = []
            for p in shots:
                im = Image.open(p).convert('RGB')
                assert im.size == size, (p, im.size)
                im.save(out / p.name, optimize=True)
                t = im.copy()
                t.thumbnail((size[0] // 5, size[1] // 5))
                thumbs.append(t)
                count += 1
            sheet = Image.new('RGB', (sum(t.width for t in thumbs), thumbs[0].height), 'white')
            x = 0
            for t in thumbs:
                sheet.paste(t, (x, 0))
                x += t.width
            sheet.save(out / 'contact_sheet.jpg', quality=88)
    (DST / 'pv').mkdir(parents=True, exist_ok=True)
    pv = sorted((ROOT / 'build' / 'pv' / 'out').glob('PV_*.mp4'))
    for p in pv:
        shutil.copy2(p, DST / 'pv' / p.name)
    print(f'{count} screenshots, {len(pv)} previews -> {DST}')


if __name__ == '__main__':
    main()
