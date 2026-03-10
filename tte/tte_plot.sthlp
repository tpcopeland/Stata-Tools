{smcl}
{* *! version 1.1.0  10mar2026}{...}
{viewerjumpto "Syntax" "tte_plot##syntax"}{...}
{viewerjumpto "Description" "tte_plot##description"}{...}
{viewerjumpto "Options" "tte_plot##options"}{...}
{viewerjumpto "Examples" "tte_plot##examples"}{...}
{viewerjumpto "Author" "tte_plot##author"}{...}

{title:Title}

{phang}
{bf:tte_plot} {hline 2} Visualization for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_plot}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth type(string)}}km, cumhaz, weights, balance, pscore, or equipoise{p_end}
{synopt:{opt ci}}show confidence intervals{p_end}
{synopt:{opth scheme(string)}}graph scheme; default is {cmd:plotplainblind}{p_end}
{synopt:{opth title(string)}}graph title{p_end}
{synopt:{opth export(filename)}}export graph to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synopt:{opt top(#)}}show top # covariates in balance plot (sorted by |SMD|){p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_plot} produces diagnostic and results visualizations.

{dlgtab:Plot types}

{phang}
{cmd:km} - Kaplan-Meier survival curves by treatment arm, optionally
weighted by IP weights.

{phang}
{cmd:cumhaz} - Cumulative incidence curves from {helpb tte_predict} with
optional confidence bands.

{phang}
{cmd:weights} - Kernel density plots of IP weight distributions by arm.

{phang}
{cmd:balance} - Love plot showing absolute standardized mean differences
before and after weighting from {helpb tte_diagnose}. Use {opt top(#)}
to show only the N most imbalanced covariates.

{phang}
{cmd:pscore} - Propensity score overlap density plot by treatment arm.
Requires {cmd:tte_weight, save_ps} to have been run first. Reference
lines at 0.1 and 0.9 indicate common trimming thresholds.

{phang}
{cmd:equipoise} - Preference score density plot by treatment arm with
dashed lines marking the equipoise zone [0.3, 0.7]. Preference scores
adjust propensity scores for treatment prevalence, with 0.5 indicating
equal preference for treatment and control.


{marker options}{...}
{title:Options}

{phang}
{opt top(#)} restricts the balance (Love) plot to the # covariates
with the largest absolute unweighted SMD. Useful when many covariates
make the full plot hard to read.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_plot, type(km)}{p_end}
{phang2}{cmd:. tte_plot, type(weights) export(weights.png) replace}{p_end}
{phang2}{cmd:. tte_plot, type(cumhaz) ci}{p_end}

{pstd}Propensity score overlap (requires {cmd:save_ps}){p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity) save_ps nolog}{p_end}
{phang2}{cmd:. tte_plot, type(pscore)}{p_end}

{pstd}Equipoise assessment{p_end}
{phang2}{cmd:. tte_plot, type(equipoise)}{p_end}

{pstd}Top-10 Love plot{p_end}
{phang2}{cmd:. tte_diagnose, balance_covariates(age sex comorbidity biomarker bmi smoking)}{p_end}
{phang2}{cmd:. tte_plot, type(balance) top(10)}{p_end}


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
