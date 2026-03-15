{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_tmle" "help drest_tmle"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_ltmle##syntax"}{...}
{viewerjumpto "Description" "drest_ltmle##description"}{...}
{viewerjumpto "Options" "drest_ltmle##options"}{...}
{viewerjumpto "Remarks" "drest_ltmle##remarks"}{...}
{viewerjumpto "Examples" "drest_ltmle##examples"}{...}
{viewerjumpto "Stored results" "drest_ltmle##results"}{...}
{viewerjumpto "References" "drest_ltmle##references"}{...}
{viewerjumpto "Author" "drest_ltmle##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:drest_ltmle} {hline 2}}Longitudinal Targeted Minimum Loss-Based Estimation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_ltmle}
{ifin}
{cmd:,}
{opt id(varname)}
{opt per:iod(varname)}
{opt out:come(varname)}
{opt treat:ment(varname)}
{opt cov:ariates(varlist)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}individual identifier{p_end}
{synopt:{opt per:iod(varname)}}time period variable{p_end}
{synopt:{opt out:come(varname)}}binary outcome variable{p_end}
{synopt:{opt treat:ment(varname)}}binary treatment (0/1){p_end}
{synopt:{opt cov:ariates(varlist)}}time-varying covariates{p_end}

{syntab:Optional}
{synopt:{opt bas:eline(varlist)}}time-fixed baseline covariates{p_end}
{synopt:{opt cen:sor(varname)}}binary censoring indicator{p_end}
{synopt:{opt reg:ime(string)}}treatment regime: {cmd:always_never} (default),
{cmd:always}, {cmd:never}{p_end}

{syntab:Model specification}
{synopt:{opt of:amily(string)}}outcome model family; default {cmd:logit}{p_end}
{synopt:{opt tf:amily(string)}}treatment model family; default {cmd:logit}{p_end}
{synopt:{opt trimps(numlist)}}propensity score trimming bounds{p_end}

{syntab:Other}
{synopt:{opt l:evel(#)}}confidence level{p_end}
{synopt:{opt nolog}}suppress progress messages{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_ltmle} implements Longitudinal TMLE for estimating causal effects
of sustained treatment strategies in the presence of time-varying confounding.
It extends TMLE to panel/longitudinal data using sequential regression from
the final time period backward, with a targeting step at each period.

{pstd}
The data must be in person-period (long) format with one row per
individual-period. This format is compatible with data created by
{cmd:tte_expand}.

{pstd}
The default {opt regime(always_never)} compares the "always treat" strategy
to the "never treat" strategy, returning the ATE as the difference in
counterfactual outcome probabilities.


{marker options}{...}
{title:Options}

{phang}
{opt id(varname)} specifies the variable identifying individuals.

{phang}
{opt period(varname)} specifies the time period variable. Must be integer-valued
and consecutive within each individual.

{phang}
{opt covariates(varlist)} specifies time-varying covariates to include in both
the treatment and outcome models at each time point.

{phang}
{opt baseline(varlist)} specifies time-fixed covariates (measured once per
individual) to include in all models.

{phang}
{opt censor(varname)} specifies a binary indicator for censoring (1 = censored,
0 = observed). When specified, LTMLE adjusts for informative censoring using
inverse probability of censoring weights.

{phang}
{opt regime(string)} specifies the treatment regime to evaluate. Options:
{cmd:always_never} (default, compares always vs never treated),
{cmd:always} (counterfactual under always treated),
{cmd:never} (counterfactual under never treated).


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Data requirements}

{pstd}
The data must be in long format with variables for {opt id}, {opt period},
{opt treatment}, and {opt outcome}. Each individual should have one row per
time period. Missing periods are allowed but reduce efficiency.

{pstd}
{bf:Integration with tte}

{pstd}
If the data was prepared with {cmd:tte_expand}, LTMLE automatically detects
the {cmd:_tte_prepared} characteristic and can use the expanded data structure
directly.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Basic LTMLE with simulated panel data}

{phang2}{cmd:. drest_ltmle, id(id) period(t) outcome(y) treatment(a) covariates(x1 x2)}{p_end}

{pstd}
{bf:With baseline covariates and censoring}

{phang2}{cmd:. drest_ltmle, id(id) period(t) outcome(y) treatment(a) covariates(x1 x2) baseline(age sex) censor(c)}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}total observations (person-periods){p_end}
{synopt:{cmd:e(N_id)}}number of individuals{p_end}
{synopt:{cmd:e(T)}}number of time periods{p_end}
{synopt:{cmd:e(tau)}}treatment effect estimate{p_end}
{synopt:{cmd:e(se)}}standard error{p_end}
{synopt:{cmd:e(po_always)}}counterfactual P(Y=1) under always treat{p_end}
{synopt:{cmd:e(po_never)}}counterfactual P(Y=1) under never treat{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:drest_ltmle}{p_end}
{synopt:{cmd:e(method)}}{cmd:ltmle}{p_end}
{synopt:{cmd:e(regime)}}treatment regime{p_end}


{marker references}{...}
{title:References}

{pstd}
van der Laan MJ, Gruber S. Targeted minimum loss based estimation of causal
effects of multiple time point interventions.
{it:International Journal of Biostatistics}. 2012;8(1).

{pstd}
Petersen M, Schwab J, Gruber S, et al. Targeted maximum likelihood estimation
for dynamic and static longitudinal marginal structural working models.
{it:Journal of Causal Inference}. 2014;2(2):147-185.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
