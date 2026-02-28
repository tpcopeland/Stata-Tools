{smcl}
{* *! version 1.4.4  25feb2026}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "gformtab" "help gformtab"}{...}
{viewerjumpto "Package overview" "regtab##package"}{...}
{viewerjumpto "Syntax" "regtab##syntax"}{...}
{viewerjumpto "Description" "regtab##description"}{...}
{viewerjumpto "Options" "regtab##options"}{...}
{viewerjumpto "Examples" "regtab##examples"}{...}
{viewerjumpto "Author" "regtab##author"}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:regtab} {hline 2}}Format regression and treatment effects tables for Excel{p_end}
{p2colreset}{...}


{marker package}{...}
{title:Package Overview}

{pstd}
The {cmd:regtab} package provides commands for formatting regression and treatment
effects output into publication-ready Excel tables. All commands work with
Stata's {helpb collect} framework and apply professional formatting.

{synoptset 14}{...}
{synopt:{helpb regtab}}Format collected regression tables (logit, regress, stcox, etc.){p_end}
{synopt:{helpb effecttab}}Format treatment effects and margins tables (teffects, margins){p_end}
{synopt:{helpb gformtab}}Format gformula mediation analysis tables (TCE, NDE, NIE, PM, CDE){p_end}

{pstd}
{bf:Installation}

{phang2}{cmd:. net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/tabtools") replace}{p_end}

{hline}


{title:regtab}

{pstd}Format {helpb collect}ed regression results into a polished Excel table.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:regtab}, {opt xlsx(string)} {opt sheet(string)} [{opt sep(string asis)} {opt models(string)} {opt coef(string)} {opt title(string)} {opt noint} {opt nore} {opt stats(string)} {opt relabel}]{p_end}

{pstd}Required: an active {helpb collect} with items {cmd:_r_b}, {cmd:_r_ci}, and {cmd:_r_p} and dimensions including {cmd:colname} and {cmd:cmdset}.{p_end}

{marker description}{title:Description}

{pstd}{cmd:regtab} reads the current {helpb collect} table and writes a clean Excel sheet with, for each model (each {cmd:cmdset}), three columns: point estimate ({cmd:_r_b}), 95% CI ({cmd:_r_ci}), and p-value ({cmd:_r_p}). It applies labels and number formats, exports to a temporary workbook, re-imports to allow row edits (e.g., dropping intercept or random-effects rows), optionally merges model headers, writes to your target workbook/sheet, and styles borders, alignment, fonts, and column widths. Title text can be written to cell {cmd:A1}; the main table begins at {cmd:B2}.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(string)}}Output Excel filename (must end with {cmd:.xlsx}). If the file exists, only the named sheet is replaced.{p_end}
{synopt:{opt sheet(string)}}Target sheet name to create/replace in {opt xlsx()}.{p_end}
{synopt:{opt sep(string asis)}}Delimiter between CI endpoints used by {cmd:collect} {cmd:cidelimiter()}. Default is {cmd:", "}.{p_end}
{synopt:{opt models(string)}}Labels to merge above each model's three columns. Separate labels with a backslash, e.g., {cmd:"Model 1 \ Model 2"}. If omitted, model label is not included.{p_end}
{synopt:{opt coef(string)}}Header label for the point estimate column (the {cmd:_r_b} result). If omitted, the collect default/blank label is used; set this to {cmd:"OR"}, {cmd:"RR"}, {cmd:"Coef."}, {cmd:"HR"}, etc., as desired.{p_end}
{synopt:{opt title(string)}}Text written into {cmd:A1} and merged across the table width. If omitted, the title row is left blank.{p_end}
{synopt:{opt noint}}Drop the intercept row. Matches {cmd:_cons}, {cmd:constant}, or {cmd:Intercept} (case-insensitive).{p_end}
{synopt:{opt nore}}Drop rows whose variable name contains {cmd:var(}...{cmd:)} (common for random-effects variance components).{p_end}
{synopt:{opt stats(string)}}Add model fit statistics at the bottom of the table. Space-separated list of: {cmd:n} (observations), {cmd:aic}, {cmd:bic}, {cmd:icc} (intraclass correlation), {cmd:ll} (log-likelihood), {cmd:groups} (for mixed models).{p_end}
{synopt:{opt relabel}}Relabel random effects using variable labels from the grouping variable and random effects. For example, if the grouping variable {cmd:provider} has label "Healthcare Provider" and the model includes a random slope on {cmd:treatment} (labeled "Treatment Group"), the output will show "Healthcare Provider (Intercept)" for the random intercept variance, "Healthcare Provider (Treatment Group)" for the random slope variance, and "Healthcare Provider (Intercept, Treatment Group)" for the covariance. The residual variance is labeled "Residual Variance". If variable labels are not available, falls back to generic labels like {it:Variance (Intercept)}.{p_end}
{synoptline}

{marker remarks}{title:Remarks}

{pstd}Prerequisites and expectations{p_end}
{p 4 8 2}- Run your models inside {cmd:collect:} or otherwise ensure the relevant results are in the active {helpb collect}. {cmd:regtab} does not run models.{p_end}
{p 4 8 2}- {cmd:regtab} expects dimensions including {cmd:colname} and {cmd:cmdset}, and result items {cmd:_r_b}, {cmd:_r_ci}, {cmd:_r_p}. It applies cell styles: {cmd:_r_b} as %4.2fc, {cmd:_r_ci} as {cmd:sformat("(%s")} with {cmd:cidelimiter()}, and {cmd:_r_p} as %5.4f.{p_end}
{p 4 8 2}- The CI delimiter is controlled by {opt sep()}; default {cmd:", "}. Example alternative: {cmd:sep("; ")}.{p_end}
{p 4 8 2}- If {opt coef()} is not provided, the header label above {cmd:_r_b} may be blank depending on your {helpb collect} labels; set it explicitly for clarity (e.g., {cmd:coef("OR")}).{p_end}
{p 4 8 2}- Model header labels are included only when {opt models()} is supplied; the labels are split on the backslash character.{p_end}

{pstd}Notes on output shaping{p_end}
{p 4 8 2}- Baseline/reference rows: if a point estimate is 0 or 1 and the adjacent CI cell is empty, {cmd:regtab} substitutes {it:Reference} in the estimate column.{p_end}
{p 4 8 2}- Intercept and random-effects rows can be removed using {opt noint} and {opt nore}, respectively.{p_end}
{p 4 8 2}- Fonts are set to Arial 10. Borders are drawn around the table and model blocks. Column widths and row heights are adjusted heuristically to fit labels and contents.{p_end}
{p 4 8 2}- The command writes the Excel output using {helpb putexcel}; a temporary workbook {cmd:temp.xlsx} is created and deleted during processing.{p_end}

{marker examples}{title:Examples}

{pstd}Propensity score model for SNRI vs SSRI:{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/_examples/cohort.dta", clear"':. use _examples/cohort.dta, clear}{p_end}
{phang2}{stata `"merge 1:1 id using "https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/_examples/treatment.dta", nogen keep(match)"':. merge 1:1 id using _examples/treatment.dta, nogen keep(match)}{p_end}
{phang2}{stata `"merge 1:1 id using "https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/_examples/comorbidities.dta", nogen keep(master match)"':. merge 1:1 id using _examples/comorbidities.dta, nogen keep(master match)}{p_end}
{phang2}{stata "replace diabetes = 0 if missing(diabetes)":. replace diabetes = 0 if missing(diabetes)}{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: logit treated index_age female i.education diabetes hypertension anxiety":. collect: logit treated index_age female i.education diabetes hypertension anxiety}{p_end}
{phang2}{stata `"regtab, xlsx(tabtools/examples/regression.xlsx) sheet("PS_Model") title("Propensity Score Model: SNRI vs SSRI") coef(OR)"':. regtab, xlsx(tabtools/examples/regression.xlsx) sheet("PS_Model") ///}{p_end}
{phang3}{cmd:title("Propensity Score Model: SNRI vs SSRI") coef(OR)}{p_end}

{pstd}Two models with merged headers, dropping the intercept row:{p_end}
{phang2}{stata "collect clear":. collect clear}{p_end}
{phang2}{stata "collect: logit treated index_age female":. collect: logit treated index_age female}{p_end}
{phang2}{stata "collect: logit treated index_age female i.education diabetes hypertension anxiety":. collect: logit treated index_age female i.education diabetes hypertension anxiety}{p_end}
{phang2}{stata `"regtab, xlsx(tabtools/examples/regression.xlsx) sheet("Table 2") models("Unadj \ Adj") coef("OR") title("Table 2. Odds ratios") noint"':. regtab, xlsx(tabtools/examples/regression.xlsx) sheet("Table 2") ///}{p_end}
{phang3}{cmd:models("Unadj \ Adj") coef("OR") title("Table 2. Odds ratios") noint}{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:regtab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in output table{p_end}
{synopt:{cmd:r(N_cols)}}number of columns in output table{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename{p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}

{pstd}It clears the active {cmd:collect} at the end and deletes the temporary workbook.{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.4.4 - 2026-02-25{p_end}

