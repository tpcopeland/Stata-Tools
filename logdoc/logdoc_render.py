#!/usr/bin/env python3
"""logdoc_render.py - Convert Stata SMCL/log files to shareable documents.

Default HTML rendering is faithful-first: Stata spacing, SMCL color semantics,
and monospace output are preserved without table parsing, command syntax
highlighting, folding, or document controls unless those enhancements are
explicitly requested.

Usage:
    python3 logdoc_render.py input.smcl output.html [options]
    python3 logdoc_render.py input.log output.md --format md
    python3 logdoc_render.py input.smcl output.qmd --format qmd

Options:
    --format html|md|both|qmd|tex    Output format (default: html)
    --theme light|dark       CSS theme (default: light)
    --title "Title"          Document title
    --fold                   Fold long output blocks
    --highlight              Syntax-highlight command text
    --tables                 Parse supported Stata tables into HTML tables
    --copy                   Add copy buttons to command blocks
    --download               Add Download .do toolbar button
    --preformatted           Compatibility alias; HTML tables are monospace by default
    --nofold                 Compatibility alias; folding is off by default
    --css PATH               Custom CSS file path

No external dependencies — uses only the Python standard library.
"""

import argparse
import base64
import datetime
import difflib
import html as html_mod
import json
import os
import re
import sys
import tempfile


# ---------------------------------------------------------------------------
# O1: Stata syntax highlighting for command blocks
# ---------------------------------------------------------------------------

STATA_KEYWORDS = {
    "about", "ado", "adopath", "append", "areg", "assert", "binreg",
    "biprobit", "bootstrap", "break", "bsample", "bysort", "capture",
    "cd", "census", "ci", "clear", "clogit", "cloglog", "cls", "cmdlog",
    "codebook", "collapse", "compress", "confirm", "constraint",
    "continue", "contract", "copy", "correlate", "count", "creturn",
    "cross", "cscript", "cumul", "datasignature", "decode", "destring",
    "describe", "di", "dir", "discard", "display", "do", "drop",
    "duplicates", "edit", "egen", "else", "encode", "erase", "error",
    "estimates", "exit", "expand", "export", "file", "fillin", "foreach",
    "forvalues", "generate", "global", "glm", "graph", "gsort",
    "heckman", "help", "histogram", "if", "import", "in", "input",
    "insheet", "intreg", "ivprobit", "ivregress", "ivtobit",
    "joinby", "keep", "label", "levelsof", "lincom", "list", "local",
    "log", "logistic", "logit", "lookup", "macro", "margins",
    "mark", "mata", "matrix", "maximize", "mcc", "mean", "merge",
    "mixed", "mkspline", "mlogit", "more", "mvdecode", "net", "nlcom",
    "nlogit", "noisily", "note", "notes", "ologit", "oprobit", "order",
    "outsheet", "pause", "pctile", "poisson", "predict", "preserve",
    "probit", "program", "proportion", "prtesti", "putexcel", "pwcorr",
    "quietly", "ranksum", "ratio", "recode", "regress", "rename",
    "replace", "reshape", "restore", "return", "rmdir", "rologit",
    "run", "save", "scalar", "scatter", "sdtest", "search", "set",
    "shell", "signrank", "simulate", "sort", "split", "ssc",
    "statsby", "stcox", "streg", "stset", "sts", "stsum", "summarize",
    "sureg", "survey", "survival", "svy", "syntax", "sysuse",
    "tab", "tabdisp", "table", "tabstat", "tabulate", "tempfile",
    "tempname", "tempvar", "test", "testnl", "timer", "tokenize",
    "tobit", "total", "translate", "truncreg", "tset", "tsset",
    "ttest", "twoway", "type", "unab", "use", "using", "version",
    "webuse", "which", "while", "window", "xtabond", "xtivreg",
    "xtlogit", "xtmelogit", "xtmepoisson", "xtmixed", "xtpoisson",
    "xtprobit", "xtreg", "xtset", "xttab", "xttobit", "zinb", "zip",
}

# Pre-compile the keyword pattern for performance
_STATA_KW_PATTERN = re.compile(
    r'\b(' + '|'.join(sorted(STATA_KEYWORDS, key=len, reverse=True)) + r')\b'
)


def highlight_stata(plain_text):
    """Apply Stata syntax highlighting to plain command text.

    Takes plain text (already HTML-escaped) and wraps tokens in spans.
    Returns HTML with syntax highlighting spans.
    """
    # Work on each line independently
    lines = plain_text.split('\n')
    result_lines = []
    for line in lines:
        result_lines.append(_highlight_stata_line(line))
    return '\n'.join(result_lines)


def _highlight_stata_line(line):
    """Highlight a single line of Stata code (HTML-escaped input)."""
    # Unescape HTML entities to work on plain text
    text = line.replace('&amp;', '&').replace('&lt;', '<').replace(
        '&gt;', '>').replace('&quot;', '"').replace('&#x27;', "'")

    tokens = []
    i = 0
    n = len(text)

    while i < n:
        # Line-start comment: * at the beginning (possibly after dot prompt)
        stripped_so_far = text[:i].strip()
        if text[i] == '*' and (i == 0 or stripped_so_far == '' or
                               stripped_so_far in ('.', '>')):
            tokens.append(('comment', text[i:]))
            break

        # // comment to end of line (not inside a string)
        if text[i:i+2] == '//' and not _inside_string(text, i):
            tokens.append(('comment', text[i:]))
            break

        # Compound double-quote string `"..."'
        if text[i:i+2] == '`"':
            end = text.find("\"'", i + 2)
            if end == -1:
                tokens.append(('string', text[i:]))
                break
            tokens.append(('string', text[i:end+2]))
            i = end + 2
            continue

        # Regular double-quote string
        if text[i] == '"':
            end = text.find('"', i + 1)
            if end == -1:
                tokens.append(('string', text[i:]))
                break
            tokens.append(('string', text[i:end+1]))
            i = end + 1
            continue

        # Macro: `name' (local) or $name / ${name} (global)
        if text[i] == '`' and i + 1 < n and text[i+1] != '"':
            end = text.find("'", i + 1)
            if end != -1:
                tokens.append(('macro', text[i:end+1]))
                i = end + 1
                continue

        if text[i] == '$':
            if i + 1 < n and text[i+1] == '{':
                end = text.find('}', i + 2)
                if end != -1:
                    tokens.append(('macro', text[i:end+1]))
                    i = end + 1
                    continue
            elif i + 1 < n and (text[i+1].isalpha() or text[i+1] == '_'):
                j = i + 1
                while j < n and (text[j].isalnum() or text[j] == '_'):
                    j += 1
                tokens.append(('macro', text[i:j]))
                i = j
                continue

        # Number (digit at start, not part of a word)
        if text[i].isdigit() and (i == 0 or not (text[i-1].isalnum() or text[i-1] == '_')):
            j = i
            while j < n and (text[j].isdigit() or text[j] == '.'):
                j += 1
            # Handle scientific notation
            if j < n and text[j] in ('e', 'E'):
                k = j + 1
                if k < n and text[k] in ('+', '-'):
                    k += 1
                if k < n and text[k].isdigit():
                    while k < n and text[k].isdigit():
                        k += 1
                    j = k
            tokens.append(('number', text[i:j]))
            i = j
            continue

        # Word (potential keyword)
        if text[i].isalpha() or text[i] == '_':
            j = i
            while j < n and (text[j].isalnum() or text[j] == '_'):
                j += 1
            word = text[i:j]
            if word.lower() in STATA_KEYWORDS:
                tokens.append(('keyword', word))
            else:
                tokens.append(('text', word))
            i = j
            continue

        # Any other character
        tokens.append(('text', text[i]))
        i += 1

    # Reconstruct with HTML spans and re-escape
    parts = []
    for kind, value in tokens:
        escaped = html_mod.escape(value)
        if kind == 'keyword':
            parts.append(f'<span class="stata-kw">{escaped}</span>')
        elif kind == 'string':
            parts.append(f'<span class="stata-str">{escaped}</span>')
        elif kind == 'macro':
            parts.append(f'<span class="stata-macro">{escaped}</span>')
        elif kind == 'comment':
            parts.append(f'<span class="stata-comment">{escaped}</span>')
        elif kind == 'number':
            parts.append(f'<span class="stata-num">{escaped}</span>')
        else:
            parts.append(escaped)
    return ''.join(parts)


def _inside_string(text, pos):
    """Rough check: is position pos inside a double-quoted string?"""
    in_str = False
    i = 0
    while i < pos:
        if text[i] == '"' and not (i > 0 and text[i-1] == '`'):
            in_str = not in_str
        i += 1
    return in_str


# ---------------------------------------------------------------------------
# F4: Section marker detection for comments
# ---------------------------------------------------------------------------

_SECTION_PATTERNS = [
    # * # Title  or  // # Title
    re.compile(r'^\s*(?:\*|//)\s*#{1,2}\s+(.+)$'),
    # * === Title ===
    re.compile(r'^\s*(?:\*|//)\s*={3,}\s+(.+?)\s*={3,}\s*$'),
]


def detect_section_marker(comment_text):
    """Check if a comment is a section marker. Returns (level, title) or None.

    level 1 = # Title (h2), level 2 = ## Title (h3)
    """
    for pat in _SECTION_PATTERNS:
        m = pat.match(comment_text)
        if m:
            title = m.group(1).strip()
            # Determine level: ## = level 2, # or === = level 1
            if re.match(r'^\s*(?:\*|//)\s*##\s+', comment_text):
                return (2, title)
            return (1, title)
    return None


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
.code-block { position: relative; margin: 1rem 0 0.25rem 0; padding: 0.75rem 1rem;
  background: #f8f9fa; border-left: 3px solid #4582ec; border-radius: 0 4px 4px 0;
  overflow-x: auto; }
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
.stamp { font-size: 0.6875rem; color: #adb5bd; margin-top: 0.25rem; font-family: "JetBrains Mono",
  "Fira Code", "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace; }
.copy-btn { position: absolute; top: 0.4rem; right: 0.5rem; padding: 0.15rem 0.5rem;
  font-size: 0.7rem; border: 1px solid #dee2e6; border-radius: 3px; background: #fff;
  color: #6c757d; cursor: pointer; opacity: 0; transition: opacity 0.15s; }
.code-block:hover .copy-btn { opacity: 1; }
.copy-btn:hover { background: #e9ecef; }
.stata-kw { color: #0550ae; font-weight: 600; }
.stata-str { color: #0a3069; }
.stata-macro { color: #8250df; }
.stata-comment { color: #6e7781; font-style: italic; }
.stata-num { color: #0550ae; }
.line-num { color: #adb5bd; user-select: none; width: 3ch; display: inline-block;
  text-align: right; margin-right: 1ch; }
.logdoc-toolbar { display: flex; gap: 0.5rem; padding: 0.5rem 0; margin-bottom: 0.5rem; }
.toolbar-btn { padding: 0.25rem 0.75rem; font-size: 0.75rem; border: 1px solid #dee2e6;
  border-radius: 3px; background: #f8f9fa; color: #495057; cursor: pointer; }
.toolbar-btn:hover { background: #e9ecef; }
.code-block.error-source { border-left-color: #e74c3c; background: #fff5f5; }
.section-header { margin: 2rem 0 1rem 0; padding-bottom: 0.5rem; border-bottom: 1px solid #dee2e6;
  color: #212529; font-size: 1.25rem; font-weight: 600; }
.section-header.level-2 { font-size: 1.1rem; border-bottom: none; margin: 1.5rem 0 0.75rem 0; }
.logdoc-toc { margin-bottom: 2rem; padding: 1rem 1.5rem; background: #f8f9fa;
  border: 1px solid #dee2e6; border-radius: 4px; }
.logdoc-toc ol { margin: 0.5rem 0 0 1.5rem; padding: 0; }
.logdoc-toc li { margin: 0.25rem 0; font-size: 0.875rem; }
.logdoc-toc a { color: #4582ec; text-decoration: none; }
.logdoc-toc a:hover { text-decoration: underline; }
.logdoc-nav { position: sticky; top: 0; z-index: 100; background: rgba(255,255,255,0.95);
  padding: 0.5rem 1rem; border-bottom: 1px solid #dee2e6; font-size: 0.8125rem;
  color: #495057; backdrop-filter: blur(4px); }
@media (max-width: 768px) { .logdoc { padding: 1rem; } .logdoc-header h1 { font-size: 1.25rem; } }
@media print { body { font-size: 11pt; } .logdoc { max-width: 100%; padding: 0; }
  .code-block { break-inside: avoid; border-left-color: #999; }
  .table-block { break-inside: avoid; } .copy-btn { display: none; }
  .fold-block { border: none; } .fold-block > * { display: block !important; }
  .fold-block summary { display: none; } .logdoc-footer { color: #999; }
  .logdoc-toolbar { display: none; } .logdoc-nav { position: static; border: none; } }
.notebook-cell { border: 1px solid #e9ecef; border-radius: 4px; margin: 1rem 0; overflow: hidden; }
.cell-number { padding: 0.25rem 0.75rem; font-family: monospace; font-size: 0.75rem; color: #6c757d; }
.diff-added { background: #d4edda; border-left: 3px solid #28a745; }
.diff-removed { background: #f8d7da; border-left: 3px solid #dc3545; }
.annotation { background: #fff3cd; border-left: 3px solid #ffc107; padding: 0.5rem 1rem;
  margin: 0.25rem 0; font-size: 0.875rem; }
"""

CSS_DARK = """\
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #1e1e2e; color: #cdd6f4;
  font-family: "Source Sans Pro", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 16px; line-height: 1.6; -webkit-font-smoothing: antialiased; }
.logdoc { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; }
.logdoc-header { margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 2px solid #45475a; }
.logdoc-header h1 { font-size: 1.75rem; font-weight: 600; color: #cdd6f4; margin: 0; }
.code-block { position: relative; margin: 1rem 0 0.25rem 0; padding: 0.75rem 1rem;
  background: #313244; border-left: 3px solid #89b4fa; border-radius: 0 4px 4px 0;
  overflow-x: auto; }
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
.stamp { font-size: 0.6875rem; color: #585b70; margin-top: 0.25rem; font-family: "JetBrains Mono",
  "Fira Code", "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace; }
.copy-btn { position: absolute; top: 0.4rem; right: 0.5rem; padding: 0.15rem 0.5rem;
  font-size: 0.7rem; border: 1px solid #585b70; border-radius: 3px; background: #45475a;
  color: #a6adc8; cursor: pointer; opacity: 0; transition: opacity 0.15s; }
.code-block:hover .copy-btn { opacity: 1; }
.copy-btn:hover { background: #585b70; }
.stata-kw { color: #89b4fa; font-weight: 600; }
.stata-str { color: #a6e3a1; }
.stata-macro { color: #cba6f7; }
.stata-comment { color: #6c7086; font-style: italic; }
.stata-num { color: #fab387; }
.line-num { color: #585b70; user-select: none; width: 3ch; display: inline-block;
  text-align: right; margin-right: 1ch; }
.logdoc-toolbar { display: flex; gap: 0.5rem; padding: 0.5rem 0; margin-bottom: 0.5rem; }
.toolbar-btn { padding: 0.25rem 0.75rem; font-size: 0.75rem; border: 1px solid #585b70;
  border-radius: 3px; background: #313244; color: #a6adc8; cursor: pointer; }
.toolbar-btn:hover { background: #45475a; }
.code-block.error-source { border-left-color: #f38ba8; background: #302028; }
.section-header { margin: 2rem 0 1rem 0; padding-bottom: 0.5rem; border-bottom: 1px solid #45475a;
  color: #cdd6f4; font-size: 1.25rem; font-weight: 600; }
.section-header.level-2 { font-size: 1.1rem; border-bottom: none; margin: 1.5rem 0 0.75rem 0; }
.logdoc-toc { margin-bottom: 2rem; padding: 1rem 1.5rem; background: #313244;
  border: 1px solid #45475a; border-radius: 4px; }
.logdoc-toc ol { margin: 0.5rem 0 0 1.5rem; padding: 0; }
.logdoc-toc li { margin: 0.25rem 0; font-size: 0.875rem; }
.logdoc-toc a { color: #89dceb; text-decoration: none; }
.logdoc-toc a:hover { text-decoration: underline; }
.logdoc-nav { position: sticky; top: 0; z-index: 100; background: rgba(30,30,46,0.95);
  padding: 0.5rem 1rem; border-bottom: 1px solid #45475a; font-size: 0.8125rem;
  color: #a6adc8; backdrop-filter: blur(4px); }
@media (max-width: 768px) { .logdoc { padding: 1rem; } .logdoc-header h1 { font-size: 1.25rem; } }
@media print { body { background: #fff; color: #212529; font-size: 11pt; }
  .logdoc { max-width: 100%; padding: 0; }
  .code-block { break-inside: avoid; background: #f8f9fa; border-left-color: #999; }
  .code-block pre, .output-block pre { color: #212529; }
  .table-block { break-inside: avoid; } .copy-btn { display: none; }
  .fold-block { border: none; } .fold-block > * { display: block !important; }
  .fold-block summary { display: none; } .logdoc-footer { color: #999; }
  .logdoc-toolbar { display: none; } .logdoc-nav { position: static; border: none; } }
.notebook-cell { border: 1px solid #45475a; border-radius: 4px; margin: 1rem 0; overflow: hidden; }
.cell-number { padding: 0.25rem 0.75rem; font-family: monospace; font-size: 0.75rem; color: #6c7086; }
.diff-added { background: #1a3a2a; border-left: 3px solid #a6e3a1; }
.diff-removed { background: #3a1a2a; border-left: 3px solid #f38ba8; }
.annotation { background: #3a3520; border-left: 3px solid #f9e2af; padding: 0.5rem 1rem;
  margin: 0.25rem 0; font-size: 0.875rem; }
"""


CSS_CORE_LIGHT = """\
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #ffffff; color: #212529;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 16px; line-height: 1.55; -webkit-font-smoothing: antialiased; }
.logdoc { max-width: 1040px; margin: 0 auto; padding: 2rem 1.25rem; }
.logdoc-header { margin-bottom: 1.25rem; padding-bottom: 0.75rem; border-bottom: 1px solid #d7dde5; }
.logdoc-header h1 { font-size: 1.5rem; font-weight: 600; color: #1f2937; margin: 0; }
.subtitle { font-size: 0.9375rem; color: #667085; margin-top: 0.25rem; }
.stamp { font-size: 0.75rem; color: #667085; margin-top: 0.25rem; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
.stata-log-wrap { margin: 0; overflow-x: auto; }
.stata-log { margin: 0; padding: 0 0 0.75rem 0; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.875rem; line-height: 1.45; white-space: pre; tab-size: 8; color: #374151; }
.err { color: #b42318; }
.cmd { color: #111827; font-weight: 600; }
.res { color: #111827; }
.comment-block { margin: 0.25rem 0; color: #667085; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.875rem; }
.graph-figure { margin: 1rem 0 1.5rem 0; text-align: center; }
.graph-figure img { max-width: 100%; height: auto; border: 1px solid #d7dde5; border-radius: 4px; }
.graph-missing { margin: 0.5rem 0; padding: 0.6rem 0.75rem; background: #fff7ed; border-left: 3px solid #f97316; color: #9a3412; font-size: 0.875rem; }
.logdoc-footer { margin-top: 2rem; padding-top: 0.75rem; border-top: 1px solid #d7dde5; font-size: 0.75rem; color: #667085; text-align: center; }
@media (max-width: 768px) { .logdoc { padding: 1rem; } .logdoc-header h1 { font-size: 1.25rem; } }
.diff-added { background: #d4edda; border-left: 3px solid #28a745; }
.diff-removed { background: #f8d7da; border-left: 3px solid #dc3545; }
.diff-context { opacity: 0.6; }
.diff-legend { display: flex; gap: 1.5rem; margin-bottom: 1rem; font-size: 0.8125rem; color: #667085; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
.diff-legend span { display: inline-flex; align-items: center; gap: 0.4rem; }
.diff-legend .swatch { display: inline-block; width: 0.875rem; height: 0.875rem; border-radius: 2px; }
.diff-group { margin: 0.5rem 0; padding: 0.25rem 0; border-top: 1px dashed #d7dde5; }
.diff-label { font-size: 0.75rem; color: #667085; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; padding: 0.125rem 0.5rem; }
@media print { body { font-size: 11pt; } .logdoc { max-width: 100%; padding: 0; } .graph-figure, .stata-log-wrap { break-inside: avoid; } }
"""


CSS_CORE_DARK = """\
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #191a1f; color: #e5e7eb;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 16px; line-height: 1.55; -webkit-font-smoothing: antialiased; }
.logdoc { max-width: 1040px; margin: 0 auto; padding: 2rem 1.25rem; }
.logdoc-header { margin-bottom: 1.25rem; padding-bottom: 0.75rem; border-bottom: 1px solid #374151; }
.logdoc-header h1 { font-size: 1.5rem; font-weight: 600; color: #f9fafb; margin: 0; }
.subtitle { font-size: 0.9375rem; color: #9ca3af; margin-top: 0.25rem; }
.stamp { font-size: 0.75rem; color: #9ca3af; margin-top: 0.25rem; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
.stata-log-wrap { margin: 0; overflow-x: auto; }
.stata-log { margin: 0; padding: 0 0 0.75rem 0; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.875rem; line-height: 1.45; white-space: pre; tab-size: 8; color: #d1d5db; }
.err { color: #fca5a5; }
.cmd { color: #f9fafb; font-weight: 600; }
.res { color: #f9fafb; }
.comment-block { margin: 0.25rem 0; color: #9ca3af; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.875rem; }
.graph-figure { margin: 1rem 0 1.5rem 0; text-align: center; }
.graph-figure img { max-width: 100%; height: auto; border: 1px solid #374151; border-radius: 4px; }
.graph-missing { margin: 0.5rem 0; padding: 0.6rem 0.75rem; background: #431407; border-left: 3px solid #fb923c; color: #fed7aa; font-size: 0.875rem; }
.logdoc-footer { margin-top: 2rem; padding-top: 0.75rem; border-top: 1px solid #374151; font-size: 0.75rem; color: #9ca3af; text-align: center; }
@media (max-width: 768px) { .logdoc { padding: 1rem; } .logdoc-header h1 { font-size: 1.25rem; } }
.diff-added { background: #1a3a2a; border-left: 3px solid #a6e3a1; }
.diff-removed { background: #3a1a2a; border-left: 3px solid #f38ba8; }
.diff-context { opacity: 0.6; }
.diff-legend { display: flex; gap: 1.5rem; margin-bottom: 1rem; font-size: 0.8125rem; color: #9ca3af; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
.diff-legend span { display: inline-flex; align-items: center; gap: 0.4rem; }
.diff-legend .swatch { display: inline-block; width: 0.875rem; height: 0.875rem; border-radius: 2px; }
.diff-group { margin: 0.5rem 0; padding: 0.25rem 0; border-top: 1px dashed #374151; }
.diff-label { font-size: 0.75rem; color: #9ca3af; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; padding: 0.125rem 0.5rem; }
@media print { body { background: #fff; color: #212529; font-size: 11pt; } .logdoc { max-width: 100%; padding: 0; } .graph-figure, .stata-log-wrap { break-inside: avoid; } }
"""


# ---------------------------------------------------------------------------
# SMCL box-drawing character map
# ---------------------------------------------------------------------------
SMCL_CHAR_MAP = {
    "{c TLC}": "┌", "{c TRC}": "┐", "{c BLC}": "└", "{c BRC}": "┘",
    "{c TT}": "┬", "{c BT}": "┴", "{c LT}": "├", "{c RT}": "┤",
    "{c +}": "┼", "{c |}": "│", "{c -}": "─",
    "{c -(}": "{", "{c )-}": "}",
    "{c S|}": "§", "{c 0xa3}": "£", "{c 0xa9}": "©",
    "{c 0xae}": "®", "{c 0xb0}": "°", "{c 0xb1}": "±",
    "{c 0xb2}": "²", "{c 0xb3}": "³", "{c 0xb7}": "·",
    "{c 0xbc}": "¼", "{c 0xbd}": "½", "{c 0xbe}": "¾",
    "{c 0xd7}": "×", "{c 0xf7}": "÷",
}


# ---------------------------------------------------------------------------
# Stage 2: Semantic SMCL Parser — classify raw lines into blocks
# ---------------------------------------------------------------------------

class Block:
    """A semantic block of SMCL content."""
    __slots__ = ("kind", "lines", "raw_lines", "state")

    def __init__(self, kind, lines=None, raw_lines=None):
        self.kind = kind            # command, table, error, graph_ref, output
        self.lines = lines or []    # expanded text lines
        self.raw_lines = raw_lines or []  # original SMCL lines
        # SMCL layout state ({p2colset}); parse_blocks shares one per source
        self.state = new_smcl_state()


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
    # A plain "> " line (no {com}) is a command continuation only right after
    # a command echo; after output it is the rest of an output line the log
    # wrapped at the linesize. parse_blocks decides from the context.
    if re.match(r'>\s+[a-zA-Z*/_]', clean):
        return "plain_continuation"
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


_SMCL_CONTINUATION_RE = re.compile(r'\{\.\.\.\}\s*$')


def _is_wrap_continuation(line):
    """A plain "> " line: the rest of a line a text log wrapped."""
    if re.search(r'\{com\}', line):
        return False
    clean = re.sub(r'\{[^}]*\}', '', line)
    return clean.startswith("> ")


def normalize_smcl_continuations(raw_lines):
    """Join physical SMCL lines connected by Stata's invisible {...} marker."""
    normalized = []
    pending = ""

    for line in raw_lines:
        current = pending + line if pending else line
        if _SMCL_CONTINUATION_RE.search(current):
            pending = _SMCL_CONTINUATION_RE.sub("", current)
            continue

        normalized.append(current)
        pending = ""

    if pending:
        normalized.append(pending)

    return normalized


def _smcl_visible_blank(line):
    return not re.sub(r'\{[^}]*\}', '', line).strip()


def join_smcl_paragraphs(raw_lines):
    """Join the physical lines of an SMCL paragraph into one line.

    In paragraph mode ({p ...} through {p_end} or a blank line) Stata joins
    the source lines with single spaces before wrapping, so an error such as
    "{p 0 4 2}" / "file x" / "already exists" / "{p_end}" prints as one
    line.  Nothing is joined across a command echo.
    """
    out = []
    i = 0
    n = len(raw_lines)
    while i < n:
        line = raw_lines[i]
        if not _SMCL_PARA_START_RE.search(line) or "{p_end}" in line:
            out.append(line)
            i += 1
            continue
        pieces = [line.rstrip()]
        j = i + 1
        while j < n:
            nxt = raw_lines[j]
            if classify_raw_line(nxt) in ("command", "continuation",
                                          "command_blank"):
                break
            if _smcl_visible_blank(nxt) and "{p_end}" not in nxt:
                break
            # a new paragraph directive starts a new paragraph
            if _SMCL_PARA_START_RE.search(nxt):
                break
            pieces.append(nxt.strip())
            j += 1
            if "{p_end}" in nxt:
                break
        joined = ""
        for piece in pieces:
            visible = re.sub(r'\{[^}]*\}', '', joined)
            if visible.strip() and not visible.endswith(" ") and \
                    not _smcl_visible_blank(piece):
                joined += " " + piece
            else:
                joined += piece
        out.append(joined)
        i = j
    return out


_SMCL_MODE_LINE_RE = re.compile(
    r'^\s*(?:\{(?:sf|ul off|\.-)\})*\{(com|txt|text|res|result|err|error|inp|input)\}')


def _text_log_wrap_width(raw_lines):
    """The linesize a plain-text log was written at, from its own lines.

    Stata cuts a wrapped command echo at exactly the linesize and never
    writes a longer line, so a log with a wrapped line has the linesize as
    its longest line length.  Below Stata's minimum linesize (40) nothing
    can have wrapped: 0.
    """
    width = max((len(line.rstrip("\r\n")) for line in raw_lines),
                default=0)
    return width if width >= 40 else 0


def _is_command_continuation(prev, line, is_smcl, wrap_width=0):
    """True when `line` continues the command echo whose last line is prev.

    {com}> is always a continuation.  In SMCL a bare "> " line continues
    the command (its {com} mode is still on) while output always opens with
    its own mode tag, so "{res}> x" is output.  A text log carries no tags:
    there "> " continues the command only when the previous line was cut at
    the log's linesize (`wrap_width`, from _text_log_wrap_width) or ends
    with ///; otherwise it is output starting "> ".
    """
    stripped = line.strip()
    if stripped.startswith("{com}>"):
        return True
    if is_smcl:
        return bool(re.match(r'>(\s|$)', line.lstrip()))
    if not re.match(r'>(\s|$)', line):
        return False
    # prev is brace-escaped ({c -(}): measure the text as written
    prev_text = prev.replace("{c -(}", "{").replace("{c )-}", "}")
    prev_text = prev_text.rstrip("\r\n")
    return prev_text.rstrip().endswith("///") or (
        wrap_width > 0 and len(prev_text) == wrap_width)


def _is_smcl_text(raw_lines):
    """True when the input is SMCL rather than a plain-text log.

    SMCL when an {smcl} header line appears among the first nonblank lines
    (blank lines or a BOM may precede it), or when the file has lines that
    start with SMCL mode tags: at least one {com} line and one {txt}/{res}/
    {err}/{inp} line.  A plain log that merely contains braces (JSON, a
    displayed "{x}") has neither, so its braces stay literal.
    """
    nonblank = 0
    for line in raw_lines:
        stripped = line.strip().lstrip("\ufeff")
        if not stripped:
            continue
        if stripped.startswith("{smcl}"):
            return True
        nonblank += 1
        if nonblank >= 10:
            break
    kinds = set()
    for line in raw_lines:
        m = _SMCL_MODE_LINE_RE.match(line)
        if m:
            kinds.add("com" if m.group(1) == "com" else "other")
            if len(kinds) == 2:
                return True
    return False


def _escape_plain_braces(line):
    """Protect literal braces of a plain-text log from SMCL expansion."""
    return line.replace("{", "\x00").replace("}", "{c )-}").replace(
        "\x00", "{c -(}")


def parse_blocks(raw_lines):
    """Parse raw SMCL lines into semantic blocks.

    A plain-text log (no {smcl} header) carries no markup, so its braces are
    literal output: they are escaped to {c -(}/{c )-} before parsing and
    survive expansion unchanged.
    """
    is_smcl = _is_smcl_text(raw_lines)
    wrap_width = 0
    if not is_smcl:
        wrap_width = _text_log_wrap_width(raw_lines)
        raw_lines = [_escape_plain_braces(line) for line in raw_lines]
        raw_lines = normalize_smcl_continuations(raw_lines)
    else:
        raw_lines = join_smcl_paragraphs(
            normalize_smcl_continuations(raw_lines))
    blocks = []
    i = 0
    n = len(raw_lines)

    while i < n:
        line = raw_lines[i]
        ltype = classify_raw_line(line)

        # Skip the log open/close banner (name/log/log type/opened on
        # cluster).  A lone "name: ..." output line is user output.
        if _banner_at(raw_lines, i):
            if _is_log_rule(line):
                i += 1
            i = _skip_log_metadata(raw_lines, i)
            continue

        # Skip SMCL structural markers that do not render visible content.
        stripped = line.strip()
        if stripped in ("{smcl}", "{.-}", "") or \
           re.match(r'^(?:\{(?:com|txt|sf|ul off|smcl|\.-)\})+$', stripped):
            i += 1
            continue

        if ltype == "command" or ltype == "continuation":
            # Extract clean command text to check for log commands
            cmd_clean = re.sub(r'\{[^}]*\}', '', line).strip()
            if re.match(r'\.\s*log\s+(close|using|open|off|on)\b',
                        cmd_clean):
                # Skip log open/close commands and their metadata
                i += 1
                while i < n and (_is_log_metadata(raw_lines[i]) or
                                 _is_wrap_continuation(raw_lines[i])):
                    i += 1
                # a text log closes its banner with a rule of dashes
                if i < n and _is_log_rule(raw_lines[i]):
                    i += 1
                if i < n and raw_lines[i].strip() == "":
                    i += 1
                continue

            block = Block("command")
            # Gather the command and any continuation lines
            block.raw_lines.append(line)
            i += 1
            while i < n:
                if _is_command_continuation(block.raw_lines[-1],
                                            raw_lines[i], is_smcl,
                                            wrap_width):
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
            # Gather until table_bottom.  A {c TT} with no {c BT} before the
            # next command (or the end of the log) is not a table: keep it
            # as ordinary output and leave the command to the main loop.
            closed = False
            while i < n:
                ntype = classify_raw_line(raw_lines[i])
                if ntype in ("command", "continuation", "command_blank"):
                    break
                block.raw_lines.append(raw_lines[i])
                i += 1
                if ntype == "table_bottom":
                    closed = True
                    break
            if not closed:
                block.kind = "output"
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
            if ntype in ("output", "blank", "plain_continuation") and \
                    not _banner_at(raw_lines, i):
                block.raw_lines.append(raw_lines[i])
                i += 1
            else:
                break
        blocks.append(block)

    # one layout state per source document ({p2colset} carries across
    # its lines, never into another file of a combined document)
    state = new_smcl_state()
    for block in blocks:
        block.state = state

    return blocks


def _is_log_metadata(line):
    """Check if line is part of log open/close metadata."""
    stripped = line.strip()
    # Remove leading SMCL tags
    clean = re.sub(r'\{[^}]*\}', '', stripped).strip()
    return bool(re.match(
        r'(name|log|log type|opened on|closed on|paused on|resumed on):\s+',
        clean))


def _is_log_banner(lines, start):
    """True when the metadata-looking line at `start` opens a log banner.

    Stata's log open/close banner is a cluster of name:/log:/log type:/
    opened on:/closed on: lines.  It counts as a banner only when the
    cluster has a "log type:" line and an "opened on:"/"closed on:" line, so
    user output such as "name: John Smith" is kept.
    """
    keys = set()
    i = start
    while i < len(lines) and _is_log_metadata(lines[i]):
        clean = re.sub(r'\{[^}]*\}', '', lines[i]).strip()
        keys.add(clean.split(":", 1)[0])
        i += 1
        while i < len(lines) and _is_wrap_continuation(lines[i]):
            i += 1
    return "log type" in keys and bool(
        keys & {"opened on", "closed on", "paused on", "resumed on"})


def _is_log_rule(line):
    """A plain-text log's banner rule: a line of dashes only."""
    clean = re.sub(r'\{[^}]*\}', '', line).strip()
    return bool(re.fullmatch(r'-{20,}', clean))


def _banner_at(lines, i):
    """True when a log open/close banner (or its leading rule) is at i."""
    if _is_log_metadata(lines[i]):
        return _is_log_banner(lines, i)
    return (_is_log_rule(lines[i]) and i + 1 < len(lines) and
            _is_log_metadata(lines[i + 1]) and _is_log_banner(lines, i + 1))


def _skip_log_metadata(lines, start):
    """Skip a log metadata block starting at `start`."""
    i = start
    while i < len(lines):
        if _is_log_metadata(lines[i]):
            i += 1
            # a long log path wraps onto "> " lines
            while i < len(lines) and _is_wrap_continuation(lines[i]):
                i += 1
            continue
        if _is_log_rule(lines[i]):
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
# F6: Selective output via keep/drop filtering
# ---------------------------------------------------------------------------

def filter_blocks(blocks, keep=None, drop=None):
    """Filter blocks by keep/drop patterns on command text.

    Patterns are pipe-delimited strings matched via re.search against the
    plain command text (dots stripped).

    For keep: retain only matching command blocks and their trailing
    non-command blocks (output, table, error) until the next command.
    For drop: remove matching command blocks and their trailing non-command
    blocks until the next command.

    Keep is applied first, then drop.
    """
    if not keep and not drop:
        return blocks

    for _label, _pat_str in [("keep", keep), ("drop", drop)]:
        if _pat_str:
            for _p in _pat_str.split("|"):
                try:
                    re.compile(_p)
                except re.error as exc:
                    print_metadata(0, 0)
                    print(f"Error: invalid {_label} regex '{_p}': {exc}",
                          file=sys.stderr)
                    sys.exit(1)

    def _group_blocks(blocks):
        """Group blocks into (command_block, [trailing_blocks]) tuples.

        Non-command blocks before the first command are returned as a group
        with command_block=None.
        """
        groups = []
        current_cmd = None
        current_trailing = []
        for block in blocks:
            if block.kind == "command":
                if current_cmd is not None or current_trailing:
                    groups.append((current_cmd, current_trailing))
                current_cmd = block
                current_trailing = []
            else:
                current_trailing.append(block)
        if current_cmd is not None or current_trailing:
            groups.append((current_cmd, current_trailing))
        return groups

    def _cmd_text(block):
        """Extract clean command text from a command block."""
        if block is None:
            return ""
        return " ".join(
            extract_command_text(raw_line, strip_dots=True)
            for raw_line in block.raw_lines
        )

    groups = _group_blocks(blocks)

    # Apply keep filter
    if keep:
        keep_patterns = keep.split("|")
        filtered = []
        for cmd_block, trailing in groups:
            if cmd_block is None:
                # Pre-command blocks: always keep
                filtered.append((cmd_block, trailing))
                continue
            text = _cmd_text(cmd_block)
            if any(re.search(pat, text) for pat in keep_patterns):
                filtered.append((cmd_block, trailing))
        groups = filtered

    # Apply drop filter
    if drop:
        drop_patterns = drop.split("|")
        filtered = []
        for cmd_block, trailing in groups:
            if cmd_block is None:
                filtered.append((cmd_block, trailing))
                continue
            text = _cmd_text(cmd_block)
            if not any(re.search(pat, text) for pat in drop_patterns):
                filtered.append((cmd_block, trailing))
        groups = filtered

    # Flatten groups back to block list
    result = []
    for cmd_block, trailing in groups:
        if cmd_block is not None:
            result.append(cmd_block)
        result.extend(trailing)
    return result


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


# Directive forms below were checked one by one against Stata's own
# translate (smcl2log): Stata interprets a directive only in the forms its
# manual ([P] smcl) defines and prints any other form -- {lm}, {sub:E},
# {braces}, {"a": 1}, {foo:bar}, {opt}, {ul} -- literally, braces included.

# Colour/mode directives: {res}, {res:text}.  The span class they open in
# HTML; None is plain text.
_SMCL_COLOR_CLASSES = {
    "com": "cmd", "cmd": "cmd", "input": "cmd", "inp": "cmd",
    "res": "res", "result": "res", "hi": "res", "hilite": "res",
    "err": "err", "error": "err",
    "txt": None, "text": None,
}
# Font directives: {bf}, {bf:text}.  As switches they change the face, not
# the colour, so they never close a colour span ({err}x {bf}y{sf} z stays
# in err).  Only the inline form is styled.
_SMCL_FONT_TAGS = {
    "bf": ("<strong>", "</strong>"), "it": ("<em>", "</em>"),
    "sf": ("", ""), "rm": ("", ""),
}
# Syntax placeholders: {varname} -> varname, {varname:x} -> varnamex.
_SMCL_PLACEHOLDERS = {
    "var": "varname", "varname": "varname", "varlist": "varlist",
    "vars": "varlist", "depvar": "depvar", "depvars": "depvars",
    "depvarlist": "depvarlist", "indepvars": "indepvars", "newvar": "newvar",
}
# No-argument fixed text: {ifin} -> [if] [in].
_SMCL_FIXED = {"ifin": "[if] [in]", "weight": "[weight]", "dtype": "[type]"}
# Links shown as their text, or their argument when there is no text:
# {help a:T} -> T, {browse "http://x"} -> http://x.
_SMCL_LINKS = {
    "help", "helpb", "search", "view", "net", "ado", "update", "dialog",
    "browse", "stata", "matacmd", "mansection", "manpage",
}
# Directives valid only as {name:text}; they show the text.
_SMCL_TEXT_ONLY = {
    "title", "bind", "dlgtab", "help_d", "search_d", "view_d", "net_d",
    "netfrom_d", "ado_d", "update_d", "back", "clearmore", "right",
    "center", "centre", "rcenter", "rcentre", "syntab",
}
# Argument-free directives with no visible output.
_SMCL_SILENT = {
    "smcl", "asis", "s6hlp", "reset", "...", ".-", "p_end", "p2line",
    "p2colreset", "synoptset", "break",
}
# Paragraph directives and their first-line indent.
_SMCL_PARA_INDENT = {
    "pstd": 4, "psee": 4, "phang": 4, "pmore": 8, "pin": 8, "phang2": 8,
    "pmore2": 12, "pin2": 12, "phang3": 12, "pmore3": 16, "pin3": 16,
}
_SMCL_PARA_START_RE = re.compile(
    r'\{(?:p(?:\s+\d+)*|pstd|psee|phang[23]?|pmore[23]?|pin[23]?)\}')

# Upper bound on any repeat count ({dup}, {hline}, {space}, {col}): a
# hostile count must not exhaust memory.
SMCL_MAX_REPEAT = 10000

# {p2col} column layout: (first col, second col, continuation col), 1-based.
# Stata's default layout puts the second column at 31 (verified against
# translate smcl2log); {p2colset} overrides it until {p2colreset}.
_P2COL_DEFAULT = (1, 31, 33)


def new_smcl_state():
    """Fresh layout state for one source document."""
    return {"p2col": _P2COL_DEFAULT}


def _split_smcl_tag(tag_inner):
    """Split a directive into (name, args, text-or-None).

    The text starts after the first colon outside double quotes and nested
    braces, so {browse "http://x.org":label} keeps the URL in its args.
    """
    depth = 0
    in_quote = False
    head, text = tag_inner, None
    for k, ch in enumerate(tag_inner):
        if ch == '"':
            in_quote = not in_quote
        elif in_quote:
            continue
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
        elif ch == ':' and depth == 0:
            head, text = tag_inner[:k], tag_inner[k + 1:]
            break
    parts = head.strip().split(None, 1)
    name = parts[0] if parts else ""
    args = parts[1].strip() if len(parts) > 1 else ""
    return name, args, text


def _vis_len(text, mode):
    """Visible width of expanded text: tags removed, entities unescaped."""
    if mode == "html":
        return len(html_mod.unescape(re.sub(r'<[^>]+>', '', text)))
    return len(text)


def _unquote_args(args):
    """A link argument as Stata shows it: surrounding quotes removed."""
    m = re.fullmatch(r'"([^"]*)"', args.strip())
    return m.group(1) if m else args.strip()


def _repeat(n):
    return min(max(0, n), SMCL_MAX_REPEAT)


def expand_smcl_line(line, mode="text", state=None):
    """Expand SMCL tags in a single line.

    mode="text": strip all tags to plain text (Markdown fences, LaTeX)
    mode="html": convert style tags to HTML spans
    state: layout state shared by the lines of one document ({p2colset});
    a fresh state is used when omitted.

    A directive in a form Stata does not define is output text, as in
    Stata's own rendering.
    """
    if state is None:
        state = new_smcl_state()
    result = []
    col = 0
    i = 0
    current_style = None

    def emit_text(text):
        nonlocal col
        result.append(html_mod.escape(text) if mode == "html" else text)
        col += len(text)

    def emit_expanded(inner):
        nonlocal col
        result.append(inner)
        col += _vis_len(inner, mode)

    def expand(text):
        return expand_smcl_line(text, mode, state)

    while i < len(line):
        if line[i] != '{':
            emit_text(line[i])
            i += 1
            continue

        j = _find_matching_brace(line, i)
        if j == -1:
            emit_text(line[i])
            i += 1
            continue
        tag_full = line[i:j+1]
        tag_inner = line[i+1:j]
        i = j + 1
        name, args, text = _split_smcl_tag(tag_inner)
        plain = text is None and not args

        # {col N} -- move to column N (1-based).  Stata adds no space when
        # the output is already at or past column N.
        m = re.fullmatch(r'col\s+(\d+)', tag_inner)
        if m:
            spaces = max(0, _repeat(int(m.group(1))) - 1 - col)
            result.append(' ' * spaces)
            col += spaces
            continue

        # {hline N} / {hline}
        m = re.fullmatch(r'hline(?:\s+(\d+))?', tag_inner)
        if m:
            n = _repeat(int(m.group(1))) if m.group(1) else 79
            result.append('─' * n)
            col += n
            continue

        # {space N}
        m = re.fullmatch(r'space\s+(\d+)', tag_inner)
        if m:
            n = _repeat(int(m.group(1)))
            result.append(' ' * n)
            col += n
            continue

        # {tab}: to the next multiple of 8
        if name == "tab" and plain:
            n = 8 - col % 8
            result.append(' ' * n)
            col += n
            continue

        # Box-drawing and named characters {c XX}
        if tag_full in SMCL_CHAR_MAP:
            emit_text(SMCL_CHAR_MAP[tag_full])
            continue
        # {c 0xNN} / {c NNN} / {char NNN}: character by code
        m = re.fullmatch(r'(?:c|char)\s+(0x[0-9a-fA-F]+|\d+)', tag_inner)
        if m:
            try:
                emit_text(chr(int(m.group(1), 0)))
            except (ValueError, OverflowError):
                emit_text(tag_full)
            continue

        # {lalign N:text}, {ralign N:text}, {center N:text}, {rcenter N:text}
        m = re.fullmatch(r'(lalign|ralign|center|centre|rcenter|rcentre)'
                         r'\s+(\d+):(.*)', tag_inner, re.DOTALL)
        if m:
            align = m.group(1)
            width = _repeat(int(m.group(2)))
            inner = expand(m.group(3))
            pad = max(0, width - _vis_len(inner, mode))
            if align == "ralign":
                rendered = ' ' * pad + inner
            elif align == "lalign":
                rendered = inner + ' ' * pad
            else:
                left = (pad + 1) // 2 if align.startswith("r") else pad // 2
                rendered = ' ' * left + inner + ' ' * (pad - left)
            emit_expanded(rendered)
            continue

        # {dup N:text} → text repeated N times (bounded)
        if name == "dup" and text is not None and re.fullmatch(r'\d+', args):
            inner = expand(text)
            count = _repeat(int(args))
            if _vis_len(inner, mode) > 0:
                count = min(count,
                            max(1, SMCL_MAX_REPEAT // _vis_len(inner, mode)))
            emit_expanded(inner * count)
            continue

        # Colour directives: {res:x} inline, {res} switch
        if name in _SMCL_COLOR_CLASSES and not args:
            cls = _SMCL_COLOR_CLASSES[name]
            if text is not None:
                inner = expand(text)
                if mode == "html" and cls:
                    result.append(f'<span class="{cls}">{inner}</span>')
                    col += _vis_len(inner, mode)
                else:
                    emit_expanded(inner)
            elif mode == "html":
                if current_style:
                    result.append('</span>')
                    current_style = None
                if cls:
                    result.append(f'<span class="{cls}">')
                    current_style = cls
            continue

        # Font directives: {bf:x} inline; {bf}/{sf}/{it}/{rm} switches
        # change the face only and are dropped.
        if name in _SMCL_FONT_TAGS and not args:
            if text is not None:
                inner = expand(text)
                open_tag, close_tag = _SMCL_FONT_TAGS[name]
                if mode == "html" and open_tag:
                    result.append(f"{open_tag}{inner}{close_tag}")
                    col += _vis_len(inner, mode)
                else:
                    emit_expanded(inner)
            continue

        # {ul:x} inline; {ul on}/{ul off} switches ({ul} alone is literal)
        if name == "ul":
            if text is not None and not args:
                inner = expand(text)
                if mode == "html":
                    result.append(f"<u>{inner}</u>")
                    col += _vis_len(inner, mode)
                else:
                    emit_expanded(inner)
                continue
            if text is None and args in ("on", "off"):
                continue

        # Syntax placeholders and fixed syntax text
        if name in _SMCL_PLACEHOLDERS and not args:
            emit_text(_SMCL_PLACEHOLDERS[name])
            if text is not None:
                emit_expanded(expand(text))
            continue
        if name in _SMCL_FIXED and plain:
            emit_text(_SMCL_FIXED[name])
            continue

        # Links: {help a}, {help a:T}, {help "a b"}, {browse "url":T}
        if (name in _SMCL_LINKS and args) or (
                name == "update" and text is not None and not args):
            shown = _unquote_args(args)
            if name in ("help", "helpb") and mode == "html":
                topic = re.sub(r'##\|_new$', '', shown)
                inner = (expand(text) if text is not None
                         else html_mod.escape(shown, quote=True))
                if name == "helpb":
                    inner = f"<strong>{inner}</strong>"
                url = html_mod.escape(
                    f"https://www.stata.com/help.cgi?{topic}", quote=True)
                result.append(f'<a href="{url}" class="help-link">{inner}</a>')
                col += _vis_len(inner, mode)
            elif text is not None:
                emit_expanded(expand(text))
            else:
                emit_text(shown)
            continue

        # {manhelp topic SECTION[:text]} → [SECTION] topic|text
        if name in ("manhelp", "manhelpi") and len(args.split()) >= 2:
            topic, section = args.split()[:2]
            emit_text(f"[{section}] " + (text if text is not None else topic))
            continue
        # {manlink SECTION entry} → [SECTION] entry (the colon is literal)
        if name in ("manlink", "manlinki") and (args or text is not None):
            rest = tag_inner.strip()[len(name):].strip()
            parts = rest.split(None, 1)
            emit_text(f"[{parts[0]}] " + (parts[1] if len(parts) > 1 else ""))
            continue

        # {opt name[:rest]} → name+rest; {opth name(arg)} → name(arg)
        if name == "opt" and args:
            emit_text(args + (text if text is not None else ""))
            continue
        if name == "opth" and "(" in args and text is None:
            emit_text(args)
            continue
        # {cmdab:reg:ress} → regress (the colon marks the abbreviation)
        if name == "cmdab" and text is not None and not args:
            emit_expanded(expand(text.replace(":", "")))
            continue

        # Text-only directives: {title:x}, {bind:x}, {right:x}, ...
        if name in _SMCL_TEXT_ONLY and text is not None and not args:
            emit_expanded(expand(text))
            continue

        # {p2colset # # # #} / {p2col [# # # #]:first}second
        if name == "p2colset" and text is None:
            nums = [int(x) for x in re.findall(r'\d+', args)]
            if len(nums) >= 3:
                state["p2col"] = tuple(_repeat(x) for x in nums[:3])
            continue
        if name in ("p2col", "synopt", "p2coldent") and text is not None:
            nums = [_repeat(int(x)) for x in re.findall(r'\d+', args)]
            c1, c2, c3 = (tuple(nums[:3]) if len(nums) >= 3
                          else state["p2col"])
            pad = max(0, c1 - 1 - col)
            result.append(' ' * pad)
            col += pad
            emit_expanded(expand(text))
            if col < c2 - 1:
                result.append(' ' * (c2 - 1 - col))
                col = c2 - 1
            else:
                # first column too wide: the second column starts on a new
                # line at the continuation column
                result.append('\n' + ' ' * (c3 - 1))
                col = c3 - 1
            continue

        # Paragraph directives: indent the (joined) paragraph's first line
        if text is None and (
                (name == "p" and re.fullmatch(r'[\d\s]*', args)) or
                (name in _SMCL_PARA_INDENT and not args)):
            nums = re.findall(r'\d+', args)
            indent = (int(nums[0]) if nums else 0) if name == "p" \
                else _SMCL_PARA_INDENT[name]
            pad = max(0, _repeat(indent) - col)
            result.append(' ' * pad)
            col += pad
            continue

        # Directives with no visible output
        if name in _SMCL_SILENT and plain:
            continue
        if name == "marker" and ((args and len(args.split()) == 1
                                  and text is None) or
                                 (text is not None and not args)):
            continue
        if name in ("viewerjumpto", "vieweralsosee", "viewerdialog") and \
                len(args.split()) >= 2:
            continue
        if name == "ccl" and args and text is None:
            # current-value class: the value is not in the log
            continue

        # Any other form is literal output, as in Stata
        emit_text(tag_full)

    # Close any open style span
    if mode == "html" and current_style:
        result.append('</span>')

    return ''.join(result)


_SEP_CHARS = set("─┬┼┴│├┤┌┐└┘")


def expand_block(block, mode="text"):
    """Expand all raw_lines in a block, set block.lines.

    Trailing blanks are dropped, except on an output line the log wrapped:
    there they are part of the line, and the "> " continuation that follows
    lines up with it only if they are kept.
    """
    raws = block.raw_lines
    block.lines = []
    for k, raw_line in enumerate(raws):
        line = expand_smcl_line(raw_line, mode, block.state)
        wrapped = (block.kind == "output" and k + 1 < len(raws)
                   and _is_wrap_continuation(raws[k + 1]))
        block.lines.append(line.rstrip("\r\n") if wrapped else line.rstrip())


def extract_command_text(line, strip_dots=False):
    """Extract the command text from a raw SMCL command line."""
    # A loop-body echo "{txt}  2{com}.     cmd" keeps its "2. " prompt
    text = re.sub(r'^((?:\{[^}]*\})*\s*\d+)(?:\{[^}]*\})*\.\s+', r'\1. ',
                  line.strip())
    # Remove {com}. prefix
    text = re.sub(r'\{com\}\.\s*', '', text)
    # Remove {com}> prefix for continuations
    text = re.sub(r'\{com\}>\s*', '', text)
    # Strip remaining tags; escaped literal braces ({c -(}, {c )-}) are
    # command text, so restore them rather than dropping them
    text = text.replace("{c -(}", "\x00").replace("{c )-}", "\x01")
    text = re.sub(r'\{[^}]*\}', '', text)
    text = text.replace("\x00", "{").replace("\x01", "}")
    # Remove trailing ///
    text = re.sub(r'\s*///\s*$', '', text)
    text = text.strip()
    if strip_dots:
        # Remove leading ". ", "> " or loop-body "2. " prompt
        text = re.sub(r'^(?:\d+\.\s+|[.>]\s*)', '', text)
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
        parts = [part.strip() for part in line.split('│')]
        # Border pipes create empty edge cells; internal empty cells are data.
        if parts and not parts[0]:
            parts = parts[1:]
        if parts and not parts[-1]:
            parts = parts[:-1]
        return parts

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

    headers = [split_at_pipes(line) for line in header_lines]
    rows = [split_at_pipes(line) for line in body_lines]

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
    # Stata missing values: ., .a, .b, ..., .z
    if re.match(r'^\.[a-z]?$', s):
        return True
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
    # Strip colon-suffixed prefixes (svy:, xi:, bootstrap:, jackknife:, etc.)
    if cmd_lower.endswith(":") and len(words) > 1:
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

# Graph files a browser can show in <img> (HTML) or Markdown ![](...).
IMAGE_GRAPH_EXTS = {
    ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
    ".gif": "image/gif", ".svg": "image/svg+xml",
}
# Graph files the LaTeX output references with \includegraphics.  The file
# is referenced by path, never read.  Only types pdflatex handles with the
# graphicx package alone: .svg and .gif are not (svg needs the svg package
# plus Inkscape; gif is unsupported), so those exports are skipped and
# counted as warnings.  .eps works through graphicx's automatic epstopdf.
LATEX_GRAPH_EXTS = {".png", ".jpg", ".jpeg", ".pdf", ".eps"}
LATEX_SKIPPED_EXTS = {".svg", ".gif"}


def _graph_export_failed(blocks, idx):
    """True when the output of the command at `idx` reports an error."""
    for block in blocks[idx + 1:_graph_group_end(blocks, idx)]:
        if block.kind == "command":
            continue
        if block.kind == "error":
            return True
        for raw in block.raw_lines:
            clean = re.sub(r'\{[^}]*\}', '', raw).strip()
            if re.match(r'r\(\d+\);$', clean):
                return True
    return False


# Stata's graph export formats and the file extension each corresponds to.
_GRAPH_FORMAT_EXTS = {
    "png": ".png", "jpg": ".jpg", "jpeg": ".jpg", "gif": ".gif",
    "svg": ".svg", "pdf": ".pdf", "eps": ".eps", "ps": ".ps",
    "tif": ".tif", "tiff": ".tif", "emf": ".emf", "wmf": ".wmf",
}
# "graph export" as Stata accepts it: graph or gr (gra/grap are not valid
# abbreviations; Stata reports them as unrecognized commands).
_GRAPH_EXPORT_RE = re.compile(r'(?:^|[\s;:])(?:graph|gr)\s+export\s+(.*)$',
                              re.IGNORECASE)
# Stata's success note, e.g. "file x.png written in PNG format" (also
# "saved as ... format", with or without parentheses).
_GRAPH_SAVED_RE = re.compile(
    r'^\(?file (.+?) (?:written in|saved as) ([A-Za-z0-9]+) format\)?$')


class GraphRef(str):
    """A graph file name that also carries its export format extension."""
    ext = ""


def _graph_ref(filename, ext):
    ref = GraphRef(filename)
    ref.ext = ext
    return ref


def _is_loop_body_echo(block):
    """A command block echoing a numbered loop/program line ("  2. cmd")."""
    return block.kind == "command" and bool(re.match(
        r'\s*\d+\.\s', extract_command_text(block.raw_lines[0])))


def _graph_group_end(blocks, idx):
    """End (exclusive) of the command at idx with its output, extended over
    the numbered loop-body echoes that follow it."""
    j = idx + 1
    while j < len(blocks) and (blocks[j].kind != "command" or
                               _is_loop_body_echo(blocks[j])):
        j += 1
    return j


def _group_command_texts(blocks, idx):
    """Command texts of the command at idx, including numbered loop-body
    echoes ("  2. graph export ...") that follow it."""
    end = _graph_group_end(blocks, idx)
    texts = []
    for block in blocks[idx:end]:
        if block.kind == "command":
            texts.append(" ".join(extract_command_text(raw, strip_dots=True)
                                  for raw in block.raw_lines))
            continue
        for raw in block.raw_lines:
            clean = expand_smcl_line(raw, "text", block.state)
            m = re.match(r'\s*\d+\.\s+(.*)$', clean)
            if m:
                texts.append(m.group(1).strip())
    return texts


def _graph_saved_notes(blocks, idx):
    """(filename, extension) from Stata's success notes after idx."""
    notes = []
    for block in blocks[idx + 1:_graph_group_end(blocks, idx)]:
        if block.kind == "command":
            continue
        for raw in block.raw_lines:
            clean = expand_smcl_line(raw, "text", block.state).strip()
            m = _GRAPH_SAVED_RE.match(clean)
            if m:
                ext = _GRAPH_FORMAT_EXTS.get(m.group(2).lower())
                if ext:
                    notes.append((m.group(1), ext))
    return notes


def _graph_export_target(args):
    """(filename, extension) from the arguments of a graph export command,
    or None when the name cannot be read from the echo (a macro)."""
    m = re.match(r'\s*(?:"([^"]+)"|([^\s,]+))(.*)$', args)
    if not m:
        return None
    filename = m.group(1) or m.group(2)
    if "`" in filename or "$" in filename:
        return None
    fmt = re.search(r'\bas\(\s*([A-Za-z0-9]+)\s*\)', m.group(3))
    if fmt:
        ext = _GRAPH_FORMAT_EXTS.get(fmt.group(1).lower(), "")
    else:
        ext = os.path.splitext(filename)[1].lower()
        ext = _GRAPH_FORMAT_EXTS.get(ext.lstrip("."), ext)
    return filename, ext


def detect_graph_exports(blocks, nograph=False, exts=None):
    """Find graph exports as ordered (filename, block_index) pairs.

    The files are read from Stata's own "file ... written in FORMAT format"
    notes when present (they name the real file even inside loops and with
    as() and no extension); otherwise from the export command itself.  Only
    exports whose format the target can show are returned (`exts`, default:
    browser image types).  A failed export, or one naming a non-image file,
    is never embedded or linked.  Each filename is a GraphRef carrying its
    format extension.
    """
    if nograph:
        return []
    if exts is None:
        exts = IMAGE_GRAPH_EXTS
    graph_files = []
    covered = 0
    for idx, block in enumerate(blocks):
        if block.kind != "command" or idx < covered:
            continue
        covered = _graph_group_end(blocks, idx)
        exports = []
        for text in _group_command_texts(blocks, idx):
            # Skip comments: they can mention "graph export" in prose
            if text.startswith("*") or text.startswith("//"):
                continue
            m = _GRAPH_EXPORT_RE.search(text)
            if m:
                exports.append(m.group(1))
        if not exports:
            continue
        found = _graph_saved_notes(blocks, idx)
        if not found:
            if _graph_export_failed(blocks, idx):
                continue
            found = [t for t in (_graph_export_target(a) for a in exports)
                     if t is not None]
        for filename, ext in found:
            if ext in exts:
                graph_files.append((_graph_ref(filename, ext), idx))
    return graph_files


def _resolve_graph_path(filepath, base_dir):
    """Return an absolute graph path if it exists, otherwise None.

    A relative path is tried against base_dir (the input's directory, or the
    execution directory for run/live capture), then against the current
    working directory, which is Stata's c(pwd) when logdoc shells out. The
    second lookup covers a log written to a subdirectory while graphs were
    exported relative to the project root.
    """
    filepath = filepath.replace('\\', '/')
    if os.path.isabs(filepath):
        return filepath if os.path.isfile(filepath) else None
    for root in (base_dir, os.getcwd()):
        candidate = os.path.join(root, filepath)
        if os.path.isfile(candidate):
            return os.path.abspath(candidate)
    return None


def embed_image_base64(filepath, base_dir):
    """Read an image file and return a base64 data URI, or None."""
    ext = getattr(filepath, "ext", "") or \
        os.path.splitext(filepath)[1].lower()
    filepath = _resolve_graph_path(filepath, base_dir)
    if filepath is None:
        return None

    mime = IMAGE_GRAPH_EXTS.get(ext)
    if mime is None:
        return None

    try:
        with open(filepath, "rb") as f:
            data = base64.b64encode(f.read()).decode("ascii")
    except (IOError, OSError):
        return None

    return f"data:{mime};base64,{data}"


# ---------------------------------------------------------------------------
# Stage 6: HTML Renderer
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# C7: Annotation parsing
# ---------------------------------------------------------------------------

def parse_annotations(filepath):
    """Parse an annotation file into a dict.

    Format:
        @block 1: This is a note about the first command
        @block 3: This highlights the third block
        @command "regress": Note about all regression commands

    Returns:
        { 'block': {1: 'note', 3: 'note'},
          'command': {'regress': 'note'} }
    """
    annotations = {'block': {}, 'command': {}}
    if not filepath or not os.path.isfile(filepath):
        return annotations
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            m = re.match(r'@block\s+(\d+):\s*(.+)', line)
            if m:
                annotations['block'][int(m.group(1))] = m.group(2)
                continue
            m = re.match(r'@command\s+"([^"]+)":\s*(.+)', line)
            if m:
                annotations['command'][m.group(1)] = m.group(2)
                continue
    return annotations


def get_annotation_html(block_index, command_text, annotations):
    """Return annotation HTML for a given block if any annotation matches."""
    parts = []
    # Check block-number annotations (1-based index)
    if block_index in annotations.get('block', {}):
        text = annotations['block'][block_index]
        parts.append(
            f'<aside class="annotation">{html_mod.escape(text)}</aside>'
        )
    # Check command-pattern annotations
    for pattern, text in annotations.get('command', {}).items():
        if pattern in command_text:
            parts.append(
                f'<aside class="annotation">{html_mod.escape(text)}</aside>'
            )
    return '\n'.join(parts)


# ---------------------------------------------------------------------------
# C3: Email-safe inline style mapping
# ---------------------------------------------------------------------------

_EMAIL_INLINE_STYLES = {
    'logdoc': 'max-width:900px;margin:0 auto;padding:2rem 1.5rem;',
    'logdoc-header': 'margin-bottom:2rem;padding-bottom:1rem;border-bottom:2px solid #dee2e6;',
    'code-block': 'position:relative;margin:1rem 0 0.25rem 0;padding:0.75rem 1rem;background:#f8f9fa;border-left:3px solid #4582ec;border-radius:0 4px 4px 0;overflow-x:auto;',
    'output-block': 'margin:0 0 1rem 0;padding:0.5rem 1rem;overflow-x:auto;',
    'comment-block': 'margin:0.5rem 0;padding:0.25rem 1rem;color:#6c757d;font-style:italic;font-size:0.875rem;',
    'error-block': 'margin:0.5rem 0 1rem 0;padding:0.75rem 1rem;background:#fff5f5;border-left:3px solid #e74c3c;border-radius:0 4px 4px 0;overflow-x:auto;',
    'table-block': 'margin:0.5rem 0 1.5rem 0;overflow-x:auto;',
    'fold-block': 'margin:0 0 1rem 0;border:1px solid #e9ecef;border-radius:4px;',
    'graph-figure': 'margin:1rem 0 1.5rem 0;text-align:center;',
    'graph-missing': 'margin:0.5rem 0;padding:0.75rem 1rem;background:#fff3cd;border-left:3px solid #ffc107;border-radius:0 4px 4px 0;color:#856404;font-size:0.875rem;',
    'section-header': 'margin:2rem 0 1rem 0;padding-bottom:0.5rem;border-bottom:1px solid #dee2e6;color:#212529;font-size:1.25rem;font-weight:600;',
    'logdoc-footer': 'margin-top:3rem;padding-top:1rem;border-top:1px solid #dee2e6;font-size:0.75rem;color:#adb5bd;text-align:center;',
    'logdoc-toc': 'margin-bottom:2rem;padding:1rem 1.5rem;background:#f8f9fa;border:1px solid #dee2e6;border-radius:4px;',
    'stamp': 'font-size:0.6875rem;color:#adb5bd;margin-top:0.25rem;font-family:monospace;',
    'subtitle': 'font-size:0.9375rem;color:#6c757d;margin-top:0.25rem;',
    'notebook-cell': 'border:1px solid #e9ecef;border-radius:4px;margin:1rem 0;overflow:hidden;',
    'cell-number': 'padding:0.25rem 0.75rem;font-family:monospace;font-size:0.75rem;color:#6c757d;',
    'annotation': 'background:#fff3cd;border-left:3px solid #ffc107;padding:0.5rem 1rem;margin:0.25rem 0;font-size:0.875rem;',
    'cmd': 'color:#212529;font-weight:600;',
    'res': 'color:#212529;',
    'err': 'color:#c0392b;',
    'error-source': 'border-left-color:#e74c3c;background:#fff5f5;',
}


def _inline_css(html_str):
    """Replace class="X" with style="..." for email-safe HTML.

    Removes the <style> block entirely.
    """
    # Remove <style>...</style>
    result = re.sub(r'<style>[\s\S]*?</style>', '', html_str)
    # Replace class="classname" with style="..."
    def _replace_class(match):
        classes = match.group(1).split()
        styles = []
        for cls in classes:
            if cls in _EMAIL_INLINE_STYLES:
                styles.append(_EMAIL_INLINE_STYLES[cls])
        if styles:
            return f'style="{" ".join(styles)}"'
        return match.group(0)

    result = re.sub(r'class="([^"]+)"', _replace_class, result)
    return result


# ---------------------------------------------------------------------------
# C2: Diff rendering
# ---------------------------------------------------------------------------

def render_diff_html(blocks_a, blocks_b, title="Diff View", theme_css="",
                     base_dir=".", generated=False, file_a="", file_b=""):
    """Render a diff view comparing two sets of blocks."""
    for b in blocks_a:
        expand_block(b, mode="html")
    for b in blocks_b:
        expand_block(b, mode="html")

    texts_a = ['\n'.join(b.lines) for b in blocks_a]
    texts_b = ['\n'.join(b.lines) for b in blocks_b]

    label_a = os.path.basename(file_a) if file_a else "File A"
    label_b = os.path.basename(file_b) if file_b else "File B"

    matcher = difflib.SequenceMatcher(None, texts_a, texts_b)
    parts = []

    for op, i1, i2, j1, j2 in matcher.get_opcodes():
        if op == 'equal':
            for b in blocks_a[i1:i2]:
                content = '\n'.join(b.lines)
                parts.append(
                    f'<div class="output-block diff-context">'
                    f'<pre>{content}</pre></div>'
                )
        elif op == 'replace':
            parts.append('<div class="diff-group">')
            parts.append(
                f'<div class="diff-label">− {html_mod.escape(label_a)}</div>')
            for b in blocks_a[i1:i2]:
                content = '\n'.join(b.lines)
                parts.append(
                    f'<div class="output-block diff-removed">'
                    f'<pre>{content}</pre></div>'
                )
            parts.append(
                f'<div class="diff-label">+ {html_mod.escape(label_b)}</div>')
            for b in blocks_b[j1:j2]:
                content = '\n'.join(b.lines)
                parts.append(
                    f'<div class="output-block diff-added">'
                    f'<pre>{content}</pre></div>'
                )
            parts.append('</div>')
        elif op == 'delete':
            parts.append('<div class="diff-group">')
            parts.append(
                f'<div class="diff-label">− {html_mod.escape(label_a)}</div>')
            for b in blocks_a[i1:i2]:
                content = '\n'.join(b.lines)
                parts.append(
                    f'<div class="output-block diff-removed">'
                    f'<pre>{content}</pre></div>'
                )
            parts.append('</div>')
        elif op == 'insert':
            parts.append('<div class="diff-group">')
            parts.append(
                f'<div class="diff-label">+ {html_mod.escape(label_b)}</div>')
            for b in blocks_b[j1:j2]:
                content = '\n'.join(b.lines)
                parts.append(
                    f'<div class="output-block diff-added">'
                    f'<pre>{content}</pre></div>'
                )
            parts.append('</div>')

    body = '\n'.join(parts)
    escaped_title = html_mod.escape(title)
    esc_a = html_mod.escape(label_a)
    esc_b = html_mod.escape(label_b)

    footer_block = ""
    if generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        footer_block = f"""
<footer class="logdoc-footer">
<p>Generated {timestamp}</p>
</footer>"""

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
<h1>{escaped_title}</h1>
<div class="diff-legend">
<span><span class="swatch" style="background:#f8d7da;border:1px solid #dc3545;"></span> − {esc_a}</span>
<span><span class="swatch" style="background:#d4edda;border:1px solid #28a745;"></span> + {esc_b}</span>
<span>Dimmed = unchanged</span>
</div>
</header>
<main class="logdoc-body">
{body}
</main>{footer_block}
</article>
</body>
</html>"""


# ---------------------------------------------------------------------------
# O3: Estimation table detection and parsing
# ---------------------------------------------------------------------------

_EST_HEADER_PATTERN = re.compile(
    r'(?:Coef\.|Coefficient|Std\.\s*err\.|Std\.\s*Err\.|[zt]\b|P>|'
    r'\[95%|\[.*Conf\.|Interval\])',
    re.IGNORECASE,
)


def _parse_estimation_table(block):
    """Parse a single-pipe estimation table into header + rows.

    Returns (headers, rows) or None.
    """
    # Work on visible text: the cells are HTML-escaped once by the caller,
    # so entities from the expanded lines (P&gt;|t|) are decoded here.
    lines = [html_mod.unescape(re.sub(r'<[^>]+>', '', line))
             for line in block.lines]
    if not lines:
        return None

    # Find separator lines
    sep_indices = []
    for idx, line in enumerate(lines):
        if '┬' in line or '┼' in line or '┴' in line:
            sep_indices.append(idx)

    if len(sep_indices) < 2:
        return None

    # Must have exactly 1 pipe column
    sep_line = lines[sep_indices[0]]
    col_positions = [m.start() for m in re.finditer(r'[┬┼┴]', sep_line)]
    if len(col_positions) != 1:
        return None

    pipe_pos = col_positions[0]

    # Check if header area contains estimation keywords
    header_text = ''
    for idx in range(sep_indices[0] + 1, min(sep_indices[1], len(lines))):
        header_text += re.sub(r'<[^>]+>', '', lines[idx])

    if not _EST_HEADER_PATTERN.search(header_text):
        return None

    # Parse header: left label + right columns split by whitespace alignment
    header_lines = []
    for idx in range(sep_indices[0] + 1, sep_indices[1]):
        if idx < len(lines):
            header_lines.append(lines[idx])

    # Determine column positions from the header right side
    # Use the first header line's whitespace structure
    right_headers = []
    for hl in header_lines:
        plain = re.sub(r'<[^>]+>', '', hl)
        if len(plain) > pipe_pos + 1:
            right_part = plain[pipe_pos + 1:]  # skip │
            # Find column positions by splitting on 2+ whitespace
            cols = re.split(r'\s{2,}', right_part.strip())
            if cols:
                right_headers = [c.strip() for c in cols if c.strip()]
                break

    if not right_headers:
        return None

    # Get left header
    left_header = ''
    for hl in header_lines:
        plain = re.sub(r'<[^>]+>', '', hl)
        left_part = plain[:pipe_pos].strip()
        if left_part:
            left_header = left_part
            break

    headers = [[left_header] + right_headers]

    # Parse body rows
    body_lines = []
    for idx in range(sep_indices[1] + 1, sep_indices[-1]):
        if idx < len(lines):
            if '┼' not in lines[idx] and '┬' not in lines[idx] and '┴' not in lines[idx]:
                # Skip pure separator lines
                plain_check = re.sub(r'<[^>]+>', '', lines[idx]).strip()
                if plain_check and not all(c in _SEP_CHARS for c in plain_check):
                    body_lines.append(lines[idx])

    rows = []
    for bl in body_lines:
        plain = re.sub(r'<[^>]+>', '', bl)
        if '│' in plain:
            parts = plain.split('│', 1)
            left = parts[0].strip()
            right = parts[1].strip() if len(parts) > 1 else ''
            right_cols = re.split(r'\s{2,}', right)
            right_cols = [c.strip() for c in right_cols if c.strip()]
            rows.append([left] + right_cols)
        else:
            # No pipe in line — might be a sub-header or separator label
            stripped = plain.strip()
            if stripped:
                rows.append([stripped])

    return headers, rows


def _is_empty_html(content):
    """Check if HTML content is effectively empty (only tags, whitespace)."""
    text = re.sub(r'<[^>]+>', '', content).strip()
    return not text


def _download_button(title):
    """Build a download button with a JS string safe in an HTML attribute."""
    filename_js = json.dumps(f"{title}.do", ensure_ascii=False)
    handler = (
        "(function(){var c=Array.from(document.querySelectorAll("
        "'.code-block pre')).map(function(e){return e.textContent.trim()})"
        ".join('\\n\\n');var b=new Blob([c],{type:'text/plain'});"
        "var a=document.createElement('a');a.href=URL.createObjectURL(b);"
        f"a.download={filename_js};a.click()}})()"
    )
    return (
        '<button class="toolbar-btn" '
        f'onclick="{html_mod.escape(handler, quote=True)}">'
        'Download .do</button>'
    )


def _yaml_double_quoted(value):
    """Escape one value for a YAML double-quoted scalar."""
    return (
        value.replace('\\', '\\\\')
        .replace('"', '\\"')
        .replace('\r', '\\r')
        .replace('\n', '\\n')
        .replace('\t', '\\t')
    )


def render_html_faithful(blocks, title="Stata Output", theme_css="",
                         nodots=False, date=None, base_dir=".",
                         footer=None, stamp=None, nograph=False,
                         graphwidth=None, graphheight=None,
                         generated=False):
    """Render HTML as a faithful Stata log transcript.

    This is the default renderer. It keeps a single monospace transcript
    surface and uses only Stata's own SMCL style/color semantics.
    """
    graph_files = detect_graph_exports(blocks, nograph=nograph)

    for block in blocks:
        expand_block(block, mode="html")

    parts = []
    current_lines = []

    def flush_transcript():
        if not current_lines:
            return
        content = "\n".join(current_lines)
        if not _is_empty_html(content):
            parts.append(
                f'<div class="stata-log-wrap"><pre class="stata-log">'
                f'{content}</pre></div>'
            )
        current_lines.clear()

    for idx, block in enumerate(blocks):
        if block.kind == "command" and nodots:
            for raw_l in block.raw_lines:
                cmd = extract_command_text(raw_l, strip_dots=True)
                current_lines.append(
                    f'<span class="cmd">{html_mod.escape(cmd)}</span>'
                )
        else:
            current_lines.extend(block.lines)

        for gfile, gidx in graph_files:
            if gidx != idx:
                continue
            flush_transcript()
            data_uri = embed_image_base64(gfile, base_dir)
            if data_uri:
                style_parts = []
                if graphwidth:
                    style_parts.append(f"width:{graphwidth}px")
                if graphheight:
                    style_parts.append(f"height:{graphheight}px")
                img_style = ""
                if style_parts:
                    img_style = f' style="{";".join(style_parts)}"'
                parts.append(
                    f'<figure class="graph-figure">'
                    f'<img src="{data_uri}" '
                    f'alt="{html_mod.escape(gfile)}"{img_style}>'
                    f'</figure>'
                )
            else:
                parts.append(
                    f'<div class="graph-missing">'
                    f'Graph file not found: {html_mod.escape(gfile)}</div>'
                )

    flush_transcript()

    body = "\n".join(parts)
    escaped_title = html_mod.escape(title)

    subtitle_html = ""
    if date:
        subtitle_html = f'\n<p class="subtitle">{html_mod.escape(date)}</p>'

    footer_html = ""
    if footer:
        footer_html = f'<p>{html_mod.escape(footer)}</p>'
    elif generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        footer_html = f'<p>Generated {timestamp}</p>'

    stamp_html = ""
    if stamp:
        stamp_html = f'\n<p class="stamp">{html_mod.escape(stamp)}</p>'

    footer_block = ""
    if footer_html:
        footer_block = f"""
<footer class="logdoc-footer">
{footer_html}
</footer>"""

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
<h1>{escaped_title}</h1>{subtitle_html}{stamp_html}
</header>
<main class="logdoc-body">
{body}
</main>{footer_block}
</article>
</body>
</html>"""


def render_html(blocks, title="Stata Output", theme_css="", preformatted=False,
                nofold=False, nodots=False, date=None, base_dir=".",
                footer=None, stamp=None, nograph=False,
                graphwidth=None, graphheight=None,
                linenumbers=False, toc=False,
                notebook=False, email=False, annotations=None,
                fold=False, highlight=False, tables=False,
                copy=False, download=False, generated=False):
    """Render parsed blocks to a self-contained HTML document."""
    graph_files = detect_graph_exports(blocks, nograph=nograph)

    # Expand all blocks in HTML mode
    for block in blocks:
        expand_block(block, mode="html")

    parts = []
    last_command_text = ""
    sections = []  # F4: track sections for TOC (F3)
    section_counter = 0
    cell_counter = 0  # C1: notebook cell numbering
    if annotations is None:
        annotations = {'block': {}, 'command': {}}
    cmd_block_counter = 0  # Track command block index for annotations
    cell_open = False

    for idx, block in enumerate(blocks):
        if block.kind == "command":
            if notebook and cell_open:
                parts.append('</div><!-- /notebook-cell -->')
                cell_open = False
            cmd_block_counter += 1
            # Always-stripped version for comment/section detection
            # and folding logic (log files keep ". " prefix when nodots is False)
            clean_cmd_texts = [
                extract_command_text(raw_line, strip_dots=True)
                for raw_line in block.raw_lines
            ]
            clean_cmd = " ".join(clean_cmd_texts)
            last_command_text = clean_cmd

            # Check if this is a graph export command
            graph_html = ""
            for gfile, gidx in graph_files:
                if gidx == idx:
                    data_uri = embed_image_base64(gfile, base_dir)
                    if data_uri:
                        img_style = ""
                        style_parts = []
                        if graphwidth:
                            style_parts.append(f"width:{graphwidth}px")
                        if graphheight:
                            style_parts.append(f"height:{graphheight}px")
                        if style_parts:
                            img_style = f' style="{";".join(style_parts)}"'
                        graph_html = (
                            f'<figure class="graph-figure">'
                            f'<img src="{data_uri}" '
                            f'alt="{html_mod.escape(gfile)}"{img_style}>'
                            f'</figure>'
                        )
                    else:
                        graph_html = (
                            f'<div class="graph-missing">'
                            f'Graph file not found: {html_mod.escape(gfile)}'
                            f'</div>'
                        )

            # Skip comment-only commands (lines starting with *)
            if clean_cmd.startswith("*") or clean_cmd.startswith("//"):
                # F4: Check for section marker (use clean_cmd for detection)
                section_info = detect_section_marker(clean_cmd)
                if section_info and toc:
                    level, sec_title = section_info
                    section_counter += 1
                    sec_id = f"section-{section_counter}"
                    tag = "h2" if level == 1 else "h3"
                    level_class = "" if level == 1 else " level-2"
                    parts.append(
                        f'<{tag} class="section-header{level_class}" '
                        f'id="{sec_id}">'
                        f'{html_mod.escape(sec_title)}</{tag}>'
                    )
                    sections.append((level, sec_title, sec_id))
                else:
                    parts.append(
                        f'<div class="comment-block">'
                        f'{html_mod.escape(clean_cmd)}</div>'
                    )
                if graph_html:
                    parts.append(graph_html)
                continue

            # O1: Syntax highlighting is opt-in. The default path preserves
            # Stata's own SMCL color spans without adding token interpretation.
            plain_cmd_lines = [
                extract_command_text(raw_line, strip_dots=True)
                for raw_line in block.raw_lines
            ]
            displayed_lines = []
            for raw_l, expanded_l, pcl in zip(
                    block.raw_lines, block.lines, plain_cmd_lines):
                if highlight:
                    displayed = highlight_stata(html_mod.escape(pcl))
                    if not nodots:
                        raw_clean = re.sub(r'\{[^}]*\}', '', raw_l).strip()
                        if re.match(r'^>\s', raw_clean):
                            displayed = '&gt; ' + displayed
                        elif re.match(r'^\.\s', raw_clean):
                            displayed = '. ' + displayed
                elif nodots:
                    displayed = (
                        f'<span class="cmd">{html_mod.escape(pcl)}</span>'
                    )
                else:
                    displayed = expanded_l
                displayed_lines.append(displayed)

            # O2: Line numbers
            if linenumbers:
                numbered_lines = []
                for ln_idx, hl in enumerate(displayed_lines, 1):
                    numbered_lines.append(
                        f'<span class="line-num">{ln_idx}</span>{hl}'
                    )
                displayed_lines = numbered_lines

            cmd_display = "\n".join(displayed_lines)

            # O7: Error highlighting — look ahead for error block
            error_source_class = ""
            if idx + 1 < len(blocks) and blocks[idx + 1].kind == "error":
                error_source_class = " error-source"

            # C1: Notebook mode — open cell div and add In[] label
            if notebook:
                cell_counter += 1
                parts.append('<div class="notebook-cell">')
                cell_open = True
                parts.append(
                    f'<div class="cell-number">In [{cell_counter}]:</div>'
                )

            copy_btn = ""
            if copy:
                copy_btn = (
                    '<button class="copy-btn" onclick="navigator.clipboard'
                    ".writeText(this.parentElement.querySelector('pre')"
                    '.textContent.trim())">'
                    'Copy</button>'
                )
            parts.append(
                f'<div class="code-block{error_source_class}">'
                f'{copy_btn}<pre>{cmd_display}</pre></div>'
            )
            if graph_html:
                parts.append(graph_html)

            # C7: Annotation injection
            ann_html = get_annotation_html(
                cmd_block_counter, clean_cmd, annotations)
            if ann_html:
                parts.append(ann_html)

            # C1: Notebook mode — collect following output/table/error in
            # the same cell, then close the cell div. We peek ahead.
            if notebook:
                # Add Out[] label if there is non-empty output following
                has_output = False
                j = idx + 1
                while j < len(blocks) and blocks[j].kind != "command":
                    out_block = blocks[j]
                    if out_block.kind == "output":
                        out_content = "\n".join(out_block.lines)
                        if not _is_empty_html(out_content):
                            has_output = True
                            break
                    elif out_block.kind in ("table", "error"):
                        has_output = True
                        break
                    j += 1
                if has_output:
                    parts.append(
                        f'<div class="cell-number">'
                        f'Out [{cell_counter}]:</div>'
                    )

        elif block.kind == "table":
            if preformatted or not tables:
                content = "\n".join(block.lines)
                parts.append(
                    f'<div class="output-block"><pre>{content}</pre></div>'
                )
            else:
                # O3: Try estimation table parsing for single-pipe tables
                html_table = table_to_html(block)
                if html_table is None:
                    est_parsed = _parse_estimation_table(block)
                    if est_parsed is not None:
                        est_headers, est_rows = est_parsed
                        est_parts = ['<table class="stata-table">']
                        if est_headers:
                            est_parts.append('<thead>')
                            for hrow in est_headers:
                                est_parts.append('<tr>')
                                for cell in hrow:
                                    est_parts.append(
                                        f'  <th>{html_mod.escape(cell)}</th>')
                                est_parts.append('</tr>')
                            est_parts.append('</thead>')
                        if est_rows:
                            est_parts.append('<tbody>')
                            for row in est_rows:
                                est_parts.append('<tr>')
                                for ci, cell in enumerate(row):
                                    text_only = re.sub(
                                        r'<[^>]+>', '', cell).strip()
                                    css_cls = ""
                                    if ci > 0 and _is_numeric(text_only):
                                        css_cls = ' class="numeric"'
                                    est_parts.append(
                                        f'  <td{css_cls}>'
                                        f'{html_mod.escape(cell)}</td>')
                                est_parts.append('</tr>')
                            est_parts.append('</tbody>')
                        est_parts.append('</table>')
                        html_table = '\n'.join(est_parts)

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

            if fold and should_fold(last_command_text, block.lines, nofold):
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

        # C1: Close notebook cell after all non-command blocks
        if notebook and block.kind != "command":
            # Check if the next block is a command (or end of blocks)
            next_is_cmd = (idx + 1 >= len(blocks) or
                           blocks[idx + 1].kind == "command")
            if next_is_cmd and cell_counter > 0:
                parts.append('</div><!-- /notebook-cell -->')
                cell_open = False

    if notebook and cell_open:
        parts.append('</div><!-- /notebook-cell -->')

    body = "\n".join(parts)
    escaped_title = html_mod.escape(title)

    # Build subtitle line (date if provided)
    subtitle_html = ""
    if date:
        subtitle_html = f'\n<p class="subtitle">{html_mod.escape(date)}</p>'

    # Footer text
    footer_html = ""
    if footer:
        footer_html = f'<p>{html_mod.escape(footer)}</p>'
    elif generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        footer_html = f'<p>Generated {timestamp}</p>'

    # Stamp HTML (environment info in header)
    stamp_html = ""
    if stamp:
        stamp_html = f'\n<p class="stamp">{html_mod.escape(stamp)}</p>'

    # O6: Expand all / Collapse all toolbar + C5: Download .do button
    fold_buttons = ""
    if fold and not nofold:
        fold_buttons = (
            '<button class="toolbar-btn" onclick="document.querySelectorAll(\'details.fold-block\').forEach(d=>d.open=true)">Expand All</button>'
            '<button class="toolbar-btn" onclick="document.querySelectorAll(\'details.fold-block\').forEach(d=>d.open=false)">Collapse All</button>'
        )
    download_btn = ""
    if download:
        download_btn = _download_button(title)
    toolbar_html = ""
    if fold_buttons or download_btn:
        toolbar_html = (
            f'\n<div class="logdoc-toolbar">{fold_buttons}{download_btn}</div>'
        )

    # F3: Table of Contents
    toc_html = ""
    if toc and sections:
        toc_items = []
        for _level, sec_title, sec_id in sections:
            toc_items.append(
                f'<li><a href="#{sec_id}">{html_mod.escape(sec_title)}</a></li>'
            )
        toc_html = (
            f'\n<nav class="logdoc-toc"><strong>Contents</strong>'
            f'<ol>{"".join(toc_items)}</ol></nav>'
        )

    # O5: Sticky navigation header (only when sections exist)
    nav_html = ""
    nav_js = ""
    if sections:
        nav_html = '<nav class="logdoc-nav" id="logdoc-nav" style="display:none"></nav>'
        nav_js = """
<script>
(function(){
  var nav=document.getElementById('logdoc-nav');
  var headers=document.querySelectorAll('.section-header');
  if(!headers.length||!nav)return;
  var observer=new IntersectionObserver(function(entries){
    entries.forEach(function(e){
      if(e.isIntersecting){nav.textContent=e.target.textContent;nav.style.display='block';}
    });
  },{rootMargin:'-60px 0px -80% 0px'});
  headers.forEach(function(h){observer.observe(h);});
})();
</script>"""

    html_doc = f"""<!DOCTYPE html>
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
<h1>{escaped_title}</h1>{subtitle_html}{stamp_html}
</header>{toolbar_html}{toc_html}
{nav_html}
<main class="logdoc-body">
{body}
</main>{f'''
<footer class="logdoc-footer">
{footer_html}
</footer>''' if footer_html else ''}
</article>{nav_js}
</body>
</html>"""

    # C3: Email-safe HTML — inline all CSS, remove <style> block
    if email:
        html_doc = _inline_css(html_doc)

    return html_doc


# ---------------------------------------------------------------------------
# Stage 7: Markdown Renderer
# ---------------------------------------------------------------------------

def _md_fence(content):
    """A backtick fence longer than any backtick run inside `content`."""
    runs = [len(r) for r in re.findall(r'`+', content)]
    return "`" * max(3, max(runs, default=0) + 1)


def _md_link_target(path):
    """A Markdown link destination; <...> form when it has spaces/parens."""
    if re.search(r'[\s()]', path) and not re.search(r'[<>]', path):
        return f"<{path}>"
    return path


def render_markdown(blocks, title="Stata Output", nofold=False, nodots=False,
                    date=None, base_dir=".", output_dir=None,
                    footer=None, stamp=None, nograph=False,
                    generated=False):
    """Render parsed blocks to Markdown."""
    graph_files = detect_graph_exports(blocks, nograph=nograph)
    if output_dir is None:
        output_dir = base_dir

    # Expand all blocks in text mode
    for block in blocks:
        expand_block(block, mode="text")

    parts = []
    safe_title = _yaml_double_quoted(title)
    parts.append("---")
    parts.append(f'title: "{safe_title}"')
    if date:
        safe_date = _yaml_double_quoted(date)
        parts.append(f'date: "{safe_date}"')
    parts.append("---")
    parts.append("")

    for idx, block in enumerate(blocks):
        if block.kind == "command":
            # Always-stripped version for comment/section detection
            clean_cmd_texts = [
                extract_command_text(raw_line, strip_dots=True)
                for raw_line in block.raw_lines
            ]
            clean_cmd = " ".join(clean_cmd_texts)

            if clean_cmd.startswith("*") or clean_cmd.startswith("//"):
                # F4: Section markers in Markdown
                section_info = detect_section_marker(clean_cmd)
                if section_info:
                    level, sec_title = section_info
                    prefix = "##" if level == 1 else "###"
                    parts.append(f"{prefix} {sec_title}")
                    parts.append("")
                else:
                    parts.append(f"<!-- {clean_cmd} -->")
                    parts.append("")
                continue

            # Reconstruct clean command for markdown
            clean_lines = []
            for raw in block.raw_lines:
                text = extract_command_text(raw, strip_dots=nodots)
                if text:
                    clean_lines.append(text)
            cmd_str = "\n".join(clean_lines)

            fence = _md_fence(cmd_str)
            parts.append(fence + "stata")
            parts.append(cmd_str)
            parts.append(fence)
            parts.append("")

            # Graph reference — resolve path relative to the output .md file
            for gfile, gidx in graph_files:
                if gidx == idx:
                    abs_gfile = (_resolve_graph_path(gfile, base_dir)
                                 or os.path.join(base_dir, gfile))
                    rel_path = os.path.relpath(
                        abs_gfile, os.path.abspath(output_dir))
                    display_name = os.path.basename(gfile)
                    parts.append(f"![{display_name}]({_md_link_target(rel_path)})")
                    parts.append("")

        elif block.kind == "table":
            content = "\n".join(block.lines)
            if content.strip():
                fence = _md_fence(content)
                parts.append(fence)
                parts.append(content)
                parts.append(fence)
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
            fence = _md_fence(content)
            parts.append(fence)
            parts.append(content)
            parts.append(fence)
            parts.append("")

    # Stamp
    if stamp:
        parts.append("---")
        parts.append(f"*{stamp}*")
        parts.append("")

    # Footer
    if footer:
        parts.append("---")
        parts.append(f"*{footer}*")
        parts.append("")
    elif generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        parts.append("---")
        parts.append(f"*Generated {timestamp}*")
        parts.append("")

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Stage 8: LaTeX Renderer
# ---------------------------------------------------------------------------

def _latex_verbatim_env(begin, env, content):
    """Lines of a verbatim-like LaTeX environment holding `content`.

    verbatim and lstlisting end at the first literal \\end{<env>}, so an
    output line containing it is set outside the environment with \\verb
    (delimiter chosen from characters absent in the line) and the
    environment is reopened after it.
    """
    term = "\\end{" + env + "}"
    out = [begin]
    for line in content.split("\n"):
        if term not in line:
            out.append(line)
            continue
        out.append(term)
        delim = next((c for c in "|!+@#~=;:/" if c not in line), None)
        if delim is not None:
            out.append("\\noindent\\verb" + delim + line + delim + "\\par")
        else:
            out.append("\\noindent\\texttt{" + _latex_escape(line) + "}\\par")
        out.append(begin)
    out.append(term)
    return out


def _latex_escape(text):
    """Escape special LaTeX characters in plain text."""
    replacements = [
        ('\\', '\\textbackslash{}'),
        ('{', '\\{'),
        ('}', '\\}'),
        ('$', '\\$'),
        ('&', '\\&'),
        ('#', '\\#'),
        ('%', '\\%'),
        ('_', '\\_'),
        ('^', '\\textasciicircum{}'),
        ('~', '\\textasciitilde{}'),
    ]
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def render_latex(blocks, title="Stata Output", nodots=False, date=None,
                 base_dir=".", footer=None, stamp=None, nograph=False,
                 generated=False, output_dir=None):
    """Render parsed blocks to a LaTeX document."""
    graph_files = detect_graph_exports(blocks, nograph=nograph,
                                       exts=LATEX_GRAPH_EXTS)
    if output_dir is None:
        output_dir = base_dir

    # Expand all blocks in text mode
    for block in blocks:
        expand_block(block, mode="text")

    parts = []

    # Preamble
    parts.append(r"\documentclass{article}")
    parts.append(r"\usepackage[utf8]{inputenc}")
    parts.append(r"\usepackage[T1]{fontenc}")
    parts.append(r"\usepackage{listings}")
    parts.append(r"\usepackage{booktabs}")
    parts.append(r"\usepackage{xcolor}")
    parts.append(r"\usepackage{graphicx}")
    parts.append(r"\usepackage[margin=1in]{geometry}")
    parts.append("")
    parts.append(r"\definecolor{statacommand}{RGB}{0,85,170}")
    parts.append(r"\definecolor{stataerror}{RGB}{192,57,43}")
    parts.append(r"\definecolor{stataoutput}{RGB}{73,80,87}")
    parts.append(r"\definecolor{statabg}{RGB}{248,249,250}")
    parts.append("")
    parts.append(r"\lstset{")
    parts.append(r"  basicstyle=\ttfamily\small,")
    parts.append(r"  breaklines=true,")
    parts.append(r"  breakatwhitespace=false,")
    parts.append(r"  columns=fullflexible,")
    parts.append(r"  keepspaces=true,")
    parts.append(r"  showstringspaces=false,")
    parts.append(r"  frame=none,")
    parts.append(r"  xleftmargin=0.5em,")
    parts.append(r"}")
    parts.append("")
    parts.append(r"\lstdefinestyle{statacommand}{")
    parts.append(r"  basicstyle=\ttfamily\small\color{statacommand},")
    parts.append(r"  backgroundcolor=\color{statabg},")
    parts.append(r"  frame=l,")
    parts.append(r"  framerule=2pt,")
    parts.append(r"  rulecolor=\color{statacommand},")
    parts.append(r"}")
    parts.append("")
    parts.append(r"\lstdefinestyle{stataoutput}{")
    parts.append(r"  basicstyle=\ttfamily\footnotesize\color{stataoutput},")
    parts.append(r"}")
    parts.append("")
    parts.append(r"\lstdefinestyle{stataerror}{")
    parts.append(r"  basicstyle=\ttfamily\footnotesize\color{stataerror},")
    parts.append(r"}")
    parts.append("")

    # Title
    safe_title = _latex_escape(title)
    parts.append(r"\title{" + safe_title + "}")
    if date:
        parts.append(r"\date{" + _latex_escape(date) + "}")
    else:
        parts.append(r"\date{\today}")
    parts.append(r"\author{}")
    parts.append("")
    parts.append(r"\begin{document}")
    parts.append(r"\maketitle")
    parts.append("")

    for idx, block in enumerate(blocks):
        if block.kind == "command":
            clean_cmd_texts = [
                extract_command_text(raw_line, strip_dots=True)
                for raw_line in block.raw_lines
            ]
            clean_cmd = " ".join(clean_cmd_texts)

            # Comments
            if clean_cmd.startswith("*") or clean_cmd.startswith("//"):
                section_info = detect_section_marker(clean_cmd)
                if section_info:
                    level, sec_title = section_info
                    if level == 1:
                        parts.append(r"\section{" + _latex_escape(sec_title) + "}")
                    else:
                        parts.append(r"\subsection{" + _latex_escape(sec_title) + "}")
                else:
                    parts.append("% " + clean_cmd)
                parts.append("")
                continue

            # Command block
            clean_lines = []
            for raw in block.raw_lines:
                text = extract_command_text(raw, strip_dots=nodots)
                if text:
                    clean_lines.append(text)
            cmd_str = "\n".join(clean_lines)

            parts.extend(_latex_verbatim_env(
                r"\begin{lstlisting}[style=statacommand]", "lstlisting",
                cmd_str))
            parts.append("")

            # Graph reference (use external file path, not base64)
            for gfile, gidx in graph_files:
                if gidx == idx:
                    resolved = _resolve_graph_path(gfile, base_dir)
                    if resolved is not None:
                        gpath = os.path.relpath(
                            resolved, os.path.abspath(output_dir))
                    else:
                        gpath = gfile
                    parts.append(r"\begin{figure}[htbp]")
                    parts.append(r"\centering")
                    parts.append(r"\includegraphics[width=0.8\textwidth]{"
                                 + gpath + "}")
                    parts.append(r"\end{figure}")
                    parts.append("")

        elif block.kind == "table":
            content = "\n".join(block.lines)
            if content.strip():
                parts.extend(_latex_verbatim_env(
                    r"\begin{verbatim}", "verbatim", content))
                parts.append("")

        elif block.kind == "error":
            content = "\n".join(block.lines)
            if content.strip():
                parts.append(r"{\color{stataerror}")
                parts.extend(_latex_verbatim_env(
                    r"\begin{verbatim}", "verbatim", content))
                parts.append(r"}")
                parts.append("")

        elif block.kind == "output":
            content = "\n".join(block.lines)
            text_only = re.sub(r'<[^>]+>', '', content).strip()
            if not text_only:
                continue
            parts.extend(_latex_verbatim_env(
                r"\begin{lstlisting}[style=stataoutput]", "lstlisting",
                content))
            parts.append("")

    # Stamp
    if stamp:
        parts.append(r"\vfill")
        parts.append(r"\noindent\small\texttt{" + _latex_escape(stamp) + "}")
        parts.append("")

    # Footer
    if footer:
        parts.append(r"\vfill")
        parts.append(r"\begin{center}")
        parts.append(r"\small " + _latex_escape(footer))
        parts.append(r"\end{center}")
    elif generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        parts.append(r"\vfill")
        parts.append(r"\begin{center}")
        parts.append(r"\small Generated " + timestamp)
        parts.append(r"\end{center}")

    parts.append("")
    parts.append(r"\end{document}")
    parts.append("")

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# PDF conversion via xhtml2pdf (optional dependency)
# ---------------------------------------------------------------------------

_BOX_DRAW_MAP = str.maketrans({
    '─': '-', '━': '-', '│': '|', '┃': '|',
    '┌': '+', '┐': '+', '└': '+', '┘': '+',
    '├': '+', '┤': '+', '┬': '+', '┴': '+', '┼': '+',
    '┏': '+', '┓': '+', '┗': '+', '┛': '+',
    '┣': '+', '┫': '+', '┳': '+', '┻': '+', '╋': '+',
    '╌': '-', '╎': '|', '╴': '-', '╶': '-', '╵': '|', '╷': '|',
    '═': '=', '║': '|',
    '╔': '+', '╗': '+', '╚': '+', '╝': '+',
    '╠': '+', '╣': '+', '╦': '+', '╩': '+', '╬': '+',
    '╭': '+', '╮': '+', '╰': '+', '╯': '+',
})


def convert_html_to_pdf(html_path, pdf_path):
    """Convert an HTML file to PDF using xhtml2pdf.

    Returns True on success, False if xhtml2pdf is not installed.
    Raises RuntimeError on conversion failure.
    """
    try:
        from xhtml2pdf import pisa
    except ImportError:
        return False

    with open(html_path, "r", encoding="utf-8") as f:
        html = f.read()

    html = html.translate(_BOX_DRAW_MAP)

    output_dir = os.path.dirname(os.path.abspath(pdf_path))
    os.makedirs(output_dir, exist_ok=True)
    fd, temporary_pdf = tempfile.mkstemp(
        prefix=".logdoc-pdf-", suffix=".tmp", dir=output_dir
    )
    os.close(fd)
    try:
        with open(temporary_pdf, "wb") as out:
            status = pisa.CreatePDF(html, dest=out)
        if status.err:
            raise RuntimeError(
                f"xhtml2pdf conversion failed with {status.err} error(s)"
            )
        os.replace(temporary_pdf, pdf_path)
    finally:
        if os.path.exists(temporary_pdf):
            os.remove(temporary_pdf)
    return True


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def load_css(css_path):
    """Load the user's --css file; empty string if not found."""
    if css_path and os.path.isfile(css_path):
        with open(css_path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    return ""


def read_text_file(path):
    """Read a text file as UTF-8 (a leading BOM removed), else Latin-1.

    Latin-1 maps every byte, so the fallback always decodes.
    """
    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            return f.read()
    except UnicodeDecodeError:
        with open(path, "r", encoding="latin-1") as f:
            return f.read()


def read_combine_manifest(path):
    """Read newline-delimited source paths for combine mode."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return [line.strip() for line in f if line.strip()]


def validate_accent(accent):
    """Validate a CSS hex accent color."""
    if accent is None:
        return True
    return re.fullmatch(r"#[0-9A-Fa-f]{6}", accent) is not None


def _same_path(path_a, path_b):
    """Return whether two paths resolve to the same filesystem location."""
    try:
        if os.path.samefile(path_a, path_b):
            return True
    except OSError:
        pass  # A new destination has no filesystem identity yet.
    normalized_a = os.path.normcase(os.path.realpath(os.path.abspath(path_a)))
    normalized_b = os.path.normcase(os.path.realpath(os.path.abspath(path_b)))
    return normalized_a == normalized_b


def _output_paths(output, fmt):
    """Return every file the selected format will write."""
    if fmt == "both":
        return [_swap_ext(output, ".html"), _swap_ext(output, ".md")]
    return [output]


def _reject_output_collisions(sources, output, fmt):
    """Raise ValueError when any output would replace a source file."""
    for source in sources:
        for destination in _output_paths(output, fmt):
            if _same_path(source, destination):
                raise ValueError(
                    f"output path must differ from source path: {source}"
                )


def apply_accent_css(theme_css, accent):
    """Append accent-color overrides without requiring a custom CSS file."""
    if not accent:
        return theme_css
    return theme_css + f"""

:root {{ --logdoc-accent: {accent}; }}
.logdoc-header {{ border-bottom-color: var(--logdoc-accent); }}
.code-block {{ border-left-color: var(--logdoc-accent); }}
.logdoc-toc {{ border-color: var(--logdoc-accent); }}
.logdoc-toc a, .help-link {{ color: var(--logdoc-accent); }}
.toolbar-btn:focus {{ outline: 2px solid var(--logdoc-accent); outline-offset: 2px; }}
.section-header {{ border-bottom-color: var(--logdoc-accent); }}
"""


def metadata_for_blocks(blocks, base_dir=".", nograph=False, latex=False):
    """Return composable metadata counts for a parsed block list."""
    graph_files = detect_graph_exports(
        blocks, nograph=nograph,
        exts=LATEX_GRAPH_EXTS if latex else None)
    nwarnings = 0
    if latex:
        # Successful exports LaTeX cannot include are skipped: one warning each
        nwarnings += len(detect_graph_exports(
            blocks, nograph=nograph, exts=LATEX_SKIPPED_EXTS))
    for gfile, _gidx in graph_files:
        if _resolve_graph_path(gfile, base_dir) is None:
            nwarnings += 1
    return {
        "blocks": len(blocks),
        "graphs": len(graph_files),
        "tables": sum(1 for block in blocks if block.kind == "table"),
        "warnings": nwarnings,
    }


def print_metadata(nblocks, filesize, ngraphs=0, ntables=0, nwarnings=0):
    """Emit the metadata line parsed by logdoc.ado."""
    print(
        "LOGDOC_META: "
        f"blocks={nblocks} filesize={filesize} "
        f"graphs={ngraphs} tables={ntables} warnings={nwarnings}"
    )


_MD_FRONT_MATTER_RE = re.compile(r"\A---\n.*?\n---\n*", re.DOTALL)
_LATEX_DOC_RE = re.compile(
    r"(?ms)^\\begin\{document\}\s*$(.*?)^\\end\{document\}\s*$"
)
_LATEX_END_DOC_RE = re.compile(r"(?m)^\\end\{document\}\s*$")


def _append_html_document(existing, new_content):
    """Append rendered HTML body into an existing logdoc document."""
    if not re.search(r'<main class="logdoc-body">.*?</main>', existing, re.DOTALL):
        raise ValueError("existing HTML is not a logdoc document")

    match = re.search(
        r'<main class="logdoc-body">\s*(.*?)\s*</main>',
        new_content, re.DOTALL
    )
    if not match:
        raise ValueError("new HTML is not a logdoc document")

    new_body = match.group(1).strip()
    if not new_body:
        return existing

    return existing.replace("</main>", f"\n{new_body}\n</main>", 1)


def _append_markdown_document(existing, new_content):
    """Append Markdown while preserving a single top-level YAML block."""
    new_body = _MD_FRONT_MATTER_RE.sub("", new_content, count=1).lstrip()
    if not new_body:
        return existing
    return existing.rstrip() + "\n\n" + new_body


def _extract_latex_body(content):
    """Extract appendable LaTeX body content from a rendered document."""
    match = _LATEX_DOC_RE.search(content)
    if not match:
        return content.strip()

    body = match.group(1).strip()
    body = re.sub(r"\A\\maketitle\s*", "", body, count=1)
    return body.strip()


def _append_latex_document(existing, new_content):
    """Append LaTeX body content before the closing document marker."""
    new_body = _extract_latex_body(new_content)
    if not new_body:
        return existing

    matches = list(_LATEX_END_DOC_RE.finditer(existing))
    if not matches:
        return existing.rstrip() + "\n\n" + new_body + "\n"

    end_pos = matches[-1].start()
    prefix = existing[:end_pos].rstrip()
    suffix = existing[end_pos:].lstrip()
    return prefix + "\n\n" + new_body + "\n\n" + suffix


def _extract_html_main(content):
    """Extract the rendered body from a complete logdoc HTML document."""
    match = re.search(
        r'<main class="logdoc-body">\s*(.*?)\s*</main>',
        content, re.DOTALL
    )
    if match:
        return match.group(1).strip()
    return content.strip()


def _source_title(path):
    """Return the default combine section title for a source path."""
    base = os.path.basename(path)
    stem, _ = os.path.splitext(base)
    return stem or base or path


def _source_id(index):
    return f"logdoc-source-{index}"


def render_combined_html(sources, args, theme_css, annotations=None,
                         use_enhanced_html=False):
    """Render several logs into one HTML document with source-level TOC."""
    bodies = []
    toc_items = []
    totals = {"blocks": 0, "graphs": 0, "tables": 0, "warnings": 0}

    for idx, source in enumerate(sources, 1):
        raw_text = read_text_file(source)
        blocks = parse_blocks(raw_text.split("\n"))
        blocks = filter_blocks(blocks, keep=args.keep, drop=args.drop)
        if not blocks:
            totals["warnings"] += 1
            continue

        base_dir = os.path.dirname(os.path.abspath(source))
        stats = metadata_for_blocks(blocks, base_dir, nograph=args.nograph)
        for key in totals:
            totals[key] += stats[key]

        section_title = _source_title(source)
        section_id = _source_id(idx)
        toc_items.append((section_title, section_id))

        if use_enhanced_html:
            source_doc = render_html(
                blocks, title=section_title, theme_css=theme_css,
                preformatted=args.preformatted, nofold=args.nofold,
                nodots=args.nodots, date=None, base_dir=base_dir,
                footer=None, stamp=None, nograph=args.nograph,
                graphwidth=args.graphwidth, graphheight=args.graphheight,
                linenumbers=args.linenumbers, toc=False,
                notebook=args.notebook, email=False,
                annotations=annotations,
                fold=(args.fold or args.legacy) and not args.nofold,
                highlight=args.highlight or args.legacy,
                tables=(args.tables or args.legacy) and not args.preformatted,
                copy=args.copy or args.legacy,
                download=False,
                generated=False,
            )
        else:
            source_doc = render_html_faithful(
                blocks, title=section_title, theme_css=theme_css,
                nodots=args.nodots, date=None, base_dir=base_dir,
                footer=None, stamp=None, nograph=args.nograph,
                graphwidth=args.graphwidth, graphheight=args.graphheight,
                generated=False,
            )

        bodies.append(
            f'<section class="logdoc-source" id="{section_id}">\n'
            f'<h2 class="section-header">{html_mod.escape(section_title)}</h2>\n'
            f'{_extract_html_main(source_doc)}\n'
            f'</section>'
        )

    if not bodies:
        print_metadata(0, 0, 0, 0, totals["warnings"])
        print("Error: No content blocks found in combined inputs", file=sys.stderr)
        sys.exit(1)

    title = args.title or "Combined logdoc report"
    escaped_title = html_mod.escape(title)
    subtitle_html = ""
    if args.date:
        subtitle_html = f'\n<p class="subtitle">{html_mod.escape(args.date)}</p>'

    stamp_html = ""
    if args.stamp:
        stamp_html = f'\n<p class="stamp">{html_mod.escape(args.stamp)}</p>'

    footer_html = ""
    if args.footer:
        footer_html = f'<p>{html_mod.escape(args.footer)}</p>'
    elif args.generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        footer_html = f'<p>Generated {timestamp}</p>'

    footer_block = ""
    if footer_html:
        footer_block = f"""
<footer class="logdoc-footer">
{footer_html}
</footer>"""

    toc_html = ""
    if args.toc or len(toc_items) > 1:
        items = "".join(
            f'<li><a href="#{sec_id}">{html_mod.escape(sec_title)}</a></li>'
            for sec_title, sec_id in toc_items
        )
        toc_html = (
            f'\n<nav class="logdoc-toc"><strong>Contents</strong>'
            f'<ol>{items}</ol></nav>'
        )

    download_btn = ""
    if args.download or args.legacy:
        download_btn = _download_button(title)
    toolbar_html = f'\n<div class="logdoc-toolbar">{download_btn}</div>' if download_btn else ""

    html_doc = f"""<!DOCTYPE html>
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
<h1>{escaped_title}</h1>{subtitle_html}{stamp_html}
</header>{toolbar_html}{toc_html}
<main class="logdoc-body">
{chr(10).join(bodies)}
</main>{footer_block}
</article>
</body>
</html>"""

    if args.email:
        html_doc = _inline_css(html_doc)

    return html_doc, totals


def render_combined_markdown(sources, args, fmt="md"):
    """Render several logs into one Markdown or Quarto Markdown document."""
    title = args.title or "Combined logdoc report"
    safe_title = _yaml_double_quoted(title)
    parts = ["---", f'title: "{safe_title}"']
    if args.date:
        safe_date = _yaml_double_quoted(args.date)
        parts.append(f'date: "{safe_date}"')
    parts.extend(["---", ""])
    totals = {"blocks": 0, "graphs": 0, "tables": 0, "warnings": 0}

    for source in sources:
        raw_text = read_text_file(source)
        blocks = parse_blocks(raw_text.split("\n"))
        blocks = filter_blocks(blocks, keep=args.keep, drop=args.drop)
        if not blocks:
            totals["warnings"] += 1
            continue

        base_dir = os.path.dirname(os.path.abspath(source))
        stats = metadata_for_blocks(blocks, base_dir, nograph=args.nograph)
        for key in totals:
            totals[key] += stats[key]

        section_title = _source_title(source)
        md_content = render_markdown(
            blocks, title=section_title, nofold=args.nofold,
            nodots=args.nodots, date=None, base_dir=base_dir,
            output_dir=os.path.dirname(os.path.abspath(args.output)),
            footer=None, stamp=None, nograph=args.nograph,
            generated=False,
        )
        md_body = _MD_FRONT_MATTER_RE.sub("", md_content, count=1).lstrip()
        parts.append(f"## {section_title}")
        parts.append("")
        parts.append(md_body.rstrip())
        parts.append("")

    if args.stamp:
        parts.extend(["---", f"*{args.stamp}*", ""])
    if args.footer:
        parts.extend(["---", f"*{args.footer}*", ""])
    elif args.generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        parts.extend(["---", f"*Generated {timestamp}*", ""])

    if totals["blocks"] == 0:
        print_metadata(0, 0, 0, 0, totals["warnings"])
        print("Error: No content blocks found in combined inputs", file=sys.stderr)
        sys.exit(1)

    return "\n".join(parts), totals


def render_combined_latex(sources, args):
    """Render several logs into one LaTeX document."""
    title = args.title or "Combined logdoc report"
    parts = []
    parts.append(r"\documentclass{article}")
    parts.append(r"\usepackage[utf8]{inputenc}")
    parts.append(r"\usepackage[T1]{fontenc}")
    parts.append(r"\usepackage{listings}")
    parts.append(r"\usepackage{booktabs}")
    parts.append(r"\usepackage{xcolor}")
    parts.append(r"\usepackage{graphicx}")
    parts.append(r"\usepackage[margin=1in]{geometry}")
    parts.append("")
    parts.append(r"\definecolor{statacommand}{RGB}{0,85,170}")
    parts.append(r"\definecolor{stataerror}{RGB}{192,57,43}")
    parts.append(r"\definecolor{stataoutput}{RGB}{73,80,87}")
    parts.append(r"\definecolor{statabg}{RGB}{248,249,250}")
    parts.append("")
    parts.append(r"\lstset{basicstyle=\ttfamily\small,breaklines=true,columns=fullflexible,keepspaces=true,showstringspaces=false}")
    parts.append(r"\lstdefinestyle{statacommand}{basicstyle=\ttfamily\small\color{statacommand},backgroundcolor=\color{statabg},frame=l,framerule=2pt,rulecolor=\color{statacommand}}")
    parts.append(r"\lstdefinestyle{stataoutput}{basicstyle=\ttfamily\footnotesize\color{stataoutput}}")
    parts.append(r"\lstdefinestyle{stataerror}{basicstyle=\ttfamily\footnotesize\color{stataerror}}")
    parts.append("")
    parts.append(r"\title{" + _latex_escape(title) + "}")
    if args.date:
        parts.append(r"\date{" + _latex_escape(args.date) + "}")
    else:
        parts.append(r"\date{\today}")
    parts.append(r"\author{}")
    parts.append(r"\begin{document}")
    parts.append(r"\maketitle")
    parts.append("")
    totals = {"blocks": 0, "graphs": 0, "tables": 0, "warnings": 0}

    for source in sources:
        raw_text = read_text_file(source)
        blocks = parse_blocks(raw_text.split("\n"))
        blocks = filter_blocks(blocks, keep=args.keep, drop=args.drop)
        if not blocks:
            totals["warnings"] += 1
            continue
        base_dir = os.path.dirname(os.path.abspath(source))
        stats = metadata_for_blocks(blocks, base_dir, nograph=args.nograph)
        for key in totals:
            totals[key] += stats[key]

        section_title = _source_title(source)
        tex_doc = render_latex(
            blocks, title=section_title, nodots=args.nodots, date=None,
            base_dir=base_dir, footer=None, stamp=None,
            nograph=args.nograph, generated=False,
            output_dir=os.path.dirname(os.path.abspath(args.output)),
        )
        parts.append(r"\section{" + _latex_escape(section_title) + "}")
        parts.append(_extract_latex_body(tex_doc))
        parts.append("")

    if args.stamp:
        parts.append(r"\vfill")
        parts.append(r"\noindent\small\texttt{" + _latex_escape(args.stamp) + "}")
    if args.footer:
        parts.append(r"\vfill")
        parts.append(r"\begin{center}")
        parts.append(r"\small " + _latex_escape(args.footer))
        parts.append(r"\end{center}")
    elif args.generated:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        parts.append(r"\vfill")
        parts.append(r"\begin{center}")
        parts.append(r"\small Generated " + timestamp)
        parts.append(r"\end{center}")
    parts.append(r"\end{document}")
    parts.append("")

    if totals["blocks"] == 0:
        print_metadata(0, 0, 0, 0, totals["warnings"])
        print("Error: No content blocks found in combined inputs", file=sys.stderr)
        sys.exit(1)

    return "\n".join(parts), totals


def main():
    parser = argparse.ArgumentParser(
        description="Convert Stata SMCL/log files to shareable documents"
    )
    parser.add_argument("input", help="Input .smcl, .log, or .do file")
    parser.add_argument("output", help="Output file path")
    parser.add_argument("--format", default="html",
                        choices=["html", "md", "both", "qmd", "tex"],
                        help="Output format (default: html)")
    parser.add_argument("--theme", default="light",
                        choices=["light", "dark"],
                        help="CSS theme (default: light)")
    parser.add_argument("--title", default=None,
                        help="Document title (defaults to filename)")
    parser.add_argument("--preformatted", action="store_true",
                        help="Compatibility alias; tables are monospace by default")
    parser.add_argument("--nofold", action="store_true",
                        help="Compatibility alias; folding is off by default")
    parser.add_argument("--nodots", action="store_true",
                        help="Strip dot prompts from commands")
    parser.add_argument("--fold", action="store_true",
                        help="Fold long output blocks")
    parser.add_argument("--highlight", action="store_true",
                        help="Syntax-highlight command text")
    parser.add_argument("--tables", action="store_true",
                        help="Parse supported Stata tables into HTML tables")
    parser.add_argument("--copy", action="store_true",
                        help="Add copy buttons to command blocks")
    parser.add_argument("--download", action="store_true",
                        help="Add a Download .do toolbar button")
    parser.add_argument("--legacy", action="store_true",
                        help="Enable all HTML enhancements in one switch")
    parser.add_argument("--date", default=None,
                        help="Date subtitle shown in document header")
    parser.add_argument("--title-file", default=None,
                        help="Read title from file (avoids shell quoting)")
    parser.add_argument("--date-file", default=None,
                        help="Read date from file (avoids shell quoting)")
    parser.add_argument("--css", default=None,
                        help="Custom CSS file path")
    parser.add_argument("--accent", default=None,
                        help="Accent color as #RRGGBB")
    parser.add_argument("--verbose", action="store_true",
                        help="Print block count and timing to stderr")
    parser.add_argument("--footer", default=None,
                        help="Custom footer text")
    parser.add_argument("--footer-file", default=None,
                        help="Read footer from file (avoids shell quoting)")
    parser.add_argument("--generated", action="store_true",
                        help="Add 'Generated YYYY-MM-DD HH:MM' footer")
    parser.add_argument("--stamp", default=None,
                        help="Environment stamp text")
    parser.add_argument("--stamp-file", default=None,
                        help="Read stamp from file (avoids shell quoting)")
    parser.add_argument("--nograph", action="store_true",
                        help="Suppress graph embedding")
    parser.add_argument("--graphwidth", default=None,
                        help="Width in pixels for embedded graph images")
    parser.add_argument("--graphheight", default=None,
                        help="Height in pixels for embedded graph images")
    parser.add_argument("--linenumbers", action="store_true",
                        help="Add line numbers to command blocks")
    parser.add_argument("--toc", action="store_true",
                        help="Generate table of contents from section markers")
    parser.add_argument("--keep", default=None,
                        help="Pipe-delimited patterns: keep only matching commands")
    parser.add_argument("--keep-file", default=None,
                        help="Read keep patterns from file (one per line)")
    parser.add_argument("--drop", default=None,
                        help="Pipe-delimited patterns: drop matching commands")
    parser.add_argument("--drop-file", default=None,
                        help="Read drop patterns from file (one per line)")
    parser.add_argument("--append", action="store_true",
                        help="Append to existing output file")
    parser.add_argument("--notebook", action="store_true",
                        help="Jupyter-style notebook cell rendering")
    parser.add_argument("--compare", default=None,
                        help="Second file for diff comparison")
    parser.add_argument("--combine-file", default=None,
                        help="Newline-delimited source manifest for combine mode")
    parser.add_argument("--email", action="store_true",
                        help="Email-safe HTML with inline CSS")
    parser.add_argument("--annotate", default=None,
                        help="Annotation file path")
    parser.add_argument("--graph-base", default=None,
                        help="Execution directory for run/session graph paths")
    parser.add_argument("--check-output-only", action="store_true",
                        help="Check source/output identity without writing")
    parser.add_argument("--html-to-pdf", default=None,
                        help="Convert an HTML file to PDF via xhtml2pdf (standalone mode)")

    args = parser.parse_args()

    if not validate_accent(args.accent):
        print_metadata(0, 0)
        print("Error: --accent must be a #RRGGBB color", file=sys.stderr)
        sys.exit(1)

    for attr in ("graphwidth", "graphheight"):
        value = getattr(args, attr)
        if value is not None and re.fullmatch(r"[1-9][0-9]*", value) is None:
            print_metadata(0, 0)
            print(
                f"Error: --{attr} must be a positive integer",
                file=sys.stderr,
            )
            sys.exit(1)

    for attr in ("css", "annotate"):
        path = getattr(args, attr)
        if path and not os.path.isfile(path):
            print_metadata(0, 0)
            print(
                f"Error: --{attr.replace('_', '-')} not found: {path}",
                file=sys.stderr,
            )
            sys.exit(1)

    # Standalone HTML-to-PDF conversion (called from .ado)
    if args.html_to_pdf:
        html_path = args.html_to_pdf
        pdf_path = args.output
        if not os.path.isfile(html_path):
            print(f"Error: HTML file not found: {html_path}", file=sys.stderr)
            sys.exit(1)
        if _same_path(html_path, pdf_path):
            print("Error: PDF output must differ from HTML input", file=sys.stderr)
            sys.exit(1)
        try:
            ok = convert_html_to_pdf(html_path, pdf_path)
        except RuntimeError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
        if not ok:
            print("XHTML2PDF_NOT_INSTALLED", file=sys.stderr)
            sys.exit(2)
        print(f"Generated: {pdf_path}")
        sys.exit(0)

    # Read title/date/footer/stamp from file if provided (avoids shell quoting)
    for _attr in ("title_file", "date_file", "footer_file", "stamp_file"):
        _path = getattr(args, _attr)
        if _path:
            if not os.path.isfile(_path):
                print_metadata(0, 0)
                print(f"Error: --{_attr.replace('_', '-')} not found: {_path}",
                      file=sys.stderr)
                sys.exit(1)
            with open(_path, "r", encoding="utf-8", errors="replace") as f:
                setattr(args, _attr.replace("_file", ""), f.read().strip())
    for _attr in ("keep_file", "drop_file"):
        _path = getattr(args, _attr)
        if _path:
            if not os.path.isfile(_path):
                print_metadata(0, 0)
                print(f"Error: --{_attr.replace('_', '-')} not found: {_path}",
                      file=sys.stderr)
                sys.exit(1)
            with open(_path, "r", encoding="utf-8", errors="replace") as f:
                _target = _attr.replace("_file", "")
                setattr(args, _target, "|".join(
                    line.strip() for line in f if line.strip()
                ))

    import time as _time
    _t0 = _time.time()

    if not os.path.isfile(args.input):
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    initial_sources = [args.input]
    if args.compare:
        initial_sources.append(args.compare)
    try:
        _reject_output_collisions(initial_sources, args.output, args.format)
    except ValueError as exc:
        print_metadata(0, 0)
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    if args.check_output_only:
        return

    # R2: Read input with encoding cascade: UTF-8 -> Latin-1.
    raw_text = read_text_file(args.input)

    # Determine title
    title = args.title or os.path.splitext(os.path.basename(args.input))[0]

    # Base directory for resolving graph paths
    base_dir = args.graph_base or os.path.dirname(os.path.abspath(args.input))

    # Parse into lines and blocks
    raw_lines = raw_text.split("\n")

    # U4: Progress feedback for large logs
    if len(raw_lines) > 5000:
        print(f"logdoc: processing {len(raw_lines)} lines...",
              file=sys.stderr)

    blocks = parse_blocks(raw_lines)

    # F6: Apply keep/drop filtering
    blocks = filter_blocks(blocks, keep=args.keep, drop=args.drop)

    if not blocks and not args.combine_file:
        print("Warning: No content blocks found in input", file=sys.stderr)
        print_metadata(0, 0)
        sys.exit(1)

    use_enhanced_html = any((
        args.fold, args.highlight, args.tables, args.copy, args.download,
        args.legacy, args.linenumbers, args.toc, args.notebook, args.email,
        args.annotate,
    ))

    # Determine CSS -- default HTML uses a compact faithful core stylesheet.
    # Opt-in enhancements use the full built-in theme CSS (the single source:
    # net install does not install .css files).  --css replaces it with the
    # user's own stylesheet.
    if not args.css and not use_enhanced_html and args.format in ("html", "both"):
        theme_css = CSS_CORE_DARK if args.theme == "dark" else CSS_CORE_LIGHT
    elif args.css:
        theme_css = load_css(args.css)
    elif args.theme == "dark":
        theme_css = CSS_DARK
    else:
        theme_css = CSS_LIGHT
    theme_css = apply_accent_css(theme_css, args.accent)

    # C7: Load annotations if provided
    annot = {'block': {}, 'command': {}}
    if args.annotate:
        annot = parse_annotations(args.annotate)

    # Combine mode — source manifest is written by logdoc.ado.
    if args.combine_file:
        if not os.path.isfile(args.combine_file):
            print_metadata(0, 0)
            print(f"Error: Combine manifest not found: {args.combine_file}",
                  file=sys.stderr)
            sys.exit(1)
        sources = read_combine_manifest(args.combine_file)
        if not sources:
            print_metadata(0, 0)
            print("Error: Combine manifest is empty", file=sys.stderr)
            sys.exit(1)
        for source in sources:
            if not os.path.isfile(source):
                print_metadata(0, 0)
                print(f"Error: Combine source not found: {source}",
                      file=sys.stderr)
                sys.exit(1)
        try:
            _reject_output_collisions(sources, args.output, args.format)
        except ValueError as exc:
            print_metadata(0, 0)
            print(f"Error: {exc}", file=sys.stderr)
            sys.exit(1)

        fmt = args.format
        output_path = args.output
        totals = {"blocks": 0, "graphs": 0, "tables": 0, "warnings": 0}

        if fmt in ("html", "both"):
            html_out = output_path if fmt == "html" else _swap_ext(output_path, ".html")
            html_content, html_totals = render_combined_html(
                sources, args, theme_css, annotations=annot,
                use_enhanced_html=use_enhanced_html,
            )
            totals = html_totals
            if args.append and os.path.isfile(html_out):
                with open(html_out, "r", encoding="utf-8",
                          errors="replace") as f:
                    existing = f.read()
                try:
                    html_content = _append_html_document(
                        existing, html_content
                    )
                except ValueError as exc:
                    print_metadata(0, 0)
                    print(f"Error: {exc}", file=sys.stderr)
                    sys.exit(1)
            os.makedirs(os.path.dirname(os.path.abspath(html_out)), exist_ok=True)
            with open(html_out, "w", encoding="utf-8") as f:
                f.write(html_content)
            print(f"Generated: {html_out}")

        if fmt in ("md", "qmd", "both"):
            md_out = output_path if fmt in ("md", "qmd") else _swap_ext(output_path, ".md")
            md_content, md_totals = render_combined_markdown(sources, args, fmt=fmt)
            if totals["blocks"] == 0:
                totals = md_totals
            if args.append and os.path.isfile(md_out):
                with open(md_out, "r", encoding="utf-8",
                          errors="replace") as f:
                    existing_md = f.read()
                md_content = _append_markdown_document(existing_md, md_content)
            os.makedirs(os.path.dirname(os.path.abspath(md_out)), exist_ok=True)
            with open(md_out, "w", encoding="utf-8") as f:
                f.write(md_content)
            print(f"Generated: {md_out}")

        if fmt == "tex":
            tex_content, totals = render_combined_latex(sources, args)
            if args.append and os.path.isfile(output_path):
                with open(output_path, "r", encoding="utf-8",
                          errors="replace") as f:
                    existing_tex = f.read()
                tex_content = _append_latex_document(existing_tex, tex_content)
            os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(tex_content)
            print(f"Generated: {output_path}")

        total_size = 0
        if fmt == "both":
            for candidate in (_swap_ext(output_path, ".html"),
                              _swap_ext(output_path, ".md")):
                try:
                    total_size += os.path.getsize(candidate)
                except OSError:
                    pass
        else:
            try:
                total_size = os.path.getsize(output_path)
            except OSError:
                total_size = 0

        print_metadata(
            totals["blocks"], total_size, totals["graphs"],
            totals["tables"], totals["warnings"]
        )
        if args.verbose:
            elapsed = _time.time() - _t0
            print(
                f"logdoc: {totals['blocks']} blocks processed in {elapsed:.2f}s",
                file=sys.stderr,
            )
        return

    # C2: Diff mode — compare two files
    if args.compare:
        if not os.path.isfile(args.compare):
            print(f"Error: Compare file not found: {args.compare}",
                  file=sys.stderr)
            sys.exit(1)
        raw_text_b = read_text_file(args.compare)
        blocks_b = parse_blocks(raw_text_b.split("\n"))
        diff_html = render_diff_html(
            blocks, blocks_b, title=f"Diff: {title}",
            theme_css=theme_css, base_dir=base_dir,
            generated=args.generated,
            file_a=args.input, file_b=args.compare,
        )
        os.makedirs(os.path.dirname(os.path.abspath(args.output)),
                     exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(diff_html)
        print(f"Generated: {args.output}")
        nblocks = len(blocks) + len(blocks_b)
        total_size = os.path.getsize(args.output)
        stats_a = metadata_for_blocks(blocks, base_dir, nograph=args.nograph)
        base_dir_b = os.path.dirname(os.path.abspath(args.compare))
        stats_b = metadata_for_blocks(blocks_b, base_dir_b,
                                      nograph=args.nograph)
        print_metadata(
            nblocks, total_size,
            stats_a["graphs"] + stats_b["graphs"],
            stats_a["tables"] + stats_b["tables"],
            stats_a["warnings"] + stats_b["warnings"],
        )
        if args.verbose:
            elapsed = _time.time() - _t0
            print(f"logdoc: {nblocks} blocks processed in {elapsed:.2f}s",
                  file=sys.stderr)
        return

    # R3: Normalize Windows backslashes in graph paths
    # (os.path handles both, but ensure consistency)

    # Render
    fmt = args.format
    output_path = args.output
    opt_fold = (args.fold or args.legacy) and not args.nofold
    opt_highlight = args.highlight or args.legacy
    opt_tables = (args.tables or args.legacy) and not args.preformatted
    opt_copy = args.copy or args.legacy
    opt_download = args.download or args.legacy

    if fmt in ("html", "both"):
        html_out = output_path if fmt == "html" else _swap_ext(output_path, ".html")
        if use_enhanced_html:
            html_content = render_html(
                blocks, title=title, theme_css=theme_css,
                preformatted=args.preformatted, nofold=args.nofold,
                nodots=args.nodots, date=args.date, base_dir=base_dir,
                footer=args.footer, stamp=args.stamp, nograph=args.nograph,
                graphwidth=args.graphwidth, graphheight=args.graphheight,
                linenumbers=args.linenumbers, toc=args.toc,
                notebook=args.notebook, email=args.email,
                annotations=annot,
                fold=opt_fold, highlight=opt_highlight, tables=opt_tables,
                copy=opt_copy, download=opt_download,
                generated=args.generated,
            )
        else:
            html_content = render_html_faithful(
                blocks, title=title, theme_css=theme_css,
                nodots=args.nodots, date=args.date, base_dir=base_dir,
                footer=args.footer, stamp=args.stamp, nograph=args.nograph,
                graphwidth=args.graphwidth, graphheight=args.graphheight,
                generated=args.generated,
            )

        # I4: Append mode
        if args.append and os.path.isfile(html_out):
            with open(html_out, "r", encoding="utf-8",
                      errors="replace") as f:
                existing = f.read()
            try:
                html_content = _append_html_document(existing, html_content)
            except ValueError as exc:
                print_metadata(0, 0)
                print(f"Error: {exc}", file=sys.stderr)
                sys.exit(1)

        os.makedirs(os.path.dirname(os.path.abspath(html_out)), exist_ok=True)
        with open(html_out, "w", encoding="utf-8") as f:
            f.write(html_content)
        print(f"Generated: {html_out}")

    if fmt in ("md", "qmd", "both"):
        # Re-parse blocks since expand_block mutates them
        blocks = parse_blocks(raw_text.split("\n"))
        blocks = filter_blocks(blocks, keep=args.keep, drop=args.drop)
        md_out = output_path if fmt in ("md", "qmd") else _swap_ext(output_path, ".md")
        md_output_dir = os.path.dirname(os.path.abspath(md_out))
        md_content = render_markdown(
            blocks, title=title, nofold=args.nofold,
            nodots=args.nodots, date=args.date, base_dir=base_dir,
            output_dir=md_output_dir,
            footer=args.footer, stamp=args.stamp, nograph=args.nograph,
            generated=args.generated,
        )
        # I4: Append mode for non-HTML
        if args.append and os.path.isfile(md_out):
            with open(md_out, "r", encoding="utf-8",
                      errors="replace") as f:
                existing_md = f.read()
            md_content = _append_markdown_document(existing_md, md_content)

        os.makedirs(os.path.dirname(os.path.abspath(md_out)), exist_ok=True)
        with open(md_out, "w", encoding="utf-8") as f:
            f.write(md_content)
        print(f"Generated: {md_out}")

    if fmt == "tex":
        # Re-parse blocks since expand_block mutates them
        blocks = parse_blocks(raw_text.split("\n"))
        blocks = filter_blocks(blocks, keep=args.keep, drop=args.drop)
        tex_out = output_path
        tex_content = render_latex(
            blocks, title=title, nodots=args.nodots, date=args.date,
            base_dir=base_dir, footer=args.footer, stamp=args.stamp,
            nograph=args.nograph, generated=args.generated,
            output_dir=os.path.dirname(os.path.abspath(tex_out)),
        )
        # I4: Append mode for non-HTML
        if args.append and os.path.isfile(tex_out):
            with open(tex_out, "r", encoding="utf-8",
                      errors="replace") as f:
                existing_tex = f.read()
            tex_content = _append_latex_document(existing_tex, tex_content)

        os.makedirs(os.path.dirname(os.path.abspath(tex_out)), exist_ok=True)
        with open(tex_out, "w", encoding="utf-8") as f:
            f.write(tex_content)
        print(f"Generated: {tex_out}")

    # I1: Print metadata for .ado to capture
    nblocks = len(blocks)
    stats = metadata_for_blocks(blocks, base_dir, nograph=args.nograph,
                                latex=(fmt == "tex"))
    # Compute total output filesize
    total_size = 0
    if fmt in ("html", "both"):
        try:
            total_size += os.path.getsize(html_out)
        except OSError:
            pass
    if fmt in ("md", "qmd", "both"):
        try:
            total_size += os.path.getsize(md_out)
        except OSError:
            pass
    if fmt == "tex":
        try:
            total_size += os.path.getsize(tex_out)
        except OSError:
            pass
    print_metadata(
        nblocks, total_size, stats["graphs"],
        stats["tables"], stats["warnings"]
    )

    # Verbose output
    if args.verbose:
        elapsed = _time.time() - _t0
        print(f"logdoc: {nblocks} blocks processed in {elapsed:.2f}s",
              file=sys.stderr)


def _swap_ext(path, new_ext):
    """Swap file extension."""
    base, _ = os.path.splitext(path)
    return base + new_ext


if __name__ == "__main__":
    main()
    print("LOGDOC_OK")
