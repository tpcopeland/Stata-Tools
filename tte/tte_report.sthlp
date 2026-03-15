{smcl}
{* *! version 1.1.0  15mar2026}{...}
{viewerjumpto "Syntax" "tte_report##syntax"}{...}
{viewerjumpto "Description" "tte_report##description"}{...}
{viewerjumpto "Options" "tte_report##options"}{...}
{viewerjumpto "Stored results" "tte_report##results"}{...}
{viewerjumpto "Examples" "tte_report##examples"}{...}
{viewerjumpto "Author" "tte_report##author"}{...}

{title:Title}

{phang}
{bf:tte_report} {hline 2} Publication-quality results tables


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_report}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth for:mat(string)}}display (default), csv, or excel{p_end}
{synopt:{opth export(filename)}}export to file{p_end}
{synopt:{opt dec:imals(#)}}decimal places; default is {cmd:3}{p_end}
{synopt:{opt eform}}exponentiate coefficients (OR/HR){p_end}
{synopt:{opth ci_separator(string)}}CI separator; default is {cmd:" to "}{p_end}
{synopt:{opth title(string)}}table title{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synopt:{opt pre:dictions(name)}}matrix of predictions from {cmd:tte_predict}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_report} generates formatted results tables suitable for
manuscripts. It reads from the expanded and fitted dataset produced by the
{cmd:tte} pipeline and produces up to three tables:

{phang2}1. {bf:Analysis Summary} {hline 2} estimand, total person-periods,
treatment/control arm sizes, outcome events, and number of emulated
trials.{p_end}

{phang2}2. {bf:IP Weight Summary} {hline 2} mean, SD, median, range, IQR,
and effective sample size (ESS) of the inverse probability weights.
Displayed only when a weight variable exists in the dataset.{p_end}

{phang2}3. {bf:Outcome Model Coefficients} {hline 2} coefficient estimates
(or exponentiated with {opt eform}), robust standard errors, confidence
intervals, and p-values for each covariate from {cmd:tte_fit}. Displayed
only when {cmd:tte_fit} has been run.{p_end}

{pstd}
{bf:Prerequisites:} {cmd:tte_report} requires that {cmd:tte_expand} has been
run (to create the person-period dataset). For the coefficient table,
{cmd:tte_fit} must also have been run. The typical workflow is:

{phang2}{cmd:. tte_expand ...}{p_end}
{phang2}{cmd:. tte_fit ...}{p_end}
{phang2}{cmd:. tte_report}{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt format(string)} specifies the output format. {cmd:display} (the default)
prints results to the Stata console. {cmd:csv} exports a comma-separated
file. {cmd:excel} exports a formatted Excel workbook with separate sheets for
Summary, Coefficients, and Predictions.

{phang}
{opt export(filename)} specifies the file path for csv or excel export.
Required when {opt format()} is {cmd:csv} or {cmd:excel}.

{phang}
{opt decimals(#)} sets the number of decimal places for reported estimates.
Default is 3. Applies to all numeric output including coefficients, CIs,
and weight summaries.

{phang}
{opt eform} exponentiates the outcome model coefficients. For logistic
models this produces odds ratios (OR); for Cox models this produces
hazard ratios (HR). CIs are also exponentiated.

{phang}
{opt ci_separator(string)} specifies the string used to separate the lower
and upper CI bounds. Default is {cmd:" to "} (e.g., "0.85 to 1.23").

{phang}
{opt title(string)} sets the table title. Default is
{cmd:"Target Trial Emulation Results"}.

{phang}
{opt replace} allows overwriting an existing export file.

{phang}
{opt predictions(name)} specifies the name of a Stata matrix (typically
produced by {cmd:tte_predict}) to include in the Excel export as a
Predictions sheet. Ignored for display and csv formats.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_report} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_obs)}}total person-period observations{p_end}
{synopt:{cmd:r(n_events)}}number of outcome events{p_end}
{synopt:{cmd:r(n_trials)}}number of emulated trials{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(format)}}output format used ({cmd:display}, {cmd:csv}, or {cmd:excel}){p_end}
{synopt:{cmd:r(estimand)}}estimand from {cmd:tte_expand} (e.g., {cmd:ATT}, {cmd:PP}){p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_report}{p_end}
{phang2}{cmd:. tte_report, eform export(results.xlsx) replace}{p_end}
{phang2}{cmd:. tte_report, format(csv) export(results.csv)}{p_end}
{phang2}{cmd:. tte_report, eform decimals(2) title("Table 1: ITT Analysis")}{p_end}

{pstd}
Include predictions in Excel export:

{phang2}{cmd:. tte_predict, generate(pred)}{p_end}
{phang2}{cmd:. matrix P = r(predictions)}{p_end}
{phang2}{cmd:. tte_report, eform export(full_results.xlsx) predictions(P) replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet
