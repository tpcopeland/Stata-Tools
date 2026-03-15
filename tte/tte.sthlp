{smcl}
{* *! version 1.2.0  15mar2026}{...}
{viewerjumpto "Syntax" "tte##syntax"}{...}
{viewerjumpto "Description" "tte##description"}{...}
{viewerjumpto "Commands" "tte##commands"}{...}
{viewerjumpto "Workflow" "tte##workflow"}{...}
{viewerjumpto "Examples" "tte##examples"}{...}
{viewerjumpto "References" "tte##references"}{...}
{viewerjumpto "Author" "tte##author"}{...}

{title:Title}

{phang}
{bf:tte} {hline 2} Target Trial Emulation suite for Stata


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt list}}display commands as simple list{p_end}
{synopt:{opt detail}}show detailed command descriptions{p_end}
{synopt:{opt pro:tocol}}show 7-component framework overview{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte} is a comprehensive suite for target trial emulation using
observational data. It implements the sequential trials framework
(Hernán & Robins, 2016) with the clone-censor-weight approach for
estimating per-protocol and intention-to-treat effects.

{pstd}
This is the first Stata implementation of the complete target trial
emulation workflow, featuring pooled logistic and Cox marginal structural
models, protocol table generation, weight/balance diagnostics, and
publication-ready reporting.


{marker commands}{...}
{title:Commands}

{dlgtab:Data Preparation}

{phang}
{helpb tte_prepare} {hline 2} Validate and map variables for analysis

{phang}
{helpb tte_validate} {hline 2} Data quality checks and diagnostics

{dlgtab:Core Analysis}

{phang}
{helpb tte_expand} {hline 2} Sequential trial expansion (clone-censor)

{phang}
{helpb tte_weight} {hline 2} Inverse probability weights (IPTW/IPCW)

{phang}
{helpb tte_fit} {hline 2} Outcome modeling (pooled logistic / Cox MSM)

{phang}
{helpb tte_predict} {hline 2} Marginal predictions with confidence intervals

{dlgtab:Diagnostics & Reporting}

{phang}
{helpb tte_diagnose} {hline 2} Weight diagnostics and balance assessment

{phang}
{helpb tte_plot} {hline 2} KM curves, cumulative incidence, weight plots

{phang}
{helpb tte_report} {hline 2} Publication-quality results tables

{phang}
{helpb tte_protocol} {hline 2} Target trial protocol table (Hernán 7-component)

{dlgtab:Sensitivity Analysis}

{phang}
{helpb tte_calibrate} {hline 2} Negative control outcome calibration (optional)


{marker workflow}{...}
{title:Typical Workflow}

{pstd}
1. {cmd:tte_prepare} - Map variables, set estimand (ITT/PP/AT){break}
2. {cmd:tte_validate} - Check data quality{break}
3. {cmd:tte_expand} - Create sequential emulated trials{break}
4. {cmd:tte_weight} - Calculate stabilized IP weights{break}
5. {cmd:tte_fit} - Fit marginal structural model{break}
6. {cmd:tte_predict} - Estimate cumulative incidence{break}
7. {cmd:tte_report} - Export publication tables


{marker examples}{...}
{title:Examples}

{pstd}Load example data{p_end}
{phang2}{cmd:. use tte_example, clear}{p_end}

{pstd}Per-protocol analysis{p_end}
{phang2}{cmd:. tte_prepare, id(patid) period(period) treatment(treatment) outcome(outcome) eligible(eligible) censor(censored) covariates(age sex comorbidity biomarker) estimand(PP)}{p_end}
{phang2}{cmd:. tte_validate}{p_end}
{phang2}{cmd:. tte_expand, maxfollowup(8) grace(1)}{p_end}
{phang2}{cmd:. tte_weight, switch_d_cov(age sex comorbidity biomarker) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. tte_fit, outcome_cov(age sex comorbidity) model(logistic) nolog}{p_end}
{phang2}{cmd:. tte_predict, times(0 2 4 6 8) type(cum_inc) difference samples(100) seed(12345)}{p_end}

{pstd}ITT analysis (simpler - no weights needed){p_end}
{phang2}{cmd:. use tte_example, clear}{p_end}
{phang2}{cmd:. tte_prepare, id(patid) period(period) treatment(treatment) outcome(outcome) eligible(eligible) estimand(ITT)}{p_end}
{phang2}{cmd:. tte_expand, maxfollowup(8)}{p_end}
{phang2}{cmd:. tte_fit, outcome_cov(age sex comorbidity) nolog}{p_end}


{marker references}{...}
{title:References}

{pstd}
Hernán MA, Robins JM. Using Big Data to Emulate a Target Trial When a
Randomized Trial Is Not Available. {it:Am J Epidemiol}. 2016;183(8):758-764.

{pstd}
Hernán MA, Robins JM. {it:Causal Inference: What If}. Boca Raton: Chapman & Hall/CRC; 2020.

{pstd}
Maringe C, Benitez Majano S, et al. TrialEmulation: An R Package for Target
Trial Emulation. {it:arXiv}. 2024;2402.12083.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet
