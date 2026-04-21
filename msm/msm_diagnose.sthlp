{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_plot" "help msm_plot"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{viewerjumpto "Syntax" "msm_diagnose##syntax"}{...}
{viewerjumpto "Description" "msm_diagnose##description"}{...}
{viewerjumpto "Options" "msm_diagnose##options"}{...}
{viewerjumpto "Stored results" "msm_diagnose##stored"}{...}
{viewerjumpto "Examples" "msm_diagnose##examples"}{...}
{viewerjumpto "Author" "msm_diagnose##author"}{...}

{title:Title}

{phang}
{bf:msm_diagnose} {hline 2} Weight diagnostics and covariate balance for MSM


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_diagnose}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth bal:ance_covariates(varlist)}}covariates for SMD assessment{p_end}
{synopt:{opt by_:period}}show weight stats by period{p_end}
{synopt:{opt thr:eshold(#)}}SMD threshold; default 0.1{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_diagnose} displays weight distribution summaries (mean, SD,
percentiles, effective sample size) and covariate balance using
standardized mean differences (SMD) before and after weighting.

{pstd}
This command requires a prior {helpb msm_weight} run. If
{cmd:balance_covariates()} is omitted, {cmd:msm_diagnose} uses the covariates
registered earlier with {helpb msm_prepare}.


{marker options}{...}
{title:Options}

{phang}
{opth balance_covariates(varlist)} specifies covariates for SMD balance
assessment. Defaults to all covariates mapped in {cmd:msm_prepare}.

{phang}
{opt by_:period} displays weight distribution statistics separately for
each time period, useful for identifying periods with extreme weights.

{phang}
{opt threshold(#)} sets the SMD threshold for acceptable balance. Default
is 0.1. Covariates with weighted SMD exceeding this threshold are flagged.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_diagnose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}weight standard deviation{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile weight{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile weight{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(ess_pct)}}ESS as percentage{p_end}
{synopt:{cmd:r(n_extreme)}}number of extreme weights{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}covariate balance matrix (if covariates specified){p_end}


{marker examples}{...}
{title:Examples}

{pstd}Setup for diagnostics{p_end}
{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}Overall weight diagnostics with default mapped covariates{p_end}
{phang2}{cmd:. msm_diagnose}{p_end}

{pstd}Period-specific diagnostics and explicit balance review{p_end}
{phang2}{cmd:. msm_diagnose, balance_covariates(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    by_period threshold(0.1)}{p_end}
{phang2}{cmd:. matrix list r(balance)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
