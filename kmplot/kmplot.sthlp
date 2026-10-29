{smcl}
{* *! version 1.0.0  20oct2026}{...}
{vieweralsosee "sts graph" "help sts graph"}{...}
{vieweralsosee "stci" "help stci"}{...}
{vieweralsosee "sts test" "help sts test"}{...}
{vieweralsosee "stcrreg" "help stcrreg"}{...}
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
{p2col:{cmd:kmplot} {hline 2}}Publication-ready Kaplan-Meier survival, cumulative
failure, and competing-risk cumulative incidence plots{p_end}
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
{synopt:{opt comp:ete(exp)}}competing event; Aalen-Johansen incidence{p_end}
{synopt:{opt byo:rder(numlist)}}drawing order of the {opt by()} levels{p_end}

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
{synopt:{opt riskw:eight(none|stset)}}count people or sum the {cmd:stset} weight{p_end}
{synopt:{opt riskmask(# [, text(string)])}}print counts from 1 to #-1 as {cmd:<}{it:#}{p_end}
{synopt:{opt noriskmask}}ignore the {cmd:tabtools} small-cell default{p_end}

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
{synopt:{opt yla:bel(string)}}y-axis labels; default automatic{p_end}
{synopt:{opt ymax(#)}}upper limit of the y axis{p_end}
{synopt:{opt per:cent}}plot on the percent scale{p_end}
{synopt:{opt tmax(#)}}stop curves, axis, and risk table at {it:#}{p_end}
{synopt:{opt leg:end(string)}}custom legend specification{p_end}
{synopt:{opt note(string)}}graph note{p_end}

{syntab:Output}
{synopt:{opt sch:eme(string)}}graph scheme; default current{p_end}
{synopt:{opt name(name[, replace])}}graph name; default {bf:kmplot}{p_end}
{synopt:{opt asp:ectratio(string)}}aspect ratio{p_end}
{synopt:{opt exp:ort(string)}}export graph{p_end}
{synopt:{opt sav:ing(filename[, replace])}}save curve data used for the graph{p_end}
{synopt:{opt risksav:ing(filename[, replace])}}save risk-table counts{p_end}
{synopt:{opt comb:ineopts(string)}}{cmd:graph combine} options with {opt risktable}{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Data must be {cmd:stset} before using {cmd:kmplot}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:kmplot} draws Kaplan-Meier survival curves, cumulative failure curves,
or, with {opt compete()}, Aalen-Johansen cumulative incidence curves in the
presence of a competing event, for {cmd:stset} data. One call can add
pointwise confidence bands, a number-at-risk table aligned with the time axis
(with counts of people under weights and optional small-count masking),
median reference lines, censoring marks, and the log-rank p-value. It can
also return fixed-time estimates and save the plotted curve and risk-table
data.

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

{phang}{opt compete(exp)} plots the Aalen-Johansen cumulative incidence of the
{cmd:stset} failure event, treating the records on which {it:exp} is true as
a competing event: a person with a competing event leaves the risk set and
can no longer fail from the event of interest, instead of being censored. For
example, after {cmd:stset exit, failure(cause == 1)},
{cmd:compete(cause == 2)} makes death from other causes the competing event. {it:exp}
is evaluated on the records in the analysis sample; a record is a
competing event when {cmd:_d} is 0, {it:exp} is true, and {cmd:stset}
{cmd:exit()} did not cut the record short. {opt compete()} implies a
cumulative incidence plot ({opt failure} is accepted and redundant); the
default y-axis title is "Cumulative incidence". It is an error (r(459)) for
{it:exp} to be true on a record that is also an {cmd:stset} failure, or, with
{cmd:id()}, on a record followed by further follow-up of the same subject; {it:exp}
evaluating to missing on any record is an error (r(416)), so write,
for example, {cmd:compete(cause == 2)} rather than {cmd:compete(death)} when
{cmd:death} can be missing. {cmd:stset exit()} is supported only in the form
{cmd:exit(time} {it:exp}{cmd:)}. {opt compete()} may not be combined with
{opt pvalue} (Gray's test is not implemented) or {opt median}. {it:exp} is a
single expression: a comma outside parentheses and quotes is an error
(r(198)). If {it:exp} is true on no record of the analysis sample, a note
says so, and the curve then equals 1 minus the Kaplan-Meier estimate. See
{it:{help kmplot##methods:Method notes}}.{p_end}

{phang}{opt byorder(numlist)} gives the order of the {opt by()} levels for
drawing, for the default legend, and for the risk-table rows; levels not
listed follow in sort order. {opt colors()} and {opt lpattern()} are then
assigned in this order. For example, with a 0/1 variable, {cmd:byorder(1 0)}
draws level 1 first. {opt byorder()} requires a numeric {opt by()} variable
(otherwise r(109)); a listed value that is not a level of {opt by()} in the
analysis sample, or a repeated value, is an error (r(198)). The {cmd:group}
column of {cmd:r(landmarks)}, {cmd:r(medians)}, {cmd:r(risktable)}, and the
saved datasets, and the {it:#} in {cmd:r(median_#)}, are positions in the
drawing order (1, 2, ...), not level values; {cmd:r(group_labels)} lists the
groups in that order.{p_end}

{dlgtab:Confidence intervals}

{phang}{opt ci} displays confidence intervals around the KM curve, or around
the cumulative incidence with {opt compete()}. With {opt compete()},
{opt ci} is allowed without weights and with frequency weights.{p_end}

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
uses untransformed (Wald) intervals. With {opt compete()} the transforms apply
to the cumulative incidence F: {bf:loglog} is the ln(-ln F) interval of
{cmd:stcompet}, {bf:log} is F exp(-/+z se/F), and {bf:plain} is F -/+ z se,
clipped to [0, 1]. Requires {opt ci}.{p_end}

{dlgtab:Median}

{phang}{opt median} draws dashed reference lines at the median survival time for each group
(horizontal at y=0.5, vertical at x=median). If the median is not reached, no
line is drawn; nor is it for a median beyond {opt tmax()}, which is still
stored in {cmd:r(median_#)}.{p_end}

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

{phang}Under {cmd:stset} probability or importance weights the table counts
people by default (see {opt riskweight()}), while the curve stays weighted. With
{cmd:riskweight(stset)}, at-risk and event counts can be fractional; such
cells are printed to one decimal place (for example, {cmd:13.3}). {cmd:r(risktable)}
and {opt risksaving()} keep the full values.{p_end}

{phang}With {opt compete()}, the event counts are failures of interest, and a
competing exit is counted as neither an event nor censored: it only lowers
the number at risk. The drop in the at-risk count between two columns is
then not accounted for by the event and censored counts alone.{p_end}

{phang}{opt riskevents} adds cumulative event counts to the risk table
in compact {it:N (events)} format (e.g., {cmd:14 (3)}, {cmd:5,682 (424)}). This is the
NEJM/Lancet convention. Equivalent to {opt riskcompact}. Requires {opt risktable}.{p_end}

{phang}{opt riskcompact} synonym for {opt riskevents}. Requires {opt risktable}.{p_end}

{phang}{opt riskmono} displays all risk table numbers in black instead of
matching line colors. Default is colored numbers that match each group's
line color. Requires {opt risktable}.{p_end}

{phang}{opt riskheight(#)} sets the vertical size of the risk-table graph
inside the combined plot; {it:#} must be greater than 0 and no more than 80. If
omitted, {cmd:kmplot} uses 25 for small risk
tables and increases the height automatically when there are more than
three groups. Requires {opt risktable}.{p_end}

{phang}{opt timepoints(numlist)} specifies the timepoints for the risk
table. Default: approximately 6 evenly spaced timepoints from 0 to the
maximum observed time, or to {opt tmax()}. The times are sorted and repeated
times dropped; a range such as {cmd:0(0.1)1} gives the same times as the typed
decimals {cmd:0 .1} ... {cmd:1}. With {opt tmax()}, no time may exceed it
(r(198)). Requires {opt risktable} or {opt risksaving()}.{p_end}

{phang}{opt riskweight(none|stset)} chooses what the risk table counts. {bf:none}
counts people (records, or subjects with {cmd:id()}), ignoring the
{cmd:stset} weight; {bf:stset} sums the {cmd:stset} weight. The default is
{bf:none} under probability and importance weights, since journals expect
numbers of people beside a weighted curve, and {bf:stset} under frequency
weights, which are real counts. Without weights the two are the same and
{cmd:r(riskweight)} reports {bf:none}. The choice applies to the at-risk,
event, and censored counts in the drawn table, in {cmd:r(risktable)}, and in
the {cmd:at_risk}, {cmd:events}, and {cmd:censored} variables of
{opt risksaving()}; the weighted sums are always saved as well (see
{opt risksaving()}). Nothing is added to the graph note; describe the basis in
your own note. Requires {opt risktable} or {opt risksaving()}.{p_end}

{phang}{opt riskmask(# [, text(string)])} masks small counts for disclosure
control. Any at-risk, event, or censored count from 1 to {it:#}-1 is printed
as {cmd:<}{it:#} (or as {opt text()}); 0 is printed as 0. {it:#} must be an
integer of 2 or more. Masking is decided on people counts, so it may not be
combined with {cmd:riskweight(stset)} under probability or importance weights
(frequency-weighted sums are counts and are allowed). Masked cells are missing
in {cmd:r(risktable)} and, together with their weighted companions, in
{opt risksaving()}, which also gets 0/1 flags {cmd:at_risk_masked},
{cmd:events_masked}, and {cmd:censored_masked}. The exact values of masked
cells appear nowhere in the risk-table output: the drawn table,
{cmd:r(risktable)}, and {opt risksaving()}. Masking applies only to those
risk-table cells; sample totals that {cmd:kmplot} prints or returns, such as
{cmd:r(N)} and the number of competing-event records in the console summary,
are not masked. Nor does {opt riskmask()} alter the curve: its step sizes and
censoring ticks can reveal small counts, so judge the curve itself against
your disclosure rule. {opt riskmask()}
masks cells, not differences: two adjacent at-risk counts and
the events between them can still reveal a small censored count by
subtraction, particularly with {opt riskevents}. No complementary suppression
is attempted; publish at-risk counts only when that matters. Requires
{opt risktable} or {opt risksaving()}.{p_end}

{phang}Session default: after {cmd:tabtools set smallcells} {it:#} (which
stores {it:#} in the global macro {cmd:TABTOOLS_set_smallcells}), every
{cmd:kmplot} call that draws a risk table or uses {opt risksaving()} masks
with that {it:#} unless {opt riskmask()} or {opt noriskmask} is given, and
prints {cmd:(kmplot: using tabtools session smallcells(}{it:#}{cmd:) for riskmask())}. An
explicit {opt riskmask()} takes precedence. The {cmd:primary}/full mode
that {cmd:tabtools} stores in {cmd:TABTOOLS_set_smallcells_mode} is ignored: {cmd:kmplot}
masks cells only. A session value that is not an integer of 2 or
more is an error (r(198)). {cmd:tabtools} need not be installed; only the
global is read.{p_end}

{phang}{opt noriskmask} turns off the {cmd:tabtools} session default for this
call. It may not be combined with {opt riskmask()} and requires
{opt risktable} or {opt risksaving()}.{p_end}

{dlgtab:Fixed-time summaries}

{phang}{opt landmark(numlist)} returns estimates at fixed analysis times, which
must be nonnegative; they are sorted and repeated times dropped, and ranges
behave as in {opt timepoints()}. In survival mode,
the returned estimate is S(t). With {opt failure}, it is 1 - S(t); with
{opt compete()}, the cumulative incidence F(t). Estimates are always
proportions, also with {opt percent}, and times beyond {opt tmax()} are still
computed. With {opt compete()}, values beyond a group's last follow-up are
missing unless all-cause survival has reached zero. If {opt ci} is
specified, lower and upper bounds are included in {cmd:r(landmarks)}. Explicit
times retain double precision. Beyond a group's last observed follow-up,
estimates and bounds are missing unless survival has reached zero (failure has
reached one); that terminal value remains defined. Bounds are missing wherever
the survival estimate is exactly 1 or 0 (see {it:{help kmplot##methods:Method notes}}).{p_end}

{dlgtab:Censoring}

{phang}{opt censor} displays tick marks at censoring times on the
KM curve. With {opt compete()}, competing events are not marked.{p_end}

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

{phang}{opt pvalueformat(string)} sets the numeric ({cmd:%f}, {cmd:%g}, or
{cmd:%e}) display format used in
the p-value annotation, for example {cmd:pvalueformat(%6.4f)}; date and
string formats are refused (r(198)). Whatever the
format, p-values below 0.001 are shown as {bf:< 0.001}.{p_end}

{phang}{opt pvaluetext(string)} changes the label printed before the p-value. For example,
{cmd:pvaluetext("Stratified log-rank P")} displays that label with the formatted
p-value; {cmd:pvaluetext("")} prints only {bf:= }{it:p}.{p_end}

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

{phang}{opt title()}, {opt subtitle()}, {opt xtitle()}, {opt ytitle()}, and
{opt note()} take {it:text} [{cmd:,} {it:textbox_options}], as in Stata's
{help title_options}: {it:text} is one string or several quoted strings, one
line each, for example {cmd:title("Overall survival" "by arm", size(large))}. A
{cmd:size()} replaces {cmd:kmplot}'s default size; the other suboptions are
passed to {cmd:graph}. A comma inside quotes is text. {cmd:r(xtitle)} and
{cmd:r(ytitle)} hold the text without the suboptions (the string itself when
there is one).{p_end}

{phang}{opt xtitle(string)} sets the x-axis title. With {opt risktable},
this is placed directly below and closer to the x-axis value labels than to
the risk table. Default is "Analysis time"; {cmd:xtitle("")} draws no title,
with or without {opt risktable}.{p_end}

{phang}{opt xlabel(string)} sets x-axis labels. With {opt risktable},
labels are placed below the main plot and above the x-axis title on the same
x scale as the risk-table columns. A solid horizontal rule separates the
title from the first risk-table row. When {opt timepoints()} is omitted, the
numeric positions (the numbers before the first comma, outside quoted label
text, as in {cmd:xlabel(0 "Start" 12 24)}) are the risk-table timepoints, so
counts sit under their labels. With {opt risktable}, an {opt xlabel()}
without numeric positions ({cmd:#5}, {cmd:minmax}, {cmd:none}) is then an
error (r(198)); give {opt timepoints()} as well. Positions beyond
{opt tmax()} are an error too.{p_end}

{phang}{opt ytitle(string)} sets the y-axis title. The default is "Survival
probability", "Cumulative failure", or "Cumulative incidence", according to
the plot type; with {opt percent}, "Survival (%)", "Cumulative failure (%)",
or "Cumulative incidence (%)".{p_end}

{phang}{opt ylabel(string)} sets y-axis labels. Without it, survival plots
use {cmd:0(0.25)1} ({cmd:0(25)100} with {opt percent}), and failure and
cumulative incidence plots run from 0 to a rounded value just above the
largest plotted value, including drawn confidence limits, with about five
labels formatted to the precision of the step (a step of 0.002 gives
{cmd:%5.3f}). Text labels such as {cmd:ylabel(0 "0" 0.002 "0.2")} are
accepted; the numbers before the quoted texts give the axis range used to
lay out the risk table and the p-value.{p_end}

{phang}{opt ymax(#)} sets the upper limit of the y axis, on the plotted
scale (percent with {opt percent}), keeping automatic labels. Stata cannot
clip a graph, so a limit below the plotted maximum (curves, drawn confidence
limits, and median lines up to {opt tmax()}) is refused with r(198), and the
message gives that maximum. {it:#} must be positive.{p_end}

{phang}{opt percent} plots 100 times the estimate and its bounds, with
percent axis labels and titles. {cmd:r(landmarks)} and the {opt saving()}
data stay in proportions ({cmd:r(risktable)} holds counts either way); {cmd:r(scale)}
records the plotted scale.{p_end}

{phang}{opt tmax(#)} stops the curves, bands, censoring marks, the x axis,
and the default risk-table timepoints at {it:#} analysis-time units, without
re-declaring {cmd:stset} with {cmd:exit()}. Estimates are not recomputed: values
up to {it:#} are those of the full curve. {opt saving()} still holds
the whole curve, and {opt landmark()} times beyond {it:#} are computed. Risk-table
times may not exceed {it:#} (r(198)), and median lines beyond it
are not drawn. {it:#} must be positive.{p_end}

{phang}{opt legend(string)} supplies a custom Stata legend
specification. Without it, {cmd:kmplot} constructs a legend from the plotted
groups.{p_end}

{phang}{opt note(string)} adds a graph note. If {opt medianannotate} is also
requested, the user-supplied note replaces the automatic median
annotation.{p_end}

{dlgtab:Output}

{phang}{opt scheme(string)} applies a Stata graph scheme. If omitted, the
current scheme is used.{p_end}

{phang}{opt name(name[, replace])} names the graph in memory; the default is
{cmd:kmplot}. It must be a single valid graph name (r(198) otherwise). {cmd:kmplot}
always replaces a graph of that name, so {cmd:, replace} is
accepted and changes nothing.{p_end}

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
mode, cumulative failure with {opt failure}, and cumulative incidence with
{opt compete()} (with its standard error and bounds when computed). It is
always a proportion. There is one row per record of the analysis sample, so
tied times repeat (two deaths at time 1 give two rows), plus one time-zero
row per group flagged by {cmd:anchor}; {cmd:group} and {cmd:time} therefore
do not identify rows. {cmd:lower} and {cmd:upper} are missing unless
{opt ci} is specified. {cmd:se}, {cmd:lower}, and
{cmd:upper} are missing where the survival estimate is 1 or 0 (the cumulative
incidence 0 or 1), and {cmd:se} is missing throughout under {cmd:stset}
probability weights, and under importance weights with {opt compete()}.{p_end}

{phang}The files written by {opt saving()} and {opt risksaving()} carry no
dataset label, notes, characteristics (including {cmd:stset} settings), or
value labels from the data in memory. Their names are checked before the
graph is drawn: the {cmd:replace} suboption must be spelled out, as with
{cmd:save}, and {opt saving()} and {opt risksaving()} must name different
files (r(198)).{p_end}

{phang}{opt risksaving(filename[, replace])} saves risk-table counts in a
Stata dataset with {cmd:group}, {cmd:group_label}, {cmd:time},
{cmd:at_risk}, {cmd:events}, and {cmd:censored} on the basis chosen by
{opt riskweight()}, followed by {cmd:at_risk_w}, {cmd:events_w}, and
{cmd:censored_w}, the same counts as summed {cmd:stset} weights (equal to the
people counts without weights). With masking it also holds
{cmd:at_risk_masked}, {cmd:events_masked}, and {cmd:censored_masked}. It can
be used with or without displaying {opt risktable}. {cmd:events} counts
failures of interest; the {cmd:censored} variable records cumulative
censoring exits from each plotted group, excluding competing events.{p_end}

{phang}{opt combineopts(string)} passes options to the {cmd:graph combine}
that joins the plot and the risk table, after all others, so they win. Requires
{opt risktable}.{p_end}

{dlgtab:Graph passthrough}

{phang}Additional {help twoway_options} (e.g., {cmd:xsize()}, {cmd:ysize()},
{cmd:plotregion()}, {cmd:graphregion()}) are passed through to the
underlying {cmd:twoway} call. With {opt risktable}, {cmd:graphregion()},
{cmd:plotregion()}, {cmd:xsize()}, and {cmd:ysize()} are also passed to the
combined graph, and {cmd:graphregion()} and {cmd:plotregion()} to the
risk-table panel, so that, for example,
{cmd:scheme(sj) graphregion(color(white))} gives a white figure throughout.{p_end}

{phang}{cmd:nodraw}, given as an option of its own (not a word inside another
option's text), builds the graph, named by {opt name()}, without
displaying it; with {opt risktable} it applies to the combined graph. The risk
table, {cmd:r()} results, and {opt saving()}/{opt risksaving()} files are
produced as usual, and {cmd:graph display} shows the graph later. {cmd:nodraw}
may not be combined with {opt export()} (r(198)), because
{cmd:graph export} needs a drawn graph; use {cmd:graph display} and
{cmd:graph export} afterwards.{p_end}


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
Kaplan-Meier survival curve, treating any competing event as censoring. When
competing events are present this overstates the probability of failure
(Coviello and Boggess 2004); use {opt compete()}. Its bounds are those of
S(t), computed on the {opt citransform()} scale and then inverted (lower
bound 1 - upper bound of S, upper bound 1 - lower bound of S), as
{cmd:sts graph, failure} does; {cmd:citransform(log)} therefore applies the
log transform to S(t), not to 1 - S(t).{p_end}

{pstd}
Requested times, {opt timepoints()}, {opt landmark()}, and {opt tmax()}, are
compared with {cmd:_t} at the precision of the data. When the {cmd:stset}
time variable is stored as {cmd:float} (Stata's default storage type) and
{cmd:stset} used a constant {cmd:origin()} and {cmd:scale()}, a requested
time {it:t} stands for the records whose time variable holds float({it:t}): {cmd:landmark(0.3)}
includes a death recorded at 0.3, which a float holds as
0.30000001. With a {cmd:double} time variable, or an {cmd:origin()} that
varies by record, times are compared exactly. {cmd:sts list, at()} compares
exactly and so can differ from {cmd:kmplot} at float times.{p_end}

{pstd}
With {opt compete()}, {cmd:kmplot} estimates the cumulative incidence of the
failure of interest by the Aalen-Johansen estimator (Aalen and Johansen 1978)
in the form given by Coviello and Boggess (2004, 104). At each distinct exit
time t_j in a group, with weighted counts (weight 1 without {cmd:stset}
weights), n_j is the number at risk just before t_j (records with
_t0 < t_j <= _t, so delayed entry and {cmd:id()} data are honoured), d1_j the
events of interest, and d2_j the competing events. Then
S(t_j) = prod_{c -(}i<=j{c )-} [1 - (d1_i + d2_i)/n_i] is the all-cause
Kaplan-Meier, and F(t) = sum_{c -(}t_j<=t{c )-} S(t_{c -(}j-1{c )-}) d1_j/n_j. Events
at t_j precede censoring at t_j. Multiplying all weights by a constant
leaves F unchanged; with no competing events F equals 1 - S, the
{opt failure} curve, up to rounding (about 1e-15).{p_end}

{pstd}
The standard error with {opt compete()} is the delta-method variance of
Marubini and Valsecchi (1995, eq. 10.12) as given by Coviello and Boggess
(2004, 104),

{p 8 8 2}
var F(t_j) = sum_{c -(}a<=j{c )-} [ {c -(}F(t_j) - F(t_a){c )-}^2 d_a/{c -(}n_a(n_a - d_a){c )-}
+ S(t_{c -(}a-1{c )-})^2 d1_a (n_a - d1_a)/n_a^3
- 2 {c -(}F(t_j) - F(t_a){c )-} S(t_{c -(}a-1{c )-}) d1_a/n_a^2 ],

{pstd}
with d_a = d1_a + d2_a and the first term dropped where n_a = d_a, exactly as
{cmd:stcompet} computes it; the default interval is the ln(-ln) interval
F^exp(-/+z se/(F ln F)) of Choudhury (2002) used by {cmd:stcompet}. Without
weights, standard errors and bounds agree with {cmd:stcompet} to rounding
error. The variance is not valid under probability or importance weights,
so {opt ci} is refused there (r(198)); point estimates, {opt landmark()},
and {opt saving()} remain available and saved standard errors are missing.{p_end}

{pstd}
The {opt pvalue} option uses Stata's {cmd:sts test, logrank}. Risk-table
counts honor delayed entry, {cmd:stset} weights as set by
{opt riskweight()}, and subject
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

{pstd}Competing risks: cumulative incidence of pelvic recurrence with distant
recurrence as the competing event, on a percent axis, with a masked risk
table{p_end}
{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. stset dftime, failure(failtype == 1)}{p_end}
{phang2}{cmd:. kmplot, by(pelnode) byorder(1 0) compete(failtype == 2) ci percent risktable riskmask(5) tmax(8) landmark(5)}{p_end}
{phang2}{cmd:. matrix list r(landmarks)}{p_end}

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
{synopt:{cmd:r(ymax)}}upper limit of the y axis, on the plotted scale{p_end}
{synopt:{cmd:r(tmax)}}{opt tmax()}, if specified{p_end}
{synopt:{cmd:r(riskmask)}}masking threshold, when masking is on{p_end}

{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}{cmd:kmplot}{p_end}
{synopt:{cmd:r(graph_name)}}graph name{p_end}
{synopt:{cmd:r(plot_type)}}{bf:survival} or {bf:failure} (incl. {opt compete()}){p_end}
{synopt:{cmd:r(estimator)}}{bf:km}, {bf:km_failure}, or {bf:aalen_johansen}{p_end}
{synopt:{cmd:r(compete)}}the {opt compete()} expression, if specified{p_end}
{synopt:{cmd:r(scale)}}{bf:proportion} or {bf:percent} (plotted scale){p_end}
{synopt:{cmd:r(riskweight)}}{bf:none} or {bf:stset}, with {opt risktable} or {opt risksaving()}{p_end}
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
{synopt:{cmd:r(risktable)}}risk-table counts; masked cells missing{p_end}

{pstd}
{cmd:r(ymax)} is the upper limit of the y axis actually drawn: the automatic
limit or {opt ymax()}; with a user {opt ylabel()}, the largest numeric label
or the plotted maximum ({opt ymax()} instead of the latter when given),
whichever is larger.{p_end}

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
Aalen, O. O., and S. Johansen. 1978. An empirical transition matrix for
non-homogeneous Markov chains based on censored
observations. {it:Scandinavian Journal of Statistics} 5: 141{c -}150.{p_end}

{phang}
Choudhury, J. B. 2002. Non-parametric confidence interval estimation for
competing risks analysis: application to contraceptive data. {it:Statistics in Medicine}
21: 1129{c -}1140. Cited as given by Coviello and Boggess (2004).{p_end}

{phang}
Coviello, V., and M. Boggess. 2004. Cumulative incidence estimation in the
presence of competing risks. {it:Stata Journal} 4: 103{c -}112.{p_end}

{phang}
Kaplan, E. L., and P. Meier. 1958. Nonparametric estimation from incomplete
observations. {it:Journal of the American Statistical Association} 53: 457{c -}481. {browse "https://doi.org/10.1080/01621459.1958.10501452":doi:10.1080/01621459.1958.10501452}.{p_end}

{phang}
Machado, G. M., M. M. Oliveira, and L. A. F. Fernandes. 2009. A
physiologically-based model for simulation of color vision
deficiency. {it:IEEE Transactions on Visualization and Computer Graphics} 15: 1291{c -}1298. {browse "https://doi.org/10.1109/TVCG.2009.113":doi:10.1109/TVCG.2009.113}.{p_end}

{phang}
Marubini, E., and M. G. Valsecchi. 1995. {it:Analysing Survival Data from Clinical Trials and Observational Studies}. Chichester,
UK: Wiley. Cited as given by Coviello and Boggess (2004).{p_end}

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
{pstd}Version 1.0.0, 2026-10-20{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}

{pstd}Check GitHub for the most up-to-date release; it may be newer than the version
installed here.{p_end}

{hline}
