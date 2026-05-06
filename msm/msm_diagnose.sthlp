{smcl}
{* *! version 1.0.3  06may2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_plot" "help msm_plot"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
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
This command does not modify the dataset.  It reads the {cmd:_msm_weight}
variable created by {helpb msm_weight} and the variable mapping stored by
{helpb msm_prepare}.

{pstd}
If {cmd:balance_covariates()} is omitted, the command defaults to all
covariates registered with {helpb msm_prepare} (both time-varying and
baseline).

{pstd}
The balance results are persisted in dataset characteristics and a Stata matrix
so that {helpb msm_table} can export them to Excel.


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


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Basic diagnostics with default covariates.}  Uses all covariates from
{cmd:msm_prepare}:{p_end}

{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
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


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}
