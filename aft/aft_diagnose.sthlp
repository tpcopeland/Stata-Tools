{smcl}
{* *! version 1.0.0  14mar2026}{...}
{vieweralsosee "[ST] streg postestimation" "help streg postestimation"}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_fit" "help aft_fit"}{...}
{viewerjumpto "Syntax" "aft_diagnose##syntax"}{...}
{viewerjumpto "Description" "aft_diagnose##description"}{...}
{viewerjumpto "Options" "aft_diagnose##options"}{...}
{viewerjumpto "Remarks" "aft_diagnose##remarks"}{...}
{viewerjumpto "Examples" "aft_diagnose##examples"}{...}
{viewerjumpto "Stored results" "aft_diagnose##results"}{...}
{viewerjumpto "Author" "aft_diagnose##author"}{...}
{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:aft_diagnose} {hline 2}}AFT model diagnostics{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_diagnose}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Diagnostics}
{synopt:{opt cox:snell}}Cox-Snell residual plot{p_end}
{synopt:{opt qq:plot}}observed vs predicted Q-Q plot{p_end}
{synopt:{opt kmo:verlay}}Kaplan-Meier vs AFT survival overlay{p_end}
{synopt:{opt dist:plot}}distribution-specific linear diagnostic{p_end}
{synopt:{opt gof:stat}}goodness-of-fit statistics (AIC, BIC){p_end}
{synopt:{opt all}}all diagnostics{p_end}

{syntab:Plot options}
{synopt:{opt by(varname)}}stratify KM overlay by groups{p_end}
{synopt:{opt sav:ing(stub)}}save graphs as {it:stub}_diagnostic.png{p_end}
{synopt:{opt name(passthru)}}graph name prefix{p_end}
{synopt:{opt scheme(passthru)}}graph scheme; default is {cmd:plotplainblind}{p_end}
{synoptline}

{pstd}
Requires {cmd:aft_fit} to have been run. Data must remain {cmd:stset}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_diagnose} produces diagnostic plots and goodness-of-fit statistics
for the most recently fitted AFT model.

{pstd}
If no diagnostic is specified, {cmd:gofstat} is shown by default.


{marker options}{...}
{title:Options}

{dlgtab:Diagnostics}

{phang}
{opt coxsnell} plots Cox-Snell residuals against their estimated cumulative
hazard. For a well-fitting model, points follow the 45-degree line.

{phang}
{opt qqplot} plots observed vs AFT-predicted failure times. Points on the
45-degree line indicate good fit.

{phang}
{opt kmoverlay} overlays the Kaplan-Meier survival curve with AFT-predicted
survival. Visual agreement indicates adequate fit.

{phang}
{opt distplot} produces distribution-specific linear diagnostic plots:
log(-log(S)) vs log(t) for Weibull, Phi^-1(F) vs log(t) for lognormal,
log-odds vs log(t) for log-logistic, -log(S) vs t for exponential.

{phang}
{opt gofstat} displays AIC, BIC, log-likelihood, and number of parameters.

{phang}
{opt all} produces all five diagnostics.

{dlgtab:Plot options}

{phang}
{opt by(varname)} stratifies the KM overlay by a grouping variable.

{phang}
{opt saving(stub)} saves graph files as {it:stub}_coxsnell.png, etc.

{phang}
{opt scheme(schemename)} specifies the graph scheme. Default is
{cmd:plotplainblind}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Cox-Snell residuals}

{pstd}
If the model is correctly specified, Cox-Snell residuals follow a unit
exponential distribution. The plot compares estimated cumulative hazard
of the residuals against a 45-degree reference line. Departures indicate
model misspecification.

{pstd}
{bf:Distribution-specific plots}

{pstd}
Each AFT distribution implies a specific linear relationship when
survival is transformed appropriately. Linearity in these plots supports
the distributional assumption. Weibull: log(-log(S)) vs log(t).
Lognormal: probit(F) vs log(t). Log-logistic: log(S/(1-S)) vs log(t).
Exponential: -log(S) vs t.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: GOF statistics only}

{phang2}{cmd:. aft_diagnose}{p_end}

{pstd}
{bf:Example 2: All diagnostics}

{phang2}{cmd:. aft_diagnose, all}{p_end}

{pstd}
{bf:Example 3: Cox-Snell residuals with saving}

{phang2}{cmd:. aft_diagnose, coxsnell saving(mymodel)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_diagnose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(ll)}}log-likelihood{p_end}
{synopt:{cmd:r(k)}}number of parameters{p_end}
{synopt:{cmd:r(aic)}}Akaike information criterion{p_end}
{synopt:{cmd:r(bic)}}Bayesian information criterion{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(dist)}}distribution{p_end}
{synopt:{cmd:r(diagnostics)}}diagnostics produced{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-14{p_end}


{title:Also see}

{psee}
Manual:  {manlink ST streg postestimation}

{psee}
Online:  {helpb aft}, {helpb aft_fit}, {helpb aft_compare}

{hline}
