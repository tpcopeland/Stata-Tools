{smcl}
{* *! version 1.0.1  19jun2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{viewerjumpto "Syntax" "qba_plot##syntax"}{...}
{viewerjumpto "Description" "qba_plot##description"}{...}
{viewerjumpto "Options" "qba_plot##options"}{...}
{viewerjumpto "Remarks" "qba_plot##remarks"}{...}
{viewerjumpto "Examples" "qba_plot##examples"}{...}
{viewerjumpto "Stored results" "qba_plot##results"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:qba_plot} {hline 2}}Visualization for quantitative bias analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:qba_plot}
{cmd:,}
{opt tor:nado} | {opt dist:ribution} | {opt tip:ping}
[{it:options}]


{synoptset 40 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Plot type (choose exactly one)}
{synopt:{opt tor:nado}}tornado sensitivity plot{p_end}
{synopt:{opt dist:ribution}}histogram and kernel density of Monte Carlo results{p_end}
{synopt:{opt tip:ping}}tipping point heatmap{p_end}

{syntab:Data (tornado and tipping)}
{synopt:{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}}2x2 table cells{p_end}
{synopt:{opt ty:pe(exposure|outcome)}}misclassification type; default {cmd:exposure}{p_end}
{synopt:{opt mea:sure(OR|RR|coefficient)}}estimate to plot; {cmd:coefficient} is for distribution plots only{p_end}

{syntab:Parameters to sweep}
{synopt:{opt param1(name)} {opt range1(# #)}}first parameter and sweep range (required for tornado/tipping){p_end}
{synopt:{opt param2(name)} {opt range2(# #)}}second parameter and sweep range (required for tipping){p_end}
{synopt:{opt param3(name)} {opt range3(# #)}}third parameter (tornado only){p_end}
{synopt:{opt steps(#)}}grid steps per parameter; default {cmd:20}; minimum {cmd:2}{p_end}

{syntab:Baseline values (for non-swept parameters)}
{synopt:{opt base_se(#)}}baseline sensitivity; default {cmd:0.9}{p_end}
{synopt:{opt base_sp(#)}}baseline specificity; default {cmd:0.9}{p_end}
{synopt:{opt base_sela(#)}}baseline selection prob, exposed cases; default {cmd:1}{p_end}
{synopt:{opt base_selb(#)}}baseline selection prob, unexposed cases; default {cmd:1}{p_end}
{synopt:{opt base_selc(#)}}baseline selection prob, exposed non-cases; default {cmd:1}{p_end}
{synopt:{opt base_seld(#)}}baseline selection prob, unexposed non-cases; default {cmd:1}{p_end}
{synopt:{opt base_p1(#)}}baseline P(confounder | exposed); default {cmd:0.3}{p_end}
{synopt:{opt base_p0(#)}}baseline P(confounder | unexposed); default {cmd:0.1}{p_end}
{synopt:{opt base_rrcd(#)}}baseline confounder-disease RR; default {cmd:2}{p_end}
{synopt:{opt base_rrud(#)}}baseline confounder-disease RR using Greenland parameterization{p_end}

{syntab:Distribution plot}
{synopt:{opt us:ing(filename)}}Monte Carlo dataset from a {cmd:saving()} option{p_end}
{synopt:{opt obs:erved(#)}}observed measure value (required for distribution plot){p_end}
{synopt:{opt nu:ll(#)}}null value for reference line; defaults to {cmd:1} for OR/RR and {cmd:0} for coefficients{p_end}

{syntab:Graph options}
{synopt:{opt sch:eme(name)}}graph scheme; default is the current Stata scheme{p_end}
{synopt:{opt ti:tle(string)}}custom graph title{p_end}
{synopt:{opt sa:ving(filename)}}export graph to file{p_end}
{synopt:{opt name(name)}}assign name to graph window{p_end}
{synopt:{opt replace}}replace existing file or named graph{p_end}
{synopt:{it:twoway_options}}additional options passed to {cmd:twoway}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_plot} creates three types of visualizations for quantitative bias
analysis:

{phang}
{bf:tornado} - Shows how the corrected estimate changes as each bias parameter
is varied across its range while other parameters are held at their baseline
values. This reveals which parameters have the greatest influence on the
corrected estimate. Up to three parameters can be displayed simultaneously.

{phang}
{bf:distribution} - Histogram and kernel density plot of corrected estimates
from a probabilistic bias analysis. Displays the full uncertainty
distribution with reference lines for the observed estimate (red dashed), the
null value (gray dotted), and the median (green dashed). Requires a saved
Monte Carlo dataset from a {cmd:saving()} option.

{phang}
{bf:tipping} - Heatmap showing combinations of two bias parameters. Points
are colored by whether the corrected estimate crosses the null (cranberry),
remains above the observed (blue), or falls below the observed (green).
Identifies which parameter combinations would change the study conclusion.


{marker options}{...}
{title:Options}

{dlgtab:Plot type}

{phang}
{opt tornado} creates a tornado sensitivity plot. Requires {opt a()}-{opt d()}
and at least {opt param1()} with {opt range1()}.

{phang}
{opt distribution} creates a histogram/density plot. Requires {opt using()}
and {opt observed()}.

{phang}
{opt tipping} creates a tipping point heatmap. Requires {opt a()}-{opt d()},
{opt param1()} with {opt range1()}, and {opt param2()} with {opt range2()}.

{dlgtab:Data}

{phang}
{opt a(#)}, {opt b(#)}, {opt c(#)}, {opt d(#)} specify the 2x2 table cells.
Required for tornado and tipping plots.

{phang}
{opt type(exposure|outcome)} specifies the misclassification type for
computing corrected estimates when sweeping misclassification parameters.
Default is {cmd:exposure}.

{phang}
{opt measure(OR|RR|coefficient)} specifies the estimate to plot. Tornado and
tipping plots support {cmd:OR} and {cmd:RR}. Distribution plots support
{cmd:OR}, {cmd:RR}, and {cmd:coefficient}; if omitted, the measure is inferred
from the saved result variable when exactly one of {cmd:corrected_or},
{cmd:corrected_rr}, or {cmd:corrected_coefficient} is present.

{dlgtab:Parameters to sweep}

{phang}
{opt param1(name)}, {opt param2(name)}, {opt param3(name)} specify which bias
parameters to vary. Recognized parameter names are:

{p2colset 12 30 32 2}{...}
{p2col:{cmd:se} or {cmd:seca}}sensitivity (misclassification){p_end}
{p2col:{cmd:sp} or {cmd:spca}}specificity (misclassification){p_end}
{p2col:{cmd:sela}}selection probability, exposed cases{p_end}
{p2col:{cmd:selb}}selection probability, unexposed cases{p_end}
{p2col:{cmd:selc}}selection probability, exposed non-cases{p_end}
{p2col:{cmd:seld}}selection probability, unexposed non-cases{p_end}
{p2col:{cmd:p1}}confounder prevalence among exposed{p_end}
{p2col:{cmd:p0}}confounder prevalence among unexposed{p_end}
{p2col:{cmd:rrcd}}confounder-disease RR (Schneeweiss formula){p_end}
{p2col:{cmd:rrud}}confounder-disease RR (Greenland formula){p_end}
{p2colreset}{...}

{pmore}
Note: {cmd:secb} and {cmd:spcb} (differential misclassification parameters)
are not supported in tornado or tipping plots. Use {cmd:seca}/{cmd:spca} for
nondifferential sensitivity analysis.

{phang}
{opt range1(# #)}, {opt range2(# #)}, {opt range3(# #)} specify the minimum
and maximum values for the corresponding parameter's sweep range. Sensitivity,
specificity, and selection probabilities must be in (0,1]; confounder
prevalences must be in [0,1]; and confounder relative risks must be greater
than 0.

{phang}
{opt steps(#)} specifies the number of grid points per parameter. Default is
{cmd:20}. Minimum is {cmd:2}. For tipping plots, the total number of computed
points is steps^2, so values above 50 may be slow.

{dlgtab:Baseline values}

{phang}
{opt base_se(#)} and {opt base_sp(#)} specify baseline values for sensitivity
and specificity when those parameters are not being swept. Defaults are 0.9.

{phang}
{opt base_sela(#)} through {opt base_seld(#)} specify baseline selection
probabilities for non-swept selection parameters. Defaults are 1 (no
selection bias).

{phang}
{opt base_p1(#)}, {opt base_p0(#)}, {opt base_rrcd(#)}, and {opt base_rrud(#)}
specify baseline confounding parameters for non-swept confounding parameters.
Defaults are 0.3, 0.1, 2, and unset, respectively. Specify {opt base_rrud()}
to use the Greenland parameterization for p1/p0 sweeps; otherwise p1/p0
sweeps use {opt base_rrcd()} and the Schneeweiss parameterization.

{pmore}
Baseline values are validated on the same support as their corresponding
sweep parameters.

{dlgtab:Distribution plot}

{phang}
{opt using(filename)} specifies the Stata dataset containing Monte Carlo
results, saved by a previous {cmd:saving()} option from any {cmd:qba_*}
command. The dataset must contain a variable named {cmd:corrected_or} or
{cmd:corrected_rr}, or {cmd:corrected_coefficient} for saved linear-model
confounding analyses. If multiple corrected result variables are present,
specify {opt measure()}.

{phang}
{opt observed(#)} specifies the observed measure value, shown as a red
dashed reference line. Required for distribution plots.

{phang}
{opt null(#)} specifies the null value shown as a gray dotted reference line.
If omitted, the default is {cmd:1} for OR/RR plots and {cmd:0} for coefficient
plots.

{dlgtab:Graph options}

{phang}
{opt scheme(name)} specifies the Stata graph scheme. Default is the current
Stata scheme.

{phang}
{opt title(string)} specifies a custom graph title. If omitted, a default
title is generated based on the plot type and measure.

{phang}
{opt saving(filename)} exports the graph to the specified file. Use with
{opt replace} to overwrite existing files.

{phang}
{opt name(name)} assigns a name to the graph window in memory. Use with
{opt replace} to replace an existing named graph. The graph-style form
{cmd:name(}{it:name}{cmd:, replace)} is also accepted.

{phang}
{it:twoway_options} — any additional options are passed through to the
underlying {cmd:twoway} command.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Tipping plot parameter types.} The tipping plot computes corrected
estimates across a grid of two parameters. For correct results, both
parameters should be of the same bias type: both misclassification (e.g.,
{cmd:se} and {cmd:sp}) or both confounding (e.g., {cmd:p1} and {cmd:rrcd}).
Mixed parameter types (e.g., one misclassification and one confounding) and
selection parameters are not supported and produce error 198. The two
alternative confounder-disease parameterizations, {cmd:rrcd} and {cmd:rrud},
cannot be used as the two axes in the same tipping plot.

{pstd}
{bf:Tornado plot with confounding parameters.} When sweeping confounding
parameters (p1, p0, rrcd, rrud), the correction is applied at the measure
level (dividing the observed measure by the bias factor). This uses the
observed measure computed from the 2x2 table. The non-swept confounding
parameters are held at their baseline values ({opt base_p1()},
{opt base_p0()}, and either {opt base_rrcd()} or {opt base_rrud()}).


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Tornado plot for Se and Sp}

{phang2}{cmd:. qba_plot, tornado a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(se) range1(.7 1) param2(sp) range2(.8 1) steps(30)}{p_end}

{pstd}
{bf:Example 2: Tornado plot for confounding parameters}

{phang2}{cmd:. qba_plot, tornado a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(p1) range1(0 .6) param2(rrcd) range2(1 4)}{p_end}

{pstd}
{bf:Example 3: Tornado with three parameters}

{phang2}{cmd:. qba_plot, tornado a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(se) range1(.7 1) param2(sp) range2(.8 1)} ///
{phang3}{cmd:param3(sela) range3(.5 1)}{p_end}

{pstd}
{bf:Example 4: Distribution plot from saved MC results}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)} ///
{phang3}{cmd:reps(10000) dist_se("trapezoidal .75 .82 .88 .95")} ///
{phang3}{cmd:dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345) saving(mc_results, replace)}{p_end}
{phang2}{cmd:. qba_plot, distribution using(mc_results) observed(2.15)}{p_end}

{pstd}
{bf:Example 5: Tipping point plot for misclassification (Se vs. Sp)}

{phang2}{cmd:. qba_plot, tipping a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(se) range1(.6 1) param2(sp) range2(.6 1) steps(25)}{p_end}

{pstd}
{bf:Example 6: Tipping point plot for confounding (p1 vs. RRcd)}

{phang2}{cmd:. qba_plot, tipping a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(p1) range1(0 .6) param2(rrcd) range2(1 5)}{p_end}

{pstd}
{bf:Example 7: Custom title and scheme}

{phang2}{cmd:. qba_plot, tornado a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(se) range1(.7 1) title("Sensitivity of OR to Misclassification")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_plot} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_missing)}}number of infeasible or undefined grid points (tornado/tipping){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(plot_type)}}plot type ({cmd:tornado}, {cmd:distribution}, or {cmd:tipping}){p_end}
{synopt:{cmd:r(measure)}}plotted measure ({cmd:OR}, {cmd:RR}, or {cmd:coefficient}){p_end}
{synopt:{cmd:r(scheme)}}graph scheme used{p_end}


{title:References}

{phang}
Lash TL, Fox MP, Fink AK. {it:Applying Quantitative Bias Analysis to}
{it:Epidemiologic Data}. 2nd ed. New York: Springer; 2021.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.0.1, 2026-06-19{p_end}

{hline}
