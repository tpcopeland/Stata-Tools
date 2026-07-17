{smcl}
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
{synopt:{opt accum:ulate(name)}}append a diagnostic row to a named frame{p_end}
{synopt:{opt cont:rast(string)}}label for the accumulated diagnostic row{p_end}
{synopt:{opt out:come(string)}}outcome label for the accumulate row{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_diagnose} is the diagnostic step that should follow every
{helpb msm_weight} run. It answers two key questions:

{phang2}1. {bf:Are the weights well-behaved?} It reports the full weight
distribution (mean, SD, percentiles, min, max), the effective sample size
(ESS), and per-treatment-group summaries.{p_end}

{phang2}2. {bf:Did weighting achieve longitudinal covariate balance?} It
computes treatment SMDs within period and prior-treatment history, reports
period-specific propensity support and ESS, and reports censoring balance
separately when IPCW was fitted.{p_end}

{pstd}
This command does not change observations or create/drop data variables. It
reads the {cmd:_msm_weight} variable created by {helpb msm_weight} and the
variable mapping stored by {helpb msm_prepare}. It does store diagnostic state
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

{phang2}{bf:Mean {c ~} 1.0:} Stabilized weights should have a mean near 1. A mean far from 1 suggests
model misspecification.{p_end}

{phang2}{bf:Effective sample size (ESS):} Measures the effective information
retained after weighting. ESS = (sum w)^2 / (sum w^2). If ESS is well below
50% of N, weight variability is high and the analysis will have wide confidence
intervals. Consider stronger truncation or a simpler weight model.{p_end}

{phang2}{bf:Extreme weights:} Large maximum weights indicate near-positivity
violations. Use {cmd:by_period} to identify which periods are affected, and
consider period-specific investigation or truncation.{p_end}

{pstd}
{bf:Longitudinal covariate balance:}

{phang2}{bf:Period and treatment history first:} The primary treatment-balance
matrix compares treated and untreated decisions separately at each period and,
after baseline, within prior-treatment strata. Opposite imbalances can cancel
in a pooled person-period SMD.{p_end}

{phang2}{bf:Balance targets:} A {cmd:target} value of 1 marks denominator-only
covariates expected to balance. Stabilized-numerator covariates have
{cmd:target=0}: the numerator intentionally retains their target distribution,
so they must also enter the outcome model rather than be declared balanced
away.{p_end}

{phang2}{bf:Censoring separately:} When IPCW is present, censoring SMDs are
reported by period in the censoring decision risk set. The diagnostic carries
forward prior uncensoring factors and replaces the current all-uncensored IPCW
factor with the stabilized factor for the observed censoring decision. This
permits a valid comparison of currently censored and uncensored groups. The
censoring SMDs are not folded into the treatment table.{p_end}

{phang2}{bf:SMD < 0.1:} The standard threshold for acceptable balance. SMDs
above 0.1 after weighting suggest residual confounding for that variable.{p_end}

{phang2}{bf:Secondary pooled % change:} A large negative change means weighting improved
balance. A positive change means weighting made balance worse for that
covariate, which warrants investigation.{p_end}

{phang2}The legacy pooled table marks covariates exceeding the threshold with
{cmd:*}; treat it as a secondary person-period summary, not the primary
longitudinal balance decision.{p_end}


{marker options}{...}
{title:Options}

{phang}
{opth balance_covariates(varlist)} specifies which covariates to assess for
balance. The command computes SMDs between treated and untreated groups both
without weights (raw) and with the IP weights. If omitted, all covariates
from {helpb msm_prepare} (both {cmd:covariates()} and
{cmd:baseline_covariates()}) are used.

{phang}
{opt by_:period} displays weight distribution statistics (N, mean, SD, min,
max) separately for each time period. This is useful for identifying periods
where weights become extreme or where the weight model breaks down.

{phang}
{opt threshold(#)} sets the SMD threshold for declaring acceptable balance. The
default is {cmd:0.1}, following common epidemiological practice. Covariates with a
weighted absolute SMD exceeding this threshold are flagged in the output. The
balance summary reports how many covariates are balanced versus imbalanced.

{phang}
{opt accumulate(name)} appends one summary row for the current weighted panel
to the named {help frames:frame}, creating the frame with a fixed schema on
first use. This is intended for loops over many pairwise contrasts, where each
contrast is fit on its own weighted person-period panel: accumulate the
per-contrast diagnostics into one frame, then export the whole frame as a
single styled sheet with {helpb msm_diagtab}. Everything {cmd:msm_diagnose}
otherwise does (console display, {cmd:r()} results, and dataset
characteristics) is unchanged when {cmd:accumulate()} is given. The frame holds
the columns {cmd:contrast}, {cmd:outcome}, {cmd:n_obs} (person-periods),
{cmd:ess}, {cmd:ess_pct}, {cmd:max_weight}, {cmd:p99_weight}, {cmd:n_extreme},
{cmd:n_imbalanced}, and {cmd:max_abs_smd}. The two balance columns
({cmd:n_imbalanced} and {cmd:max_abs_smd}) are populated whenever balance is
assessed -- which includes the default case where {cmd:balance_covariates()} is
omitted but covariates were registered with {helpb msm_prepare} -- and are left
missing only when there are no covariates to assess.

{phang}
{opt contrast(string)} supplies the contrast label written to the
{cmd:contrast} column of the accumulate row. It is {bf:required} whenever
{cmd:accumulate()} is given.

{phang}
{opt outcome(string)} supplies an optional outcome label written to the
{cmd:outcome} column of the accumulate row. It is left empty if not given.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Basic diagnostics with default covariates.} Uses all covariates from
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
{phang2}{cmd:. matrix list r(treatment_balance)}{p_end}
{phang2}{cmd:. matrix list r(support)}{p_end}
{phang2}{cmd:. capture matrix list r(censor_balance)}{p_end}
{phang2}{cmd:. matrix list r(balance)} {it:// secondary pooled summary}{p_end}

{pstd}
{bf:Visualizing the diagnostics.} Follow up with {helpb msm_plot} for weight
density and Love plots:{p_end}

{phang2}{cmd:. msm_plot, type(weights)}{p_end}
{phang2}{cmd:. msm_plot, type(balance)}{p_end}

{pstd}
{bf:Cross-contrast summary.} Loop over several pairwise contrasts, each on its
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
{synopt:{cmd:r(treatment_balance)}}primary period/history-specific treatment balance{p_end}
{synopt:{cmd:r(censor_balance)}}separate period-specific censoring balance, when IPCW exists{p_end}
{synopt:{cmd:r(support)}}period-specific propensity overlap and ESS{p_end}
{synopt:{cmd:r(balance)}}secondary pooled person-period balance matrix{p_end}

{pstd}
{cmd:r(treatment_balance)} has columns {cmd:period}, {cmd:history},
{cmd:covariate}, {cmd:raw_smd}, {cmd:weighted_smd}, {cmd:n_treated},
{cmd:n_untreated}, {cmd:ess}, and {cmd:target}. At the common baseline,
{cmd:history=-1}; later rows use prior treatment 0 or 1. The numeric covariate
index follows the order supplied to {cmd:balance_covariates()}.

{pstd}
{cmd:r(censor_balance)} has columns {cmd:period}, {cmd:covariate},
{cmd:raw_smd}, {cmd:weighted_smd}, {cmd:n_censored}, {cmd:n_uncensored}, and
{cmd:ess}. Its weighted SMD and ESS use the cumulative observed-decision
censoring weight: prior periods retain their uncensoring factors and the
current period uses the stabilized probability of the observed censoring
status. {cmd:r(support)} has columns {cmd:period}, {cmd:N}, {cmd:treated},
{cmd:untreated}, {cmd:ps_min}, {cmd:ps_max}, {cmd:common_lo}, {cmd:common_hi},
{cmd:n_outside}, and {cmd:ess}.

{pstd}
The backward-compatible {cmd:r(balance)} has columns {cmd:raw_smd},
{cmd:weighted_smd}, and {cmd:pct_change}; it pools person-period rows and is
therefore secondary.

{pstd}
When {opt accumulate(name)} is specified, {cmd:msm_diagnose} also appends one summary row
to the named frame (see the {help msm_diagnose##options:Options}); this is a side effect and is not part of
{cmd:r()}.


{marker references}{...}
{title:References}

{phang}
Adenyo D, Guertin JR, Candas B, Sirois C, Talbot D. 2024. Evaluation and
comparison of covariate balance metrics in studies with time-dependent
confounding. {it:Statistics in Medicine}. doi:10.1002/sim.10188.{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
