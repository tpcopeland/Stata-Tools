{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "[TE] teffects aipw" "help teffects aipw"}{...}
{viewerjumpto "Syntax" "drest##syntax"}{...}
{viewerjumpto "Description" "drest##description"}{...}
{viewerjumpto "Options" "drest##options"}{...}
{viewerjumpto "Commands" "drest##commands"}{...}
{viewerjumpto "Examples" "drest##examples"}{...}
{viewerjumpto "Author" "drest##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:drest} {hline 2}}Doubly Robust Estimation for Stata{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest}
[{cmd:,}
{opt l:ist}
{opt d:etail}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest} provides doubly robust causal inference estimators for Stata.
The current version implements augmented inverse probability weighting
(AIPW), which combines an outcome model and a treatment model to provide
consistent estimation of average treatment effects when {it:either} model
is correctly specified.

{pstd}
The package supports ATE, ATT, and ATC estimands with flexible model
specifications, influence-function-based standard errors, diagnostics,
method comparison, bootstrap inference, and sensitivity analysis.

{pstd}
The typical workflow is:

{phang2}1. {cmd:drest_estimate} {hline 2} Fit AIPW (outcome + treatment models)

{phang2}2. {cmd:drest_diagnose} {hline 2} Check overlap, balance, influence

{phang2}3. {cmd:drest_compare} {hline 2} Compare IPTW / g-computation / AIPW

{phang2}4. {cmd:drest_plot} {hline 2} Visualize diagnostics

{phang2}5. {cmd:drest_report} {hline 2} Export results

{phang2}6. {cmd:drest_sensitivity} {hline 2} E-value for unmeasured confounding


{marker options}{...}
{title:Options}

{phang}
{opt list} displays a simple list of available commands.

{phang}
{opt detail} displays detailed descriptions of each command.


{marker commands}{...}
{title:Commands}

{synoptset 22 tabbed}{...}
{synopthdr:Command}
{synoptline}
{syntab:Estimation}
{synopt:{helpb drest_estimate}}AIPW doubly robust estimation (ATE/ATT/ATC){p_end}
{synopt:{helpb drest_crossfit}}cross-fitted AIPW (DML-style, K-fold){p_end}
{synopt:{helpb drest_tmle}}targeted minimum loss-based estimation{p_end}
{synopt:{helpb drest_ltmle}}longitudinal TMLE (time-varying treatments){p_end}

{syntab:Diagnostics}
{synopt:{helpb drest_diagnose}}overlap, propensity, influence, balance{p_end}
{synopt:{helpb drest_compare}}side-by-side IPTW vs g-computation vs AIPW{p_end}
{synopt:{helpb drest_sensitivity}}E-value sensitivity analysis{p_end}

{syntab:Post-estimation}
{synopt:{helpb drest_predict}}potential outcome predictions{p_end}
{synopt:{helpb drest_bootstrap}}bootstrap inference{p_end}

{syntab:Output}
{synopt:{helpb drest_plot}}overlap, influence, treatment effect plots{p_end}
{synopt:{helpb drest_report}}summary tables (display or Excel){p_end}
{synoptline}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Basic AIPW estimation}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. gen byte highmpg = (mpg > 20)}{p_end}
{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}

{pstd}
{bf:With separate model specifications}

{phang2}{cmd:. drest_estimate, outcome(price) treatment(foreign) omodel(weight length mpg) tmodel(weight length) ofamily(regress) tfamily(logit)}{p_end}

{pstd}
{bf:Full diagnostic workflow}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_diagnose, all graph}{p_end}
{phang2}{cmd:. drest_compare weight length, outcome(price) treatment(foreign) graph}{p_end}
{phang2}{cmd:. drest_sensitivity, evalue}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb drest_estimate}, {helpb drest_diagnose}, {helpb drest_compare},
{helpb teffects aipw}

{hline}
