{smcl}
{* *! version 1.1.0  21jun2026}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "finegray_cif" "help finegray_cif"}{...}
{vieweralsosee "finegray_phtest" "help finegray_phtest"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "finegray##syntax"}{...}
{viewerjumpto "Description" "finegray##description"}{...}
{viewerjumpto "Options" "finegray##options"}{...}
{viewerjumpto "Remarks" "finegray##remarks"}{...}
{viewerjumpto "Examples" "finegray##examples"}{...}
{viewerjumpto "Stored results" "finegray##results"}{...}
{viewerjumpto "Author" "finegray##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:finegray} {hline 2}}Fine-Gray competing risks regression{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:finegray}
{varlist}
{ifin}{cmd:,}
{opt comp:ete(varname)}
{opt cau:se(#)}
[{it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth comp:ete(varname)}}event type variable (0=censored, 1, 2, ...){p_end}
{synopt:{opt cau:se(#)}}value of {it:compete()} for cause of interest{p_end}

{syntab:Model}
{synopt:{opt cens:value(#)}}censoring value in {it:compete()}; default is {cmd:0}{p_end}
{synopt:{opth str:ata(varlist)}}stratify censoring distribution by groups (numeric only){p_end}

{syntab:SE/Robust}
{synopt:{opth cl:uster(varname:numvar)}}adjust SEs for intragroup correlation (numeric only){p_end}
{synopt:{opt norob:ust}}report model-based SEs instead of default sandwich estimator{p_end}

{syntab:Reporting}
{synopt:{opt noshr}}report coefficients instead of subdistribution hazard ratios{p_end}
{synopt:{opt l:evel(#)}}set confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}

{syntab:Optimization}
{synopt:{opt iter:ate(#)}}maximum iterations; default is {cmd:iterate(200)}{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance; default is {cmd:tolerance(1e-8)}{p_end}
{synoptline}
{p 4 6 2}
{it:varlist} may contain factor variables and interactions; see
{help fvvarlist}. Supports {cmd:i.}{it:varname},
{cmd:ib}{it:#}{cmd:.}{it:varname}, {cmd:c.}{it:varname}, {cmd:#}, and {cmd:##}
operators.
{p_end}
{p 4 6 2}
Data must be {cmd:stset} with {cmd:id()}. A subject may contribute multiple
records when the model covariates are constant within {cmd:id()} (e.g. delayed
entry or {helpb stsplit} data); such records are reduced automatically to one
risk-set unit. Left-truncated (delayed entry) data are supported.
{p_end}

{pstd}
{bf:Post-estimation:}

{p 8 17 2}
{cmd:finegray_predict}
{newvar}
{ifin}{cmd:,}
[{opt xb} {opt cif} {opt sch:oenfeld} {opt time:var(varname)}]

{p 8 17 2}
{cmd:finegray_phtest}
[{cmd:,} {opt time(rank|log|identity)} {opt det:ail}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray} fits the Fine and Gray (1999) subdistribution hazard model for
competing risks data.

{pstd}
It estimates subdistribution hazard ratios (SHR) which quantify the effect of
covariates on the cumulative incidence of a cause of interest in the presence of
competing events.

{pstd}
The estimator uses a native O(np) forward-backward scan algorithm (Kawaguchi et
al. 2021) that avoids data expansion entirely, making it substantially faster
than {cmd:stcrreg} for large datasets.

{pstd}
See {it:Performance} under {help finegray##remarks:Remarks} for benchmarks.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth compete(varname)} specifies the variable containing event types. Typically
coded as 0 = censored, 1 = cause 1, 2 = cause 2, etc. Must be consistent with
the {cmd:stset} failure indicator.

{phang}
{opt cause(#)} specifies which value of {it:compete()} represents the cause of
interest.

{dlgtab:Model}

{phang}
{opt censvalue(#)} specifies the value in {it:compete()} that represents
censoring. Default is {cmd:0}.

{phang}
{opth strata(varlist)} stratifies the Kaplan-Meier censoring distribution
estimation by the specified variables. This is appropriate when the censoring
mechanism differs across groups (e.g., treatment arms or study sites).

{dlgtab:SE/Robust}

{phang}
{opth cluster(varname)} adjusts standard errors for intragroup correlation.

{phang}
{opt norobust} reports model-based standard errors from the observed information
matrix instead of the default Huber/White/sandwich estimator.

{pmore}
The sandwich estimator is the default because the Fine-Gray model uses a
pseudo-likelihood, making robust SEs appropriate regardless of model
specification.

{dlgtab:Reporting}

{phang}
{opt noshr} reports coefficients (log subdistribution hazard ratios) instead of
exponentiated coefficients (subdistribution hazard ratios).

{phang}
{opt level(#)} specifies the confidence level for confidence intervals. Default
is {cmd:level(95)}.

{phang}
{opt nolog} suppresses the iteration log.

{dlgtab:Optimization}

{phang}
{opt iterate(#)} specifies the maximum number of Newton-Raphson
iterations. Default is {cmd:iterate(200)}.

{phang}
{opt tolerance(#)} specifies the convergence tolerance. Default is
{cmd:tolerance(1e-8)}.


{marker remarks}{...}
{title:Remarks}

{pstd}
The Fine-Gray model directly models the subdistribution hazard, which is the
instantaneous rate of failure from the cause of interest among subjects who have
not yet experienced that specific cause.

{pstd}
Subjects who experience a competing event remain in the risk set indefinitely
with time-dependent weights derived from the Kaplan-Meier estimate of the
censoring distribution.

{pstd}
{bf:Factor variables and interactions:} {cmd:finegray} supports the full Stata
factor-variable syntax via {cmd:fvrevar}: {cmd:i.}{it:varname},
{cmd:ib}{it:#}{cmd:.}{it:varname}, {cmd:c.}{it:varname}, {cmd:#} (interaction),
and {cmd:##} (full factorial with main effects).

{pstd}
Indicator and interaction variables are automatically created with the prefix
{cmd:_fg_} (e.g., {cmd:_fg_race_2}, {cmd:_fg_race_2Xage} for an
{cmd:i.race#c.age} interaction). These persist in the dataset for use with
{cmd:finegray_predict}.

{pstd}
Re-running {cmd:finegray} drops only the finegray-created FV variables recorded
from the prior run; it does not wildcard-drop every {cmd:_fg_*} variable in the
dataset.

{pstd}
{bf:Note:} {cmd:finegray_predict} reconstructs factor-variable design columns on
demand via {cmd:fvrevar}. This requires that the current data preserve the same
factor-level support as the estimation sample.

{pstd}
If a factor level is dropped or absent, prediction will fail with an error. The
persistent {cmd:_fg_*} columns are retained for convenience but are not required
for prediction when the factor support is intact.

{pstd}
{bf:Interpretation:} A subdistribution hazard ratio (SHR) > 1 indicates that the
covariate increases the cumulative incidence of the cause of interest.

{pstd}
Unlike cause-specific hazard ratios, SHRs have a direct interpretation in terms
of the cumulative incidence function.

{pstd}
{bf:Left truncation (delayed entry):} {cmd:finegray} supports left-truncated
data where subjects enter observation after time 0.

{pstd}
Use {cmd:stset} with the {cmd:enter()} option to specify entry times. The
censoring distribution and risk sets are computed correctly for delayed entry.

{pstd}
{bf:Proportional hazards diagnostic:} Use {cmd:finegray_phtest} after estimation
for an approximate test of the proportional subdistribution hazards assumption
via scaled Schoenfeld residuals. See {helpb finegray_phtest} for details on the
diagonal-only scaling and independent per-variable test structure.

{pstd}
Both {cmd:finegray_phtest} and {cmd:finegray_predict, schoenfeld} require the
original {cmd:stset} estimation data ({cmd:_t}, {cmd:_d}, and
{cmd:e(sample)}); they cannot be run after loading a new
dataset. {cmd:finegray_predict, xb} and {cmd:finegray_predict, cif} work on any
dataset containing the model covariates.

{pmore}
{bf:Cumulative incidence curves:} Use {helpb finegray_cif} after estimation to
plot the predicted CIF with a pointwise confidence band, an analogue of
{cmd:stcurve, cif} that can also plot the interval.

{pmore}
{cmd:finegray_cif} also reports the CIF at fixed horizons such as 5 years and
exports the numeric estimates. For a confidence interval on each subject's CIF,
use {cmd:finegray_predict, cif ci}.

{pmore}
{bf:Multiple records per subject:} {cmd:finegray} accepts datasets in which a
subject contributes more than one in-sample record (delayed entry,
{cmd:(start,stop]} intervals, or data run through {helpb stsplit}) as long as
the model covariates are constant within {cmd:id()}.

{pmore}
Such records are reduced automatically to one risk-set unit per subject
(earliest entry, latest exit, final status), and the engine's left-truncation
handles the entry times.

{pmore}
Genuinely time-varying covariates are not supported and produce an error,
because the subdistribution hazard is not defined with internal time-varying
covariates (see {helpb stcox} for a cause-specific model with time-varying
covariates).

{pstd}
{bf:Margins:} {cmd:margins} is supported after {cmd:finegray} for the linear
predictor ({cmd:predict(xb)}) in models without factor-variable expansion.

{pstd}
For factor-variable models, {cmd:margins} is not supported because the
estimation uses generated design columns rather than native Stata factor
notation.

{pstd}
{bf:Cross-validation against other implementations:} {cmd:finegray} is
systematically validated against three independent implementations: Stata's
{cmd:stcrreg}, R's {cmd:cmprsk::crr}, and R's {cmd:fastcmprsk::fastCrr}.

{pstd}
The cross-validation suite (68 tests) covers coefficients, standard errors,
log-likelihoods, cumulative incidence functions, baseline hazards, stratified
censoring, and post-estimation predictions (xb, CIF, and Schoenfeld residuals)
across real and simulated datasets.

{pstd}
Point estimates (coefficients) and log pseudo-likelihoods are numerically
identical across all four implementations.

{pstd}
Against {cmd:cmprsk::crr}, coefficients match to 6 decimal places, robust SEs
match to 3 decimal places, model-based SEs match to 6 decimal places, and CIF
predictions match to 6 decimal places.

{pstd}
Against {cmd:fastcmprsk::fastCrr}, coefficients and log-likelihoods match to 6
decimal places, and the baseline cumulative hazard matches to 8 decimal places.

{pstd}
Against {cmd:stcrreg}, coefficients match within 1e-4 across all tested
configurations including multiple covariate combinations, both causes, factor
variables, cluster SEs, and left-truncated data.

{pstd}
The {opt strata()} option is cross-validated against
{cmd:crr(..., cengroup=)}; coefficients agree within 0.002 and SEs within 0.3%,
reflecting minor differences in how the stratified censoring KM is computed
internally.

{pstd}
{bf:Technical note on standard errors:} The only quantity where implementations
diverge is standard errors, and this reflects differences in variance estimation
approach rather than errors.

{pstd}
{cmd:finegray} (default) and {cmd:cmprsk::crr} both compute IPCW sandwich SEs on
the original (unexpanded) data, producing agreement to 3+ decimal places.

{pstd}
{cmd:stcrreg} computes sandwich SEs on an expanded dataset; both are valid
sandwich estimators but the different computational path produces ~0.5% relative
SE differences.

{pstd}
{cmd:finegray} with {opt norobust} and {cmd:crr$invinf} both report the inverse
observed information matrix, matching to 6 decimal places.

{pstd}
{cmd:fastcmprsk::fastCrr} uses bootstrap SEs (B=200), a fundamentally different
variance estimator; wider divergence (up to ~50%) is expected.

{pstd}
The observed-information SEs reported under {opt norobust} are not a
like-for-like replacement for {cmd:stcrreg}'s reported (sandwich) SEs.

{pstd}
{bf:Post-estimation predictions vs {help stcrreg}:} The {helpb finegray_predict}
outputs are cross-validated against {cmd:stcrreg}'s native predictions and agree
to numerical precision.

{pstd}
{opt xb} equals {cmd:stcrreg}'s {cmd:predict, xb}; the baseline CIF (covariates
at 0) equals {cmd:predict, basecif}; and {cmd:e(basehaz)} equals {cmd:stcrreg}'s
cumulative-subhazard analogue (H0(t) = -ln(1 - {cmd:basecif})) at each distinct
event time.

{pstd}
The per-observation {opt cif} is the covariate-adjusted CIF 1 -
exp(-H0(t)*exp(z'beta)).

{pstd}
{cmd:stcrreg} produces this quantity through {cmd:stcurve, cif at()} rather than
{cmd:predict} (its {cmd:predict} offers only the baseline {cmd:basecif} and the
relative subhazard), and {cmd:finegray_predict, cif} reproduces it to numerical
precision.

{pstd}
{opt schoenfeld} residuals match {cmd:stcrreg}'s {cmd:predict, schoenfeld}
exactly at untied cause-event times.

{pstd}
At a {bf:tied} cause-event time the two implementations partition the residual
among the simultaneous events differently, so an individual residual at a tied
time can differ; the {bf:sum} of the residuals within each event time -- and
hence the overall score -- is identical.

{pstd}
See {helpb finegray_predict} for the per-prediction detail.

{pstd}
{bf:Performance:} The forward-backward scan algorithm is O(np) per
Newton-Raphson iteration, compared to O(nDp) for {cmd:stcrreg}, where D is the
number of unique event times. Benchmarks on simulated competing risks data (3
covariates, Stata/MP):

{col 10}{bf:N}{col 24}{bf:finegray}{col 40}{bf:stcrreg}{col 56}{bf:Speedup}
{col 10}{hline 52}
{col 10}500{col 24}0.04s{col 40}1.5s{col 56}40x
{col 10}1,000{col 24}0.06s{col 40}3.9s{col 56}63x
{col 10}2,000{col 24}0.14s{col 40}15.9s{col 56}114x
{col 10}5,000{col 24}0.27s{col 40}96.8s{col 56}357x
{col 10}10,000{col 24}0.58s{col 40}378.7s{col 56}651x

{pstd}
The speedup grows with sample size because {cmd:stcrreg} expands the dataset by
the number of unique event times.

{pstd}
At registry scale (N=50,000+), {cmd:finegray} completes in under 10 seconds with
3 covariates; {cmd:stcrreg} is not feasible at these sizes.

{pstd}
{bf:Limitations:} The {cmd:by:} prefix is not supported because {cmd:finegray}
requires {cmd:stset} with {cmd:id()}, which is incompatible with
{cmd:by:} processing.

{pstd}
To fit models on subgroups, use {cmd:if} conditions. Sampling weights
({cmd:fweight}, {cmd:pweight}) are not supported.

{pstd}
{bf:References}

{pstd}
Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a
competing risk. {it:JASA} 1999; 94(446): 496-509.

{pstd}
Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable algorithms for large competing
risks data. {it:Journal of Computational and Graphical Statistics}
2021; 30(3): 685-693.

{pstd}
Grambsch PM, Therneau TM. Proportional hazards tests and diagnostics based on
weighted residuals. {it:Biometrika} 1994; 81(3): 515-526.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup}

{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}

{pstd}
{bf:Basic model}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}

{pstd}
{bf:Stratified censoring distribution}

{phang2}{cmd:. finegray ifp tumsize, compete(status) cause(1) strata(pelnode)}{p_end}

{pstd}
{bf:Model-based standard errors (default is robust/sandwich)}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1) norobust}{p_end}

{pstd}
{bf:Log-SHR (no exponentiation)}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1) noshr}{p_end}

{pstd}
{bf:CIF prediction}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}
{phang2}{cmd:. finegray_predict cif_hat, cif}{p_end}

{pstd}
{bf:Factor variables (automatic indicator expansion)}

{phang2}{cmd:. finegray i.pelnode ifp, compete(status) cause(1)}{p_end}

{pstd}
{bf:Factor variables with specified base category}

{phang2}{cmd:. finegray ib1.pelnode ifp, compete(status) cause(1)}{p_end}

{pstd}
{bf:Interaction: factor x continuous (full factorial)}

{phang2}{cmd:. finegray i.pelnode##c.ifp tumsize, compete(status) cause(1)}{p_end}

{pstd}
{bf:Interaction: factor x factor}

{phang2}{cmd:. gen byte ifp_grp = (ifp > 10)}{p_end}
{phang2}{cmd:. finegray i.pelnode##i.ifp_grp tumsize, compete(status) cause(1)}{p_end}

{pstd}
{bf:Margins (adjusted predictions)}

{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}
{phang2}{cmd:. margins, at(ifp=(0 5 10)) predict(xb)}{p_end}
{phang2}{cmd:. margins, dydx(ifp) predict(xb)}{p_end}

{pstd}
{bf:Compare with stcrreg} (requires different stset)

{phang2}{cmd:. stset dftime, failure(status==1) id(stnum)}{p_end}
{phang2}{cmd:. stcrreg ifp tumsize pelnode, compete(status == 2)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of subjects{p_end}
{synopt:{cmd:e(N_fail)}}number of cause-of-interest events{p_end}
{synopt:{cmd:e(N_compete)}}number of competing events{p_end}
{synopt:{cmd:e(N_cens)}}number of censored observations{p_end}
{synopt:{cmd:e(ll)}}log pseudo-likelihood{p_end}
{synopt:{cmd:e(ll_0)}}log pseudo-likelihood, constant-only model{p_end}
{synopt:{cmd:e(chi2)}}Wald chi-squared{p_end}
{synopt:{cmd:e(p)}}p-value for model chi-squared{p_end}
{synopt:{cmd:e(df_m)}}model degrees of freedom{p_end}
{synopt:{cmd:e(converged)}}1 if converged, 0 otherwise{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}
{synopt:{cmd:e(cause)}}cause of interest value{p_end}
{synopt:{cmd:e(censvalue)}}censoring value{p_end}
{synopt:{cmd:e(iterate)}}maximum iterations{p_end}
{synopt:{cmd:e(tolerance)}}convergence tolerance{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:finegray}{p_end}
{synopt:{cmd:e(cmdline)}}full estimation command as typed{p_end}
{synopt:{cmd:e(predict)}}{cmd:finegray_predict}{p_end}
{synopt:{cmd:e(depvar)}}competing events variable name{p_end}
{synopt:{cmd:e(compete)}}competing events variable name{p_end}
{synopt:{cmd:e(covariates)}}covariate variable names{p_end}
{synopt:{cmd:e(fvvarlist)}}original factor-variable specification; if factor variables used{p_end}
{synopt:{cmd:e(strata)}}censoring stratification variables; if {cmd:strata()} specified{p_end}
{synopt:{cmd:e(clustvar)}}cluster variable; if {cmd:cluster()} specified{p_end}
{synopt:{cmd:e(vce)}}variance estimation method{p_end}
{synopt:{cmd:e(title)}}Fine-Gray competing risks regression{p_end}
{synopt:{cmd:e(marginsok)}}{cmd:xb} (empty for factor-variable models){p_end}
{synopt:{cmd:e(properties)}}b V{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector (log-SHR){p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}
{synopt:{cmd:e(basehaz)}}baseline cumulative subdistribution hazard (time, cumhazard){p_end}

{pstd}
{cmd:e(basehaz)} holds the baseline cumulative subdistribution hazard H0(t) as a
right-continuous step function: column {it:time} lists the distinct
cause-of-interest event times and column {it:cumhazard} the corresponding H0(t).

{pstd}
The baseline CIF (the analogue of {cmd:stcrreg}'s {cmd:basecif}) is 1 -
exp(-{it:cumhazard}); an individual's CIF rescales the hazard by
exp(z'beta). {helpb finegray_predict} uses this matrix to compute the {cmd:cif}
prediction.

{pstd}
{cmd:finegray} also records dataset characteristics
{cmd:_dta[_finegray_estimated]}, {cmd:_dta[_finegray_compete]},
{cmd:_dta[_finegray_cause]}, and {cmd:_dta[_finegray_covars]}.

{pstd}
When factor variables are used it also records {cmd:_dta[_finegray_fvvars]} and
{cmd:_dta[_finegray_fvvarlist]}. These persist with the dataset and allow
subsequent {cmd:finegray} runs to clean up prior finegray-generated
factor-variable columns safely.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-06-21{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:Also see}

{psee}
Online: {helpb finegray_predict}, {helpb finegray_cif}, {helpb finegray_phtest},
{helpb stcrreg}, {helpb stcox}, {helpb stset}

{hline}
