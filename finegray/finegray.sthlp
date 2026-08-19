{smcl}
{* *! version 1.2.0  16aug2026}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "finegray_cif" "help finegray_cif"}{...}
{vieweralsosee "finegray_phtest" "help finegray_phtest"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "finegray##syntax"}{...}
{viewerjumpto "Description" "finegray##description"}{...}
{viewerjumpto "Options" "finegray##options"}{...}
{viewerjumpto "Remarks" "finegray##remarks"}{...}
{viewerjumpto "Dataset side effects" "finegray##sideeffects"}{...}
{viewerjumpto "Examples" "finegray##examples"}{...}
{viewerjumpto "Stored results" "finegray##results"}{...}
{viewerjumpto "Author" "finegray##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:finegray} {hline 2}}Fine-Gray competing risks regression{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:finegray}
{varlist}
{ifin}{cmd:,}
{opt comp:ete(varname)}
{opt cau:se(#)}
[{it:options}]

{pstd}Replay the last results{p_end}

{p 8 17 2}
{cmd:finegray}
[{cmd:,}
{opt noshr}
{opt l:evel(#)}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth comp:ete(varname)}}event type variable (0=censored, 1, 2, ...){p_end}
{synopt:{opt cau:se(#)}}value of {it:compete()} for cause of interest{p_end}

{syntab:Model}
{synopt:{opt cens:value(#)}}censoring value in {it:compete()}; default is {cmd:0}{p_end}
{synopt:{opth str:ata(varlist)}}stratify censoring distribution (numeric){p_end}
{synopt:{opth trunc:strata(varlist)}}stratify entry distribution (numeric){p_end}

{syntab:SE/Robust}
{synopt:{opth cl:uster(varname:numvar)}}adjust SEs for intragroup correlation{p_end}
{synopt:{opt noadj:ust}}omit finite-sample adjustment to the sandwich{p_end}
{synopt:{opt norob:ust}}report model-based SEs, not sandwich{p_end}
{synopt:{opt nuis:ance}}add the estimated-{it:G} term to the sandwich meat{p_end}

{syntab:Reporting}
{synopt:{opt noshr}}report coefficients, not hazard ratios{p_end}
{synopt:{opt l:evel(#)}}set confidence level; default is {cmd:c(level)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt baseh:az}}post the cumulative subhazard in {cmd:e(basehaz)}{p_end}

{syntab:Optimization}
{synopt:{opt iter:ate(#)}}maximum iterations; default is {cmd:200}{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance; default is {cmd:1e-8}{p_end}
{synoptline}
{p 4 6 2}
{it:varlist} may contain factor variables and interactions; see
{help fvvarlist}. Supports {cmd:i.}{it:varname},
{cmd:ib}{it:#}{cmd:.}{it:varname}, {cmd:ibn.}{it:varname} (interactions only),
{cmd:c.}{it:varname}, {cmd:#}, and {cmd:##} operators.
{p_end}
{p 4 6 2}
Data must be {cmd:stset} with {cmd:id()}. A subject may contribute multiple
records when its intervals are contiguous and the model covariates,
{opt strata()}, {opt truncstrata()}, and {opt cluster()} variables are constant
within {cmd:id()} (e.g. delayed-entry or {helpb stsplit} data); such records are
reduced automatically to one risk-set unit. Left-truncated data are supported.
{p_end}

{pstd}
{bf:Post-estimation:}

{p 8 17 2}
{cmd:finegray_predict}
{dtype}
{newvar}
{ifin}{cmd:,}
[{opt xb} {opt cif} {opt sch:oenfeld} {opt time:var(varname)} {opt ci}
{opt basecsh:azard} {opt l:evel(#)} {opt boot:strap(#)} {opt seed(#)}]

{p 8 17 2}
{cmd:finegray_cif}
[{cmd:,} {opt at(var=# ...)} {opt att:ime(numlist)}
{opt ti:mepoints(numlist)} {opt ci} {opt l:evel(#)}
{opt sav:ing(filename[, replace])} {opt boot:strap(#)} {opt seed(#)}
{opt nograph} {it:twoway_options}]

{p 8 17 2}
{cmd:finegray_phtest}
[{cmd:,} {opt time(rank|log|identity)} {opt det:ail}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray} fits the Fine and Gray (1999) subdistribution hazard model for
competing risks data.

{pstd}
It estimates subdistribution hazard ratios (SHR) which quantify the effect of
covariates on the cumulative incidence of a cause of interest in the presence of
competing events.

{pstd}
The estimator uses a native forward-backward scan adapted from Kawaguchi et al. (2021)
that avoids data expansion. Their published decomposition covers
right-censored data without ties; tie handling and delayed entry are package
extensions described below.

{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth compete(varname)} specifies the variable containing event types. Typically
coded as 0 = censored, 1 = cause 1, 2 = cause 2, etc. Must be consistent with
the {cmd:stset} failure indicator.

{pmore}
{cmd:compete()} is the outcome classification, not a covariate, so it must be
observed on every record of the estimation sample. A record whose event type is
{it:missing} is refused with {cmd:r(198)}, naming how many such records there
are and how many of them are {cmd:stset} failures; it is not dropped. Dropping
it would remove an event from the estimand with nothing on screen, and it would
be inconsistent with the check that already refuses a record whose event type
merely {it:disagrees} with the {cmd:stset} failure indicator.

{pmore}
The usual way to arrive at a missing {cmd:compete()} is to {cmd:stset} the
failure indicator on the event-type variable itself and then {helpb stsplit} --
{cmd:stsplit} sets that variable to missing on every non-terminal episode, in
both the by-name and the expression form. Carry the subject's event type onto
every episode before fitting, or {cmd:stset} a separate failure indicator:

{pmore2}
{cmd:. generate byte anyev = status != 0}{break}
{cmd:. stset t, failure(anyev) id(id)}{break}
{cmd:. stsplit iv, at(2 4)}{break}
{cmd:. finegray x1 x2, compete(status) cause(1)}

{phang}
{opt cause(#)} specifies which value of {it:compete()} represents the cause of
interest.

{dlgtab:Model}

{phang}
{opt censvalue(#)} specifies the value in {it:compete()} that represents
censoring. Default is {cmd:0}.

{phang}
{opth strata(varlist)} stratifies the Kaplan-Meier censoring distribution
estimation by the specified variables. This is appropriate when the censoring
mechanism differs across groups (e.g., treatment arms or study sites).

{phang}
{opth truncstrata(varlist)} stratifies the {it:entry} (left-truncation) distribution by
the specified variables. Use it when the delayed-entry mechanism differs
across observed groups — for example, when one arm is enrolled later than
another. It is the entry-side counterpart of {opt strata()}, which remains the
{it:censoring}-side option; the two are specified independently and are
cross-classified internally into joint weight strata. {cmd:finegray} never silently
reuses {opt strata()} for the entry distribution.

{pmore}
{opt truncstrata()} requires delayed entry. On data with no delayed entry it is
rejected with {cmd:r(198)} rather than accepted as a no-op, because an option that
quietly does nothing is indistinguishable from one that worked.

{pmore}
Each variable must be constant within subject on multi-record data, and
missing values are excluded from the estimation sample. The joint (censoring x
entry) weight cells are subject to a hard support boundary: at most {bf:100}
observed joint strata, each holding at least {bf:20} estimation-sample
subjects. Exceeding either boundary is {cmd:r(459)}; groups are never silently
pooled. See {help finegray##lt:Left truncation} for why the boundary applies to {opt strata()} as well
once entry is delayed.

{pmore}
{bf:Neither boundary is overridable}, and both apply to delayed-entry fits
only; a fit without delayed entry is unaffected by either. Both are
{it:package conventions}, not values derived from the underlying theory. G is
estimated within {opt strata()} groups and H within {opt truncstrata()}
groups, then the components are evaluated together for each observed
cross-classified cell. The ceiling and floor limit how finely that configured
weight may be cross-classified before cell support becomes too sparse. Choosing
to refuse rather than to pool or drop is deliberate; the two numbers themselves
are conservative round figures. Note in particular that the 20-subject floor is a {it:size} check
only -- it bounds how many subjects a stratum holds, not whether A stays away
from zero where the weight scan divides by it, which is checked separately (see
the paragraph below).

{pmore}
{bf:The size boundary does not guarantee a usable weight.} A retained
competing-event subject carries weight A(t-)/A(X_i-), and if its own stratum's
A(X_i-) is zero that weight is undefined. This is checked before the fit and
refused with {cmd:r(459)}, naming the count and the offending joint-group
codes. Splitting into more entry strata makes it {it:more} likely, because each
stratum's entry distribution is then estimated from fewer subjects.

{dlgtab:SE/Robust}

{phang}
{opth cluster(varname)} adjusts standard errors for intragroup correlation, treating
whole clusters as the resampling unit. The clustered variance matrix is a sum
of {it:g} cluster-score outer products whose totals sum to zero at the solution, so
its rank is at most {it:g}-1. {cmd:finegray} therefore requires more clusters than
coefficients and errors out otherwise, rather than reporting standard errors
that the g-inverse invented for directions the variance matrix cannot see. The
number of clusters is reported in the header and stored in {cmd:e(N_clust)}, and
{opt cluster()} is not allowed with {opt norobust}: the former requests a
cluster-robust sandwich and the latter requests inverse-information variance.

{phang}
{opt noadjust} suppresses the finite-sample adjustment applied to the robust
(sandwich) variance. By default {cmd:finegray} multiplies the sandwich by {it:N}/({it:N}-1),
or by {it:g}/({it:g}-1) when {opt cluster()} is specified, matching {helpb stcrreg}. {opt noadjust} is not
allowed with {opt norobust}, which has no such adjustment.

{phang}
{opt norobust} reports model-based standard errors from the observed information
matrix instead of the default Huber/White/sandwich estimator.

{pmore}
{bf:These standard errors are not generally valid for Fine-Gray inference.} The
weighted Fine-Gray estimating equation is a pseudo-likelihood score, so the
ordinary likelihood information identity need not hold: inverse information
omits the empirical score variability and any estimated-weight contribution. It
can coincide with a likelihood variance in special limiting cases, but
model-based standard errors are generally too small in the competing-risk
settings targeted here, and their confidence intervals need not have nominal
coverage. {opt norobust} exists so that the naive likelihood variance can be
inspected and compared; use the default sandwich variance to report
results. {cmd:finegray} prints a warning whenever {opt norobust} is used.

{pmore}
{bf:Under delayed entry, inverse information also omits weight-estimation uncertainty.} Bellach
et al. (2020, sec. 5) document truncation-dependent undercoverage of
inverse-information inference. Do not use {opt norobust} for inference on
left-truncated data.

{pmore}
{bf:Scope of the sandwich estimator.} The default sandwich is a
{it:fixed-weight} sandwich: it treats the estimated
inverse-probability-of-censoring weights as fixed and does not propagate the
uncertainty in the
estimated censoring distribution G(t) (nor, under delayed entry, the entry
distribution H(t)). Under right censoring this is the same variance convention
{helpb stcrreg} reports. {bf:Same convention is not the same digits:} the two
commands break ties in the censoring Kaplan-Meier differently, so the standard
errors agree to about four significant figures rather than exactly. On
{cmd:webuse hypoxia} the coefficients match to {cmd:mreldif} 5e-11 while the
standard errors differ by up to 2e-4 in relative terms; the package's own
cross-validation gates {cmd:stcrreg} standard-error parity as a tolerance, not
as equality. Under delayed entry the commands use different weights, so
neither estimates nor standard errors are numerically comparable. Coefficients
are unaffected by the variance option — only their standard errors change. {cmd:e(lt_vce)}
records the delayed-entry variance actually computed as
{cmd:fixed_weight_sandwich} (or {cmd:model_based} under {opt norobust}), and
{cmd:e(vce_meat)} records which sandwich meat was used on any fit. Under right
censoring the Fine and Gray (1999, eq. 7-8) nuisance term is available via
{opt nuisance}; under delayed entry the corresponding term is Zhang, Zhang and
Fine (2011, Appendix B), which this package does not implement.

{phang}
{opt nuisance} adds the Fine and Gray (1999, eq. 7-8, pp. 500-501)
{it:psi} term to the sandwich meat, so that the meat becomes
sum_i (eta_i + psi_i)^2 rather than sum_i eta_i^2. The {it:eta} term is the
score contribution treating the censoring survivor G as known; {it:psi} is the
additional contribution from having {bf:estimated} G by Kaplan-Meier. With
{opt nuisance}, {cmd:finegray}'s variance targets the same right-censoring
nuisance-adjusted sandwich as {cmd:cmprsk::crr}.

{pmore}
The correction is not always conservative: {it:eta} and {it:psi} are
correlated, so the nuisance-adjusted variance can be larger or smaller than
the default. It is therefore not safe to assume the default is the
"conservative" choice.

{pmore}
{opt nuisance} requires the sandwich, so it is not allowed with
{opt norobust}. It is {bf:not allowed under delayed entry}: eq. (7)-(8) is
derived for right censoring with no entry times, and applying a
right-censoring correction to left-truncated data would return a plausible
number with no derivation behind it. For nuisance-adjusted inference under
delayed entry, bootstrap the whole fit; see
{it:Bootstrap coefficient inference} below.

{pmore}
{opt nuisance} is {bf:not} the default, so upgrading does not move standard
errors reported from earlier releases. When it is specified,
{cmd:e(vce_meat)} is {cmd:nuisance_adjusted}; otherwise it is
{cmd:fixed_weight} (or {cmd:not_applicable} under {opt norobust}).

{pmore}
{bf:It does not propagate to post-estimation.} {helpb finegray_cif} and
{helpb finegray_predict} use a fixed-weight analytic CIF influence function. The
full CIF influence function includes the coefficient-path {it:psi} contribution
and a separate weight-estimation contribution for the baseline/CIF path. The
analytic postestimation path includes neither contribution and remains
fixed-weight, so its standard errors are identical after a {opt nuisance} fit
and after a default fit. Use those commands' bootstrap options when CIF
intervals should include weight re-estimation.

{pmore}
{bf:Bootstrap coefficient inference.} The {opt bootstrap()} options of
{helpb finegray_cif} and {helpb finegray_predict} resample subjects to get
{it:CIF} and {it:prediction} standard errors; they do {bf:not} produce
nuisance-adjusted standard errors for the coefficient vector {cmd:e(b)}. For
coefficient-level inference that accounts for estimating G(t) (and H(t) under
delayed entry), bootstrap the whole fit by resampling subjects and re-estimating
in each replication. Wrap the {cmd:stset}+{cmd:finegray} step and bootstrap with
subject-cluster resampling:

{pmore2}{cmd:. program define myfit, eclass}{p_end}
{pmore2}{cmd:.     quietly stset t, failure(ev) id(id)}{p_end}
{pmore2}{cmd:.     quietly finegray x1 x2, compete(ev) cause(1)}{p_end}
{pmore2}{cmd:. end}{p_end}
{pmore2}{cmd:. bootstrap _b, reps(500) seed(12345) cluster(id) idcluster(newid) group(id): myfit}{p_end}

{pmore}
Each replication re-estimates the model and, under delayed entry, G(t), H(t) and
the weight strata, so the resulting standard errors propagate the
weight-estimation uncertainty the fixed-weight sandwich omits. Use enough replications
(500+) for a stable standard error.

{dlgtab:Reporting}

{phang}
{opt noshr} reports coefficients (log subdistribution hazard ratios) instead of
exponentiated coefficients (subdistribution hazard ratios).

{phang}
{opt level(#)} specifies the confidence level for confidence intervals. Default
is {cmd:c(level)}, which is initially 95; see {helpb set level}.

{phang}
{opt nolog} suppresses the iteration log.

{phang}
{cmd:finegray} typed with no {it:varlist} redisplays the last {cmd:finegray}
results. {opt noshr} and {opt level(#)} are honoured on replay, so
{cmd:finegray, level(90)} reports the same fit at a 90% confidence level without
refitting the model. Replay requires that the last estimation results in memory
are a {cmd:finegray} fit; otherwise it exits with {cmd:r(301)}.

{phang}
{opt basehaz} posts the baseline cumulative subdistribution hazard in
{cmd:e(basehaz)}, a matrix with one row per distinct cause-event time and columns
{cmd:time} and {cmd:cumhazard}. It is not posted by default: that matrix has
roughly N/2 rows, and building a Stata matrix that tall is O(rows^2), which at
N = 200,000 took longer than the model fit itself. You do not need it for
post-estimation -- {helpb finegray_cif} and {helpb finegray_predict} rebuild the
same curve internally -- and {cmd:predict, basecshazard} returns the baseline as
a variable at O(N) cost. Ask for {opt basehaz} when you want the matrix itself.

{phang}
{opt basehaz} is also what you need if you will {helpb estimates:estimates save}
the fit and predict from it in a {it:later} Stata session. The cached baseline
lives in Mata and does not cross sessions, and a saved estimation set carries only
{cmd:e()} -- so without {cmd:e(basehaz)} in it, {cmd:predict, cif} after
{cmd:estimates use} cannot recover the baseline and exits with an error telling you
to refit. Fit with {opt basehaz} and the matrix is saved alongside the estimates,
so the workflow just works. Predicting in the {it:same} session needs nothing
extra.

{dlgtab:Optimization}

{phang}
{opt iterate(#)} specifies the maximum number of Newton-Raphson
iterations. Default is {cmd:iterate(200)}. If the model has not converged
within {it:#} iterations, {cmd:finegray} reports the last iterate with
{cmd:e(converged)} set to 0 and prints a warning above the coefficient
table. Those coefficients are not a solution: {helpb finegray_predict},
{helpb finegray_cif} and {helpb finegray_phtest} all refuse to run on a
nonconverged fit.

{phang}
{opt tolerance(#)} specifies the convergence tolerance. Default is
{cmd:tolerance(1e-8)}. {it:#} must be a positive number. Convergence is
declared when the Newton decrement, {cmd:score' * inv(I) * score}, falls
below {it:#}; near the optimum this is approximately twice the remaining gain
in the log pseudo-likelihood. The decrement is used rather than the size of
the coefficient step because it is invariant to rescaling a covariate, so
{cmd:x} and {cmd:1e6*x} converge to the same fit.

{phang}
{cmd:finegray} requires the model to be identified. Because the
subdistribution likelihood is evaluated only over cause-event risk sets, a
covariate can be of full rank in the data as a whole and still contribute no
information to the fit (for example, if it is nonzero only for subjects
censored before the first cause event). Such a coefficient is not estimable,
and {cmd:finegray} exits with an error naming the offending term rather than
reporting an arbitrary value for it.


{marker remarks}{...}
{title:Remarks}

{pstd}
The Fine-Gray model directly models the subdistribution hazard, which is the
instantaneous rate of failure from the cause of interest among subjects who have
not yet experienced that specific cause.

{pstd}
Subjects who experience a competing event remain in the risk set indefinitely
with time-dependent weights derived from the Kaplan-Meier estimate of the
censoring distribution.

{pstd}
{bf:Factor variables and interactions:} {cmd:finegray} supports the full Stata
factor-variable syntax via {cmd:fvrevar}: {cmd:i.}{it:varname},
{cmd:ib}{it:#}{cmd:.}{it:varname}, {cmd:ibn.}{it:varname}, {cmd:c.}{it:varname},
{cmd:#} (interaction), and {cmd:##} (full factorial with main effects).

{pmore}
{cmd:ibn.} is estimable only inside an interaction ({cmd:c.x#ibn.grp}). As a
{it:main effect} it names every level, and the Fine-Gray partial likelihood has
no intercept to absorb the redundancy: adding a constant to every level's
coefficient leaves the likelihood unchanged, so one level is not
identified. {cmd:finegray ibn.grp ...} therefore stops with {cmd:r(459)} and
tells you to use {cmd:i.} or {cmd:ib}{it:#}{cmd:.} instead. It does not silently drop a level
and report the rest, which is what {helpb stcox} does with the same
specification.

{pstd}
Indicator and interaction variables are automatically created with the prefix
{cmd:_fg_} (e.g., {cmd:_fg_race_2}, {cmd:_fg_race_2Xage} for an
{cmd:i.race#c.age} interaction). These persist in the dataset for use with
{cmd:finegray_predict}.

{pstd}
Re-running {cmd:finegray} drops only the finegray-created FV variables recorded
from the prior run; it does not wildcard-drop every {cmd:_fg_*} variable in the
dataset.

{pstd}
{bf:Names follow the user's specification.} The coefficient table,
{cmd:e(b)}, {cmd:e(V)}, {helpb finegray_phtest} rows, and
{helpb finegray_cif}'s {cmd:r(profile_vars)} carry the factor-variable terms
you typed ({cmd:2.grp}). Thus {helpb lincom} and {helpb test} address those
user-facing terms directly. Package-owned design columns such as
{cmd:_fg_grp_2} are recorded separately in {cmd:e(covariates)} for prediction
and post-estimation. {cmd:e(fvsemantic)} records the fit-time expansion whose
non-base terms pair 1:1 and in order with those design columns, so the {it:k}th
coefficient and the {it:k}th post-estimation row always describe the same term.

{pstd}
{bf:Note:} the post-estimation commands rebuild factor-variable design columns
on demand from the expansion recorded at estimation ({cmd:e(fvsemantic)}),
keyed to each level's {bf:value}. They do not re-run {cmd:fvrevar} against the
data in memory, so neither a changed {cmd:fvset} base nor a shifted level
support can silently re-pair a column with the wrong coefficient.

{pstd}
A fitted level that is {bf:absent} from the current data is therefore not an
error: prediction succeeds for the rows that remain. What is refused is the
opposite case -- an observation at a level the fit never saw has no
coefficient, so {helpb finegray_predict} exits with {cmd:r(459)} naming the
variable and the fitted levels rather than collapsing that row onto the base
category. The persistent {cmd:_fg_*} columns are retained for convenience but
are not required for prediction.

{pstd}
{bf:Interpretation:} A subdistribution hazard ratio (SHR) > 1 indicates that the
covariate increases the cumulative incidence of the cause of interest.

{pstd}
Unlike cause-specific hazard ratios, SHRs have a direct interpretation in terms
of the cumulative incidence function.

{marker sideeffects}{...}
{pstd}
{bf:What {cmd:finegray} changes in your dataset.} The fit itself runs inside a
{cmd:preserve}, and the command is {cmd:sortpreserve}, so
{bf:no observation is dropped, altered, or reordered} and your sort order is
restored. What does persist, deliberately, is the following.

{phang2}
{bf:1. Factor-variable design columns} named {cmd:_fg_}{it:term}, one per
expanded factor or interaction term, created only when the model uses
factor-variable syntax. They are labelled and left in the dataset for
{helpb finegray_predict}. A later {cmd:finegray} run drops only the columns its
own prior run recorded; it never wildcard-drops {cmd:_fg_*}. A pre-existing
{cmd:_fg_}{it:term} that finegray did not create is an error
({cmd:r(198)}), not a silent overwrite.

{phang2}
{bf:2. An entry-time column} {cmd:_fg_entry}, created only when multiple records
per subject are reduced. It holds each subject's earliest entry time and is
required by the post-estimation commands; see
{help finegray##lt:Left truncation}.

{phang2}
{bf:3. Dataset characteristics} recording the fit for post-estimation use; see
{help finegray##results:Stored results} for the full list. These travel with the
dataset when you {cmd:save} it, but the estimation results themselves do
not, so after {cmd:save} and {cmd:use} the post-estimation commands report
{cmd:r(459)} because {cmd:e()} was not restored along with the
data. {helpb estimates save} and {helpb estimates use} carry the fit across
sessions; refitting always works and needs nothing explained.

{pmore2}
{bf:What {cmd:estimates use} does not bring back is {cmd:e(sample)}.} The sample
marker is a property of the data in memory, not of the saved estimation set, so
after {cmd:estimates use} no observation is marked. {cmd:finegray} itself
replays, and {cmd:finegray_predict} with {opt xb} or {opt cif} works, because
neither reads the estimation sample -- {opt cif} needs only the baseline, which
is why {opt basehaz} matters for a fit you intend to reload (see
{help finegray##options:Options}). The commands that do read it --
{helpb finegray_cif}, {helpb finegray_phtest}, and {cmd:finegray_predict} with
{opt ci} or {opt schoenfeld} -- stop with {cmd:r(459)} and say the estimation
sample is empty. Re-declare it with {helpb estimates:estimates esample:} over
the variables listed in {cmd:e(datasignaturevars)} and they all resume; the data
signature is still checked, so a sample that does not match the fit is refused
exactly as before.

{pmore2}
This holds whether the dataset in memory was saved before or after the fit. The
dataset characteristics in point 3 above are written by the fit, so a copy saved
{it:before} it does not carry them; that copy is still recognised from
{cmd:e()}, and it reaches the same {cmd:r(459)} and the same one-line
repair. A multiple-record fit is the one case the repair cannot rescue: its
subject-level entry times live in the {cmd:_fg_entry} column that the fit
created, {cmd:_fg_entry} is one of the {cmd:e(datasignaturevars)}, and a dataset
that predates the fit does not contain it -- so the reload stops with
{cmd:r(459)} naming {cmd:_fg_entry}, and the fit must be re-run.

{pmore2}
{cmd:. estimates use myfit}{break}
{cmd:. estimates esample: `e(datasignaturevars)' if !missing(_t)}{break}
{cmd:. finegray_cif, attime(5)}

{phang2}
{bf:4. A reduced {cmd:e(sample)}} on multiple-record data -- one record per
subject rather than one per supplied record, with {cmd:e(N)} counting
subjects. The data are untouched; only the estimation-sample marker is
reduced. See {help finegray##lt:Left truncation}.

{pstd}
Items 1 and 2 are ordinary variables: {cmd:describe}, {cmd:save} and
{cmd:drop} all see them. Dropping the {cmd:_fg_*} design columns is supported --
{helpb finegray_predict}, {helpb finegray_cif} and {helpb finegray_phtest} all
rebuild them on demand, from the factor expansion in force at fit time -- but do
not drop {cmd:_fg_entry} while post-estimation on a multiple-record fit is still
needed. Modifying a {cmd:_fg_*} column in place is a different matter: it is
refused with {cmd:r(459)}, because the fitted coefficients no longer correspond
to what the column holds.

{marker lt}{...}
{pstd}
{bf:Left truncation (delayed entry).} {cmd:finegray} supports left-truncated
data, where subjects enter observation after time 0. Specify entry times with
{cmd:stset}'s {cmd:enter()} option.

{pstd}
{bf:Under delayed entry finegray deliberately disagrees with stcrreg, by design.} An
inverse-probability-of-censoring weight built from the censoring distribution
alone is {it:not} a valid weight for left-truncated data: with no censoring at all
it collapses to a constant, which cannot correct anything. Zhang, Zhang and
Fine (2011) show the resulting estimator is biased, and the bias does not
vanish as the sample grows. {cmd:stcrreg} uses that censoring-only weight; so did
{cmd:finegray} before this release.

{pstd}
With one weight stratum, {cmd:finegray} implements the
{bf:Geskus (2011) product-limit representation}. Writing
A(t) = G(t-)H(t-), where G is the delayed-entry-aware censoring survivor
and H is a reverse-time product-limit estimator of entry, a subject retained
after a competing event at X_i carries A(t-)/A(X_i-) instead of the
censoring-only ratio G(t-)/G(X_i-). Geskus states that this weight is equivalent
to Zhang-Zhang-Fine Weight 1, and Bellach et al. (2020) prove the equivalence for
continuous failure times. The package supplies and tests its own finite-sample
tie convention.

{pstd}
With multiple weight strata, {cmd:finegray} uses the Zhang, Zhang and Fine
(2011, eq. 7) form: the time-side stabilizer is pooled, while each subject-side
denominator is stratum-specific. When {opt strata()} and {opt truncstrata()}
specify the same grouping, this is the paper's stratified nonparametric
construction. When they differ, {cmd:finegray} estimates G within {opt strata()},
estimates H within {opt truncstrata()}, and multiplies the components in each
observed combination. That factorized cross-classification is a package
extension, not a construction attributed to Zhang et al. The same contract is
used by estimation and every postestimation calculation.

{pstd}
{cmd:e(lt_weight)} reports {cmd:zzf1_geskus} for a one-stratum delayed-entry
fit and {cmd:zzf1_stratified} for the equation-7 pooled-stabilizer form when
{opt strata()} and {opt truncstrata()} name the same grouping (the paper's
stratified construction). When they name different groupings -- the factorized
extension described above -- it reports {cmd:zzf1_factorized} instead, so a
consumer can tell the extension apart from the ZZF construction it is not.

{pstd}
{bf:Consequences you should expect.} Delayed-entry coefficients, standard errors,
baseline hazards, predictions and CIFs all {it:change} relative to earlier versions
of {cmd:finegray} and relative to {cmd:stcrreg}. Results with no delayed entry are
unchanged, bit for bit: when every subject enters at the origin, H is
identically 1, A collapses to G, and the estimator is the existing
right-censoring path. {cmd:e(lt_weight)} reports {cmd:right_censoring} there, and
{cmd:e(lt_vce)} reports {cmd:not_applicable}.

{pstd}
{bf:Which weights are valid for your data.} Pooled weights (no {opt strata()} or
{opt truncstrata()}) assume that the entry and censoring mechanisms do not vary
with model covariates in ways that require conditioning. When entry depends on
an observed discrete group, name it in
{opt truncstrata()}; when censoring does, name it in {opt strata()}. Observed
combinations form the joint denominator strata. Continuous covariate-dependent
entry is {bf:not supported}; the command cannot infer or reject that dependence
from the realized data. Do not use pooled weights in that setting unless a
scientifically defensible discrete stratification removes the dependence. Covariates
that change within subject are also unsupported; for
internal time-varying covariates, the direct relationship between a
subdistribution hazard and the CIF is generally unavailable after a competing
event.

{pstd}
{bf:When the groupings differ.} The published same-group product-limit result
does not require entry and censoring to be independent. The package's
{cmd:zzf1_factorized} extension is a different claim: because it estimates G
without conditioning on {opt truncstrata()} and H without conditioning on
{opt strata()}, it requires factor-specific separability. Within each observed
censoring stratum, the censoring law must be homogeneous across levels of
{opt truncstrata()} that are not also in {opt strata()}; within each entry
stratum, the entry law must be homogeneous across levels of {opt strata()} that
are not also in {opt truncstrata()}. A useful sufficient structure is that entry
and censoring are independent conditional on the joint cell, G depends only on
{opt strata()}, and H depends only on {opt truncstrata()}.

{pstd}
If one observed factor drives {it:both} mechanisms -- for example, a site or
enrolment wave -- name it in {bf:both} options. Matching groupings use the
published stratified construction. If that specification fails the positivity
boundary, coarsen only when a coarser mechanism model is scientifically
defensible. Pooled or one-sided fits may be useful sensitivity analyses, but
their numerical feasibility does not make them valid replacements.

{pstd}
{bf:Support boundary, and a breaking change.} Under delayed entry the weight A is
evaluated {it:per observed joint weight cell}, so every level of {opt strata()}
participates in a weight cell even when {opt truncstrata()} is not specified. At most 100 joint
strata are supported, each with at least 20 estimation-sample subjects; beyond
that {cmd:finegray} stops with {cmd:r(459)} rather than pooling groups behind your
back. {bf:A delayed-entry model with many {opt strata()} levels may stop with {cmd:r(459)}.} The
same model still fits without delayed entry, because that branch is required
to remain bit-identical. If you hit this boundary, reduce the number of
censoring strata.

{pstd}
{bf:Standard errors under delayed entry.} Use the default sandwich variance. The
inverse information does not carry the variability of the weighted
pseudo-score, and Bellach et al. (2020, sec. 5) document worsening
undercoverage with truncation. {cmd:e(lt_vce)} records which variance a fit
used ({cmd:fixed_weight_sandwich} or {cmd:model_based}); {opt norobust} prints a
warning at run time, and {opt cluster()} uses the cluster-robust form of the
sandwich.

{pstd}
{bf:What the sandwich does not do.} It treats the estimated weights as fixed — it
does not propagate the uncertainty in estimating G and H, so {cmd:e(lt_vce)} is
reported as {cmd:fixed_weight_sandwich}, not as the Fine and Gray (1999, eq. 7-8)
nuisance-adjusted variance. Zhang, Zhang and Fine (2011, Appendix B) give a
variance with additional terms for that uncertainty, and it is not implemented
here. For {it:coefficient} standard errors that propagate weight-estimation uncertainty,
bootstrap the whole fit (see {it:Bootstrap coefficient inference} under
{help finegray##options:Options}); the {opt bootstrap()} options of
{helpb finegray_cif} and {helpb finegray_predict} give CIF/prediction standard
errors, not coefficient ones.

{pstd}
{bf:Diagnostics.} {cmd:finegray} reports the weight design and its
sensitivity: {cmd:e(N_weight_strata)}, {cmd:e(min_weight_prob)} (the smallest A the scan
actually consults), {cmd:e(max_lt_weight)}, and the counts {cmd:e(N_prob_warn)} and
{cmd:e(N_weight_warn)} with the affected groups in {cmd:e(weight_warn_strata)}. Unlike the
censoring-only weight, ZZF weights may legitimately exceed 1, so a maximum
weight above 1 under delayed entry is expected rather than alarming. If A
reaches exactly zero at a consulted denominator or pooled stabilizer, the
corresponding risk contribution is undefined and
{cmd:finegray} refuses the fit with {cmd:r(459)}, naming the offending groups, instead of
failing later as a convergence error. Weights that are merely extreme are
reported as warnings and the fit proceeds.

{pstd}
{bf:Proportional hazards diagnostic:} Use {cmd:finegray_phtest} after estimation
for an exploratory diagnostic of the proportional subdistribution hazards
assumption. It uses raw Schoenfeld residuals and simple residual-time
correlations, with no test statistic or p-value. See {helpb finegray_phtest}.

{pstd}
Both {cmd:finegray_phtest} and {cmd:finegray_predict, schoenfeld} require the
original {cmd:stset} estimation data ({cmd:_t}, {cmd:_d}, and
{cmd:e(sample)}); they cannot be run after loading a new
dataset. {cmd:finegray_predict, xb} works on compatible data containing the
model covariates. Point {cmd:cif} and {cmd:basecshazard} predictions also need
{cmd:_t} or {opt timevar()} and a resolvable cached or posted fitted baseline.

{pmore}
{bf:Cumulative incidence curves:} Use {helpb finegray_cif} after estimation to
plot the predicted CIF with a pointwise confidence band, an analogue of
{cmd:stcurve, cif} that can also plot the interval.

{pmore}
{cmd:finegray_cif} also reports the CIF at fixed horizons such as 5 years and
exports the numeric estimates. For a confidence interval on each subject's CIF,
use {cmd:finegray_predict, cif ci}.

{pmore}
{bf:Multiple records per subject:} {cmd:finegray} accepts datasets in which a
subject contributes more than one in-sample record (delayed entry,
{cmd:(start,stop]} intervals, or data run through {helpb stsplit}) as long as
the intervals are contiguous (no gaps or overlaps) and the model covariates,
{opt strata()}, {opt truncstrata()}, and {opt cluster()} variables are constant
within {cmd:id()}.

{pmore}
Such records are reduced automatically to one risk-set unit per subject
(earliest entry, latest exit, final status), and the engine's left-truncation
handles the entry times.

{pmore}
{bf:The reduction is visible in {cmd:e(sample)}.} On multiple-record data
{cmd:e(sample)} marks only the single retained record per subject -- not every
record you supplied -- and {cmd:e(N)} counts subjects rather than records. So
{cmd:count if e(sample)} returns the number of subjects, and any
{cmd:summarize}, {cmd:tabulate} or {cmd:list} restricted to {cmd:e(sample)}
sees one row per subject. The dataset itself is not reduced: your records are
all still there, and no row is dropped or reordered. Single-record data is
unaffected, since each subject already occupies exactly one row.

{pmore}
For multi-record fits, {cmd:finegray} records each subject's earliest entry
time in the variable {cmd:_fg_entry}, which post-estimation commands
({helpb finegray_cif}, {helpb finegray_phtest}, and the {opt ci},
{opt schoenfeld}, and {opt bootstrap()} paths of {helpb finegray_predict})
require to reconstruct the estimation risk sets. It persists like the
{cmd:_fg_*} factor-variable columns and is dropped or refreshed by the next
{cmd:finegray} run; do not drop it while post-estimation is still needed.

{pmore}
Covariates that change within subject are not supported and produce an error. In
particular, internal time-varying covariates do not retain the model's
direct CIF interpretation after a competing event. Deterministic effects of
baseline covariates that vary with analysis time are defined by Fine and Gray
(1999), but this implementation does not fit them. See {helpb stcox} for a
cause-specific model when internal time-varying covariates are scientifically
appropriate.

{pstd}
{bf:Margins:} {cmd:margins} is supported after {cmd:finegray} for the linear
predictor ({cmd:predict(xb)}) in models without factor-variable expansion.

{pstd}
For factor-variable models, {cmd:margins} cannot address the
{it:factor terms}: the estimation carries generated design columns rather than
native Stata factor notation, so {cmd:margins grp}, {cmd:margins, dydx(grp)} and
{cmd:margins, at(grp=(1 2 3))} all stop with {cmd:r(322)}, naming the variable
that is not in the covariate list. Margins for a {it:continuous} covariate in
the same fit remain valid -- {cmd:margins, dydx(x) predict(xb)} returns that
covariate's coefficient and its standard error -- as does a plain
{cmd:margins}, which averages the linear predictor. Use {helpb finegray_cif}
with {opt at()} for covariate-profile quantities on the CIF scale, which is
what a factor-level margin after this estimator is usually asked for.

{pstd}
{bf:Coefficient names.} The coefficient table, {cmd:e(b)} and {cmd:e(V)} carry
the factor-variable terms you typed ({cmd:1.pelnode}, {cmd:1.pelnode#c.ifp}), so
{helpb test}, {helpb testparm}, {helpb estimates table} and estout-style
exporters all address coefficients in your own vocabulary. The package-owned
design columns that hold the expansion ({cmd:_fg_pelnode_1} and the like) are
reported separately in {cmd:e(covariates)}; they are what {helpb finegray_cif}
and {helpb finegray_predict} read, and {cmd:at()} accepts them by name as an
override; ordinarily you name the underlying variables instead. See {help finegray##sideeffects:Dataset side effects}.

{pstd}
{bf:Compatibility with other implementations.} Without delayed entry,
{cmd:finegray} uses the ordinary Fine-Gray risk set and variance conventions
described above. {helpb finegray_predict} maps its baseline CIF, linear
predictor, cumulative subhazard, and Schoenfeld residuals to the corresponding
{helpb stcrreg} quantities. At tied cause-event times the commands may assign
individual Schoenfeld residuals differently, while preserving each event-time
sum. Under delayed entry, {cmd:stcrreg} uses a censoring-only weight, so parity
is neither expected nor a validity criterion.

{pstd}
{bf:Performance.} For fixed covariate dimension and a bounded number of weight
strata, each forward-backward score scan is O(np) and the information scan is
O(np^2); the command does not expand data over event times. Posting
{cmd:e(basehaz)} is opt-in because constructing a Stata matrix with one row per
cause-event time has superlinear naming overhead. The baseline remains
available through the Mata cache/rebuild path and through
{cmd:predict, basecshazard} without that matrix.

{pstd}
{bf:Limitations:} The {cmd:by:} prefix is not supported because {cmd:finegray}
requires {cmd:stset} with {cmd:id()}, which is incompatible with
{cmd:by:} processing.

{pstd}
To fit models on subgroups, use {cmd:if} conditions. Sampling weights
({cmd:fweight}, {cmd:pweight}) are not supported.

{pstd}
{bf:References and citation scope}

{pstd}
Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a
competing risk. {it:JASA} 1999; 94(446): 496-509.

{pstd}{browse "https://doi.org/10.1080/01621459.1999.10474144":doi:10.1080/01621459.1999.10474144}{p_end}

{pstd}
Zhang X, Zhang M-J, Fine J. A proportional hazards regression model for the
subdistribution with right-censored and left-truncated competing risks
data. {it:Statistics in Medicine} 2011; 30(16): 1933-1951.

{pstd}{browse "https://doi.org/10.1002/sim.4264":doi:10.1002/sim.4264}{p_end}

{pstd}
Geskus RB. Cause-specific cumulative incidence estimation and the Fine and Gray
model under both left truncation and right censoring. {it:Biometrics}
2011; 67(1): 39-49.

{pstd}{browse "https://doi.org/10.1111/j.1541-0420.2010.01420.x":doi:10.1111/j.1541-0420.2010.01420.x}{p_end}

{pstd}
Bellach A, Kosorok MR, Gilbert PB, Fine JP. General regression model for the
subdistribution of a competing risk under left-truncation and
right-censoring. {it:Biometrika} 2020; 107(4): 949-964.

{pstd}{browse "https://doi.org/10.1093/biomet/asaa034":doi:10.1093/biomet/asaa034}{p_end}

{pstd}
Bellach A, Kosorok MR, Rüschendorf L, Fine JP. Weighted NPMLE for the
subdistribution of a competing risk. {it:JASA} 2019; 114(525): 259-270.

{pstd}{browse "https://doi.org/10.1080/01621459.2017.1401540":doi:10.1080/01621459.2017.1401540}{p_end}

{pstd}
Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable algorithms for large competing
risks data. {it:Journal of Computational and Graphical Statistics}
2021; 30(3): 685-693.

{pstd}{browse "https://doi.org/10.1080/10618600.2020.1841650":doi:10.1080/10618600.2020.1841650}{p_end}

{pstd}
Fine and Gray (1999) ground the model, right-censoring risk sets, variance
structure, and Schoenfeld-type residual plots. Zhang et al. (2011) ground
left-truncated Weight 1 in its published b/S form; Geskus (2011) grounds the
G*H product-limit representation and tie ordering; Bellach et al. (2020) ground
their continuous-time equivalence. Bellach et al. (2019) ground the
estimated-weight variance term and the limitation for internal time-varying
covariates. Kawaguchi et al. (2021) ground only the right-censoring, no-ties
scan decomposition, not this package's tie, left-truncation, or variance
extensions. See {helpb finegray_phtest} for the package diagnostic's scope.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup}

{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}

{pstd}
{bf:Basic model}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}

{pstd}
{bf:Stratified censoring distribution}

{phang2}{cmd:. finegray ifp tumsize, compete(status) cause(1) strata(pelnode)}{p_end}

{pstd}
{bf:Model-based standard errors (default is robust/sandwich)}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1) norobust}{p_end}

{pstd}
{bf:Log-SHR (no exponentiation)}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1) noshr}{p_end}

{pstd}
{bf:CIF prediction}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}
{phang2}{cmd:. finegray_predict cif_hat, cif}{p_end}

{pstd}
{bf:Cumulative-incidence curve and fixed-horizon table}

{phang2}{cmd:. finegray_cif, ci}{p_end}
{phang2}{cmd:. finegray_cif, attime(1 5 8) ci}{p_end}

{pstd}
{bf:Factor variables (automatic indicator expansion)}

{phang2}{cmd:. finegray i.pelnode ifp, compete(status) cause(1)}{p_end}

{pstd}
{bf:Factor variables with specified base category}

{phang2}{cmd:. finegray ib1.pelnode ifp, compete(status) cause(1)}{p_end}

{pstd}
{bf:Interaction: factor x continuous (full factorial)}

{phang2}{cmd:. finegray i.pelnode##c.ifp tumsize, compete(status) cause(1)}{p_end}

{pstd}
{bf:Margins (adjusted predictions)}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}
{phang2}{cmd:. margins, at(ifp=(0 5 10)) predict(xb)}{p_end}
{phang2}{cmd:. margins, dydx(ifp) predict(xb)}{p_end}

{pstd}
{bf:Compare with stcrreg} (requires different stset)

{phang2}{cmd:. stset dftime, failure(status==1) id(stnum)}{p_end}
{phang2}{cmd:. stcrreg ifp tumsize pelnode, compete(status == 2)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of subjects{p_end}
{synopt:{cmd:e(N_fail)}}subjects with a cause-of-interest event{p_end}
{synopt:{cmd:e(N_compete)}}subjects with a competing event{p_end}
{synopt:{cmd:e(N_cens)}}censored subjects{p_end}
{synopt:{cmd:e(ll)}}log pseudo-likelihood{p_end}
{synopt:{cmd:e(ll_0)}}log pseudo-likelihood at b=0 (the null model){p_end}
{synopt:{cmd:e(chi2)}}Wald chi-squared{p_end}
{synopt:{cmd:e(p)}}p-value for model chi-squared{p_end}
{synopt:{cmd:e(df_m)}}model degrees of freedom (numerical rank of {cmd:e(V)}){p_end}
{synopt:{cmd:e(rank)}}rank of {cmd:e(V)}{p_end}
{synopt:{cmd:e(N_clust)}}number of clusters (only with {opt cluster()}){p_end}
{synopt:{cmd:e(converged)}}1 if converged, 0 otherwise{p_end}
{synopt:{cmd:e(N_delayed)}}number of subjects entering after time 0 (delayed entry){p_end}
{synopt:{cmd:e(N_G_trunc)}}observations with censoring survivor {it:G(t)} floored at 1e-10{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}
{synopt:{cmd:e(cause)}}cause of interest value{p_end}
{synopt:{cmd:e(censvalue)}}censoring value{p_end}
{synopt:{cmd:e(iterate)}}maximum iterations{p_end}
{synopt:{cmd:e(tolerance)}}convergence tolerance{p_end}
{synopt:{cmd:e(N_weight_strata)}}number of observed joint (censoring x entry) weight strata{p_end}
{synopt:{cmd:e(min_weight_prob)}}smallest weight probability A actually consulted by the scan{p_end}
{synopt:{cmd:e(max_lt_weight)}}largest retained subject-by-cause-time weight{p_end}
{synopt:{cmd:e(N_prob_warn)}}count of consulted weight probabilities with A < 1e-10{p_end}
{synopt:{cmd:e(N_weight_warn)}}count of retained subject-by-cause-time weights above 1e6{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:finegray}{p_end}
{synopt:{cmd:e(cmdline)}}full estimation command as typed{p_end}
{synopt:{cmd:e(refitcmd)}}estimation command used by the {opt bootstrap()} refits{p_end}
{synopt:{cmd:e(predict)}}{cmd:finegray_predict}{p_end}
{synopt:{cmd:e(depvar)}}{cmd:_t} (the {cmd:stset} analysis time; as {helpb stcrreg}){p_end}
{synopt:{cmd:e(compete)}}competing events variable name{p_end}
{synopt:{cmd:e(compete_values)}}values of {cmd:e(compete)} pooled as competing events{p_end}
{synopt:{cmd:e(covariates)}}covariate variable names{p_end}
{synopt:{cmd:e(entryvar)}}entry-time column of a multiple-record fit; empty otherwise{p_end}
{synopt:{cmd:e(fvvarlist)}}original factor-variable specification{p_end}
{synopt:{cmd:e(fvsemantic)}}factor-variable expansion semantics{p_end}
{synopt:{cmd:e(strata)}}censoring stratification variables{p_end}
{synopt:{cmd:e(truncstrata)}}entry stratification variables; if {opt truncstrata()} specified{p_end}
{synopt:{cmd:e(lt_weight)}}weight computed; see {help finegray##lt:Left truncation}{p_end}
{synopt:{cmd:e(lt_vce)}}variance computed under delayed entry{p_end}
{synopt:{cmd:e(bh_seq)}}internal key to the cached baseline; see below{p_end}
{synopt:{cmd:e(weight_warn_strata)}}joint-group codes flagged by the weight diagnostics{p_end}
{synopt:{cmd:e(clustvar)}}cluster variable; if {cmd:cluster()} specified{p_end}
{synopt:{cmd:e(vce)}}variance estimation method{p_end}
{synopt:{cmd:e(vce_meat)}}which sandwich meat was used{p_end}
{synopt:{cmd:e(title)}}Fine-Gray competing risks regression{p_end}
{synopt:{cmd:e(marginsok)}}{cmd:xb} (empty for factor-variable models){p_end}
{synopt:{cmd:e(properties)}}b V{p_end}
{synopt:{cmd:e(datasignature)}}signature of the estimation data{p_end}
{synopt:{cmd:e(datasignaturevars)}}variables covered by {cmd:e(datasignature)}{p_end}
{synopt:{cmd:e(sample)}}estimation-sample indicator{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector (log-SHR){p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}
{synopt:{cmd:e(basehaz)}}baseline cumulative subhazard; only with {opt basehaz}{p_end}

{pstd}
{cmd:e(bh_seq)} is bookkeeping, not a statistic. The baseline curve is kept in
Mata after every fit, where it costs nothing, so that {helpb finegray_cif} and
{helpb finegray_predict} can use it without ever building a Stata matrix -- which
is also what lets {cmd:predict, cif} work on new data, after the estimation sample
has been dropped. {cmd:e(bh_seq)} says which fit that cached curve belongs to: it
must be presented by post-estimation and is refused if it does not match, so a
curve from an earlier fit can never answer for the current one. You should not
need to read it.

{pstd}
{cmd:e(basehaz)} holds the baseline cumulative subdistribution hazard H0(t) as a
right-continuous step function: column {it:time} lists the distinct
cause-of-interest event times and column {it:cumhazard} the corresponding H0(t). It
is posted {bf:only when} {opt basehaz} is specified, because a matrix with one
row per event time is O(rows^2) to create in Stata; see {opt basehaz} under
{help finegray##options:Options}. For the baseline as a variable, which costs
O(N), use {cmd:predict, basecshazard} -- the same idiom {helpb stcrreg} uses.

{pstd}
The baseline CIF (the analogue of {cmd:stcrreg}'s {cmd:basecif}) is 1 -
exp(-{it:cumhazard}); an individual's CIF rescales the hazard by
exp(z'beta). {helpb finegray_predict} resolves the fitted baseline from the
opt-in matrix, the fit-specific Mata cache, or a rebuild from unchanged
estimation data.

{pstd}
{cmd:finegray} also records dataset characteristics
{cmd:_dta[_finegray_estimated]}, {cmd:_dta[_finegray_compete]},
{cmd:_dta[_finegray_cause]}, and {cmd:_dta[_finegray_covars]}. The first of
these is {cmd:1} after a successful fit and {cmd:0} when a re-fit began mutating
package-owned columns and then failed; {cmd:0} is refused by every
post-estimation command with {cmd:r(301)}, and is deliberately distinct from the
characteristic being absent altogether, which is what a dataset saved before the
fit looks like.

{pstd}
When factor variables are used it also records {cmd:_dta[_finegray_fvvars]} and
{cmd:_dta[_finegray_fvvarlist]}. These persist with the dataset and allow
subsequent {cmd:finegray} runs to clean up prior finegray-generated
factor-variable columns safely.

{pstd}
When multiple records per subject are reduced, {cmd:finegray} records the name
of the persistent entry-time variable ({cmd:_fg_entry}) in
{cmd:_dta[_finegray_entryvar]} and in {cmd:e(entryvar)}; post-estimation
commands read the characteristic, falling back to {cmd:e(entryvar)} when the
dataset in memory does not carry it, and reconstruct each subject's risk window
from it. Two records of the same fact because the characteristic travels with
the data and {cmd:e()} travels with the estimates: reading {cmd:_t0} instead
would silently substitute per-record entry times for subject-level ones.

{pstd}
Constant and exactly collinear covariate columns are not identified by the
unpenalized Fine-Gray model. {cmd:finegray} rejects such specifications with
{cmd:r(459)} and names the expanded terms that must be removed or
recoded; it does not silently impose a ridge penalty.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.2.0, 2026-08-16{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:Also see}

{psee}
Online: {helpb finegray_predict}, {helpb finegray_cif}, {helpb finegray_phtest},
{helpb stcrreg}, {helpb stcox}, {helpb stset}

{hline}
