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
{synopt:{opt est:imate(#)}}observed OR, RR, HR, or IRR to correct{p_end}
{synopt:{opt from_model}}take the estimate from {cmd:e(b)}{p_end}
{synopt:{opt coef(coefname)}}which coefficient to correct{p_end}

{syntab:Confounding parameters}
{synopt:{opt p1(#)}}P(confounder = 1 | exposed); range [0, 1]{p_end}
{synopt:{opt p0(#)}}P(confounder = 1 | unexposed); range [0, 1]{p_end}
{synopt:{opt rrcd(#)}}confounder-disease RR (Schneeweiss){p_end}
{synopt:{opt rrud(#)}}confounder-disease RR (Greenland){p_end}
{synopt:{opt conf:effect(#)}}additive confounder effect (linear only){p_end}

{syntab:E-value}
{synopt:{opt eva:lue}}compute E-value (VanderWeele & Ding 2017){p_end}
{synopt:{opt ci_bound(#)}}CI bound for the E-value{p_end}
{synopt:{opt com:monoutcome}}outcome is common (>15%){p_end}

{syntab:Options}
{synopt:{opt mea:sure(OR|RR|HR|IRR)}}measure type; default {cmd:RR}{p_end}

{syntab:Probabilistic}
{synopt:{opt reps(#)}}Monte Carlo replications; minimum 100{p_end}
{synopt:{opt dist_p1(distribution)}}p1 distribution; default constant{p_end}
{synopt:{opt dist_p0(distribution)}}p0 distribution; default constant{p_end}
{synopt:{opt dist_rr(distribution)}}confounder-disease RR distribution{p_end}
{synopt:{opt dist_confeffect(distribution)}}confounder-effect distribution{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:c(level)}{p_end}
{synopt:{opt sa:ving(filename, ...)}}save the Monte Carlo dataset{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_confound} corrects an observed measure of association for a single
binary unmeasured confounder. It implements the Schneeweiss (2006) and
Greenland (1996) bias factor approaches and optionally computes E-values
(VanderWeele & Ding 2017).

{pstd}
{bf:For ratio measures (OR, RR, HR, IRR)}, the correction divides the observed
estimate by a bias factor:

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

{pstd}
The E-value formula in VanderWeele and Ding (2017) Table 1 takes a {bf:risk}
ratio. Their Table 2 states what must happen first for the other ratio
measures, and {opt commonoutcome} selects it:

{p2colset 9 34 36 2}{...}
{p2col:{cmd:measure(RR)}, {cmd:measure(IRR)}}inserted directly at any outcome prevalence{p_end}
{p2col:{cmd:measure(OR)} + {opt commonoutcome}}RR is approximated by sqrt(OR){p_end}
{p2col:{cmd:measure(HR)} + {opt commonoutcome}}RR is approximated by (1-0.5^sqrt(HR)) / (1-0.5^sqrt(1/HR)){p_end}
{p2col:{cmd:measure(OR)}/{cmd:measure(HR)} alone}inserted directly; valid only for a rare outcome{p_end}
{p2colreset}{...}

{pstd}
The scale actually used is printed above the E-value, and the converted risk
ratio is returned in {cmd:r(evalue_rr)}, so an E-value is never silently a
rare-outcome approximation applied to a common-outcome estimate.

{pstd}
{opt measure(HR)} and {opt measure(IRR)} are corrected by the same bias factor
as {cmd:RR}; they exist as separate labels because the E-value conversion
differs. Note that {opt from_model} auto-detection still reports {cmd:RR} for
{cmd:stcox}, {cmd:streg}, {cmd:stcrreg}, and the count models -- specify
{opt measure(HR)} explicitly when you want the hazard-ratio conversion.


{marker options}{...}
{title:Options}

{dlgtab:Estimate source}

{phang}
{opt estimate(#)} specifies the observed OR, RR, HR, or IRR to correct. It must
be greater than 0 and cannot be combined with {opt from_model}.

{phang}
{opt from_model} reads the point estimate and standard error from the last
estimation command ({cmd:e(b)} and {cmd:e(V)}). The coefficient is automatically
exponentiated for log-scale models. Supported log-scale commands: {cmd:logistic},
{cmd:logit}, {cmd:stcox}, {cmd:poisson}, {cmd:nbreg}, {cmd:cloglog}, {cmd:clogit}, {cmd:xtlogit}, {cmd:xtpoisson}, {cmd:xtnbreg},
{cmd:melogit}, {cmd:mepoisson}, {cmd:streg}, {cmd:stcrreg}, and {cmd:glm} with log or logit link. Supported
additive commands are {cmd:regress}, {cmd:areg}, {cmd:cnsreg}, and identity-link
{cmd:glm}. Other estimator scales are rejected rather than treated as
additive. Because {cmd:cloglog}
coefficients are not odds ratios, {cmd:cloglog} requires explicit {opt measure(RR)}.

{phang}
When neither {opt estimate()} nor {opt from_model} is specified, {cmd:qba_confound} can read the
active {cmd:tmle} or {cmd:ltmle} estimation contract. It uses {cmd:e(tau)} as the observed
effect and, when available, {cmd:e(ci_lo)} and {cmd:e(ci_hi)} as confidence
limits. Current {cmd:tmle}/{cmd:ltmle} contracts are treated as additive coefficients
unless they explicitly declare a ratio measure through {cmd:e(measure)},
{cmd:e(effect_measure)}, or {cmd:e(qba_measure)}. Additive contracts use the subtractive
confounding correction with {opt confeffect()}; E-values are skipped because they
require an OR, RR, HR, or IRR. This integration requires a separately installed
{cmd:tmle} or {cmd:ltmle} command that leaves the active contract in
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

{phang}
{opt commonoutcome} declares that the outcome is common (more than about 15%
by the end of follow-up) and applies the corresponding VanderWeele and Ding
Table 2 conversion before the E-value formula: sqrt(OR) for {opt measure(OR)},
and (1-0.5^sqrt(HR)) / (1-0.5^sqrt(1/HR)) for {opt measure(HR)}. The same
conversion is applied to the confidence limit. For {opt measure(RR)} and
{opt measure(IRR)} no conversion is required, and the option reports that it
had no effect. It requires {opt evalue}.

{dlgtab:Options}

{phang}
{opt measure(OR|RR|HR|IRR)} specifies the measure type. When {opt from_model}
is used, the measure is auto-detected from the estimation command
(logistic/logit family produces OR; Poisson/Cox family defaults to RR). Specify
{opt measure(HR)} or {opt measure(IRR)} explicitly when that label and its
E-value scale are required. RR and IRR enter the E-value formula directly,
whereas with {opt commonoutcome}, HR uses the documented hazard-to-risk conversion,
while {cmd:cloglog} requires explicit {opt measure(RR)}. With {opt estimate()},
the default is {cmd:RR}.

{dlgtab:Probabilistic}

{phang}
{opt reps(#)} specifies the number of Monte Carlo replications. The minimum
accepted is 100, which is a floor rather than a stability guarantee: Fox,
MacLehose, and Lash (2023) repeat the process "hundreds of thousands" of
times, and their worked examples use 10^5 to 10^6 replications. Specifying
{opt reps()} activates probabilistic mode, which requires
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
for the CI derived from {opt from_model}. The default is the current
{cmd:c(level)} setting (95 unless changed).

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
result. VanderWeele and Ding (2017) Table 3 is explicit that there is no
universal threshold: an E-value is interpreted against the
confounder-treatment and confounder-outcome associations that are plausible in
the setting at hand, and the natural comparison is the E-value each
{it:measured} covariate would produce had it been omitted. Two- and three-fold
associations are discussed there as examples, not as cut-points, so no
robustness grade is printed.

{pstd}
{bf:E-value for the CI bound.} The E-value for the CI bound closest to the
null answers a stricter question: how strong would confounding need to be to
shift the CI to include the null? This is the more conservative assessment.

{pstd}
{bf:E-values and the rare-outcome assumption.} VanderWeele and Ding (2017)
derive the E-value on the risk-ratio scale. Applying it directly to an odds or
hazard ratio is licensed by their Table 2 only when the outcome is rare (less
than about 15% by end of follow-up); for a common outcome the direct E-value is
too large, i.e. it overstates robustness. Specify {opt commonoutcome} to apply
the Table 2 conversion instead. The scale used is printed with the E-value.

{pstd}
{bf:Linear models.} When {opt from_model} detects a supported additive model (e.g., {cmd:regress}), the
correction is subtractive rather than multiplicative. Specify {opt confeffect()} as
the signed additive confounder-outcome effect. E-values are not computed
because they require a ratio measure. Unsupported link scales such as probit
and ordered logit are rejected.

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
The same estimate when the outcome is common, so the odds ratio must enter the
E-value formula as sqrt(OR):

{phang2}{cmd:. qba_confound, estimate(1.5) measure(OR) evalue ci_bound(1.1) commonoutcome}{p_end}

{pstd}
A hazard ratio with a common outcome:

{phang2}{cmd:. qba_confound, estimate(1.5) measure(HR) evalue ci_bound(1.1) commonoutcome}{p_end}

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
{synopt:{cmd:r(corrected)}}corrected measure, when corrected{p_end}
{synopt:{cmd:r(bias_factor)}}bias factor (ratio measures only){p_end}
{synopt:{cmd:r(ratio)}}corrected / observed (ratio measures){p_end}
{synopt:{cmd:r(p1)}}confounder prevalence among exposed{p_end}
{synopt:{cmd:r(p0)}}confounder prevalence among unexposed{p_end}
{synopt:{cmd:r(rrcd)}}confounder-disease RR (when {opt rrcd()} specified){p_end}
{synopt:{cmd:r(rrud)}}confounder-disease RR (when {opt rrud()} specified){p_end}
{synopt:{cmd:r(confeffect)}}additive confounder effect (linear models){p_end}
{synopt:{cmd:r(evalue)}}E-value for point estimate (when {opt evalue} specified){p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for CI bound (when available){p_end}
{synopt:{cmd:r(evalue_rr)}}risk ratio the E-value formula was applied to{p_end}
{synopt:{cmd:r(ci_lower)}}lower CI bound ({opt from_model} or active estimator contract){p_end}
{synopt:{cmd:r(ci_upper)}}upper CI bound ({opt from_model} or active estimator contract){p_end}
{synopt:{cmd:r(se)}}standard error of the source estimate{p_end}

{p2col 5 22 26 2: Scalars (probabilistic mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}median corrected measure{p_end}
{synopt:{cmd:r(mean)}}mean of corrected measures{p_end}
{synopt:{cmd:r(sd)}}standard deviation of corrected measures{p_end}
{synopt:{cmd:r(ci_lower)}}lower limit of the systematic-error simulation interval{p_end}
{synopt:{cmd:r(ci_upper)}}upper limit of the systematic-error simulation interval{p_end}
{synopt:{cmd:r(reps)}}number of replications requested{p_end}
{synopt:{cmd:r(n_valid)}}number of valid (non-missing) replications{p_end}
{synopt:{cmd:r(n_draw_invalid)}}number of draws with out-of-support parameters{p_end}
{synopt:{cmd:r(evalue)}}E-value for point estimate (when {opt evalue} specified){p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for CI bound (when available){p_end}
{synopt:{cmd:r(evalue_rr)}}risk ratio the E-value formula was applied to{p_end}
{synopt:{cmd:r(se)}}standard error of the source estimate{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(measure)}}measure or estimand ({cmd:OR}, {cmd:RR}, {cmd:HR}, {cmd:IRR}, or {cmd:coefficient}){p_end}
{synopt:{cmd:r(method)}}{cmd:simple} or {cmd:probabilistic}{p_end}
{synopt:{cmd:r(interval)}}what {cmd:r(ci_lower)}/{cmd:r(ci_upper)} are (probabilistic only){p_end}
{synopt:{cmd:r(evalue_conv)}}E-value scale conversion: {cmd:none}, {cmd:sqrtor}, or {cmd:hrcommon}{p_end}
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


{phang}
Fox MP, MacLehose RF, Lash TL. SAS and R code for probabilistic quantitative
bias analysis for misclassified binary variables and binary unmeasured
confounders. {it:Int J Epidemiol}. 2023;52(5):1624-1633.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
