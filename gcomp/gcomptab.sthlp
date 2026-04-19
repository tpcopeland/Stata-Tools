{smcl}
{* *! version 1.0.2  19apr2026}{...}
{viewerjumpto "Syntax" "gcomptab##syntax"}{...}
{viewerjumpto "Description" "gcomptab##description"}{...}
{viewerjumpto "Options" "gcomptab##options"}{...}
{viewerjumpto "Remarks" "gcomptab##remarks"}{...}
{viewerjumpto "Examples" "gcomptab##examples"}{...}
{viewerjumpto "Output format" "gcomptab##output"}{...}
{viewerjumpto "Stored results" "gcomptab##stored"}{...}
{viewerjumpto "Also see" "gcomptab##seealso"}{...}
{viewerjumpto "Author" "gcomptab##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:gcomptab} {hline 2}}Format gcomp mediation results into Excel tables{p_end}
{p2colreset}{...}

{pstd}Format gcomp mediation analysis results into a polished Excel table.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:gcomptab}, {opt xlsx(string)} {opt sheet(string)} [{opt ci(string)} {opt effect(string)} {opt title(string)} {opt labels(string)} {opt decimal(#)} {opt font(string)} {opt fonts:ize(#)} {opt border:style(string)} {opt zebra} {opt foot:note(string)} {opt open} {opt bold:p(#)} {opt high:light(#)}]{p_end}

{pstd}Required: run {cmd:gcomp} first for a supported mediation analysis. {cmd:gcomptab} requires {cmd:e(cmd)} = {cmd:gcomp}, {cmd:e(analysis_type)} = {cmd:mediation}, and the result matrices described below.{p_end}

{marker description}{title:Description}

{pstd}{cmd:gcomptab} formats output from {cmd:gcomp} (parametric g-formula for causal mediation analysis) into publication-ready Excel tables. It exports:{p_end}

{p 8 12 2}- Total Causal Effect (TCE){p_end}
{p 8 12 2}- Natural Direct Effect (NDE){p_end}
{p 8 12 2}- Natural Indirect Effect (NIE){p_end}
{p 8 12 2}- Proportion Mediated (PM){p_end}
{p 8 12 2}- Controlled Direct Effect (CDE){p_end}

{pstd}Each effect is displayed with its point estimate, 95% confidence interval, and standard error. The command applies professional Excel formatting.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt xlsx(string)}}Output Excel filename (must end with {cmd:.xlsx}). If the file exists, only the named sheet is replaced.{p_end}
{synopt:{opt sheet(string)}}Target sheet name to create/replace in {opt xlsx()}. Excel sheet names must be 31 characters or fewer and may not contain {cmd:: \ / ? * [ ]}.{p_end}
{synopt:{opt ci(string)}}Type of confidence interval to display: {cmd:normal} (default), {cmd:percentile}, {cmd:bc} (bias-corrected), or {cmd:bca} (bias-corrected and accelerated). Must match a CI matrix created by gcomp.{p_end}
{synopt:{opt effect(string)}}Header label for the effect estimate column. Default is {cmd:"Estimate"}.{p_end}
{synopt:{opt title(string)}}Text written into cell {cmd:A1} and merged across the table width.{p_end}
{synopt:{opt labels(string)}}Custom labels for the five effects, separated by backslash. Default is {cmd:"Total Causal Effect (TCE) \ Natural Direct Effect (NDE) \ Natural Indirect Effect (NIE) \ Proportion Mediated (PM) \ Controlled Direct Effect (CDE)"}.{p_end}
{synopt:{opt decimal(#)}}Number of decimal places for estimates and CIs. Default is 3. Range: 1-6.{p_end}
{synopt:{opt font(string)}}Font family for Excel output. Default is {cmd:"Arial"}.{p_end}
{synopt:{opt fonts:ize(#)}}Font size for body text. Title uses fontsize+2. Default is 10.{p_end}
{synopt:{opt border:style(string)}}Border style: {cmd:academic} (default, horizontal only), {cmd:thin}, or {cmd:medium}.{p_end}
{synopt:{opt zebra}}Apply alternating row shading (light blue) to data rows.{p_end}
{synopt:{opt foot:note(string)}}Footnote text placed below the table in smaller italic font.{p_end}
{synopt:{opt open}}Open the Excel file after export.{p_end}
{synopt:{opt bold:p(#)}}Bold the numeric cells in a data row when the two-sided Wald p-value {cmd:2*normal(-abs(estimate/se))} is below the cutoff. Default {cmd:0} disables bolding; otherwise require {cmd:0 < cutoff < 1}.{p_end}
{synopt:{opt high:light(#)}}Highlight the full data row in yellow when the same Wald p-value is below the cutoff. Default {cmd:0} disables highlighting; otherwise require {cmd:0 < cutoff < 1}.{p_end}
{synoptline}

{marker remarks}{title:Remarks}

{pstd}{bf:About gcomp}{p_end}

{p 4 8 2}{cmd:gcomp} is a user-written Stata command for causal mediation analysis using the parametric g-formula. It estimates causal effects through Monte Carlo simulation with bootstrap confidence intervals. It is a maintained fork of SSC {cmd:gformula} with bug fixes and modernization.{p_end}

{pstd}{bf:Prerequisites}{p_end}

{p 4 8 2}Run {cmd:gcomp} with the {cmd:mediation} option before using {cmd:gcomptab}. The {cmd:oce} mediation type is not supported; {cmd:gcomptab} handles standard mediation results ({cmd:obe}, {cmd:linexp}, {cmd:specific}, or baseline-based). The command reads:{p_end}

{p 8 12 2}- Point estimates from {cmd:e(b)} with named columns {cmd:tce nde nie pm} and optional {cmd:cde}{p_end}
{p 8 12 2}- Standard errors from {cmd:e(se)} with the same column names{p_end}
{p 8 12 2}- Confidence intervals from {cmd:e(ci_normal)} and, when requested, {cmd:e(ci_percentile)}, {cmd:e(ci_bc)}, or {cmd:e(ci_bca)}{p_end}

{p 4 8 2}When the fitted mediation results do not include a {cmd:cde} column, {cmd:gcomptab} exports four effect rows ({cmd:TCE}, {cmd:NDE}, {cmd:NIE}, {cmd:PM}), returns {cmd:r(N_effects)} = 4, and does not return {cmd:r(cde)}.{p_end}

{pstd}{bf:Confidence interval types}{p_end}

{p 4 8 2}The {opt ci()} option controls which confidence interval is displayed:{p_end}

{p 8 12 2}{cmd:normal} - Normal approximation (mean +/- 1.96*SE){p_end}
{p 8 12 2}{cmd:percentile} - Percentile bootstrap CI{p_end}
{p 8 12 2}{cmd:bc} - Bias-corrected bootstrap CI{p_end}
{p 8 12 2}{cmd:bca} - Bias-corrected and accelerated bootstrap CI{p_end}

{pstd}{bf:Comparison with effecttab}{p_end}

{p 4 8 2}Use {cmd:effecttab} for causal inference results from Stata's built-in commands ({cmd:teffects}, {cmd:margins}).{p_end}

{p 4 8 2}Use {cmd:gcomptab} for mediation analysis results from the user-written {cmd:gcomp} command.{p_end}

{marker examples}{title:Examples}

{pstd}These examples assume the mediation fit shown above has already been run. The workbook paths below are ordinary filenames in the current working directory, so they work after a normal {cmd:net install}.{p_end}

{pstd}{bf:Example 1: Mediation of antidepressant effect through adherence}{p_end}
{phang2}{cmd:. * Run gcomp: SNRI vs SSRI → adherence → CV event}{p_end}
{phang2}{cmd:. gcomp cv_event adherence treated index_age female, ///}{p_end}
{phang3}{cmd:outcome(cv_event) mediation obe exposure(treated) mediator(adherence) ///}{p_end}
{phang3}{cmd:commands(adherence: logit, cv_event: logit) ///}{p_end}
{phang3}{cmd:equations(adherence: treated index_age female, cv_event: adherence treated index_age female) ///}{p_end}
{phang3}{cmd:base_confs(index_age female) control(0) sim(1000) samples(500) all}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Format results to Excel}{p_end}
{phang2}{cmd:. gcomptab, xlsx("mediation_results.xlsx") sheet("Table 1") ///}{p_end}
{phang3}{cmd:title("Causal Mediation: SNRI Effect via Adherence")}{p_end}

{pstd}{bf:Example 2: Using percentile bootstrap CIs}{p_end}
{phang2}{cmd:. gcomptab, xlsx("mediation_results.xlsx") sheet("Percentile CI") ///}{p_end}
{phang3}{cmd:ci(percentile) title("Mediation Results (Percentile CI)")}{p_end}

{pstd}{bf:Example 3: Custom effect labels}{p_end}
{phang2}{cmd:. gcomptab, xlsx("mediation_results.xlsx") sheet("Custom") ///}{p_end}
{phang3}{cmd:labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ CDE") ///}{p_end}
{phang3}{cmd:effect("RD") title("Risk Difference Decomposition")}{p_end}

{pstd}{bf:Example 4: Higher precision output}{p_end}
{phang2}{cmd:. gcomptab, xlsx("mediation_results.xlsx") sheet("Precise") ///}{p_end}
{phang3}{cmd:decimal(4) title("Mediation Analysis (4 decimals)")}{p_end}

{marker output}{title:Output Format}

{pstd}The Excel output includes:{p_end}

{p 8 12 2}- {bf:Row 1}: Title (if specified), merged across table width{p_end}
{p 8 12 2}- {bf:Row 2}: Column headers: Effect, Estimate, 95% CI, SE{p_end}
{p 8 12 2}- {bf:Rows 3-6}: TCE, NDE, NIE, and PM{p_end}
{p 8 12 2}- {bf:Row 7}: CDE when the fitted {cmd:gcomp} results include it{p_end}
{p 8 12 2}- {bf:Next row}: Optional footnote, merged across the table width{p_end}

{pstd}Formatting applied:{p_end}

{p 8 12 2}- Configurable font and size (default Arial 10; title is fontsize+2){p_end}
{p 8 12 2}- Academic border style by default (horizontal rules only){p_end}
{p 8 12 2}- Blue-shaded header row{p_end}
{p 8 12 2}- Bold headers{p_end}
{p 8 12 2}- Centered numeric columns{p_end}
{p 8 12 2}- Column widths adjusted to content{p_end}
{p 8 12 2}- Numeric cells stored as Excel numbers (not text){p_end}
{p 8 12 2}- Optional zebra striping, footnotes, bolding via {opt bold:p()}, and row highlighting via {opt high:light()}{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:gcomptab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N_effects)}}number of effects (4 without CDE, 5 with CDE){p_end}
{synopt:{cmd:r(tce)}}total causal effect{p_end}
{synopt:{cmd:r(nde)}}natural direct effect{p_end}
{synopt:{cmd:r(nie)}}natural indirect effect{p_end}
{synopt:{cmd:r(pm)}}proportion mediated{p_end}
{synopt:{cmd:r(cde)}}controlled direct effect; returned only when the fitted results include CDE{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename{p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(ci)}}CI type used{p_end}

{marker seealso}{title:Also see}

{pstd}{helpb gcomp} for parametric g-formula mediation analysis{p_end}
{pstd}{helpb regtab} for formatting standard regression tables{p_end}
{pstd}{helpb effecttab} for formatting teffects and margins results{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.2 - 2026-04-19{p_end}

{hline}
