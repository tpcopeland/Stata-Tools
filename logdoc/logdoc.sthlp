{smcl}
{* *! version 1.1.0  15mar2026}{...}
{viewerjumpto "Syntax" "logdoc##syntax"}{...}
{viewerjumpto "Description" "logdoc##description"}{...}
{viewerjumpto "Options" "logdoc##options"}{...}
{viewerjumpto "Examples" "logdoc##examples"}{...}
{viewerjumpto "Stored results" "logdoc##results"}{...}
{viewerjumpto "Requirements" "logdoc##requirements"}{...}
{viewerjumpto "Author" "logdoc##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:logdoc} {hline 2}}Convert Stata log files to HTML or Markdown documents{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:logdoc}
{cmd:using}
{it:filename}
{cmd:,}
{opt out:put(filename)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opt out:put(filename)}}output file path{p_end}
{synopt:{opt f:ormat(string)}}output format: {bf:html} (default), {bf:md}, or {bf:both}{p_end}
{synopt:{opt th:eme(string)}}CSS theme: {bf:light} (default) or {bf:dark}{p_end}
{synopt:{opt ti:tle(string)}}document title; defaults to input filename{p_end}
{synopt:{opt dat:e(string)}}date subtitle shown in document header{p_end}
{synopt:{opt run}}execute .do file first, then convert the resulting log{p_end}
{synopt:{opt pre:formatted}}keep regression tables as monospace blocks{p_end}
{synopt:{opt nof:old}}disable collapsible sections for verbose output{p_end}
{synopt:{opt nod:ots}}strip dot prompts from commands for cleaner display{p_end}
{synopt:{opt py:thon(string)}}explicit path to Python executable{p_end}
{synopt:{opt replace}}overwrite existing output file{p_end}
{synoptline}
{p 4 6 2}* {opt output()} is required.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:logdoc} converts Stata {bf:.smcl}, {bf:.log}, or {bf:.do} files into
self-contained HTML or Markdown documents. The output is styled in a
Quarto-inspired format with syntax-highlighted commands, formatted tables,
collapsible verbose output, and embedded graphs.

{pstd}
The command uses Python 3 (standard library only, no external dependencies)
to parse SMCL tags, classify content into semantic blocks (commands, tables,
output, errors), and render to the chosen format.

{pstd}
{bf:Input formats:}

{p2colset 9 22 24 2}{...}
{p2col:{bf:.smcl}}Stata SMCL log files (full tag parsing){p_end}
{p2col:{bf:.log}}Plain text log files{p_end}
{p2col:{bf:.do}}Do-files (requires {opt run} option){p_end}
{p2colreset}{...}

{pstd}
{bf:HTML output} is fully self-contained: CSS is inlined and graph images are
base64-encoded, so the file can be shared without dependencies.


{marker options}{...}
{title:Options}

{phang}
{opt output(filename)} specifies the output file path. Required. The file
extension should match the chosen format (.html or .md).

{phang}
{opt format(string)} selects the output format. {bf:html} (default) produces
a self-contained HTML document. {bf:md} produces Markdown with YAML front
matter. {bf:both} generates both formats from the same input.

{phang}
{opt theme(string)} selects the CSS theme for HTML output. {bf:light}
(default) uses a clean, Quarto-inspired white background with blue accents.
{bf:dark} uses a Catppuccin-inspired terminal theme with a dark background.

{phang}
{opt title(string)} sets the document title shown in the header and
HTML {cmd:<title>} tag. Defaults to the input filename without extension.

{phang}
{opt date(string)} adds a subtitle line below the document title showing the
specified date string. Useful for versioning or timestamping documents.

{phang}
{opt run} executes the input .do file in batch mode ({cmd:stata-mp -b do})
before converting. The resulting .smcl or .log file is used as input.
This option is only valid when the input is a .do file.

{phang}
{opt preformatted} keeps regression tables as monospace preformatted blocks
instead of converting them to HTML tables. Useful when table alignment
depends on precise character positioning.

{phang}
{opt nofold} disables collapsible {cmd:<details>} sections in HTML output.
By default, verbose output blocks (e.g., {cmd:summarize, detail} or output
longer than 30 lines) are wrapped in collapsible sections.

{phang}
{opt nodots} strips the Stata dot prompts ({cmd:. } and {cmd:> }) from
command blocks, producing cleaner output that looks like a script rather
than an interactive session.

{phang}
{opt python(string)} specifies an explicit path to the Python 3 executable.
By default, {cmd:logdoc} tries {cmd:python3} on Unix or {cmd:python} on
Windows.

{phang}
{opt replace} allows overwriting an existing output file.


{marker examples}{...}
{title:Examples}

{pstd}
Convert a SMCL log to HTML:

{phang2}{cmd:. logdoc using "myanalysis.smcl", output("myanalysis.html") replace}

{pstd}
Convert to Markdown:

{phang2}{cmd:. logdoc using "myanalysis.smcl", output("myanalysis.md") format(md) replace}

{pstd}
Use the dark theme:

{phang2}{cmd:. logdoc using "results.smcl", output("results.html") theme(dark) replace}

{pstd}
Generate both HTML and Markdown:

{phang2}{cmd:. logdoc using "output.smcl", output("output.html") format(both) replace}

{pstd}
Run a .do file and convert:

{phang2}{cmd:. logdoc using "analysis.do", output("analysis.html") run replace}

{pstd}
Clean output without dot prompts, with date:

{phang2}{cmd:. logdoc using "results.smcl", output("results.html") nodots date("March 2026") replace}

{pstd}
Keep tables as monospace, disable folding:

{phang2}{cmd:. logdoc using "results.smcl", output("results.html") preformatted nofold replace}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:logdoc} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(output)}}output file path{p_end}
{synopt:{cmd:r(input)}}input file path (may differ from {it:using} if {opt run} was specified){p_end}
{synopt:{cmd:r(format)}}output format used{p_end}
{synopt:{cmd:r(theme)}}theme used{p_end}


{marker requirements}{...}
{title:Requirements}

{pstd}
{bf:Python 3.6+} must be installed and accessible from the command line.
No external Python packages are required — {cmd:logdoc} uses only the
standard library.

{pstd}
Stata 16.0 or later.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet
{p_end}
