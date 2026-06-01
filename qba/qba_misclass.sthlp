{smcl}
{* *! version 1.0.0  02jun2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{vieweralsosee "qba_plot" "help qba_plot"}{...}
{viewerjumpto "Syntax" "qba_misclass##syntax"}{...}
{viewerjumpto "Description" "qba_misclass##description"}{...}
{viewerjumpto "Options" "qba_misclass##options"}{...}
{viewerjumpto "Remarks" "qba_misclass##remarks"}{...}
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
{synopt:{opt ty:pe(exposure|outcome)}}what is misclassified; default {cmd:exposure}{p_end}
{synopt:{opt secb(#)}}sensitivity for second group (enables differential mode){p_end}
{synopt:{opt spcb(#)}}specificity for second group (enables differential mode){p_end}

{syntab:Measure}
{synopt:{opt mea:sure(OR|RR)}}measure of association; default {cmd:OR}{p_end}

{syntab:Probabilistic}
{synopt:{opt reps(#)}}Monte Carlo replications (minimum 100; enables probabilistic mode){p_end}
{synopt:{opt dist_se(distribution)}}distribution for sensitivity; default constant at {cmd:seca()}{p_end}
{synopt:{opt dist_sp(distribution)}}distribution for specificity; default constant at {cmd:spca()}{p_end}
{synopt:{opt dist_se1(distribution)}}distribution for Se in group B (differential only); default constant at {cmd:secb()}{p_end}
{synopt:{opt dist_sp1(distribution)}}distribution for Sp in group B (differential only); default constant at {cmd:spcb()}{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt level(#)}}confidence level for percentile interval; default {cmd:95}{p_end}
{synopt:{opt sa:ving(filename, ...)}}save Monte Carlo dataset for use with {helpb qba_plot}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_misclass} corrects 2x2 table cell counts and measures of association
(OR or RR) for misclassification of exposure or outcome. It supports both
nondifferential (same Se/Sp across strata) and differential (different Se/Sp
by stratum) misclassification.

{pstd}
The 2x2 table layout is:

{p 12 12 2}
{c TLC}{hline 30}{c TRC}{break}
{c |}           Exposed  Unexposed{c |}{break}
{c |} Cases        a        b     {c |}{break}
{c |} Non-cases    c        d     {c |}{break}
{c BLC}{hline 30}{c BRC}

{pstd}
{bf:Simple mode} (default): Applies the Greenland/Lash matrix method to
analytically correct the table using fixed Se and Sp values. For
nondifferential exposure misclassification, the corrected exposed-case count
is:

{p 12 12 2}
a* = [a - (1 - Sp) * M1] / (Se + Sp - 1)

{pstd}
where M1 = a + b (row total for cases). The remaining cells are derived from
the row totals. This formula requires Se + Sp > 1 for identifiability.

{pstd}
Simple mode warns when any corrected cell is negative, indicating the bias
parameters are incompatible with the observed data. In that case corrected
cells are displayed, but the corrected measure and ratio are reported as
missing rather than as an impossible negative effect measure.

{pstd}
{bf:Probabilistic mode} ({opt reps(#)}): Draws Se and Sp values from
specified distributions at each replicate, computes the corrected table,
and returns the distribution of corrected estimates. Replicates producing
negative corrected cells or undefined measures are excluded.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt a(#)}, {opt b(#)}, {opt c(#)}, {opt d(#)} specify the four cells of the
observed 2x2 table. All values must be non-negative.

{phang}
{opt seca(#)} and {opt spca(#)} specify the sensitivity and specificity of the
classification. For nondifferential misclassification, these apply to all
strata. For differential misclassification, these apply to the first stratum
(cases for exposure misclassification; exposed for outcome misclassification).
Each value must be in (0, 1] and their sum must exceed 1.

{dlgtab:Misclassification type}

{phang}
{opt type(exposure|outcome)} specifies what is misclassified. With
{cmd:type(exposure)} (the default), the correction operates within disease
strata (rows). With {cmd:type(outcome)}, the correction operates within
exposure strata (columns).

{phang}
{opt secb(#)} and {opt spcb(#)} specify sensitivity and specificity for the
second stratum, enabling differential misclassification. When
{opt type(exposure)}, the second stratum is non-cases; when
{opt type(outcome)}, the second stratum is unexposed. Specifying either
{opt secb()} or {opt spcb()} activates differential mode; the other defaults
to its group-A counterpart if omitted. Each value must be in (0, 1] and
their sum must exceed 1.

{dlgtab:Measure}

{phang}
{opt measure(OR|RR)} specifies the measure of association to compute from the
corrected table. Default is {cmd:OR} (odds ratio). Use {cmd:RR} for risk
ratio.

{dlgtab:Probabilistic}

{phang}
{opt reps(#)} specifies the number of Monte Carlo replications. Minimum is
100; typical values are 5,000 to 50,000. Specifying {opt reps()} activates
probabilistic mode.

{phang}
{opt dist_se(distribution)} and {opt dist_sp(distribution)} specify the
distributions from which sensitivity and specificity values are drawn at
each replicate. If omitted, a constant at {opt seca()} or {opt spca()} is
used. See {helpb qba} for distribution syntax (e.g.,
{cmd:"trapezoidal .75 .82 .88 .95"}).

{phang}
{opt dist_se1(distribution)} and {opt dist_sp1(distribution)} specify
distributions for Se and Sp in the second stratum during differential
misclassification. These require differential mode (i.e., {opt secb()} or
{opt spcb()} must be specified). If omitted, constants at {opt secb()} and
{opt spcb()} are used.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt level(#)} specifies the confidence level for the percentile interval.
Default is {cmd:95}.

{phang}
{opt saving(filename, replace)} saves the Monte Carlo dataset to a Stata
file. The saved dataset contains Se/Sp draws, corrected cell counts, and
corrected measures. This file can be used with {cmd:qba_plot, distribution}
for visualization.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Identifiability constraint.} The correction requires Se + Sp > 1. When
Se + Sp <= 1, the classification performs no better than chance, and the
corrected table is unidentifiable. This constraint is enforced for both
the fixed parameters and (in probabilistic mode) for each draw;
replicates violating it are excluded.

{pstd}
{bf:Nondifferential vs. differential.} Nondifferential misclassification
assumes that misclassification rates are the same regardless of disease or
exposure status. Nondifferential exposure misclassification generally biases
the odds ratio toward the null. Differential misclassification can bias the
estimate in either direction.

{pstd}
{bf:Choosing distributions.} Lash, Fox, and Fink (2021) recommend trapezoidal
distributions for encoding expert opinion about likely ranges of Se and Sp.
When validation study data or prior information are available, a Beta
distribution is appropriate. Beta shape parameters represent the strength of
prior information; they need not be literal validation counts.

{pstd}
{bf:Negative corrected cells.} When fixed bias parameters produce negative
corrected cells, the corrected OR or RR is reported as missing. The corrected
cells are still displayed so you can see how the bias parameters failed for
the observed table.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Simple nondifferential exposure misclassification}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)}{p_end}

{pstd}
{bf:Example 2: Differential exposure misclassification}

{pstd}
Se and Sp differ between cases ({opt seca}, {opt spca}) and non-cases
({opt secb}, {opt spcb}):

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.90) spca(.95) secb(.80) spcb(.95)}{p_end}

{pstd}
{bf:Example 3: Outcome misclassification with RR}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.92) spca(.98) type(outcome) measure(RR)}{p_end}

{pstd}
{bf:Example 4: Probabilistic analysis with trapezoidal distributions}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)} ///
{phang3}{cmd:reps(10000) dist_se("trapezoidal .75 .82 .88 .95")} ///
{phang3}{cmd:dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345)}{p_end}

{pstd}
{bf:Example 5: Probabilistic analysis with Beta distributions}

{pstd}
When Se and Sp are estimated from validation data or prior information, Beta
distributions are natural:

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)} ///
{phang3}{cmd:reps(10000) dist_se("beta 17 3") dist_sp("beta 19 1")} ///
{phang3}{cmd:seed(12345) saving(mc_results, replace)}{p_end}

{pstd}
{bf:Example 6: Visualize results}

{phang2}{cmd:. qba_plot, distribution using(mc_results) observed(2.15)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_misclass} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars (simple mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}corrected measure of association; missing when corrected cells are infeasible{p_end}
{synopt:{cmd:r(ratio)}}corrected / observed (when both are defined){p_end}
{synopt:{cmd:r(a)}}observed cell a{p_end}
{synopt:{cmd:r(b)}}observed cell b{p_end}
{synopt:{cmd:r(c)}}observed cell c{p_end}
{synopt:{cmd:r(d)}}observed cell d{p_end}
{synopt:{cmd:r(corrected_a)}}corrected cell a{p_end}
{synopt:{cmd:r(corrected_b)}}corrected cell b{p_end}
{synopt:{cmd:r(corrected_c)}}corrected cell c{p_end}
{synopt:{cmd:r(corrected_d)}}corrected cell d{p_end}
{synopt:{cmd:r(seca)}}sensitivity (group A / overall){p_end}
{synopt:{cmd:r(spca)}}specificity (group A / overall){p_end}
{synopt:{cmd:r(secb)}}sensitivity group B (differential only){p_end}
{synopt:{cmd:r(spcb)}}specificity group B (differential only){p_end}

{p2col 5 20 24 2: Scalars (probabilistic mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}median corrected measure{p_end}
{synopt:{cmd:r(mean)}}mean of corrected measures{p_end}
{synopt:{cmd:r(sd)}}standard deviation of corrected measures{p_end}
{synopt:{cmd:r(ci_lower)}}lower bound of percentile confidence interval{p_end}
{synopt:{cmd:r(ci_upper)}}upper bound of percentile confidence interval{p_end}
{synopt:{cmd:r(reps)}}number of replications requested{p_end}
{synopt:{cmd:r(n_valid)}}number of valid (non-missing) replications{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(type)}}misclassification type ({cmd:exposure} or {cmd:outcome}){p_end}
{synopt:{cmd:r(measure)}}measure of association ({cmd:OR} or {cmd:RR}){p_end}
{synopt:{cmd:r(method)}}{cmd:simple} or {cmd:probabilistic}{p_end}
{synopt:{cmd:r(dist_se)}}Se distribution specification (probabilistic only){p_end}
{synopt:{cmd:r(dist_sp)}}Sp distribution specification (probabilistic only){p_end}


{title:References}

{phang}
Lash TL, Fox MP, Fink AK. {it:Applying Quantitative Bias Analysis to}
{it:Epidemiologic Data}. 2nd ed. New York: Springer; 2021. Chapters 5-6.

{phang}
Fox MP, Lash TL, Greenland S. A method to automate probabilistic
sensitivity analyses of misclassified binary variables.
{it:Int J Epidemiol}. 2005;34(6):1370-1376.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-06-02{p_end}

{hline}
