{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_plot" "help msm_plot"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{viewerjumpto "Syntax" "msm_predict##syntax"}{...}
{viewerjumpto "Description" "msm_predict##description"}{...}
{viewerjumpto "Options" "msm_predict##options"}{...}
{viewerjumpto "Current limits" "msm_predict##limits"}{...}
{viewerjumpto "Stored results" "msm_predict##stored"}{...}
{viewerjumpto "Examples" "msm_predict##examples"}{...}
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
{synopt:{opt times(numlist)}}time periods for prediction (required){p_end}
{synopt:{opt stra:tegy(string)}}always, never, or both (default){p_end}
{synopt:{opt type(string)}}cum_inc (default) or survival{p_end}
{synopt:{opt sam:ples(#)}}MC samples for CIs; default 100{p_end}
{synopt:{opt seed(#)}}random seed{p_end}
{synopt:{opt level(#)}}confidence level; default 95{p_end}
{synopt:{opt diff:erence}}compute risk difference{p_end}
{synopt:{opt extra:polate}}allow predictions beyond observed follow-up{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_predict} generates counterfactual predictions under always-treated
and never-treated strategies. Uses Monte Carlo simulation from the
coefficient distribution (Cholesky decomposition) for confidence intervals.
Predictions are based on G-formula standardization across the reference
population at baseline. {cmd:msm_predict} currently supports logistic outcome
models only. Any {cmd:outcome_cov()} terms from {helpb msm_fit} are held at
their baseline/reference-population values during prediction, so they must be
time-fixed within individual.


{marker options}{...}
{title:Options}

{phang}
{opth times(numlist)} specifies the time periods at which to predict
counterfactual outcomes. Required. Values must be non-negative integers
corresponding to period values in the data. By default they must also lie
within the observed follow-up range.

{phang}
{opt strategy(string)} specifies which treatment strategy to predict.
{cmd:always} predicts under always-treated, {cmd:never} under never-treated,
and {cmd:both} (the default) predicts under both strategies. These are
static intervention regimes; dynamic rules are not implemented here.

{phang}
{opt type(string)} specifies the prediction type. {cmd:cum_inc} (default)
computes cumulative incidence (risk). {cmd:survival} computes 1 minus
cumulative incidence.

{phang}
{opt samples(#)} specifies the number of Monte Carlo draws from the
coefficient distribution for confidence interval estimation. Default is 100.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt level(#)} specifies the confidence level. Default is 95.

{phang}
{opt difference} computes risk differences between always-treated and
never-treated strategies at each time point. It is only meaningful with
{cmd:strategy(both)}; otherwise the option is ignored.

{phang}
{opt extrapolate} allows prediction at time points beyond the maximum
observed period in the data. By default, {cmd:msm_predict} rejects
{cmd:times()} values exceeding the observed follow-up range. Use this
option to override the guard when extrapolation is intentional.


{marker limits}{...}
{title:Current limits}

{phang}
{bf:Requires pooled logistic MSMs.} {cmd:msm_predict} stops unless the most
recent {helpb msm_fit} run used {cmd:model(logistic)}.

{phang}
{bf:Static strategies only.} Supported {cmd:strategy()} values are
{cmd:always}, {cmd:never}, and {cmd:both}. Dynamic or stochastic treatment
regimes are out of scope for the current release.

{phang}
{bf:Outcome-model covariates must be time-fixed if predicting.} Any
{cmd:outcome_cov()} variables from {helpb msm_fit} are standardized at the
baseline/reference-population values, so they must not vary within person.

{phang}
{bf:Prediction horizon defaults to observed data support.} Out-of-range
{cmd:times()} values require {cmd:extrapolate}; otherwise the command refuses
them.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_predict} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(predictions)}}predictions per strategy and time{p_end}

{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(rd_#)}}risk difference at time # (with {cmd:difference}){p_end}
{synopt:{cmd:r(n_times)}}number of time points{p_end}
{synopt:{cmd:r(n_ref)}}reference population size{p_end}
{synopt:{cmd:r(samples)}}MC samples used{p_end}
{synopt:{cmd:r(level)}}confidence level{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(type)}}prediction type{p_end}
{synopt:{cmd:r(strategy)}}strategy used{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Setup for prediction from a pooled logistic MSM{p_end}
{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}

{pstd}Risk predictions and risk differences at selected follow-up times{p_end}
{phang2}{cmd:. msm_predict, times(3 5 7 9) difference seed(12345)}{p_end}
{phang2}{cmd:. matrix list r(predictions)}{p_end}

{pstd}Survival-scale predictions with more Monte Carlo draws{p_end}
{phang2}{cmd:. msm_predict, times(1 3 5 7 9) type(survival) samples(200)}{p_end}

{pstd}Single-strategy prediction when you only want one counterfactual path{p_end}
{phang2}{cmd:. msm_predict, times(1 3 5 7 9) strategy(always) seed(12345)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
