#!/usr/bin/env python3
"""Build and query a local Stata PDF documentation library.

Release this file alone. Python 3.10+ and PyMuPDF >= 1.24 are needed to
build; search, get, and verify use only the Python standard library.
PDF builds and retrieval are offline. Optional import-datasets fetches catalogue
HTML only; no dataset files, API key, model, or Stata process is used.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import platform
import re
import shutil
import sqlite3
import sys
import tempfile
import time
import unicodedata
from urllib.error import URLError
from urllib.parse import parse_qs, unquote, urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

VERSION = "1.2.0"
SCHEMA_VERSION = 1
TOOL = "stata-docs"
DEFAULT_OUTPUT = "Stata-Library"
DATA_INDEX = "https://www.stata-press.com/data/"
DATA_MARKER = "\n<!-- stata-docs:datasets -->\n"
SECTION_NAMES = {
    "Description", "Quick start", "Menu", "Syntax", "Options", "Option",
    "Remarks", "Remarks and examples", "Methods and formulas", "Stored results",
    "References", "Also see", "Acknowledgment", "Acknowledgments", "Conformability",
    "Diagnostics", "Source code", "Video example", "Video examples", "Technical note",
}
MONO_FONT = re.compile(r"mono|courier|cmtt|typewriter|consolas", re.I)
# Whole-block matches only. Unknown wording and notices in command entries stay.
PUBLICATION_HEADER = re.compile(
    r"(?:® )?Copyright © \d{4}[–-]\d{4} StataCorp LLC All rights reserved Version (\d+(?:\.\d+)?)")
PUBLICATION_NOTICES = {
    "Published by Stata Press, 4905 Lakeway Drive, College Station, Texas 77845",
    "This manual is protected by copyright. All rights are reserved. No part of this manual "
    "may be reproduced, stored in a retrieval system, or transcribed, in any form or by any "
    "means—electronic, mechanical, photocopy, recording, or otherwise—without the prior "
    "written permission of StataCorp LLC unless permitted subject to the terms and conditions "
    "of a license granted to you by StataCorp LLC to use the software and documentation. "
    "No license, express or implied, by estoppel or otherwise, to any intellectual property "
    "rights is granted by this document.",
    "StataCorp provides this manual “as is” without warranty of any kind, either expressed or "
    "implied, including, but not limited to, the implied warranties of merchantability and "
    "fitness for a particular purpose. StataCorp may make improvements and/or changes in the "
    "product(s) and the program(s) described in this manual at any time and without notice.",
    "The software described in this manual is furnished under a license agreement or "
    "nondisclosure agreement. The software may be copied only in accordance with the terms of "
    "the agreement. It is against the law to copy the software onto DVD, CD, disk, diskette, "
    "tape, or any other medium for any purpose other than backup or archival purposes.",
    "The automobile dataset appearing on the accompanying media is Copyright © 1979 by "
    "Consumers Union of U.S., Inc., Yonkers, NY 10703-1057 and is reproduced by permission "
    "from CONSUMER REPORTS, April 1979.",
    "Certain icons are licensed from Axialis SA. They remain the property of Axialis SA and "
    "may not be reproduced or distributed.",
    "Stata, , Stata Press, Mata, , NetCourse, and NetCourseNow are registered trademarks of StataCorp LLC.",
    "Stata and Stata Press are registered trademarks with the World Intellectual Property "
    "Organization of the United Nations.",
    "StataNow is a trademark of StataCorp LLC.",
    "Other brand and product names are registered trademarks or trademarks of their respective companies.",
    "For copyright information about the software, type `help copyright` within Stata.",
    "www.stata.com",
    "®",
}


def compact_publication_page(atoms, front_matter):
    """Trim recognized notices only on an identified front-matter publication page.

    Require both the publisher/version line and the full reproduction notice.
    Preserve headings, code, math, citations, release identifiers and unknown text.
    """
    def notice_text(atom):
        text = atom["text"]
        if atom["kind"] == "layout":
            match = re.fullmatch(r"(`{3,}|~{3,})text\n(.*)\n\1", text, re.S)
            if not match:
                return ""
            text = match[2]
        elif atom["kind"] != "paragraph":
            return ""
        return " ".join(text.split())

    texts = [notice_text(atom) for atom in atoms] if front_matter else []
    if not (any(PUBLICATION_HEADER.fullmatch(text) for text in texts)
            and any(text in PUBLICATION_NOTICES and text.startswith("This manual is protected")
                    for text in texts)):
        return atoms, 0, 0
    kept, blocks, characters = [], 0, 0
    for atom, text in zip(atoms, texts):
        header = PUBLICATION_HEADER.fullmatch(text)
        # Only this known extraction artifact is accepted, not arbitrary dehyphenation.
        known_text = text.replace("but not lim-ited to,", "but not limited to,")
        isbn = re.fullmatch(r"ISBN-10: [\dX-]+ ISBN-13: [\d-]+", text)
        if header:
            replacement = dict(atom, text="Version " + header[1])
            kept.append(replacement)
            blocks += 1
            characters += len(atom["text"]) - len(replacement["text"])
        elif known_text in PUBLICATION_NOTICES or isbn:
            blocks += 1
            characters += len(atom["text"])
        else:
            kept.append(atom)
    return kept, blocks, characters


def json_line(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
                    encoding="utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def text_hash(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def clean_text(text):
    # NFC preserves mathematical alphabets and code identifiers (NFKC does not).
    text = unicodedata.normalize("NFC", text)
    text = text.translate(str.maketrans({"ﬀ": "ff", "ﬁ": "fi", "ﬂ": "fl",
                                       "ﬃ": "ffi", "ﬄ": "ffl", "\u00ad": ""}))
    return "".join(c for c in text if c in "\n\t" or not unicodedata.category(c).startswith("C"))


def slug(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")[:100] or "entry"


def is_mono(span):
    # Stata's NewCMMono font incorrectly reports the proportional font flag.
    return bool(span.get("flags", 0) & 8 or MONO_FONT.search(span.get("font", "")))


def pdf_module():
    # The pymupdf module alias was introduced after PyMuPDF 1.24.0.
    try:
        import pymupdf
        return pymupdf
    except ImportError:
        try:
            import fitz
            if not hasattr(fitz, "VersionBind"):
                raise ImportError("Unrelated package named fitz")
            return fitz
        except ImportError:
            raise ValueError("Building requires PyMuPDF: python3 -m pip install 'PyMuPDF>=1.24'") from None


def local_outline(doc, pdf_path):
    """Walk local bookmark branches, including Stata's self-directed GoToR links.

    Stata manuals share 27,000+ cross-manual bookmarks. Avoid get_toc(), which
    visits them all and reports even the self-directed links as external.
    """
    names = doc.resolve_names()
    chapters = sorted({v["page"] for k, v in names.items()
                       if re.fullmatch(r"chapter\.\d+", k) and 0 <= v.get("page", -1) < doc.page_count})
    # PyMuPDF 1.27 may expose a null-outline sentinel whose .down segfaults.
    if doc.xref_get_key(doc.pdf_catalog(), "Outlines")[0] == "null":
        return [], chapters
    result = []

    def walk(node, depth=0):
        while node:
            uri = node.uri or ""
            parts = urlsplit(uri)
            target = unquote(parts.path).replace("\\", "/").split("/")[-1]
            local = not target or target.casefold() == pdf_path.name.casefold()
            if local:
                name = parse_qs(parts.fragment).get("nameddest", [None])[0]
                dest = names.get(name, {})
                page = dest.get("page", -1)
                if page < 0 and uri and not node.is_external:
                    page = doc.resolve_link(uri)[0]
                if isinstance(page, int) and 0 <= page < doc.page_count:
                    result.append({"title": clean_text(node.title or ""), "page": page,
                                   "depth": depth, "destination": name})
                if node.down:
                    walk(node.down, depth + 1)
            # The [GS] container points to Windows but includes Mac/Unix children.
            elif node.down and (node.title or "").startswith("[GS]"):
                walk(node.down, depth + 1)
            node = node.next

    walk(doc.outline)
    return result, chapters


def page_rows(page, fitz):
    """Rebuild rows from character geometry; recover vector-drawn underscores."""
    data = page.get_text("rawdict", flags=fitz.TEXTFLAGS_TEXT)
    lines = []
    controls = 0
    for block_id, block in enumerate(data["blocks"]):
        for line in block.get("lines", []):
            spans = []
            for source in line["spans"]:
                span = dict(source)
                chars = span.pop("chars", [])
                controls += sum(unicodedata.category(c["c"]).startswith("C") for c in chars)
                span["text"] = clean_text("".join(c["c"] for c in chars))
                span["chars"] = chars
                spans.append(span)
            if spans:
                lines.append({"spans": spans, "bbox": line["bbox"], "block": block_id,
                              "baseline": spans[0]["origin"][1]})
    strokes = []
    for drawing in page.get_cdrawings():
        if drawing.get("width", 0) > 1.2 or drawing.get("type") not in ("s", "fs"):
            continue
        for item in drawing["items"]:
            if item[0] == "l":
                a, b = item[1], item[2]
                if abs(a[1] - b[1]) < 0.15 and 2 <= abs(a[0] - b[0]) <= 12:
                    strokes.append((min(a[0], b[0]), max(a[0], b[0]), a[1]))
    recovered = 0
    for line in lines:
        mono = [s for s in line["spans"] if is_mono(s)]
        if not mono:
            continue
        for x0, x1, y in strokes:
            matches = [s for s in mono if abs(s["origin"][1] - y) <= 1.2
                       and s["bbox"][0] - s["size"] <= x0 <= s["bbox"][2] + s["size"]
                       and 0.35 * s["size"] <= x1 - x0 <= 0.85 * s["size"]]
            if not matches:
                continue
            occupied = any(c["c"].strip() and c["bbox"][0] < x1 - 0.5
                           and c["bbox"][2] > x0 + 0.5
                           for s in line["spans"] for c in s["chars"])
            if occupied:
                continue
            for s in line["spans"]:
                if not s["chars"]:
                    continue  # Retain underscores already recovered in this row.
                s["chars"] = [c for c in s["chars"] if not
                              (c["c"].isspace() and c["bbox"][0] < x1 and c["bbox"][2] > x0)]
                s["text"] = clean_text("".join(c["c"] for c in s["chars"]))
            template = matches[0]
            line["spans"].append({"text": "_", "font": template["font"],
                                  "size": template["size"], "flags": template["flags"],
                                  "bbox": (x0, y - template["size"], x1, y + 1),
                                  "origin": (x0, template["origin"][1]), "chars": []})
            recovered += 1
        # Character positions are needed because a space inside one span may
        # have become an underscore. Split at each recovered stroke before join.
        if any(s["text"] == "_" and not s["chars"] for s in line["spans"]):
            expanded = []
            for s in line["spans"]:
                if s["chars"]:
                    for char in s["chars"]:
                        expanded.append(dict(s, text=clean_text(char["c"]), bbox=char["bbox"], chars=[]))
                else:
                    expanded.append(s)
            line["spans"] = expanded

    # A table's columns often live in different PDF blocks on the same baseline.
    rows = []
    for line in sorted(lines, key=lambda l: (round(l["baseline"], 1), l["bbox"][0])):
        if rows and abs(rows[-1]["baseline"] - line["baseline"]) < 2:
            row = rows[-1]
            row["spans"].extend(line["spans"])
            row["blocks"].add(line["block"])
        else:
            rows.append({"spans": list(line["spans"]), "baseline": line["baseline"],
                         "blocks": {line["block"]}})
    for row in rows:
        row["spans"].sort(key=lambda s: (s["bbox"][0], s["bbox"][1]))
        row["spans"] = [s for s in row["spans"] if s["text"]]
        row["y"] = min((s["bbox"][1] for s in row["spans"]), default=0)
    return [r for r in rows if r["spans"]], controls, recovered


def code_quotes(text):
    return text.translate(str.maketrans({"‘": "`", "’": "'", "“": '"', "”": '"'}))


def inline_code(text):
    text = code_quotes(text)
    fence = "`" * max(1, max((len(m[0]) + 1 for m in re.finditer(r"`+", text)), default=1))
    pad = " " if text.startswith("`") or text.endswith("`") else ""
    return fence + pad + text + pad + fence


def row_text(row, layout=False, origin=None, inline=False):
    output = ""
    end = None
    unit = min(s["size"] for s in row["spans"]) * 0.52
    spans = row["spans"]
    if inline:
        # Merge adjacent monospace runs, including recovered underscore chars.
        spans = []
        for span in row["spans"]:
            if (spans and is_mono(span) and is_mono(spans[-1]) and
                    span["bbox"][0] - spans[-1]["bbox"][2] < 1):
                last = spans[-1]
                last["text"] += span["text"]
                last["bbox"] = (last["bbox"][0], last["bbox"][1], span["bbox"][2], last["bbox"][3])
            else:
                spans.append(dict(span))
    for span in spans:
        start = span["bbox"][0]
        text = span["text"]
        if end is None and layout and origin is not None:
            output += " " * max(0, round((start - origin) / unit))
        elif end is not None and start - end > 0.8:
            spaces = max(1, round((start - end) / unit)) if layout else 1
            if not output.endswith(" ") and not text.startswith(" "):
                output += " " * spaces
        if inline and is_mono(span) and text.strip():
            left = text[:len(text) - len(text.lstrip())]
            right = text[len(text.rstrip()):]
            text = left + inline_code(text.strip()) + right
        output += text
        end = max(span["bbox"][2], end or 0)
    return output.rstrip() if layout else output.strip()


def page_title(rows, fallback):
    top = [r for r in rows if r["y"] < 90]
    if not top:
        return fallback
    first = top[0]
    title = row_text(first)
    # Multi-line chapter titles and long reference-entry descriptions.
    if len(top) > 1 and top[1]["baseline"] - first["baseline"] < 18:
        if max(s["size"] for s in top[1]["spans"]) >= 10:
            title += " " + row_text(top[1])
    return title or fallback


def entry_starts(doc, outline, chapters, fitz):
    """Augment chapter destinations with bookmarks that match page title clusters.

    Some manuals use non-chapter destinations for early chapters or appendices.
    A continuation header's smaller font prevents section bookmarks on later
    pages from being mistaken for new entries.
    """
    starts = {0, *chapters}
    by_page = {}
    for bookmark in outline:
        by_page.setdefault(bookmark["page"], []).append(bookmark)
    normalize = lambda text: re.sub(r"[^\w]", "", text.casefold())
    for page_no, bookmarks in by_page.items():
        if page_no in starts:
            continue
        rows, _, _ = page_rows(doc[page_no], fitz)
        if not rows or rows[0]["y"] >= 90 or max(s["size"] for s in rows[0]["spans"]) < 10:
            continue
        title = normalize(page_title(rows, ""))
        if any(normalize(b["title"]) and title.startswith(normalize(b["title"])) for b in bookmarks):
            starts.add(page_no)
    if len(starts) == 1 and not chapters and outline:
        depth = min(b["depth"] for b in outline)
        starts.update(b["page"] for b in outline if b["depth"] == depth)
    return sorted(starts)


def fenced(text, language):
    tick_size = max(3, max((len(m[0]) + 1 for m in re.finditer(r"`+", text)), default=3))
    tilde_size = max(3, max((len(m[0]) + 1 for m in re.finditer(r"~+", text)), default=3))
    fence = "`" * tick_size if tick_size <= tilde_size else "~" * tilde_size
    return fence + language + "\n" + text + "\n" + fence


def render_page(rows, page, title, start_page, vocabulary=None):
    """Typography and geometry only: no individual-command/page overrides."""
    atoms = []
    group = []
    group_kind = None
    previous = None
    printed = page.get_label() or None

    def flush():
        nonlocal group, group_kind
        if not group:
            return
        if group_kind in ("code", "layout", "math"):
            origin = min(s["bbox"][0] for r in group for s in r["spans"])
            text = "\n".join(row_text(r, layout=True, origin=origin) for r in group)
            if group_kind == "code":
                text = code_quotes(text)
            atoms.append({"kind": group_kind, "text": fenced(text, "stata" if group_kind == "code" else "text")})
        else:
            text = ""
            for row in group:
                part = row_text(row, inline=True)
                match = re.search(r"([A-Za-z]{2,})-$", text)
                following = re.match(r"([a-z]{2,})", part)
                if match and following:
                    combined = (match[1] + following[1]).lower()
                    compound = (match[1] + "-" + following[1]).lower()
                    if vocabulary and combined in vocabulary and compound not in vocabulary:
                        text = text[:-1]
                    text += part
                else:
                    text += (" " if text else "") + part
            atoms.append({"kind": "paragraph", "text": text})
        group = []
        group_kind = None

    for row in rows:
        text = row_text(row)
        if not text:
            continue
        sizes = [s["size"] for s in row["spans"]]
        center = (row["spans"][0]["bbox"][0] + row["spans"][-1]["bbox"][2]) / 2
        if (row["y"] > page.rect.height * 0.9 and re.fullmatch(r"[\divxlc]+", text, re.I)
                and abs(center - page.rect.width / 2) < page.rect.width * 0.1
                and not any(is_mono(s) for s in row["spans"])):
            printed = printed or text
            continue
        if not start_page and row["y"] < 35 and max(sizes) < 10 and (
                "—" in text or re.search(r"\s\d+$", text)):
            continue
        # Remove the clickable mini-TOC, leaving the real section headings.
        if start_page and row["y"] < 150 and max(sizes) < 10 and all(
                s["text"].strip() in SECTION_NAMES or s["text"].strip().startswith("Syntax,")
                for s in row["spans"]):
            continue
        if start_page and row["y"] < 40 and text in title:
            continue
        total = sum(len(s["text"].strip()) for s in row["spans"]) or 1
        mono = sum(len(s["text"].strip()) for s in row["spans"] if is_mono(s)) / total
        bold = sum(len(s["text"].strip()) for s in row["spans"] if s["flags"] & 16) / total
        math = sum(len(s["text"].strip()) for s in row["spans"] if "math" in s["font"].lower()) / total
        roman = sum(len(re.sub(r"\W", "", s["text"])) for s in row["spans"]
                    if not is_mono(s) and not s["flags"] & 2 and "math" not in s["font"].lower()) / total
        gaps = [b["bbox"][0] - a["bbox"][2] for a, b in zip(row["spans"], row["spans"][1:])]
        heading = len(text) < 150 and mono < 0.2 and (
            (bold > 0.65 and max(sizes) >= 10) or (text in SECTION_NAMES and bold > 0.5))
        if heading:
            flush()
            atoms.append({"kind": "heading", "text": "## " + text, "section": text})
            previous = None
            continue
        if math > 0.4 and mono < 0.25:
            kind = "math"
        elif max(gaps, default=0) > 16:
            kind = "layout"
        elif mono > 0.75 or (mono > 0.05 and roman < 0.05):
            kind = "code"
        else:
            kind = "paragraph"
        gap = row["baseline"] - previous["baseline"] if previous else 999
        if (kind in ("paragraph", "code") and group_kind == "layout" and gap < 13 and
                min(s["bbox"][0] for s in row["spans"]) >
                min(s["bbox"][0] for r in group for s in r["spans"]) + 25):
            kind = "layout"  # Wrapped text in a table's right-hand column.
        same_block = bool(previous and row["blocks"] & previous["blocks"])
        if group_kind != kind or gap > 18 or (kind == "paragraph" and not same_block):
            flush()
        group_kind = kind
        group.append(row)
        previous = row
    flush()
    return atoms, printed


def split_atom(atom, limit):
    """Split oversized blocks with balanced fences and no dropped characters."""
    text = atom["text"]
    if len(text) <= limit:
        return [text]
    fenced_match = re.fullmatch(r"(`{3,}|~{3,})(\w*)\n(.*)\n\1", text, re.S)
    if fenced_match:
        _, language, text = fenced_match.groups()
        result = []
        while text:
            cut = min(limit - len(language) - 10, len(text))
            # Re-fence each piece independently. This guarantees progress even
            # when the source contains arbitrarily long runs of fence characters.
            while len(fenced(text[:cut], language)) > limit and cut > 1:
                cut //= 2
            if cut < 1:
                raise ValueError("Chunk size cannot accommodate a fenced passage")
            if cut < len(text):
                boundary = text.rfind("\n", 0, cut)
                if boundary > cut // 2:
                    cut = boundary + 1
            result.append(fenced(text[:cut], language))
            text = text[cut:]
        return result
    room = limit
    result = []
    while text:
        cut = min(room, len(text))
        if cut < len(text):
            boundary = text.rfind(" ", 0, cut)
            if boundary > room // 2:
                cut = boundary + 1
        result.append(text[:cut])
        text = text[cut:]
    return result


def convert_manual(task):
    fitz = pdf_module()

    source, relative, code, digest, stage_name, output_name, config = task
    source, stage, output = Path(source), Path(stage_name), Path(output_name)
    manual_dir = stage / code
    manual_dir.mkdir()
    (stage / "chunks").mkdir(exist_ok=True)
    entries = []
    warnings = {"empty_pages": [], "replacement_character_pages": [], "math_pages": [],
                "recovered_underscores": 0, "removed_control_characters": 0}
    cleanup = {"publication_blocks_trimmed": 0, "publication_characters_removed": 0,
               "publication_pages": []}
    with fitz.open(source) as doc:
        if doc.needs_pass:
            raise ValueError(f"{relative}: password-protected PDF")
        if not doc.page_count:
            raise ValueError(f"{relative}: PDF has no pages")
        outline, chapters = local_outline(doc, source)
        # LaTeX chapter destinations cover reference entries, guide chapters,
        # contents and appendices. Other PDF producers use local bookmarks.
        starts = entry_starts(doc, outline, chapters, fitz)
        # Corpus evidence for removing discretionary line-wrap hyphens: accept
        # a rejoined word only if it also appears unbroken in this same PDF.
        vocabulary = set()
        for page in doc:
            vocabulary.update(w.lower() for w in re.findall(r"[A-Za-z]{3,}(?:-[A-Za-z]{2,})?",
                                                           page.get_text(flags=fitz.TEXTFLAGS_TEXT)))
        manual = {"code": code, "title": clean_text(doc.metadata.get("title") or source.stem),
                  "pdf": relative, "pdf_sha256": digest, "pages": doc.page_count,
                  "source_metadata": doc.metadata, "entry_count": len(starts), "chunk_count": 0,
                  "warnings": warnings, "cleanup": cleanup, "artifacts": {}}
        used_slugs = {"readme"}  # Reserve the index on case-insensitive filesystems.
        chunk_path = stage / "chunks" / (code + ".jsonl")
        with chunk_path.open("w", encoding="utf-8") as chunks_file:
            for i, start in enumerate(starts):
                stop = starts[i + 1] if i + 1 < len(starts) else doc.page_count
                first_rows, _, _ = page_rows(doc[start], fitz)
                fallback = next((b["title"] for b in outline if b["page"] == start), f"Page {start + 1}")
                title = page_title(first_rows, fallback)
                name = re.split(r"\s+—\s+", title, maxsplit=1)[0]
                base = slug(name)
                key = base
                suffix = 2
                while key in used_slugs:
                    key = f"{base}-{suffix}"
                    suffix += 1
                used_slugs.add(key)
                entry_id = code + "/" + key
                md_path = code + "/" + key + ".md"
                entry = {"id": entry_id, "name": name, "title": title, "manual": code,
                         "manual_title": manual["title"], "path": md_path,
                         "pdf": relative, "pdf_sha256": digest, "page_start": start + 1,
                         "page_end": stop, "sections": [], "chunk_count": 0,
                         "destinations": sorted({b["destination"] for b in outline if b["page"] == start
                                                 and b["destination"]})}
                pdf_link = Path(os.path.relpath(source, output / code)).as_posix()
                # URL-encode path characters so PDF links also work with spaces.
                from urllib.parse import quote
                header = (f"# {title}\n\n> Manual: {manual['title']} | Entry: `{entry_id}`\n"
                          f"> Source: [{relative}, PDF pages {start + 1}–{stop}]"
                          f"({quote(pdf_link, safe='/.:')}#page={start + 1})\n\n")
                markdown = [header]
                section = "Overview"
                for page_no in range(start, stop):
                    page = doc[page_no]
                    rows, controls, recovered = page_rows(page, fitz)
                    warnings["removed_control_characters"] += controls
                    warnings["recovered_underscores"] += recovered
                    if not rows:
                        warnings["empty_pages"].append(page_no + 1)
                    if any("\ufffd" in s["text"] for r in rows for s in r["spans"]):
                        warnings["replacement_character_pages"].append(page_no + 1)
                    has_math = any("math" in s["font"].lower() for r in rows for s in r["spans"])
                    if has_math:
                        warnings["math_pages"].append(page_no + 1)
                    atoms, printed = render_page(rows, page, title, page_no == start, vocabulary)
                    if not config["keep_boilerplate"]:
                        atoms, trimmed, removed = compact_publication_page(atoms, front_matter=i == 0)
                        cleanup["publication_blocks_trimmed"] += trimmed
                        cleanup["publication_characters_removed"] += removed
                        if trimmed:
                            cleanup["publication_pages"].append(page_no + 1)
                    if not atoms:
                        atoms = [{"kind": "paragraph", "text": "[No extractable body text on this page; consult the source PDF.]"}]
                    buffer = []

                    def emit():
                        if not buffer:
                            return
                        text = "\n\n".join(buffer)
                        entry["chunk_count"] += 1
                        chunk = {"id": f"{entry_id}#{entry['chunk_count']:04d}",
                                 "entry_id": entry_id, "title": title, "manual": code,
                                 "section": section, "text": text, "pages": [page_no + 1],
                                 "page_labels": [printed], "pdf": relative,
                                 "pdf_sha256": digest, "markdown_path": md_path,
                                 "content_sha256": text_hash(text), "characters": len(text),
                                 "has_math": has_math, "extraction": "pdf-text-layer"}
                        chunks_file.write(json_line(chunk) + "\n")
                        buffer.clear()

                    for atom in atoms:
                        if atom["kind"] == "heading":
                            emit()
                            section = atom["section"]
                            if section not in entry["sections"]:
                                entry["sections"].append(section)
                        markdown.append(atom["text"] + "\n\n")
                        for part in split_atom(atom, config["chunk_chars"]):
                            if sum(map(len, buffer)) + 2 * len(buffer) + len(part) > config["chunk_chars"]:
                                emit()
                            buffer.append(part)
                    emit()
                text = "".join(markdown).rstrip() + "\n"
                (stage / md_path).write_text(text, encoding="utf-8")
                entry["sha256"] = text_hash(text)
                entries.append(entry)
                manual["chunk_count"] += entry["chunk_count"]
        manual_index = "# " + manual["title"] + "\n\n" + "\n".join(
            f"- [{e['title']}]({Path(e['path']).name}) — PDF pages {e['page_start']}–{e['page_end']}"
            for e in entries) + "\n"
        (manual_dir / "README.md").write_text(manual_index, encoding="utf-8")
    files = sorted(p for p in manual_dir.iterdir() if p.is_file()) + [chunk_path]
    manual["artifacts"] = {p.relative_to(stage).as_posix(): sha256(p) for p in files}
    return manual, entries


def read_jsonl(path):
    with path.open(encoding="utf-8") as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


class CatalogueHTML(HTMLParser):
    """Collect ordinary links with their nearest command/chapter heading."""

    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.links, self.heading, self.anchor, self.heading_parts = [], "", None, None
        self.feed(source)
        self.close()

    def handle_starttag(self, tag, attrs):
        if tag == "h3":
            self.heading_parts = []
        if tag == "a":
            href = dict(attrs).get("href")
            self.anchor = [href, []] if href else None

    def handle_data(self, data):
        if self.heading_parts is not None:
            self.heading_parts.append(data)
        if self.anchor is not None:
            self.anchor[1].append(data)

    def handle_endtag(self, tag):
        if tag == "h3" and self.heading_parts is not None:
            self.heading = " ".join(clean_text("".join(self.heading_parts)).split())
            self.heading_parts = None
        if tag == "a" and self.anchor is not None:
            href, parts = self.anchor
            self.links.append((href, " ".join(clean_text("".join(parts)).split()), self.heading))
            self.anchor = None


class RejectCatalogueRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Redirects would change source identity and can turn an HTML request
        # into a dataset request. Fail before issuing the redirected request.
        raise ValueError(f"Catalogue redirect rejected: {req.full_url} -> {newurl}")


# Keep a single transport hook so imports can be tested without any network.
urlopen = build_opener(RejectCatalogueRedirects()).open


def fetch_catalogue(url):
    """The only network operation: bounded reads of official catalogue HTML."""
    parts = urlsplit(url)
    if (parts.scheme != "https" or parts.netloc != "www.stata-press.com"
            or not parts.path.startswith("/data/") or parts.query or parts.fragment
            or not (parts.path.endswith("/") or parts.path.endswith(".html"))):
        raise ValueError(f"Not an official dataset catalogue HTML URL: {url}")
    try:
        request = Request(url, headers={"User-Agent": f"Stata-Docs/{VERSION}", "Accept": "text/html"})
        with urlopen(request, timeout=30) as response:
            if response.geturl() != url:
                raise ValueError(f"Catalogue source changed: {url} -> {response.geturl()}")
            if response.headers.get_content_type() not in {"text/html", "application/xhtml+xml"}:
                raise ValueError(f"Expected catalogue HTML: {url}")
            raw = response.read(8 * 1024 * 1024 + 1)
            if len(raw) > 8 * 1024 * 1024:
                raise ValueError(f"Catalogue HTML exceeds 8 MiB: {url}")
            source = raw.decode(response.headers.get_content_charset() or "utf-8")
    except (URLError, OSError, UnicodeError, LookupError) as error:
        raise ValueError(f"Could not import catalogue {url}: {error}") from None
    return CatalogueHTML(source), hashlib.sha256(raw).hexdigest()


def dataset_manuals(version, links, wanted):
    base = DATA_INDEX + f"r{version}/"
    manuals = {}
    for href, title, _ in links:
        url = urljoin(base, href)
        parts = urlsplit(url)
        match = re.fullmatch(rf"/data/r{version}/([a-z][a-z0-9_-]*)\.html", parts.path)
        if (parts.scheme == "https" and parts.netloc == "www.stata-press.com"
                and not parts.query and not parts.fragment and match):
            code = slug(match[1]).upper()
            if code == "README":
                raise ValueError("Dataset manual code README is reserved")
            if code in manuals and manuals[code]["catalogue_url"] != url:
                raise ValueError(f"Duplicate dataset manual identifier: {code}")
            manuals[code] = {"code": code, "title": title or code, "catalogue_url": url}
    if wanted:
        wanted = {code.upper() for code in wanted}
        missing = wanted - manuals.keys()
        if missing:
            raise ValueError("Dataset manuals not found: " + ", ".join(sorted(missing)))
        manuals = {code: manual for code, manual in manuals.items() if code in wanted}
    if not manuals:
        raise ValueError(f"No manual dataset catalogues found at {base}")
    return [manuals[code] for code in sorted(manuals)]


def dataset_records(version, manual, links):
    records, allocated = {}, set()
    for href, _, section in links:
        url = urljoin(manual["catalogue_url"], href)
        parts = urlsplit(url)
        if (parts.scheme not in {"http", "https"} or not parts.netloc
                or not parts.path.lower().endswith(".dta")):
            continue
        if url not in records:
            name = unquote(parts.path.rsplit("/", 1)[-1])
            stem, suffix = slug(name), 1
            identifier = stem
            while identifier in allocated:
                suffix += 1
                identifier = f"{stem}-{suffix}"
            allocated.add(identifier)
            records[url] = {
                "id": f"DATASETS/r{version}/{manual['code']}/{identifier}",
                "stata_version": version, "manual": manual["code"], "manual_title": manual["title"],
                "name": name, "url": url, "catalogue_url": manual["catalogue_url"],
                "catalogue_sha256": manual["catalogue_sha256"],
                "sections": [], "occurrences": 0, "use_command": f'use "{url}"',
            }
        record = records[url]
        record["occurrences"] += 1
        if section and section not in record["sections"]:
            record["sections"].append(section)
    return sorted(records.values(), key=lambda r: (r["name"].casefold(), r["url"]))


def write_dataset_catalogue(stage, version, manuals, records, catalogue_hash):
    relative = f"datasets/r{version}"
    directory = stage / relative
    directory.mkdir(parents=True)
    with (directory / "catalog.jsonl").open("w", encoding="utf-8") as stream:
        for record in records:
            stream.write(json_line(record) + "\n")
    with sqlite3.connect(directory / "search.sqlite") as conn:
        conn.executescript("""
            CREATE TABLE datasets(id TEXT PRIMARY KEY, manual TEXT, name TEXT, sections TEXT,
                                  manual_title TEXT, url TEXT, metadata TEXT);
            CREATE VIRTUAL TABLE search USING fts5(name, sections, manual_title, url,
                content='datasets', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2');
        """)
        conn.executemany("INSERT INTO datasets VALUES(?,?,?,?,?,?,?)", (
            (r["id"], r["manual"], r["name"], " | ".join(r["sections"]),
             r["manual_title"], r["url"], json_line(r)) for r in records))
        conn.execute("INSERT INTO search(search) VALUES('rebuild')")
        conn.execute("INSERT INTO search(search) VALUES('optimize')")
    catalogue_url = DATA_INDEX + f"r{version}/"
    intro = (f"# Stata {version} dataset catalogue\n\n"
             f"Source: <{catalogue_url}>. Imported link metadata only; dataset files were not downloaded.\n\n"
             "The version identifies the catalogue. Links can target other releases; keep their URLs as given. "
             "Names and example headings describe catalogue references, not dataset contents or variable schemas.\n\n"
             "Search offline with `python3 /path/to/stata_docs.py search-datasets 'auto' "
             f"-o /path/to/library --stata-version {version} --json`. "
             "catalog.jsonl contains complete records; search.sqlite is an independent FTS5 index.\n\n")
    lines = [intro, "## Manuals\n"]
    for manual in manuals:
        items = [r for r in records if r["manual"] == manual["code"]]
        manual["dataset_count"] = len(items)
        lines.append(f"- [{manual['title']}]({manual['code']}.md): {len(items)} dataset links.")
        # JSON quotes are also a readable way to retain punctuation in headings.
        text = [f"# {manual['title']} — dataset links\n", f"Catalogue: <{manual['catalogue_url']}>\n",
                "These are link records only. Inspect a dataset before making claims about its contents.\n"]
        for record in items:
            text.extend([f"## {record['name']}\n", f"ID: {record['id']}\n", f"URL: <{record['url']}>\n",
                         "Example sections: " + json.dumps(record["sections"], ensure_ascii=False) + "\n",
                         "```stata\n" + record["use_command"] + "\n```\n"])
        (directory / (manual["code"] + ".md")).write_text("\n".join(text), encoding="utf-8")
    (directory / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {"stata_version": version, "catalogue_url": catalogue_url, "catalogue_sha256": catalogue_hash,
            "importer_version": VERSION, "importer_sha256": sha256(Path(__file__)),
            "manuals": manuals, "datasets": len(records), "unique_urls": len({r["url"] for r in records}),
            "artifacts": {relative + "/" + name: digest for name, digest in output_inventory(directory).items()}}


def dataset_discovery(stage, catalogues):
    for name in ("llms.txt", "AGENTS.md"):
        path = stage / name
        base = path.read_text(encoding="utf-8").split(DATA_MARKER, 1)[0].rstrip() + "\n"
        if catalogues:
            lines = ["## Dataset catalogues", "", "Optional example-data link metadata, separate from PDF passages. "
                     "No dataset files are stored. The catalogue version can differ from a linked dataset's release.", "",
                     "Use `search-datasets 'auto' -o /path/to/library --json` for offline lookup; "
                     "the default selects the newest imported catalogue.", ""]
            lines.extend(f"- [Stata {c['stata_version']} dataset catalogue](datasets/r{c['stata_version']}/README.md): "
                         f"{c['datasets']} manual/dataset records." for c in sorted(
                             catalogues, key=lambda c: c["stata_version"], reverse=True))
            base += DATA_MARKER + "\n".join(lines) + "\n"
        path.write_text(base, encoding="utf-8")


def preserve_datasets(output, stage, previous):
    catalogues = previous.get("dataset_catalogues", []) if previous else []
    for catalogue in catalogues:
        for name, digest in catalogue["artifacts"].items():
            path = output / name
            if not path.is_file() or sha256(path) != digest:
                raise ValueError(f"Missing or modified dataset artifact: {name}")
            dest = stage / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
    return catalogues


def publish_library(stage, output, previous):
    backup = None
    if output.exists():
        owned_output(output, previous)
        backup = Path(tempfile.mkdtemp(prefix="." + output.name + ".previous-", dir=output.parent))
        backup.rmdir()
        output.rename(backup)
    try:
        stage.rename(output)
    except BaseException:
        if backup:
            backup.rename(output)
        raise
    if backup:
        shutil.rmtree(backup)


def import_datasets(args):
    output = Path(args.output).expanduser().absolute()
    if output.is_symlink():
        raise ValueError("Output must not be a symlink")
    output = output.resolve()
    if not (output / "manifest.json").is_file():
        raise ValueError("Build a local PDF library before importing dataset catalogues")
    lock = output.parent / ("." + output.name + ".lock")
    try:
        lock_fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ValueError(f"Another build or import holds {lock}. If its process has exited, remove this lock.") from None
    stage = None
    try:
        with os.fdopen(lock_fd, "w") as stream:
            stream.write(str(os.getpid()))
        previous = load_manifest(output)
        owned_output(output, previous)
        verify_library(output)
        version = args.stata_version
        if version == "latest":
            index, _ = fetch_catalogue(DATA_INDEX)
            versions = {int(match[1]) for href, _, _ in index.links
                        if (url := urlsplit(urljoin(DATA_INDEX, href))).netloc == "www.stata-press.com"
                        and (match := re.fullmatch(r"/data/r(\d+)/", url.path)) and int(match[1]) >= 8}
            if not versions:
                raise ValueError(f"No Stata releases found at {DATA_INDEX}")
            version = max(versions)
        catalogue, digest = fetch_catalogue(DATA_INDEX + f"r{version}/")
        manuals = dataset_manuals(version, catalogue.links, args.manual)
        records = []
        with ThreadPoolExecutor(max_workers=min(args.workers, len(manuals))) as pool:
            results = list(pool.map(fetch_catalogue, [m["catalogue_url"] for m in manuals]))
        for manual, (page, page_hash) in zip(manuals, results):
            manual["catalogue_sha256"] = page_hash
            records.extend(dataset_records(version, manual, page.links))
        if not records:
            raise ValueError(f"No .dta dataset links found in the selected Stata {version} catalogues")
        stage = Path(tempfile.mkdtemp(prefix="." + output.name + ".build-", dir=output.parent))
        shutil.copytree(output, stage, dirs_exist_ok=True)
        directory = stage / "datasets" / f"r{version}"
        if directory.exists():
            shutil.rmtree(directory)
        imported = write_dataset_catalogue(stage, version, manuals, records, digest)
        catalogues = [c for c in previous.get("dataset_catalogues", []) if c["stata_version"] != version]
        catalogues.append(imported)
        manifest = dict(previous, dataset_catalogues=sorted(catalogues, key=lambda c: c["stata_version"]))
        dataset_discovery(stage, catalogues)
        manifest["artifacts"] = output_inventory(stage)
        write_json(stage / "manifest.json", manifest)
        verify_library(stage)
        publish_library(stage, output, previous)
        print(json_line({"output": str(output), "stata_version": version, "manuals": len(manuals),
                         "datasets": len(records), "unique_urls": imported["unique_urls"],
                         "dataset_files_downloaded": 0}))
    finally:
        if stage is not None and stage.exists():
            shutil.rmtree(stage)
        lock.unlink(missing_ok=True)


def search_datasets(args):
    root = Path(args.output).expanduser()
    manifest = load_manifest(root)
    catalogues = manifest.get("dataset_catalogues", [])
    if not catalogues:
        raise ValueError("No dataset catalogues imported; run import-datasets explicitly first")
    version = max(c["stata_version"] for c in catalogues) if args.stata_version == "latest" else args.stata_version
    if not any(c["stata_version"] == version for c in catalogues):
        raise ValueError(f"Stata {version} dataset catalogue has not been imported")
    match = literal_match(args.query)
    results = []
    if match:
        uri = (root / "datasets" / f"r{version}" / "search.sqlite").resolve().as_uri() + "?mode=ro"
        with sqlite3.connect(uri, uri=True) as conn:
            query = ("SELECT d.metadata, bm25(search, 8.0, 4.0, 1.0, 0.5) FROM search "
                     "JOIN datasets d ON d.rowid=search.rowid WHERE search MATCH ?")
            params = [match]
            if args.manual:
                query += " AND d.manual=?"
                params.append(args.manual.upper())
            query += " ORDER BY bm25(search, 8.0, 4.0, 1.0, 0.5), d.id LIMIT ?"
            params.append(args.limit)
            results = [dict(json.loads(meta), score=round(score, 8)) for meta, score in conn.execute(query, params)]
    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        for hit in results:
            print(f"{hit['id']} | {hit['name']} | catalogue Stata {hit['stata_version']} [{hit['manual']}]")
            print(hit["url"])
            print("Example sections: " + "; ".join(hit["sections"]))
            print(hit["use_command"] + "\n")
        if not results:
            print("No matches.")


def make_database(stage, entries, manuals):
    with sqlite3.connect(stage / "library.sqlite") as conn:
        conn.executescript("""
            CREATE TABLE entries(id TEXT PRIMARY KEY, manual TEXT, title TEXT, metadata TEXT);
            CREATE TABLE chunks(id TEXT PRIMARY KEY, entry_id TEXT REFERENCES entries(id),
                                manual TEXT, title TEXT, section TEXT, text TEXT, metadata TEXT);
            CREATE INDEX chunks_entry ON chunks(entry_id);
            CREATE VIRTUAL TABLE search USING fts5(title, section, text,
                content='chunks', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2');
        """)
        conn.executemany("INSERT INTO entries VALUES(?,?,?,?)", (
            (e["id"], e["manual"], e["title"], json_line(e)) for e in entries))
        for manual in manuals:
            conn.executemany("INSERT INTO chunks VALUES(?,?,?,?,?,?,?)", (
                (c["id"], c["entry_id"], c["manual"], c["title"], c["section"], c["text"], json_line(c))
                for c in read_jsonl(stage / "chunks" / (manual["code"] + ".jsonl"))))
        conn.execute("INSERT INTO search(search) VALUES('rebuild')")
        conn.execute("INSERT INTO search(search) VALUES('optimize')")


def output_inventory(root):
    return {p.relative_to(root).as_posix(): sha256(p)
            for p in sorted(root.rglob("*")) if p.is_file() and p.name != "manifest.json"}


def load_manifest(root):
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("tool") != TOOL or manifest.get("schema_version") != SCHEMA_VERSION:
        raise ValueError(f"{root}: unsupported library manifest")
    for name in manifest["artifacts"]:
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or path.as_posix() != name:
            raise ValueError(f"Invalid artifact path: {name}")
    for manual in manifest["manuals"]:
        path = Path(manual["pdf"])
        if path.is_absolute() or ".." in path.parts or slug(manual["code"]).upper() != manual["code"]:
            raise ValueError("Invalid source path or manual identifier")
    versions = set()
    for catalogue in manifest.get("dataset_catalogues", []):
        version = catalogue["stata_version"]
        if type(version) is not int or version < 8 or version in versions:
            raise ValueError("Invalid or duplicate dataset catalogue version")
        versions.add(version)
        base = f"datasets/r{version}/"
        if catalogue["catalogue_url"] != DATA_INDEX + f"r{version}/":
            raise ValueError("Invalid dataset catalogue source")
        codes = [m["code"] for m in catalogue["manuals"]]
        if (len(set(codes)) != len(codes) or any(
                not re.fullmatch(r"[A-Z][A-Z0-9-]*", code) or code == "README" for code in codes)):
            raise ValueError("Invalid dataset manual identifiers")
        expected = {base + name for name in ["README.md", "catalog.jsonl", "search.sqlite"]}
        expected.update(base + code + ".md" for code in codes)
        if set(catalogue["artifacts"]) != expected or any(
                manifest["artifacts"].get(name) != digest for name, digest in catalogue["artifacts"].items()):
            raise ValueError("Inconsistent dataset artifact inventory")
    return manifest


def owned_output(root, manifest):
    expected = set(manifest["artifacts"]) | {"manifest.json"}
    for path in root.rglob("*"):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink() or (path.is_file() and relative not in expected):
            raise ValueError(f"Refusing to replace library containing an untracked file or symlink: {path}")


def build(args):
    pymupdf = pdf_module()
    if tuple(map(int, pymupdf.VersionBind.split(".")[:2])) < (1, 24):
        raise ValueError("Building requires PyMuPDF >= 1.24")
    source = Path(args.input).expanduser().resolve()
    output = Path(args.output).expanduser().absolute()
    if output.is_symlink():
        raise ValueError("Output must not be a symlink")
    output = output.resolve()
    if not source.exists():
        raise ValueError(f"Input does not exist: {source}")
    pdfs = [source] if source.is_file() and source.suffix.lower() == ".pdf" else (
        sorted(p for p in source.rglob("*") if p.is_file() and p.suffix.lower() == ".pdf") if source.is_dir() else [])
    if args.manual:
        wanted = {v.casefold() for v in args.manual}
        pdfs = [p for p in pdfs if p.stem.casefold() in wanted]
        missing = wanted - {p.stem.casefold() for p in pdfs}
        if missing:
            raise ValueError("Requested manuals not found: " + ", ".join(sorted(missing)))
    if not pdfs:
        raise ValueError("No PDF files found")
    input_root = source if source.is_dir() else source.parent
    if output == input_root or output in input_root.parents or any(output in p.parents for p in pdfs):
        raise ValueError("Output must be separate from the input PDFs")
    codes = [slug(p.stem).upper() for p in pdfs]
    if len(set(codes)) != len(codes):
        raise ValueError("PDF filenames must produce distinct manual identifiers")
    if set(codes) & {"CHUNKS", "DATASETS"}:
        raise ValueError("The PDF stems 'chunks' and 'datasets' are reserved for retrieval output directories")
    config = {"chunk_chars": args.chunk_chars, "keep_boilerplate": args.keep_boilerplate}
    fingerprint = {"script_sha256": sha256(Path(__file__)), "pymupdf": pymupdf.VersionBind,
                   "python": platform.python_version(),
                   "config": config}
    previous = None
    if output.exists():
        previous = load_manifest(output)
        owned_output(output, previous)
    output.parent.mkdir(parents=True, exist_ok=True)
    lock = output.parent / ("." + output.name + ".lock")
    try:
        lock_fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ValueError(f"Another build holds {lock}. If its process has exited, remove this lock.") from None
    started = time.monotonic()
    stage = None
    try:
        with os.fdopen(lock_fd, "w") as stream:
            stream.write(str(os.getpid()))
        stage = Path(tempfile.mkdtemp(prefix="." + output.name + ".build-", dir=output.parent))
        (stage / "chunks").mkdir()
        tasks, manuals, entries = [], [], []
        old_manuals = {m["code"]: m for m in previous["manuals"]} if previous else {}
        catalog_ok = bool(previous and (output / "catalog.jsonl").is_file() and
                          sha256(output / "catalog.jsonl") == previous["artifacts"].get("catalog.jsonl"))
        old_entries = list(read_jsonl(output / "catalog.jsonl")) if catalog_ok else []
        reused = 0
        for pdf, code in zip(pdfs, codes):
            digest = sha256(pdf)
            old = old_manuals.get(code)
            relative = pdf.relative_to(input_root).as_posix()
            reusable = (not args.force and previous and catalog_ok and previous["build"] == fingerprint and old
                        and old["pdf_sha256"] == digest and old["pdf"] == relative
                        and previous["source_directory"] == Path(os.path.relpath(input_root, output)).as_posix())
            if reusable:
                reusable = all((output / p).is_file() and sha256(output / p) == d for p, d in old["artifacts"].items())
            if reusable:
                for p in old["artifacts"]:
                    dest = stage / p
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(output / p, dest)
                manuals.append(old)
                entries.extend(e for e in old_entries if e["manual"] == code)
                reused += 1
                print(f"Reused [{code}] {old['entry_count']} entries", file=sys.stderr, flush=True)
            else:
                tasks.append((str(pdf), relative, code, digest, str(stage), str(output), config))
        if not tasks and len(manuals) == len(previous["manuals"]):
            # Preserve all artifacts and mtimes on a fully unchanged build.
            # A modified global index is repaired by the normal assembly below.
            try:
                verify_library(output, input_root)
            except (ValueError, OSError, sqlite3.Error):
                pass
            else:
                print(json_line({"output": str(output), **previous["summary"],
                                 "manuals_reused": reused, "seconds": round(time.monotonic() - started, 2)}))
                return
        if args.workers == 1:
            results = map(convert_manual, tasks)
            for manual, items in results:
                manuals.append(manual)
                entries.extend(items)
                print(f"Built [{manual['code']}] {manual['pages']} pages, {len(items)} entries", file=sys.stderr, flush=True)
        elif tasks:
            with ProcessPoolExecutor(max_workers=min(args.workers, len(tasks))) as pool:
                futures = [pool.submit(convert_manual, task) for task in tasks]
                for future in as_completed(futures):
                    manual, items = future.result()
                    manuals.append(manual)
                    entries.extend(items)
                    print(f"Built [{manual['code']}] {manual['pages']} pages, {len(items)} entries", file=sys.stderr, flush=True)
        manuals.sort(key=lambda m: m["code"])
        entries.sort(key=lambda e: (e["manual"], e["page_start"], e["id"]))
        with (stage / "catalog.jsonl").open("w", encoding="utf-8") as stream:
            for entry in entries:
                stream.write(json_line(entry) + "\n")
        make_database(stage, entries, manuals)
        llms = ["# Local Stata documentation", "",
                "> Extracted from the user's local PDFs. Consult the cited PDF page for equations and figures.", "",
                "Start with AGENTS.md for retrieval instructions. catalog.jsonl lists entries;",
                "chunks/*.jsonl contains bounded passages and provenance. library.sqlite supports offline FTS5 search.", "",
                "## Manuals", ""]
        llms.extend(f"- [{m['title']}]({m['code']}/README.md): {m['entry_count']} entries; {m['pages']} PDF pages."
                    for m in manuals)
        if any(m["cleanup"]["publication_blocks_trimmed"] for m in manuals):
            llms.extend(["", "Original Stata documentation © StataCorp LLC. Full publication notices remain in the source PDFs."])
        (stage / "llms.txt").write_text("\n".join(llms) + "\n", encoding="utf-8")
        (stage / "AGENTS.md").write_text(
            "# Using this local Stata reference library\n\n"
            "Read llms.txt, then the relevant manual's README.md or catalog.jsonl. Read only the entries and sections needed. "
            "Avoid loading the entire corpus into context.\n\n"
            "Use the standalone script: `python3 /path/to/stata_docs.py search 'syntax varlist' -o /path/to/library --manual P --json --compact`. "
            "Search terms are literal words combined with AND. Results contain the complete matching chunk and provenance. "
            "Use `get 'P/syntax' --section 'Syntax' -o /path/to/library` for a focused section. "
            "Add `--json --compact` to get citation metadata without hashes and build bookkeeping. "
            "Compact JSON is minified. Compact search results have text and a citations list; identical text is returned once "
            "with every citation among the selected hits. --limit caps hits before grouping. "
            "Compact entry/section get stores shared manual, title, and PDF metadata in entry; chunks inherit those fields. "
            "Entry IDs are listed in catalog.jsonl; chunk IDs are listed in chunks/*.jsonl.\n\n"
            "Cite the manual, entry, printed page when known, and 1-based PDF page. Source locations are relative to "
            "manifest.json's source_directory. PDF hashes identify the source revision; content hashes identify passages. "
            "Exact pages and hashes are in passage metadata; Markdown omits repeated page comments and hashes. "
            "Check the PDF for equations, diagrams, ambiguous layout, or source glyphs. Text extraction is not mathematical validation. "
            "Do not infer a Stata version from this tool's version: inspect each manual's source_metadata and content.\n",
            encoding="utf-8")
        summary = {"manuals": len(manuals), "pages": sum(m["pages"] for m in manuals),
                   "entries": len(entries), "chunks": sum(m["chunk_count"] for m in manuals)}
        catalogues = preserve_datasets(output, stage, previous)
        if catalogues:
            dataset_discovery(stage, catalogues)
        manifest = {"tool": TOOL, "version": VERSION, "schema_version": SCHEMA_VERSION,
                    "build": fingerprint, "source_directory": Path(os.path.relpath(input_root, output)).as_posix(),
                    "summary": summary, "manuals": manuals, "artifacts": output_inventory(stage)}
        if catalogues:
            manifest["dataset_catalogues"] = catalogues
        write_json(stage / "manifest.json", manifest)
        # Check the staged product before making it visible to readers.
        verify_library(stage, input_root)
        publish_library(stage, output, previous)
        print(json_line({"output": str(output), **summary, "manuals_reused": reused,
                         "seconds": round(time.monotonic() - started, 2)}))
    finally:
        if stage is not None and stage.exists():
            shutil.rmtree(stage)
        lock.unlink(missing_ok=True)


def open_database(root):
    load_manifest(root)
    return sqlite3.connect((root / "library.sqlite").resolve().as_uri() + "?mode=ro", uri=True)


def literal_match(query):
    # Never interpolate FTS syntax from an assistant/user's query. Punctuation
    # in Stata commands (prefixes, macro quotes, function parentheses) is normal.
    words = re.findall(r"[^\W_]+", query, flags=re.UNICODE)
    return " AND ".join('"' + w.replace('"', '""') + '"' for w in words)


def compact_chunk(chunk, *, shared_source=False):
    """LLM-facing fields; full provenance remains in the stored record."""
    keys = ("id", "section", "text", "pages", "page_labels", "has_math") if shared_source else (
        "id", "manual", "title", "section", "text", "pdf", "pages", "page_labels", "has_math")
    return {key: chunk[key] for key in keys}


def compact_search_results(hits):
    """Group exact text within the selected hits, preserving all citations and rank."""
    by_text = {}
    for hit in hits:
        citation = compact_chunk(hit)
        text = citation.pop("text")
        if text not in by_text:
            by_text[text] = {"text": text, "citations": []}
        by_text[text]["citations"].append(citation)
    return list(by_text.values())


def retrieval_json(value, compact):
    """Minify compact responses without changing text or ordinary JSON formatting."""
    if compact:
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return json.dumps(value, ensure_ascii=False, indent=2)


def search(args):
    match = literal_match(args.query)
    if not match:
        # Empty/punctuation-only queries are valid, with no matching passages.
        load_manifest(Path(args.output))
        print("[]" if args.json else "No matches. Enter a word or command name.")
        return
    with open_database(Path(args.output)) as conn:
        query = ("SELECT c.metadata, bm25(search, 8.0, 4.0, 1.0) FROM search "
                 "JOIN chunks c ON c.rowid=search.rowid WHERE search MATCH ?")
        params = [match]
        if args.manual:
            query += " AND c.manual=?"
            params.append(args.manual.upper())
        query += " ORDER BY bm25(search, 8.0, 4.0, 1.0), c.id LIMIT ?"
        params.append(args.limit)
        results = [dict(json.loads(metadata), score=round(score, 8)) for metadata, score in conn.execute(query, params)]
    if args.json:
        if args.compact:
            results = compact_search_results(results)
        print(retrieval_json(results, args.compact))
    else:
        for hit in results:
            print(f"{hit['id']} | {hit['title']} | {hit['section']} | PDF page {hit['pages'][0]}")
            print(hit["text"] + "\n")
        if not results:
            print("No matches. Try fewer terms or omit --manual.")


def get(args):
    root = Path(args.output)
    with open_database(root) as conn:
        entry = conn.execute("SELECT metadata FROM entries WHERE id=?", (args.entry_id,)).fetchone()
        if not entry:
            chunk = conn.execute("SELECT metadata FROM chunks WHERE id=?", (args.entry_id,)).fetchone()
            if not chunk:
                raise ValueError(f"Unknown entry or chunk: {args.entry_id}")
            value = json.loads(chunk[0])
            if args.compact:
                value = compact_chunk(value)
            print(retrieval_json(value, args.compact) if args.json else value["text"])
            return
        meta = json.loads(entry[0])
        if args.section or args.json:
            rows = conn.execute("SELECT metadata FROM chunks WHERE entry_id=? ORDER BY rowid", (args.entry_id,))
            chunks = [json.loads(r[0]) for r in rows]
            if args.section:
                chunks = [c for c in chunks if args.section.casefold() in c["section"].casefold()]
                if not chunks:
                    raise ValueError(f"Section not found. Available: {', '.join(meta['sections'])}")
            if args.compact:
                meta = {key: meta[key] for key in ("id", "title", "manual", "pdf", "page_start", "page_end")}
                chunks = [compact_chunk(chunk, shared_source=True) for chunk in chunks]
            print(retrieval_json({"entry": meta, "chunks": chunks}, args.compact)
                  if args.json else "\n\n".join(c["text"] for c in chunks))
        else:
            print((root / meta["path"]).read_text(encoding="utf-8"), end="")


def verify_datasets(root, catalogues):
    for catalogue in catalogues:
        version = catalogue["stata_version"]
        directory = root / "datasets" / f"r{version}"
        records = list(read_jsonl(directory / "catalog.jsonl"))
        manuals = {m["code"]: m for m in catalogue["manuals"]}
        ids, counts = set(), {code: 0 for code in manuals}
        for record in records:
            manual = manuals.get(record["manual"])
            parts = urlsplit(record["url"])
            if (not manual or record["id"] in ids
                    or not record["id"].startswith(f"DATASETS/r{version}/{record['manual']}/")
                    or record["stata_version"] != version
                    or record["manual_title"] != manual["title"]
                    or record["catalogue_url"] != manual["catalogue_url"]
                    or record["catalogue_sha256"] != manual["catalogue_sha256"]
                    or parts.scheme not in {"http", "https"} or not parts.netloc
                    or not parts.path.lower().endswith(".dta")
                    or record["name"] != unquote(parts.path.rsplit("/", 1)[-1])
                    or record["use_command"] != f'use "{record["url"]}"'
                    or type(record["occurrences"]) is not int or record["occurrences"] < 1
                    or not isinstance(record["sections"], list)
                    or not all(isinstance(s, str) for s in record["sections"])):
                raise ValueError(f"Inconsistent dataset record: {record['id']}")
            ids.add(record["id"])
            counts[record["manual"]] += 1
        if (len(records) != catalogue["datasets"]
                or len({r["url"] for r in records}) != catalogue["unique_urls"]
                or any(counts[m["code"]] != m["dataset_count"] for m in manuals.values())):
            raise ValueError(f"Dataset catalogue totals mismatch: Stata {version}")
        uri = (directory / "search.sqlite").resolve().as_uri() + "?mode=ro"
        with sqlite3.connect(uri, uri=True) as conn:
            if conn.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise ValueError(f"Dataset SQLite integrity check failed: Stata {version}")
            expected = {(r["id"], r["manual"], r["name"], " | ".join(r["sections"]),
                         r["manual_title"], r["url"], json_line(r)) for r in records}
            actual = set(conn.execute("SELECT id, manual, name, sections, manual_title, url, metadata FROM datasets"))
            if actual != expected:
                raise ValueError(f"Dataset SQLite records mismatch: Stata {version}")


def verify_library(root, sources=None):
    manifest = load_manifest(root)
    for name, digest in manifest["artifacts"].items():
        path = root / name
        if not path.is_file() or sha256(path) != digest:
            raise ValueError(f"Missing or modified artifact: {name}")
    entries = list(read_jsonl(root / "catalog.jsonl"))
    ids = {e["id"] for e in entries}
    if len(ids) != len(entries):
        raise ValueError("Duplicate entry identifiers")
    chunk_count = 0
    entry_map = {e["id"]: e for e in entries}
    seen_chunks = set()
    for manual in manifest["manuals"]:
        items = [e for e in entries if e["manual"] == manual["code"]]
        if len(items) != manual["entry_count"]:
            raise ValueError(f"Entry total mismatch: {manual['code']}")
        cursor = 1
        for entry in items:
            if (not entry["path"].startswith(manual["code"] + "/")
                    or manifest["artifacts"].get(entry["path"]) != entry["sha256"]
                    or entry["pdf"] != manual["pdf"] or entry["pdf_sha256"] != manual["pdf_sha256"]):
                raise ValueError(f"Inconsistent entry provenance: {entry['id']}")
            if entry["page_start"] != cursor or entry["page_end"] < cursor:
                raise ValueError(f"Gap or overlapping page coverage: {entry['id']}")
            cursor = entry["page_end"] + 1
        if cursor != manual["pages"] + 1:
            raise ValueError(f"Incomplete page coverage: {manual['code']}")
        count = 0
        covered_pages = set()
        entry_counts = {}
        for chunk in read_jsonl(root / "chunks" / (manual["code"] + ".jsonl")):
            if chunk["entry_id"] not in ids or text_hash(chunk["text"]) != chunk["content_sha256"]:
                raise ValueError(f"Invalid chunk: {chunk['id']}")
            entry = entry_map[chunk["entry_id"]]
            if (chunk["id"] in seen_chunks or not chunk["id"].startswith(entry["id"] + "#")
                    or chunk["manual"] != manual["code"] or entry["manual"] != manual["code"]
                    or chunk["markdown_path"] != entry["path"]
                    or chunk["pdf"] != manual["pdf"] or chunk["pdf_sha256"] != manual["pdf_sha256"]
                    or chunk["characters"] != len(chunk["text"])
                    or len(chunk["pages"]) != 1 or len(chunk["page_labels"]) != 1
                    or not entry["page_start"] <= chunk["pages"][0] <= entry["page_end"]):
                raise ValueError(f"Inconsistent chunk provenance: {chunk['id']}")
            seen_chunks.add(chunk["id"])
            covered_pages.update(chunk["pages"])
            entry_counts[entry["id"]] = entry_counts.get(entry["id"], 0) + 1
            if len(chunk["text"]) > manifest["build"]["config"]["chunk_chars"]:
                raise ValueError(f"Oversized chunk: {chunk['id']}")
            count += 1
        if count != manual["chunk_count"]:
            raise ValueError(f"Chunk total mismatch: {manual['code']}")
        if covered_pages != set(range(1, manual["pages"] + 1)):
            raise ValueError(f"Incomplete passage page coverage: {manual['code']}")
        if any(entry_counts.get(e["id"], 0) != e["chunk_count"] for e in items):
            raise ValueError(f"Entry passage count mismatch: {manual['code']}")
        chunk_count += count
        if sources is not None:
            path = sources / manual["pdf"]
            if not path.is_file() or sha256(path) != manual["pdf_sha256"]:
                raise ValueError(f"Missing or modified source PDF: {manual['pdf']}")
    with open_database(root) as conn:
        if conn.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("SQLite integrity check failed")
        if conn.execute("SELECT count(*) FROM chunks").fetchone()[0] != chunk_count:
            raise ValueError("SQLite chunk count mismatch")
        if conn.execute("SELECT count(*) FROM entries").fetchone()[0] != len(entries):
            raise ValueError("SQLite entry count mismatch")
    totals = {"manuals": len(manifest["manuals"]), "entries": len(entries), "chunks": chunk_count,
              "pages": sum(m["pages"] for m in manifest["manuals"])}
    if totals != manifest["summary"]:
        raise ValueError("Library summary totals do not match its contents")
    verify_datasets(root, manifest.get("dataset_catalogues", []))
    return manifest["summary"]


def positive_integer(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def stata_version(value):
    if value.lower() == "latest":
        return "latest"
    try:
        number = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError("must be 'latest' or a Stata release number, e.g. 19") from None
    if number < 8:
        raise argparse.ArgumentTypeError("dataset catalogues start at Stata 8")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", action="version", version=f"{TOOL} {VERSION}")
    commands = parser.add_subparsers(dest="command", required=True)
    build_parser = commands.add_parser("build", help="Build or incrementally refresh a library from PDFs")
    build_parser.add_argument("input", nargs="?", default="PDFs", help="PDF file or directory (searched recursively)")
    build_parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT)
    build_parser.add_argument("--workers", type=positive_integer, default=min(4, os.cpu_count() or 1))
    build_parser.add_argument("--chunk-chars", type=positive_integer, default=6000, help="Maximum characters per retrieval passage (minimum 256)")
    build_parser.add_argument("--manual", action="append", help="Include this PDF stem; repeat to select several")
    build_parser.add_argument("--force", action="store_true", help="Re-extract unchanged PDFs")
    build_parser.add_argument("--keep-boilerplate", action="store_true",
                              help="Retain recognized front-matter publication notices (default: trim)")
    build_parser.set_defaults(run=build)
    search_parser = commands.add_parser("search", help="Search passages offline with literal terms")
    search_parser.add_argument("query")
    search_parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT)
    search_parser.add_argument("--manual", help="Limit to a manual code, e.g. P")
    search_parser.add_argument("--limit", type=positive_integer, default=5,
                               help="Maximum matching passages before compact grouping (default: 5)")
    search_parser.add_argument("--json", action="store_true", help="Return full passages and provenance as JSON")
    search_parser.add_argument("--compact", action="store_true",
                               help="With --json, minify, omit bookkeeping, and group exact text with citations")
    search_parser.set_defaults(run=search)
    get_parser = commands.add_parser("get", help="Read an entry, section, or individual chunk")
    get_parser.add_argument("entry_id")
    get_parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT)
    get_parser.add_argument("--section", help="Case-insensitive section substring")
    get_parser.add_argument("--json", action="store_true")
    get_parser.add_argument("--compact", action="store_true",
                            help="With --json, minify, omit bookkeeping, and share entry source metadata")
    get_parser.set_defaults(run=get)
    import_parser = commands.add_parser("import-datasets", help="Explicitly import example-data catalogue HTML; no datasets downloaded")
    import_parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT, help="Existing local PDF library")
    import_parser.add_argument("--stata-version", type=stata_version, default="latest",
                               help="Catalogue release, e.g. 19; default: latest published catalogue")
    import_parser.add_argument("--manual", action="append", help="Dataset manual code, e.g. P; repeat to select several")
    import_parser.add_argument("--workers", type=positive_integer, default=4)
    import_parser.set_defaults(run=import_datasets)
    datasets_parser = commands.add_parser("search-datasets", help="Search explicitly imported dataset link metadata offline")
    datasets_parser.add_argument("query")
    datasets_parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT)
    datasets_parser.add_argument("--stata-version", type=stata_version, default="latest",
                                 help="Catalogue release; default: newest imported catalogue (offline)")
    datasets_parser.add_argument("--manual", help="Limit to a dataset manual code, e.g. P")
    datasets_parser.add_argument("--limit", type=positive_integer, default=5)
    datasets_parser.add_argument("--json", action="store_true")
    datasets_parser.set_defaults(run=search_datasets)
    verify_parser = commands.add_parser("verify", help="Verify hashes, coverage, chunks, and database")
    verify_parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT)
    verify_parser.add_argument("--sources", help="Also verify the PDFs in this source directory")
    verify_parser.set_defaults(run=lambda args: print(json_line({"verified": True, **verify_library(
        Path(args.output), Path(args.sources).resolve() if args.sources else None)})))
    args = parser.parse_args(argv)
    if args.command == "build" and args.chunk_chars < 256:
        parser.error("--chunk-chars must be at least 256")
    if getattr(args, "compact", False) and not args.json:
        parser.error("--compact requires --json")
    try:
        args.run(args)
    except (ValueError, OSError, sqlite3.Error, KeyError, json.JSONDecodeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
