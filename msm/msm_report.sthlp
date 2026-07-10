{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_protocol" "help msm_protocol"}{...}
{vieweralsosee "msm_sensitivity" "help msm_sensitivity"}{...}
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
{syntab:Output}
{synopt:{opt exp:ort(string)}}file path for CSV or Excel export{p_end}
{synopt:{opt for:mat(string)}}{cmd:display} (default), {cmd:csv}, or {cmd:excel}{p_end}
{synopt:{opt dec:imals(#)}}decimal places; default {cmd:4}{p_end}
{synopt:{opt eform}}exponentiated coefficients (OR for logistic, HR for Cox){p_end}
{synopt:{opt replace}}replace report sheet(s) in an existing workbook{p_end}

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
{cmd:msm_report} produces a compact analysis summary that combines three
sections: a data summary, IP weight diagnostics, and outcome model
coefficients. It is designed for quick reporting and manuscript drafting.

{pstd}
By default, the report is displayed in the Results window
({cmd:format(display)}). Use {cmd:format(csv)} or {cmd:format(excel)} to export the report to a
file. The Excel format produces a professional workbook with formatted
headers, borders, and optional zebra striping and footnotes.

{pstd}
{cmd:msm_report} focuses on a single compact table. For multi-sheet Excel
export of the full pipeline (coefficients, predictions, balance, weights,
sensitivity), use {helpb msm_table} instead.

{pstd}
The command reads the persisted coefficient and variance matrices
({cmd:_msm_fit_b}, {cmd:_msm_fit_V}) rather than requiring {cmd:e()} to still
hold the {helpb msm_fit} results. This means you can run other estimation
commands between {cmd:msm_fit} and {cmd:msm_report} without losing the MSM
results.


{marker options}{...}
{title:Options}

{dlgtab:Output}

{phang}
{opt exp:ort(string)} specifies the output file path. Required when
{cmd:format()} is {cmd:csv} or {cmd:excel}. For Excel, the file must have
a {cmd:.xlsx} extension.

{phang}
{opt for:mat(string)} specifies the output format. {cmd:display} (default) prints to the
Stata Results window. {cmd:csv} writes a comma-separated file. {cmd:excel} writes a
formatted Excel workbook.

{phang}
{opt dec:imals(#)} specifies decimal places for numeric values. Default is 4.

{phang}
{opt eform} displays exponentiated coefficients. For logistic models this
gives odds ratios with confidence intervals; for Cox models it gives hazard
ratios.

{phang}
{opt replace} replaces the report sheet(s) in an existing Excel workbook
without deleting unrelated sheets. For CSV output, it overwrites the existing
file.

{dlgtab:Excel formatting}

{pstd}
The following options apply only with {cmd:format(excel)}:

{phang}
{opt tit:le(string)} sets the title in cell A1. Default is "MSM Analysis
Summary".

{phang}
{opt f:ont(name)} sets the font. Default is {cmd:Arial}.

{phang}
{opt fonts:ize(#)} sets the font size in points. Default is 10.

{phang}
{opt border:style(style)} sets the border weight: {cmd:thin} (default),
{cmd:medium}, or {cmd:academic} (horizontal-only medium borders).

{phang}
{opt zebra} applies alternating row shading to data rows.

{phang}
{opt foot:note(string)} adds a merged, italic footnote below each table sheet.

{phang}
{opt open} automatically opens the exported file using the system default
application.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Quick console report:}{p_end}

{phang2}{cmd:. msm_report}{p_end}

{pstd}
{bf:Console report with odds ratios:}{p_end}

{phang2}{cmd:. msm_report, eform}{p_end}

{pstd}
{bf:Excel export with formatting:}{p_end}

{phang2}{cmd:. msm_report, export(results.xlsx) format(excel) eform zebra replace}{p_end}

{pstd}
{bf:Excel with custom title and footnote:}{p_end}

{phang2}{cmd:. msm_report, export(results.xlsx) format(excel) eform zebra}{p_end}
{phang2}{cmd:    footnote("Adjusted for time-varying confounders.") replace open}{p_end}

{pstd}
{bf:CSV export for import into other software:}{p_end}

{phang2}{cmd:. msm_report, export(results.csv) format(csv) eform replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_report} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(format)}}output format used{p_end}
{synopt:{cmd:r(export)}}export file path (if applicable){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
