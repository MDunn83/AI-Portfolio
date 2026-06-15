#!/usr/bin/env python3
"""Extract and scrub a single Zap from a Zapier GDPR export.

Zapier's data export ("version": "gdpr_v1") bundles *every* Zap into one
JSON file, with your real account IDs, connection IDs, spreadsheet IDs, and
email addresses in cleartext. This tool pulls out one Zap by title (or id)
and replaces those values with placeholders so the result is safe to commit
to a public-synced folder.

Usage:
    # See what's in the export
    python extract_zap.py export.zip --list
    python extract_zap.py export.json --list

    # Extract + scrub one Zap to a file
    python extract_zap.py export.zip --title "AI Governance" -o out.json
    python extract_zap.py export.zip --id 368531070 -o out.json

Input may be the raw .json or the .zip Zapier hands you (the script finds the
single .json inside). Title match is case-insensitive substring; it errors if
the match is ambiguous so you never silently grab the wrong Zap.

What gets scrubbed:
    account_id, customuser_id              -> 0
    authentication_id (nonzero integers)  -> 0   (connection IDs)
    spreadsheet IDs                        -> YOUR_<NAME>_SHEET_ID
                                              (NAME taken from the Zap's own
                                               human-readable parammap label)
    email in a "from" field                -> YOUR_EMAIL_FROM
    email in a "to" field                  -> YOUR_EMAIL_TO
    any other real email                   -> YOUR_EMAIL

Descriptive labels (parammap names like "Proj4"/"Questions"), prompts, and
Code steps are kept as-is — they don't leak anything.

After writing, the script re-scans the output and fails loudly if any of the
original sensitive values survived, and warns about any other long ID-like
tokens left in params so you can eyeball them.
"""

import argparse
import json
import re
import sys
import zipfile

# Strict email pattern: TLD must be alphabetic, so Zapier API identifiers like
# "CodeCLIAPI@1.0.1" or "AICLIAPI@3.8.5" are NOT treated as emails.
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
# Google Sheet/Drive IDs are long; flag leftovers for manual review.
LONGID_RE = re.compile(r"^[A-Za-z0-9_-]{25,}$")


def load_export(path):
    """Return the parsed export dict from a .json or .zip path."""
    if path.lower().endswith(".zip"):
        with zipfile.ZipFile(path) as z:
            jsons = [n for n in z.namelist() if n.lower().endswith(".json")]
            if len(jsons) != 1:
                sys.exit(f"Expected exactly one .json in {path}, found: {jsons}")
            with z.open(jsons[0]) as f:
                return json.load(f)
    with open(path) as f:
        return json.load(f)


def slugify(name):
    return re.sub(r"_+", "_", re.sub(r"[^A-Za-z0-9]+", "_", name)).strip("_").upper()


def select_zap(export, title=None, zap_id=None):
    zaps = export.get("zaps", [])
    if zap_id is not None:
        matches = [z for z in zaps if str(z.get("id")) == str(zap_id)]
    elif title is not None:
        t = title.lower()
        matches = [z for z in zaps if t in (z.get("title") or "").lower()]
    else:
        sys.exit("Provide --title or --id (or --list to see what's available).")

    if not matches:
        sys.exit("No Zap matched. Run with --list to see available Zaps.")
    if len(matches) > 1:
        names = "\n  ".join(f'{z["id"]}: {z.get("title")}' for z in matches)
        sys.exit(f"Ambiguous match — narrow it down by --id:\n  {names}")
    return matches[0]


def build_sheet_map(zap):
    """Map each real spreadsheet ID -> placeholder using its parammap label."""
    mapping = {}
    used = set()
    for node in zap.get("nodes", {}).values():
        if not isinstance(node, dict):
            continue
        sid = (node.get("params") or {}).get("spreadsheet")
        if not isinstance(sid, str) or sid in mapping or not LONGID_RE.match(sid):
            continue
        label = ((node.get("meta") or {}).get("parammap") or {}).get("spreadsheet") or "SHEET"
        base = f"YOUR_{slugify(label)}_SHEET_ID"
        placeholder, n = base, 2
        while placeholder in used:
            placeholder, n = f"{base}_{n}", n + 1
        mapping[sid] = placeholder
        used.add(placeholder)
    return mapping


def build_email_map(zap):
    """Classify real emails as FROM / TO / other and map to placeholders."""
    from_set, to_set = set(), set()

    def walk(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if k == "from" and isinstance(v, str):
                    from_set.update(EMAIL_RE.findall(v))
                elif k == "to":
                    vals = v if isinstance(v, list) else [v]
                    for item in vals:
                        if isinstance(item, str):
                            to_set.update(EMAIL_RE.findall(item))
                walk(v)
        elif isinstance(obj, list):
            for x in obj:
                walk(x)

    walk(zap)
    all_emails = set(EMAIL_RE.findall(json.dumps(zap)))
    mapping = {}
    for e in all_emails:
        if e in from_set:
            mapping[e] = "YOUR_EMAIL_FROM"
        elif e in to_set:
            mapping[e] = "YOUR_EMAIL_TO"
        else:
            mapping[e] = "YOUR_EMAIL"
    return mapping


def scrub(obj, replacements):
    if isinstance(obj, dict):
        return {k: (0 if (k in ("account_id", "customuser_id") and isinstance(v, int))
                    else 0 if (k == "authentication_id" and isinstance(v, int) and v != 0)
                    else scrub(v, replacements))
                for k, v in obj.items()}
    if isinstance(obj, list):
        return [scrub(x, replacements) for x in obj]
    if isinstance(obj, str):
        for old, new in replacements.items():
            obj = obj.replace(old, new)
        return obj
    return obj


def main():
    ap = argparse.ArgumentParser(description="Extract + scrub one Zap from a Zapier GDPR export.")
    ap.add_argument("export", help="Path to the Zapier export (.zip or .json)")
    ap.add_argument("--list", action="store_true", help="List Zaps in the export and exit")
    ap.add_argument("--title", help="Case-insensitive substring of the Zap title")
    ap.add_argument("--id", dest="zap_id", help="Exact Zap id")
    ap.add_argument("-o", "--output", help="Output path for the scrubbed single-Zap JSON")
    args = ap.parse_args()

    export = load_export(args.export)

    if args.list:
        for z in export.get("zaps", []):
            print(f'{z.get("id")}  [{z.get("status")}]  {z.get("title")}')
        return

    if not args.output:
        sys.exit("-o/--output is required when extracting.")

    zap = select_zap(export, title=args.title, zap_id=args.zap_id)
    sheet_map = build_sheet_map(zap)
    email_map = build_email_map(zap)
    replacements = {**sheet_map, **email_map}

    cleaned = {"metadata": export.get("metadata", {}), "zaps": [scrub(zap, replacements)]}

    with open(args.output, "w") as f:
        json.dump(cleaned, f, indent=2)

    # Verify: no original sensitive value survived.
    blob = json.dumps(cleaned)
    leaks = [v for v in list(replacements) if v in blob]
    blob_full = json.dumps(zap)
    for key in ("account_id", "customuser_id"):
        for m in set(re.findall(rf'"{key}": (\d+)', blob_full)):
            if m != "0" and f'"{key}": {m}' in blob:
                leaks.append(f"{key}={m}")
    if leaks:
        sys.exit(f"REFUSING TO TRUST OUTPUT — values survived scrub: {leaks}")

    # Warn about any other long ID-like tokens left in params (manual review).
    leftover = set()
    for node in cleaned["zaps"][0].get("nodes", {}).values():
        for v in (node.get("params") or {}).values() if isinstance(node, dict) else []:
            if isinstance(v, str) and LONGID_RE.match(v) and "-" not in v:
                leftover.add(v)

    print(f'Wrote {args.output}')
    print(f'  Zap: {zap.get("title")} (id={zap.get("id")})')
    print(f'  Sheet IDs scrubbed: {len(sheet_map)}  Emails scrubbed: {len(email_map)}')
    for old, new in {**sheet_map, **email_map}.items():
        print(f'    {old}  ->  {new}')
    if leftover:
        print(f'  WARNING — review these long tokens left in params: {sorted(leftover)}')


if __name__ == "__main__":
    main()
