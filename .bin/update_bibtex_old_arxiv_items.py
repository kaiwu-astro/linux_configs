#!/usr/bin/env python3
# -*- coding: utf-8 -*-

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
    将 bibtex 文件按条目划分，并返回 [(start_line_idx, end_line_idx, entry_lines), ...]
    end_line_idx 为 slice 末端索引（即 entry 在原列表中的切片 lines[start:end]）
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
    从 BibTeX 字符串中提取 entry 类型和 cite key
    """
    match = re.match(r'\s*@\s*([A-Za-z]+)\s*{\s*([^,]+)\s*,', entry_text, flags=re.DOTALL)
    if not match:
        raise ValueError("无法解析 cite key")
    entry_type, cite_key = match.group(1).strip(), match.group(2).strip()
    return entry_type, cite_key


def has_arxiv_journal(entry_text: str) -> bool:
    """
    判断条目是否为 arXiv 引用：journal = {arXiv e-prints}
    """
    return bool(re.search(r'journal\s*=\s*[{"]\s*arXiv\s+e-prints\s*["}]?', entry_text, re.IGNORECASE))


def validate_adsurl(entry_text: str) -> bool:
    """
    验证 adsurl 是否符合包含 abs 和 arxiv 的要求
    """
    return bool(re.search(r'adsurl\s*=\s*[{"]\s*https?://[^}]*abs[^}]*arxiv', entry_text, re.IGNORECASE))


def extract_bibcode(entry_text: str) -> str:
    """
    从 adsurl 中提取 bibcode
    """
    match = re.search(
        r'adsurl\s*=\s*[{"]\s*https?://ui\.adsabs\.harvard\.edu/abs/([^}"/\s]+)',
        entry_text,
        re.IGNORECASE
    )
    if not match:
        raise ValueError("未能从 adsurl 中提取 bibcode")
    return match.group(1)


def load_api_token(token_path: Path = Path("~/.ads_api_token").expanduser()) -> str:
    if not token_path.exists():
        raise RuntimeError("未找到 ~/.ads_api_token 文件。")
    with token_path.open("r", encoding="utf-8") as f:
        first_line = f.readline().strip()
    if not first_line:
        raise RuntimeError("~/.ads_api_token 文件为空。")
    return first_line


def fetch_updated_entry(bibcode: str, api_token: str) -> str:
    """
    调用 ADS Export API 获取更新后的 BibTeX
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
            f"ADS API 返回错误状态码 {response.status_code}: {response.text}"
        )
    data = response.json()
    updated_entry = data.get("export")
    if not updated_entry:
        raise RuntimeError("ADS API 返回中缺失 'export' 字段")
    return updated_entry


def replace_cite_key(entry_text: str, new_key: str) -> str:
    """
    将 BibTeX 条目的 cite key 替换为指定的 new_key
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
    if len(sys.argv) < 2:
        print("❌ 请提供输入 BibTeX 文件路径作为第一个参数", file=sys.stderr)
        sys.exit(1)

    input_bib_path = Path(sys.argv[1]).expanduser()
    if not input_bib_path.exists():
        print(f"❌ 输入文件不存在：{input_bib_path}", file=sys.stderr)
        sys.exit(1)
    try:
        api_token = load_api_token()
    except RuntimeError as exc:
        print(f"❌ {exc}请参考 https://github.com/adsabs/adsabs-dev-api?tab=readme-ov-file#access 添加 token。", file=sys.stderr)
        sys.exit(1)

    with input_bib_path.open("r", encoding="utf-8") as f:
        lines = f.readlines()

    entries = split_entries_with_lines(lines)
    updated_entries: List[str] = []
    updated_count = 0

    print(f"共发现 {len(entries)} 个 BibTeX 条目。开始检查 arXiv 条目...\n")

    for start_idx, end_idx, entry_lines in entries:
        entry_text = "".join(entry_lines)
        try:
            entry_type, cite_key = extract_cite_key(entry_text)
        except ValueError:
            print(f"[❗️ 警告] 第 {start_idx + 1} 行条目无法解析 cite key，已跳过。")
            updated_entries.append(entry_text)
            continue

        if not has_arxiv_journal(entry_text):
            # 非 arXiv，保持原样
            updated_entries.append(entry_text)
            continue

        print(f"[信息] 第 {start_idx + 1} 行：检测到 arXiv 条目 -> cite_key = {cite_key}")

        if not validate_adsurl(entry_text):
            print(f"  [❌ 错误] adsurl 字段未通过验证（需要包含 abs 与 arxiv），跳过：{cite_key}")
            updated_entries.append(entry_text)
            continue

        try:
            bibcode = extract_bibcode(entry_text)
        except ValueError as exc:
            print(f"  [❗️ 警告] {exc} -> 跳过：{cite_key}")
            updated_entries.append(entry_text)
            continue

        print(f"  [信息] 提取到 ADS bibcode: {bibcode}")

        try:
            updated_entry = fetch_updated_entry(bibcode, api_token)
        except Exception as exc:
            print(f"  [❌ 失败] ADS API 调用失败：{exc} -> 跳过：{cite_key}")
            updated_entries.append(entry_text)
            continue

        if has_arxiv_journal(updated_entry):
            print(f"  [🤪 信息] ADS 返回结果仍为 arXiv 条目，跳过：{cite_key}")
            updated_entries.append(entry_text)
            continue

        updated_entry = replace_cite_key(updated_entry, cite_key)
        if not updated_entry.endswith("\n"):
            updated_entry += "\n"
        updated_entries.append(updated_entry)
        updated_count += 1
        print(f"  [✅ 成功] 已更新 {cite_key}\n")

    output_path = input_bib_path.with_stem(input_bib_path.stem + "_updated")
    with output_path.open("w", encoding="utf-8") as f:
        f.write("".join(updated_entries))

    print(f"\n处理完成，共更新 {updated_count} 个 arXiv 条目。")
    print(f"更新后的 BibTeX 文件已写入：{output_path}")


if __name__ == "__main__":
    main()