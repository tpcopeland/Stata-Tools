{smcl}
{* *! version 1.1.0  7mar2026}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "[XT] xtgee" "help xtgee"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "iivw##syntax"}{...}
{viewerjumpto "Description" "iivw##description"}{...}
{viewerjumpto "Commands" "iivw##commands"}{...}
{viewerjumpto "Workflow" "iivw##workflow"}{...}
{viewerjumpto "Examples" "iivw##examples"}{...}
{viewerjumpto "References" "iivw##references"}{...}
{viewerjumpto "Author" "iivw##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:iivw} {hline 2}}Inverse intensity of visit weighting for longitudinal data{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw} is a package for correcting informative visit processes in
longitudinal observational studies with irregular visit times.  It implements
inverse intensity weighting (IIW; Buzkova & Lumley 2007), inverse probability
of treatment weighting (IPTW), and their multiplicative combination (FIPTIW;
Tompkins et al. 2025).

{pstd}
The package provides two main commands:

{phang2}{helpb iivw_weight} computes IIW, IPTW, or FIPTIW weights{p_end}
{phang2}{helpb iivw_fit} fits weighted outcome models via GEE or mixed effects{p_end}

{pstd}
In clinic-based longitudinal data, sicker patients often visit more frequently,
biasing naive analyses.  IIW corrects this by weighting each observation by the
inverse of its estimated visit intensity.  When combined with IPTW for treatment
confounding, the resulting FIPTIW weights address both sources of bias
simultaneously.


{marker commands}{...}
{title:Commands}

{synoptset 20}{...}
{synopt:{helpb iivw_weight}}compute IIW/IPTW/FIPTIW weights from visit and treatment models{p_end}
{synopt:{helpb iivw_fit}}fit weighted outcome model using GEE or mixed effects{p_end}


{marker workflow}{...}
{title:Workflow}

{pstd}
The typical analysis proceeds in two steps:

{phang2}1. Compute weights with {cmd:iivw_weight}, specifying the visit intensity
covariates and (optionally) treatment and treatment covariates.{p_end}

{phang2}2. Inspect weights using {cmd:summarize _iivw_weight, detail} and
optionally re-run with truncation.{p_end}

{phang2}3. Fit the outcome model with {cmd:iivw_fit}, which applies the weights
to a GEE (independence working correlation) or mixed model.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: IIW only (visit process correction)}

{phang2}{cmd:. use relapses.dta, clear}{p_end}
{phang2}{cmd:. sort id edss_date}{p_end}
{phang2}{cmd:. gen double days = edss_date - dx_date}{p_end}
{phang2}{cmd:. gen byte relapse = !missing(relapse_date)}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog}{p_end}
{phang2}{cmd:. iivw_fit edss relapse, model(gee) timespec(linear)}{p_end}

{pstd}
{bf:Example 2: FIPTIW (visit + treatment correction)}

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) treat(treated) treat_cov(age sex edss_bl) truncate(1 99) replace nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)}{p_end}


{marker references}{...}
{title:References}

{phang}
Buzkova P, Lumley T. 2007.
Longitudinal data analysis for generalized linear models with follow-up
dependent on outcome-related variables.
{it:Canadian Journal of Statistics} 35: 485-500.

{phang}
Lin H, Scharfstein DO, Rosenheck RA. 2004.
Analysis of longitudinal data with irregular, outcome-dependent follow-up.
{it:JRSS-B} 66: 791-813.

{phang}
Tompkins G, Dubin JA, Wallace M. 2025.
On flexible inverse probability of treatment and intensity weighting.
{it:Statistical Methods in Medical Research}.

{phang}
Pullenayegum EM. 2020.
Meeting the assumptions of inverse-intensity weighting.
{it:Epidemiologic Methods}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-06{p_end}


{title:Also see}

{psee}
Online:  {helpb iivw_weight}, {helpb iivw_fit}, {helpb xtgee}, {helpb stcox}

{hline}
