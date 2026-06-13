{smcl}
{* *! version 1.7.0  13jun2026}{...}
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

{p 4 8 2}{cmd:regtab}, [{opt xlsx(filename)} {opt excel(filename)} {opt sheet(string)} {opt sep(string asis)} {opt models(string)} {opt coef(string)} {opt title(string)} {opt noint:ercept} {opt keepi:ntercept} {opt nore:effects} {opt stats(string)} {opt relab:el} {opt digits(#)} {opt foot:note(string)} {opt open} {opt zebra} {opt headers:hade} {opt high:light(#)} {opt bold:p(#)} {opt border:style(string)} {opt the:me(string)} {opt headerc:olor(string)} {opt zebrac:olor(string)} {opt csv(string)} {opt markdown(filename)} {opt mdappend} {opt fra:me(name)} {opt eplotf:rame(name[, replace])} {opt dis:play} {opt keep(varlist)} {opt drop(varlist)} {opt dimnon:sig} {opt factorl:abel} {opt ref:cat(string)} {opt cutl:abels(string)} {opt comp:act} {opt nop:value} {opt stars} {opt starsl:evels(numlist)} {opt addr:ow(string asis)} {opt pdp(#)} {opt highpdp(#)} {opt cdisc} {opt labelw:idth(#)}]{p_end}

{pstd}Required: an active {helpb collect} with items {cmd:_r_b}, {cmd:_r_ci}, and {cmd:_r_p} and dimensions including {cmd:colname} and {cmd:cmdset}.{p_end}

{marker description}{title:Description}

{pstd}{cmd:regtab} reads the current {helpb collect} table and writes a clean Excel sheet with, for each model (each {cmd:cmdset}), columns for the point estimate ({cmd:_r_b}), 95% CI ({cmd:_r_ci}), and p-value ({cmd:_r_p}). Use {opt nopvalue} to suppress the p-value column in the rendered output. It applies labels and number formats, exports to a temporary workbook, re-imports to allow row edits (e.g., dropping intercept or random-effects rows), optionally merges model headers, writes to your target workbook/sheet, and styles borders, alignment, fonts, and column widths. Title text can be written to cell {cmd:A1}; the main table begins at {cmd:B2}.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(string)}}Output Excel filename (must end with {cmd:.xlsx}); {opt excel()} is a synonym.{p_end}
{synopt:{opt sheet(string)}}Target sheet to create/replace in {opt xlsx()}. Default {cmd:"Regression"}.{p_end}
{synopt:{opt sep(string asis)}}CI-endpoint delimiter for {cmd:collect}. Default {cmd:", "}.{p_end}
{synopt:{opt models(string)}}Labels merged above each model's columns, backslash-separated; auto-generated if omitted.{p_end}
{synopt:{opt coef(string)}}Header for the estimate column; auto-detected per model scale if omitted (see Remarks).{p_end}
{synopt:{opt title(string)}}Title written to {cmd:A1}, merged across the table; blank if omitted.{p_end}
{synopt:{opt noint:ercept}}Drop intercept, cutpoint, and ancillary rows; auto-enabled for all-ratio-scale models.{p_end}
{synopt:{opt keepi:ntercept}}Force display of the intercept row even for exponentiated models.{p_end}
{synopt:{opt nore:effects}}Drop all random-effects rows (variances, covariances, SDs).{p_end}
{synopt:{opt stats(string)}}Model-fit statistics row: {cmd:n}, {cmd:aic}, {cmd:bic}, {cmd:qic}, {cmd:icc}, {cmd:ll}, {cmd:groups}, {cmd:r2} (see Remarks).{p_end}
{synopt:{opt digits(#)}}Decimal places for coefficients and CIs (default 2, range 0-6).{p_end}
{synopt:{opt labelw:idth(#)}}Maximum width of the label column in characters (default 45); longer labels wrap.{p_end}
{synopt:{opt foot:note(string)}}Add a footnote row below the table in smaller italic font.{p_end}
{synopt:{opt open}}Open the Excel file after export; requires {opt xlsx()} or {opt excel()}.{p_end}
{synopt:{opt zebra}}Apply alternating light gray row shading.{p_end}
{synopt:{opt high:light(#)}}Yellow fill for rows where p-value < #.{p_end}
{synopt:{opt bold:p(#)}}Bold p-value cells below #.{p_end}
{synopt:{opt headers:hade}}Apply background fill to the header row.{p_end}
{synopt:{opt border:style(string)}}Border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic} (default {cmd:thin}).{p_end}
{synopt:{opt cdisc}}CDISC mode: digits 4, coef label "Estimate", forces {cmd:stats(n)}.{p_end}
{synopt:{opt relab:el}}Relabel random effects using variable labels and parameter types (see Remarks).{p_end}
{synopt:{opt stars}}Add significance stars to coefficients (*, **, ***).{p_end}
{synopt:{opt starsl:evels(numlist)}}Custom p-value thresholds for stars; exactly 3 values (default 0.05 0.01 0.001).{p_end}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}Formatting theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}.{p_end}
{synopt:{cmdab:headerc:olor(}{it:string}{cmd:)}}Custom header color (Stata color name or RGB triplet; default {cmd:"219 229 241"}).{p_end}
{synopt:{cmdab:zebrac:olor(}{it:string}{cmd:)}}Custom zebra color (Stata color name or RGB triplet; default {cmd:"237 242 249"}).{p_end}
{synopt:{opt csv("filename")} {opt markdown(filename)} {opt mdappend}}Also export as CSV.{p_end}
{synopt:{opt markdown(filename)}}Export the table as GitHub-Flavored Markdown.{p_end}
{synopt:{opt mdappend}}Append the Markdown table to an existing file; requires {opt markdown()}.{p_end}
{synopt:{opt fra:me(name)}}Store output in a named frame; {cmd:frame(name, replace)} replaces an existing frame.{p_end}
{synopt:{opt eplotf:rame(name[, replace])}}Store a graph-ready companion frame for {helpb eplot} (see Remarks).{p_end}
{synopt:{opt dis:play}}Accepted for compatibility; the table is displayed automatically.{p_end}
{synopt:{opt keep(varlist)}}Show only rows matching these variable names; not with {opt drop()}.{p_end}
{synopt:{opt drop(varlist)}}Drop rows matching these variable names; not with {opt keep()}.{p_end}
{synopt:{opt dimnon:sig}}Gray out non-significant rows (see Remarks).{p_end}
{synopt:{opt factorl:abel}}Replace factor-variable prefixes (e.g., {it:3.rep78}) with value labels.{p_end}
{synopt:{opt ref:cat(string)}}Label for reference-category rows. Default {cmd:"Reference"}.{p_end}
{synopt:{opt cutl:abels(string)}}Custom labels for ordered-model cutpoint rows, backslash-separated.{p_end}
{synopt:{opt comp:act}}Merge estimate and CI into one column per model.{p_end}
{synopt:{opt nop:value}}Suppress p-value columns; stars and highlighting still use p-values internally.{p_end}
{synopt:{opt addr:ow(string asis)}}Append custom label/value rows below the table (see Remarks for syntax).{p_end}
{synopt:{opt pdp(#)}}Max decimal places for small p-values (p < 0.10); default 3.{p_end}
{synopt:{opt highpdp(#)}}Max decimal places for large p-values (p >= 0.10); default 2.{p_end}
{synoptline}

{pstd}{bf:Automatic Median Odds Ratio / Median Hazard Ratio}{p_end}

{pstd}When the model type is {cmd:melogit}, {cmd:regtab} automatically converts the
random intercept variance to a {bf:Median Odds Ratio (MOR)} using the formula
MOR = exp(sqrt(2 * {it:sigma}^2) * invnormal(0.75)). For {cmd:mestreg} and
{cmd:mecloglog}, the conversion produces a {bf:Median Hazard Ratio (MHR)}.
The 95% CI bounds are transformed on the same scale. In multi-level models,
each transformed random-intercept row keeps its own grouping label, so the
output reads, for example, "Median Odds Ratio (District)" and
"Median Odds Ratio (School)". MOR/MHR values and other random effects
(slopes, covariances, residual) follow the requested {opt digits()} precision.
Use {opt nore} to suppress all
random-effects rows if desired.{p_end}

{marker remarks}{title:Remarks}

{pstd}Prerequisites and expectations{p_end}
{p 4 8 2}- Run your models inside {cmd:collect:} or otherwise ensure the relevant results are in the active {helpb collect}. {cmd:regtab} does not run models.{p_end}
{p 4 8 2}- {cmd:regtab} expects dimensions including {cmd:colname} and {cmd:cmdset}, and result items {cmd:_r_b}, {cmd:_r_ci}, {cmd:_r_p}. It applies cell styles: {cmd:_r_b} as %4.2fc, {cmd:_r_ci} as {cmd:sformat("(%s")} with {cmd:cidelimiter()}, and {cmd:_r_p} as %5.4f.{p_end}
{p 4 8 2}- Because {cmd:regtab} works through the active {cmd:collect}, it intentionally updates collect labels, styles, and layout before export. If you need the original collection layout unchanged for later commands, save or rebuild that collection before running {cmd:regtab}.{p_end}
{p 4 8 2}- The CI delimiter is controlled by {opt sep()}; default {cmd:", "}. Example alternative: {cmd:sep("; ")}.{p_end}
{p 4 8 2}- If {opt coef()} is not provided, {cmd:regtab} detects the display scale per collected model from the collected command metadata and fills the estimate header automatically. When models use different scales, estimate headers are set per model and {cmd:r(coef_label)} returns {cmd:mixed}.{p_end}
{p 4 8 2}- Multi-equation models such as {cmd:mlogit}, {cmd:zip}, {cmd:zinb}, and {cmd:churdle} use the equation/outcome dimension in the row labels, so rows read like {it:Partial response: Age z-score} or {it:Inflation equation: Prior events} instead of collapsing repeated covariate names across equations. For labeled multinomial outcomes, value labels are used when available. {cmd:mlogit} is displayed as relative risk ratios (RRR) by default; zero-inflated and hurdle models remain on their native coefficient scale unless {opt coef()} and collection styling are supplied by the user.{p_end}
{p 4 8 2}- Model header labels are auto-generated unless {opt models()} supplies explicit names. {opt models()} values are split on the backslash character.{p_end}
{p 4 8 2}- {opt coef()}: if omitted, the estimate-column header and scale are auto-detected per collected model: {cmd:logit}/{cmd:logistic} {it:->} OR, {cmd:mlogit} {it:->} RRR, {cmd:stcox} {it:->} HR, {cmd:poisson}/{cmd:nbreg} {it:->} IRR, {cmd:stcrreg} {it:->} SHR, {cmd:streg} {it:->} TR/AF, {cmd:regress}/{cmd:mixed} {it:->} Coef. Coefficient-scale fits are exponentiated for display when the auto header implies a ratio scale.{p_end}
{p 4 8 2}- {opt relabel}: relabels random effects using variable labels and explicit parameter types. For single-level models {cmd:var(_cons)} becomes {it:Variance: GroupLabel (Intercept)} and {cmd:cov(x,_cons)} becomes {it:Covariance: GroupLabel (X label, Intercept)}; multi-level models label each level separately.{p_end}
{p 4 8 2}- {opt eplotframe()}: stores a graph-ready companion frame for {helpb eplot} containing {cmd:label}, {cmd:estimate}, {cmd:ll}, {cmd:ul}, {cmd:pvalue}, {cmd:model}, {cmd:model_label}, {cmd:rowtype}, and source-row metadata. When {opt frame()} is also set, the display frame records the companion in {cmd:_dta[tabtools_eplotframe]}.{p_end}
{p 4 8 2}- {opt addrow()}: appends custom label/value rows below the table body; separate multiple rows with a backslash, e.g., {cmd:addrow("P trend" 0.032 0.041 \ "P interaction" 0.15 0.22)}.{p_end}
{p 4 8 2}- {opt labelwidth()}: caps the label-column width (in characters, default 45); labels longer than the cap wrap onto extra lines rather than being clipped by the adjacent estimate cell.{p_end}
{p 4 8 2}- {opt dimnonsig}: dims rows whose every displayed fixed-effect CI includes the null (1 for ratio scales, 0 for coefficients); reference rows are always dimmed and category headers dim unless a level is significant.{p_end}

{pstd}Notes on output shaping{p_end}
{p 4 8 2}- Baseline/reference rows: if a point estimate is 0 or 1 and the adjacent CI cell is empty, {cmd:regtab} substitutes {it:Reference} in the estimate column.{p_end}
{p 4 8 2}- Random-effects variance components ({cmd:var()}, {cmd:cov()}, {cmd:sd()}) from {cmd:mixed}, {cmd:melogit}, {cmd:mepoisson}, and similar commands use the same {opt digits()} precision as the main coefficient rows. Random-effects rows can be removed entirely with {opt nore}.{p_end}
{p 4 8 2}- Intercept, ordered cutpoint, and ancillary-only rows can be removed with {opt noint}. Use {opt keepintercept} plus {opt cutlabels()} if you intentionally want ordered-model cutpoints displayed with publication-friendly labels.{p_end}
{p 4 8 2}- P-value columns can be removed from the rendered table with {opt nopvalue}. If {opt stars} is also specified, significance stars are still computed from the collected p-values before the p-value columns are dropped.{p_end}
{p 4 8 2}- By default, fonts are set to Arial 10, but this can be overridden by {opt theme()}, session defaults set with {helpb tabtools:set font} / {helpb tabtools:set fontsize}, or both. Borders are drawn around the table and model blocks. Column widths and row heights are adjusted heuristically to fit labels and contents.{p_end}
{p 4 8 2}- The command writes Excel and Markdown output through the shared tabtools Mata {cmd:xl()} backend and then applies formatting in the same workbook session.{p_end}
{p 4 8 2}- Model statistics ({opt stats()}): For multi-model tables, N, AIC, BIC, QIC, log-likelihood, and groups are extracted per model from the {helpb collect} framework and placed in each model's column. If extraction fails, statistics fall back to the last model's {cmd:e()} values in the first column only. For GEE models ({cmd:xtgee}), AIC is undefined because GEE uses quasi-likelihood rather than full maximum likelihood; when {cmd:aic} is requested, {cmd:regtab} automatically computes and displays QIC (deviance + 2p) instead. QIC can also be requested directly via {cmd:stats(qic)}. ICC is computed per model from variance components in the collected results when that variance decomposition is defined. For model families without a closed-form level-1 variance, ICC is left blank rather than guessed. If the primary collection path cannot recover supported ICC components, {cmd:regtab} falls back to the last model's {cmd:e(b)} matrix.{p_end}

{marker examples}{title:Examples}

{pstd}Logistic regression with odds ratios:{p_end}
{phang2}{stata "webuse nhanes2, clear":. webuse nhanes2, clear}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: logit diabetes age female i.race bmi highbp":. collect: logit diabetes age female i.race bmi highbp}{p_end}
{phang2}{stata `"regtab, xlsx(regression.xlsx) sheet("Diabetes") title("Odds Ratios for Diabetes") coef(OR)"':. regtab, xlsx(regression.xlsx) sheet("Diabetes") ///}{p_end}
{phang3}{cmd:title("Odds Ratios for Diabetes") coef(OR)}{p_end}

{pstd}Multinomial logistic regression with outcome-specific RRR rows:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. xtile price_group = price, nq(3)}{p_end}
{phang2}{cmd:. label define price_group 1 "Low price" 2 "Middle price" 3 "High price"}{p_end}
{phang2}{cmd:. label values price_group price_group}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: mlogit price_group mpg weight, baseoutcome(1)}{p_end}
{phang2}{cmd:. regtab, xlsx(regression.xlsx) sheet("Multinomial") title("Price group model")}{p_end}

{pstd}
Rows are labeled by outcome and term (for example, {it:Middle price: Mileage (mpg)}),
and the estimate header is auto-detected as {cmd:RRR}.{p_end}

{pstd}Ordered logit with custom cutpoint labels:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. keep if !missing(rep78)}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: ologit rep78 mpg weight}{p_end}
{phang2}{cmd:. regtab, xlsx(regression.xlsx) sheet("Ordered") keepintercept ///}{p_end}
{phang3}{cmd:cutlabels("1 to 2 \ 2 to 3 \ 3 to 4 \ 4 to 5")}{p_end}

{pstd}
The number of labels may match however many cutpoints the ordered model returns.
Without {opt keepintercept}, {cmd:regtab} treats cutpoints like ancillary rows and
omits them from ratio-scale presentation tables.{p_end}

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
its variable label and the parameter type: {it:Variance: District (Intercept)},
{it:Variance: School (Intercept)}, {it:Residual Variance}. Without {opt relabel}, the raw bracket notation is
shown: {cmd:var(_cons[district])}, {cmd:var(_cons[school])}, {cmd:var(e)}.
Random effects are sorted by level (outermost first) after fixed effects.
Models with random slopes and covariance terms (e.g.,
{cmd:|| school: treatment, cov(unstructured)}) produce additional rows such
as {it:Variance: School (Treatment)} and
{it:Covariance: School (Treatment, Intercept)}.{p_end}

{pstd}Auto-detected coefficient labels and conditional formatting:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: stcox treated age female i.education}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet("Cox") title("Cox Model") ///}{p_end}
{phang3}{cmd:noint boldp(0.05) highlight(0.05)}{p_end}

{pstd}
When {opt coef()} is omitted, {cmd:regtab} auto-detects the label from the
model type: {cmd:logit}/{cmd:logistic} {it:->} OR, {cmd:stcox} {it:->} HR,
{cmd:poisson}/{cmd:nbreg} {it:->} IRR, {cmd:stcrreg} {it:->} SHR,
{cmd:mlogit} {it:->} RRR,
{cmd:zip}/{cmd:zinb}/{cmd:churdle} {it:->} Coef.,
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
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(coef_label)}}shared coefficient label, or {cmd:mixed} when auto headers differ by model{p_end}
{synopt:{cmd:r(methods)}}auto-generated methods paragraph{p_end}
{synopt:{cmd:r(stars)}}stars option value{p_end}
{synopt:{cmd:r(frame)}}frame name (if {cmd:frame()} specified){p_end}
{synopt:{cmd:r(eplotframe)}}graph-ready companion frame name (if {cmd:eplotframe()} specified){p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}coefficient values for the displayed body (rows = variables, columns = models){p_end}
{p2colreset}{...}

{pstd}{cmd:r(table)} excludes the title and any appended stats/addrows. Row names are derived from each variable's display label with periods, spaces, commas, and colons replaced by underscores or stripped, then truncated to 32 characters.{p_end}

{marker seealso}{...}
{title:Also see}

{pstd}{helpb effecttab} for treatment effects and margins tables{p_end}
{pstd}{helpb tabtools} for suite overview and persistent formatting defaults{p_end}
{pstd}{helpb collect} for the underlying collection framework{p_end}
{pstd}{helpb tabtools_tips} for quick reference{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.7.0{p_end}

{hline}
