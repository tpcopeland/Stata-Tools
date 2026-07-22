{smcl}
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

{p 4 8 2}{cmd:effecttab}, [{opt xlsx(string)} {opt excel(string)}
{opt sheet(string)} {opt type(string)} {opt effect(string)}
{opt sep(string asis)} {opt models(string)} {opt title(string)} {opt clean}
{opt tlab:els(string asis)} {opt foot:note(string)} {opt open} {opt zebra}
{opt high:light(#)} {opt bold:p(#)} {opt border:style(string)}
{opt the:me(string)} {opt full} {opt digits(#)} {opt level(#)} {opt fra:me(name)}
{opt eplotf:rame(name[, replace])} {opt from(name)}
{opt headers:hade} {opt headerc:olor(string)} {opt zebrac:olor(string)}
{opt csv(string)} {opt markdown(filename)} {opt mdappend}
{opt addr:ow(string asis)} {opt ref:cat(string)} {opt pdp(#)} {opt highpdp(#)} {opt labelw:idth(#)}]{p_end}

{pstd}Required: either an active {helpb collect} containing results from {helpb teffects} or
{helpb margins}, or {opt from(name)} with a matrix of estimates, confidence limits, and
p-values.{p_end}

{marker description}{title:Description}

{pstd}{cmd:effecttab} formats treatment effects and margins output for publication-ready
Excel tables. It is designed for causal inference workflows including:{p_end}

{p 8 12 2}- Inverse probability weighting ({cmd:teffects ipw}){p_end}
{p 8 12 2}- Regression adjustment / G-computation ({cmd:teffects ra}, {cmd:margins}){p_end}
{p 8 12 2}- Doubly robust estimation ({cmd:teffects aipw}, {cmd:teffects ipwra}){p_end}
{p 8 12 2}- Propensity score matching ({cmd:teffects psmatch}){p_end}
{p 8 12 2}- Marginal effects and predicted probabilities ({cmd:margins}){p_end}

{pstd}{cmd:effecttab} reads either the current {helpb collect} table or a named matrix supplied
through {opt from(name)}, then writes an Excel sheet with columns for point
estimate, confidence interval, and p-value. It applies the same professional formatting as
{helpb regtab}.{p_end}

{pstd}When reading from {cmd:collect}, {cmd:effecttab} requires the active
collection to come from {cmd:teffects} or {cmd:margins}. Other collected
command types are rejected rather than being guessed as margins output.{p_end}

{pstd}The {cmd:collect} path intentionally updates active collection labels,
styles, and layout before export. The {opt from()} matrix path does not inspect
or relabel the active collection and is the safer path when the existing
collection must remain unchanged.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(string)}}output Excel filename (must end with .xlsx){p_end}
{synopt:{opt sheet(string)}}target sheet name to create/replace in xlsx(){p_end}
{synopt:{opt type(string)}}select the collected-results adapter{p_end}
{synopt:{opt effect(string)}}header for the effect column (e.g., ATE, RD, RR, AME){p_end}
{synopt:{opt sep(string asis)}}delimiter between CI endpoints. Default is {cmd:", "}{p_end}
{synopt:{opt models(string)}}labels for multiple models, separated by backslash{p_end}
{synopt:{opt title(string)}}set the table title in cell A1{p_end}
{synopt:{opt clean}}clean up teffects row labels{p_end}
{synopt:{opt tlab:els(string asis)}}explicit treatment-level label pairs{p_end}
{synopt:{opt foot:note(string)}}add italic footnote text{p_end}
{synopt:{opt open}}open the exported workbook{p_end}
{synopt:{opt zebra}}shade alternating rows{p_end}
{synopt:{opt high:light(#)}}apply yellow fill to rows where p-value < threshold{p_end}
{synopt:{opt bold:p(#)}}bold cells below a p threshold{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt full}}retain normally filtered rows{p_end}
{synopt:{opt digits(#)}}set decimals for effects and CIs{p_end}
{synopt:{opt level(#)}}set or verify the confidence level{p_end}
{synopt:{opt labelw:idth(#)}}cap the label-column width{p_end}
{synopt:{opt fra:me(name)}}store output in a named Stata frame{p_end}
{synopt:{opt eplotf:rame(name[, replace])}}save a graph-ready companion frame{p_end}
{synopt:{opt the:me(string)}}apply a journal formatting theme{p_end}
{synopt:{opt from(name)}}read results from a named matrix{p_end}
{synopt:{opt headers:hade}}apply background fill to the header row{p_end}
{synopt:{opt headerc:olor(string)}}set the header fill color{p_end}
{synopt:{opt zebrac:olor(string)}}set alternating-row fill color{p_end}
{synopt:{opt csv(filename)}}also export the table as a CSV file{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file{p_end}
{synopt:{opt addr:ow(string asis)}}append custom rows below the table body{p_end}
{synopt:{opt ref:cat(string)}}label for reference rows (default {cmd:Reference}){p_end}
{synopt:{opt pdp(#)}}maximum decimal places for small p-values (p < 0.10){p_end}
{synopt:{opt highpdp(#)}}maximum decimal places for large p-values (p >= 0.10){p_end}
{synoptline}


{pstd}
{it:Detailed option contracts}{p_end}

{phang}
{opt addr:ow(string asis)} append custom rows below the table body. Specify pairs of label and
values. Use backslash to separate multiple rows{p_end}

{phang}
{opt bold:p(#)} bold p-value cells below threshold (e.g., {cmd:boldp(0.05)}){p_end}

{phang}
{opt border:style(string)} border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}

{phang}
{opt clean} clean up teffects row labels; uses value labels when available (e.g.,
{cmd:"r1vs0.treated"} becomes {cmd:"SNRI vs SSRI"}), otherwise falls back to basic cleanup{p_end}

{phang}
{opt csv(filename)} also export the table as a CSV file. The CSV holds the table's data columns only; the
title and footnote, if set, are not written (they are included in {opt xlsx()} and {opt markdown()} output){p_end}

{phang}
{opt digits(#)} number of decimal places for effects and CIs (default 2, range 0-6){p_end}

{phang}
{opt effect(string)} header for the effect column (e.g., {cmd:ATE}, {cmd:RD}, {cmd:RR}, {cmd:AME}); default
"Effect"/"Estimate"{p_end}

{phang}
{opt eplotf:rame(name[, replace])} store a graph-ready companion frame for {helpb eplot} (see
Remarks){p_end}

{phang}
{opt foot:note(string)} add a footnote row below the table in smaller italic font{p_end}

{phang}
{opt fra:me(name)} store output in a named Stata frame. Specify {cmd:frame(name, replace)} to
replace an existing frame{p_end}

{phang}
{opt from(name)} read results from a named matrix instead of {cmd:collect} (see Remarks){p_end}

{phang}
{opt full} show all rows including those normally filtered (e.g., display all teffects rows, not
just ATE/POmean){p_end}

{phang}
{opt headerc:olor(string)} custom header background color as a supported Stata color name or RGB
triplet (e.g., {cmd:"219 229 241"}){p_end}

{phang}
{opt headers:hade} apply background fill to the header row{p_end}

{phang}
{opt high:light(#)} apply yellow fill to rows where p-value < threshold{p_end}

{phang}
{opt highpdp(#)} maximum decimal places for large p-values (p >= 0.10). Default is 2; allowed range
is 1 to 10{p_end}

{phang}
{opt labelw:idth(#)} maximum width of the label column in characters (default 45); longer labels
wrap{p_end}

{phang}
{opt level(#)} sets or verifies confidence-level provenance. With a collected
result, the active collection's stored level is used and an explicit value must
match it. Not every Stata version records the level in the collection: Stata 17
does, Stata 19 does not. When it is absent, {cmd:effecttab} requires
{opt level()} and exits with error 198 otherwise. It does {it:not} fall back to
the current {helpb set level}: that is the session setting at render time,
whereas the intervals were computed when the models ran, so assuming it can
label real 90% bounds as a 95% CI. State the level the collected models were
fit at. Matrix input has no interval metadata, so it uses 95 unless
{opt level()} is supplied. The resolved level labels intervals in headers and methods text, is
returned in {cmd:r(ci_level)}, and is stored on display and eplot frames; it
affects no computed quantity.{p_end}

{phang}
{opt markdown(filename)} export the rendered table as GitHub-Flavored Markdown; may be combined with
Excel, CSV, and frame exports{p_end}

{phang}
{opt mdappend} append the Markdown table to an existing file; requires {opt markdown()}{p_end}

{phang}
{opt models(string)} labels for multiple models, separated by backslash. Example: {cmd:"IPTW \ AIPW"}{p_end}

{phang}
{opt open} open the Excel file in the default application after export. Requires {opt xlsx()} or
{opt excel()}{p_end}

{phang}
{opt pdp(#)} maximum decimal places for small p-values (p < 0.10). Default is 3; allowed range is 1
to 10{p_end}

{phang}
{opt ref:cat(string)} label written into base-category (reference) rows. Default is {cmd:Reference}, matching
{helpb regtab}. Unlike {cmd:regtab}, which identifies reference rows from the structural base-level key of
the underlying model, {cmd:effecttab} reads {cmd:teffects}/{cmd:margins} output that carries no such key and
therefore flags a reference row heuristically: a point estimate that displays as exactly {cmd:0} at the current
{opt digits()} together with an empty confidence interval. A genuine effect that rounds to {cmd:0.00} with a
missing CI would be labeled with this string; such cases are rare in {cmd:teffects}/{cmd:margins} output but
can be avoided by increasing {opt digits()}{p_end}

{phang}
{opt sep(string asis)} delimiter between CI endpoints. Default is {cmd:", "}{p_end}

{phang}
{opt sheet(string)} target sheet name to create/replace in {opt xlsx()}. Default is {cmd:"Effects"}{p_end}

{phang}
{opt the:me(string)} formatting theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama},
{cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}. Overrides
font/fontsize/borderstyle. Can also be set globally with {cmd:tabtools set theme}{p_end}

{phang}
{opt title(string)} text written into cell {cmd:A1} and merged across the table width{p_end}

{phang}
{opt tlab:els(string asis)} explicit treatment-level label pairs; implies {cmd:clean}; for example, use
{cmd:tlabels(0 "SSRI" 1 "SNRI")}{p_end}

{phang}
{opt type(string)} collected results type: {cmd:teffects}, {cmd:margins}, or {cmd:auto} (default; see
Remarks){p_end}

{phang}
{opt xlsx(string)} output Excel filename (must end with {cmd:.xlsx}); {opt excel()} is a synonym{p_end}

{phang}
{opt zebra} apply alternating light gray row shading for readability{p_end}

{phang}
{opt zebrac:olor(string)} custom zebra stripe color as a supported Stata color name or RGB triplet
(e.g., {cmd:"237 242 249"}){p_end}

{marker remarks}{title:Remarks}

{pstd}{bf:Comparison with regtab}{p_end}

{p 4 8 2}Use {cmd:regtab} for standard regression output (logit, regress, stcox,
etc.) where you want to display coefficients/odds ratios for each covariate.{p_end}

{p 4 8 2}Use {cmd:effecttab} for causal inference results where you want to display treatment
effects (ATE, ATET), potential outcome means, marginal effects, or predicted
probabilities.{p_end}

{pstd}{bf:Working with teffects}{p_end}

{p 4 8 2}The {cmd:teffects} family of commands estimates treatment effects using
various methods. Use the {cmd:collect:} prefix to capture results:{p_end}

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (outcome) (treatment age sex), ate}{p_end}
{phang2}{cmd:. effecttab, xlsx(results.xlsx) sheet("ATE") effect("ATE")}{p_end}

{pstd}{bf:Working with margins}{p_end}

{p 4 8 2}The {cmd:margins} command computes marginal effects and predicted
probabilities. Standard {cmd:margins} collections can be collected directly:{p_end}

{p 4 8 2}Contrast-backed collections such as {cmd:collect: margins r.treatment}
are currently unsupported and are rejected by {cmd:effecttab}.{p_end}

{phang2}{cmd:. logit outcome i.treatment age sex}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins treatment}{p_end}
{phang2}{cmd:. effecttab, xlsx(results.xlsx) sheet("Predictions") type(margins) effect("Pr(Y)")}{p_end}

{pstd}{bf:The clean option and treatment labels}{p_end}

{p 4 8 2}When using {cmd:teffects}, the row labels contain technical notation like
{cmd:r1vs0.treatment}. The {cmd:clean} option reformats these using value labels
from the treatment variable when available:{p_end}

{p 8 12 2}- If {cmd:treatment} has value labels (0="SSRI", 1="SNRI"), the ATE row becomes
{cmd:"SNRI vs SSRI"} and PO Mean rows become {cmd:"SSRI (PO Mean)"}, {cmd:"SNRI (PO Mean)"}.{p_end}
{p 8 12 2}- If no value labels exist, falls back to basic cleanup: {cmd:"Treatment (1 vs 0)"}.{p_end}

{p 4 8 2}Use {cmd:tlabels()} to explicitly specify treatment level labels when value labels
are not defined or you want different wording. {cmd:tlabels()} implies {cmd:clean}.{p_end}

{pstd}{bf:Option details}{p_end}
{p 4 8 2}- {opt type()}: {cmd:auto} (default) inspects the active {cmd:collect}
metadata, not ambient {cmd:e()}. Unsupported collections are rejected, and one
collection cannot mix {cmd:teffects} and {cmd:margins}. With {opt from()},
{cmd:auto} uses margins-style defaults and does not relabel the active collection.{p_end}
{p 4 8 2}- {opt from()}: read results from a named matrix instead of {cmd:collect}; the matrix must
hold estimate, lower CI, upper CI, and p-value columns in that order. This
path leaves any active {cmd:collect} labels and layout unchanged.{p_end}
{p 4 8 2}- {opt eplotframe()}: stores a graph-ready companion frame for {helpb eplot} containing
{cmd:label}, {cmd:estimate}, {cmd:ll}, {cmd:ul}, {cmd:pvalue}, {cmd:model}, {cmd:model_label}, {cmd:rowtype}, and source-row
metadata. When {opt frame()} is also set, the display frame records the companion in
{cmd:_dta[tabtools_eplotframe]}.{p_end}
{p 4 8 2}- Frame provenance: requested display and eplot frames store the CI
level, ordered statistic IDs, model count, and per-model command identity,
outcome identity when available, effect scale, and display label as
{cmd:_dta[tabtools_*]} characteristics. {helpb comptab} uses these identities
to align compatible sources and rejects ambiguous or conflicting metadata.{p_end}


{marker examples}{title:Examples}

{pstd}{bf:Example 1: IPTW estimation of maternal smoking on birth weight}{p_end}
{phang2}{cmd:. webuse cattaneo2, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (bweight) (mbsmoke mage medu, logit), ate}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("ATE") effect("ATE") ///}{p_end}
{phang3}{cmd:title("ATE of Maternal Smoking on Birth Weight") ///}{p_end}
{phang3}{cmd:tlabels(0 "Non-smoker" 1 "Smoker")}{p_end}

{pstd}{bf:Example 2: Comparing IPTW and doubly robust estimators}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (bweight) (mbsmoke mage medu, logit), ate}{p_end}
{phang2}{cmd:. collect: teffects aipw (bweight mage medu) (mbsmoke mage medu, logit), ate}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("Comparison") ///}{p_end}
{phang3}{cmd:models("IPTW \ AIPW") effect("ATE") clean}{p_end}

{pstd}{bf:Example 3: Potential outcome means}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: teffects ipw (bweight) (mbsmoke mage medu, logit), pomeans}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("PO Means") ///}{p_end}
{phang3}{cmd:effect("Birth Weight") title("Potential Outcome Means") clean}{p_end}

{pstd}{bf:Example 4: Marginal effects}{p_end}
{phang2}{cmd:. webuse nhanes2, clear}{p_end}
{phang2}{cmd:. logit diabetes age female i.race bmi highbp}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins, dydx(age female bmi)}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("AME") effect("AME") ///}{p_end}
{phang3}{cmd:title("Average Marginal Effects on Diabetes")}{p_end}

{pstd}{bf:Example 5: Marginal effects at specific covariate values}{p_end}
{phang2}{cmd:. logit diabetes age female bmi highbp}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins, at(age=(40(10)70))}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("Predictions") effect("Pr(Diabetes)") ///}{p_end}
{phang3}{cmd:title("Predicted Probability at Different Ages")}{p_end}

{pstd}{bf:Example 6: Stratified marginal effects with over()}{p_end}
{phang2}{cmd:. logit diabetes highbp##female age bmi}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins highbp, over(female)}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("Stratified") effect("Pr(Diabetes)") ///}{p_end}
{phang3}{cmd:title("Predicted Probability by Sex and Hypertension")}{p_end}

{pstd}{bf:Example 7: Average marginal effects (dydx) for all covariates}{p_end}
{phang2}{cmd:. logit diabetes age female bmi highbp}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: margins, dydx(*)}{p_end}
{phang2}{cmd:. effecttab, xlsx(effects.xlsx) sheet("All AME") effect("AME") ///}{p_end}
{phang3}{cmd:title("Average Marginal Effects on Diabetes")}{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:effecttab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in output table{p_end}
{synopt:{cmd:r(N_cols)}}number of columns in output table{p_end}
{synopt:{cmd:r(ci_level)}}confidence level used for the displayed intervals{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(type)}}detected or specified result type{p_end}
{synopt:{cmd:r(effect_label)}}effect column label{p_end}
{synopt:{cmd:r(methods)}}methods paragraph for manuscript text{p_end}
{synopt:{cmd:r(frame)}}frame name (if {cmd:frame()} specified){p_end}
{synopt:{cmd:r(eplotframe)}}graph-ready companion frame name (if {cmd:eplotframe()} specified){p_end}

{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}numeric effect estimates and p-values{p_end}

{marker seealso}{title:Also see}

{pstd}{helpb regtab} for formatting standard regression tables{p_end}
{pstd}{helpb teffects} for treatment effects estimation{p_end}
{pstd}{helpb margins} for marginal effects and predictions{p_end}
{pstd}{helpb collect} for the underlying collection framework{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
