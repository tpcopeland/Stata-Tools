{smcl}
{* *! version 1.8.6  25jun2026}{...}
{viewerjumpto "Package overview" "diagtab##package"}{...}
{viewerjumpto "Syntax" "diagtab##syntax"}{...}
{viewerjumpto "Description" "diagtab##description"}{...}
{viewerjumpto "Options" "diagtab##options"}{...}
{viewerjumpto "Examples" "diagtab##examples"}{...}
{viewerjumpto "Stored results" "diagtab##stored"}{...}
{viewerjumpto "Also see" "diagtab##alsosee"}{...}
{viewerjumpto "Author" "diagtab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "corrtab" "help corrtab"}{...}
{vieweralsosee "crosstab" "help crosstab"}{...}
{vieweralsosee "roctab" "help roctab"}{...}
{vieweralsosee "diagt" "help diagt"}{...}
{title:Title}

{phang}
{bf:diagtab} {hline 2} Diagnostic accuracy table with sensitivity, specificity, and predictive values

{marker package}{title:Package}

{pstd}{cmd:diagtab} is part of the {helpb tabtools} suite. See {helpb crosstab}
for general 2x2 tables and {helpb corrtab} for matrix-style correlation output.{p_end}

{hline}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:diagtab} {it:test_var} {it:gold_var} [{it:if}] [{it:in}],
[{opt xlsx(filename)} {opt excel(filename)} {opt cut:off(#)} {opt cuto:ffs(numlist)}
{opt prev:alence(#)} {opt ex:act} {opt wil:son} {opt auc} {opt opt:imal}
{opt dig:its(#)} {opt sheet(string)} {opt title(string)}
{opt foot:note(string)} {opt the:me(string)} {opt border:style(string)}
{opt headerc:olor(string)} {opt zebrac:olor(string)} {opt zebra}
{opt headers:hade} {opt csv(filename)} {opt markdown(filename)} {opt mdappend} {opt fra:me(name)} {opt dis:play}
{opt open}]{p_end}

{marker description}{title:Description}

{pstd}{cmd:diagtab} computes diagnostic accuracy measures from a 2x2
classification table: sensitivity, specificity, PPV, NPV, accuracy,
likelihood ratios, diagnostic odds ratio, and optionally AUC. Confidence
intervals use Wilson score (default) or Clopper-Pearson exact method. If
{opt cutoff()}, {opt cutoffs()}, and {opt optimal} are all omitted, {it:test_var}
must already be coded 0/1. The completed table is displayed in the Results
window and may also be exported to Excel, CSV, or Markdown, or stored in a Stata frame.{p_end}

{marker options}{title:Options}

{synoptset 24 tabbed}{...}
{synoptline}
{syntab:Diagnostic}
{synopt:{opt cut:off(#)}}dichotomize a continuous test variable at a single threshold{p_end}
{synopt:{opt cuto:ffs(numlist)}}evaluate diagnostic accuracy over multiple cutoff values; cannot be combined with {opt cutoff()}, {opt auc}, or {opt optimal}{p_end}
{synopt:{opt prev:alence(#)}}adjust PPV and NPV for a target prevalence between 0 and 1{p_end}
{synopt:{opt ex:act}}use Clopper-Pearson exact confidence intervals; may not be combined with {opt wilson}{p_end}
{synopt:{opt wil:son}}use Wilson score confidence intervals (default); may not be combined with {opt exact}{p_end}
{synopt:{opt auc}}report AUC with 95% CI; requires both 0 and 1 in {it:gold_var}{p_end}
{synopt:{opt opt:imal}}choose the cutoff that maximizes Youden's J index{p_end}
{synopt:{opt dig:its(#)}}decimal places for diagnostic measures and confidence intervals; default 1, range 0-6{p_end}
{syntab:Output}
{synopt:{opt xlsx(filename)}}export to Excel; filename must end in {cmd:.xlsx}{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx(filename)}{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default is {cmd:"Diagnostics"}{p_end}
{synopt:{opt csv(filename)}}also export the output dataset as CSV{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}store the output dataset in a named Stata frame; specify {cmd:frame(name, replace)} to replace an existing frame{p_end}
{synopt:{opt dis:play}}accepted for compatibility; the completed table is displayed automatically{p_end}
{synopt:{opt open}}open the Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}
{syntab:Formatting}
{synopt:{opt title(string)}}table title{p_end}
{synopt:{opt foot:note(string)}}footnote text below the table{p_end}
{synopt:{opt the:me(string)}}journal-style formatting theme such as {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt headers:hade}}apply background fill to the header rows{p_end}
{synopt:{opt headerc:olor(string)}}custom header color as a supported Stata color name or RGB triplet (for example, {cmd:"200 220 240"}){p_end}
{synopt:{opt zebrac:olor(string)}}custom zebra stripe color as a supported Stata color name or RGB triplet{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synoptline}

{dlgtab:Diagnostic details}

{phang}{opt cut:off(#)} dichotomize a continuous test variable at this threshold.
Values >= cutoff are classified as test-positive.{p_end}

{phang}{opt cutoffs(numlist)} evaluate diagnostic accuracy at multiple cutoff
values. Produces one section per cutoff in the displayed/exported table and
returns the combined results in {cmd:r(cutoff_table)} plus the original cutoff
list in {cmd:r(cutoffs)}. When {opt cutoffs()} is used, the single-cutoff
scalars such as {cmd:r(sensitivity)} and {cmd:r(specificity)} are not returned.
Cannot be combined with {opt cutoff()}, {opt auc}, or {opt optimal}.{p_end}

{phang}{opt prevalence(#)} adjust PPV and NPV for a specified prevalence using
Bayes' theorem. Useful when the study sample prevalence differs from the target population.
Specify a proportion strictly between 0 and 1.{p_end}

{phang}{opt exact} use Clopper-Pearson exact confidence intervals instead of Wilson score. May not be combined with {opt wilson}.{p_end}

{phang}{opt wilson} use Wilson score confidence intervals (this is the default). May not be combined with {opt exact}.{p_end}

{phang}{opt auc} report area under the ROC curve with 95% CI. Cannot be combined
with {opt cutoffs()}, and requires both outcome classes to be present in
{it:gold_var}.{p_end}

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

{pstd}{bf:Example 3: Multiple cutoffs evaluated simultaneously}{p_end}
{phang2}{stata "webuse lbw, clear":. webuse lbw, clear}{p_end}
{phang2}{stata "logit low age lwt smoke":. logit low age lwt smoke}{p_end}
{phang2}{stata "predict phat":. predict phat}{p_end}
{phang2}{cmd:. diagtab phat low, cutoffs(0.2 0.3 0.4 0.5) ///}{p_end}
{phang3}{cmd:xlsx(diag_multi.xlsx) ///}{p_end}
{phang3}{cmd:title("Diagnostic Accuracy Across Cutoffs") display}{p_end}

{pstd}When {opt cutoffs()} is used, the output shows one section per
cutoff with sensitivity, specificity, PPV, NPV, and accuracy.
Undefined estimates are displayed as {cmd:--} while stored numeric
results remain missing.
The combined results are returned in {cmd:r(cutoff_table)}.{p_end}

{pstd}{bf:Example 4: Prevalence-adjusted predictive values}{p_end}
{phang2}{stata "webuse lbw, clear":. webuse lbw, clear}{p_end}
{phang2}{stata "logit low age lwt smoke":. logit low age lwt smoke}{p_end}
{phang2}{stata "predict phat":. predict phat}{p_end}
{phang2}{stata "gen byte pred_low = (phat > 0.3)":. gen byte pred_low = (phat > 0.3)}{p_end}
{phang2}{cmd:. diagtab pred_low low, prevalence(0.07) exact ///}{p_end}
{phang3}{cmd:title("PPV/NPV Adjusted for 7% Population Prevalence") ///}{p_end}
{phang3}{cmd:display}{p_end}

{marker stored}{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(TP)}}true positives (single-cutoff mode){p_end}
{synopt:{cmd:r(FP)}}false positives (single-cutoff mode){p_end}
{synopt:{cmd:r(FN)}}false negatives (single-cutoff mode){p_end}
{synopt:{cmd:r(TN)}}true negatives (single-cutoff mode){p_end}
{synopt:{cmd:r(sensitivity)}}sensitivity (single-cutoff mode){p_end}
{synopt:{cmd:r(sensitivity_lb)}}sensitivity lower CI bound{p_end}
{synopt:{cmd:r(sensitivity_ub)}}sensitivity upper CI bound{p_end}
{synopt:{cmd:r(specificity)}}specificity (single-cutoff mode){p_end}
{synopt:{cmd:r(specificity_lb)}}specificity lower CI bound{p_end}
{synopt:{cmd:r(specificity_ub)}}specificity upper CI bound{p_end}
{synopt:{cmd:r(ppv)}}positive predictive value (single-cutoff mode){p_end}
{synopt:{cmd:r(ppv_lb)}}PPV lower CI bound{p_end}
{synopt:{cmd:r(ppv_ub)}}PPV upper CI bound{p_end}
{synopt:{cmd:r(npv)}}negative predictive value (single-cutoff mode){p_end}
{synopt:{cmd:r(npv_lb)}}NPV lower CI bound{p_end}
{synopt:{cmd:r(npv_ub)}}NPV upper CI bound{p_end}
{synopt:{cmd:r(accuracy)}}overall accuracy (single-cutoff mode){p_end}
{synopt:{cmd:r(accuracy_lb)}}accuracy lower CI bound{p_end}
{synopt:{cmd:r(accuracy_ub)}}accuracy upper CI bound{p_end}
{synopt:{cmd:r(lr_pos)}}positive likelihood ratio (single-cutoff mode){p_end}
{synopt:{cmd:r(lr_pos_lb)}}LR+ lower CI bound{p_end}
{synopt:{cmd:r(lr_pos_ub)}}LR+ upper CI bound{p_end}
{synopt:{cmd:r(lr_neg)}}negative likelihood ratio (single-cutoff mode){p_end}
{synopt:{cmd:r(lr_neg_lb)}}LR- lower CI bound{p_end}
{synopt:{cmd:r(lr_neg_ub)}}LR- upper CI bound{p_end}
{synopt:{cmd:r(dor)}}diagnostic odds ratio (single-cutoff mode){p_end}
{synopt:{cmd:r(dor_lb)}}DOR lower CI bound{p_end}
{synopt:{cmd:r(dor_ub)}}DOR upper CI bound{p_end}
{synopt:{cmd:r(youden)}}Youden's index (single-cutoff mode){p_end}
{synopt:{cmd:r(auc)}}area under ROC curve (when {opt auc} requested){p_end}
{synopt:{cmd:r(auc_lb)}}AUC lower CI bound{p_end}
{synopt:{cmd:r(auc_ub)}}AUC upper CI bound{p_end}
{synopt:{cmd:r(optimal_cutoff)}}optimal cutoff (Youden's J; single-cutoff mode){p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(cutoff_table)}}cutoff analysis results (when {cmd:cutoffs()} specified){p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(cutoffs)}}cutoff values used (when {cmd:cutoffs()} specified){p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(methods)}}methods paragraph{p_end}

{marker alsosee}{title:Also see}

{psee}
{helpb tabtools}, {helpb crosstab}, {helpb corrtab},
{helpb tabtools_tips}, {helpb roctab}, {helpb diagt}
{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.8.6{p_end}

{hline}
