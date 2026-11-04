#!/usr/bin/env python3
"""Turn MedTagger XML output files into one table.

Reads every *.xml file in OUTPUT_DIR, writes OUTPUT_DIR/results.csv
(one row per found concept) and prints the rows as a table.

Usage:  python3 scripts/xml_to_table.py OUTPUT_DIR [CSV_PATH]
"""
import csv
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

COLUMNS = ["file", "id", "text", "start", "end", "concept_id",
           "certainty", "experiencer", "status", "section", "semgroup"]


def rows_from(xml_path):
    root = ET.parse(xml_path).getroot()
    tags = root.find("TAGS")
    for cm in (tags if tags is not None else []):
        start, _, end = cm.get("spans", "").partition("~")
        yield {
            "file": xml_path.name,
            "id": cm.get("id", ""),
            "text": cm.get("text", ""),
            "start": start,
            "end": end,
            "concept_id": cm.get("normTarget", ""),
            "certainty": cm.get("certainty", ""),
            "experiencer": cm.get("experiencer", ""),
            "status": cm.get("status", ""),
            "section": cm.get("section", ""),
            "semgroup": cm.get("semG", ""),
        }


def print_table(rows):
    if not rows:
        print("(no concepts found)")
        return
    widths = {c: max(len(c), *(len(r[c]) for r in rows)) for c in COLUMNS}
    line = lambda r: " | ".join(r[c].ljust(widths[c]) for c in COLUMNS)
    print(line({c: c for c in COLUMNS}))
    print("-+-".join("-" * widths[c] for c in COLUMNS))
    for r in rows:
        print(line(r))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out_dir = Path(sys.argv[1])
    csv_path = Path(sys.argv[2]) if len(sys.argv) > 2 else out_dir / "results.csv"

    rows = []
    for xml_path in sorted(out_dir.glob("*.xml")):
        try:
            rows.extend(rows_from(xml_path))
        except ET.ParseError as e:
            print(f"skipped {xml_path.name}: {e}", file=sys.stderr)

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)

    print_table(rows)
    print(f"\n{len(rows)} concept(s) written to {csv_path}")


if __name__ == "__main__":
    main()
