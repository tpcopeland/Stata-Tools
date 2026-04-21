{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{viewerjumpto "Syntax" "msm_sensitivity##syntax"}{...}
{viewerjumpto "Description" "msm_sensitivity##description"}{...}
{viewerjumpto "Remarks" "msm_sensitivity##remarks"}{...}
{viewerjumpto "Options" "msm_sensitivity##options"}{...}
{viewerjumpto "Stored results" "msm_sensitivity##stored"}{...}
{viewerjumpto "Examples" "msm_sensitivity##examples"}{...}
{viewerjumpto "References" "msm_sensitivity##references"}{...}
{viewerjumpto "Author" "msm_sensitivity##author"}{...}

{title:Title}

{phang}
{bf:msm_sensitivity} {hline 2} Sensitivity analysis for unmeasured confounding


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_sensitivity}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt eva:lue}}compute E-value (default){p_end}
{synopt:{opt conf:ounding_strength(# #)}}RR(U,D) and RR(U,Y) for bias factor{p_end}
{synopt:{opt level(#)}}confidence level; default 95{p_end}
{synopt:{opt rarethres:hold(#)}}maximum weighted outcome prevalence for automatic logistic approximation; default 0.10{p_end}
{synopt:{opt orapprox}}force OR-based rare-outcome approximation for logistic models{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_sensitivity} assesses sensitivity to unmeasured confounding.

{pstd}
The {bf:E-value} (VanderWeele & Ding 2017) is the minimum strength of
association on the risk ratio scale that an unmeasured confounder would
need with both treatment and outcome to explain away the observed effect.

{pstd}
{bf:Confounding strength bounds} compute the bias factor given hypothetical
confounder-treatment (RR_UD) and confounder-outcome (RR_UY) associations.

{marker remarks}{...}
{title:Remarks}

{pstd}
E-values and bias-factor corrections are defined on the risk ratio scale.
For {cmd:msm_fit, model(logistic)}, {cmd:msm_sensitivity} therefore treats the
odds ratio as a {it:rare-outcome approximation}, not as an exact risk ratio.

{pstd}
By default, the logistic branch is only used when the weighted outcome
prevalence in the MSM estimation sample is less than or equal to
{cmd:rarethreshold()}, which defaults to 0.10. The prevalence screen is
computed on the same at-risk person-period sample used by {cmd:msm_fit}.

{pstd}
If the weighted outcome prevalence exceeds {cmd:rarethreshold()}, the command
stops with an error instead of silently reporting RR-scale sensitivity
quantities from a common-outcome odds ratio.

{pstd}
Use {cmd:orapprox} only when you deliberately want the OR-based rare-outcome
approximation despite failing the prevalence screen. In that case, the command
continues but labels the result as an approximation. The override is intended
for informed sensitivity work, not as a default workflow.

{pstd}
For {cmd:msm_fit, model(cox)}, the hazard ratio is used directly. For
{cmd:msm_fit, model(linear)}, E-values are not reported because the effect is
not on a ratio scale.


{marker options}{...}
{title:Options}

{phang}
{opt evalue} computes the E-value for the point estimate and (if available)
the confidence interval bound closest to the null for Cox fits and for
logistic fits that pass the rare-outcome screen. This is the default if no
other option is specified. Linear models do not return E-values.

{phang}
{opt confounding_strength(# #)} specifies hypothetical RR(U,D) and RR(U,Y)
values for a specific bias factor computation. The first number is the
confounder-treatment association and the second is the confounder-outcome
association. For logistic fits, the same rare-outcome screen applies because
the bias factor is a risk-ratio-scale quantity.

{phang}
{opt level(#)} specifies the confidence level. Default is 95.

{phang}
{opt rarethreshold(#)} specifies the maximum weighted outcome prevalence that
will be treated as consistent with the default rare-outcome approximation for
logistic fits. The default is {cmd:rarethreshold(0.10)}. This must be strictly
between 0 and 1.

{phang}
{opt orapprox} forces the logistic branch to use the odds ratio as a
rare-outcome approximation even when the weighted outcome prevalence exceeds
{cmd:rarethreshold()}. Use this only when you are willing to defend that
approximation substantively.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_sensitivity} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(evalue_point)}}E-value for point estimate (Cox fits; logistic rare-outcome approximation when allowed){p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for CI bound (Cox fits; logistic rare-outcome approximation when allowed){p_end}
{synopt:{cmd:r(effect)}}treatment effect estimate{p_end}
{synopt:{cmd:r(effect_lo)}}lower CI bound{p_end}
{synopt:{cmd:r(effect_hi)}}upper CI bound{p_end}
{synopt:{cmd:r(bias_factor)}}bias factor (when {opt confounding_strength()} specified){p_end}
{synopt:{cmd:r(corrected_effect)}}corrected ratio-scale effect estimate or approximation{p_end}
{synopt:{cmd:r(rr_ud)}}hypothetical RR(U,D){p_end}
{synopt:{cmd:r(rr_uy)}}hypothetical RR(U,Y){p_end}
{synopt:{cmd:r(outcome_prevalence)}}weighted outcome prevalence used for logistic rare-outcome screening{p_end}
{synopt:{cmd:r(rare_threshold)}}value of {cmd:rarethreshold()} used in the command call{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(effect_label)}}effect measure label{p_end}
{synopt:{cmd:r(model)}}model type{p_end}
{synopt:{cmd:r(approximation)}}approximation status: {cmd:none}, {cmd:rare-outcome auto}, or {cmd:rare-outcome override}{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_sensitivity, evalue}{p_end}
{phang2}{cmd:. msm_sensitivity, confounding_strength(1.5 2.0)}{p_end}
{phang2}{cmd:. msm_sensitivity, evalue rarethreshold(0.05)}{p_end}
{phang2}{cmd:. msm_sensitivity, evalue orapprox}{p_end}


{marker references}{...}
{title:References}

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational research:
introducing the E-value. {it:Annals of Internal Medicine}. 2017;167(4):268-274.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}
