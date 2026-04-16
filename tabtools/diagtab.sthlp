{smcl}
{* *! version 1.0.4  16apr2026}{...}
{viewerjumpto "Package overview" "diagtab##package"}{...}
{viewerjumpto "Syntax" "diagtab##syntax"}{...}
{viewerjumpto "Description" "diagtab##description"}{...}
{viewerjumpto "Options" "diagtab##options"}{...}
{viewerjumpto "Examples" "diagtab##examples"}{...}
{viewerjumpto "Stored results" "diagtab##stored"}{...}
{viewerjumpto "Author" "diagtab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "corrtab" "help corrtab"}{...}
{vieweralsosee "crosstab" "help crosstab"}{...}
{vieweralsosee "roctab" "help roctab"}{...}
{vieweralsosee "diagt" "help diagt"}{...}
{title:diagtab}

{pstd}Diagnostic accuracy table with sensitivity, specificity, and predictive values.{p_end}

{marker package}{title:Package}

{pstd}{cmd:diagtab} is part of the {helpb tabtools} suite. See {helpb crosstab}
for general 2x2 tables and {helpb corrtab} for matrix-style correlation output.{p_end}

{hline}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:diagtab} {it:test_var} {it:gold_var} [{it:if}] [{it:in}],
[{opt xlsx(filename)} {opt cutoff(#)} {opt cutoffs(numlist)}
{opt prevalence(#)} {opt exact} {opt wilson} {opt auc} {opt optimal}
{opt digits(#)} {opt sheet(string)} {opt title(string)} {opt subtitle(string)}
{opt footnote(string)} {opt theme(string)} {opt borderstyle(string)}
{opt headercolor(string)} {opt zebracolor(string)} {opt zebra}
{opt headershade} {opt csv(filename)} {opt frame(name)} {opt display}
{opt open}]{p_end}

{marker description}{title:Description}

{pstd}{cmd:diagtab} computes diagnostic accuracy measures from a 2x2
classification table: sensitivity, specificity, PPV, NPV, accuracy,
likelihood ratios, diagnostic odds ratio, and optionally AUC. Confidence
intervals use Wilson score (default) or Clopper-Pearson exact method. If
{opt cutoff()}, {opt cutoffs()}, and {opt optimal} are all omitted, {it:test_var}
must already be coded 0/1.{p_end}

{marker options}{title:Options}

{synoptset 24 tabbed}{...}
{synoptline}
{syntab:Diagnostic}
{synopt:{opt cutoff(#)}}dichotomize a continuous test variable at a single threshold{p_end}
{synopt:{opt cutoffs(numlist)}}evaluate diagnostic accuracy over multiple cutoff values; cannot be combined with {opt cutoff()}, {opt auc}, or {opt optimal}{p_end}
{synopt:{opt prevalence(#)}}adjust PPV and NPV for a target prevalence between 0 and 1{p_end}
{synopt:{opt exact}}use Clopper-Pearson exact confidence intervals{p_end}
{synopt:{opt wilson}}use Wilson score confidence intervals (default){p_end}
{synopt:{opt auc}}report AUC with 95% CI{p_end}
{synopt:{opt optimal}}choose the cutoff that maximizes Youden's J index{p_end}
{synopt:{opt digits(#)}}decimal places for diagnostic measures and confidence intervals; default 1, range 0-6{p_end}
{syntab:Output}
{synopt:{opt xlsx(filename)}}export to Excel; if omitted, output is displayed in the Results window only{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default is {cmd:"Diagnostics"}{p_end}
{synopt:{opt csv(filename)}}also export the output dataset as CSV{p_end}
{synopt:{opt frame(name)}}store the output dataset in a named Stata frame{p_end}
{synopt:{opt display}}show console output in addition to any file export{p_end}
{synopt:{opt open}}open the Excel file after export{p_end}
{syntab:Formatting}
{synopt:{opt title(string)}}table title{p_end}
{synopt:{opt subtitle(string)}}subtitle text displayed below the title{p_end}
{synopt:{opt footnote(string)}}footnote text below the table{p_end}
{synopt:{opt theme(string)}}journal-style formatting theme such as {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, or {cmd:apa}{p_end}
{synopt:{opt borderstyle(string)}}border style: {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt headershade}}apply background fill to the header rows{p_end}
{synopt:{opt headercolor(string)}}custom RGB header color (for example, {cmd:"200 220 240"}){p_end}
{synopt:{opt zebracolor(string)}}custom RGB zebra stripe color{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synoptline}

{dlgtab:Diagnostic details}

{phang}{opt cutoff(#)} dichotomize a continuous test variable at this threshold.
Values >= cutoff are classified as test-positive.{p_end}

{phang}{opt cutoffs(numlist)} evaluate diagnostic accuracy at multiple cutoff
values. Produces one row per cutoff showing all metrics. Cannot be combined with
{opt cutoff()}.{p_end}

{phang}{opt prevalence(#)} adjust PPV and NPV for a specified prevalence using
Bayes' theorem. Useful when the study sample prevalence differs from the target population.
Specify a proportion strictly between 0 and 1.{p_end}

{phang}{opt exact} use Clopper-Pearson exact confidence intervals instead of Wilson score.{p_end}

{phang}{opt wilson} use Wilson score confidence intervals (this is the default).{p_end}

{phang}{opt auc} report area under the ROC curve with 95% CI. Cannot be combined
with {opt cutoffs()}.{p_end}

{phang}{opt optimal} find the optimal cutoff that maximizes Youden's J index
(sensitivity + specificity - 1). Requires a continuous test variable. If
{opt cutoff()} is omitted, the displayed 2x2 table is evaluated at the optimal cutoff.
Cannot be combined with {opt cutoffs()}.{p_end}

{phang}{opt digits(#)} decimal places for diagnostic measures and CIs
(default 1, range 0-6).{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Basic diagnostic accuracy table}{p_end}
{phang2}{stata "webuse lbw, clear":. webuse lbw, clear}{p_end}
{phang2}{stata "logit low age lwt smoke":. logit low age lwt smoke}{p_end}
{phang2}{stata "predict phat":. predict phat}{p_end}
{phang2}{stata "gen byte pred_low = (phat > 0.3)":. gen byte pred_low = (phat > 0.3)}{p_end}
{phang2}{cmd:. diagtab pred_low low, xlsx(diag.xlsx) ///}{p_end}
{phang3}{cmd:title("Diagnostic Accuracy: Low Birth Weight Prediction")}{p_end}

{pstd}{bf:Example 2: Continuous test with cutoff and AUC}{p_end}
{phang2}{stata "webuse lbw, clear":. webuse lbw, clear}{p_end}
{phang2}{stata "logit low age lwt smoke":. logit low age lwt smoke}{p_end}
{phang2}{stata "predict phat":. predict phat}{p_end}
{phang2}{cmd:. diagtab phat low, cutoff(0.4) auc ///}{p_end}
{phang3}{cmd:xlsx(diag_auc.xlsx) title("LBW Prediction") ///}{p_end}
{phang3}{cmd:theme(nejm) display}{p_end}

{pstd}{bf:Example 3: Prevalence-adjusted predictive values}{p_end}
{phang2}{stata "webuse lbw, clear":. webuse lbw, clear}{p_end}
{phang2}{stata "logit low age lwt smoke":. logit low age lwt smoke}{p_end}
{phang2}{stata "predict phat":. predict phat}{p_end}
{phang2}{stata "gen byte pred_low = (phat > 0.3)":. gen byte pred_low = (phat > 0.3)}{p_end}
{phang2}{cmd:. diagtab pred_low low, prevalence(0.07) exact ///}{p_end}
{phang3}{cmd:title("PPV/NPV Adjusted for 7% Population Prevalence") ///}{p_end}
{phang3}{cmd:display}{p_end}

{marker stored}{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(sensitivity)}}sensitivity{p_end}
{synopt:{cmd:r(specificity)}}specificity{p_end}
{synopt:{cmd:r(ppv)}}positive predictive value{p_end}
{synopt:{cmd:r(npv)}}negative predictive value{p_end}
{synopt:{cmd:r(accuracy)}}overall accuracy{p_end}
{synopt:{cmd:r(lr_pos)}}positive likelihood ratio{p_end}
{synopt:{cmd:r(lr_neg)}}negative likelihood ratio{p_end}
{synopt:{cmd:r(dor)}}diagnostic odds ratio{p_end}
{synopt:{cmd:r(youden)}}Youden's index{p_end}
{synopt:{cmd:r(auc)}}area under ROC curve{p_end}
{synopt:{cmd:r(optimal_cutoff)}}optimal cutoff (Youden's J){p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(cutoff_table)}}cutoff analysis results (when {cmd:cutoffs()} specified){p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(cutoffs)}}cutoff values used (when {cmd:cutoffs()} specified){p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(methods)}}methods paragraph{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.4{p_end}

{hline}
