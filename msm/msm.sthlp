{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm##syntax"}{...}
{viewerjumpto "Description" "msm##description"}{...}
{viewerjumpto "Commands" "msm##commands"}{...}
{viewerjumpto "Workflow" "msm##workflow"}{...}
{viewerjumpto "Examples" "msm##examples"}{...}
{viewerjumpto "References" "msm##references"}{...}
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
{synopt:{opt pro:tocol}}show MSM protocol framework{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm} is a comprehensive suite for marginal structural model estimation
using inverse probability of treatment weighting (IPTW) for time-varying
treatments and confounders. It implements the complete IPTW pipeline:
data preparation, weight calculation, diagnostics, outcome modeling,
counterfactual prediction, and sensitivity analysis.

{pstd}
Unlike point-in-time treatment effect estimators ({cmd:teffects ipw}),
{cmd:msm} handles the key challenge of time-varying treatment-confounder
feedback where confounders are simultaneously affected by past treatment
and predictive of future treatment. Standard regression adjustment cannot
handle this structure; IPTW creates a pseudo-population where treatment
is independent of measured confounders.


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
{helpb msm_fit} {hline 2} Weighted outcome model (pooled logistic/Cox)

{phang}
{helpb msm_predict} {hline 2} Counterfactual predictions with CIs

{dlgtab:Diagnostics and Reporting}

{phang}
{helpb msm_diagnose} {hline 2} Weight distribution and covariate balance

{phang}
{helpb msm_plot} {hline 2} Weight, balance, survival, trajectory plots

{phang}
{helpb msm_report} {hline 2} Publication-quality results tables

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


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. use msm_example.dta}{p_end}

{pstd}Prepare data{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}

{pstd}Validate{p_end}
{phang2}{cmd:. msm_validate, verbose}{p_end}

{pstd}Calculate weights{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}Diagnose{p_end}
{phang2}{cmd:. msm_diagnose, by_period threshold(0.1)}{p_end}

{pstd}Fit model{p_end}
{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}

{pstd}Predict{p_end}
{phang2}{cmd:. msm_predict, times(3 5 7 9) difference seed(12345)}{p_end}

{pstd}Sensitivity{p_end}
{phang2}{cmd:. msm_sensitivity, evalue}{p_end}


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


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
