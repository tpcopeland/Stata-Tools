{smcl}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "iivw_exogtest" "help iivw_exogtest"}{...}
{vieweralsosee "iivw_diagnose" "help iivw_diagnose"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "iivw_balance##syntax"}{...}
{viewerjumpto "Description" "iivw_balance##description"}{...}
{viewerjumpto "Options" "iivw_balance##options"}{...}
{viewerjumpto "Remarks" "iivw_balance##remarks"}{...}
{viewerjumpto "Interpreting results" "iivw_balance##interpreting"}{...}
{viewerjumpto "Examples" "iivw_balance##examples"}{...}
{viewerjumpto "Stored results" "iivw_balance##results"}{...}
{viewerjumpto "References" "iivw_balance##references"}{...}
{viewerjumpto "Author" "iivw_balance##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:iivw_balance} {hline 2}}Check IIVW weight leverage and visit-model balance{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_balance}
[{it:varlist}]
{ifin}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Weight component}
{synopt:{opt comp:onent(iiw|final)}}which weight to describe; default {cmd:iiw}{p_end}

{syntab:Thresholds}
{synopt:{opt cvcut(#)}}weight CV threshold for low leverage; default {cmd:0.10}{p_end}
{synopt:{opt essratiocut(#)}}ESS/N threshold for low leverage; default {cmd:0.95}{p_end}
{synopt:{opt bal:cut(#)}}absolute target SMD threshold for the balance flag; default {cmd:0.10}{p_end}

{syntab:Supplementary AG refit}
{synopt:{opt agr:efit}}also display the refitted visit-intensity model's hazard ratios{p_end}
{synopt:{opt efr:on}}ignored; the refit replays the stored tie method{p_end}
{synopt:{opt nolog}}suppress Cox iteration logs in AG refits{p_end}
{synopt:{opt l:evel(#)}}confidence level for AG-refit hazard-ratio intervals; default {cmd:c(level)}{p_end}

{syntab:Reporting}
{synopt:{opt xlsx(filename)}}write the balance table to an Excel workbook{p_end}
{synopt:{opt sheet(sheetname)}}Excel worksheet name; default is {cmd:Balance}{p_end}
{synopt:{opt replace}}overwrite the named worksheet if it already exists{p_end}
{synopt:{opt open}}open the Excel workbook after writing it{p_end}
{synopt:{opt title(string)}}optional Excel title row{p_end}
{synopt:{opt footnote(string)}}optional Excel footnote row{p_end}
{synopt:{opt dec:imals(#)}}number of Excel decimal places; default {cmd:4}{p_end}
{synopt:{opt border:style(string)}}Excel border scheme; default {cmd:thin}{p_end}
{synopt:{opt headers:hade}}shade the header rows; off by default{p_end}
{synopt:{opt the:me(string)}}journal preset (e.g. {cmd:lancet}, {cmd:nejm}, {cmd:jama}, {cmd:apa}){p_end}
{synopt:{opt headerc:olor(string)}}header fill as {cmd:"R G B"} 0-255; used with {opt headershade}{p_end}
{synopt:{opt zebrac:olor(string)}}zebra fill as {cmd:"R G B"} 0-255; used with {opt zebra}{p_end}
{synopt:{opt zeb:ra}}shade alternating data rows{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_balance} is a post-weighting diagnostic for data weighted by
{helpb iivw_weight}. It asks two practical questions before an unchanged
weighted outcome estimate is interpreted as evidence of measurement artifact:

{phang2}1. Did the weights have enough leverage to move an estimate?{p_end}
{phang2}2. Do the modeled visit covariates look stable under weighting?{p_end}

{pstd}
The command recovers the panel ID, visit time, weight variable, weight type,
and visit-model covariate list from dataset characteristics written by
{cmd:iivw_weight}. It applies only to {cmd:iivw} and {cmd:fiptiw} weights,
because IPTW-only weights do not contain a visit-intensity component.

{pstd}
The optional {it:varlist} adds extra numeric covariates to the displayed
balance table. The stored visit-model covariates always appear first and are
the covariates used for {cmd:r(balance_flag)}.


{marker options}{...}
{title:Options}

{dlgtab:Thresholds}

{phang}
{opt cvcut(#)} specifies the weight coefficient-of-variation threshold below
which leverage is classified as {cmd:low}. The default is {cmd:0.10}.

{phang}
{opt essratiocut(#)} specifies the effective-sample-size ratio threshold above which
leverage is classified as {cmd:low}. The default is {cmd:0.95}. High ESS/N means the
weights are nearly constant and therefore have little ability to move an
estimate.

{phang}
{opt bal:cut(#)} specifies the absolute {it:target SMD} above which the
IIW-weighted visits are judged not to reproduce the at-risk person-time
distribution. The default is {cmd:0.10}. See
{help iivw_balance##interpreting:Interpreting results} for what the target is.

{dlgtab:Weight component}

{phang}
{opt comp:onent(iiw|final)} selects which weight the leverage and composition
statistics describe. The default, {cmd:iiw}, is the visit-intensity weight
({cmd:_iivw_iw}) -- the component this command is about. {cmd:final} is the
stored analysis weight ({cmd:_iivw_weight}), which for {cmd:fiptiw} is
IIW x IPTW.

{phang}
For {cmd:fiptiw}, summarizing the product and calling the result a
visit-model diagnostic attributes treatment-weight variation to the visit
process: with a constant IIW and a well-separated propensity model, the
product can show a large weight CV and a large mean shift when the visit
weights did nothing at all. Treatment-side balance belongs to
{helpb psdash}. The balance verdict always uses the IIW component, whatever
{opt component()} is set to.

{dlgtab:Supplementary AG refit}

{phang}
{opt agr:efit} displays the hazard ratios of the refitted visit-intensity
model. The refit itself always runs -- it is what the balance verdict rests
on -- so {opt agrefit} only controls the display. Covariates that have no
usable variation or fail to fit are skipped with
a note and a nonzero row-specific return code.

{phang}
{opt efr:on} uses Efron's method for tied event times in the supplementary Cox
models.

{phang}
{opt nolog} suppresses iteration logs in the supplementary Cox models.

{phang}
{opt l:evel(#)} sets the confidence level for the supplementary hazard-ratio
intervals.

{dlgtab:Reporting}

{phang}
{opt xlsx(filename)} writes the balance table to an Excel {cmd:.xlsx}
workbook. The exported worksheet uses a tabtools-style layout with a merged
title, grouped headers, readable statistic labels, variable-label row headers
when available, column widths, borders, and an explanatory footnote. The
numeric values are rendered from {cmd:r(balance)} for presentation.

{phang}
{opt sheet(sheetname)} sets the Excel worksheet name. The default is
{cmd:Balance}. This option requires {opt xlsx()}.

{phang}
{opt replace} overwrites the target worksheet when it already exists. Excel
output follows the tabtools workbook convention: only the named sheet is
cleared and rewritten; other sheets in the workbook are preserved. Without
{opt replace}, an existing worksheet of the same name is left untouched, the
export is skipped with a warning, and the diagnostic results are still
returned in {cmd:r()}.

{phang}
{opt open} opens the Excel workbook after writing it. This option requires
{opt xlsx()}.

{phang}
{opt title(string)} and {opt footnote(string)} add optional title and footnote
rows to Excel output.

{phang}
{opt decimals(#)} sets the number of decimal places used in Excel numeric
cell formatting. The allowed range is 0 through 6; the default is 4.

{phang}
{opt borderstyle(string)} selects the Excel border scheme and requires {opt xlsx()}. {cmd:thin}
(the default) draws a full thin grid -- an outer box plus interior horizontal
and vertical rules -- matching the tabtools house style. {cmd:medium} draws the same
framed grid with medium lines. {cmd:academic} uses a three-rule (top/header/bottom)
layout with no vertical rules. {cmd:default} is an alias for {cmd:thin}.

{phang}
{opt headershade} shades the header rows. It is off by default so that output
matches the unshaded house style. {opt headercolor(string)} sets the header
fill as three space-separated 0-255 RGB values, for example
{cmd:headercolor("219 229 241")}.

{phang}
{opt zebra} shades alternating data rows, and {opt zebracolor(string)} sets
that fill as {cmd:"R G B"} values.

{phang}
{opt theme(string)} applies a journal preset ({cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos},
{cmd:nature}, {cmd:cell}, or {cmd:annals}) that sets the font, font size, and border scheme
together. Explicit {opt borderstyle()}, {opt headershade}, or {opt zebra} options override the
matching theme setting.


{marker remarks}{...}
{title:Remarks}

{pstd}
Leverage is classified as follows. It is {cmd:low} if weight CV is below
{opt cvcut()} or ESS/N is above {opt essratiocut()}. Among non-low cases it
is {cmd:adequate} when CV is at least {cmd:0.25} and ESS/N is at most
{cmd:0.80}; otherwise it is {cmd:moderate}. These are conventions and can be
changed for the low-leverage gate with {opt cvcut()} and {opt essratiocut()}.

{pstd}
{cmd:iivw_balance} reports two different things about each covariate, and it is
important not to confuse them.

{pstd}
{bf:Composition shift} is descriptive. It measures how far the weights moved
the covariate composition of the observed visits:

{p 12 12 2}
{it:shift} = (weighted mean - unweighted mean) / unweighted SD.

{pstd}
A large shift says the weights did a lot of work. It does {it:not} say they did
the right work, because it compares the sample to itself and has no target. It
therefore drives no verdict. A large shift is exactly what you should expect
when the visit process is strongly informative and the weights are correcting
it properly.

{pstd}
{bf:Target SMD} is the verdict. Under a correctly specified visit-intensity
model the IIW weight cancels the intensity, so the IIW-weighted distribution of
a covariate over the {it:observed visits} equals its distribution over the
{it:at-risk person-time}, measured in {it:dLambda-0} units:

{p 12 12 2}
{it:target SMD} = (IIW-weighted visit mean - person-time mean) / person-time SD.

{pstd}
That is a real reference distribution rather than a rearrangement of the same
visits, so it has a null: it is 0 when the weights work. {cmd:r(balance_flag)}
is {cmd:good} when the largest absolute target SMD is at or below
{opt balcut()}, and {cmd:poor} otherwise. Computing the person-time target
requires each subject's terminal at-risk interval, which is why the weights
must have been built with {opt censor()} or {opt maxfu()} to get the most out
of this diagnostic.

{pstd}
Covariates you pass in {it:varlist} that were {it:not} in the visit model are
the most informative test here, because the verdict on the model's own
covariates is partly self-fulfilling -- in the same way that a propensity-score
balance check on the score model's own covariates is.


{marker interpreting}{...}
{title:Interpreting results}

{pstd}
Read {cmd:iivw_balance} as a diagnostic stress test. A {cmd:low} leverage
verdict means a null weighting movement is not informative, because nearly
constant weights cannot move estimates much. A {cmd:poor} balance flag means
the IIW-weighted visits do not reproduce the at-risk person-time distribution
they are meant to represent, so the visit model needs more scrutiny.

{pstd}
{cmd:r(balance_flag)} is {cmd:unknown}, not {cmd:good}, when the refit that
supports the verdict could not be completed. A diagnostic with no evidence
behind it does not get to report a clean bill of health.

{pstd}
The refit reconstructs the counting-process intervals using the stored
weighting contract: the same {opt entry()} start times, the same
{opt baseline()} treatment of the first visit, and the same terminal at-risk
interval from {opt censor()} or {opt maxfu()}. On that interval a {it:lagged}
covariate takes the value it had at the last visit, rebuilt from the source
variable -- not the value in the lag column of the last visit row, which refers
to the visit before it. This keeps the refit's risk sets aligned with the
weight-generating model.

{pstd}
{bf:Why no weighted refit is reported.} The intuitive check -- refit the visit
model with the IIW weights and see whether the coefficients go to zero -- does
not work, and is no longer offered. {cmd:stcox} with {cmd:pweight}s applies the
weight to the event term {it:and} to the risk-set average. In the score at
{it:beta} = 0 the weight cancels against the intensity in the first but not the
second, leaving a term in the {it:weighted} risk-set mean that does not vanish.
The weighted coefficients therefore have no null at zero: on correctly weighted
data the unweighted visit-model hazard ratio was 1.523 and the IIW-weighted
refit gave 1.537. Use {it:target SMD}, which does have a null.


{marker examples}{...}
{title:Examples}

{pstd}Create synthetic irregular-visit panel data and compute IIW weights.{p_end}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 240526}{p_end}
{phang2}{cmd:. set obs 240}{p_end}
{phang2}{cmd:. gen long id = ceil(_n/4)}{p_end}
{phang2}{cmd:. bysort id: gen byte visit = _n}{p_end}
{phang2}{cmd:. gen double months = 3 * (visit - 1) + runiform() * .05}{p_end}
{phang2}{cmd:. replace months = 0 if visit == 1}{p_end}
{phang2}{cmd:. gen double age = 35 + mod(id, 20)}{p_end}
{phang2}{cmd:. gen byte female = mod(id, 2)}{p_end}
{phang2}{cmd:. gen double severity = .04 * age + .25 * female + .12 * visit + rnormal()}{p_end}
{phang2}{cmd:. gen byte relapse = runiform() < invlogit(-2 + .4 * severity)}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(months) visit_cov(age female) lagvars(severity relapse) nolog}{p_end}

{pstd}Check leverage and visit-model covariate balance.{p_end}

{phang2}{cmd:. iivw_balance}{p_end}

{pstd}Add extra covariates to the displayed table and request the supplementary
AG-refit view.{p_end}

{phang2}{cmd:. iivw_balance severity relapse, agrefit nolog}{p_end}

{pstd}Export the formatted balance table to a workbook sheet.{p_end}

{phang2}{cmd:. iivw_balance, xlsx(iivw_results.xlsx) sheet(Balance) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_balance} stores the following in {cmd:r()}:

{synoptset 28 tabbed}{...}
{p2col 5 28 32 2:Scalars}{p_end}
{synopt:{cmd:r(N)}}analysis observations with nonmissing weights, ID, and time{p_end}
{synopt:{cmd:r(n_ids)}}number of subjects{p_end}
{synopt:{cmd:r(weight_cv)}}weight coefficient of variation{p_end}
{synopt:{cmd:r(ess)}}effective sample size, (sum w)^2 / sum(w^2){p_end}
{synopt:{cmd:r(ess_ratio)}}effective sample size divided by {cmd:r(N)}{p_end}
{synopt:{cmd:r(balance_max_shift)}}maximum absolute composition shift; descriptive{p_end}
{synopt:{cmd:r(balance_max_tsmd)}}maximum absolute target SMD; drives {cmd:r(balance_flag)}{p_end}
{synopt:{cmd:r(refit_N)}}at-risk intervals used by the visit-model refit{p_end}
{synopt:{cmd:r(refit_n_censrows)}}terminal at-risk intervals in the refit{p_end}
{synopt:{cmd:r(refit_ok)}}1 if the refit that supports the verdict completed{p_end}

{p2col 5 28 32 2:Macros}{p_end}
{synopt:{cmd:r(id)}}stored panel ID variable{p_end}
{synopt:{cmd:r(time)}}stored visit time variable{p_end}
{synopt:{cmd:r(weighttype)}}stored weight type{p_end}
{synopt:{cmd:r(weight_var)}}stored weight variable{p_end}
{synopt:{cmd:r(visit_covars)}}stored visit-model covariates{p_end}
{synopt:{cmd:r(extra_covars)}}extra covariates supplied in {it:varlist}{p_end}
{synopt:{cmd:r(balance_covars)}}all covariates in the displayed table{p_end}
{synopt:{cmd:r(component)}}{cmd:iiw} or {cmd:final}; which weight was described{p_end}
{synopt:{cmd:r(leverage)}}{cmd:low}, {cmd:moderate}, or {cmd:adequate}{p_end}
{synopt:{cmd:r(balance_flag)}}{cmd:good}, {cmd:poor}, or {cmd:unknown}{p_end}
{synopt:{cmd:r(result_columns)}}column names for {cmd:r(balance)}{p_end}
{synopt:{cmd:r(xlsx)}}Excel workbook written; only when {opt xlsx()} succeeds{p_end}
{synopt:{cmd:r(sheet)}}Excel worksheet written; only when Excel export succeeds{p_end}

{p2col 5 28 32 2:Export scalars}{p_end}
{synopt:{cmd:r(decimals)}}Excel decimal formatting used; only when an export succeeds{p_end}

{p2col 5 28 32 2:Matrices}{p_end}
{synopt:{cmd:r(balance)}}covariate composition statistics and flags{p_end}
{synopt:{cmd:r(hr_unweighted)}}refitted visit-intensity model HRs{p_end}
{p2colreset}{...}

{pstd}
{cmd:r(balance)} contains the unweighted mean, weighted mean, unweighted SD,
composition shift, absolute shift, N, missing count, and modeled-covariate
flag.


{marker references}{...}
{title:References}

{pstd}
{bf:What is and is not sourced.} The weights being diagnosed come from
Buzkova & Lumley (2007) (see {helpb iivw_weight}). The effective sample size is
Kish's, {it:ESS} = (sum of weights)^2 / (sum of squared weights).

{pstd}
The {it:target SMD} null is a consequence of the estimator itself, not a
convention: Buzkova & Lumley weight each observed visit by exp(-{it:gamma}'Z)
while the visit intensity is {it:lambda-0}(t)exp({it:gamma}'Z), so the weight
cancels the intensity and the IIW-weighted sum over observed visits has the
same expectation as the integral over at-risk person-time in {it:dLambda-0}
units (their eq. 8, p. 8). The equality of the two distributions is what
{it:target SMD} measures, and it is 0 under a correct visit model.

{pstd}
The {cmd:0.10} {opt balcut()} and the {it:leverage} thresholds remain package
{it:conventions} with no published source: {cmd:0.10} is borrowed from the
propensity-score balance literature. It now cuts a statistic of the same kind
that literature uses -- a standardized gap between a weighted sample and the
distribution it is supposed to represent -- rather than the earlier
weighted-versus-unweighted movement, but the cut is still a rule of thumb, not
a validated threshold. Treat {cmd:r(leverage)} and {cmd:r(balance_flag)} as
descriptive summaries, not as tests.

{phang}
Buzkova P, Lumley T. 2007. Longitudinal data analysis for generalized linear
models with follow-up dependent on outcome-related
variables. {it:Canadian Journal of Statistics}
35(4): 485-500. doi:10.1002/cjs.5550350402.

{phang}
Kish L. 1965. {it:Survey Sampling}. New York: Wiley.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
