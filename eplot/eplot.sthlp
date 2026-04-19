{smcl}
{* *! version 1.1.0  19apr2026}{...}
{viewerjumpto "Syntax" "eplot##syntax"}{...}
{viewerjumpto "Description" "eplot##description"}{...}
{viewerjumpto "Options" "eplot##options"}{...}
{viewerjumpto "Examples" "eplot##examples"}{...}
{viewerjumpto "Stored results" "eplot##results"}{...}
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
{cmd:eplot} creates effect plots (forest plots and coefficient plots) from
data in memory, stored estimation results, or matrices. It provides a unified,
intuitive interface for visualizing effect sizes with confidence intervals.

{pstd}
{cmd:eplot} supports three modes:

{phang2}
{it:Data mode}: When three numeric variables are specified ({it:esvar lcivar ucivar}),
{cmd:eplot} treats these as effect sizes and confidence limits from data in memory.
This is useful for meta-analysis results, pre-computed estimates, or any tabular
effect data.

{phang2}
{it:Estimates mode}: When no variables are specified, a single {cmd:.} (active
estimates), or a list of stored estimate names is provided, {cmd:eplot} extracts
coefficients from the estimation results. Multiple stored estimates can be
plotted side by side for model comparison.

{phang2}
{it:Matrix mode}: When {opt matrix(matname)} is specified, {cmd:eplot} plots
from a Stata matrix with 2 columns ({it:b}, {it:se}) or 3 columns ({it:b},
{it:lci}, {it:uci}). Row names are used as labels.

{pstd}
{bf:Choosing a mode:} Use {it:data mode} when you have pre-computed effect
sizes in variables (e.g., meta-analysis results from another package). Use
{it:estimates mode} when you want to plot coefficients from a regression you
just ran — this is the quickest path from model to plot. Use {it:matrix mode}
when your results are in a Stata matrix (e.g., from {cmd:matrix} commands or
post-estimation).  When {opt eform} is specified, the constant is automatically
suppressed because exp(_cons) is not interpretable.

{pmore}
Mode detection gives precedence to data mode when the first three tokens are
numeric variables. If stored estimate names happen to match numeric variable
names in memory, {cmd:eplot} will treat the call as data mode. In ambiguous
cases, restore the active model and use {cmd:eplot .}, or rename the variables
or stored estimates.


{marker options}{...}
{title:Options}

{dlgtab:Data specification}

{phang}
{opt labels(varname)} specifies a string variable containing labels for each row
(e.g., study names, coefficient names). If not specified, rows are labeled
generically.

{phang}
{opt weights(varname)} specifies a numeric variable for sizing markers. In forest
plots, this typically represents study weights. Larger weights result in larger
markers.

{phang}
{opt type(varname)} specifies a variable indicating the type of each row:

{p2colset 9 20 22 2}{...}
{p2col:Value}Meaning{p_end}
{p2line}
{p2col:1}Regular effect (study){p_end}
{p2col:2}Missing/excluded{p_end}
{p2col:3}Subgroup pooled effect{p_end}
{p2col:4}Heterogeneity info{p_end}
{p2col:5}Overall pooled effect{p_end}
{p2col:0}Header/label{p_end}
{p2col:6}Blank row{p_end}
{p2colreset}{...}

{pmore}
Rows with type 3 or 5 are displayed as diamonds by default.

{dlgtab:Coefficient selection}

{phang}
{opt keep(coeflist)} specifies which coefficients to keep. Wildcards {cmd:*} and
{cmd:?} are supported.

{phang}
{opt drop(coeflist)} specifies which coefficients to drop. Wildcards are supported.
For example, {cmd:drop(_cons)} removes the constant.

{phang}
{opt rename(spec)} renames coefficients. Syntax: {cmd:rename(oldname = newname ...)}

{dlgtab:Labeling}

{phang}
{opt coeflabels(spec)} specifies custom labels for coefficients or effects.
Syntax: {cmd:coeflabels(coef1 = "Label 1" coef2 = "Label 2")}

{phang}
{opt groups(spec)} defines groups of effects and inserts group headers.
Syntax: {cmd:groups(coef1 coef2 = "Group Label" coef3 coef4 = "Another Group")}

{pmore}
Group headers appear above the first coefficient in each group. Available in
single-model mode only.

{phang}
{opt gap(#)} adds extra vertical space between adjacent {opt groups()} blocks
without requiring blank rows in the source data. Available in data mode and
single-model estimates mode only.

{phang}
{opt headers(spec)} inserts section headers before specified coefficients.
Syntax: {cmd:headers(coef1 = "Section Header")} or
{cmd:headers(before(coef1) = "Section Header")}

{dlgtab:Transform}

{phang}
{opt eform} exponentiates the effect sizes and confidence limits. Use this for
odds ratios, hazard ratios, risk ratios, or other exponentiated coefficients.
The null line is automatically set to 1 instead of 0. In estimates mode,
the x-axis label is automatically set based on the estimation command
(e.g., "Odds Ratio" after {cmd:logit}, "Hazard Ratio" after {cmd:stcox},
"IRR" after {cmd:poisson}).

{phang}
{opt rescale(#)} multiplies all estimates by {it:#}. Useful for rescaling units.

{dlgtab:Confidence intervals}

{phang}
{opt cicap} draws capped confidence interval lines using {cmd:rcap} instead of
{cmd:rspike}. Adds horizontal end caps to CI whiskers.

{dlgtab:Display}

{phang}
{opt values} annotates each row with formatted text showing the point estimate
and confidence interval (e.g., "0.85 (0.72, 0.99)"). Available in data,
single-model estimates, and matrix modes. Requires horizontal layout.

{phang}
{opt vformat(fmt)} specifies the numeric format for values annotation. Default
is {cmd:%5.2f}. If both {opt dp()} and {opt vformat()} are specified,
{opt vformat()} takes precedence. {cmd:eplot} automatically widens the values
column margin when the formatted text is longer than the default layout.

{phang}
{opt xlabel(spec)} passes a tick specification to the effect axis. In
horizontal layout this behaves like Stata's {cmd:xlabel()}, while in vertical
layout it is applied to the y-axis so the effect scale can still be controlled
without remapping the syntax manually.

{phang}
{opt noconstant} drops the constant ({cmd:_cons}) from the plot. Shorthand for
{cmd:drop(_cons)}.

{phang}
{opt stars} adds significance stars to values annotation: * for p<0.05,
** for p<0.01, *** for p<0.001. Available in single-model estimates mode.
p-values are computed from the coefficient and standard error.

{phang}
{opt sigcolors} colors markers and CI lines differently based on whether the
confidence interval excludes the null value. Significant effects use
{opt sigcolor()} (default {cmd:cranberry}); non-significant effects use
{opt insigncolor()} (default {cmd:gs10}). Significance is determined relative
to the {opt null()} line position. When plotting pre-exponentiated ratios
without {opt eform}, specify {cmd:null(1)} to set the correct reference.

{phang}
{opt style(name)} applies a style preset that sets sensible defaults for common
use cases. User-specified options override preset defaults.

{p2colset 9 22 24 2}{...}
{p2col:Preset}Defaults applied{p_end}
{p2line}
{p2col:{cmd:forest}}values annotation, navy markers{p_end}
{p2col:{cmd:coef}}capped CIs, circle markers{p_end}
{p2col:{cmd:lancet}}cranberry diamonds, capped CIs{p_end}
{p2col:{cmd:jama}}black squares, values annotation{p_end}
{p2col:{cmd:nejm}}dark navy circles, capped CIs, values{p_end}
{p2col:{cmd:bmj}}black squares, capped CIs, values{p_end}
{p2colreset}{...}

{phang}
{opt favors(left right)} adds directional annotation text below the x-axis.
Provide two strings indicating the interpretation of each direction, e.g.,
{cmd:favors("Favors Treatment" "Favors Control")}. Available in horizontal
mode only. All three modes are supported.

{phang}
{opt pi(lci_var uci_var)} draws prediction interval whiskers (dashed, behind
the CI whiskers) using the specified lower and upper PI variables. Available
in data mode only. Useful for meta-analysis forest plots showing both CI and PI.

{phang}
{opt i2(string)}, {opt tau2(string)}, {opt qstat(string)} display heterogeneity
statistics in the graph note. Values are displayed as-is (not computed).
Available in data mode only.

{dlgtab:Layout}

{phang}
{opt horizontal} creates a horizontal forest plot with effect sizes on the x-axis
and row labels on the y-axis. This is the default.

{phang}
{opt vertical} creates a vertical plot with effect sizes on the y-axis.

{phang}
{opt sort} sorts coefficients by effect size, smallest at top.

{phang}
{opt order(coeflist)} specifies an explicit ordering of coefficients. List the
coefficient names in the desired display order.

{dlgtab:Multi-model}

{phang}
{opt modellabels(strlist)} specifies custom legend labels for each model in
multi-model mode. Provide one label per model, separated by spaces. Quoted
strings are supported.

{phang}
{opt offset(#)} controls the vertical spacing between models in multi-model
plots. Default is 0.15. Increase for more separation; decrease for tighter
grouping.

{phang}
{opt palette(colorlist)} specifies the color palette for multi-model plots.
Default is {cmd:navy cranberry forest_green dkorange purple teal maroon olive_teal}.
Provide one Stata color name per model.

{phang}
{opt legendopts(string)} specifies additional legend options passed directly to
the legend. Default is {cmd:rows(1) pos(6) size(small)}.

{dlgtab:Markers}

{phang}
{opt mcolor(color)} specifies the marker color. Default is {cmd:navy}. In
multi-model mode, colors are determined by {opt palette()} instead.

{phang}
{opt msymbol(symbol)} specifies the marker symbol. Default is {cmd:O} (circle).

{phang}
{opt msize(size)} specifies the marker size. Default is {cmd:medium} for
single-model and {cmd:medsmall} for multi-model.

{phang}
{opt cicolor(color)} specifies the CI line color. Default matches the marker
color.

{phang}
{opt ciwidth(lwstyle)} specifies the CI line width. Default is {cmd:medium}.


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
(e.g., from {cmd:metan}, {cmd:meta summarize}, or another meta-analysis package).
Use {it:estimates mode} for the fastest path from regression to plot: run a
model, then {cmd:eplot .} to see the coefficients immediately.
Use {it:matrix mode} when results live in a Stata matrix from post-estimation
commands or custom calculations.

{pstd}
{bf:Journal presets.}
The {opt style()} option provides ready-made looks:
{cmd:lancet} (cranberry diamonds, capped CIs),
{cmd:jama} (black squares, values),
{cmd:nejm} (dark navy circles, capped CIs, values), and
{cmd:bmj} (black squares, capped CIs, values).
User-specified options always override preset defaults.

{pstd}
{bf:Eform and auto-labels.}
When {opt eform} is specified in estimates mode, {cmd:eplot} automatically
detects the estimation command and sets the x-axis label:
"Odds Ratio" after {cmd:logit}/{cmd:logistic},
"Hazard Ratio" after {cmd:stcox},
"IRR" after {cmd:poisson}/{cmd:nbreg}.
Override with {opt effect(string)}.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:eplot} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of effects plotted{p_end}
{synopt:{cmd:r(k)}}number of coefficients (excluding headers/diamonds){p_end}
{synopt:{cmd:r(n_models)}}number of models plotted (estimates mode only){p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}graph command executed{p_end}

{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}plotted effects with coefficient names as row labels;
k x 3 (b, ll, ul) for single-model, or k x (3*m) (b_1, ll_1, ul_1, ..., b_m, ll_m, ul_m) for multi-model{p_end}
{synopt:{cmd:r(pvalues)}}p-values for each coefficient (estimates mode, single-model only){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden


{title:Also see}

{psee}
Help: {help twoway}, {help graph}, {help estimates store}, {help graph combine}

{psee}
Stata 18+: {help meta forestplot} (official meta-analysis forest plots)

{psee}
User-written: {cmd:coefplot} (Ben Jann, SSC), {cmd:metan} (SSC){p_end}
