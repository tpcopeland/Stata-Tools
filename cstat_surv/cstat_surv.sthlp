{smcl}
{* *! version 1.0.0  2025/12/02}{...}
{viewerjumpto "Syntax" "cstat_surv##syntax"}{...}
{viewerjumpto "Description" "cstat_surv##description"}{...}
{viewerjumpto "Remarks" "cstat_surv##remarks"}{...}
{viewerjumpto "Examples" "cstat_surv##examples"}{...}
{viewerjumpto "Stored results" "cstat_surv##results"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:cstat_surv} {hline 2}}Calculate C-statistic for survival models{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:cstat_surv}


{marker description}{...}
{title:Description}

{pstd}
{cmd:cstat_surv} calculates Harrell's C-statistic (concordance statistic) for survival models after fitting a Cox proportional hazards model. The C-statistic measures the model's ability to discriminate between subjects who experience the event and those who do not.

{pstd}
The command must be run immediately after fitting a Cox model with {helpb stcox}. It calculates the C-statistic directly by comparing all comparable pairs of observations, accounting for censoring in survival data.

{pstd}
The C-statistic ranges from 0 to 1:

{phang2}• C = 0.5 indicates no discrimination (random predictions){p_end}
{phang2}• C > 0.7 indicates acceptable discrimination{p_end}
{phang2}• C > 0.8 indicates excellent discrimination{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:cstat_surv} requires that:

{phang2}1. Your data must be {helpb stset} before running the Cox model{p_end}
{phang2}2. You must have just run {helpb stcox} in the current session{p_end}

{pstd}
The command works by:

{phang2}1. Predicting hazard ratios from the fitted Cox model{p_end}
{phang2}2. Comparing all comparable pairs of observations{p_end}
{phang2}3. Calculating concordance (pairs where higher predicted risk corresponds to earlier event){p_end}
{phang2}4. Computing standard errors via infinitesimal jackknife{p_end}

{pstd}
A pair of observations is comparable if the observation with the shorter survival time experienced the event. For tied survival times where both subjects experienced events, each possible ordering is counted as half concordant and half discordant.

{pstd}
The C-statistic is equivalent to the area under the ROC curve (AUC) for binary outcomes and represents the probability that, for a randomly selected comparable pair, the model assigns a higher risk to the subject who experienced the event earlier.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. webuse drugtr}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}

{pstd}Fit a Cox proportional hazards model{p_end}
{phang2}{cmd:. stcox age drug}{p_end}

{pstd}Calculate the C-statistic{p_end}
{phang2}{cmd:. cstat_surv}{p_end}

{pstd}The output displays the C-statistic with standard error and 95% confidence interval, along with pair comparison statistics.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:cstat_surv} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(c)}}C-statistic{p_end}
{synopt:{cmd:e(se)}}Standard error (infinitesimal jackknife){p_end}
{synopt:{cmd:e(ci_lo)}}Lower bound of 95% confidence interval{p_end}
{synopt:{cmd:e(ci_hi)}}Upper bound of 95% confidence interval{p_end}
{synopt:{cmd:e(df_r)}}Degrees of freedom{p_end}
{synopt:{cmd:e(N)}}Number of observations{p_end}
{synopt:{cmd:e(N_comparable)}}Number of comparable pairs{p_end}
{synopt:{cmd:e(N_concordant)}}Number of concordant pairs{p_end}
{synopt:{cmd:e(N_discordant)}}Number of discordant pairs{p_end}
{synopt:{cmd:e(N_tied)}}Number of tied pairs{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:cstat_surv}{p_end}
{synopt:{cmd:e(title)}}Harrell's C-statistic{p_end}
{synopt:{cmd:e(vcetype)}}Jackknife{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector (C-statistic){p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}


{title:Also see}

{psee}
Manual: {manlink ST stcox}, {manlink ST stset}

{psee}
Online: {helpb stcox}, {helpb stset}
{p_end}
