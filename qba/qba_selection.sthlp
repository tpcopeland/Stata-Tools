{smcl}
{* *! version 1.0.0  13mar2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{viewerjumpto "Syntax" "qba_selection##syntax"}{...}
{viewerjumpto "Description" "qba_selection##description"}{...}
{viewerjumpto "Options" "qba_selection##options"}{...}
{viewerjumpto "Examples" "qba_selection##examples"}{...}
{viewerjumpto "Stored results" "qba_selection##results"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:qba_selection} {hline 2}}Selection bias analysis for 2x2 tables{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 22 2}
{cmd:qba_selection}
{cmd:,}
{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}
{opt sela(#)} {opt selb(#)} {opt selc(#)} {opt seld(#)}
[{it:options}]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt a(#)}}exposed cases{p_end}
{synopt:{opt b(#)}}unexposed cases{p_end}
{synopt:{opt c(#)}}exposed non-cases{p_end}
{synopt:{opt d(#)}}unexposed non-cases{p_end}
{synopt:{opt sela(#)}}selection probability for exposed cases{p_end}
{synopt:{opt selb(#)}}selection probability for unexposed cases{p_end}
{synopt:{opt selc(#)}}selection probability for exposed non-cases{p_end}
{synopt:{opt seld(#)}}selection probability for unexposed non-cases{p_end}

{syntab:Measure}
{synopt:{opt mea:sure(OR|RR)}}measure of association; default {cmd:OR}{p_end}

{syntab:Probabilistic}
{synopt:{opt reps(#)}}Monte Carlo replications{p_end}
{synopt:{opt dist_sela(distribution)}}distribution for sela{p_end}
{synopt:{opt dist_selb(distribution)}}distribution for selb{p_end}
{synopt:{opt dist_selc(distribution)}}distribution for selc{p_end}
{synopt:{opt dist_seld(distribution)}}distribution for seld{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:95}{p_end}
{synopt:{opt saving(filename, ...)}}save Monte Carlo results{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_selection} corrects 2x2 table cell counts and measures of association
for selection bias by specifying the probability of selection into the study
for each exposure-outcome stratum.

{pstd}
The correction divides each observed cell by its selection probability to
estimate the source population counts. Selection bias arises when the
selection probabilities differ across strata, distorting the measure of
association.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt sela(#)} through {opt seld(#)} specify selection probabilities for each
cell of the 2x2 table. Values must be in (0, 1]. When all four are equal,
there is no selection bias.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Simple selection bias correction}

{phang2}{cmd:. qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8)}{p_end}

{pstd}
{bf:Example 2: Probabilistic with uniform distributions}

{phang2}{cmd:. qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:reps(10000) dist_sela("uniform .8 1.0") dist_selb("uniform .75 .95")} ///
{phang3}{cmd:dist_selc("uniform .6 .8") dist_seld("uniform .7 .9") seed(54321)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_selection} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars (simple mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure{p_end}
{synopt:{cmd:r(corrected)}}corrected measure{p_end}
{synopt:{cmd:r(bias_factor)}}selection bias factor (OR scale){p_end}
{synopt:{cmd:r(ratio)}}corrected / observed{p_end}
{synopt:{cmd:r(corrected_a)}}through {cmd:r(corrected_d)} corrected cells{p_end}

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
