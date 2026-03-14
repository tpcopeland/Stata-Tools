{smcl}
{* *! version 1.0.0  13mar2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{viewerjumpto "Syntax" "qba_confound##syntax"}{...}
{viewerjumpto "Description" "qba_confound##description"}{...}
{viewerjumpto "Options" "qba_confound##options"}{...}
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
{opt est:imate(#)} | {opt from_model}
[{it:options}]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Estimate source}
{synopt:{opt est:imate(#)}}observed OR or RR{p_end}
{synopt:{opt from_model}}use last estimation command{p_end}

{syntab:Confounding parameters}
{synopt:{opt p1(#)}}prevalence of confounder among exposed{p_end}
{synopt:{opt p0(#)}}prevalence of confounder among unexposed{p_end}
{synopt:{opt rrcd(#)}}RR for confounder-disease association{p_end}
{synopt:{opt rrud(#)}}RR for confounder-disease (alternative){p_end}

{syntab:Options}
{synopt:{opt mea:sure(OR|RR)}}measure type; default {cmd:RR}{p_end}
{synopt:{opt eva:lue}}compute E-value{p_end}
{synopt:{opt ci_bound(#)}}CI bound for E-value calculation{p_end}

{syntab:Probabilistic}
{synopt:{opt reps(#)}}Monte Carlo replications{p_end}
{synopt:{opt dist_p1(distribution)}}distribution for p1{p_end}
{synopt:{opt dist_p0(distribution)}}distribution for p0{p_end}
{synopt:{opt dist_rr(distribution)}}distribution for RR{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:95}{p_end}
{synopt:{opt saving(filename, ...)}}save Monte Carlo results{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_confound} corrects an observed measure of association for a single
binary unmeasured confounder. It implements the Schneeweiss (2006) and
Greenland (1996) bias factor approaches and optionally computes E-values
(VanderWeele & Ding 2017).

{pstd}
The bias factor is computed as:

{pstd}
Using {opt rrcd()}: BF = [p1*(RRcd-1) + 1] / [p0*(RRcd-1) + 1]

{pstd}
Using {opt rrud()}: BF = [p1*RRud + (1-p1)] / [p0*RRud + (1-p0)]

{pstd}
The corrected estimate is: {it:observed / BF}

{pstd}
The {opt evalue} option computes the minimum strength of unmeasured
confounding needed to explain away the observed effect.


{marker options}{...}
{title:Options}

{dlgtab:Estimate source}

{phang}
{opt estimate(#)} specifies the observed OR or RR to correct.

{phang}
{opt from_model} reads the point estimate and SE from the last estimation
command (e.g., {cmd:logistic}, {cmd:stcox}). Cannot be combined with
{opt estimate()}.

{dlgtab:Confounding parameters}

{phang}
{opt p1(#)} prevalence of unmeasured confounder among exposed (0 to 1).

{phang}
{opt p0(#)} prevalence of unmeasured confounder among unexposed (0 to 1).

{phang}
{opt rrcd(#)} or {opt rrud(#)} risk ratio for the confounder-disease
association. Specify one or the other. Must be > 0.

{dlgtab:E-value}

{phang}
{opt evalue} computes the E-value for the point estimate and (if available)
the confidence interval bound closest to the null.

{phang}
{opt ci_bound(#)} specifies the CI bound for E-value calculation when not
using {opt from_model}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Simple confounding correction}

{phang2}{cmd:. qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0)}{p_end}

{pstd}
{bf:Example 2: E-value only}

{phang2}{cmd:. qba_confound, estimate(2.1) evalue ci_bound(1.3)}{p_end}

{pstd}
{bf:Example 3: From model with E-value}

{phang2}{cmd:. logistic outcome treatment age sex}{p_end}
{phang2}{cmd:. qba_confound, from_model p1(.35) p0(.15) rrcd(1.8) evalue}{p_end}

{pstd}
{bf:Example 4: Probabilistic}

{phang2}{cmd:. qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0)} ///
{phang3}{cmd:reps(10000) dist_p1("beta 8 12") dist_p0("beta 4 16")} ///
{phang3}{cmd:dist_rr("trapezoidal 1.5 1.8 2.2 3.0") seed(99999)}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(observed)}}observed measure{p_end}
{synopt:{cmd:r(corrected)}}corrected measure{p_end}
{synopt:{cmd:r(bias_factor)}}bias factor{p_end}
{synopt:{cmd:r(evalue)}}E-value for point estimate{p_end}
{synopt:{cmd:r(evalue_ci)}}E-value for CI bound{p_end}
{synopt:{cmd:r(p1)}}confounder prevalence, exposed{p_end}
{synopt:{cmd:r(p0)}}confounder prevalence, unexposed{p_end}

{p2col 5 20 24 2: Scalars (probabilistic mode)}{p_end}
{synopt:{cmd:r(corrected)}}median corrected measure{p_end}
{synopt:{cmd:r(mean)}}mean{p_end}
{synopt:{cmd:r(sd)}}standard deviation{p_end}
{synopt:{cmd:r(ci_lower)}}lower CI{p_end}
{synopt:{cmd:r(ci_upper)}}upper CI{p_end}
{synopt:{cmd:r(reps)}}replications{p_end}


{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}

{hline}
