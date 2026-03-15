#!/usr/bin/env python3
"""logdoc_render.py - Convert Stata SMCL/log files to HTML or Markdown.

Parses SMCL files into semantic blocks (commands, tables, output, errors),
expands tags, and renders to self-contained HTML or Markdown documents.

Usage:
    python3 logdoc_render.py input.smcl output.html [options]
    python3 logdoc_render.py input.log output.md --format md

Options:
    --format html|md|both    Output format (default: html)
    --theme light|dark       CSS theme (default: light)
    --title "Title"          Document title
    --preformatted           Keep tables as monospace (skip HTML table conversion)
    --nofold                 Disable collapsible sections
    --css PATH               Custom CSS file path
    --light-css PATH         Path to light theme CSS
    --dark-css PATH          Path to dark theme CSS

No external dependencies — uses only the Python standard library.
"""

import argparse
import base64
import datetime
import html as html_mod
import mimetypes
import os
import re
import sys


# ---------------------------------------------------------------------------
# Embedded CSS themes (used when external .css files not found)
# ---------------------------------------------------------------------------
CSS_LIGHT = """\
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #ffffff; color: #212529;
  font-family: "Source Sans Pro", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 16px; line-height: 1.6; -webkit-font-smoothing: antialiased; }
.logdoc { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; }
.logdoc-header { margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 2px solid #dee2e6; }
.logdoc-header h1 { font-size: 1.75rem; font-weight: 600; color: #212529; margin: 0; }
.code-block { margin: 1rem 0 0.25rem 0; padding: 0.75rem 1rem; background: #f8f9fa;
  border-left: 3px solid #4582ec; border-radius: 0 4px 4px 0; overflow-x: auto; }
.code-block pre { margin: 0; font-family: "JetBrains Mono", "Fira Code", "SFMono-Regular",
  Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.875rem; line-height: 1.5;
  white-space: pre; color: #212529; }
.output-block { margin: 0 0 1rem 0; padding: 0.5rem 1rem; overflow-x: auto; }
.output-block pre { margin: 0; font-family: "JetBrains Mono", "Fira Code", "SFMono-Regular",
  Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.8125rem; line-height: 1.45;
  white-space: pre; color: #495057; }
.comment-block { margin: 0.5rem 0; padding: 0.25rem 1rem; color: #6c757d;
  font-style: italic; font-size: 0.875rem; }
.error-block { margin: 0.5rem 0 1rem 0; padding: 0.75rem 1rem; background: #fff5f5;
  border-left: 3px solid #e74c3c; border-radius: 0 4px 4px 0; overflow-x: auto; }
.error-block pre { margin: 0; font-family: "JetBrains Mono", "Fira Code", "SFMono-Regular",
  Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.8125rem; line-height: 1.45;
  white-space: pre; color: #c0392b; }
.table-block { margin: 0.5rem 0 1.5rem 0; overflow-x: auto; }
table.stata-table { border-collapse: collapse; font-family: "JetBrains Mono", "Fira Code",
  "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.8125rem;
  color: #212529; width: 100%; }
table.stata-table th, table.stata-table td { padding: 0.35rem 0.75rem; text-align: left;
  vertical-align: top; border-bottom: 1px solid #dee2e6; }
table.stata-table th { font-weight: 600; color: #495057; border-bottom: 2px solid #adb5bd;
  white-space: nowrap; }
table.stata-table tbody tr:hover { background: #f8f9fa; }
table.stata-table td.numeric { text-align: right; font-variant-numeric: tabular-nums; }
.fold-block { margin: 0 0 1rem 0; border: 1px solid #e9ecef; border-radius: 4px; }
.fold-block summary { padding: 0.5rem 1rem; cursor: pointer; font-size: 0.8125rem;
  color: #6c757d; background: #f8f9fa; border-radius: 4px; user-select: none; }
.fold-block summary:hover { background: #e9ecef; }
.fold-block[open] summary { border-bottom: 1px solid #e9ecef; border-radius: 4px 4px 0 0; }
.fold-block .output-block { margin: 0; }
.graph-figure { margin: 1rem 0 1.5rem 0; text-align: center; }
.graph-figure img { max-width: 100%; height: auto; border: 1px solid #dee2e6; border-radius: 4px; }
.graph-missing { margin: 0.5rem 0; padding: 0.75rem 1rem; background: #fff3cd;
  border-left: 3px solid #ffc107; border-radius: 0 4px 4px 0; color: #856404; font-size: 0.875rem; }
.cmd { color: #212529; font-weight: 600; }
.res { color: #212529; }
.err { color: #c0392b; }
.help-link { color: #4582ec; text-decoration: none; }
.help-link:hover { text-decoration: underline; }
.logdoc-header .subtitle { font-size: 0.9375rem; color: #6c757d; margin-top: 0.25rem; }
.logdoc-footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid #dee2e6;
  font-size: 0.75rem; color: #adb5bd; text-align: center; }
.code-block { position: relative; }
.copy-btn { position: absolute; top: 0.4rem; right: 0.5rem; padding: 0.15rem 0.5rem;
  font-size: 0.7rem; border: 1px solid #dee2e6; border-radius: 3px; background: #fff;
  color: #6c757d; cursor: pointer; opacity: 0; transition: opacity 0.15s; }
.code-block:hover .copy-btn { opacity: 1; }
.copy-btn:hover { background: #e9ecef; }
@media (max-width: 768px) { .logdoc { padding: 1rem; } .logdoc-header h1 { font-size: 1.25rem; } }
@media print { body { font-size: 11pt; } .logdoc { max-width: 100%; padding: 0; }
  .code-block { break-inside: avoid; border-left-color: #999; }
  .table-block { break-inside: avoid; } .copy-btn { display: none; }
  .fold-block { border: none; } .fold-block > * { display: block !important; }
  .fold-block summary { display: none; } .logdoc-footer { color: #999; } }
"""

CSS_DARK = """\
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #1e1e2e; color: #cdd6f4;
  font-family: "Source Sans Pro", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 16px; line-height: 1.6; -webkit-font-smoothing: antialiased; }
.logdoc { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; }
.logdoc-header { margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 2px solid #45475a; }
.logdoc-header h1 { font-size: 1.75rem; font-weight: 600; color: #cdd6f4; margin: 0; }
.code-block { margin: 1rem 0 0.25rem 0; padding: 0.75rem 1rem; background: #313244;
  border-left: 3px solid #89b4fa; border-radius: 0 4px 4px 0; overflow-x: auto; }
.code-block pre { margin: 0; font-family: "JetBrains Mono", "Fira Code", "SFMono-Regular",
  Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.875rem; line-height: 1.5;
  white-space: pre; color: #cdd6f4; }
.output-block { margin: 0 0 1rem 0; padding: 0.5rem 1rem; overflow-x: auto; }
.output-block pre { margin: 0; font-family: "JetBrains Mono", "Fira Code", "SFMono-Regular",
  Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.8125rem; line-height: 1.45;
  white-space: pre; color: #a6adc8; }
.comment-block { margin: 0.5rem 0; padding: 0.25rem 1rem; color: #6c7086;
  font-style: italic; font-size: 0.875rem; }
.error-block { margin: 0.5rem 0 1rem 0; padding: 0.75rem 1rem; background: #302028;
  border-left: 3px solid #f38ba8; border-radius: 0 4px 4px 0; overflow-x: auto; }
.error-block pre { margin: 0; font-family: "JetBrains Mono", "Fira Code", "SFMono-Regular",
  Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.8125rem; line-height: 1.45;
  white-space: pre; color: #f38ba8; }
.table-block { margin: 0.5rem 0 1.5rem 0; overflow-x: auto; }
table.stata-table { border-collapse: collapse; font-family: "JetBrains Mono", "Fira Code",
  "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.8125rem;
  color: #cdd6f4; width: 100%; }
table.stata-table th, table.stata-table td { padding: 0.35rem 0.75rem; text-align: left;
  vertical-align: top; border-bottom: 1px solid #45475a; }
table.stata-table th { font-weight: 600; color: #bac2de; border-bottom: 2px solid #585b70;
  white-space: nowrap; }
table.stata-table tbody tr:hover { background: #313244; }
table.stata-table td.numeric { text-align: right; font-variant-numeric: tabular-nums; }
.fold-block { margin: 0 0 1rem 0; border: 1px solid #45475a; border-radius: 4px; }
.fold-block summary { padding: 0.5rem 1rem; cursor: pointer; font-size: 0.8125rem;
  color: #6c7086; background: #313244; border-radius: 4px; user-select: none; }
.fold-block summary:hover { background: #45475a; }
.fold-block[open] summary { border-bottom: 1px solid #45475a; border-radius: 4px 4px 0 0; }
.fold-block .output-block { margin: 0; }
.graph-figure { margin: 1rem 0 1.5rem 0; text-align: center; }
.graph-figure img { max-width: 100%; height: auto; border: 1px solid #45475a; border-radius: 4px; }
.graph-missing { margin: 0.5rem 0; padding: 0.75rem 1rem; background: #3a3520;
  border-left: 3px solid #f9e2af; border-radius: 0 4px 4px 0; color: #f9e2af; font-size: 0.875rem; }
.cmd { color: #89b4fa; font-weight: 600; }
.res { color: #cdd6f4; }
.err { color: #f38ba8; }
.help-link { color: #89dceb; text-decoration: none; }
.help-link:hover { text-decoration: underline; }
.logdoc-header .subtitle { font-size: 0.9375rem; color: #6c7086; margin-top: 0.25rem; }
.logdoc-footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid #45475a;
  font-size: 0.75rem; color: #585b70; text-align: center; }
.code-block { position: relative; }
.copy-btn { position: absolute; top: 0.4rem; right: 0.5rem; padding: 0.15rem 0.5rem;
  font-size: 0.7rem; border: 1px solid #585b70; border-radius: 3px; background: #45475a;
  color: #a6adc8; cursor: pointer; opacity: 0; transition: opacity 0.15s; }
.code-block:hover .copy-btn { opacity: 1; }
.copy-btn:hover { background: #585b70; }
@media (max-width: 768px) { .logdoc { padding: 1rem; } .logdoc-header h1 { font-size: 1.25rem; } }
@media print { body { background: #fff; color: #212529; font-size: 11pt; }
  .logdoc { max-width: 100%; padding: 0; }
  .code-block { break-inside: avoid; background: #f8f9fa; border-left-color: #999; }
  .code-block pre, .output-block pre { color: #212529; }
  .table-block { break-inside: avoid; } .copy-btn { display: none; }
  .fold-block { border: none; } .fold-block > * { display: block !important; }
  .fold-block summary { display: none; } .logdoc-footer { color: #999; } }
"""


# ---------------------------------------------------------------------------
# SMCL box-drawing character map
# ---------------------------------------------------------------------------
SMCL_CHAR_MAP = {
    "{c TLC}": "┌", "{c TRC}": "┐", "{c BLC}": "└", "{c BRC}": "┘",
    "{c TT}": "┬", "{c BT}": "┴", "{c LT}": "├", "{c RT}": "┤",
    "{c +}": "┼", "{c |}": "│", "{c -}": "─",
    "{c S|}": "§", "{c 0xa3}": "£", "{c 0xb1}": "±",
    "{c 0xb2}": "²", "{c 0xb3}": "³", "{c 0xb7}": "·",
    "{c 0xd7}": "×", "{c 0xf7}": "÷",
}


# ---------------------------------------------------------------------------
# Stage 2: Semantic SMCL Parser — classify raw lines into blocks
# ---------------------------------------------------------------------------

class Block:
    """A semantic block of SMCL content."""
    __slots__ = ("kind", "lines", "raw_lines")

    def __init__(self, kind, lines=None, raw_lines=None):
        self.kind = kind            # command, table, error, graph_ref, output
        self.lines = lines or []    # expanded text lines
        self.raw_lines = raw_lines or []  # original SMCL lines


def classify_raw_line(line):
    """Return the semantic type of a raw SMCL line."""
    stripped = line.strip()
    if not stripped:
        return "blank"
    # Command lines: {com}. or plain ". command" (Stata prompt)
    if re.search(r'\{com\}\.\s', stripped) or stripped.startswith("{com}. "):
        return "command"
    if re.search(r'\{com\}>\s', stripped) or stripped.startswith("{com}> "):
        return "continuation"
    if stripped == "{com}.":
        return "command_blank"
    # Plain dot-prompt lines (common when {com} is on a preceding line)
    # Match ". command" where command starts with a letter, *, or //
    clean = re.sub(r'\{[^}]*\}', '', stripped).strip()
    if re.match(r'\.\s+[a-zA-Z*/_]', clean):
        return "command"
    if re.match(r'>\s+[a-zA-Z*/_]', clean):
        return "continuation"
    if clean == ".":
        return "command_blank"
    # Table boundary markers
    if "{c TT}" in stripped:
        return "table_top"
    if "{c BT}" in stripped:
        return "table_bottom"
    # Error lines
    if "{err}" in stripped or "{error}" in stripped:
        return "error"
    return "output"


def parse_blocks(raw_lines):
    """Parse raw SMCL lines into semantic blocks."""
    blocks = []
    i = 0
    n = len(raw_lines)

    while i < n:
        line = raw_lines[i]
        ltype = classify_raw_line(line)

        # Skip log open/close metadata
        if _is_log_metadata(line):
            i = _skip_log_metadata(raw_lines, i)
            continue

        # Skip {smcl}, {.-}, {sf}, {ul off} structural markers
        stripped = line.strip()
        if stripped in ("{smcl}", "{.-}", "") or \
           re.match(r'^\{txt\}\{sf\}\{ul off\}(\{.-\})?$', stripped):
            i += 1
            continue

        if ltype == "command" or ltype == "continuation":
            # Extract clean command text to check for log commands
            cmd_clean = re.sub(r'\{[^}]*\}', '', line).strip()
            if re.match(r'\.\s*log\s+(close|using|open)', cmd_clean):
                # Skip log open/close commands and their metadata
                i += 1
                while i < n and _is_log_metadata(raw_lines[i]):
                    i += 1
                if i < n and raw_lines[i].strip() == "":
                    i += 1
                continue

            block = Block("command")
            # Gather the command and any continuation lines
            block.raw_lines.append(line)
            i += 1
            while i < n:
                ntype = classify_raw_line(raw_lines[i])
                if ntype == "continuation":
                    block.raw_lines.append(raw_lines[i])
                    i += 1
                else:
                    break
            blocks.append(block)
            continue

        if ltype == "command_blank":
            # Empty command prompt — skip
            i += 1
            continue

        if ltype == "table_top":
            block = Block("table")
            block.raw_lines.append(line)
            i += 1
            # Gather until table_bottom
            while i < n:
                block.raw_lines.append(raw_lines[i])
                if classify_raw_line(raw_lines[i]) == "table_bottom":
                    i += 1
                    break
                i += 1
            else:
                i = min(i, n)
            blocks.append(block)
            continue

        if ltype == "error":
            block = Block("error")
            block.raw_lines.append(line)
            i += 1
            # Gather consecutive error lines
            while i < n and classify_raw_line(raw_lines[i]) == "error":
                block.raw_lines.append(raw_lines[i])
                i += 1
            blocks.append(block)
            continue

        # Default: output block — gather consecutive output/blank lines
        block = Block("output")
        block.raw_lines.append(line)
        i += 1
        while i < n:
            ntype = classify_raw_line(raw_lines[i])
            if ntype in ("output", "blank"):
                block.raw_lines.append(raw_lines[i])
                i += 1
            else:
                break
        blocks.append(block)

    return blocks


def _is_log_metadata(line):
    """Check if line is part of log open/close metadata."""
    stripped = line.strip()
    # Remove leading SMCL tags
    clean = re.sub(r'\{[^}]*\}', '', stripped).strip()
    return bool(re.match(r'(name|log|log type|opened on|closed on):\s+', clean))


def _skip_log_metadata(lines, start):
    """Skip a log metadata block starting at `start`."""
    i = start
    while i < len(lines):
        if _is_log_metadata(lines[i]):
            i += 1
            continue
        stripped = lines[i].strip()
        clean = re.sub(r'\{[^}]*\}', '', stripped).strip()
        if clean == "":
            i += 1
            break
        break
    return i


# ---------------------------------------------------------------------------
# Stage 3: SMCL Tag Expansion
# ---------------------------------------------------------------------------

def _find_matching_brace(line, start):
    """Find the closing } that matches the { at position start, handling nesting."""
    depth = 0
    i = start
    while i < len(line):
        if line[i] == '{':
            depth += 1
        elif line[i] == '}':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def expand_smcl_line(line, mode="text"):
    """Expand SMCL tags in a single line.

    mode="text": strip all tags to plain text (for Markdown)
    mode="html": convert style tags to HTML spans
    """
    result = []
    col = 0
    i = 0
    current_style = None

    while i < len(line):
        if line[i] == '{':
            j = _find_matching_brace(line, i)
            if j == -1:
                ch = html_mod.escape(line[i]) if mode == "html" else line[i]
                result.append(ch)
                col += 1
                i += 1
                continue
            tag_full = line[i:j+1]
            tag_inner = line[i+1:j]
            i = j + 1

            # {col N} — pad to column N (1-based)
            m = re.match(r'col\s+(\d+)', tag_inner)
            if m:
                target = int(m.group(1)) - 1
                spaces = max(1, target - col)
                result.append(' ' * spaces)
                col += spaces
                continue

            # {hline N} / {hline}
            m = re.match(r'hline\s+(\d+)', tag_inner)
            if m:
                n = int(m.group(1))
                ch = '─' * n
                result.append(ch)
                col += n
                continue
            if tag_inner == 'hline':
                ch = '─' * 60
                result.append(ch)
                col += 60
                continue

            # {space N}
            m = re.match(r'space\s+(\d+)', tag_inner)
            if m:
                n = int(m.group(1))
                result.append(' ' * n)
                col += n
                continue

            # Box-drawing characters {c XX}
            if tag_full in SMCL_CHAR_MAP:
                ch = SMCL_CHAR_MAP[tag_full]
                result.append(ch)
                col += 1
                continue

            # {bf:text} → bold (recursively expand inner content)
            m = re.match(r'bf:(.+)', tag_inner)
            if m:
                inner = expand_smcl_line(m.group(1), mode)
                plain = re.sub(r'<[^>]+>', '', inner)
                if mode == "html":
                    result.append(f'<strong>{inner}</strong>')
                else:
                    result.append(f'**{inner}**')
                col += len(plain)
                continue

            # {it:text} → italic (recursively expand inner content)
            m = re.match(r'it:(.+)', tag_inner)
            if m:
                inner = expand_smcl_line(m.group(1), mode)
                plain = re.sub(r'<[^>]+>', '', inner)
                if mode == "html":
                    result.append(f'<em>{inner}</em>')
                else:
                    result.append(f'*{inner}*')
                col += len(plain)
                continue

            # {result:text} — inline result coloring (recursively expand)
            m = re.match(r'result:(.+)', tag_inner)
            if m:
                inner = expand_smcl_line(m.group(1), mode)
                plain = re.sub(r'<[^>]+>', '', inner)
                if mode == "html":
                    result.append(f'<span class="res">{inner}</span>')
                else:
                    result.append(inner)
                col += len(plain)
                continue

            # {res:text} — same as result:text (recursively expand)
            m = re.match(r'res:(.+)', tag_inner)
            if m:
                inner = expand_smcl_line(m.group(1), mode)
                plain = re.sub(r'<[^>]+>', '', inner)
                if mode == "html":
                    result.append(f'<span class="res">{inner}</span>')
                else:
                    result.append(inner)
                col += len(plain)
                continue

            # {lalign N:text}, {ralign N:text}, {center N:text}
            m = re.match(r'(?:[lr]align|center)\s+\d+:(.+)', tag_inner)
            if m:
                inner = expand_smcl_line(m.group(1), mode)
                plain = re.sub(r'<[^>]+>', '', inner)
                result.append(inner)
                col += len(plain)
                continue

            # {help topic##|_new:text} → link
            m = re.match(r'help\s+(\S+?)(?:##\|_new)?(?::(.+))?', tag_inner)
            if m:
                topic = m.group(1)
                display_text = m.group(2) or topic
                if mode == "html":
                    url = f"https://www.stata.com/help.cgi?{topic}"
                    result.append(
                        f'<a href="{url}" class="help-link">'
                        f'{html_mod.escape(display_text)}</a>'
                    )
                else:
                    result.append(display_text)
                col += len(display_text)
                continue

            # {helpb topic} → bold help link
            m = re.match(r'helpb\s+(\S+)', tag_inner)
            if m:
                topic = m.group(1)
                if mode == "html":
                    url = f"https://www.stata.com/help.cgi?{topic}"
                    result.append(
                        f'<a href="{url}" class="help-link">'
                        f'<strong>{html_mod.escape(topic)}</strong></a>'
                    )
                else:
                    result.append(f'**{topic}**')
                col += len(topic)
                continue

            # Style markers: {com}, {res}, {txt}, {err}
            if mode == "html":
                if tag_inner in ("com", "cmd"):
                    if current_style:
                        result.append('</span>')
                    result.append('<span class="cmd">')
                    current_style = "cmd"
                    continue
                elif tag_inner == "res":
                    if current_style:
                        result.append('</span>')
                    result.append('<span class="res">')
                    current_style = "res"
                    continue
                elif tag_inner == "err" or tag_inner == "error":
                    if current_style:
                        result.append('</span>')
                    result.append('<span class="err">')
                    current_style = "err"
                    continue
                elif tag_inner == "txt":
                    if current_style:
                        result.append('</span>')
                    current_style = None
                    continue

            # All other tags — silently skip
            # ({smcl}, {sf}, {ul off}, {p_end}, {.-}, {p}, etc.)
            continue
        else:
            ch = line[i]
            if mode == "html":
                ch = html_mod.escape(ch)
            result.append(ch)
            col += 1
            i += 1

    # Close any open style span
    if mode == "html" and current_style:
        result.append('</span>')

    return ''.join(result)


def _visible_len(line):
    """Length of a line excluding HTML tags."""
    return len(re.sub(r'<[^>]+>', '', line))


_SEP_CHARS = set("─┬┼┴│├┤┌┐└┘┘")


def _is_separator_line(line):
    """Check if a line is a box-drawing separator (only ─ and connectors)."""
    text = re.sub(r'<[^>]+>', '', line).strip()
    return bool(text) and all(ch in _SEP_CHARS for ch in text)


def _pad_separator_lines(lines):
    """Pad separator lines with ─ to match the widest line in the block."""
    if not lines:
        return lines

    max_width = max(_visible_len(l) for l in lines)

    result = []
    for line in lines:
        if _is_separator_line(line):
            vis_len = _visible_len(line)
            if vis_len < max_width:
                # Extend with ─ at the end (before trailing whitespace)
                stripped = line.rstrip()
                line = stripped + '─' * (max_width - vis_len)
        result.append(line)
    return result


def expand_block(block, mode="text"):
    """Expand all raw_lines in a block, set block.lines."""
    block.lines = [expand_smcl_line(l, mode) for l in block.raw_lines]
    # Pad separator lines to match the widest data line
    block.lines = _pad_separator_lines(block.lines)


def extract_command_text(line, strip_dots=False):
    """Extract the command text from a raw SMCL command line."""
    # Remove {com}. prefix
    text = re.sub(r'\{com\}\.\s*', '', line.strip())
    # Remove {com}> prefix for continuations
    text = re.sub(r'\{com\}>\s*', '', text)
    # Strip remaining tags
    text = re.sub(r'\{[^}]*\}', '', text)
    # Remove trailing ///
    text = re.sub(r'\s*///\s*$', '', text)
    text = text.strip()
    if strip_dots:
        # Remove leading ". " or "> " prompt
        text = re.sub(r'^[.>]\s*', '', text)
    return text


# ---------------------------------------------------------------------------
# Stage 4: Table Parser — box-drawing tables to HTML
# ---------------------------------------------------------------------------

def parse_table_block(block):
    """Parse a table block's expanded lines into header + body rows.

    Returns (headers, rows) where each is a list of cell strings,
    or None if the table can't be parsed into clean rows.
    """
    lines = block.lines
    if not lines:
        return None

    # Find separator lines (contain ┬, ┼, ┴)
    sep_indices = []
    for idx, line in enumerate(lines):
        if '┬' in line or '┼' in line or '┴' in line:
            sep_indices.append(idx)

    if len(sep_indices) < 2:
        return None

    # Determine column boundaries from the first separator line
    sep_line = lines[sep_indices[0]]
    col_positions = [m.start() for m in re.finditer(r'[┬┼┴]', sep_line)]

    if not col_positions:
        return None

    # Estimation tables (regress, margins, etc.) have only 1 pipe column —
    # variable name on left, all coefficients crammed in one right cell.
    # These render much better as preformatted monospace, so skip HTML conversion.
    if len(col_positions) == 1:
        return None

    def split_at_pipes(line):
        """Split a line into cells using │ as delimiter."""
        # Find the position of the first │
        parts = line.split('│')
        return [p.strip() for p in parts]

    # Collect header rows (between first and second separator)
    header_lines = []
    for idx in range(sep_indices[0] + 1, sep_indices[1]):
        if idx < len(lines):
            header_lines.append(lines[idx])

    # Collect body rows (between second and last separator)
    body_lines = []
    for idx in range(sep_indices[1] + 1, sep_indices[-1]):
        if idx < len(lines):
            # Skip internal separator lines
            if '┼' not in lines[idx] and '┬' not in lines[idx]:
                body_lines.append(lines[idx])

    headers = [split_at_pipes(l) for l in header_lines]
    rows = [split_at_pipes(l) for l in body_lines]

    return headers, rows


def table_to_html(block):
    """Convert a parsed table block to an HTML table string."""
    parsed = parse_table_block(block)
    if parsed is None:
        return None

    headers, rows = parsed

    html_parts = ['<table class="stata-table">']

    # Header
    if headers:
        html_parts.append('<thead>')
        for hrow in headers:
            html_parts.append('<tr>')
            for cell in hrow:
                html_parts.append(f'  <th>{cell}</th>')
            html_parts.append('</tr>')
        html_parts.append('</thead>')

    # Body
    if rows:
        html_parts.append('<tbody>')
        for row in rows:
            html_parts.append('<tr>')
            for cell in row:
                clean = cell.strip()
                # Strip any remaining HTML spans for alignment detection
                text_only = re.sub(r'<[^>]+>', '', clean)
                css_class = ""
                if _is_numeric(text_only):
                    css_class = ' class="numeric"'
                html_parts.append(f'  <td{css_class}>{clean}</td>')
            html_parts.append('</tr>')
        html_parts.append('</tbody>')

    html_parts.append('</table>')
    return '\n'.join(html_parts)


def _is_numeric(s):
    """Check if string looks numeric (for right-alignment)."""
    s = s.strip()
    if not s:
        return False
    # Remove commas, leading/trailing spaces
    s = s.replace(',', '')
    try:
        float(s)
        return True
    except ValueError:
        return False


# ---------------------------------------------------------------------------
# Collapsible section heuristic
# ---------------------------------------------------------------------------

COLLAPSIBLE_COMMANDS = {
    "summarize": {"keyword": "detail", "threshold": 0},
    "describe": {"keyword": None, "threshold": 20},
    "list": {"keyword": None, "threshold": 10},
    "codebook": {"keyword": None, "threshold": 0},
    "tab": {"keyword": None, "threshold": 20},
    "tabulate": {"keyword": None, "threshold": 20},
}

OUTPUT_FOLD_THRESHOLD = 30


def should_fold(command_text, output_lines, nofold=False):
    """Determine if an output block should be collapsible."""
    if nofold:
        return False

    words = command_text.strip().split() if command_text.strip() else []
    cmd_word = words[0] if words else ""
    cmd_lower = cmd_word.lower()
    # Skip common prefixes to find actual command
    while cmd_lower in ("noisily", "quietly", "capture") and len(words) > 1:
        words = words[1:]
        cmd_word = words[0]
        cmd_lower = cmd_word.lower()

    if cmd_lower in COLLAPSIBLE_COMMANDS:
        info = COLLAPSIBLE_COMMANDS[cmd_lower]
        if info["keyword"] is None:
            return len(output_lines) > info["threshold"]
        if info["keyword"] in command_text.lower():
            return True
        return len(output_lines) > info.get("threshold", OUTPUT_FOLD_THRESHOLD)

    # Generic: fold any long output
    return len(output_lines) > OUTPUT_FOLD_THRESHOLD


# ---------------------------------------------------------------------------
# Stage 5: Graph embedding
# ---------------------------------------------------------------------------

def detect_graph_exports(blocks):
    """Find graph export commands and return {filename: block_index}."""
    graph_files = {}
    for idx, block in enumerate(blocks):
        if block.kind != "command":
            continue
        cmd_text = " ".join(extract_command_text(l) for l in block.raw_lines)
        # Skip comments — they can contain "graph export" in descriptive text
        if cmd_text.startswith("*") or cmd_text.startswith("//"):
            continue
        m = re.search(r'graph\s+export\s+"?([^",]+)"?', cmd_text, re.IGNORECASE)
        if m:
            graph_files[m.group(1)] = idx
    return graph_files


def embed_image_base64(filepath, base_dir):
    """Read an image file and return a base64 data URI, or None."""
    if not os.path.isabs(filepath):
        # Try relative to CWD first, then relative to base_dir
        if os.path.isfile(filepath):
            filepath = os.path.abspath(filepath)
        else:
            filepath = os.path.join(base_dir, filepath)

    if not os.path.isfile(filepath):
        return None

    mime, _ = mimetypes.guess_type(filepath)
    if mime is None:
        mime = "image/png"

    try:
        with open(filepath, "rb") as f:
            data = base64.b64encode(f.read()).decode("ascii")
    except (IOError, OSError):
        return None

    return f"data:{mime};base64,{data}"


# ---------------------------------------------------------------------------
# Stage 6: HTML Renderer
# ---------------------------------------------------------------------------

def _is_empty_html(content):
    """Check if HTML content is effectively empty (only tags, whitespace)."""
    text = re.sub(r'<[^>]+>', '', content).strip()
    return not text


def render_html(blocks, title="Stata Output", theme_css="", preformatted=False,
                nofold=False, nodots=False, date=None, base_dir="."):
    """Render parsed blocks to a self-contained HTML document."""
    graph_files = detect_graph_exports(blocks)

    # Expand all blocks in HTML mode
    for block in blocks:
        expand_block(block, mode="html")

    parts = []
    last_command_text = ""

    for idx, block in enumerate(blocks):
        if block.kind == "command":
            # Extract plain command text for display and folding logic
            cmd_texts = [extract_command_text(l, strip_dots=nodots)
                         for l in block.raw_lines]
            last_command_text = " ".join(cmd_texts)
            full_cmd = last_command_text

            # Check if this is a graph export command
            graph_html = ""
            for gfile, gidx in graph_files.items():
                if gidx == idx:
                    data_uri = embed_image_base64(gfile, base_dir)
                    if data_uri:
                        graph_html = (
                            f'<figure class="graph-figure">'
                            f'<img src="{data_uri}" alt="{html_mod.escape(gfile)}">'
                            f'</figure>'
                        )
                    else:
                        graph_html = (
                            f'<div class="graph-missing">'
                            f'Graph file not found: {html_mod.escape(gfile)}'
                            f'</div>'
                        )

            # Skip comment-only commands (lines starting with *)
            if full_cmd.startswith("*") or full_cmd.startswith("//"):
                parts.append(
                    f'<div class="comment-block">'
                    f'{html_mod.escape(full_cmd)}</div>'
                )
                if graph_html:
                    parts.append(graph_html)
                continue

            # Render command block with copy button
            cmd_display = "\n".join(block.lines)
            if nodots:
                # Strip ". " and "> " prefixes from expanded display
                display_lines = []
                for dl in block.lines:
                    cleaned = re.sub(r'<[^>]+>', '', dl)
                    if re.match(r'^[.>]\s', cleaned):
                        # Remove the dot/arrow prefix from the original HTML line
                        dl = re.sub(r'^([^<]*?)([.>])\s', r'\1', dl, count=1)
                    display_lines.append(dl)
                cmd_display = "\n".join(display_lines)
            copy_text = html_mod.escape(
                re.sub(r'<[^>]+>', '', cmd_display).strip()
            )
            parts.append(
                f'<div class="code-block">'
                f'<button class="copy-btn" onclick="navigator.clipboard'
                f".writeText(this.parentElement.querySelector('pre')"
                f'.textContent.trim())">'
                f'Copy</button>'
                f'<pre>{cmd_display}</pre></div>'
            )
            if graph_html:
                parts.append(graph_html)

        elif block.kind == "table":
            if preformatted:
                content = "\n".join(block.lines)
                parts.append(
                    f'<div class="output-block"><pre>{content}</pre></div>'
                )
            else:
                html_table = table_to_html(block)
                if html_table:
                    parts.append(
                        f'<div class="table-block">{html_table}</div>'
                    )
                else:
                    # Fallback to preformatted
                    content = "\n".join(block.lines)
                    parts.append(
                        f'<div class="output-block"><pre>{content}</pre></div>'
                    )

        elif block.kind == "error":
            content = "\n".join(block.lines)
            parts.append(
                f'<div class="error-block"><pre>{content}</pre></div>'
            )

        elif block.kind == "output":
            content = "\n".join(block.lines)
            # Skip empty output (including blocks with only empty HTML spans)
            if _is_empty_html(content):
                continue

            if should_fold(last_command_text, block.lines, nofold):
                summary = f"Output ({len(block.lines)} lines)"
                parts.append(
                    f'<details class="fold-block">'
                    f'<summary>{summary}</summary>'
                    f'<div class="output-block"><pre>{content}</pre></div>'
                    f'</details>'
                )
            else:
                parts.append(
                    f'<div class="output-block"><pre>{content}</pre></div>'
                )

    body = "\n".join(parts)
    escaped_title = html_mod.escape(title)

    # Build subtitle line (date if provided)
    subtitle_html = ""
    if date:
        subtitle_html = f'\n<p class="subtitle">{html_mod.escape(date)}</p>'

    # Timestamp for footer
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escaped_title}</title>
<style>
{theme_css}
</style>
</head>
<body>
<article class="logdoc">
<header class="logdoc-header">
<h1>{escaped_title}</h1>{subtitle_html}
</header>
<main class="logdoc-body">
{body}
</main>
<footer class="logdoc-footer">
<p>Generated by <strong>logdoc</strong> &middot; {timestamp}</p>
</footer>
</article>
</body>
</html>"""


# ---------------------------------------------------------------------------
# Stage 7: Markdown Renderer
# ---------------------------------------------------------------------------

def render_markdown(blocks, title="Stata Output", nofold=False, nodots=False,
                    date=None, base_dir=".", output_dir=None):
    """Render parsed blocks to Markdown."""
    graph_files = detect_graph_exports(blocks)
    if output_dir is None:
        output_dir = base_dir

    # Expand all blocks in text mode
    for block in blocks:
        expand_block(block, mode="text")

    parts = []
    safe_title = title.replace('\\', '\\\\').replace('"', '\\"')
    parts.append("---")
    parts.append(f'title: "{safe_title}"')
    if date:
        safe_date = date.replace('\\', '\\\\').replace('"', '\\"')
        parts.append(f'date: "{safe_date}"')
    parts.append("---")
    parts.append("")
    last_command_text = ""

    for idx, block in enumerate(blocks):
        if block.kind == "command":
            cmd_texts = [extract_command_text(l, strip_dots=nodots)
                         for l in block.raw_lines]
            last_command_text = " ".join(cmd_texts)
            full_cmd = last_command_text

            if full_cmd.startswith("*") or full_cmd.startswith("//"):
                parts.append(f"<!-- {full_cmd} -->")
                parts.append("")
                continue

            # Reconstruct clean command for markdown
            clean_lines = []
            for raw in block.raw_lines:
                text = extract_command_text(raw, strip_dots=nodots)
                if text:
                    clean_lines.append(text)
            cmd_str = "\n".join(clean_lines)

            parts.append("```stata")
            parts.append(cmd_str)
            parts.append("```")
            parts.append("")

            # Graph reference — resolve path relative to the output .md file
            for gfile, gidx in graph_files.items():
                if gidx == idx:
                    # Try CWD-relative first, then base_dir-relative
                    if os.path.isfile(gfile):
                        abs_gfile = os.path.abspath(gfile)
                    elif os.path.isfile(os.path.join(base_dir, gfile)):
                        abs_gfile = os.path.abspath(
                            os.path.join(base_dir, gfile))
                    else:
                        abs_gfile = gfile
                    rel_path = os.path.relpath(
                        abs_gfile, os.path.abspath(output_dir))
                    display_name = os.path.basename(gfile)
                    parts.append(f"![{display_name}]({rel_path})")
                    parts.append("")

        elif block.kind == "table":
            content = "\n".join(block.lines)
            if content.strip():
                parts.append("```")
                parts.append(content)
                parts.append("```")
                parts.append("")

        elif block.kind == "error":
            for line in block.lines:
                clean = line.strip()
                if clean:
                    parts.append(f"> **Error:** {clean}")
            parts.append("")

        elif block.kind == "output":
            content = "\n".join(block.lines)
            text_only = re.sub(r'<[^>]+>', '', content).strip()
            if not text_only:
                continue
            parts.append("```")
            parts.append(content)
            parts.append("```")
            parts.append("")

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def load_css(css_path):
    """Load CSS from file, return empty string if not found."""
    if css_path and os.path.isfile(css_path):
        with open(css_path, "r") as f:
            return f.read()
    return ""


def find_css_file(name, script_dir):
    """Find a CSS file by name, checking script directory."""
    path = os.path.join(script_dir, name)
    if os.path.isfile(path):
        return path
    return None


def main():
    parser = argparse.ArgumentParser(
        description="Convert Stata SMCL/log files to HTML or Markdown"
    )
    parser.add_argument("input", help="Input .smcl, .log, or .do file")
    parser.add_argument("output", help="Output file path")
    parser.add_argument("--format", default="html",
                        choices=["html", "md", "both"],
                        help="Output format (default: html)")
    parser.add_argument("--theme", default="light",
                        choices=["light", "dark"],
                        help="CSS theme (default: light)")
    parser.add_argument("--title", default=None,
                        help="Document title (defaults to filename)")
    parser.add_argument("--preformatted", action="store_true",
                        help="Keep tables as monospace blocks")
    parser.add_argument("--nofold", action="store_true",
                        help="Disable collapsible sections")
    parser.add_argument("--nodots", action="store_true",
                        help="Strip dot prompts from commands")
    parser.add_argument("--date", default=None,
                        help="Date subtitle shown in document header")
    parser.add_argument("--css", default=None,
                        help="Custom CSS file path")
    parser.add_argument("--light-css", default=None,
                        help="Path to light theme CSS")
    parser.add_argument("--dark-css", default=None,
                        help="Path to dark theme CSS")

    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    # Read input
    with open(args.input, "r", errors="replace") as f:
        raw_text = f.read()

    # Determine title
    title = args.title or os.path.splitext(os.path.basename(args.input))[0]

    # Base directory for resolving graph paths
    base_dir = os.path.dirname(os.path.abspath(args.input))

    # Parse into lines and blocks
    raw_lines = raw_text.split("\n")
    blocks = parse_blocks(raw_lines)

    if not blocks:
        print("Warning: No content blocks found in input", file=sys.stderr)
        sys.exit(1)

    # Determine CSS — try external files first, fall back to embedded
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if args.css:
        theme_css = load_css(args.css)
    elif args.theme == "dark":
        css_path = args.dark_css or find_css_file("logdoc_dark.css", script_dir)
        theme_css = load_css(css_path) or CSS_DARK
    else:
        css_path = args.light_css or find_css_file("logdoc_light.css", script_dir)
        theme_css = load_css(css_path) or CSS_LIGHT

    # Render
    fmt = args.format
    output_path = args.output

    if fmt in ("html", "both"):
        html_out = output_path if fmt == "html" else _swap_ext(output_path, ".html")
        html_content = render_html(
            blocks, title=title, theme_css=theme_css,
            preformatted=args.preformatted, nofold=args.nofold,
            nodots=args.nodots, date=args.date, base_dir=base_dir,
        )
        os.makedirs(os.path.dirname(os.path.abspath(html_out)), exist_ok=True)
        with open(html_out, "w") as f:
            f.write(html_content)
        print(f"Generated: {html_out}")

    if fmt in ("md", "both"):
        # Re-parse blocks since expand_block mutates them
        blocks = parse_blocks(raw_text.split("\n"))
        md_out = output_path if fmt == "md" else _swap_ext(output_path, ".md")
        md_output_dir = os.path.dirname(os.path.abspath(md_out))
        md_content = render_markdown(
            blocks, title=title, nofold=args.nofold,
            nodots=args.nodots, date=args.date, base_dir=base_dir,
            output_dir=md_output_dir,
        )
        os.makedirs(os.path.dirname(os.path.abspath(md_out)), exist_ok=True)
        with open(md_out, "w") as f:
            f.write(md_content)
        print(f"Generated: {md_out}")


def _swap_ext(path, new_ext):
    """Swap file extension."""
    base, _ = os.path.splitext(path)
    return base + new_ext


if __name__ == "__main__":
    main()
