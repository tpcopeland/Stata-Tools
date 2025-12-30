{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{vieweralsosee "tvweight" "help tvweight"}{...}
{viewerjumpto "Syntax" "tvestimate##syntax"}{...}
{viewerjumpto "Description" "tvestimate##description"}{...}
{viewerjumpto "Options" "tvestimate##options"}{...}
{viewerjumpto "Examples" "tvestimate##examples"}{...}
{viewerjumpto "Stored results" "tvestimate##results"}{...}
{viewerjumpto "Methods" "tvestimate##methods"}{...}
{viewerjumpto "Author" "tvestimate##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:tvestimate} {hline 2}}G-estimation for structural nested models{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvestimate}
{depvar} {it:treatment}
{ifin}{cmd:,}
{opt conf:ounders(varlist)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt conf:ounders(varlist)}}confounding variables for propensity score{p_end}

{syntab:Model}
{synopt:{opt model(string)}}model type: {bf:snmm} (default) or snftm{p_end}

{syntab:SE/Inference}
{synopt:{opt rob:ust}}robust (sandwich) standard errors{p_end}
{synopt:{opt cl:uster(varname)}}compute clustered standard errors{p_end}
{synopt:{opt boot:strap}}use bootstrap standard errors{p_end}
{synopt:{opt reps(#)}}bootstrap replications; default is 200{p_end}
{synopt:{opt seed(#)}}random seed for bootstrap{p_end}
{synopt:{opt level(#)}}confidence level; default is {bf:95}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvestimate} implements G-estimation for structural nested mean models (SNMM)
to estimate causal effects of treatments in the presence of confounding.

{pstd}
G-estimation is a semiparametric method that:

{phang2}1. Models the treatment mechanism (propensity score){p_end}
{phang2}2. Uses the estimated propensity score to identify the causal effect{p_end}
{phang2}3. Does not require correct specification of the outcome model{p_end}

{pstd}
The method is particularly useful for time-varying treatments where traditional
regression adjustment may be biased by time-varying confounding affected by
prior treatment.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt confounders(varlist)} specifies the confounding variables to include in
the propensity score model. These should be variables that predict both
treatment and outcome.

{dlgtab:Model}

{phang}
{opt model(string)} specifies the type of structural nested model.

{phang2}{opt snmm} specifies a structural nested mean model for continuous
outcomes (default).{p_end}

{phang2}{opt snftm} specifies a structural nested failure time model for
survival outcomes (not yet implemented).{p_end}

{dlgtab:SE/Inference}

{phang}
{opt robust} requests heteroskedasticity-robust standard errors using
the sandwich variance estimator.

{phang}
{opt cluster(varname)} requests clustered standard errors, clustering
on {it:varname}. This is recommended when individuals contribute multiple
observations (e.g., in panel or time-varying exposure data).

{phang}
{opt bootstrap} requests bootstrap standard errors instead of analytical
standard errors. Bootstrap provides more robust inference when the
analytical standard errors may be unreliable.

{phang}
{opt reps(#)} specifies the number of bootstrap replications. The default
is 200. More replications provide more stable standard errors but take
longer to compute.

{phang}
{opt seed(#)} sets the random seed for reproducible bootstrap results.

{phang}
{opt level(#)} specifies the confidence level for confidence intervals.
The default is 95.


{marker examples}{...}
{title:Examples}

{pstd}Setup: Create example data{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. set obs 1000}{p_end}
{phang2}{cmd:. gen age = 50 + rnormal(0, 10)}{p_end}
{phang2}{cmd:. gen sex = runiform() > 0.5}{p_end}
{phang2}{cmd:. gen confounder = rnormal()}{p_end}
{phang2}{cmd:. gen pr_treat = invlogit(-1 + 0.02*age + 0.5*sex + 0.3*confounder)}{p_end}
{phang2}{cmd:. gen treatment = runiform() < pr_treat}{p_end}
{phang2}{cmd:. gen outcome = 50 + 2*treatment + 0.5*age + 1*sex + 2*confounder + rnormal(0, 5)}{p_end}

{pstd}Basic G-estimation{p_end}
{phang2}{cmd:. tvestimate outcome treatment, confounders(age sex confounder)}{p_end}

{pstd}With robust standard errors{p_end}
{phang2}{cmd:. tvestimate outcome treatment, confounders(age sex confounder) robust}{p_end}

{pstd}With bootstrap standard errors{p_end}
{phang2}{cmd:. tvestimate outcome treatment, confounders(age sex confounder) bootstrap reps(500)}{p_end}

{pstd}With time-varying data and clustering{p_end}
{phang2}{cmd:. * After tvexpose creates time-varying dataset}{p_end}
{phang2}{cmd:. tvestimate outcome tv_exposure, confounders(age sex) cluster(id)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvestimate} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(psi)}}causal effect estimate{p_end}
{synopt:{cmd:e(se_psi)}}standard error of causal effect{p_end}
{synopt:{cmd:e(z)}}z statistic{p_end}
{synopt:{cmd:e(p)}}p-value{p_end}
{synopt:{cmd:e(ci_lo)}}lower confidence limit{p_end}
{synopt:{cmd:e(ci_hi)}}upper confidence limit{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}
{synopt:{cmd:e(ps_mean)}}mean propensity score{p_end}
{synopt:{cmd:e(ps_min)}}minimum propensity score{p_end}
{synopt:{cmd:e(ps_max)}}maximum propensity score{p_end}
{synopt:{cmd:e(mean_y0)}}mean potential outcome under no treatment{p_end}
{synopt:{cmd:e(reps)}}bootstrap replications (if bootstrap){p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:tvestimate}{p_end}
{synopt:{cmd:e(cmdline)}}command as typed{p_end}
{synopt:{cmd:e(depvar)}}outcome variable name{p_end}
{synopt:{cmd:e(treatment)}}treatment variable name{p_end}
{synopt:{cmd:e(confounders)}}confounder variable names{p_end}
{synopt:{cmd:e(model)}}model type (snmm or snftm){p_end}
{synopt:{cmd:e(vcetype)}}variance type (Model, Robust, Clustered, Bootstrap){p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector{p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}marks estimation sample{p_end}


{marker methods}{...}
{title:Methods and formulas}

{pstd}
{cmd:tvestimate} implements G-estimation for structural nested mean models.

{pstd}
{bf:Structural Nested Mean Model (SNMM)}

{pstd}
For binary treatment A and continuous outcome Y, the SNMM assumes:

{p 8 8 2}
E[Y(0) | L] = E[Y | L] - psi * A

{pstd}
where Y(0) is the potential outcome under no treatment, L are confounders,
and psi is the causal effect of treatment.

{pstd}
{bf:G-estimation}

{pstd}
Under the assumption of no unmeasured confounding (Y(0) independent of A | L),
the causal effect psi can be identified by finding the value that makes
the "blipped-down" outcome Y - psi*A independent of treatment given confounders.

{pstd}
The estimating equation is:

{p 8 8 2}
sum_i[ (Y_i - psi*A_i) * (A_i - e(L_i)) ] = 0

{pstd}
where e(L) = P(A=1 | L) is the propensity score. The closed-form solution is:

{p 8 8 2}
psi_hat = sum_i[Y_i * (A_i - e_hat(L_i))] / sum_i[A_i * (A_i - e_hat(L_i))]

{pstd}
{bf:Standard Errors}

{pstd}
Standard errors are computed via the influence function, which accounts for
estimation of the propensity score:

{p 8 8 2}
IF_i = (Y_i - psi*A_i) * (A_i - e_hat(L_i)) / E[A*(A-e(L))]

{pstd}
For clustered data, the influence functions are summed within clusters before
computing the variance.

{pstd}
Bootstrap standard errors provide an alternative that may be more robust
to model misspecification.

{pstd}
{bf:References}

{phang}
Robins JM. (1994). Correcting for non-compliance in randomized trials using
structural nested mean models. Communications in Statistics - Theory and
Methods. 23(8):2379-2412.

{phang}
Vansteelandt S, Joffe M. (2014). Structural nested models and G-estimation:
The partially realized promise. Statistical Science. 29(4):707-731.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden

{pstd}
Part of the {bf:tvtools} package for time-varying exposure analysis.
