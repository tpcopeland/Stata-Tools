{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_bootstrap##syntax"}{...}
{viewerjumpto "Description" "drest_bootstrap##description"}{...}
{viewerjumpto "Options" "drest_bootstrap##options"}{...}
{viewerjumpto "Examples" "drest_bootstrap##examples"}{...}
{viewerjumpto "Stored results" "drest_bootstrap##results"}{...}
{viewerjumpto "Author" "drest_bootstrap##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:drest_bootstrap} {hline 2}}Bootstrap inference for AIPW{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_bootstrap}
[{cmd:,}
{opt r:eps(#)}
{opt seed(#)}
{opt l:evel(#)}
{opt nolog}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_bootstrap} performs non-parametric bootstrap inference for the
AIPW estimator. Each bootstrap replicate re-fits both the treatment and
outcome models, providing finite-sample-valid inference that does not rely
on the influence function variance approximation.

{pstd}
Requires that {cmd:drest_estimate} has been run. Reads model specifications
from stored dataset characteristics.


{marker options}{...}
{title:Options}

{phang}{opt reps(#)} number of bootstrap replications; default is {cmd:1000}.{p_end}
{phang}{opt seed(#)} random number seed for reproducibility.{p_end}
{phang}{opt level(#)} confidence level; default is {cmd:level(95)}.{p_end}
{phang}{opt nolog} suppresses progress messages.{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_bootstrap, reps(500) seed(12345)}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(tau)}}bootstrap estimate{p_end}
{synopt:{cmd:e(se)}}bootstrap standard error{p_end}
{synopt:{cmd:e(z)}}z-statistic{p_end}
{synopt:{cmd:e(p)}}p-value{p_end}
{synopt:{cmd:e(ci_lo)}}lower CI bound{p_end}
{synopt:{cmd:e(ci_hi)}}upper CI bound{p_end}
{synopt:{cmd:e(reps)}}number of replications requested{p_end}
{synopt:{cmd:e(reps_ok)}}number of successful replications{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
