{smcl}
{* *! version 1.0.2  01mar2026}{...}
{viewerjumpto "Syntax" "nma_fit##syntax"}{...}
{viewerjumpto "Description" "nma_fit##description"}{...}
{viewerjumpto "Options" "nma_fit##options"}{...}
{viewerjumpto "Examples" "nma_fit##examples"}{...}
{viewerjumpto "Stored results" "nma_fit##results"}{...}
{viewerjumpto "Author" "nma_fit##author"}{...}

{title:Title}

{phang}
{bf:nma_fit} {hline 2} Fit consistency model for network meta-analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_fit}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt met:hod(string)}}reml (default) or ml{p_end}
{synopt:{opt common}}common (fixed) effect model{p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt iter:ate(#)}}maximum iterations; default is {cmd:200}{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance; default is {cmd:1e-8}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt eform}}display exponentiated coefficients{p_end}
{synopt:{opt dig:its(#)}}decimal places in display; default is {cmd:4}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_fit} fits the network meta-analysis consistency model using
multivariate random-effects meta-analysis. The model assumes that
treatment effects are consistent across the network (transitivity
assumption).

{pstd}
The estimation is performed via a custom Mata REML engine that optimizes
the restricted log-likelihood using Newton-Raphson with Cholesky
parameterization of the between-study variance matrix.

{pstd}
Results are posted to {cmd:e()}, allowing use of standard Stata
post-estimation commands including {helpb lincom}, {helpb nlcom},
and {helpb test}.


{marker options}{...}
{title:Options}

{phang}
{opt method(string)} specifies the estimation method. {opt reml} (default)
uses restricted maximum likelihood. {opt ml} uses maximum likelihood.

{phang}
{opt common} fits a common (fixed) effect model with no between-study
heterogeneity. Equivalent to setting tau-squared to zero.

{phang}
{opt level(#)} specifies the confidence level. Default is 95.

{phang}
{opt iterate(#)} specifies the maximum number of iterations. Default is 200.

{phang}
{opt tolerance(#)} specifies the convergence tolerance. Default is 1e-8.

{phang}
{opt nolog} suppresses the iteration log.

{phang}
{opt eform} displays exponentiated coefficients. Appropriate for log OR,
log RR, log IRR, or log HR measures.

{phang}
{opt digits(#)} specifies the number of decimal places in the display.
Default is 4. I-squared is always displayed with 1 decimal place.


{marker examples}{...}
{title:Examples}

{pstd}Default REML estimation{p_end}
{phang2}{cmd:. nma_fit}{p_end}

{pstd}Common effect model{p_end}
{phang2}{cmd:. nma_fit, common}{p_end}

{pstd}ML with exponentiated results{p_end}
{phang2}{cmd:. nma_fit, method(ml) eform}{p_end}

{pstd}Post-estimation{p_end}
{phang2}{cmd:. nma_fit, nolog}{p_end}
{phang2}{cmd:. lincom Drug_A - Drug_B}{p_end}
{phang2}{cmd:. test Drug_A = Drug_B}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:nma_fit} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(tau2)}}estimated between-study variance{p_end}
{synopt:{cmd:e(I2)}}I-squared statistic: 100*tau2/(tau2+median(SE^2)){p_end}
{synopt:{cmd:e(ll)}}log-likelihood{p_end}
{synopt:{cmd:e(converged)}}1 if converged, 0 otherwise{p_end}
{synopt:{cmd:e(k)}}number of treatments{p_end}
{synopt:{cmd:e(n_studies)}}number of studies{p_end}
{synopt:{cmd:e(n_comparisons)}}number of comparisons{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:nma_fit}{p_end}
{synopt:{cmd:e(method)}}estimation method{p_end}
{synopt:{cmd:e(measure)}}effect measure{p_end}
{synopt:{cmd:e(ref)}}reference treatment{p_end}
{synopt:{cmd:e(treatments)}}space-separated treatment list{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector{p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}
{synopt:{cmd:e(Sigma)}}between-study variance matrix{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
