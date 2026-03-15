{smcl}
{* *! version 1.1.0  15mar2026}{...}
{viewerjumpto "Syntax" "tte_predict##syntax"}{...}
{viewerjumpto "Description" "tte_predict##description"}{...}
{viewerjumpto "Options" "tte_predict##options"}{...}
{viewerjumpto "Examples" "tte_predict##examples"}{...}
{viewerjumpto "Stored results" "tte_predict##results"}{...}
{viewerjumpto "Technical notes" "tte_predict##technical"}{...}
{viewerjumpto "Author" "tte_predict##author"}{...}

{title:Title}

{phang}
{bf:tte_predict} {hline 2} Marginal predictions for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_predict}
{cmd:,} {opth time:s(numlist)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth time:s(numlist)}}follow-up times for prediction (required){p_end}
{synopt:{opth type(string)}}cum_inc (default) or survival{p_end}
{synopt:{opt sample:s(#)}}MC samples for CIs; default is {cmd:100}{p_end}
{synopt:{opt seed(#)}}random seed for reproducibility{p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt diff:erence}}compute risk difference{p_end}
{synopt:{opt rat:io}}compute risk ratio{p_end}
{synopt:{opt att}}target ATT instead of ATE{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_predict} generates marginal cumulative incidence or survival
predictions with confidence intervals. It uses Monte Carlo simulation
from the fitted model's coefficient distribution.

{pstd}
For each MC sample, coefficient vectors are drawn from the multivariate
normal distribution defined by the point estimates and robust variance
matrix. Predictions are averaged over a reference population to obtain
marginal estimates.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth times(numlist)} specifies the follow-up times at which to compute
predictions. For example, {cmd:times(0 2 4 6 8)} or {cmd:times(0(1)8)}.

{dlgtab:Prediction}

{phang}
{opt type(string)} specifies the prediction type: {cmd:cum_inc} (default)
for cumulative incidence or {cmd:survival} for survival probability
(1 - cumulative incidence).

{phang}
{opt samples(#)} specifies the number of Monte Carlo samples for confidence
intervals. The default is {cmd:100}. Use 500+ for publication-quality
results.

{phang}
{opt seed(#)} sets the random seed for reproducibility of Monte Carlo
draws.

{phang}
{opt level(#)} sets the confidence level for prediction intervals.
The default is {cmd:95}.

{dlgtab:Contrasts}

{phang}
{opt difference} computes the risk difference (treated minus control)
at each time point, with Monte Carlo confidence intervals.

{phang}
{opt ratio} computes the risk ratio (treated divided by control)
at each time point, with Monte Carlo confidence intervals. Can be
combined with {opt difference}.

{dlgtab:Target population}

{phang}
{opt att} restricts the reference population to individuals who
initiated treatment at baseline (ATT = average treatment effect among
the treated). By default, the reference population includes all
eligible individuals (ATE = average treatment effect).


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_predict, times(0 2 4 6 8) type(cum_inc) difference samples(100) seed(12345)}{p_end}
{phang2}{cmd:. tte_predict, times(0 1 2 3 4 5) type(survival) samples(500)}{p_end}

{pstd}Risk ratio with confidence intervals{p_end}
{phang2}{cmd:. tte_predict, times(0 2 4 6 8) ratio samples(200) seed(42)}{p_end}

{pstd}Both risk difference and risk ratio{p_end}
{phang2}{cmd:. tte_predict, times(0 2 4 6 8) difference ratio samples(200)}{p_end}

{pstd}ATT estimates{p_end}
{phang2}{cmd:. tte_predict, times(0 2 4 6 8) att difference samples(200)}{p_end}


{marker technical}{...}
{title:Technical notes}

{dlgtab:Reference population}

{pstd}
Marginal predictions are averaged over all observations at follow-up
time 0 ({cmd:_tte_followup == 0}) in the estimation sample. This
population includes baseline observations from all emulated trials,
yielding marginal estimates over the full eligible population.

{pstd}
When {opt att} is specified, only individuals whose observed treatment
at the trial baseline equals 1 are retained in the reference population.
This gives the average treatment effect among the treated.

{dlgtab:Cumulative incidence computation}

{pstd}
Cumulative incidence is computed iteratively through every integer
follow-up time from 0 to the maximum requested time, not just at the
requested times. At each step t, the conditional probability of the event
is predicted from the fitted model, and the cumulative incidence is
updated: P(T <= t) = P(T <= t-1) + [1 - P(T <= t-1)] * h(t), where
h(t) is the predicted discrete hazard from the pooled logistic model.

{dlgtab:Risk ratio}

{pstd}
The risk ratio at time t is RR(t) = CI_1(t) / CI_0(t), where CI_1 and
CI_0 are the cumulative incidence in the treated and control arms. MC
confidence intervals are computed by taking the ratio of each MC draw's
predictions, sorting, and extracting percentiles.

{dlgtab:Monte Carlo confidence intervals}

{pstd}
Confidence intervals are computed by drawing {opt samples(#)} coefficient
vectors from MVN(b, V), where b = e(b) and V = e(V) from the fitted
model. For each draw, the full prediction is recomputed. Pointwise
percentile CIs are taken at (alpha/2, 1-alpha/2) across the MC samples.
This is a parametric bootstrap on the coefficient uncertainty and does
not account for uncertainty in the IP weights.

{pstd}
The default of 100 samples is adequate for exploratory analysis.
For publication-quality results, use {cmd:samples(500)} or higher to
reduce Monte Carlo error in the CI bounds.


{dlgtab:Covariate limitations}

{pstd}
Marginal predictions require that the linear predictor can be reconstructed
from the stored coefficients. Factor variable notation ({cmd:i.sex}) and
interaction operators ({cmd:c.age#c.age}) used in {cmd:tte_fit} will produce
incorrect predictions because {cmd:tte_predict} rebuilds Xb manually.
Create dummy variables before calling {cmd:tte_fit} if categorical or
interaction terms are needed.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_predict} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_times)}}number of prediction times{p_end}
{synopt:{cmd:r(samples)}}number of MC samples{p_end}
{synopt:{cmd:r(level)}}confidence level{p_end}
{synopt:{cmd:r(rd_#)}}risk difference at time # (if {cmd:difference}){p_end}
{synopt:{cmd:r(rr_#)}}risk ratio at time # (if {cmd:ratio}){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(type)}}prediction type (cum_inc or survival){p_end}
{synopt:{cmd:r(estimand)}}estimand (ITT, PP, AT){p_end}
{synopt:{cmd:r(target)}}target population (ATE or ATT){p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(predictions)}}matrix with columns: time, est_0, ci_lo_0, ci_hi_0, est_1, ci_lo_1, ci_hi_1 [, diff, diff_lo, diff_hi] [, rr, rr_lo, rr_hi]{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet
