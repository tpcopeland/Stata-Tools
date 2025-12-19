{smcl}
{* *! version 1.0.0  19dec2025}{...}
{title:gformtab}

{pstd}Format gformula mediation analysis results into a polished Excel table.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:gformtab}, {opt xlsx(string)} {opt sheet(string)} [{opt ci(string)} {opt effect(string)} {opt title(string)} {opt labels(string)} {opt decimal(#)}]{p_end}

{pstd}Required: Run {cmd:gformula} first. {cmd:gformtab} reads results from {cmd:r()} scalars and matrices.{p_end}

{marker description}{title:Description}

{pstd}{cmd:gformtab} formats output from {cmd:gformula} (parametric g-formula for causal mediation analysis) into publication-ready Excel tables. It exports:{p_end}

{p 8 12 2}- Total Causal Effect (TCE){p_end}
{p 8 12 2}- Natural Direct Effect (NDE){p_end}
{p 8 12 2}- Natural Indirect Effect (NIE){p_end}
{p 8 12 2}- Proportion Mediated (PM){p_end}
{p 8 12 2}- Controlled Direct Effect (CDE){p_end}

{pstd}Each effect is displayed with its point estimate, 95% confidence interval, and standard error. The command applies professional Excel formatting consistent with {helpb regtab} and {helpb effecttab}.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(string)}}Output Excel filename (must end with {cmd:.xlsx}). If the file exists, only the named sheet is replaced.{p_end}
{synopt:{opt sheet(string)}}Target sheet name to create/replace in {opt xlsx()}.{p_end}
{synopt:{opt ci(string)}}Type of confidence interval to display: {cmd:normal} (default), {cmd:percentile}, {cmd:bc} (bias-corrected), or {cmd:bca} (bias-corrected and accelerated). Must match a CI matrix created by gformula.{p_end}
{synopt:{opt effect(string)}}Header label for the effect estimate column. Default is {cmd:"Effect"}.{p_end}
{synopt:{opt title(string)}}Text written into cell {cmd:A1} and merged across the table width.{p_end}
{synopt:{opt labels(string)}}Custom labels for the five effects, separated by backslash. Default is {cmd:"Total Causal Effect (TCE) \ Natural Direct Effect (NDE) \ Natural Indirect Effect (NIE) \ Proportion Mediated (PM) \ Controlled Direct Effect (CDE)"}.{p_end}
{synopt:{opt decimal(#)}}Number of decimal places for estimates and CIs. Default is 3. Range: 1-6.{p_end}
{synoptline}

{marker remarks}{title:Remarks}

{pstd}{bf:About gformula}{p_end}

{p 4 8 2}{cmd:gformula} is a user-written Stata command for causal mediation analysis using the parametric g-formula. It estimates causal effects through Monte Carlo simulation with bootstrap confidence intervals. The command is available from the SSC archive.{p_end}

{pstd}{bf:Prerequisites}{p_end}

{p 4 8 2}Run {cmd:gformula} with the bootstrap option before using {cmd:gformtab}. The command reads:{p_end}

{p 8 12 2}- Point estimates from {cmd:r(tce)}, {cmd:r(nde)}, {cmd:r(nie)}, {cmd:r(pm)}, {cmd:r(cde)}{p_end}
{p 8 12 2}- Standard errors from {cmd:r(se_tce)}, {cmd:r(se_nde)}, {cmd:r(se_nie)}, {cmd:r(se_pm)}, {cmd:r(se_cde)}{p_end}
{p 8 12 2}- Confidence intervals from matrices: {cmd:ci_normal}, {cmd:ci_percentile}, {cmd:ci_bc}, {cmd:ci_bca}{p_end}

{pstd}{bf:Confidence interval types}{p_end}

{p 4 8 2}The {opt ci()} option controls which confidence interval is displayed:{p_end}

{p 8 12 2}{cmd:normal} - Normal approximation (mean +/- 1.96*SE){p_end}
{p 8 12 2}{cmd:percentile} - Percentile bootstrap CI{p_end}
{p 8 12 2}{cmd:bc} - Bias-corrected bootstrap CI{p_end}
{p 8 12 2}{cmd:bca} - Bias-corrected and accelerated bootstrap CI{p_end}

{pstd}{bf:Comparison with effecttab}{p_end}

{p 4 8 2}Use {cmd:effecttab} for causal inference results from Stata's built-in commands ({cmd:teffects}, {cmd:margins}).{p_end}

{p 4 8 2}Use {cmd:gformtab} for mediation analysis results from the user-written {cmd:gformula} command.{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Basic usage after gformula}{p_end}
{phang2}{cmd:. * Run gformula first (example syntax)}{p_end}
{phang2}{cmd:. gformula outcome mediator treatment confounder, ///}{p_end}
{phang2}{cmd:      outcome(outcome) treatment(treatment) mediator(mediator) ///}{p_end}
{phang2}{cmd:      control(0) base_confs(confounder) sim(1000) bootstrap(500)}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Format results to Excel}{p_end}
{phang2}{cmd:. gformtab, xlsx(mediation.xlsx) sheet("Table 1") ///}{p_end}
{phang2}{cmd:      title("Table 1. Causal Mediation Analysis")}{p_end}

{pstd}{bf:Example 2: Using percentile bootstrap CIs}{p_end}
{phang2}{cmd:. gformtab, xlsx(mediation.xlsx) sheet("Percentile CI") ///}{p_end}
{phang2}{cmd:      ci(percentile) title("Mediation Results (Percentile CI)")}{p_end}

{pstd}{bf:Example 3: Custom effect labels}{p_end}
{phang2}{cmd:. gformtab, xlsx(mediation.xlsx) sheet("Custom") ///}{p_end}
{phang2}{cmd:      labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ CDE") ///}{p_end}
{phang2}{cmd:      effect("RD") title("Risk Difference Decomposition")}{p_end}

{pstd}{bf:Example 4: Higher precision output}{p_end}
{phang2}{cmd:. gformtab, xlsx(mediation.xlsx) sheet("Precise") ///}{p_end}
{phang2}{cmd:      decimal(4) title("Mediation Analysis (4 decimals)")}{p_end}

{marker output}{title:Output Format}

{pstd}The Excel output includes:{p_end}

{p 8 12 2}- {bf:Row 1}: Title (if specified), merged across table width{p_end}
{p 8 12 2}- {bf:Row 2}: Column headers: Effect, Estimate, 95% CI, SE{p_end}
{p 8 12 2}- {bf:Rows 3-7}: The five effect estimates with CIs and SEs{p_end}

{pstd}Formatting applied:{p_end}

{p 8 12 2}- Arial 10 point font{p_end}
{p 8 12 2}- Borders around table{p_end}
{p 8 12 2}- Bold headers{p_end}
{p 8 12 2}- Centered numeric columns{p_end}
{p 8 12 2}- Column widths adjusted to content{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:gformtab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N_effects)}}number of effects (always 5){p_end}
{synopt:{cmd:r(tce)}}total causal effect{p_end}
{synopt:{cmd:r(nde)}}natural direct effect{p_end}
{synopt:{cmd:r(nie)}}natural indirect effect{p_end}
{synopt:{cmd:r(pm)}}proportion mediated{p_end}
{synopt:{cmd:r(cde)}}controlled direct effect{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename{p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(ci)}}CI type used{p_end}

{marker seealso}{title:Also see}

{pstd}{helpb regtab} for formatting standard regression tables{p_end}
{pstd}{helpb effecttab} for formatting teffects and margins results{p_end}
{pstd}SSC package {cmd:gformula} for parametric g-formula mediation analysis{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 2025-12-19{p_end}
