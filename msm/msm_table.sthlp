{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_sensitivity" "help msm_sensitivity"}{...}
{viewerjumpto "Syntax" "msm_table##syntax"}{...}
{viewerjumpto "Description" "msm_table##description"}{...}
{viewerjumpto "Options" "msm_table##options"}{...}
{viewerjumpto "Sheets" "msm_table##sheets"}{...}
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
{synopt:{opt xlsx(filename)}}Excel output file (.xlsx){p_end}

{syntab:Table selection}
{synopt:{opt coef:icients}}model coefficients{p_end}
{synopt:{opt pred:ictions}}counterfactual outcome predictions{p_end}
{synopt:{opt bal:ance}}covariate balance (SMD){p_end}
{synopt:{opt weight:s}}weight distribution summary{p_end}
{synopt:{opt sens:itivity}}E-value sensitivity analysis{p_end}
{synopt:{opt all}}all available tables (default){p_end}

{syntab:Formatting}
{synopt:{opt ef:orm}}exponentiate coefficients (OR/HR){p_end}
{synopt:{opt dec:imals(#)}}decimal places; default is {cmd:3}{p_end}
{synopt:{opt sep(string)}}CI delimiter; default is {cmd:", "}{p_end}
{synopt:{opt tit:le(string)}}title for cell A1{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synopt:{opt f:ont(name)}}font name; default is {cmd:Arial}{p_end}
{synopt:{opt fonts:ize(#)}}font size in points; default is {cmd:10}{p_end}
{synopt:{opt border:style(style)}}border style: {cmd:thin}, {cmd:medium}, or {cmd:academic}; default is {cmd:thin}{p_end}
{synopt:{opt nfor:mat(string)}}Excel number format for numeric cells{p_end}
{synopt:{opt zebra}}alternating row shading (light gray){p_end}
{synopt:{opt bold:p(#)}}bold p-values below threshold (Coefficients only){p_end}
{synopt:{opt high:light(#)}}highlight rows where p < threshold (Coefficients only){p_end}
{synopt:{opt foot:note(string)}}merged footnote below each table{p_end}
{synopt:{opt open}}auto-open Excel file after export{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_table} exports results from the MSM pipeline to a formatted Excel
workbook with one sheet per table type. Each sheet includes a title row,
formatted headers, full border frame, and configurable font (default
Arial 10). Numeric values are stored as proper Excel numbers for
sorting and formulas. Column widths are calculated automatically from
content.

{pstd}
By default (or with {opt all}), all available tables are exported. Tables are
skipped silently if the required pipeline step has not been run. When specific
tables are requested, missing prerequisites produce an error.

{pstd}
The command reads persisted results stored by {cmd:msm_fit} (e()),
{cmd:msm_predict}, {cmd:msm_diagnose}, and {cmd:msm_sensitivity} (saved to
Stata matrices and dataset characteristics).


{marker options}{...}
{title:Options}

{dlgtab:Table selection}

{phang}
{opt coef:icients} exports model coefficients from {cmd:msm_fit}. Columns
include the point estimate, 95% CI, and p-value. The column header adapts
to model type: OR (logistic), HR (cox), or Coef. (linear).

{phang}
{opt pred:ictions} exports counterfactual predictions from {cmd:msm_predict}.
For {cmd:both} strategy, includes Never-Treat and Always-Treat estimates with
two-level merged headers. Includes Risk Difference columns if {cmd:difference}
was specified.

{phang}
{opt bal:ance} exports the covariate balance table from {cmd:msm_diagnose}.
Shows raw and weighted SMDs, percentage change, and a balanced indicator.
Includes a footer summarizing the number of balanced covariates.

{phang}
{opt weight:s} exports weight distribution summary statistics from
{cmd:msm_diagnose}: mean, SD, min, P1, median, P99, max, ESS, and ESS (%).

{phang}
{opt sens:itivity} exports sensitivity analysis results from
{cmd:msm_sensitivity}: treatment effect, CI, and E-values if computed.

{dlgtab:Formatting}

{phang}
{opt ef:orm} exponentiates coefficients on the Coefficients sheet. Displays
odds ratios (logistic), hazard ratios (cox), or exp(b) (linear).

{phang}
{opt dec:imals(#)} sets decimal places for numeric values. Default is 3.
P-values use the tabtools convention: {cmd:<0.001} for very small values,
3 decimal places for p < 0.05, 2 decimal places for p >= 0.05.

{phang}
{opt sep(string)} sets the CI delimiter. Default is {cmd:", "}. For example,
{cmd:sep(" to ")} produces CI formatted as "(0.58 to 0.85)".

{phang}
{opt tit:le(string)} sets the title text in cell A1 of each sheet. If not
specified, a default title is used (e.g., "Coefficients", "Predictions").

{phang}
{opt replace} overwrites an existing Excel file.

{phang}
{opt f:ont(name)} sets the font for all cells. Default is {cmd:Arial}.

{phang}
{opt fonts:ize(#)} sets the font size in points. Default is {cmd:10}.
Must be between 6 and 72.

{phang}
{opt border:style(style)} sets the border weight for the table frame and
separators. Options are {cmd:thin} (default), {cmd:medium}, or
{cmd:academic}.

{phang}
{opt nfor:mat(string)} applies an Excel number format to converted numeric
cells. For example, {cmd:nformat("#,##0.000")} adds thousands separators
with 3 decimal places. If not specified, Excel uses its default format.

{phang}
{opt zebra} applies alternating row shading (light gray, RGB 242 242 242) to
data rows. Makes wide tables easier to read across rows. Applies to all
sheets.

{phang}
{opt bold:p(#)} bolds p-values below the specified threshold on the
Coefficients sheet. For example, {cmd:boldp(0.05)} bolds all p-values < 0.05.
Values formatted as {cmd:<0.001} are always bolded when this option is used.

{phang}
{opt high:light(#)} highlights entire rows on the Coefficients sheet where the
p-value is below the specified threshold, using light yellow shading
(RGB 255 255 204). Overrides zebra shading for highlighted rows.

{phang}
{opt foot:note(string)} adds a merged, italic footnote row below each table.
The footnote appears outside the table border frame in a smaller font
(2 points below the main font size, minimum 6pt). Useful for explaining
statistical conventions or data sources.

{phang}
{opt open} automatically opens the Excel file after export using the
system default application.


{marker sheets}{...}
{title:Sheet specifications}

{pstd}
{bf:Coefficients}: Variable | OR/HR/Coef. | 95% CI | p-value

{pstd}
{bf:Predictions}: Period | Est. | 95% CI (per strategy, with merged headers)

{pstd}
{bf:Balance}: Covariate | Raw SMD | Weighted SMD | % Change | Balanced

{pstd}
{bf:Weights}: Statistic | Value (9 summary rows)

{pstd}
{bf:Sensitivity}: Parameter | Value (effect, CI, E-values)


{marker examples}{...}
{title:Examples}

{pstd}Export all available tables:{p_end}
{phang2}{cmd:. msm_table, xlsx(results.xlsx) eform replace}{p_end}

{pstd}Export only coefficients with odds ratios:{p_end}
{phang2}{cmd:. msm_table, xlsx(coef_table.xlsx) coefficients eform replace}{p_end}

{pstd}Export predictions and balance sheets:{p_end}
{phang2}{cmd:. msm_table, xlsx(tables.xlsx) predictions balance replace}{p_end}

{pstd}Custom formatting:{p_end}
{phang2}{cmd:. msm_table, xlsx(pub_table.xlsx) all eform decimals(2) sep(" to ") title("Table 1: MSM Results") replace}{p_end}

{pstd}Custom font and border style:{p_end}
{phang2}{cmd:. msm_table, xlsx(results.xlsx) all eform font(Calibri) fontsize(11) borderstyle(medium) replace}{p_end}

{pstd}With zebra striping and bold p-values:{p_end}
{phang2}{cmd:. msm_table, xlsx(results.xlsx) all eform zebra boldp(0.05) replace}{p_end}

{pstd}Highlight significant results with footnote:{p_end}
{phang2}{cmd:. msm_table, xlsx(results.xlsx) coefficients eform zebra highlight(0.05) footnote("Bold p-values indicate statistical significance at the 0.05 level.") replace}{p_end}

{pstd}Auto-open after export:{p_end}
{phang2}{cmd:. msm_table, xlsx(results.xlsx) all eform zebra open replace}{p_end}


{title:Prerequisites}

{pstd}
Run the MSM pipeline before calling {cmd:msm_table}:

{phang2}1. {cmd:msm_prepare} {hline 2} set up data{p_end}
{phang2}2. {cmd:msm_weight} {hline 2} compute IPTW weights{p_end}
{phang2}3. {cmd:msm_fit} {hline 2} fit outcome model (required for coefficients){p_end}
{phang2}4. {cmd:msm_predict} {hline 2} compute predictions (required for predictions){p_end}
{phang2}5. {cmd:msm_diagnose} {hline 2} run diagnostics (required for balance/weights){p_end}
{phang2}6. {cmd:msm_sensitivity} {hline 2} sensitivity analysis (required for sensitivity){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
