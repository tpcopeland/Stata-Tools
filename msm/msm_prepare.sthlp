{smcl}
{* *! version 1.0.0  03mar2026}{...}
{viewerjumpto "Syntax" "msm_prepare##syntax"}{...}
{viewerjumpto "Description" "msm_prepare##description"}{...}
{viewerjumpto "Options" "msm_prepare##options"}{...}
{viewerjumpto "Examples" "msm_prepare##examples"}{...}
{viewerjumpto "Stored results" "msm_prepare##results"}{...}
{viewerjumpto "Author" "msm_prepare##author"}{...}

{title:Title}

{phang}
{bf:msm_prepare} {hline 2} Data preparation and variable mapping for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_prepare}
{cmd:,} {opth id(varname)} {opth per:iod(varname)} {opth treat:ment(varname)}
{opth out:come(varname)}
[{it:options}]

{synoptset 35 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth id(varname)}}individual identifier{p_end}
{synopt:{opth per:iod(varname)}}time period variable (integer){p_end}
{synopt:{opth treat:ment(varname)}}binary treatment indicator (0/1){p_end}
{synopt:{opth out:come(varname)}}binary outcome indicator (0/1){p_end}

{syntab:Optional}
{synopt:{opth cen:sor(varname)}}binary censoring indicator (0/1){p_end}
{synopt:{opth cov:ariates(varlist)}}time-varying covariates{p_end}
{synopt:{opth bas:eline_covariates(varlist)}}baseline-only covariates{p_end}
{synopt:{opth gen:erate(string)}}variable prefix; default is {cmd:_msm_}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_prepare} is the entry point for the MSM pipeline. It validates the
input data structure, maps user variable names, and stores metadata as dataset
characteristics for downstream commands.

{pstd}
Data must be in person-period (long) format with one row per individual per
time period.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth id(varname)} specifies the individual identifier variable.

{phang}
{opth per:iod(varname)} specifies the time period variable. Must be integer-valued.

{phang}
{opth treat:ment(varname)} specifies the binary treatment indicator (0/1).

{phang}
{opth out:come(varname)} specifies the binary outcome indicator (0/1).

{dlgtab:Optional}

{phang}
{opth cen:sor(varname)} specifies a binary censoring indicator (0/1).

{phang}
{opth cov:ariates(varlist)} specifies time-varying covariates for weight models.

{phang}
{opth bas:eline_covariates(varlist)} specifies baseline-only covariates.

{phang}
{opth gen:erate(string)} specifies the prefix for generated variables;
default is {cmd:_msm_}.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use msm_example.dta}{p_end}

{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_prepare} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_ids)}}number of unique individuals{p_end}
{synopt:{cmd:r(n_periods)}}number of periods{p_end}
{synopt:{cmd:r(n_events)}}number of outcome events{p_end}
{synopt:{cmd:r(n_treated)}}number of treated observations{p_end}

{p2col 5 20 24 2: Locals}{p_end}
{synopt:{cmd:r(id)}}ID variable name{p_end}
{synopt:{cmd:r(period)}}period variable name{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(outcome)}}outcome variable name{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
