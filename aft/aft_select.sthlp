{smcl}
{* *! version 1.0.0  14mar2026}{...}
{vieweralsosee "[ST] streg" "help streg"}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_fit" "help aft_fit"}{...}
{viewerjumpto "Syntax" "aft_select##syntax"}{...}
{viewerjumpto "Description" "aft_select##description"}{...}
{viewerjumpto "Options" "aft_select##options"}{...}
{viewerjumpto "Remarks" "aft_select##remarks"}{...}
{viewerjumpto "Examples" "aft_select##examples"}{...}
{viewerjumpto "Stored results" "aft_select##results"}{...}
{viewerjumpto "Author" "aft_select##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:aft_select} {hline 2}}Compare AFT distributions and recommend best fit{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_select}
[{varlist}]
{ifin}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Distribution}
{synopt:{opt dist:ributions(dlist)}}distributions to compare; default is all five{p_end}
{synopt:{opt exc:lude(dlist)}}distributions to exclude{p_end}

{syntab:Model}
{synopt:{opt str:ata(varname)}}strata variable{p_end}
{synopt:{opt fra:ilty(string)}}frailty distribution: {cmd:gamma} or {cmd:invgaussian}{p_end}
{synopt:{opt sha:red(varname)}}shared frailty group variable{p_end}
{synopt:{opth vce(vcetype)}}variance estimator{p_end}
{synopt:{opt anc:ovariate(varlist)}}ancillary covariates{p_end}

{syntab:Reporting}
{synopt:{opt l:evel(#)}}confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt notable}}suppress comparison table{p_end}
{synopt:{opt norecommend}}suppress recommendation{p_end}
{synopt:{opt sav:ing(filename)}}save results dataset{p_end}
{synoptline}

{pstd}
Data must be {cmd:stset} before using {cmd:aft_select}.

{pstd}
Supported distributions ({it:dlist}): {cmd:exponential}, {cmd:weibull},
{cmd:lognormal}, {cmd:loglogistic}, {cmd:ggamma}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_select} fits up to five parametric AFT distributions to {cmd:stset}
data, computes AIC and BIC for each, runs likelihood ratio tests for nested
models within the generalized gamma family, and recommends the best-fitting
distribution.

{pstd}
Results are stored in dataset characteristics so that {helpb aft_fit} can
automatically use the recommended distribution.


{marker options}{...}
{title:Options}

{dlgtab:Distribution}

{phang}
{opt distributions(dlist)} specifies which distributions to compare.
The default is all five: exponential, Weibull, lognormal, log-logistic,
and generalized gamma.

{phang}
{opt exclude(dlist)} removes distributions from comparison. For example,
{cmd:exclude(ggamma)} skips the generalized gamma, which sometimes fails
to converge with complex models.

{dlgtab:Model}

{phang}
{opt strata(varname)} passes the strata variable to {cmd:streg}.

{phang}
{opt frailty(string)} specifies the frailty distribution: {cmd:gamma} or
{cmd:invgaussian}. Passed to {cmd:streg}.

{phang}
{opt shared(varname)} specifies the shared frailty group variable.

{phang}
{opth vce(vcetype)} specifies the variance estimator. Passed to {cmd:streg}.

{phang}
{opt ancovariate(varlist)} specifies covariates for the ancillary
(shape/scale) parameter. Passed as {cmd:ancillary()} to {cmd:streg}.

{dlgtab:Reporting}

{phang}
{opt level(#)} specifies the confidence level. Default is 95.

{phang}
{opt nolog} suppresses the iteration log for each distribution fit.

{phang}
{opt notable} suppresses the comparison table.

{phang}
{opt norecommend} suppresses the distribution recommendation.

{phang}
{opt saving(filename)} saves the comparison results as a Stata dataset.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Nested model tests}

{pstd}
The generalized gamma nests the Weibull, lognormal, and exponential as
special cases. {cmd:aft_select} uses likelihood ratio tests to compare
these nested models. A non-significant test (p > 0.05) means the simpler
distribution is adequate.

{pstd}
The log-logistic is {it:not} nested in the generalized gamma family and
is compared via AIC/BIC only.

{pstd}
{bf:Convergence}

{pstd}
The generalized gamma can fail to converge with complex models (many
covariates, frailty, small samples). If convergence fails, {cmd:aft_select}
flags the failure and continues with the remaining distributions.

{pstd}
{bf:AFT metric}

{pstd}
For exponential and Weibull distributions, {cmd:streg} defaults to the
proportional hazards parameterization. {cmd:aft_select} automatically
passes the {cmd:time} option to obtain AFT (time ratio) estimates.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Compare all distributions}

{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. aft_select drug age}{p_end}

{pstd}
{bf:Example 2: Exclude generalized gamma}

{phang2}{cmd:. aft_select drug age, exclude(ggamma)}{p_end}

{pstd}
{bf:Example 3: Compare only Weibull and lognormal}

{phang2}{cmd:. aft_select drug age, distributions(weibull lognormal)}{p_end}

{pstd}
{bf:Example 4: With ancillary covariates}

{phang2}{cmd:. aft_select drug age, ancovariate(age) nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_select} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(best_aic)}}AIC of best distribution{p_end}
{synopt:{cmd:r(best_bic)}}BIC of best distribution{p_end}
{synopt:{cmd:r(n_converged)}}number of distributions that converged{p_end}
{synopt:{cmd:r(n_dists)}}number of distributions compared{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_fail)}}number of failures{p_end}
{synopt:{cmd:r(lr_weibull_p)}}LR test p-value: Weibull vs gen. gamma{p_end}
{synopt:{cmd:r(lr_lognormal_p)}}LR test p-value: lognormal vs gen. gamma{p_end}
{synopt:{cmd:r(lr_exponential_p)}}LR test p-value: exponential vs gen. gamma{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(best_dist)}}recommended distribution{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}comparison table (ll, k, AIC, BIC, converged){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-14{p_end}


{title:Also see}

{psee}
Manual:  {manlink ST streg}

{psee}
Online:  {helpb aft}, {helpb aft_fit}, {helpb aft_diagnose}, {helpb aft_compare}

{hline}
