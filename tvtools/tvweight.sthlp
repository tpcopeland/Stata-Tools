{smcl}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{viewerjumpto "Syntax" "tvweight##syntax"}{...}
{viewerjumpto "Description" "tvweight##description"}{...}
{viewerjumpto "Options" "tvweight##options"}{...}
{viewerjumpto "Examples" "tvweight##examples"}{...}
{viewerjumpto "Stored results" "tvweight##results"}{...}
{viewerjumpto "Methods" "tvweight##methods"}{...}
{viewerjumpto "Author" "tvweight##author"}{...}
{viewerjumpto "References" "tvweight##references"}{...}
{viewerjumpto "Also see" "tvweight##alsosee"}{...}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:tvweight} {hline 2}}Calculate inverse probability of treatment weights (IPTW) for time-varying exposures{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvweight}
{it:exposure}
{ifin}
{cmd:,} {opt cov:ariates(varlist)}
[{it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{it:exposure}}binary or categorical exposure variable{p_end}
{synopt:{opt cov:ariates(varlist)}}covariates for propensity score model{p_end}

{syntab:Weight Options}
{synopt:{opt gen:erate(name)}}name for weight variable; default is {cmd:iptw}{p_end}
{synopt:{opt wt:ype(type)}}weight type: {cmd:iptw} (default), {cmd:ato}, or {cmd:matching}{p_end}
{synopt:{opt stab:ilized}}calculate stabilized weights ({cmd:iptw} only){p_end}
{synopt:{opt trunc:ate(# #)}}truncate at lower and upper percentiles{p_end}
{synopt:{opt cum:ulative}}within-person cumulative product weight (MSM){p_end}
{synopt:{opt cumg:enerate(name)}}name for the cumulative weight variable{p_end}

{syntab:Censoring weights (IPCW)}
{synopt:{opt ipcw(varname)}}censoring indicator (1=censored at end of interval); adds IPCW and the combined IPTW{c -(}IPCW weight{p_end}
{synopt:{opt censorc:ovariates(varlist)}}covariates for the censoring model (default: treatment-model covariates){p_end}
{synopt:{opt censg:enerate(name)}}name for the cumulative censoring weight (default: {cmd:ipcw}){p_end}
{synopt:{opt combg:enerate(name)}}name for the combined weight (default: {it:weight}{cmd:_ipcw}){p_end}

{syntab:Model Options}
{synopt:{opt model(string)}}model type: {cmd:logit} (binary) or {cmd:mlogit} (categorical){p_end}
{synopt:{opt tvc:ovariates(varlist)}}time-varying covariates{p_end}
{synopt:{opt id(varname)}}person identifier for time-varying models{p_end}
{synopt:{opt time(varname)}}time variable for time-varying models{p_end}
{synopt:{opt est:name(name)}}store the propensity model under this name{p_end}

{syntab:Diagnostics}
{synopt:{opt bal:ance}}report standardized mean differences before/after weighting{p_end}
{synopt:{opt love:plot}}love plot of SMDs, delegated to {helpb psdash} (requires {opt balance}){p_end}
{synopt:{opt hist:ogram}}histogram of the weight distribution{p_end}

{syntab:Output Options}
{synopt:{opt den:ominator(name)}}also generate propensity score variable{p_end}
{synopt:{opt replace}}replace existing weight variable{p_end}
{synopt:{opt nolog}}suppress model iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvweight} calculates inverse probability of treatment weights (IPTW) for
causal inference with time-varying exposures. IPTW creates a pseudo-population
where confounders are balanced between treatment groups, enabling estimation
of causal effects from observational data.

{pstd}
The command:

{phang2}
1. Fits a propensity score model (logistic or multinomial)

{phang2}
2. Calculates IPTW weights: 1/P(A=a|X) where A is treatment and X are covariates

{phang2}
3. Optionally stabilizes weights by multiplying by marginal treatment probability

{phang2}
4. Optionally truncates extreme weights at specified percentiles

{phang2}
5. Provides diagnostic output including weight distribution and effective sample size

{pstd}
{cmd:tvweight} is designed to work with time-varying exposure datasets created by
{help tvexpose}, where each row represents a person-period with a specific exposure
status.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{it:exposure} specifies the exposure variable. For binary exposures, the lower
value is treated as the reference (unexposed) group. For categorical exposures
with more than 2 levels, multinomial logistic regression is used automatically.

{phang}
{opt covariates(varlist)} specifies the covariates to include in the propensity
score model. These should be confounders that predict both treatment and outcome.

{dlgtab:Weight Options}

{phang}
{opt generate(name)} specifies the name for the generated weight variable.
The default is {cmd:iptw}.

{phang}
{opt wtype(type)} selects the weight estimand. {cmd:iptw} (the default) gives
inverse probability of treatment weights. {cmd:ato} gives overlap (ATO) weights,
which target the population with the most overlap and are robust to extreme
propensity scores; with a logistic propensity model they balance covariate means
exactly. {cmd:matching} gives matching weights, which mimic a 1:1 matched sample.
{cmd:ato} and {cmd:matching} are alternatives to {opt truncate()} under poor
overlap. {opt stabilized} applies only to {cmd:iptw}.

{phang}
{opt stabilized} requests stabilized weights. Stabilized weights multiply
the standard IPTW by the marginal probability of treatment:

{p 12 12 2}
SW = P(A=a) / P(A=a|X)

{pmore}
Stabilized weights have mean closer to 1 and generally smaller variance than
unstabilized weights, leading to more efficient estimates.

{phang}
{opt truncate(# #)} truncates weights at the specified lower and upper
percentiles. For example, {cmd:truncate(1 99)} truncates at the 1st and 99th
percentiles. Both percentiles must be strictly between 0 and 100. Truncation
reduces the influence of extreme weights but may introduce some bias.

{phang}
{opt cumulative} additionally generates a within-person cumulative product of
the per-row weights, ordered by {opt time()}. Requires {opt id()} and
{opt time()}. The per-row weight {cmd:tvweight} computes is {it:not} itself a
time-varying marginal structural model (MSM) weight: a genuine MSM with
time-varying confounding requires the cumulative product of period-specific
weights within person, which {opt cumulative} provides. See
{it:Methods and formulas}. For the full fixed-width MSM panel workflow, see
{help tvpanel} feeding the {bf:msm} package.

{phang}
{opt cumgenerate(name)} names the cumulative weight variable. Requires
{opt cumulative}. The default name is the weight name with a {cmd:_cum} suffix
(for example {cmd:iptw_cum}).

{dlgtab:Censoring weights (IPCW)}

{phang}
{opt ipcw(varname)} supplies a per-interval censoring indicator (1 if the person
is censored at the end of this interval, 0 if they remain under observation) and
turns on inverse-probability-of-censoring weighting. A pooled logistic censoring
model is fit; the cumulative censoring weight is the inverse cumulative
probability of remaining uncensored, and a combined weight equal to the
cumulative IPTW times the cumulative IPCW is produced. This completes the
canonical marginal structural model, which weights for both confounded treatment
and informative censoring (Hernan & Robins). Requires {opt id()} and {opt time()}.
With {opt stabilized}, both weights use stabilized numerators. With
{opt truncate()}, truncation is applied to the final combined weight.

{phang}
{opt censorcovariates(varlist)} lists the covariates for the censoring model.
Defaults to the treatment-model covariates ({opt covariates()} plus any
{opt tvcovariates()}).

{phang}
{opt censgenerate(name)} names the cumulative censoring weight variable
(default: {cmd:ipcw}).

{phang}
{opt combgenerate(name)} names the combined IPTW{c -(}IPCW weight variable
(default: the treatment-weight name with an {cmd:_ipcw} suffix).

{dlgtab:Model Options}

{phang}
{opt model(string)} specifies the propensity score model type. Options are:

{p 12 12 2}
{cmd:logit} - Binary logistic regression (default for binary exposures)

{p 12 12 2}
{cmd:mlogit} - Multinomial logistic regression (automatic for >2 levels)

{phang}
{opt tvcovariates(varlist)} specifies time-varying covariates for the
propensity score model. Requires {opt id()} and {opt time()} options.

{phang}
{opt id(varname)} specifies the person identifier variable. When specified
with {opt time()}, enables panel-aware weighting: time fixed effects
({cmd:i.}{it:time}) are included in the propensity score model and
cluster-robust standard errors are computed by {it:id}.

{phang}
{opt time(varname)} specifies the time variable. When specified with
{opt id()}, time fixed effects are added to the propensity score model.
This is the standard approach for marginal structural models with
time-varying treatments.

{phang}
{opt estname(name)} stores the fitted propensity model under {it:name} via
{helpb estimates store}, so it can be inspected, replayed, or used by
{helpb margins} downstream. Without this option the model is discarded after
the weights are computed.

{dlgtab:Diagnostics}

{phang}
{opt balance} reports the standardized mean difference (SMD) of each covariate
between exposure groups, both before and after weighting, and returns them in
{cmd:r(balance)}. SMD is the standard balance check for weighted analyses
(Austin 2009, 2011). The denominator is the unweighted pooled standard
deviation, so the before and after columns share a common scale. For
categorical exposures the maximum absolute SMD across non-reference levels is
reported per covariate.

{phang}
{opt loveplot} produces a love plot of the SMDs (unweighted vs weighted).
Covariate-balance plotting is delegated to the dedicated propensity-score
dashboard package {helpb psdash}: tvweight calls {cmd:psdash balance} with the
exposure, the generated weight variable and the balance covariates. Requires
{opt balance}. If {cmd:psdash} is not installed, tvweight prints installation
guidance instead of drawing a plot; you can also build the figure yourself from
the returned {cmd:r(balance)} matrix. Install psdash with
{stata `"net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace"'}.

{phang}
{opt histogram} draws a histogram of the weight distribution. The plot honors
the active graph scheme.

{dlgtab:Output Options}

{phang}
{opt denominator(name)} creates an additional variable containing the
propensity score (predicted probability of observed treatment given covariates).

{phang}
{opt replace} allows overwriting of existing weight variables.

{phang}
{opt nolog} suppresses the iteration log from the propensity score model.


{marker examples}{...}
{title:Examples}

{pstd}
The examples below assume you have created a time-varying dataset using
{helpb tvexpose} with baseline covariates carried through via {cmd:keepvars()}.

{pstd}
{bf:Setup}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}

{phang2}{cmd:. tvexpose using _data/tv_antidep_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(index_age female education)}{p_end}


{pstd}
{bf:Example 1: Basic IPTW for binary treatment}

{pstd}
Recode the multi-level antidepressant variable to binary (any vs none), then
estimate IPTW:

{phang2}{cmd:. gen byte treated = (tv_exposure > 0) if !missing(tv_exposure)}{p_end}
{phang2}{cmd:. tvweight treated, covariates(index_age female education)}{p_end}

{pstd}
Creates the variable {cmd:iptw} in the dataset. The output shows weight
distribution, percentiles, and effective sample size.


{pstd}
{bf:Example 2: Stabilized weights with truncation}

{pstd}
Stabilized weights have smaller variance. Truncation at the 1st and 99th
percentiles limits the influence of extreme weights:

{phang2}{cmd:. tvweight treated, covariates(index_age female education) ///}{p_end}
{phang3}{cmd:stabilized truncate(1 99) replace}{p_end}

{pstd}
The {cmd:replace} option overwrites the {cmd:iptw} variable from Example 1.


{pstd}
{bf:Example 3: Multinomial weights for categorical treatment}

{pstd}
When the exposure has 3+ levels (e.g., 0=unexposed, 1=SSRI, 2=SNRI),
{cmd:tvweight} automatically uses multinomial logistic regression:

{phang2}{cmd:. tvweight tv_exposure, covariates(index_age female education) ///}{p_end}
{phang3}{cmd:generate(mw) stabilized nolog}{p_end}

{pstd}
Each observation receives weight 1/P(A=a|X), where a is the observed
treatment level. The {cmd:nolog} option suppresses the iteration log.


{pstd}
{bf:Example 4: Propensity score output}

{pstd}
Save the propensity score alongside the weight for diagnostic plots:

{phang2}{cmd:. tvweight treated, covariates(index_age female education) ///}{p_end}
{phang3}{cmd:generate(sw) denominator(ps) stabilized replace}{p_end}


{pstd}
{bf:Example 5: Panel-aware weighting with time-varying covariates}

{pstd}
When panel structure is available, {cmd:id()} and {cmd:time()} enable
cluster-robust standard errors and time fixed effects in the propensity
score model:

{phang2}{cmd:. gen period = quarter(rx_start)}{p_end}
{phang2}{cmd:. tvweight treated, covariates(index_age female education) ///}{p_end}
{phang3}{cmd:id(id) time(period) generate(panel_w) replace nolog}{p_end}


{pstd}
{bf:Example 6: Weighted Cox regression}

{pstd}
After weighting, fit a marginal structural Cox model:

{phang2}{cmd:. stset rx_stop, failure(event==1) enter(rx_start) id(id)}{p_end}
{phang2}{cmd:. stcox treated [pw=iptw], robust cluster(id)}{p_end}

{pstd}
The {cmd:[pw=iptw]} applies the inverse probability weights. Cluster-robust
standard errors account for within-person correlation in the panel data.


{pstd}
{bf:Example 7: Balance diagnostics with a love plot}

{pstd}
Check covariate balance before and after weighting and draw a love plot:

{phang2}{cmd:. tvweight treated, covariates(index_age female education) ///}{p_end}
{phang3}{cmd:generate(w) balance loveplot replace}{p_end}

{pstd}
The standardized mean differences are printed and returned in {cmd:r(balance)}.


{pstd}
{bf:Example 8: Overlap (ATO) weights for poor overlap}

{pstd}
When propensity scores are extreme, overlap weights are a principled
alternative to truncation and balance covariate means exactly:

{phang2}{cmd:. tvweight treated, covariates(index_age female education) ///}{p_end}
{phang3}{cmd:generate(ato_w) wtype(ato) balance replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvweight} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_levels)}}number of exposure levels{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(ess_pct)}}effective sample size as percentage of N{p_end}
{synopt:{cmd:r(w_mean)}}mean of weights{p_end}
{synopt:{cmd:r(w_sd)}}standard deviation of weights{p_end}
{synopt:{cmd:r(w_min)}}minimum weight{p_end}
{synopt:{cmd:r(w_max)}}maximum weight{p_end}
{synopt:{cmd:r(w_p1)}}1st percentile of weights{p_end}
{synopt:{cmd:r(w_p5)}}5th percentile of weights{p_end}
{synopt:{cmd:r(w_p25)}}25th percentile of weights{p_end}
{synopt:{cmd:r(w_p50)}}50th percentile of weights (median){p_end}
{synopt:{cmd:r(w_p75)}}75th percentile of weights{p_end}
{synopt:{cmd:r(w_p95)}}95th percentile of weights{p_end}
{synopt:{cmd:r(w_p99)}}99th percentile of weights{p_end}
{synopt:{cmd:r(n_truncated)}}number of truncated observations (if truncate specified){p_end}
{synopt:{cmd:r(trunc_lo)}}lower truncation percentile (if truncate specified){p_end}
{synopt:{cmd:r(trunc_hi)}}upper truncation percentile (if truncate specified){p_end}
{synopt:{cmd:r(overlap_lo)}}minimum probability of the observed treatment{p_end}
{synopt:{cmd:r(overlap_hi)}}maximum probability of the observed treatment{p_end}
{synopt:{cmd:r(pct_nonoverlap)}}percentage of rows with P(observed treatment) < 0.05{p_end}
{synopt:{cmd:r(n_nonoverlap)}}number of rows with P(observed treatment) < 0.05{p_end}
{synopt:{cmd:r(top1_wt_share)}}percentage of total weight mass held by the top 1% of rows{p_end}
{synopt:{cmd:r(ess_combined)}}effective sample size of the combined weight (if ipcw){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(exposure)}}name of exposure variable{p_end}
{synopt:{cmd:r(covariates)}}covariates used in model{p_end}
{synopt:{cmd:r(model)}}model type (logit or mlogit){p_end}
{synopt:{cmd:r(wtype)}}weight type (iptw, ato, or matching){p_end}
{synopt:{cmd:r(generate)}}name of generated weight variable{p_end}
{synopt:{cmd:r(stabilized)}}stabilized if stabilized weights requested{p_end}
{synopt:{cmd:r(denominator)}}name of propensity score variable (if requested){p_end}
{synopt:{cmd:r(estname)}}name of stored propensity model (if estname specified){p_end}
{synopt:{cmd:r(cumgenerate)}}name of cumulative weight variable (if cumulative){p_end}
{synopt:{cmd:r(ipcw)}}name of the censoring indicator variable (if ipcw){p_end}
{synopt:{cmd:r(censgenerate)}}name of the cumulative censoring weight (if ipcw){p_end}
{synopt:{cmd:r(combgenerate)}}name of the combined IPTW{c -(}IPCW weight (if ipcw){p_end}
{synopt:{cmd:r(censorcovariates)}}covariates used in the censoring model (if ipcw){p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}covariate-by-{cmd:smd_unweighted}/{cmd:smd_weighted} SMD matrix (if balance){p_end}
{p2colreset}{...}


{marker methods}{...}
{title:Methods and formulas}

{pstd}
{bf:Inverse Probability of Treatment Weights (IPTW)}

{pstd}
For a binary treatment A with covariates X, the propensity score is:

{p 8 8 2}
e(X) = P(A=1|X)

{pstd}
estimated using logistic regression. The IPTW weights are:

{p 8 8 2}
W = A/e(X) + (1-A)/(1-e(X))

{pstd}
This assigns weight 1/e(X) to treated units and 1/(1-e(X)) to untreated units.

{pstd}
{bf:Stabilized Weights}

{pstd}
Stabilized weights multiply the standard weights by the marginal probability:

{p 8 8 2}
SW = A*P(A=1)/e(X) + (1-A)*P(A=0)/(1-e(X))

{pstd}
Stabilized weights have mean approximately 1 and smaller variance.

{pstd}
{bf:Effective Sample Size}

{pstd}
The effective sample size (ESS) measures the equivalent unweighted sample size:

{p 8 8 2}
ESS = (Sum of weights)^2 / Sum of squared weights

{pstd}
ESS near N indicates minimal information loss from weighting.

{pstd}
{bf:Multinomial Treatment}

{pstd}
For categorical treatments with K levels, multinomial logistic regression
estimates P(A=k|X) for each level k. The weight for an observation with
treatment level a is:

{p 8 8 2}
W = 1/P(A=a|X)

{pstd}
{bf:Overlap (ATO) and matching weights}

{pstd}
With {cmd:wtype(ato)} the binary overlap weight is the probability of the
opposite assignment:

{p 8 8 2}
W = A*(1-e(X)) + (1-A)*e(X)

{pstd}
Overlap weights target the population with the most overlap and, with a
logistic propensity model, yield exactly zero weighted standardized mean
differences (Li, Morgan & Zaslavsky 2018). With {cmd:wtype(matching)} the
matching weight is:

{p 8 8 2}
W = min(e(X), 1-e(X)) / [A*e(X) + (1-A)*(1-e(X))]

{pstd}
For categorical exposures the generalized forms are used: the overlap weight is
[1/{&Sigma}{sub:k}(1/P(A=k|X))]/P(A=a|X) and the matching weight is
min{sub:k}P(A=k|X)/P(A=a|X).

{pstd}
{bf:Per-row IPTW versus cumulative MSM weights}

{pstd}
The weight described above is a {it:per-row} (cross-sectional) IPTW. A genuine
marginal structural model for a time-varying treatment with time-varying
confounding requires the {it:cumulative product} of the period-specific weights
within each person, ordered by time:

{p 8 8 2}
W{sub:it} = {&prod}{sub:s<=t} weight at period s

{pstd}
The {opt cumulative} option computes this product (requires {opt id()} and
{opt time()}). For the full fixed-width MSM panel grid that feeds the {bf:msm}
package, see {help tvpanel}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{marker references}{...}
{title:References}

{pstd}
Robins JM, Hernan MA, Brumback B. Marginal structural models and causal
inference in epidemiology. Epidemiology. 2000;11(5):550-560.

{pstd}
Cole SR, Hernan MA. Constructing inverse probability weights for marginal
structural models. American Journal of Epidemiology. 2008;168(6):656-664.

{pstd}
Austin PC, Stuart EA. Moving towards best practice when using inverse
probability of treatment weighting (IPTW) using the propensity score to
estimate causal treatment effects in observational studies. Statistics in
Medicine. 2015;34(28):3661-3679.

{pstd}
Li F, Morgan KL, Zaslavsky AM. Balancing covariates via propensity score
weighting. Journal of the American Statistical Association.
2018;113(521):390-400.

{pstd}
Li L, Greene T. A weighting analogue to pair matching in propensity score
analysis. International Journal of Biostatistics. 2013;9(2):215-234.


{marker alsosee}{...}
{title:Also see}

{psee}
{help tvexpose}, {help tvdiagnose}
{p_end}

{hline}
