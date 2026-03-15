{smcl}
{* *! version 1.1.0  15mar2026}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "stcrprep" "help stcrprep"}{...}
{viewerjumpto "Syntax" "finegray##syntax"}{...}
{viewerjumpto "Description" "finegray##description"}{...}
{viewerjumpto "Options" "finegray##options"}{...}
{viewerjumpto "Remarks" "finegray##remarks"}{...}
{viewerjumpto "Examples" "finegray##examples"}{...}
{viewerjumpto "Stored results" "finegray##results"}{...}
{viewerjumpto "Author" "finegray##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:finegray} {hline 2}}Fine-Gray competing risks regression{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:finegray}
{varlist}
{ifin}{cmd:,}
{opt ev:ents(varname)}
{opt ca:use(#)}
[{it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth ev:ents(varname)}}event type variable (0=censored, 1, 2, ...){p_end}
{synopt:{opt ca:use(#)}}value of {it:events()} for cause of interest{p_end}

{syntab:Model}
{synopt:{opt wrapper}}use stcrprep + stcox wrapper mode instead of Mata engine{p_end}
{synopt:{opt censv:alue(#)}}censoring value in {it:events()}; default is {cmd:0}{p_end}
{synopt:{opth tvc(varlist)}}time-varying coefficients (triggers wrapper mode){p_end}
{synopt:{opth str:ata(varlist)}}stratification variables (triggers wrapper mode){p_end}
{synopt:{opth byg(varlist)}}stratify censoring distribution by groups{p_end}

{syntab:SE/Robust}
{synopt:{opth cl:uster(varname)}}adjust SEs for intragroup correlation{p_end}
{synopt:{opt rob:ust}}Huber/White/sandwich variance estimator{p_end}

{syntab:Reporting}
{synopt:{opt nohr}}report log subdistribution hazard ratios{p_end}
{synopt:{opt l:evel(#)}}set confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}

{syntab:Optimization (Mata engine)}
{synopt:{opt iter:ate(#)}}maximum iterations; default is {cmd:iterate(200)}{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance; default is {cmd:tolerance(1e-8)}{p_end}

{syntab:Advanced}
{synopt:{opt noshort:en}}do not collapse equal weights in stcrprep{p_end}
{synoptline}
{p 4 6 2}
Data must be {cmd:stset} with {cmd:id()}.  One observation per subject.
{p_end}

{pstd}
{bf:Post-estimation:}

{p 8 17 2}
{cmd:finegray_predict}
{newvar}
{ifin}{cmd:,}
[{opt cif} {opt xb} {opt timev:ar(varname)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray} fits the Fine and Gray (1999) subdistribution hazard model
for competing risks data.  It estimates subdistribution hazard ratios (SHR)
which quantify the effect of covariates on the cumulative incidence of a
cause of interest in the presence of competing events.

{pstd}
Two estimation modes are available:

{phang2}
{bf:Mata engine} (default) uses a native O(np) forward-backward
scan algorithm (Kawaguchi et al. 2020) that avoids data expansion entirely.
This is substantially faster than alternatives, especially for large datasets.

{phang2}
{bf:Wrapper mode} ({cmd:wrapper} option) automates the five-step
{cmd:stcrprep} + {cmd:stcox} workflow.  This mode is automatically activated
when {cmd:tvc()} or {cmd:strata()} are specified, as these features require
the underlying {cmd:stcox} engine.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth events(varname)} specifies the variable containing event types.
Typically coded as 0 = censored, 1 = cause 1, 2 = cause 2, etc.
Must be consistent with the {cmd:stset} failure indicator.

{phang}
{opt cause(#)} specifies which value of {it:events()} represents the
cause of interest.

{dlgtab:Model}

{phang}
{opt wrapper} requests the {cmd:stcrprep} + {cmd:stcox} wrapper mode
instead of the default Mata-native forward-backward scan estimator.
This is automatically activated when {cmd:tvc()} or {cmd:strata()} are
specified.

{phang}
{opt censvalue(#)} specifies the value in {it:events()} that represents
censoring.  Default is {cmd:0}.

{phang}
{opth tvc(varlist)} specifies variables that have time-varying coefficients.
Automatically triggers wrapper mode.

{phang}
{opth strata(varlist)} requests a stratified model.
Automatically triggers wrapper mode.

{phang}
{opth byg(varlist)} stratifies the censoring distribution estimation
by the specified variables.

{dlgtab:SE/Robust}

{phang}
{opth cluster(varname)} adjusts standard errors for intragroup correlation.

{phang}
{opt robust} specifies the Huber/White/sandwich estimator of variance.

{dlgtab:Reporting}

{phang}
{opt nohr} reports coefficients (log subdistribution hazard ratios) instead
of exponentiated coefficients (subdistribution hazard ratios).

{phang}
{opt level(#)} specifies the confidence level for confidence intervals.
Default is {cmd:level(95)}.

{phang}
{opt nolog} suppresses the iteration log.

{dlgtab:Optimization}

{phang}
{opt iterate(#)} specifies the maximum number of Newton-Raphson iterations
for the Mata engine. Default is {cmd:iterate(200)}.

{phang}
{opt tolerance(#)} specifies the convergence tolerance for the Mata engine.
Default is {cmd:tolerance(1e-8)}.

{dlgtab:Advanced}

{phang}
{opt noshorten} prevents {cmd:stcrprep} from collapsing observations with
equal weights, which can be useful for debugging.


{marker remarks}{...}
{title:Remarks}

{pstd}
The Fine-Gray model directly models the subdistribution hazard, which is
the instantaneous rate of failure from the cause of interest among subjects
who have not yet experienced that specific cause.  Subjects who experience
a competing event remain in the risk set indefinitely with time-dependent
weights derived from the Kaplan-Meier estimate of the censoring distribution.

{pstd}
{bf:Mata engine vs Wrapper mode:}  The default Mata engine implements
the Fine-Gray algorithm directly, avoiding data expansion.  It is typically
10-100x faster than alternatives.  The wrapper mode uses Lambert's
{cmd:stcrprep} to expand the data, then fits a weighted Cox model via
{cmd:stcox}.  Wrapper mode is required for {cmd:tvc()} and {cmd:strata()}
features and is activated automatically when those options are specified.

{pstd}
{bf:Interpretation:}  A subdistribution hazard ratio (SHR) > 1 indicates
that the covariate increases the cumulative incidence of the cause of
interest.  Unlike cause-specific hazard ratios, SHRs have a direct
interpretation in terms of the cumulative incidence function.

{pstd}
{bf:Reference:}  Fine JP, Gray RJ. A proportional hazards model for the
subdistribution of a competing risk. {it:JASA} 1999; 94(446): 496-509.

{pstd}
Kawaguchi ES, Shen JI, Suchard MA, Li G. Scalable estimation and inference
for censored quantile regression process. {it:Computational Statistics &
Data Analysis} 2020; 148: 106959.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup}

{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}

{pstd}
{bf:Default (Mata engine)}

{phang2}{cmd:. finegray ifp tumsize pelnode, events(status) cause(1)}{p_end}

{pstd}
{bf:Wrapper mode (stcrprep + stcox)}

{phang2}{cmd:. finegray ifp tumsize pelnode, events(status) cause(1) wrapper}{p_end}

{pstd}
{bf:With stratified censoring distribution}

{phang2}{cmd:. finegray ifp tumsize, events(status) cause(1) byg(pelnode)}{p_end}

{pstd}
{bf:Robust standard errors}

{phang2}{cmd:. finegray ifp tumsize pelnode, events(status) cause(1) robust}{p_end}

{pstd}
{bf:Log-SHR (no exponentiation)}

{phang2}{cmd:. finegray ifp tumsize pelnode, events(status) cause(1) nohr}{p_end}

{pstd}
{bf:CIF prediction}

{phang2}{cmd:. finegray ifp tumsize pelnode, events(status) cause(1)}{p_end}
{phang2}{cmd:. finegray_predict cif_hat, cif}{p_end}

{pstd}
{bf:Compare with stcrreg} (requires different stset)

{phang2}{cmd:. stset dftime, failure(status==1) id(stnum)}{p_end}
{phang2}{cmd:. stcrreg ifp tumsize pelnode, compete(status == 2)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of subjects{p_end}
{synopt:{cmd:e(N_sub)}}number of subjects{p_end}
{synopt:{cmd:e(N_fail)}}number of cause-of-interest events{p_end}
{synopt:{cmd:e(N_compete)}}number of competing events{p_end}
{synopt:{cmd:e(N_cens)}}number of censored observations{p_end}
{synopt:{cmd:e(N_expand)}}number of expanded observations (wrapper mode){p_end}
{synopt:{cmd:e(ll)}}log pseudo-likelihood{p_end}
{synopt:{cmd:e(ll_0)}}log pseudo-likelihood, constant-only model{p_end}
{synopt:{cmd:e(chi2)}}Wald chi-squared{p_end}
{synopt:{cmd:e(p)}}p-value for model chi-squared{p_end}
{synopt:{cmd:e(df_m)}}model degrees of freedom{p_end}
{synopt:{cmd:e(converged)}}1 if converged, 0 otherwise{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}
{synopt:{cmd:e(cause)}}cause of interest value{p_end}
{synopt:{cmd:e(censvalue)}}censoring value{p_end}
{synopt:{cmd:e(iterate)}}maximum iterations (Mata engine){p_end}
{synopt:{cmd:e(tolerance)}}convergence tolerance (Mata engine){p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:finegray}{p_end}
{synopt:{cmd:e(method)}}{cmd:wrapper} or {cmd:fast}{p_end}
{synopt:{cmd:e(predict)}}{cmd:finegray_predict}{p_end}
{synopt:{cmd:e(depvar)}}event variable name{p_end}
{synopt:{cmd:e(events)}}event variable name{p_end}
{synopt:{cmd:e(covariates)}}covariate variable names{p_end}
{synopt:{cmd:e(tvc)}}time-varying coefficient variables{p_end}
{synopt:{cmd:e(strata)}}stratification variables{p_end}
{synopt:{cmd:e(byg)}}censoring stratification variables{p_end}
{synopt:{cmd:e(clustvar)}}cluster variable{p_end}
{synopt:{cmd:e(vce)}}variance estimation method{p_end}
{synopt:{cmd:e(title)}}Fine-Gray competing risks regression{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector (log-SHR){p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix{p_end}
{synopt:{cmd:e(basehaz)}}baseline cumulative subhazard (time, cumhazard){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb stcrreg}, {helpb stcox}, {helpb stcrprep}, {helpb stset}

{hline}
