{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_protocol" "help msm_protocol"}{...}
{viewerjumpto "Syntax" "msm_report##syntax"}{...}
{viewerjumpto "Description" "msm_report##description"}{...}
{viewerjumpto "Options" "msm_report##options"}{...}
{viewerjumpto "Examples" "msm_report##examples"}{...}
{viewerjumpto "Stored results" "msm_report##results"}{...}
{viewerjumpto "Author" "msm_report##author"}{...}

{title:Title}

{phang}
{bf:msm_report} {hline 2} Publication-quality results tables for MSM


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_report}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt exp:ort(string)}}file path for export{p_end}
{synopt:{opt for:mat(string)}}display (default), csv, or excel{p_end}
{synopt:{opt dec:imals(#)}}decimal places; default 4{p_end}
{synopt:{opt eform}}exponentiated coefficients (OR/HR){p_end}
{synopt:{opt replace}}replace existing file{p_end}

{syntab:Excel formatting}
{synopt:{opt tit:le(string)}}title for cell A1{p_end}
{synopt:{opt f:ont(name)}}font name; default is {cmd:Arial}{p_end}
{synopt:{opt fonts:ize(#)}}font size in points; default is {cmd:10}{p_end}
{synopt:{opt border:style(style)}}{cmd:thin} (default), {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt foot:note(string)}}merged footnote below table{p_end}
{synopt:{opt open}}auto-open file after export{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_report} generates publication tables summarizing the MSM analysis:
data summary, IP weight diagnostics, and model coefficients.

{pstd}
The {cmd:excel} format produces a formatted workbook with title rows, header
formatting, border frames, proper column widths, and numeric cell conversion.
Optional zebra striping and footnotes match the formatting style used by
{cmd:msm_table} and the {cmd:tabtools} package.


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

{dlgtab:Excel formatting}

{pstd}
The following options apply only when {cmd:format(excel)} is specified:

{phang}
{opt tit:le(string)} sets the title in cell A1. Default is "MSM Analysis Summary".

{phang}
{opt f:ont(name)} sets the font. Default is {cmd:Arial}.

{phang}
{opt fonts:ize(#)} sets the font size. Default is {cmd:10}.

{phang}
{opt border:style(style)} sets border weight: {cmd:thin} (default),
{cmd:medium}, or {cmd:academic}.

{phang}
{opt zebra} applies alternating row shading to data rows.

{phang}
{opt foot:note(string)} adds a merged, italic footnote below each sheet.

{phang}
{opt open} automatically opens the file after export.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_report}{p_end}
{phang2}{cmd:. msm_report, eform}{p_end}
{phang2}{cmd:. msm_report, export(results.xlsx) format(excel) eform replace}{p_end}
{phang2}{cmd:. msm_report, export(results.xlsx) format(excel) eform zebra replace}{p_end}
{phang2}{cmd:. msm_report, export(results.xlsx) format(excel) eform zebra footnote("Adjusted for time-varying confounders.") replace open}{p_end}
{phang2}{cmd:. msm_report, export(results.csv) format(csv)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_report} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(format)}}output format{p_end}
{synopt:{cmd:r(export)}}export file path{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
