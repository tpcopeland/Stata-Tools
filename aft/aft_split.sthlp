{smcl}
{* *! version 1.1.0  15mar2026}{...}
{vieweralsosee "[ST] streg" "help streg"}{...}
{vieweralsosee "[ST] stsplit" "help stsplit"}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_pool" "help aft_pool"}{...}
{viewerjumpto "Syntax" "aft_split##syntax"}{...}
{viewerjumpto "Description" "aft_split##description"}{...}
{viewerjumpto "Options" "aft_split##options"}{...}
{viewerjumpto "Examples" "aft_split##examples"}{...}
{viewerjumpto "Stored results" "aft_split##results"}{...}
{viewerjumpto "Author" "aft_split##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:aft_split} {hline 2}}Piecewise AFT: episode splitting and per-interval fitting{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_split}
{varlist}
{ifin}
{cmd:,}
{c -(}{opt cut:points(numlist)} | {opt q:uantiles(#)}{c )-}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required (one of)}
{synopt:{opt cut:points(numlist)}}time points at which to split episodes{p_end}
{synopt:{opt q:uantiles(#)}}number of quantile-based intervals (>= 2){p_end}

{syntab:Model}
{synopt:{opt dist:ribution(dist)}}AFT distribution; reads from {cmd:aft_select} if omitted{p_end}
{synopt:{opt str:ata(varname)}}strata variable{p_end}
{synopt:{opt fra:ilty(string)}}frailty distribution{p_end}
{synopt:{opt sha:red(varname)}}shared frailty group variable{p_end}
{synopt:{opth vce(vcetype)}}variance estimator{p_end}
{synopt:{opt anc:ovariate(varlist)}}ancillary covariates{p_end}

{syntab:Reporting}
{synopt:{opt l:evel(#)}}confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt notable}}suppress results table{p_end}
{synopt:{opt sav:ing(filename)}}save per-interval results to file{p_end}
{synoptline}

{pstd}
Data must be {cmd:stset}. Either {opt cutpoints()} or {opt quantiles()} is required.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_split} fits piecewise AFT models by splitting survival data into
time intervals and fitting separate AFT models within each interval. This
allows covariate effects (time ratios) to vary across time periods.

{pstd}
The command uses Stata's {helpb stsplit} to create episodes, then fits
{helpb streg} within each interval. Per-interval coefficients and standard
errors are stored in dataset characteristics for subsequent pooling by
{helpb aft_pool}.

{pstd}
This is useful when the proportional hazards or constant time ratio
assumption is violated and the covariate effect changes over time.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt cutpoints(numlist)} specifies the time points at which to split episodes.
Values must be positive and in ascending order. For example,
{cmd:cutpoints(6 12 24)} creates four intervals: [0,6), [6,12), [12,24), and
[24,+).

{phang}
{opt quantiles(#)} specifies the number of quantile-based intervals to create.
Cutpoints are computed from the failure time distribution. For example,
{cmd:quantiles(3)} creates tertile-based intervals.

{dlgtab:Model}

{phang}
{opt distribution(dist)} specifies the AFT distribution. If omitted, reads from
{cmd:aft_select} or {cmd:aft_fit} characteristics. Valid values:
{cmd:exponential}, {cmd:weibull}, {cmd:lognormal}, {cmd:loglogistic},
{cmd:ggamma}.

{phang}
Options {opt strata()}, {opt frailty()}, {opt shared()}, {opt vce()}, and
{opt ancovariate()} are passed directly to {cmd:streg} for each interval.

{dlgtab:Reporting}

{phang}
{opt level(#)} specifies the confidence level.

{phang}
{opt nolog} suppresses the iteration log for each interval.

{phang}
{opt notable} suppresses the per-interval results table.

{phang}
{opt saving(filename)} saves per-interval results to a Stata dataset.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Split at fixed time points}

{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. aft_select drug age}{p_end}
{phang2}{cmd:. aft_split drug age, cutpoints(10 20)}{p_end}
{phang2}{cmd:. aft_pool}{p_end}

{pstd}
{bf:Example 2: Quantile-based splitting}

{phang2}{cmd:. aft_split drug age, quantiles(3) distribution(weibull)}{p_end}

{pstd}
{bf:Example 3: Full piecewise pipeline}

{phang2}{cmd:. aft_split drug age, cutpoints(10 20 30)}{p_end}
{phang2}{cmd:. aft_pool, method(random) plot}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_split} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_pieces)}}number of intervals{p_end}
{synopt:{cmd:r(n_converged)}}number of intervals that converged{p_end}
{synopt:{cmd:r(n_skipped)}}number of intervals skipped{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(cutpoints)}}cutpoint values{p_end}
{synopt:{cmd:r(dist)}}distribution used{p_end}
{synopt:{cmd:r(varlist)}}covariates{p_end}
{synopt:{cmd:r(labels)}}interval labels{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(coefs)}}coefficient matrix (vars x intervals){p_end}
{synopt:{cmd:r(ses)}}standard error matrix (vars x intervals){p_end}
{synopt:{cmd:r(table)}}fit statistics (intervals x 5: N, failures, ll, AIC, BIC){p_end}

{pstd}
Dataset characteristics {cmd:_dta[_aft_piecewise]}, {cmd:_dta[_aft_pw_*]}
are stored for use by {cmd:aft_pool}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Manual:  {manlink ST streg}, {manlink ST stsplit}

{psee}
Online:  {helpb aft}, {helpb aft_pool}, {helpb aft_select}

{hline}
