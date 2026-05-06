{smcl}
{* *! version 1.1.2  06may2026}{...}
{vieweralsosee "[R] bootstrap" "help bootstrap"}{...}
{viewerjumpto "Syntax" "gcomptab##syntax"}{...}
{viewerjumpto "Description" "gcomptab##description"}{...}
{viewerjumpto "Options" "gcomptab##options"}{...}
{viewerjumpto "Remarks" "gcomptab##remarks"}{...}
{viewerjumpto "Examples" "gcomptab##examples"}{...}
{viewerjumpto "Output format" "gcomptab##output"}{...}
{viewerjumpto "Stored results" "gcomptab##stored"}{...}
{viewerjumpto "Author" "gcomptab##author"}{...}
{viewerjumpto "Also see" "gcomptab##seealso"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:gcomptab} {hline 2}}Format gcomp mediation results into Excel tables{p_end}
{p2colreset}{...}

{pstd}
Export causal mediation results from {helpb gcomp} into a publication-ready
Excel table with formatted estimates, confidence intervals, and standard
errors.


{marker syntax}{...}
{title:Syntax}

{p 4 8 2}
{cmd:gcomptab}{cmd:,}
{opt xlsx(filename)}
{opt sheet(string)}
[{it:options}]

{synoptset 27 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt xlsx(filename)}}output Excel filename (must end with {cmd:.xlsx}){p_end}
{synopt:{opt sheet(string)}}target sheet name{p_end}

{syntab:Content}
{synopt:{opt ci(string)}}CI type: {cmd:normal} (default), {cmd:percentile}, {cmd:bc}, or {cmd:bca}{p_end}
{synopt:{opt effect(string)}}header label for estimate column; default is {cmd:"Estimate"}{p_end}
{synopt:{opt title(string)}}title text for cell A1{p_end}
{synopt:{opt labels(string)}}custom effect labels separated by backslash{p_end}
{synopt:{opt decimal(#)}}decimal places for numeric values; default is {cmd:3}; range 1-6{p_end}

{syntab:Formatting}
{synopt:{opt font(string)}}font family; default is {cmd:"Arial"}{p_end}
{synopt:{opt fonts:ize(#)}}body font size; title uses fontsize+2; default is {cmd:10}{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:academic} (default), {cmd:thin}, or {cmd:medium}{p_end}
{synopt:{opt zebra}}alternating row shading (light blue){p_end}
{synopt:{opt foot:note(string)}}footnote text below the table in smaller italic font{p_end}

{syntab:Emphasis}
{synopt:{opt bold:p(#)}}bold numeric cells when Wald p < cutoff; default {cmd:0} disables{p_end}
{synopt:{opt high:light(#)}}highlight row in yellow when Wald p < cutoff; default {cmd:0} disables{p_end}

{syntab:Other}
{synopt:{opt open}}open the Excel file after export{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:gcomptab} is a post-estimation command that reads the {cmd:e()} results
left behind by {helpb gcomp} and writes them into a formatted Excel workbook.
It is designed for the {bf:mediation analysis} workflow — it does not format
time-varying intervention results.

{pstd}
The exported table includes one row for each mediation effect:

{p 8 12 2}{hline 3} Total Causal Effect (TCE){p_end}
{p 8 12 2}{hline 3} Natural Direct Effect (NDE){p_end}
{p 8 12 2}{hline 3} Natural Indirect Effect (NIE){p_end}
{p 8 12 2}{hline 3} Proportion Mediated (PM){p_end}
{p 8 12 2}{hline 3} Controlled Direct Effect (CDE) — only when the fitted {cmd:gcomp} model included {opt control()}{p_end}

{pstd}
Each row shows the point estimate, 95% confidence interval, and standard error.
The table uses professional formatting: adjustable fonts, border styles,
optional zebra striping, footnotes, and conditional emphasis (bold or
highlight) for statistically significant effects.

{pstd}
{bf:Prerequisites.} Run {cmd:gcomp} with {opt mediation} before calling
{cmd:gcomptab}. The command checks that {cmd:e(cmd)} is {cmd:"gcomp"} and
{cmd:e(analysis_type)} is {cmd:"mediation"}. The {opt oce} mediation type is
not supported; use {opt obe}, {opt linexp}, {opt specific}, or baseline-based
mediation.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt xlsx(filename)} specifies the Excel workbook to create or update. The
filename must end with {cmd:.xlsx}. If the file already exists, only the named
sheet is replaced; other sheets are preserved.

{phang}
{opt sheet(string)} specifies the sheet name within the workbook. If the sheet
already exists it is overwritten; otherwise a new sheet is created. Sheet names
must be 31 characters or fewer and may not contain {cmd:: \ / ? * [ ]}.

{dlgtab:Content}

{phang}
{opt ci(string)} selects which confidence interval type to display in the
table. Options are:{break}
{cmd:normal} {hline 2} normal approximation: mean +/- 1.96 * SE (default){break}
{cmd:percentile} {hline 2} percentile bootstrap CI{break}
{cmd:bc} {hline 2} bias-corrected bootstrap CI{break}
{cmd:bca} {hline 2} bias-corrected and accelerated bootstrap CI{break}
The corresponding CI matrix (e.g. {cmd:e(ci_percentile)}) must exist in the
{cmd:gcomp} results. Run {cmd:gcomp} with {opt all} to generate all four
types.

{phang}
{opt effect(string)} sets the column header for the effect estimate column.
Default is {cmd:"Estimate"}. Use this to label the column with the scale of
your analysis, for example {cmd:effect("Risk Difference")} or {cmd:effect("logOR")}.

{phang}
{opt title(string)} places a title in cell A1 of the sheet, merged across
all columns and set in a larger, bold font. Useful for table captions that
will appear in the Excel output, such as
{cmd:title("Table 2. Causal Mediation Analysis")}.

{phang}
{opt labels(string)} overrides the default row labels for the five effects.
Separate labels with backslashes. The default is:{break}
{cmd:"Total Causal Effect (TCE) \ Natural Direct Effect (NDE) \}{break}
{cmd: Natural Indirect Effect (NIE) \ Proportion Mediated (PM) \}{break}
{cmd: Controlled Direct Effect (CDE)"}{break}
If the {cmd:gcomp} results have only 4 effects (no CDE), the fifth label is
ignored. If you provide fewer labels than effects, the remaining rows use
default labels.

{phang}
{opt decimal(#)} sets the number of decimal places for point estimates,
confidence limits, and standard errors. Default is {cmd:3}. Range is 1 to 6.

{dlgtab:Formatting}

{phang}
{opt font(string)} sets the font family for all text in the workbook.
Default is {cmd:"Arial"}. Any font installed on your system can be used.
Font names containing shell metacharacters are rejected before workbook
creation.

{phang}
{opt fontsize(#)} sets the body text font size in points. The title row
(if specified) uses fontsize+2. Default is {cmd:10}. Range is 1 to 72.

{phang}
{opt borderstyle(string)} controls the table border style:{break}
{cmd:academic} {hline 2} horizontal rules only, between header/body/footer (default){break}
{cmd:thin} {hline 2} thin borders on all cells{break}
{cmd:medium} {hline 2} medium-weight borders on all cells

{phang}
{opt zebra} applies alternating light-blue shading to data rows. This
improves readability in tables with many rows.

{phang}
{opt footnote(string)} places footnote text below the table. The text is
merged across the table width and displayed in a smaller italic font. Use
for model notes, data sources, or abbreviation definitions.

{dlgtab:Emphasis}

{phang}
{opt boldp(#)} applies bold formatting to the numeric cells (Estimate, CI, SE)
in any data row whose two-sided Wald p-value falls below the specified cutoff.
The p-value is computed as {cmd:2 * normal(-abs(estimate / se))}. Default is
{cmd:0}, which disables bolding. Specify a value between 0 and 1 (e.g.
{cmd:boldp(0.05)}).

{phang}
{opt highlight(#)} applies yellow background shading to the entire data row
when the Wald p-value is below the cutoff. Works like {opt boldp()} but uses
color instead of (or in addition to) bold weight. Default is {cmd:0} (disabled).

{dlgtab:Other}

{phang}
{opt open} opens the Excel file in the default application after export. On
most systems this launches Excel or a compatible viewer.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Workflow}

{pstd}
The typical workflow is:

{phang2}1. Fit the mediation model with {cmd:gcomp} (see {helpb gcomp}).{p_end}
{phang2}2. Run {cmd:gcomptab} immediately after to export results.{p_end}
{phang2}3. Optionally run {cmd:gcomptab} again with a different {opt ci()} or {opt sheet()} to create multiple tables in the same workbook.{p_end}

{pstd}
{bf:Multiple tables in one workbook}

{pstd}
Because {cmd:gcomptab} replaces only the named sheet, you can build a
multi-sheet workbook by calling {cmd:gcomptab} repeatedly with different
{opt sheet()} names:

{phang2}{cmd:. gcomptab, xlsx(results.xlsx) sheet("Normal CI") ci(normal)}{p_end}
{phang2}{cmd:. gcomptab, xlsx(results.xlsx) sheet("Percentile CI") ci(percentile)}{p_end}

{pstd}
{bf:Supported and unsupported mediation types}

{pstd}
{cmd:gcomptab} supports {opt obe}, {opt linexp}, {opt specific}, and
baseline-based mediation results. It does {bf:not} support {opt oce} results
because {opt oce} produces a variable number of contrast rows (one per
non-baseline exposure level) that cannot be formatted with a fixed 4-or-5
row layout. For {opt oce} output, extract results from {cmd:e()} directly.

{pstd}
{bf:When to use gcomptab vs. effecttab}

{pstd}
Use {cmd:gcomptab} for mediation results from the user-written {cmd:gcomp}
command. Use {helpb effecttab} for causal-inference results from Stata's
built-in commands ({helpb teffects}, {helpb margins}).


{marker examples}{...}
{title:Examples}

{pstd}
All examples below assume you have already run a {cmd:gcomp} mediation model.
See {helpb gcomp} for complete data-generation and model-fitting examples.

    {hline}
{pstd}
{bf:Example 1: Basic export}

{pstd}
Export the default results (normal CIs, 3 decimal places) to a new workbook:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Table 1") ///}{p_end}
{phang2}{cmd:      title("Causal Mediation: Treatment Effect via Adherence")}{p_end}

    {hline}
{pstd}
{bf:Example 2: Percentile bootstrap CIs}

{pstd}
Use percentile CIs instead of normal approximation. This requires that
{cmd:gcomp} was run with {opt all}:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Percentile CI") ///}{p_end}
{phang2}{cmd:      ci(percentile) title("Mediation Results (Percentile CI)")}{p_end}

    {hline}
{pstd}
{bf:Example 3: Custom labels and effect column header}

{pstd}
Relabel the effects and change the estimate column header:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Custom") ///}{p_end}
{phang2}{cmd:      labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ CDE") ///}{p_end}
{phang2}{cmd:      effect("Risk Difference") title("Risk Difference Decomposition")}{p_end}

    {hline}
{pstd}
{bf:Example 4: Higher precision with footnote}

{pstd}
Show 4 decimal places and add a footnote with model details:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Precise") ///}{p_end}
{phang2}{cmd:      decimal(4) title("Mediation Analysis") ///}{p_end}
{phang2}{cmd:      footnote("Bootstrap: 1000 replications. CI: Normal approximation.")}{p_end}

    {hline}
{pstd}
{bf:Example 5: Bold significant effects and zebra striping}

{pstd}
Bold effects with p < 0.05 and apply alternating row shading:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Formatted") ///}{p_end}
{phang2}{cmd:      title("Mediation Analysis") boldp(0.05) zebra}{p_end}

    {hline}
{pstd}
{bf:Example 6: Full formatting with highlight}

{pstd}
Combine title, footnote, zebra, bold, and yellow highlighting:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Full Format") ///}{p_end}
{phang2}{cmd:      title("Table 3. Causal Mediation Results") ///}{p_end}
{phang2}{cmd:      footnote("Bold: p < 0.05. Yellow: p < 0.01.") ///}{p_end}
{phang2}{cmd:      zebra boldp(0.05) highlight(0.01) font("Calibri") fontsize(11)}{p_end}


{marker output}{...}
{title:Output format}

{pstd}
The Excel table has the following structure:

{p 8 12 2}{bf:Row 1}: Title (if specified), merged across the table width, bold, fontsize+2.{p_end}
{p 8 12 2}{bf:Row 2}: Column headers — Effect | Estimate | 95% CI | SE — with blue background and bold text.{p_end}
{p 8 12 2}{bf:Rows 3-6}: Data rows for TCE, NDE, NIE, and PM.{p_end}
{p 8 12 2}{bf:Row 7}: CDE data row (only when the fitted model included {opt control()}).{p_end}
{p 8 12 2}{bf:Next row}: Footnote (if specified), merged across the table width, italic, smaller font.{p_end}

{pstd}
Formatting details:

{p 8 12 2}{hline 3} Numeric cells are stored as Excel numbers, not text, so they can be used in formulas.{p_end}
{p 8 12 2}{hline 3} Column widths are adjusted to content.{p_end}
{p 8 12 2}{hline 3} The academic border style (default) uses horizontal rules only — above and below the header row and below the last data row — matching journal conventions.{p_end}
{p 8 12 2}{hline 3} Zebra striping, bold, and highlighting are applied conditionally as described in {it:Options}.{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:gcomptab} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_effects)}}number of effects exported (4 without CDE, 5 with CDE){p_end}
{synopt:{cmd:r(tce)}}total causal effect{p_end}
{synopt:{cmd:r(nde)}}natural direct effect{p_end}
{synopt:{cmd:r(nie)}}natural indirect effect{p_end}
{synopt:{cmd:r(pm)}}proportion mediated{p_end}
{synopt:{cmd:r(cde)}}controlled direct effect (only when the fitted model included CDE){p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename used{p_end}
{synopt:{cmd:r(sheet)}}sheet name used{p_end}
{synopt:{cmd:r(ci)}}CI type displayed{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.1.2, 2026-05-06{p_end}


{marker seealso}{...}
{title:Also see}

{psee}
Online: {helpb gcomp}, {helpb regtab}, {helpb effecttab}

{hline}
