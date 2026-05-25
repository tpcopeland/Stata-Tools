{smcl}
{* *! version 1.2.1  25may2026}{...}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "iivw_exogtest" "help iivw_exogtest"}{...}
{viewerjumpto "Syntax" "iivw_diagnose##syntax"}{...}
{viewerjumpto "Description" "iivw_diagnose##description"}{...}
{viewerjumpto "Options" "iivw_diagnose##options"}{...}
{viewerjumpto "Estimand restriction" "iivw_diagnose##estimand"}{...}
{viewerjumpto "Formula" "iivw_diagnose##formula"}{...}
{viewerjumpto "Interpreting results" "iivw_diagnose##interpreting"}{...}
{viewerjumpto "Reporting guidance" "iivw_diagnose##reporting"}{...}
{viewerjumpto "Examples" "iivw_diagnose##examples"}{...}
{viewerjumpto "Stored results" "iivw_diagnose##results"}{...}
{viewerjumpto "References" "iivw_diagnose##references"}{...}
{viewerjumpto "Author" "iivw_diagnose##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:iivw_diagnose} {hline 2}}Compare stored estimates for IIVW diagnostic decomposition{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_diagnose}
{it:coefficient}{cmd:,}
{opt unw:eighted(estname)}
{opt we:ighted(estname)}
{opt ad:justed(estname)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt unw:eighted(estname)}}stored unweighted outcome model{p_end}
{synopt:{opt we:ighted(estname)}}stored IIVW/FIPTIW-weighted outcome model{p_end}
{synopt:{opt ad:justed(estname)}}stored weighted model with measurement-process adjustment{p_end}
{synopt:{opt ex:ogeneity(string)}}{cmd:exogenous}, {cmd:endogenous}, or {cmd:unknown}; default is {cmd:unknown}{p_end}
{synopt:{opt est:imand(string)}}{cmd:marginal} or {cmd:contrast}; default is {cmd:marginal}{p_end}
{synopt:{opt tr:ue(#)}}known true value, mainly for simulations{p_end}
{synopt:{opt l:evel(#)}}confidence level for coefficient intervals; default is {cmd:95}{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_diagnose} compares three stored estimates of the same coefficient:
an unweighted estimate, an IIVW/FIPTIW-weighted estimate, and a weighted
estimate that also adjusts directly for a measurement-process variable such
as cumulative test number.

{pstd}
The decomposition is intended for the marginal or reference-arm time slope.
This is the estimand for which the sampling/artifact split used in the IIVW
diagnostic framework is meaningful.  Use {cmd:estimand(contrast)} only for a
movement summary; the command suppresses sampling and artifact shares for
treatment contrasts.

{pstd}
The command reads stored estimation results created with
{cmd:estimates store}.  The estimates may come from {cmd:iivw_fit} or from
ordinary Stata estimation commands such as {cmd:regress} or {cmd:glm}, as long
as the requested coefficient is present in all three models.


{marker options}{...}
{title:Options}

{phang}
{opt unweighted(estname)} specifies the stored unweighted model.

{phang}
{opt weighted(estname)} specifies the stored IIVW, IPTW, or FIPTIW weighted
model.

{phang}
{opt adjusted(estname)} specifies the stored weighted model that additionally
adjusts for the measurement process.

{phang}
{opt exogeneity(string)} controls interpretation of the measurement-process
adjustment.  {cmd:exogenous} reports the shares as a point diagnostic under
additive separability.  {cmd:unknown} reports them as descriptive only.
{cmd:endogenous} treats the weighted and adjusted estimates as a diagnostic
range because direct adjustment may over-correct.

{phang}
{opt estimand(string)} specifies whether {it:coefficient} is a
{cmd:marginal} or {cmd:contrast} estimand.  The default is {cmd:marginal}.
With {cmd:estimand(contrast)}, the command reports model movement only and
does not compute sampling or artifact shares.

{phang}
{opt true(#)} supplies a known true value.  When specified, the command returns
and displays the bias of each estimate versus that value.

{phang}
{opt level(#)} sets the confidence level for the individual coefficient
intervals displayed from each stored model.


{marker estimand}{...}
{title:Estimand restriction}

{pstd}
The decomposition is for the marginal or reference-arm time slope, such as a
main time coefficient.  It should not be used to assign sampling or artifact
shares to a treatment x time contrast.  Contrasts can be useful sensitivity
checks, but the contrast may barely move under weighting even when the
marginal trajectory is biased.


{marker formula}{...}
{title:Formula}

{pstd}
Let {it:b0} be the unweighted estimate, {it:bw} the weighted estimate, and
{it:ba} the weighted estimate after direct measurement-process adjustment.
These quantities should be marginal/reference-arm time-slope estimates.

{pstd}
{cmd:sampling gap}   = {it:b0} - {it:bw}{break}
{cmd:artifact gap}   = {it:bw} - {it:ba}{break}
{cmd:total gap}      = {it:b0} - {it:ba}{break}
{cmd:sampling share} = ({it:b0} - {it:bw}) / ({it:b0} - {it:ba}){break}
{cmd:artifact share} = ({it:bw} - {it:ba}) / ({it:b0} - {it:ba})

{pstd}
If the total gap is very small, shares are unstable and are returned as
missing.  If shares fall outside [0, 1], the command displays them but marks
the decomposition as sign-inconsistent.


{marker interpreting}{...}
{title:Interpreting results}

{pstd}
If exogeneity of the measurement-process adjustment is plausible, shares
summarize how much movement is attributable to sampling correction versus
residual measurement artifact under additive separability.

{pstd}
If the measurement process appears outcome-dependent, use
{cmd:exogeneity(endogenous)}.  The command then reports the weighted and
adjusted estimates as a sensitivity range rather than a point decomposition.

{pstd}
If {cmd:estimand(contrast)} is used, the command displays only movement across
the three models.  It suppresses the share decomposition because treatment
contrasts may be structurally insensitive to weighting.


{marker reporting}{...}
{title:Reporting guidance}

{pstd}
Report the three estimates before reporting any decomposition.  The estimate
sequence is often more informative than the share summary because readers can
see whether movement is large enough to matter clinically.

{p2colset 5 28 62 2}{...}
{p2col:{bf:Diagnostic quantity}}{bf:How to describe it}{p_end}
{p2col:Unweighted estimate}
The baseline analysis before correcting the visit process.  This is the
quantity most exposed to over-representation of frequent visitors.{p_end}
{p2col:Weighted estimate}
The estimate after correcting the modeled visit and/or treatment process.
Large movement from the unweighted estimate suggests informative sampling or
treatment-confounding sensitivity.{p_end}
{p2col:Adjusted estimate}
The weighted estimate after adding a measurement-process adjustment such as
cumulative test number or log(test number + 1).  Movement from the weighted
estimate suggests possible residual measurement artifact.{p_end}
{p2col:Sampling and artifact shares}
Use only for a marginal/reference slope when the total gap is not tiny and
the movement is sign-consistent.  Treat as descriptive unless exogeneity is
well defended.{p_end}
{p2col:Endogenous range}
When {cmd:exogeneity(endogenous)} is used, report the weighted and adjusted
estimates as a plausible diagnostic range, not as a point decomposition.
{p_end}
{p2colreset}{...}

{pstd}
For manuscripts, pair this command with the exact {cmd:iivw_exogtest}
specification.  A concise report should state the coefficient being
decomposed, the three stored models, whether the coefficient is marginal or a
contrast, the exogeneity setting, and any known true value used in simulation.


{marker examples}{...}
{title:Examples}

{pstd}
Example 1: compare a marginal slope across three stored models.

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. gen double visit_w = cond(foreign, 1.30, 0.85)}{p_end}
{phang2}{cmd:. regress price mpg}{p_end}
{phang2}{cmd:. estimates store M_unweighted}{p_end}
{phang2}{cmd:. regress price mpg [pw=visit_w]}{p_end}
{phang2}{cmd:. estimates store M_weighted}{p_end}
{phang2}{cmd:. regress price mpg weight [pw=visit_w]}{p_end}
{phang2}{cmd:. estimates store M_adjusted}{p_end}
{phang2}{cmd:. iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) adjusted(M_adjusted) exogeneity(exogenous)}{p_end}

{pstd}
Example 2: same marginal slope, but treating direct measurement adjustment as
a sensitivity range because testing may be outcome-dependent.

{phang2}{cmd:. iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) adjusted(M_adjusted) exogeneity(endogenous)}{p_end}

{pstd}
Example 3: simulation-style call with a known true value.

{phang2}{cmd:. iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) adjusted(M_adjusted) true(0) exogeneity(unknown)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_diagnose} stores the following in {cmd:r()}:

{synoptset 28 tabbed}{...}
{synopthdr:Scalars}
{synoptline}
{synopt:{cmd:r(b_unweighted)}}unweighted coefficient estimate{p_end}
{synopt:{cmd:r(se_unweighted)}}standard error for unweighted estimate{p_end}
{synopt:{cmd:r(b_weighted)}}weighted coefficient estimate{p_end}
{synopt:{cmd:r(se_weighted)}}standard error for weighted estimate{p_end}
{synopt:{cmd:r(b_adjusted)}}weighted plus measurement-adjusted coefficient estimate{p_end}
{synopt:{cmd:r(se_adjusted)}}standard error for adjusted estimate{p_end}
{synopt:{cmd:r(sampling_gap)}}unweighted minus weighted estimate{p_end}
{synopt:{cmd:r(artifact_gap)}}weighted minus adjusted estimate{p_end}
{synopt:{cmd:r(total_gap)}}unweighted minus adjusted estimate{p_end}
{synopt:{cmd:r(sampling_share)}}sampling share; missing for contrasts or tiny total gaps{p_end}
{synopt:{cmd:r(artifact_share)}}artifact share; missing for contrasts or tiny total gaps{p_end}
{synopt:{cmd:r(bounds_lower)}}lower endpoint of weighted/adjusted diagnostic range{p_end}
{synopt:{cmd:r(bounds_upper)}}upper endpoint of weighted/adjusted diagnostic range{p_end}
{synopt:{cmd:r(true)}}known true value, if {opt true()} is specified{p_end}
{synopt:{cmd:r(bias_unweighted)}}unweighted estimate minus true value{p_end}
{synopt:{cmd:r(bias_weighted)}}weighted estimate minus true value{p_end}
{synopt:{cmd:r(bias_adjusted)}}adjusted estimate minus true value{p_end}
{synoptline}

{synopthdr:Macros}
{synoptline}
{synopt:{cmd:r(coefficient)}}coefficient name{p_end}
{synopt:{cmd:r(unweighted)}}stored unweighted model name{p_end}
{synopt:{cmd:r(weighted)}}stored weighted model name{p_end}
{synopt:{cmd:r(adjusted)}}stored adjusted model name{p_end}
{synopt:{cmd:r(exogeneity)}}exogeneity setting{p_end}
{synopt:{cmd:r(estimand)}}estimand setting{p_end}
{synopt:{cmd:r(conclusion)}}interpretation category{p_end}
{synoptline}

{synopthdr:Matrices}
{synoptline}
{synopt:{cmd:r(estimates)}}rows {cmd:unweighted}, {cmd:weighted}, {cmd:adjusted}; columns {cmd:b}, {cmd:se}, {cmd:ll}, {cmd:ul}{p_end}
{synoptline}
{p2colreset}{...}


{marker references}{...}
{title:References}

{phang}
Buzkova P, Lumley T. 2007.
Longitudinal data analysis for generalized linear models with follow-up
dependent on outcome-related variables.
{it:Canadian Journal of Statistics} 35(4): 485-500.
doi:10.1002/cjs.5550350402.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.2.1, 2026-05-25{p_end}

{hline}
