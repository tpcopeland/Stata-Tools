{smcl}
{* *! version 2.0.0  13oct2026}{...}
{vieweralsosee "msm_prepare" "help msm_prepare"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{viewerjumpto "Syntax" "msm##syntax"}{...}
{viewerjumpto "Options" "msm##options"}{...}
{viewerjumpto "Description" "msm##description"}{...}
{viewerjumpto "When to use this package" "msm##when"}{...}
{viewerjumpto "Commands" "msm##commands"}{...}
{viewerjumpto "Workflow" "msm##workflow"}{...}
{viewerjumpto "Companion packages" "msm##companions"}{...}
{viewerjumpto "Pipeline status" "msm##status"}{...}
{viewerjumpto "Current scope and limits" "msm##scope"}{...}
{viewerjumpto "Examples" "msm##examples"}{...}
{viewerjumpto "References" "msm##references"}{...}
{viewerjumpto "Stored results" "msm##results"}{...}
{viewerjumpto "Author" "msm##author"}{...}

{title:Title}

{phang}
{bf:msm} {hline 2} Marginal structural models for longitudinal causal analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt list}}display the command names as a simple list{p_end}
{synopt:{opt detail}}describe each command and the companion map{p_end}
{synopt:{opt stat:us}}show the pipeline stage and dataset artifacts{p_end}
{synoptline}

{pstd}
With no options, {cmd:msm} displays the command overview and the companion
map. At most one option may be given.


{marker options}{...}
{title:Options}

{phang}
{opt list} displays the names of the five estimator commands.

{phang}
{opt detail} displays a description of each command and the map from
reporting tasks to companion packages.

{phang}
{opt stat:us} reports the current pipeline stage, the mapped variables, the
weight and fit artifacts in the dataset, and the recommended next command. It
reads the dataset state without fitting models or modifying the data.

{pstd}
The {opt protocol} option was removed in msm 2.0.0 together with
{cmd:msm_protocol}; specifying it exits with return code 198.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm} estimates marginal structural models by inverse probability of
treatment weighting (IPTW) in longitudinal person-period data. It is designed
for the setting where treatment and confounders both vary over time and the
confounders are affected by past treatment and predict future treatment
{hline 1} the "treatment-confounder feedback" problem.

{pstd}
Regression adjustment for time-varying confounders affected by past treatment
can block mediated effects or induce collider bias. Under consistency,
sequential exchangeability, positivity, and adequate specification of the
treatment, censoring, and marginal outcome models, IPTW creates a weighted
pseudo-population in which treatment is independent of measured confounder
history, so the weighted outcome model identifies the specified marginal causal
effect.

{pstd}
The weight models add only the immediately prior treatment
automatically. Sequential exchangeability may require richer treatment and covariate
histories; construct the relevant lagged, cumulative, or trajectory summaries
and supply them to {helpb msm_weight}.

{pstd}
From version 2.0.0, {cmd:msm} is the estimator core: preparation, weighting,
longitudinal diagnostics, the weighted outcome model, and standardized
counterfactual prediction. Tables, pooled weight and balance diagnostics,
figures, and E-values come from companion packages that read the core's
output directly; see {help msm##companions:Companion packages}.

{pstd}
Temporary sorts preserve the caller's row order and sort keys, and guard
refusals preserve the caller's returned results.


{marker when}{...}
{title:When to use this package}

{pstd}
Use {cmd:msm} when your data have all of the following features:

{phang2}{bf:Longitudinal (panel) structure} with repeated observations per
individual over time.{p_end}

{phang2}{bf:Time-varying treatment} that can change between periods.{p_end}

{phang2}{bf:Time-varying confounders} that are affected by past treatment and
predictive of future treatment.{p_end}

{phang2}{bf:Binary treatment and outcome indicators} (0/1). Linear models use
the binary outcome on the identity scale, and Cox models estimate weighted
hazard ratios. Standardized prediction requires a pooled logistic model.{p_end}

{pstd}
If treatment is assigned at a single point in time, consider Stata's
{helpb teffects ipw} instead.


{marker commands}{...}
{title:Commands}

{p2colset 5 22 24 2}{...}
{p2col:{helpb msm_prepare}}map variables, refuse invalid person-period data, report data checks{p_end}
{p2col:{helpb msm_weight}}stabilized IPTW and optional IPCW{p_end}
{p2col:{helpb msm_diagnose}}balance by period and treatment history, censoring balance, positivity{p_end}
{p2col:{helpb msm_fit}}weighted pooled logistic, linear, or Cox outcome model{p_end}
{p2col:{helpb msm_predict}}standardized risks under always and never treated, risk differences{p_end}
{p2colreset}{...}

{pstd}
{cmd:msm_protocol}, {cmd:msm_validate}, {cmd:msm_plot}, {cmd:msm_report},
{cmd:msm_table}, {cmd:msm_diagtab} and {cmd:msm_sensitivity} were removed in
msm 2.0.0. Throughout msm 2.x they remain installed as stubs that print the
replacement listed below and exit with return code 199.


{marker workflow}{...}
{title:Workflow}

{p 4 4 2}
1. {helpb msm_prepare} {hline 1} map variables and check the data{break}
2. {helpb msm_weight} {hline 1} estimate stabilized IP weights{break}
3. {helpb msm_diagnose} {hline 1} longitudinal balance and positivity; pooled
weights and balance with {cmd:psdash}{break}
4. {helpb msm_fit} {hline 1} fit the weighted outcome model{break}
5. {helpb msm_predict} {hline 1} standardized counterfactual risks

{pstd}
Run {cmd:msm, status} at any point to see where the dataset sits in the
pipeline and what to run next. Re-running {cmd:msm_prepare} clears every
downstream weight and fit artifact.


{marker companions}{...}
{title:Companion packages}

{pstd}
Each task below reads {cmd:msm} output directly. The companion packages are
installed separately from Stata-Tools; the core needs none of them.

{phang2}{bf:Coefficient table} (was {cmd:msm_table},
{cmd:msm_report}): {cmd:collect: msm_fit ...} then {cmd:regtab} (tabtools){p_end}
{phang2}{bf:Risk-difference table}: {cmd:msm_predict, difference} then
{cmd:matrix RD = r(rd)} then {cmd:effecttab, from(RD)} (tabtools){p_end}
{phang2}{bf:Any returned matrix}: {cmd:puttab using} {it:file}{cmd:.xlsx, matrix(r(}{it:name}{cmd:))}
(tabtools){p_end}
{phang2}{bf:Weight distribution} (was
{cmd:msm_plot}): {cmd:psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) graph}{p_end}
{phang2}{bf:Pooled balance and Love plot}: {cmd:psdash balance treatment}
{cmd:_msm_ps if _msm_decision_risk, covariates(}{it:denominator covariates}{cmd:)}
{cmd:wvar(_msm_weight) loveplot}{p_end}
{phang2}{bf:Per-period weights and overlap}: {cmd:psdash combined} (reads the
msm contract; analysis weight by default){p_end}
{phang2}{bf:Risk-difference forest plot}: {cmd:msm_predict, ... frame(F)} then
{cmd:eplot if strategy == "rd", frame(F)} (eplot){p_end}
{phang2}{bf:Cumulative-incidence curve}: {cmd:twoway} on the {cmd:frame()}
rows; see {help msm_predict##curve:msm_predict}{p_end}
{phang2}{bf:Treatment trajectories}: {cmd:generate pstop = period + 1}, then
{cmd:swimlane, id(id) start(period) stop(pstop) state(treatment)} (swimlane){p_end}
{phang2}{bf:E-value} (was
{cmd:msm_sensitivity}): {cmd:qba_confound, from_model coef(treatment) evalue measure(HR)} (qba){p_end}
{phang2}{bf:Data checks} (was {cmd:msm_validate}): refusals and {cmd:r()} notes
in {helpb msm_prepare} and {helpb msm_weight}; positivity and periods without a
treatment contrast in {helpb msm_diagnose}{p_end}
{phang2}{bf:Protocol} (was {cmd:msm_protocol}): no replacement; record it in
the manuscript or a protocol document{p_end}
{phang2}{bf:Cross-contrast export} (was {cmd:msm_diagtab}): no
replacement; {cmd:frame post} the returns and export with {cmd:puttab, frame()}{p_end}

{pstd}
{bf:psdash after msm.} {cmd:psdash combined} (psdash 1.8.0 or later) detects
the msm contract (version 1.1 from msm 2.0.0), restricts every summary to the decision risk set named in
{cmd:_dta[_msm_risk_var]}, and diagnoses the analysis weight {cmd:_msm_weight}
that {cmd:msm_fit} uses unless {cmd:wvar()} names another. For the pooled
{cmd:psdash weights} and {cmd:psdash balance} calls, restrict to the risk set
with {cmd:if _msm_decision_risk} as shown above.

{pstd}
{bf:Balance targets.} Covariates in {cmd:treat_n_cov()} stay in the
stabilized-weight numerator, so weighting is not meant to balance them; pass
only the remaining denominator covariates to a pooled balance
plot; {cmd:msm_diagnose} marks numerator covariates {cmd:target=0}.

{pstd}
{bf:E-values.} A pooled-logistic odds ratio from {cmd:msm_fit} is a ratio of
per-period odds and approximates a discrete-time hazard ratio when the
per-period risk is small, hence {cmd:measure(HR)}. Add {cmd:commonoutcome}
when the cumulative incidence at the end of follow-up (for example from
{cmd:msm_predict}) is 15% or more; {help qba_confound} documents both choices
and the bounding factor.


{marker status}{...}
{title:Pipeline status}

{pstd}
{cmd:msm, status} reads the {cmd:_dta[_msm_*]} characteristics and verifies
each stage the same way the commands do before using it. It reports the
current stage (not prepared, prepared, weighted, fitted), the recommended next
command, the mapped variables, and the weight variables and fit artifacts in
the dataset. {cmd:msm_diagnose} and {cmd:msm_predict} return their results in
{cmd:r()} (and {cmd:frame()}) and write nothing to the dataset, so they do not
appear in the status report.


{marker scope}{...}
{title:Current scope and limits}

{phang}
{bf:Static strategies only.} Prediction supports always treated, never
treated, or both. Dynamic or stochastic regimes are not implemented.

{phang}
{bf:Prediction requires a pooled logistic MSM.} Linear and Cox fits are
reported from {cmd:e()}; {helpb msm_predict} refuses them.

{phang}
{bf:Outcome-model covariates must be time-fixed.} Time-varying confounders
belong in the treatment and censoring weight models.

{phang}
{bf:Common baseline required.} {helpb msm_weight} refuses delayed entry.

{phang}
{bf:Observed follow-up is the default horizon.} {helpb msm_predict} refuses
{cmd:times()} beyond the fitted risk-set support unless {cmd:extrapolate} is
specified.

{phang}
{bf:Intervals are conditional on the weights.} {cmd:msm_fit} standard errors
and {cmd:msm_predict} Monte Carlo intervals do not propagate weight-model
estimation.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Prediction-ready workflow} on the bundled example data, with informative
censoring:{p_end}

{phang2}{cmd:. capture confirm file msm_example.dta}{p_end}
{phang2}{cmd:. if _rc net get msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace}{p_end}
{phang2}{cmd:. use msm_example.dta, clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)}{p_end}
{phang2}{cmd:    censor(censored) covariates(biomarker comorbidity) baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex)}{p_end}
{phang2}{cmd:    censor_d_cov(biomarker comorbidity age sex) censor_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. msm_diagnose, threshold(0.1)}{p_end}
{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog}{p_end}
{phang2}{cmd:. msm_predict, times(3 5 7 9) difference samples(500) seed(12345) frame(pred, replace)}{p_end}
{phang2}{cmd:. msm, status}{p_end}

{pstd}
{bf:Estimation-only workflow.} A Cox MSM for a weighted hazard ratio:{p_end}

{phang2}{cmd:. use msm_example.dta, clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)}{p_end}
{phang2}{cmd:    covariates(biomarker comorbidity) baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) nolog}{p_end}
{phang2}{cmd:. msm_fit, model(cox) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. stcox, hr}{p_end}

{pstd}
The companion-package calls for these results are listed under
{help msm##companions:Companion packages}.{p_end}


{marker references}{...}
{title:References}

{phang}
Robins JM, Hernan MA, Brumback B. Marginal structural models and causal
inference in epidemiology. {it:Epidemiology}. 2000;11(5):550-560. doi:10.1097/00001648-200009000-00011.

{phang}
Hernan MA, Brumback B, Robins JM. Marginal structural models to estimate the
causal effect of zidovudine on the survival of HIV-positive
men. {it:Epidemiology}. 2000;11(5):561-570. doi:10.1097/00001648-200009000-00012.

{phang}
Cole SR, Hernan MA. Constructing inverse probability weights for marginal
structural models. {it:American Journal of Epidemiology}. 2008;168(6):656-664. doi:10.1093/aje/kwn164.

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational
research: introducing the
E-value. {it:Annals of Internal Medicine}. 2017;167(4):268-274. doi:10.7326/m16-2607.

{phang}
Hernan MA, Robins JM. {it:Causal Inference: What If}. Boca Raton: Chapman &
Hall/CRC, 2020.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of estimator commands (5){p_end}

{pstd}
With {opt status}, the following additional scalars are stored:

{synopt:{cmd:r(prepared)}}1 if a verified {cmd:msm_prepare} state exists{p_end}
{synopt:{cmd:r(weighted)}}1 if verified weights exist{p_end}
{synopt:{cmd:r(fitted)}}1 if a verified fit exists{p_end}

{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version number{p_end}
{synopt:{cmd:r(commands)}}the five estimator commands{p_end}
{synopt:{cmd:r(removed)}}the seven commands removed in 2.0.0{p_end}

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

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 2.0.0, 2026-10-13{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}

{pstd}Check GitHub for the most up-to-date release; it may be newer than the version installed here.{p_end}

{hline}
