{smcl}
{* *! version 1.1.0  15mar2026}{...}
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
{synopt:{opt by_trial}}weight distribution by trial period{p_end}
{synopt:{opt equi:poise}}compute preference scores and equipoise assessment{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_diagnose} provides comprehensive diagnostics for the IP weights
and covariate balance. It reports weight summary statistics, effective
sample sizes, standardized mean differences (weighted and unweighted),
and identifies extreme weights.

{pstd}
When {opt equipoise} is specified, {cmd:tte_diagnose} computes preference
scores (Walker et al., 2013) that adjust propensity scores for treatment
prevalence. The percentage of observations falling in the equipoise zone
[0.3, 0.7] is reported. Requires {cmd:tte_weight, save_ps} to have been
run first.


{marker options}{...}
{title:Options}

{phang}
{opt equipoise} computes preference scores and reports the proportion of
observations in the clinical equipoise zone [0.3, 0.7]. A preference
score of 0.5 indicates equal "preference" for treatment and control
after adjusting for treatment prevalence. High overlap in the equipoise
zone supports the positivity assumption.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_diagnose, balance_covariates(age sex comorbidity biomarker)}{p_end}
{phang2}{cmd:. tte_diagnose, balance_covariates(age sex) by_trial}{p_end}

{pstd}Equipoise assessment (requires {cmd:save_ps}){p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity) save_ps nolog}{p_end}
{phang2}{cmd:. tte_diagnose, equipoise}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(ess)}}effective sample size (overall){p_end}
{synopt:{cmd:r(ess_treat)}}ESS for treatment arm{p_end}
{synopt:{cmd:r(ess_control)}}ESS for control arm{p_end}
{synopt:{cmd:r(max_smd_unwt)}}max unweighted SMD{p_end}
{synopt:{cmd:r(max_smd_wt)}}max weighted SMD{p_end}
{synopt:{cmd:r(prevalence)}}treatment prevalence at baseline (if {cmd:equipoise}){p_end}
{synopt:{cmd:r(pct_equipoise)}}% of observations in equipoise zone (if {cmd:equipoise}){p_end}
{synopt:{cmd:r(mean_pref_treat)}}mean preference score, treated (if {cmd:equipoise}){p_end}
{synopt:{cmd:r(mean_pref_control)}}mean preference score, control (if {cmd:equipoise}){p_end}

{p2col 5 25 29 2: Matrices}{p_end}
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
