{smcl}
{* *! version 1.0.2  28feb2026}{...}
{viewerjumpto "Syntax" "tte_weight##syntax"}{...}
{viewerjumpto "Description" "tte_weight##description"}{...}
{viewerjumpto "Options" "tte_weight##options"}{...}
{viewerjumpto "Examples" "tte_weight##examples"}{...}
{viewerjumpto "Stored results" "tte_weight##results"}{...}
{viewerjumpto "Technical notes" "tte_weight##technical"}{...}
{viewerjumpto "Author" "tte_weight##author"}{...}

{title:Title}

{phang}
{bf:tte_weight} {hline 2} Inverse probability weights for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_weight}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Switch models}
{synopt:{opth switch_d_cov(varlist)}}covariates for switch denominator model{p_end}
{synopt:{opth switch_n_cov(varlist)}}covariates for switch numerator model{p_end}

{syntab:Censoring models}
{synopt:{opth censor_d_cov(varlist)}}covariates for censoring denominator model{p_end}
{synopt:{opth censor_n_cov(varlist)}}covariates for censoring numerator model{p_end}

{syntab:Model specification}
{synopt:{opt pool_switch}}pool switch models across arms{p_end}
{synopt:{opt pool_censor}}pool censoring models across arms{p_end}

{syntab:Options}
{synopt:{opth trunc:ate(numlist)}}truncate at percentiles (e.g., {cmd:truncate(1 99)}){p_end}
{synopt:{opt stab:ilized}}use stabilized weights (default){p_end}
{synopt:{opth gen:erate(name)}}weight variable name; default is {cmd:_tte_weight}{p_end}
{synopt:{opt replace}}replace existing weight variable{p_end}
{synopt:{opt nolog}}suppress model iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_weight} calculates stabilized inverse probability weights for
treatment switching and optionally for informative censoring. These
weights account for the artificial censoring introduced by {helpb tte_expand}
in per-protocol and as-treated analyses.

{pstd}
For ITT analyses, all weights are set to 1 (no artificial censoring occurs).


{marker examples}{...}
{title:Examples}

{pstd}Basic stabilized weights with truncation{p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity biomarker) stabilized truncate(1 99) nolog}{p_end}

{pstd}With censoring weights{p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity) censor_d_cov(age sex) truncate(1 99) nolog}{p_end}


{marker technical}{...}
{title:Technical notes}

{dlgtab:Weight model stratification}

{pstd}
Switch models are fitted separately by treatment arm (2 strata: arm=0
and arm=1). Within each stratum, a logistic regression models the
probability of treatment switching as a function of covariates and
lagged treatment status.

{pstd}
An alternative approach uses 4 strata (arm x lagged treatment) with
intercept-only denominators within each stratum. Both are valid
parameterizations of the inverse probability weight model
(Hernán & Robins, 2020, Technical Point 12.2). The choice affects
individual weight values and outcome model coefficients but not the
target causal estimand (risk differences from {cmd:tte_predict}) when
both models are correctly specified.

{dlgtab:Stabilized weights}

{pstd}
Stabilized weights use the form w = Pr(A{sub:t}|A{sub:t-1}, L{sub:0}) /
Pr(A{sub:t}|A{sub:t-1}, L{sub:0}, L{sub:t}). The numerator model includes
variables from {opt switch_n_cov()}, which stabilizes weights and reduces
variance compared to unstabilized weights (numerator = 1).

{dlgtab:Covariate values in weight models}

{pstd}
After expansion by {cmd:tte_expand}, covariates registered in
{cmd:tte_prepare} are frozen at trial-entry (baseline) values. Weight
model covariates passed via {opt switch_d_cov()} and {opt switch_n_cov()}
therefore use baseline values. This is theoretically justified: the IP
weight model can condition on baseline covariates L{sub:0} and still
produce consistent estimates of the causal effect, provided the model is
correctly specified (Hernán & Robins, 2020, Technical Point 12.2).

{pstd}
If time-varying covariates are needed in the weight model, users must
construct them manually before calling {cmd:tte_weight} (e.g., by merging
from the original data using {cmd:id}, {cmd:period}).

{dlgtab:Truncation}

{pstd}
When {opt truncate(lo hi)} is specified, weights below the {it:lo}th
percentile or above the {it:hi}th percentile are set to those percentile
values. Truncation is applied after weight computation. The number of
truncated weights is reported in {cmd:r(n_truncated)}.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_weight} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}SD of weights{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(n_truncated)}}number of truncated weights{p_end}


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
