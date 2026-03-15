{smcl}
{* *! version 1.2.0  15mar2026}{...}
{viewerjumpto "Syntax" "tte_weight##syntax"}{...}
{viewerjumpto "Description" "tte_weight##description"}{...}
{viewerjumpto "Options" "tte_weight##options"}{...}
{viewerjumpto "Examples" "tte_weight##examples"}{...}
{viewerjumpto "Stored results" "tte_weight##results"}{...}
{viewerjumpto "Technical notes" "tte_weight##technical"}{...}
{viewerjumpto "Author" "tte_weight##author"}{...}

{title:Title}

{phang}
{bf:tte_weight} {hline 2} Inverse probability weights for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_weight}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Switch models}
{synopt:{opth switch_d_cov(varlist)}}covariates for switch denominator model{p_end}
{synopt:{opth switch_n_cov(varlist)}}covariates for switch numerator model{p_end}

{syntab:Censoring models}
{synopt:{opth censor_d_cov(varlist)}}covariates for censoring denominator model{p_end}
{synopt:{opth censor_n_cov(varlist)}}covariates for censoring numerator model{p_end}

{syntab:Model specification}
{synopt:{opt pool_switch}}pool switch models across arms{p_end}
{synopt:{opt pool_censor}}pool censoring models across arms{p_end}
{synopt:{opth strata(string)}}stratification: {cmd:arm} (default, 2 models) or {cmd:arm_lag} (4 models){p_end}

{syntab:Options}
{synopt:{opth trunc:ate(numlist)}}truncate at percentiles (e.g., {cmd:truncate(1 99)}){p_end}
{synopt:{opth gen:erate(name)}}weight variable name; default is {cmd:_tte_weight}{p_end}
{synopt:{opt replace}}replace existing weight variable{p_end}
{synopt:{opt nolog}}suppress model iteration log{p_end}

{syntab:Propensity score}
{synopt:{opt save_ps}}save propensity scores as permanent variable{p_end}
{synopt:{opt trim_ps(#)}}trim observations at #th percentile from each PS tail{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_weight} calculates stabilized inverse probability weights for
treatment switching and optionally for informative censoring. These
weights account for the artificial censoring introduced by {helpb tte_expand}
in per-protocol and as-treated analyses.

{pstd}
For ITT analyses, all weights are set to 1 (no artificial censoring occurs).


{marker options}{...}
{title:Options}

{dlgtab:Switch models}

{phang}
{opth switch_d_cov(varlist)} specifies covariates for the switch denominator
model. This is the main confounding adjustment model — include all
covariates that predict both treatment switching and the outcome. More
variables reduce confounding bias.

{phang}
{opth switch_n_cov(varlist)} specifies covariates for the switch numerator
model. Fewer covariates than the denominator model produce weights closer
to 1, reducing variance. Omit to use an intercept-only numerator
(unstabilized weights).

{dlgtab:Censoring models}

{phang}
{opth censor_d_cov(varlist)} specifies covariates for the censoring
denominator model. Used when informative censoring (beyond the artificial
censoring from cloning) is present in the data.

{phang}
{opth censor_n_cov(varlist)} specifies covariates for the censoring
numerator model.

{dlgtab:Model specification}

{phang}
{opt pool_switch} pools the switch models across treatment arms instead of
fitting separately by arm. Use when arm-specific models suffer from
separation or small samples.

{phang}
{opt pool_censor} pools the censoring models across treatment arms.

{phang}
{opt strata(string)} specifies the stratification for the switch weight
models. {cmd:arm} (default) fits 2 models (one per arm), where lagged
treatment enters as a covariate. {cmd:arm_lag} fits 4 models
(one per arm x lagged treatment combination), omitting lagged treatment
from the model (it is constant within each stratum). The 4-stratum
approach matches R TrialEmulation. Both are valid parameterizations that
target the same causal estimand when correctly specified.

{dlgtab:Options}

{phang}
{opth truncate(numlist)} truncates weights at the specified percentiles.
For example, {cmd:truncate(1 99)} sets weights below the 1st percentile
to the 1st percentile value and weights above the 99th to the 99th.
Truncation reduces the influence of extreme weights.

{phang}
{opth generate(name)} specifies the name for the weight variable. The
default is {cmd:_tte_weight}.

{phang}
{opt replace} replaces an existing weight variable of the same name.

{phang}
{opt nolog} suppresses the iteration log of the logistic regression
models.

{dlgtab:Propensity score}

{phang}
{opt save_ps} saves the propensity score (predicted probability from the
switch denominator model) as a permanent variable named
{cmd:_tte_pscore}. This enables downstream diagnostics with
{helpb tte_diagnose:tte_diagnose, equipoise} and overlap plots with
{helpb tte_plot:tte_plot, type(pscore)}.

{phang}
{opt trim_ps(#)} trims observations with extreme propensity scores by
dropping those below the #th and above the (100-#)th percentile. For
example, {cmd:trim_ps(5)} drops observations below the 5th and above
the 95th percentile of the PS distribution. Trimming is applied after
weight computation.

{pmore}
{bf:Caution:} In sequential trials, PS trimming at the person-period
level may introduce selection bias by differentially removing observations
across trial periods. Weight truncation ({opt truncate()}) is generally
preferred as it modifies extreme weights without dropping observations.


{marker examples}{...}
{title:Examples}

{pstd}Stabilized weights with truncation{p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity biomarker) truncate(1 99) nolog}{p_end}

{pstd}With censoring weights{p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity) censor_d_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}Save propensity scores for diagnostics{p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity) save_ps truncate(1 99) nolog}{p_end}
{phang2}{cmd:. tte_plot, type(pscore)}{p_end}

{pstd}PS trimming (5th/95th percentile){p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity) trim_ps(5) nolog}{p_end}


{marker technical}{...}
{title:Technical notes}

{dlgtab:Weight model stratification}

{pstd}
With {cmd:strata(arm)} (default), switch models are fitted separately by
treatment arm (2 strata: arm=0 and arm=1). Within each stratum, a logistic
regression models the probability of treatment switching as a function of
covariates and lagged treatment status.

{pstd}
With {cmd:strata(arm_lag)}, models are fitted separately for each
(arm, lagged treatment) combination (4 strata). Within each stratum,
lagged treatment is constant and omitted from the model. This matches
the R TrialEmulation default stratification.

{pstd}
Both are valid parameterizations of the inverse probability weight model
(Hernán & Robins, 2020, Technical Point 12.2). The choice affects
individual weight values and outcome model coefficients but not the
target causal estimand (risk differences from {cmd:tte_predict}) when
both models are correctly specified.

{dlgtab:Stabilized weights}

{pstd}
Stabilized weights use the form w = Pr(A{sub:t}|A{sub:t-1}, L{sub:0}) /
Pr(A{sub:t}|A{sub:t-1}, L{sub:0}, L{sub:t}). The numerator model includes
variables from {opt switch_n_cov()}, which stabilizes weights and reduces
variance compared to unstabilized weights (numerator = 1).

{dlgtab:Covariate values in weight models}

{pstd}
After expansion by {cmd:tte_expand}, covariates registered in
{cmd:tte_prepare} are frozen at trial-entry (baseline) values. Weight
model covariates passed via {opt switch_d_cov()} and {opt switch_n_cov()}
therefore use baseline values. This is theoretically justified: the IP
weight model can condition on baseline covariates L{sub:0} and still
produce consistent estimates of the causal effect, provided the model is
correctly specified (Hernán & Robins, 2020, Technical Point 12.2).

{pstd}
If time-varying covariates are needed in the weight model, users must
construct them manually before calling {cmd:tte_weight} (e.g., by merging
from the original data using {cmd:id}, {cmd:period}).

{dlgtab:Propensity score}

{pstd}
The saved propensity score is the predicted probability from the switch
denominator model: P(A_t | A_{t-1}, L, t). This is a time-varying
quantity available at follow-up period 1 onwards (no prediction at
period 0 because there is no lagged treatment). For PS overlap
diagnostics, consider restricting to follow-up period 1.

{dlgtab:Model failure fallbacks}

{pstd}
If a weight model fails to converge (e.g., due to separation or
insufficient variation), {cmd:tte_weight} falls back to default
probabilities: 0.5 for treatment switch models and 0.05 for
censoring models. These defaults produce neutral weight contributions
(approximately 1.0) for the affected periods. A warning is displayed
when a model fails to converge or when predictions are missing due to
covariate issues. Inspect weight distributions ({cmd:tte_diagnose})
to verify weight quality.

{dlgtab:Truncation}

{pstd}
When {opt truncate(lo hi)} is specified, weights below the {it:lo}th
percentile or above the {it:hi}th percentile are set to those percentile
values. Truncation is applied after weight computation. The number of
truncated weights is reported in {cmd:r(n_truncated)}.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_weight} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}SD of weights{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(n_truncated)}}number of truncated weights{p_end}
{synopt:{cmd:r(mean_ps)}}mean propensity score (if {cmd:save_ps}){p_end}
{synopt:{cmd:r(sd_ps)}}SD of propensity scores (if {cmd:save_ps}){p_end}
{synopt:{cmd:r(min_ps)}}minimum propensity score (if {cmd:save_ps}){p_end}
{synopt:{cmd:r(max_ps)}}maximum propensity score (if {cmd:save_ps}){p_end}
{synopt:{cmd:r(n_ps_trimmed)}}observations dropped by PS trimming (if {cmd:trim_ps()}){p_end}
{synopt:{cmd:r(ps_lo_cut)}}lower PS cutoff (if {cmd:trim_ps()}){p_end}
{synopt:{cmd:r(ps_hi_cut)}}upper PS cutoff (if {cmd:trim_ps()}){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(generate)}}weight variable name{p_end}
{synopt:{cmd:r(estimand)}}estimand{p_end}
{synopt:{cmd:r(strata)}}stratification (arm or arm_lag){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se
