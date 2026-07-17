{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_prepare" "help msm_prepare"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_validate" "help msm_validate"}{...}
{viewerjumpto "Syntax" "msm_weight##syntax"}{...}
{viewerjumpto "Description" "msm_weight##description"}{...}
{viewerjumpto "How the weights are built" "msm_weight##mechanics"}{...}
{viewerjumpto "Options" "msm_weight##options"}{...}
{viewerjumpto "Interpreting the output" "msm_weight##interpreting"}{...}
{viewerjumpto "Examples" "msm_weight##examples"}{...}
{viewerjumpto "Stored results" "msm_weight##results"}{...}
{viewerjumpto "Author" "msm_weight##author"}{...}

{title:Title}

{phang}
{bf:msm_weight} {hline 2} Inverse probability of treatment weights for MSM


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_weight}
[{cmd:,}
{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Treatment weight models}
{synopt:{opt treat_d_cov(varlist)}}covariates for the treatment denominator model{p_end}
{synopt:{opt treat_n_cov(varlist)}}treatment numerator covariates{p_end}

{syntab:Censoring weight models}
{synopt:{opt cen:sor_d_cov(varlist)}}covariates for the censoring denominator model{p_end}
{synopt:{opt cen:sor_n_cov(varlist)}}covariates for the censoring numerator model{p_end}

{syntab:Weight processing}
{synopt:{opt tru:ncate(numlist)}}truncation percentiles (e.g., {cmd:1} or {cmd:1 99}){p_end}

{syntab:Model behavior}
{synopt:{opt fitfailure(policy)}}failure policy; default is {cmd:error}{p_end}
{synopt:{opt probpolicy(policy)}}probability-support policy; default is {cmd:error}{p_end}
{synopt:{opt clip(#)}}probability bound required with {cmd:probpolicy(clip)}{p_end}
{synopt:{opt preview}}display resolved model specs without fitting{p_end}
{synopt:{opt replace}}replace existing weight variables{p_end}
{synopt:{opt nolog}}suppress logistic model iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_weight} is the core of the MSM package. It calculates the inverse
probability weights that create a pseudo-population where treatment is
independent of measured confounders. These weights allow a subsequent
outcome model (fitted by {helpb msm_fit}) to estimate the causal effect of
treatment free from time-varying confounding.

{pstd}
The command produces {bf:stabilized} inverse probability of treatment weights
(IPTW). When a censoring variable was mapped in {helpb msm_prepare} and you
specify {cmd:censor_d_cov()}, it also produces inverse probability of
censoring weights (IPCW) and combines both into a single final weight.

{pstd}
New variables are created in the dataset:

{phang2}{cmd:_msm_weight} {hline 2} the final combined cumulative weight
(treatment x censoring){p_end}
{phang2}{cmd:_msm_tw_weight} {hline 2} cumulative treatment weight only{p_end}
{phang2}{cmd:_msm_cw_weight} {hline 2} cumulative censoring weight
(only if IPCW is requested){p_end}
{phang2}{cmd:_msm_ps} {hline 2} the per-period treatment propensity
P(A_t = 1 | history) from the denominator model, kept for diagnostics{p_end}
{phang2}{cmd:_msm_treat_den_raw}, {cmd:_msm_treat_num_raw} {hline 2} raw fitted
treatment probabilities before any explicit repair{p_end}
{phang2}{cmd:_msm_treat_den_p}, {cmd:_msm_treat_num_p} {hline 2} treatment
probabilities actually used in the weights{p_end}
{phang2}{cmd:_msm_cens_den_raw}, {cmd:_msm_cens_num_raw},
{cmd:_msm_cens_den_p}, {cmd:_msm_cens_num_p} {hline 2} analogous censoring
probabilities when IPCW is requested{p_end}
{phang2}{cmd:_msm_decision_risk} {hline 2} marker for treatment/censoring
decision risk sets used by diagnostics{p_end}

{pstd}
Well-specified stabilized weights should have a mean close to 1.0 and moderate
variability. If the mean deviates substantially from 1 or the max/min ratio
is extreme, the command prints a diagnostic note suggesting you review the
treatment model specification.

{pstd}
After {cmd:msm_weight}, run {helpb psdash:psdash combined} for a longitudinal
period-by-period propensity-score overlap and weight diagnostic. It reads the
treatment, {cmd:_msm_ps}, the treatment weight, and the id/period structure
from the msm contract and complements {helpb msm_diagnose} (which reports
period/history-specific balance, separate censoring balance, support, weight
summaries, and effective sample size).


{marker mechanics}{...}
{title:How the weights are built}

{pstd}
For each person-period, {cmd:msm_weight} fits two logistic regression models:

{phang2}{bf:Denominator model:} P(A_t = 1 | A_{c -(}t-1{c )-}, L_t, V, period){p_end}
{phang2}{space 4}Predicts treatment from the full set of confounders, lagged
treatment, and period. This is the "full" model.{p_end}

{phang2}{bf:Numerator model:} P(A_t = 1 | A_{c -(}t-1{c )-}, V){p_end}
{phang2}{space 4}Predicts treatment from baseline covariates only (or just
lagged treatment if no numerator covariates are specified). This is the
"stabilizing" model that reduces weight variability.{p_end}

{pstd}
The period-specific stabilized weight for treated observations is
numerator/denominator; for untreated observations it is
(1-numerator)/(1-denominator). Cumulative weights are computed within each
individual using log-sum for numerical stability.

{pstd}
For non-technical readers, the denominator model asks how likely the observed
treatment was given the person's history and confounders. The numerator model
is a simpler stabilizing model. Final weights are larger when an observed
treatment pattern was unlikely under the denominator model, and smaller when
the pattern was common.

{pstd}
The first period is handled with a simpler model (no lagged treatment)
because there is no treatment history at baseline.


{marker options}{...}
{title:Options}

{dlgtab:Treatment weight models}

{phang}
{opth treat_d_cov(varlist)} specifies the covariates for the treatment
denominator model. This should include all time-varying confounders and
baseline covariates that predict treatment. If omitted, {cmd:msm_weight}
defaults to the {cmd:covariates()} and {cmd:baseline_covariates()} stored by
{helpb msm_prepare}. An explicit {cmd:treat_d_cov()} always overrides the
prepared default.

{phang}
{opth treat_n_cov(varlist)} specifies the covariates for the treatment
numerator model. Including fewer variables than the denominator produces
stabilized weights with lower variance. If omitted, the numerator model uses
only lagged treatment and an intercept.

{phang2}
Numerator covariates must be baseline-fixed (constant within {it:id}); a
time-varying variable is refused because {helpb msm_fit} cannot verify a
compatible treatment-history MSM. They are {it:not} balanced away by the
weights, so {cmd:msm_fit} requires every one in the structural outcome model
via {cmd:outcome_cov()} or, for Cox models, {cmd:strata()}, and refuses a fit
that omits one. See the {help msm_weight##numerator:numerator contract} below.

{dlgtab:Censoring weight models}

{phang}
{opth censor_d_cov(varlist)} specifies the covariates for the censoring
denominator model. This enables IPCW. Requires that a censoring variable was
mapped in {helpb msm_prepare} via {cmd:censor()}. Include variables that
predict both censoring and the outcome.

{phang}
{opth censor_n_cov(varlist)} specifies the covariates for the censoring
numerator model (stabilization). If omitted, the censoring numerator model
uses only current treatment status and an intercept. Requires
{cmd:censor_d_cov()} to be specified. The same baseline-fixed and outcome-model
requirements apply as for {cmd:treat_n_cov()}.

{dlgtab:Weight processing}

{phang}
{opth tru:ncate(numlist)} truncates extreme weights at specified percentiles. The most
common choice is {cmd:truncate(1 99)}, which caps the bottom 1% and top 1% of the
weight distribution. You can also use the symmetric shorthand {cmd:truncate(1)},
which is equivalent to {cmd:truncate(1 99)}. Truncation reduces the influence of
extreme weights at the cost of a small amount of bias. Values must lie
strictly between 0 and 100.

{dlgtab:Model behavior}

{phang}
{opt fitfailure(policy)} controls what happens when a logistic weight model
fails to estimate or does not converge. The default {cmd:fitfailure(error)}
stops immediately, which is safer for production analyses because it forces
you to address model specification problems (e.g., separation, positivity
violations). Use {cmd:fitfailure(marginal)} only if you explicitly want a
pooled marginal probability substituted for the failed model. Affected model
names are stored in {cmd:r(fitfailure_models)}.

{phang}
{opt probpolicy(policy)} controls unusable fitted probabilities after a model
has run. The default {cmd:probpolicy(error)} stops with error 459 when an
at-risk decision has a missing probability (including separation or an
incomplete weighting covariate) or a probability at exactly 0 or 1. The whole
weighting transaction is rolled back. There is no hidden clipping.

{phang}
{opt clip(#)} is required with {cmd:probpolicy(clip)} and must be strictly
between 0 and 0.5. The explicit clip policy replaces missing probabilities
for observed decisions at the appropriate endpoint and bounds all fitted
probabilities to [{it:#}, 1-{it:#}]. This changes the estimator and should be
used as a named sensitivity policy, not as evidence that positivity holds,
every missing, low, and high repair remains visible in the raw probability
variables and in {cmd:r(probability_repairs)}.

{phang}
{opt preview} resolves and displays the treatment and censoring model specifications
(including any {cmd:treat_d_cov()} defaulting and {cmd:truncate()} shorthand expansion)
without fitting any models or creating weight variables. Use this to verify
the specification before committing to a potentially time-consuming weighting
run.

{phang}
{opt replace} allows overwriting existing {cmd:_msm_weight},
{cmd:_msm_tw_weight}, {cmd:_msm_cw_weight}, and {cmd:_msm_ps} variables from a
previous run. Without this option, {cmd:msm_weight} refuses to overwrite and
exits with an error.

{phang}
{opt nolog} suppresses the iteration log from the logistic models. Recommended for
production scripts.


{marker numerator}{...}
{title:The stabilized numerator contract}

{pstd}
Stabilization does not remove the numerator covariates' confounding -- it
deliberately leaves it in place. A variable kept in the numerator is still
associated with treatment in the pseudo-population, so the structural model is
{it:conditional} on it and must include it. Hernan, Brumback and Robins (2000)
carry a {bf:beta_2*V} term in their marginal structural model for exactly the
{bf:V} that appears in their weight numerator.

{pstd}
This matters because the failure is silent. Weights built from a numerator
that the outcome model omits can look perfect -- mean 1, small spread, and
no positivity warning -- while retaining all of the confounding. {helpb msm_fit}
therefore refuses such a fit (error 198) rather than reporting a
confounded estimate with a tight confidence interval.

{pstd}
The package offers no override for time-varying numerator covariates because
such a covariate changes the estimand and requires a treatment-history outcome
model whose terms and prediction contract this package cannot establish. Build
and validate that model directly rather than treating the current-only MSM as
equivalent.


{marker interpreting}{...}
{title:Interpreting the output}

{pstd}
After fitting, {cmd:msm_weight} reports a weight summary. Key diagnostics:

{phang2}{bf:Mean {c ~} 1.0:} Stabilized weights should have a mean close to
1. A mean far from 1 suggests the numerator or denominator model may be
misspecified.{p_end}

{phang2}{bf:Effective sample size (ESS):} ESS = (sum w)^2 / (sum w^2). This
measures how much information the weighted sample retains compared to the
unweighted sample. Low ESS (e.g., <50% of N) suggests high weight variability,
which inflates variance. Consider truncation or model simplification.{p_end}

{phang2}{bf:Max/min ratio:} Very large weights indicate near-violations of the
positivity assumption. Investigate with {helpb msm_diagnose} and
{helpb msm_plot}.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Treatment weights only (IPTW).} The most common use case. Denominator
covariates default to the prepared variables:{p_end}

{phang2}{cmd:. msm_weight, treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}
{bf:Preview the model specification before fitting:}{p_end}

{phang2}{cmd:. msm_weight, preview truncate(1)}{p_end}

{pstd}
{bf:Explicit denominator covariates.} Override the prepared defaults:{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}
{bf:IPTW + IPCW.} Combined treatment and censoring weights:{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) censor_d_cov(age sex biomarker)}{p_end}
{phang2}{cmd:    truncate(1 99) nolog}{p_end}

{pstd}
{bf:Marginal fallback for unstable models.} Use only when you have
investigated and are willing to accept a marginal probability substitute:{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) fitfailure(marginal)}{p_end}
{phang2}{cmd:    probpolicy(clip) clip(0.001) nolog}{p_end}

{pstd}
{bf:Explicit probability clipping sensitivity policy:}{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) probpolicy(clip) clip(0.01) nolog}{p_end}
{phang2}{cmd:. matrix list r(probability_repairs)}{p_end}

{pstd}
{bf:Re-running weights after adjusting truncation:}{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(5 95) replace nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_weight} stores the following in {cmd:r()}. In {cmd:preview} mode,
only the model-specification macros are returned; after fitting, all scalars
and macros below are returned.

{pstd}
Scalars are available only after fitting. They are not returned by
{cmd:preview}.

{synoptset 28 tabbed}{...}
{p2col 5 28 32 2: Scalars}{p_end}
{synopt:{cmd:r(mean_weight)}}mean of the final combined weight{p_end}
{synopt:{cmd:r(sd_weight)}}standard deviation of the final weight{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile weight{p_end}
{synopt:{cmd:r(median_weight)}}median weight{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile weight{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(n_truncated)}}number of observations truncated{p_end}
{synopt:{cmd:r(n_fitfail_fallback)}}number of model-level marginal fallback events{p_end}
{synopt:{cmd:r(fitfailure_fallback)}}1 if any fallback was used, 0 otherwise{p_end}
{synopt:{cmd:r(n_probability_repairs)}}total missing, low, and high probability repairs{p_end}
{synopt:{cmd:r(clip_threshold)}}explicit probability bound, with {cmd:probpolicy(clip)}{p_end}

{p2col 5 28 32 2: Matrices}{p_end}
{synopt:{cmd:r(probability_repairs)}}model-period-cell probability audit{p_end}

{p2col 5 28 32 2: Macros}{p_end}
{pstd}
The specification macros are returned both after fitting and after
{cmd:preview}, except {cmd:r(weight_var)} and {cmd:r(fitfailure_models)}, which
are meaningful after fitting.

{synopt:{cmd:r(weight_var)}}name of the final weight variable ({cmd:_msm_weight}){p_end}
{synopt:{cmd:r(fitfailure_policy)}}resolved failure policy ({cmd:error} or {cmd:marginal}){p_end}
{synopt:{cmd:r(fitfailure_models)}}model identifiers that used marginal fallback{p_end}
{synopt:{cmd:r(probability_policy)}}resolved policy ({cmd:error} or {cmd:clip}){p_end}
{synopt:{cmd:r(probability_models)}}numeric model codes used in the repair matrix{p_end}
{synopt:{cmd:r(preview)}}{cmd:1} if preview mode was used, {cmd:0} otherwise{p_end}
{synopt:{cmd:r(treat_d_cov)}}resolved treatment denominator covariates{p_end}
{synopt:{cmd:r(treat_d_cov_source)}}{cmd:explicit} or {cmd:prepared}{p_end}
{synopt:{cmd:r(treat_n_cov)}}treatment numerator covariates{p_end}
{synopt:{cmd:r(censor_d_cov)}}censoring denominator covariates{p_end}
{synopt:{cmd:r(censor_n_cov)}}censoring numerator covariates{p_end}
{synopt:{cmd:r(truncate)}}resolved truncation percentiles{p_end}

{pstd}
For scripted specification checks, the most useful preview results are
{cmd:r(preview)}, {cmd:r(treat_d_cov)}, {cmd:r(treat_d_cov_source)},
{cmd:r(treat_n_cov)}, {cmd:r(censor_d_cov)}, {cmd:r(censor_n_cov)},
{cmd:r(truncate)}, {cmd:r(fitfailure_policy)}, and
{cmd:r(probability_policy)}.

{pstd}
For scripted post-fit checks, the most useful diagnostics are
{cmd:r(weight_var)}, {cmd:r(mean_weight)}, {cmd:r(ess)},
{cmd:r(n_truncated)}, {cmd:r(n_fitfail_fallback)}, {cmd:r(fitfailure_fallback)},
{cmd:r(fitfailure_models)}, and {cmd:r(n_probability_repairs)}.

{pstd}
{cmd:r(probability_repairs)} has columns {cmd:model}, {cmd:period}, {cmd:cell},
{cmd:N}, {cmd:n_missing}, {cmd:n_low}, {cmd:n_high}, {cmd:raw_min},
{cmd:raw_max}, {cmd:repaired_min}, and {cmd:repaired_max}. Model codes are
decoded by {cmd:r(probability_models)}. A row is returned for every observed
decision cell, including cells with zero repairs.

{pstd}
For routine QA thresholds, scripts commonly inspect {cmd:r(mean_weight)},
{cmd:r(sd_weight)}, {cmd:r(min_weight)}, {cmd:r(max_weight)}, and
{cmd:r(p99_weight)} before proceeding to {helpb msm_diagnose}.

{phang2}{cmd:r(mean_weight)} is the fastest check for whether stabilized
weights are centered near 1.{p_end}

{phang2}{cmd:r(ess)} is the fastest check for whether extreme weights have
substantially reduced usable information.{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
