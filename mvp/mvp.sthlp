{smcl}
{* *! version 1.1.1  2025/12/16}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[D] misstable" "help misstable"}{...}
{vieweralsosee "[MI] mi misstable" "help mi_misstable"}{...}
{viewerjumpto "Syntax" "mvp##syntax"}{...}
{viewerjumpto "Description" "mvp##description"}{...}
{viewerjumpto "Options" "mvp##options"}{...}
{viewerjumpto "Examples" "mvp##examples"}{...}
{viewerjumpto "Stored results" "mvp##results"}{...}
{viewerjumpto "Authors" "mvp##authors"}{...}
{hline}
help for {cmd:mvp}{right:version 1.1.0}
{hline}

{title:Title}

{p2colset 5 12 14 2}{...}
{p2col:{cmd:mvp} {hline 2}}Missing value pattern analysis with enhanced features{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:mvp}
[{varlist}]
{ifin}
[{cmd:,} {it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Display}
{synopt:{opt not:able}}suppress variable summary table{p_end}
{synopt:{opt sk:ip}}insert spaces every 5 variables for readability{p_end}
{synopt:{opt so:rt}}sort variables by descending missingness{p_end}
{synopt:{opt nod:rop}}include variables with no missing values{p_end}
{synopt:{opt wide}}compact display for many variables{p_end}
{synopt:{opt nosu:mmary}}suppress summary statistics{p_end}

{syntab:Pattern filtering}
{synopt:{opt m:infreq(#)}}minimum frequency for pattern display; default is 1{p_end}
{synopt:{opt minm:issing(#)}}show only patterns with at least # missing vars{p_end}
{synopt:{opt maxm:issing(#)}}show only patterns with at most # missing vars{p_end}
{synopt:{opt a:scending}}sort patterns by ascending frequency (rarest first){p_end}

{syntab:Statistics}
{synopt:{opt p:ercent}}display percentages{p_end}
{synopt:{opt cu:mulative}}display cumulative frequencies/percentages{p_end}
{synopt:{opt cor:relate}}display tetrachoric correlations of missingness{p_end}
{synopt:{opt mo:notone}}test for monotone missingness pattern{p_end}

{syntab:Output}
{synopt:{opt g:enerate(stub)}}generate missingness indicator variables{p_end}
{synopt:{opt save(name)}}save pattern data to file or frame{p_end}

{syntab:Graphics}
{synopt:{opt gr:aph(type)}}produce missingness graph; {it:type} may be {cmd:bar}, {cmd:patterns}, {cmd:matrix}, or {cmd:correlation}{p_end}
{synopt:{opt sch:eme(schemename)}}graph scheme{p_end}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt subti:tle(string)}}graph subtitle{p_end}
{synopt:{opt gn:ame(name)}}name the graph in memory{p_end}
{synopt:{opt gsav:ing(filename)}}save graph to file{p_end}
{synopt:{opt nodr:aw}}suppress graph display{p_end}

{syntab:Bar/Patterns graph options}
{synopt:{opt barc:olor(colorstyle)}}bar fill color; default is {cmd:navy}{p_end}
{synopt:{opt hor:izontal}}horizontal bars (default){p_end}
{synopt:{opt ver:tical}}vertical bars{p_end}
{synopt:{opt top(#)}}number of top patterns to show; default is 20{p_end}

{syntab:Matrix heatmap options}
{synopt:{opt missc:olor(colorstyle)}}color for missing values; default is {cmd:cranberry}{p_end}
{synopt:{opt obsc:olor(colorstyle)}}color for observed values; default is {cmd:navy*0.2}{p_end}

{syntab:Correlation heatmap options}
{synopt:{opt textl:abels}}display correlation values in cells{p_end}
{synopt:{opt colorr:amp(type)}}color scheme: {cmd:bluered} (default), {cmd:redblue}, or {cmd:grayscale}{p_end}

{syntab:Stratification options}
{synopt:{opt gby(varname)}}stratify graphs by categorical variable (faceted display){p_end}
{synopt:{opt over(varname)}}overlay comparison by categorical variable (grouped bars){p_end}
{synopt:{opt st:acked}}show stacked bar chart; requires graph(bar){p_end}
{synopt:{opt groupg:ap(#)}}gap between bar groups; default is 0{p_end}
{synopt:{opt legendo:pts(string)}}pass-through legend options{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}
{cmd:by} is allowed; see {help prefix}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:mvp} analyzes and displays missing value patterns in the data. For each
unique combination of missing and nonmissing values across the specified
variables, it shows the pattern, frequency, and number of missing variables.

{pstd}
In the pattern display, {cmd:+} denotes a nonmissing value and {cmd:.} denotes
a missing value. For string variables, empty strings are treated as missing.
Patterns are sorted by frequency (most common first) by default.

{pstd}
This command is a fork of {cmd:mvpatterns} by Jeroen Weesie (STB-61: dm91)
with additional features for deeper missingness analysis.


{marker options}{...}
{title:Options}

{dlgtab:Display}

{phang}
{opt notable} suppresses the variable summary table that shows observation
counts, missing counts, and percentages for each variable.

{phang}
{opt skip} inserts a space in the pattern string after every 5 variables, and
separator lines in the variable table, to enhance readability with many variables.

{phang}
{opt sort} sorts the variables in the display and pattern by descending
missingness (most missing first).

{phang}
{opt nodrop} includes variables that have no missing values in the analysis.
By default, such variables are excluded and listed separately.

{phang}
{opt wide} uses a compact display format suitable for analyses with many
variables.

{phang}
{opt nosummary} suppresses the summary statistics shown at the bottom of
the output.

{dlgtab:Pattern filtering}

{phang}
{opt minfreq(#)} specifies the minimum frequency for a pattern to be displayed.
Patterns with fewer observations are summarized at the end. Default is 1
(show all patterns).

{phang}
{opt minmissing(#)} displays only patterns with at least {it:#} missing
variables.

{phang}
{opt maxmissing(#)} displays only patterns with at most {it:#} missing
variables.

{phang}
{opt ascending} sorts patterns by ascending frequency (rarest patterns first)
instead of the default descending order.

{dlgtab:Statistics}

{phang}
{opt percent} adds a column showing the percentage of observations for
each pattern.

{phang}
{opt cumulative} adds a column showing cumulative frequencies or percentages.

{phang}
{opt correlate} displays tetrachoric correlations (or Pearson correlations
if {cmd:tetrachoric} is unavailable) among the missingness indicators. This
helps identify variables whose missingness tends to co-occur.

{phang}
{opt monotone} tests whether the missing data pattern is monotone. A pattern
is monotone if, for each observation, once a variable is missing, all
subsequent variables (in the specified or sorted order) are also missing.
Monotone patterns are important for multiple imputation methods.

{dlgtab:Output}

{phang}
{opt generate(stub)} creates missingness indicator variables with the
specified stub. For each variable {it:var}, creates {it:stub}_{it:var}
(1 if missing, 0 otherwise), plus {it:stub}_pattern (the pattern string)
and {it:stub}_nmiss (count of missing values per observation).

{phang}
{opt save(name)} saves the pattern data. If {it:name} contains a period,
slash, or backslash, it is treated as a filename and the data is saved
as a Stata dataset. Otherwise, it is treated as a frame name.

{dlgtab:Graphics}

{phang}
{opt graph(type)} produces a graph of the missingness structure. The following
types are available:

{phang2}
{opt graph(bar)} produces a horizontal bar chart showing the percent missing
for each variable, sorted by the variable order (or by missingness if {opt sort}
is specified). Use {opt vertical} for vertical bars.

{phang2}
{opt graph(patterns)} produces a horizontal bar chart of the most common missing
value patterns, showing their frequencies. By default shows the top 20 patterns;
use {opt top(#)} to adjust.

{phang2}
{opt graph(matrix)} produces an observation-by-variable heatmap showing
missingness across the dataset. Missing values appear in red (customizable with
{opt misscolor()}), observed values in blue (customizable with {opt obscolor()}).
For large datasets (>500 observations), a random sample is drawn by default.
Suboptions:

{phang3}
{opt graph(matrix, sample(#))} specifies the number of observations to sample.

{phang3}
{opt graph(matrix, sort)} sorts observations by their missingness pattern
before display, revealing structure in the missing data.

{phang2}
{opt graph(correlation)} produces a heatmap of the correlation matrix among
missingness indicators. Use {opt textlabels} to display correlation values in
each cell. Use {opt colorramp()} to change the color scheme.

{phang}
{opt scheme(schemename)} specifies the graph scheme to use.

{phang}
{opt title(string)} specifies a custom title for the graph. If not specified,
a default title is used based on the graph type.

{phang}
{opt subtitle(string)} specifies a custom subtitle for the graph.

{phang}
{opt gname(name)} names the graph in memory, allowing you to save or manipulate
it later. The name replaces any existing graph with the same name.

{phang}
{opt gsaving(filename)} saves the graph to the specified file. Supports standard
Stata graph saving options like {cmd:gsaving(mygraph.gph, replace)}.

{phang}
{opt nodraw} suppresses the display of the graph. Useful when you only want to
save the graph to a file.

{dlgtab:Bar/Patterns graph options}

{phang}
{opt barcolor(colorstyle)} specifies the fill color for bars in {opt graph(bar)}
and {opt graph(patterns)}. Default is {cmd:navy}. Accepts any valid Stata color.

{phang}
{opt horizontal} displays bars horizontally (default for bar charts).

{phang}
{opt vertical} displays bars vertically.

{phang}
{opt top(#)} specifies how many of the most common patterns to display in
{opt graph(patterns)}. Default is 20. Minimum is 1.

{dlgtab:Matrix heatmap options}

{phang}
{opt misscolor(colorstyle)} specifies the color for missing values in
{opt graph(matrix)}. Default is {cmd:cranberry}. Accepts any valid Stata color.

{phang}
{opt obscolor(colorstyle)} specifies the color for observed (non-missing) values
in {opt graph(matrix)}. Default is {cmd:navy*0.2}. Accepts any valid Stata color.

{dlgtab:Correlation heatmap options}

{phang}
{opt textlabels} displays the correlation coefficient value in each cell of
{opt graph(correlation)}. Text size adjusts automatically based on the number
of variables.

{phang}
{opt colorramp(type)} specifies the color scheme for {opt graph(correlation)}:

{phang2}
{opt colorramp(bluered)} uses blue for positive correlations and red for negative
correlations (default).

{phang2}
{opt colorramp(redblue)} uses red for positive correlations and blue for negative
correlations.

{phang2}
{opt colorramp(grayscale)} uses a grayscale gradient where darker shades indicate
stronger correlations regardless of sign.

{dlgtab:Stratification options}

{phang}
{opt gby(varname)} stratifies graphs by a categorical variable, producing separate
faceted panels for each level of the variable. This allows direct comparison of
missingness patterns across groups (e.g., treatment vs control, male vs female).
Works with {opt graph(bar)} and {opt graph(patterns)}.

{phang}
{opt over(varname)} overlays bars for each level of the categorical variable
within the same graph, showing grouped bars side-by-side for direct comparison.
Only works with {opt graph(bar)}. Uses value labels if available.

{phang}
{opt stacked} displays a stacked bar chart where each variable's missingness
contribution is shown as a segment. Only works with {opt graph(bar)}.

{phang}
{opt groupgap(#)} specifies the gap between bar groups when using {opt over()}.
Default is 0. Larger values increase spacing between groups.

{phang}
{opt legendopts(string)} allows customization of the legend when using {opt over()}.
The string is passed directly to the legend option of the graph command.
Example: {cmd:legendopts(rows(2) position(3))}


{marker examples}{...}
{title:Examples}

{pstd}Basic usage{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mvp}{p_end}

{pstd}Analyze specific variables with percentages{p_end}
{phang2}{cmd:. mvp price mpg rep78 headroom, percent}{p_end}

{pstd}Sort variables by missingness, show rare patterns first{p_end}
{phang2}{cmd:. mvp, sort ascending}{p_end}

{pstd}Show only patterns appearing at least 5 times with cumulative stats{p_end}
{phang2}{cmd:. mvp, minfreq(5) percent cumulative}{p_end}

{pstd}Filter to patterns with 1-3 missing variables{p_end}
{phang2}{cmd:. mvp, minmissing(1) maxmissing(3)}{p_end}

{pstd}Test for monotone missingness{p_end}
{phang2}{cmd:. mvp var1 var2 var3 var4, monotone}{p_end}

{pstd}Show correlations among missingness indicators{p_end}
{phang2}{cmd:. mvp income education occupation, correlate}{p_end}

{pstd}Generate missingness indicators for further analysis{p_end}
{phang2}{cmd:. mvp, generate(m)}{p_end}
{phang2}{cmd:. tab m_pattern}{p_end}

{pstd}Save patterns to a frame for later use{p_end}
{phang2}{cmd:. mvp, save(patterns)}{p_end}
{phang2}{cmd:. frame patterns: list}{p_end}

{pstd}Save patterns to a file{p_end}
{phang2}{cmd:. mvp, save(mypatterns.dta)}{p_end}

{pstd}Use with by prefix{p_end}
{phang2}{cmd:. bysort foreign: mvp price mpg rep78}{p_end}

{pstd}{bf:Graphics examples}{p_end}

{pstd}Bar chart of missingness by variable{p_end}
{phang2}{cmd:. mvp, graph(bar)}{p_end}

{pstd}Bar chart with variables sorted by missingness{p_end}
{phang2}{cmd:. mvp, sort graph(bar)}{p_end}

{pstd}Vertical bar chart with custom color{p_end}
{phang2}{cmd:. mvp, graph(bar) vertical barcolor(maroon)}{p_end}

{pstd}Pattern frequency bar chart{p_end}
{phang2}{cmd:. mvp, graph(patterns)}{p_end}

{pstd}Show top 10 patterns with custom title{p_end}
{phang2}{cmd:. mvp, graph(patterns) top(10) title("Missing Data Patterns")}{p_end}

{pstd}Missingness matrix heatmap{p_end}
{phang2}{cmd:. mvp, graph(matrix)}{p_end}

{pstd}Matrix with 1000 sampled observations, sorted by pattern{p_end}
{phang2}{cmd:. mvp, graph(matrix, sample(1000) sort)}{p_end}

{pstd}Matrix with custom colors{p_end}
{phang2}{cmd:. mvp, graph(matrix) misscolor(red) obscolor(green*0.2)}{p_end}

{pstd}Correlation heatmap of missingness{p_end}
{phang2}{cmd:. mvp, graph(correlation)}{p_end}

{pstd}Correlation heatmap with values displayed{p_end}
{phang2}{cmd:. mvp, graph(correlation) textlabels}{p_end}

{pstd}Correlation heatmap with grayscale color scheme{p_end}
{phang2}{cmd:. mvp, graph(correlation) colorramp(grayscale)}{p_end}

{pstd}Save graph to file without displaying{p_end}
{phang2}{cmd:. mvp, graph(bar) gsaving(missingness.gph, replace) nodraw}{p_end}

{pstd}Name graph in memory for later use{p_end}
{phang2}{cmd:. mvp, graph(correlation) gname(mycorr)}{p_end}

{pstd}Use a specific graph scheme{p_end}
{phang2}{cmd:. mvp, graph(bar) scheme(s1mono)}{p_end}

{pstd}{bf:Stratified graphics examples}{p_end}

{pstd}Compare missingness by group (faceted display){p_end}
{phang2}{cmd:. mvp price mpg rep78, graph(bar) gby(foreign)}{p_end}

{pstd}Overlay groups in same chart (grouped bars){p_end}
{phang2}{cmd:. mvp price mpg rep78, graph(bar) over(foreign)}{p_end}

{pstd}Compare patterns by treatment group{p_end}
{phang2}{cmd:. mvp outcome1-outcome5, graph(patterns) gby(treatment) top(10)}{p_end}

{pstd}Stacked bar chart showing variable contributions{p_end}
{phang2}{cmd:. mvp, graph(bar) stacked}{p_end}

{pstd}Grouped bars with custom legend and spacing{p_end}
{phang2}{cmd:. mvp price mpg rep78, graph(bar) over(foreign) groupgap(20) legendopts(rows(1) position(6))}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mvp} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(N_complete)}}number of complete cases (no missing){p_end}
{synopt:{cmd:r(N_incomplete)}}number of incomplete cases{p_end}
{synopt:{cmd:r(N_patterns)}}number of unique patterns displayed{p_end}
{synopt:{cmd:r(N_vars)}}number of variables analyzed{p_end}
{synopt:{cmd:r(max_miss)}}maximum missing values in any observation{p_end}
{synopt:{cmd:r(mean_miss)}}mean missing values per observation{p_end}
{synopt:{cmd:r(N_mv_total)}}total number of missing values{p_end}

{pstd}If {opt monotone} is specified:{p_end}
{synopt:{cmd:r(N_monotone)}}observations with monotone pattern{p_end}
{synopt:{cmd:r(pct_monotone)}}percent with monotone pattern{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}variables with missing values analyzed{p_end}
{synopt:{cmd:r(varlist_nomiss)}}variables with no missing values{p_end}
{synopt:{cmd:r(monotone_status)}}{cmd:monotone} or {cmd:non-monotone} if tested{p_end}

{pstd}If {opt gby()} is specified:{p_end}
{synopt:{cmd:r(gby)}}name of the gby variable{p_end}
{synopt:{cmd:r(gby_levels)}}levels of the gby variable{p_end}

{pstd}If {opt over()} is specified:{p_end}
{synopt:{cmd:r(over)}}name of the over variable{p_end}
{synopt:{cmd:r(over_levels)}}levels of the over variable{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(corr_miss)}}correlation matrix of missingness (if {opt correlate} or {opt graph(correlation)} specified){p_end}


{marker authors}{...}
{title:Authors}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}
This is a fork of {cmd:mvpatterns} version 2.0.0 (STB-61: dm91) by:

{pstd}
Jeroen Weesie{break}
Dept of Sociology{break}
Utrecht University


{marker technotes}{...}
{title:Technical notes}

{pstd}
{bf:Variable limit:} The maximum number of variables that can be analyzed is
244, due to Stata's string length limitations for pattern representation.
If you need to analyze more than 244 variables, consider splitting your
analysis into multiple runs.

{pstd}
{bf:Memory considerations:} The {opt graph(matrix)} option automatically samples
500 observations for large datasets to avoid memory issues. Use the
{cmd:sample(#)} suboption to adjust this limit.

{pstd}
{bf:Generated variable names:} When using {opt generate()}, variable names
are truncated to 31 characters to comply with Stata's naming limits.


{title:Also see}

{psee}
Manual:  {manlink D codebook}, {manlink D misstable}

{psee}
{space 2}Help:  {help codebook}, {help misstable}, {help mi_misstable:mi misstable}
{p_end}
