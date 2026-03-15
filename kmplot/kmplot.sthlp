{smcl}
{* *! version 1.1.0  15mar2026}{...}
{vieweralsosee "sts graph" "help sts graph"}{...}
{vieweralsosee "stci" "help stci"}{...}
{vieweralsosee "sts test" "help sts test"}{...}
{viewerjumpto "Syntax" "kmplot##syntax"}{...}
{viewerjumpto "Description" "kmplot##description"}{...}
{viewerjumpto "Options" "kmplot##options"}{...}
{viewerjumpto "Examples" "kmplot##examples"}{...}
{viewerjumpto "Stored results" "kmplot##results"}{...}
{viewerjumpto "Author" "kmplot##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:kmplot} {hline 2}}Publication-ready Kaplan-Meier and cumulative incidence plots{p_end}
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
{synopt:{opt fail:ure}}plot cumulative incidence (1-KM) instead of survival{p_end}

{syntab:Confidence intervals}
{synopt:{opt ci}}show 95% confidence intervals{p_end}
{synopt:{opt cist:yle(string)}}CI display: {bf:band} (default) or {bf:line}{p_end}
{synopt:{opt ciop:acity(#)}}band opacity 0-100; default {bf:12}{p_end}
{synopt:{opt citr:ansform(string)}}CI transform: {bf:loglog} (default), {bf:log}, or {bf:plain}{p_end}

{syntab:Median}
{synopt:{opt med:ian}}draw median survival reference lines{p_end}
{synopt:{opt mediana:nnotate}}annotate median values in plot note{p_end}

{syntab:Risk table}
{synopt:{opt risk:table}}add number-at-risk table below plot{p_end}
{synopt:{opt riskev:ents}}add cumulative events as {it:N (events)} in risk table{p_end}
{synopt:{opt riskcom:pact}}same as {opt riskevents}; compact {it:N (events)} format{p_end}
{synopt:{opt riskm:ono}}display risk table numbers in black (default: match line colors){p_end}
{synopt:{opt time:points(numlist)}}timepoints for risk table; default auto{p_end}

{syntab:Censoring}
{synopt:{opt cens:or}}show censoring marks{p_end}
{synopt:{opt censort:hin(#)}}show every Nth censor mark; default {bf:1}{p_end}

{syntab:P-value}
{synopt:{opt pval:ue}}display log-rank p-value on plot{p_end}
{synopt:{opt pvaluep:os(string)}}position: {bf:bottomright} (default), {bf:topright}, {bf:topleft}, {bf:bottomleft}{p_end}

{syntab:Appearance}
{synopt:{opt col:ors(colorlist)}}line colors; default colorblind-safe palette{p_end}
{synopt:{opt lw:idth(string)}}line width; default {bf:medthick}{p_end}
{synopt:{opt lp:attern(patternlist)}}line patterns; default all {bf:solid}{p_end}

{syntab:Labels}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt sub:title(string)}}graph subtitle{p_end}
{synopt:{opt xti:tle(string)}}x-axis title; default "Analysis time"{p_end}
{synopt:{opt yti:tle(string)}}y-axis title; auto from model{p_end}
{synopt:{opt xla:bel(string)}}x-axis labels{p_end}
{synopt:{opt yla:bel(string)}}y-axis labels; default 0(0.25)1{p_end}
{synopt:{opt le:gend(string)}}custom legend specification{p_end}
{synopt:{opt note(string)}}graph note{p_end}

{syntab:Output}
{synopt:{opt sch:eme(string)}}graph scheme; default {bf:plotplainblind}{p_end}
{synopt:{opt name(string)}}graph name; default {bf:kmplot}{p_end}
{synopt:{opt asp:ectratio(string)}}aspect ratio{p_end}
{synopt:{opt exp:ort(string)}}export graph to file (e.g., {it:file.pdf, replace}){p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Data must be {cmd:stset} before using {cmd:kmplot}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:kmplot} produces publication-quality Kaplan-Meier survival curves
or cumulative incidence plots with one command.  It replaces the tedious
customization workflow typically needed with {cmd:sts graph} by providing
sensible defaults for confidence bands, number-at-risk tables, median
survival lines, censoring marks, log-rank p-values, and colorblind-safe
styling.

{pstd}
All plots use step-function rendering with the {bf:plotplainblind} scheme
by default.  Colors, line widths, patterns, titles, and all graph elements
are fully customizable.


{marker options}{...}
{title:Options}

{dlgtab:Model}

{phang}{opt by(varname)} specifies a grouping variable for stratified KM
curves. Both numeric and string variables are supported. Value labels are
used automatically if defined.{p_end}

{phang}{opt failure} plots cumulative incidence (1 minus KM) instead of
the survival function. The y-axis title changes to "Cumulative incidence"
and the curve starts at 0 instead of 1.{p_end}

{dlgtab:Confidence intervals}

{phang}{opt ci} displays 95% confidence intervals around the KM curve.{p_end}

{phang}{opt cistyle(string)} sets the CI display style.
{bf:band} (default) shows shaded bands; {bf:line} shows dashed lines.{p_end}

{phang}{opt ciopacity(#)} sets shaded band opacity (0-100); default 12.
Only applies when {opt cistyle(band)}.{p_end}

{phang}{opt citransform(string)} sets the CI transformation.
{bf:loglog} (default) uses the log-log transform (Stata's default for KM).
{bf:log} uses the log transform. {bf:plain} uses untransformed (Wald) intervals.{p_end}

{dlgtab:Median}

{phang}{opt median} draws dashed reference lines at the median survival
time for each group (horizontal at y=0.5, vertical at x=median).
If the median is not reached, no line is drawn.{p_end}

{phang}{opt medianannotate} adds median values to the graph note.
Requires {opt median}.{p_end}

{dlgtab:Risk table}

{phang}{opt risktable} adds a number-at-risk table below the main plot.
The table shows the number of subjects still under observation at each
timepoint.{p_end}

{phang}{opt riskevents} adds cumulative event counts to the risk table
in compact {it:N (events)} format (e.g., {cmd:14 (3)}).  This is the
NEJM/Lancet convention.  Equivalent to {opt riskcompact}.{p_end}

{phang}{opt riskcompact} synonym for {opt riskevents}.{p_end}

{phang}{opt riskmono} displays all risk table numbers in black instead of
matching line colors. Default is colored numbers that match each group's
line color.{p_end}

{phang}{opt timepoints(numlist)} specifies the timepoints for the risk
table. Default: approximately 6 evenly spaced timepoints from 0 to the
maximum observed time.{p_end}

{dlgtab:Censoring}

{phang}{opt censor} displays tick marks at censoring times on the
KM curve.{p_end}

{phang}{opt censorthin(#)} shows every Nth censor mark to reduce clutter.
Default 1 (show all). Use {cmd:censorthin(5)} to show every 5th mark.{p_end}

{dlgtab:P-value}

{phang}{opt pvalue} computes and displays the log-rank test p-value on
the plot. Requires {opt by()}.{p_end}

{phang}{opt pvaluepos(string)} positions the p-value text:
{bf:bottomright} (default), {bf:topright}, {bf:topleft}, {bf:bottomleft}.{p_end}

{dlgtab:Output}

{phang}{opt export(string)} exports the graph to a file.  The format is
auto-detected from the extension (.pdf, .png, .eps, .svg).  Sub-options
(e.g., {it:replace}, {it:width(#)}) are passed to {cmd:graph export}.
Example: {cmd:export(figure1.pdf, replace)}.{p_end}


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

{pstd}Cumulative incidence with risk table{p_end}
{phang2}{cmd:. kmplot, by(drug) failure risktable}{p_end}

{pstd}Full publication example{p_end}
{phang2}{cmd:. kmplot, by(drug) ci risktable median medianannotate pvalue censor}{p_end}

{pstd}Custom styling{p_end}
{phang2}{cmd:. kmplot, by(drug) ci colors(navy red) lpattern(solid dash)}{p_end}

{pstd}Export to PDF{p_end}
{phang2}{cmd:. kmplot, by(drug) ci median export(km_figure.pdf, replace)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:kmplot} stores the following in {cmd:r()}:

{synoptset 16 tabbed}{...}
{p2col 5 16 20 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_groups)}}number of groups{p_end}
{synopt:{cmd:r(p)}}log-rank p-value (if {opt pvalue}){p_end}
{synopt:{cmd:r(median_1)}}median for group 1 (if {opt median} and reached){p_end}
{synopt:{cmd:r(median_2)}}median for group 2, etc.{p_end}

{p2col 5 16 20 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}{cmd:kmplot}{p_end}
{synopt:{cmd:r(scheme)}}graph scheme used{p_end}
{synopt:{cmd:r(by)}}by-variable name (if specified){p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
