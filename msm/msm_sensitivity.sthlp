{smcl}
{* *! version 1.0.0  03mar2026}{...}
{viewerjumpto "Syntax" "msm_sensitivity##syntax"}{...}
{viewerjumpto "Description" "msm_sensitivity##description"}{...}
{viewerjumpto "Examples" "msm_sensitivity##examples"}{...}
{viewerjumpto "References" "msm_sensitivity##references"}{...}
{viewerjumpto "Author" "msm_sensitivity##author"}{...}

{title:Title}

{phang}
{bf:msm_sensitivity} {hline 2} Sensitivity analysis for unmeasured confounding


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_sensitivity}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt eva:lue}}compute E-value (default){p_end}
{synopt:{opt con:founding_strength(# #)}}RR(U,D) and RR(U,Y) for bias factor{p_end}
{synopt:{opt level(#)}}confidence level; default 95{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_sensitivity} assesses sensitivity to unmeasured confounding.

{pstd}
The {bf:E-value} (VanderWeele & Ding 2017) is the minimum strength of
association on the risk ratio scale that an unmeasured confounder would
need with both treatment and outcome to explain away the observed effect.

{pstd}
{bf:Confounding strength bounds} compute the bias factor given hypothetical
confounder-treatment (RR_UD) and confounder-outcome (RR_UY) associations.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_sensitivity, evalue}{p_end}
{phang2}{cmd:. msm_sensitivity, confounding_strength(1.5 2.0)}{p_end}


{marker references}{...}
{title:References}

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational research:
introducing the E-value. {it:Annals of Internal Medicine}. 2017;167(4):268-274.


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
