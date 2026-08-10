{smcl}
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
{synopt:{opt secb(#)}}Se, second stratum; enables differential{p_end}
{synopt:{opt spcb(#)}}Sp, second stratum; enables differential{p_end}

{syntab:Measure}
{synopt:{opt mea:sure(OR|RR)}}measure of association; default {cmd:OR}{p_end}

{syntab:Study design}
{synopt:{opt fcas:e(#)}}case sampling fraction; default {cmd:1}{p_end}
{synopt:{opt fctr:l(#)}}non-case sampling fraction; default {cmd:1}{p_end}

{syntab:Probabilistic}
{synopt:{opt reps(#)}}Monte Carlo replications; minimum 100{p_end}
{synopt:{opt dist_se(distribution)}}Se distribution; default constant{p_end}
{synopt:{opt dist_sp(distribution)}}Sp distribution; default constant{p_end}
{synopt:{opt dist_se1(distribution)}}Se distribution, second stratum{p_end}
{synopt:{opt dist_sp1(distribution)}}Sp distribution, second stratum{p_end}
{synopt:{opt corr(#)}}Se/Sp correlation across strata{p_end}
{synopt:{opt to:talerror}}also report total-error intervals{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt level(#)}}simulation-interval level; default {cmd:c(level)}{p_end}
{synopt:{opt sa:ving(filename, ...)}}save the Monte Carlo dataset{p_end}
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

{p2colset 12 24 26 2}{...}
{p2col:{bf:Row}}{bf:Cells}{p_end}
{p2col:{bf:Cases}}exposed {cmd:a}; unexposed {cmd:b}{p_end}
{p2col:{bf:Non-cases}}exposed {cmd:c}; unexposed {cmd:d}{p_end}
{p2colreset}{...}

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
Simple mode warns when any corrected cell is not strictly positive, indicating
the bias parameters are incompatible with the observed data. In that case
corrected cells are displayed, but the corrected measure and ratio are reported
as missing rather than as an impossible effect measure. Zero is treated the
same as negative: the worked example in Fox, MacLehose, and Lash (2023)
discards simulations with negative {it:or zero} bias-adjusted cells, and
probabilistic mode applies the same rule.

{pstd}
{bf:Probabilistic mode} ({opt reps(#)}): Draws Se and Sp values from
specified distributions at each replicate, computes the corrected table,
and returns the distribution of corrected estimates. Replicates producing
nonpositive corrected cells or undefined measures are excluded.

{pstd}
The reported percentile interval is a
{bf:systematic-error simulation interval}: it propagates uncertainty in the
bias parameters and nothing else. It is not a corrected confidence interval,
and it does {it:not} widen for sampling variability -- with a large table and
tight bias-parameter distributions it can be narrower than the conventional
confidence interval.

{pstd}
{bf:Total error} ({opt totalerror}): adds the two further uncertainty sources
of the revised summary-level algorithm in Fox, MacLehose, and Lash (2023) and
reports the resulting total-error simulation interval:

{p 8 12 2}
1. the classified-variable prevalence in each stratum is drawn
Beta({it:adjusted cell}, {it:complement}), converted to predictive values, and
the observed cells are reallocated by binomial draws; then

{p 8 12 2}
2. the log measure from those reallocated cells is perturbed by
{it:z} * SE, where SE is the standard error of the log measure computed on the
reallocated cells.

{pstd}
A random-error-only arm (the observed measure perturbed by its own log
standard error) is reported alongside, so the three interval widths are
directly comparable. The systematic- and total-error arms use the same common
valid-replication mask, requiring both corrected and reallocated cells to be
strictly positive. {opt totalerror} requires whole-number cell counts, all
four greater than zero, because step 1 reallocates counts.


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
(cases for exposure misclassification; exposed for outcome
misclassification). Each value must be in (0, 1] and their sum must exceed 1.

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

{dlgtab:Study design}

{phang}
{opt fcase(#)} and {opt fctrl(#)} give the fraction of source-population cases
and of source-population non-cases that were sampled, and apply to
{opt type(outcome)} only. Outcome misclassification must be corrected on the
source-population table, so the case row is divided by {opt fcase()} and the
non-case row by {opt fctrl()} before the correction. Each must be in
(0, 1]; both default to {cmd:1} (a census or full cohort). Exposure
misclassification
is corrected within outcome strata and needs no such adjustment, so specifying
either option with {opt type(exposure)} is an error.

{phang}
Without these options {opt type(outcome)} assumes the observed table
{it:is} the source-population table. Applying it to case-control data with
{opt fcase()} and {opt fctrl()} left at their defaults gives a wrong answer
with no warning, because the sampled non-case row understates the
source-population non-case row.

{dlgtab:Probabilistic}

{phang}
{opt reps(#)} specifies the number of Monte Carlo replications. The minimum
accepted is 100, which is a floor rather than a stability guarantee: Fox,
MacLehose, and Lash (2023) repeat the process "hundreds of thousands" of
times, and their worked summary-level examples use 10^5 to 10^6
replications. Specifying {opt reps()} activates probabilistic mode.

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
{opt corr(#)} induces a correlation between the case-stratum and
non-case-stratum bias parameters, in [-1, 1]; the default {cmd:0} draws them
independently. Se and Sp are correlated separately (Se with Se, Sp with
Sp); they are never correlated with each other. Dependence is imposed by a
Gaussian
copula, so each marginal distribution is exactly the one requested in
{opt dist_se()}, {opt dist_sp()}, {opt dist_se1()}, and {opt dist_sp1()}; only
the joint behaviour changes. The author reference code for Fox, MacLehose, and
Lash (2023) uses 0.80 in its examples. {opt corr()} requires differential
mode: nondifferential misclassification has one Se and one Sp, so there is no
second
parameter to correlate with. Note that the realized Pearson correlation of the
drawn parameters is at or slightly below {opt corr(#)}, and falls further the
more skewed the marginal is -- an inherent property of the Gaussian copula, not
an error.

{phang}
{opt totalerror} additionally reports a total-error simulation interval and a
random-error-only interval; see
{help qba_misclass##description:Description}. It requires whole-number cell
counts, all four greater than zero.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt level(#)} specifies the level for the percentile simulation
interval. The default is the current {cmd:c(level)} setting (95 unless changed).

{phang}
{opt saving(filename, replace)} saves the Monte Carlo dataset to a Stata
file. The saved dataset contains Se/Sp draws, corrected cell counts, and
corrected measures, and with {opt totalerror} also the reallocated cells and
the reclassification, total-error, and random-error measures. It has one row
per {it:requested} replication: invalid replications are retained as rows with
missing corrected measures, not dropped, so the row count always equals
{opt reps()}. This file can be used with {cmd:qba_plot, distribution} for
visualization.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Identifiability constraint.} The correction requires Se + Sp > 1. When Se + Sp
<= 1, the classification performs no better than chance, and the corrected
table is unidentifiable. This constraint is enforced for both the fixed
parameters and (in probabilistic mode) for each draw; replicates violating it
are excluded.

{pstd}
{bf:Nondifferential vs. differential.} Nondifferential misclassification
assumes that misclassification rates are the same regardless of disease or
exposure status. Nondifferential exposure misclassification generally biases
the odds ratio toward the null. Differential misclassification can bias the
estimate in either direction.

{pstd}
{bf:Choosing distributions.} Fox, MacLehose, and Lash (2021) recommend trapezoidal
distributions for encoding expert opinion about likely ranges of Se and
Sp. When validation study data or prior information are available, a Beta
distribution is appropriate. Beta shape parameters represent the strength of
prior information; they need not be literal validation counts.

{pstd}
{bf:Nonpositive corrected cells.} When fixed bias parameters produce a
corrected cell that is negative or zero, the corrected OR or RR is reported as
missing. The corrected cells are still displayed so you can see how the bias
parameters failed for the observed table.

{pstd}
{bf:What the interval is.} Fox, MacLehose, and Lash (2023) distinguish a
{it:systematic-error} simulation interval -- percentiles of estimates obtained
by drawing bias parameters -- from a {it:total-error} simulation interval,
which also carries conventional random error. The default output here is the
former. Report it as a simulation interval, not as a corrected confidence
interval, and use {opt totalerror} when you want an interval that is
comparable in kind to a confidence interval.

{pstd}
{bf:Case-control outcome misclassification.} Correcting outcome
misclassification in a case-control study requires the case and control
sampling fractions; supply them with {opt fcase()} and {opt fctrl()}. Exposure
misclassification in a case-control study needs no such adjustment, because it
is corrected within the case and non-case rows, which are each complete as
sampled.


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

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)} ///{p_end}
{phang3}{cmd:reps(10000) dist_se("trapezoidal .75 .82 .88 .95")} ///{p_end}
{phang3}{cmd:dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345)}{p_end}

{pstd}
{bf:Example 5: Probabilistic analysis with Beta distributions}

{pstd}
When Se and Sp are estimated from validation data or prior information, Beta
distributions are natural:

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)} ///{p_end}
{phang3}{cmd:reps(10000) dist_se("beta 17 3") dist_sp("beta 19 1")} ///{p_end}
{phang3}{cmd:seed(12345) saving(mc_results, replace)}{p_end}

{pstd}
{bf:Example 6: Visualize results}

{phang2}{cmd:. qba_plot, distribution using(mc_results) observed(2.15)}{p_end}

{pstd}
{bf:Example 7: Total-error simulation interval}

{pstd}
Report the systematic-error, random-error, and total-error intervals side by
side:

{phang2}{cmd:. qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) measure(RR)} ///{p_end}
{phang3}{cmd:reps(100000) dist_se("beta 50.6 14.3") dist_sp("beta 70 1")} ///{p_end}
{phang3}{cmd:totalerror seed(12345)}{p_end}

{pstd}
{bf:Example 8: Correlated Se and Sp across strata}

{pstd}
Sensitivity in cases and in non-cases are rarely independent; correlate them
at 0.80 while keeping the requested Beta marginals:

{phang2}{cmd:. qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) secb(.75) spcb(.98)} ///{p_end}
{phang3}{cmd:measure(RR) reps(100000) dist_se("beta 50.6 14.3") dist_sp("beta 70 1")} ///{p_end}
{phang3}{cmd:dist_se1("beta 45 15") dist_sp1("beta 70 1") corr(0.80) seed(12345)}{p_end}

{pstd}
{bf:Example 9: Outcome misclassification in a case-control study}

{pstd}
All cases and a 10% sample of non-cases were selected, so the non-case row is
inflated back to the source population before the correction:

{phang2}{cmd:. qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) measure(OR)} ///{p_end}
{phang3}{cmd:seca(.92) spca(.98) fcase(1) fctrl(.1)} ///{p_end}
{phang3}{cmd:reps(100000) dist_se("beta 35 3") dist_sp("uniform .96 1") totalerror seed(12345)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_misclass} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars (simple mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}corrected measure; missing when infeasible{p_end}
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
{synopt:{cmd:r(ci_lower)}}lower limit of the systematic-error simulation interval{p_end}
{synopt:{cmd:r(ci_upper)}}upper limit of the systematic-error simulation interval{p_end}
{synopt:{cmd:r(reps)}}number of replications requested{p_end}
{synopt:{cmd:r(n_valid)}}number of valid (non-missing) replications{p_end}
{synopt:{cmd:r(corr)}}Se/Sp correlation, when {opt corr()} is nonzero{p_end}

{p2col 5 20 24 2: Scalars ({opt totalerror} only)}{p_end}
{synopt:{cmd:r(te_median)}}median total-error measure{p_end}
{synopt:{cmd:r(te_mean)}}mean total-error measure{p_end}
{synopt:{cmd:r(te_sd)}}standard deviation of total-error measures{p_end}
{synopt:{cmd:r(te_lower)}}lower limit of the total-error simulation interval{p_end}
{synopt:{cmd:r(te_upper)}}upper limit of the total-error simulation interval{p_end}
{synopt:{cmd:r(n_valid_te)}}number of valid total-error replications{p_end}
{synopt:{cmd:r(re_median)}}median random-error-only measure{p_end}
{synopt:{cmd:r(re_lower)}}lower limit of the random-error-only interval{p_end}
{synopt:{cmd:r(re_upper)}}upper limit of the random-error-only interval{p_end}

{p2col 5 20 24 2: Scalars ({opt fcase()} or {opt fctrl()} only)}{p_end}
{synopt:{cmd:r(fcase)}}case sampling fraction{p_end}
{synopt:{cmd:r(fctrl)}}non-case sampling fraction{p_end}
{synopt:{cmd:r(adj_a)}}source-population cell a{p_end}
{synopt:{cmd:r(adj_b)}}source-population cell b{p_end}
{synopt:{cmd:r(adj_c)}}source-population cell c{p_end}
{synopt:{cmd:r(adj_d)}}source-population cell d{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(type)}}misclassification type ({cmd:exposure} or {cmd:outcome}){p_end}
{synopt:{cmd:r(measure)}}measure of association ({cmd:OR} or {cmd:RR}){p_end}
{synopt:{cmd:r(method)}}{cmd:simple} or {cmd:probabilistic}{p_end}
{synopt:{cmd:r(interval)}}what {cmd:r(ci_lower)}/{cmd:r(ci_upper)} are (probabilistic only){p_end}
{synopt:{cmd:r(dist_se)}}Se distribution specification (probabilistic only){p_end}
{synopt:{cmd:r(dist_sp)}}Sp distribution specification (probabilistic only){p_end}


{title:References}

{phang}
Fox MP, MacLehose RF, Lash TL. {it:Applying Quantitative Bias Analysis to}
{it:Epidemiologic Data}. 2nd ed. Cham: Springer; 2021. Chapter 6.

{phang}
Fox MP, Lash TL, Greenland S. A method to automate probabilistic sensitivity
analyses of misclassified binary
variables. {it:Int J Epidemiol}. 2005;34(6):1370-1376.

{phang}
Fox MP, MacLehose RF, Lash TL. SAS and R code for probabilistic quantitative
bias analysis for misclassified binary variables and binary unmeasured
confounders. {it:Int J Epidemiol}. 2023;52(5):1624-1633.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
