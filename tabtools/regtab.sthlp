{smcl}
{* *! version 1.0.14  05may2026}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{viewerjumpto "Package overview" "regtab##package"}{...}
{viewerjumpto "Syntax" "regtab##syntax"}{...}
{viewerjumpto "Description" "regtab##description"}{...}
{viewerjumpto "Options" "regtab##options"}{...}
{viewerjumpto "Remarks" "regtab##remarks"}{...}
{viewerjumpto "Examples" "regtab##examples"}{...}
{viewerjumpto "Stored results" "regtab##stored"}{...}
{viewerjumpto "Also see" "regtab##seealso"}{...}
{viewerjumpto "Author" "regtab##author"}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:regtab} {hline 2}}Format collected regression results for publication-ready Excel tables{p_end}
{p2colreset}{...}


{marker package}{...}
{title:Package}

{pstd}
{cmd:regtab} is part of the {helpb tabtools} suite. See also {helpb effecttab}
for treatment effects and margins tables.

{hline}


{title:regtab}

{pstd}Format {helpb collect}ed regression results into a polished Excel table.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:regtab}, [{opt xlsx(filename)} {opt excel(filename)} {opt sheet(string)} {opt sep(string asis)} {opt models(string)} {opt coef(string)} {opt title(string)} {opt noint:ercept} {opt keepi:ntercept} {opt nore:effects} {opt stats(string)} {opt relab:el} {opt digits(#)} {opt foot:note(string)} {opt open} {opt zebra} {opt headers:hade} {opt high:light(#)} {opt bold:p(#)} {opt border:style(string)} {opt the:me(string)} {opt headerc:olor(string)} {opt zebrac:olor(string)} {opt csv(string)} {opt fra:me(name)} {opt dis:play} {opt keep(varlist)} {opt drop(varlist)} {opt dimnon:sig} {opt factorl:abel} {opt ref:cat(string)} {opt comp:act} {opt stars} {cmdab:starsl:evels(}{it:numlist}{cmd:)} {cmdab:addr:ow(}{it:string asis}{cmd:)} {opt pdp(#)} {opt highpdp(#)} {opt cdisc}]{p_end}

{pstd}Required: an active {helpb collect} with items {cmd:_r_b}, {cmd:_r_ci}, and {cmd:_r_p} and dimensions including {cmd:colname} and {cmd:cmdset}.{p_end}

{marker description}{title:Description}

{pstd}{cmd:regtab} reads the current {helpb collect} table and writes a clean Excel sheet with, for each model (each {cmd:cmdset}), three columns: point estimate ({cmd:_r_b}), 95% CI ({cmd:_r_ci}), and p-value ({cmd:_r_p}). It applies labels and number formats, exports to a temporary workbook, re-imports to allow row edits (e.g., dropping intercept or random-effects rows), optionally merges model headers, writes to your target workbook/sheet, and styles borders, alignment, fonts, and column widths. Title text can be written to cell {cmd:A1}; the main table begins at {cmd:B2}.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(string)}}Output Excel filename (must end with {cmd:.xlsx}). If the file exists, only the named sheet is replaced. {opt excel()} is accepted as a synonym. If omitted, results are displayed in the console only.{p_end}
{synopt:{opt sheet(string)}}Target sheet name to create/replace in {opt xlsx()}. Default is {cmd:"Regression"}.{p_end}
{synopt:{opt sep(string asis)}}Delimiter between CI endpoints used by {cmd:collect} {cmd:cidelimiter()}. Default is {cmd:", "}.{p_end}
{synopt:{opt models(string)}}Labels to merge above each model's three columns. Separate labels with a backslash, e.g., {cmd:"Model 1 \ Model 2"}. If omitted, {cmd:regtab} auto-generates {cmd:Model} or {cmd:Model 1}, {cmd:Model 2}, ...{p_end}
{synopt:{opt coef(string)}}Header label for the point estimate column. If omitted, {cmd:regtab} auto-detects the display scale separately for each collected model from the collected command metadata: {cmd:logit}/{cmd:logistic}{it:->}OR, {cmd:stcox}{it:->}HR, {cmd:poisson}/{cmd:nbreg}{it:->}IRR, {cmd:stcrreg}{it:->}SHR, {cmd:streg}{it:->}TR/AF, {cmd:regress}/{cmd:mixed}{it:->}Coef. For coefficient-scale fits such as {cmd:logit} or {cmd:poisson}, fixed-effect rows are exponentiated for display when the auto header implies OR/IRR output. Mixed-scale collections use per-model headers unless you set {opt coef()} explicitly.{p_end}
{synopt:{opt title(string)}}Text written into {cmd:A1} and merged across the table width. If omitted, the title row is left blank.{p_end}
{synopt:{opt noint:ercept}}Drop the intercept row. Auto-enabled when all collected models are on a ratio scale (OR/HR/IRR/SHR/TR/AF); use {opt keepintercept} to override.{p_end}
{synopt:{opt keepi:ntercept}}Force display of intercept row even for exponentiated models.{p_end}
{synopt:{opt nore:effects}}Drop all random-effects rows: variance components ({cmd:var(}...{cmd:)}), covariances ({cmd:cov(}...{cmd:)}), and standard deviations ({cmd:sd(}...{cmd:)}).{p_end}
{synopt:{opt stats(string)}}Model fit statistics at bottom. Space-separated: {cmd:n}, {cmd:aic}, {cmd:bic}, {cmd:qic}, {cmd:icc}, {cmd:ll}, {cmd:groups}, {cmd:r2} (R²/pseudo-R²). For GEE models ({cmd:xtgee}), {cmd:aic} automatically displays QIC (Quasi-likelihood Information Criterion) since AIC is undefined for quasi-likelihood. {cmd:qic} can also be requested explicitly. For mixed regular and pseudo-R² collections, the row label becomes {cmd:R² / Pseudo R²}. {cmd:icc} is computed per model from variance components when defined.{p_end}
{synopt:{opt digits(#)}}Number of decimal places for coefficients and CIs (default 2, range 0-6). Random-effects rows use the same display precision as the main coefficient columns; MOR/MHR rows follow the transformed scale.{p_end}
{synopt:{opt foot:note(string)}}Add a footnote row below the table in smaller italic font.{p_end}
{synopt:{opt open}}Open the Excel file in the default application after export. Requires {opt xlsx()} or {opt excel()}.{p_end}
{synopt:{opt zebra}}Apply alternating light gray row shading for readability.{p_end}
{synopt:{opt high:light(#)}}Apply yellow fill to rows where p-value < threshold (e.g., {cmd:highlight(0.05)}).{p_end}
{synopt:{opt bold:p(#)}}Bold p-value cells below threshold (e.g., {cmd:boldp(0.05)}).{p_end}
{synopt:{opt headers:hade}}Apply background fill to the header row.{p_end}
{synopt:{opt border:style(string)}}Border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}.{p_end}
{synopt:{opt cdisc}}CDISC formatting mode: sets digits to 4, coef label to "Estimate", and forces {cmd:stats(n)}.{p_end}
{synopt:{opt relab:el}}Relabel random effects using variable labels. For single-level models, {cmd:var(_cons)} becomes {it:GroupLabel} {cmd:(Intercept)}. For multi-level models ({cmd:mixed ... || district: || school:}), each level is labeled separately: {it:District} {cmd:(Intercept)}, {it:School} {cmd:(Intercept)}, etc.{p_end}
{synopt:{opt stars}}Add significance stars to coefficients (*, **, ***).{p_end}
{synopt:{cmdab:starsl:evels(}{it:numlist}{cmd:)}}Custom p-value thresholds for stars; exactly 3 values (default: 0.05 0.01 0.001).{p_end}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}Formatting theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}.{p_end}
{synopt:{cmdab:headerc:olor(}{it:string}{cmd:)}}Custom header color as a named Excel color or RGB triplet (default: {cmd:"219 229 241"}).{p_end}
{synopt:{cmdab:zebrac:olor(}{it:string}{cmd:)}}Custom zebra color as a named Excel color or RGB triplet (default: {cmd:"237 242 249"}).{p_end}
{synopt:{opt csv("filename")}}Also export as CSV.{p_end}
{synopt:{opt fra:me(name)}}Store output in a named Stata frame for programmatic access. Specify {cmd:frame(name, replace)} to replace an existing frame.{p_end}
{synopt:{opt dis:play}}Show formatted table in the Results window (in addition to Excel export if {cmd:xlsx()} specified).{p_end}
{synopt:{opt keep(varlist)}}Show only rows matching specified variable names. Cannot be combined with {cmd:drop()}.{p_end}
{synopt:{opt drop(varlist)}}Drop rows matching specified variable names. Cannot be combined with {cmd:keep()}.{p_end}
{synopt:{opt dimnon:sig}}Gray out non-significant rows. Rows where every displayed fixed-effect confidence interval includes the null value (1 for OR/HR/IRR/SHR/TR, 0 for Coef.) are dimmed. Reference category rows are always dimmed. Category headers are dimmed unless at least one level is significant.{p_end}
{synopt:{opt factorl:abel}}Replace factor variable prefixes (e.g., {it:3.rep78}) with their value labels.{p_end}
{synopt:{opt ref:cat(string)}}Label for reference category rows. Default is {cmd:"Reference"}. Set to customize, e.g., {cmd:refcat("Ref.")}.{p_end}
{synopt:{opt comp:act}}Merge estimate and CI into a single column per model, producing a more compact layout: ({it:Est (CI)} | {it:p}) instead of ({it:Est} | {it:CI} | {it:p}).{p_end}
{synopt:{cmdab:addr:ow(}{it:string asis}{cmd:)}}Append custom rows below the table body. Specify pairs of label and values. Use backslash to separate multiple rows: {cmd:addrow("P trend" 0.032 0.041 \ "P interaction" 0.15 0.22)}.{p_end}
{synopt:{opt pdp(#)}}Maximum decimal places for small p-values (p < 0.10). Default is 3; allowed range is 1 to 10.{p_end}
{synopt:{opt highpdp(#)}}Maximum decimal places for large p-values (p >= 0.10). Default is 2; allowed range is 1 to 10.{p_end}
{synoptline}

{pstd}{bf:Automatic Median Odds Ratio / Median Hazard Ratio}{p_end}

{pstd}When the model type is {cmd:melogit}, {cmd:regtab} automatically converts the
random intercept variance to a {bf:Median Odds Ratio (MOR)} using the formula
MOR = exp(sqrt(2 * {it:sigma}^2) * invnormal(0.75)). For {cmd:mestreg} and
{cmd:mecloglog}, the conversion produces a {bf:Median Hazard Ratio (MHR)}.
The 95% CI bounds are transformed on the same scale. In multi-level models,
each transformed random-intercept row keeps its own grouping label, so the
output reads, for example, "Median Odds Ratio (District)" and
"Median Odds Ratio (School)". MOR/MHR values are formatted with 2
decimal places. Other random effects (slopes, covariances, residual) remain
as variance components with 4 decimal places. Use {opt nore} to suppress all
random-effects rows if desired.{p_end}

{marker remarks}{title:Remarks}

{pstd}Prerequisites and expectations{p_end}
{p 4 8 2}- Run your models inside {cmd:collect:} or otherwise ensure the relevant results are in the active {helpb collect}. {cmd:regtab} does not run models.{p_end}
{p 4 8 2}- {cmd:regtab} expects dimensions including {cmd:colname} and {cmd:cmdset}, and result items {cmd:_r_b}, {cmd:_r_ci}, {cmd:_r_p}. It applies cell styles: {cmd:_r_b} as %4.2fc, {cmd:_r_ci} as {cmd:sformat("(%s")} with {cmd:cidelimiter()}, and {cmd:_r_p} as %5.4f.{p_end}
{p 4 8 2}- Because {cmd:regtab} works through the active {cmd:collect}, it intentionally updates collect labels, styles, and layout before export. If you need the original collection layout unchanged for later commands, save or rebuild that collection before running {cmd:regtab}.{p_end}
{p 4 8 2}- The CI delimiter is controlled by {opt sep()}; default {cmd:", "}. Example alternative: {cmd:sep("; ")}.{p_end}
{p 4 8 2}- If {opt coef()} is not provided, {cmd:regtab} detects the display scale per collected model from the collected command metadata and fills the estimate header automatically. When models use different scales, estimate headers are set per model and {cmd:r(coef_label)} returns {cmd:mixed}.{p_end}
{p 4 8 2}- Model header labels are auto-generated unless {opt models()} supplies explicit names. {opt models()} values are split on the backslash character.{p_end}

{pstd}Notes on output shaping{p_end}
{p 4 8 2}- Baseline/reference rows: if a point estimate is 0 or 1 and the adjacent CI cell is empty, {cmd:regtab} substitutes {it:Reference} in the estimate column.{p_end}
{p 4 8 2}- Random-effects variance components ({cmd:var()}, {cmd:cov()}, {cmd:sd()}) from {cmd:mixed}, {cmd:melogit}, {cmd:mepoisson}, and similar commands use the same {opt digits()} precision as the main coefficient rows. Random-effects rows can be removed entirely with {opt nore}.{p_end}
{p 4 8 2}- Intercept rows can be removed with {opt noint}.{p_end}
{p 4 8 2}- By default, fonts are set to Arial 10, but this can be overridden by {opt theme()}, session defaults set with {helpb tabtools:set font} / {helpb tabtools:set fontsize}, or both. Borders are drawn around the table and model blocks. Column widths and row heights are adjusted heuristically to fit labels and contents.{p_end}
{p 4 8 2}- The command writes the Excel output using {helpb export excel} and applies formatting via the Mata {cmd:xl()} class.{p_end}
{p 4 8 2}- Model statistics ({opt stats()}): For multi-model tables, N, AIC, BIC, QIC, log-likelihood, and groups are extracted per model from the {helpb collect} framework and placed in each model's column. If extraction fails, statistics fall back to the last model's {cmd:e()} values in the first column only. For GEE models ({cmd:xtgee}), AIC is undefined because GEE uses quasi-likelihood rather than full maximum likelihood; when {cmd:aic} is requested, {cmd:regtab} automatically computes and displays QIC (deviance + 2p) instead. QIC can also be requested directly via {cmd:stats(qic)}. ICC is computed per model from variance components in the collected results when that variance decomposition is defined. For model families without a closed-form level-1 variance, ICC is left blank rather than guessed. If the primary collection path cannot recover supported ICC components, {cmd:regtab} falls back to the last model's {cmd:e(b)} matrix.{p_end}

{marker examples}{title:Examples}

{pstd}Logistic regression with odds ratios:{p_end}
{phang2}{stata "webuse nhanes2, clear":. webuse nhanes2, clear}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: logit diabetes age female i.race bmi highbp":. collect: logit diabetes age female i.race bmi highbp}{p_end}
{phang2}{stata `"regtab, xlsx(regression.xlsx) sheet("Diabetes") title("Odds Ratios for Diabetes") coef(OR)"':. regtab, xlsx(regression.xlsx) sheet("Diabetes") ///}{p_end}
{phang3}{cmd:title("Odds Ratios for Diabetes") coef(OR)}{p_end}

{pstd}Two models with merged headers, dropping the intercept row:{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: logit diabetes age female":. collect: logit diabetes age female}{p_end}
{phang2}{stata "collect: logit diabetes age female i.race bmi highbp":. collect: logit diabetes age female i.race bmi highbp}{p_end}
{phang2}{stata `"regtab, xlsx(regression.xlsx) sheet("Table 2") models("Unadj \ Adj") coef("OR") title("Table 2. Odds ratios") noint"':. regtab, xlsx(regression.xlsx) sheet("Table 2") ///}{p_end}
{phang3}{cmd:models("Unadj \ Adj") coef("OR") title("Table 2. Odds ratios") noint}{p_end}

{pstd}Mixed-effects logistic model with Median Odds Ratio and ICC:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: melogit outcome treated age female || provider:}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet("Mixed") title("Multilevel Model") ///}{p_end}
{phang3}{cmd:relabel stats(n icc groups)}{p_end}

{pstd}
This produces a table where the random intercept variance is automatically
converted to a Median Odds Ratio (MOR), {opt relabel} translates
{cmd:var(_cons[provider])} into a readable label using the variable label of
{cmd:provider}, and {opt stats()} appends N, ICC, and number of groups at the
bottom.{p_end}

{pstd}Multi-level linear mixed model with nested random effects:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: mixed outcome treatment age || district: || school:}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet("Nested") title("Table 3") relabel stats(n icc)}{p_end}

{pstd}
With {opt relabel}, each grouping level gets a separate label derived from
its variable label: {it:District (Intercept)}, {it:School (Intercept)},
{it:Residual Variance}. Without {opt relabel}, the raw bracket notation is
shown: {cmd:var(_cons[district])}, {cmd:var(_cons[school])}, {cmd:var(e)}.
Random effects are sorted by level (outermost first) after fixed effects.
Models with random slopes and covariance terms (e.g.,
{cmd:|| school: treatment, cov(unstructured)}) produce additional rows such
as {it:School (Treatment)} and {it:School (Treatment, Intercept)}.{p_end}

{pstd}Auto-detected coefficient labels and conditional formatting:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: stcox treated age female i.education}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet("Cox") title("Cox Model") ///}{p_end}
{phang3}{cmd:noint boldp(0.05) highlight(0.05)}{p_end}

{pstd}
When {opt coef()} is omitted, {cmd:regtab} auto-detects the label from the
model type: {cmd:logit}/{cmd:logistic} {it:->} OR, {cmd:stcox} {it:->} HR,
{cmd:poisson}/{cmd:nbreg} {it:->} IRR, {cmd:stcrreg} {it:->} SHR,
{cmd:streg} (time) {it:->} TR, {cmd:streg} (log-time) {it:->} AF,
{cmd:regress}/{cmd:mixed} {it:->} Coef.
The {opt boldp()} option bolds p-value cells below
the threshold, and {opt highlight()} applies yellow fill to entire rows.{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:regtab} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in output table{p_end}
{synopt:{cmd:r(N_cols)}}number of columns in output table{p_end}
{synopt:{cmd:r(N_models)}}number of models{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(coef_label)}}shared coefficient label, or {cmd:mixed} when auto headers differ by model{p_end}
{synopt:{cmd:r(methods)}}auto-generated methods paragraph{p_end}
{synopt:{cmd:r(stars)}}stars option value{p_end}
{synopt:{cmd:r(frame)}}frame name (if {cmd:frame()} specified){p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}coefficient values matrix for the displayed coefficient body (rows = variables, columns = models; excludes title and appended stats/addrows){p_end}

{marker seealso}{...}
{title:Also see}

{pstd}{helpb effecttab} for treatment effects and margins tables{p_end}
{pstd}{helpb tabtools} for suite overview and persistent formatting defaults{p_end}
{pstd}{helpb collect} for the underlying collection framework{p_end}
{pstd}{helpb tabtools_cheatsheet} for quick reference{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.0.14{p_end}

{hline}
