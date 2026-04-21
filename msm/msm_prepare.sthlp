{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_validate" "help msm_validate"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
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
{synopt:{opt id(varname)}}individual identifier{p_end}
{synopt:{opt per:iod(varname)}}time period variable (integer){p_end}
{synopt:{opt treat:ment(varname)}}binary treatment indicator (0/1){p_end}
{synopt:{opt out:come(varname)}}binary outcome indicator (0/1){p_end}

{syntab:Optional}
{synopt:{opt cen:sor(varname)}}binary censoring indicator (0/1){p_end}
{synopt:{opt cov:ariates(varlist)}}time-varying covariates{p_end}
{synopt:{opt bas:eline_covariates(varlist)}}baseline-only covariates{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_prepare} is the entry point for the MSM pipeline. It validates the
input data structure, maps user variable names, and stores metadata as dataset
characteristics for downstream commands.

{pstd}
Data must be in person-period (long) format with one row per individual per
time period. All individuals must share the common baseline period, and
variables passed in {cmd:baseline_covariates()} must be time-fixed within
individual.

{pstd}
Re-running {cmd:msm_prepare} overwrites the stored mapping and clears
downstream {cmd:_msm_*} analysis artifacts from earlier weighting, fitting,
prediction, and diagnostic runs, making it the right restart point when your
analysis specification changes.


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

{marker examples}{...}
{title:Examples}

{pstd}Minimal mapping of a person-period dataset{p_end}
{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome)}{p_end}

{pstd}Full mapping for the intended IPTW workflow{p_end}
{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    censor(censored) baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. return list}{p_end}

{pstd}Restart after revising the mapped covariate set{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{pstd}
After re-running {cmd:msm_prepare}, re-run {helpb msm_validate} and
{helpb msm_weight} because prior downstream results are cleared.{p_end}


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
{synopt:{cmd:r(n_censored)}}number of censored observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(id)}}ID variable name{p_end}
{synopt:{cmd:r(period)}}period variable name{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(outcome)}}outcome variable name{p_end}
{synopt:{cmd:r(censor)}}censoring variable name{p_end}
{synopt:{cmd:r(covariates)}}time-varying covariates{p_end}
{synopt:{cmd:r(baseline_covariates)}}baseline covariates{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
