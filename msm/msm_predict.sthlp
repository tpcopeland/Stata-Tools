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
