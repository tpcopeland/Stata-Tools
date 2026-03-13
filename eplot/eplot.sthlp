{smcl}
{* *! version 2.0.0  13mar2026}{...}
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
{synopt:{opt w:eights(varname)}}variable for marker/box sizing{p_end}
{synopt:{opt type(varname)}}row type indicator (1=effect, 3=subgroup, 5=overall){p_end}

{syntab:Coefficient selection}
{synopt:{opt keep(coeflist)}}keep specified coefficients{p_end}
{synopt:{opt drop(coeflist)}}drop specified coefficients{p_end}
{synopt:{opt rename(spec)}}rename coefficients (estimates mode){p_end}

{syntab:Labeling}
{synopt:{opt coefl:abels(spec)}}custom coefficient/effect labels{p_end}
{synopt:{opt groups(spec)}}define groups of effects with labels{p_end}
{synopt:{opt head:ers(spec)}}insert section headers{p_end}
{synopt:{opt headings(spec)}}alias for {opt headers()}{p_end}

{syntab:Transform}
{synopt:{opt eform}}exponentiate estimates (for OR, HR, RR){p_end}
{synopt:{opt rescale(#)}}multiply estimates by #{p_end}

{syntab:Reference lines}
{synopt:{opt xline(numlist)}}add vertical reference lines{p_end}
{synopt:{opt null(#)}}null hypothesis line position{p_end}
{synopt:{opt nonull}}suppress null line{p_end}

{syntab:Confidence intervals}
{synopt:{opt level(#)}}confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt noci}}suppress confidence intervals{p_end}
{synopt:{opt cicap}}draw capped CI lines (rcap instead of rspike){p_end}

{syntab:Display}
{synopt:{opt dp(#)}}decimal places; default is 2{p_end}
{synopt:{opt eff:ect(string)}}x-axis title for effect sizes{p_end}
{synopt:{opt val:ues}}annotate each row with formatted effect text{p_end}
{synopt:{opt vformat(fmt)}}format for values; default is {cmd:%5.2f}{p_end}

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
{synopt:{opt ms:ymbol(symbol)}}marker symbol; default is {cmd:O}{p_end}
{synopt:{opt msi:ze(size)}}marker size; default is {cmd:medium}{p_end}
{synopt:{opt boxscale(#)}}box size scaling (percentage){p_end}
{synopt:{opt nobox}}suppress weighted boxes{p_end}
{synopt:{opt nodiamonds}}use markers instead of diamonds for pooled effects{p_end}
{synopt:{opt cicolor(color)}}CI line color{p_end}
{synopt:{opt ciwidth(lwstyle)}}CI line width{p_end}

{syntab:Graph options}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt subti:tle(string)}}graph subtitle{p_end}
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
{opt headers(spec)} inserts section headers before specified coefficients.
Syntax: {cmd:headers(coef1 = "Section Header")} or
{cmd:headers(before(coef1) = "Section Header")}

{dlgtab:Transform}

{phang}
{opt eform} exponentiates the effect sizes and confidence limits. Use this for
odds ratios, hazard ratios, risk ratios, or other exponentiated coefficients.
The null line is automatically set to 1 instead of 0.

{phang}
{opt rescale(#)} multiplies all estimates by {it:#}. Useful for rescaling units.

{dlgtab:Confidence intervals}

{phang}
{opt cicap} draws capped confidence interval lines using {cmd:rcap} instead of
{cmd:rspike}. Adds horizontal end caps to CI whiskers.

{dlgtab:Display}

{phang}
{opt values} annotates each row with formatted text showing the point estimate
and confidence interval (e.g., "0.85 (0.72, 0.99)"). Available in horizontal
mode with single-model estimates, data mode, and matrix mode.

{phang}
{opt vformat(fmt)} specifies the numeric format for values annotation. Default
is {cmd:%5.2f}.

{dlgtab:Layout}

{phang}
{opt horizontal} creates a horizontal forest plot with effect sizes on the x-axis
and row labels on the y-axis. This is the default.

{phang}
{opt vertical} creates a vertical plot with effect sizes on the y-axis.

{phang}
{opt sort} sorts coefficients by effect size magnitude, smallest at top.

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


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:eplot} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of effects plotted{p_end}
{synopt:{cmd:r(n_models)}}number of models plotted (estimates mode){p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}graph command executed{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden


{title:Also see}

{psee}
Help: {help twoway}, {help graph}, {help estimates store}
{p_end}
