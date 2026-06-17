{smcl}
{* *! version 1.7.1  17jun2026}{...}
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
{syntab:Thresholds}
{synopt:{opt cvcut(#)}}weight CV threshold for low leverage; default {cmd:0.10}{p_end}
{synopt:{opt essratiocut(#)}}ESS/N threshold for low leverage; default {cmd:0.95}{p_end}
{synopt:{opt smdcut(#)}}absolute standardized-difference threshold; default {cmd:0.10}{p_end}

{syntab:Supplementary AG refit}
{synopt:{opt agr:efit}}also refit unweighted and weighted visit-timing Cox models{p_end}
{synopt:{opt efr:on}}use Efron method for tied event times in AG refits{p_end}
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
{synopt:{opt border:style(string)}}Excel border scheme: {cmd:thin} (framed grid with column-group separators; default), {cmd:medium}, {cmd:academic}, or {cmd:default}{p_end}
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
{helpb iivw_weight}.  It asks two practical questions before an unchanged
weighted outcome estimate is interpreted as evidence of measurement artifact:

{phang2}1. Did the weights have enough leverage to move an estimate?{p_end}
{phang2}2. Do the modeled visit covariates look stable under weighting?{p_end}

{pstd}
The command recovers the panel ID, visit time, weight variable, weight type,
and visit-model covariate list from dataset characteristics written by
{cmd:iivw_weight}.  It applies only to {cmd:iivw} and {cmd:fiptiw} weights,
because IPTW-only weights do not contain a visit-intensity component.

{pstd}
The optional {it:varlist} adds extra numeric covariates to the displayed
balance table.  The stored visit-model covariates always appear first and are
the covariates used for {cmd:r(balance_flag)}.


{marker options}{...}
{title:Options}

{dlgtab:Thresholds}

{phang}
{opt cvcut(#)} specifies the weight coefficient-of-variation threshold below
which leverage is classified as {cmd:low}.  The default is {cmd:0.10}.

{phang}
{opt essratiocut(#)} specifies the effective-sample-size ratio threshold
above which leverage is classified as {cmd:low}.  The default is {cmd:0.95}.
High ESS/N means the weights are nearly constant and therefore have little
ability to move an estimate.

{phang}
{opt smdcut(#)} specifies the absolute standardized-difference threshold used
for {cmd:r(balance_flag)}.  The default is {cmd:0.10}.  The statistic is the
weighted mean minus the unweighted mean, divided by the unweighted standard
deviation.  This is a heuristic composition check, not a formal test.

{dlgtab:Supplementary AG refit}

{phang}
{opt agr:efit} refits one Andersen-Gill style Cox model per stored visit-model
covariate, once without weights and once with the stored IIVW/FIPTIW weights.
It returns hazard-ratio matrices as a supplementary model-matched view.
Covariates that have no usable variation or fail to fit are skipped with a
note and a nonzero row-specific return code.

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
workbook.  The exported worksheet uses a tabtools-style layout with a merged
title, grouped headers, readable statistic labels, variable-label row headers
when available, column widths, borders, and an explanatory footnote.  The
numeric values are rendered from {cmd:r(balance)} for presentation.

{phang}
{opt sheet(sheetname)} sets the Excel worksheet name.  The default is
{cmd:Balance}.  This option requires {opt xlsx()}.

{phang}
{opt replace} overwrites the target worksheet when it already exists.  Excel
output follows the tabtools workbook convention: only the named sheet is
cleared and rewritten; other sheets in the workbook are preserved.  Without
{opt replace}, an existing worksheet of the same name is left untouched, the
export is skipped with a warning, and the diagnostic results are still
returned in {cmd:r()}.

{phang}
{opt open} opens the Excel workbook after writing it.  This option requires
{opt xlsx()}.

{phang}
{opt title(string)} and {opt footnote(string)} add optional title and footnote
rows to Excel output.

{phang}
{opt decimals(#)} sets the number of decimal places used in Excel numeric
cell formatting.  The allowed range is 0 through 6; the default is 4.

{phang}
{opt borderstyle(string)} selects the Excel border scheme and requires
{opt xlsx()}.  {cmd:thin} (the default) draws a full thin grid -- an outer box
plus interior horizontal and vertical rules -- matching the tabtools house
style.  {cmd:medium} draws the same framed grid with medium lines.
{cmd:academic} uses a three-rule (top/header/bottom) layout with no vertical
rules.  {cmd:default} is an alias for {cmd:thin}.

{phang}
{opt headershade} shades the header rows.  It is off by default so that output
matches the unshaded house style.  {opt headercolor(string)} sets the header
fill as three space-separated 0-255 RGB values, for example
{cmd:headercolor("219 229 241")}.

{phang}
{opt zebra} shades alternating data rows, and {opt zebracolor(string)} sets
that fill as {cmd:"R G B"} values.

{phang}
{opt theme(string)} applies a journal preset ({cmd:lancet}, {cmd:nejm},
{cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, or
{cmd:annals}) that sets the font, font size, and border scheme together.
Explicit {opt borderstyle()}, {opt headershade}, or {opt zebra} options
override the matching theme setting.


{marker remarks}{...}
{title:Remarks}

{pstd}
Leverage is classified as follows.  It is {cmd:low} if weight CV is below
{opt cvcut()} or ESS/N is above {opt essratiocut()}.  Among non-low cases it
is {cmd:adequate} when CV is at least {cmd:0.25} and ESS/N is at most
{cmd:0.80}; otherwise it is {cmd:moderate}.  These are conventions and can be
changed for the low-leverage gate with {opt cvcut()} and {opt essratiocut()}.

{pstd}
The balance table reports weighted and unweighted means for each modeled
visit covariate and any extra covariates supplied by the user.  The
standardized difference is scale-free:

{p 12 12 2}
{it:SMD} = (weighted mean - unweighted mean) / unweighted SD.

{pstd}
The returned {cmd:r(informative)} flag is {cmd:1} only when leverage is
{cmd:moderate} or {cmd:adequate} and {cmd:r(balance_flag)} is {cmd:good}.
Use it as a simulation or workflow guard.  Do not treat it as proof that the
visit model is correct.


{marker interpreting}{...}
{title:Interpreting results}

{pstd}
Read {cmd:iivw_balance} as a diagnostic stress test.  A {cmd:low} leverage
verdict means a null weighting movement is not informative, because nearly
constant weights cannot move estimates much.  A {cmd:poor} balance flag means
the modeled covariate composition changed beyond the documented convention
and the result needs more scrutiny.

{pstd}
The supplementary {opt agrefit} output is deliberately secondary.  Cox
partial-likelihood weighting does not guarantee hazard ratios shrink to one,
so these matrices are best used to understand direction and scale rather than
as pass/fail criteria.


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
{synopt:{cmd:r(balance_max_smd)}}maximum absolute SMD among modeled visit covariates{p_end}
{synopt:{cmd:r(informative)}}1 if leverage is not low and balance flag is good; otherwise 0{p_end}

{p2col 5 28 32 2:Macros}{p_end}
{synopt:{cmd:r(id)}}stored panel ID variable{p_end}
{synopt:{cmd:r(time)}}stored visit time variable{p_end}
{synopt:{cmd:r(weighttype)}}stored weight type{p_end}
{synopt:{cmd:r(weight_var)}}stored weight variable{p_end}
{synopt:{cmd:r(visit_covars)}}stored visit-model covariates{p_end}
{synopt:{cmd:r(extra_covars)}}extra covariates supplied in {it:varlist}{p_end}
{synopt:{cmd:r(balance_covars)}}all covariates in the displayed table{p_end}
{synopt:{cmd:r(leverage)}}{cmd:low}, {cmd:moderate}, or {cmd:adequate}{p_end}
{synopt:{cmd:r(balance_flag)}}{cmd:good} or {cmd:poor}{p_end}
{synopt:{cmd:r(result_columns)}}column names for {cmd:r(balance)}{p_end}
{synopt:{cmd:r(xlsx)}}Excel workbook written; only when {opt xlsx()} succeeds{p_end}
{synopt:{cmd:r(sheet)}}Excel worksheet written; only when Excel export succeeds{p_end}

{p2col 5 28 32 2:Export scalars}{p_end}
{synopt:{cmd:r(decimals)}}Excel decimal formatting used; only when an export succeeds{p_end}

{p2col 5 28 32 2:Matrices}{p_end}
{synopt:{cmd:r(balance)}}unweighted mean, weighted mean, SD, SMD, abs(SMD), N, missing count, modeled flag{p_end}
{synopt:{cmd:r(hr_unweighted)}}unweighted AG-refit HRs; only with {opt agrefit}{p_end}
{synopt:{cmd:r(hr_weighted)}}weighted AG-refit HRs; only with {opt agrefit}{p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{pstd}Version 1.7.1, 2026-06-17{p_end}

{hline}
