import io
import json
import os
import re
import struct
import sys

from PIL import Image

PACK_DIR = r'G:\SteamLibrary\steamapps\common\ProjectZomboid\media\texturepacks'
PACKS = ['Tiles2x.pack', 'Tiles2x.floor.pack']
HALF_W, HALF_H, LEVEL = 64, 32, 192

_index = None
_pages = {}


def _load_index():
    global _index
    if _index is not None:
        return _index
    _index = {}
    for pack in PACKS:
        path = os.path.join(PACK_DIR, pack)
        if not os.path.exists(path):
            continue
        data = open(path, 'rb').read()
        pos = 4
        version, pages = struct.unpack_from('<II', data, pos)
        pos += 8

        def read_str():
            nonlocal pos
            (n,) = struct.unpack_from('<I', data, pos)
            pos += 4
            text = data[pos:pos + n].decode('utf-8', 'ignore')
            pos += n
            return text

        for _ in range(pages):
            read_str()
            count, flag = struct.unpack_from('<II', data, pos)
            pos += 8
            entries = []
            for _ in range(count):
                name = read_str()
                x, y, w, h, ox, oy, fw, fh = struct.unpack_from('<8I', data, pos)
                pos += 32
                entries.append((name, x, y, w, h, ox, oy, fw, fh))
            start = data.find(b'\x89PNG\r\n\x1a\n', pos)
            end = data.find(b'IEND', start) + 8
            key = (pack, start)
            _pages[key] = (data, start, end, None)
            for entry in entries:
                _index[entry[0]] = (key, entry)
            pos = end
    return _index


def _page_image(key):
    data, start, end, image = _pages[key]
    if image is None:
        image = Image.open(io.BytesIO(data[start:end])).convert('RGBA')
        _pages[key] = (data, start, end, image)
    return image


def sprite(name):
    index = _load_index()
    hit = index.get(name)
    if hit is None:
        return None
    key, entry = hit
    _, x, y, w, h, ox, oy, fw, fh = entry
    return _page_image(key).crop((x, y, x + w, y + h)), ox, oy, fw, fh


def render(items, out, scale=0.5, background=(52, 78, 48, 255), margin=40, labels=False):
    placed = []
    missing = set()
    for item in items:
        got = sprite(item['s'])
        if got is None:
            missing.add(item['s'])
            continue
        image, ox, oy, fw, fh = got
        x, y, z = item['x'], item['y'], item.get('z', 0)
        cx = (x - y) * HALF_W
        cy = (x + y) * HALF_H - z * LEVEL
        left = cx - fw // 2 + ox
        top = cy - fh + HALF_H + oy
        order = (x + y, z, x, item.get('layer', 0))
        placed.append((order, image, left, top))
    if not placed:
        print('nothing to draw, missing:', sorted(missing))
        return None
    placed.sort(key=lambda row: row[0])
    min_x = min(p[2] for p in placed) - margin
    min_y = min(p[3] for p in placed) - margin
    max_x = max(p[2] + p[1].width for p in placed) + margin
    max_y = max(p[3] + p[1].height for p in placed) + margin
    canvas = Image.new('RGBA', (max_x - min_x, max_y - min_y), background)
    for _, image, left, top in placed:
        canvas.alpha_composite(image, (left - min_x, top - min_y))
    if scale != 1:
        canvas = canvas.resize((max(1, int(canvas.width * scale)), max(1, int(canvas.height * scale))), Image.LANCZOS)
    canvas.save(out)
    if missing:
        print('missing sprites:', sorted(missing))
    print('saved', out, canvas.size)
    return canvas


def main():
    if len(sys.argv) < 3:
        print('usage: python iso_preview.py items.json out.png [scale]')
        print('items.json: [{"x": 10, "y": 20, "z": 0, "s": "sprite_name"}, ...]')
        print('draws an isometric scene with Tiles2x sprites (one grid cell = 128x64 px before scale, level height 192 px)')
        return 1
    items = json.load(open(sys.argv[1], encoding='utf-8'))
    scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    render(items, sys.argv[2], scale)
    return 0


if __name__ == '__main__':
    sys.exit(main())
