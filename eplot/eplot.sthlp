{smcl}
{* *! version 1.0.0  09jan2026}{...}
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
Plot coefficients from stored estimates:

{p 8 16 2}
{cmd:eplot} [{it:namelist}] [{cmd:,} {it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Data specification}
{synopt:{opt lab:els(varname)}}variable containing row labels{p_end}
{synopt:{opt w:eights(varname)}}variable for marker/box sizing{p_end}
{synopt:{opt type(varname)}}row type indicator (1=effect, 3=subgroup, 5=overall){p_end}
{synopt:{opt se(varname)}}standard errors (alternative to CI variables){p_end}

{syntab:Coefficient selection}
{synopt:{opt keep(coeflist)}}keep specified coefficients{p_end}
{synopt:{opt drop(coeflist)}}drop specified coefficients{p_end}
{synopt:{opt order(coeflist)}}reorder coefficients{p_end}
{synopt:{opt rename(spec)}}rename coefficients{p_end}

{syntab:Labeling}
{synopt:{opt coefl:abels(spec)}}custom coefficient/effect labels{p_end}
{synopt:{opt groups(spec)}}define groups of effects with labels{p_end}
{synopt:{opt head:ers(spec)}}insert section headers{p_end}
{synopt:{opt headings(spec)}}alias for {opt headers()}{p_end}

{syntab:Transform}
{synopt:{opt eform}}exponentiate estimates (for OR, HR, RR){p_end}
{synopt:{opt percent}}display as percentages{p_end}
{synopt:{opt rescale(#)}}multiply estimates by #{p_end}

{syntab:Reference lines}
{synopt:{opt xline(numlist)}}add vertical reference lines{p_end}
{synopt:{opt null(#)}}null hypothesis line position{p_end}
{synopt:{opt nonull}}suppress null line{p_end}

{syntab:Confidence intervals}
{synopt:{opt level(#)}}confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt levels(numlist)}}multiple CI levels{p_end}
{synopt:{opt noci}}suppress confidence intervals{p_end}

{syntab:Display}
{synopt:{opt nostats}}suppress effect size column{p_end}
{synopt:{opt nowt}}suppress weight column{p_end}
{synopt:{opt nonames}}suppress row labels{p_end}
{synopt:{opt dp(#)}}decimal places; default is 2{p_end}
{synopt:{opt eff:ect(string)}}column header for effect sizes{p_end}
{synopt:{opt favours(spec)}}x-axis labels (left # right){p_end}

{syntab:Layout}
{synopt:{opt lcols(varlist)}}left-side text columns{p_end}
{synopt:{opt rcols(varlist)}}right-side text columns{p_end}
{synopt:{opt spacing(#)}}row spacing multiplier{p_end}
{synopt:{opt textsize(#)}}text size multiplier (percentage){p_end}
{synopt:{opt astext(#)}}percent of width for text (10-90){p_end}
{synopt:{opt hor:izontal}}horizontal layout (default){p_end}
{synopt:{opt vert:ical}}vertical layout{p_end}

{syntab:Markers}
{synopt:{opt boxscale(#)}}box size scaling (percentage){p_end}
{synopt:{opt nobox}}suppress weighted boxes{p_end}
{synopt:{opt nodiamonds}}use markers instead of diamonds for pooled effects{p_end}

{syntab:Graph options}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt subti:tle(string)}}graph subtitle{p_end}
{synopt:{opt note(string)}}graph note{p_end}
{synopt:{opt name(string)}}graph name{p_end}
{synopt:{opt saving(filename)}}save graph to file{p_end}
{synopt:{opt scheme(schemename)}}graph scheme{p_end}
{synopt:{it:twoway_options}}other {help twoway} options{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:eplot} creates effect plots (forest plots and coefficient plots) from either
data in memory or stored estimation results. It provides a unified, intuitive
interface for visualizing effect sizes with confidence intervals.

{pstd}
{cmd:eplot} supports two main modes:

{phang2}
{it:Data mode}: When three numeric variables are specified ({it:esvar lcivar ucivar}),
{cmd:eplot} treats these as effect sizes and confidence limits from data in memory.
This is useful for meta-analysis results, pre-computed estimates, or any tabular
effect data.

{phang2}
{it:Estimates mode}: When no variables are specified or a list of stored estimate
names is provided, {cmd:eplot} extracts coefficients from the estimation results.
Use {cmd:.} to refer to the active estimation results.


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
Group headers appear above the first coefficient in each group.

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

{dlgtab:Reference lines}

{phang}
{opt xline(numlist)} adds vertical reference lines at the specified values.

{phang}
{opt null(#)} specifies the position of the null hypothesis line. Default is 0,
or 1 if {opt eform} is specified.

{phang}
{opt nonull} suppresses the null hypothesis line.

{dlgtab:Layout}

{phang}
{opt horizontal} creates a horizontal forest plot with effect sizes on the x-axis
and row labels on the y-axis. This is the default.

{phang}
{opt vertical} creates a vertical plot with effect sizes on the y-axis.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic forest plot from data}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str20 study es lci uci weight}{p_end}
{phang2}{cmd:. "Smith 2020"    -0.16  -0.36  0.03  15.2}{p_end}
{phang2}{cmd:. "Jones 2021"    -0.33  -0.54 -0.12  18.4}{p_end}
{phang2}{cmd:. "Brown 2022"    -0.09  -0.25  0.06  22.1}{p_end}
{phang2}{cmd:. "Wilson 2023"   -0.39  -0.65 -0.12  12.8}{p_end}
{phang2}{cmd:. "Overall"       -0.24  -0.34 -0.13   .}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. gen byte type = cond(study=="Overall", 5, 1)}{p_end}
{phang2}{cmd:. eplot es lci uci, labels(study) weights(weight) type(type)}{p_end}

{pstd}
{bf:Example 2: Forest plot with exponentiated effects (odds ratios)}

{phang2}{cmd:. eplot es lci uci, labels(study) weights(weight) type(type) eform effect("Odds Ratio")}{p_end}

{pstd}
{bf:Example 3: Coefficient plot from regression}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. regress price mpg weight length foreign}{p_end}
{phang2}{cmd:. eplot ., drop(_cons) title("Price Determinants")}{p_end}

{pstd}
{bf:Example 4: With custom labels}

{phang2}{cmd:. eplot ., drop(_cons) coeflabels(mpg = "Miles per Gallon" weight = "Vehicle Weight" length = "Length" foreign = "Foreign Make")}{p_end}

{pstd}
{bf:Example 5: Using groups}

{phang2}{cmd:. regress price mpg weight length turn foreign rep78}{p_end}
{phang2}{cmd:. eplot ., drop(_cons) groups(mpg weight length turn = "Vehicle Characteristics" foreign rep78 = "Other Factors")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:eplot} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of effects plotted{p_end}

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
Help: {help twoway}, {help graph}
{p_end}
