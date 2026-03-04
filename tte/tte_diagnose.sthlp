{smcl}
{* *! version 1.0.2  28feb2026}{...}
{viewerjumpto "Syntax" "tte_diagnose##syntax"}{...}
{viewerjumpto "Description" "tte_diagnose##description"}{...}
{viewerjumpto "Options" "tte_diagnose##options"}{...}
{viewerjumpto "Examples" "tte_diagnose##examples"}{...}
{viewerjumpto "Stored results" "tte_diagnose##results"}{...}
{viewerjumpto "Author" "tte_diagnose##author"}{...}

{title:Title}

{phang}
{bf:tte_diagnose} {hline 2} Weight diagnostics and balance assessment


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_diagnose}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth bal:ance_covariates(varlist)}}covariates for balance assessment{p_end}
{synopt:{opt weight_summary}}show weight summary (default if weights exist){p_end}
{synopt:{opt by_trial}}weight distribution by trial period{p_end}
{synopt:{opt by_period}}weight distribution by follow-up period{p_end}
{synopt:{opth export(filename)}}export diagnostics to file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_diagnose} provides comprehensive diagnostics for the IP weights
and covariate balance. It reports weight summary statistics, effective
sample sizes, standardized mean differences (weighted and unweighted),
and identifies extreme weights.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_diagnose, balance_covariates(age sex comorbidity biomarker)}{p_end}
{phang2}{cmd:. tte_diagnose, balance_covariates(age sex) by_trial}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(ess)}}effective sample size (overall){p_end}
{synopt:{cmd:r(ess_treat)}}ESS for treatment arm{p_end}
{synopt:{cmd:r(ess_control)}}ESS for control arm{p_end}
{synopt:{cmd:r(max_smd_unwt)}}max unweighted SMD{p_end}
{synopt:{cmd:r(max_smd_wt)}}max weighted SMD{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}covariate balance matrix{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet
