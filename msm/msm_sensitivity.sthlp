{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{viewerjumpto "Syntax" "msm_sensitivity##syntax"}{...}
{viewerjumpto "Description" "msm_sensitivity##description"}{...}
{viewerjumpto "How to interpret E-values" "msm_sensitivity##interpreting"}{...}
{viewerjumpto "Remarks" "msm_sensitivity##remarks"}{...}
{viewerjumpto "Options" "msm_sensitivity##options"}{...}
{viewerjumpto "Examples" "msm_sensitivity##examples"}{...}
{viewerjumpto "Stored results" "msm_sensitivity##stored"}{...}
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
{synopt:{opt eva:lue}}compute E-value; default with no options{p_end}
{synopt:{opt conf:ounding_strength(# #)}}RR(U,D) and RR(U,Y) for bias factor computation{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:c(level)}{p_end}
{synopt:{opt rarethr:eshold(#)}}rare/common cumulative-incidence cut; default {cmd:0.15}{p_end}
{synopt:{opt orapprox}}force the raw OR/HR as the RR scale{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_sensitivity} addresses the question every MSM analysis must face: "How
sensitive is this result to confounders I did not measure?" It provides two
complementary tools:

{phang2}{bf:E-value:} The minimum strength of association (on the risk ratio
scale) that an unmeasured confounder would need with {it:both} the treatment
and the outcome to fully explain away the observed effect. Larger E-values
mean the result is more robust to unmeasured confounding.{p_end}

{phang2}{bf:Confounding strength bounds:} Given specific hypothetical
confounder-treatment and confounder-outcome associations (RR_UD and RR_UY),
computes the bias factor and what the corrected effect would be after
accounting for that confounder.{p_end}

{pstd}
The command requires a prior {helpb msm_fit} run and reads the persisted
coefficient and variance matrices.


{marker interpreting}{...}
{title:How to interpret E-values}

{pstd}
The E-value answers: "How strong would an unmeasured confounder need to be to
explain away this result?"  Two values are reported:

{phang2}{bf:E-value (point estimate):} How strong a confounder would need to
be to reduce the point estimate to the null (1 on the RR scale).{p_end}

{phang2}{bf:E-value (CI limit):} How strong a confounder would need to be to
shift the confidence interval to include the null. This is always smaller than
or equal to the point estimate E-value.{p_end}

{pstd}
Rules of thumb:

{phang2}E-value < 2: a relatively weak confounder could explain the result.{p_end}
{phang2}E-value 2-3: a moderately strong confounder would be needed.{p_end}
{phang2}E-value > 3: a strong confounder would be needed.{p_end}

{pstd}
If the CI E-value is 1, the confidence interval already includes the null,
so no unmeasured confounding is needed to explain the association at the
specified confidence level.


{marker remarks}{...}
{title:Remarks}

{pstd}
E-values and bias-factor corrections are defined on the {it:risk ratio} scale
(VanderWeele & Ding 2017). An odds ratio or a hazard ratio approximates the
risk ratio only when the outcome is rare {it:by the end of follow-up}.

{pstd}
{cmd:msm_sensitivity} therefore judges rarity by the subject-level
{bf:cumulative incidence} (the share of subjects who experience the event over
follow-up), returned in {cmd:r(cumulative_incidence)}. When it is at most
{cmd:rarethreshold()} (default 0.15, the VanderWeele-Ding rare/common cut), the
OR (logistic) or HR (Cox) is used directly as the risk ratio.

{pstd}
When the outcome is common (cumulative incidence above {cmd:rarethreshold()}),
the command applies the paper's common-outcome transforms rather than treating
the raw OR/HR as a risk ratio: for {cmd:model(logistic)} it uses
{cmd:RR = sqrt(OR)}, and for {cmd:model(cox)} it uses
{cmd:RR = (1 - 0.5^sqrt(HR)) / (1 - 0.5^sqrt(1/HR))}, applied to the point
estimate and both confidence limits before the E-value formula. Specify
{opt orapprox} to force the raw OR/HR as the risk ratio even for a common
outcome (the cruder rare-outcome approximation).

{pstd}
For {cmd:model(linear)} the coefficient is not on a ratio scale, so no E-value
or bias factor is produced; use {opt confounding_strength()} for bound
explorations, and see {cmd:r(metric_produced)}.


{marker options}{...}
{title:Options}

{phang}
{opt eva:lue} computes the E-value for the point estimate and the CI limit closest to
the null. This is the default if no other option is specified. Not available
for linear models.

{phang}
{opt conf:ounding_strength(# #)} specifies hypothetical association strengths
for a specific unmeasured confounder. The first number is RR(U,D), the
confounder-treatment association; the second is RR(U,Y), the
confounder-outcome association. Both values must be >= 1 (invert
protective associations). The command computes the bias factor
= (RR_UD x RR_UY) / (RR_UD + RR_UY - 1) and reports the corrected effect,
shifted toward the null: the observed effect is divided by the bias factor
when it exceeds 1 and multiplied by it when it is below 1.

{phang}
{opt level(#)} specifies the confidence level. The default is the current {cmd:c(level)}, usually 95.

{phang}
{opt rarethr:eshold(#)} specifies the cumulative-incidence cut (share of
subjects with the event by the end of follow-up) at or below which the OR/HR
is used directly as the risk ratio; above it, the common-outcome transform is
applied ({cmd:sqrt(OR)} for logistic, the HR-to-RR transform for Cox). Default
is 0.15 (VanderWeele & Ding 2017). Must be strictly between 0 and 1.

{phang}
{opt orapprox} forces the raw odds ratio or hazard ratio to be used as the
risk ratio even when the outcome is common, bypassing the common-outcome
transform. Use this only when you are willing to defend the cruder
approximation substantively.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Default E-value after fitting:}{p_end}

{phang2}{cmd:. msm_sensitivity, evalue}{p_end}

{pstd}
{bf:Hypothetical confounder analysis.} What if an unmeasured confounder had
RR = 1.5 with treatment and RR = 2.0 with the outcome?{p_end}

{phang2}{cmd:. msm_sensitivity, confounding_strength(1.5 2.0)}{p_end}

{pstd}
{bf:Both E-value and confounding bounds together:}{p_end}

{phang2}{cmd:. msm_sensitivity, evalue confounding_strength(1.5 2.0)}{p_end}

{pstd}
{bf:Stricter rare-outcome screen:}{p_end}

{phang2}{cmd:. msm_sensitivity, evalue rarethreshold(0.05)}{p_end}

{pstd}
{bf:Force OR approximation for a common outcome:}{p_end}

{phang2}{cmd:. msm_sensitivity, evalue orapprox}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_sensitivity} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(evalue_point)}}E-value for the point estimate{p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for the CI limit closest to the null{p_end}
{synopt:{cmd:r(effect)}}treatment effect estimate (OR, HR, or coefficient){p_end}
{synopt:{cmd:r(effect_lo)}}lower confidence bound{p_end}
{synopt:{cmd:r(effect_hi)}}upper confidence bound{p_end}
{synopt:{cmd:r(effect_se)}}standard error of the effect term{p_end}
{synopt:{cmd:r(bias_factor)}}computed bias factor (with {opt confounding_strength()}){p_end}
{synopt:{cmd:r(bound)}}bias-adjusted bound on the RR scale{p_end}
{synopt:{cmd:r(corrected_effect)}}effect corrected toward the null by the bias factor{p_end}
{synopt:{cmd:r(rr_ud)}}hypothetical RR(U,D) specified{p_end}
{synopt:{cmd:r(rr_uy)}}hypothetical RR(U,Y) specified{p_end}
{synopt:{cmd:r(cumulative_incidence)}}cumulative incidence by end of follow-up{p_end}
{synopt:{cmd:r(outcome_prevalence)}}alias of {cmd:r(cumulative_incidence)}{p_end}
{synopt:{cmd:r(rare_threshold)}}value of {cmd:rarethreshold()} used{p_end}
{synopt:{cmd:r(metric_produced)}}1 if a RR-scale measure was produced{p_end}

{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(effect_label)}}effect measure label ({cmd:OR}, {cmd:HR}, or {cmd:Coef}){p_end}
{synopt:{cmd:r(model)}}model type{p_end}
{synopt:{cmd:r(rr_scale)}}RR-scale input label for the E-value{p_end}
{synopt:{cmd:r(approximation)}}RR-scale approximation applied (see Remarks){p_end}


{marker references}{...}
{title:References}

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational
research: introducing the
E-value. {it:Annals of Internal Medicine}. 2017;167(4):268-274.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
