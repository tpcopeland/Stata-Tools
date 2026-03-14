{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_validate##syntax"}{...}
{viewerjumpto "Description" "msm_validate##description"}{...}
{viewerjumpto "Examples" "msm_validate##examples"}{...}
{viewerjumpto "Author" "msm_validate##author"}{...}

{title:Title}

{phang}
{bf:msm_validate} {hline 2} Data quality checks for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_validate}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt str:ict}}treat warnings as errors{p_end}
{synopt:{opt ver:bose}}show detailed diagnostics{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_validate} runs 10 data quality checks: person-period format,
gaps, terminal outcome, treatment variation, missing data, sufficient
observations per period, covariate completeness, treatment history
patterns, censoring patterns, and positivity by period.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_validate}{p_end}
{phang2}{cmd:. msm_validate, strict verbose}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
