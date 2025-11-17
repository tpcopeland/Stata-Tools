{smcl}
{* *! version 1.0.0  15may2022}{...}
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
{cmd:cstat_surv} calculates the C-statistic (concordance statistic) for survival models after fitting a Cox proportional hazards model. The C-statistic measures the model's ability to discriminate between subjects who experience the event and those who do not.

{pstd}
The command must be run immediately after fitting a Cox model with {helpb stcox}. It uses Somers' D transformation to calculate the C-statistic, accounting for censoring in survival data.

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
{phang2}3. The {helpb somersd} package must be installed (from SSC){p_end}

{pstd}
The command works by:

{phang2}1. Predicting hazard ratios from the fitted Cox model{p_end}
{phang2}2. Computing the inverse hazard ratio for proper ordering{p_end}
{phang2}3. Creating a censoring indicator from the failure variable{p_end}
{phang2}4. Calculating Somers' D using the {cmd:somersd} command with the c-transformation{p_end}
{phang2}5. Cleaning up temporary variables{p_end}

{pstd}
The C-statistic is equivalent to the area under the ROC curve (AUC) and represents the probability that, for a randomly selected pair of subjects where one experienced the event and one did not, the model assigns a higher risk to the subject who experienced the event.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. webuse drugtr}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}

{pstd}Fit a Cox proportional hazards model{p_end}
{phang2}{cmd:. stcox age drug}{p_end}

{pstd}Calculate the C-statistic{p_end}
{phang2}{cmd:. cstat_surv}{p_end}

{pstd}The output will display Somers' D and its transformation, including the C-statistic with confidence intervals and p-values.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:cstat_surv} stores the following in {cmd:r()} (via the {cmd:somersd} command):

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(somers_d)}}Somers' D coefficient{p_end}
{synopt:{cmd:r(c)}}C-statistic{p_end}
{synopt:{cmd:r(se)}}Standard error{p_end}
{synopt:{cmd:r(z)}}Z-statistic{p_end}
{synopt:{cmd:r(p)}}P-value{p_end}
{synopt:{cmd:r(lb)}}Lower bound of confidence interval{p_end}
{synopt:{cmd:r(ub)}}Upper bound of confidence interval{p_end}


{title:Dependencies}

{pstd}
{cmd:cstat_surv} requires the {cmd:somersd} package. Install it with:

{phang2}{cmd:. ssc install somersd}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.0.0 - 15 May 2022{p_end}


{title:Also see}

{psee}
Manual: {manlink ST stcox}, {manlink ST stset}

{psee}
Online: {helpb stcox}, {helpb stset}, {helpb somersd}
{p_end}
