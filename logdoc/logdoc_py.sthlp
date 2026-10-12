{smcl}
{vieweralsosee "logdoc" "help logdoc"}{...}
{viewerjumpto "Syntax" "logdoc_py##syntax"}{...}
{viewerjumpto "Description" "logdoc_py##description"}{...}
{viewerjumpto "Actions" "logdoc_py##actions"}{...}
{viewerjumpto "Options" "logdoc_py##options"}{...}
{viewerjumpto "Detection order" "logdoc_py##detection"}{...}
{viewerjumpto "Examples" "logdoc_py##examples"}{...}
{viewerjumpto "Stored results" "logdoc_py##results"}{...}
{viewerjumpto "Troubleshooting" "logdoc_py##troubleshooting"}{...}
{viewerjumpto "Author" "logdoc_py##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:logdoc_py} {hline 2}}Find, check, and save Python configuration for logdoc{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Check the current Python setup:

{p 8 17 2}
{cmd:logdoc_py}
[{cmd:,}
{opt ch:eck}
{opt py:thon(path)}
{opt pdf}
{opt q:uiet}
{opt v:erbose}]

{pstd}
Set the detected Python for the current Stata session:

{p 8 17 2}
{cmd:logdoc_py}
{cmd:,}
{opt set}
[{opt py:thon(path)}
{opt pdf}
{opt q:uiet}
{opt v:erbose}]

{pstd}
Save the detected Python path to the project configuration file:

{p 8 17 2}
{cmd:logdoc_py}
{cmd:,}
{opt save}
[{opt py:thon(path)}
{opt rep:lace}
{opt pdf}
{opt q:uiet}
{opt v:erbose}]

{pstd}
Install Python package dependencies, when a package needs them:

{p 8 17 2}
{cmd:logdoc_py}
{cmd:,}
{opt inst:all(string)}
[{opt py:thon(path)}
{opt dry:run}
{opt q:uiet}
{opt v:erbose}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt ch:eck}}run setup checks; the default action{p_end}
{synopt:{opt set}}select Python for this Stata session{p_end}
{synopt:{opt save}}write or update {cmd:python=...} in {cmd:.logdocrc}{p_end}
{synopt:{opt inst:all(string)}}install a requested Python package{p_end}
{synopt:{opt py:thon(path)}}explicit Python executable to check or save{p_end}
{synopt:{opt pdf}}check PDF converter availability{p_end}
{synopt:{opt rep:lace}}allow {opt save} to replace the Python setting{p_end}
{synopt:{opt dry:run}}show the pip command without running it{p_end}
{synopt:{opt q:uiet}}suppress nonessential output{p_end}
{synopt:{opt v:erbose}}show candidate search and check details{p_end}
{synoptline}

{pstd}
At most one of {opt check}, {opt set}, {opt save}, and {opt install()} may
be specified. If no action is specified, {cmd:logdoc_py} behaves as
{cmd:logdoc_py, check}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:logdoc_py} finds, checks, and records the Python executable used by
{helpb logdoc}. Run it from the Command window before first use, after moving
a project to another computer, or when {cmd:logdoc} reports that Python
cannot be found.

{pstd}
{cmd:logdoc} calls its bundled renderer, {cmd:logdoc_render.py}, through a
Python 3.6+ executable. Conversion to HTML, Markdown, Quarto Markdown, and
LaTeX needs only the Python standard library. {cmd:format(pdf)} additionally
needs {cmd:xhtml2pdf} or {cmd:wkhtmltopdf}; see {opt pdf} below.

{pstd}
For the chosen executable, {cmd:logdoc_py} confirms that it starts and reports
Python 3.6 or newer, locates {cmd:logdoc_render.py}, and runs a renderer
smoke check. It never runs {cmd:sudo}, calls an operating-system package
manager, or changes a Python installation unless you request {opt install()}.


{marker actions}{...}
{title:Actions}

{phang}
{opt check} validates Python and the renderer and reports what {cmd:logdoc}
will use. It is the default action. PDF support is checked only when
{opt pdf} is specified.

{phang}
{opt set} performs the same checks, then stores the selected executable in
{cmd:$LOGDOC_PYTHON}. This lasts for the current Stata session only.

{phang}
{opt save} performs the same checks, then writes {cmd:python=}{it:path} to
{cmd:.logdocrc} in the current working directory, creating the file if
necessary. If the file already has a {cmd:python=} line, {opt save} stops
with return code 602 unless {opt replace} is specified; with {opt replace}
the line is updated in place and duplicate {cmd:python=} lines are
consolidated into one. Other lines are preserved.

{phang}
{opt install(string)} runs {cmd:python -m pip install} for the named packages
through the selected executable. When the executable is Stata's own
{cmd:python:} interpreter, pip is launched from that session using
{cmd:sys.executable}. {cmd:install(required)}, {cmd:install(optional)}, and
{cmd:install(all)} report that {cmd:logdoc} has no Python packages to
install. Any other value is treated as a list of package names, for example
{cmd:install(xhtml2pdf)}.


{marker options}{...}
{title:Options}

{phang}
{opt check}, {opt set}, {opt save}, and {opt install()} select the action; see {help logdoc_py##actions:Actions}.

{phang}
{opt python(path)} specifies the Python executable to check. Paths with spaces
must be quoted. When {opt python()} is supplied, only that executable is
tried.

{phang}
{opt pdf} checks whether {cmd:xhtml2pdf} (Python library) or
{cmd:wkhtmltopdf} (system executable) is available for {cmd:format(pdf)}
output, and exits with return code 601 if neither is found. {cmd:xhtml2pdf}
is preferred and can be installed with
{cmd:logdoc_py, install(xhtml2pdf)}. Missing PDF support does not affect the other formats.

{phang}
{opt replace} allows {opt save} to replace an existing {cmd:python=} entry in
{cmd:.logdocrc}. Without {opt replace}, {opt save} stops with return code 602
when the file already has a {cmd:python=} entry. Allowed only with
{opt save}.

{phang}
{opt dryrun} is allowed only with {opt install()}. It prints the exact
{cmd:python -m pip install ...} command that would be run and exits without
installing anything.

{phang}
{opt quiet} suppresses nonessential output. Errors and actionable warnings
are still displayed.

{phang}
{opt verbose} prints each candidate Python path, version-check command,
renderer check, and optional dependency check. {opt quiet} and {opt verbose}
are mutually exclusive.


{marker detection}{...}
{title:Detection order}

{pstd}
{cmd:logdoc_py} uses the same resolution order as {cmd:logdoc}. When
{opt python(path)} is supplied, only that executable is tried. Otherwise the
candidates are, in order:

{phang2}{cmd:1.} {cmd:$LOGDOC_PYTHON}, if set (for example by
{cmd:logdoc_py, set}).{p_end}
{phang2}{cmd:2.} {cmd:python=} in {cmd:.logdocrc}. The global
{cmd:~/.logdocrc} is read first, and a {cmd:.logdocrc} in the current
directory overrides it.{p_end}
{phang2}{cmd:3.} Stata's configured {cmd:python:} executable, when
available.{p_end}
{phang2}{cmd:4.} Platform defaults on the system path: {cmd:python3} then
{cmd:python}, or {cmd:py -3}, {cmd:python}, then {cmd:python3} on
Windows.{p_end}

{pstd}
The first candidate that starts, reports Python 3.6 or newer, and passes the
renderer smoke check is selected. A Python chosen explicitly through
{cmd:$LOGDOC_PYTHON} or {cmd:.logdocrc} never falls through to the next
candidate: if it is unusable, {cmd:logdoc_py} exits with return code 601 and an
error naming the source ({cmd:$LOGDOC_PYTHON} or {cmd:.logdocrc}) and the
failing path. Fix or remove that setting, or repair it with
{cmd:logdoc_py, python(}{it:path}{cmd:) set} or
{cmd:logdoc_py, python(}{it:path}{cmd:) save replace}. {cmd:.logdocrc} lines
use the same {it:key}{cmd:=}{it:value} grammar as {helpb logdoc}.


{marker examples}{...}
{title:Examples}

{pstd}
Check the default setup:

{phang2}{cmd:. logdoc_py}{p_end}

{pstd}
Check Python and PDF support:

{phang2}{cmd:. logdoc_py, check pdf}{p_end}

{pstd}
Check a specific Python executable:

{phang2}{cmd:. logdoc_py, python("/opt/venv/bin/python3")}{p_end}

{pstd}
Use a specific Python for the current Stata session:

{phang2}{cmd:. logdoc_py, python("/opt/venv/bin/python3") set}{p_end}
{phang2}{cmd:. logdoc using analysis.smcl, output(analysis.html) replace}{p_end}

{pstd}
Save a project-local Python setting:

{phang2}{cmd:. logdoc_py, python("/opt/venv/bin/python3") save replace}{p_end}

{pstd}
Show the pip command that would install the PDF converter:

{phang2}{cmd:. logdoc_py, install(xhtml2pdf) dryrun}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:logdoc_py} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(ok)}}1 when the command succeeded{p_end}
{synopt:{cmd:r(python_ok)}}1 when a usable Python executable was found{p_end}
{synopt:{cmd:r(renderer_ok)}}1 when the renderer was located{p_end}
{synopt:{cmd:r(pdf_ok)}}1 when a PDF converter was found; only with {opt pdf}{p_end}
{synopt:{cmd:r(installed)}}1 pip ran; 0 nothing to install{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(python)}}selected Python executable{p_end}
{synopt:{cmd:r(python_version)}}Python version string{p_end}
{synopt:{cmd:r(python_source)}}{cmd:option}, {cmd:global}, {cmd:config}, {cmd:stata}, or {cmd:path}{p_end}
{synopt:{cmd:r(renderer)}}path to {cmd:logdoc_render.py}{p_end}
{synopt:{cmd:r(config)}}{cmd:.logdocrc} path, when read or written{p_end}
{synopt:{cmd:r(xhtml2pdf)}}{cmd:installed}, when found; only with {opt pdf}{p_end}
{synopt:{cmd:r(wkhtmltopdf)}}{cmd:wkhtmltopdf} path, when found{p_end}
{synopt:{cmd:r(required)}}reserved; currently empty{p_end}
{synopt:{cmd:r(optional)}}reserved; currently empty{p_end}
{synopt:{cmd:r(missing)}}reserved; currently empty{p_end}
{synopt:{cmd:r(install_cmd)}}pip command used or proposed by {opt dryrun}{p_end}
{p2colreset}{...}

{pstd}
{cmd:r(installed)} is missing after {opt install()} with {opt dryrun}. Return codes are 198 for
invalid or conflicting options, 601 when Python, the renderer, a PDF converter, or a pip install is unavailable or fails, and
602 when {opt save} would overwrite an existing {cmd:python=} entry without
{opt replace}.


{marker troubleshooting}{...}
{title:Troubleshooting}

{phang}
{bf:Python not found}: Run {cmd:logdoc_py, verbose} to see each candidate that
was tried. If Python is installed but not on the path Stata sees, specify it
explicitly with {opt python(path)}.

{phang}
{bf:Python from $LOGDOC_PYTHON or .logdocrc not usable}: That setting is
used without fallback. Fix or remove it (see {help logdoc_py##detection:Detection order}).

{phang}
{bf:Wrong Python}: Use {cmd:logdoc_py, python(path) set} for the current Stata
session or {cmd:logdoc_py, python(path) save replace} for the current project.

{phang}
{bf:PDF support missing}: Install {cmd:xhtml2pdf} with
{cmd:logdoc_py, install(xhtml2pdf)} (recommended), or install
{cmd:wkhtmltopdf} as a system package. Then rerun
{cmd:logdoc_py, check pdf}.

{phang}
{bf:Python package installs fail}: Use {opt dryrun} to display the exact pip
command, then run it manually in a shell to see the full error output. In
restricted environments, create a virtual environment and pass its Python
executable with {opt python(path)}.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet
{p_end}

{hline}
