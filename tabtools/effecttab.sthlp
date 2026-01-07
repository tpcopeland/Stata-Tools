{smcl}
{* *! version 1.0.0  19dec2025}{...}
{title:effecttab}

{pstd}Format treatment effects and margins results into a polished Excel table.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:effecttab}, {opt xlsx(string)} {opt sheet(string)} [{opt type(string)} {opt effect(string)} {opt sep(string asis)} {opt models(string)} {opt title(string)} {opt clean}]{p_end}

{pstd}Required: an active {helpb collect} containing results from {helpb teffects} or {helpb margins}.{p_end}

{marker description}{title:Description}

{pstd}{cmd:effecttab} formats treatment effects and margins output for publication-ready Excel tables. It is designed for causal inference workflows including:{p_end}

{p 8 12 2}- Inverse probability weighting ({cmd:teffects ipw}){p_end}
{p 8 12 2}- Regression adjustment / G-computation ({cmd:teffects ra}, {cmd:margins}){p_end}
{p 8 12 2}- Doubly robust estimation ({cmd:teffects aipw}, {cmd:teffects ipwra}){p_end}
{p 8 12 2}- Propensity score matching ({cmd:teffects psmatch}){p_end}
{p 8 12 2}- Marginal effects and predicted probabilities ({cmd:margins}){p_end}

{pstd}{cmd:effecttab} reads the current {helpb collect} table and writes an Excel sheet with columns for point estimate, 95% CI, and p-value. It applies the same professional formatting as {helpb regtab}.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(string)}}Output Excel filename (must end with {cmd:.xlsx}). If the file exists, only the named sheet is replaced.{p_end}
{synopt:{opt sheet(string)}}Target sheet name to create/replace in {opt xlsx()}.{p_end}
{synopt:{opt type(string)}}Type of collected results: {cmd:teffects}, {cmd:margins}, or {cmd:auto} (default). Auto-detection examines colname patterns.{p_end}
{synopt:{opt effect(string)}}Header label for the effect column. Examples: {cmd:ATE}, {cmd:ATET}, {cmd:RD} (risk difference), {cmd:RR} (risk ratio), {cmd:AME} (average marginal effect), {cmd:Pr(Y)}. Default is "Effect" for teffects, "Estimate" for margins.{p_end}
{synopt:{opt sep(string asis)}}Delimiter between CI endpoints. Default is {cmd:", "}.{p_end}
{synopt:{opt models(string)}}Labels for multiple models, separated by backslash. Example: {cmd:"IPTW \ AIPW"}.{p_end}
{synopt:{opt title(string)}}Text written into cell {cmd:A1} and merged across the table width.{p_end}
{synopt:{opt clean}}Clean up teffects-style labels (e.g., {cmd:"r1vs0.treat"} becomes {cmd:"Treat (1 vs 0)"}).{p_end}
{synoptline}

{marker remarks}{title:Remarks}

{pstd}{bf:Comparison with regtab}{p_end}

{p 4 8 2}Use {cmd:regtab} for standard regression output (logit, regress, stcox, etc.) where you want to display coefficients/odds ratios for each covariate.{p_end}

{p 4 8 2}Use {cmd:effecttab} for causal inference results where you want to display treatment effects (ATE, ATET), potential outcome means, marginal effects, or predicted probabilities.{p_end}

{pstd}{bf:Working with teffects}{p_end}

{p 4 8 2}The {cmd:teffects} family of commands estimates treatment effects using various methods. Use the {cmd:collect:} prefix to capture results:{p_end}

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (outcome) (treatment age sex), ate}{p_end}
{phang2}{cmd:. effecttab, xlsx(results.xlsx) sheet("ATE") effect("ATE")}{p_end}

{pstd}{bf:Working with margins}{p_end}

{p 4 8 2}The {cmd:margins} command computes marginal effects, predicted probabilities, and contrasts. Results can be collected directly:{p_end}

{phang2}{cmd:. logit outcome i.treatment age sex}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins treatment}{p_end}
{phang2}{cmd:. effecttab, xlsx(results.xlsx) sheet("Predictions") type(margins) effect("Pr(Y)")}{p_end}

{pstd}{bf:The clean option}{p_end}

{p 4 8 2}When using {cmd:teffects}, the row labels often contain technical notation like {cmd:r1vs0.treatment} (meaning treatment level 1 vs 0). The {cmd:clean} option reformats these to human-readable labels like {cmd:Treatment (1 vs 0)}.{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: IPTW estimation of average treatment effect}{p_end}
{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (died) (drug age), ate}{p_end}
{phang2}{cmd:. effecttab, xlsx(cancer_ate.xlsx) sheet("Table 1") effect("ATE") title("Table 1. Average Treatment Effect (IPTW)") clean}{p_end}

{pstd}{bf:Example 2: Comparing IPTW and doubly robust estimators}{p_end}
{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (died) (drug age), ate}{p_end}
{phang2}{cmd:. collect: teffects aipw (died age) (drug age), ate}{p_end}
{phang2}{cmd:. effecttab, xlsx(cancer_compare.xlsx) sheet("Comparison") models("IPTW \ AIPW") effect("ATE") clean}{p_end}

{pstd}{bf:Example 3: Potential outcome means}{p_end}
{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (died) (drug age), pomeans}{p_end}
{phang2}{cmd:. effecttab, xlsx(cancer_pom.xlsx) sheet("PO Means") effect("Pr(Death)") title("Potential Outcome Means") clean}{p_end}

{pstd}{bf:Example 4: Marginal effects (G-computation style)}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins, dydx(mpg weight)}{p_end}
{phang2}{cmd:. effecttab, xlsx(auto_margins.xlsx) sheet("AME") effect("AME") title("Average Marginal Effects")}{p_end}

{pstd}{bf:Example 5: Predicted probabilities by group}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign i.rep78 mpg weight}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins rep78}{p_end}
{phang2}{cmd:. effecttab, xlsx(auto_probs.xlsx) sheet("Predictions") type(margins) effect("Pr(Foreign)") title("Predicted Probability by Repair Record")}{p_end}

{pstd}{bf:Example 6: Risk differences from margins}{p_end}
{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. logit died i.drug age}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins r.drug}{p_end}
{phang2}{cmd:. effecttab, xlsx(cancer_rd.xlsx) sheet("Risk Diff") effect("RD") title("Risk Differences vs Reference")}{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:effecttab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in output table{p_end}
{synopt:{cmd:r(N_cols)}}number of columns in output table{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename{p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(type)}}detected or specified result type{p_end}

{marker seealso}{title:Also see}

{pstd}{helpb regtab} for formatting standard regression tables{p_end}
{pstd}{helpb teffects} for treatment effects estimation{p_end}
{pstd}{helpb margins} for marginal effects and predictions{p_end}
{pstd}{helpb collect} for the underlying collection framework{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 2025-12-19{p_end}
