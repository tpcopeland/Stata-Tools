{smcl}
{* *! version 1.1.0  14jun2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_sensitivity" "help msm_sensitivity"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{viewerjumpto "Syntax" "msm_table##syntax"}{...}
{viewerjumpto "Description" "msm_table##description"}{...}
{viewerjumpto "Options" "msm_table##options"}{...}
{viewerjumpto "Sheets" "msm_table##sheets"}{...}
{viewerjumpto "Prerequisites" "msm_table##prerequisites"}{...}
{viewerjumpto "Examples" "msm_table##examples"}{...}
{viewerjumpto "Author" "msm_table##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{bf:msm_table} {hline 2}}Publication-quality Excel tables for MSM results{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_table}
{cmd:,} {opt xlsx(filename)}
[{it:table_options} {it:formatting_options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt xlsx(filename)}}Excel output file ({cmd:.xlsx} extension){p_end}

{syntab:Table selection}
{synopt:{opt coef:icients}}model coefficients from {helpb msm_fit}{p_end}
{synopt:{opt pred:ictions}}counterfactual predictions from {helpb msm_predict}{p_end}
{synopt:{opt bal:ance}}covariate balance (SMD) from {helpb msm_diagnose}{p_end}
{synopt:{opt weight:s}}weight distribution summary from {helpb msm_diagnose}{p_end}
{synopt:{opt sens:itivity}}E-value analysis from {helpb msm_sensitivity}{p_end}
{synopt:{opt all}}all available tables on separate sheets (default){p_end}

{syntab:Formatting}
{synopt:{opt ef:orm}}exponentiate coefficients (OR/HR){p_end}
{synopt:{opt dec:imals(#)}}decimal places; default is {cmd:3}{p_end}
{synopt:{opt sep(string)}}CI delimiter; default is {cmd:", "}{p_end}
{synopt:{opt tit:le(string)}}title for cell A1 of each sheet{p_end}
{synopt:{opt replace}}replace selected sheet(s) in an existing workbook{p_end}
{synopt:{opt f:ont(name)}}font name; default is {cmd:Arial}{p_end}
{synopt:{opt fonts:ize(#)}}font size in points; default is {cmd:10}{p_end}
{synopt:{opt border:style(style)}}{cmd:thin} (default), {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt nfor:mat(string)}}Excel number format for numeric cells{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt bold:p(#)}}bold p-values below threshold (Coefficients sheet only){p_end}
{synopt:{opt high:light(#)}}highlight significant rows (Coefficients sheet only){p_end}
{synopt:{opt foot:note(string)}}merged footnote below each table{p_end}
{synopt:{opt open}}auto-open Excel file after export{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_table} exports results from the entire MSM pipeline to a formatted
Excel workbook.  Each table type goes on its own sheet, producing a single
file that contains all the publication-ready tables from an analysis.

{pstd}
Sheets include title rows, formatted headers with background shading, full
border frames, and configurable font and size.  Numeric values are stored as
proper Excel numbers (not text) so they can be sorted and used in formulas.
Column widths are calculated automatically from content.

{pstd}
By default (or with {opt all}), all available tables are exported.  Tables are
silently skipped if the corresponding pipeline step has not been run yet.
When specific tables are requested explicitly, missing prerequisites produce
an error.  If no requested or auto-detected table is available, the command
exits with an error rather than creating an empty workbook.

{pstd}
{cmd:msm_table} is the multi-sheet companion to {helpb msm_report}, which
produces a single compact summary.  Use {cmd:msm_table} when you want the
full set of pipeline outputs in one workbook; use {cmd:msm_report} for a
quick overview.

{pstd}
{cmd:msm_table} is an export command.  Its durable output is the Excel
workbook; it does not leave returned scalars, macros, matrices, or estimation
results behind for later commands.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt xlsx(filename)} specifies the output Excel file.  Must have a
{cmd:.xlsx} extension.

{dlgtab:Table selection}

{phang}
{opt coef:icients} exports model coefficients from {helpb msm_fit}.  Columns
include the point estimate, 95% CI, and p-value.  The column header adapts
to model type: OR (logistic), HR (Cox), or Coef. (linear).

{phang}
{opt pred:ictions} exports counterfactual predictions from {helpb msm_predict}.
For {cmd:strategy(both)}, includes Never-Treat and Always-Treat estimates with
two-level merged headers.  Includes Risk Difference columns if {opt difference}
was specified during prediction.

{phang}
{opt bal:ance} exports the covariate balance table from {helpb msm_diagnose}.
Shows raw SMD, weighted SMD, percentage change, and a balanced/imbalanced
indicator.

{phang}
{opt weight:s} exports weight distribution summary statistics from
{helpb msm_diagnose}: mean, SD, min, P1, median, P99, max, ESS, and ESS (%).

{phang}
{opt sens:itivity} exports sensitivity analysis results from
{helpb msm_sensitivity}: treatment effect, CI, and E-values if computed.

{phang}
{opt all} exports all available tables.  Tables whose prerequisites have not
been run are silently skipped.  This is the default behavior when no specific
table is requested.

{dlgtab:Formatting}

{phang}
{opt ef:orm} exponentiates coefficients on the Coefficients sheet.  Displays
odds ratios (logistic), hazard ratios (Cox), or exp(b) (linear).

{phang}
{opt dec:imals(#)} sets decimal places for numeric values.  Default is 3.
P-values use a tiered convention: {cmd:<0.001} for very small values,
3 decimal places for p < 0.05, 2 decimal places for p >= 0.05.

{phang}
{opt sep(string)} sets the CI delimiter string.  Default is {cmd:", "}.
For example, {cmd:sep(" to ")} formats CIs as "(0.58 to 0.85)".

{phang}
{opt tit:le(string)} sets the title text in cell A1 of each sheet.  If
omitted, each sheet gets a descriptive default title.

{phang}
{opt replace} replaces selected sheet(s) in an existing Excel workbook
without deleting unrelated sheets.

{phang}
{opt f:ont(name)} sets the font.  Default is {cmd:Arial}.

{phang}
{opt fonts:ize(#)} sets the font size in points.  Default is 10.  Must be
between 6 and 72.

{phang}
{opt border:style(style)} sets the border weight.  {cmd:thin} (default) adds
a full grid.  {cmd:medium} uses heavier lines.  {cmd:academic} uses medium
horizontal borders only (top/bottom of header and bottom of table), which
mirrors the style of journal tables.

{phang}
{opt nfor:mat(string)} applies an Excel number format to numeric cells (e.g.,
{cmd:nformat("#,##0.000")} for thousands separators with 3 decimals).

{phang}
{opt zebra} applies alternating row shading (light gray) to data rows across
all sheets.

{phang}
{opt bold:p(#)} bolds p-values below the threshold on the Coefficients sheet
(e.g., {cmd:boldp(0.05)}).

{phang}
{opt high:light(#)} highlights entire rows on the Coefficients sheet where
p < threshold, using light yellow shading.

{phang}
{opt foot:note(string)} adds a merged, italic footnote below each table in a
smaller font.

{phang}
{opt open} opens the file after export using the system default application.


{marker sheets}{...}
{title:Sheet specifications}

{pstd}
{bf:Coefficients:} Variable | OR/HR/Coef. | 95% CI | p-value

{pstd}
{bf:Predictions:} Period | Est. | 95% CI (per strategy, with merged headers)

{pstd}
{bf:Balance:} Covariate | Raw SMD | Weighted SMD | % Change | Balanced

{pstd}
{bf:Weights:} Statistic | Value (9 summary rows)

{pstd}
{bf:Sensitivity:} Parameter | Value (effect, CI, E-values)


{marker prerequisites}{...}
{title:Prerequisites}

{pstd}
Run the MSM pipeline before calling {cmd:msm_table}:

{phang2}1. {helpb msm_prepare} {hline 2} set up data{p_end}
{phang2}2. {helpb msm_weight} {hline 2} compute IPTW weights{p_end}
{phang2}3. {helpb msm_fit} {hline 2} fit outcome model (for Coefficients sheet){p_end}
{phang2}4. {helpb msm_predict} {hline 2} predictions (for Predictions sheet){p_end}
{phang2}5. {helpb msm_diagnose} {hline 2} diagnostics (for Balance and Weights sheets){p_end}
{phang2}6. {helpb msm_sensitivity} {hline 2} sensitivity (for Sensitivity sheet){p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Export all available pipeline results:}{p_end}

{phang2}{cmd:. msm_table, xlsx(results.xlsx) eform replace}{p_end}

{pstd}
{bf:Export only the coefficient table with odds ratios:}{p_end}

{phang2}{cmd:. msm_table, xlsx(coef_table.xlsx) coefficients eform replace}{p_end}

{pstd}
{bf:Export predictions and balance on separate sheets:}{p_end}

{phang2}{cmd:. msm_table, xlsx(tables.xlsx) predictions balance replace}{p_end}

{pstd}
{bf:Publication-style formatting:}{p_end}

{phang2}{cmd:. msm_table, xlsx(pub_table.xlsx) all eform decimals(2)}{p_end}
{phang2}{cmd:    sep(" to ") title("Table 1: MSM Results") replace}{p_end}

{pstd}
{bf:Academic border style with custom font:}{p_end}

{phang2}{cmd:. msm_table, xlsx(results.xlsx) all eform}{p_end}
{phang2}{cmd:    font(Calibri) fontsize(11) borderstyle(academic) replace}{p_end}

{pstd}
{bf:Zebra striping, bold significant p-values, and a footnote:}{p_end}

{phang2}{cmd:. msm_table, xlsx(results.xlsx) coefficients eform zebra}{p_end}
{phang2}{cmd:    boldp(0.05) highlight(0.05)}{p_end}
{phang2}{cmd:    footnote("Bold p-values indicate significance at 0.05.") replace}{p_end}

{pstd}
{bf:Auto-open after export:}{p_end}

{phang2}{cmd:. msm_table, xlsx(results.xlsx) all eform zebra open replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}
