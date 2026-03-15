{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_compare##syntax"}{...}
{viewerjumpto "Description" "drest_compare##description"}{...}
{viewerjumpto "Options" "drest_compare##options"}{...}
{viewerjumpto "Examples" "drest_compare##examples"}{...}
{viewerjumpto "Stored results" "drest_compare##results"}{...}
{viewerjumpto "Author" "drest_compare##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:drest_compare} {hline 2}}Side-by-side estimator comparison{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_compare}
[{varlist}]
{ifin}
{cmd:,}
{opt out:come(varname)}
{opt treat:ment(varname)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt out:come(varname)}}outcome variable{p_end}
{synopt:{opt treat:ment(varname)}}binary treatment indicator{p_end}

{syntab:Methods}
{synopt:{opt meth:ods(string)}}estimators to compare; default is {cmd:iptw gcomp aipw}{p_end}

{syntab:Model specification}
{synopt:{opt omod:el(varlist)}}covariates for outcome model{p_end}
{synopt:{opt of:amily(string)}}outcome model family{p_end}
{synopt:{opt tmod:el(varlist)}}covariates for treatment model{p_end}
{synopt:{opt tf:amily(string)}}treatment model family{p_end}
{synopt:{opt est:imand(string)}}estimand: {cmd:ATE} (default; only ATE supported){p_end}
{synopt:{opt trimps(numlist)}}propensity score trimming bounds{p_end}
{synopt:{opt l:evel(#)}}confidence level{p_end}

{syntab:Output}
{synopt:{opt gr:aph}}generate forest-style comparison plot{p_end}
{synopt:{opt sav:ing(string)}}save graph to file{p_end}
{synopt:{opt sch:eme(string)}}graph scheme; default is {cmd:plotplainblind}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_compare} fits multiple causal estimators on the same data and
displays results side-by-side for comparison. Available methods are IPTW
(inverse probability of treatment weighting), g-computation, and AIPW
(augmented IPW). This helps assess sensitivity to estimation strategy.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_compare weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_compare weight length, outcome(price) treatment(foreign) methods(iptw aipw) graph}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:drest_compare} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(iptw_tau)}}IPTW estimate{p_end}
{synopt:{cmd:r(iptw_se)}}IPTW standard error{p_end}
{synopt:{cmd:r(gcomp_tau)}}g-computation estimate{p_end}
{synopt:{cmd:r(gcomp_se)}}g-computation standard error{p_end}
{synopt:{cmd:r(aipw_tau)}}AIPW estimate{p_end}
{synopt:{cmd:r(aipw_se)}}AIPW standard error{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(methods)}}methods compared{p_end}
{synopt:{cmd:r(estimand)}}estimand{p_end}
{synopt:{cmd:r(outcome)}}outcome variable name{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(comparison)}}comparison matrix (methods x estimates){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
