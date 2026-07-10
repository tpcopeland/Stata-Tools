{smcl}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{vieweralsosee "qba_plot" "help qba_plot"}{...}
{viewerjumpto "Syntax" "qba_confound##syntax"}{...}
{viewerjumpto "Description" "qba_confound##description"}{...}
{viewerjumpto "Options" "qba_confound##options"}{...}
{viewerjumpto "Remarks" "qba_confound##remarks"}{...}
{viewerjumpto "Examples" "qba_confound##examples"}{...}
{viewerjumpto "Stored results" "qba_confound##results"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:qba_confound} {hline 2}}Unmeasured confounding bias analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 22 2}
{cmd:qba_confound}
{cmd:,}
[{opt est:imate(#)} | {opt from_model}]
[{it:options}]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Estimate source}
{synopt:{opt est:imate(#)}}observed OR or RR to correct{p_end}
{synopt:{opt from_model}}extract estimate from the last estimation command{p_end}
{synopt:{opt coef(coefname)}}coefficient to use when multiple predictors are present{p_end}

{syntab:Confounding parameters}
{synopt:{opt p1(#)}}P(confounder = 1 | exposed); range [0, 1]{p_end}
{synopt:{opt p0(#)}}P(confounder = 1 | unexposed); range [0, 1]{p_end}
{synopt:{opt rrcd(#)}}RR for confounder-disease association (Schneeweiss formula){p_end}
{synopt:{opt rrud(#)}}RR for confounder-disease association (Greenland formula){p_end}
{synopt:{opt conf:effect(#)}}signed additive confounder effect for linear {cmd:from_model}{p_end}

{syntab:E-value}
{synopt:{opt eva:lue}}compute E-value (VanderWeele & Ding 2017){p_end}
{synopt:{opt ci_bound(#)}}CI bound for E-value when not using {cmd:from_model}{p_end}

{syntab:Options}
{synopt:{opt mea:sure(OR|RR)}}measure type; default inferred from {cmd:from_model} or {cmd:RR}{p_end}

{syntab:Probabilistic}
{synopt:{opt reps(#)}}Monte Carlo replications (minimum 100; enables probabilistic mode){p_end}
{synopt:{opt dist_p1(distribution)}}distribution for p1; default constant at {cmd:p1()}{p_end}
{synopt:{opt dist_p0(distribution)}}distribution for p0; default constant at {cmd:p0()}{p_end}
{synopt:{opt dist_rr(distribution)}}distribution for the confounder-disease RR; default constant{p_end}
{synopt:{opt dist_confeffect(distribution)}}distribution for additive confounder effects in linear models{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:95}{p_end}
{synopt:{opt sa:ving(filename, ...)}}save Monte Carlo dataset for use with {helpb qba_plot}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_confound} corrects an observed measure of association for a single
binary unmeasured confounder. It implements the Schneeweiss (2006) and
Greenland (1996) bias factor approaches and optionally computes E-values
(VanderWeele & Ding 2017).

{pstd}
{bf:For ratio measures (OR, RR)}, the correction divides the observed estimate
by a bias factor:

{pstd}
Using {opt rrcd()} (Schneeweiss formula):

{p 12 12 2}
BF = [p1 * (RRcd - 1) + 1] / [p0 * (RRcd - 1) + 1]

{pstd}
Using {opt rrud()} (Greenland formula):

{p 12 12 2}
BF = [p1 * RRud + (1 - p1)] / [p0 * RRud + (1 - p0)]

{pstd}
The corrected estimate is: {it:corrected = observed / BF}

{pstd}
{bf:For linear models} (when {opt from_model} is used with a linear estimation
command such as {cmd:regress}), a subtractive correction is applied instead:

{p 12 12 2}
corrected = observed - (p1 - p0) * confounder_effect

{pstd}
The {bf:E-value} represents the minimum strength of association that an
unmeasured confounder would need to have with both the treatment and the
outcome, conditional on measured covariates, to fully explain away the
observed effect. Larger E-values indicate greater robustness to unmeasured
confounding.


{marker options}{...}
{title:Options}

{dlgtab:Estimate source}

{phang}
{opt estimate(#)} specifies the observed OR or RR to correct. Must be > 0. Cannot be
combined with {opt from_model}.

{phang}
{opt from_model} reads the point estimate and standard error from the last
estimation command ({cmd:e(b)} and {cmd:e(V)}). The coefficient is automatically
exponentiated for log-scale models. Supported log-scale commands: {cmd:logistic},
{cmd:logit}, {cmd:stcox}, {cmd:poisson}, {cmd:nbreg}, {cmd:cloglog}, {cmd:clogit}, {cmd:xtlogit}, {cmd:xtpoisson}, {cmd:xtnbreg},
{cmd:melogit}, {cmd:mepoisson}, {cmd:streg}, {cmd:stcrreg}, and {cmd:glm} with log or logit link. All other
commands are treated as linear (coefficient used directly). Because {cmd:cloglog}
coefficients are not odds ratios, {cmd:cloglog} requires explicit {opt measure(RR)}.

{phang}
When neither {opt estimate()} nor {opt from_model} is specified, {cmd:qba_confound} can read the
active {cmd:tmle} or {cmd:ltmle} estimation contract. It uses {cmd:e(tau)} as the observed
effect and, when available, {cmd:e(ci_lo)} and {cmd:e(ci_hi)} as confidence
limits. Current {cmd:tmle}/{cmd:ltmle} contracts are treated as additive coefficients
unless they explicitly declare a ratio measure through {cmd:e(measure)},
{cmd:e(effect_measure)}, or {cmd:e(qba_measure)}. Additive contracts use the subtractive
confounding correction with {opt confeffect()}; E-values are skipped because they
require an odds ratio or risk ratio. This integration requires a separately
installed {cmd:tmle} or {cmd:ltmle} command that leaves the active contract in
{cmd:e()}; {cmd:qba_confound} only reads that contract.

{phang}
{opt coef(coefname)} specifies which coefficient to use when the estimation
results contain multiple non-constant, non-omitted predictors. Required when
the model has more than one estimable predictor; omitted/base coefficients and
the constant term are not valid targets.

{dlgtab:Confounding parameters}

{phang}
{opt p1(#)} specifies the prevalence of the unmeasured confounder among the
exposed. Must be in [0, 1].

{phang}
{opt p0(#)} specifies the prevalence of the unmeasured confounder among the
unexposed. Must be in [0, 1].

{phang}
{opt rrcd(#)} specifies the risk ratio for the association between the confounder
and the disease, using the Schneeweiss (2006) parameterization. Must be >
0. Cannot be combined with {opt rrud()}.

{phang}
{opt rrud(#)} specifies the risk ratio for the association between the confounder
and the disease, using the Greenland (1996) parameterization. Must be >
0. Cannot be combined with {opt rrcd()}.

{phang}
{opt confeffect(#)} specifies the signed additive effect of the unmeasured
confounder on the outcome scale for linear {cmd:from_model} corrections. It is
required instead of {opt rrcd()} or {opt rrud()} when the last estimation command is
linear.

{dlgtab:E-value}

{phang}
{opt evalue} computes the E-value for the point estimate and, when available, for
the CI bound closest to the null. When {opt from_model} is used, the CI bounds are
derived from the model's standard error. When {opt from_model} is not used, specify
{opt ci_bound()} to provide the relevant CI limit. E-values are not available for
linear models.

{phang}
{opt ci_bound(#)} specifies the CI bound for the E-value calculation when not
using {opt from_model}. This should be the CI bound closest to the null
(e.g., the lower bound of the CI when the point estimate is > 1). Must be
> 0.

{dlgtab:Options}

{phang}
{opt measure(OR|RR)} specifies the measure type. When {opt from_model} is
used, the measure is auto-detected from the estimation command (logistic/logit
family produces OR; Poisson/Cox family produces RR). {cmd:cloglog} requires
explicit {opt measure(RR)}. When {opt estimate()} is used, the default is
{cmd:RR}.

{dlgtab:Probabilistic}

{phang}
{opt reps(#)} specifies the number of Monte Carlo replications. Minimum is
100. Specifying {opt reps()} activates probabilistic mode, which requires
confounding parameters ({opt p1()}, {opt p0()}, and {opt rrcd()} or
{opt rrud()} for ratio measures, or {opt confeffect()} for linear models).

{phang}
{opt dist_p1(distribution)}, {opt dist_p0(distribution)}, and {opt dist_rr(distribution)}
specify distributions for the confounding parameters. If omitted, constants at
the fixed parameter values are used. See {helpb qba} for distribution syntax.

{phang}
{opt dist_confeffect(distribution)} specifies the distribution for signed
additive confounder effects in linear {cmd:from_model} corrections.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt level(#)} specifies the confidence level for the percentile interval and
for the CI derived from {opt from_model}. Default is {cmd:95}.

{phang}
{opt saving(filename, replace)} saves the Monte Carlo dataset to a Stata
file containing parameter draws and corrected estimates.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:rrcd() vs. rrud().} Both options parameterize the confounder-disease
association. The Schneeweiss (2006) {opt rrcd()} formula is written in
excess-risk form, while the Greenland (1996) {opt rrud()} formula is written
in full-risk-ratio form. For a binary confounder, the two displayed formulas
are algebraically equivalent for the same numeric value; choose the
option name that matches your external data or expert terminology.

{pstd}
{bf:E-value interpretation.} An E-value of 3.0 means that an unmeasured confounder
would need to be associated with both the exposure and the outcome by a risk
ratio of at least 3.0 each (above and beyond measured covariates) to explain
away the observed effect. Weaker confounding could not fully account for the
result. E-values below 2 suggest relatively low robustness; values above 3
suggest strong robustness.

{pstd}
{bf:E-value for the CI bound.} The E-value for the CI bound closest to the
null answers a stricter question: how strong would confounding need to be to
shift the CI to include the null? This is the more conservative assessment.

{pstd}
{bf:E-values and the rare-outcome assumption.} VanderWeele and Ding (2017)
derive the E-value on the risk-ratio scale. When this command is applied to an
odds ratio, the E-value is a conservative approximation that works best when
the outcome is rare (less than about 15% prevalence) and can be
anti-conservative otherwise.

{pstd}
{bf:Linear models.} When {opt from_model} detects a linear model (e.g., {cmd:regress}), the
correction is subtractive rather than multiplicative. Specify {opt confeffect()} as
the signed additive confounder-outcome effect. E-values are not computed
because they require a ratio measure.

{pstd}
{bf:After tmle or ltmle.} If a separately installed {cmd:tmle} or
{cmd:ltmle} command leaves active estimation results, run
{cmd:qba_confound} without {opt estimate()} or {opt from_model}. This is
intended for post-estimation sensitivity checks on the reported causal
contrast. For additive contrasts, specify
{opt p1()}, {opt p0()}, and {opt confeffect()} to apply a subtractive
correction. If a future or custom TMLE contract posts a ratio-scale measure,
{cmd:qba_confound, evalue} will use that ratio-scale contract for E-values.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Simple confounding correction}

{phang2}{cmd:. qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0)}{p_end}

{pstd}
{bf:Example 2: E-value only (no correction)}

{phang2}{cmd:. qba_confound, estimate(2.1) evalue ci_bound(1.3)}{p_end}

{pstd}
{bf:Example 3: Correction with E-value}

{phang2}{cmd:. qba_confound, estimate(1.5) measure(OR) p1(.4) p0(.2) rrcd(2.0) evalue ci_bound(1.1)}{p_end}

{pstd}
{bf:Example 4: From estimation results}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logistic foreign mpg weight}{p_end}
{phang2}{cmd:. qba_confound, from_model coef(mpg) p1(.35) p0(.15) rrcd(1.8) evalue}{p_end}

{pstd}
{bf:Example 5: From a linear model (subtractive correction)}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. regress price mpg weight}{p_end}
{phang2}{cmd:. qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(500)}{p_end}

{pstd}
{bf:Example 6: After tmle or ltmle (optional integration)}

{pstd}
This example requires a separately installed {cmd:tmle} command. The same
pattern applies after {cmd:ltmle} when it leaves an active estimation contract.

{phang2}{cmd:. tmle x1 x2, outcome(y) treatment(a) nolog}{p_end}
{phang2}{cmd:. qba_confound, p1(.35) p0(.15) confeffect(.25)}{p_end}

{pstd}
E-values are available only when the active contract reports a ratio-scale
effect:

{phang2}{cmd:. qba_confound, evalue}{p_end}

{pstd}
{bf:Example 7: Probabilistic with distributions}

{phang2}{cmd:. qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0)} ///{p_end}
{phang3}{cmd:reps(10000) dist_p1("beta 8 12") dist_p0("beta 4 16")} ///{p_end}
{phang3}{cmd:dist_rr("trapezoidal 1.5 1.8 2.2 3.0") seed(99999)}{p_end}

{pstd}
{bf:Example 8: Using the Greenland (rrud) parameterization}

{phang2}{cmd:. qba_confound, estimate(1.8) p1(.5) p0(.2) rrud(2.5)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_confound} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars (simple mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}corrected measure of association (when correction is performed){p_end}
{synopt:{cmd:r(bias_factor)}}bias factor (ratio measures only){p_end}
{synopt:{cmd:r(ratio)}}corrected / observed (ratio measures only, when both are defined){p_end}
{synopt:{cmd:r(p1)}}confounder prevalence among exposed{p_end}
{synopt:{cmd:r(p0)}}confounder prevalence among unexposed{p_end}
{synopt:{cmd:r(rrcd)}}confounder-disease RR (when {opt rrcd()} specified){p_end}
{synopt:{cmd:r(rrud)}}confounder-disease RR (when {opt rrud()} specified){p_end}
{synopt:{cmd:r(confeffect)}}additive confounder effect (linear models){p_end}
{synopt:{cmd:r(evalue)}}E-value for point estimate (when {opt evalue} specified){p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for CI bound (when available){p_end}
{synopt:{cmd:r(ci_lower)}}lower CI bound ({opt from_model} or active estimator contract){p_end}
{synopt:{cmd:r(ci_upper)}}upper CI bound ({opt from_model} or active estimator contract){p_end}
{synopt:{cmd:r(se)}}standard error from {opt from_model} or active estimator contract, when available{p_end}

{p2col 5 22 26 2: Scalars (probabilistic mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}median corrected measure{p_end}
{synopt:{cmd:r(mean)}}mean of corrected measures{p_end}
{synopt:{cmd:r(sd)}}standard deviation of corrected measures{p_end}
{synopt:{cmd:r(ci_lower)}}lower bound of percentile confidence interval{p_end}
{synopt:{cmd:r(ci_upper)}}upper bound of percentile confidence interval{p_end}
{synopt:{cmd:r(reps)}}number of replications requested{p_end}
{synopt:{cmd:r(n_valid)}}number of valid (non-missing) replications{p_end}
{synopt:{cmd:r(n_draw_invalid)}}number of draws with out-of-support parameters{p_end}
{synopt:{cmd:r(evalue)}}E-value for point estimate (when {opt evalue} specified){p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for CI bound (when available){p_end}
{synopt:{cmd:r(se)}}standard error from {opt from_model} or active estimator contract, when available{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(measure)}}measure or estimand ({cmd:OR}, {cmd:RR}, or {cmd:coefficient}){p_end}
{synopt:{cmd:r(method)}}{cmd:simple} or {cmd:probabilistic}{p_end}
{synopt:{cmd:r(correction_type)}}{cmd:subtractive} (linear models only){p_end}
{synopt:{cmd:r(source)}}active estimator source ({cmd:tmle} or {cmd:ltmle}), when used{p_end}
{synopt:{cmd:r(cmd)}}active estimator command, when a contract is used{p_end}
{synopt:{cmd:r(outcome)}}outcome variable from the active estimator contract{p_end}
{synopt:{cmd:r(treatment)}}treatment variable from the active estimator contract{p_end}
{synopt:{cmd:r(estimand)}}estimand from the active estimator contract{p_end}


{title:References}

{phang}
Lash TL, Fox MP, Fink AK. {it:Applying Quantitative Bias Analysis to}
{it:Epidemiologic Data}. 2nd ed. New York: Springer; 2021. Chapter 8.

{phang}
Schneeweiss S. Sensitivity analysis and external adjustment for unmeasured
confounders in epidemiologic database studies of
therapeutics. {it:Pharmacoepidemiol Drug Saf}. 2006;15(5):291-303.

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational
research: introducing the E-value. {it:Ann Intern Med}. 2017;167(4):268-274.

{phang}
Greenland S. Basic methods for sensitivity analysis of
biases. {it:Int J Epidemiol}. 1996;25(6):1107-1116.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}