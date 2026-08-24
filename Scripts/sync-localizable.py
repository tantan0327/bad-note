#!/usr/bin/env python3
"""Localizable.xcstrings をコードの実文字列と同期する(tasks.md 6.2)。

コマンドラインの xcodebuild は SwiftPM モジュール内の文字列を抽出しないので、
`Text("…", bundle: .module)` を自前で走査してカタログに反映する。

- コードにあるキー: カタログへ追加(既存の訳・状態は保持)。comment も写す
- コードに無いキー: カタログから削除(テンプレートの残骸を残さない)

使い方: python3 Scripts/sync-localizable.py
"""

import glob
import json
import re
import sys

CATALOG = "Sources/BadNote/Resources/Localizable.xcstrings"

# Text("キー", bundle: .module) / Text("キー", bundle: .module, comment: "…")
# 改行を挟む呼び出しにも合わせる
PATTERN = re.compile(
    r'Text\(\s*"((?:[^"\\]|\\.)+)"\s*,\s*bundle:\s*\.module'
    r'(?:\s*,\s*comment:\s*"((?:[^"\\]|\\.)*)")?',
    re.S,
)

# Text(条件 ? "キーA" : "キーB", bundle: .module) の 2 キーも拾う
TERNARY = re.compile(
    r'Text\([^"\n]*\?\s*"((?:[^"\\]|\\.)+)"\s*:\s*"((?:[^"\\]|\\.)+)"\s*,\s*bundle:\s*\.module',
)


def main() -> int:
    keys: dict[str, str] = {}
    for path in glob.glob("Sources/BadNote/**/*.swift", recursive=True):
        with open(path, encoding="utf-8") as f:
            source = f.read()
        for match in PATTERN.finditer(source):
            key, comment = match.group(1), match.group(2)
            if comment:
                keys[key] = comment
            else:
                keys.setdefault(key, "")
        for match in TERNARY.finditer(source):
            keys.setdefault(match.group(1), "")
            keys.setdefault(match.group(2), "")

    with open(CATALOG, encoding="utf-8") as f:
        catalog = json.load(f)
    old = catalog.get("strings", {})

    strings: dict[str, dict] = {}
    for key in sorted(keys):
        entry = dict(old.get(key, {}))
        # 手で書いた覚え書きより、コードの comment を正とする
        if keys[key]:
            entry["comment"] = keys[key]
        entry.pop("extractionState", None)
        strings[key] = entry

    added = sorted(k for k in keys if k not in old)
    removed = sorted(k for k in old if k not in keys)
    catalog["strings"] = strings

    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=True)
        f.write("\n")

    print(f"コードのキー: {len(keys)} / 追加: {len(added)} / 削除: {len(removed)}")
    for key in added:
        print(f"  + {key}")
    for key in removed:
        print(f"  - {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
