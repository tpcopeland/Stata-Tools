{smcl}
{* *! version 1.1.4  10jul2026}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "finegray_cif" "help finegray_cif"}{...}
{vieweralsosee "finegray_phtest" "help finegray_phtest"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "finegray##syntax"}{...}
{viewerjumpto "Description" "finegray##description"}{...}
{viewerjumpto "Options" "finegray##options"}{...}
{viewerjumpto "Remarks" "finegray##remarks"}{...}
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
{synopt:{opth cl:uster(varname:numvar)}}adjust SEs for intragroup correlation (numeric only){p_end}
{synopt:{opt noadj:ust}}omit finite-sample adjustment to the sandwich{p_end}
{synopt:{opt norob:ust}}report model-based SEs, not sandwich{p_end}

{syntab:Reporting}
{synopt:{opt noshr}}report coefficients, not hazard ratios{p_end}
{synopt:{opt l:evel(#)}}set confidence level; default is {cmd:c(level)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt baseh:az}}post the baseline cumulative subhazard in {cmd:e(basehaz)}{p_end}

{syntab:Optimization}
{synopt:{opt iter:ate(#)}}maximum iterations; default is {cmd:iterate(200)}{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance; default is {cmd:tolerance(1e-8)}{p_end}
{synoptline}
{p 4 6 2}
{it:varlist} may contain factor variables and interactions; see
{help fvvarlist}. Supports {cmd:i.}{it:varname},
{cmd:ib}{it:#}{cmd:.}{it:varname}, {cmd:c.}{it:varname}, {cmd:#}, and {cmd:##}
operators.
{p_end}
{p 4 6 2}
Data must be {cmd:stset} with {cmd:id()}. A subject may contribute multiple
records when the model covariates are constant within {cmd:id()} (e.g. delayed
entry or {helpb stsplit} data); such records are reduced automatically to one
risk-set unit. Left-truncated (delayed entry) data are supported.
{p_end}

{pstd}
{bf:Post-estimation:}

{p 8 17 2}
{cmd:finegray_predict}
{dtype}
{newvar}
{ifin}{cmd:,}
[{opt xb} {opt cif} {opt sch:oenfeld} {opt time:var(varname)} {opt ci}
{opt l:evel(#)} {opt boot:strap(#)} {opt seed(#)}]

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
The estimator uses a native O(np) forward-backward scan algorithm (Kawaguchi et
al. 2021) that avoids data expansion entirely, making it substantially faster
than {cmd:stcrreg} for large datasets.

{pstd}
See {it:Performance} under {help finegray##remarks:Remarks} for benchmarks.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth compete(varname)} specifies the variable containing event types. Typically
coded as 0 = censored, 1 = cause 1, 2 = cause 2, etc. Must be consistent with
the {cmd:stset} failure indicator.

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
entry) weight strata are subject to a hard support boundary: at most {bf:100}
observed joint strata, each holding at least {bf:20} estimation-sample
subjects. Exceeding either boundary is {cmd:r(459)}; groups are never silently
pooled. See {help finegray##lt:Left truncation} for why the boundary applies to {opt strata()} as well
once entry is delayed.

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
number of clusters is reported in the header and stored in {cmd:e(N_clust)}.

{phang}
{opt noadjust} suppresses the finite-sample adjustment applied to the robust
(sandwich) variance. By default {cmd:finegray} multiplies the sandwich by {it:N}/({it:N}-1),
or by {it:g}/({it:g}-1) when {opt cluster()} is specified, matching {helpb stcrreg}. {opt noadjust} is not
allowed with {opt norobust}, which has no such adjustment.

{phang}
{opt norobust} reports model-based standard errors from the observed information
matrix instead of the default Huber/White/sandwich estimator.

{pmore}
{bf:These standard errors are not valid for inference.} The Fine-Gray objective is
a pseudo-likelihood: the inverse-probability-of-censoring weights make
subjects' contributions dependent, so the inverse information matrix does not
estimate the sampling variance of the coefficients. Model-based standard
errors are generally too small, and their confidence intervals do not have
nominal coverage. {opt norobust} exists so that the naive likelihood variance can be
inspected and compared; use the default sandwich variance to report
results. {cmd:finegray} prints a warning whenever {opt norobust} is used.

{pmore}
{bf:Under delayed entry the defect is measured, severe, and grows with the truncation fraction.} The
truncation weights are themselves estimated, and the information matrix does
not carry their uncertainty. In this package's coverage study (1,000
replications per arm against a known truth, nominal 95%), {opt norobust} intervals
covered 89% at 37% truncation and 85% at 69% truncation, and the model-based
standard errors ran up to 38% below the true sampling variability; the default
sandwich covered 94-96% in every arm. This settles a genuine disagreement in
the literature — Geskus (2011, p.44) argues no sandwich is needed under left
truncation, while Bellach et al. (2020, sec. 5) report exactly this
truncation-dependent undercoverage. On this estimator,
{bf:the measurement agrees with Bellach.} Do not use {opt norobust} for inference on
left-truncated data.

{pmore}
{bf:Scope of the sandwich estimator.} The default sandwich treats the estimated
inverse-probability-of-censoring weights as {it:fixed}; it does not propagate the
uncertainty in the estimated censoring distribution G(t). This is the same
variance {helpb stcrreg} reports, and coefficients are unaffected — only the standard
errors are. Against {cmd:cmprsk::crr}, whose variance includes the censoring-weight
nuisance term, {cmd:finegray}'s standard errors differ by roughly 0.2% in relative
terms on tie-free data. Where that difference matters, {opt bootstrap()} in
{helpb finegray_cif} and {helpb finegray_predict} resamples subjects and re-estimates G(t) in
every replication, so it captures the censoring-weight uncertainty exactly.

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
{opt basehaz} posts the baseline cumulative subdistribution hazard in
{cmd:e(basehaz)}, a matrix with one row per distinct cause-event time and columns
{cmd:time} and {cmd:cumhazard}. It is not posted by default: that matrix has
roughly N/2 rows, and building a Stata matrix that tall is O(rows^2), which at
N = 200,000 took longer than the model fit itself. You do not need it for
post-estimation -- {helpb finegray_cif} and {helpb finegray_predict} rebuild the
same curve internally -- and {cmd:predict, basecshazard} returns the baseline as
a variable at O(N) cost. Ask for {opt basehaz} when you want the matrix itself.

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
{cmd:ib}{it:#}{cmd:.}{it:varname}, {cmd:c.}{it:varname}, {cmd:#} (interaction),
and {cmd:##} (full factorial with main effects).

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
{bf:Note:} {cmd:finegray_predict} reconstructs factor-variable design columns on
demand via {cmd:fvrevar}. This requires that the current data preserve the same
factor-level support as the estimation sample.

{pstd}
If a factor level is dropped or absent, prediction will fail with an error. The
persistent {cmd:_fg_*} columns are retained for convenience but are not required
for prediction when the factor support is intact.

{pstd}
{bf:Interpretation:} A subdistribution hazard ratio (SHR) > 1 indicates that the
covariate increases the cumulative incidence of the cause of interest.

{pstd}
Unlike cause-specific hazard ratios, SHRs have a direct interpretation in terms
of the cumulative incidence function.

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
{cmd:finegray} instead targets the {bf:stabilized Zhang-Zhang-Fine Weight 1}
estimator. Writing A(t) for the probability of being under observation at t, a
subject retained in the risk set after a competing event at X_i carries weight
A(t-)/A(X_i-) rather than the censoring-only ratio G(t-)/G(X_i-). A(t) is
computed as the product of the delayed-entry-aware censoring survivor G and a
reverse-time product-limit estimator H of the entry distribution (Geskus
2011), and {cmd:e(lt_weight)} reports {cmd:zzf1_geskus} whenever this branch is taken. The
two forms were verified to agree to machine precision across every tied-time
collision class before either was shipped.

{pstd}
{bf:Consequences you should expect.} Delayed-entry coefficients, standard errors,
baseline hazards, predictions and CIFs all {it:change} relative to earlier versions
of {cmd:finegray} and relative to {cmd:stcrreg}. Results with no delayed entry are
unchanged, bit for bit: when every subject enters at the origin, H is
identically 1, A collapses to G, and the estimator is the existing
right-censoring path. {cmd:e(lt_weight)} reports {cmd:right_censoring} there, and
{cmd:e(lt_vce)} reports {cmd:not_applicable}.

{pstd}
{bf:Which weights are valid for your data.} Pooled weights (no {opt truncstrata()})
assume the entry and censoring mechanisms do not depend on the
covariates. When entry depends on an observed discrete group, name it in
{opt truncstrata()}; when censoring does, name it in {opt strata()}. The two are
cross-classified internally. Entry mechanisms that depend continuously on
covariates are {bf:not supported} in this release and are not approximated silently
— a continuously subject-specific weight destroys the shared time factor the
scan is built on. Internal time-varying covariates remain prohibited, as they
are for any subdistribution model.

{pstd}
{bf:Support boundary, and a breaking change.} Under delayed entry the weight A is
estimated {it:per joint weight stratum}, so every level of {opt strata()} is also a
weight stratum even when {opt truncstrata()} is not specified. At most 100 joint
strata are supported, each with at least 20 estimation-sample subjects; beyond
that {cmd:finegray} stops with {cmd:r(459)} rather than pooling groups behind your
back. {bf:A delayed-entry model with many {opt strata()} levels that fitted in version 1.1.4 may now stop with {cmd:r(459)}.} The
same model still fits without delayed entry, because that branch is required
to remain bit-identical. If you hit this boundary, reduce the number of
censoring strata.

{pstd}
{bf:Standard errors under delayed entry.} Use the default (sandwich) variance. The
literature genuinely disagrees here — Geskus (2011, p.44) argues that no
sandwich is needed under left truncation, because a subject's weight is 1 at
its own event time, while Bellach et al. (2020, sec. 5) report that the
fixed-weight/inverse-information variance is biased and undercovers,
increasingly so as the truncation fraction rises. {cmd:finegray} settled the
question by measuring it (1,000 replications per arm against a known truth,
nominal 95% coverage):

{p2colset 9 34 36 2}{...}
{p2col:{it:truncation fraction}}{it:norobust}{space 6}{it:default (sandwich)}{p_end}
{p2col:0% (no delayed entry)}0.95{space 12}0.95{p_end}
{p2col:37%}0.89{space 12}0.95{p_end}
{p2col:69%}0.85{space 12}0.95{p_end}
{p2colreset}{...}

{pstd}
On this estimator the measurement agrees with Bellach: the model-based
standard errors ran up to 38% below the true sampling variability, and the
failure worsened with truncation. The default sandwich covered 94-96% in every
arm tested, including 69% truncation and stratified entry. {cmd:e(lt_vce)} records
which variance a fit actually used ({cmd:fg_sandwich} or {cmd:model_based}), and {opt norobust}
prints this warning at run time. {opt cluster()} fits use the cluster-robust form of
the same sandwich.

{pstd}
{bf:What the sandwich does not do.} It treats the estimated weights as fixed — it
does not propagate the uncertainty in estimating G and H. Zhang, Zhang and
Fine (2011, Appendix B) give a two-part variance whose second and third terms
account for that uncertainty, and it is not implemented here. The coverage
study above is the evidence that the fixed-weight sandwich is nevertheless
adequate across the supported range; where you need the weight-estimation
uncertainty propagated exactly, {opt bootstrap()} in {helpb finegray_cif} and
{helpb finegray_predict} re-estimates G, H and the weight strata in every replication.

{pstd}
{bf:Diagnostics.} {cmd:finegray} reports the weight design and its
sensitivity: {cmd:e(N_weight_strata)}, {cmd:e(min_weight_prob)} (the smallest A the scan
actually divides by), {cmd:e(max_lt_weight)}, and the counts {cmd:e(N_prob_warn)} and
{cmd:e(N_weight_warn)} with the affected groups in {cmd:e(weight_warn_strata)}. Unlike the
censoring-only weight, ZZF weights may legitimately exceed 1, so a maximum
weight above 1 under delayed entry is expected rather than alarming. If A
reaches exactly zero for a retained subject its weight is undefined, and
{cmd:finegray} refuses the fit with {cmd:r(459)}, naming the offending groups, instead of
failing later as a convergence error. Weights that are merely extreme are
reported as warnings and the fit proceeds.

{pstd}
{bf:Proportional hazards diagnostic:} Use {cmd:finegray_phtest} after estimation
for an approximate test of the proportional subdistribution hazards assumption
via scaled Schoenfeld residuals. See {helpb finegray_phtest} for details on the
diagonal-only scaling and independent per-variable test structure.

{pstd}
Both {cmd:finegray_phtest} and {cmd:finegray_predict, schoenfeld} require the
original {cmd:stset} estimation data ({cmd:_t}, {cmd:_d}, and
{cmd:e(sample)}); they cannot be run after loading a new
dataset. {cmd:finegray_predict, xb} and {cmd:finegray_predict, cif} work on any
dataset containing the model covariates.

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
the model covariates are constant within {cmd:id()}.

{pmore}
Such records are reduced automatically to one risk-set unit per subject
(earliest entry, latest exit, final status), and the engine's left-truncation
handles the entry times.

{pmore}
For multi-record fits, {cmd:finegray} records each subject's earliest entry
time in the variable {cmd:_fg_entry}, which post-estimation commands
({helpb finegray_cif}, {helpb finegray_phtest}, and the {opt ci},
{opt schoenfeld}, and {opt bootstrap()} paths of {helpb finegray_predict})
require to reconstruct the estimation risk sets. It persists like the
{cmd:_fg_*} factor-variable columns and is dropped or refreshed by the next
{cmd:finegray} run; do not drop it while post-estimation is still needed.

{pmore}
Genuinely time-varying covariates are not supported and produce an error,
because the subdistribution hazard is not defined with internal time-varying
covariates (see {helpb stcox} for a cause-specific model with time-varying
covariates).

{pstd}
{bf:Margins:} {cmd:margins} is supported after {cmd:finegray} for the linear
predictor ({cmd:predict(xb)}) in models without factor-variable expansion.

{pstd}
For factor-variable models, {cmd:margins} is not supported because the
estimation uses generated design columns rather than native Stata factor
notation.

{pstd}
{bf:Cross-validation against other implementations:} {cmd:finegray} is
systematically validated against three independent implementations: Stata's
{cmd:stcrreg}, R's {cmd:cmprsk::crr}, and R's {cmd:fastcmprsk::fastCrr}.

{pstd}
The cross-validation suite covers coefficients, standard errors,
log-likelihoods, cumulative incidence functions, baseline hazards, stratified
censoring, and post-estimation predictions (xb, CIF, and Schoenfeld residuals)
across real and simulated datasets.

{pstd}
Point estimates (coefficients) and log pseudo-likelihoods are numerically
identical across all four implementations.

{pstd}
Against {cmd:cmprsk::crr}, coefficients match to 6 decimal places, robust SEs
match to 3 decimal places, model-based SEs match to 6 decimal places, and CIF
predictions match to 6 decimal places.

{pstd}
Against {cmd:fastcmprsk::fastCrr}, coefficients and log-likelihoods match to 6
decimal places, and the baseline cumulative hazard matches to 8 decimal places.

{pstd}
Against {cmd:stcrreg}, coefficients match within 1e-4 across all tested
configurations including multiple covariate combinations, both causes, factor
variables, cluster SEs, and left-truncated data.

{pstd}
The {opt strata()} option is cross-validated against
{cmd:crr(..., cengroup=)}. Coefficients and log pseudo-likelihood agree to
numerical precision, CIFs agree within 1e-5, and robust SEs agree within
0.1%. Each retained competing-event subject is weighted by the censoring
survival from that subject's own stratum.

{pstd}
{bf:Technical note on standard errors:} Coefficients agree closely across
implementations; standard errors are where they diverge, because the
implementations do not all estimate the same variance.

{pstd}
{cmd:finegray}'s default sandwich treats the estimated censoring weights as fixed
and applies the same finite-sample adjustment as {helpb stcrreg} ({it:N}/({it:N}-1), or {it:g}/({it:g}-1)
under {opt cluster()}). Standard errors agree with {cmd:stcrreg} to within 1e-3 in
relative terms. Versions through 1.1.4 omitted the finite-sample adjustment,
so they reproduced {cmd:stcrreg}'s {cmd:noadjust} variance while presenting it as the
default; {opt noadjust} now reproduces those earlier numbers exactly.

{pstd}
{cmd:cmprsk::crr} computes a sandwich that additionally propagates the uncertainty
in the estimated censoring distribution G(t). Coefficients match {cmd:finegray} to 8
decimal places, but its standard errors are larger by roughly 0.2% in relative
terms because {cmd:finegray} omits that nuisance term. To capture censoring-weight
uncertainty exactly, use {opt bootstrap()} in {helpb finegray_cif} or {helpb finegray_predict},
which re-estimates G(t) in every replication.

{pstd}
{cmd:finegray} with {opt norobust} and {cmd:crr$invinf} both report the inverse observed
information matrix, matching to 6 decimal places. Neither is valid for
inference, and neither is a like-for-like replacement for the sandwich
standard errors {cmd:stcrreg} reports.

{pstd}
{cmd:fastcmprsk::fastCrr} uses bootstrap SEs (B=200), a fundamentally different
variance estimator; wider divergence (up to ~50%) is expected.

{pstd}
{bf:Post-estimation predictions vs {help stcrreg}:} The {helpb finegray_predict}
outputs are cross-validated against {cmd:stcrreg}'s native predictions and agree
to numerical precision.

{pstd}
{opt xb} equals {cmd:stcrreg}'s {cmd:predict, xb}; the baseline CIF (covariates
at 0) equals {cmd:predict, basecif}; and {cmd:e(basehaz)} equals {cmd:stcrreg}'s
cumulative-subhazard analogue (H0(t) = -ln(1 - {cmd:basecif})) at each distinct
event time.

{pstd}
The per-observation {opt cif} is the covariate-adjusted CIF 1 -
exp(-H0(t)*exp(z'beta)).

{pstd}
{cmd:stcrreg} produces this quantity through {cmd:stcurve, cif at()} rather than
{cmd:predict} (its {cmd:predict} offers only the baseline {cmd:basecif} and the
relative subhazard), and {cmd:finegray_predict, cif} reproduces it to numerical
precision.

{pstd}
{opt schoenfeld} residuals match {cmd:stcrreg}'s {cmd:predict, schoenfeld}
exactly at untied cause-event times.

{pstd}
At a {bf:tied} cause-event time the two implementations partition the residual
among the simultaneous events differently, so an individual residual at a tied
time can differ; the {bf:sum} of the residuals within each event time -- and
hence the overall score -- is identical.

{pstd}
See {helpb finegray_predict} for the per-prediction detail.

{pstd}
{bf:Performance:} The forward-backward scan algorithm is O(np) per
Newton-Raphson iteration, compared to O(nDp) for {cmd:stcrreg}, where D is the
number of unique event times. Benchmarks on simulated competing risks data (3
covariates, Stata/MP):

{col 10}{bf:N}{col 24}{bf:finegray}{col 40}{bf:stcrreg}{col 56}{bf:Speedup}
{col 10}{hline 52}
{col 10}500{col 24}0.04s{col 40}1.5s{col 56}40x
{col 10}1,000{col 24}0.06s{col 40}3.9s{col 56}63x
{col 10}2,000{col 24}0.14s{col 40}15.9s{col 56}114x
{col 10}5,000{col 24}0.27s{col 40}96.8s{col 56}357x
{col 10}10,000{col 24}0.58s{col 40}378.7s{col 56}651x

{pstd}
The speedup grows with sample size because {cmd:stcrreg} expands the dataset by
the number of unique event times.

{pstd}
Runtime is linear in N. Measured CPU time (Stata/MP, 2 covariates, delayed entry,
one truncation stratum), doubling N each row:

{col 10}{bf:N}{col 26}{bf:CPU}{col 40}{bf:vs previous}
{col 10}{hline 40}
{col 10}25,000{col 26}2.0s
{col 10}50,000{col 26}4.0s{col 40}2.0x
{col 10}100,000{col 26}8.3s{col 40}2.1x
{col 10}200,000{col 26}17.5s{col 40}2.1x

{pstd}
{bf:Why {opt basehaz} is not the default:} {cmd:e(basehaz)} carries one row per
distinct cause-event time, so it has roughly N/2 rows. Creating a Stata matrix
that tall is O(rows^2) -- Stata builds one dimension name per row, and the cost
is per name, not per element -- which at N = 200,000 cost 38 seconds on its own,
more than the entire model fit. Requesting {opt basehaz} restores the matrix and
pays that cost. Nothing else needs it: {helpb finegray_cif} and
{helpb finegray_predict} rebuild the same curve in Mata, and
{cmd:predict, basecshazard} returns the baseline as a variable, which is O(N).

{pstd}
{bf:Limitations:} The {cmd:by:} prefix is not supported because {cmd:finegray}
requires {cmd:stset} with {cmd:id()}, which is incompatible with
{cmd:by:} processing.

{pstd}
To fit models on subgroups, use {cmd:if} conditions. Sampling weights
({cmd:fweight}, {cmd:pweight}) are not supported.

{pstd}
{bf:References}

{pstd}
Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a
competing risk. {it:JASA} 1999; 94(446): 496-509.

{pstd}
Zhang X, Zhang M-J, Fine J. A proportional hazards regression model for the
subdistribution with right-censored and left-truncated competing risks
data. {it:Statistics in Medicine} 2011; 30(16): 1933-1951.

{pstd}
Geskus RB. Cause-specific cumulative incidence estimation and the Fine and Gray
model under both left truncation and right censoring. {it:Biometrics}
2011; 67(1): 39-49.

{pstd}
Bellach A, Kosorok MR, Gilbert PB, Fine JP. General regression model for the
subdistribution of a competing risk under left-truncation and
right-censoring. {it:Biometrika} 2020; 107(4): 949-964.

{pstd}
Bellach A, Kosorok MR, Ruschendorf L, Fine JP. Weighted NPMLE for the
subdistribution of a competing risk. {it:JASA} 2019; 114(525): 259-270.

{pstd}
Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable algorithms for large competing
risks data. {it:Journal of Computational and Graphical Statistics}
2021; 30(3): 685-693.

{pstd}
Grambsch PM, Therneau TM. Proportional hazards tests and diagnostics based on
weighted residuals. {it:Biometrika} 1994; 81(3): 515-526.


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
{bf:Interaction: factor x factor}

{phang2}{cmd:. gen byte ifp_grp = (ifp > 10)}{p_end}
{phang2}{cmd:. finegray i.pelnode##i.ifp_grp tumsize, compete(status) cause(1)}{p_end}

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
{synopt:{cmd:e(N_fail)}}number of cause-of-interest events{p_end}
{synopt:{cmd:e(N_compete)}}number of competing events{p_end}
{synopt:{cmd:e(N_cens)}}number of censored observations{p_end}
{synopt:{cmd:e(ll)}}log pseudo-likelihood{p_end}
{synopt:{cmd:e(ll_0)}}log pseudo-likelihood at b=0 (the null model){p_end}
{synopt:{cmd:e(chi2)}}Wald chi-squared{p_end}
{synopt:{cmd:e(p)}}p-value for model chi-squared{p_end}
{synopt:{cmd:e(df_m)}}model degrees of freedom (numerical rank of {cmd:e(V)}){p_end}
{synopt:{cmd:e(rank)}}rank of {cmd:e(V)}{p_end}
{synopt:{cmd:e(N_clust)}}number of clusters (only with {opt cluster()}){p_end}
{synopt:{cmd:e(converged)}}1 if converged, 0 otherwise{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}
{synopt:{cmd:e(cause)}}cause of interest value{p_end}
{synopt:{cmd:e(censvalue)}}censoring value{p_end}
{synopt:{cmd:e(iterate)}}maximum iterations{p_end}
{synopt:{cmd:e(tolerance)}}convergence tolerance{p_end}
{synopt:{cmd:e(N_weight_strata)}}number of observed joint (censoring x entry) weight strata{p_end}
{synopt:{cmd:e(min_weight_prob)}}smallest weight probability A actually consulted by the scan{p_end}
{synopt:{cmd:e(max_lt_weight)}}largest retained subject-by-cause-time weight{p_end}
{synopt:{cmd:e(N_prob_warn)}}count of consulted time-by-stratum cells with A < 1e-10{p_end}
{synopt:{cmd:e(N_weight_warn)}}count of retained subject-by-cause-time weights above 1e6{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:finegray}{p_end}
{synopt:{cmd:e(cmdline)}}full estimation command as typed{p_end}
{synopt:{cmd:e(refitcmd)}}estimation command used by the {opt bootstrap()} refits{p_end}
{synopt:{cmd:e(predict)}}{cmd:finegray_predict}{p_end}
{synopt:{cmd:e(depvar)}}competing events variable name{p_end}
{synopt:{cmd:e(compete)}}competing events variable name{p_end}
{synopt:{cmd:e(covariates)}}covariate variable names{p_end}
{synopt:{cmd:e(fvvarlist)}}original factor-variable specification{p_end}
{synopt:{cmd:e(fvsemantic)}}factor-variable expansion semantics{p_end}
{synopt:{cmd:e(strata)}}censoring stratification variables{p_end}
{synopt:{cmd:e(truncstrata)}}entry stratification variables; if {opt truncstrata()} specified{p_end}
{synopt:{cmd:e(lt_weight)}}weight computed; see {help finegray##lt:Left truncation}{p_end}
{synopt:{cmd:e(lt_vce)}}variance computed under delayed entry{p_end}
{synopt:{cmd:e(weight_warn_strata)}}joint-group codes flagged by the weight diagnostics{p_end}
{synopt:{cmd:e(clustvar)}}cluster variable; if {cmd:cluster()} specified{p_end}
{synopt:{cmd:e(vce)}}variance estimation method{p_end}
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
exp(z'beta). {helpb finegray_predict} uses this matrix to compute the {cmd:cif}
prediction.

{pstd}
{cmd:finegray} also records dataset characteristics
{cmd:_dta[_finegray_estimated]}, {cmd:_dta[_finegray_compete]},
{cmd:_dta[_finegray_cause]}, and {cmd:_dta[_finegray_covars]}.

{pstd}
When factor variables are used it also records {cmd:_dta[_finegray_fvvars]} and
{cmd:_dta[_finegray_fvvarlist]}. These persist with the dataset and allow
subsequent {cmd:finegray} runs to clean up prior finegray-generated
factor-variable columns safely.

{pstd}
When multiple records per subject are reduced, {cmd:finegray} records the name
of the persistent entry-time variable ({cmd:_fg_entry}) in
{cmd:_dta[_finegray_entryvar]}; post-estimation commands read it to
reconstruct each subject's risk window.

{pstd}
Constant and exactly collinear covariate columns are not identified by the
unpenalized Fine-Gray model. {cmd:finegray} rejects such specifications with
{cmd:r(459)} and names the expanded terms that must be removed or
recoded; it does not silently impose a ridge penalty.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.1.4, 2026-07-10{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:Also see}

{psee}
Online: {helpb finegray_predict}, {helpb finegray_cif}, {helpb finegray_phtest},
{helpb stcrreg}, {helpb stcox}, {helpb stset}

{hline}
