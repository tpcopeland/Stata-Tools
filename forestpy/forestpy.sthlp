{smcl}
{* *! version 1.0.0  09jan2026}{...}
{viewerjumpto "Syntax" "forestpy##syntax"}{...}
{viewerjumpto "Description" "forestpy##description"}{...}
{viewerjumpto "Options" "forestpy##options"}{...}
{viewerjumpto "Examples" "forestpy##examples"}{...}
{viewerjumpto "Stored results" "forestpy##results"}{...}
{viewerjumpto "Requirements" "forestpy##requirements"}{...}
{viewerjumpto "Author" "forestpy##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:forestpy} {hline 2}}Publication-ready forest plots using Python forestplot{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:forestpy} {ifin}{cmd:,} {opth est:imate(varname)} {opth varl:abel(varname)} [{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth est:imate(varname)}}variable containing point estimates{p_end}
{synopt:{opth varl:abel(varname)}}variable containing row labels{p_end}

{syntab:Confidence intervals}
{synopt:{opth ll(varname)}}lower confidence limit variable{p_end}
{synopt:{opth hl(varname)}}upper confidence limit variable{p_end}

{syntab:Grouping and sorting}
{synopt:{opth groupv:ar(varname)}}variable for grouping rows{p_end}
{synopt:{opt groupo:rder(string)}}order of groups (space-separated){p_end}
{synopt:{opt sort}}sort rows by estimate value{p_end}
{synopt:{opth sortby(varname)}}variable to sort by{p_end}

{syntab:Display}
{synopt:{opt logs:cale}}use logarithmic scale for x-axis{p_end}
{synopt:{opt xla:bel(string)}}x-axis label{p_end}
{synopt:{opt yla:bel(string)}}y-axis label{p_end}
{synopt:{opt dec:imal(#)}}decimal precision; default is {cmd:2}{p_end}
{synopt:{opt figs:ize(# #)}}figure width and height{p_end}
{synopt:{opt color_alt_rows}}shade alternate rows{p_end}
{synopt:{opt table}}display as table format with lines{p_end}
{synopt:{opt flush}}left-flush labels; default{p_end}
{synopt:{opt cap:italize(string)}}text capitalization style{p_end}

{syntab:Annotations}
{synopt:{opth annote(varlist)}}variables for left-side annotations{p_end}
{synopt:{opt annotehead(string)}}headers for left annotations{p_end}
{synopt:{opth rightannote(varlist)}}variables for right-side annotations{p_end}
{synopt:{opt righthead(string)}}headers for right annotations{p_end}
{synopt:{opth pval(varname)}}p-value variable{p_end}
{synopt:{opt nostarpval}}do not add stars to significant p-values{p_end}

{syntab:Plot customization}
{synopt:{opt xticks(numlist)}}custom x-axis tick positions{p_end}
{synopt:{opt xline(#)}}reference line position; default is {cmd:0}{p_end}
{synopt:{opt marker(string)}}marker style; default is {cmd:s} (square){p_end}
{synopt:{opt markersize(#)}}marker size; default is {cmd:40}{p_end}
{synopt:{opt markercolor(string)}}marker color; default is {cmd:darkslategray}{p_end}
{synopt:{opt linecolor(string)}}CI line color; default is {cmd:.6}{p_end}
{synopt:{opt linewidth(#)}}CI line width; default is {cmd:1.4}{p_end}

{syntab:Multi-model}
{synopt:{opth modelcol(varname)}}variable identifying models{p_end}
{synopt:{opt modellabels(string)}}display labels for models{p_end}

{syntab:Output}
{synopt:{opt sav:ing(filename)}}save plot to file (PNG, PDF, SVG, EPS){p_end}
{synopt:{opt replace}}replace existing file{p_end}

{syntab:Advanced}
{synopt:{opt nopreprocess}}skip data preprocessing{p_end}
{synopt:{opt debug}}show debug information{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:forestpy} creates publication-ready forest plots using the Python
{browse "https://github.com/lsys/forestplot":forestplot} package. Forest plots
are commonly used in meta-analyses, epidemiological studies, and to display
regression coefficients with confidence intervals.

{pstd}
This command provides a Stata interface to the Python forestplot library,
automatically handling data transfer between Stata and Python, and managing
Python dependencies.

{pstd}
Forest plots display:

{phang2}- Point estimates as markers{p_end}
{phang2}- Confidence intervals as horizontal lines (whiskers){p_end}
{phang2}- Optional reference line (typically at 0 or 1){p_end}
{phang2}- Row labels and optional annotations{p_end}
{phang2}- Optional grouping of variables{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth estimate(varname)} specifies the variable containing point estimates.
These may be correlation coefficients, regression coefficients, odds ratios,
hazard ratios, or any other effect size measure.

{phang}
{opth varlabel(varname)} specifies the string variable containing labels for
each row of the forest plot.

{dlgtab:Confidence intervals}

{phang}
{opth ll(varname)} specifies the variable containing lower confidence limits.
Must be specified together with {opt hl()}.

{phang}
{opth hl(varname)} specifies the variable containing upper confidence limits.
Must be specified together with {opt ll()}.

{dlgtab:Grouping and sorting}

{phang}
{opth groupvar(varname)} specifies a variable for grouping rows. Groups are
displayed with headers and can be useful for organizing variables by category.

{phang}
{opt grouporder(string)} specifies the order of groups as a space-separated
list. Groups not listed will appear after those specified.

{phang}
{opt sort} requests that rows be sorted by estimate value.

{phang}
{opth sortby(varname)} specifies an alternative variable to sort by when
{opt sort} is specified.

{dlgtab:Display}

{phang}
{opt logscale} displays the x-axis on a logarithmic scale. This is appropriate
for odds ratios, hazard ratios, and risk ratios. The default reference line
changes from 0 to 1.

{phang}
{opt xlabel(string)} specifies a label for the x-axis.

{phang}
{opt ylabel(string)} specifies a label for the y-axis.

{phang}
{opt decimal(#)} specifies the number of decimal places for numeric
formatting. The default is 2.

{phang}
{opt figsize(# #)} specifies the figure dimensions as width and height.
The default is {cmd:figsize(4 8)}.

{phang}
{opt color_alt_rows} shades alternate rows in gray for improved readability.

{phang}
{opt table} displays the plot in table format with horizontal lines.

{phang}
{opt flush} left-flushes variable labels. This is the default.

{phang}
{opt capitalize(string)} specifies text capitalization for labels:
{cmd:capitalize}, {cmd:title}, {cmd:lower}, {cmd:upper}, or {cmd:swapcase}.

{dlgtab:Annotations}

{phang}
{opth annote(varlist)} specifies variables to display as annotations on the
left side of the plot.

{phang}
{opt annotehead(string)} specifies headers for left-side annotations as a
space-separated list.

{phang}
{opth rightannote(varlist)} specifies variables to display as annotations on
the right side of the plot.

{phang}
{opt righthead(string)} specifies headers for right-side annotations.

{phang}
{opth pval(varname)} specifies a variable containing p-values. P-values are
displayed on the right side with significance stars by default.

{phang}
{opt nostarpval} suppresses significance stars on p-values.

{dlgtab:Plot customization}

{phang}
{opt xticks(numlist)} specifies custom x-axis tick positions.

{phang}
{opt xline(#)} specifies the position of the reference line. The default is
0 for linear scale and 1 for log scale.

{phang}
{opt marker(string)} specifies the marker style. Common values include
{cmd:s} (square), {cmd:o} (circle), {cmd:D} (diamond). Default is {cmd:s}.

{phang}
{opt markersize(#)} specifies the marker size. Default is 40.

{phang}
{opt markercolor(string)} specifies the marker color. Default is
{cmd:darkslategray}.

{phang}
{opt linecolor(string)} specifies the confidence interval line color.
Default is {cmd:.6} (gray).

{phang}
{opt linewidth(#)} specifies the confidence interval line width.
Default is 1.4.

{dlgtab:Multi-model}

{phang}
{opth modelcol(varname)} specifies a variable identifying different models.
When specified, {cmd:forestpy} creates a multi-model coefficient plot showing
the same variables across multiple models.

{phang}
{opt modellabels(string)} specifies display labels for models as a
space-separated list.

{dlgtab:Output}

{phang}
{opt saving(filename)} saves the plot to the specified file. Supported formats
include PNG (default), PDF, SVG, EPS, and TIFF. If no extension is provided,
{cmd:.png} is appended.

{phang}
{opt replace} permits overwriting an existing file.


{marker examples}{...}
{title:Examples}

{pstd}Setup - create example data{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str20 label estimate ll hl str10 group}{p_end}
{phang2}{cmd:. "Age" 0.15 0.08 0.22 "Demographics"}{p_end}
{phang2}{cmd:. "Sex (Male)" -0.05 -0.12 0.02 "Demographics"}{p_end}
{phang2}{cmd:. "BMI" 0.28 0.21 0.35 "Clinical"}{p_end}
{phang2}{cmd:. "Smoking" 0.42 0.33 0.51 "Clinical"}{p_end}
{phang2}{cmd:. "Diabetes" 0.35 0.25 0.45 "Clinical"}{p_end}
{phang2}{cmd:. "Education" -0.18 -0.26 -0.10 "Socioeconomic"}{p_end}
{phang2}{cmd:. "Income" -0.12 -0.20 -0.04 "Socioeconomic"}{p_end}
{phang2}{cmd:. end}{p_end}

{pstd}Basic forest plot{p_end}
{phang2}{cmd:. forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl)}{p_end}

{pstd}Forest plot with groups{p_end}
{phang2}{cmd:. forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) groupvar(group)}{p_end}

{pstd}Forest plot with custom appearance{p_end}
{phang2}{cmd:. forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///}{p_end}
{phang3}{cmd:xlabel("Correlation coefficient") ///}{p_end}
{phang3}{cmd:markercolor(navy) color_alt_rows saving(forest.png, replace)}{p_end}

{pstd}Forest plot with log scale (for odds ratios){p_end}
{phang2}{cmd:. forestpy, estimate(or) varlabel(label) ll(or_ll) hl(or_hl) ///}{p_end}
{phang3}{cmd:logscale xlabel("Odds Ratio")}{p_end}

{pstd}Forest plot with annotations{p_end}
{phang2}{cmd:. forestpy, estimate(estimate) varlabel(label) ll(ll) hl(hl) ///}{p_end}
{phang3}{cmd:annote(n) annotehead(N) pval(pvalue)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:forestpy} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations plotted{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(estimate)}}estimate variable name{p_end}
{synopt:{cmd:r(varlabel)}}label variable name{p_end}
{synopt:{cmd:r(ll)}}lower limit variable name (if specified){p_end}
{synopt:{cmd:r(hl)}}upper limit variable name (if specified){p_end}
{synopt:{cmd:r(filename)}}output filename (if saved){p_end}


{marker requirements}{...}
{title:Requirements}

{pstd}
{cmd:forestpy} requires:

{phang2}- Stata 16.0 or later with Python integration{p_end}
{phang2}- Python 3.6 or later{p_end}
{phang2}- Python packages: pandas, numpy, matplotlib, forestplot{p_end}

{pstd}
Python dependencies are automatically checked and installed on first use.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}

{pstd}
Python forestplot package by Lucas Shen:{break}
{browse "https://github.com/lsys/forestplot"}


{title:Also see}

{psee}
Manual: {manlink R graph twoway}

{psee}
{space 2}Help: {manhelp graph_twoway G-2:graph twoway}, {helpb eplot} (if installed)
{p_end}
