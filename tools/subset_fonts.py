"""Builds the shipped font subsets (keeps the game download small).
Source: Pretendard 1.3.9 static OTFs (https://github.com/orioncactus/pretendard/releases).
Usage: python3 tools/subset_fonts.py <dir with Pretendard-Regular.otf and Pretendard-Bold.otf>
Keeps: Latin, punctuation, symbols, Hangul jamo, the 2,350 common Hangul syllables (KS X 1001)
and every character used in data/i18n/*.json. Other characters fall back to the system font."""
import glob, json, os, sys
from fontTools import subset
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1]
chars = set()
for cp in range(0xAC00, 0xD7A4):
    try:
        if len(chr(cp).encode("euc-kr")) == 2:   # KS X 1001 proper (not the 8-byte composed form)
            chars.add(cp)
    except UnicodeEncodeError:
        pass
ranges = [(0x20, 0x7E), (0xA0, 0x17F), (0x2000, 0x206F), (0x20A0, 0x20BF), (0x2100, 0x21FF), (0x2190, 0x21FF),
          (0x2200, 0x22FF), (0x2460, 0x24FF), (0x25A0, 0x25FF), (0x2600, 0x26FF), (0x2700, 0x27BF), (0x3000, 0x303F),
          (0x3130, 0x318F), (0xFF01, 0xFF5E)]
for a, b in ranges:
    chars.update(range(a, b + 1))
for f in glob.glob(os.path.join(ROOT, "data/i18n/*.json")):
    for ch in open(f, encoding="utf-8").read():
        chars.add(ord(ch))
for weight in ("Regular", "Bold"):
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    font = subset.load_font(os.path.join(src, f"Pretendard-{weight}.otf"), opts)
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=sorted(chars))
    sub.subset(font)
    out = os.path.join(ROOT, f"assets/fonts/Pretendard-{weight}.otf")
    subset.save_font(font, out, opts)
    print(weight, os.path.getsize(out), "bytes,", len(chars), "codepoints requested")
