{smcl}
{* *! version 1.1.0  15mar2026}{...}
{vieweralsosee "[ST] streg" "help streg"}{...}
{vieweralsosee "[ST] sts test" "help sts_test"}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_counterfactual" "help aft_counterfactual"}{...}
{viewerjumpto "Syntax" "aft_rpsftm##syntax"}{...}
{viewerjumpto "Description" "aft_rpsftm##description"}{...}
{viewerjumpto "Options" "aft_rpsftm##options"}{...}
{viewerjumpto "Remarks" "aft_rpsftm##remarks"}{...}
{viewerjumpto "Examples" "aft_rpsftm##examples"}{...}
{viewerjumpto "Stored results" "aft_rpsftm##results"}{...}
{viewerjumpto "Author" "aft_rpsftm##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:aft_rpsftm} {hline 2}}Rank-Preserving Structural Failure Time Model{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_rpsftm}
{ifin}
{cmd:,}
{opt rand:omization(varname)}
{opt treat:ment(varname)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt rand:omization(varname)}}binary randomization arm (0/1){p_end}
{synopt:{opt treat:ment(varname)}}treatment received indicator (0/1){p_end}

{syntab:Treatment exposure}
{synopt:{opt treatt:ime(varname)}}cumulative time on active treatment{p_end}

{syntab:Grid search}
{synopt:{opt gridr:ange(# #)}}search range for psi; default is {cmd:gridrange(-2 2)}{p_end}
{synopt:{opt gridp:oints(#)}}number of grid points; default is 200{p_end}

{syntab:Test}
{synopt:{opt testt:ype(string)}}test for independence: {bf:logrank} (default) or {bf:wilcoxon}{p_end}
{synopt:{opt rec:ensor}}apply re-censoring (recommended){p_end}

{syntab:Inference}
{synopt:{opt boot:strap}}compute bootstrap standard errors{p_end}
{synopt:{opt reps(#)}}bootstrap replications; default is 1000{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt l:evel(#)}}confidence level; default is {cmd:level(95)}{p_end}

{syntab:Reporting}
{synopt:{opt pl:ot}}plot Z(psi) curve{p_end}
{synopt:{opt sav:ing(filename)}}save grid results to file{p_end}
{synopt:{opt sch:eme(schemename)}}graph scheme{p_end}
{synopt:{opt nolog}}suppress progress display{p_end}
{synoptline}

{pstd}
Data must be {cmd:stset}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_rpsftm} estimates the causal acceleration factor using the
Rank-Preserving Structural Failure Time Model (RPSFTM), a g-estimation
method for randomized trials with treatment switching.

{pstd}
In an RCT where control-arm patients cross over to the experimental
treatment, the intention-to-treat (ITT) analysis underestimates the true
treatment effect. The RPSFTM adjusts for this by finding the acceleration
factor psi such that counterfactual untreated survival times are
independent of randomization arm.

{pstd}
The method performs a grid search over candidate psi values. For each psi,
counterfactual untreated times are computed as U_i = T_i * exp(-psi * d_i),
where d_i is the proportion of time on treatment. A log-rank (or Wilcoxon)
test is run on U by randomization arm. The psi where the test statistic
crosses zero is the point estimate. Confidence intervals are obtained by
inverting the test at the critical value.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt randomization(varname)} specifies the binary (0/1) randomization arm
variable. 1 = experimental arm, 0 = control arm.

{phang}
{opt treatment(varname)} specifies the treatment received indicator. For
binary treatment (on/off), code as 0/1. For partial treatment exposure,
specify a proportion in [0, 1].

{dlgtab:Treatment exposure}

{phang}
{opt treattime(varname)} specifies cumulative time on active treatment. When
provided, treatment exposure is computed as {it:treattime}/_t. Use this when
treatment duration varies among subjects.

{dlgtab:Grid search}

{phang}
{opt gridrange(# #)} specifies the search range for psi. Default is
{cmd:gridrange(-2 2)}. Widen this if the true effect is large.

{phang}
{opt gridpoints(#)} specifies the number of grid points. Default is 200.
More points give finer resolution but take longer.

{dlgtab:Test}

{phang}
{opt testtype(string)} specifies the independence test. {bf:logrank} (default)
is most powerful under proportional hazards. {bf:wilcoxon} gives more weight
to early events.

{phang}
{opt recensor} applies re-censoring to prevent informative censoring under
the counterfactual scenario. Recommended when administrative censoring is
present.

{dlgtab:Inference}

{phang}
{opt bootstrap} computes bootstrap standard errors by resampling subjects
(stratified by arm) and repeating the grid search. This is computationally
intensive.

{phang}
{opt reps(#)} specifies the number of bootstrap replications. Default is 1000.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{dlgtab:Reporting}

{phang}
{opt plot} produces a plot of the Z(psi) curve with horizontal reference
lines at 0 and the critical values, and vertical lines at the point estimate
and CI bounds.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Assumptions.} The RPSFTM assumes: (1) randomization is valid
(no unmeasured confounding of arm assignment); (2) the acceleration factor
is common to all subjects (rank preservation); (3) treatment effect acts
multiplicatively on survival time.

{pstd}
{bf:Re-censoring.} Without re-censoring, administrative censoring can
become informative under the counterfactual. The {opt recensor} option is
strongly recommended when the study has a fixed end date.

{pstd}
{bf:Validation.} Results should be validated against the R {bf:rpsftm}
package on the same dataset to ensure correctness.

{pstd}
{bf:After estimation.} Use {helpb aft_counterfactual} to visualize
counterfactual survival curves and compute RMST comparisons.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic RPSFTM}

{phang2}{cmd:. stset os_time, failure(os_event)}{p_end}
{phang2}{cmd:. aft_rpsftm, randomization(arm) treatment(treated) recensor}{p_end}

{pstd}
{bf:Example 2: With treatment time and bootstrap}

{phang2}{cmd:. aft_rpsftm, randomization(arm) treatment(treated)}{p_end}
{phang2}{cmd:    treattime(time_on_drug) bootstrap reps(500) seed(12345)}{p_end}

{pstd}
{bf:Example 3: With Z-curve plot}

{phang2}{cmd:. aft_rpsftm, randomization(arm) treatment(treated) plot}{p_end}
{phang2}{cmd:. aft_counterfactual, plot}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_rpsftm} stores the following in {cmd:e()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:e(psi)}}acceleration factor (log scale){p_end}
{synopt:{cmd:e(af)}}acceleration factor exp(psi){p_end}
{synopt:{cmd:e(se_psi)}}standard error of psi{p_end}
{synopt:{cmd:e(ci_lo)}}lower CI bound for psi{p_end}
{synopt:{cmd:e(ci_hi)}}upper CI bound for psi{p_end}
{synopt:{cmd:e(af_lo)}}lower CI bound for exp(psi){p_end}
{synopt:{cmd:e(af_hi)}}upper CI bound for exp(psi){p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}
{synopt:{cmd:e(n_events)}}number of events{p_end}
{synopt:{cmd:e(n_switched)}}number of treatment switches{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:aft_rpsftm}{p_end}
{synopt:{cmd:e(testtype)}}independence test used{p_end}
{synopt:{cmd:e(randomization)}}randomization variable{p_end}
{synopt:{cmd:e(treatment)}}treatment variable{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector (psi){p_end}
{synopt:{cmd:e(V)}}variance matrix{p_end}
{synopt:{cmd:e(grid)}}grid search results (psi x Z){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-03-15{p_end}

{pstd}
{bf:Reference:} White IR, Babiker AG, Walker S, Darbyshire JH. Randomization-based
methods for correcting for treatment changes: examples from the Concorde trial.
{it:Statistics in Medicine} 1999;18:2617-2634.


{title:Also see}

{psee}
Manual:  {manlink ST streg}, {manlink ST sts test}

{psee}
Online:  {helpb aft}, {helpb aft_counterfactual}

{hline}
