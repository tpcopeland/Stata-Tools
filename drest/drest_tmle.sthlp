{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{vieweralsosee "drest_crossfit" "help drest_crossfit"}{...}
{viewerjumpto "Syntax" "drest_tmle##syntax"}{...}
{viewerjumpto "Description" "drest_tmle##description"}{...}
{viewerjumpto "Options" "drest_tmle##options"}{...}
{viewerjumpto "Remarks" "drest_tmle##remarks"}{...}
{viewerjumpto "Examples" "drest_tmle##examples"}{...}
{viewerjumpto "Stored results" "drest_tmle##results"}{...}
{viewerjumpto "References" "drest_tmle##references"}{...}
{viewerjumpto "Author" "drest_tmle##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:drest_tmle} {hline 2}}Targeted Minimum Loss-Based Estimation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_tmle}
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

{syntab:TMLE targeting}
{synopt:{opt iter:ate(#)}}maximum targeting iterations; default is {cmd:100}{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance for epsilon; default is {cmd:1e-5}{p_end}

{syntab:Cross-fitting}
{synopt:{opt cross:fit}}enable K-fold cross-fitting{p_end}
{synopt:{opt fold:s(#)}}number of folds; default is {cmd:5}{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}

{syntab:Estimation}
{synopt:{opt est:imand(string)}}currently {cmd:ATE} only{p_end}
{synopt:{opt trimps(numlist)}}propensity score trimming bounds{p_end}
{synopt:{opt l:evel(#)}}confidence level{p_end}
{synopt:{opt nolog}}suppress progress messages{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_tmle} implements Targeted Minimum Loss-Based Estimation, a doubly
robust substitution estimator. Unlike AIPW (which is an estimating-equation
approach), TMLE updates the initial outcome model estimates through a
targeting step that solves the efficient influence function equation. This
ensures predictions respect model constraints (e.g., probabilities stay in
[0,1] for binary outcomes).

{pstd}
For binary outcomes, TMLE uses a logistic fluctuation submodel with the
clever covariate. For continuous outcomes, it uses a linear fluctuation.
Both achieve the same asymptotic efficiency as AIPW.


{marker options}{...}
{title:Options}

{phang}
{opt iterate(#)} specifies the maximum number of targeting iterations.
For binary outcomes, the fluctuation step iterates until the epsilon
coefficient is below the tolerance. For continuous outcomes, a single
step suffices.

{phang}
{opt tolerance(#)} specifies the convergence criterion for the targeting
step. Default is 1e-5.

{phang}
{opt crossfit} enables K-fold cross-fitting for the initial nuisance
model estimation, combining sample splitting with TMLE targeting.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:TMLE vs AIPW}

{pstd}
On correctly specified parametric models, TMLE and AIPW produce nearly
identical results. The key differences:

{phang2}1. TMLE respects the model bounds (predictions stay in [0,1] for binary Y){p_end}
{phang2}2. TMLE is a substitution estimator (uses updated predictions directly){p_end}
{phang2}3. TMLE can be more stable with near-positivity violations{p_end}

{pstd}
{bf:When to prefer TMLE}

{phang2}- Binary outcomes where AIPW predictions may extrapolate outside [0,1]{p_end}
{phang2}- When you want a plug-in estimator that directly uses model predictions{p_end}
{phang2}- Combined with cross-fitting ({opt crossfit} option) for maximum robustness{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Standard TMLE}

{phang2}{cmd:. drest_tmle x1 x2, outcome(y) treatment(treat)}{p_end}

{pstd}
{bf:Cross-fitted TMLE}

{phang2}{cmd:. drest_tmle x1 x2, outcome(y) treatment(treat) crossfit folds(5) seed(42)}{p_end}

{pstd}
{bf:Binary outcome with custom tolerance}

{phang2}{cmd:. drest_tmle x1 x2, outcome(y_bin) treatment(treat) tolerance(1e-6) iterate(200)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:drest_tmle} stores the same results as {cmd:drest_estimate}, plus:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(converged)}}1 if targeting converged, 0 otherwise{p_end}
{synopt:{cmd:e(n_iter)}}number of targeting iterations{p_end}
{synopt:{cmd:e(epsilon)}}final fluctuation coefficient{p_end}
{synopt:{cmd:e(folds)}}number of folds (if crossfit){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:drest_tmle}{p_end}
{synopt:{cmd:e(method)}}{cmd:tmle} or {cmd:tmle_crossfit}{p_end}


{marker references}{...}
{title:References}

{pstd}
van der Laan MJ, Rose S. {it:Targeted Learning: Causal Inference for}
{it:Observational and Experimental Data}. Springer, 2011.

{pstd}
Schuler MS, Rose S. Targeted maximum likelihood estimation for causal
inference in observational studies. {it:American Journal of Epidemiology}.
2017;185(1):65-73.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
