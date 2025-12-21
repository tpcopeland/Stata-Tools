{smcl}
{* *! version 1.0.0  21dec2025}{...}
{vieweralsosee "[TE] teffects" "help teffects"}{...}
{vieweralsosee "[R] logit" "help logit"}{...}
{viewerjumpto "Syntax" "iptw_diag##syntax"}{...}
{viewerjumpto "Description" "iptw_diag##description"}{...}
{viewerjumpto "Options" "iptw_diag##options"}{...}
{viewerjumpto "Remarks" "iptw_diag##remarks"}{...}
{viewerjumpto "Examples" "iptw_diag##examples"}{...}
{viewerjumpto "Stored results" "iptw_diag##results"}{...}
{viewerjumpto "Author" "iptw_diag##author"}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:iptw_diag} {hline 2}}IPTW weight diagnostics - distribution, ESS, extreme weights, trimming{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iptw_diag}
{it:wvar}
{ifin}{cmd:,}
{opt treat:ment(varname)}
[{it:options}]


{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{it:wvar}}IPTW weight variable{p_end}
{synopt:{opt treat:ment(varname)}}binary treatment indicator (0/1){p_end}

{syntab:Weight Modification}
{synopt:{opt trim(#)}}trim weights at specified percentile (50-99.9){p_end}
{synopt:{opt trunc:ate(#)}}truncate weights at maximum value{p_end}
{synopt:{opt stab:ilize}}calculate stabilized weights{p_end}
{synopt:{opt gen:erate(name)}}name for modified weight variable{p_end}
{synopt:{opt replace}}allow replacing existing variable{p_end}

{syntab:Display}
{synopt:{opt det:ail}}show detailed percentile distribution{p_end}

{syntab:Visualization}
{synopt:{opt gr:aph}}display weight distribution histogram{p_end}
{synopt:{opt saving(filename)}}save graph to file{p_end}
{synopt:{opt xlabel(numlist)}}custom x-axis labels for graph{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iptw_diag} provides comprehensive diagnostics for inverse probability of
treatment weights (IPTW). It assesses weight distribution, calculates effective
sample size, detects extreme weights, and provides weight trimming and
stabilization utilities.

{pstd}
The command calculates:

{phang2}{bf:Weight Distribution:} Mean, SD, min, max, and percentiles of weights
overall and by treatment group.

{phang2}{bf:Effective Sample Size (ESS):} Measures the effective number of
independent observations after weighting. Lower ESS indicates greater weight
variability and potential instability.

{phang2}{bf:Extreme Weights:} Counts observations with weights exceeding
common thresholds (10, 20).

{phang2}{bf:Coefficient of Variation:} SD/mean ratio measuring relative
weight variability.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{it:wvar} specifies the IPTW weight variable. Weights must be positive.

{phang}
{opt treatment(varname)} specifies the binary treatment indicator variable.
Must be coded as 0 (control) and 1 (treated).

{dlgtab:Weight Modification}

{phang}
{opt trim(#)} trims weights at the specified percentile. Weights above this
percentile are set to the percentile value. Valid range is 50-99.9. Commonly
used values are 95, 99, or 99.5.

{phang}
{opt truncate(#)} truncates weights at the specified maximum value. Weights
above this value are set to this value. Common choices are 10 or 20.

{phang}
{opt stabilize} creates stabilized weights by multiplying IPTW by the marginal
probability of treatment. Stabilized weights have mean closer to 1 and often
have better properties.

{phang}
{opt generate(name)} specifies the name for the modified weight variable.
Required when using {opt trim()}, {opt truncate()}, or {opt stabilize}.

{phang}
{opt replace} allows overwriting an existing variable when using {opt generate()}.

{dlgtab:Display}

{phang}
{opt detail} displays the full percentile distribution of weights (1st, 5th,
10th, 25th, 50th, 75th, 90th, 95th, 99th percentiles).

{dlgtab:Visualization}

{phang}
{opt graph} displays overlapping histograms of the weight distribution for
treated and control groups.

{phang}
{opt saving(filename)} saves the histogram to the specified file.

{phang}
{opt xlabel(numlist)} specifies custom x-axis labels for the histogram.
Default is "0 2 5 10 15 20".


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Effective Sample Size}

{pstd}
ESS = (sum of weights)^2 / (sum of weights squared)

{pstd}
ESS represents the equivalent number of equally-weighted observations.
If ESS is much smaller than N, weights are highly variable and estimates
may be unstable. Common guidance suggests:

{p2colset 8 30 32 2}{...}
{p2col:ESS > 50% of N}Acceptable{p_end}
{p2col:ESS 25-50% of N}Concerning{p_end}
{p2col:ESS < 25% of N}Problematic{p_end}

{pstd}
{bf:When to Trim or Truncate}

{pstd}
Extreme weights can cause bias and instability. Consider trimming when:

{phang2}• Maximum weight > 10-20{p_end}
{phang2}• CV > 1{p_end}
{phang2}• ESS < 50% of N{p_end}

{pstd}
{bf:Stabilized Weights}

{pstd}
Standard IPTW: w = 1/P(T|X) for treated, 1/(1-P(T|X)) for controls

{pstd}
Stabilized IPTW: w = P(T)/P(T|X) for treated, (1-P(T))/(1-P(T|X)) for controls

{pstd}
Stabilized weights have mean 1 and often smaller variance.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic diagnostics}

{phang2}{cmd:. webuse cattaneo2, clear}{p_end}
{phang2}{cmd:. logit mbsmoke mage medu fage}{p_end}
{phang2}{cmd:. predict ps, pr}{p_end}
{phang2}{cmd:. gen ipw = cond(mbsmoke==1, 1/ps, 1/(1-ps))}{p_end}
{phang2}{cmd:. iptw_diag ipw, treatment(mbsmoke)}{p_end}

{pstd}
{bf:Example 2: With detailed percentiles}

{phang2}{cmd:. iptw_diag ipw, treatment(mbsmoke) detail}{p_end}

{pstd}
{bf:Example 3: Trim at 99th percentile}

{phang2}{cmd:. iptw_diag ipw, treatment(mbsmoke) trim(99) generate(ipw_trim)}{p_end}

{pstd}
{bf:Example 4: Truncate at maximum value}

{phang2}{cmd:. iptw_diag ipw, treatment(mbsmoke) truncate(10) generate(ipw_trunc)}{p_end}

{pstd}
{bf:Example 5: Create stabilized weights}

{phang2}{cmd:. iptw_diag ipw, treatment(mbsmoke) stabilize generate(ipw_stab)}{p_end}

{pstd}
{bf:Example 6: With histogram}

{phang2}{cmd:. iptw_diag ipw, treatment(mbsmoke) graph saving(weights.png)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iptw_diag} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total number of observations{p_end}
{synopt:{cmd:r(N_treated)}}number in treatment group{p_end}
{synopt:{cmd:r(N_control)}}number in control group{p_end}
{synopt:{cmd:r(mean_wt)}}mean weight{p_end}
{synopt:{cmd:r(sd_wt)}}standard deviation of weights{p_end}
{synopt:{cmd:r(min_wt)}}minimum weight{p_end}
{synopt:{cmd:r(max_wt)}}maximum weight{p_end}
{synopt:{cmd:r(cv)}}coefficient of variation{p_end}
{synopt:{cmd:r(ess)}}effective sample size (overall){p_end}
{synopt:{cmd:r(ess_pct)}}ESS as percentage of N{p_end}
{synopt:{cmd:r(ess_treated)}}ESS for treated group{p_end}
{synopt:{cmd:r(ess_control)}}ESS for control group{p_end}
{synopt:{cmd:r(n_extreme)}}number of extreme weights (>10){p_end}
{synopt:{cmd:r(pct_extreme)}}percentage of extreme weights{p_end}
{synopt:{cmd:r(p1)}}1st percentile of weights{p_end}
{synopt:{cmd:r(p5)}}5th percentile of weights{p_end}
{synopt:{cmd:r(p95)}}95th percentile of weights{p_end}
{synopt:{cmd:r(p99)}}99th percentile of weights{p_end}

{pstd}
When {opt generate()} is used:

{synopt:{cmd:r(new_mean)}}mean of modified weights{p_end}
{synopt:{cmd:r(new_sd)}}SD of modified weights{p_end}
{synopt:{cmd:r(new_max)}}maximum of modified weights{p_end}
{synopt:{cmd:r(new_ess)}}ESS of modified weights{p_end}
{synopt:{cmd:r(new_ess_pct)}}ESS percentage of modified weights{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(wvar)}}weight variable name{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(generate)}}name of generated variable (if applicable){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2025-12-21{p_end}


{title:Also see}

{psee}
Manual:  {manlink TE teffects}

{psee}
Online:  {helpb balancetab}, {helpb effecttab}, {helpb teffects ipw}

{hline}
