{smcl}
{* *! version 1.1.1  30apr2026}{...}
{vieweralsosee "[G] graph twoway" "help twoway"}{...}
{vieweralsosee "estimates store" "help estimates store"}{...}
{viewerjumpto "Syntax" "eplot##syntax"}{...}
{viewerjumpto "Description" "eplot##description"}{...}
{viewerjumpto "Options" "eplot##options"}{...}
{viewerjumpto "Remarks" "eplot##remarks"}{...}
{viewerjumpto "Examples" "eplot##examples"}{...}
{viewerjumpto "Stored results" "eplot##results"}{...}
{viewerjumpto "Also see" "eplot##alsosee"}{...}
{viewerjumpto "Author" "eplot##author"}{...}

{title:Title}

{p2colset 5 14 16 2}{...}
{p2col:{cmd:eplot} {hline 2}}Unified effect plotting for forest plots and coefficient plots{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Plot effects from data in memory:

{p 8 16 2}
{cmd:eplot} {it:esvar} {it:lcivar} {it:ucivar} {ifin} [{cmd:,} {it:options}]


{pstd}
Plot coefficients from stored estimates (single or multiple models):

{p 8 16 2}
{cmd:eplot} [{it:namelist}] [{cmd:,} {it:options}]


{pstd}
Plot from matrix:

{p 8 16 2}
{cmd:eplot} {cmd:,} {opt matrix(matname)} [{it:options}]


{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Data specification}
{synopt:{opt lab:els(varname)}}variable containing row labels{p_end}
{synopt:{opt wei:ghts(varname)}}variable for marker/box sizing{p_end}
{synopt:{opt type(varname)}}row type indicator (1=effect, 3=subgroup, 5=overall){p_end}

{syntab:Coefficient selection}
{synopt:{opt keep(coeflist)}}keep specified coefficients{p_end}
{synopt:{opt drop(coeflist)}}drop specified coefficients{p_end}
{synopt:{opt rename(spec)}}rename coefficients (estimates mode){p_end}
{synopt:{opt nocons:tant}}drop the constant (_cons){p_end}

{syntab:Labeling}
{synopt:{opt coefl:abels(spec)}}custom coefficient/effect labels{p_end}
{synopt:{opt groups(spec)}}define groups of effects with labels{p_end}
{synopt:{opt head:ers(spec)}}insert section headers{p_end}
{synopt:{opt headings(spec)}}alias for {opt headers()}{p_end}
{synopt:{opt gap(#)}}extra vertical space between {opt groups()} blocks; single-model only{p_end}

{syntab:Transform}
{synopt:{opt eform}}exponentiate estimates (for OR, HR, RR){p_end}
{synopt:{opt rescale(#)}}multiply estimates by #{p_end}

{syntab:Reference lines}
{synopt:{opt xline(numlist)}}add vertical reference lines{p_end}
{synopt:{opt xlab:el(spec)}}effect-axis tick specification; maps to the effect axis in either layout{p_end}
{synopt:{opt null(#)}}null hypothesis line position{p_end}
{synopt:{opt nonull}}suppress null line{p_end}

{syntab:Confidence intervals}
{synopt:{opt level(#)}}confidence level; default is {cmd:level(95)}; estimates and matrix modes only{p_end}
{synopt:{opt noci}}suppress confidence intervals{p_end}
{synopt:{opt cicap}}draw capped CI lines (rcap instead of rspike){p_end}

{syntab:Display}
{synopt:{opt dp(#)}}decimal places; default is 2{p_end}
{synopt:{opt eff:ect(string)}}x-axis title for effect sizes{p_end}
{synopt:{opt val:ues}}annotate each row with formatted effect text{p_end}
{synopt:{opt vformat(fmt)}}format for values; default is {cmd:%5.2f}{p_end}
{synopt:{opt star:s}}add significance stars (*, **, ***) to values; estimates and matrix (2-col) modes{p_end}
{synopt:{opt sigcolors}}color markers by significance (CI vs null){p_end}
{synopt:{opt sigcolor(color)}}color for significant effects; default is {cmd:cranberry}{p_end}
{synopt:{opt insigncolor(color)}}color for non-significant effects; default is {cmd:gs10}{p_end}
{synopt:{opt sty:le(name)}}style preset: {cmd:forest}, {cmd:coef}, {cmd:lancet}, {cmd:jama}, {cmd:nejm}, or {cmd:bmj}{p_end}
{synopt:{opt favors(left right)}}directional annotation text below x-axis (horizontal mode){p_end}

{syntab:Prediction intervals (data mode)}
{synopt:{opt pi(lci_var uci_var)}}draw prediction interval whiskers behind CIs{p_end}

{syntab:Heterogeneity (data mode)}
{synopt:{opt i2(string)}}display I-squared value in note{p_end}
{synopt:{opt tau2(string)}}display tau-squared value in note{p_end}
{synopt:{opt qstat(string)}}display Q statistic in note{p_end}

{syntab:Layout}
{synopt:{opt hor:izontal}}horizontal layout (default){p_end}
{synopt:{opt vert:ical}}vertical layout{p_end}
{synopt:{opt sort}}sort coefficients by effect size{p_end}
{synopt:{opt order(coeflist)}}explicit coefficient ordering{p_end}

{syntab:Multi-model (estimates mode)}
{synopt:{opt modell:abels(strlist)}}custom legend labels for each model{p_end}
{synopt:{opt off:set(#)}}vertical spacing between models; default is 0.15{p_end}
{synopt:{opt pal:ette(colorlist)}}color palette for models{p_end}
{synopt:{opt legendopts(string)}}additional legend options{p_end}

{syntab:Markers}
{synopt:{opt mc:olor(color)}}marker color{p_end}
{synopt:{opt msy:mbol(symbol)}}marker symbol; default is {cmd:O}{p_end}
{synopt:{opt msi:ze(size)}}marker size; default is {cmd:medium}{p_end}
{synopt:{opt boxscale(#)}}box size scaling (percentage); default is {cmd:100}{p_end}
{synopt:{opt nobox}}suppress weighted boxes{p_end}
{synopt:{opt nodiamonds}}use markers instead of diamonds for pooled effects{p_end}
{synopt:{opt cicolor(color)}}CI line color{p_end}
{synopt:{opt ciwidth(lwstyle)}}CI line width{p_end}

{syntab:Graph options}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt sub:title(string)}}graph subtitle{p_end}
{synopt:{opt note(string)}}graph note{p_end}
{synopt:{opt name(string)}}graph name{p_end}
{synopt:{opt saving(filename)}}save graph to file{p_end}
{synopt:{opt scheme(schemename)}}graph scheme{p_end}
{synopt:{opt plotregion(options)}}plot region options{p_end}
{synopt:{opt graphregion(options)}}graph region options{p_end}
{synopt:{opt aspect(#)}}aspect ratio{p_end}
{synopt:{it:twoway_options}}other {help twoway} options{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:eplot} creates forest plots and coefficient plots from data in memory,
stored estimation results, or matrices.  Instead of switching between separate
plotting commands for different workflows, {cmd:eplot} provides one interface
for all three sources.

{pstd}
{bf:Quick start.}  Run a regression and see the coefficients immediately:

	{cmd:. sysuse auto, clear}
	{cmd:. regress price mpg weight foreign}
	{cmd:. eplot ., drop(_cons) cicap}

{pstd}
{cmd:eplot} supports three input modes.  It detects the mode automatically
from the arguments you supply:

{phang2}
{bf:1. Data mode} — you supply three numeric variables ({it:esvar lcivar ucivar}).
{cmd:eplot} treats them as point estimates and confidence limits.  This is the
mode for meta-analysis results, pre-computed estimates, or any tabular effect
data that already lives in your dataset.

{phang2}
{bf:2. Estimates mode} — you supply nothing, a single {cmd:.} (for the active
model), or a list of stored estimate names.  {cmd:eplot} reads coefficients
directly from the estimation results.  This is the fastest path from model to
plot: run a regression, then type {cmd:eplot .} to see the coefficients.
Multiple stored estimates can be overlaid for model comparison.

{phang2}
{bf:3. Matrix mode} — you specify {opt matrix(matname)}.  {cmd:eplot} reads a
Stata matrix with either 2 columns ({it:b}, {it:se}) or 3 columns ({it:b},
{it:lci}, {it:uci}).  Row names become labels.  This is useful when results
come from post-estimation commands or custom calculations.

{pstd}
{bf:Choosing the right mode.}

{p2colset 9 24 26 2}{...}
{p2col:Situation}Mode to use{p_end}
{p2line}
{p2col:Just ran a regression}Estimates: {cmd:eplot .}{p_end}
{p2col:Comparing two models}Estimates: {cmd:eplot m1 m2}{p_end}
{p2col:Have effect sizes in variables}Data: {cmd:eplot es lci uci}{p_end}
{p2col:Results in a matrix}Matrix: {cmd:eplot, matrix(R)}{p_end}
{p2colreset}{...}

{pstd}
When {opt eform} is specified, the constant ({cmd:_cons}) is automatically
suppressed because exp(_cons) is not interpretable.

{pstd}
{bf:Mode detection.}
Mode detection gives precedence to data mode when the first three tokens are
numeric variables.  If stored estimate names happen to match numeric variable
names in memory, {cmd:eplot} will treat the call as data mode.  In ambiguous
cases, use {cmd:eplot .} to force estimates mode or {opt matrix()} to force
matrix mode.


{marker options}{...}
{title:Options}

{pstd}
Not every option works in every mode.  The availability tags below indicate
which modes accept each option:
{bf:[D]} = data mode,
{bf:[E]} = estimates mode,
{bf:[M]} = matrix mode.
Options without a tag work in all three modes.

{dlgtab:Data specification}

{phang}
{opt labels(varname)} {bf:[D]}
specifies a string variable containing labels for each row (e.g., study names).
If omitted, rows are labeled "Row 1", "Row 2", etc.

{phang}
{opt weights(varname)} {bf:[D]}
specifies a numeric variable that controls marker (or box) size.  In a forest
plot this typically represents study weights; larger values produce larger
markers.  When {opt weights()} is specified, markers are drawn as filled
squares whose area is proportional to the weight.

{phang}
{opt type(varname)} {bf:[D]}
specifies a variable indicating the role of each row in the plot.  This lets
you include headers, subgroup summaries, and overall pooled estimates in one
dataset.  Accepted values:

{p2colset 9 20 22 2}{...}
{p2col:Value}Meaning{p_end}
{p2line}
{p2col:0}Header or label row (no point or CI){p_end}
{p2col:1}Regular effect (individual study or coefficient){p_end}
{p2col:2}Missing or excluded row{p_end}
{p2col:3}Subgroup pooled effect (drawn as a diamond){p_end}
{p2col:4}Heterogeneity information row{p_end}
{p2col:5}Overall pooled effect (drawn as a diamond){p_end}
{p2col:6}Blank spacer row{p_end}
{p2colreset}{...}

{pmore}
If {opt type()} is a string variable, the values {cmd:"header"},
{cmd:"missing"}, {cmd:"subgroup"}, {cmd:"hetinfo"}, {cmd:"overall"}, and
{cmd:"blank"} are recognized.  If {opt type()} is omitted, all rows are
treated as regular effects (type 1).

{dlgtab:Coefficient selection}

{phang}
{opt keep(coeflist)}
specifies which coefficients to keep.  All others are dropped.  Wildcards
{cmd:*} and {cmd:?} are supported.  Example: {cmd:keep(mpg weight)} keeps only
those two coefficients.

{phang}
{opt drop(coeflist)}
specifies which coefficients to drop.  All others are kept.  Wildcards are
supported.  Example: {cmd:drop(_cons)} removes the constant.

{phang}
{opt noconstant}
drops the constant ({cmd:_cons}) from the plot.  This is shorthand for
{cmd:drop(_cons)}.

{phang}
{opt rename(spec)} {bf:[E]}
renames coefficients for display.  Syntax:
{cmd:rename(oldname = newname oldname2 = newname2)}.

{dlgtab:Labeling}

{phang}
{opt coeflabels(spec)}
assigns custom labels to coefficients or effects.  Syntax:
{cmd:coeflabels(coef1 = "Label 1" coef2 = "Label 2")}.  In data mode, labels
are matched against the {opt labels()} variable.

{phang}
{opt groups(spec)} {bf:[D]} {bf:[E single-model]}
groups coefficients under section headers.  Syntax:
{cmd:groups(coef1 coef2 = "Group A" coef3 coef4 = "Group B")}.  Group headers
appear as bold text above the first coefficient in each group.

{phang}
{opt gap(#)} {bf:[D]} {bf:[E single-model]}
adds extra vertical space between adjacent {opt groups()} blocks.  The value
sets the gap size in row-height units; the default is {cmd:0} (no extra space).
Useful for visually separating clinical domains in forest plots without
inserting blank rows in the source data.

{phang}
{opt headers(spec)} {bf:[D]} {bf:[E single-model]}
inserts a section header before a specified coefficient.  Syntax:
{cmd:headers(coef1 = "Section Header")}.  Use this when you want a header
above a single coefficient rather than grouping multiple coefficients.
{opt headings()} is accepted as an alias.

{dlgtab:Transform}

{phang}
{opt eform}
exponentiates the point estimates and confidence limits before plotting.
Use this after models estimated on the log scale — for example, {cmd:logit}
(odds ratios), {cmd:stcox} (hazard ratios), or {cmd:poisson} (incidence-rate
ratios).  The null line is automatically set to 1 instead of 0.  In estimates
mode, the x-axis label is set automatically (e.g., "Odds Ratio" after
{cmd:logit}, "Hazard Ratio" after {cmd:stcox}, "IRR" after {cmd:poisson}).

{phang}
{opt rescale(#)}
multiplies all estimates and confidence limits by {it:#} before plotting.
Useful for rescaling units (e.g., per 10-unit increase).

{dlgtab:Reference lines}

{phang}
{opt null(#)}
sets the position of the null hypothesis line.  Default is {cmd:0} (or
{cmd:1} when {opt eform} is specified).  Override to use a different reference
value.

{phang}
{opt nonull}
suppresses the null hypothesis line entirely.

{phang}
{opt xline(numlist)}
adds additional vertical reference lines at the specified positions.

{phang}
{opt xlabel(spec)}
controls the tick marks on the effect axis.  In horizontal layout this maps
to Stata's {cmd:xlabel()}; in vertical layout it maps to {cmd:ylabel()}, so
you can control the effect scale without worrying about orientation.

{dlgtab:Confidence intervals}

{phang}
{opt level(#)} {bf:[E]} {bf:[M]}
sets the confidence level for interval construction.  Default is {cmd:95}.
In data mode, confidence limits are taken directly from the supplied variables.

{phang}
{opt noci}
suppresses confidence interval whiskers entirely.  Only point estimates are
plotted.

{phang}
{opt cicap}
draws capped confidence interval lines (using {cmd:rcap}) instead of the
default uncapped lines ({cmd:rspike}).  Caps add horizontal end bars to each
whisker.

{dlgtab:Display}

{phang}
{opt dp(#)}
sets the number of decimal places used in {opt values} annotation.  Default
is {cmd:2}.  Ignored if {opt vformat()} is specified.

{phang}
{opt effect(string)}
sets the x-axis title (or y-axis title in vertical layout).  Default is
"Estimate (95% CI)", or "Effect (95% CI)" when {opt eform} is specified.
Override with a custom label such as {cmd:effect("Odds Ratio (95% CI)")}.

{phang}
{opt values} {bf:[D]} {bf:[E single-model]} {bf:[M]}
annotates each row with formatted text showing the point estimate and
confidence interval (e.g., "0.85 (0.72, 0.99)").  Requires horizontal layout.
See also {opt vformat()} for custom formatting.

{phang}
{opt vformat(fmt)}
sets the numeric format for the {opt values} annotation.  Default is
{cmd:%5.2f} (or {cmd:%5.}{it:dp}{cmd:f} when {opt dp()} is specified).
Example: {cmd:vformat(%6.3f)}.  {cmd:eplot} automatically widens the values
column margin when formatted text is longer than the default layout.

{phang}
{opt stars} {bf:[E single-model]} {bf:[M 2-col]}
appends significance stars to the {opt values} annotation: {cmd:*} for
p < 0.05, {cmd:**} for p < 0.01, {cmd:***} for p < 0.001.  p-values are
computed from the coefficient and its standard error.  In matrix mode, this
requires a 2-column matrix (b and se); 3-column matrices (b, lci, uci) do
not carry standard errors so stars are not available.

{phang}
{opt sigcolors}
colors markers and CI lines by statistical significance.  Effects whose
confidence interval excludes the null value are drawn in {opt sigcolor()}
(default {cmd:cranberry}); non-significant effects are drawn in
{opt insigncolor()} (default {cmd:gs10}).  Significance is determined
relative to the {opt null()} position.  When plotting pre-exponentiated
ratios without {opt eform}, set {cmd:null(1)} to use the correct reference.

{phang}
{opt sigcolor(color)}
color for statistically significant effects when {opt sigcolors} is
specified.  Default is {cmd:cranberry}.

{phang}
{opt insigncolor(color)}
color for non-significant effects when {opt sigcolors} is specified.
Default is {cmd:gs10}.

{phang}
{opt style(name)}
applies a style preset.  Presets set sensible defaults for common journal
and plot styles; any option you specify explicitly overrides the preset.

{p2colset 9 22 24 2}{...}
{p2col:Preset}What it sets{p_end}
{p2line}
{p2col:{cmd:forest}}values annotation, navy markers{p_end}
{p2col:{cmd:coef}}capped CIs, circle markers{p_end}
{p2col:{cmd:lancet}}cranberry diamonds, capped CIs{p_end}
{p2col:{cmd:jama}}black squares, values annotation{p_end}
{p2col:{cmd:nejm}}dark navy circles, capped CIs, values{p_end}
{p2col:{cmd:bmj}}black squares, capped CIs, values{p_end}
{p2colreset}{...}

{phang}
{opt favors(left right)}
adds directional annotation text below the x-axis (horizontal layout only).
Provide two quoted strings, e.g.,
{cmd:favors("Favors Treatment" "Favors Control")}.  Useful in forest plots to
show the clinical interpretation of each direction.

{dlgtab:Prediction intervals (data mode)}

{phang}
{opt pi(lci_var uci_var)} {bf:[D]}
draws prediction interval whiskers as dashed lines behind the confidence
interval whiskers.  Specify two numeric variables for the lower and upper
prediction limits.  Prediction intervals are wider than confidence intervals
and show the range within which a future study's true effect is expected to
fall.

{dlgtab:Heterogeneity (data mode)}

{phang}
{opt i2(string)} {bf:[D]}
displays the I-squared (I{c 178}) heterogeneity value in the graph note.  The value
is displayed as-is — {cmd:eplot} does not compute it.

{phang}
{opt tau2(string)} {bf:[D]}
displays the between-study variance ({it:tau}{c 178}) in the graph note.

{phang}
{opt qstat(string)} {bf:[D]}
displays the Q statistic (Cochran's Q) in the graph note.  Example:
{cmd:qstat("8.63, df=5, p=0.125")}.

{dlgtab:Layout}

{phang}
{opt horizontal}
creates a horizontal plot with effect sizes on the x-axis and row labels on
the y-axis.  This is the default and is the standard orientation for forest
plots.

{phang}
{opt vertical}
creates a vertical plot with effect sizes on the y-axis.

{phang}
{opt sort}
sorts coefficients by effect size, smallest at top.  In data mode, only
regular effects (type 1) are sorted; headers, pooled estimates, and blank
rows keep their original positions.

{phang}
{opt order(coeflist)}
specifies an explicit ordering of coefficients.  List the coefficient names
(or labels, in data mode) in the desired display order.  Unmatched names are
placed at the end.

{dlgtab:Multi-model (estimates mode)}

{phang}
{opt modellabels(strlist)} {bf:[E]}
specifies custom legend labels for each model.  Provide one label per model,
in the same order as the estimate names.  Quoted strings are supported:
{cmd:modellabels("Base Model" "Adjusted")}.

{phang}
{opt offset(#)} {bf:[E]}
controls the vertical spacing between models when overlaying multiple
estimates on the same coefficient row.  Default is {cmd:0.15}.  Increase for
more visual separation; decrease for tighter grouping.

{phang}
{opt palette(colorlist)} {bf:[E]}
specifies the color palette for multi-model plots.  Default is
{cmd:navy cranberry forest_green dkorange purple teal maroon olive_teal}.
Provide one Stata color name per model.

{phang}
{opt legendopts(string)} {bf:[E]}
passes additional options to the graph legend.  Default is
{cmd:rows(1) pos(6) size(small)}.

{dlgtab:Markers}

{phang}
{opt mcolor(color)}
sets the marker color.  Default is {cmd:navy}.  In multi-model estimates mode,
per-model colors come from {opt palette()} instead.

{phang}
{opt msymbol(symbol)}
sets the marker symbol.  Default is {cmd:O} (filled circle).

{phang}
{opt msize(size)}
sets the marker size.  Default is {cmd:medium} for single-model plots and
{cmd:medsmall} for multi-model plots.

{phang}
{opt boxscale(#)} {bf:[D]}
scales the weighted-box marker size.  The value is a percentage; default is
{cmd:100}.  Use {cmd:boxscale(150)} for 50% larger boxes or {cmd:boxscale(50)}
for half-sized boxes.

{phang}
{opt nobox} {bf:[D]}
suppresses weighted square markers.  Effects are drawn with the standard
marker symbol instead of weight-proportional squares.

{phang}
{opt nodiamonds} {bf:[D]}
draws pooled effects (type 3 and 5 rows) as standard markers instead of
diamonds.

{phang}
{opt cicolor(color)}
sets the CI line color.  Default matches {opt mcolor()}.

{phang}
{opt ciwidth(lwstyle)}
sets the CI line width.  Default is {cmd:medium}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic forest plot from data}

{phang2}{stata "clear":. clear}{p_end}
{phang2}{cmd:. input str20 study es lci uci weight}{p_end}
{phang2}{cmd:. "Smith 2020"    -0.16  -0.36  0.03  15.2}{p_end}
{phang2}{cmd:. "Jones 2021"    -0.33  -0.54 -0.12  18.4}{p_end}
{phang2}{cmd:. "Brown 2022"    -0.09  -0.25  0.06  22.1}{p_end}
{phang2}{cmd:. "Wilson 2023"   -0.39  -0.65 -0.12  12.8}{p_end}
{phang2}{cmd:. "Overall"       -0.24  -0.34 -0.13   .}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{stata `"gen byte type = cond(study=="Overall", 5, 1)"':. gen byte type = cond(study=="Overall", 5, 1)}{p_end}
{phang2}{stata "eplot es lci uci, labels(study) weights(weight) type(type) scheme(plotplainblind)":. eplot es lci uci, labels(study) weights(weight) type(type) scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 2: Forest plot with values annotation}

{phang2}{cmd:. eplot es lci uci, labels(study) weights(weight) type(type) values scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 3: Coefficient plot from regression}

{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "regress price mpg weight foreign":. regress price mpg weight foreign}{p_end}
{phang2}{cmd:. eplot ., drop(_cons) coeflabels(mpg = "Miles per Gallon" weight = "Vehicle Weight" foreign = "Foreign Make") cicap scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 4: Multi-model comparison}

{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "quietly regress price mpg weight foreign":. quietly regress price mpg weight foreign}{p_end}
{phang2}{stata "estimates store base":. estimates store base}{p_end}
{phang2}{stata "quietly regress price mpg weight length foreign headroom":. quietly regress price mpg weight length foreign headroom}{p_end}
{phang2}{stata "estimates store extended":. estimates store extended}{p_end}
{phang2}{cmd:. eplot base extended, drop(_cons) modellabels("Base" "Extended") scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 5: Sorted coefficients with custom colors}

{phang2}{stata "regress price mpg weight length foreign":. regress price mpg weight length foreign}{p_end}
{phang2}{cmd:. eplot ., drop(_cons) sort cicap mcolor(cranberry) scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 6: Using groups}

{phang2}{stata "regress price mpg weight length turn foreign rep78":. regress price mpg weight length turn foreign rep78}{p_end}
{phang2}{cmd:. eplot ., drop(_cons) groups(mpg weight length turn = "Vehicle Characteristics" foreign rep78 = "Other Factors") scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 7: Matrix mode}

{phang2}{cmd:. matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.2, 0.9, 1.6)}{p_end}
{phang2}{cmd:. matrix rownames R = "Treatment_A" "Treatment_B" "Treatment_C"}{p_end}
{phang2}{cmd:. eplot, matrix(R) eform effect("Odds Ratio") scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 8: Logistic regression with eform}

{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "logit foreign mpg weight length":. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. eplot ., drop(_cons) eform values effect("Odds Ratio") scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 9: Noconstant, auto-labels, and significance stars}

{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "regress price mpg weight foreign":. regress price mpg weight foreign}{p_end}
{phang2}{cmd:. eplot ., noconstant stars values scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 10: Color-coded significance}

{phang2}{cmd:. eplot ., noconstant sigcolors sigcolor(navy) insigncolor(gs12) cicap scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 11: Style presets}

{phang2}{cmd:. eplot ., noconstant style(lancet) scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 12: Factor variable labels}

{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "logit foreign mpg weight i.rep78":. logit foreign mpg weight i.rep78}{p_end}
{phang2}{cmd:. eplot ., noconstant eform cicap scheme(plotplainblind)}{p_end}

{pstd}
{bf:Example 13: Meta-analysis forest plot with heterogeneity}

{phang2}{stata "clear":. clear}{p_end}
{phang2}{cmd:. input str20 study es lci uci weight byte type}{p_end}
{phang2}{cmd:. "Smith 2018"   -0.42  -0.78  -0.06  12.3  1}{p_end}
{phang2}{cmd:. "Jones 2019"   -0.31  -0.58  -0.04  16.8  1}{p_end}
{phang2}{cmd:. "Brown 2020"   -0.18  -0.41   0.05  21.5  1}{p_end}
{phang2}{cmd:. "Lee 2021"     -0.55  -0.93  -0.17  10.2  1}{p_end}
{phang2}{cmd:. "Garcia 2022"  -0.27  -0.49  -0.05  19.1  1}{p_end}
{phang2}{cmd:. "Patel 2023"   -0.09  -0.35   0.17  20.1  1}{p_end}
{phang2}{cmd:. "Overall"      -0.28  -0.41  -0.15   .    5}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. eplot es lci uci, labels(study) weights(weight) type(type) values vformat(%4.2f) i2("42.1") tau2("0.021") qstat("8.63, df=5, p=0.125") effect("Mean Difference (95% CI)") scheme(plotplainblind)}{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Choosing a mode.}
Use {it:data mode} when you have pre-computed effect sizes in variables
(e.g., from {cmd:metan}, {cmd:meta summarize}, or another meta-analysis
package).  Use {it:estimates mode} for the fastest path from regression to
plot: run a model, then {cmd:eplot .} to see the coefficients immediately.
Use {it:matrix mode} when results live in a Stata matrix from post-estimation
commands or custom calculations.

{pstd}
{bf:Journal presets.}
The {opt style()} option provides ready-made looks modeled on journal
conventions:
{cmd:lancet} (cranberry diamonds, capped CIs),
{cmd:jama} (black squares, values),
{cmd:nejm} (dark navy circles, capped CIs, values), and
{cmd:bmj} (black squares, capped CIs, values).
The two generic presets, {cmd:forest} and {cmd:coef}, are useful starting
points for general-purpose plots.  User-specified options always override
preset defaults.

{pstd}
{bf:Eform and auto-labels.}
When {opt eform} is specified in estimates mode, {cmd:eplot} automatically
detects the estimation command and sets the x-axis label:
"Odds Ratio" after {cmd:logit}/{cmd:logistic},
"Hazard Ratio" after {cmd:stcox},
"IRR" after {cmd:poisson}/{cmd:nbreg}.
Override with {opt effect(string)}.  In data mode and matrix mode, {opt eform}
exponentiates the supplied values (useful when they are on the log scale) and
shifts the null line to 1.

{pstd}
{bf:Layering options.}
Options in {cmd:eplot} are designed to be layered.  Start with a bare
{cmd:eplot .} call, then add {opt cicap}, {opt values}, {opt sigcolors},
{opt groups()}, or {opt style()} incrementally until the plot looks right.
Because {opt style()} presets are overridden by explicit options, you can
start from a preset and customize individual elements.

{pstd}
{bf:Values annotation.}
When {opt values} is specified, {cmd:eplot} prints the point estimate and
confidence interval next to each marker (e.g., "0.85 (0.72, 0.99)").
The column width adjusts automatically to accommodate long formatted
strings.  Use {opt vformat()} for custom formatting.

{pstd}
{bf:Significance visualization.}
Two complementary tools are available.  {opt stars} appends asterisks to the
values text.  {opt sigcolors} draws significant and non-significant effects
in contrasting colors.  Both can be used together.

{pstd}
{bf:Prediction intervals and heterogeneity.}
In data mode, {opt pi()} overlays prediction intervals as dashed whiskers
behind the confidence intervals — useful for meta-analysis plots that
distinguish between the uncertainty around the pooled estimate (CI) and
the expected range of true effects across studies (PI).
{opt i2()}, {opt tau2()}, and {opt qstat()} add heterogeneity statistics
as a graph note.

{pstd}
{bf:Working with factor variables.}
In estimates mode, {cmd:eplot} recognizes factor-variable notation
(e.g., {cmd:i.rep78}) and uses Stata's value labels as coefficient labels
automatically.  No {opt coeflabels()} needed unless you want custom text.

{pstd}
{bf:Common patterns.}

{p2colset 9 42 44 2}{...}
{p2col:Goal}Command{p_end}
{p2line}
{p2col:Quick coefficient plot}{cmd:eplot ., noconstant cicap}{p_end}
{p2col:Odds ratios after logit}{cmd:eplot ., eform values}{p_end}
{p2col:Compare two models}{cmd:eplot m1 m2, drop(_cons)}{p_end}
{p2col:Lancet-style forest plot}{cmd:eplot es lci uci, style(lancet)}{p_end}
{p2col:Significance coloring}{cmd:eplot ., noconstant sigcolors}{p_end}
{p2colreset}{...}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:eplot} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of effects plotted{p_end}
{synopt:{cmd:r(k)}}number of plotted coefficients (excludes headers and diamonds){p_end}
{synopt:{cmd:r(n_models)}}number of models plotted (estimates mode only){p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}the full {cmd:twoway} command that was executed{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}k x 3 matrix of plotted effects ({it:b}, {it:ll}, {it:ul}); k x 3m for multi-model{p_end}
{synopt:{cmd:r(pvalues)}}p-values per coefficient (estimates mode, single-model only){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden


{marker alsosee}{...}
{title:Also see}

{psee}
Help: {help twoway}, {help graph}, {help estimates store}, {help graph combine}

{psee}
Stata 18+: {help meta forestplot} (official meta-analysis forest plots)

{psee}
User-written: {cmd:coefplot} (Ben Jann, SSC), {cmd:metan} (SSC)

{hline}
