{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_predict##syntax"}{...}
{viewerjumpto "Description" "drest_predict##description"}{...}
{viewerjumpto "Options" "drest_predict##options"}{...}
{viewerjumpto "Examples" "drest_predict##examples"}{...}
{viewerjumpto "Author" "drest_predict##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:drest_predict} {hline 2}}Potential outcome predictions{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_predict}
[{cmd:,}
{opt mu1(name)}
{opt mu0(name)}
{opt ite(name)}
{opt ps(name)}
{opt replace}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_predict} creates user-named copies of the predicted potential
outcomes, individual treatment effects, and propensity scores from a
previous {cmd:drest_estimate} call.


{marker options}{...}
{title:Options}

{phang}{opt mu1(name)} creates a variable with predicted outcome under treatment.{p_end}
{phang}{opt mu0(name)} creates a variable with predicted outcome under control.{p_end}
{phang}{opt ite(name)} creates a variable with individual treatment effect (mu1 - mu0).{p_end}
{phang}{opt ps(name)} creates a variable with propensity scores.{p_end}
{phang}{opt replace} allows overwriting existing variables.{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_predict, mu1(y1hat) mu0(y0hat) ite(tau_i) ps(pscore)}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
