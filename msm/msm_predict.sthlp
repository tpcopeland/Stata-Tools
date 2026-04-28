{smcl}
{* *! version 1.0.0  26apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_plot" "help msm_plot"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_sensitivity" "help msm_sensitivity"}{...}
{viewerjumpto "Syntax" "msm_predict##syntax"}{...}
{viewerjumpto "Description" "msm_predict##description"}{...}
{viewerjumpto "How prediction works" "msm_predict##how"}{...}
{viewerjumpto "Options" "msm_predict##options"}{...}
{viewerjumpto "Current limits" "msm_predict##limits"}{...}
{viewerjumpto "Examples" "msm_predict##examples"}{...}
{viewerjumpto "Stored results" "msm_predict##stored"}{...}
{viewerjumpto "Author" "msm_predict##author"}{...}

{title:Title}

{phang}
{bf:msm_predict} {hline 2} Counterfactual predictions from marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_predict}
{cmd:,} {opth times(numlist)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt times(numlist)}}time periods for prediction{p_end}

{syntab:Strategy}
{synopt:{opt stra:tegy(string)}}{cmd:always}, {cmd:never}, or {cmd:both} (default){p_end}
{synopt:{opt diff:erence}}compute risk differences between strategies{p_end}

{syntab:Output type}
{synopt:{opt type(string)}}{cmd:cum_inc} (default) or {cmd:survival}{p_end}

{syntab:Monte Carlo settings}
{synopt:{opt sam:ples(#)}}MC draws for confidence intervals; default {cmd:100}{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:95}{p_end}

{syntab:Extrapolation}
{synopt:{opt extra:polate}}allow predictions beyond observed follow-up{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_predict} answers the central causal question: "What would happen if
everyone were always treated versus never treated?"  It generates standardized
counterfactual predictions under static treatment strategies using the fitted
pooled logistic MSM from {helpb msm_fit}.

{pstd}
The command computes cumulative incidence (risk) or survival at each requested
time point for each strategy, averaging over the reference population at
baseline.  Confidence intervals are computed via Monte Carlo simulation from
the estimated coefficient distribution using Cholesky decomposition.

{pstd}
When {opt difference} is specified with {cmd:strategy(both)}, the command also
reports risk differences (always-treated minus never-treated) with CIs at each
time point.

{pstd}
{cmd:msm_predict} requires a prior {helpb msm_fit} run with
{cmd:model(logistic)}.  Use {cmd:msm, status} to confirm that prediction is
available before calling this command.


{marker how}{...}
{title:How prediction works}

{phang2}1. {bf:Reference population.}  The command identifies all individuals
at the first observed period who are in the estimation sample.  These serve
as the reference population over which predictions are standardized.{p_end}

{phang2}2. {bf:Counterfactual trajectories.}  For each individual in the
reference population and each strategy (always-treated or never-treated),
the command computes period-specific event probabilities from the fitted
model by setting treatment to the strategy value (1 or 0) at every period.
{p_end}

{phang2}3. {bf:Cumulative survival.}  The product of (1 - period hazard) across
periods gives cumulative survival.  Cumulative incidence = 1 - survival.{p_end}

{phang2}4. {bf:Population average.}  The individual-level predictions are
averaged across the reference population to produce the marginal
estimate.{p_end}

{phang2}5. {bf:Monte Carlo CIs.}  Steps 2-4 are repeated for each MC draw
from the coefficient distribution.  Percentile-based CIs are constructed from
the resulting empirical distribution.{p_end}

{pstd}
Any {cmd:outcome_cov()} variables from {helpb msm_fit} are held at each
individual's actual baseline values during prediction.  They must therefore be
time-fixed within person.


{marker options}{...}
{title:Options}

{phang}
{opth times(numlist)} specifies the time periods at which to predict
counterfactual outcomes.  Required.  Values must be non-negative integers
corresponding to period values in the data.  By default they must also lie
within the observed follow-up range; use {opt extrapolate} to override.

{phang}
{opt stra:tegy(string)} specifies which treatment strategy to predict.
{cmd:always} computes predictions under always-treated, {cmd:never} under
never-treated, and {cmd:both} (the default) computes both.

{phang}
{opt diff:erence} computes risk differences (always-treated minus
never-treated) at each time point with MC confidence intervals.  Only
meaningful with {cmd:strategy(both)}; silently ignored otherwise.

{phang}
{opt type(string)} specifies the output scale.  {cmd:cum_inc} (default)
reports cumulative incidence (risk).  {cmd:survival} reports one minus
cumulative incidence.

{phang}
{opt sam:ples(#)} specifies the number of Monte Carlo draws from the
coefficient distribution for CI estimation.  Default is 100.  More draws
produce smoother CIs but take longer.  Must be at least 10.

{phang}
{opt seed(#)} sets the random number seed before the MC simulation for
reproducibility.  If omitted, the command uses the current session RNG state
and returns the starting state so you can reproduce the results later.

{phang}
{opt level(#)} specifies the confidence level.  Default is 95.

{phang}
{opt extra:polate} allows prediction at time points beyond the maximum
observed period.  By default, out-of-range values in {opt times()} produce an
error.  Use this only when extrapolation beyond the observed data support is
intentional.


{marker limits}{...}
{title:Current limits}

{phang}
{bf:Requires pooled logistic MSMs.}  {cmd:msm_predict} stops with an error
unless the most recent {helpb msm_fit} used {cmd:model(logistic)}.  Linear
and Cox models can be estimated but do not feed into this prediction
workflow.{p_end}

{phang}
{bf:Static strategies only.}  Supported strategies are always-treated,
never-treated, and both.  Dynamic or stochastic treatment regimes are out
of scope.{p_end}

{phang}
{bf:Outcome-model covariates must be time-fixed.}  Any {cmd:outcome_cov()}
from {helpb msm_fit} are standardized at baseline values, so they must not
vary within person.{p_end}

{phang}
{bf:Prediction horizon defaults to observed data.}  Out-of-range
{opt times()} values require {opt extrapolate}.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup.}  Run the pipeline through {cmd:msm_fit} first:{p_end}

{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}

{pstd}
{bf:Risk predictions with risk differences:}{p_end}

{phang2}{cmd:. msm, status}{p_end}
{phang2}{cmd:. msm_predict, times(3 5 7 9) difference seed(12345)}{p_end}
{phang2}{cmd:. matrix list r(predictions)}{p_end}

{pstd}
{bf:Survival-scale predictions with more MC draws:}{p_end}

{phang2}{cmd:. msm_predict, times(1 3 5 7 9) type(survival) samples(200) seed(12345)}{p_end}

{pstd}
{bf:Single-strategy prediction:}{p_end}

{phang2}{cmd:. msm_predict, times(1 3 5 7 9) strategy(always) seed(12345)}{p_end}

{pstd}
{bf:Visualizing predictions.}  Follow up with a survival plot:{p_end}

{phang2}{cmd:. msm_plot, type(survival) times(1 3 5 7 9) seed(12345)}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_predict} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(predictions)}}prediction matrix (period, estimates, CIs per strategy; plus diff columns with {opt difference}){p_end}

{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(rd_#)}}risk difference at time # (only with {opt difference}){p_end}
{synopt:{cmd:r(n_times)}}number of time points requested{p_end}
{synopt:{cmd:r(n_ref)}}number of individuals in the reference population{p_end}
{synopt:{cmd:r(samples)}}number of MC draws used{p_end}
{synopt:{cmd:r(level)}}confidence level{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(seed)}}seed or RNG state used for the MC simulation{p_end}
{synopt:{cmd:r(seed_source)}}{cmd:seed()} or {cmd:session_rng_state}{p_end}
{synopt:{cmd:r(seed_state)}}full starting RNG state string{p_end}
{synopt:{cmd:r(type)}}prediction type ({cmd:cum_inc} or {cmd:survival}){p_end}
{synopt:{cmd:r(strategy)}}strategy used ({cmd:always}, {cmd:never}, or {cmd:both}){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}
