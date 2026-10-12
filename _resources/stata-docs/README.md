# stata_docs.py: search your Stata manuals offline

`stata_docs.py` turns the Stata PDF manuals that come with your Stata installation into a local, searchable documentation library. Searching and reading it work offline, and each result cites the manual, entry, and PDF page it came from. It is useful on its own, and it is especially useful with a coding assistant (Claude, Copilot, ChatGPT, and others). The assistant can look up the actual manual passage for a command or option instead of working from memory, and cite where the passage came from.

It is a single Python file with no other repository dependencies. Copy it anywhere.

> [!NOTE]
> No manuals are included here. The Stata documentation is copyright © StataCorp LLC; you build the library from **your own** licensed PDFs. Those PDFs remain the authoritative reference.

## Requirements

- **Python 3.10+.** Searching and reading use only the standard library.
- **[PyMuPDF](https://pymupdf.readthedocs.io/) 1.24+** for the one-time build step only.

```bash
python3 -m venv .venv
.venv/bin/python -m pip install 'PyMuPDF>=1.24'
```

## 1. Build the library (once, and after a Stata upgrade)

Point it at the folder of PDF manuals in your Stata installation. It searches subfolders. Stata keeps the manuals in a `docs` folder inside its installation directory, for example `/usr/local/stata17/docs` on Linux. The files are named by manual code (`p.pdf`, `r.pdf`, `st.pdf`, …).

```bash
.venv/bin/python stata_docs.py build /path/to/stata/docs -o Stata-Library
```

To build only some manuals, select them by file name; for example, `p` is the Programming Reference Manual and `r` is the Base Reference Manual:

```bash
.venv/bin/python stata_docs.py build /path/to/stata/docs -o Stata-Library --manual p --manual r
```

Re-running `build` refreshes the library and reuses any manual that has not changed. `-o` must be a folder dedicated to the generated library.

## 2. Search and read

```bash
# Ranked passages for literal terms, filtered to one manual
python3 stata_docs.py search 'capture _rc' -o Stata-Library --manual P --limit 3

# Read one section of an entry, or the whole entry
python3 stata_docs.py get P/syntax  -o Stata-Library --section Syntax
python3 stata_docs.py get P/capture -o Stata-Library

# Compact JSON, for scripts and assistants
python3 stata_docs.py search 'syntax varlist' -o Stata-Library --manual P --json --compact

# Check the library against its sources
python3 stata_docs.py verify -o Stata-Library --sources /path/to/stata/docs
```

Search treats every word literally and requires all of them; ranking favours entry titles and section headings. Stata punctuation such as `_rc`, `` ` ``, or `/` is safe to use. If a query returns nothing, drop a term.

## 3. Use it with a coding assistant

Point the assistant at the library folder. The build writes two guide files there, `AGENTS.md` and `llms.txt`, which tell an assistant how to search and cite efficiently. A sample instruction:

> Use `/path/to/Stata-Library` as the Stata reference. Before you use a command or option, search for it, read the relevant passage, and cite the manual, entry, and PDF page. For formulas or figures, check the cited page in the source PDF.

## Optional: example-dataset links

This command fetches the Stata Press dataset catalogue pages: link metadata only, nothing downloaded or run. It makes the manuals' example datasets searchable:

```bash
python3 stata_docs.py import-datasets -o Stata-Library --stata-version 18
python3 stata_docs.py search-datasets 'auto' -o Stata-Library
```

## Limits

- **Text layer only:** it extracts the PDFs' text layer and does not use OCR.
- **Equations and figures:** these are not reconstructed; check them on the cited PDF page.
- **Scope:** coverage is whatever PDFs you supply.
- **Not a substitute:** the library is a retrieval aid, not a replacement for the manuals.

Run `python3 stata_docs.py --help` or `python3 stata_docs.py <command> --help` for every option.
