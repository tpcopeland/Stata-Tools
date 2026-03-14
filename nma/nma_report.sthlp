{smcl}
{* *! version 1.0.5  01mar2026}{...}
{viewerjumpto "Syntax" "nma_report##syntax"}{...}
{viewerjumpto "Description" "nma_report##description"}{...}
{viewerjumpto "Options" "nma_report##options"}{...}
{viewerjumpto "Examples" "nma_report##examples"}{...}
{viewerjumpto "Author" "nma_report##author"}{...}

{title:Title}

{phang}
{bf:nma_report} {hline 2} Publication-quality report export


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_report}
{cmd:using} {it:filename}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt for:mat(string)}}excel (default) or csv{p_end}
{synopt:{opt eform}}exponentiated effects{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt sec:tions(string)}}report sections: setup fit rank{p_end}
{synopt:{opt level(#)}}confidence level{p_end}
{synopt:{opt dig:its(#)}}decimal places in output; default is {cmd:digits(4)}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_report} exports a structured report with selected analysis
sections to Excel or CSV format. The report includes network summary
statistics, treatment effect estimates, rankings (SUCRA), and league tables
as appropriate.


{marker options}{...}
{title:Options}

{phang}
{opt format(string)} specifies the output format: {cmd:excel} (default)
produces a formatted .xlsx file with headers, borders, and column widths;
{cmd:csv} produces a plain-text comma-separated file.

{phang}
{opt eform} exports exponentiated treatment effects (e.g., odds ratios
instead of log odds ratios). Appropriate when the effect measure is on
the log scale.

{phang}
{opt replace} allows overwriting an existing output file.

{phang}
{opt sections(string)} specifies which sections to include in the report.
Options are {cmd:setup} (network summary), {cmd:fit} (model estimates), and
{cmd:rank} (SUCRA rankings). Multiple sections can be specified, e.g.,
{cmd:sections(fit rank)}. By default, all sections are included.

{phang}
{opt level(#)} specifies the confidence level for confidence intervals in
the report. Default is 95.

{phang}
{opt digits(#)} specifies the number of decimal places in the report.
Default is 4.


{marker examples}{...}
{title:Examples}

{pstd}Export to Excel{p_end}
{phang2}{cmd:. nma_report using results.xlsx, replace}{p_end}

{pstd}Export specific sections{p_end}
{phang2}{cmd:. nma_report using results.xlsx, sections(fit rank) eform replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:nma_report} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(filename)}}output file path{p_end}
{synopt:{cmd:r(format)}}output format (excel or csv){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
