{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm_prepare" "help msm_prepare"}{...}
{vieweralsosee "msm_validate" "help msm_validate"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{vieweralsosee "msm_plot" "help msm_plot"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_protocol" "help msm_protocol"}{...}
{vieweralsosee "msm_sensitivity" "help msm_sensitivity"}{...}
{viewerjumpto "Syntax" "msm##syntax"}{...}
{viewerjumpto "Description" "msm##description"}{...}
{viewerjumpto "Commands" "msm##commands"}{...}
{viewerjumpto "Workflow" "msm##workflow"}{...}
{viewerjumpto "Pipeline status" "msm##status"}{...}
{viewerjumpto "Current scope and limits" "msm##scope"}{...}
{viewerjumpto "Examples" "msm##examples"}{...}
{viewerjumpto "References" "msm##references"}{...}
{viewerjumpto "Stored results" "msm##results"}{...}
{viewerjumpto "Author" "msm##author"}{...}

{title:Title}

{phang}
{bf:msm} {hline 2} Marginal Structural Models suite for Stata


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt list}}display commands as simple list{p_end}
{synopt:{opt detail}}show detailed command descriptions{p_end}
{synopt:{opt prot:ocol}}show MSM protocol framework{p_end}
{synopt:{opt stat:us}}show current pipeline stage, mapped variables, and saved artifacts{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm} is a comprehensive suite for marginal structural model estimation
using inverse probability of treatment weighting (IPTW) for time-varying
treatments and confounders. It implements the complete IPTW pipeline:
data preparation, weight calculation, diagnostics, outcome modeling,
counterfactual prediction, and sensitivity analysis for conventional
static-regime analyses in person-period data.

{pstd}
Unlike point-in-time treatment effect estimators ({cmd:teffects ipw}),
{cmd:msm} handles the key challenge of time-varying treatment-confounder
feedback where confounders are simultaneously affected by past treatment
and predictive of future treatment. Standard regression adjustment cannot
handle this structure; IPTW creates a pseudo-population where treatment
is independent of measured confounders.

{pstd}
The package's prediction workflow targets static always-treated and
never-treated strategies for binary outcomes fitted with pooled logistic
models. Linear and Cox MSM fits are available for estimation and reporting,
but they do not feed into {helpb msm_predict}.

{pstd}
Run {cmd:msm, status} at any point to inspect the current dataset state.
It reports whether the data are prepared, weighted, and fitted; the
variable mappings stored by {helpb msm_prepare}; saved prediction, balance,
diagnostic, and sensitivity artifacts; the fitted model type if present;
and a recommended next command.


{marker commands}{...}
{title:Commands}

{dlgtab:Data Preparation}

{phang}
{helpb msm_prepare} {hline 2} Map variables and store metadata

{phang}
{helpb msm_validate} {hline 2} Data quality checks (10 diagnostics)

{dlgtab:Core Engine}

{phang}
{helpb msm_weight} {hline 2} Stabilized IPTW (+ optional IPCW)

{phang}
{helpb msm_fit} {hline 2} Weighted outcome model (pooled logistic/linear/Cox)

{phang}
{helpb msm_predict} {hline 2} Counterfactual predictions with CIs

{dlgtab:Diagnostics and Reporting}

{phang}
{helpb msm_diagnose} {hline 2} Weight distribution and covariate balance

{phang}
{helpb msm_plot} {hline 2} Weight, balance, survival, trajectory, positivity plots

{phang}
{helpb msm_report} {hline 2} Publication-quality results tables

{phang}
{helpb msm_table} {hline 2} Multi-sheet Excel export of pipeline results

{phang}
{helpb msm_protocol} {hline 2} MSM study protocol (7 components)

{phang}
{helpb msm_sensitivity} {hline 2} E-value and confounding bounds


{marker workflow}{...}
{title:Typical Workflow}

{p 4 4 2}
0. {cmd:msm_protocol} - Document study design{break}
1. {cmd:msm_prepare} - Map variables{break}
2. {cmd:msm_validate} - Check data quality{break}
3. {cmd:msm_weight} - Calculate stabilized IP weights{break}
4. {cmd:msm_diagnose} - Assess weight distribution and balance{break}
5. {cmd:msm_fit} - Fit weighted outcome model{break}
6. {cmd:msm_predict} - Estimate counterfactual outcomes{break}
7. {cmd:msm_report} - Export publication tables{break}
8. {cmd:msm_sensitivity} - Sensitivity analysis

{pstd}
Run {cmd:msm, status} anytime to see where the current dataset sits in
the workflow and what outputs are already available.


{marker status}{...}
{title:Pipeline status}

{pstd}
{cmd:msm, status} is a lightweight introspection command for interrupted
or iterative workflows. It does not fit models or recalculate anything.
Instead, it reads the stored {cmd:_dta[_msm_*]} characteristics and saved
artifacts already attached to the dataset.

{pstd}
The status report summarizes the current pipeline stage, mapped variables,
saved weight/model/prediction artifacts, and the recommended next step.
Use it before resuming work in an old dataset or after commands such as
{helpb msm_prepare}, {helpb msm_weight}, {helpb msm_fit}, or
{helpb msm_predict}.


{marker scope}{...}
{title:Current scope and limits}

{phang}
{bf:Static strategies only.} The standardized prediction workflow is built
for always-treated, never-treated, or both. Dynamic or stochastic treatment
regimes are not implemented in the current release.

{phang}
{bf:Prediction requires pooled logistic MSMs.} Run {cmd:msm_fit, model(logistic)}
before {helpb msm_predict}. Linear and Cox models can be estimated, but
prediction is not available for them.

{phang}
{bf:Prediction covariates must be time-fixed.} If you include
{cmd:outcome_cov()} in {helpb msm_fit} and then call {helpb msm_predict},
those covariates must be constant within {cmd:id}; prediction standardizes
them at the baseline/reference-population values.

{phang}
{bf:Common baseline required for weighting.} {helpb msm_weight} assumes all
individuals enter at the same baseline period and currently rejects delayed
entry.

{phang}
{bf:Observed follow-up is the default prediction horizon.} {helpb msm_predict}
rejects out-of-range {cmd:times()} values unless you explicitly request
{cmd:extrapolate}.


{marker examples}{...}
{title:Examples}

{pstd}Prediction-ready end-to-end workflow{p_end}
{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults aged 18-65 with condition X")}{p_end}
{phang2}{cmd:    treatment("Always treat vs. never treat")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("Binary clinical endpoint")}{p_end}
{phang2}{cmd:    causal_contrast("ATE: always treat vs. never treat")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE clustered by ID")}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_validate, strict verbose}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. msm_diagnose, balance_covariates(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    by_period threshold(0.1)}{p_end}
{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. msm_predict, times(3 5 7 9) difference seed(12345)}{p_end}
{phang2}{cmd:. msm_sensitivity, evalue}{p_end}
{phang2}{cmd:. msm_report, eform}{p_end}
{phang2}{cmd:. msm, status}{p_end}

{pstd}Estimation-only workflow when prediction is not needed{p_end}
{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(cox) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. msm_report, eform}{p_end}

{pstd}
Use the Cox or linear branches when the estimand is a weighted hazard ratio
or weighted mean difference, but do not expect those fits to work with
{cmd:msm_predict}.{p_end}


{marker references}{...}
{title:References}

{phang}
Robins JM, Hernan MA, Brumback B. Marginal structural models and causal
inference in epidemiology. {it:Epidemiology}. 2000;11(5):550-560.

{phang}
Hernan MA, Brumback B, Robins JM. Marginal structural models to estimate
the causal effect of zidovudine on the survival of HIV-positive men.
{it:Epidemiology}. 2000;11(5):561-570.

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational research:
introducing the E-value. {it:Annals of Internal Medicine}. 2017;167(4):268-274.

{phang}
Cole SR, Hernan MA. Constructing inverse probability weights for marginal
structural models. {it:American Journal of Epidemiology}. 2008;168(6):656-664.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of available commands{p_end}
{synopt:{cmd:r(prepared)}}1 if {cmd:msm_prepare} state is available; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(weighted)}}1 if saved weights are available; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(fitted)}}1 if a saved fit is available; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(prediction_saved)}}1 if saved prediction results are available; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(balance_saved)}}1 if saved balance results are available; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(diagnostics_saved)}}1 if saved diagnostics are available; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(sensitivity_saved)}}1 if saved sensitivity results are available; reported by {cmd:msm, status}{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version number{p_end}
{synopt:{cmd:r(commands)}}list of all msm commands{p_end}
{synopt:{cmd:r(stage)}}current pipeline stage; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(next_step)}}recommended next command; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(model)}}saved fitted model type, if any; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(id)}}mapped ID variable; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(period)}}mapped period variable; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(treatment)}}mapped treatment variable; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(outcome)}}mapped outcome variable; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(censor)}}mapped censoring variable, if any; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(covariates)}}mapped time-varying covariates; reported by {cmd:msm, status}{p_end}
{synopt:{cmd:r(baseline_covariates)}}mapped baseline covariates; reported by {cmd:msm, status}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
