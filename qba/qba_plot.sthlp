{smcl}
{* *! version 1.0.0  13mar2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{viewerjumpto "Syntax" "qba_plot##syntax"}{...}
{viewerjumpto "Description" "qba_plot##description"}{...}
{viewerjumpto "Options" "qba_plot##options"}{...}
{viewerjumpto "Examples" "qba_plot##examples"}{...}
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


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Plot type (choose one)}
{synopt:{opt tor:nado}}tornado sensitivity plot{p_end}
{synopt:{opt dist:ribution}}histogram/density of MC results{p_end}
{synopt:{opt tip:ping}}tipping point heatmap{p_end}

{syntab:Data (tornado and tipping)}
{synopt:{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}}2x2 table cells{p_end}
{synopt:{opt type(exposure|outcome)}}misclassification type{p_end}
{synopt:{opt mea:sure(OR|RR)}}measure; default {cmd:OR}{p_end}

{syntab:Parameters to sweep}
{synopt:{opt param1(name)}}first parameter name (se, sp, seca, spca, etc.){p_end}
{synopt:{opt range1(# #)}}range for param1{p_end}
{synopt:{opt param2(name)}}second parameter name{p_end}
{synopt:{opt range2(# #)}}range for param2{p_end}
{synopt:{opt param3(name)}}third parameter name (tornado only){p_end}
{synopt:{opt range3(# #)}}range for param3{p_end}
{synopt:{opt steps(#)}}grid steps; default {cmd:20}{p_end}

{syntab:Distribution plot}
{synopt:{opt using(filename)}}dataset from {cmd:saving()} option{p_end}
{synopt:{opt obs:erved(#)}}observed measure value{p_end}
{synopt:{opt null(#)}}null value; default {cmd:1}{p_end}

{syntab:Graph options}
{synopt:{opt sch:eme(name)}}graph scheme; default {cmd:plotplainblind}{p_end}
{synopt:{opt title(string)}}graph title{p_end}
{synopt:{opt saving(filename)}}export graph{p_end}
{synopt:{opt name(name)}}name graph in memory{p_end}
{synopt:{opt replace}}replace existing file/graph{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_plot} creates three types of visualizations:

{phang}
{bf:tornado} - Shows how the corrected estimate changes as each bias parameter
varies across its range. Reveals which parameters have the greatest influence.

{phang}
{bf:distribution} - Histogram and kernel density of corrected estimates from
probabilistic bias analysis. Shows the full uncertainty distribution with
reference lines for the observed estimate, null, and median.

{phang}
{bf:tipping} - Heatmap showing combinations of two bias parameters. Points
are colored by whether the corrected estimate crosses the null, helping
identify which parameter combinations would change the study conclusion.


{marker options}{...}
{title:Options}

{dlgtab:Plot type}

{phang}
{opt tornado} creates a tornado sensitivity plot showing how the corrected
estimate changes as each parameter varies across its range.

{phang}
{opt distribution} creates a histogram and kernel density of corrected
estimates from probabilistic bias analysis. Requires {opt using()}.

{phang}
{opt tipping} creates a tipping point heatmap colored by whether the
corrected estimate crosses the null.

{dlgtab:Data (tornado and tipping)}

{phang}
{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)} specify the 2x2 table cells.
Required for tornado and tipping plots.

{phang}
{opt type(exposure|outcome)} specifies the misclassification type for
computing corrected estimates. Default is {cmd:exposure}.

{phang}
{opt measure(OR|RR)} specifies the measure of association. Default is
{cmd:OR}.

{dlgtab:Parameters to sweep}

{phang}
{opt param1(name)} and {opt range1(# #)} specify the first parameter name
and its sweep range. Parameter names include {cmd:se}, {cmd:sp},
{cmd:seca}, {cmd:spca}, {cmd:sela}, {cmd:selb}, {cmd:selc}, {cmd:seld},
{cmd:p1}, {cmd:p0}, {cmd:rrcd}.

{phang}
{opt param2(name)} and {opt range2(# #)} specify the second parameter.
Required for tornado and tipping plots.

{phang}
{opt param3(name)} and {opt range3(# #)} specify an optional third
parameter (tornado only).

{phang}
{opt steps(#)} specifies the number of grid steps per parameter. Default
is 20.

{dlgtab:Distribution plot}

{phang}
{opt using(filename)} specifies the dataset of Monte Carlo results
saved by a previous {cmd:saving()} option.

{phang}
{opt observed(#)} specifies the observed measure value, shown as a
reference line.

{phang}
{opt null(#)} specifies the null value for the reference line. Default is 1.

{dlgtab:Graph options}

{phang}
{opt scheme(name)} specifies the graph scheme. Default is
{cmd:plotplainblind}.

{phang}
{opt title(string)} specifies a custom graph title.

{phang}
{opt saving(filename)} saves the graph to file.

{phang}
{opt name(name)} assigns a name to the graph window.

{phang}
{opt replace} allows overwriting an existing file or graph.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Tornado plot}

{phang2}{cmd:. qba_plot, tornado a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(se) range1(.7 1) param2(sp) range2(.8 1) steps(30)}{p_end}

{pstd}
{bf:Example 2: Distribution plot from saved MC results}

{phang2}{cmd:. qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)} ///
{phang3}{cmd:reps(10000) dist_se("trapezoidal .75 .82 .88 .95")} ///
{phang3}{cmd:dist_sp("trapezoidal .90 .93 .97 1.0") saving(mc_results, replace)}{p_end}
{phang2}{cmd:. qba_plot, distribution using(mc_results) observed(1.5)}{p_end}

{pstd}
{bf:Example 3: Tipping point plot}

{phang2}{cmd:. qba_plot, tipping a(136) b(297) c(1432) d(6738)} ///
{phang3}{cmd:param1(se) range1(.6 1) param2(sp) range2(.6 1) steps(25)}{p_end}


{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}

{hline}
