{smcl}
{* *! version 1.0.0  13mar2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{viewerjumpto "Syntax" "qba_multi##syntax"}{...}
{viewerjumpto "Description" "qba_multi##description"}{...}
{viewerjumpto "Options" "qba_multi##options"}{...}
{viewerjumpto "Examples" "qba_multi##examples"}{...}
{viewerjumpto "Stored results" "qba_multi##results"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:qba_multi} {hline 2}}Multi-bias analysis combining multiple bias corrections{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 18 2}
{cmd:qba_multi}
{cmd:,}
{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}
{opt reps(#)}
[{it:misclass_options}]
[{it:selection_options}]
[{it:confound_options}]
[{it:options}]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}}2x2 table cells{p_end}
{synopt:{opt reps(#)}}Monte Carlo replications (minimum 100){p_end}

{syntab:Misclassification}
{synopt:{opt seca(#)}}sensitivity{p_end}
{synopt:{opt spca(#)}}specificity{p_end}
{synopt:{opt secb(#)} {opt spcb(#)}}for differential misclassification{p_end}
{synopt:{opt mctype(exposure|outcome)}}misclassification type; default {cmd:exposure}{p_end}
{synopt:{opt dist_se(distribution)}}Se distribution{p_end}
{synopt:{opt dist_sp(distribution)}}Sp distribution{p_end}

{syntab:Selection}
{synopt:{opt sela(#)} {opt selb(#)}}selection probabilities (cases){p_end}
{synopt:{opt selc(#)} {opt seld(#)}}selection probabilities (non-cases){p_end}
{synopt:{opt dist_sela(distribution)}}through {opt dist_seld()} distributions{p_end}

{syntab:Confounding}
{synopt:{opt p1(#)}}confounder prevalence, exposed{p_end}
{synopt:{opt p0(#)}}confounder prevalence, unexposed{p_end}
{synopt:{opt rrcd(#)}}or {opt rrud(#)} confounder-disease RR{p_end}
{synopt:{opt dist_p1(distribution)}}through {opt dist_rr()} distributions{p_end}

{syntab:Control}
{synopt:{opt mea:sure(OR|RR)}}measure of association; default {cmd:OR}{p_end}
{synopt:{opt order(string)}}correction order; default {cmd:misclass selection confound}{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:95}{p_end}
{synopt:{opt saving(filename, ...)}}save Monte Carlo results{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_multi} chains multiple bias corrections in a single Monte Carlo
simulation. In each replicate, bias parameters are drawn from their
distributions and corrections are applied sequentially.

{pstd}
The default correction order follows Lash, Fox, and Fink (2021):
misclassification {it:->} selection {it:->} confounding. Only biases with
parameters specified are applied.

{pstd}
This is the recommended approach when multiple sources of systematic error
may be present simultaneously, as it propagates uncertainty through the
full correction chain.


{marker options}{...}
{title:Options}

{phang}
{opt order(string)} specifies the order of bias corrections. Default is
{cmd:misclass selection confound}. Specify any permutation, e.g.,
{cmd:order(confound misclass selection)}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: All three biases with fixed parameters}

{phang2}{cmd:. qba_multi, a(136) b(297) c(1432) d(6738) reps(10000)} ///
{phang3}{cmd:seca(.85) spca(.95)} ///
{phang3}{cmd:sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:p1(.4) p0(.2) rrcd(2.0) seed(12345)}{p_end}

{pstd}
{bf:Example 2: Misclassification + confounding with distributions}

{phang2}{cmd:. qba_multi, a(136) b(297) c(1432) d(6738) reps(20000)} ///
{phang3}{cmd:seca(.85) spca(.95) dist_se("trapezoidal .75 .82 .88 .95")} ///
{phang3}{cmd:dist_sp("trapezoidal .90 .93 .97 1.0")} ///
{phang3}{cmd:p1(.4) p0(.2) rrcd(2.0) dist_rr("uniform 1.5 3.0")} ///
{phang3}{cmd:seed(54321) saving(multi_results, replace)}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(observed)}}observed measure{p_end}
{synopt:{cmd:r(corrected)}}median corrected measure{p_end}
{synopt:{cmd:r(mean)}}mean{p_end}
{synopt:{cmd:r(sd)}}standard deviation{p_end}
{synopt:{cmd:r(ci_lower)}}lower CI{p_end}
{synopt:{cmd:r(ci_upper)}}upper CI{p_end}
{synopt:{cmd:r(reps)}}replications{p_end}
{synopt:{cmd:r(n_valid)}}valid replications{p_end}
{synopt:{cmd:r(n_biases)}}number of bias types corrected{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(measure)}}measure of association{p_end}
{synopt:{cmd:r(method)}}multi-bias{p_end}
{synopt:{cmd:r(order)}}correction order used{p_end}


{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}

{hline}
