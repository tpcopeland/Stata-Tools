"""Render a tabtools Markdown export and compare its visible text.

Usage:
    python3 check_md_render.py FILE.md EXPECTED.txt RESULT.txt

The Markdown file is rendered with markdown-it-py as CommonMark with raw HTML
enabled and the GFM table and strikethrough extensions on, which is how
GitHub, Quarto and most viewers treat the output (~~x~~ renders as struck
text there). The visible text of every h3, th, td and em element is collected
in document order (tags removed, entities decoded) and compared with
EXPECTED.txt, one "tag<TAB>text" line per element, UTF-8. RESULT.txt receives
"PASS" or "FAIL" followed by a description of the first mismatch.

A cell whose source text contained live HTML, an entity, link syntax or a
code span renders differently from its source, so this is the axis on which
Markdown escaping is judged. Checking the characters in the .md source alone
cannot see it.
"""

import sys
from html.parser import HTMLParser

from markdown_it import MarkdownIt

TAGS = ("h3", "th", "td", "em")


class _Collector(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.items = []

    def handle_starttag(self, tag, attrs):
        if tag in TAGS:
            self.stack.append([tag, ""])

    def handle_endtag(self, tag):
        if tag in TAGS and self.stack and self.stack[-1][0] == tag:
            name, text = self.stack.pop()
            # An em nested in a cell is part of that cell's text and would
            # already show as a mismatch there; only top-level elements count.
            if self.stack:
                self.stack[-1][1] += text
            else:
                self.items.append((name, text))

    def handle_data(self, data):
        if self.stack:
            self.stack[-1][1] += data


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    md_file, expected_file, result_file = argv[1:]
    with open(md_file, encoding="utf-8") as fh:
        source = fh.read()
    html = MarkdownIt("commonmark", {"html": True}).enable(["table", "strikethrough"]).render(source)
    collector = _Collector()
    collector.feed(html)
    got = collector.items

    want = []
    with open(expected_file, encoding="utf-8") as fh:
        for line in fh.read().split("\n"):
            if line == "":
                continue
            tag, _, text = line.partition("\t")
            want.append((tag, text))

    verdict = "PASS"
    if got != want:
        verdict = "FAIL"
        for i in range(max(len(got), len(want))):
            g = got[i] if i < len(got) else None
            w = want[i] if i < len(want) else None
            if g != w:
                verdict += f"\nitem {i + 1}: rendered {g!r}, expected {w!r}"
                break
        verdict += f"\nrendered HTML:\n{html}"
    with open(result_file, "w", encoding="utf-8") as fh:
        fh.write(verdict + "\n")
    print(verdict)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
