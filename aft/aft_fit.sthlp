{smcl}
{* *! version 1.0.0  14mar2026}{...}
{vieweralsosee "[ST] streg" "help streg"}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_select" "help aft_select"}{...}
{viewerjumpto "Syntax" "aft_fit##syntax"}{...}
{viewerjumpto "Description" "aft_fit##description"}{...}
{viewerjumpto "Options" "aft_fit##options"}{...}
{viewerjumpto "Examples" "aft_fit##examples"}{...}
{viewerjumpto "Stored results" "aft_fit##results"}{...}
{viewerjumpto "Author" "aft_fit##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:aft_fit} {hline 2}}Fit AFT model with selected distribution{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_fit}
[{varlist}]
{ifin}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Model}
{synopt:{opt dist:ribution(dist)}}AFT distribution; reads from {cmd:aft_select} if omitted{p_end}
{synopt:{opt notr:atio}}display coefficients instead of time ratios{p_end}

{syntab:streg options}
{synopt:{opt str:ata(varname)}}strata variable{p_end}
{synopt:{opt fra:ilty(string)}}frailty distribution{p_end}
{synopt:{opt sha:red(varname)}}shared frailty group variable{p_end}
{synopt:{opth vce(vcetype)}}variance estimator{p_end}
{synopt:{opt anc:ovariate(varlist)}}ancillary covariates{p_end}

{syntab:Reporting}
{synopt:{opt l:evel(#)}}confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt noheader}}suppress header display{p_end}
{synoptline}

{pstd}
Data must be {cmd:stset}. If {cmd:distribution()} is omitted, {cmd:aft_fit}
reads the recommendation from {cmd:aft_select}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_fit} wraps {cmd:streg} with the correct AFT parameterization.
It reads the recommended distribution from {helpb aft_select} (stored in
dataset characteristics) or accepts a manual override via {opt distribution()}.

{pstd}
By default, results are displayed as time ratios (TR). A TR > 1 means the
covariate is associated with longer survival time.

{pstd}
If {it:varlist} is omitted, {cmd:aft_fit} uses the covariates from
{cmd:aft_select}. Model options (strata, frailty, vce) are also inherited
from {cmd:aft_select} unless explicitly overridden.


{marker options}{...}
{title:Options}

{dlgtab:Model}

{phang}
{opt distribution(dist)} specifies the AFT distribution. Valid values:
{cmd:exponential}, {cmd:weibull}, {cmd:lognormal}, {cmd:loglogistic},
{cmd:ggamma}. If omitted, reads from {cmd:aft_select} characteristics.

{phang}
{opt notratio} displays regression coefficients instead of exponentiated
time ratios.

{dlgtab:streg options}

{phang}
Options {opt strata()}, {opt frailty()}, {opt shared()}, {opt vce()}, and
{opt ancovariate()} are passed directly to {cmd:streg}. If omitted, they
are inherited from {cmd:aft_select} characteristics.

{dlgtab:Reporting}

{phang}
{opt level(#)} specifies the confidence level.

{phang}
{opt nolog} suppresses the iteration log.

{phang}
{opt noheader} suppresses the header display.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Use aft_select recommendation}

{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. aft_select drug age}{p_end}
{phang2}{cmd:. aft_fit drug age}{p_end}

{pstd}
{bf:Example 2: Manual distribution override}

{phang2}{cmd:. aft_fit drug age, distribution(weibull)}{p_end}

{pstd}
{bf:Example 3: Display coefficients}

{phang2}{cmd:. aft_fit drug age, notratio}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_fit} stores {cmd:streg} estimation results in {cmd:e()} plus:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(aft_cmd)}}{cmd:aft_fit}{p_end}
{synopt:{cmd:e(aft_dist)}}distribution used{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-14{p_end}


{title:Also see}

{psee}
Manual:  {manlink ST streg}

{psee}
Online:  {helpb aft}, {helpb aft_select}, {helpb aft_diagnose}, {helpb aft_compare}

{hline}
