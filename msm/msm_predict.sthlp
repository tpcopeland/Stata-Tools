{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_predict##syntax"}{...}
{viewerjumpto "Description" "msm_predict##description"}{...}
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
{synopt:{opth times(numlist)}}time periods for prediction (required){p_end}
{synopt:{opt stra:tegy(string)}}always, never, or both (default){p_end}
{synopt:{opt type(string)}}cum_inc (default) or survival{p_end}
{synopt:{opt sam:ples(#)}}MC samples for CIs; default 100{p_end}
{synopt:{opt seed(#)}}random seed{p_end}
{synopt:{opt level(#)}}confidence level; default 95{p_end}
{synopt:{opt diff:erence}}compute risk difference{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_predict} generates counterfactual predictions under always-treated
and never-treated strategies. Uses Monte Carlo simulation from the
coefficient distribution (Cholesky decomposition) for confidence intervals.
Predictions are based on G-formula standardization across the reference
population at baseline.


{marker options}{...}
{title:Options}

{phang}
{opth times(numlist)} specifies the time periods at which to predict
counterfactual outcomes. Required. Values must be non-negative integers
corresponding to period values in the data.

{phang}
{opt strategy(string)} specifies which treatment strategy to predict.
{cmd:always} predicts under always-treated, {cmd:never} under never-treated,
and {cmd:both} (the default) predicts under both strategies.

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
never-treated strategies at each time point.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_predict} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(predictions)}}predictions per strategy and time{p_end}

{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(rd_#)}}risk difference at time # (with {cmd:difference}){p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_predict, times(3 5 7 9) difference seed(12345)}{p_end}
{phang2}{cmd:. msm_predict, times(1 3 5 7 9) type(survival) samples(200)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
