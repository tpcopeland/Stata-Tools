{smcl}
{* *! version 1.0.0  08apr2026}{...}
{viewerjumpto "Syntax" "cstat_surv##syntax"}{...}
{viewerjumpto "Options" "cstat_surv##options"}{...}
{viewerjumpto "Description" "cstat_surv##description"}{...}
{viewerjumpto "Remarks" "cstat_surv##remarks"}{...}
{viewerjumpto "Examples" "cstat_surv##examples"}{...}
{viewerjumpto "Stored results" "cstat_surv##results"}{...}
{viewerjumpto "Author" "cstat_surv##author"}{...}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:cstat_surv} {hline 2}}Calculate C-statistic for survival models{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:cstat_surv}
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt l:evel(#)}}set confidence level; default is {cmd:level({ccl level})}{p_end}
{synoptline}


{marker options}{...}
{title:Options}

{phang}
{opt level(#)} specifies the confidence level, as a percentage, for confidence
intervals. The default is {cmd:level(95)} or as set by {helpb set level}.


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

{pstd}
{ul:Limitations}

{phang2}1. The C-statistic is computed on unweighted pairs regardless of any weights used in the {cmd:stcox} model. A note is displayed when weights are detected.{p_end}
{phang2}2. Delayed entry (left truncation via {cmd:_t0}) is not accounted for in pair comparisons. Use single-record survival data without late entries for correct results.{p_end}
{phang2}3. Multi-record (counting process) data is not supported. The command assumes one record per subject.{p_end}
{phang2}4. The algorithm compares all pairs of observations (O(n{c 178}) complexity). For datasets with more than 10,000 observations, computation may take several seconds.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{stata "webuse drugtr":. webuse drugtr}{p_end}
{phang2}{stata "stset studytime, failure(died)":. stset studytime, failure(died)}{p_end}

{pstd}Fit a Cox proportional hazards model{p_end}
{phang2}{stata "stcox age drug":. stcox age drug}{p_end}

{pstd}Calculate the C-statistic{p_end}
{phang2}{stata "cstat_surv":. cstat_surv}{p_end}

{pstd}The output displays the C-statistic with standard error and 95% confidence interval, along with pair comparison statistics.

{pstd}More complex example with SSRI/SNRI cohort{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{stata `"merge 1:1 id using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/treatment.dta", nogen keep(match)"':. merge 1:1 id using _data/treatment.dta, nogen keep(match)}{p_end}
{phang2}{stata `"merge 1:1 id using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/comorbidities.dta", nogen keep(match)"':. merge 1:1 id using _data/comorbidities.dta, nogen keep(match)}{p_end}
{phang2}{stata `"merge 1:1 id using "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/outcomes.dta", nogen"':. merge 1:1 id using _data/outcomes.dta, nogen}{p_end}
{phang2}{stata "gen byte cv_event = (cv_event_date < . & cv_event_date <= study_exit)":. gen byte cv_event = (cv_event_date < . & cv_event_date <= study_exit)}{p_end}
{phang2}{stata "gen double fu_time = cond(cv_event, cv_event_date, study_exit) - study_entry":. gen double fu_time = cond(cv_event, cv_event_date, study_exit) - study_entry}{p_end}
{phang2}{stata "replace fu_time = fu_time / 365.25":. replace fu_time = fu_time / 365.25}{p_end}
{phang2}{stata "stset fu_time, failure(cv_event)":. stset fu_time, failure(cv_event)}{p_end}
{phang2}{stata "drop if _st == 0":. drop if _st == 0}{p_end}
{phang2}{stata "stcox treated index_age i.female i.education diabetes hypertension":. stcox treated index_age i.female i.education diabetes hypertension}{p_end}
{phang2}{stata "cstat_surv":. cstat_surv}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:cstat_surv} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(c)}}C-statistic{p_end}
{synopt:{cmd:e(se)}}Standard error (infinitesimal jackknife){p_end}
{synopt:{cmd:e(ci_lo)}}Lower bound of confidence interval{p_end}
{synopt:{cmd:e(ci_hi)}}Upper bound of confidence interval{p_end}
{synopt:{cmd:e(df_r)}}Degrees of freedom{p_end}
{synopt:{cmd:e(somers_d)}}Somers' D statistic (= 2C - 1){p_end}
{synopt:{cmd:e(N)}}Number of observations{p_end}
{synopt:{cmd:e(N_comparable)}}Number of comparable pairs{p_end}
{synopt:{cmd:e(N_concordant)}}Number of concordant pairs (may be fractional with tied times){p_end}
{synopt:{cmd:e(N_discordant)}}Number of discordant pairs (may be fractional with tied times){p_end}
{synopt:{cmd:e(N_tied)}}Number of tied pairs{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:cstat_surv}{p_end}
{synopt:{cmd:e(depvar)}}{cmd:_t}{p_end}
{synopt:{cmd:e(title)}}Harrell's C-statistic{p_end}
{synopt:{cmd:e(vcetype)}}Jackknife{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector (C-statistic){p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}


{title:Also see}

{psee}
Manual: {manlink ST stcox}, {manlink ST stset}

{psee}
Online: {helpb stcox}, {helpb stset}
{p_end}
