"""Dump the visible text of a rendered tabtools Markdown export, one element per line.

Usage:
    python3 md_facts.py FILE.md RESULT.txt

The file is rendered exactly as check_md_render.py renders it (markdown-it-py,
CommonMark with raw HTML enabled and GFM tables on), and RESULT.txt receives
one "tag<TAB>text" line per top-level h3, th, td and em element, in document
order, UTF-8. A Stata suite then asserts that an exact line is present, e.g.
that the table heading renders as the literal title text. Reading the
rendered text keeps the oracle independent of the writer's escaping.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from markdown_it import MarkdownIt  # noqa: E402

from check_md_render import _Collector  # noqa: E402


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    md_file, result_file = argv[1:]
    with open(md_file, encoding="utf-8") as fh:
        source = fh.read()
    html = MarkdownIt("commonmark", {"html": True}).enable("table").render(source)
    collector = _Collector()
    collector.feed(html)
    with open(result_file, "w", encoding="utf-8") as fh:
        for tag, text in collector.items:
            fh.write(f"{tag}\t{text.strip()}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
