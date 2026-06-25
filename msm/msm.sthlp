{smcl}
{* *! version 1.2.1  25jun2026}{...}
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
{viewerjumpto "When to use this package" "msm##when"}{...}
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
{synopt:{opt list}}display command names as a simple list{p_end}
{synopt:{opt detail}}show detailed descriptions of each command{p_end}
{synopt:{opt prot:ocol}}show the 7-component MSM protocol framework{p_end}
{synopt:{opt stat:us}}show current pipeline stage, mapped variables, and saved artifacts{p_end}
{synoptline}

{pstd}
With no options, {cmd:msm} displays the command overview and workflow guide.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm} is a comprehensive suite for estimating marginal structural models
using inverse probability of treatment weighting (IPTW) in longitudinal
person-period data.  It is designed for the common setting where treatment and
confounders both vary over time and where confounders are simultaneously
affected by past treatment and predictive of future treatment {hline 1} the
classic "treatment-confounder feedback" problem.

{pstd}
Standard regression adjustment (including fixed-effects and random-effects
models) cannot handle this structure without introducing bias.  IPTW solves
the problem by creating a pseudo-population where treatment is independent of
measured confounders, allowing a simple weighted outcome model to estimate the
causal effect.

{pstd}
The package covers the full analysis pipeline:

{phang2}1. {bf:Protocol specification} {hline 2} document the causal question{p_end}
{phang2}2. {bf:Data preparation} {hline 2} map variables and validate data{p_end}
{phang2}3. {bf:Weighting} {hline 2} stabilized IPTW and optional IPCW{p_end}
{phang2}4. {bf:Diagnostics} {hline 2} weight behavior and covariate balance{p_end}
{phang2}5. {bf:Estimation} {hline 2} weighted outcome model{p_end}
{phang2}6. {bf:Prediction} {hline 2} counterfactual standardization{p_end}
{phang2}7. {bf:Reporting} {hline 2} tables, plots, and sensitivity analysis{p_end}


{marker when}{...}
{title:When to use this package}

{pstd}
Use {cmd:msm} when your data have all of the following features:

{phang2}{bf:Longitudinal (panel) structure} with repeated observations per
individual over time.{p_end}

{phang2}{bf:Time-varying treatment} that can change between periods.{p_end}

{phang2}{bf:Time-varying confounders} that are affected by past treatment and
predictive of future treatment (treatment-confounder feedback).{p_end}

{phang2}{bf:Binary treatment and outcome indicators} (0/1).  Linear models use
the prepared binary outcome on the identity scale, and Cox models estimate
weighted hazard ratios.  The full prediction workflow currently requires a
binary outcome with a pooled logistic model.{p_end}

{pstd}
If your treatment is assigned at a single point in time (not time-varying),
consider Stata's built-in {helpb teffects ipw} instead.


{marker commands}{...}
{title:Commands}

{dlgtab:Data Preparation}

{phang}
{helpb msm_prepare} {hline 2} Map variables and store metadata.  Entry point
for the pipeline.

{phang}
{helpb msm_validate} {hline 2} Run 10 data quality checks for person-period
data.

{dlgtab:Core Engine}

{phang}
{helpb msm_weight} {hline 2} Estimate stabilized IPTW (+ optional IPCW for
informative censoring).

{phang}
{helpb msm_fit} {hline 2} Fit the weighted outcome model: pooled logistic
(GLM), linear, or Cox PH.

{phang}
{helpb msm_predict} {hline 2} Generate counterfactual predictions under
always-treated and never-treated strategies with Monte Carlo CIs.

{dlgtab:Diagnostics and Reporting}

{phang}
{helpb msm_diagnose} {hline 2} Inspect weight distribution and covariate
balance (SMD before/after weighting).

{phang}
{helpb msm_plot} {hline 2} Visualize weights, balance (Love plot), survival
curves, treatment trajectories, and positivity.

{phang}
{helpb msm_report} {hline 2} Compact publication-style results table (console,
CSV, or Excel).

{phang}
{helpb msm_table} {hline 2} Multi-sheet Excel workbook with all pipeline
results.

{phang}
{helpb msm_protocol} {hline 2} Document the MSM study protocol (7 components
adapted from Hernan et al.).

{phang}
{helpb msm_sensitivity} {hline 2} E-value and confounding strength bounds for
unmeasured confounding assessment.


{marker workflow}{...}
{title:Typical Workflow}

{p 4 4 2}
0. {helpb msm_protocol} {hline 1} Document the study design{break}
1. {helpb msm_prepare} {hline 1} Map variables and store metadata{break}
2. {helpb msm_validate} {hline 1} Check data quality (10 diagnostics){break}
3. {helpb msm_weight} {hline 1} Calculate stabilized IP weights{break}
4. {helpb msm_diagnose} {hline 1} Assess weight distribution and balance{break}
5. {helpb msm_fit} {hline 1} Fit the weighted outcome model{break}
6. {helpb msm_predict} {hline 1} Estimate counterfactual outcomes{break}
7. {helpb msm_plot} {hline 1} Visualize results{break}
8. {helpb msm_report} / {helpb msm_table} {hline 1} Export publication tables{break}
9. {helpb msm_sensitivity} {hline 1} Sensitivity analysis

{pstd}
Run {cmd:msm, status} at any point to see where the current dataset sits in
the pipeline, what outputs are available, and what the recommended next step is.

{pstd}
{bf:Plain-language command map.}  If you are new to MSMs, think of the
commands as a sequence of practical checks and outputs:

{phang2}{cmd:msm_prepare} tells the package what each column means.{p_end}

{phang2}{cmd:msm_validate} checks whether the person-period data are usable
before modeling.{p_end}

{phang2}{cmd:msm_weight} builds the weighted pseudo-population used for causal
estimation.{p_end}

{phang2}{cmd:msm_diagnose} checks whether those weights look stable and whether
covariate balance improved.{p_end}

{phang2}{cmd:msm_fit} estimates the treatment effect in the weighted data.{p_end}

{phang2}{cmd:msm_predict} translates a logistic MSM into absolute predicted
risks under always-treated and never-treated strategies.{p_end}

{phang2}{cmd:msm_report} and {cmd:msm_table} turn saved pipeline artifacts into
console, CSV, or Excel tables for reporting.{p_end}


{marker status}{...}
{title:Pipeline status}

{pstd}
{cmd:msm, status} is a lightweight introspection command.  It reads the stored
{cmd:_dta[_msm_*]} characteristics and saved artifacts already attached to the
dataset.  It does not fit models, recalculate anything, or modify the data.

{pstd}
The status report shows:

{phang2}The current pipeline stage (not prepared / prepared / weighted / fitted){p_end}
{phang2}The recommended next command{p_end}
{phang2}All mapped variables (ID, period, treatment, outcome, covariates){p_end}
{phang2}Available saved artifacts (weights, predictions, balance, diagnostics,
sensitivity){p_end}
{phang2}Summary details for each artifact (e.g., prediction type, balance
threshold, E-value){p_end}

{pstd}
Use it before resuming work in a saved dataset, after any pipeline step, or
whenever you are unsure what has been run.


{marker scope}{...}
{title:Current scope and limits}

{phang}
{bf:Static strategies only.}  The prediction workflow supports always-treated,
never-treated, or both.  Dynamic or stochastic treatment regimes are not
implemented.

{phang}
{bf:Prediction requires pooled logistic MSMs.}  Run
{cmd:msm_fit, model(logistic)} before {helpb msm_predict}.  Linear and Cox
models can be estimated, diagnosed, and reported, but prediction is not
available for them.

{phang}
{bf:Outcome-model covariates must be time-fixed.}  Any {cmd:outcome_cov()} in
{helpb msm_fit} must be constant within person.  Time-varying confounders
belong in the treatment and censoring weight models.

{phang}
{bf:Common baseline required.}  {helpb msm_weight} assumes all individuals
enter at the same baseline period.  Delayed entry / left truncation is not
supported.

{phang}
{bf:Observed follow-up is the default horizon.}  {helpb msm_predict} rejects
out-of-range {cmd:times()} unless {cmd:extrapolate} is specified.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Prediction-ready end-to-end workflow.}  This is the complete pipeline using
the bundled example dataset:{p_end}

{phang2}{cmd:. capture confirm file msm_example.dta}{p_end}
{phang2}{cmd:. if _rc net get msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace}{p_end}
{phang2}{cmd:. use msm_example.dta, clear}{p_end}
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

{pstd}
{bf:Estimation-only workflow.}  Use a Cox or linear model when prediction is
not needed:{p_end}

{phang2}{cmd:. capture confirm file msm_example.dta}{p_end}
{phang2}{cmd:. if _rc net get msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace}{p_end}
{phang2}{cmd:. use msm_example.dta, clear}{p_end}
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
{helpb msm_predict}.{p_end}


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
Cole SR, Hernan MA. Constructing inverse probability weights for marginal
structural models. {it:American Journal of Epidemiology}. 2008;168(6):656-664.

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational research:
introducing the E-value. {it:Annals of Internal Medicine}. 2017;167(4):268-274.

{phang}
Hernan MA, Robins JM. {it:Causal Inference: What If}. Boca Raton: Chapman &
Hall/CRC, 2020.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of available commands (11){p_end}

{pstd}
With {opt status}, the following additional results are stored:

{synopt:{cmd:r(prepared)}}1 if {helpb msm_prepare} state is available{p_end}
{synopt:{cmd:r(weighted)}}1 if saved weights are available{p_end}
{synopt:{cmd:r(fitted)}}1 if a saved fit is available{p_end}
{synopt:{cmd:r(prediction_saved)}}1 if prediction results are available{p_end}
{synopt:{cmd:r(balance_saved)}}1 if balance results are available{p_end}
{synopt:{cmd:r(diagnostics_saved)}}1 if diagnostic results are available{p_end}
{synopt:{cmd:r(sensitivity_saved)}}1 if sensitivity results are available{p_end}

{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version number{p_end}
{synopt:{cmd:r(commands)}}list of all msm commands{p_end}

{pstd}
With {opt status}:

{synopt:{cmd:r(stage)}}current pipeline stage{p_end}
{synopt:{cmd:r(next_step)}}recommended next command{p_end}
{synopt:{cmd:r(model)}}fitted model type, if any{p_end}
{synopt:{cmd:r(id)}}mapped ID variable{p_end}
{synopt:{cmd:r(period)}}mapped period variable{p_end}
{synopt:{cmd:r(treatment)}}mapped treatment variable{p_end}
{synopt:{cmd:r(outcome)}}mapped outcome variable{p_end}
{synopt:{cmd:r(censor)}}mapped censoring variable, if any{p_end}
{synopt:{cmd:r(covariates)}}mapped time-varying covariates{p_end}
{synopt:{cmd:r(baseline_covariates)}}mapped baseline covariates{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
