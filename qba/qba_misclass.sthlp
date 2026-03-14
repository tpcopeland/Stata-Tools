{smcl}
{* *! version 1.0.0  13mar2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{viewerjumpto "Syntax" "qba_misclass##syntax"}{...}
{viewerjumpto "Description" "qba_misclass##description"}{...}
{viewerjumpto "Options" "qba_misclass##options"}{...}
{viewerjumpto "Examples" "qba_misclass##examples"}{...}
{viewerjumpto "Stored results" "qba_misclass##results"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:qba_misclass} {hline 2}}Misclassification bias analysis for 2x2 tables{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 20 2}
{cmd:qba_misclass}
{cmd:,}
{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}
{opt seca(#)} {opt spca(#)}
[{it:options}]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt a(#)}}exposed cases{p_end}
{synopt:{opt b(#)}}unexposed cases{p_end}
{synopt:{opt c(#)}}exposed non-cases{p_end}
{synopt:{opt d(#)}}unexposed non-cases{p_end}
{synopt:{opt seca(#)}}sensitivity of classification{p_end}
{synopt:{opt spca(#)}}specificity of classification{p_end}

{syntab:Misclassification type}
{synopt:{opt type(exposure|outcome)}}what is misclassified; default {cmd:exposure}{p_end}
{synopt:{opt secb(#)}}sensitivity for second group (differential){p_end}
{synopt:{opt spcb(#)}}specificity for second group (differential){p_end}

{syntab:Measure}
{synopt:{opt mea:sure(OR|RR)}}measure of association; default {cmd:OR}{p_end}

{syntab:Probabilistic}
{synopt:{opt reps(#)}}Monte Carlo replications (enables probabilistic mode){p_end}
{synopt:{opt dist_se(distribution)}}distribution for sensitivity{p_end}
{synopt:{opt dist_sp(distribution)}}distribution for specificity{p_end}
{synopt:{opt dist_se1(distribution)}}distribution for Se group B (differential){p_end}
{synopt:{opt dist_sp1(distribution)}}distribution for Sp group B (differential){p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt level(#)}}confidence level; default {cmd:95}{p_end}
{synopt:{opt saving(filename, ...)}}save Monte Carlo results{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_misclass} corrects 2x2 table cell counts and measures of association
(OR, RR) for misclassification of exposure or outcome. It supports both
nondifferential (same Se/Sp across strata) and differential (different Se/Sp)
misclassification.

{pstd}
The 2x2 table layout is:

{p 12 12 2}
{c TLC}{hline 30}{c TRC}{break}
{c |}           Exposed  Unexposed{c |}{break}
{c |} Cases        a        b     {c |}{break}
{c |} Non-cases    c        d     {c |}{break}
{c BLC}{hline 30}{c BRC}

{pstd}
{bf:Simple mode} (default): Applies fixed Se/Sp values to analytically
correct the table. Returns corrected cell counts and measure of association.

{pstd}
{bf:Probabilistic mode} ({opt reps(#)}): Draws Se/Sp from specified distributions
for each replicate, returning a distribution of corrected estimates.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)} specify the four cells of the
observed 2x2 table. All values must be non-negative.

{phang}
{opt seca(#)} and {opt spca(#)} specify the sensitivity and specificity of the
classification. For nondifferential misclassification, these apply to both
strata. For differential, these apply to the first stratum (cases for exposure
misclassification, exposed for outcome misclassification). Values must be in
(0, 1] and their sum must exceed 1.

{dlgtab:Differential misclassification}

{phang}
{opt secb(#)} and {opt spcb(#)} specify sensitivity and specificity for the
second stratum. When specified, the analysis is differential.

{dlgtab:Probabilistic}

{phang}
{opt reps(#)} number of Monte Carlo replications. Minimum 100. Values of
5,000-50,000 are typical.

{phang}
{opt dist_se(distribution)} and {opt dist_sp(distribution)} specify
distributions for Se and Sp draws. See {helpb qba} for distribution syntax.

{phang}
{opt saving(filename, replace)} saves Monte Carlo results to a Stata dataset.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Simple nondifferential exposure misclassification}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)}{p_end}

{pstd}
{bf:Example 2: Differential misclassification}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.90) spca(.95) secb(.80) spcb(.95)}{p_end}

{pstd}
{bf:Example 3: Probabilistic analysis with trapezoidal distributions}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)} ///
{phang3}{cmd:reps(10000) dist_se("trapezoidal .75 .82 .88 .95")} ///
{phang3}{cmd:dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345)}{p_end}

{pstd}
{bf:Example 4: Outcome misclassification with RR}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.92) spca(.98) type(outcome) measure(RR)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_misclass} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars (simple mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}corrected measure of association{p_end}
{synopt:{cmd:r(ratio)}}corrected / observed{p_end}
{synopt:{cmd:r(corrected_a)}}corrected cell a{p_end}
{synopt:{cmd:r(corrected_b)}}corrected cell b{p_end}
{synopt:{cmd:r(corrected_c)}}corrected cell c{p_end}
{synopt:{cmd:r(corrected_d)}}corrected cell d{p_end}

{p2col 5 20 24 2: Scalars (probabilistic mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure{p_end}
{synopt:{cmd:r(corrected)}}median corrected measure{p_end}
{synopt:{cmd:r(mean)}}mean corrected measure{p_end}
{synopt:{cmd:r(sd)}}SD of corrected measures{p_end}
{synopt:{cmd:r(ci_lower)}}lower percentile CI bound{p_end}
{synopt:{cmd:r(ci_upper)}}upper percentile CI bound{p_end}
{synopt:{cmd:r(reps)}}number of replications{p_end}
{synopt:{cmd:r(n_valid)}}number of valid replications{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(type)}}misclassification type{p_end}
{synopt:{cmd:r(measure)}}measure of association{p_end}
{synopt:{cmd:r(method)}}simple or probabilistic{p_end}


{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}

{hline}
