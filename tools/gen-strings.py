#!/usr/bin/env python3
"""Vygeneruje preklady pre iOS a Android z localization/strings.json.

    python3 tools/gen-strings.py

iOS:     ios/RadioPackage/Sources/L10n/Resources/<lang>.lproj/Localizable.strings
         ios/RadioPackage/Sources/L10n/L10n.swift (typované prístupy)
         ios/App/Resources/<lang>.lproj/InfoPlist.strings
Android: android/app/src/main/res/values[-<lang>]/strings.xml
         android/app/src/main/res/xml/locales_config.xml
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = json.loads((ROOT / "localization/strings.json").read_text(encoding="utf-8"))
LANGUAGES = TABLE["languages"]
STRINGS = TABLE["strings"]
BASE = "en"
PLACEHOLDER = re.compile(r"\{(\d+)\}")
HEADER = "Vygenerované z localization/strings.json (tools/gen-strings.py) – neupravuj ručne."


def value(entry, lang):
    return entry.get(lang) or entry[BASE]


def for_platform(platform):
    return {k: v for k, v in STRINGS.items() if platform in v.get("platforms", ["ios", "android"])}


def arg_count(text):
    return max((int(n) for n in PLACEHOLDER.findall(text)), default=0)


# ---------- iOS ----------

def ios_escape(text):
    text = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return PLACEHOLDER.sub(lambda m: f"%{m.group(1)}$@", text)


def swift_name(key):
    parts = re.split(r"[._]", key)
    name = parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])
    return ("_" + name) if name[0].isdigit() else name


def write_ios():
    strings = for_platform("ios")
    resources = ROOT / "ios/RadioPackage/Sources/L10n/Resources"
    for lang in LANGUAGES:
        folder = resources / f"{lang}.lproj"
        folder.mkdir(parents=True, exist_ok=True)
        lines = [f"/* {HEADER} */", ""]
        lines += [f'"{key}" = "{ios_escape(value(entry, lang))}";' for key, entry in strings.items()]
        (folder / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")

        app = ROOT / f"ios/App/Resources/{lang}.lproj"
        app.mkdir(parents=True, exist_ok=True)
        plist = {
            "CFBundleDisplayName": value(STRINGS["app.name"], lang),
            "NSSiriUsageDescription": value(STRINGS["voice.siri.usage"], lang),
        }
        lines = [f"/* {HEADER} */", ""] + [f'"{k}" = "{ios_escape(v)}";' for k, v in plist.items()]
        (app / "InfoPlist.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")

    members = []
    for key, entry in strings.items():
        if key.startswith("genre."):
            continue  # žánre sa hľadajú podľa tagu cez L10n.genre(_:)
        count = arg_count(entry[BASE])
        name = swift_name(key)
        doc = entry[BASE].replace("\n", " ")
        if count == 0:
            members.append(f'  /// {doc}\n  public static var {name}: String {{ tr("{key}") }}')
        else:
            params = ", ".join(f"_ p{i}: String" for i in range(1, count + 1))
            args = ", ".join(f"p{i}" for i in range(1, count + 1))
            members.append(f'  /// {doc}\n  public static func {name}({params}) -> String {{ tr("{key}", {args}) }}')

    source = f"""// {HEADER}

import Foundation

/// Lokalizované texty aplikácie (rovnaké ako v Android aplikácii).
public enum L10n {{
{chr(10).join(members)}

  /// Názov žánru podľa tagu z Radio Browser, napr. „top 40“.
  public static func genre(_ tag: String) -> String {{
    tr("genre." + tag.replacingOccurrences(of: " ", with: ""))
  }}

  /// Jazyky, do ktorých je aplikácia preložená.
  public static let languages = {json.dumps(LANGUAGES)}

  private static func tr(_ key: String, _ args: CVarArg...) -> String {{
    let format = Bundle.module.localizedString(forKey: key, value: nil, table: nil)
    return args.isEmpty ? format : String(format: format, locale: .current, arguments: args)
  }}
}}
"""
    (ROOT / "ios/RadioPackage/Sources/L10n/L10n.swift").write_text(source, encoding="utf-8")


# ---------- Android ----------

def android_escape(text):
    text = (
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        .replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")
    )
    if text.startswith(("@", "?")):
        text = "\\" + text
    return PLACEHOLDER.sub(lambda m: f"%{m.group(1)}$s", text)


def android_name(key):
    """„car.yourCountry“ → „car_your_country“."""
    snake = re.sub(r"(?<=[a-z0-9])([A-Z])", r"_\1", key).replace(".", "_").lower()
    return re.sub(r"[^a-z0-9_]", "_", snake)


def write_android():
    strings = for_platform("android")
    res = ROOT / "android/app/src/main/res"
    for lang in LANGUAGES:
        folder = res / ("values" if lang == BASE else f"values-{lang}")
        folder.mkdir(parents=True, exist_ok=True)
        lines = ['<?xml version="1.0" encoding="utf-8"?>', f"<!-- {HEADER} -->", "<resources>"]
        for key, entry in strings.items():
            lines.append(f'    <string name="{android_name(key)}">{android_escape(value(entry, lang))}</string>')
        lines.append("</resources>")
        (folder / "strings.xml").write_text("\n".join(lines) + "\n", encoding="utf-8")

    (res / "xml").mkdir(exist_ok=True)
    locales = "\n".join(f'    <locale android:name="{lang}" />' for lang in LANGUAGES)
    (res / "xml/locales_config.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        f"<!-- {HEADER} -->\n"
        '<locale-config xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f"{locales}\n</locale-config>\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    missing = [(k, l) for k, e in STRINGS.items() for l in LANGUAGES if l not in e and BASE not in e]
    assert not missing, f"Chýba anglický text: {missing}"
    write_ios()
    write_android()
    print(f"OK – {len(STRINGS)} textov × {len(LANGUAGES)} jazykov")
