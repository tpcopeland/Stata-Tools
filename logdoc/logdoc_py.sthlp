{smcl}
{* *! version 1.0.2  14jun2026}{...}
{vieweralsosee "logdoc" "help logdoc"}{...}
{viewerjumpto "Syntax" "logdoc_py##syntax"}{...}
{viewerjumpto "Description" "logdoc_py##description"}{...}
{viewerjumpto "Actions" "logdoc_py##actions"}{...}
{viewerjumpto "Options" "logdoc_py##options"}{...}
{viewerjumpto "Detection order" "logdoc_py##detection"}{...}
{viewerjumpto "Portable setup contract" "logdoc_py##portable"}{...}
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
{synopt:{opt ch:eck}}check Python, renderer, and optional PDF support; default action{p_end}
{synopt:{opt set}}store the selected Python executable in {cmd:$LOGDOC_PYTHON} for this Stata session{p_end}
{synopt:{opt save}}write or update {cmd:python=...} in {cmd:.logdocrc}{p_end}
{synopt:{opt inst:all(string)}}install Python packages with the selected Python executable{p_end}
{synopt:{opt py:thon(path)}}explicit Python executable to check or save{p_end}
{synopt:{opt pdf}}also check {cmd:xhtml2pdf} and {cmd:wkhtmltopdf} for {cmd:format(pdf)}{p_end}
{synopt:{opt rep:lace}}allow {cmd:save} to replace an existing {cmd:python=} entry in {cmd:.logdocrc}{p_end}
{synopt:{opt dry:run}}show the pip command that would be run, but do not install packages{p_end}
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
{cmd:logdoc_py} is a setup and diagnostic command for the Python executable
used by {helpb logdoc}. It is intended to be run from the Stata Command
window before first use, after moving projects between computers, or when
{cmd:logdoc} reports that Python cannot be found.

{pstd}
{cmd:logdoc} calls a bundled Python renderer, {cmd:logdoc_render.py}, through
the Python executable configured for Stata whenever possible. This keeps the
ordinary setup path aligned with {cmd:python query} and {cmd:set python_exec}.
It can still fall back to a project setting or a system-path Python when
Stata's {cmd:python:} integration is unavailable. {cmd:logdoc} does not
currently require any third-party Python packages; the required Python modules
are from the Python standard library.

{pstd}
The purpose of {cmd:logdoc_py} is therefore to:

{phang2}{c 149} find a usable Python executable;{p_end}
{phang2}{c 149} confirm that it is Python 3.6 or newer;{p_end}
{phang2}{c 149} confirm that the bundled {cmd:logdoc_render.py} script can be found;{p_end}
{phang2}{c 149} optionally save the executable path to {cmd:.logdocrc}; and{p_end}
{phang2}{c 149} optionally check system tools such as {cmd:wkhtmltopdf} for PDF output.{p_end}

{pstd}
This command is deliberately conservative. It should not run {cmd:sudo}, call
operating-system package managers, or mutate a system Python installation
without an explicit {opt install()} request.


{marker actions}{...}
{title:Actions}

{phang}
{opt check} validates Python and reports what {cmd:logdoc} will use. This is
the default action. A successful check means that HTML, Markdown, Quarto,
LaTeX, and Word-rendering preflight checks passed at the Python layer. PDF
support is checked only when {opt pdf} is specified.

{phang}
{opt set} performs the same checks as {opt check}, then stores the selected
executable in {cmd:$LOGDOC_PYTHON}. This affects the current Stata session
only. It is useful when testing a virtual environment or a non-default Python
without writing project configuration.

{phang}
{opt save} performs the same checks as {opt check}, then writes
{cmd:python=}{it:path} to {cmd:.logdocrc} in the current working directory.
If {cmd:.logdocrc} already contains a {cmd:python=} entry, {opt replace} is
required to update it. Other configuration lines are preserved. If the file
contains duplicate {cmd:python=} entries, {opt save} with {opt replace}
consolidates them into a single entry.

{phang}
{opt install(string)} installs Python packages using the selected executable
and {cmd:-m pip install}. When the selected executable comes from Stata's
{cmd:python:} configuration, installation is launched through that same Stata
Python session and {cmd:sys.executable}. For {cmd:logdoc}, no Python packages
are required; therefore {cmd:logdoc_py, install(required)} should report that
there is nothing to install. Custom package names may be supported for
advanced users, but should be treated as an explicit user request.


{marker options}{...}
{title:Options}

{phang}
{opt python(path)} specifies the Python executable to check. Paths with spaces
must be quoted. When {opt python()} is supplied, it takes precedence over all
auto-detected candidates.

{phang}
{opt pdf} checks whether {cmd:xhtml2pdf} (Python library) or
{cmd:wkhtmltopdf} (system executable) is available for {cmd:format(pdf)}
output. {cmd:xhtml2pdf} is preferred and can be installed with
{cmd:logdoc_py, install(xhtml2pdf)}. Missing PDF support does not affect
HTML or Markdown output.

{phang}
{opt replace} allows {opt save} to replace an existing {cmd:python=} entry in
{cmd:.logdocrc}. Without {opt replace}, {opt save} should refuse to overwrite
an existing Python setting.

{phang}
{opt dryrun} applies only with {opt install()}. It prints the exact
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
{cmd:logdoc_py} selects the first candidate that passes the Python
version and renderer checks. When {opt python(path)} is supplied,
only that candidate is tried and all others are skipped.
The default search order (without {opt python()}) is:

{phang2}{cmd:1.} Stata's configured {cmd:python:} executable, when available.{p_end}
{phang2}{cmd:2.} {cmd:$LOGDOC_PYTHON}, if set by {cmd:logdoc_py, set}.{p_end}
{phang2}{cmd:3.} {cmd:python=} in the current directory's {cmd:.logdocrc}.{p_end}
{phang2}{cmd:4.} Platform defaults found on the system path, such as
{cmd:python3}, {cmd:python}, or Windows launcher commands such as
{cmd:py -3}.{p_end}

{pstd}
For each candidate, the implementation should check:

{phang2}{c 149} the executable starts and prints a Python version;{p_end}
{phang2}{c 149} the version is Python 3.6 or newer;{p_end}
{phang2}{c 149} standard-library modules used by {cmd:logdoc_render.py} can be imported; and{p_end}
{phang2}{c 149} {cmd:logdoc_render.py} can be located through the installed package path.{p_end}

{pstd}
The selected executable should be the same executable passed to {cmd:logdoc}'s
{opt python()} option, reported by Stata's {cmd:python query}, stored in
{cmd:$LOGDOC_PYTHON}, or written as {cmd:python=} in {cmd:.logdocrc}.


{marker portable}{...}
{title:Portable setup contract}

{pstd}
The {cmd:logdoc_py} design is intended to be portable to other Stata packages
that call Python. The recommended package-wide convention is:

{phang2}{cmd:<pkg>_py, check} checks Python and package dependencies.{p_end}
{phang2}{cmd:<pkg>_py, set} stores a session-local executable in
{cmd:$<PKG>_PYTHON}. {p_end}
{phang2}{cmd:<pkg>_py, save} writes the executable to the package's project
configuration file when such a file exists. {p_end}
{phang2}{cmd:<pkg>_py, install(required|optional|all|}{it:packages}{cmd:)}
runs explicit pip installation through the selected executable. {p_end}

{pstd}
Packages should implement one of two runner profiles:

{phang}
{bf:External-shell profile.} The package runs Python scripts through
{cmd:shell}. Examples include {cmd:logdoc} and {cmd:consort}. The setup
command should validate a shell executable and pass that path into the package
command, usually through {opt python()}, a package global, or a project
configuration file.

{phang}
{bf:Stata-bridge profile.} The package runs Python through Stata's
{cmd:python:} integration. Examples include learners that use the Stata-Python
bridge. The setup command should validate {cmd:python:}, report
{cmd:sys.executable}, and install packages through
{cmd:python: import subprocess, sys; subprocess.check_call([sys.executable, "-m", "pip", "install", ...])}.

{pstd}
Both profiles should use the same user-facing action names and stored result
names whenever possible. This makes setup commands predictable across packages
even when the underlying Python runner differs.

{pstd}
Recommended return-code behavior:

{phang2}{cmd:0}: checks passed or requested setup completed.{p_end}
{phang2}{cmd:198}: invalid options or conflicting actions.{p_end}
{phang2}{cmd:601}: Python, package files, or required dependencies are missing.{p_end}


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
Show the pip command that would be used for a custom package install:

{phang2}{cmd:. logdoc_py, install(jinja2) dryrun}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:logdoc_py} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(ok)}}1 if the requested checks passed, 0 otherwise{p_end}
{synopt:{cmd:r(python_ok)}}1 if a usable Python executable was found{p_end}
{synopt:{cmd:r(renderer_ok)}}1 if {cmd:logdoc_render.py} was found and passed the renderer smoke check{p_end}
{synopt:{cmd:r(pdf_ok)}}1 if {cmd:wkhtmltopdf} is available; missing if {opt pdf} was not requested{p_end}
{synopt:{cmd:r(installed)}}1 if {opt install()} completed; missing otherwise{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(python)}}selected Python executable{p_end}
{synopt:{cmd:r(python_version)}}Python version string{p_end}
{synopt:{cmd:r(python_source)}}where the selected executable came from: {cmd:option}, {cmd:global}, {cmd:config}, {cmd:stata}, or {cmd:path}{p_end}
{synopt:{cmd:r(renderer)}}path to {cmd:logdoc_render.py}{p_end}
{synopt:{cmd:r(config)}}path to {cmd:.logdocrc}, when read or written{p_end}
{synopt:{cmd:r(wkhtmltopdf)}}path or command name for {cmd:wkhtmltopdf}, when found{p_end}
{synopt:{cmd:r(required)}}space-separated required Python packages; empty for current {cmd:logdoc}{p_end}
{synopt:{cmd:r(optional)}}space-separated optional Python packages, if any{p_end}
{synopt:{cmd:r(missing)}}space-separated missing Python packages, if any{p_end}
{synopt:{cmd:r(install_cmd)}}pip command used or proposed by {opt dryrun}{p_end}
{p2colreset}{...}

{pstd}
{cmd:logdoc} currently has no third-party Python package dependencies.
{cmd:r(required)}, {cmd:r(optional)}, and {cmd:r(missing)} are therefore always
empty. They are present for portable-contract compliance so that other packages
adopting this setup pattern can populate them without changing the return
interface.


{marker troubleshooting}{...}
{title:Troubleshooting}

{phang}
{bf:Python not found}: Run {cmd:logdoc_py, verbose} to see each candidate that
was tried. If Python is installed but not on the path Stata sees, specify it
explicitly with {opt python(path)}.

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
