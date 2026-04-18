{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{viewerjumpto "Syntax" "msm_fit##syntax"}{...}
{viewerjumpto "Description" "msm_fit##description"}{...}
{viewerjumpto "Options" "msm_fit##options"}{...}
{viewerjumpto "Stored results" "msm_fit##stored"}{...}
{viewerjumpto "Examples" "msm_fit##examples"}{...}
{viewerjumpto "Author" "msm_fit##author"}{...}

{title:Title}

{phang}
{bf:msm_fit} {hline 2} Weighted outcome model for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_fit}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt mod:el(string)}}logistic (default), linear, or cox{p_end}
{synopt:{opt outcome_cov(varlist)}}additional time-fixed outcome covariates{p_end}
{synopt:{opt per:iod_spec(string)}}linear, quadratic (default), cubic, ns(#), or none{p_end}
{synopt:{opt cl:uster(varname)}}cluster variable; default is ID{p_end}
{synopt:{opt boot:strap(#)}}bootstrap replicates (0 = no bootstrap){p_end}
{synopt:{opt level(#)}}confidence level; default is 95{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_fit} fits the weighted outcome model for MSM estimation. It supports
pooled logistic regression (GLM with binomial family), linear regression,
or Cox proportional hazards. Robust/sandwich standard errors are clustered
at the individual level by default.


{marker options}{...}
{title:Options}

{phang}
{opt mod:el(string)} specifies the model type. {cmd:logistic} fits a pooled
logistic regression via GLM. {cmd:linear} fits a weighted linear model.
{cmd:cox} fits a weighted Cox proportional hazards model.

{phang}
{opth outcome_cov(varlist)} specifies additional time-fixed covariates for the
outcome model beyond treatment and period. If you plan to run
{helpb msm_predict}, use baseline-only covariates here; dynamic time-varying
covariate paths are not propagated by the prediction routine.

{phang}
{opt per:iod_spec(string)} specifies the functional form for period in
the outcome model: {cmd:linear}, {cmd:quadratic} (default), {cmd:cubic},
{cmd:ns(#)} (natural splines with # df), or {cmd:none}.

{phang}
{opth cluster(varname)} specifies the clustering variable for robust
sandwich standard errors. Default is the patient ID from {cmd:msm_prepare}.

{phang}
{opt boot:strap(#)} requests bootstrap variance estimation with the
specified number of replicates. Default is 0 (no bootstrap).
Not yet implemented.

{phang}
{opt level(#)} specifies the confidence level. Default is 95.

{phang}
{opt nolog} suppresses the iteration log.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_fit} stores standard {cmd:glm}/{cmd:regress}/{cmd:stcox} results
in {cmd:e()}, plus:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:e(msm_cmd)}}{cmd:"msm_fit"}{p_end}
{synopt:{cmd:e(msm_model)}}model type (logistic, linear, or cox){p_end}
{synopt:{cmd:e(msm_treatment)}}treatment variable name{p_end}
{synopt:{cmd:e(msm_period_spec)}}period specification used{p_end}

{p2col 5 25 29 2: Matrices}{p_end}
{synopt:{cmd:e(effects)}}1 x 4 effect matrix with columns {cmd:estimate}, {cmd:ci_lower}, {cmd:ci_upper}, and {cmd:pvalue}{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(logistic) period_spec(ns(3)) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(cox) outcome_cov(age sex) nolog}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
