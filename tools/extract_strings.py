"""Lists user-facing English strings (translation keys) and reports which are missing from data/i18n/<lang>.json.
Usage: python3 tools/extract_strings.py [ko]"""
import json, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lang = sys.argv[1] if len(sys.argv) > 1 else "ko"
lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
skip_files = {"tests", "tools"}
keys = set()
TECH = re.compile(r'^(res|user)://|^#|^[a-z0-9_./%\-]+$|^[A-Z0-9_]+$|^%[-+0-9.]*[dfs]$|^[a-z_]+\.[a-z_]+$')
for dirpath, _, files in os.walk(os.path.join(ROOT, "scripts")):
    for f in files:
        if not f.endswith(".gd"):
            continue
        for line in open(os.path.join(dirpath, f), encoding="utf-8"):
            code = line.split("##")[0]
            if code.strip().startswith("#"):
                continue
            for m in lit.finditer(code):
                s = m.group(1).encode().decode("unicode_escape") if "\\" in m.group(1) else m.group(1)
                if not re.search(r"[A-Za-z]{2,}", s) or TECH.search(s):
                    continue
                if any(t in code for t in ("theme_", "_override", "preload(", "load(", "has_method", "get_node")) and "tr(" not in code:
                    continue
                keys.add(s)
# data files
bal = json.load(open(os.path.join(ROOT, "data/balance.json")))
for grp in ("budgets", "car_levels", "headquarters", "philosophies"):
    for e in bal[grp]:
        keys.add(e["name"]); keys.add(e["desc"])
for c in json.load(open(os.path.join(ROOT, "data/components.json")))["components"]:
    keys.add(c["name"])
for d in json.load(open(os.path.join(ROOT, "data/components.json")))["dimensions"]:
    keys.add(d.replace("_", " ").title())
for c in json.load(open(os.path.join(ROOT, "data/championships.json")))["championships"]:
    keys.add(c["name"])
for d in json.load(open(os.path.join(ROOT, "data/drivers.json")))["drivers"]:
    for t in d["traits"]:
        keys.add(t)
path = os.path.join(ROOT, "data/i18n", lang + ".json")
have = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
missing = sorted(k for k in keys if k not in have)
print(f"{len(keys)} keys, {len(missing)} missing in {lang}.json")
for k in missing:
    print(json.dumps(k, ensure_ascii=False))
