{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "[G-2] graph twoway line" "help line"}{...}
{vieweralsosee "[R] lowess" "help lowess"}{...}
{viewerjumpto "Syntax" "spaghetti##syntax"}{...}
{viewerjumpto "Description" "spaghetti##description"}{...}
{viewerjumpto "Options" "spaghetti##options"}{...}
{viewerjumpto "Remarks" "spaghetti##remarks"}{...}
{viewerjumpto "Examples" "spaghetti##examples"}{...}
{viewerjumpto "Stored results" "spaghetti##results"}{...}
{viewerjumpto "Author" "spaghetti##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:spaghetti} {hline 2}}Longitudinal trajectory visualization with group mean overlays{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:spaghetti}
{varname}
{ifin}
{cmd:,}
{opt id(varname)}
{opt time(varname)}
[{it:options}]


{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}individual identifier variable{p_end}
{synopt:{opt time(varname)}}time variable (numeric){p_end}

{syntab:Grouping}
{synopt:{opt by(varname)}}group variable for separate trajectories (max 8 levels){p_end}
{synopt:{opt colorby(varname [, categorical])}}color trajectories by a variable{p_end}

{syntab:Mean overlay}
{synopt:{opt mean(options)}}add group mean overlay; sub-options: {cmd:bold}, {cmd:ci}, {cmd:smooth(lowess|linear)}{p_end}

{syntab:Subsetting}
{synopt:{opt samp:le(#)}}randomly sample {it:#} individuals{p_end}
{synopt:{opt seed(#)}}random seed for reproducible sampling{p_end}
{synopt:{opt high:light(conditions [bgopacity(#)])}}emphasize specific individuals{p_end}

{syntab:Annotations}
{synopt:{opt ref:line(# [, subopts])}}vertical reference line at time {it:#}; sub-options: {cmd:label("text")}, {cmd:style(pattern)}{p_end}

{syntab:Styling}
{synopt:{opt col:ors(colorlist)}}override default color palette{p_end}
{synopt:{opt ind:ividual(options)}}individual line style; sub-options: {cmd:color()}, {cmd:opacity()}, {cmd:lwidth()}{p_end}
{synopt:{opt scheme(schemename)}}graph scheme (default: {cmd:plotplainblind}){p_end}

{syntab:Graph options}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt sub:title(string)}}graph subtitle{p_end}
{synopt:{opt note(string)}}graph note{p_end}
{synopt:{opt yti:tle(string)}}y-axis title{p_end}
{synopt:{opt xti:tle(string)}}x-axis title{p_end}
{synopt:{opt plotr:egion(options)}}plot region options{p_end}
{synopt:{opt graphr:egion(options)}}graph region options{p_end}
{synopt:{opt name(name)}}graph window name{p_end}
{synopt:{opt sav:ing(filename)}}save graph to file{p_end}

{syntab:Export}
{synopt:{opt exp:ort(filename [, replace])}}export graph (.png, .pdf, .svg, .eps){p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{it:varname} is the numeric outcome variable to plot on the y-axis.


{marker description}{...}
{title:Description}

{pstd}
{cmd:spaghetti} creates trajectory plots for longitudinal/panel data.
Each individual's observations are connected as a thin line, producing
the characteristic "spaghetti" pattern. Optional group mean overlays
with confidence bands provide visual anchors.

{pstd}
The command handles arbitrarily large panels efficiently by drawing all
trajectories within each group as a single plot element (using line breaks
at individual boundaries), rather than creating one plot element per
individual. This avoids Stata's ~300 plot element limit.

{pstd}
Data must be in long format with one row per individual-timepoint.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the variable identifying individuals.
Can be numeric or string.

{phang}
{opt time(varname)} specifies the numeric time variable for the x-axis.

{dlgtab:Grouping}

{phang}
{opt by(varname)} specifies a grouping variable. Trajectories are
colored by group, and separate mean overlays are computed per group.
Maximum 8 levels. Cannot be combined with {opt colorby()}.

{phang}
{opt colorby(varname [, categorical])} colors individual trajectories
by a variable. By default, the variable is treated as continuous and
split into quintiles. Specify {cmd:categorical} to use distinct levels
directly. Cannot be combined with {opt by()} or {opt highlight()}.

{dlgtab:Mean overlay}

{phang}
{opt mean(options)} adds a group mean overlay. Sub-options:

{phang2}
{cmd:bold} draws the mean line with thick line width.

{phang2}
{cmd:ci} adds a 95% confidence band around the mean.

{phang2}
{cmd:smooth(lowess|linear)} smooths the mean trajectory.
{cmd:lowess} applies local polynomial smoothing;
{cmd:linear} fits a linear regression.
When combined with {cmd:ci}, the confidence band reflects the
raw (unsmoothed) means; the smoothed line may extend beyond the band.

{dlgtab:Subsetting}

{phang}
{opt sample(#)} randomly selects {it:#} individuals to display.
Useful for decluttering large panels. Use with {opt seed()} for
reproducibility.

{phang}
{opt seed(#)} sets the random number seed for {opt sample()}.

{phang}
{opt highlight(conditions [bgopacity(#)])} emphasizes specific individuals
with bold colored lines while fading all others to the background.
Non-highlighted individuals use the {opt individual()} styling settings.
Conditions can be standard Stata expressions:

{phang3}{cmd:highlight(patid==142 | patid==307)}{p_end}
{phang3}{cmd:highlight(baseline_score < 30)}{p_end}

{pstd}
For multiple conditions, use {cmd:|} (OR) or {cmd:&} (AND):

{phang3}{cmd:highlight(patid==142 | patid==307)}{p_end}

{pstd}
The {cmd:bgopacity(#)} sub-option controls the opacity of the
non-highlighted background trajectories (default: same as
{opt individual(opacity())}). Use lower values to fade the background
further, or higher values to keep it more visible:

{phang3}{cmd:highlight(patid==1 | patid==5 bgopacity(10))}{p_end}

{dlgtab:Annotations}

{phang}
{opt refline(# [, label("text") style(pattern)])} draws a vertical
reference line at time {it:#}. The {cmd:label()} sub-option places
text near the line. The {cmd:style()} sub-option sets the line
pattern (default: {cmd:dash}).

{dlgtab:Styling}

{phang}
{opt colors(colorlist)} overrides the default color palette.
Default: {cmd:navy cranberry forest_green dkorange purple teal maroon olive_teal}.

{phang}
{opt individual(options)} controls individual trajectory styling.
Sub-options: {cmd:color(colorname)}, {cmd:opacity(#)},
{cmd:lwidth(lwstyle)}. Defaults: {cmd:color(gs12)}, {cmd:opacity(25)},
{cmd:lwidth(vthin)}. These settings also control the background
appearance when {opt highlight()} is used.

{phang}
{opt scheme(schemename)} sets the graph scheme.
Default: {cmd:plotplainblind}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:How it works}

{pstd}
Rather than creating one {cmd:(line ...)} element per individual (which
hits Stata's plot element limit around 300-400), {cmd:spaghetti} uses
a line-break technique: all trajectories within a group are drawn as a
single {cmd:line} element, with missing values inserted between
individuals and {cmd:cmissing(n)} to break the line at boundaries.
This handles 10,000+ individuals with just 1-8 plot elements.

{pstd}
{bf:Performance}

{pstd}
For very large panels (N > 5,000 individuals), use {opt sample()} to
display a random subset. The mean overlay (if specified) is always
computed on the full sample before any random sampling is applied.

{pstd}
{bf:Note on mean computation}

{pstd}
The mean overlay is computed on the full sample (before any random
sampling via {opt sample()}) by collapsing data to time-specific
means (within by-groups if specified). Standard errors are computed
as SD/sqrt(N). Confidence intervals use a normal approximation:
mean +/- invnormal(0.975) * SE.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic trajectories}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. spaghetti ln_wage, id(idcode) time(year)}{p_end}

{pstd}
{bf:Example 2: By group with mean overlay}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. spaghetti ln_wage, id(idcode) time(year) by(race) mean(bold ci)}{p_end}

{pstd}
{bf:Example 3: Random sample for decluttering}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. spaghetti ln_wage, id(idcode) time(year) sample(100) seed(12345) mean(bold)}{p_end}

{pstd}
{bf:Example 4: Highlight specific individuals}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. spaghetti ln_wage, id(idcode) time(year) highlight(idcode==1 | idcode==2)}{p_end}

{pstd}
{bf:Example 5: Reference line}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. spaghetti ln_wage, id(idcode) time(year) sample(50) refline(80, label("Policy change") style(dash))}{p_end}

{pstd}
{bf:Example 6: Custom styling}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. spaghetti ln_wage, id(idcode) time(year) by(race) individual(color(gs12) opacity(10) lwidth(vthin)) mean(bold ci) colors(navy cranberry)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:spaghetti} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_ids)}}number of unique individuals{p_end}
{synopt:{cmd:r(n_sampled)}}number of individuals after sampling{p_end}
{synopt:{cmd:r(n_groups)}}number of by-groups{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}graph command executed{p_end}
{synopt:{cmd:r(outcome)}}outcome variable{p_end}
{synopt:{cmd:r(id)}}individual identifier variable{p_end}
{synopt:{cmd:r(time)}}time variable{p_end}
{synopt:{cmd:r(by)}}by-group variable (if specified){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Manual:  {manlink G-2 graph twoway line}

{psee}
Online:  {helpb twoway line}, {helpb lowess}, {helpb xtline}

{hline}
