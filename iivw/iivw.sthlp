{smcl}
{* *! version 1.2.0  24may2026}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "iivw_balance" "help iivw_balance"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "iivw_exogtest" "help iivw_exogtest"}{...}
{vieweralsosee "iivw_diagnose" "help iivw_diagnose"}{...}
{vieweralsosee "[XT] xtgee" "help xtgee"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "iivw##syntax"}{...}
{viewerjumpto "Description" "iivw##description"}{...}
{viewerjumpto "When do I need this?" "iivw##when"}{...}
{viewerjumpto "Commands" "iivw##commands"}{...}
{viewerjumpto "Choosing a weight type" "iivw##choosing"}{...}
{viewerjumpto "Practical decision guide" "iivw##decision"}{...}
{viewerjumpto "Assumptions and limits" "iivw##assumptions"}{...}
{viewerjumpto "Workflow" "iivw##workflow"}{...}
{viewerjumpto "Diagnostic workflow" "iivw##diagnostic"}{...}
{viewerjumpto "Examples" "iivw##examples"}{...}
{viewerjumpto "Stored results" "iivw##results"}{...}
{viewerjumpto "References" "iivw##references"}{...}
{viewerjumpto "Author" "iivw##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:iivw} {hline 2}}Inverse intensity of visit weighting for longitudinal data{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw}

{pstd}
Typing {cmd:iivw} without arguments displays a package overview.  The
working commands are {helpb iivw_weight}, {helpb iivw_balance},
{helpb iivw_fit}, {helpb iivw_exogtest}, and {helpb iivw_diagnose}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw} is a package for correcting informative visit processes in
longitudinal observational studies with irregular visit times.  It implements
inverse intensity weighting (IIW; Buzkova & Lumley 2007), inverse probability
of treatment weighting (IPTW), and their multiplicative combination (FIPTIW;
Tompkins et al. 2025).

{pstd}
The package provides five main commands:

{phang2}{helpb iivw_weight} computes IIW, IPTW, or FIPTIW weights{p_end}
{phang2}{helpb iivw_balance} checks weight leverage and visit-model balance{p_end}
{phang2}{helpb iivw_fit} fits unweighted or weighted outcome models via GEE or mixed effects{p_end}
{phang2}{helpb iivw_exogtest} tests whether prior outcomes predict visit timing{p_end}
{phang2}{helpb iivw_diagnose} decomposes marginal/reference-slope movement across models{p_end}

{pstd}
{bf:Plain-language summary.}  In many clinical datasets, the unit recorded
in the data is a visit, but the scientific target is a patient population.
If patients with worse disease visit more often, they appear more often in
the data and can dominate an ordinary regression.  {cmd:iivw_weight}
estimates how expected each visit was and creates weights so that frequent
visitors do not automatically receive more influence just because they have
more rows.  {cmd:iivw_balance} checks whether those weights have enough
leverage to make a null weighting movement informative.  {cmd:iivw_fit} then
fits comparable unweighted and weighted outcome models.  {cmd:iivw_exogtest}
and {cmd:iivw_diagnose} support a
diagnostic workflow for separating sampling bias from residual measurement
artifact.


{marker when}{...}
{title:When do I need this?}

{pstd}
{bf:The core problem.}  In clinic-based longitudinal studies, patients are
not observed on a fixed schedule.  Sicker patients often visit the clinic
more frequently, so they contribute more rows to the analysis dataset.
A naive regression on this data over-represents sick patients at each time
point, which biases estimates of treatment effects, disease trajectories,
and covariate associations.

{pstd}
{bf:What IIW does.}  Inverse intensity weighting down-weights observations
from patients who visit frequently (relative to what the model predicts)
and up-weights observations from patients who visit rarely.  After
reweighting, the analysis is less dominated by differential visit
frequency and, under the visit model assumptions, targets the patient
population rather than the visit process.

{pstd}
{bf:You likely need this package if:}

{phang2}(a) Your data comes from a clinical registry, electronic health
records, or any setting where visit times are determined by clinical need
rather than a protocol.{p_end}

{phang2}(b) You have longitudinal data with unequal numbers of visits per
subject, and you suspect that sicker (or healthier) patients are observed
more often.{p_end}

{phang2}(c) You want to estimate a treatment effect, disease trajectory, or
covariate association in such data and need to remove the bias introduced by
informative visit timing.{p_end}

{pstd}
{bf:You do not need this package if:}

{phang2}(a) Your data comes from a randomized trial with a fixed visit
schedule (all patients observed at the same planned time points).{p_end}

{phang2}(b) Missing visits are the main concern rather than differential
visit frequency.  For missing data due to dropout, consider inverse
probability of censoring weighting (IPCW) instead.{p_end}


{marker commands}{...}
{title:Commands}

{synoptset 20}{...}
{synopt:{helpb iivw_weight}}compute IIW/IPTW/FIPTIW weights from visit and treatment models{p_end}
{synopt:{helpb iivw_balance}}check weight leverage and visit-model covariate balance{p_end}
{synopt:{helpb iivw_fit}}fit unweighted or weighted outcome model using GEE or mixed effects{p_end}
{synopt:{helpb iivw_exogtest}}test whether prior outcomes predict visit timing{p_end}
{synopt:{helpb iivw_diagnose}}decompose marginal/reference-slope movement across models{p_end}


{marker choosing}{...}
{title:Choosing a weight type}

{pstd}
{cmd:iivw_weight} supports three types of weights.  Which one you need
depends on the sources of bias in your study:

{p2colset 5 18 60 2}{...}
{p2col:{bf:Weight type}}{bf:When to use}{p_end}
{p2col:{cmd:iivw}}Visit timing is informative (sicker patients visit more
often), but treatment assignment is either randomized or not a concern.
This is the most common case for registry data without a treatment
comparison.{p_end}
{p2col:{cmd:iptw}}Treatment assignment is non-random (confounding by
indication), but visit timing is either protocol-driven or not
informative.  This is standard propensity-score weighting.{p_end}
{p2col:{cmd:fiptiw}}Both problems are present: visit timing is informative
{it:and} treatment assignment is confounded.  The weight is the product
IIW x IPTW.  This is the most common case when comparing treatments in
registry data.{p_end}
{p2colreset}{...}

{pstd}
By default, {cmd:iivw_weight} auto-detects the weight type: if you specify
{cmd:treat()}, it computes FIPTIW; otherwise it computes IIW.  You can
override this with {cmd:wtype()}.


{marker decision}{...}
{title:Practical decision guide}

{pstd}
Use the commands as a design-specific workflow rather than as a black-box
regression wrapper.

{p2colset 5 26 62 2}{...}
{p2col:{bf:Study question}}{bf:Suggested starting point}{p_end}
{p2col:Descriptive disease trajectory in registry data}
Use {cmd:iivw_weight} with baseline predictors and lagged disease activity,
then fit a marginal GEE model with {cmd:iivw_fit}.  Compare
{cmd:timespec(linear)} with {cmd:timespec(ns(3))}.{p_end}
{p2col:Binary treatment comparison with informative visits}
Use FIPTIW: specify both {cmd:visit_cov()} and
{cmd:treat()} plus {cmd:treat_cov()}.  Inspect both the final weight and the
treatment-weight component.{p_end}
{p2col:Treatment effect changes over time}
Use {cmd:iivw_fit, interaction(treatment)} after weighting.  Interpret the
interaction on the chosen time scale and use Stata post-estimation commands
for contrasts at clinically meaningful times.{p_end}
{p2col:Sampling bias versus repeated-measurement artifact}
Fit unweighted, weighted, and measurement-adjusted models; run
{cmd:iivw_balance} and {cmd:iivw_exogtest}; then summarize the
marginal/reference time slope with {cmd:iivw_diagnose}.{p_end}
{p2colreset}{...}

{pstd}
For graduate-student projects, the safest reporting structure is to show the
unweighted result, the weighted result, the weight diagnostics, and at least
one sensitivity analysis using truncation or an alternate time specification.
For expert applications, add design justification for the visit model, the
treatment model, and any direct measurement-process adjustment.


{marker assumptions}{...}
{title:Assumptions and limits}

{pstd}
Weights correct specific measured sources of bias.  They do not, by
themselves, make a weak study design causal.  Before interpreting a weighted
model, check the following assumptions:

{phang2}(a) The visit model includes the measured variables that drive visit
timing and are related to the outcome.{p_end}

{phang2}(b) For IPTW/FIPTIW, the treatment model includes the measured
variables that drive treatment assignment; unmeasured confounding remains a
study-design limitation.{p_end}

{phang2}(c) Treatment is binary and time-invariant within subject.  This
package is not a time-varying treatment MSM implementation.{p_end}

{phang2}(d) Positivity/overlap is plausible.  Near-certain visits or
near-certain treatment assignments create extreme weights and unstable
estimates.{p_end}

{phang2}(e) Built-in standard errors treat the weights as fixed.  The
{cmd:bootstrap()} option re-samples the outcome model but does not re-fit
{cmd:iivw_weight} inside each replicate.{p_end}

{pstd}
Use IPCW methods for censoring/dropout problems, and use a time-varying
treatment method when treatment changes over follow-up.


{marker workflow}{...}
{title:Workflow}

{pstd}
A typical analysis proceeds in three steps:

{phang2}1. {bf:Compute weights} with {cmd:iivw_weight}, specifying the visit
intensity covariates and (optionally) treatment and treatment covariates.
The command creates the final weight variable (default {cmd:_iivw_weight}),
component weights when applicable, and dataset metadata used by
{cmd:iivw_fit}.{p_end}

{phang2}2. {bf:Inspect weights} using {cmd:summarize _iivw_weight, detail}.
Look for extreme values (very large max or very small min).  If the weight
distribution has heavy tails, re-run {cmd:iivw_weight} with
{cmd:truncate(1 99)} to stabilize the weights.  A mean near 1.0 is expected
for well-specified models.{p_end}

{phang2}3. {bf:Fit the outcome model} with {cmd:iivw_fit}, which reads the
weights from the dataset automatically.  The default is a GEE-style model
(GLM with clustered robust standard errors), equivalent to independence
working correlation GEE.{p_end}


{marker diagnostic}{...}
{title:Diagnostic workflow}

{pstd}
{cmd:iivw_weight} corrects bias from the observation process.  It does not
remove bias that lives inside the measurement itself, such as practice
effects from repeated cognitive testing.  The diagnostic workflow compares
how much a marginal/reference-arm time slope moves after weighting and how
much it moves after direct adjustment for the measurement process.

{pstd}
A typical diagnostic analysis proceeds as follows:

{phang2}1. Fit an unweighted outcome model with {cmd:iivw_fit, unweighted}.{p_end}
{phang2}2. Compute IIW/IPTW/FIPTIW weights with {cmd:iivw_weight}.{p_end}
{phang2}3. Check leverage and visit-model balance with {cmd:iivw_balance}.{p_end}
{phang2}4. Fit the weighted outcome model and a weighted model adjusted for
cumulative testing or another measurement-process variable with
{cmd:iivw_fit}.{p_end}
{phang2}5. Use {cmd:iivw_exogtest} to check whether lagged outcome or
disease-activity variables predict future visit or test timing.{p_end}
{phang2}6. Use {cmd:iivw_diagnose} to summarize the sampling gap,
measurement-artifact gap, and artifact share for the marginal/reference time
slope.{p_end}

{pstd}
The decomposition is descriptive.  It is intended for the marginal or
reference-arm time slope, not for a treatment x time contrast.  Treatment
contrasts may be useful sensitivity estimates, but they can be structurally
insensitive to weighting even when the marginal trajectory is biased.  If
{cmd:iivw_exogtest} suggests outcome-dependent testing, interpret the
measurement-adjusted estimate as a bound or sensitivity result rather than a
clean correction.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup: create example longitudinal data}

{pstd}
These examples use a synthetic panel dataset that mimics a clinical registry:
80 patients, each with 4 visits at irregular intervals, with a continuous
outcome (EDSS disability score), a binary treatment, and a binary event
(relapse) that also predicts future visit timing.

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
{phang2}{cmd:. gen byte treatment = cond(treated == 0, 0, cond(edss_bl < 3.5, 1, 2))}{p_end}
{phang2}{cmd:. label define arm 0 "Placebo" 1 "Low dose" 2 "High dose"}{p_end}
{phang2}{cmd:. label values treatment arm}{p_end}

{pstd}
{bf:Example 1: IIW only (correct the visit process)}

{pstd}
When the main concern is that patients with worse disease are seen more
often, but treatment assignment is either randomized or not being analyzed:

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) nolog}{p_end}
{phang2}{cmd:. iivw_balance}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) timespec(linear)}{p_end}

{pstd}
For real analyses, prefer baseline or lagged time-varying predictors in the
visit model when the current visit measurement should not be used to explain
the timing of that same visit.

{pstd}
{bf:Example 2: FIPTIW (correct both visit timing and treatment confounding)}

{pstd}
When both visit frequency and treatment assignment are driven by disease
severity, add {cmd:treat()} and {cmd:treat_cov()} to correct for both
simultaneously:

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) treat(treated) treat_cov(age sex edss_bl) truncate(1 99) replace nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)}{p_end}


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

{phang}
Pullenayegum EM. 2016.
Multiple outputation for the analysis of longitudinal data subject to
irregular observation.
{it:Statistics in Medicine} 35: 1800-1818.

{phang}
Pullenayegum EM. 2020.
IrregLong: Analysis of longitudinal data with irregular observation times.
R package. CRAN.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of available commands{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version{p_end}
{synopt:{cmd:r(commands)}}list of available commands{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.2.0, 2026-05-24{p_end}


{title:Also see}

{psee}
Online:  {helpb iivw_weight}, {helpb iivw_balance}, {helpb iivw_fit},
{helpb iivw_exogtest}, {helpb iivw_diagnose}, {helpb xtgee}, {helpb stcox}

{hline}
