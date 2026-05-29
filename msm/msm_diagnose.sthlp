{smcl}
{* *! version 1.0.4  29may2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_plot" "help msm_plot"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_diagtab" "help msm_diagtab"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{viewerjumpto "Syntax" "msm_diagnose##syntax"}{...}
{viewerjumpto "Description" "msm_diagnose##description"}{...}
{viewerjumpto "What to look for" "msm_diagnose##interpreting"}{...}
{viewerjumpto "Options" "msm_diagnose##options"}{...}
{viewerjumpto "Examples" "msm_diagnose##examples"}{...}
{viewerjumpto "Stored results" "msm_diagnose##stored"}{...}
{viewerjumpto "Author" "msm_diagnose##author"}{...}

{title:Title}

{phang}
{bf:msm_diagnose} {hline 2} Weight diagnostics and covariate balance for MSM


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_diagnose}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth bal:ance_covariates(varlist)}}covariates for SMD balance assessment{p_end}
{synopt:{opt by_:period}}show weight statistics separately by period{p_end}
{synopt:{opt thr:eshold(#)}}SMD balance threshold; default is {cmd:0.1}{p_end}
{synopt:{opt accum:ulate(name)}}append a one-row diagnostic summary to a named {help frames:frame}{p_end}
{synopt:{opt cont:rast(string)}}contrast label for the accumulate row (required with {cmd:accumulate()}){p_end}
{synopt:{opt out:come(string)}}outcome label for the accumulate row{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_diagnose} is the diagnostic step that should follow every
{helpb msm_weight} run.  It answers two key questions:

{phang2}1. {bf:Are the weights well-behaved?}  It reports the full weight
distribution (mean, SD, percentiles, min, max), the effective sample size
(ESS), and per-treatment-group summaries.{p_end}

{phang2}2. {bf:Did weighting achieve covariate balance?}  When covariates are
specified, it computes the standardized mean difference (SMD) between treated
and untreated groups both before and after weighting, and reports how much
each covariate improved.{p_end}

{pstd}
This command does not change observations or create/drop data variables.  It
reads the {cmd:_msm_weight} variable created by {helpb msm_weight} and the
variable mapping stored by {helpb msm_prepare}.  It does store diagnostic state
in dataset characteristics so downstream commands can report or export the
latest diagnostics.

{pstd}
If {cmd:balance_covariates()} is omitted, the command defaults to all
covariates registered with {helpb msm_prepare} (both time-varying and
baseline).

{pstd}
When balance diagnostics are requested, the balance results are also persisted
in dataset characteristics and a Stata matrix so that {helpb msm_table} can
export them to Excel.


{marker interpreting}{...}
{title:What to look for}

{pstd}
{bf:Weight distribution:}

{phang2}{bf:Mean {c ~} 1.0:}  Stabilized weights should have a mean near 1.
A mean far from 1 suggests model misspecification.{p_end}

{phang2}{bf:Effective sample size (ESS):}  Measures the effective information
retained after weighting.  ESS = (sum w)^2 / (sum w^2).  If ESS is well below
50% of N, weight variability is high and the analysis will have wide confidence
intervals.  Consider stronger truncation or a simpler weight model.{p_end}

{phang2}{bf:Extreme weights:}  Large maximum weights indicate near-positivity
violations.  Use {cmd:by_period} to identify which periods are affected, and
consider period-specific investigation or truncation.{p_end}

{pstd}
{bf:Covariate balance:}

{phang2}{bf:SMD < 0.1:}  The standard threshold for acceptable balance.  SMDs
above 0.1 after weighting suggest residual confounding for that variable.{p_end}

{phang2}{bf:% Change:}  A large negative change means weighting improved
balance.  A positive change means weighting made balance worse for that
covariate, which warrants investigation.{p_end}

{phang2}Covariates exceeding the threshold are marked with {cmd:*} in the
output.{p_end}


{marker options}{...}
{title:Options}

{phang}
{opth balance_covariates(varlist)} specifies which covariates to assess for
balance.  The command computes SMDs between treated and untreated groups both
without weights (raw) and with the IP weights.  If omitted, all covariates
from {helpb msm_prepare} (both {cmd:covariates()} and
{cmd:baseline_covariates()}) are used.

{phang}
{opt by_:period} displays weight distribution statistics (N, mean, SD, min,
max) separately for each time period.  This is useful for identifying periods
where weights become extreme or where the weight model breaks down.

{phang}
{opt threshold(#)} sets the SMD threshold for declaring acceptable balance.
The default is {cmd:0.1}, following common epidemiological practice.
Covariates with a weighted absolute SMD exceeding this threshold are flagged
in the output.  The balance summary reports how many covariates are balanced
versus imbalanced.

{phang}
{opt accumulate(name)} appends one summary row for the current weighted panel
to the named {help frames:frame}, creating the frame with a fixed schema on
first use.  This is intended for loops over many pairwise contrasts, where each
contrast is fit on its own weighted person-period panel: accumulate the
per-contrast diagnostics into one frame, then export the whole frame as a
single styled sheet with {helpb msm_diagtab}.  Everything {cmd:msm_diagnose}
otherwise does (console display, {cmd:r()} results, and dataset
characteristics) is unchanged when {cmd:accumulate()} is given.  The frame holds
the columns {cmd:contrast}, {cmd:outcome}, {cmd:n_obs} (person-periods),
{cmd:ess}, {cmd:ess_pct}, {cmd:max_weight}, {cmd:p99_weight}, {cmd:n_extreme},
{cmd:n_imbalanced}, and {cmd:max_abs_smd}.  The two balance columns
({cmd:n_imbalanced} and {cmd:max_abs_smd}) are populated whenever balance is
assessed -- which includes the default case where {cmd:balance_covariates()} is
omitted but covariates were registered with {helpb msm_prepare} -- and are left
missing only when there are no covariates to assess.

{phang}
{opt contrast(string)} supplies the contrast label written to the
{cmd:contrast} column of the accumulate row.  It is {bf:required} whenever
{cmd:accumulate()} is given.

{phang}
{opt outcome(string)} supplies an optional outcome label written to the
{cmd:outcome} column of the accumulate row.  It is left empty if not given.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Basic diagnostics with default covariates.}  Uses all covariates from
{cmd:msm_prepare}:{p_end}

{phang2}{cmd:. capture confirm file msm_example.dta}{p_end}
{phang2}{cmd:. if _rc net get msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace}{p_end}
{phang2}{cmd:. use msm_example.dta, clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. msm_diagnose}{p_end}

{pstd}
{bf:Explicit covariates with period-level detail:}{p_end}

{phang2}{cmd:. msm_diagnose, balance_covariates(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    by_period threshold(0.1)}{p_end}

{pstd}
{bf:Inspecting the balance matrix programmatically:}{p_end}

{phang2}{cmd:. msm_diagnose, balance_covariates(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:. matrix list r(balance)}{p_end}

{pstd}
{bf:Visualizing the diagnostics.}  Follow up with {helpb msm_plot} for weight
density and Love plots:{p_end}

{phang2}{cmd:. msm_plot, type(weights)}{p_end}
{phang2}{cmd:. msm_plot, type(balance)}{p_end}

{pstd}
{bf:Cross-contrast summary.}  Loop over several pairwise contrasts, each on its
own weighted panel, accumulate one diagnostic row per contrast, then export the
accumulated frame as a single sheet with {helpb msm_diagtab}:{p_end}

{phang2}{cmd:. capture frame drop wd}{p_end}
{phang2}{cmd:. foreach c in classA classB {c -(}}{p_end}
{phang2}{cmd:.     use panel_`c'.dta, clear}{p_end}
{phang2}{cmd:.     msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) covariates(biomarker comorbidity) baseline_covariates(age sex)}{p_end}
{phang2}{cmd:.     msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:.     msm_diagnose, accumulate(wd) contrast("`c' vs platform") outcome("death")}{p_end}
{phang2}{cmd:. {c )-}}{p_end}
{phang2}{cmd:. msm_diagtab, frame(wd) xlsx("contrast_diagnostics.xlsx") replace}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_diagnose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}weight standard deviation{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile weight{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile weight{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(ess_pct)}}ESS as a percentage of total observations{p_end}
{synopt:{cmd:r(n_extreme)}}number of observations with extreme weights (above P99){p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}covariate balance matrix (columns: raw_smd, weighted_smd, pct_change){p_end}

{pstd}
When {opt accumulate(name)} is specified, {cmd:msm_diagnose} also appends one
summary row to the named frame (see the {help msm_diagnose##options:Options});
this is a side effect and is not part of {cmd:r()}.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}
