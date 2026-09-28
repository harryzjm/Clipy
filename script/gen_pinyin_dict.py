#!/usr/bin/env python3
"""Regenerates Clipy/Resources/pinyin.txt, the character -> readings table WCDB's Pinyin
tokenizer indexes with (see PinyinDictionary.swift).

    python3 script/gen_pinyin_dict.py

Source: mozillazg/pinyin-data (MIT), built from Unihan plus corrections. Every reading a
character has is kept -- that is what makes polyphones searchable under each of them.

Output, one character per line: `重 zhong chong`. Readings are toneless ASCII, with ü spelled
`v` (the way it is typed), and in the source's order, so the most common reading comes first.
Only BMP characters are written: the tokenizer never indexes anything outside the BMP.

Standard library only.
"""

import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

TAG = 'v0.15.0'
SOURCE = f'https://raw.githubusercontent.com/mozillazg/pinyin-data/{TAG}/pinyin.txt'
OUTPUT = Path(__file__).resolve().parent.parent / 'Clipy' / 'Resources' / 'pinyin.txt'

# `U+4E2D: zhōng,zhòng  # 中`
LINE = re.compile(r'\AU\+([0-9A-F]+):\s*([^#]+?)\s*#')
READING = re.compile(r'\A[a-z]+\Z')
UMLAUT_TO_V = str.maketrans('üǖǘǚǜ', 'vvvvv')


def toneless(reading):
    decomposed = unicodedata.normalize('NFD', reading.translate(UMLAUT_TO_V))
    return ''.join(c for c in decomposed if unicodedata.category(c) != 'Mn').lower()


def main():
    try:
        with urllib.request.urlopen(SOURCE) as response:
            body = response.read().decode('utf-8')
    except OSError as error:
        sys.exit(f'fetching {SOURCE} failed: {error}')

    entries = []
    for line in body.splitlines():
        match = LINE.match(line)
        if not match:
            continue

        codepoint = int(match[1], 16)
        if codepoint > 0xFFFF:
            continue

        readings = []
        for reading in (toneless(r.strip()) for r in match[2].split(',')):
            if READING.match(reading) and reading not in readings:
                readings.append(reading)
        if not readings:
            continue

        entries.append((codepoint, f'{chr(codepoint)} {" ".join(readings)}'))

    entries.sort(key=lambda entry: entry[0])
    header = f'# generated from mozillazg/pinyin-data {TAG} (MIT) by script/gen_pinyin_dict.py'
    OUTPUT.write_text('\n'.join([header, *(text for _, text in entries)]) + '\n', encoding='utf-8')
    print(f'wrote {len(entries)} characters to {OUTPUT}')


if __name__ == '__main__':
    main()
