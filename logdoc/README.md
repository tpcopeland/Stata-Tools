# logdoc

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Convert Stata SMCL/log files to self-contained HTML or Markdown documents.

## Description

`logdoc` transforms Stata `.smcl`, `.log`, or `.do` files into styled, shareable documents. HTML output is fully self-contained -- CSS is inlined, graphs are base64-encoded, and no external dependencies are needed. The result can be emailed, uploaded, or printed to PDF directly from a browser.

The output uses a Quarto-inspired layout with syntax-highlighted Stata commands, formatted regression tables, collapsible verbose output sections, and embedded graphs. A dark theme (Catppuccin-inspired) is also available.

## Features

- **Syntax-highlighted commands** with copy-to-clipboard buttons (hover to reveal)
- **Regression tables** automatically converted to formatted HTML tables (or keep as monospace with `preformatted`)
- **Collapsible sections** for verbose output like `summarize, detail` (disable with `nofold`)
- **Base64-embedded graphs** -- fully standalone HTML, no external image files
- **Light and dark themes** -- clean Quarto-style white or Catppuccin-style terminal dark
- **Script-style output** with `nodots` (strips `. ` and `> ` prompts)
- **Print-optimized CSS** -- copy buttons hidden, collapsibles expanded, page breaks avoid splitting code blocks
- **Markdown output** with YAML front matter
- **Dual output** with `format(both)` for HTML + Markdown from one command
- **Run-and-convert** with `run` option: execute a `.do` file, then convert the resulting log

## Installation

```stata
net install logdoc, from("https://raw.githubusercontent.com/tcopeland/Stata-Dev/main/logdoc/") replace
```

## Requirements

- Stata 16.0+
- Python 3.6+ (standard library only -- no pip packages needed)

## Syntax

```stata
logdoc using filename, output(filename) [options]
```

### Options

| Option | Description |
|--------|-------------|
| `output(filename)` | Output file path (**required**) |
| `format(html|md|both)` | Output format; default `html` |
| `theme(light|dark)` | CSS theme; default `light` |
| `title(string)` | Document title; defaults to input filename |
| `date(string)` | Date subtitle shown below the title |
| `run` | Execute a `.do` file first, then convert the resulting log |
| `preformatted` | Keep regression tables as monospace blocks (skip HTML table conversion) |
| `nofold` | Disable collapsible `<details>` sections for verbose output |
| `nodots` | Strip `. ` and `> ` prompts for cleaner script-style display |
| `python(string)` | Explicit path to the Python 3 executable |
| `replace` | Overwrite existing output file |

### Input formats

| Extension | Behavior |
|-----------|----------|
| `.smcl` | Full SMCL tag parsing with rich formatting |
| `.log` | Plain text log file conversion |
| `.do` | Requires `run` option; executes the do-file in batch mode, then converts the resulting log |

## Examples

```stata
* Basic: SMCL log to HTML
logdoc using "analysis.smcl", output("analysis.html") replace

* Markdown output
logdoc using "results.smcl", output("results.md") format(md) replace

* Both HTML and Markdown from one command
logdoc using "output.smcl", output("output.html") format(both) replace

* Dark theme with a title and date
logdoc using "output.smcl", output("output.html") theme(dark) ///
    title("Survival Analysis") date("March 2026") replace

* Run a .do file, then convert to HTML
logdoc using "analysis.do", output("analysis.html") run replace

* Clean script-style output (no dot prompts)
logdoc using "results.smcl", output("results.html") nodots replace

* Monospace tables, no collapsible sections
logdoc using "results.smcl", output("results.html") preformatted nofold replace
```

## HTML Output Details

### Copy Button

Every command block includes a copy-to-clipboard button that appears on hover.

### Collapsible Sections

Verbose output (e.g., `summarize, detail` or output longer than 30 lines) is wrapped in a collapsible `<details>` element by default. Use `nofold` to keep everything expanded.

### Print / PDF Export

The HTML includes a print-optimized stylesheet. When printing or using "Save as PDF" in a browser:

- Copy buttons are hidden
- Collapsible sections are automatically expanded
- Page breaks avoid splitting code blocks and tables
- Dark theme converts to light colors for paper

### Self-Contained

CSS is inlined in a `<style>` tag and graph images are base64-encoded directly in `<img>` tags. The output file has zero external dependencies.

## Stored Results

| Macro | Contents |
|-------|----------|
| `r(output)` | Output file path |
| `r(input)` | Input file path (may differ from `using` if `run` was used) |
| `r(format)` | Output format used |
| `r(theme)` | Theme used |

## Version

- **1.1.0** (15 March 2026): CSS expansion fix, `format(both)` secondary file verification, table header double-escape fix, greedy dot-match classifier fix, embedded CSS fallbacks for `net install`, YAML title escaping, fold heuristic improvements, expanded SMCL character map
- **1.0.0** (14 March 2026): Initial release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License
