{smcl}
{* *! version 2.0.1  30aug2026}{...}
{viewerjumpto "Package overview" "diagtab##package"}{...}
{viewerjumpto "Syntax" "diagtab##syntax"}{...}
{viewerjumpto "Description" "diagtab##description"}{...}
{viewerjumpto "Options" "diagtab##options"}{...}
{viewerjumpto "Examples" "diagtab##examples"}{...}
{viewerjumpto "Stored results" "diagtab##stored"}{...}
{viewerjumpto "References" "diagtab##references"}{...}
{viewerjumpto "Also see" "diagtab##alsosee"}{...}
{viewerjumpto "Author" "diagtab##author"}{...}
{vieweralsosee "roctab" "help roctab"}{...}
{vieweralsosee "diagt" "help diagt"}{...}
{title:Title}

{phang}
{bf:diagtab} {hline 2} Diagnostic accuracy table with sensitivity, specificity, and
predictive values

{marker package}{title:Package}

{pstd}{cmd:diagtab} is a standalone package for diagnostic-accuracy and cutoff
analysis.{p_end}

{hline}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:diagtab} {it:test_var} {it:gold_var} [{it:if}] [{it:in}],
[{opt xlsx(filename)} {opt excel(filename)} {opt cut:off(#)} {opt cuto:ffs(numlist)}
{opt prev:alence(#)} {opt ex:act} {opt wil:son} {opt auc} {opt opt:imal}
{opt level(#)} {opt dig:its(#)} {opt sheet(string)} {opt title(string)}
{opt foot:note(string)} {opt the:me(string)} {opt border:style(string)}
{opt headerc:olor(string)} {opt zebrac:olor(string)} {opt zebra}
{opt headers:hade} {opt csv(filename)} {opt markdown(filename)} {opt mdappend} {opt fra:me(name)}
{opt open}]{p_end}

{marker description}{title:Description}

{pstd}{cmd:diagtab} computes diagnostic accuracy measures from a 2x2 classification
table: sensitivity, specificity, PPV, NPV, accuracy, likelihood ratios,
diagnostic odds ratio, and optionally AUC. Directly estimated binomial
proportions use Wilson score (default) or Clopper-Pearson exact intervals at
{opt level()} (default {cmd:c(level)}); other measures use the methods documented
below. If {opt cutoff()}, {opt cutoffs()}, and
{opt optimal} are all omitted, {it:test_var} must already be coded 0/1. The completed
table is displayed in the Results window and may also be exported to Excel,
CSV, or Markdown, or stored in a Stata frame.{p_end}

{marker options}{title:Options}

{synoptset 24 tabbed}{...}
{synoptline}
{syntab:Diagnostic}
{synopt:{opt cut:off(#)}}set one dichotomization cutoff{p_end}
{synopt:{opt cuto:ffs(numlist)}}evaluate multiple cutoff values{p_end}
{synopt:{opt prev:alence(#)}}set target prevalence for PPV and NPV{p_end}
{synopt:{opt ex:act}}use Clopper-Pearson exact confidence intervals{p_end}
{synopt:{opt wil:son}}use Wilson score confidence intervals (default){p_end}
{synopt:{opt level(#)}}set the confidence level; default is {cmd:c(level)}{p_end}
{synopt:{opt auc}}report AUC with a confidence interval{p_end}
{synopt:{opt opt:imal}}maximize Youden's J over observed cutoffs{p_end}
{synopt:{opt dig:its(#)}}set decimals for diagnostic measures{p_end}
{syntab:Output}
{synopt:{opt xlsx(filename)}}export to Excel; filename must end in {cmd:.xlsx}{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx(filename)}{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default is {cmd:"Diagnostics"}{p_end}
{synopt:{opt csv(filename)}}also export the output dataset as CSV{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as Markdown{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file{p_end}
{synopt:{opt fra:me(name)}}store output in a named Stata frame{p_end}
{synopt:{opt open}}open the Excel file after export{p_end}
{syntab:Formatting}
{synopt:{opt title(string)}}table title{p_end}
{synopt:{opt foot:note(string)}}footnote text below the table{p_end}
{synopt:{opt the:me(string)}}apply a journal formatting theme{p_end}
{synopt:{opt border:style(string)}}set the workbook border style{p_end}
{synopt:{opt headers:hade}}apply background fill to the header rows{p_end}
{synopt:{opt headerc:olor(string)}}set the header fill color{p_end}
{synopt:{opt zebrac:olor(string)}}set alternating-row fill color{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synoptline}

{dlgtab:Diagnostic details}

{phang}{opt cut:off(#)} dichotomize a continuous test variable at this
threshold. Values >= cutoff are classified as test-positive. The threshold
must be a nonmissing real number; every finite real value, including
{cmd:-999}, is valid.{p_end}

{phang}{opt cutoffs(numlist)} evaluate diagnostic accuracy at multiple distinct,
nonmissing cutoff values. Values are sorted numerically. Closely spaced and
scientific-notation cutoffs retain distinct display labels and unique row
identifiers in {cmd:r(cutoff_table)}. The exact round-trip values, in matrix-row
order, are returned in {cmd:r(cutoffs)}. The option produces one section per
cutoff in the displayed/exported table. The single-cutoff scalars such as
{cmd:r(sensitivity)} and
{cmd:r(specificity)} are not returned. Cannot be combined with {opt cutoff()},
{opt auc}, or {opt optimal}.{p_end}

{phang}{opt prevalence(#)} adjust PPV and NPV for a specified prevalence using Bayes'
theorem. Useful when the study sample prevalence differs from the target
population. Specify a proportion strictly between 0 and 1.{p_end}

{phang2}{bf:Interval method.} The adjusted predictive values are not binomial
proportions of an observed denominator, so neither {opt exact} nor {opt wilson}
applies to them. Their intervals are {bf:symmetric delta-method} intervals that
propagate sensitivity and specificity uncertainty at the supplied prevalence and
are truncated to [0,1]. They are computed only when both estimated sensitivity
and specificity are strictly between 0 and 1. At a boundary estimate the adjusted
PPV/NPV bounds are returned missing rather than as a degenerate point
interval. Consequently, where available, the adjusted bounds are identical under
{opt exact} and {opt wilson}, while sensitivity and specificity bounds
differ; {cmd:r(methods)} states both methods separately. The prevalence is treated as
{bf:known without error}, so the intervals do not reflect uncertainty in it.{p_end}

{phang}{opt exact} use Clopper-Pearson exact confidence intervals instead of
Wilson score for the directly estimated binomial proportions (sensitivity,
specificity, accuracy, and unadjusted predictive values). May not be combined
with {opt wilson}. See {opt prevalence()} for how adjusted predictive values
are handled.{p_end}

{phang}{opt wilson} use Wilson score confidence intervals (this is the
default). May not be combined with {opt exact}.{p_end}

{phang}{opt level(#)} sets the confidence level for all reported proportion,
likelihood-ratio, diagnostic-odds-ratio, and AUC intervals. The default is the
current {cmd:c(level)}, and the resolved level is returned in
{cmd:r(ci_level)} and stored on a requested output frame.{p_end}

{phang}{opt auc} report area under the ROC curve with a confidence interval at
the requested {opt level()}. The calculation delegates to Stata's
{helpb roctab}, whose default standard error is the DeLong method. Cannot be
combined with {opt cutoffs()}, and requires both outcome classes to be present
in {it:gold_var}.{p_end}

{phang}{opt optimal} find the optimal cutoff that maximizes Youden's J index (sensitivity +
specificity - 1). Requires a continuous test variable. If {opt cutoff()} is omitted,
the displayed 2x2 table is evaluated at the optimal cutoff. Cannot be combined
with {opt cutoffs()}.{p_end}

{phang}{opt digits(#)} decimal places for diagnostic measures and CIs
(default 1, range 0-6).{p_end}


{pstd}
{it:Detailed option contracts}{p_end}

{phang}
{opt border:style(string)} border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}

{phang}
{opt csv(filename)} also export the output dataset as CSV. The CSV mirrors the
workbook with {opt title()} written as the first row and {opt footnote()} as
the last row, both in the first column and the table body between them.{p_end}

{phang}
{opt excel(filename)} synonym for {opt xlsx(filename)}. Specify only one of
these aliases in a call.{p_end}

{phang}
{opt foot:note(string)} footnote text below the table{p_end}

{phang}
{opt headerc:olor(string)} custom header color as a supported Stata color name or RGB triplet (for
example, {cmd:"200 220 240"}){p_end}

{phang}
{opt headers:hade} apply background fill to the header rows{p_end}

{phang}
{opt markdown(filename)} export the rendered table as GitHub-Flavored Markdown; may be combined with
Excel, CSV, and frame exports{p_end}

{phang}
{opt mdappend} append the Markdown table to an existing file; requires {opt markdown()}{p_end}

{phang}
{opt open} open the Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}

{phang}
{opt sheet(string)} Excel sheet name; default is {cmd:"Diagnostics"}{p_end}

{phang}
{opt the:me(string)} journal-style formatting theme such as {cmd:lancet}, {cmd:nejm}, {cmd:bmj},
{cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}

{phang}
{opt title(string)} table title{p_end}

{phang}
{opt xlsx(filename)} export to Excel; filename must end in {cmd:.xlsx}. May not
be combined with {opt excel()}.{p_end}

{phang}
{opt zebra} alternating row shading{p_end}

{phang}
{opt zebrac:olor(string)} custom zebra stripe color as a supported Stata color name or RGB triplet{p_end}


{phang}
{opt fra:me(name)} store the output dataset in a named Stata frame; specify
{cmd:frame(name, replace)} to replace an existing frame{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Basic diagnostic accuracy table}{p_end}
{phang2}{cmd:. webuse lbw, clear}{p_end}
{phang2}{cmd:. logit low age lwt smoke}{p_end}
{phang2}{cmd:. predict phat}{p_end}
{phang2}{cmd:. gen byte pred_low = (phat > 0.3)}{p_end}
{phang2}{cmd:. diagtab pred_low low, xlsx(diag.xlsx) ///}{p_end}
{phang3}{cmd:title("Diagnostic Accuracy: Low Birth Weight Prediction")}{p_end}

{pstd}{bf:Example 2: Continuous test with cutoff and AUC}{p_end}
{phang2}{cmd:. webuse lbw, clear}{p_end}
{phang2}{cmd:. logit low age lwt smoke}{p_end}
{phang2}{cmd:. predict phat}{p_end}
{phang2}{cmd:. diagtab phat low, cutoff(0.4) auc ///}{p_end}
{phang3}{cmd:xlsx(diag_auc.xlsx) title("LBW Prediction") ///}{p_end}
{phang3}{cmd:theme(nejm)}{p_end}

{pstd}{bf:Example 3: Multiple cutoffs evaluated simultaneously}{p_end}
{phang2}{cmd:. webuse lbw, clear}{p_end}
{phang2}{cmd:. logit low age lwt smoke}{p_end}
{phang2}{cmd:. predict phat}{p_end}
{phang2}{cmd:. diagtab phat low, cutoffs(0.2 0.3 0.4 0.5) ///}{p_end}
{phang3}{cmd:xlsx(diag_multi.xlsx) ///}{p_end}
{phang3}{cmd:title("Diagnostic Accuracy Across Cutoffs")}{p_end}

{pstd}When {opt cutoffs()} is used, the output shows one section per cutoff with
sensitivity, specificity, PPV, NPV, and accuracy. Undefined estimates are
displayed as {cmd:--} while stored numeric results remain missing. The combined
results are returned in {cmd:r(cutoff_table)}.{p_end}

{pstd}{bf:Example 4: Prevalence-adjusted predictive values}{p_end}
{phang2}{cmd:. webuse lbw, clear}{p_end}
{phang2}{cmd:. logit low age lwt smoke}{p_end}
{phang2}{cmd:. predict phat}{p_end}
{phang2}{cmd:. gen byte pred_low = (phat > 0.3)}{p_end}
{phang2}{cmd:. diagtab pred_low low, prevalence(0.07) exact ///}{p_end}
{phang3}{cmd:title("PPV/NPV Adjusted for 7% Population Prevalence")}{p_end}

{marker stored}{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(TP)}}true positives (single-cutoff mode){p_end}
{synopt:{cmd:r(FP)}}false positives (single-cutoff mode){p_end}
{synopt:{cmd:r(FN)}}false negatives (single-cutoff mode){p_end}
{synopt:{cmd:r(TN)}}true negatives (single-cutoff mode){p_end}
{synopt:{cmd:r(ci_level)}}confidence level used for all intervals{p_end}
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
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(cutoff_table)}}multi-cutoff analysis results{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(cutoffs)}}cutoff values used (when {cmd:cutoffs()} specified){p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(methods)}}methods paragraph{p_end}

{pstd}
When {opt prevalence()} is specified and sensitivity or specificity is at a
boundary, {cmd:r(ppv_lb)}, {cmd:r(ppv_ub)}, {cmd:r(npv_lb)}, and
{cmd:r(npv_ub)} are missing. Point estimates remain available when their Bayes
denominators are nonzero.{p_end}

{marker references}{title:References}

{phang}
Clopper, C. J., and E. S. Pearson. 1934. The use of confidence or fiducial
limits illustrated in the case of the binomial. {it:Biometrika} 26: 404-413.

{phang}
DeLong, E. R., D. M. DeLong, and D. L. Clarke-Pearson. 1988. Comparing the
areas under two or more correlated receiver operating characteristic curves: A
nonparametric approach. {it:Biometrics} 44: 837-845.

{phang}
Glas, A. S., J. G. Lijmer, M. H. Prins, G. J. Bonsel,
and P. M. M. Bossuyt. 2003. The diagnostic odds ratio: A single indicator of
test performance. {it:Journal of Clinical Epidemiology} 56: 1129-1135.

{phang}
Wilson, E. B. 1927. Probable inference, the law of succession, and statistical
inference. {it:Journal of the American Statistical Association} 22: 209-212.

{phang}
Youden, W. J. 1950. Index for rating diagnostic tests. {it:Cancer} 3: 32-35.

{marker alsosee}{title:Also see}

{psee}
{helpb roctab}, {helpb diagt}
{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{pstd}Version 2.0.1, 2026-08-30{p_end}

{hline}
