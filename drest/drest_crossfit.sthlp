{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_crossfit##syntax"}{...}
{viewerjumpto "Description" "drest_crossfit##description"}{...}
{viewerjumpto "Options" "drest_crossfit##options"}{...}
{viewerjumpto "Remarks" "drest_crossfit##remarks"}{...}
{viewerjumpto "Examples" "drest_crossfit##examples"}{...}
{viewerjumpto "Stored results" "drest_crossfit##results"}{...}
{viewerjumpto "Author" "drest_crossfit##author"}{...}
{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:drest_crossfit} {hline 2}}Cross-fitted AIPW estimation (DML-style){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_crossfit}
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
{synopt:{opt treat:ment(varname)}}binary treatment indicator (0/1){p_end}

{syntab:Model specification}
{synopt:{opt omod:el(varlist)}}covariates for outcome model{p_end}
{synopt:{opt of:amily(string)}}outcome model family: {cmd:regress}, {cmd:logit}, {cmd:probit}, {cmd:poisson}{p_end}
{synopt:{opt tmod:el(varlist)}}covariates for treatment model{p_end}
{synopt:{opt tf:amily(string)}}treatment model family: {cmd:logit}, {cmd:probit}{p_end}

{syntab:Cross-fitting}
{synopt:{opt fold:s(#)}}number of folds; default is {cmd:5}{p_end}
{synopt:{opt seed(#)}}random number seed for fold assignment{p_end}

{syntab:Estimation}
{synopt:{opt est:imand(string)}}estimand: {cmd:ATE} (default), {cmd:ATT}, {cmd:ATC}{p_end}
{synopt:{opt trimps(numlist)}}propensity score trimming bounds; default is {cmd:0.01 0.99}{p_end}
{synopt:{opt l:evel(#)}}confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt nolog}}suppress progress messages{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_crossfit} implements cross-fitted (sample-split) AIPW estimation,
also known as the DML (double/debiased machine learning) approach. For each
of K folds, nuisance models are trained on out-of-fold data and used to
predict on the held-out fold. This avoids the Donsker conditions required by
standard AIPW and is essential when nuisance models are flexible or
high-dimensional.

{pstd}
On well-specified parametric models, cross-fitted and standard AIPW give
similar results. The key advantage of cross-fitting appears with flexible
models or many covariates, where overfitting in the nuisance step could bias
the treatment effect estimate.


{marker options}{...}
{title:Options}

{phang}
{opt folds(#)} specifies the number of cross-validation folds.
Default is 5. Higher values reduce bias from sample splitting at the
cost of increased computation. 5 or 10 folds are standard choices.

{phang}
{opt seed(#)} sets the random number seed for reproducible fold assignment.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to use cross-fitting}

{pstd}
Use {cmd:drest_crossfit} instead of {cmd:drest_estimate} when:

{phang2}1. You have many covariates relative to sample size{p_end}
{phang2}2. You suspect the parametric models may overfit{p_end}
{phang2}3. You want results that are robust to flexible model specifications{p_end}

{pstd}
{bf:Generated variables}

{pstd}
Same as {cmd:drest_estimate} ({cmd:_drest_ps}, {cmd:_drest_mu1},
{cmd:_drest_mu0}, {cmd:_drest_if}, {cmd:_drest_esample}), plus
{cmd:_drest_fold} indicating the fold assignment.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_crossfit x1 x2 x3, outcome(y) treatment(treat) folds(5) seed(12345)}{p_end}

{phang2}{cmd:. drest_crossfit, outcome(y) treatment(treat) omodel(x1 x2 x3) tmodel(x1 x2) folds(10)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:drest_crossfit} stores the same results as {cmd:drest_estimate}, plus:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(folds)}}number of cross-validation folds{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:drest_crossfit}{p_end}
{synopt:{cmd:e(method)}}{cmd:aipw_crossfit}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
