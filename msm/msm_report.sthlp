{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_report##syntax"}{...}
{viewerjumpto "Description" "msm_report##description"}{...}
{viewerjumpto "Examples" "msm_report##examples"}{...}
{viewerjumpto "Author" "msm_report##author"}{...}

{title:Title}

{phang}
{bf:msm_report} {hline 2} Publication-quality results tables for MSM


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_report}
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt exp:ort(string)}}file path for export{p_end}
{synopt:{opt for:mat(string)}}display (default), csv, or excel{p_end}
{synopt:{opt dec:imals(#)}}decimal places; default 4{p_end}
{synopt:{opt eform}}exponentiated coefficients (OR/HR){p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_report} generates publication tables summarizing the MSM analysis:
data summary, IP weight diagnostics, and model coefficients.


{marker options}{...}
{title:Options}

{phang}
{opt export(string)} specifies the file path for export. Required when
{opt format()} is {cmd:csv} or {cmd:excel}.

{phang}
{opt format(string)} specifies the output format: {cmd:display} (default)
prints to the console, {cmd:csv} exports comma-separated values, and
{cmd:excel} exports a formatted Excel file.

{phang}
{opt decimals(#)} specifies the number of decimal places. Default is 4.

{phang}
{opt eform} displays exponentiated coefficients (odds ratios for logistic,
hazard ratios for Cox).

{phang}
{opt replace} allows overwriting an existing export file.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_report}{p_end}
{phang2}{cmd:. msm_report, eform}{p_end}
{phang2}{cmd:. msm_report, export(results.xlsx) format(excel) eform replace}{p_end}
{phang2}{cmd:. msm_report, export(results.csv) format(csv)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
