{smcl}
{* *! version 1.1.0  14jun2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_prepare" "help msm_prepare"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{viewerjumpto "Syntax" "msm_validate##syntax"}{...}
{viewerjumpto "Description" "msm_validate##description"}{...}
{viewerjumpto "The 10 checks" "msm_validate##checks"}{...}
{viewerjumpto "Options" "msm_validate##options"}{...}
{viewerjumpto "Examples" "msm_validate##examples"}{...}
{viewerjumpto "Stored results" "msm_validate##results"}{...}
{viewerjumpto "Author" "msm_validate##author"}{...}

{title:Title}

{phang}
{bf:msm_validate} {hline 2} Data quality checks for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_validate}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt str:ict}}treat warnings as errors{p_end}
{synopt:{opt ver:bose}}show detailed diagnostics{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_validate} runs 10 data quality checks on a dataset that has already
been prepared with {helpb msm_prepare}.  It reads the stored variable mapping
from the dataset characteristics and systematically inspects the data for
problems that would compromise the integrity of an IPTW analysis.

{pstd}
Run {cmd:msm_validate} after {cmd:msm_prepare} and before {cmd:msm_weight}.
It is the quality gate that stands between your raw data and the weighting
step.  You can run it as many times as you like; it does not modify the dataset.

{pstd}
By default, some checks produce warnings rather than hard errors.  Use
{opt strict} to force all checks to produce errors, which is recommended before
committing to an analysis.  Use {opt verbose} to see detailed information about
which individuals or periods are affected when problems are detected.


{marker checks}{...}
{title:The 10 checks}

{phang2}1. {bf:Person-period format} {hline 2} exactly one row per (id, period)
combination.  Duplicates mean the data is not in the expected long format and
would produce incorrect weights.{p_end}

{phang2}2. {bf:No gaps in period sequences} {hline 2} consecutive periods
within each individual.  Gaps can mean missed visits or data extraction errors
and may bias the weight models.  Default: warning.{p_end}

{phang2}3. {bf:Outcome is terminal} {hline 2} no rows exist after the outcome
event.  If a person has the outcome at period 5, they should not have rows at
period 6+.  Post-event rows would contaminate the estimation sample.  Default:
warning.{p_end}

{phang2}4. {bf:Treatment variation} {hline 2} both treated and untreated
observations exist.  Without variation, the treatment model cannot be
estimated.  Also reports treatment switching patterns.{p_end}

{phang2}5. {bf:Missing data} {hline 2} checks id, period, treatment, outcome,
censoring, and all covariates for missing values.  Missing values in the core
variables can cause silent observation loss in the weight models.  Default:
warning.{p_end}

{phang2}6. {bf:Sufficient observations per period} {hline 2} warns if any
period has fewer than 10 observations.  Very small period-specific samples can
lead to unstable weight models.  Default: warning.{p_end}

{phang2}7. {bf:Covariate completeness} {hline 2} every covariate has non-missing
values and at least some variation.  A constant covariate would be collinear in
the weight model.{p_end}

{phang2}8. {bf:Treatment history patterns} {hline 2} classifies individuals as
always-treated, never-treated, or switchers and reports the distribution.
Not a pass/fail check {hline 1} purely descriptive.{p_end}

{phang2}9. {bf:Censoring patterns} {hline 2} checks that censoring is terminal
(no rows after censoring).  Default: warning.{p_end}

{phang2}10. {bf:Positivity by period} {hline 2} both treatment values exist in
every period.  If any period has 100% treated or 100% untreated, the weight
model will fail for that period (positivity violation).  Default: warning.
Reports the treatment prevalence range across periods.{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt str:ict} promotes all warnings to errors.  When specified, {cmd:msm_validate}
exits with return code 198 if any check produces a warning or error.  Use this
before committing to a final analysis to ensure every data quality issue has
been addressed.

{phang}
{opt ver:bose} displays detailed information about data quality issues.  For
example, it reports the number of individuals with gaps (check 2), lists
specific variables with missing values (check 5), and identifies the exact
periods that violate positivity (check 10).  Useful for diagnosis after a
failed check.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Basic validation after preparing data:}{p_end}

{phang2}{cmd:. capture confirm file msm_example.dta}{p_end}
{phang2}{cmd:. if _rc net get msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace}{p_end}
{phang2}{cmd:. use msm_example.dta, clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_validate}{p_end}

{pstd}
{bf:Strict mode for final analyses.}  Treats all warnings as errors so you can
confirm everything is clean before weighting:{p_end}

{phang2}{cmd:. msm_validate, strict}{p_end}

{pstd}
{bf:Verbose diagnostics for debugging.}  When a check fails, use {cmd:verbose}
to see exactly which individuals or periods are affected:{p_end}

{phang2}{cmd:. msm_validate, strict verbose}{p_end}

{pstd}
{bf:Checking the result programmatically:}{p_end}

{phang2}{cmd:. msm_validate}{p_end}
{phang2}{cmd:. display r(validation)}{p_end}
{phang2}{cmd:. display "Checks: " r(n_checks) ", Errors: " r(n_errors) ", Warnings: " r(n_warnings)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_validate} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_checks)}}number of checks run (always 10){p_end}
{synopt:{cmd:r(n_errors)}}number of checks that produced errors{p_end}
{synopt:{cmd:r(n_warnings)}}number of checks that produced warnings{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(validation)}}{cmd:"passed"} if no errors, {cmd:"failed"} otherwise{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}
