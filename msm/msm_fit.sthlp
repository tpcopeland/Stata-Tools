{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_fit##syntax"}{...}
{viewerjumpto "Description" "msm_fit##description"}{...}
{viewerjumpto "Options" "msm_fit##options"}{...}
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
{synopt:{opth outcome_cov(varlist)}}additional outcome covariates{p_end}
{synopt:{opt per:iod_spec(string)}}linear, quadratic (default), cubic, ns(#), or none{p_end}
{synopt:{opth cl:uster(varname)}}cluster variable; default is ID{p_end}
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
{opth outcome_cov(varlist)} specifies additional covariates for the
outcome model beyond treatment and period.

{phang}
{opt per:iod_spec(string)} specifies the functional form for period in
the outcome model: {cmd:linear}, {cmd:quadratic} (default), {cmd:cubic},
{cmd:ns(#)} (natural splines with # df), or {cmd:none}.

{phang}
{opt boot:strap(#)} requests bootstrap variance estimation with the
specified number of replicates. Default is 0 (no bootstrap).


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(logistic) period_spec(ns(3)) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(cox) outcome_cov(age sex) nolog}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
