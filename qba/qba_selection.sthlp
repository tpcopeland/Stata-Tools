{smcl}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{vieweralsosee "qba_plot" "help qba_plot"}{...}
{viewerjumpto "Syntax" "qba_selection##syntax"}{...}
{viewerjumpto "Description" "qba_selection##description"}{...}
{viewerjumpto "Options" "qba_selection##options"}{...}
{viewerjumpto "Remarks" "qba_selection##remarks"}{...}
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
{synopt:{opt reps(#)}}Monte Carlo replications (minimum 100; enables probabilistic mode){p_end}
{synopt:{opt dist_sela(distribution)}}distribution for sela; default constant at {cmd:sela()}{p_end}
{synopt:{opt dist_selb(distribution)}}distribution for selb; default constant at {cmd:selb()}{p_end}
{synopt:{opt dist_selc(distribution)}}distribution for selc; default constant at {cmd:selc()}{p_end}
{synopt:{opt dist_seld(distribution)}}distribution for seld; default constant at {cmd:seld()}{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt level(#)}}confidence level for percentile interval; default {cmd:95}{p_end}
{synopt:{opt sa:ving(filename, ...)}}save Monte Carlo dataset for use with {helpb qba_plot}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_selection} corrects 2x2 table cell counts and measures of association
for selection bias by specifying the probability of selection into the study
for each exposure-outcome stratum.

{pstd}
The correction divides each observed cell count by its selection probability
to estimate the corresponding source population count:

{p 12 12 2}
a* = a / S_a,    b* = b / S_b,    c* = c / S_c,    d* = d / S_d

{pstd}
where S_a through S_d are the selection probabilities. The corrected measure
of association is then computed from the corrected table.

{pstd}
Selection bias arises when the probability of being included in the study
depends on both exposure and outcome, causing the selection probabilities to
differ across strata. When all four probabilities are equal, there is no
selection bias and the corrected estimate equals the observed estimate.

{pstd}
The selection bias factor on the OR scale is reported as:

{p 12 12 2}
SBF = (S_a * S_d) / (S_b * S_c)

{pstd}
When SBF > 1, the observed OR overestimates the source population OR; when
SBF < 1, it underestimates it.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt a(#)}, {opt b(#)}, {opt c(#)}, {opt d(#)} specify the four cells of the
observed 2x2 table. All values must be non-negative.

{phang}
{opt sela(#)} through {opt seld(#)} specify the selection probability for each
cell of the 2x2 table. Each value must be in (0, 1]. The layout matches the
2x2 table: {opt sela()} for exposed cases, {opt selb()} for unexposed cases,
{opt selc()} for exposed non-cases, {opt seld()} for unexposed non-cases.

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
{opt dist_sela(distribution)} through {opt dist_seld(distribution)} specify
distributions from which each selection probability is drawn at each
replicate. If omitted, a constant at the corresponding fixed value is used.
See {helpb qba} for distribution syntax.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt level(#)} specifies the confidence level for the percentile interval.
Default is {cmd:95}.

{phang}
{opt saving(filename, replace)} saves the Monte Carlo dataset to a Stata
file containing selection probability draws, corrected cell counts, and
corrected measures. This file can be used with {cmd:qba_plot, distribution}
for visualization.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Interpreting selection probabilities.} Selection probabilities represent the
proportion of each exposure-outcome stratum that is included in the study
sample. They are not the probability of exposure or outcome. A study where
exposed cases are more likely to participate (S_a > S_d, for example) will
tend to inflate the observed OR.

{pstd}
{bf:Estimating selection probabilities.} In practice, selection probabilities
are rarely known precisely. They may be estimated from external data sources,
administrative records comparing participants to the target population, or
expert opinion. Probabilistic analysis with distributions reflecting this
uncertainty is strongly recommended.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Simple selection bias correction (OR)}

{phang2}{cmd:. qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8)}{p_end}

{pstd}
{bf:Example 2: Selection bias correction with RR}

{phang2}{cmd:. qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8) measure(RR)}{p_end}

{pstd}
{bf:Example 3: Probabilistic with uniform distributions}

{phang2}{cmd:. qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:reps(10000) dist_sela("uniform .8 1.0") dist_selb("uniform .75 .95")} ///
{phang3}{cmd:dist_selc("uniform .6 .8") dist_seld("uniform .7 .9") seed(54321)}{p_end}

{pstd}
{bf:Example 4: Probabilistic with trapezoidal distributions and saving}

{phang2}{cmd:. qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:reps(10000) dist_sela("trapezoidal .8 .85 .95 1.0")} ///
{phang3}{cmd:dist_selb("trapezoidal .7 .80 .90 .95")} ///
{phang3}{cmd:dist_selc("trapezoidal .5 .65 .75 .85")} ///
{phang3}{cmd:dist_seld("trapezoidal .6 .75 .85 .90") seed(54321) saving(mc_sel, replace)}{p_end}

{pstd}
{bf:Example 5: Visualize results}

{phang2}{cmd:. qba_plot, distribution using(mc_sel) observed(2.15)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_selection} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars (simple mode)}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}corrected measure of association{p_end}
{synopt:{cmd:r(bias_factor)}}selection bias factor on the OR scale{p_end}
{synopt:{cmd:r(ratio)}}corrected / observed (when both are defined){p_end}
{synopt:{cmd:r(a)}}observed exposed cases cell count{p_end}
{synopt:{cmd:r(b)}}observed unexposed cases cell count{p_end}
{synopt:{cmd:r(c)}}observed exposed non-cases cell count{p_end}
{synopt:{cmd:r(d)}}observed unexposed non-cases cell count{p_end}
{synopt:{cmd:r(corrected_a)}}corrected exposed cases cell count{p_end}
{synopt:{cmd:r(corrected_b)}}corrected unexposed cases cell count{p_end}
{synopt:{cmd:r(corrected_c)}}corrected exposed non-cases cell count{p_end}
{synopt:{cmd:r(corrected_d)}}corrected unexposed non-cases cell count{p_end}
{synopt:{cmd:r(sela)}}selection probability for exposed cases{p_end}
{synopt:{cmd:r(selb)}}selection probability for unexposed cases{p_end}
{synopt:{cmd:r(selc)}}selection probability for exposed non-cases{p_end}
{synopt:{cmd:r(seld)}}selection probability for unexposed non-cases{p_end}

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
{synopt:{cmd:r(measure)}}measure of association ({cmd:OR} or {cmd:RR}){p_end}
{synopt:{cmd:r(method)}}{cmd:simple} or {cmd:probabilistic}{p_end}


{title:References}

{phang}
Lash TL, Fox MP, Fink AK. {it:Applying Quantitative Bias Analysis to}
{it:Epidemiologic Data}. 2nd ed. New York: Springer; 2021. Chapter 7.

{phang}
Greenland S. Basic methods for sensitivity analysis of biases.
{it:Int J Epidemiol}. 1996;25(6):1107-1116.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
