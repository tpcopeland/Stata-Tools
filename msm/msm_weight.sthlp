{smcl}
{* *! version 1.0.0  26apr2026}{...}
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
{synopt:{opt treat_n_cov(varlist)}}covariates for the treatment numerator model (stabilization){p_end}

{syntab:Censoring weight models}
{synopt:{opt cen:sor_d_cov(varlist)}}covariates for the censoring denominator model{p_end}
{synopt:{opt cen:sor_n_cov(varlist)}}covariates for the censoring numerator model{p_end}

{syntab:Weight processing}
{synopt:{opt tru:ncate(numlist)}}truncation percentiles (e.g., {cmd:1} or {cmd:1 99}){p_end}

{syntab:Model behavior}
{synopt:{opt fitfailure(policy)}}model-failure policy: {cmd:error} (default) or {cmd:marginal}{p_end}
{synopt:{opt preview}}display resolved model specs without fitting{p_end}
{synopt:{opt replace}}replace existing weight variables{p_end}
{synopt:{opt nolog}}suppress logistic model iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_weight} is the core of the MSM package.  It calculates the inverse
probability weights that create a pseudo-population where treatment is
independent of measured confounders.  These weights allow a subsequent
outcome model (fitted by {helpb msm_fit}) to estimate the causal effect of
treatment free from time-varying confounding.

{pstd}
The command produces {bf:stabilized} inverse probability of treatment weights
(IPTW).  When a censoring variable was mapped in {helpb msm_prepare} and you
specify {cmd:censor_d_cov()}, it also produces inverse probability of
censoring weights (IPCW) and combines both into a single final weight.

{pstd}
Three new variables are created in the dataset:

{phang2}{cmd:_msm_weight} {hline 2} the final combined cumulative weight
(treatment x censoring){p_end}
{phang2}{cmd:_msm_tw_weight} {hline 2} cumulative treatment weight only{p_end}
{phang2}{cmd:_msm_cw_weight} {hline 2} cumulative censoring weight
(only if IPCW is requested){p_end}

{pstd}
Well-specified stabilized weights should have a mean close to 1.0 and moderate
variability.  If the mean deviates substantially from 1 or the max/min ratio
is extreme, the command prints a diagnostic note suggesting you review the
treatment model specification.


{marker mechanics}{...}
{title:How the weights are built}

{pstd}
For each person-period, {cmd:msm_weight} fits two logistic regression models:

{phang2}{bf:Denominator model:}  P(A_t = 1 | A_{{t-1}}, L_t, V, period){p_end}
{phang2}{space 4}Predicts treatment from the full set of confounders, lagged
treatment, and period.  This is the "full" model.{p_end}

{phang2}{bf:Numerator model:}  P(A_t = 1 | A_{{t-1}}, V){p_end}
{phang2}{space 4}Predicts treatment from baseline covariates only (or just
lagged treatment if no numerator covariates are specified).  This is the
"stabilizing" model that reduces weight variability.{p_end}

{pstd}
The period-specific stabilized weight for treated observations is
numerator/denominator; for untreated observations it is
(1-numerator)/(1-denominator).  Cumulative weights are computed within each
individual using log-sum for numerical stability.

{pstd}
The first period is handled with a simpler model (no lagged treatment)
because there is no treatment history at baseline.


{marker options}{...}
{title:Options}

{dlgtab:Treatment weight models}

{phang}
{opth treat_d_cov(varlist)} specifies the covariates for the treatment
denominator model.  This should include all time-varying confounders and
baseline covariates that predict treatment.  If omitted, {cmd:msm_weight}
defaults to the {cmd:covariates()} and {cmd:baseline_covariates()} stored by
{helpb msm_prepare}.  An explicit {cmd:treat_d_cov()} always overrides the
prepared default.

{phang}
{opth treat_n_cov(varlist)} specifies the covariates for the treatment
numerator model.  This should typically include only baseline covariates
(e.g., age, sex) that do not change over time.  Including fewer variables than
the denominator produces stabilized weights with lower variance.  If omitted,
the numerator model uses only lagged treatment and an intercept.

{dlgtab:Censoring weight models}

{phang}
{opth censor_d_cov(varlist)} specifies the covariates for the censoring
denominator model.  This enables IPCW.  Requires that a censoring variable was
mapped in {helpb msm_prepare} via {cmd:censor()}.  Include variables that
predict both censoring and the outcome.

{phang}
{opth censor_n_cov(varlist)} specifies the covariates for the censoring
numerator model (stabilization).  If omitted, the censoring numerator model
uses only current treatment status and an intercept.  Requires
{cmd:censor_d_cov()} to be specified.

{dlgtab:Weight processing}

{phang}
{opth tru:ncate(numlist)} truncates extreme weights at specified percentiles.
The most common choice is {cmd:truncate(1 99)}, which caps the bottom 1% and
top 1% of the weight distribution.  You can also use the symmetric shorthand
{cmd:truncate(1)}, which is equivalent to {cmd:truncate(1 99)}.  Truncation
reduces the influence of extreme weights at the cost of a small amount of
bias.  Values must lie strictly between 0 and 100.

{dlgtab:Model behavior}

{phang}
{opt fitfailure(policy)} controls what happens when a logistic weight model
fails to estimate or does not converge.  The default {cmd:fitfailure(error)}
stops immediately, which is safer for production analyses because it forces
you to address model specification problems (e.g., separation, positivity
violations).  Use {cmd:fitfailure(marginal)} only if you explicitly want a
pooled marginal probability substituted for the failed model.  Affected model
names are stored in {cmd:r(fitfailure_models)}.

{phang}
{opt preview} resolves and displays the treatment and censoring model
specifications (including any {cmd:treat_d_cov()} defaulting and {cmd:truncate()}
shorthand expansion) without fitting any models or creating weight variables.
Use this to verify the specification before committing to a potentially
time-consuming weighting run.

{phang}
{opt replace} allows overwriting existing {cmd:_msm_weight},
{cmd:_msm_tw_weight}, and {cmd:_msm_cw_weight} variables from a previous
run.  Without this option, {cmd:msm_weight} refuses to overwrite and exits
with an error.

{phang}
{opt nolog} suppresses the iteration log from the logistic models.
Recommended for production scripts.


{marker interpreting}{...}
{title:Interpreting the output}

{pstd}
After fitting, {cmd:msm_weight} reports a weight summary.  Key diagnostics:

{phang2}{bf:Mean {c ~} 1.0:}  Stabilized weights should have a mean close to
1.  A mean far from 1 suggests the numerator or denominator model may be
misspecified.{p_end}

{phang2}{bf:Effective sample size (ESS):}  ESS = (sum w)^2 / (sum w^2).  This
measures how much information the weighted sample retains compared to the
unweighted sample.  Low ESS (e.g., <50% of N) suggests high weight variability,
which inflates variance.  Consider truncation or model simplification.{p_end}

{phang2}{bf:Max/min ratio:}  Very large weights indicate near-violations of the
positivity assumption.  Investigate with {helpb msm_diagnose} and
{helpb msm_plot}.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Treatment weights only (IPTW).}  The most common use case.  Denominator
covariates default to the prepared variables:{p_end}

{phang2}{cmd:. msm_weight, treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}
{bf:Preview the model specification before fitting:}{p_end}

{phang2}{cmd:. msm_weight, preview truncate(1)}{p_end}

{pstd}
{bf:Explicit denominator covariates.}  Override the prepared defaults:{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}
{bf:IPTW + IPCW.}  Combined treatment and censoring weights:{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) censor_d_cov(age sex biomarker)}{p_end}
{phang2}{cmd:    truncate(1 99) nolog}{p_end}

{pstd}
{bf:Marginal fallback for unstable models.}  Use only when you have
investigated and are willing to accept a marginal probability substitute:{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) fitfailure(marginal) nolog}{p_end}

{pstd}
{bf:Re-running weights after adjusting truncation:}{p_end}

{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(5 95) replace nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_weight} stores the following in {cmd:r()} after fitting (not in
{cmd:preview} mode):

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
{synopt:{cmd:r(n_probability_repairs)}}observations repaired after perfect prediction{p_end}

{p2col 5 28 32 2: Macros}{p_end}
{synopt:{cmd:r(weight_var)}}name of the final weight variable ({cmd:_msm_weight}){p_end}
{synopt:{cmd:r(fitfailure_policy)}}resolved failure policy ({cmd:error} or {cmd:marginal}){p_end}
{synopt:{cmd:r(fitfailure_models)}}model identifiers that used marginal fallback{p_end}
{synopt:{cmd:r(preview)}}{cmd:1} if preview mode was used, {cmd:0} otherwise{p_end}
{synopt:{cmd:r(treat_d_cov)}}resolved treatment denominator covariates{p_end}
{synopt:{cmd:r(treat_d_cov_source)}}{cmd:explicit} or {cmd:prepared}{p_end}
{synopt:{cmd:r(treat_n_cov)}}treatment numerator covariates{p_end}
{synopt:{cmd:r(censor_d_cov)}}censoring denominator covariates{p_end}
{synopt:{cmd:r(censor_n_cov)}}censoring numerator covariates{p_end}
{synopt:{cmd:r(truncate)}}resolved truncation percentiles{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}
