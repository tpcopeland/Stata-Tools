{smcl}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "[XT] xtgee" "help xtgee"}{...}
{vieweralsosee "[ME] mixed" "help mixed"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{viewerjumpto "Syntax" "iivw_fit##syntax"}{...}
{viewerjumpto "Description" "iivw_fit##description"}{...}
{viewerjumpto "Options" "iivw_fit##options"}{...}
{viewerjumpto "Remarks" "iivw_fit##remarks"}{...}
{viewerjumpto "Analysis recipes" "iivw_fit##recipes"}{...}
{viewerjumpto "Interpreting results" "iivw_fit##interpreting"}{...}
{viewerjumpto "Troubleshooting" "iivw_fit##troubleshooting"}{...}
{viewerjumpto "What to report" "iivw_fit##reporting"}{...}
{viewerjumpto "Examples" "iivw_fit##examples"}{...}
{viewerjumpto "Stored results" "iivw_fit##results"}{...}
{viewerjumpto "References" "iivw_fit##references"}{...}
{viewerjumpto "Author" "iivw_fit##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:iivw_fit} {hline 2}}Fit weighted or unweighted outcome model for IIVW analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_fit}
{depvar}
[{indepvars}]
{ifin}
[{cmd:,} {it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Unweighted diagnostic fits}
{synopt:{opt unw:eighted}}fit without applying IIVW/IPTW/FIPTIW weights{p_end}
{synopt:{opt id(varname)}}subject id for {opt unweighted} fits{p_end}
{synopt:{opt time(varname)}}time variable for {opt unweighted} fits{p_end}

{syntab:Model}
{synopt:{opt mod:el(string)}}estimation method: {cmd:gee} (default) or {cmd:mixed}{p_end}
{synopt:{opt fam:ily(string)}}GEE family (default: {cmd:gaussian}){p_end}
{synopt:{opt lin:k(string)}}GEE link function (default: canonical){p_end}
{synopt:{opt times:pec(string)}}time specification; default {cmd:linear}{p_end}
{synopt:{opt int:eraction(varlist)}}create time x covariate interaction terms{p_end}
{synopt:{opt categ:orical(varlist)}}expand categorical predictors into labeled dummies{p_end}
{synopt:{opt base:cat(#)}}reference category for {opt categorical()}{p_end}
{synopt:{opt timebase:cat(#)}}reference category for categorical time{p_end}

{syntab:Standard errors}
{synopt:{opt cl:uster(varname)}}clustering variable (default: id from metadata){p_end}
{synopt:{opt vce(vcetype)}}{cmd:bootstrap} (refit) or {cmd:fixed}{p_end}
{synopt:{opt allowfailedr:eps}}accept an incomplete bootstrap{p_end}
{synopt:{opt boot:strap(#)}}{it:legacy}; prefer {opt vce()}{p_end}
{synopt:{opt refit:weights}}{it:legacy}; prefer {opt vce()}{p_end}

{syntab:Reporting}
{synopt:{opt l:evel(#)}}confidence level; default {cmd:c(level)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt allownonconv:erged}}proceed when a model fails to converge{p_end}
{synopt:{opt experimental:mixed}}acknowledge the weighted {opt model(mixed)} caveat{p_end}
{synopt:{opt replace}}overwrite generated variables{p_end}
{synopt:{opt col:lect}}enable the {cmd:collect} framework{p_end}
{synopt:{opt gee:opts(string)}}additional options passed to {cmd:glm}{p_end}
{synopt:{opt mixed:opts(string)}}additional options passed to {cmd:mixed}{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_fit} fits weighted or unweighted outcome models. Weighted fits use
weights computed by {helpb iivw_weight}; unweighted fits use the same
model-building surface without applying weights. This is useful for
diagnostic comparisons because the unweighted and weighted analyses share
time terms, categorical expansion, interaction construction, clustering, and
formatted output. The command supports GEE-equivalent estimation via
{cmd:glm} with clustered standard errors, and mixed-effects models via
{cmd:mixed}.

{pstd}
For GEE models, {cmd:glm} with {cmd:vce(cluster)} is used, which is
equivalent to GEE with independence working correlation and robust standard
errors. This is the estimation method required by IIW theory (Buzkova &
Lumley 2007).

{pstd}
For weighted fits, the command automatically retrieves the weight variable,
panel ID, time variable, and weight type from dataset characteristics stored
by {cmd:iivw_weight}. For {opt unweighted} fits, specify {opt id()} and
{opt time()} when no package metadata are present.

{pstd}
{bf:What the command does.} {cmd:iivw_fit} takes your outcome variable and
predictors, optionally builds time trend variables and interaction terms,
and fits a regression. It displays both the underlying model
output (from {cmd:glm} or {cmd:mixed}) and a formatted summary table of
effects with coefficients, standard errors, confidence
intervals, and p-values.

{pstd}
{bf:For non-technical readers.} After {cmd:iivw_weight} has made the dataset behave less
like "one row per clinic visit" and more like "one appropriately weighted
patient history," {cmd:iivw_fit} estimates the association or treatment effect of
interest in that weighted dataset. With {opt unweighted}, it estimates the
corresponding baseline model before weights are applied. The default model
reports a population-average effect with standard errors clustered by subject.


{marker options}{...}
{title:Options}

{dlgtab:Unweighted diagnostic fits}

{phang}
{opt unweighted} fits the outcome model without applying IIVW/IPTW/FIPTIW
weights. It is intended for diagnostic comparisons where the unweighted,
weighted, and measurement-process-adjusted models should use the same
outcome-model machinery.

{pmore}
When {opt unweighted} is specified, {cmd:iivw_fit} does not require prior
{cmd:iivw_weight} metadata and does not erase existing weight metadata. If
{cmd:iivw_weight} has already been run, the stored panel ID and time variable
can be reused.

{phang}
{opt id(varname)} specifies the subject identifier for {opt unweighted} fits
when no stored package metadata are present. It is used as the default
clustering variable and as the random-intercept grouping variable for
{cmd:model(mixed)}.

{phang}
{opt time(varname)} specifies the time variable for {opt unweighted} fits
when no stored package metadata are present. It is required when
{opt timespec()} is not {cmd:none} and no stored time metadata exist.

{dlgtab:Model}

{phang}
{opt model(string)} specifies the estimation method. {cmd:gee} (the default)
fits a GLM with clustered robust standard errors via {cmd:glm}, equivalent to
independence working correlation GEE. {cmd:mixed} fits a mixed-effects model
via {cmd:mixed} with a random intercept per subject (requires Stata 17+).

{phang2}
{bf:Weighted mixed models.} {cmd:model(gee)} is the defensible primary
weighted estimator: it is the marginal estimating equation that IIW theory
identifies. {cmd:model(mixed)} applies IIVW weights through a single
observation-level {cmd:[pw=]}, which Stata does not rescale across levels, so
the random-effects variance components are {it:not} consistently
weight-estimated (Rabe-Hesketh and Skrondal 2006). Under weighting, interpret
only the fixed-effect (mean) structure of a mixed fit. A {bf:weighted}
{cmd:model(mixed)} therefore requires {opt experimental:mixed}, which is how you
state that you understand the variance components it prints are not a valid
weighted estimate. For a properly weighted subject-specific model, a
multilevel-pseudolikelihood approach with level-specific weight scaling is
required and is outside the scope of this command.

{phang}
{opt family(string)} specifies the GLM family distribution for GEE models. Default
is {cmd:gaussian} (identity link, for continuous outcomes). Other common
choices: {cmd:binomial} for binary outcomes, {cmd:poisson} for count outcomes. Only used
when {cmd:model(gee)} is specified.

{phang}
{opt link(string)} specifies the GLM link function. If omitted, the canonical
link for the specified family is used (identity for gaussian, logit for
binomial, log for poisson). Override when you need a non-canonical link (e.g.,
{cmd:family(binomial) link(log)} for risk ratios).

{phang}
{opt times:pec(string)} specifies how time enters the outcome model. {cmd:linear} (default)
includes the time variable as a single linear term. {cmd:quadratic} adds time and
time-squared. {cmd:cubic} adds time, time-squared, and time-cubed. {cmd:ns(#)} uses a
natural cubic spline with {it:#} degrees of freedom, which allows flexible
nonlinear trends while remaining stable at the boundaries. {cmd:categorical} expands
the stored time variable into one indicator per non-reference time
category. {cmd:none} excludes time from the model entirely.

{pmore}
The predictor list may be empty. For example, {cmd:iivw_fit y} fits a weighted
intercept-plus-time model using the default {cmd:timespec(linear)}. With
{cmd:timespec(none)} and no predictors, the command fits a weighted intercept-only
model.

{pmore}
The time variables are built from the time variable stored by
{cmd:iivw_weight}. For polynomial specifications, variables named
{it:prefix}{cmd:time_sq} and {it:prefix}{cmd:time_cu} are created. For
natural splines, variables named {it:prefix}{cmd:tns1}, {it:prefix}{cmd:tns2},
etc. are created. For categorical time, variables named
{it:prefix}{cmd:tcat_1}, {it:prefix}{cmd:tcat_2}, etc. are created and labeled
with the time value and reference category.

{phang}
{opt interaction(varlist)} creates product terms between each specified
covariate and every time variable from {opt timespec()}. This allows
covariate effects to change over time. For example, with
{cmd:timespec(linear)}, one interaction variable is created per covariate
(covariate x time). With {cmd:timespec(quadratic)}, two are created
(covariate x time, covariate x time-squared). With {cmd:ns(#)}, {it:#}
interaction variables are created per covariate. With
{cmd:timespec(categorical)}, one interaction variable is created for each
non-reference time category per interacted covariate.

{pmore}
Not compatible with {cmd:timespec(none)}, since there are no time variables
to interact with.

{pmore}
Interaction variables are named {cmd:_iivw_ix_{it:covar}_{it:suffix}} where {it:suffix} is {cmd:time}, {cmd:tsq},
{cmd:tcu}, {cmd:tnsN}, or {cmd:tcat_N}. Names longer than 32 characters are truncated with a
warning. If truncation would produce duplicate interaction-variable names,
{cmd:iivw_fit} stops with an error so the model is not fit with a silently collapsed
interaction list.

{pmore}
If a variable in {opt interaction()} is not included in {it:indepvars}, a
note is displayed (its main effect is absent from the model).

{phang}
{opt categorical(varlist)} specifies variables in {it:indepvars} to expand
into indicator (dummy) variables. For each variable, one dummy is created per
non-reference level. If the variable has value labels, dummies are named using
sanitized labels (e.g., {cmd:_iivw_cat_highdose} for "High dose") and labeled
with "High dose (vs. Placebo)". Without value labels, numeric naming is used
(e.g., {cmd:_iivw_cat_region_2} labeled "region=2 (vs. 1)").

{pmore}
The original variable is replaced by its dummies in the predictor list. If
the variable also appears in {opt interaction()}, its dummies are interacted
with time variables. Interaction names strip the {cmd:_iivw_cat_} prefix for
readability (e.g., {cmd:_iivw_ix_highdose_time}).

{pmore}
Variables must have integer values and at least two unique levels. If
sanitized labels produce name collisions, all levels of that variable fall
back to numeric naming. Names longer than 32 characters are truncated with
a note.

{phang}
{opt basecat(#)} specifies the reference (base) category for all variables in
{opt categorical()}. Must be an integer. If the specified value is not found
in a variable's levels, the lowest value is used with a note. Requires
{opt categorical()}.

{phang}
{opt timebasecat(#)} specifies the reference time category when
{cmd:timespec(categorical)} is used. The default is the lowest observed time
value in the estimation sample. If {opt timebasecat()} is specified but not
observed, {cmd:iivw_fit} uses the lowest observed time value and displays a
note.

{dlgtab:Standard errors}

{phang}
{opt cluster(varname)} specifies the clustering variable for sandwich standard
errors. Default is the panel ID variable stored by {cmd:iivw_weight}. You
rarely need to change this, but it is available for designs where the
clustering level differs from the panel ID (e.g., clustering at the clinic
level when patients are nested within clinics).

{phang2}
{bf:Few clusters.} Cluster-robust standard errors are anti-conservative when
the number of clusters is modest, and IIVW weighting concentrates influence on
a few subjects, which worsens the effective-cluster count. {cmd:iivw_fit}
prints a note when fewer than 40 clusters contribute to an analytic-SE
(non-bootstrap) fit; prefer {opt bootstrap(#)} for inference in that regime.

{phang}
{opt vce(vcetype)} chooses the variance estimator. It is the contract for
standard errors; the {opt bootstrap(#)}/{opt refitweights} spellings below are
retained as a legacy alias but name each method less clearly.

{pmore}
{cmd:vce(bootstrap, reps(#) [seed(#)])} is the {bf:default for weighted fits} and
the recommended method: a subject-level bootstrap that {bf:refits} every nuisance
model inside each draw, so the interval propagates weight-estimation uncertainty
-- the practical estimator of the full sampling variability that Buzkova & Lumley
(2007) and Coulombe, Moodie & Platt (2021) derive analytically. {opt reps()}
omitted takes the release-frozen {bf:999}; fewer than 999 is allowed but stamped
{cmd:e(iivw_inference_status)}={cmd:uncleared-low-reps}. The printed interval is
the normal/Wald interval from the bootstrap covariance. An explicit {opt reps()}
must be at least 2; zero, one, and negative values are rejected rather than
being mistaken for omission. The stored method is
{cmd:e(iivw_ci_type)}={cmd:wald-normal}; percentile/BC/BCa are separate methods
and are not implied. {opt seed()}
fixes the resampling stream; with no seed, the exact pre-draw RNG
state is stored in {cmd:e(iivw_rngstate_start)} so the run is still replayable.

{pmore}
{cmd:vce(bootstrap, reps(#) fixedweights)} bootstraps with the weights held
{bf:fixed} across draws, so the interval reflects outcome-model uncertainty
only; {cmd:vce(fixed)} is the analytic cluster-robust sandwich. Both treat the
estimated weights as {bf:known} -- they {bf:omit the nuisance-estimation correction}
that both source papers put inside the sandwich. That correction can
make the interval either narrower or wider; under a correctly specified weight
model the fixed sandwich is in fact {bf:conservative (over-wide)}, because the
Buzkova-Lumley variance residualises the outcome score against the visit-model
score before squaring and that projection is orthogonal for an MLE nuisance
model. Naming one of these explicitly is the acknowledgment that the SE omits the
correction; the disclosure note still prints. {cmd:e(iivw_vce)} records which of
the three was used, and an unweighted fit keeps the cluster sandwich (no nuisance
weights to propagate).

{phang}
{opt bootstrap(#)} ({it:legacy}) specifies the number of bootstrap replicates. {cmd:bootstrap(0)}
explicitly requests the weights-known sandwich standard errors
(equivalent to {cmd:vce(fixed)}); a weighted fit with no variance option instead
takes the refit-bootstrap default. When
positive, the {cmd:bootstrap} prefix is applied with clustering at
{opt cluster()}, which defaults to the subject ID stored by
{cmd:iivw_weight}. Negative values are not allowed. Prefer {opt vce()}; a plain
{cmd:bootstrap(#)} was ambiguous because it meant fixed weights only by the
absence of {opt refitweights}. Positive legacy counts must be at least 2.

{pmore}
The legacy {opt bootstrap(#)} without {opt refitweights} treats the IIW/IPTW
weights as fixed and does not re-estimate them in each draw, so standard errors
reflect outcome-model uncertainty only. This {bf:omits the weight-estimation correction}
that both source papers put inside the sandwich: Buzkova & Lumley
(2007) add a correction for having estimated the visit-model coefficients, and
Coulombe, Moodie & Platt (2021) build the FIPTIW variance as a two-step
(Newey-McFadden) sandwich for the same reason. Omitting it does not have a fixed
direction -- under a correctly specified weight model the fixed sandwich is
conservative (over-wide), not anti-conservative. Use the default refit bootstrap
(or {opt refitweights}) to propagate weight-estimation uncertainty.

{phang}
{opt refitweights} re-estimates the IIW/IPTW/FIPTIW weights from scratch inside
every bootstrap replicate, so the resulting interval reflects both outcome
model and weight estimation uncertainty. Each replicate resamples whole
subjects (a cluster bootstrap at the {opt id()} level), recomputes the Andersen-Gill
visit-intensity model and, for FIPTIW/IPTW, the treatment propensity model on
the resampled panel using the visit/treatment specification stored by
{cmd:iivw_weight}, and then refits the outcome model with the fresh weights. The
point estimates are unchanged from the fixed-weight fit; only the standard
errors and intervals differ, and they may be larger or smaller depending on
how the visit and outcome models share covariates. {opt refitweights} requires
{opt bootstrap(#)} with {it:#} > 0, is not compatible with {opt unweighted}, resamples at the
stored subject {opt id()} (so {opt cluster()} must be that id), and needs the weighting
metadata from a preceding {cmd:iivw_weight} run. It is substantially slower than the
fixed-weight bootstrap because the weight models are refit in every replicate.

{phang}
{opt allowfailedreps} accepts a bootstrap whose replicates did not all complete.

{pmore}
A replicate can fail: a resampled panel may contain no variation in a covariate,
so the outcome model drops that term and returns a missing coefficient for it; a
nuisance model may not converge on a draw; a draw may retain no weighted rows. Stata's
{helpb bootstrap} responds by computing the variance from the replicates
that {it:did} return a number and recording the shortfall in {cmd:e(N_misreps)}. It
does not stop.

{pmore}
That subset is not random with respect to what is being estimated. The draws that
fail are the ones carrying the least information about exactly the terms whose
standard error is being reported, so the surviving standard error is
anti-conservative -- and before 2.0.0 nothing in the output said so. A measured
probe (40 subjects, a binary covariate true for 2 of them, {cmd:bootstrap(40)})
had six replicates fail and printed a standard error built from 34 draws in
silence.

{pmore}
An incomplete bootstrap is therefore an {bf:error}. {opt allowfailedreps} is how
you declare that a standard error from a subset of the draws is what you intend. Even
then the counts are reported and stored: {cmd:e(iivw_bs_reps_requested)},
{cmd:e(iivw_bs_reps_completed)},
{cmd:e(iivw_bs_reps_failed)}. The usual cause is a rare binary covariate in a
small panel; respecifying is almost always the better answer than accepting the
option.

{pmore}
{bf:Changed in 2.0.0.} Each replicate now rebuilds {opt lagvars()} from the raw
source variables, inside the resampled subject, using the same code that built
the observed weights. An earlier implementation passed the precomputed {cmd:*_lag1} columns
passed through as if they were raw covariates. That was wrong in two ways: on a
terminal censoring interval the lagged value must be the source variable's value
{it:at} the last visit, and a carried-over lag column supplies the value from two
visits back instead; and the lag construction could never be rebuilt within a
draw, so the very uncertainty the bootstrap exists to propagate was frozen at its
observed-data value in every replicate. Measured on an identity draw -- a
resample in which every subject is drawn exactly once, so the draw {it:is} the
observed panel and the weights must come back unchanged -- the old replay was off
by 22%. It is now exact.

{pmore}
Weights written by a version of {cmd:iivw} older than 2.0.0 cannot be
replayed: the raw visit covariates were not stored apart from the generated lag
columns, so the replay cannot reconstruct them. {opt refitweights} refuses such a contract
rather than falling back to the old behaviour. Re-run {cmd:iivw_weight}.

{pmore}
The compact effects table printed by {cmd:iivw_fit} reports
normal-approximation confidence intervals (coefficient {+/-} {it:z} {cmd:*} SE)
for every fit, including bootstrap fits. The full bootstrap results, including
{cmd:bootstrap}'s bias-corrected and percentile intervals, remain available in
{cmd:e()}; display them with {helpb estat bootstrap} after the command.

{dlgtab:Reporting}

{phang}
{opt level(#)} specifies the confidence level for confidence
intervals. The default is {cmd:c(level)}.

{phang}
{opt allownonconv:erged} lets {cmd:iivw_fit} proceed when the outcome model
fails to converge. By default nonconvergence is an {bf:error}: a nonconverged
fit has no valid coefficients or standard errors, and recording it as a
successful fit would let every downstream diagnostic report on numbers that
mean nothing. Use it only to inspect the failure.

{phang}
{opt experimental:mixed} is required to fit a {bf:weighted} {opt model(mixed)}. The IIW weights
enter {cmd:mixed} as a single observation-level {cmd:[pw=]}, which Stata does not rescale
across levels, so the random-effects variance components are {bf:not} consistently
weight-estimated even though they are reported (Rabe-Hesketh and Skrondal
2006). The IIW theory identifies a {it:marginal} estimator, so {opt model(gee)} is the
defensible primary weighted analysis. Specify {opt experimental:mixed} only if you
want the fixed-effect (mean) structure and accept that the variance components
are not a valid weighted estimate. Unweighted {opt model(mixed)} is unaffected and
needs no acknowledgment.

{phang}
{opt nolog} suppresses the iteration log from the underlying {cmd:glm} or
{cmd:mixed} command.

{phang}
{opt replace} allows overwriting existing time, categorical, and interaction
variables created by a previous {cmd:iivw_fit} call. Without {opt replace},
the command errors if any generated variable already exists.

{phang}
{opt col:lect} adds the {cmd:collect:} prefix to non-bootstrap
{cmd:model(gee)} fits, enabling Stata's {cmd:collect} framework for building
multi-model tables. Use this when combining results from multiple
{cmd:iivw_fit} calls into a single table via {helpb collect} or
{helpb regtab}. This option is not applied to {opt bootstrap()} fits or
{cmd:model(mixed)}.

{phang}
{opt gee:opts(string)} passes additional options directly to {cmd:glm}. Options
that would set the variance estimator ({cmd:vce()}, {cmd:robust},
{cmd:cluster()}) are rejected: {cmd:iivw} owns the variance. {cmd:irls} is
additionally rejected whenever a bootstrap variance is requested, because
{cmd:glm, irls} does not set {cmd:e(converged)} and each replicate's outcome fit
is gated on it -- a draw whose convergence cannot be verified must not enter the
variance. {cmd:irls} remains available with {cmd:vce(fixed)}.

{phang}
{opt mixed:opts(string)} passes additional options directly to {cmd:mixed}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Stabilized weights are checked against this outcome model}

{pstd}
Bůžková & Lumley (2007) define the stabilizing numerator as
h0(X{it:i}(t)) = exp({it:delta}'X{it:i}(t)), where X is the {bf:outcome-model}
covariate vector. That is not incidental notation. The stabilized estimating
equation solves for the same {it:beta} as the unstabilized one precisely because
the numerator is a function of covariates the outcome model conditions on: with
E[Y - mu(X;{it:beta}) | X] = 0, the h-weighted score is mean-zero whatever h is. Stabilize
on a variable this outcome model never sees and that argument
collapses -- the weighted fit then targets an h-weighted average of
subject-specific effects, not the {it:beta} in the table.

{pstd}
{cmd:iivw_weight} cannot check this: it runs before the outcome model exists. {cmd:iivw_fit}
can, and does. If any {opt stabcov()} variable is not a source of
this outcome design -- an independent variable, a {opt categorical()} or
{opt interaction()} source, or the panel time variable behind the fitted time
terms -- the fit stops with an error before estimating anything, and names the
offending variables. Add them to the outcome model, or recompute the weights
with a numerator this model contains. Unstabilized IIW is always valid. {cmd:e(iivw_stabilization_validated)}
records that the check ran and passed; {cmd:e(iivw_stab_terms)}
records the terms it cleared.

{pstd}
The check is deliberately conservative. A stabilization variable that is some
other deterministic function of a design covariate is defensible in theory, but
the package cannot prove that from the data, and a guard that accepts what it
cannot verify is not a guard. Put the function in the outcome model.

{pstd}
{bf:Independence working correlation}

{pstd}
The GEE model uses {cmd:glm} with {cmd:vce(cluster)}, which is mathematically
equivalent to GEE with independence working correlation and robust standard
errors. This structure is required by IIW theory: the weights correct for
the informative visit process, and the independence assumption avoids
modeling within-subject correlation (which is already accounted for by the
weights).

{pstd}
{bf:Prerequisites}

{pstd}
For weighted fits, {cmd:iivw_weight} must be run before {cmd:iivw_fit}. The weight
variable and metadata are read from dataset characteristics set by
{cmd:iivw_weight}. If you modify the dataset between the two commands (e.g.,
dropping observations or replacing variables), the metadata may become
stale. In that case, re-run {cmd:iivw_weight}.

{pstd}
For {opt unweighted} fits, prior weighting is optional. Specify {opt id()}
and {opt time()} if no stored metadata are available. Running
{cmd:iivw_fit, unweighted} after {cmd:iivw_weight} does not clear the stored
weight variable or weight metadata, so it can be used in the same dataset as
weighted comparisons.

{pstd}
{bf:Artifact-adjustment covariates and the time slope}

{pstd}
A common adjustment for a measurement artifact is to include a cumulative
measurement covariate -- a test count or visit index -- among the outcome
model's predictors. Such a covariate is usually close to collinear with
follow-up time, because a subject's k-th measurement occurs at roughly the
k-th time point. When it is, the fitted model attributes the time trend to
the test count, and the estimated marginal time slope is no longer the time
slope of the underlying outcome process: it can attenuate substantially or
reverse sign. Check the correlation between the test count and the time
variable before adding it, and do not read a marginal time slope out of a
model that adjusts for a time-collinear measurement covariate.

{pstd}
The adjustment is also not a general remedy for artifact bias in the treatment
effect. In the package's simulation gates ({cmd:sim_scenarios_abc.do},
{cmd:sim_scenario_d.do}), adding a cumulative test count to a FIPTIW-weighted
fit changed the treatment-coefficient bias only marginally, and never improved
on the FIPTIW fit without it.

{pstd}
When the artifact is {it:outcome-dependent} -- its magnitude depends on the
level of the outcome, not just on the number of prior measurements -- additive
separability fails, and no covariate adjustment of this form recovers the
truth. In {cmd:sim_scenario_e.do}, which simulates exactly this case, no
estimator recovers the marginal slope and the test-count-adjusted fit returns
a marginal slope of the wrong sign. Treat that configuration as a sensitivity
range rather than a point estimate, and see {helpb iivw_diagnose}'s
{cmd:exogeneity(endogenous)} option, which reports the weighted and adjusted
estimates as a range instead of a point decomposition.


{marker recipes}{...}
{title:Analysis recipes}

{pstd}
These are practical modeling patterns to adapt after {cmd:iivw_weight} has
created weights.

{pstd}
{bf:Population-average treatment effect.} Use the default GEE model, include
the treatment indicator and baseline confounders, and start with a simple
time specification.

{phang2}{cmd:. iivw_fit score treated age sex baseline_score, timespec(linear) nolog}{p_end}

{pstd}
{bf:What "population-average" means here, and where it stops.} With the
default {cmd:family(gaussian) link(identity)}, the fitted coefficient on an
adjusted treatment indicator is collapsible: it is a difference of weighted
means and carries the marginal reading above. On a {bf:nonlinear} link --
{cmd:family(binomial) link(logit)}, {cmd:family(poisson) link(log)}, and
anything else non-identity -- it does not. A conditional odds ratio or hazard
ratio adjusted for covariates is {bf:noncollapsible}: it differs from the
marginal contrast even when the covariates are independent of treatment and
even when every model is correctly specified, so it is not the effect of
moving the whole population from untreated to treated.

{pstd}
Confine the words {bf:ATE} and {bf:marginal causal contrast} to identity-link
specifications and to marginal structural models built for the purpose. On a
nonlinear link, either report the coefficient as the conditional association
it is, or obtain a marginal contrast explicitly with {helpb margins} after the
fit -- the weights do not make a conditional nonlinear coefficient
marginal. {helpb iivw_diagnose} enforces the same boundary: it returns
{cmd:r(decomposable) = 0} for non-identity-link fits.

{pstd}
{bf:Nonlinear disease trajectory.} Use a natural spline when the outcome
changes quickly early in follow-up and then plateaus, or when linear time is
not credible.

{phang2}{cmd:. iivw_fit score treated age sex baseline_score, timespec(ns(3)) replace nolog}{p_end}

{pstd}
{bf:Treatment effect that varies over time.} Interact the treatment
indicator with the generated time basis, then use {cmd:lincom},
{cmd:margins}, or a prespecified contrast to report effects at meaningful
follow-up times.

{phang2}{cmd:. iivw_fit score treated age sex baseline_score, timespec(ns(3)) interaction(treated) replace nolog}{p_end}

{pstd}
{bf:Diagnostic comparison.} Fit the unweighted model through the same command
surface before fitting weighted and measurement-adjusted models. Store each
model and pass the marginal/reference time coefficient to
{helpb iivw_diagnose}.

{phang2}{cmd:. iivw_fit score treated age sex baseline_score, unweighted id(id) time(months) timespec(linear) nolog}{p_end}
{phang2}{cmd:. estimates store M_unweighted}{p_end}

{pstd}
In all recipes, the unweighted and weighted models should differ only in the
weighting decision unless there is a written design reason for changing the
outcome model. This keeps sensitivity comparisons interpretable.

{pstd}
{bf:Mixed vs. GEE}

{pstd}
The GEE model (default) estimates a marginal (population-averaged) treatment
effect: the average effect of treatment across all subjects. This is what IIW
theory is designed for (Buzkova & Lumley 2007).

{pstd}
The mixed model ({cmd:model(mixed)}) adds a subject-specific random intercept
and estimates a conditional (subject-specific) treatment effect. Use it only
when a conditional interpretation is specifically needed and you understand
that the IIW theoretical justification is for marginal models. The mixed model
requires Stata 17 or later.

{pstd}
{bf:Choosing timespec}

{pstd}
The choice of time specification affects the estimated treatment
effect. {cmd:timespec(linear)} assumes a constant rate of change over time,
appropriate when the outcome trends linearly. {cmd:timespec(ns(3))} or
{cmd:timespec(ns(4))} allows flexible nonlinear trends, preferable when the outcome
trajectory has curvature (e.g., rapid early change that plateaus).

{pstd}
Practical guidance: start with {cmd:linear}, then compare to {cmd:ns(3)}. If the treatment
effect changes substantially, the relationship between time and outcome is
nonlinear and the spline specification is more appropriate. Quadratic and
cubic specifications are available but natural splines are generally more
stable at the boundaries of the time range.

{pstd}
{bf:Convergence}

{pstd}
After fitting the GEE or mixed model, {cmd:iivw_fit} checks whether the
estimation converged. If not, a warning is displayed. Non-convergence
typically indicates model misspecification, collinear predictors, or
extreme weights. This check is skipped when using {opt bootstrap()},
since the bootstrap wrapper does not expose convergence status.

{pstd}
{bf:Table export with collect and regtab}

{pstd}
{cmd:iivw_fit} is an {cmd:eclass} command and works with Stata's {cmd:collect}
framework. For non-bootstrap {cmd:model(gee)} fits, use the {opt collect}
option or the {cmd:collect:} prefix to accumulate results across models, then
export with {helpb regtab} (from the {cmd:tabtools} package; install
separately if needed). For bootstrap or {cmd:model(mixed)} fits, use Stata's
standard post-estimation/export workflow after the model is fit.

{pstd}
Generated coefficient names are short and stable so post-estimation commands
can address them exactly. Generated variable labels carry table-ready
text. For example, a labeled treatment category "Drug" interacted with
categorical time "Second visit" is stored under a coefficient name such as
{cmd:_iivw_ix_drug_tcat_1} but labeled "Drug x Visit wave: Second visit" for table
output.

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_fit score drug age severity_bl, model(gee) collect}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet(IIW) coef(Coef.) title(IIW Model)}{p_end}

{pstd}
To compare multiple weighting strategies side by side:

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl) replace censor(fu_end) nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated age, model(gee) nolog collect}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl) treat(treated) treat_cov(age) replace censor(fu_end) nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated age, model(gee) nolog collect}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet(Compare) models(IIW \ FIPTIW) coef(Coef.) stats(n)}{p_end}


{marker interpreting}{...}
{title:Interpreting results}

{pstd}
{bf:Coefficients.} With {cmd:model(gee)} and the default {cmd:family(gaussian)},
coefficients are interpreted as the change in the outcome for a one-unit
change in the predictor, averaged over the population. For example, a
coefficient of -0.7 on {cmd:treated} means that, after reweighting for
informative visit timing, treatment is associated with a 0.7-unit decrease
in the outcome on average.

{pstd}
{bf:Treatment effect.} The coefficient on the treatment variable is often the
primary quantity of interest. With IIW, IPTW, or FIPTIW weights, it is the
weighted treatment contrast implied by the selected weight type. A causal
interpretation requires the visit intensity model and, for IPTW/FIPTIW, the
propensity score model to be correctly specified, with no unmeasured
confounding and plausible positivity.

{pstd}
{bf:Time variables.} When {opt timespec()} is not {cmd:none}, the model
includes one or more time trend variables. These capture the average
trajectory of the outcome over time, after removing the effect of treatment
and other covariates. With {cmd:timespec(linear)}, the time coefficient is
the per-unit-time rate of change.

{pstd}
With {cmd:timespec(categorical)}, time is treated as a set of visit waves,
periods, or other discrete occasions. The coefficients compare each
non-reference time category with the reference time category. This is useful
for planned visits or coarse calendar periods where a smooth linear or spline
trend is not the intended estimand.

{pstd}
{bf:Interactions.} When {opt interaction(treated)} is specified, the model
includes a treatment x time product term. The coefficient on this interaction
represents how much the treatment effect changes per unit of time. A
positive interaction means the treatment becomes less protective (or more
harmful) over time; a negative interaction means it becomes more protective.

{pstd}
{bf:Standard errors.} For a {bf:weighted} fit the default is now the 999-draw
refit subject bootstrap ({cmd:vce(bootstrap)}), which re-estimates every nuisance
model inside each draw and so includes the weight-estimation term. {cmd:vce(fixed)}
requests the analytic sandwich (robust, clustered at the subject level): it is
consistent even under misspecification of the within-subject correlation
structure, but it treats the IIW/IPTW weights as if they were known rather than
estimated, and so omits the weight-estimation term that both Buzkova & Lumley
(2007) and Coulombe, Moodie & Platt (2021) carry in their sandwich. Omitting that
term does not have a fixed sign -- under a correctly specified weight model the
fixed sandwich is conservative (over-wide). An {bf:unweighted} fit keeps the
cluster sandwich as its default, since it estimates no nuisance weights. See
{opt vce()} (and the legacy {opt bootstrap()}/{opt refitweights}) in
the Options section).


{marker troubleshooting}{...}
{title:Troubleshooting}

{pstd}
Common messages and decisions:

{phang2}{bf:{cmd:data has not been weighted}.} The dataset does not contain
the metadata and weight variable created by {cmd:iivw_weight}, or those
variables were dropped. Re-run {cmd:iivw_weight} immediately before
{cmd:iivw_fit}.{p_end}

{phang2}{bf:Generated time or interaction variables already exist.} A
previous {cmd:iivw_fit} call created variables such as {cmd:_iivw_time_sq} or
{cmd:_iivw_ix_*}. Add {opt replace} if overwriting those generated variables
is intended.{p_end}

{phang2}{bf:Interaction variable name collision after truncation.} Two long names in
{opt interaction()} truncate to the same generated variable name. Rename one of the
source variables or use a shorter generated-variable prefix from
{cmd:iivw_weight, generate()}.{p_end}

{phang2}{bf:No observations.} The analysis sample becomes empty after
applying {it:if}/{it:in} restrictions and marking out missing variables,
weights, cluster variable, time variable, categorical variables, or
interaction variables. Check missingness before fitting.{p_end}

{phang2}{bf:Model does not converge.} The outcome model may be too complex, the predictors
may be collinear, or extreme weights may dominate the fit. Inspect the weight
distribution, simplify the model, and compare results with truncated weights.{p_end}

{phang2}{bf:Which time specification should I use?} Start with
{cmd:timespec(linear)}. If residual trends or subject-matter knowledge
suggest curvature, compare with {cmd:timespec(ns(3))}. Report whether the
main effect is sensitive to this choice. Use {cmd:timespec(categorical)}
when time is a small set of meaningful visit waves or periods rather than a
continuous trend.{p_end}


{marker reporting}{...}
{title:What to report}

{pstd}
A reproducible report should include:

{phang2}(a) the outcome model type ({cmd:gee} or {cmd:mixed}), family, and
link;{p_end}

{phang2}(b) the covariates in {it:indepvars}, the {opt timespec()} choice,
and any {opt interaction()} or {opt categorical()} expansions;{p_end}

{phang2}(c) the clustering variable and whether standard errors were
sandwich or bootstrap;{p_end}

{phang2}(d) the weight type inherited from {cmd:iivw_weight} and the weight
diagnostics from the weighting step;{p_end}

{phang2}(e) a sensitivity check comparing an untruncated and truncated
weight analysis when weights are extreme.{p_end}

{phang2}(f) for diagnostic workflows, the matching {opt unweighted} model
specification and the coefficient used as the marginal/reference time-slope
target for {helpb iivw_diagnose}.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup example data and weights}

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
{phang2}{cmd:. bysort id (days): egen double fu_end = max(days)}{p_end}
{phang2}{cmd:. replace fu_end = fu_end + 30}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) censor(fu_end) nolog}{p_end}

{pstd}
{bf:Diagnostic baseline: Unweighted model}

{pstd}
Fit an unweighted model through the same interface before comparing it with
weighted and measurement-adjusted models.

{phang2}{cmd:. iivw_fit edss treated edss_bl, unweighted id(id) time(days) timespec(linear) nolog}{p_end}
{phang2}{cmd:. estimates store Unweighted}{p_end}

{pstd}
{bf:Example 1: Basic GEE model with linear time}

{pstd}
The simplest specification: a continuous outcome with treatment, a baseline
covariate, and a linear time trend.

{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) timespec(linear)}{p_end}

{pstd}
{bf:Example 2: Quadratic time specification}

{pstd}
Allow the outcome trajectory to curve over time. Adds a time-squared term.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(quadratic) replace}{p_end}

{pstd}
{bf:Example 3: Natural spline for time}

{pstd}
More flexible than polynomial time. Natural splines with 3 degrees of freedom
allow the outcome trajectory to bend at internal knots while staying linear
beyond the boundaries.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(ns(3)) replace}{p_end}

{pstd}
{bf:Example 4: Treatment x time interaction}

{pstd}
Test whether the treatment effect changes over time. The interaction term
captures the rate at which the treatment effect grows or shrinks per unit
of time.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(linear) interaction(treated) replace}{p_end}

{pstd}
{bf:Example 5: Bootstrap standard errors}

{pstd}
Use bootstrap standard errors (500 replicates) instead of sandwich
SEs. Note: the bootstrap does not re-estimate weights, so SEs reflect only
outcome model uncertainty.

{phang2}{cmd:. iivw_fit edss treated edss_bl, bootstrap(500) nolog replace}{p_end}

{pstd}
Add {opt refitweights} to re-estimate the weights inside each replicate so the
interval also reflects weight estimation uncertainty. The point estimates match
the fixed-weight fit; only the standard errors differ.

{pstd}
Each replicate resamples whole subjects from the {it:visit panel} -- the rows
{cmd:iivw_weight} was fitted on -- and not from the outcome sample. A visit
whose outcome or outcome covariate is missing, or which an {cmd:if}/{cmd:in}
restricts out of the outcome analysis, is still an event in the monitoring
process and still belongs to the model each replicate re-estimates. The outcome
equation is restricted separately, so {cmd:e(N)} and {cmd:e(sample)} continue to
describe the outcome sample. A replicate whose outcome model fails to converge
is a failed draw, never a completed one; {opt allownonconverged} governs the
nuisance models and does not admit a nonconverged outcome fit inside a draw.

{phang2}{cmd:. iivw_fit edss treated edss_bl, bootstrap(500) refitweights nolog replace}{p_end}

{pstd}
{bf:Example 6: Binary outcome (binomial family)}

{pstd}
Model a binary outcome (relapse) with logistic link. Coefficients are log
odds ratios.

{phang2}{cmd:. iivw_fit relapse treated edss_bl, family(binomial) link(logit) replace}{p_end}

{pstd}
{bf:Example 7: Export results to Excel}

{pstd}
Use the {opt collect} option with non-bootstrap {cmd:model(gee)} fits to
accumulate results, then export with {cmd:regtab}.

{pstd}
{cmd:regtab} is provided by the optional {cmd:tabtools} package. Install it
before running the export examples if needed:

{phang2}{cmd:. net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace}{p_end}

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) nolog replace collect}{p_end}
{phang2}{cmd:. regtab, xlsx(iivw_results.xlsx) sheet(Results) title(IIW Analysis) stats(n)}{p_end}

{pstd}
{bf:Example 8: Treatment x time interaction with natural spline}

{pstd}
Allow the treatment effect to vary flexibly over time. With {cmd:ns(3)},
three interaction variables are created (one per spline basis), capturing
nonlinear treatment effect trajectories.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(ns(3)) interaction(treated) replace}{p_end}

{pstd}
{bf:Example 9: Multiple covariate interactions}

{pstd}
Allow both treatment and age effects to vary over time.

{phang2}{cmd:. iivw_fit edss treated age edss_bl, timespec(quadratic) interaction(treated age) replace}{p_end}

{pstd}
{bf:Example 10: Compare IIW vs FIPTIW in one table}

{pstd}
Run two weighting strategies and combine them in a single Excel table.

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) replace censor(fu_end) nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) nolog collect}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) treat(treated) treat_cov(age sex edss_bl) replace censor(fu_end) nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) nolog replace collect}{p_end}
{phang2}{cmd:. regtab, xlsx(iivw_results.xlsx) sheet(Comparison) models(IIW \ FIPTIW) title(IIW vs FIPTIW) stats(n) noint}{p_end}

{pstd}
{bf:Example 11: Categorical predictor with value labels}

{pstd}
Expand a multi-level treatment variable into labeled dummy variables. The
reference category is the lowest level by default.

{phang2}{cmd:. iivw_fit edss treatment edss_bl, categorical(treatment) replace}{p_end}

{pstd}
{bf:Example 12: Custom base category}

{pstd}
Set "High dose" (coded as 2) as the reference category instead of
"Placebo" (coded as 0).

{phang2}{cmd:. iivw_fit edss treatment edss_bl, categorical(treatment) basecat(2) replace}{p_end}

{pstd}
{bf:Example 13: Categorical with interaction}

{pstd}
Interact each treatment level with nonlinear time. Each non-reference
level gets its own set of time interaction terms.

{phang2}{cmd:. iivw_fit edss treatment edss_bl, timespec(ns(3)) categorical(treatment) interaction(treatment) replace}{p_end}

{pstd}
{bf:Example 14: Categorical time and treatment-by-period effects}

{pstd}
Use categorical time when visits occur at planned waves. Give the time
variable value labels before fitting so exported tables show readable row
labels.

{phang2}{cmd:. gen byte visit_wave = visit}{p_end}
{phang2}{cmd:. label define wave 1 "Baseline" 2 "Month 6" 3 "Month 12" 4 "Month 18", replace}{p_end}
{phang2}{cmd:. label values visit_wave wave}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(visit_wave) visit_cov(edss_bl relapse) replace endatlastvisit nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treatment edss_bl, timespec(categorical) categorical(treatment) interaction(treatment) replace collect}{p_end}
{phang2}{cmd:. regtab, xlsx(iivw_results.xlsx) sheet(Waves) title(Treatment by Visit Wave)}{p_end}

{pstd}
{bf:Example 15: Exclude time from the model}

{pstd}
When the outcome has no time trend or when time is already included as a
predictor in {it:indepvars}, use {cmd:timespec(none)} to skip automatic
time variable creation.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(none) replace}{p_end}

{pstd}
{bf:Example 16: Mixed-effects model (Stata 17+)}

{pstd}
Fit a mixed model with a random intercept per subject. This estimates
a conditional (subject-specific) treatment effect rather than the marginal
(population-averaged) effect.

{phang2}{cmd:. iivw_fit edss treated edss_bl, model(mixed) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_fit} stores the results from the underlying {cmd:glm} or
{cmd:mixed} command in {cmd:e()}, plus the following:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:e(iivw_cmd)}}{cmd:iivw_fit}{p_end}
{synopt:{cmd:e(iivw_model)}}estimation method (gee or mixed){p_end}
{synopt:{cmd:e(iivw_weighttype)}}weight type (iivw, iptw, fiptiw, or unweighted){p_end}
{synopt:{cmd:e(iivw_unweighted)}}1 if fit used {opt unweighted}, 0 otherwise{p_end}
{synopt:{cmd:e(iivw_refitweights)}}1 if bootstrap weights were refit; otherwise 0{p_end}
{synopt:{cmd:e(iivw_vce)}}{cmd:fixed}, {cmd:bootstrap-fixedweights}, or {cmd:bootstrap}{p_end}
{synopt:{cmd:e(iivw_resample_unit)}}the resampling unit, when bootstrapped{p_end}
{synopt:{cmd:e(iivw_vce_seed)}}resampling seed, when set via {opt vce(bootstrap, seed())}{p_end}
{synopt:{cmd:e(iivw_allowfailedreps)}}1 if an incomplete bootstrap was accepted{p_end}
{synopt:{cmd:e(iivw_inference_status)}}inference-clearance status; never {cmd:cleared}{p_end}
{synopt:{cmd:e(iivw_ci_type)}}confidence-interval type ({cmd:wald-normal}){p_end}
{synopt:{cmd:e(iivw_vce_seed_explicit)}}1 if a seed was set via {opt vce(bootstrap, seed())}{p_end}
{synopt:{cmd:e(iivw_rng)}}RNG type used, when bootstrapped{p_end}
{synopt:{cmd:e(iivw_rngstate_start)}}starting RNG state, when bootstrapped{p_end}
{synopt:{cmd:e(iivw_wsig)}}signature of the weight contract behind the estimates{p_end}
{synopt:{cmd:e(iivw_treat_in_visit)}}1 if {opt treat()} is in the visit-intensity model{p_end}
{synopt:{cmd:e(iivw_stab_terms)}}the validated {opt stabcov()} terms, if stabilized{p_end}
{synopt:{cmd:e(iivw_timespec)}}time specification used{p_end}
{synopt:{cmd:e(iivw_weight_var)}}weight variable name{p_end}
{synopt:{cmd:e(iivw_cluster)}}clustering variable used{p_end}
{synopt:{cmd:e(iivw_id)}}panel ID used{p_end}
{synopt:{cmd:e(iivw_time)}}time variable used{p_end}
{synopt:{cmd:e(iivw_time_vars)}}time variables included in the outcome model{p_end}
{synopt:{cmd:e(iivw_time_cat_vars)}}categorical-time dummies created{p_end}
{synopt:{cmd:e(iivw_time_basecat)}}reference category for categorical time, when applicable{p_end}
{synopt:{cmd:e(iivw_display_vars)}}terms displayed in the formatted effects table{p_end}
{synopt:{cmd:e(iivw_interaction)}}variables specified in {opt interaction()}, when applicable{p_end}
{synopt:{cmd:e(iivw_ix_vars)}}interaction variables created, when applicable{p_end}
{synopt:{cmd:e(iivw_categorical)}}variables specified in {opt categorical()}, when applicable{p_end}
{synopt:{cmd:e(iivw_cat_vars)}}categorical dummy variables created, when applicable{p_end}

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations in the outcome equation{p_end}
{synopt:{cmd:e(iivw_stabilization_validated)}}1 if {opt stabcov()} was validated against the outcome design{p_end}
{synopt:{cmd:e(iivw_vce_locked)}}1 if the post-fit variance lock confirmed the VCE{p_end}
{synopt:{cmd:e(iivw_bs_reps_requested)}}bootstrap replicates requested{p_end}
{synopt:{cmd:e(iivw_bs_reps_completed)}}bootstrap replicates that returned an estimate{p_end}
{synopt:{cmd:e(iivw_bs_reps_failed)}}bootstrap replicates that failed{p_end}
{synopt:{cmd:e(iivw_bs_frame_N)}}rows in the resampling frame ({opt refitweights} only){p_end}
{synopt:{cmd:e(iivw_outcome_nclust)}}clusters in the outcome equation{p_end}

{pstd}
{bf:Reading e(N) and e(N_clust) after} {opt refitweights}{bf:.} These two
scalars describe different samples, deliberately. A refit bootstrap resamples
the {it:visit panel}, because that is the data the visit-intensity model was
fitted on and which every replicate re-fits; the outcome equation is then
evaluated on the smaller {it:outcome sample}. So {cmd:e(N_clust)} reports the
clusters actually resampled -- the number the "Replications based on ..."
header line refers to -- while {cmd:e(N)} reports outcome-equation rows. When a
subject contributes monitoring visits but no recorded outcome, it is counted in
{cmd:e(N_clust)} and not in {cmd:e(N)}. Use {cmd:e(iivw_outcome_nclust)} for the
outcome sample's own cluster count and {cmd:e(iivw_bs_frame_N)} for the frame's
row count; the four together reconcile the two samples.

{pstd}
The command also stores fit metadata in dataset characteristics so downstream
checks can tell which model was most recently fit:

{synoptset 26 tabbed}{...}
{p2col 5 26 30 2: Dataset characteristics}{p_end}
{synopt:{cmd:_dta[_iivw_fitted]}}flag that {cmd:iivw_fit} completed{p_end}
{synopt:{cmd:_dta[_iivw_model]}}estimation method used{p_end}
{synopt:{cmd:_dta[_iivw_timespec]}}time specification used{p_end}
{synopt:{cmd:_dta[_iivw_cluster]}}clustering variable used{p_end}
{synopt:{cmd:_dta[_iivw_time_vars]}}time variables included in the outcome model{p_end}
{synopt:{cmd:_dta[_iivw_time_cat_vars]}}categorical-time dummy variables created{p_end}
{synopt:{cmd:_dta[_iivw_time_basecat]}}reference category for categorical time{p_end}
{synopt:{cmd:_dta[_iivw_interaction]}}variables specified in {opt interaction()}{p_end}
{synopt:{cmd:_dta[_iivw_ix_vars]}}interaction variables created{p_end}
{synopt:{cmd:_dta[_iivw_categorical]}}variables specified in {opt categorical()}{p_end}
{synopt:{cmd:_dta[_iivw_cat_vars]}}categorical dummy variables created{p_end}
{synopt:{cmd:_dta[_iivw_basecat]}}base category, if specified{p_end}

{pstd}
All standard post-estimation commands for {cmd:glm} or {cmd:mixed} are
available after {cmd:iivw_fit}. For example, {cmd:predict}, {cmd:lincom},
{cmd:test}, and {cmd:margins} work as usual.


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
Tompkins G, Dubin JA, Wallace M. 2025. On flexible inverse probability of
treatment and intensity weighting: Informative censoring, variable selection,
and weight trimming. {it:Statistical Methods in Medical Research}
34(5): 915-937. doi:10.1177/09622802241313289.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb iivw}, {helpb iivw_weight}, {helpb iivw_exogtest},
{helpb iivw_diagnose}, {helpb regtab}, {helpb glm}, {helpb xtgee}, {helpb mixed}

{hline}
