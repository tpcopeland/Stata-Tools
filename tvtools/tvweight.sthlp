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
{synopt:{opt ipcw(varname)}}interval censoring indicator{p_end}
{synopt:{opt censorc:ovariates(varlist)}}censoring-model covariates{p_end}
{synopt:{opt censg:enerate(name)}}cumulative censoring weight name{p_end}
{synopt:{opt combg:enerate(name)}}name for the combined weight (default: {it:weight}{cmd:_ipcw}){p_end}

{syntab:Model Options}
{synopt:{opt model(string)}}model type: {cmd:logit} (binary) or {cmd:mlogit} (categorical){p_end}
{synopt:{opt tvc:ovariates(varlist)}}time-varying covariates{p_end}
{synopt:{opt id(varname)}}person identifier for time-varying models{p_end}
{synopt:{opt time(varname)}}time variable for time-varying models{p_end}
{synopt:{opt est:name(name)}}store the propensity model under this name{p_end}
{synopt:{opt estrep:lace}}replace an existing {opt estname()} target{p_end}

{syntab:Diagnostics}
{synopt:{opt bal:ance}}report standardized mean differences{p_end}
{synopt:{opt love:plot}}draw SMD love plot via {helpb psdash}{p_end}
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
3. Optionally stabilizes weights by multiplying by marginal treatment
probability

{phang2}
4. Optionally truncates extreme weights at specified percentiles

{phang2}
5. Provides diagnostic output including weight distribution and effective
sample size

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
score model. These should be confounders that predict both treatment and
outcome. Stata factor-variable notation, including interactions such as
{cmd:i.sex##c.age}, is allowed.

{dlgtab:Weight Options}

{phang}
{opt generate(name)} specifies the name for the generated weight variable. The
default is {cmd:iptw}.

{phang}
{opt wtype(type)} selects the weight estimand. {cmd:iptw} (the default) gives inverse
probability of treatment weights. {cmd:ato} gives overlap (ATO) weights, which
target the population with the most overlap and are robust to extreme
propensity scores; with a logistic propensity model they balance covariate
means exactly. {cmd:matching} gives matching weights, which mimic a 1:1 matched
sample. {cmd:ato} and {cmd:matching} are alternatives to {opt truncate()} under poor
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
{opt ipcw(varname)} supplies a per-interval censoring indicator (1 if the person is
censored at the end of this interval, 0 if they remain under observation) and
turns on inverse-probability-of-censoring weighting. A pooled logistic
censoring model is fit; the cumulative censoring weight is the inverse
cumulative probability of remaining uncensored, and a combined weight equal to
the cumulative IPTW times the cumulative IPCW is produced. This completes the
canonical marginal structural model, which weights for both confounded
treatment and informative censoring (Hernan & Robins). Requires {opt id()} and
{opt time()}. With {opt stabilized}, both weights use stabilized numerators. With
{opt truncate()}, truncation is applied to the final combined weight.

{pmore}
The stabilized IPCW numerator is the {bf:marginal} (constant) probability of
remaining uncensored -- the same stabilization form used for the treatment
weight -- not a time-varying numerator model of censoring. Readers expecting the
fully stabilized Robins-Hernan censoring weights (a numerator model conditional
on the past-treatment and baseline history) should note that {cmd:tvweight}
stabilizes the censoring weight in form only.

{pmore}
The censoring model uses its raw fitted P(uncensored|history). Probabilities are
reported but never silently capped. A zero, one, or missing probability makes
IPCW undefined and stops with error 498; {opt truncate()} acts on the final
combined weight only when explicitly requested.

{phang}
{opt censorcovariates(varlist)} lists the covariates for the censoring
model. Defaults to the treatment-model covariates ({opt covariates()} plus any
{opt tvcovariates()}). Factor-variable notation is allowed.

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
propensity score model. Factor-variable notation is allowed. Requires
{opt id()} and {opt time()} options.

{phang}
{opt id(varname)} specifies the person identifier variable. When specified
with {opt time()}, enables panel-aware weighting: time fixed effects
({cmd:i.}{it:time}) are included in the propensity score model and
cluster-robust standard errors are computed by {it:id}. History-dependent
modes ({opt cumulative}, {opt tvcovariates()}, and {opt ipcw()}) require
{opt id()} and {opt time()} to identify estimation-sample rows uniquely; duplicate
keys stop with error 459 before outputs are retained.

{phang}
{opt time(varname)} specifies the time variable. When specified with {opt id()}, time
fixed effects are added to the propensity score model. This is the standard
approach for marginal structural models with time-varying treatments.

{phang}
{opt estname(name)} stores the fitted propensity model under {it:name} via
{helpb estimates store}, so it can be inspected, replayed, or used by
{helpb margins} downstream. Without this option the model is discarded after
the weights are computed. {cmd:tvweight} restores whatever estimation results
were active on entry, whether or not {opt estname()} is specified.

{phang}
{opt estreplace} permits {opt estname()} to replace an existing stored estimate. Without
{opt estreplace}, an existing name causes error 110. Replacement is
transactional: if weight construction later fails, the prior stored estimate
is restored. {opt estreplace} requires {opt estname()}.

{dlgtab:Diagnostics}

{phang}
{opt balance} reports the standardized mean difference (SMD) of each covariate
between exposure groups, both before and after weighting, and returns them in
{cmd:r(balance)}. SMD is the standard balance check for weighted analyses
(Austin 2009, 2011). The denominator is the unweighted pooled standard
deviation, so the before and after columns share a common scale. For
categorical exposures the maximum absolute SMD across non-reference levels is
reported per covariate. Factor variables and interactions are expanded into
their estimable nonbase columns; {cmd:r(balance_terms)} maps those columns to
the rows of {cmd:r(balance)}.

{phang}
{opt loveplot} produces a love plot of the SMDs (unweighted vs
weighted). Covariate-balance plotting is delegated to the dedicated
propensity-score
dashboard package {helpb psdash}: tvweight calls {cmd:psdash balance} with the
exposure, the generated weight variable and the balance covariates. Requires
{opt balance}. If {cmd:psdash} is not installed, tvweight prints installation
guidance instead of drawing a plot; you can also build the figure yourself from
the returned {cmd:r(balance)} matrix. Install psdash with
{stata `"net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace"'}.

{phang}
{opt histogram} draws a histogram of the weight distribution. The plot honors
the active graph scheme. Graph outcomes are reported by
{cmd:r(histogram_created)}, {cmd:r(loveplot_created)}, and
{cmd:r(graph_created)}.

{dlgtab:Output Options}

{phang}
{opt denominator(name)} creates an additional variable containing the
fitted propensity score. For binary logit this is P(A=1|X); for multinomial
logit it is P(A=a|X), where a is the observed treatment level.

{phang}
{opt replace} allows overwriting of existing weight variables.

{phang}
{opt nolog} suppresses the iteration log from the propensity score model.


{marker examples}{...}
{title:Examples}

{pstd}
Create a reproducible four-period panel with treatment, censoring, and outcome
variables:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 240713}{p_end}
{phang2}{cmd:. set obs 400}{p_end}
{phang2}{cmd:. generate long id = ceil(_n / 4)}{p_end}
{phang2}{cmd:. bysort id: generate int period = _n - 1}{p_end}
{phang2}{cmd:. generate double age = 45 + mod(id, 30)}{p_end}
{phang2}{cmd:. generate byte female = mod(id, 2)}{p_end}
{phang2}{cmd:. generate double comorbidity = rnormal()}{p_end}
{phang2}{cmd:. generate double p_treat = invlogit(-1 + .02*age + .4*female + .3*comorbidity)}{p_end}
{phang2}{cmd:. generate byte treated = runiform() < p_treat}{p_end}
{phang2}{cmd:. generate double rx_start = mdy(1, 1, 2020) + 91*period}{p_end}
{phang2}{cmd:. generate double rx_stop = rx_start + 90}{p_end}
{phang2}{cmd:. by id: generate byte will_censor = runiform() < .25 if _n == 1}{p_end}
{phang2}{cmd:. by id: replace will_censor = will_censor[1]}{p_end}
{phang2}{cmd:. by id: generate byte censor_period = floor(4*runiform()) if _n == 1}{p_end}
{phang2}{cmd:. by id: replace censor_period = censor_period[1]}{p_end}
{phang2}{cmd:. generate byte censored = will_censor & period == censor_period}{p_end}
{phang2}{cmd:. drop if will_censor & period > censor_period}{p_end}
{phang2}{cmd:. bysort id (period): generate byte event = _n == _N & !censored & runiform() < .25}{p_end}
{phang2}{cmd:. format rx_start rx_stop %td}{p_end}

{pstd}{bf:Stabilized IPTW and balance diagnostics}{p_end}
{phang2}{cmd:. tvweight treated, covariates(age female comorbidity) ///}{p_end}
{phang3}{cmd:stabilized generate(iptw) balance nolog}{p_end}
{phang2}{cmd:. matrix list r(balance)}{p_end}

{pstd}
Add {opt loveplot} only after installing the optional {bf:psdash} package. The
weight and {cmd:r(balance)} matrix are still produced when it is absent.

{pstd}{bf:Panel-aware cumulative MSM weights}{p_end}
{phang2}{cmd:. tvweight treated, covariates(age female comorbidity) ///}{p_end}
{phang3}{cmd:id(id) time(period) stabilized cumulative ///}{p_end}
{phang3}{cmd:generate(iptw_period) cumgenerate(iptw_cum) nolog}{p_end}

{pstd}{bf:IPTW times IPCW}{p_end}
{phang2}{cmd:. tvweight treated, covariates(age female comorbidity) ///}{p_end}
{phang3}{cmd:id(id) time(period) stabilized cumulative ipcw(censored) ///}{p_end}
{phang3}{cmd:censorcovariates(age female comorbidity) generate(iptw_period) ///}{p_end}
{phang3}{cmd:cumgenerate(iptw_cum) censgenerate(ipcw_cum) ///}{p_end}
{phang3}{cmd:combgenerate(msm_weight) truncate(1 99) replace nolog}{p_end}

{pstd}{bf:Calendar-quarter index and weighted survival model}{p_end}
{phang2}{cmd:. generate int calendar_qtr = qofd(rx_start)}{p_end}
{phang2}{cmd:. format calendar_qtr %tq}{p_end}
{phang2}{cmd:. generate double analysis_t0 = rx_start - 1}{p_end}
{phang2}{cmd:. stset rx_stop [pweight=msm_weight], failure(event) time0(analysis_t0)}{p_end}
{phang2}{cmd:. stcox treated, vce(cluster id)}{p_end}

{pstd}
The interval-specific weight is declared in {cmd:stset}. Omit {cmd:id()} there
because Stata requires a survival-declaration weight to be constant within a
declared ID; retain person-level dependence through {cmd:vce(cluster id)} in
the model.

{pstd}
Use {cmd:qofd(rx_start)}, not {cmd:quarter(rx_start)}: the former retains the
calendar year, whereas the latter repeats values 1--4 every year. An
entry-anchored integer {opt period()} from {helpb tvpanel} is preferable for a
fixed-width MSM grid.

{pstd}{bf:Overlap weights}{p_end}
{phang2}{cmd:. tvweight treated, covariates(age female comorbidity) ///}{p_end}
{phang3}{cmd:wtype(ato) generate(ato_weight) replace nolog}{p_end}

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
{synopt:{cmd:r(n_top1_rows)}}number of rows used for the top-1% statistic{p_end}
{synopt:{cmd:r(n_ps_extreme)}}rows with P(observed treatment) < .001 or > .999{p_end}
{synopt:{cmd:r(n_ps_boundary)}}rows with a zero, one, or missing fitted probability{p_end}
{synopt:{cmd:r(n_cens_extreme)}}rows with P(uncensored) < .001 or > .999{p_end}
{synopt:{cmd:r(n_cens_boundary)}}rows with a zero, one, or missing uncensoring probability{p_end}
{synopt:{cmd:r(histogram_created)}}1 if the requested histogram was created; 0 otherwise{p_end}
{synopt:{cmd:r(loveplot_created)}}1 if the requested love plot was created; 0 otherwise{p_end}
{synopt:{cmd:r(graph_created)}}1 if either optional graph was created; 0 otherwise{p_end}
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
{synopt:{cmd:r(balance_terms)}}factor-expanded terms indexing {cmd:r(balance)} (if balance){p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}unweighted/weighted SMD matrix{p_end}
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
All components of either multinomial weight use the same raw vector of fitted
class probabilities. {cmd:tvweight} reports probabilities below .001 or above
.999 but does not cap or otherwise modify them. The {opt truncate()} option,
when requested, acts explicitly on weights rather than silently changing fitted
probabilities. Exact boundary probabilities make weights undefined and stop
with error 498.

{pstd}
The same raw-probability contract applies to the pooled censoring model used by
{opt ipcw()}: missing predictions (including rows excluded by perfect
prediction) and exact boundary probabilities stop with error 498. Extreme but
finite probabilities are reported and retained; explicit {opt truncate()}
changes only the final combined weight.

{pstd}
{bf:Positivity and concentration diagnostics}

{pstd}
The top-1% diagnostic ranks the final analysis weight (the combined IPTW-IPCW
weight when {opt ipcw()} is used) and sums exactly ceil(.01*N) rows. Descending
weight and original observation order define the deterministic ranking, so a
percentile tie cannot sweep extra rows into the statistic.

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

{pstd}
{bf:Causal interpretation}

{pstd}
Causal interpretation of these weights requires consistency, conditional
exchangeability (no unmeasured confounding), positivity for every treatment
history of interest, and correctly specified treatment models. Analyses using
{opt ipcw()} additionally require conditional independent censoring and a
correctly specified censoring model. Balance, overlap, extreme-probability,
weight-concentration, and effective-sample-size diagnostics assess consequences
of the fitted models; they do not prove these identifying assumptions.


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
weighting. Journal of the American Statistical
Association. 2018;113(521):390-400.

{pstd}
Li L, Greene T. A weighting analogue to pair matching in propensity score
analysis. International Journal of Biostatistics. 2013;9(2):215-234.


{marker alsosee}{...}
{title:Also see}

{psee}
{help tvexpose}, {help tvdiagnose}
{p_end}

{hline}
