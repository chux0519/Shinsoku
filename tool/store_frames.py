#!/usr/bin/env python3
"""App Store screenshots, step 2 (release-01 R3): frame the renders with a caption.

  build/venv-store/bin/python tool/store_frames.py [--look light|dark] [--locales en-US,ja] [--check]

Needs Pillow, from a venv under build/ (never a global install):
  python3 -m venv build/venv-store && build/venv-store/bin/pip install pillow

Inputs:
  build/store/raw/<locale>/NN-<scene>-<look>.png   host renders, 1320×2868 (tool/store_shots.sh)
  build/store/keyboard/<locale>.png                keyboard frame from the simulator (StoreSceneTests,
                                                   coordinator, tier B); 1206×2622 on iPhone 17. Optional.
  docs/store/metadata/<locale>.yaml  captions      one per scene, in upload order
Output:
  build/store/screenshots/<locale>/NN-<scene>.png  1320×2868 RGB (no alpha), NN = upload order
  build/store/screenshots/index.html               contact sheet

Canvas: flat brand colour (DESIGN.md: light = accent #1F6470 with white text; dark = canvas #101314 with
text #E3E9EA), the caption (≤ 2 lines, wrapped and balanced at spaces, or at a '|' in the caption, which
Chinese/Japanese 2-line captions must have; the font shrinks from 96 to 80 px before it
fails), a "Shinsoku Pro" tag on Pro scenes, the screen scaled into a rounded, device-free frame.
--check only measures: every caption must fit in 2 lines, and so must the English captions stretched by 40 %
(pseudo-length headroom for later wording changes). Fonts: SF Pro (Latin), PingFang SC/TC, Hiragino Sans,
Apple SD Gothic Neo — all shipped with macOS.
"""
import argparse
import html
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import store_metadata  # noqa: E402  (YAML subset parser, locales, caption scene order)

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    sys.exit('Pillow missing: python3 -m venv build/venv-store && build/venv-store/bin/pip install pillow, '
             'then run this script with build/venv-store/bin/python')

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build' / 'store' / 'raw'
KEYBOARD = ROOT / 'build' / 'store' / 'keyboard'
OUT = ROOT / 'build' / 'store' / 'screenshots'
W, H = 1320, 2868
SCENES = store_metadata.CAPTION_SCENES
PRO_SCENES = {'profiles', 'field-rules', 'desktop'}
LOOKS = {
    'light': {'bg': (0x1F, 0x64, 0x70), 'text': (0xFF, 0xFF, 0xFF), 'tag_bg': (0xD6, 0xEC, 0xEF),
              'tag_text': (0x1F, 0x64, 0x70), 'edge': (255, 255, 255, 60)},
    'dark': {'bg': (0x10, 0x13, 0x14), 'text': (0xE3, 0xE9, 0xEA), 'tag_bg': (0x23, 0x46, 0x4C),
             'tag_text': (0x6C, 0xC3, 0xCF), 'edge': (255, 255, 255, 40)},
}
CAPTION_SIZES = range(96, 79, -4)  # 96, 92, 88, 84, 80
CAPTION_WIDTH = 1120
LINE_HEIGHT = 1.2
SCREEN_W = 1000
SCREEN_TOP = 560
RADIUS = 120
HEADER = (110, SCREEN_TOP - 50)  # caption block is centred vertically in this band


def _pingfang():
    for p in sorted(Path('/System/Library/AssetsV2').glob('com_apple_MobileAsset_Font*/*.asset/AssetData/PingFang.ttc')):
        return p
    return None


def font(locale: str, size: int, weight: int = 700):
    lang = locale.split('-')[0]
    if lang == 'zh':
        pf = _pingfang()
        if pf is None:
            sys.exit('PingFang.ttc not found under /System/Library/AssetsV2 (download it in Font Book)')
        return ImageFont.truetype(str(pf), size, index=11 if locale == 'zh-Hans' else 10)  # SC / TC Semibold
    if lang == 'ja':
        return ImageFont.truetype('/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc', size, index=0)
    if lang == 'ko':
        return ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', size, index=6)  # Bold
    f = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', size)
    axes = {a['name']: a['default'] for a in f.get_variation_axes()}
    axes[b'Weight'] = weight
    axes[b'Optical Size'] = min(96, max(17, size))
    f.set_variation_by_axes([axes[a['name']] for a in f.get_variation_axes()])
    return f


# ---------- wrapping ----------

NO_START = set('，。、．,.!?！？:;：；)）]」』】〉》・ーっゃゅょッャュョ%…’”')
NO_END = set('（([「『【〈《‘“')


def _cjk(ch: str) -> bool:
    """Chinese / Japanese characters (a line may break between them). Hangul is not: Korean breaks at spaces."""
    o = ord(ch)
    return 0x3000 <= o <= 0x9FFF or 0xF900 <= o <= 0xFAFF or 0xFF00 <= o <= 0xFFEF


def _breaks(text: str):
    """(index, skip): a line may end before text[index]; skip=1 drops the space there."""
    out = []
    for i in range(1, len(text)):
        a, b = text[i - 1], text[i]
        if b == ' ':
            out.append((i, 1))
        elif a == ' ':
            continue
        elif (_cjk(a) or _cjk(b)) and b not in NO_START and a not in NO_END:
            out.append((i, 0))
    return out


def wrap(text: str, f, width: int):
    """At most 2 balanced lines that fit [width], or None. A '|' in the caption is the break (required for
    Chinese/Japanese captions on 2 lines: a character-level break can split a word)."""
    if '|' in text:
        lines = [x.strip() for x in text.split('|')]
        return lines if len(lines) == 2 and all(f.getlength(x) <= width for x in lines) else None
    if f.getlength(text) <= width:
        return [text]
    if any(_cjk(ch) for ch in text):
        return None
    best = None
    for i, skip in _breaks(text):
        a, b = text[:i].rstrip(), text[i + skip:].lstrip()
        wa, wb = f.getlength(a), f.getlength(b)
        if wa <= width and wb <= width:
            score = (max(wa, wb), wb < wa * 0.5)
            if best is None or score < best[0]:
                best = (score, [a, b])
    return best[1] if best else None


def fit(locale: str, text: str):
    for size in CAPTION_SIZES:
        f = font(locale, size)
        lines = wrap(text, f, CAPTION_WIDTH)
        if lines:
            return f, size, lines
    return None


def pseudo(text: str) -> str:
    """~40 % longer, word-shaped, like the pseudo locale."""
    words = text.split()
    extra, i = [], 0
    while len(' '.join(words + extra)) < len(text) * 1.4:
        extra.append(words[i % len(words)])
        i += 1
    return ' '.join(words + extra)


# ---------- drawing ----------

def rounded_mask(size, radius):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def compose(locale: str, scene: str, screen: Image.Image, look: str) -> Image.Image:
    L = LOOKS[look]
    canvas = Image.new('RGB', (W, H), L['bg'])
    draw = ImageDraw.Draw(canvas)
    caption = store_metadata.load_locale(locale)['captions'][scene]
    fitted = fit(locale, caption)
    if not fitted:
        raise SystemExit(f'{locale}/{scene}: caption does not fit in 2 lines: {caption!r}')
    f, size, lines = fitted
    line_h = round(size * LINE_HEIGHT)
    tag_h, tag_gap = (64, 36) if scene in PRO_SCENES else (0, 0)
    block_h = tag_h + tag_gap + line_h * len(lines)
    y = HEADER[0] + (HEADER[1] - HEADER[0] - block_h) // 2
    if tag_h:
        tf = font('en-US', 34, 600)
        label = 'Shinsoku Pro'
        tw = tf.getlength(label)
        x0 = (W - tw) / 2 - 28
        draw.rounded_rectangle([x0, y, x0 + tw + 56, y + tag_h], radius=tag_h / 2, fill=L['tag_bg'])
        draw.text((W / 2, y + tag_h / 2), label, font=tf, fill=L['tag_text'], anchor='mm')
        y += tag_h + tag_gap
    for line in lines:
        draw.text((W / 2, y + line_h / 2), line, font=f, fill=L['text'], anchor='mm')
        y += line_h
    # screen
    sw = SCREEN_W
    sh = round(screen.height * sw / screen.width)
    shot = screen.convert('RGB').resize((sw, sh), Image.LANCZOS)
    x = (W - sw) // 2
    top = SCREEN_TOP
    shadow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x, top + 24, x + sw, top + sh + 24], radius=RADIUS, fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.paste(Image.new('RGB', (W, H), (0, 0, 0)), (0, 0), shadow)
    canvas.paste(shot, (x, top), rounded_mask((sw, sh), RADIUS))
    edge = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle([x - 1, top - 1, x + sw, top + sh], radius=RADIUS + 1,
                                            outline=L['edge'], width=3)
    canvas.paste(edge, (0, 0), edge)
    return canvas


def raw_for(locale: str, scene: str, look: str):
    if scene == 'keyboard':
        p = KEYBOARD / f'{locale}.png'
        return p if p.is_file() else None
    hits = sorted((RAW / locale).glob(f'[0-9][0-9]-{scene}-{look}.png'))
    return hits[0] if hits else None


def check(locales):
    problems = []
    for loc in locales:
        caps = store_metadata.load_locale(loc)['captions']
        for scene in SCENES:
            r = fit(loc, caps[scene])
            if not r:
                hint = ' (Chinese/Japanese: mark the break with |)' if any(map(_cjk, caps[scene])) else ''
                problems.append(f'{loc}/{scene}: does not fit in 2 lines{hint}: {caps[scene]!r}')
            else:
                print(f'  {loc:8} {scene:12} {r[1]}px {len(r[2])} line(s): {" / ".join(r[2])}')
            if loc == 'en-US':
                p = pseudo(caps[scene])
                if not fit(loc, p):
                    problems.append(f'{loc}/{scene}: no headroom, +40 % does not fit: {p!r}')
    for p in problems:
        print('FAIL', p)
    if not problems:
        print(f'ok: captions fit ({len(locales)} locales, + pseudo-length check)')
    return 1 if problems else 0


def contact_sheet(locales):
    parts = ['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
             '<title>Shinsoku App Store screenshots</title>',
             '<style>body{font:13px -apple-system,sans-serif;background:#1b1d1e;color:#ddd;margin:16px}'
             'section{margin-bottom:28px}div{display:flex;gap:10px;flex-wrap:wrap}figure{margin:0}'
             'img{height:420px;border:1px solid #444}figcaption{color:#aaa;margin-top:4px}</style>',
             '<p>App Store screenshots, 6.9" (1320×2868), upload order. Host renders; keyboard frames come from '
             'the simulator (tier B).</p>']
    count = 0
    for loc in locales:
        files = sorted((OUT / loc).glob('*.png'))
        count += len(files)
        parts.append(f'<section><h3>{html.escape(loc)} ({len(files)})</h3><div>')
        for p in files:
            rel = p.relative_to(OUT).as_posix()
            parts.append(f'<figure><a href="{html.escape(rel)}"><img src="{html.escape(rel)}" loading="lazy"></a>'
                         f'<figcaption>{html.escape(p.stem)}</figcaption></figure>')
        parts.append('</div></section>')
    (OUT / 'index.html').write_text('\n'.join(parts) + '\n', encoding='utf-8')
    print(f'{count} screenshots -> {OUT / "index.html"}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--look', choices=sorted(LOOKS), default='light')
    ap.add_argument('--locales', default=','.join(store_metadata.LOCALES))
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    locales = [x for x in a.locales.split(',') if x]
    unknown = set(locales) - set(store_metadata.LOCALES)
    if unknown:
        sys.exit(f'unknown locales: {sorted(unknown)}')
    if a.check:
        return check(locales)
    status = 0
    for loc in locales:
        d = OUT / loc
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob('*.png'):
            old.unlink()
        n = 0
        missing = []
        for scene in SCENES:
            src = raw_for(loc, scene, a.look)
            if src is None:
                missing.append(scene)
                continue
            n += 1
            img = Image.open(src)
            if scene != 'keyboard' and img.size != (W, H):
                print(f'FAIL {loc}/{scene}: render is {img.size}, expected {(W, H)}')
                status = 1
            out = compose(loc, scene, img, a.look)
            assert out.size == (W, H) and out.mode == 'RGB'
            out.save(d / f'{n:02d}-{scene}.png', optimize=True)
        note = f' (missing: {", ".join(missing)})' if missing else ''
        print(f'{loc}: {n} screenshots{note}')
        if set(missing) - {'keyboard'}:
            status = 1
    contact_sheet([x for x in store_metadata.LOCALES if (OUT / x).is_dir()])
    return status


if __name__ == '__main__':
    sys.exit(main())
