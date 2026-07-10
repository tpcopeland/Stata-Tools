{smcl}
{* *! version 1.1.2  09jul2026}{...}
{vieweralsosee "logdoc_py" "help logdoc_py"}{...}
{viewerjumpto "Syntax" "logdoc##syntax"}{...}
{viewerjumpto "Setup" "logdoc##setup"}{...}
{viewerjumpto "Description" "logdoc##description"}{...}
{viewerjumpto "Subcommands" "logdoc##subcommands"}{...}
{viewerjumpto "Options" "logdoc##options"}{...}
{viewerjumpto "Workflow" "logdoc##workflow"}{...}
{viewerjumpto "Examples" "logdoc##examples"}{...}
{viewerjumpto "Stored results" "logdoc##results"}{...}
{viewerjumpto "Tips" "logdoc##tips"}{...}
{viewerjumpto "Troubleshooting" "logdoc##troubleshooting"}{...}
{viewerjumpto "Requirements" "logdoc##requirements"}{...}
{viewerjumpto "Author" "logdoc##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:logdoc} {hline 2}}Convert Stata log files to faithful HTML, Markdown, Word, LaTeX, Quarto, or PDF documents{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Convert a log file to a document:

{p 8 17 2}
{cmd:logdoc}
{cmd:using}
{it:filename}
{cmd:,}
{opt out:put(filename)}
[{it:options}]

{pstd}
Live session mode:

{p 8 17 2}
{cmd:logdoc start}
{cmd:,}
{opt out:put(filename)}
[{it:options}]

{p 8 17 2}
{cmd:logdoc stop}

{pstd}
Other subcommands:

{p 8 17 2}
{cmd:logdoc diff}
{cmd:using}
{it:filename}
{cmd:,}
{opt comp:are(filename)}
{opt out:put(filename)}
[{opt rep:lace} {opt th:eme(string)} {opt py:thon(string)} {opt css(filename)} {opt acc:ent(#RRGGBB)} {opt q:uiet}]

{p 8 17 2}
{cmd:logdoc batch}
{cmd:,}
{opt in:put(string)}
{opt out:dir(string)}
[{it:options}]

{p 8 17 2}
{cmd:logdoc combine}
{cmd:using}
{it:file1}
{it:file2}
[{it:...}]
{cmd:,}
{opt out:put(filename)}
[{it:options}]

{p 8 17 2}
{cmd:logdoc replay}
[{cmd:,} {opt th:eme(string)} {opt f:ormat(string)} {opt open}]

{synoptset 28 tabbed}{...}
{synopthdr:options}
{synoptline}
{p2coldent:* {opt out:put(filename)}}output file path{p_end}

{syntab:Format & theme}
{synopt:{opt f:ormat(string)}}output format: {bf:html} (default), {bf:md}, {bf:qmd}, {bf:both}, {bf:docx}, {bf:tex}, or {bf:pdf}{p_end}
{synopt:{opt th:eme(string)}}CSS theme: {bf:light} (default) or {bf:dark}{p_end}
{synopt:{opt css(filename)}}custom CSS file (overrides theme){p_end}
{synopt:{opt acc:ent(#RRGGBB)}}brand/accent color for headings, links, and controls{p_end}

{syntab:Document metadata}
{synopt:{opt ti:tle(string)}}document title; defaults to input filename{p_end}
{synopt:{opt date(string)}}date subtitle shown in document header{p_end}
{synopt:{opt foot:er(string)}}custom footer text{p_end}
{synopt:{opt gen:erated}}add "Generated YYYY-MM-DD HH:MM" footer{p_end}
{synopt:{opt st:amp}}add Stata version, date/time, and data filename to header{p_end}

{syntab:Display & layout}
{synopt:{opt run}}execute .do file first, then convert the resulting log{p_end}
{synopt:{opt statae:xe(string)}}name of the Stata batch executable used by {opt run} (default: auto-detected from flavor/OS){p_end}
{synopt:{opt pre:formatted}}compatibility option; HTML tables are monospace by default{p_end}
{synopt:{opt nof:old}}compatibility option; folding is off by default{p_end}
{synopt:{opt nod:ots}}strip dot prompts from commands for cleaner display{p_end}
{synopt:{opt fold}}collapse long output blocks into expandable sections{p_end}
{synopt:{opt high:light}}add Stata syntax highlighting to command blocks{p_end}
{synopt:{opt tab:les}}parse supported Stata tables into HTML tables{p_end}
{synopt:{opt copy}}add copy-to-clipboard buttons to command blocks{p_end}
{synopt:{opt down:load}}add a Download .do toolbar button{p_end}
{synopt:{opt leg:acy}}enable all HTML enhancements in one switch{p_end}
{synopt:{opt line:numbers}}show line numbers in command blocks{p_end}
{synopt:{opt toc}}generate a table of contents from section markers{p_end}
{synopt:{opt note:book}}Jupyter-style cell layout with In/Out labels{p_end}
{synopt:{opt ema:il}}email-safe HTML with inline CSS (no {cmd:<style>} block){p_end}
{synopt:{opt nog:raph}}skip graph detection and embedding{p_end}
{synopt:{opt graphw:idth(#)}}set embedded graph width in pixels{p_end}
{synopt:{opt graphh:eight(#)}}set embedded graph height in pixels{p_end}

{syntab:Filtering}
{synopt:{opt keep(string)}}only include commands matching pattern{p_end}
{synopt:{opt drop(string)}}exclude commands matching pattern{p_end}

{syntab:Other}
{synopt:{opt open}}open the output file in the default browser after generation{p_end}
{synopt:{opt app:end}}append to existing HTML, Markdown, Quarto Markdown, or LaTeX output{p_end}
{synopt:{opt ann:otate(filename)}}annotation file with notes to embed in output{p_end}
{synopt:{opt py:thon(string)}}explicit path to Python executable{p_end}
{synopt:{opt q:uiet}}suppress all status messages{p_end}
{synopt:{opt v:erbose}}show detailed processing information{p_end}
{synopt:{opt rep:lace}}overwrite existing output file{p_end}
{synoptline}
{p 4 6 2}* {opt output()} is required.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:logdoc} converts Stata {bf:.smcl}, {bf:.log}, or {bf:.do} files into
styled, self-contained documents. Output formats include HTML, Markdown,
Quarto Markdown (.qmd), Word (.docx), LaTeX (.tex), and PDF.

{pstd}
HTML output is faithful by default: Stata's monospace alignment, SMCL
input/result/error coloring, table spacing, and horizontal rules are
preserved rather than reinterpreted. Syntax highlighting, parsed HTML
tables, collapsible output, copy buttons, and Download .do controls are
available only when explicitly requested.

{pstd}
The command uses Python 3 (standard library only, no external dependencies)
to expand SMCL tags, preserve Stata output, embed graphs, and render to
the chosen format.

{pstd}
{bf:Input formats:}

{p2colset 9 22 24 2}{...}
{p2col:{bf:.smcl}}Stata SMCL log files with faithful input/result/error colors{p_end}
{p2col:{bf:.log}}Plain text log files{p_end}
{p2col:{bf:.do}}Do-files (requires {opt run} option; auto-sets {opt replace}){p_end}
{p2colreset}{...}

{pstd}
{bf:Output formats:}

{p2colset 9 22 24 2}{...}
{p2col:{bf:html}}Self-contained HTML with inlined CSS and base64 graphs{p_end}
{p2col:{bf:md}}Markdown with YAML front matter{p_end}
{p2col:{bf:qmd}}Quarto-flavored Markdown with YAML front matter{p_end}
{p2col:{bf:both}}HTML and Markdown from one command{p_end}
{p2col:{bf:docx}}Word document via Stata's {cmd:html2docx} (requires Stata 17+){p_end}
{p2col:{bf:tex}}LaTeX document with listings and booktabs{p_end}
{p2col:{bf:pdf}}PDF via xhtml2pdf (preferred) or wkhtmltopdf{p_end}
{p2colreset}{...}

{pstd}
The format is auto-detected from the output file extension when {opt format()}
is not specified. For example, {cmd:output("report.md")} automatically uses
Markdown format.


{marker subcommands}{...}
{title:Subcommands}

{dlgtab:logdoc start / logdoc stop}

{pstd}
Wraps an interactive session. {cmd:logdoc start} opens a background SMCL
log; {cmd:logdoc stop} closes the log and converts it. This eliminates the two-step
"log then convert" workflow. If the conversion fails, {cmd:logdoc stop} keeps the
captured SMCL log and prints its path so the session transcript can be
converted manually.

{phang2}{cmd:. logdoc start, output("session.html") theme(dark)}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. regress price mpg weight}{p_end}
{phang2}{cmd:. logdoc stop}{p_end}

{dlgtab:logdoc diff}

{pstd}
Produces a side-by-side diff of two log files, highlighting added and removed
content with color-coded blocks.

{phang2}{cmd:. logdoc diff using "old.smcl", compare("new.smcl") output("diff.html") replace}{p_end}

{dlgtab:logdoc batch}

{pstd}
Converts multiple files matching a glob pattern in one command.

{phang2}{cmd:. logdoc batch, input("*.smcl") outdir("/reports/") replace}{p_end}

{dlgtab:logdoc combine}

{pstd}
Combines two or more log files into one document with source-level sections
and a table of contents. Supported output formats are HTML, Markdown,
Quarto Markdown, LaTeX, and {opt format(both)}.

{phang2}{cmd:. logdoc combine using "model.smcl" "tables.smcl", output("report.html") toc replace}{p_end}

{dlgtab:logdoc replay}

{pstd}
Re-runs the most recent {cmd:logdoc} conversion using the last resolved
options, with optional overrides. Useful for quickly switching themes
or formats without retyping metadata or filtering options. If the
previous conversion used {opt run}, replay re-executes the .do file in
batch mode (with the same {opt stataexe()} setting) before converting.

{phang2}{cmd:. logdoc replay, theme(dark)}{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Format & theme}

{phang}
{opt format(string)} selects the output format. {bf:html} (default) produces a
self-contained HTML document. {bf:md} produces Markdown with YAML front
matter. {bf:both} generates both formats from the same input. {bf:docx} generates Word
via {cmd:html2docx} (Stata 17+). {bf:tex} generates LaTeX. {bf:pdf} generates PDF via
{cmd:xhtml2pdf} (preferred) or {cmd:wkhtmltopdf}.

{phang}
{opt theme(string)} selects the CSS theme for HTML output. {bf:light}
(default) uses a clean Stata-style white background. {bf:dark} uses a
compact Stata-style dark background.

{phang}
{opt css(filename)} specifies a custom CSS file, overriding the built-in
theme. The file must exist on disk.

{phang}
{opt accent(#RRGGBB)} applies a single brand color to built-in HTML styling
without requiring a custom CSS file. The value must be a six-digit hex color,
for example {cmd:accent("#005ea8")}. If {opt css()} is also specified,
{opt accent()} is applied after the custom CSS.

{dlgtab:Document metadata}

{phang}
{opt title(string)} sets the document title. Defaults to the input filename.

{phang}
{opt date(string)} adds a date subtitle below the title.

{phang}
{opt footer(string)} sets custom footer text. No footer appears by default.

{phang}
{opt generated} adds a "Generated YYYY-MM-DD HH:MM" timestamp footer. If both
{opt footer()} and {opt generated} are specified, {opt footer()} takes precedence.

{phang}
{opt stamp} adds a metadata line to the header showing the Stata version,
edition, date/time, and current data filename.

{dlgtab:Display & layout}

{phang}
{opt run} executes the input .do file in batch mode before converting. Automatically
sets {opt replace} for the output file. The child session is launched with the batch
Stata executable matching the running flavor and operating
system: {bf:stata-mp}/{bf:stata-se}/{bf:stata} on Unix and macOS,
{bf:StataMP-64}/{bf:StataSE-64}/{bf:Stata-64} on Windows. The chosen binary must be on the
system {cmd:PATH}.

{phang}
{opt stataexe(string)} overrides the auto-detected batch executable used by
{opt run}. Use it when your Stata binary has a nonstandard name or is not on
{cmd:PATH}. Example: {cmd:stataexe(/opt/stata18/stata-mp)}. Specifying
{opt stataexe()} without {opt run} is an error; a {cmd:stataexe=} line in
{cmd:.logdocrc} is simply ignored when {opt run} is not used.

{phang}
{opt preformatted} is retained for compatibility. HTML tables are already
monospace by default unless {opt tables} is specified.

{phang}
{opt nofold} is retained for compatibility. Folding is off by default unless
{opt fold} is specified.

{phang}
{opt nodots} strips Stata dot prompts for cleaner script-style display.

{phang}
{opt fold} collapses long output blocks into expandable {cmd:<details>}
sections and adds expand/collapse controls.

{phang}
{opt highlight} adds conservative Stata syntax highlighting to command
blocks. The default uses only Stata's SMCL input/result/error coloring.

{phang}
{opt tables} parses supported Stata tables into HTML {cmd:<table>} elements. If parsing
fails, logdoc falls back to monospace output.

{phang}
{opt copy} adds copy-to-clipboard buttons to command blocks.

{phang}
{opt download} adds a toolbar button that downloads displayed command blocks
as a .do file.

{phang}
{opt legacy} enables all HTML enhancements in one switch: {opt highlight}, {opt tables}, {opt fold},
{opt copy}, and {opt download}. Use {opt preformatted} or {opt nofold} with {opt legacy} to suppress table
parsing or folding.

{phang}
{opt linenumbers} adds line numbers to command blocks.

{phang}
{opt toc} generates a table of contents from section markers in comments. Use
{cmd:* # Section Title} in your .do file to create sections.

{phang}
{opt notebook} renders output in Jupyter-style cells with In/Out labels.

{phang}
{opt email} produces email-safe HTML with inline CSS instead of a
{cmd:<style>} block, compatible with email clients that strip stylesheets.

{phang}
{opt nograph} skips graph detection and embedding.

{phang}
{opt graphwidth(#)} and {opt graphheight(#)} set the display dimensions
(in pixels) for embedded graph images.

{dlgtab:Filtering}

{phang}
{opt keep(string)} retains only commands matching the specified pattern
and their output. For example, {cmd:keep("regress")} shows only regression
commands.

{phang}
{opt drop(string)} removes commands matching the pattern and their output. For
example, {cmd:drop("set *")} hides setup commands.

{dlgtab:Other}

{phang}
{opt open} opens the output file in the default browser (or application)
after generation.

{phang}
{opt append} appends new content to an existing output file instead of
replacing it. It does not require {opt replace}. Supported for HTML,
Markdown, LaTeX, and {opt format(both)} output; not supported with
{opt format(docx)} or {opt format(pdf)}.

{phang}
{opt annotate(filename)} specifies an annotation file containing notes
to embed alongside commands. Format: {cmd:@block N: text} or
{cmd:@command "pattern": text}.

{phang}
{opt python(string)} specifies an explicit path to the Python 3 executable. If
omitted, {cmd:logdoc} first uses Stata's configured Python executable from
{cmd:python query}; project and system-path fallbacks are used only when Stata's
Python is unavailable.

{phang}
{opt quiet} suppresses all status messages.

{phang}
{opt verbose} shows detailed processing information from the Python renderer.

{phang}
{opt replace} allows overwriting an existing output file.


{marker workflow}{...}
{title:Workflow}

{pstd}
{bf:Typical workflow:}

{phang}
1. Run your analysis and produce a log file ({cmd:.smcl} or {cmd:.log}).{p_end}
{phang}
2. Convert the log to a
document: {cmd:logdoc using "analysis.smcl", output("analysis.html") replace}{p_end}
{phang}
3. Share the self-contained HTML file by email, upload, or print to PDF.{p_end}

{pstd}
{bf:When to use logdoc vs. related tools:}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:logdoc}}Post-hoc conversion of existing SMCL/log files to faithful, shareable documents{p_end}
{p2col:{cmd:translate}}Convert SMCL to plain text, PostScript, or basic PDF with minimal styling{p_end}
{p2col:{cmd:dyndoc}}Author dynamic documents that execute Stata code embedded in Markdown-like source{p_end}
{p2col:{cmd:markstat}}Write literate analysis documents that mix prose, Stata code, and output{p_end}
{p2col:{cmd:texdoc/webdoc}}Write LaTeX or web documents from annotated Stata source files{p_end}
{p2col:{cmd:Quarto}}Author executable multi-language reports; logdoc's {bf:.qmd} output is rendered Markdown, not executable chunks{p_end}
{p2col:{cmd:markdown}}Convert Markdown text to HTML or Word (not log files){p_end}
{p2colreset}{...}

{pstd}
{bf:Section markers:} Structure your .do file with section headers using
comments. These become headings when {opt toc} is specified:

{phang2}{cmd:* # Data Preparation}{p_end}
{phang2}{cmd:* ## Loading data}{p_end}
{phang2}{cmd:* === Results ===}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
Basic: convert a SMCL log to HTML:

{phang2}{cmd:. logdoc using "myanalysis.smcl", output("myanalysis.html") replace}

{pstd}
Markdown (auto-detected from extension):

{phang2}{cmd:. logdoc using "results.smcl", output("results.md") replace}

{pstd}
Dark theme with title and date:

{phang2}{cmd:. logdoc using "results.smcl", output("results.html") theme(dark) title("Survival Analysis") date("March 2026") replace}

{pstd}
Institutional accent color:

{phang2}{cmd:. logdoc using "results.smcl", output("report.html") accent("#005ea8") replace}

{pstd}
Both HTML and Markdown:

{phang2}{cmd:. logdoc using "output.smcl", output("output.html") format(both) replace}

{pstd}
Run a .do file and convert:

{phang2}{cmd:. logdoc using "analysis.do", output("analysis.html") run}

{pstd}
Word document (Stata 17+):

{phang2}{cmd:. logdoc using "results.smcl", output("results.docx") replace}

{pstd}
LaTeX:

{phang2}{cmd:. logdoc using "results.smcl", output("results.tex") replace}

{pstd}
Quarto Markdown:

{phang2}{cmd:. logdoc using "results.smcl", output("results.qmd") replace}

{pstd}
Opt-in parsed/enhanced HTML:

{phang2}{cmd:. logdoc using "analysis.smcl", output("enhanced.html") highlight tables fold copy download replace}

{pstd}
Notebook mode with line numbers and table of contents:

{phang2}{cmd:. logdoc using "analysis.smcl", output("notebook.html") notebook linenumbers toc replace}

{pstd}
Filter output to show only regressions:

{phang2}{cmd:. logdoc using "results.smcl", output("regressions.html") keep("regress") replace}

{pstd}
Clean output: no dots, no fold, Stata version stamp:

{phang2}{cmd:. logdoc using "results.smcl", output("report.html") nodots nofold stamp replace}

{pstd}
Live session:

{phang2}{cmd:. logdoc start, output("session.html") open}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. summarize price mpg}{p_end}
{phang2}{cmd:. regress price mpg weight}{p_end}
{phang2}{cmd:. logdoc stop}

{pstd}
Batch convert all SMCL files:

{phang2}{cmd:. logdoc batch, input("*.smcl") outdir("reports/") replace}

{pstd}
Combine several logs into one project report:

{phang2}{cmd:. logdoc combine using "setup.smcl" "models.smcl" "tables.smcl", output("project_report.html") toc replace}

{pstd}
Replay with different theme:

{phang2}{cmd:. logdoc replay, theme(dark)}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:logdoc} and {cmd:logdoc stop} store the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(nblocks)}}number of rendered content blocks parsed{p_end}
{synopt:{cmd:r(filesize)}}output file size in bytes{p_end}
{synopt:{cmd:r(ngraphs)}}number of graph export commands detected{p_end}
{synopt:{cmd:r(ntables)}}number of table blocks detected{p_end}
{synopt:{cmd:r(nwarnings)}}number of renderer warnings, such as missing graph files{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(output)}}output file path{p_end}
{synopt:{cmd:r(input)}}input file path (may differ from {it:using} if {opt run} was specified){p_end}
{synopt:{cmd:r(format)}}output format used{p_end}
{synopt:{cmd:r(theme)}}theme used{p_end}
{synopt:{cmd:r(accent)}}accent color used, if specified{p_end}
{synopt:{cmd:r(secondary)}}secondary output path (only with {opt format(both)}){p_end}

{pstd}
{cmd:logdoc combine} stores the same conversion results plus:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(n_sources)}}number of source files combined{p_end}

{pstd}
{cmd:logdoc batch} stores:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(n_files)}}number of files processed{p_end}
{synopt:{cmd:r(n_failed)}}number of files that failed{p_end}

{pstd}
{cmd:logdoc diff} stores:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(output)}}output file path{p_end}
{synopt:{cmd:r(input)}}first (left-side) input file path{p_end}
{synopt:{cmd:r(compare)}}second (right-side) file path{p_end}


{marker tips}{...}
{title:Tips for best results}

{phang}
Use {bf:.smcl} format for input, not {bf:.log}. SMCL files contain rich
formatting tags that preserve Stata's input/result/error color semantics.

{phang}
Use {cmd:log using "file.smcl", nomsg} to avoid log metadata clutter in
the output.

{phang}
{cmd:logdoc start} and {cmd:logdoc using ... , run} set Stata's line size
to the maximum ({cmd:255}) while capturing output, then restore the caller's
line size where applicable. Existing log files are rendered as already
captured; rerun them with a wider line size if Stata wrapped them earlier.

{phang}
Structure your .do files with {cmd:* # Section Title} comments to create
navigable documents with the {opt toc} option.

{phang}
Use {opt legacy} if you want every HTML enhancement enabled in one
switch.

{phang}
For graph quality, set dimensions before export:{break}
{cmd:graph export "plot.png", width(800) replace}

{phang}
A global {cmd:~/.logdocrc} file can set defaults across projects, and a project
{cmd:.logdocrc} file in the working directory overrides those defaults. Command-line
options override both files. Format: one {it:key}{cmd:=}{it:value} per line (e.g., {cmd:theme=dark}
or {cmd:accent=#005ea8}). For Python setup diagnostics, run {helpb logdoc_py}; it follows
the same Stata-first Python convention as {cmd:logdoc}.


{marker troubleshooting}{...}
{title:Troubleshooting}

{phang}
{bf:Python 3 not found}: Run {cmd:python query} to inspect Stata's configured
Python and {cmd:logdoc_py, check verbose} to see all candidates. Use
{cmd:set python_exec} to configure Python for Stata, or use {opt python(path)}
for an explicit one-command override.

{phang}
{bf:Empty output}: Check that the input file is not empty and is valid
SMCL or log format. An empty input produces no output.

{phang}
{bf:Graphs not embedded}: Graphs are embedded only when a
{cmd:graph export} command appears in the log AND the image file exists
relative to the input file's directory. Use absolute paths for reliability.

{phang}
{bf:Tables not formatted}: Tables are rendered as monospace by default for
alignment fidelity. Use {opt tables} to request parsed HTML tables. If a
table cannot be parsed safely, logdoc falls back to monospace output.

{phang}
{bf:Python CLI}: Advanced users can call the renderer directly:{break}
{cmd:python3 logdoc_render.py --help}


{marker requirements}{...}
{title:Requirements}

{pstd}
{bf:Python 3.6+} must be installed. The recommended setup is Stata's
{cmd:python:} integration configured with {cmd:set python_exec}; {cmd:logdoc}
then launches the renderer with that same executable. No external Python
packages are required -- {cmd:logdoc} uses only the standard library.

{pstd}
Stata 16.0 or later. {opt format(docx)} requires Stata 17+. {opt format(pdf)} requires
{cmd:xhtml2pdf} or {cmd:wkhtmltopdf}.


{marker setup}{...}
{title:Setup}

{pstd}
{bf:Step 1: Install logdoc.} From within Stata:

{phang2}{cmd:. capture ado uninstall logdoc}{p_end}
{phang2}{cmd:. net install logdoc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/logdoc/") replace}{p_end}

{pstd}
{bf:Step 2: Check Python.} Run the setup diagnostic:

{phang2}{cmd:. logdoc_py}{p_end}

{pstd}
If {cmd:logdoc_py} reports "logdoc Python check passed" with a Python 3.6+
executable and renderer path, you are ready to use {cmd:logdoc}. No further
setup is needed.

{pstd}
{bf:If Python is not found:}

{phang}
{cmd:a.} Check whether Stata has a Python executable configured:{break}
{cmd:. python query}{break}
If the path is empty or wrong, configure it:{break}
{cmd:. set python_exec "/path/to/python3", permanently}{p_end}

{phang}
{cmd:b.} Alternatively, point {cmd:logdoc} at a specific Python for one
session:{break}
{cmd:. logdoc_py, python("/usr/local/bin/python3") set}{p_end}

{phang}
{cmd:c.} Or save the Python path to a per-project configuration file:{break}
{cmd:. logdoc_py, python("/usr/local/bin/python3") save}{p_end}

{pstd}
{bf:Step 3 (optional): Enable PDF output.} The recommended method is
{cmd:xhtml2pdf}, a pure Python library with no system dependencies:

{phang2}{cmd:. logdoc_py, install(xhtml2pdf)}{p_end}

{pstd}
Alternatively, {browse "https://wkhtmltopdf.org":wkhtmltopdf} works as a
system executable:

{phang2}Ubuntu/Debian: {cmd:sudo apt install wkhtmltopdf}{p_end}
{phang2}macOS (Homebrew): {cmd:brew install wkhtmltopdf}{p_end}
{phang2}RHEL/Fedora: {cmd:sudo dnf install wkhtmltopdf}{p_end}
{phang2}Windows (Chocolatey): {cmd:choco install wkhtmltopdf}{p_end}

{pstd}
logdoc tries xhtml2pdf first, then falls back to wkhtmltopdf. Verify
either is available:

{phang2}{cmd:. logdoc_py, check pdf}{p_end}

{pstd}
See {helpb logdoc_py} for the full detection order, verbose diagnostics, and
the portable setup contract.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
