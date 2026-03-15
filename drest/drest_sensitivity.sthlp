{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_sensitivity##syntax"}{...}
{viewerjumpto "Description" "drest_sensitivity##description"}{...}
{viewerjumpto "Options" "drest_sensitivity##options"}{...}
{viewerjumpto "Examples" "drest_sensitivity##examples"}{...}
{viewerjumpto "Stored results" "drest_sensitivity##results"}{...}
{viewerjumpto "References" "drest_sensitivity##references"}{...}
{viewerjumpto "Author" "drest_sensitivity##author"}{...}
{title:Title}

{p2colset 5 28 30 2}{...}
{p2col:{cmd:drest_sensitivity} {hline 2}}E-value sensitivity analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_sensitivity}
[{cmd:,}
{opt eva:lue}
{opt rare}
{opt d:etail}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_sensitivity} computes the E-value (VanderWeele & Ding 2017)
for the AIPW treatment effect estimate. The E-value quantifies the
minimum strength of association an unmeasured confounder would need to
have with both the treatment and the outcome to explain away the observed
effect, above and beyond measured confounders.


{marker options}{...}
{title:Options}

{phang}{opt evalue} computes the E-value (default).{p_end}
{phang}{opt rare} uses the rare-outcome approximation for binary outcomes (OR {c 126} RR).{p_end}
{phang}{opt detail} displays computational details.{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_sensitivity, evalue detail}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(evalue)}}E-value for point estimate{p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for CI bound{p_end}
{synopt:{cmd:r(rr)}}risk ratio (or approximation){p_end}
{synopt:{cmd:r(tau)}}treatment effect estimate{p_end}
{synopt:{cmd:r(se)}}standard error{p_end}


{marker references}{...}
{title:References}

{pstd}
VanderWeele TJ, Ding P. Sensitivity analysis in observational research:
introducing the E-value. {it:Annals of Internal Medicine}. 2017;167(4):268-274.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
