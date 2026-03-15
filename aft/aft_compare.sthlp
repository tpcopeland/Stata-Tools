{smcl}
{* *! version 1.0.0  14mar2026}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[ST] streg" "help streg"}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_select" "help aft_select"}{...}
{viewerjumpto "Syntax" "aft_compare##syntax"}{...}
{viewerjumpto "Description" "aft_compare##description"}{...}
{viewerjumpto "Options" "aft_compare##options"}{...}
{viewerjumpto "Remarks" "aft_compare##remarks"}{...}
{viewerjumpto "Examples" "aft_compare##examples"}{...}
{viewerjumpto "Stored results" "aft_compare##results"}{...}
{viewerjumpto "Author" "aft_compare##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:aft_compare} {hline 2}}Cox PH vs AFT side-by-side comparison{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_compare}
[{varlist}]
{ifin}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Model}
{synopt:{opt dist:ribution(dist)}}AFT distribution; reads from {cmd:aft_select} if omitted{p_end}
{synopt:{opt nosch:oenfeld}}skip Schoenfeld PH test{p_end}

{syntab:Reporting}
{synopt:{opt notable}}suppress comparison table{p_end}
{synopt:{opt pl:ot}}overlay survival curves{p_end}
{synopt:{opt sav:ing(stub)}}save graph as {it:stub}_compare.png{p_end}
{synopt:{opt scheme(passthru)}}graph scheme; default is {cmd:plotplainblind}{p_end}
{synoptline}

{pstd}
Data must be {cmd:stset}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_compare} fits a Cox proportional hazards model and an AFT model on
the same covariates, then displays a side-by-side comparison table showing
hazard ratios (HR) from Cox and time ratios (TR) from AFT.

{pstd}
By default, the Schoenfeld test for the PH assumption is performed. Covariates
where the PH assumption is violated are flagged, suggesting the AFT model
may be more appropriate.

{pstd}
Interpretation: HR > 1 means increased hazard (shorter survival). TR > 1
means longer survival time. When PH holds, TR {&approx} 1/HR approximately.


{marker options}{...}
{title:Options}

{dlgtab:Model}

{phang}
{opt distribution(dist)} specifies the AFT distribution. If omitted, reads
from {cmd:aft_select} or {cmd:aft_fit} characteristics.

{phang}
{opt noschoenfeld} skips the Schoenfeld test for proportional hazards.

{dlgtab:Reporting}

{phang}
{opt notable} suppresses the comparison table.

{phang}
{opt plot} produces an overlay plot of Kaplan-Meier and AFT-predicted
survival curves.

{phang}
{opt saving(stub)} saves the plot as {it:stub}_compare.png.

{phang}
{opt scheme(schemename)} specifies the graph scheme. Default is
{cmd:plotplainblind}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to prefer AFT over Cox}

{pstd}
If the Schoenfeld test rejects the PH assumption (p < 0.05), the Cox model
is misspecified. AFT models do not require proportional hazards and can
provide valid inference when PH is violated.

{pstd}
Even when PH holds, AFT time ratios may be more interpretable: "treatment
extends survival by 40%" (TR = 1.4) vs "treatment reduces hazard by 30%"
(HR = 0.7).

{pstd}
{bf:Comparison limitations}

{pstd}
Cox and AFT log-likelihoods are not directly comparable (different models,
different scales). The comparison table shows AIC for within-model-class
reference only.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Full comparison}

{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. aft_compare drug age, distribution(weibull)}{p_end}

{pstd}
{bf:Example 2: With survival curve overlay}

{phang2}{cmd:. aft_compare drug age, distribution(lognormal) plot}{p_end}

{pstd}
{bf:Example 3: Skip Schoenfeld test}

{phang2}{cmd:. aft_compare drug age, noschoenfeld}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_compare} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(ph_global_p)}}global Schoenfeld test p-value{p_end}
{synopt:{cmd:r(ph_global_chi2)}}global Schoenfeld test chi-squared{p_end}
{synopt:{cmd:r(cox_ll)}}Cox model log-likelihood{p_end}
{synopt:{cmd:r(cox_aic)}}Cox model AIC{p_end}
{synopt:{cmd:r(aft_ll)}}AFT model log-likelihood{p_end}
{synopt:{cmd:r(aft_aic)}}AFT model AIC{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(dist)}}AFT distribution used{p_end}
{synopt:{cmd:r(varlist)}}covariates{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(comparison)}}comparison matrix (cox_hr, cox_lo, cox_hi, aft_tr, aft_lo, aft_hi){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-14{p_end}


{title:Also see}

{psee}
Manual:  {manlink ST stcox}, {manlink ST streg}

{psee}
Online:  {helpb aft}, {helpb aft_select}, {helpb aft_fit}, {helpb aft_diagnose}

{hline}
