{smcl}
{* *! version 1.1.0  15mar2026}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_split" "help aft_split"}{...}
{viewerjumpto "Syntax" "aft_pool##syntax"}{...}
{viewerjumpto "Description" "aft_pool##description"}{...}
{viewerjumpto "Options" "aft_pool##options"}{...}
{viewerjumpto "Examples" "aft_pool##examples"}{...}
{viewerjumpto "Stored results" "aft_pool##results"}{...}
{viewerjumpto "Author" "aft_pool##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:aft_pool} {hline 2}}Meta-analytic pooling of piecewise AFT estimates{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_pool}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt m:ethod(string)}}pooling method: {bf:fixed} (default) or {bf:random}{p_end}
{synopt:{opt pl:ot}}produce forest plot{p_end}
{synopt:{opt notable}}suppress results table{p_end}
{synopt:{opt sav:ing(filename)}}save pooled results to file{p_end}
{synopt:{opt sch:eme(schemename)}}graph scheme{p_end}
{synoptline}

{pstd}
Requires {cmd:aft_split} to have been run first.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_pool} reads per-interval AFT coefficients and standard errors
stored by {helpb aft_split} and computes inverse-variance weighted pooled
estimates.

{pstd}
Two pooling methods are available:

{phang2}{bf:Fixed-effect} (default): assumes a common true effect across
intervals. Pooled estimate is the inverse-variance weighted average.

{phang2}{bf:Random-effects}: uses the DerSimonian-Laird estimator to account
for between-interval heterogeneity. Appropriate when the time ratio is
expected to vary across intervals.

{pstd}
For each covariate, {cmd:aft_pool} reports heterogeneity statistics:
Cochran's Q (test of homogeneity) and I{c 178} (percentage of variability
due to heterogeneity vs sampling error). High I{c 178} (>50%) suggests the
time ratio varies meaningfully across intervals.


{marker options}{...}
{title:Options}

{phang}
{opt method(string)} specifies the pooling method. {bf:fixed} (default) uses
inverse-variance weighting. {bf:random} uses DerSimonian-Laird random-effects.

{phang}
{opt plot} produces a forest plot showing per-interval time ratios with
confidence intervals and the pooled estimate.

{phang}
{opt notable} suppresses the results table.

{phang}
{opt saving(filename)} saves pooled results to a Stata dataset.

{phang}
{opt scheme(schemename)} specifies the graph scheme. Default is
{cmd:plotplainblind}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Fixed-effect pooling}

{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. aft_split drug age, cutpoints(10 20) distribution(weibull)}{p_end}
{phang2}{cmd:. aft_pool}{p_end}

{pstd}
{bf:Example 2: Random-effects with forest plot}

{phang2}{cmd:. aft_pool, method(random) plot}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_pool} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_pieces)}}number of intervals{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(method)}}pooling method used{p_end}
{synopt:{cmd:r(dist)}}distribution{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(pooled)}}pooled results (vars x 5: TR, SE, ci_lo, ci_hi, p){p_end}
{synopt:{cmd:r(heterogeneity)}}heterogeneity stats (vars x 3: Q, Q_p, I2){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online:  {helpb aft}, {helpb aft_split}

{hline}
