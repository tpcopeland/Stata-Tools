{smcl}
{* *! version 1.0.6  18may2026}{...}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[R] logit" "help logit"}{...}
{viewerjumpto "Syntax" "iivw_weight##syntax"}{...}
{viewerjumpto "Description" "iivw_weight##description"}{...}
{viewerjumpto "Options" "iivw_weight##options"}{...}
{viewerjumpto "Weight types" "iivw_weight##wtypes"}{...}
{viewerjumpto "Remarks" "iivw_weight##remarks"}{...}
{viewerjumpto "Diagnostics" "iivw_weight##diagnostics"}{...}
{viewerjumpto "Troubleshooting" "iivw_weight##troubleshooting"}{...}
{viewerjumpto "What to report" "iivw_weight##reporting"}{...}
{viewerjumpto "Examples" "iivw_weight##examples"}{...}
{viewerjumpto "Stored results" "iivw_weight##results"}{...}
{viewerjumpto "References" "iivw_weight##references"}{...}
{viewerjumpto "Author" "iivw_weight##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:iivw_weight} {hline 2}}Compute inverse intensity and treatment weights{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_weight}
{cmd:,}
{opt id(varname)}
{opt time(varname)}
[{it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}subject identifier{p_end}
{synopt:{opt time(varname)}}visit time (continuous, numeric){p_end}

{syntab:Visit model (required for IIW/FIPTIW)}
{synopt:{opt vis:it_cov(varlist)}}covariates for visit intensity Cox model{p_end}

{syntab:Treatment (IPTW)}
{synopt:{opt treat(varname)}}binary treatment indicator (0/1){p_end}
{synopt:{opt treat_c:ov(varlist)}}covariates for treatment logistic model{p_end}

{syntab:Weight specification}
{synopt:{opt wt:ype(string)}}weight type: {cmd:iivw}, {cmd:iptw}, or {cmd:fiptiw}{p_end}
{synopt:{opt stab:cov(varlist)}}stabilization covariates for IIW numerator{p_end}

{syntab:Data options}
{synopt:{opt lag:vars(varlist)}}time-varying covariates to lag by one visit{p_end}
{synopt:{opt ent:ry(varname)}}study entry time per subject (default: 0){p_end}

{syntab:Reporting}
{synopt:{opt trunc:ate(# #)}}percentile trimming (e.g., {cmd:truncate(1 99)}){p_end}
{synopt:{opt gen:erate(name)}}prefix for weight variables (default: {cmd:_iivw_}){p_end}
{synopt:{opt replace}}overwrite existing weight variables{p_end}
{synopt:{opt nolog}}suppress model iteration log{p_end}
{synopt:{opt efr:on}}use Efron method for tied visit times in Cox model{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_weight} computes weights to correct for informative visit processes
in longitudinal panel data.  Three types of weights are available:

{phang2}{bf:IIW} (inverse intensity weighting) corrects for outcome-dependent
visit frequency using an Andersen-Gill recurrent-event Cox model.  Use this
when sicker patients visit the clinic more often, causing them to be
over-represented in the data.{p_end}

{phang2}{bf:IPTW} (inverse probability of treatment weighting) corrects for
confounding by indication using a cross-sectional logistic model.  Use this
when treatment assignment is driven by patient characteristics (e.g., sicker
patients are more likely to receive an active drug).{p_end}

{phang2}{bf:FIPTIW} (fully inverse probability of treatment and intensity
weighting) is the product IIW x IPTW, correcting for both sources of bias
simultaneously.  Use this when both visit frequency and treatment assignment
are driven by patient characteristics.{p_end}

{pstd}
The weight type is auto-detected: if {opt treat()} is specified, FIPTIW is
computed; otherwise, IIW only.  Override with {opt wtype()}.

{pstd}
{bf:For non-technical readers.}  The command estimates how much influence
each row should have in the later outcome model.  Visits that were very
likely under the visit model receive less influence; visits that were less
likely receive more influence.  If treatment assignment is also confounded,
the final FIPTIW weight combines this visit weight with a treatment
propensity-score weight.

{pstd}
{bf:What the command creates.}  {cmd:iivw_weight} adds one or more weight
variables to the dataset.  The final weight variable (by default
{cmd:_iivw_weight}) is used automatically by {helpb iivw_fit} in the next
step.  If you specified FIPTIW, two component variables are also created:
{cmd:_iivw_iw} (the visit intensity weight) and {cmd:_iivw_tw} (the treatment
weight).  You can change the prefix with {opt generate()}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the subject identifier.  Data must be in long
panel format with one row per subject-visit.  IIW and FIPTIW analyses
require multiple rows per subject; IPTW-only analyses may use one row per
subject.

{phang}
{opt time(varname)} specifies the visit time in continuous units (e.g., days
since baseline, months since enrollment).  Must be numeric and uniquely
identify visits within each subject.  If your time variable has ties within
a subject (e.g., two visits on the same day), resolve them first.

{dlgtab:Visit model (required for IIW/FIPTIW)}

{phang}
{opt visit_cov(varlist)} specifies covariates for the Andersen-Gill Cox model
that predicts visit frequency.  These should include factors that you believe
drive visit timing: current disease severity, recent clinical events, and any
other variables associated with when a patient comes in for a visit.  Required
for IIW and FIPTIW weights.

{pmore}
For {cmd:wtype(iptw)}, {opt visit_cov()} is optional.  The visit model is
skipped entirely, and any {opt visit_cov()} variables are ignored with a note.

{pmore}
{bf:Choosing visit covariates.}  Include variables that predict both (a) the
outcome and (b) visit frequency.  Use information that would plausibly be
available before, or at the start of, the interval leading to a visit:
baseline risk factors, previous disease score, recent adverse events, or
previous lab values.  Avoid adding many weak predictors simply because they
are available; overly complex visit models can create unstable weights.
Use {opt lagvars()} for time-varying predictors when the current visit's
measurement should not be used to explain the timing of that same visit.

{dlgtab:Treatment (IPTW)}

{phang}
{opt treat(varname)} specifies a binary (0/1) time-invariant treatment
indicator.  Each subject must have the same treatment value at every visit.
Required for IPTW or FIPTIW weights.  For time-varying treatments (e.g.,
switching drugs), consider marginal structural models (MSMs) instead.

{phang}
{opt treat_cov(varlist)} specifies covariates for the treatment propensity
score model (logistic regression).  These should include baseline
characteristics that predict treatment assignment: demographics, baseline
disease severity, comorbidities.  Required for IPTW and FIPTIW weights;
{cmd:iivw_weight} does not infer treatment-model covariates from
{opt visit_cov()}.

{pmore}
The propensity score model is fit on a cross-sectional dataset (one row per
subject) to avoid over-counting subjects with more visits.  The resulting
score is merged back to all visits for each subject.

{dlgtab:Weight specification}

{phang}
{opt wtype(string)} overrides automatic weight type detection.  Options are
{cmd:iivw}, {cmd:iptw}, or {cmd:fiptiw}.  By default, specifying {opt treat()}
triggers FIPTIW; omitting it triggers IIW.

{phang}
{opt stab:cov(varlist)} specifies covariates for the IIW stabilization
numerator model.  Without this option, the IIW weight is
{it:exp(-xb_full)}, which can be volatile.  With stabilization, a second
(simpler) Cox model is fit using only {opt stabcov()}, and the weight becomes
{it:exp(xb_stab - xb_full)}.

{pmore}
In the FIPTIW setting (Tompkins et al. 2025), the numerator model typically
includes only the treatment variable, not the time-varying confounders
that appear in the full visit model.  This stabilizes the weights while
preserving the treatment effect estimand.

{dlgtab:Data options}

{phang}
{opt lag:vars(varlist)} creates lagged versions (lag-1) of the specified
time-varying covariates within each subject.  Lagged variables are named
{it:varname}_lag1 and are automatically included in the visit intensity model
alongside any variables in {opt visit_cov()}.

{pmore}
Lagging avoids using the current visit's outcome to predict the current
visit (which is tautological).  For example, if EDSS at visit {it:t}
partly determines when visit {it:t} happens, using the previous visit's
EDSS ({cmd:edss_lag1}) is more appropriate.

{phang}
{opt entry(varname)} specifies a subject-specific study entry time.  The
default is 0 for all subjects.  This affects the start time for the first
visit's counting process interval in the Andersen-Gill model.

{pmore}
In designs with late entry or left truncation, set this to the date
(in the same units as {opt time()}) when each subject became eligible for
observation.  Ensure that entry times are strictly less than first visit
times.  Examine the weight distribution carefully in such designs, as late
entry can concentrate weight on a few early-entering subjects.

{dlgtab:Reporting}

{phang}
{opt truncate(# #)} truncates (winsorizes) weights at the specified
percentiles.  For example, {cmd:truncate(1 99)} sets all weights below the
1st percentile to the 1st percentile value, and all weights above the 99th
percentile to the 99th percentile value.  This stabilizes estimates when a
few observations have extreme weights.  Both percentile values must be
strictly between 0 and 100.

{pmore}
Truncation does not drop observations; it caps the influence of extreme
weights.  A common starting point is {cmd:truncate(1 99)}.  If you still
see extreme weights after truncation, check whether the visit model is
well-specified or whether certain subjects have unusual visit patterns.

{phang}
{opt generate(name)} specifies a prefix for generated weight variables.
Default is {cmd:_iivw_}.  Variables created include {it:prefix}iw (IIW
component), {it:prefix}tw (IPTW component), and {it:prefix}weight (final
combined weight).  The prefix must be 23 characters or fewer so derived
variables used by {cmd:iivw_fit} can also be valid Stata names.

{phang}
{opt replace} allows overwriting existing weight variables.  Without this
option, {cmd:iivw_weight} errors if any generated variable already exists.
Use this when re-running the weighting step with different options.

{phang}
{opt nolog} suppresses iteration logs from the Cox and logistic models.

{phang}
{opt efron} uses the Efron method for handling tied event times in the
Andersen-Gill Cox model.  The default is Breslow.  Efron is more accurate
when there are many tied visit times, which is common in clinic data where
visits are recorded at monthly or quarterly granularity.  This option also
matches R's {cmd:coxph()} default, which is useful when cross-validating
results against R.


{marker wtypes}{...}
{title:Weight types}

{pstd}
{bf:IIW (inverse intensity weighting)}

{pstd}
Visit intensity is modeled as an Andersen-Gill counting process where each
visit is a recurrent event.  The Cox model estimates the conditional hazard of
a visit occurring given covariates.  Subjects whose covariates predict frequent
visits receive lower weights (they are over-represented), while subjects whose
covariates predict rare visits receive higher weights (they are
under-represented).

{pstd}
Formally, the IIW weight for each observation is exp(-xb), where xb is the
linear predictor from the Cox model.  First observations per subject always
receive weight 1 because there is no prior inter-visit interval from which
to estimate intensity.

{pstd}
{bf:IPTW (inverse probability of treatment weighting)}

{pstd}
A logistic regression estimates the propensity score: the probability of
receiving treatment given measured covariates.  IPTW creates a pseudo-population
in which treatment is independent of the measured confounders, enabling an
unbiased estimate of the treatment effect.

{pstd}
IPTW weights are always stabilized using the marginal treatment prevalence as
the numerator: P(treatment)/P(treatment | covariates) for treated subjects
and (1-P(treatment))/(1-P(treatment | covariates)) for untreated subjects.
Stabilization reduces weight variability without changing the estimand.

{pstd}
The propensity model is fit on a cross-sectional dataset (one row per subject)
to avoid over-counting subjects with more visits.

{pstd}
{bf:FIPTIW}

{pstd}
The final weight is IIW x IPTW, applied to each observation.  This product
simultaneously reweights for both informative visit timing and confounding
by indication.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Data requirements}

{pstd}
Data must be in long panel format with one row per subject-visit.  Each
subject must have at least 2 visits for IIW and FIPTIW because the visit
intensity model requires repeated visits.  IPTW-only analyses may use a
single row per subject.  The {opt id()} and {opt time()} combination must
uniquely identify each row.  The {opt treat()} variable must be observed
for every row used in IPTW/FIPTIW, binary (0/1), and time-invariant within
subjects.

{pstd}
{bf:First-observation weights}

{pstd}
The first observation per subject always receives IIW weight 1, by
convention.  There is no prior visit from which to estimate intensity at
the first visit.  If visit covariates are missing for first observations,
a note is displayed and the weight remains 1.

{pstd}
{bf:Truncation}

{pstd}
Extreme weights can destabilize estimates.  The {opt truncate()} option
winsorizes weights at the specified percentiles (sets values beyond the
bounds to the boundary value, rather than dropping observations).  A common
choice is {cmd:truncate(1 99)}.  Start without truncation, inspect the
weight distribution, and add truncation if the max weight is very large
(e.g., > 10) or the effective sample size is much smaller than N.

{pstd}
{bf:Extreme propensity scores}

{pstd}
When computing IPTW or FIPTIW weights, propensity scores near 0 or 1
produce extreme weights because they appear in the denominator.
{cmd:iivw_weight} displays a note if any observations have propensity
scores below 0.01 or above 0.99, recommending {opt truncate()} to stabilize
weights.  Extreme propensity scores can indicate positivity violations
(some covariate patterns always or never receive treatment).

{pstd}
{bf:Effective sample size}

{pstd}
The effective sample size (ESS) measures how much information the weighted
sample retains relative to an unweighted sample of the same size.  It is
calculated as (sum w)^2 / sum(w^2).  An ESS much smaller than N indicates
highly variable weights that may reduce statistical power.  As a rule of
thumb, an ESS below 50% of N warrants investigating model specification or
using truncation.

{pstd}
{bf:Weight mean}

{pstd}
For a correctly specified model, the mean of the weights should be close to
1.0.  {cmd:iivw_weight} displays a note if the mean deviates from 1 by more
than 0.2.  A mean far from 1 can indicate model misspecification or data
issues.


{marker diagnostics}{...}
{title:Diagnostics}

{pstd}
After running {cmd:iivw_weight}, check the following before proceeding to
{cmd:iivw_fit}:

{phang2}1. {bf:Weight distribution.}  Run {cmd:summarize _iivw_weight, detail}.
Look at the min, max, and percentiles.  Weights with a max above 10 or a
ratio of max/min above 100 suggest the model may be struggling with certain
subjects.{p_end}

{phang2}2. {bf:Effective sample size.}  Reported by {cmd:iivw_weight}
automatically.  If ESS is much less than N, consider truncation or
simplifying the visit model.{p_end}

{phang2}3. {bf:Weight mean.}  Should be near 1.0.  A mean far from 1
suggests model misspecification.{p_end}

{phang2}4. {bf:Sensitivity to truncation.}  Compare results with and without
{opt truncate(1 99)}.  If the treatment effect changes substantially, the
estimate may be driven by a few extreme weights.{p_end}

{phang2}5. {bf:IPTW component.}  For FIPTIW, inspect {cmd:_iivw_tw}
separately.  Extreme treatment weights usually indicate positivity
violations.{p_end}


{marker troubleshooting}{...}
{title:Troubleshooting}

{pstd}
Common messages and what they usually mean:

{phang2}{bf:{cmd:treat() contains missing values}.}  Treatment is missing on
one or more visit rows.  For IPTW/FIPTIW, treatment must be observed on every
row used by the command.  Fill the baseline treatment consistently within
subject or exclude those subjects deliberately.{p_end}

{phang2}{bf:{cmd:treat() must be time-invariant within subjects}.}  A subject
changes treatment over follow-up.  This implementation is for fixed binary
treatment; use a time-varying treatment/MSM approach for treatment switching.
{p_end}

{phang2}{bf:{cmd:requires at least 2 visits per subject}.}  IIW and FIPTIW
need repeated visits because the visit process is estimated from inter-visit
intervals.  Use repeated-visit data, or use {cmd:wtype(iptw)} when treatment
weighting only is required.{p_end}

{phang2}{bf:Very large weights or very small ESS.}  This usually indicates
sparse overlap, an overly complex model, or unusual visit patterns.  Inspect
the covariates, simplify the visit or treatment model, and compare results
with {cmd:truncate(1 99)}.{p_end}

{phang2}{bf:Generated variable already exists.}  The command is protecting
variables from a previous run.  Add {opt replace} only when you intentionally
want to overwrite those variables.{p_end}


{marker reporting}{...}
{title:What to report}

{pstd}
A transparent analysis report should describe:

{phang2}(a) the weight type used ({cmd:iivw}, {cmd:iptw}, or
{cmd:fiptiw});{p_end}

{phang2}(b) the visit model covariates and whether {opt efron} tie handling
was used;{p_end}

{phang2}(c) the treatment model covariates for IPTW/FIPTIW;{p_end}

{phang2}(d) whether IIW stabilization ({opt stabcov()}) and/or percentile
truncation ({opt truncate()}) was used;{p_end}

{phang2}(e) weight diagnostics: mean, min, max, selected percentiles, and
effective sample size.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup example data}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 20260417}{p_end}
{phang2}{cmd:. set obs 320}{p_end}
{phang2}{cmd:. gen long id = ceil(_n/4)}{p_end}
{phang2}{cmd:. bysort id: gen byte visit = _n}{p_end}
{phang2}{cmd:. gen double days = (visit - 1) * 90 + runiform() * 20}{p_end}
{phang2}{cmd:. replace days = 0 if visit == 1}{p_end}
{phang2}{cmd:. gen double edss_bl = 2 + 3 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace edss_bl = edss_bl[1]}{p_end}
{phang2}{cmd:. gen double age = 35 + 15 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace age = age[1]}{p_end}
{phang2}{cmd:. gen byte sex = runiform() > 0.5}{p_end}
{phang2}{cmd:. bysort id: replace sex = sex[1]}{p_end}
{phang2}{cmd:. gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))}{p_end}
{phang2}{cmd:. bysort id: replace treated = treated[1]}{p_end}
{phang2}{cmd:. gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)}{p_end}
{phang2}{cmd:. gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))}{p_end}

{pstd}
{bf:Example 1: Basic IIW weights}

{pstd}
Correct for informative visit timing only.  The visit model includes
baseline severity, age, sex, and previous-visit values of EDSS and relapse
as predictors of when patients visit the clinic.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) nolog}{p_end}
{phang2}{cmd:. summarize _iivw_weight, detail}{p_end}

{pstd}
{bf:Example 2: FIPTIW with truncation}

{pstd}
Correct for both informative visits and treatment confounding.
{opt truncate(1 99)} caps extreme weights at the 1st and 99th percentiles.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) treat(treated) treat_cov(age sex edss_bl) truncate(1 99) nolog}{p_end}

{pstd}
{bf:Example 3: Lagged covariates in the visit model}

{pstd}
Using a lagged version of a time-varying covariate avoids the conceptual
problem of using the current visit's measurement to predict the current
visit's timing.  {opt lagvars()} creates the lagged variables automatically.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) replace nolog}{p_end}

{pstd}
{bf:Example 4: Custom variable prefix}

{pstd}
Use {opt generate()} to change the prefix of created weight variables,
which is useful when comparing different weighting specifications
side by side.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl) lagvars(edss) generate(w_) replace nolog}{p_end}

{pstd}
{bf:Example 5: IPTW only (treatment confounding without visit correction)}

{phang2}{cmd:. iivw_weight, id(id) time(days) treat(treated) treat_cov(age sex edss_bl) wtype(iptw) replace nolog}{p_end}

{pstd}
{bf:Example 6: Stabilized IIW weights}

{pstd}
Fit a simpler numerator model to stabilize the IIW weights.  This reduces
weight variability without changing the target estimand.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) stabcov(treated) replace nolog}{p_end}

{pstd}
{bf:Example 7: Efron tie handling}

{pstd}
When visit times are rounded (e.g., monthly), many subjects may share
the same visit time.  The Efron method handles these ties more accurately
than the default Breslow method.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) efron replace nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_weight} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_ids)}}number of subjects{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}standard deviation of weights{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile weight{p_end}
{synopt:{cmd:r(median_weight)}}median weight{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile weight{p_end}
{synopt:{cmd:r(ess)}}effective sample size: (sum w)^2 / sum(w^2){p_end}
{synopt:{cmd:r(n_truncated)}}number of truncated observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(weighttype)}}weight type (iivw, iptw, or fiptiw){p_end}
{synopt:{cmd:r(weight_var)}}name of final weight variable{p_end}

{p2col 5 28 32 2: Dataset characteristics}{p_end}
{synopt:{cmd:_dta[_iivw_weighted]}}flag that weights are current{p_end}
{synopt:{cmd:_dta[_iivw_id]}}subject identifier used in {opt id()}{p_end}
{synopt:{cmd:_dta[_iivw_time]}}visit time variable used in {opt time()}{p_end}
{synopt:{cmd:_dta[_iivw_weighttype]}}weight type used{p_end}
{synopt:{cmd:_dta[_iivw_weight_var]}}final weight variable name{p_end}
{synopt:{cmd:_dta[_iivw_prefix]}}generated-variable prefix{p_end}
{synopt:{cmd:_dta[_iivw_treat]}}treatment variable, if specified{p_end}


{marker references}{...}
{title:References}

{phang}
Buzkova P, Lumley T. 2007.
Longitudinal data analysis for generalized linear models with follow-up
dependent on outcome-related variables.
{it:Canadian Journal of Statistics} 35: 485-500.

{phang}
Lin H, Scharfstein DO, Rosenheck RA. 2004.
Analysis of longitudinal data with irregular, outcome-dependent follow-up.
{it:JRSS-B} 66: 791-813.

{phang}
Tompkins G, Dubin JA, Wallace M. 2025.
On flexible inverse probability of treatment and intensity weighting.
{it:Statistical Methods in Medical Research}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.0.6, 2026-05-18{p_end}


{title:Also see}

{psee}
Online:  {helpb iivw}, {helpb iivw_fit}, {helpb stcox}, {helpb logit}

{hline}
