{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_prepare" "help msm_prepare"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{viewerjumpto "Syntax" "msm_weight##syntax"}{...}
{viewerjumpto "Description" "msm_weight##description"}{...}
{viewerjumpto "Options" "msm_weight##options"}{...}
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
{cmd:,}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Optional}
{synopt:{opt treat_d_cov(varlist)}}treatment denominator covariates; defaults to prepared covariates when available{p_end}
{synopt:{opt treat_n_cov(varlist)}}treatment numerator covariates{p_end}
{synopt:{opt censor_d_cov(varlist)}}censoring denominator covariates{p_end}
{synopt:{opt censor_n_cov(varlist)}}censoring numerator covariates{p_end}
{synopt:{opt tru:ncate(numlist)}}truncation percentiles (e.g., 1 or 1 99){p_end}
{synopt:{opt preview}}resolve and display treatment/censoring model specs without fitting{p_end}
{synopt:{opt fitfailure(policy)}}model-failure policy: {cmd:error} (default) or {cmd:marginal}{p_end}
{synopt:{opt replace}}replace existing weight variables{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_weight} calculates stabilized inverse probability of treatment
weights (IPTW) and optionally inverse probability of censoring weights
(IPCW). For each person-period, it fits logistic models:

{phang2}Denominator: P(A_t | A_{t-1}, L_t, V) - full model{p_end}
{phang2}Numerator: P(A_t | A_{t-1}, V) - baseline only{p_end}

{pstd}
Period-specific weight ratios are accumulated via cumulative product
within individuals using log-sum for numerical stability. Stabilized
weights should have mean approximately 1.

{pstd}
If {cmd:treat_d_cov()} is omitted, {cmd:msm_weight} defaults the treatment
denominator covariates to the variables stored by {cmd:msm_prepare} in
{cmd:covariates()} plus {cmd:baseline_covariates()}, when those are available.
An explicit {cmd:treat_d_cov()} always overrides the prepared default.

{pstd}
{cmd:preview} resolves those treatment and censoring model specifications,
prints the formulas that would be fit, and returns without creating weight
variables or modifying existing ones.

{pstd}
Model-level fit failures and observation-level perfect prediction are handled
differently. By default, if a treatment or censoring model cannot be estimated
or does not converge, {cmd:msm_weight} stops with an error rather than quietly
substituting a marginal probability. Users who explicitly want the older
behavior may request {cmd:fitfailure(marginal)}; when used, the marginal
fallback is applied only to the complete-case estimation sample for the failed
model and is recorded in {cmd:r(fitfailure_models)}.

{pstd}
If a fitted model succeeds but some complete-case observations are perfectly
predicted, {cmd:msm_weight} assigns truncated observed probabilities to those
observations rather than silently dropping them. Observations with missing model
inputs retain missing probabilities, and cumulative weights are set to missing
from that period forward.

{pstd}
Creates variables: {cmd:_msm_weight} (cumulative combined),
{cmd:_msm_tw_weight} (treatment weight), and optionally
{cmd:_msm_cw_weight} (censoring weight).


{marker options}{...}
{title:Options}

{phang}
{opth treat_d_cov(varlist)} specifies covariates for the treatment
denominator model. Should include time-varying confounders and baseline
covariates. If omitted, {cmd:msm_weight} uses the prepared
{cmd:covariates()} and {cmd:baseline_covariates()} stored by
{cmd:msm_prepare}. Explicit {cmd:treat_d_cov()} overrides that default.

{phang}
{opth treat_n_cov(varlist)} specifies covariates for the treatment
numerator model (stabilization). Typically baseline covariates only.

{phang}
{opth censor_d_cov(varlist)} specifies covariates for the censoring
denominator model. Requires {opt censor()} in {cmd:msm_prepare}.

{phang}
{opth censor_n_cov(varlist)} specifies covariates for the censoring
numerator model (stabilization). Typically baseline covariates only.

{phang}
{opth tru:ncate(numlist)} truncates weights at specified percentiles.
Common choices are {cmd:truncate(1 99)} and the symmetric shorthand
{cmd:truncate(1)}, which resolves to {cmd:1 99}. Values must lie strictly
between 0 and 100.

{phang}
{opt preview} resolves and displays the treatment and censoring model
specifications that {cmd:msm_weight} would fit, including any defaulted
{cmd:treat_d_cov()} and shorthand {cmd:truncate()} expansion. No models are
fit and no weight variables are created.

{phang}
{opt fitfailure(policy)} controls what happens when a pooled treatment or
censoring model fails to estimate or does not converge. The default
{cmd:fitfailure(error)} stops immediately, which is safer for publication work
because it does not conceal positivity or separation problems. Use
{cmd:fitfailure(marginal)} only if you explicitly want a pooled marginal
probability substituted for the failed model's complete-case estimation sample.
When fallback is used, the affected model names are stored in
{cmd:r(fitfailure_models)} and the number of fallback events is stored in
{cmd:r(n_fitfail_fallback)}.

{phang}
{opt replace} allows overwriting existing weight variables from a previous
run of {cmd:msm_weight}.

{phang}
{opt nolog} suppresses the iteration log from the logistic models.


{marker examples}{...}
{title:Examples}

{pstd}IPTW only{p_end}
{phang2}{cmd:. msm_weight}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}Preview resolved model specifications{p_end}
{phang2}{cmd:. msm_weight, preview truncate(1)}{p_end}

{pstd}IPTW + IPCW{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) censor_d_cov(age sex biomarker)}{p_end}
{phang2}{cmd:    truncate(1 99) nolog}{p_end}

{pstd}Explicit opt-in marginal fallback for unstable weight models{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) fitfailure(marginal) nolog}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}weight standard deviation{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(n_truncated)}}number of truncated observations{p_end}
{synopt:{cmd:r(n_fitfail_fallback)}}number of model-level marginal fallback events used{p_end}
{synopt:{cmd:r(fitfailure_fallback)}}1 if any model-level fallback was used, else 0{p_end}
{synopt:{cmd:r(n_probability_repairs)}}number of complete-case observations repaired after perfect prediction{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile weight{p_end}
{synopt:{cmd:r(median_weight)}}median weight{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile weight{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(weight_var)}}name of weight variable{p_end}
{synopt:{cmd:r(fitfailure_policy)}}resolved model-failure policy used by {cmd:msm_weight}{p_end}
{synopt:{cmd:r(fitfailure_models)}}model identifiers that used explicit marginal fallback{p_end}
{synopt:{cmd:r(preview)}}1 if {cmd:preview} was used, else 0{p_end}
{synopt:{cmd:r(treat_d_cov)}}resolved treatment denominator covariates{p_end}
{synopt:{cmd:r(treat_d_cov_source)}}whether {cmd:treat_d_cov()} was explicit or prepared{p_end}
{synopt:{cmd:r(treat_n_cov)}}treatment numerator covariates, if any{p_end}
{synopt:{cmd:r(censor_d_cov)}}censoring denominator covariates, if any{p_end}
{synopt:{cmd:r(censor_n_cov)}}censoring numerator covariates, if any{p_end}
{synopt:{cmd:r(truncate)}}resolved truncation percentiles, if any{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
