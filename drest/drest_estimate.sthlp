{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "[TE] teffects aipw" "help teffects aipw"}{...}
{vieweralsosee "drest" "help drest"}{...}
{viewerjumpto "Syntax" "drest_estimate##syntax"}{...}
{viewerjumpto "Description" "drest_estimate##description"}{...}
{viewerjumpto "Options" "drest_estimate##options"}{...}
{viewerjumpto "Remarks" "drest_estimate##remarks"}{...}
{viewerjumpto "Examples" "drest_estimate##examples"}{...}
{viewerjumpto "Stored results" "drest_estimate##results"}{...}
{viewerjumpto "Author" "drest_estimate##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:drest_estimate} {hline 2}}AIPW doubly robust estimation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_estimate}
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

{syntab:Estimation}
{synopt:{opt est:imand(string)}}estimand: {cmd:ATE} (default), {cmd:ATT}, {cmd:ATC}{p_end}
{synopt:{opt trimps(numlist)}}propensity score trimming bounds; default is {cmd:0.01 0.99}{p_end}
{synopt:{opt l:evel(#)}}confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt nolog}}suppress progress messages{p_end}
{synoptline}

{pstd}
When {it:varlist} is specified without {opt omodel()} or {opt tmodel()},
the same covariates are used for both models.


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_estimate} fits an augmented inverse probability weighted (AIPW)
estimator for causal treatment effects. It combines a treatment model
(propensity score) with an outcome model to achieve the doubly robust
property: the estimator is consistent if {it:either} model is correctly
specified.

{pstd}
The procedure:

{phang2}1. Fits a treatment model (logit/probit) to estimate propensity scores

{phang2}2. Trims propensity scores at specified bounds to avoid instability

{phang2}3. Fits outcome models separately within each treatment arm

{phang2}4. Computes the AIPW pseudo-outcome combining both model predictions

{phang2}5. Estimates the treatment effect as the mean pseudo-outcome

{phang2}6. Computes influence-function-based standard errors

{pstd}
Results are stored as {cmd:eclass} and can be used with standard
post-estimation commands. Generated variables ({cmd:_drest_ps},
{cmd:_drest_mu1}, {cmd:_drest_mu0}, {cmd:_drest_if}) persist for
downstream diagnostics.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt outcome(varname)} specifies the outcome variable. For binary outcomes,
the outcome model defaults to logit. For continuous outcomes, it defaults
to linear regression.

{phang}
{opt treatment(varname)} specifies the binary (0/1) treatment indicator.

{dlgtab:Model specification}

{phang}
{opt omodel(varlist)} specifies covariates for the outcome model. If omitted,
uses {it:varlist} from the command line.

{phang}
{opt ofamily(string)} specifies the outcome model family. Options are
{cmd:regress} (default for continuous), {cmd:logit} (default for binary),
{cmd:probit}, and {cmd:poisson}.

{phang}
{opt tmodel(varlist)} specifies covariates for the treatment model. If omitted,
uses {it:varlist} from the command line.

{phang}
{opt tfamily(string)} specifies the treatment model family. Options are
{cmd:logit} (default) and {cmd:probit}.

{dlgtab:Estimation}

{phang}
{opt estimand(string)} specifies the causal estimand. {cmd:ATE} (average
treatment effect, default), {cmd:ATT} (average treatment effect on the
treated), or {cmd:ATC} (average treatment effect on the control).

{phang}
{opt trimps(numlist)} specifies propensity score trimming bounds. The
default {cmd:0.01 0.99} trims extreme propensity scores to prevent
numerical instability. Specify {cmd:trimps(0)} to disable trimming.

{phang}
{opt level(#)} specifies the confidence level for confidence intervals;
default is {cmd:level(95)}.

{phang}
{opt nolog} suppresses the progress messages during fitting.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Double robustness}

{pstd}
The AIPW estimator is consistent if either the outcome model or the
treatment model is correctly specified. This provides insurance against
model misspecification that purely outcome-based (g-computation) or
purely weighting-based (IPTW) approaches lack.

{pstd}
{bf:Generated variables}

{pstd}
The command creates the following variables (overwriting any existing):

{p2colset 9 28 30 2}{...}
{p2col:{cmd:_drest_ps}}estimated propensity score{p_end}
{p2col:{cmd:_drest_mu1}}predicted outcome under treatment{p_end}
{p2col:{cmd:_drest_mu0}}predicted outcome under control{p_end}
{p2col:{cmd:_drest_if}}influence function values{p_end}
{p2col:{cmd:_drest_esample}}estimation sample indicator{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic usage with shared covariates}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}

{pstd}
{bf:Example 2: Separate model specifications}

{phang2}{cmd:. drest_estimate, outcome(price) treatment(foreign) omodel(weight length mpg) tmodel(weight length)}{p_end}

{pstd}
{bf:Example 3: ATT with probit treatment model}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign) estimand(ATT) tfamily(probit)}{p_end}

{pstd}
{bf:Example 4: No PS trimming}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign) trimps(0)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:drest_estimate} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}
{synopt:{cmd:e(N_treated)}}number of treated observations{p_end}
{synopt:{cmd:e(N_control)}}number of control observations{p_end}
{synopt:{cmd:e(tau)}}treatment effect estimate{p_end}
{synopt:{cmd:e(se)}}standard error{p_end}
{synopt:{cmd:e(z)}}z-statistic{p_end}
{synopt:{cmd:e(p)}}p-value{p_end}
{synopt:{cmd:e(ci_lo)}}lower confidence interval bound{p_end}
{synopt:{cmd:e(ci_hi)}}upper confidence interval bound{p_end}
{synopt:{cmd:e(po1)}}potential outcome mean under treatment{p_end}
{synopt:{cmd:e(po0)}}potential outcome mean under control{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}
{synopt:{cmd:e(n_trimmed)}}number of trimmed propensity scores{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:drest_estimate}{p_end}
{synopt:{cmd:e(method)}}{cmd:aipw}{p_end}
{synopt:{cmd:e(outcome)}}outcome variable name{p_end}
{synopt:{cmd:e(treatment)}}treatment variable name{p_end}
{synopt:{cmd:e(omodel)}}outcome model covariates{p_end}
{synopt:{cmd:e(ofamily)}}outcome model family{p_end}
{synopt:{cmd:e(tmodel)}}treatment model covariates{p_end}
{synopt:{cmd:e(tfamily)}}treatment model family{p_end}
{synopt:{cmd:e(estimand)}}estimand (ATE/ATT/ATC){p_end}
{synopt:{cmd:e(trimps)}}trimming bounds{p_end}
{synopt:{cmd:e(depvar)}}outcome variable name{p_end}
{synopt:{cmd:e(title)}}title string{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector{p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}

{p2col 5 20 24 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}estimation sample{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb drest}, {helpb drest_diagnose}, {helpb drest_compare},
{helpb teffects aipw}

{hline}
