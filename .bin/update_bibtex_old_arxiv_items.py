#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Check ADS to update BibTeX entries. 
Replace old arXiv items and replace them with published versions, if exists.

Logic:
1. If the BibTeX entry is an arXiv paper (journal = {arXiv e-prints}), extract the bibcode from the adsurl field.
2. Use the bibcode to call the ADS Export API to obtain the updated BibTeX entry.
3. If the returned BibTeX entry is still an arXiv paper, skip it.
4. Otherwise, replace the cite key in the returned BibTeX entry with the original entry's cite key, and write it to the output in a new file.
5. Note: You need to first obtain an ADS API Token and save it to the ~/.ads_api_token file. https://github.com/adsabs/adsabs-dev-api?tab=readme-ov-file#access

Usage:
    update_bibtex_old_arxiv_items.py <input_bib_path>

Output: 
    'old_bib_name_updated.bib' in the same directory.
    After that, you can use `diff` command to manually inspect the differences.

"""

import json
import os
import re
import sys
from pathlib import Path
from typing import List, Tuple

import requests

ADS_EXPORT_URL = "https://api.adsabs.harvard.edu/v1/export/bibtex"

def split_entries_with_lines(lines: List[str]) -> List[Tuple[int, int, List[str]]]:
    """
    Split the BibTeX file into entries and return [(start_line_idx, end_line_idx, entry_lines), ...].
    end_line_idx is the slice end index (lines[start:end] in the original list).
    """
    entries = []
    start = None
    for idx, line in enumerate(lines):
        if line.lstrip().startswith("@"):
            if start is not None:
                entries.append((start, idx, lines[start:idx]))
            start = idx
    if start is not None:
        entries.append((start, len(lines), lines[start:]))
    return entries


def extract_cite_key(entry_text: str) -> Tuple[str, str]:
    """
    Extract entry type and cite key from a BibTeX string.
    """
    match = re.match(r'\s*@\s*([A-Za-z]+)\s*{\s*([^,]+)\s*,', entry_text, flags=re.DOTALL)
    if not match:
        raise ValueError("Cannot extract cite key")
    entry_type, cite_key = match.group(1).strip(), match.group(2).strip()
    return entry_type, cite_key


def has_arxiv_journal(entry_text: str) -> bool:
    """
    Check whether the entry is an arXiv citation: journal = {arXiv e-prints}
    """
    return bool(re.search(r'journal\s*=\s*[{"]\s*arXiv\s+e-prints\s*["}]?', entry_text, re.IGNORECASE))


def validate_adsurl(entry_text: str) -> bool:
    """
    Validate that adsurl contains both abs and arxiv.
    """
    return bool(re.search(r'adsurl\s*=\s*[{"]\s*https?://[^}]*abs[^}]*arxiv', entry_text, re.IGNORECASE))


def extract_bibcode(entry_text: str) -> str:
    """
    Extract bibcode from adsurl.
    """
    match = re.search(
        r'adsurl\s*=\s*[{"]\s*https?://ui\.adsabs\.harvard\.edu/abs/([^}"/\s]+)',
        entry_text,
        re.IGNORECASE
    )
    if not match:
        raise ValueError("Failed to extract bibcode from adsurl")
    return match.group(1)


def load_api_token(token_path: Path = Path("~/.ads_api_token").expanduser()) -> str:
    if not token_path.exists():
        raise RuntimeError("Could not find the ~/.ads_api_token file.")
    with token_path.open("r", encoding="utf-8") as f:
        first_line = f.readline().strip()
    if not first_line:
        raise RuntimeError("The ~/.ads_api_token file is empty.")
    return first_line


def fetch_updated_entry(bibcode: str, api_token: str) -> str:
    """
    Use the ADS Export API to fetch the updated BibTeX entry.
    """
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json",
    }
    payload = {"bibcode": [bibcode]}
    response = requests.post(
        ADS_EXPORT_URL,
        headers=headers,
        data=json.dumps(payload),
        timeout=30,
    )
    if not response.ok:
        raise RuntimeError(
            f"ADS API returned status code {response.status_code}: {response.text}"
        )
    data = response.json()
    updated_entry = data.get("export")
    if not updated_entry:
        raise RuntimeError("The ADS API response is missing the 'export' field")
    return updated_entry


def replace_cite_key(entry_text: str, new_key: str) -> str:
    """
    Replace the cite key of a BibTeX entry with the specified new_key.
    """
    def replacer(match):
        return f"{match.group(1)}{new_key}{match.group(3)}"

    return re.sub(
        r'(@\s*[A-Za-z]+\s*{\s*)([^,]+)(\s*,)',
        replacer,
        entry_text,
        count=1,
        flags=re.DOTALL
    )


def main():
    args = sys.argv[1:]
    if not args or args[0] in {"-h", "--help"}:
        help_text = (__doc__ or "").strip()
        if help_text:
            print(help_text)
        return

    input_bib_path = Path(args[0]).expanduser()
    if not input_bib_path.exists():
        print(f"❌ Input file does not exist: {input_bib_path}", file=sys.stderr)
        sys.exit(1)
    try:
        api_token = load_api_token()
    except RuntimeError as exc:
        print(f"❌ {exc} Please refer to https://github.com/adsabs/adsabs-dev-api?tab=readme-ov-file#access to add the token.", file=sys.stderr)
        sys.exit(1)

    with input_bib_path.open("r", encoding="utf-8") as f:
        lines = f.readlines()

    entries = split_entries_with_lines(lines)
    updated_entries: List[str] = []
    updated_count = 0

    print(f"Found {len(entries)} BibTeX entries. Starting to check arXiv entries...\n")

    for start_idx, end_idx, entry_lines in entries:
        entry_text = "".join(entry_lines)
        try:
            entry_type, cite_key = extract_cite_key(entry_text)
        except ValueError:
            print(f"[❗️ Warning] Entry at line {start_idx + 1} cannot parse cite key. Skipped.")
            updated_entries.append(entry_text)
            continue

        if not has_arxiv_journal(entry_text):
            # non arXiv entry, keep original
            updated_entries.append(entry_text)
            continue

        print(f"[Info] Line {start_idx + 1}: Detected arXiv entry -> cite_key = {cite_key}")

        if not validate_adsurl(entry_text):
            print(f"  [❌ Error] The adsurl field failed validation (it must include abs and arxiv). Skipped: {cite_key}")
            updated_entries.append(entry_text)
            continue

        try:
            bibcode = extract_bibcode(entry_text)
        except ValueError as exc:
            print(f"  [❗️ Warning] {exc} -> Skipped: {cite_key}")
            updated_entries.append(entry_text)
            continue

        print(f"  [Info] Extracted ADS bibcode: {bibcode}")

        try:
            updated_entry = fetch_updated_entry(bibcode, api_token)
        except Exception as exc:
            print(f"  [❌ Failure] ADS API call failed: {exc} -> Skipped: {cite_key}")
            updated_entries.append(entry_text)
            continue

        if has_arxiv_journal(updated_entry):
            print(f"  [🤪 Info] ADS response is still an arXiv entry. Skipped: {cite_key}")
            updated_entries.append(entry_text)
            continue

        updated_entry = replace_cite_key(updated_entry, cite_key)
        if not updated_entry.endswith("\n"):
            updated_entry += "\n"
        updated_entries.append(updated_entry)
        updated_count += 1
        print(f"  [✅ Success] Updated {cite_key}\n")

    output_path = input_bib_path.with_stem(input_bib_path.stem + "_updated")
    with output_path.open("w", encoding="utf-8") as f:
        f.write("".join(updated_entries))

    print(f"\nProcessing finished. Updated {updated_count} arXiv entries.")
    print(f"The updated BibTeX file has been written to: {output_path}")


if __name__ == "__main__":
    main()