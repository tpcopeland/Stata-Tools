{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_diagnose##syntax"}{...}
{viewerjumpto "Description" "msm_diagnose##description"}{...}
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
{synopt:{opt by_period}}show weight stats by period{p_end}
{synopt:{opt thr:eshold(#)}}SMD threshold; default 0.1{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_diagnose} displays weight distribution summaries (mean, SD,
percentiles, effective sample size) and covariate balance using
standardized mean differences (SMD) before and after weighting.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_diagnose}{p_end}
{phang2}{cmd:. msm_diagnose, by_period threshold(0.1)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
