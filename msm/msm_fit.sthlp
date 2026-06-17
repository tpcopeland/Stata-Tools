{smcl}
{* *! version 1.2.0  17jun2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{viewerjumpto "Syntax" "msm_fit##syntax"}{...}
{viewerjumpto "Description" "msm_fit##description"}{...}
{viewerjumpto "Choosing a model" "msm_fit##choosing"}{...}
{viewerjumpto "Continuous and time-varying exposure" "msm_fit##continuous"}{...}
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
{synopt:{opt exp:osure(varname)}}continuous/time-varying exposure term that replaces the binary treatment in the outcome model{p_end}
{synopt:{opt tvc:ov(varlist)}}time-varying outcome covariates ({cmd:cox}/{cmd:logistic} only){p_end}
{synopt:{opt per:iod_spec(string)}}period functional form: {cmd:linear}, {cmd:quadratic} (default), {cmd:cubic}, {cmd:ns(#)}, or {cmd:none}{p_end}
{synopt:{opt cl:uster(varname)}}cluster variable for robust SE; default is the ID variable{p_end}
{synopt:{opt vce(string)}}standard-error estimator: {cmd:robust} or {cmd:cluster} {it:varname}{p_end}
{synopt:{opt str:ata(varlist)}}Cox-only baseline hazard strata{p_end}
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

{p2col:{cmd:model(linear)}}Weighted linear probability model for the prepared
binary outcome.  Use when an identity-scale risk difference is the target.
{helpb msm_predict} is not available for linear models.{p_end}

{p2col:{cmd:model(cox)}}Weighted Cox proportional hazards.  Use when the target
estimand is a weighted hazard ratio.  Period terms are not added as covariates
because time is modeled through the survival-time outcome.
{helpb msm_predict} is not available for Cox models; use {helpb msm_report},
{helpb msm_table}, or {helpb msm_sensitivity} for downstream output.  If you
need custom Stata survival postestimation, fit a direct {cmd:stcox} model on
an explicitly {cmd:stset} dataset using the same weights and covariates.{p_end}

{pstd}
After fitting, run {cmd:msm, status} to confirm the current pipeline stage
and see which downstream commands are available.


{marker continuous}{...}
{title:Continuous and time-varying exposure}

{pstd}
By default {cmd:msm_fit} estimates the effect of the mapped {bf:binary}
treatment.  Some studies instead target a {bf:dose-duration} estimand {hline 1}
the effect of an additional unit of a continuous, time-varying cumulative
exposure summary (for example, the hazard ratio per lagged cumulative
class-exposure-year).  Two backward-compatible options express this:

{phang2}{opt exp:osure(varname)} swaps the binary treatment term for a
continuous exposure variable, and{p_end}
{phang2}{opt tvc:ov(varlist)} adds time-varying companion covariates that are
not subject to the {opt outcome_cov()} time-fixed restriction.{p_end}

{pstd}
{bf:Methods contract.}  The IP weights from {helpb msm_weight} are built for the
{bf:binary} treatment process.  Using them for a continuous or time-varying
outcome term is valid {bf:only} when that term is a deterministic function of
the same treatment history the weights balance:

{phang2}o  An {opt exp:osure()} term is licensed when it summarizes that
treatment history {hline 1} cumulative duration, cumulative dose, or a lagged
cumulative exposure.{p_end}
{phang2}o  A {opt tvc:ov()} term is for time-varying companions that are
themselves functions of the treatment process (e.g., comparator-class
cumulative exposure), or for pre-baseline-fixed confounders re-expressed over
time {hline 1} {bf:not} for arbitrary time-varying confounders that should have
been handled in the weight model.{p_end}

{pstd}
Passing a term the weights do not justify yields a biased estimate that only
looks package-blessed.  Because there is no binary regime to standardize,
{helpb msm_predict} and counterfactual standardization are {bf:not defined} in
this mode and {cmd:msm_predict} will refuse; use {helpb msm_report},
{helpb msm_table}, or {helpb msm_sensitivity} for downstream output.  The
relaxation of the {opt outcome_cov()} time-fixed restriction is gated to
{cmd:model(cox)} and {cmd:model(logistic)} via {opt tvc:ov()}; the restriction
existed only to support {cmd:msm_predict} standardization, which is already
unavailable in this mode.


{marker options}{...}
{title:Options}

{phang}
{opt mod:el(string)} specifies the outcome model type.  Default is
{cmd:logistic}.  See {help msm_fit##choosing:Choosing a model} above.

{phang}
{opth outcome_cov(varlist)} specifies additional covariates for the outcome
model beyond treatment and period.  These must be {bf:time-fixed} (constant
within person).  {cmd:msm_fit} rejects variables that vary within the mapped
ID because downstream prediction standardizes them at baseline values.  Common
choices are the same baseline covariates used in the weight numerator (e.g.,
age, sex).  For time-varying companions, use {opt tvc:ov()} instead.

{phang}
{opth exp:osure(varname)} replaces the mapped binary treatment term in the
outcome model with an arbitrary, possibly {bf:continuous}, exposure variable.
When omitted (the default), the mapped binary treatment is used exactly as
before.  The reported coefficient/HR is then interpreted "per one unit of the
{opt exp:osure()} variable" rather than as the binary on-treatment contrast.
This is intended for dose-duration estimands such as a lagged cumulative
class-exposure summary.  See {help msm_fit##continuous:Continuous and
time-varying exposure} for the methods contract; {helpb msm_predict} is not
available when {opt exp:osure()} is specified.

{phang}
{opth tvc:ov(varlist)} specifies {bf:time-varying} outcome covariates that are
exempt from the {opt outcome_cov()} time-fixed restriction.  It is allowed only
with {cmd:model(cox)} or {cmd:model(logistic)}.  Use it for time-varying
companions of the exposure that are themselves functions of the treatment
process (e.g., a comparator-class cumulative exposure).  Variables in
{opt tvc:ov()} may not also appear in {opt outcome_cov()}, and may not be the
mapped treatment.  {helpb msm_predict} is not available when {opt tvc:ov()} is
specified.

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
standard errors.  Default is the ID variable from {helpb msm_prepare}.  This is
equivalent to {cmd:vce(cluster} {it:varname}{cmd:)} and is retained for
backward compatibility.

{phang}
{opt vce(string)} specifies the sandwich variance estimator.  Supported values
are {cmd:vce(robust)} and {cmd:vce(cluster} {it:varname}{cmd:)}.  If neither
{cmd:vce()} nor {cmd:cluster()} is specified, {cmd:msm_fit} uses
{cmd:vce(cluster} {it:idvar}{cmd:)}.  {cmd:cluster()} and {cmd:vce()} may not
be specified together.

{phang}
{opth str:ata(varlist)} specifies Cox baseline hazard strata and is allowed
only with {cmd:model(cox)}.  Strata variables are passed to {cmd:stcox}'s
{cmd:strata()} option and are not included as regression covariates.

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
{synopt:{cmd:e(msm_exposure)}}{opt exp:osure()} variable name, if specified{p_end}
{synopt:{cmd:e(msm_tvcov)}}{opt tvc:ov()} variables, if specified{p_end}
{synopt:{cmd:e(msm_period_spec)}}period specification used{p_end}
{synopt:{cmd:e(msm_vce)}}variance estimator ({cmd:robust} or {cmd:cluster}){p_end}
{synopt:{cmd:e(msm_cluster)}}cluster variable when clustered SEs are used{p_end}
{synopt:{cmd:e(msm_strata)}}Cox strata variables, if specified{p_end}

{p2col 5 25 29 2: Matrices}{p_end}
{synopt:{cmd:e(effects)}}1 x 4 matrix (estimate, ci_lower, ci_upper, pvalue) for the primary effect term (treatment, or the {opt exp:osure()} override){p_end}

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
{bf:Cox MSM with stratum-specific baseline hazards:}{p_end}

{phang2}{cmd:. msm_fit, model(cox) outcome_cov(age) strata(sex) vce(cluster id) nolog}{p_end}

{pstd}
{bf:Continuous cumulative-exposure Cox MSM (dose-duration estimand).}  The
hazard ratio per unit of a lagged cumulative class-exposure summary, with a
comparator-class cumulative exposure as a time-varying companion:{p_end}

{phang2}{cmd:. msm_fit, model(cox) exposure(cum_test_yrs) tvcov(cum_comp_yrs) outcome_cov(age) vce(cluster id) nolog}{p_end}

{pstd}
{cmd:msm_predict} is unavailable after this fit; use {helpb msm_report},
{helpb msm_table}, or {helpb msm_sensitivity}.  See
{help msm_fit##continuous:Continuous and time-varying exposure} for the methods
contract.

{pstd}
{bf:Linear probability MSM for an identity-scale risk difference:}{p_end}

{phang2}{cmd:. msm_fit, model(linear) outcome_cov(age sex)}{p_end}

{pstd}
{bf:Linear probability MSM with robust standard errors:}{p_end}

{phang2}{cmd:. msm_fit, model(linear) outcome_cov(age sex) vce(robust)}{p_end}

{pstd}
{bf:Checking what comes next after fitting:}{p_end}

{phang2}{cmd:. msm, status}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
