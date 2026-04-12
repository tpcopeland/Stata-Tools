{smcl}
{* *! version 1.0.1  09apr2026}{...}
{viewerjumpto "Syntax" "effecttab##syntax"}{...}
{viewerjumpto "Description" "effecttab##description"}{...}
{viewerjumpto "Options" "effecttab##options"}{...}
{viewerjumpto "Remarks" "effecttab##remarks"}{...}
{viewerjumpto "Examples" "effecttab##examples"}{...}
{viewerjumpto "Stored results" "effecttab##stored"}{...}
{viewerjumpto "Also see" "effecttab##seealso"}{...}
{viewerjumpto "Author" "effecttab##author"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{title:effecttab}

{pstd}Format treatment effects and margins results into a polished Excel table.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:effecttab}, [{opt xlsx(string)} {opt sheet(string)} {opt type(string)} {opt effect(string)} {opt sep(string asis)} {opt models(string)} {opt title(string)} {opt sub:title(string)} {opt clean} {opt tlab:els(string asis)} {opt foot:note(string)} {opt open} {opt zebra} {opt high:light(#)} {opt boldp(#)} {opt borders:tyle(string)} {opt the:me(string)} {opt full} {opt digits(#)} {opt fra:me(name)} {opt dis:play} {opt from(name)} {opt headerc:olor(string)} {opt zebrac:olor(string)} {opt csv(string)} {cmdab:addr:ow(}{it:string asis}{cmd:)} {opt pdp(#)} {opt highpdp(#)}]{p_end}

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
{synopt:{opt xlsx(string)}}Output Excel filename (must end with {cmd:.xlsx}). If the file exists, only the named sheet is replaced. {opt excel()} is accepted as a synonym. If omitted, results are displayed in the console only.{p_end}
{synopt:{opt sheet(string)}}Target sheet name to create/replace in {opt xlsx()}. Default is {cmd:"Effects"}.{p_end}
{synopt:{opt type(string)}}Type of collected results: {cmd:teffects}, {cmd:margins}, or {cmd:auto} (default). Auto-detection checks {cmd:e(cmd)}.{p_end}
{synopt:{opt effect(string)}}Header label for the effect column. Examples: {cmd:ATE}, {cmd:ATET}, {cmd:RD} (risk difference), {cmd:RR} (risk ratio), {cmd:AME} (average marginal effect), {cmd:Pr(Y)}. Default is "Effect" for teffects, "Estimate" for margins.{p_end}
{synopt:{opt sep(string asis)}}Delimiter between CI endpoints. Default is {cmd:", "}.{p_end}
{synopt:{opt models(string)}}Labels for multiple models, separated by backslash. Example: {cmd:"IPTW \ AIPW"}.{p_end}
{synopt:{opt title(string)}}Text written into cell {cmd:A1} and merged across the table width.{p_end}
{synopt:{opt sub:title(string)}}Subtitle text displayed below the title row.{p_end}
{synopt:{opt clean}}Clean up teffects row labels. When the treatment variable has value labels,
uses them automatically (e.g., {cmd:"r1vs0.treated"} becomes {cmd:"SNRI vs SSRI"}).
Falls back to basic cleanup if no value labels exist (e.g., {cmd:"Treated (1 vs 0)"}).{p_end}
{synopt:{opt tlab:els(string asis)}}Explicit treatment level labels as value-label pairs.
Implies {cmd:clean}. Example: {cmd:tlabels(0 "SSRI" 1 "SNRI")} produces ATE row
{cmd:"SNRI vs SSRI"} and PO Mean rows {cmd:"SSRI (PO Mean)"}, {cmd:"SNRI (PO Mean)"}.
Takes priority over auto-detected value labels.{p_end}
{synopt:{opt foot:note(string)}}Add a footnote row below the table in smaller italic font.{p_end}
{synopt:{opt open}}Open the Excel file in the default application after export.{p_end}
{synopt:{opt zebra}}Apply alternating light gray row shading for readability.{p_end}
{synopt:{opt high:light(#)}}Apply yellow fill to rows where p-value < threshold.{p_end}
{synopt:{opt boldp(#)}}Bold p-value cells below threshold (e.g., {cmd:boldp(0.05)}).{p_end}
{synopt:{opt borders:tyle(string)}}Border style: {cmd:thin} (default), {cmd:medium}, or {cmd:academic}.{p_end}
{synopt:{opt full}}Show all rows including those normally filtered (e.g., display all teffects rows, not just ATE/POmean).{p_end}
{synopt:{opt digits(#)}}Number of decimal places for effects and CIs (default 2, range 0-6).{p_end}
{synopt:{opt fra:me(name)}}Store output in a named Stata frame. Specify {cmd:frame(name, replace)} to replace an existing frame.{p_end}
{synopt:{opt dis:play}}Show formatted table in the Results window (in addition to Excel export if {cmd:xlsx()} specified).{p_end}
{synopt:{opt the:me(string)}}Formatting theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}. Overrides font/fontsize/borderstyle. Can also be set globally with {cmd:tabtools set theme}.{p_end}
{synopt:{opt from(name)}}Pass results from a named Stata matrix instead of reading from {cmd:collect}.{p_end}
{synopt:{opt headerc:olor(string)}}Custom header background color as {cmd:"R G B"} (e.g., {cmd:"219 229 241"}).{p_end}
{synopt:{opt zebrac:olor(string)}}Custom zebra stripe color as {cmd:"R G B"} (e.g., {cmd:"237 242 249"}).{p_end}
{synopt:{opt csv(string)}}Also export as CSV to the specified filename.{p_end}
{synopt:{cmdab:addr:ow(}{it:string asis}{cmd:)}}Append custom rows below the table body. Specify pairs of label and values. Use backslash to separate multiple rows.{p_end}
{synopt:{opt pdp(#)}}Maximum decimal places for small p-values (p < 0.10). Default is 3.{p_end}
{synopt:{opt highpdp(#)}}Maximum decimal places for large p-values (p >= 0.10). Default is 2.{p_end}
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

{pstd}{bf:The clean option and treatment labels}{p_end}

{p 4 8 2}When using {cmd:teffects}, the row labels contain technical notation like
{cmd:r1vs0.treatment}. The {cmd:clean} option reformats these using value labels
from the treatment variable when available:{p_end}

{p 8 12 2}- If {cmd:treatment} has value labels (0="SSRI", 1="SNRI"), the ATE row becomes {cmd:"SNRI vs SSRI"} and PO Mean rows become {cmd:"SSRI (PO Mean)"}, {cmd:"SNRI (PO Mean)"}.{p_end}
{p 8 12 2}- If no value labels exist, falls back to basic cleanup: {cmd:"Treatment (1 vs 0)"}.{p_end}

{p 4 8 2}Use {cmd:tlabels()} to explicitly specify treatment level labels when value labels
are not defined or you want different wording. {cmd:tlabels()} implies {cmd:clean}.{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: IPTW estimation of maternal smoking on birth weight}{p_end}
{phang2}{stata "webuse cattaneo2, clear":. webuse cattaneo2, clear}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: teffects ipw (bweight) (mbsmoke mage medu, logit), ate":. collect: teffects ipw (bweight) (mbsmoke mage medu, logit), ate}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("ATE") effect("ATE") ///}{p_end}
{phang3}{cmd:title("ATE of Maternal Smoking on Birth Weight") ///}{p_end}
{phang3}{cmd:tlabels(0 "Non-smoker" 1 "Smoker")}{p_end}

{pstd}{bf:Example 2: Comparing IPTW and doubly robust estimators}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: teffects ipw (bweight) (mbsmoke mage medu, logit), ate":. collect: teffects ipw (bweight) (mbsmoke mage medu, logit), ate}{p_end}
{phang2}{stata "collect: teffects aipw (bweight mage medu) (mbsmoke mage medu, logit), ate":. collect: teffects aipw (bweight mage medu) (mbsmoke mage medu, logit), ate}{p_end}
{phang2}{stata `"effecttab, xlsx(effects.xlsx) sheet("Comparison") models("IPTW \ AIPW") effect("ATE") clean"':. effecttab, xlsx(effects.xlsx) sheet("Comparison") ///}{p_end}
{phang3}{cmd:models("IPTW \ AIPW") effect("ATE") clean}{p_end}

{pstd}{bf:Example 3: Potential outcome means}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: teffects ipw (bweight) (mbsmoke mage medu, logit), pomeans":. collect: teffects ipw (bweight) (mbsmoke mage medu, logit), pomeans}{p_end}
{phang2}{stata `"effecttab, xlsx(effects.xlsx) sheet("PO Means") effect("Birth Weight") title("Potential Outcome Means") clean"':. effecttab, xlsx(effects.xlsx) sheet("PO Means") ///}{p_end}
{phang3}{cmd:effect("Birth Weight") title("Potential Outcome Means") clean}{p_end}

{pstd}{bf:Example 4: Marginal effects}{p_end}
{phang2}{stata "webuse nhanes2, clear":. webuse nhanes2, clear}{p_end}
{phang2}{stata "logit diabetes age female i.race bmi highbp":. logit diabetes age female i.race bmi highbp}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: margins, dydx(age female bmi)":. collect: margins, dydx(age female bmi)}{p_end}
{phang2}{stata `"effecttab, xlsx(effects.xlsx) sheet("AME") effect("AME") title("Average Marginal Effects on Diabetes")"':. effecttab, xlsx(effects.xlsx) sheet("AME") effect("AME") ///}{p_end}
{phang3}{cmd:title("Average Marginal Effects on Diabetes")}{p_end}

{pstd}{bf:Example 5: Marginal effects at specific covariate values}{p_end}
{phang2}{stata "logit diabetes age female bmi highbp":. logit diabetes age female bmi highbp}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: margins, at(age=(40(10)70))":. collect: margins, at(age=(40(10)70))}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("Predictions") effect("Pr(Diabetes)") ///}{p_end}
{phang3}{cmd:title("Predicted Probability at Different Ages")}{p_end}

{pstd}{bf:Example 6: Stratified marginal effects with over()}{p_end}
{phang2}{stata "logit diabetes highbp##female age bmi":. logit diabetes highbp##female age bmi}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: margins highbp, over(female)":. collect: margins highbp, over(female)}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("Stratified") effect("Pr(Diabetes)") ///}{p_end}
{phang3}{cmd:title("Predicted Probability by Sex and Hypertension")}{p_end}

{pstd}{bf:Example 7: Average marginal effects (dydx) for all covariates}{p_end}
{phang2}{stata "logit diabetes age female bmi highbp":. logit diabetes age female bmi highbp}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: margins, dydx(*)":. collect: margins, dydx(*)}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("All AME") effect("AME") ///}{p_end}
{phang3}{cmd:title("Average Marginal Effects on Diabetes")}{p_end}

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
{synopt:{cmd:r(effect_label)}}effect column label{p_end}
{synopt:{cmd:r(methods)}}methods paragraph for manuscript text{p_end}
{synopt:{cmd:r(frame)}}frame name (if {cmd:frame()} specified){p_end}

{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}numeric matrix of effect estimates and p-values (rows = effects, columns = estimate and p-value per model){p_end}

{marker seealso}{title:Also see}

{pstd}{helpb regtab} for formatting standard regression tables{p_end}
{pstd}{helpb teffects} for treatment effects estimation{p_end}
{pstd}{helpb margins} for marginal effects and predictions{p_end}
{pstd}{helpb collect} for the underlying collection framework{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.1{p_end}

{hline}
