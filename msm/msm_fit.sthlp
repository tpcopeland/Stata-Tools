{smcl}
{* *! version 1.0.0  26apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{viewerjumpto "Syntax" "msm_fit##syntax"}{...}
{viewerjumpto "Description" "msm_fit##description"}{...}
{viewerjumpto "Choosing a model" "msm_fit##choosing"}{...}
{viewerjumpto "Options" "msm_fit##options"}{...}
{viewerjumpto "Stored results" "msm_fit##stored"}{...}
{viewerjumpto "Examples" "msm_fit##examples"}{...}
{viewerjumpto "Author" "msm_fit##author"}{...}

{title:Title}

{phang}
{bf:msm_fit} {hline 2} Weighted outcome model for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_fit}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt mod:el(string)}}model type: {cmd:logistic} (default), {cmd:linear}, or {cmd:cox}{p_end}
{synopt:{opt outcome_cov(varlist)}}additional time-fixed outcome covariates{p_end}
{synopt:{opt per:iod_spec(string)}}period functional form: {cmd:linear}, {cmd:quadratic} (default), {cmd:cubic}, {cmd:ns(#)}, or {cmd:none}{p_end}
{synopt:{opt cl:uster(varname)}}cluster variable for robust SE; default is the ID variable{p_end}
{synopt:{opt boot:strap(#)}}bootstrap replicates (not yet implemented){p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_fit} fits the weighted outcome model {hline 1} the final estimation
step that produces the causal effect estimate.  It takes the IP weights
created by {helpb msm_weight} and uses them to fit a model for the outcome as
a function of treatment, period, and optionally additional covariates.

{pstd}
The model is fitted on the {bf:at-risk estimation sample}: observations after
a prior outcome event or censoring event are automatically excluded.  Robust
sandwich standard errors clustered at the individual level are used by default,
which accounts for the within-person correlation from repeated measurements.

{pstd}
The command persists the fitted coefficient vector ({cmd:_msm_fit_b}) and
variance matrix ({cmd:_msm_fit_V}) as Stata matrices so that downstream
commands ({helpb msm_predict}, {helpb msm_report}, {helpb msm_table},
{helpb msm_sensitivity}) can access them even if an intervening estimation
command overwrites {cmd:e()}.

{pstd}
For Cox models, {cmd:msm_fit} uses an internal sandbox: any pre-existing
{cmd:stset} configuration is saved and restored after estimation, and
temporary survival-time variables are cleaned up.  Datasets that were not
previously {cmd:stset} remain un-{cmd:stset} after the command completes.

{pstd}
If the outcome model does not converge (logistic or Cox), {cmd:msm_fit}
refuses to mark the dataset as fitted and exits with an error.  This
prevents downstream commands from operating on unreliable estimates.


{marker choosing}{...}
{title:Choosing a model}

{pstd}
The choice of outcome model determines what follow-on commands are available:

{p2colset 5 25 27 2}{...}
{p2col:{cmd:model(logistic)}}Pooled logistic regression via GLM with binomial
family.  This is the most common MSM for binary outcomes in person-period data.
It approximates a discrete-time survival model when the outcome is rare within
each period.  This is the only model type that supports {helpb msm_predict}
for counterfactual standardization.{p_end}

{p2col:{cmd:model(linear)}}Weighted linear regression.  Use when the outcome is
continuous and the target estimand is a weighted mean difference.
{helpb msm_predict} is not available for linear models.{p_end}

{p2col:{cmd:model(cox)}}Weighted Cox proportional hazards.  Use when the target
estimand is a weighted hazard ratio.  Period terms are not added as covariates
because time is modeled through the survival-time outcome.
{helpb msm_predict} is not available for Cox models; use standard Stata
{cmd:stcox} postestimation instead.{p_end}

{pstd}
After fitting, run {cmd:msm, status} to confirm the current pipeline stage
and see which downstream commands are available.


{marker options}{...}
{title:Options}

{phang}
{opt mod:el(string)} specifies the outcome model type.  Default is
{cmd:logistic}.  See {help msm_fit##choosing:Choosing a model} above.

{phang}
{opth outcome_cov(varlist)} specifies additional covariates for the outcome
model beyond treatment and period.  These should be {bf:time-fixed} (constant
within person) if you plan to use {helpb msm_predict} afterward, because the
prediction routine holds them at their baseline values.  Common choices are
the same baseline covariates used in the weight numerator (e.g., age, sex).

{phang}
{opt per:iod_spec(string)} specifies the functional form for the period
variable in the outcome model.  Options are:

{phang3}{cmd:linear} {hline 2} period enters as a single linear term.{p_end}
{phang3}{cmd:quadratic} {hline 2} period enters as linear + squared terms
(the default).{p_end}
{phang3}{cmd:cubic} {hline 2} period enters as linear + squared + cubed
terms.{p_end}
{phang3}{cmd:ns(#)} {hline 2} natural splines with {it:#} degrees of freedom.
{p_end}
{phang3}{cmd:none} {hline 2} no period terms are included.{p_end}

{phang}
{opth cl:uster(varname)} specifies the clustering variable for robust sandwich
standard errors.  Default is the ID variable from {helpb msm_prepare}.

{phang}
{opt boot:strap(#)} is reserved for future bootstrap variance estimation.
Currently not implemented; the command exits with an error if a nonzero value
is specified.

{phang}
{opt level(#)} specifies the confidence level for reported intervals.
Default is 95.

{phang}
{opt nolog} suppresses the iteration log from the estimation command.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_fit} stores the standard results from {cmd:glm}, {cmd:regress}, or
{cmd:stcox} in {cmd:e()}, plus:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:e(msm_cmd)}}{cmd:"msm_fit"}{p_end}
{synopt:{cmd:e(msm_model)}}model type ({cmd:logistic}, {cmd:linear}, or {cmd:cox}){p_end}
{synopt:{cmd:e(msm_treatment)}}treatment variable name{p_end}
{synopt:{cmd:e(msm_period_spec)}}period specification used{p_end}

{p2col 5 25 29 2: Matrices}{p_end}
{synopt:{cmd:e(effects)}}1 x 4 matrix (estimate, ci_lower, ci_upper, pvalue) for treatment{p_end}

{pstd}
Additionally, {cmd:_msm_fit_b} and {cmd:_msm_fit_V} are saved as named Stata
matrices for downstream commands.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Pooled logistic MSM (default).}  The standard analysis for binary outcomes
in person-period data:{p_end}

{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. msm, status}{p_end}

{pstd}
{bf:Natural spline period specification.}  More flexible time trend:{p_end}

{phang2}{cmd:. msm_fit, model(logistic) period_spec(ns(3)) nolog}{p_end}

{pstd}
{bf:Cox proportional hazards MSM:}{p_end}

{phang2}{cmd:. msm_fit, model(cox) outcome_cov(age sex) nolog}{p_end}

{pstd}
{bf:Linear MSM for a continuous outcome:}{p_end}

{phang2}{cmd:. msm_fit, model(linear) outcome_cov(age sex)}{p_end}

{pstd}
{bf:Checking what comes next after fitting:}{p_end}

{phang2}{cmd:. msm, status}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}
