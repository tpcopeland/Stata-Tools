{smcl}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "psdash_combined##syntax"}{...}
{viewerjumpto "Description" "psdash_combined##description"}{...}
{viewerjumpto "Options" "psdash_combined##options"}{...}
{viewerjumpto "Examples" "psdash_combined##examples"}{...}
{viewerjumpto "Stored results" "psdash_combined##results"}{...}
{viewerjumpto "Author" "psdash_combined##author"}{...}
{title:Title}

{p2colset 5 28 30 2}{...}
{p2col:{cmd:psdash combined} {hline 2}}Run the coordinated diagnostics dashboard{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:psdash combined} [{it:treatment}] [{it:psvar}] {ifin}
[{cmd:,} {it:options}]

{pstd}
See {help psdash##subcommands:Subcommand syntax} for the full signature and
{help psdash##options:Options} for every option, default, and interaction.

{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash combined} coordinates overlap, balance, weight, and support panels; its
shared analysis sample requires the treatment, propensity scores, and requested
covariates; an automatically generated weight does not silently remove a
positivity-boundary observation. Undefined requested weights instead fail before
any panel runs. Its verdict is driven by documented panel thresholds, and its
machine-readable findings identify the panel responsible. For longitudinal
producer contracts it routes to period-specific diagnostics.

{pstd}
Once a longitudinal producer contract is detected, {cmd:combined} routes
directly to period diagnostics. {opt report()}, {opt saving()}, {opt scheme()},
{opt supportgraph}, and {opt nooverlap}, {opt nobalance}, {opt noweights}, or
{opt nosupport} are rejected with {cmd:r(198)}. A nondefault
{opt threshold()}, {opt overlapmax()}, {opt essmin()}, {opt imbalmax()}, or
{opt gpsfloor()} is also rejected with {cmd:r(198)}. The defaults are accepted
but do not alter period diagnostics; {opt title()}, {opt dryrun}, and explicit
input overrides remain available. The longitudinal engine diagnoses the
producer's treatment, propensity score, and weight: {opt covariates()} and
{opt psvars()} are not allowed, {opt reference()} is allowed only as the
reference level 0 of the 0/1 treatment, and {opt estimand()} must match the producer's
estimand (ignoring case); any other value is an error ({cmd:r(198)}).

{pstd}
For longitudinal diagnostics, period values must produce distinct Stata matrix
row names (for example, values such as {cmd:-1} and {cmd:.1} can both normalize to
{cmd:p_1}); recode such periods to distinct integer indices before running the
command. Non-integer period values, including float-stored periods, are
supported. The longitudinal route reports its period-specific diagnostics and
does not run the cross-sectional panel workflow or produce a report workbook.

{pstd}
After {cmd:msm_weight}, the diagnosed weight defaults to the analysis weight {cmd:msm_fit}
uses ({cmd:_msm_weight}: treatment times censoring weight, after any
truncation); the output and {cmd:r(weight_role)} say which weight was
diagnosed. Specify {cmd:wvar(_msm_tw_weight)} to diagnose the treatment-only weight
instead; it is untruncated, so it is the right input when deciding on
truncation, and it reproduces the numbers psdash 1.7.5 reported. Diagnostics
are restricted to msm's treatment-decision risk set: the variable named by the
{cmd:_msm_risk_var} characteristic (msm contract 1.1) or, under contract 1.0,
{cmd:_msm_decision_risk}. Rows after the outcome or censoring are excluded by design
and counted in {cmd:r(n_outside_risk)}, not reported as incomplete.

{pstd}
For a binary treatment the dashboard graph is a 2x2 grid: PS overlap density,
covariate balance (Love plot), weight distribution, and a {bf:Diagnostic Summary}
scorecard. The scorecard states the overall verdict ({cmd:PASS} in green or {cmd:FAIL} in
red, identical to {cmd:r(verdict)}) and the number of findings, then one row per
executed panel with its key metrics, an {cmd:OK} or {cmd:Flag} status, and, for a flagged
panel, its findings, wrapped onto at most two lines and abbreviated with "..."
when longer; the full list is in {cmd:r(warnings)}. The common-support analysis
still runs and feeds the verdict, the stored results, and the report workbook,
but its density graph, which repeats the overlap density, is not
drawn; specify {opt supportgraph} to show it in place of the scorecard. With
{opt nooverlap}, the support density takes the overlap panel's place so the support
bounds stay visible. Suppressed panels are omitted from the
scorecard. Multi-group dashboards keep their overlap, balance, weight, and
support panels.

{pstd}
Each cross-sectional panel prints a descriptive status line ({cmd:WARNING} or
{cmd:IMBALANCED} when it has a finding). The machine-readable verdict is
{cmd:r(verdict)}, {cmd:PASS} or {cmd:FAIL}; any panel finding makes it
{cmd:FAIL}.

{pstd}
The complete return contract, including {cmd:r(verdict)},
{cmd:r(n_warnings)}, and {cmd:r(warnings)}, is listed under
{help psdash##results:Stored results}.

{marker options}{...}
{title:Options}

{phang}
{opt cov:ariates(varlist)} specifies covariates for the balance panel and accepts
factor-variable and interaction notation.

{phang}
{opt w:var(varname)} specifies existing diagnostic weights.

{phang}
{opt thr:eshold(#)} sets the absolute-SMD cutoff; default is {cmd:0.1}. It must
be positive and is validated even when the balance panel is skipped.

{phang}
{opt overlap:max(#)} sets the maximum tolerated percent outside binary-treatment
common support. Multi-group verdicts use {opt gpsfloor()} instead.

{phang}
{opt ess:min(#)} sets the minimum tolerated overall ESS percentage; independent
weight findings such as per-arm collapse, variability, and extremes remain
active.

{phang}
{opt imbal:max(#)} sets the tolerated number of SMD-imbalanced covariates, while
variance-ratio findings remain active.

{phang}
{opt noo:verlap} skips the overlap panel.

{phang}
{opt nob:alance} skips the balance panel.

{phang}
{opt now:eights} skips the weight panel.

{phang}
{opt nos:upport} skips the support panel.

{phang}
{opt supportg:raph} shows the common-support density panel instead of the
Diagnostic Summary scorecard in a binary-treatment dashboard (the earlier
layout). It changes only the graph; the support analysis, verdict,
and stored results are the same either way. It has no effect for multi-group
treatments, whose dashboards always show the support panel; a note says so.

{phang}
{opt dry:run} resolves inputs without running diagnostic panels.

{phang}
{opt rep:ort(filename)} writes the combined report workbook. If the workbook
cannot be written, the remaining panels still run and print once,
{opt saving()} still runs, {cmd:r(report)} is not set, and the command exits
with the write error.

{phang}
{opt sav:ing(filename)} saves the combined graph.

{phang}
{opt sch:eme(schemename)} sets the graph scheme; series colours follow it.

{phang}
{opt ti:tle(string)} sets the combined graph title.

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc} (case does not matter).

{phang}
{opt ref:erence(#)} selects the multi-group reference arm. For a treatment coded 0/1
only {cmd:reference(0)} is allowed.

{phang}
{opt gpsfloor(#)} sets the multi-group practical-positivity floor.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash combined foreign ps, covariates(mpg weight length)}{p_end}
{phang2}{cmd:. psdash combined foreign ps, covariates(i.rep78 c.weight##c.length) dryrun}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(longitudinal)}}longitudinal-contract indicator{p_end}
{synopt:{cmd:r(n_warnings)}}total machine-readable findings{p_end}
{synopt:{cmd:r(n_panels)}}diagnostic panels run{p_end}
{synopt:{cmd:r(overlapmax)}}overlap threshold used{p_end}
{synopt:{cmd:r(essmin)}}ESS threshold used{p_end}
{synopt:{cmd:r(imbalmax)}}imbalance threshold used{p_end}
{synopt:{cmd:r(N_requested)}}observations requested{p_end}
{synopt:{cmd:r(N_analysis)}}common analysis observations{p_end}
{synopt:{cmd:r(n_common_excluded)}}observations excluded from all panels{p_end}
{synopt:{cmd:r(n_excluded)}}observations excluded{p_end}
{synopt:{cmd:r(n_estimation)}}estimation-sample observations assessed{p_end}
{synopt:{cmd:r(K)}}number of treatment groups{p_end}
{synopt:{cmd:r(max_pct_outside)}}maximum period percent outside{p_end}
{synopt:{cmd:r(n_ps_boundary)}}longitudinal PS values at 0 or 1{p_end}
{synopt:{cmd:r(n_neg_wt)}}negative contract weights{p_end}
{synopt:{cmd:r(n_nonpositive_wt)}}zero or negative contract weights{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}
{synopt:{cmd:r(psvar)}}propensity-score variable{p_end}
{synopt:{cmd:r(wvar)}}weight variable or {cmd:auto-generated}{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(method)}}producer method metadata{p_end}
{synopt:{cmd:r(contract_version)}}producer contract version{p_end}
{synopt:{cmd:r(id)}}longitudinal identifier{p_end}
{synopt:{cmd:r(period)}}longitudinal period variable{p_end}
{synopt:{cmd:r(regime)}}longitudinal regime metadata{p_end}
{synopt:{cmd:r(verdict)}}overall PASS or FAIL verdict{p_end}
{synopt:{cmd:r(warnings)}}finding labels{p_end}
{synopt:{cmd:r(warning_panels)}}panels with findings{p_end}
{synopt:{cmd:r(report)}}report path, when written{p_end}
{synopt:{cmd:r(iivwcomponent)}}selected iivw component{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels{p_end}
{synopt:{cmd:r(reference)}}reference treatment group{p_end}

{pstd}
The longitudinal route (an {cmd:ltmle}, {cmd:ltmle_surv}, {cmd:msm}, or
{cmd:tte} contract) also stores:

{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}longitudinal diagnostic-sample N{p_end}
{synopt:{cmd:r(N_input)}}rows in the input sample{p_end}
{synopt:{cmd:r(N_complete)}}rows with complete contract fields{p_end}
{synopt:{cmd:r(N_periods)}}number of longitudinal periods{p_end}
{synopt:{cmd:r(n_missing_treatment)}}rows missing the treatment{p_end}
{synopt:{cmd:r(n_missing_period)}}rows missing the period{p_end}
{synopt:{cmd:r(n_missing_ps)}}rows missing the propensity score{p_end}
{synopt:{cmd:r(n_missing_weight)}}rows missing the contract weight{p_end}
{synopt:{cmd:r(n_outside_risk)}}rows outside the producer risk set{p_end}
{synopt:{cmd:r(mean_wt)}}mean of the contract weights{p_end}
{synopt:{cmd:r(sd_wt)}}SD of the contract weights{p_end}
{synopt:{cmd:r(min_wt)}}minimum contract weight{p_end}
{synopt:{cmd:r(max_wt)}}maximum contract weight{p_end}
{synopt:{cmd:r(cv)}}contract-weight CV{p_end}
{synopt:{cmd:r(ess)}}overall effective sample size{p_end}
{synopt:{cmd:r(ess_pct)}}ESS as a percentage of {cmd:r(N)}{p_end}
{synopt:{cmd:r(min_period_ess_pct)}}minimum period-specific ESS percentage{p_end}
{synopt:{cmd:r(min_period_arm_ess_pct)}}minimum period-by-arm ESS percentage{p_end}
{synopt:{cmd:r(n_single_arm_periods)}}periods with only one arm{p_end}
{synopt:{cmd:r(n_estimable_periods)}}periods with both arms{p_end}
{synopt:{cmd:r(p1)}, {cmd:r(p5)}, {cmd:r(p50)}, {cmd:r(p95)}, {cmd:r(p99)}}contract-weight percentiles{p_end}
{synopt:{cmd:r(n_extreme)}}contract weights above 10{p_end}
{synopt:{cmd:r(pct_extreme)}}percentage of contract weights above 10{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(periods)}}included period values{p_end}
{synopt:{cmd:r(riskvar)}}msm risk-set indicator, when supplied{p_end}
{synopt:{cmd:r(weight_role)}}{cmd:analysis}, {cmd:treatment}, or {cmd:user-supplied}{p_end}

{p2col 5 32 34 2: Matrices}{p_end}
{synopt:{cmd:r(overlap_by_period)}}period-specific PS overlap table{p_end}
{synopt:{cmd:r(weights_by_period)}}period weight and arm-ESS table{p_end}

{pstd}
Rows of both matrices are named for the period value ({cmd:p0}, {cmd:p1}, ...),
in the order of {cmd:r(periods)}. See {help psdash##results:psdash Stored results}.

{pstd}
The longitudinal scalars are posted only by the longitudinal route. A
nonpositive contract weight is an error, so {cmd:r(n_neg_wt)} and
{cmd:r(n_nonpositive_wt)} are 0 whenever results are posted. {cmd:r(max_pct_outside)} is
missing when no period has both arms.

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_detect}

{hline}
