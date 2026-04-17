{smcl}
{* *! version 1.0.1  17apr2026}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "[XT] xtgee" "help xtgee"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "iivw##syntax"}{...}
{viewerjumpto "Description" "iivw##description"}{...}
{viewerjumpto "Commands" "iivw##commands"}{...}
{viewerjumpto "Workflow" "iivw##workflow"}{...}
{viewerjumpto "Examples" "iivw##examples"}{...}
{viewerjumpto "Stored results" "iivw##results"}{...}
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
The typical analysis proceeds in three steps:

{phang2}1. Compute weights with {cmd:iivw_weight}, specifying the visit intensity
covariates and (optionally) treatment and treatment covariates.{p_end}

{phang2}2. Inspect weights using {cmd:summarize _iivw_weight, detail} and
optionally re-run with truncation.{p_end}

{phang2}3. Fit the outcome model with {cmd:iivw_fit}, which applies the weights
to a GEE (independence working correlation) or mixed model.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup example data}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 20260417}{p_end}
{phang2}{cmd:. set obs 320}{p_end}
{phang2}{cmd:. gen long id = ceil(_n/4)}{p_end}
{phang2}{cmd:. bysort id: gen byte visit = _n}{p_end}
{phang2}{cmd:. gen double days = (visit - 1) * 90 + runiform() * 20}{p_end}
{phang2}{cmd:. replace days = 0 if visit == 1}{p_end}
{phang2}{cmd:. gen double edss_bl = 2 + 3 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace edss_bl = edss_bl[1]}{p_end}
{phang2}{cmd:. gen double age = 35 + 15 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace age = age[1]}{p_end}
{phang2}{cmd:. gen byte sex = runiform() > 0.5}{p_end}
{phang2}{cmd:. bysort id: replace sex = sex[1]}{p_end}
{phang2}{cmd:. gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))}{p_end}
{phang2}{cmd:. bysort id: replace treated = treated[1]}{p_end}
{phang2}{cmd:. gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)}{p_end}
{phang2}{cmd:. gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))}{p_end}
{phang2}{cmd:. gen byte treatment = cond(treated == 0, 0, cond(edss_bl < 3.5, 1, 2))}{p_end}
{phang2}{cmd:. label define arm 0 "Placebo" 1 "Low dose" 2 "High dose"}{p_end}
{phang2}{cmd:. label values treatment arm}{p_end}

{pstd}
{bf:Example 1: IIW only (visit process correction)}

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
Pullenayegum EM. 2016.
Multiple outputation for the analysis of longitudinal data subject to
irregular observation.
{it:Statistics in Medicine} 35: 1800-1818.

{phang}
Pullenayegum EM. 2020.
IrregLong: Analysis of longitudinal data with irregular observation times.
R package. CRAN.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of available commands{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version{p_end}
{synopt:{cmd:r(commands)}}list of available commands{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.1, 2026-04-17{p_end}


{title:Also see}

{psee}
Online:  {helpb iivw_weight}, {helpb iivw_fit}, {helpb xtgee}, {helpb stcox}

{hline}
