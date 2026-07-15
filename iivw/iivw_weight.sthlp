{smcl}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_balance" "help iivw_balance"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "iivw_exogtest" "help iivw_exogtest"}{...}
{vieweralsosee "psdash" "help psdash"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[R] logit" "help logit"}{...}
{viewerjumpto "Syntax" "iivw_weight##syntax"}{...}
{viewerjumpto "Description" "iivw_weight##description"}{...}
{viewerjumpto "Options" "iivw_weight##options"}{...}
{viewerjumpto "Weight types" "iivw_weight##wtypes"}{...}
{viewerjumpto "Covariate strategy" "iivw_weight##covariates"}{...}
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
{synopt:{opt treat:_cov(varlist)}}covariates for treatment logistic model{p_end}

{syntab:Weight specification}
{synopt:{opt wt:ype(string)}}weight type: {cmd:iivw}, {cmd:iptw}, or {cmd:fiptiw}{p_end}
{synopt:{opt stab:cov(varlist)}}stabilization covariates for IIW numerator{p_end}

{syntab:Data options}
{synopt:{opt lag:vars(varlist)}}time-varying covariates to lag by one visit{p_end}
{synopt:{opt ent:ry(varname)}}study entry time per subject (default: 0){p_end}
{synopt:{opt cens:or(varname)}}subject-specific end of follow-up (IIW/FIPTIW){p_end}
{synopt:{opt max:fu(#)}}common end of follow-up (IIW/FIPTIW){p_end}
{synopt:{opt endatlast:visit}}follow-up ends at last visit (IIW/FIPTIW){p_end}

{syntab:Sensitivity}
{synopt:{opt trunct:reat(# #)}}percentile trimming of the IPTW component{p_end}
{synopt:{opt truncv:isit(# #)}}percentile trimming of the IIW component{p_end}
{synopt:{opt truncf:inal(# #)}}percentile trimming of the final weight{p_end}
{synopt:{opt trunc:ate(# #)}}{it:removed}; use {opt truncfinal()}{p_end}
{synopt:{opt experimentalnotreatvis:it}}FIPTIW: omit {opt treat()} from the visit model{p_end}

{syntab:Reporting}
{synopt:{opt gen:erate(name)}}prefix for weight variables (default: {cmd:_iivw_}){p_end}
{synopt:{opt replace}}overwrite existing weight variables{p_end}
{synopt:{opt nolog}}suppress model iteration log{p_end}
{synopt:{opt efr:on}}use Efron method for tied visit times in Cox model{p_end}
{synopt:{opt allownonconv:erged}}proceed when a weight model fails to converge{p_end}
{synopt:{opt allowmissingw:eights}}accept rows that receive no weight (complete-case){p_end}
{synopt:{opt base:line(entry|event)}}first visit: entry (default) or event{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_weight} computes weights to correct for informative visit processes
in longitudinal panel data. Three types of weights are available:

{phang2}{bf:IIW} (inverse intensity weighting) corrects for outcome-dependent
visit frequency using an Andersen-Gill recurrent-event Cox model. Use this
when sicker patients visit the clinic more often, causing them to be
over-represented in the data.{p_end}

{phang2}{bf:IPTW} (inverse probability of treatment weighting) corrects for
confounding by indication using a cross-sectional logistic model. Use this
when treatment assignment is driven by patient characteristics (e.g., sicker
patients are more likely to receive an active drug).{p_end}

{phang2}{bf:FIPTIW} (fully inverse probability of treatment and intensity
weighting) is the product IIW x IPTW, correcting for both sources of bias
simultaneously. Use this when both visit frequency and treatment assignment
are driven by patient characteristics.{p_end}

{pstd}
The weight type is auto-detected: if {opt treat()} is specified, FIPTIW is
computed; otherwise, IIW only. Override with {opt wtype()}.

{pstd}
{bf:For non-technical readers.} The command estimates how much influence
each row should have in the later outcome model. Visits that were very
likely under the visit model receive less influence; visits that were less
likely receive more influence. If treatment assignment is also confounded,
the final FIPTIW weight combines this visit weight with a treatment
propensity-score weight.

{pstd}
{bf:What the command creates.} {cmd:iivw_weight} adds one or more weight variables to the
dataset. The final weight variable (by default {cmd:_iivw_weight}) is used
automatically by {helpb iivw_fit} in the next step. If you specified FIPTIW, component
variables are also created: {cmd:_iivw_iw} (the visit intensity weight), {cmd:_iivw_tw}
(the treatment weight), and {cmd:_iivw_ps} (the treatment propensity score). You can
change the prefix with {opt generate()}.

{pstd}
The command also stores the expanded visit-model covariate list used by
{helpb iivw_balance}. When {opt lagvars()} is specified, this list contains
the generated lag variables, such as {cmd:severity_lag1}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the subject identifier. Data must be in long
panel format with one row per subject-visit. IIW and FIPTIW analyses
require multiple rows per subject; IPTW-only analyses may use one row per
subject.

{phang}
{opt time(varname)} specifies the visit time in continuous units (e.g., days since
baseline, months since enrollment). Must be numeric and uniquely identify
visits within each subject. If your time variable has ties within a subject
(e.g., two visits on the same day), resolve them first. For IIW/FIPTIW
weights, visit times must also be nonnegative: the visit-intensity counting
process is at risk from time 0, so visits at negative times are rejected
rather than silently excluded from the Cox model. Shift or rescale a centered
time variable before weighting. A first visit at exactly time 0 is allowed; it
spans no risk time, so it is excluded from the visit-intensity model and keeps
the conventional raw baseline weight of 1 (rescaled with the rest, as described
under {it:Mean-1 normalization}), and a note reports how many subjects are
affected.

{dlgtab:Visit model (required for IIW/FIPTIW)}

{phang}
{opt visit_cov(varlist)} specifies covariates for the Andersen-Gill Cox model
that predicts visit frequency. These should include factors that you believe
drive visit timing: current disease severity, recent clinical events, and any
other variables associated with when a patient comes in for a visit. Required
for IIW and FIPTIW weights.

{pmore}
For {cmd:wtype(iptw)}, {opt visit_cov()} is optional. The visit model is skipped entirely,
and any {opt visit_cov()} variables are ignored with a note. Other visit-model-only
options, including {opt stabcov()}, {opt lagvars()}, {opt entry()}, {opt efron}, {opt baseline()},
and the end-of-follow-up specification, are
not allowed with {cmd:wtype(iptw)} because no visit intensity model is fit.

{pmore}
{bf:Choosing visit covariates.} Include variables that predict both (a) the outcome
and (b) visit frequency. Use information that would plausibly be available
before, or at the start of, the interval leading to a visit: baseline risk
factors, previous disease score, recent adverse events, or previous lab
values. Avoid adding many weak predictors simply because they are
available; overly complex visit models can create unstable weights. Use
{opt lagvars()} for time-varying predictors when the current visit's measurement
should not be used to explain the timing of that same visit.

{dlgtab:Treatment (IPTW)}

{phang}
{opt treat(varname)} specifies a binary (0/1) time-invariant treatment
indicator. Each subject must have the same treatment value at every
visit. Required for IPTW or FIPTIW weights. For time-varying treatments (e.g.,
switching drugs), consider marginal structural models (MSMs) instead.

{phang}
{opt treat_cov(varlist)} specifies covariates for the treatment propensity score
model (logistic regression). These should include baseline characteristics
that predict treatment assignment: demographics, baseline disease severity,
comorbidities. Required for IPTW and FIPTIW weights; {cmd:iivw_weight} does not
infer treatment-model covariates from {opt visit_cov()}.

{pmore}
The propensity score model is fit on a cross-sectional dataset (one row per
subject) to avoid over-counting subjects with more visits. The resulting
score is merged back to all visits for each subject.

{dlgtab:Weight specification}

{phang}
{opt wtype(string)} overrides automatic weight type detection. Options are
{cmd:iivw}, {cmd:iptw}, or {cmd:fiptiw}. By default, specifying {opt treat()}
triggers FIPTIW; omitting it triggers IIW.

{phang}
{opt stab:cov(varlist)} specifies covariates for the IIW stabilization numerator
model. Without this option, the IIW weight is {it:exp(-xb_full)}, which can be
volatile. With stabilization, a second (simpler) Cox model is fit using only
{opt stabcov()}, and the weight becomes {it:exp(xb_stab - xb_full)}. This option is
allowed only for IIW or FIPTIW weights.

{pmore}
{bf:Constraint: name only covariates that will appear in the outcome model.} The
estimator is unbiased for the outcome-model parameters only when the
stabilization numerator is a function of the {it:outcome model} covariates (Buzkova
& Lumley 2007, who prove the weighted estimating equation has zero mean for
any numerator {it:h(X)} built from the outcome-model covariates X; Tompkins et
al. 2025 restate the same restriction). A numerator built from a visit-model
covariate that is {it:not} in the outcome model is outside that result, and
{cmd:iivw_weight} cannot detect it, because the outcome model is not specified until
{helpb iivw_fit}. Choose {opt stabcov()} as a subset of the covariates you will pass to
{cmd:iivw_fit}.

{pmore}
{bf:Recommendation.} Stabilization leaves the target estimand unchanged but
typically lowers weight variance and reduces effective-sample-size loss
(Buzkova & Lumley 2007), so a numerator model is recommended for most IIW and
FIPTIW analyses. When {opt stabcov()} is omitted, {cmd:iivw_weight} prints a
one-line note that the visit weights are unstabilized.

{dlgtab:Data options}

{phang}
{opt lag:vars(varlist)} creates lagged versions (lag-1) of the specified time-varying
covariates within each subject. Lagged variables are named {it:varname}_lag1 and
are automatically included in the visit intensity model alongside any
variables in {opt visit_cov()}. This option is allowed only for IIW or FIPTIW
weights.

{pmore}
Lagging avoids using the current visit's outcome to predict the current
visit (which is tautological). For example, if EDSS at visit {it:t}
partly determines when visit {it:t} happens, using the previous visit's
EDSS ({cmd:edss_lag1}) is more appropriate.

{phang}
{opt entry(varname)} specifies a subject-specific study entry time. The default is 0
for all subjects. This affects the start time for the first visit's counting
process interval in the Andersen-Gill model. This option is allowed only for
IIW or FIPTIW weights.

{pmore}
In designs with late entry or left truncation, set this to the date
(in the same units as {opt time()}) when each subject became eligible for
observation. Ensure that entry times are strictly less than first visit
times. Negative entry times are accepted (useful when first visits occur
at time 0), but risk time before 0 is not counted by the visit-intensity
model; a note is displayed when this applies. Examine the weight
distribution carefully in such designs, as late entry can concentrate
weight on a few early-entering subjects.

{phang}
{bf:One of} {opt censor()}, {opt maxfu()} {bf:or} {opt endatlastvisit} {bf:is required} for IIW and FIPTIW
weights. They are three ways of saying the same thing: when each subject stops
being at risk of a visit. There is no default, because no default is safe.

{pmore}
The Andersen-Gill visit-intensity model needs each subject's observation
{it:window}, not merely the intervals between their visits. Buzkova and Lumley
(2007) write the at-risk process as xi_i(t) = I(C_i > t), with C_i the drop-out
time or end of follow-up; it is C_i, not the last visit, that decides who is in
the risk set at time t. Before version 2.0.0 this command built intervals only
between observed visits, so every subject silently left the risk set at their
own last visit -- which made risk-set membership a function of the very visit
process being modeled. On a known-truth simulation that attenuated the
visit-intensity coefficient by about a quarter, and since the weights are
exp(-xb), the error propagated into every downstream estimate.

{phang}
{opt censor(varname)} gives each subject's end of follow-up: administrative
censoring, death, or loss to follow-up. It must be constant within {opt id()} and
must not be earlier than the subject's last observed visit. This is the usual
choice for registry and EHR cohorts, where follow-up ends at different times for
different people.

{phang}
{opt maxfu(#)} gives a single end of follow-up shared by every subject. It is the
convenient form when all subjects are followed for the same length of time. No
visit may occur after it.

{phang}
{opt endatlastvisit} declares that follow-up genuinely ends at each subject's
last visit -- that they were at risk of another visit right up to their final
one, and not for one moment afterwards. This is the pre-2.0.0 behavior. It is
rarely the right description of an observational cohort, and it is never the
right description of one in which people are lost to follow-up.

{pmore}
For each subject an interval (last visit, end of follow-up] with no event is
added to the model's data before fitting. It carries the covariate values in
effect when the subject was last seen; a variable named in {opt lagvars()} is
lagged correctly across it. These rows exist only inside the model -- no row is
added to your data, and no weight is computed for them.

{phang}
{opt baseline(entry|event)} controls whether each subject's first visit is study
entry or a modeled event.

{pmore}
{opt baseline(entry)}, the default, treats the first visit as study entry (risk
onset) rather than as an event in the Andersen-Gill model. The modeled events
are the follow-up visits only -- the intervals (t1,t2], (t2,t3], ... -- so the
subject becomes at risk for the visit process at the first observed
visit. This removes the circularity of conditioning the baseline visit on
baseline covariates; when {opt lagvars()} is also used, the baseline measurement
then legitimately predicts the {it:second} visit rather than itself. Subjects with
only one visit are not an error: they contribute a baseline row (raw IIW weight 1,
rescaled with the rest)
and, given an end of follow-up, an at-risk interval running out to it. At
least one subject must still have two or more visits, so the model has events
to fit. Under {opt baseline(entry)}, {opt entry()} is ignored -- the first visit defines
risk onset.

{pmore}
{opt baseline(event)} models every visit, including the baseline, as a recurrent
event. This was the default before 2.0.0. Use it only when the first observed
visit is itself part of the modeled visit process -- that is, when it was
clinically triggered rather than an enrollment event. For registry cohorts, EHR
extracts, and similar non-protocol data, the timing of the baseline visit is not
part of the informative observation process being corrected, and
{opt baseline(event)} would let its covariates predict its own occurrence.

{phang}
{bf:Migrating from 1.x.} Two defaults changed, and the old option name is gone:

{phang2}
o {cmd:nobaseevent} is now {cmd:baseline(entry)} -- and it is the default, so you
can simply delete it. The old name is rejected rather than accepted, because
Stata's {helpb syntax} cannot distinguish an explicit {cmd:baseevent} from an
omitted option (both leave the macro empty), so keeping it would have meant
silently ignoring whatever you asked for.{p_end}

{phang2}
o Code that relied on the old default now needs {cmd:baseline(event)}
{it:explicitly}.{p_end}

{phang2}
o Every IIW/FIPTIW call now needs an end-of-follow-up specification. To
reproduce 1.x weights exactly, add {cmd:endatlastvisit} -- but read the note above
first: it is very likely not what your design actually looks like, and it is
the specification that attenuates the visit-intensity coefficient.{p_end}

{dlgtab:Sensitivity}

{phang}
{bf:The supported default analysis is untruncated.} Trimming is a labelled
sensitivity analysis, never the primary result. It does not drop observations; it
caps the influence of extreme weights, and it does so by changing what is
being estimated.

{phang}
{opt trunctreat(# #)} winsorizes the {bf:IPTW component} at the given
percentiles. This is the trim the sensitivity literature actually studies: Tompkins
et al. (2025) report that trimming reduces bias when the extreme
weights arise from the {it:treatment} model (near-violations of positivity). It
is not free. Bounding an extreme propensity weight bounds the influence of
the subjects least like their counterfactual arm, so it shifts the target away
from the ATE toward the overlap population. Report it as a sensitivity
analysis and say that you did.

{phang}
{opt truncvisit(# #)} winsorizes the {bf:IIW component}. Tompkins et al. (2025)
find that trimming does {bf:not} improve estimation when the extreme weights
arise from the {it:visit} model. An extreme visit weight is a signal to
respecify the visit model, not to cap it: trimming bounds the influence of rows
the model already fitted badly, but it does not make the model fit them. Expect
{helpb iivw_balance} to get {it:worse} under this option, because a bounded
weight has less room to reweight -- that is the honest reading, and it is why
this option cannot be described as a remedy for misspecification.

{phang}
{opt truncfinal(# #)} winsorizes the {bf:final weight} after the components are
multiplied. Under FIPTIW the final weight is IIW x IPTW, so a row clipped here
could have been extreme through either factor, and this option cannot say which. Prefer
{opt trunctreat()} or {opt truncvisit()} whenever you need to know.

{pmore}
All three take percentiles strictly between 0 and 100, with the lower bound
below the upper. They compose: components are bounded first, then the product of
the bounded components. Each reports its own count and its own realized
cutpoints, and each keeps the untrimmed component beside the trimmed one --
{it:prefix}{cmd:iw_raw} and {it:prefix}{cmd:tw_raw} -- so a reader can see
exactly which rows moved and by how much.

{phang}
{opt truncate(# #)} was removed in 2.0.0 and now errors. {bf:Users of iivw 1.x:} it
clipped only the final product, so it could never report which component was
extreme, and it left {helpb iivw_balance} describing the untrimmed IIW while the
outcome model used the trimmed one. Use {opt truncfinal()} for the identical
behaviour, stated explicitly, or better, name the component with
{opt trunctreat()} or {opt truncvisit()}.

{phang}
{opt experimentalnotreatvisit} omits {opt treat()} from the visit-intensity
model under {cmd:wtype(fiptiw)}. FIPTIW exists for the design in which treatment
drives both the outcome and the monitoring schedule, so the treatment variable
belongs in the visit-intensity denominator and {cmd:iivw_weight} puts it there
by construction. Omitting it leaves the IIW factor unable to correct a visit
process that depends on treatment: the result is not the FIPTIW of the source
literature, but IIW-without-treatment multiplied by IPTW. This option exists for
sensitivity and legacy comparison only. It is outside the supported contract and
is recorded as such in the weighting contract and in {cmd:e()}.

{dlgtab:Reporting}

{phang}
{opt generate(name)} specifies a prefix for generated weight variables. Default is
{cmd:_iivw_}. Variables created include {it:prefix}iw (IIW component), {it:prefix}ps
(treatment propensity score), {it:prefix}tw (IPTW component), and {it:prefix}weight
(final combined weight). The prefix must be 23 characters or fewer so derived
variables used by {cmd:iivw_fit} can also be valid Stata names.

{phang}
{opt replace} allows overwriting existing weight variables. Without this option,
{cmd:iivw_weight} errors if any generated variable already exists. Use this when
re-running the weighting step with different options.

{phang}
{opt nolog} suppresses iteration logs from the Cox and logistic models.

{phang}
{opt allownonconv:erged} lets {cmd:iivw_weight} proceed when the
visit-intensity Cox model, the stabilization model, or the propensity model
fails to converge. By default a nonconverged model is an {bf:error}, not a
warning. A nonconverged model's linear predictor is not a fitted linear
predictor, so exp(-xb) is not a weight; letting it reach the data would stamp
an invalid weighting contract onto the dataset and every downstream command
would treat it as sound. Use this option only when you intend to inspect the
failure, never to get past it.

{phang2}
When the option is used, the resulting weights are marked as coming from a
nonconverged nuisance model, and that mark survives any later
{helpb iivw_fit}. {helpb iivw_balance} then reports {cmd:r(balance_flag)} as {cmd:unknown} and issues no
good/poor verdict: the target-SMD null assumes the visit model solves its
estimating equation, and a nonconverged one does not.

{phang}
{opt allowmissingw:eights} lets {cmd:iivw_weight} proceed when some rows receive
no final weight. By default that is an {bf:error}.

{phang2}
A row with no weight is a row that {helpb iivw_fit} will drop. Two things follow,
and only one of them is about precision. The analysis silently becomes
complete-case, which costs power. And if the missingness is
{bf:differential by treatment arm}, the analysis silently targets a different
population than the one you asked about, which costs the estimand -- and that
loss is invisible in every number the command prints.

{phang2}
A weight is missing when a row lacks an input the weight is built from: a
visit-model covariate, a treatment-model covariate, or a lag source at a first
visit that is modeled as an event. A missing {opt treat()} value is a different
matter and is refused outright: a row with no exposure has no place in a contrast
between exposure levels, and this option does not admit it.

{phang2}
When the option is used, the loss is reported and
returned: {cmd:r(n_missing_weight)}, {cmd:r(n_ids_missing_weight)}, and -- when
{opt treat()} is present -- {cmd:r(n_lost_treated)},
{cmd:r(n_lost_untreated)} and the two corresponding percentages. Report them.

{phang}
{opt efron} uses the Efron method for handling tied event times in the Andersen-Gill
Cox model. The default is Breslow. Efron is more accurate when there are many
tied visit times, which is common in clinic data where visits are recorded at
monthly or quarterly granularity. This option also matches R's {cmd:coxph()}
default, which is useful when cross-validating results against R. This option
is allowed only for IIW or FIPTIW weights.


{marker wtypes}{...}
{title:Weight types}

{pstd}
{bf:IIW (inverse intensity weighting)}

{pstd}
Visit intensity is modeled as an Andersen-Gill counting process where each
visit is a recurrent event. The Cox model estimates the conditional hazard of
a visit occurring given covariates. Subjects whose covariates predict frequent
visits receive lower weights (they are over-represented), while subjects whose
covariates predict rare visits receive higher weights (they are
under-represented).

{pstd}
Formally, the IIW weight for each observation is exp(-xb), where xb is the
linear predictor from the Cox model. The first observation per subject is
assigned a raw weight of 1, because there is no prior inter-visit interval from
which to estimate an intensity; the baseline visit is a recruitment visit,
observed with probability 1. (This is the convention used by the reference R
implementation, {cmd:IrregLong}, under its {cmd:first=TRUE} argument.) Note that
the raw weights are then rescaled to mean 1, so the {it:reported} first-visit
weight is 1/mean(exp(-xb)), not 1 -- see {it:Mean-1 normalization} below. It is
the same for every subject and carries no covariate information, which is what
the convention is for.

{pstd}
{bf:IPTW (inverse probability of treatment weighting)}

{pstd}
A logistic regression estimates the propensity score: the probability of
receiving treatment given measured covariates. IPTW creates a pseudo-population
in which treatment is independent of the measured confounders, supporting an
unbiased treatment-effect estimate under the usual exchangeability, positivity,
and correct-model assumptions.

{pstd}
IPTW weights are always stabilized using the marginal treatment prevalence as
the numerator: P(treatment)/P(treatment | covariates) for treated subjects and
(1-P(treatment))/(1-P(treatment | covariates)) for untreated
subjects. Stabilization reduces weight variability without changing the
estimand. This is the stabilized weight of Robins, Hernan & Brumback
(2000); note that the FIPTIW papers below write the treatment weight in its
{it:unstabilized} form (1/e and 1/(1-e)), so the weight {cmd:iivw_weight} reports is
proportional to theirs within each treatment arm, not identical to it.

{pstd}
The propensity model is fit on a cross-sectional dataset (one row per subject)
to avoid over-counting subjects with more visits.

{pstd}
{bf:FIPTIW}

{pstd}
The final weight is IIW x IPTW, applied to each observation. This product
simultaneously reweights for both informative visit timing and confounding
by indication.


{marker covariates}{...}
{title:Covariate strategy}

{pstd}
The visit model and treatment model answer different design questions. Do
not copy the same covariate list into both models automatically.

{p2colset 5 24 62 2}{...}
{p2col:{bf:Covariate role}}{bf:Practical placement}{p_end}
{p2col:Baseline disease severity}
Usually belongs in both {cmd:visit_cov()} and {cmd:treat_cov()} when it
predicts both follow-up intensity and treatment choice.{p_end}
{p2col:Previous outcome or recent event}
Use {cmd:lagvars()} or a precomputed lagged variable in
{cmd:visit_cov()}. This avoids using the current measurement to explain why
the current visit occurred.{p_end}
{p2col:Calendar year, clinic, access variables}
Include when they plausibly affect visit scheduling or treatment
assignment. These variables are often useful for explaining structural
patterns in registry data.{p_end}
{p2col:Post-treatment mediator}
Do not add by habit. Adjusting for mediators can change the estimand and may
remove part of the treatment effect.{p_end}
{p2col:Cumulative test count or practice-effect proxy}
Usually belongs in the outcome-model diagnostic adjustment, not in the
primary visit model, unless the scientific estimand explicitly requires it.
{p_end}
{p2colreset}{...}

{pstd}
Start with a small subject-matter model and inspect the weight
distribution. Adding many weak predictors can make the weights more variable
without improving bias correction. If the maximum weight is very large or the
effective sample size is poor, simplify the visit or treatment model before
interpreting a precise-looking weighted coefficient.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Core identifying assumption}

{pstd}
IIW is valid under {it:conditional non-informativeness} of the visit process: visit
intensity is independent of the current outcome given the covariates in the
visit-intensity model. This is the central assumption of the method. It is
broken if the {it:concurrent} outcome is placed in {opt visit_cov()}, because the current
visit's measurement is then used to explain the timing of that same visit. Use
{opt lagvars()} (or precomputed baseline/lagged values) so the visit model
conditions only on information available before each visit. {helpb iivw_exogtest} is a
falsification check for this assumption, not a proof of it.

{pstd}
{bf:Data requirements}

{pstd}
Data must be in long panel format with one row per subject-visit. By
default each subject must have at least 2 visits for IIW and FIPTIW because
the visit intensity model treats every visit as a recurrent event and so
needs repeated visits. {opt baseline(entry)}, the default, relaxes this: the baseline
visit is then treated as study entry, single-visit subjects are retained
(raw IIW weight 1, rescaled with the rest), and only one subject need have two or
more visits. IPTW-only
analyses may use a single row per subject. The {opt id()} and {opt time()}
combination must uniquely identify each row. The {opt treat()} variable must
be observed for every row used in IPTW/FIPTIW, binary (0/1), and
time-invariant within subjects.

{pstd}
{bf:Relationship to exogeneity diagnostics}

{pstd}
Lagged outcome or disease-activity variables may be used in the visit model
to estimate weights. Use {helpb iivw_exogtest} when the analysis also plans
to adjust the outcome model directly for cumulative testing or another
measurement-process variable. That diagnostic asks whether prior outcomes
predict future visit or test timing strongly enough that a direct
measurement-process adjustment should be interpreted as potentially
endogenous.

{pstd}
{bf:First-observation weights}

{pstd}
The first observation per subject receives IIW weight 1 by convention before
normalization: there is no prior visit from which to estimate intensity at the
first visit. If visit covariates are missing for first observations, a note
is displayed and the raw weight is set to 1. In every case the reported weight
is the rescaled one, 1/mean(exp(-xb)) -- never exactly 1. See
{it:Mean-1 normalization} below.

{pstd}
{bf:Mean-1 normalization}

{pstd}
The visit-intensity component ({cmd:_iivw_iw}, and hence the FIPTIW product)
is normalized to mean 1 over the estimating sample. The raw IIW weight
{cmd:exp(-xb)} has an arbitrary scale, because the Andersen-Gill Cox model
carries no intercept and its linear predictor is uncentered, so the raw weight
mean reflects covariate location rather than model fit. Rescaling to mean 1
leaves the weighted point estimates and the cluster-robust standard errors
unchanged -- a constant weight factor cancels in the estimating equation and
in both the bread and the meat of the sandwich variance -- while making the
reported weight mean, effective sample size, and {cmd:max > 10} thresholds
interpretable on a common scale. After normalization the first-observation
weight equals 1 divided by the sample mean of {cmd:exp(-xb)}, not exactly 1.

{pstd}
{bf:Truncation}

{pstd}
Extreme weights can destabilize estimates. {opt trunctreat()}, {opt truncvisit()}
and {opt truncfinal()} winsorize a {it:named} component at the specified
percentiles (values beyond the bounds are set to the boundary value; no
observation is dropped). The supported analysis is untruncated. Start there,
inspect the weight distribution, and reach for a trim only as a labelled
sensitivity analysis -- and then name the component, because trimming the
treatment weight and trimming the visit weight are different acts with
different consequences. See {it:Sensitivity} above.

{pstd}
{bf:Extreme propensity scores}

{pstd}
When computing IPTW or FIPTIW weights, propensity scores near 0 or 1 produce
extreme weights because they appear in the denominator. {cmd:iivw_weight} displays a
note if any observations have propensity scores below 0.01 or above 0.99. {opt trunctreat()}
bounds their influence as a sensitivity analysis, at the cost
of shifting the target toward the overlap population. Extreme propensity scores can
indicate positivity violations (some covariate patterns always or never
receive treatment).

{pstd}
{bf:Effective sample size}

{pstd}
The effective sample size (ESS) measures how much information the weighted
sample retains relative to an unweighted sample of the same size. It is
calculated as (sum w)^2 / sum(w^2). An ESS much smaller than N indicates
highly variable weights that may reduce statistical power. As a rule of
thumb, an ESS below 50% of N warrants investigating model specification. Trimming
will raise the ESS, but raising the ESS is not the same as fixing the
model -- see {it:Sensitivity}.

{pstd}
{bf:Weight mean}

{pstd}
For a correctly specified model, the mean of the weights should be close to
1.0. {cmd:iivw_weight} displays a note if the mean deviates from 1 by more
than 0.2. A mean far from 1 can indicate model misspecification or data
issues.


{marker diagnostics}{...}
{title:Diagnostics}

{pstd}
After running {cmd:iivw_weight}, check the following before proceeding to
{cmd:iivw_fit}:

{phang2}1. {bf:Weight distribution.} Run {cmd:summarize _iivw_weight, detail}. Look at the min,
max, and percentiles. Weights with a max above 10 or a ratio of max/min above
100 suggest the model may be struggling with certain subjects.{p_end}

{phang2}2. {bf:Effective sample size.} Reported by {cmd:iivw_weight}
automatically. If ESS is much less than N, look first at the visit model
specification.{p_end}

{phang2}3. {bf:Weight mean.} Should be near 1.0. A mean far from 1
suggests model misspecification.{p_end}

{phang2}4. {bf:Sensitivity to trimming.} Compare results with and without
{opt trunctreat(1 99)}. If the treatment effect changes substantially, the
estimate may be driven by a few subjects with weak overlap.{p_end}

{phang2}5. {bf:Treatment propensity component.} For IPTW/FIPTIW, run
{cmd:psdash combined} after {cmd:iivw_weight} to inspect treatment-propensity
overlap, common support, treatment-covariate balance, and the treatment IPTW
component. Use {cmd:psdash weights, iivwcomponent(final) detail graph} for
the final analysis-weight distribution. Use {cmd:iivw_balance} for the
visit-intensity model.{p_end}


{marker troubleshooting}{...}
{title:Troubleshooting}

{pstd}
Common messages and what they usually mean:

{phang2}{bf:{cmd:treat() contains missing values}.} Treatment is missing on
one or more visit rows. For IPTW/FIPTIW, treatment must be observed on every
row used by the command. Fill the baseline treatment consistently within
subject or exclude those subjects deliberately.{p_end}

{phang2}{bf:{cmd:treat() must be time-invariant within subjects}.} A subject changes treatment over follow-up. This
implementation is for fixed binary treatment; use a time-varying treatment/MSM
approach for treatment switching. {p_end}

{phang2}{bf:{cmd:requires at least 2 visits per subject}.} IIW and FIPTIW
need repeated visits because the visit process is estimated from inter-visit
intervals. Use repeated-visit data, or use {cmd:wtype(iptw)} when treatment
weighting only is required.{p_end}

{phang2}{bf:Very large weights or very small ESS.} This usually indicates
sparse overlap, an overly complex model, or unusual visit patterns. Inspect
the covariates, simplify the visit or treatment model, and compare results
with {cmd:trunctreat(1 99)}.{p_end}

{phang2}{bf:Generated variable already exists.} The command is protecting
variables from a previous run. Add {opt replace} only when you intentionally
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

{phang2}(d) whether IIW stabilization ({opt stabcov()}) was used, and which
component -- if any -- was trimmed, at what percentiles;{p_end}

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
Correct for informative visit timing only. The visit model includes
baseline severity, age, sex, and previous-visit values of EDSS and relapse
as predictors of when patients visit the clinic.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) censor(fu_end) nolog}{p_end}
{phang2}{cmd:. summarize _iivw_weight, detail}{p_end}

{pstd}
{bf:Example 2: FIPTIW with a treatment-weight sensitivity trim}

{pstd}
Correct for both informative visits and treatment confounding. {opt trunctreat(1 99)}
caps the {it:treatment} component at the 1st and 99th percentiles, as a labelled
sensitivity analysis; the primary result should be the untrimmed one. Note that
{cmd:treat(treated)} also enters the visit-intensity model automatically under
{cmd:wtype(fiptiw)}.

{pstd}
The two {cmd:psdash} commands below are optional. Install {cmd:psdash} before
running them if needed:

{phang2}{cmd:. net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace}{p_end}

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) treat(treated) treat_cov(age sex edss_bl) trunctreat(1 99) replace censor(fu_end) nolog}{p_end}
{phang2}{cmd:. psdash combined}{p_end}
{phang2}{cmd:. psdash weights, iivwcomponent(final) detail graph}{p_end}
{phang2}{cmd:. iivw_balance, agrefit nolog}{p_end}

{pstd}
{bf:Example 3: Lagged covariates in the visit model}

{pstd}
Using a lagged version of a time-varying covariate avoids the conceptual
problem of using the current visit's measurement to predict the current
visit's timing. {opt lagvars()} creates the lagged variables automatically.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) replace censor(fu_end) nolog}{p_end}

{pstd}
{bf:Example 4: Custom variable prefix}

{pstd}
Use {opt generate()} to change the prefix of created weight variables,
which is useful when comparing different weighting specifications
side by side.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl) lagvars(edss) generate(w_) replace censor(fu_end) nolog}{p_end}

{pstd}
{bf:Example 5: IPTW only (treatment confounding without visit correction)}

{phang2}{cmd:. iivw_weight, id(id) time(days) treat(treated) treat_cov(age sex edss_bl) wtype(iptw) replace nolog}{p_end}

{pstd}
{bf:Example 6: Stabilized IIW weights}

{pstd}
Fit a simpler numerator model to stabilize the IIW weights. This reduces
weight variability without changing the target estimand.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) stabcov(treated) replace censor(fu_end) nolog}{p_end}

{pstd}
{bf:Example 7: Efron tie handling}

{pstd}
When visit times are rounded (e.g., monthly), many subjects may share
the same visit time. The Efron method handles these ties more accurately
than the default Breslow method.

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) efron replace censor(fu_end) nolog}{p_end}


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
{synopt:{cmd:r(ess_ratio)}}{cmd:r(ess)} / {cmd:r(N_weighted)}; 1.0 = no variability{p_end}
{synopt:{cmd:r(N_total)}}rows in the analysis sample{p_end}
{synopt:{cmd:r(N_weighted)}}rows that carry a weight{p_end}
{synopt:{cmd:r(n_unweighted)}}rows with no weight, from missing model inputs{p_end}
{synopt:{cmd:r(n_missing_weight)}}same count, as the sample-loss contract reports it{p_end}
{synopt:{cmd:r(n_ids_missing_weight)}}subjects with at least one unweighted row{p_end}
{synopt:{cmd:r(n_lost_treated)}}unweighted rows among the treated ({opt treat()} only){p_end}
{synopt:{cmd:r(n_lost_untreated)}}unweighted rows among the untreated ({opt treat()} only){p_end}
{synopt:{cmd:r(pct_lost_treated)}}percent of treated rows lost ({opt treat()} only){p_end}
{synopt:{cmd:r(pct_lost_untreated)}}percent of untreated rows lost ({opt treat()} only){p_end}
{synopt:{cmd:r(n_ids_total)}}subjects in the analysis sample{p_end}
{synopt:{cmd:r(n_ids_weighted)}}subjects with at least one weighted row{p_end}
{synopt:{cmd:r(n_truncated)}}rows clipped by {opt truncfinal()}{p_end}
{synopt:{cmd:r(truncvisit)}}the {opt truncvisit()} percentiles, if used{p_end}
{synopt:{cmd:r(trunctreat)}}the {opt trunctreat()} percentiles, if used{p_end}
{synopt:{cmd:r(truncfinal)}}the {opt truncfinal()} percentiles, if used{p_end}
{synopt:{cmd:r(n_trunc_visit)}}rows clipped by {opt truncvisit()}{p_end}
{synopt:{cmd:r(trunc_visit_lo)}}realized lower cutpoint of {opt truncvisit()}{p_end}
{synopt:{cmd:r(trunc_visit_hi)}}realized upper cutpoint of {opt truncvisit()}{p_end}
{synopt:{cmd:r(iw_raw_var)}}the untrimmed IIW component, if {opt truncvisit()}{p_end}
{synopt:{cmd:r(n_trunc_treat)}}rows clipped by {opt trunctreat()}{p_end}
{synopt:{cmd:r(trunc_treat_lo)}}realized lower cutpoint of {opt trunctreat()}{p_end}
{synopt:{cmd:r(trunc_treat_hi)}}realized upper cutpoint of {opt trunctreat()}{p_end}
{synopt:{cmd:r(tw_raw_var)}}the untrimmed IPTW component, if {opt trunctreat()}{p_end}
{synopt:{cmd:r(treat_in_visit)}}1 if {opt treat()} is in the visit-intensity model{p_end}
{synopt:{cmd:r(nobaseevent)}}1 under {opt baseline(entry)}, 0 under {opt baseline(event)}{p_end}
{synopt:{cmd:r(censor_mode)}}{cmd:censor}, {cmd:maxfu} or {cmd:lastvisit} (IIW/FIPTIW){p_end}
{synopt:{cmd:r(censor_var)}}the {opt censor()} variable, if used{p_end}
{synopt:{cmd:r(maxfu)}}the {opt maxfu()} value, if used{p_end}
{synopt:{cmd:r(n_censor_rows)}}censoring intervals added to the visit-intensity model{p_end}
{synopt:{cmd:r(visit_N)}}intervals in the visit-intensity risk set{p_end}
{synopt:{cmd:r(visit_N_sub)}}subjects in the visit-intensity risk set{p_end}
{synopt:{cmd:r(stab_N)}}intervals in the stabilization (numerator) model{p_end}
{synopt:{cmd:r(ps_N)}}subjects in the propensity model (IPTW/FIPTIW){p_end}
{synopt:{cmd:r(ps_prevalence)}}treatment prevalence in the propensity model's sample{p_end}
{synopt:{cmd:r(ps_min)}}minimum treatment propensity score (IPTW/FIPTIW){p_end}
{synopt:{cmd:r(ps_max)}}maximum treatment propensity score (IPTW/FIPTIW){p_end}
{synopt:{cmd:r(n_ps_extreme)}}extreme propensity-score observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(weighttype)}}weight type (iivw, iptw, or fiptiw){p_end}
{synopt:{cmd:r(weight_var)}}name of final weight variable{p_end}
{synopt:{cmd:r(iw_var)}}visit-intensity component variable, when created{p_end}
{synopt:{cmd:r(tw_var)}}treatment IPTW component variable, when created{p_end}
{synopt:{cmd:r(ps_var)}}treatment propensity-score variable, when created{p_end}
{synopt:{cmd:r(visit_covars)}}expanded visit-model covariates used for IIW/FIPTIW{p_end}
{synopt:{cmd:r(visit_cov_raw)}}the raw {opt visit_cov()} varlist, without the generated lags{p_end}
{synopt:{cmd:r(lagvars)}}the raw {opt lagvars()} source variables{p_end}
{synopt:{cmd:r(lag_names)}}the generated {cmd:*_lag1} columns{p_end}
{synopt:{cmd:r(owned)}}every variable name this call owns under the contract{p_end}
{synopt:{cmd:r(allowmissingweights)}}{cmd:1} if unweighted rows were accepted, else {cmd:0}{p_end}
{synopt:{cmd:r(treat_covars)}}treatment-model covariates used for IPTW/FIPTIW{p_end}
{synopt:{cmd:r(ps_estimand)}}treatment propensity-score estimand, currently {cmd:ate}{p_end}
{synopt:{cmd:r(contract_version)}}iivw metadata contract version{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(visit_b)}}visit-intensity Cox coefficients (IIW/FIPTIW){p_end}

{p2col 5 28 32 2: Dataset characteristics}{p_end}
{synopt:{cmd:_dta[_iivw_weighted]}}flag that weights are current{p_end}
{synopt:{cmd:_dta[_iivw_id]}}subject identifier used in {opt id()}{p_end}
{synopt:{cmd:_dta[_iivw_time]}}visit time variable used in {opt time()}{p_end}
{synopt:{cmd:_dta[_iivw_weighttype]}}weight type used{p_end}
{synopt:{cmd:_dta[_iivw_weight_var]}}final weight variable name{p_end}
{synopt:{cmd:_dta[_iivw_prefix]}}generated-variable prefix{p_end}
{synopt:{cmd:_dta[_iivw_iw_var]}}visit-intensity component variable, when created{p_end}
{synopt:{cmd:_dta[_iivw_tw_var]}}treatment IPTW component variable, when created{p_end}
{synopt:{cmd:_dta[_iivw_ps_var]}}treatment propensity-score variable, when created{p_end}
{synopt:{cmd:_dta[_iivw_visit_covars]}}expanded visit-model covariate list for {cmd:iivw_balance}{p_end}
{synopt:{cmd:_dta[_iivw_baseevent]}}1 under {opt baseline(entry)}, else 0{p_end}
{synopt:{cmd:_dta[_iivw_censor_mode]}}the end-of-follow-up specification (IIW/FIPTIW){p_end}
{synopt:{cmd:_dta[_iivw_censor_var]}}the {opt censor()} variable, if used{p_end}
{synopt:{cmd:_dta[_iivw_maxfu]}}the {opt maxfu()} value, if used{p_end}
{synopt:{cmd:_dta[_iivw_treat]}}treatment variable, if specified{p_end}
{synopt:{cmd:_dta[_iivw_treat_covars]}}treatment-model covariates, if specified{p_end}
{synopt:{cmd:_dta[_iivw_ps_estimand]}}treatment propensity-score estimand, currently {cmd:ate}{p_end}
{synopt:{cmd:_dta[_iivw_contract_version]}}iivw metadata contract version{p_end}


{marker references}{...}
{title:References}

{phang}
Buzkova P, Lumley T. 2007. Longitudinal data analysis for generalized linear
models with follow-up dependent on outcome-related
variables. {it:Canadian Journal of Statistics}
35(4): 485-500. doi:10.1002/cjs.5550350402.

{phang}
Lin H, Scharfstein DO, Rosenheck RA. 2004. Analysis of longitudinal data with
irregular, outcome-dependent follow-up. {it:Journal of the Royal Statistical}
{it:Society: Series B (Statistical Methodology)}
66(3): 791-813. doi:10.1111/j.1467-9868.2004.b5543.x.

{phang}
Coulombe J, Moodie EEM, Platt RW. 2021. Weighted regression analysis to correct
for informative monitoring times and confounders in longitudinal
studies. {it:Biometrics}
77(1): 162-174. doi:10.1111/biom.13285.

{phang}
Robins JM, Hernan MA, Brumback B. 2000. Marginal structural models and causal
inference in epidemiology. {it:Epidemiology}
11(5): 550-560. doi:10.1097/00001648-200009000-00011.

{phang}
Tompkins G, Dubin JA, Wallace M. 2025. On flexible inverse probability of
treatment and intensity weighting: Informative censoring, variable selection,
and weight trimming. {it:Statistical Methods in Medical Research}
34(5): 915-937. doi:10.1177/09622802241313289.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb iivw}, {helpb iivw_balance}, {helpb iivw_fit},
{helpb iivw_exogtest}, {helpb stcox}, {helpb logit}

{hline}
