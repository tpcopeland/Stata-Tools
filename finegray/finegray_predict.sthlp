{smcl}
{vieweralsosee "finegray" "help finegray"}{...}
{vieweralsosee "finegray_cif" "help finegray_cif"}{...}
{vieweralsosee "finegray_phtest" "help finegray_phtest"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "finegray_predict##syntax"}{...}
{viewerjumpto "Description" "finegray_predict##description"}{...}
{viewerjumpto "Options" "finegray_predict##options"}{...}
{viewerjumpto "Examples" "finegray_predict##examples"}{...}
{viewerjumpto "Stored results" "finegray_predict##results"}{...}
{viewerjumpto "Author" "finegray_predict##author"}{...}
{title:Title}

{p2colset 5 28 30 2}{...}
{p2col:{cmd:finegray_predict} {hline 2}}Post-estimation predictions after finegray{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 28 2}
{cmd:finegray_predict}
{dtype}
{newvar}
{ifin}{cmd:,}
[{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt xb}}linear predictor z'beta (default){p_end}
{synopt:{opt cif}}cumulative incidence function{p_end}
{synopt:{opt sch:oenfeld}}Schoenfeld residuals at cause-event times{p_end}
{synopt:{opth time:var(varname)}}use {it:varname} instead of {cmd:_t} for time{p_end}
{synopt:{opt ci}}also generate CIF confidence limits{p_end}
{synopt:{opt boot:strap(#)}}compute bootstrap-based {opt ci} limits with {it:#} subject resamples{p_end}
{synopt:{opt seed(#)}}random-number seed for {opt bootstrap()}{p_end}
{synopt:{opt l:evel(#)}}confidence level for {opt ci}; default {cmd:c(level)}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray_predict} generates predictions after {helpb finegray}. Three
prediction types are available:

{phang2}
{bf:xb} (default) computes the linear predictor z'beta from the Fine-Gray
model coefficient vector.

{phang2}
{bf:cif} computes the cumulative incidence function: CIF(t|z) = 1 -
exp(-H0(t) * exp(z'beta)), where H0(t) is the baseline cumulative
subdistribution hazard stored in {cmd:e(basehaz)}.

{phang2}
{bf:schoenfeld} computes Schoenfeld residuals at cause-event times. For a
model with p covariates, this creates p variables: {it:newvar} for the first
covariate, {it:newvar}{cmd:_2} through {it:newvar}{cmd:_}{it:p} for the
rest. Residuals are missing for non-cause-event observations.

{pstd}
{bf:What time point does the CIF use?} By default, {opt cif} evaluates the
CIF at {bf:each observation's own analysis time} {cmd:_t} — one predicted CIF
per subject, at the follow-up (event or censoring) time that subject
contributes. It is {it:not} a single fixed horizon and {it:not} the baseline
CIF. {cmd:stcrreg} produces this covariate-adjusted CIF through
{cmd:stcurve, cif at()} rather than {cmd:predict}; after {cmd:stcrreg},
{cmd:predict, basecif} gives the baseline (covariate-free) CIF instead. To
obtain the predicted CIF for every observation at a {bf:common} time point
t*, set a constant time variable and pass it through {opt timevar()} (see
{it:CIF at custom time points} under Examples). The baseline cumulative
subdistribution hazard H0(t) — the analogue of {cmd:stcrreg}'s {cmd:basecif}
— is stored as a right-continuous step function in {cmd:e(basehaz)} (columns
{it:time} and {it:cumhazard}); the baseline CIF at any time is
F0(t) = 1 - exp(-H0(t)), and an individual's covariate-adjusted CIF is obtained
from that baseline CIF as CIF(t|z) = 1 - (1 - F0(t))^exp(z'beta), equivalently
1 - exp(-H0(t) * exp(z'beta)).

{pstd}
{bf:Converting {cmd:stcrreg}'s {cmd:basecif} by hand:} the exp(z'beta) factor
rescales the baseline {it:survival} 1 - F0(t), {bf:not} the baseline CIF F0(t)
itself. The correct adjustment is CIF(t|z) = 1 - (1 - F0(t))^exp(z'beta), and
{bf:not} F0(t)^exp(z'beta). Raising the CIF directly to the exp(z'beta) power is
a common mistake — it moves the CIF in the wrong direction (toward 0) when
z'beta > 0. Using {cmd:stcrreg}'s {cmd:basecif} as F0(t),
{cmd:finegray_predict, cif} matches 1 - (1 - {cmd:basecif})^exp(z'beta) to
numerical precision.

{pstd}
{cmd:finegray} must have been run before using {cmd:finegray_predict}. For
models fit with factor variables or interactions, the current data must
preserve the same factor-level support as the estimation sample. If a factor
level has been dropped (e.g., by {cmd:drop if}), prediction will fail with an
informative error.

{pstd}
{bf:A converged fit is required.} {cmd:finegray} reports a nonconverged model
rather than erroring, leaving {cmd:e(converged)} at 0, so {cmd:e(b)} exists but
holds the last iterate rather than a solution. Every prediction type reads
{cmd:e(b)}, so all of them would otherwise be computed from a non-solution and
returned with {cmd:rc 0}. {cmd:finegray_predict} therefore exits with
{cmd:r(430)} when {cmd:e(converged)} is not 1 — this applies to {opt xb} just as
it does to {opt cif} and {opt schoenfeld}. Refit with a larger {opt iterate()}
or a different specification. (Refits inside {opt bootstrap()} that fail to
converge are a separate matter: they are skipped and counted, not fatal.)

{pstd}
The {opt ci} and {opt schoenfeld} paths verify that the original estimation
sample and its model variables are unchanged. If those data have been edited,
the command exits with {cmd:r(459)} and requires {cmd:finegray} to be re-run.
That check also covers the package-owned {cmd:_fg_*} design columns: dropping
them is supported (they are rebuilt on demand), but altering one in place is
not, because {helpb finegray_cif} and {helpb finegray_phtest} read those columns
directly.

{pstd}
Point predictions with {opt xb}, and point {opt cif} predictions without
{opt ci}, remain available on compatible new data. {opt xb} is a pure linear
score, so it does not depend on {cmd:_t}, {cmd:_d} or {opt compete()}, and it is
unaffected by changes to them. What it does depend on is each coefficient being
paired with the right column, which is guaranteed by the level-value alignment
described below.

{pstd}
{bf:Data requirements by prediction type:} {opt xb} predictions can be
computed on any dataset containing the model covariates. {opt cif}
predictions additionally require a time variable ({cmd:_t} or
{opt timevar()}). {opt schoenfeld} residuals and {helpb finegray_phtest}
require the original {cmd:stset} estimation data — specifically {cmd:_t},
{cmd:_d}, and a nonempty estimation sample ({cmd:e(sample)}). These commands
will exit with an informative error if the estimation context is not present.

{pstd}
{bf:Relationship to {help stcrreg} predictions:} {cmd:finegray_predict}
reproduces the post-estimation predictions of Stata's native Fine-Gray
estimator {helpb stcrreg}. {opt xb} is numerically identical to
{cmd:stcrreg}'s {cmd:predict, xb}; the baseline CIF (all covariates set to 0)
reproduces {cmd:predict, basecif}; and {cmd:e(basehaz)} equals {cmd:stcrreg}'s
cumulative-subhazard analogue (H0(t) = -ln(1 - {cmd:basecif})) at each
distinct event time. The per-observation {opt cif} is the covariate-adjusted
CIF, which {cmd:stcrreg} exposes only through {cmd:stcurve, cif at()} (not
{cmd:predict}); {cmd:finegray_predict, cif} matches it to numerical
precision. {opt schoenfeld} residuals are identical to {cmd:predict, schoenfeld}
{bf:at untied cause-event times}. At a {bf:tied} cause-event time the two
implementations split the residual among the simultaneous events using
different conventions, so an individual residual at a tied time can differ
between {cmd:finegray} and {cmd:stcrreg}; however, the
{bf:sum of the residuals within each event time is identical}, as is the
overall score (their grand total, which is zero at the estimate). Only the
per-observation values at tied times are affected — untied times, the
per-time totals, and every quantity that aggregates over event times are
unchanged.


{marker options}{...}
{title:Options}

{phang}
{opt xb} computes the linear predictor z'beta. This is the default if
neither {opt cif} nor {opt schoenfeld} is specified.

{phang}
{opt cif} computes the cumulative incidence function (CIF) at each
observation's analysis time {cmd:_t} (or the time given by {opt timevar()}) —
one prediction per row, at that subject's follow-up time, not at a single
shared horizon. The CIF is computed as 1 - exp(-H0(t) * exp(z'beta)) using the
baseline cumulative subdistribution hazard from {cmd:e(basehaz)}, evaluated as
a step function: for each observation, H0 is read off at the largest event
time less than or equal to that observation's time. To predict at a fixed
horizon for the whole sample, use {opt timevar()} with a constant time
variable.

{phang}
{opt sch:oenfeld} computes Schoenfeld residuals at cause-event times. For a
model with {it:p} covariates, {it:p} variables are created: {it:newvar}
contains residuals for the first covariate, and {it:newvar}{cmd:_2} through
{it:newvar}{cmd:_}{it:p} contain residuals for the remaining
covariates. Residuals are set to missing for observations that are not
cause-of-interest events. {opt timevar()} has no effect when {opt schoenfeld}
is specified; residuals are always computed at the original event times. The
residuals match
{helpb stcrreg}'s {cmd:predict, schoenfeld} exactly at untied event times; at a
tied event time the per-event split follows {cmd:finegray}'s own convention but
preserves the per-time total (see {it:Relationship to stcrreg predictions}
under {help finegray_predict##description:Description}).

{phang}
{opth timevar(varname)} specifies a variable to use as the time axis instead
of {cmd:_t}. This is useful for generating predictions at specific time points
or when the data are not currently {cmd:stset}. For {opt cif}, a constant
variable set to a target horizon (e.g. {cmd:gen t5 = 5}) yields each subject's
predicted CIF at that horizon.

{phang}
{opt ci} (with {opt cif}) additionally generates {it:newvar}{cmd:_lci} and
{it:newvar}{cmd:_uci}, the lower and upper confidence limits for each predicted
CIF. Limits use an influence-function (sandwich) standard error and are formed
on the complementary log-log scale so they remain inside (0,1). Because the
influence functions require the original estimation data, {opt ci} restricts
the prediction to the estimation sample ({cmd:e(sample)}) and needs {cmd:_t} in
memory. The standard error treats the inverse-probability-of-censoring weights
as known; under heavy censoring it is mildly anti-conservative. For confidence
bands over a grid of times, or a fixed-horizon table for a covariate profile,
see {helpb finegray_cif}.

{phang}
{opt bootstrap(#)} (with {opt ci}) computes the confidence limits by resampling
subjects with replacement and refitting instead of using the analytic
influence-function SE. If the original fit specified {opt cluster()}, whole
clusters are resampled instead. Nonconverged refits, and refits whose resample
loses a factor level, are skipped (a note reports how many). At least 25
replications must be requested, and at least 25 must succeed, or
{cmd:finegray_predict} exits with an error: a standard error is the sample
standard deviation of the replicate estimates, and below about 25 replications
that standard deviation is itself mostly noise. The refit is run on the
estimation sample, so any {cmd:if} or {cmd:in} qualifier used at fit time does
not apply to the replications. The interval includes uncertainty from estimating
the censoring weights. Point predictions are unchanged, and the original
{cmd:e()} results and {cmd:e(sample)} are preserved.

{phang}
{opt seed(#)} sets the random-number seed used by {opt bootstrap()}. It requires
{opt bootstrap()}.

{phang}
{opt level(#)} sets the confidence level for {opt ci}; the default is
{cmd:c(level)}, which is initially 95 and can be changed by {helpb set level}.

{pstd}
{bf:Note on factor variables:} Factor-variable predictions are rebuilt from the
expansion recorded at estimation ({cmd:e(fvsemantic)}) and are aligned to the
current data {bf:by level value}, not by position. An observation whose factor
level was not present when the model was fitted has no coefficient, so it cannot
be scored: {cmd:finegray_predict} exits with {cmd:r(459)} and names the
offending variable and the levels that were fitted. It does not silently
collapse such an observation onto the base category.

{pstd}
This matters whenever the level support changes. Fitting on {cmd:i.grp} over
levels 1/2/3 and then shifting the data to levels 2/3/4 leaves three factor
terms in both cases; matching them positionally would apply the coefficient for
level 2 to level 3, and so on, with no error. Matching by value cannot.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup}

{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}
{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}

{pstd}
{bf:Linear predictor (default)}

{phang2}{cmd:. finegray_predict xb_hat,}{p_end}

{pstd}
{bf:Cumulative incidence function}

{phang2}{cmd:. finegray_predict cif_hat, cif}{p_end}

{pstd}
{bf:CIF with explicit storage type}

{phang2}{cmd:. finegray_predict double cif_precise, cif}{p_end}
{phang2}{cmd:. summarize cif_precise}{p_end}

{pstd}
{bf:CIF at custom time points}

{phang2}{cmd:. gen double mytime = 5}{p_end}
{phang2}{cmd:. finegray_predict cif_at5, cif timevar(mytime)}{p_end}

{pstd}5-year CIF with a confidence interval for each subject{p_end}
{phang2}{cmd:. gen double mytime = 5}{p_end}
{phang2}{cmd:. finegray_predict cif5, cif timevar(mytime) ci}{p_end}
{phang2}{cmd:. list cif5 cif5_lci cif5_uci in 1/5}{p_end}

{pstd}5-year CIF with bootstrap confidence limits{p_end}
{phang2}{cmd:. finegray_predict cif5_bs, cif timevar(mytime) ci bootstrap(200) seed(12345)}{p_end}

{pstd}
{bf:Schoenfeld residuals}

{phang2}{cmd:. finegray_predict sch, schoenfeld}{p_end}
{phang2}{cmd:. list sch* in 1/5}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray_predict} creates a new variable but does not store results in
{cmd:r()} or {cmd:e()}. The new variable is labeled:

{phang2}{cmd:xb}: "Linear prediction (xb)"{p_end}
{phang2}{cmd:cif}: "CIF prediction"{p_end}
{phang2}{cmd:schoenfeld}: "Schoenfeld residual: {it:varname}" for each covariate{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:Also see}

{psee}
Online: {helpb finegray}, {helpb finegray_cif}, {helpb finegray_phtest},
{helpb stcrreg}, {helpb stcox}, {helpb stset}

{hline}
