{smcl}
{* *! version 1.0.0  15oct2026}{...}
{vieweralsosee "sts graph" "help sts graph"}{...}
{vieweralsosee "stci" "help stci"}{...}
{vieweralsosee "sts test" "help sts test"}{...}
{viewerjumpto "Syntax" "kmplot##syntax"}{...}
{viewerjumpto "Description" "kmplot##description"}{...}
{viewerjumpto "Options" "kmplot##options"}{...}
{viewerjumpto "Method notes" "kmplot##methods"}{...}
{viewerjumpto "Examples" "kmplot##examples"}{...}
{viewerjumpto "Stored results" "kmplot##results"}{...}
{viewerjumpto "References" "kmplot##references"}{...}
{viewerjumpto "Author" "kmplot##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:kmplot} {hline 2}}Publication-ready Kaplan-Meier survival and cumulative
failure plots{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:kmplot}
{ifin}
[{cmd:,}
{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Model}
{synopt:{opt by(varname)}}group variable for stratified curves{p_end}
{synopt:{opt fail:ure}}plot cumulative failure (1-KM){p_end}

{syntab:Confidence intervals}
{synopt:{opt ci}}show confidence intervals{p_end}
{synopt:{opt l:evel(#)}}confidence level; default {cmd:c(level)}{p_end}
{synopt:{opt cis:tyle(string)}}CI display: band or line{p_end}
{synopt:{opt cio:pacity(#)}}band opacity 0-100; default {bf:12}{p_end}
{synopt:{opt citr:ansform(string)}}CI transform: loglog, log, plain{p_end}

{syntab:Median}
{synopt:{opt med:ian}}draw median survival reference lines{p_end}
{synopt:{opt mediana:nnotate}}annotate median values in plot note{p_end}
{synopt:{opt medianf:ormat(%fmt)}}median display format; default {bf:%9.0g}{p_end}

{syntab:Risk table}
{synopt:{opt risk:table}}add number-at-risk table below plot{p_end}
{synopt:{opt riskev:ents}}show cumulative events{p_end}
{synopt:{opt riskcom:pact}}synonym for riskevents{p_end}
{synopt:{opt riskm:ono}}display risk-table numbers in black{p_end}
{synopt:{opt riskh:eight(#)}}risk-table height; default auto{p_end}
{synopt:{opt time:points(numlist)}}timepoints for risk table; default auto{p_end}

{syntab:Fixed-time summaries}
{synopt:{opt land:mark(numlist)}}return fixed-time estimates{p_end}

{syntab:Censoring}
{synopt:{opt cen:sor}}show censoring marks{p_end}
{synopt:{opt censort:hin(#)}}show every Nth censor mark; default {bf:1}{p_end}

{syntab:P-value}
{synopt:{opt pval:ue}}display log-rank p-value on plot{p_end}
{synopt:{opt pvaluepo:s(string)}}position for p-value text{p_end}
{synopt:{opt pvaluef:ormat(string)}}p-value format; default %5.3f{p_end}
{synopt:{opt pvaluet:ext(string)}}p-value label; default Log-rank p{p_end}
{synopt:{opt pvalueat(y x)}}p-value graph coordinates{p_end}

{syntab:Appearance}
{synopt:{opt col:ors(colorlist)}}line colors; default Okabe-Ito palette{p_end}
{synopt:{opt lw:idth(string)}}line width; default medthick{p_end}
{synopt:{opt lp:attern(patternlist)}}line patterns; default solid{p_end}

{syntab:Labels}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt sub:title(string)}}graph subtitle{p_end}
{synopt:{opt xti:tle(string)}}x-axis title; default Analysis time{p_end}
{synopt:{opt yti:tle(string)}}y-axis title; auto from model{p_end}
{synopt:{opt xla:bel(string)}}x-axis labels and risk-table columns{p_end}
{synopt:{opt yla:bel(string)}}y-axis labels; default 0(0.25)1{p_end}
{synopt:{opt leg:end(string)}}custom legend specification{p_end}
{synopt:{opt note(string)}}graph note{p_end}

{syntab:Output}
{synopt:{opt sch:eme(string)}}graph scheme; default current{p_end}
{synopt:{opt name(string)}}graph name; default {bf:kmplot}{p_end}
{synopt:{opt asp:ectratio(string)}}aspect ratio{p_end}
{synopt:{opt exp:ort(string)}}export graph{p_end}
{synopt:{opt sav:ing(filename[, replace])}}save curve data used for the graph{p_end}
{synopt:{opt risksav:ing(filename[, replace])}}save risk-table counts{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Data must be {cmd:stset} before using {cmd:kmplot}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:kmplot} draws Kaplan-Meier survival curves, or cumulative failure
curves, for {cmd:stset} data. One call can add pointwise confidence bands, a
number-at-risk table aligned with the time axis, median reference lines,
censoring marks, and the log-rank p-value. It can also return fixed-time
estimates and save the plotted curve and risk-table data.

{pstd}
Curves are drawn as step functions with {cmd:twoway} in the current
scheme. Line colors, widths, and patterns, the titles, labels, legend, and
note have their own options; other {help twoway_options} are passed through. The
default colors come from the Okabe-Ito palette, chosen to stay
distinguishable under red-green color-vision deficiency. Text sizes in the
risk table and the style of the median reference lines are fixed.


{marker options}{...}
{title:Options}

{dlgtab:Model}

{phang}{opt by(varname)} specifies a grouping variable for stratified KM
curves. Both numeric and string variables are supported. Value labels are
used automatically if defined; unlabelled numeric levels are shown as
{it:varname}={it:value} in the variable's display format (in full
precision if that format would make two levels look alike).{p_end}

{phang}{opt failure} plots cumulative failure (1 minus KM) instead of
the survival function. The y-axis title changes to "Cumulative failure"
and the curve starts at 0 instead of 1.{p_end}

{dlgtab:Confidence intervals}

{phang}{opt ci} displays confidence intervals around the KM curve.{p_end}

{phang}{opt level(#)} sets the confidence level for {opt ci}. The default is
{cmd:level(95)} or as set by {helpb set level}. As elsewhere in Stata, the value
must lie between 10 and 99.99 and have at most two decimal places. Requires
{opt ci}.{p_end}

{phang}{opt cistyle(string)} sets the CI display style. {bf:band} (default) shows shaded
bands; {bf:line} shows dashed lines. Requires {opt ci}.{p_end}

{phang}{opt ciopacity(#)} sets shaded band opacity (0-100); default 12. Requires
{opt ci} with {opt cistyle(band)}.{p_end}

{phang}{opt citransform(string)} sets the CI transformation. {bf:loglog} (default) uses the
log-log transform (Stata's default for KM). {bf:log} uses the log transform. {bf:plain}
uses untransformed (Wald) intervals. Requires {opt ci}.{p_end}

{dlgtab:Median}

{phang}{opt median} draws dashed reference lines at the median survival time for each group
(horizontal at y=0.5, vertical at x=median). If the median is not reached, no
line is drawn.{p_end}

{phang}{opt medianannotate} adds median values to the graph note. Requires {opt median}.{p_end}

{phang}{opt medianformat(%fmt)} sets the numeric ({cmd:%f}, {cmd:%g}, or {cmd:%e}) display
format of the median values in
the graph note and the console summary; the default is {bf:%9.0g}, so that
medians on a fractional time scale are not rounded away. {cmd:r(median_#)}
always holds the full value. Requires {opt median}.{p_end}

{dlgtab:Risk table}

{phang}{opt risktable} adds a number-at-risk table below the main plot. The table shows the
number of subjects still under observation at each timepoint and honors active
{cmd:stset} weights. Time-axis values appear directly below the main plot,
followed closely by the x-axis title. A solid horizontal rule separates the
title from the first risk-table row. Risk counts and group labels use a
readable small text size by default. Counts of 1,000 or more are shown with
thousands separators.{p_end}

{phang}Group labels are drawn in the risk table's y-axis label column, that
is, outside the plotting region, so the table's time origin coincides with
the main plot's y axis and the two time axes align without inserting blank
space inside either plotting region. Schemes that place the y axis on the
right-hand side, such as {cmd:economist}, mirror that column and are not
supported with {opt risktable}.{p_end}

{phang}With probability or importance weights, at-risk and event counts can be
fractional; such cells are printed to one decimal place (for example,
{cmd:13.3}). {cmd:r(risktable)} and {opt risksaving()} keep the full
values.{p_end}

{phang}{opt riskevents} adds cumulative event counts to the risk table
in compact {it:N (events)} format (e.g., {cmd:14 (3)}, {cmd:5,682 (424)}). This is the
NEJM/Lancet convention. Equivalent to {opt riskcompact}. Requires {opt risktable}.{p_end}

{phang}{opt riskcompact} synonym for {opt riskevents}. Requires {opt risktable}.{p_end}

{phang}{opt riskmono} displays all risk table numbers in black instead of
matching line colors. Default is colored numbers that match each group's
line color. Requires {opt risktable}.{p_end}

{phang}{opt riskheight(#)} sets the vertical size of the risk-table graph
inside the combined plot. If omitted, {cmd:kmplot} uses 25 for small risk
tables and increases the height automatically when there are more than
three groups. Requires {opt risktable}.{p_end}

{phang}{opt timepoints(numlist)} specifies the timepoints for the risk
table. Default: approximately 6 evenly spaced timepoints from 0 to the
maximum observed time. Requires {opt risktable} or {opt risksaving()}.{p_end}

{dlgtab:Fixed-time summaries}

{phang}{opt landmark(numlist)} returns estimates at fixed analysis times. In survival mode,
the returned estimate is S(t). With {opt failure}, it is 1 - S(t). If {opt ci} is
specified, lower and upper bounds are included in {cmd:r(landmarks)}. Explicit
times retain double precision. Beyond a group's last observed follow-up,
estimates and bounds are missing unless survival has reached zero (failure has
reached one); that terminal value remains defined. Bounds are missing wherever
the survival estimate is exactly 1 or 0 (see {it:{help kmplot##methods:Method notes}}).{p_end}

{dlgtab:Censoring}

{phang}{opt censor} displays tick marks at censoring times on the
KM curve.{p_end}

{phang}{opt censorthin(#)} shows every Nth censor mark to reduce clutter. Default 1 (show
all). Values must be at least 1, and the option requires {opt censor}.{p_end}

{dlgtab:P-value}

{phang}{opt pvalue} computes and displays the log-rank test p-value on
the plot. Requires {opt by()} and at least two groups in the analysis
sample.{p_end}

{phang}{opt pvaluepos(string)} positions the p-value
text: {bf:bottomright} (default), {bf:topright},
{bf:topleft}, {bf:bottomleft}. The anchor sits 5% of the y range inside the
top or bottom of the drawn y axis, taken as the span of the plotted curves,
bands, and median lines together with any numeric {opt ylabel()} list. Top
positions are centred vertically on the anchor; bottom positions draw the
text above it, clear of the time axis. The coordinates and placement used are returned in
{cmd:r(pvalue_y)}, {cmd:r(pvalue_x)}, and {cmd:r(pvalue_placement)}. The
position is fixed and does not avoid the curves or the legend; use
{opt pvalueat()} to place the text elsewhere.{p_end}

{phang}{opt pvalueformat(string)} sets the numeric display format used in
the p-value annotation, for example {cmd:pvalueformat(%6.4f)}. Whatever the
format, p-values below 0.001 are shown as {bf:< 0.001}.{p_end}

{phang}{opt pvaluetext(string)} changes the label printed before the p-value. For example,
{cmd:pvaluetext("Stratified log-rank P")} displays that label with the formatted
p-value.{p_end}

{phang}{opt pvalueat(y x)} places the p-value annotation at explicit graph
coordinates. The first number is the y coordinate and the second is the x
coordinate. It may not be combined with {opt pvaluepos()}.{p_end}

{dlgtab:Appearance}

{phang}{opt colors(colorlist)} sets one or more curve colors, as Stata color
names or quoted RGB triplets, for example {cmd:colors(navy "213 94 0")}. Shorter
lists are recycled across groups. If omitted, {cmd:kmplot} uses seven colors
from the Okabe-Ito palette (Okabe and Ito 2008), in the order blue
({cmd:"0 114 178"}), vermilion, black, sky blue, reddish purple, orange, and
bluish green. Under simulated protanopia and deuteranopia (Machado, Oliveira,
and Fernandes 2009) any two of the first five remain clearly distinguishable; with
more than five groups, add {opt lpattern()} so that curves do not depend
on color alone. With {opt ci} bands, any opacity given in a color (for
example {cmd:navy%50}) applies to the line; the band uses {opt ciopacity()}.{p_end}

{phang}{opt lwidth(string)} sets curve line width; the default is
{bf:medthick}.{p_end}

{phang}{opt lpattern(patternlist)} sets curve line patterns. The default is
{bf:solid} for every curve; shorter lists are recycled across groups.{p_end}

{dlgtab:Labels}

{phang}{opt title(string)} and {opt subtitle(string)} set the graph title and
subtitle.{p_end}

{phang}{opt xtitle(string)} sets the x-axis title. With {opt risktable},
this is placed directly below and closer to the x-axis value labels than to
the risk table. Default is "Analysis time".{p_end}

{phang}{opt xlabel(string)} sets x-axis labels. With {opt risktable},
labels are placed below the main plot and above the x-axis title on the same
x scale as the risk-table columns. A solid horizontal rule separates the
title from the first risk-table row. Numeric positions are also used when
{opt timepoints()} is omitted.{p_end}

{phang}{opt ytitle(string)} sets the y-axis title. The default is "Survival
probability" or "Cumulative failure", according to the plot type.{p_end}

{phang}{opt ylabel(string)} sets y-axis labels; the default is
{cmd:0(0.25)1}.{p_end}

{phang}{opt legend(string)} supplies a custom Stata legend
specification. Without it, {cmd:kmplot} constructs a legend from the plotted
groups.{p_end}

{phang}{opt note(string)} adds a graph note. If {opt medianannotate} is also
requested, the user-supplied note replaces the automatic median
annotation.{p_end}

{dlgtab:Output}

{phang}{opt scheme(string)} applies a Stata graph scheme. If omitted, the
current scheme is used.{p_end}

{phang}{opt name(string)} names the graph in memory; the default is
{cmd:kmplot}.{p_end}

{phang}{opt aspectratio(string)} passes an aspect-ratio specification to the
graph command.{p_end}

{phang}{opt export(string)} exports the graph to a file. The format is auto-detected from
the extension (.pdf, .png, .eps, .svg). Sub-options (e.g., {it:replace}, {it:width(#)})
are passed to {cmd:graph export}. Example: {cmd:export(figure1.pdf, replace)}. Quoted
paths with spaces are supported, for example {cmd:export("figure 1.pdf", replace)}.{p_end}

{phang}{opt saving(filename[, replace])} saves the curve data used for the
graph. The saved dataset contains {cmd:group}, {cmd:group_label},
{cmd:time}, {cmd:estimate}, {cmd:se}, {cmd:lower}, {cmd:upper},
{cmd:censor}, and {cmd:anchor}. The estimate is survival in the default
mode and cumulative failure with {opt failure}. {cmd:se}, {cmd:lower}, and
{cmd:upper} are missing where the survival estimate is 1 or 0.{p_end}

{phang}{opt risksaving(filename[, replace])} saves risk-table counts in a
Stata dataset with {cmd:group}, {cmd:group_label}, {cmd:time},
{cmd:at_risk}, {cmd:events}, and {cmd:censored}. It can be used with or
without displaying {opt risktable}. The {cmd:censored} variable records
cumulative censoring exits from each plotted group.{p_end}

{dlgtab:Graph passthrough}

{phang}Additional {help twoway_options} (e.g., {cmd:xsize()}, {cmd:ysize()},
{cmd:plotregion()}, {cmd:graphregion()}) are passed through to the
underlying {cmd:twoway} call.{p_end}


{marker methods}{...}
{title:Method notes}

{pstd}
{cmd:kmplot} uses Stata's survival-time machinery after {cmd:stset}. Kaplan-Meier
estimates and Greenwood standard errors are generated with
{cmd:sts generate} (Kaplan and Meier
1958; StataCorp, {manlink ST sts generate}). Confidence intervals use the requested
{opt level()} and the selected
transformation: log-log by default, log, or plain Wald intervals. Bounds are
reported only where 0 < S(t) < 1. Where the estimate is exactly 1 (before the
first event, including the time-zero anchor) or exactly 0, the bounds are
missing under every transformation, as in {cmd:sts list}; shaded bands
therefore begin at the first event time. Where a curve steps to 0 (1 with
{opt failure}), the drawn band or CI lines carry the last bounds to that
time, as {cmd:sts graph, ci} does, so they end where the curve ends; the
returned and saved bounds stay missing there.{p_end}

{pstd}
The {opt failure} option plots cumulative failure, {bf:1 - S(t)}, from the
Kaplan-Meier survival curve. This is not a competing-risk cumulative
incidence function, and {cmd:kmplot} does not implement Aalen-Johansen or
Fine-Gray competing-risk estimators.{p_end}

{pstd}
The {opt pvalue} option uses Stata's {cmd:sts test, logrank}. Risk-table
counts honor delayed entry, active {cmd:stset} weights, and subject
identifiers. Probability weights support point estimates and weighted counts,
but {opt ci} and {opt pvalue} are refused because Greenwood inference and the
log-rank test are unsupported. Saved standard errors are missing with
probability weights. In multiple-record data, subjects are counted once per
timepoint. Contiguous records within the same group are not treated as
censoring; departures from a group are.{p_end}

{pstd}
With {cmd:stset} importance weights ({cmd:iweight}s), {opt ci} and {opt pvalue}
are allowed, as they are by {cmd:sts}, and the Greenwood standard errors and the
log-rank test then treat the weights as frequency counts. Use them only when
that interpretation is intended.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}

{pstd}Basic KM curve{p_end}
{phang2}{cmd:. kmplot}{p_end}

{pstd}KM curves by treatment group{p_end}
{phang2}{cmd:. kmplot, by(drug)}{p_end}

{pstd}With CI bands and median lines{p_end}
{phang2}{cmd:. kmplot, by(drug) ci median medianannotate}{p_end}

{pstd}Cumulative failure with risk table{p_end}
{phang2}{cmd:. kmplot, by(drug) failure risktable}{p_end}

{pstd}Full publication example{p_end}
{phang2}{cmd:. kmplot, by(drug) ci risktable median medianannotate pvalue censor}{p_end}

{pstd}Custom styling{p_end}
{phang2}{cmd:. kmplot, by(drug) ci colors(navy red) lpattern(solid dash)}{p_end}

{pstd}Export to PDF{p_end}
{phang2}{cmd:. kmplot, by(drug) ci median export(km_figure.pdf, replace)}{p_end}

{pstd}Fixed-time estimates and saved table data{p_end}
{phang2}{cmd:. kmplot, by(drug) ci risktable landmark(12 24) risksaving(risk.dta, replace)}{p_end}
{phang2}{cmd:. matrix list r(landmarks)}{p_end}
{phang2}{cmd:. matrix list r(risktable)}{p_end}

{pstd}Custom p-value text and coordinates{p_end}
{phang2}{cmd:. kmplot, by(drug) pvalue pvalueformat(%6.4f) pvaluetext("Log-rank P") pvalueat(.9 10)}{p_end}

{pstd}Delayed entry: age as the time scale, with explicit risk-table timepoints{p_end}
{phang2}{cmd:. webuse diet, clear}{p_end}
{phang2}{cmd:. stset dox, failure(fail) origin(time dob) enter(time doe) scale(365.25) id(id)}{p_end}
{phang2}{cmd:. kmplot, by(hienergy) risktable timepoints(40 50 60 70) xtitle("Age (years)")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:kmplot} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_groups)}}number of groups{p_end}
{synopt:{cmd:r(level)}}confidence level that applies to {opt ci}{p_end}
{synopt:{cmd:r(ci)}}1 if {opt ci} was requested{p_end}
{synopt:{cmd:r(failure)}}1 if {opt failure} was requested{p_end}
{synopt:{cmd:r(n_landmarks)}}number of requested landmark timepoints{p_end}
{synopt:{cmd:r(n_timepoints)}}number of risk-table timepoints{p_end}
{synopt:{cmd:r(riskheight)}}risk-table height, with {opt risktable}{p_end}
{synopt:{cmd:r(p)}}log-rank p-value when computed{p_end}
{synopt:{cmd:r(pvalue_y)}}p-value text y coordinate{p_end}
{synopt:{cmd:r(pvalue_x)}}p-value text x coordinate{p_end}
{synopt:{cmd:r(median_#)}}median for group {it:#}, when reached{p_end}

{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}{cmd:kmplot}{p_end}
{synopt:{cmd:r(graph_name)}}graph name{p_end}
{synopt:{cmd:r(plot_type)}}{bf:survival} or {bf:failure}{p_end}
{synopt:{cmd:r(scheme)}}graph scheme used{p_end}
{synopt:{cmd:r(by)}}by-variable name (if specified){p_end}
{synopt:{cmd:r(cistyle)}}CI style used{p_end}
{synopt:{cmd:r(citransform)}}CI transform used{p_end}
{synopt:{cmd:r(colors)}}color list used{p_end}
{synopt:{cmd:r(lpattern)}}line-pattern list supplied, if any{p_end}
{synopt:{cmd:r(timepoints)}}risk-table timepoints used{p_end}
{synopt:{cmd:r(landmark_times)}}landmark timepoints requested{p_end}
{synopt:{cmd:r(group_labels)}}group labels separated by {bf: | }{p_end}
{synopt:{cmd:r(xtitle)}}x-axis title{p_end}
{synopt:{cmd:r(ytitle)}}y-axis title{p_end}
{synopt:{cmd:r(export)}}requested path when {opt export()} was specified{p_end}
{synopt:{cmd:r(saving)}}saved curve dataset path{p_end}
{synopt:{cmd:r(risksaving)}}saved risk-table dataset path{p_end}
{synopt:{cmd:r(pvalue_text)}}displayed p-value text{p_end}
{synopt:{cmd:r(pvalue_label)}}p-value label text{p_end}
{synopt:{cmd:r(pvalue_format)}}p-value numeric format{p_end}
{synopt:{cmd:r(pvalue_pos)}}p-value position keyword{p_end}
{synopt:{cmd:r(pvalue_at)}}explicit p-value coordinates, if specified{p_end}
{synopt:{cmd:r(pvalue_placement)}}p-value text placement ({bf:c} with {opt pvalueat()}){p_end}

{p2col 5 16 20 2: Matrices}{p_end}
{synopt:{cmd:r(medians)}}group and median columns{p_end}
{synopt:{cmd:r(landmarks)}}fixed-time estimate matrix{p_end}
{synopt:{cmd:r(risktable)}}risk-table count matrix{p_end}

{pstd}
{cmd:r(median_#)} is stored with {opt median}, for each group {it:#} whose curve
reaches 0.5 (1, 2, ... in the order of {cmd:r(group_labels)}); groups whose
median is not reached store no scalar. {cmd:r(level)} is stored even without
{opt ci}, as the level {opt ci} would use.{p_end}

{pstd}
The p-value macros are stored only after computing the log-rank p-value, and
{cmd:r(pvalue_at)} is empty unless {opt pvalueat()} was specified.{p_end}

{pstd}
{cmd:r(export)} records the requested export path whenever {opt export()} was
specified. Analytical returns remain available if the file write fails, even
though {cmd:kmplot} exits with the graph-export error.{p_end}


{marker references}{...}
{title:References}

{phang}
Kaplan, E. L., and P. Meier. 1958. Nonparametric estimation from incomplete
observations. {it:Journal of the American Statistical Association} 53: 457{c -}481. {browse "https://doi.org/10.1080/01621459.1958.10501452":doi:10.1080/01621459.1958.10501452}.{p_end}

{phang}
Machado, G. M., M. M. Oliveira, and L. A. F. Fernandes. 2009. A
physiologically-based model for simulation of color vision
deficiency. {it:IEEE Transactions on Visualization and Computer Graphics} 15: 1291{c -}1298. {browse "https://doi.org/10.1109/TVCG.2009.113":doi:10.1109/TVCG.2009.113}.{p_end}

{phang}
Okabe, M., and K. Ito. 2008. Color Universal Design (CUD): How to make
figures and presentations that are friendly to colorblind
people. {browse "https://jfly.uni-koeln.de/color/"}.{p_end}

{phang}
StataCorp. {it:Stata Survival Analysis Reference Manual}. College Station, TX: Stata
Press. See {manlink ST stset}, {manlink ST sts generate}, {manlink ST sts list}, and
{manlink ST sts test} for the Greenwood standard error, the log-log
confidence interval, and the log-rank test.{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-10-15{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}

{pstd}Check GitHub for the most up-to-date release; it may be newer than the version
installed here.{p_end}

{hline}
