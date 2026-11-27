#!/usr/bin/env python3
"""Generate chronicle_templates.json from data/chronicle/templates.txt."""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "chronicle" / "templates.txt"
OUT = ROOT / "Packages" / "GezCore" / "Sources" / "GezCore" / "Resources" / "chronicle_templates.json"

REQUIRED_KINDS = [
    "war_declared",
    "war_ended",
    "major_battle",
    "naval_battle",
    "siege_captured",
    "peace_treaty",
    "law_changed",
    "reform_adopted",
    "plague_outbreak",
    "famine",
    "rebellion",
    "ruler_crowned",
    "ruler_died",
    "marriage",
    "heir_born",
    "nation_formed",
]


def parse_templates(path: pathlib.Path) -> dict[str, list[str]]:
    templates: dict[str, list[str]] = {}
    current_kind: str | None = None

    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            kind = line[1:-1].strip()
            if kind not in REQUIRED_KINDS:
                raise ValueError(f"{path}:{lineno}: unknown chronicle kind '{kind}'")
            current_kind = kind
            templates.setdefault(current_kind, [])
        elif line.startswith("- "):
            if current_kind is None:
                raise ValueError(f"{path}:{lineno}: template line outside a [kind] section")
            text = line[2:].strip()
            if not text:
                raise ValueError(f"{path}:{lineno}: empty template")
            templates[current_kind].append(text)
        else:
            raise ValueError(f"{path}:{lineno}: unexpected syntax: {raw}")

    for kind in REQUIRED_KINDS:
        variants = templates.get(kind, [])
        if len(variants) < 3:
            raise ValueError(f"{path}: kind '{kind}' must have at least 3 template variants (found {len(variants)})")

    return templates


def main() -> int:
    templates = parse_templates(SRC)
    payload = {"templates": templates}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    total = sum(len(v) for v in templates.values())
    print(f"Generated {OUT.relative_to(ROOT)} ({len(templates)} kinds, {total} templates)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
