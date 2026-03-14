{smcl}
{* *! version 1.1.0  14mar2026}{...}
{vieweralsosee "[R] kdensity" "help kdensity"}{...}
{vieweralsosee "[G-2] graph twoway rarea" "help twoway rarea"}{...}
{viewerjumpto "Syntax" "raincloud##syntax"}{...}
{viewerjumpto "Description" "raincloud##description"}{...}
{viewerjumpto "Options" "raincloud##options"}{...}
{viewerjumpto "Remarks" "raincloud##remarks"}{...}
{viewerjumpto "Examples" "raincloud##examples"}{...}
{viewerjumpto "Stored results" "raincloud##results"}{...}
{viewerjumpto "References" "raincloud##references"}{...}
{viewerjumpto "Author" "raincloud##author"}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:raincloud} {hline 2}}Raincloud plots: density, scatter, and box elements{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:raincloud}
{varname}
{ifin}
{weight}
[{cmd:,} {it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Elements}
{synopt:{opt noc:loud}}suppress half-violin density{p_end}
{synopt:{opt nora:in}}suppress jittered scatter points{p_end}
{synopt:{opt nobox}}suppress box plot{p_end}
{synopt:{opt noumb:rella}}synonym for {opt nobox}{p_end}

{syntab:Cloud}
{synopt:{opt band:width(#)}}kernel density bandwidth; 0 = Stata optimal{p_end}
{synopt:{opt k:ernel(string)}}kernel function; default {cmd:epanechnikov}{p_end}
{synopt:{opt n(#)}}number of density evaluation points; default {cmd:200}{p_end}
{synopt:{opt opacity(#)}}fill opacity 0-100; default {cmd:50}{p_end}
{synopt:{opt cloudw:idth(#)}}max width of density shape; default {cmd:0.4}{p_end}
{synopt:{opt cloudo:pts(string)}}pass-through options to {cmd:rarea}{p_end}

{syntab:Rain}
{synopt:{opt j:itter(#)}}jitter intensity 0-1; default {cmd:0.4}{p_end}
{synopt:{opt seed(#)}}random seed for reproducible jitter{p_end}
{synopt:{opt points:ize(string)}}marker size; default {cmd:vsmall}{p_end}
{synopt:{opt pointo:pts(string)}}pass-through options to {cmd:scatter}{p_end}

{syntab:Box}
{synopt:{opt boxw:idth(#)}}IQR box width; default {cmd:0.08}{p_end}
{synopt:{opt boxo:pts(string)}}pass-through options to box elements{p_end}
{synopt:{opt nomed:ian}}suppress median line inside box{p_end}
{synopt:{opt mean}}add mean dot marker{p_end}

{syntab:Layout}
{synopt:{opt hor:izontal}}horizontal orientation (default){p_end}
{synopt:{opt ver:tical}}vertical orientation{p_end}
{synopt:{opt over(varname)}}stratify by groups{p_end}
{synopt:{opt gap(#)}}spacing between groups; default {cmd:1.0}{p_end}
{synopt:{opt overl:ap}}scatter points overlap the box plot{p_end}
{synopt:{opt mir:ror}}split violin (cloud on both sides){p_end}
{synopt:{opt col:ors(string)}}custom color palette (space-separated){p_end}

{syntab:Graph}
{synopt:{opt sch:eme(string)}}graph scheme; default {cmd:plotplainblind}{p_end}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt sub:title(string)}}graph subtitle{p_end}
{synopt:{opt note(string)}}graph note{p_end}
{synopt:{opt name(string)}}graph name{p_end}
{synopt:{opt saving(string)}}save graph to file{p_end}
{synopt:{opt xt:itle(string)}}x-axis title{p_end}
{synopt:{opt yt:itle(string)}}y-axis title{p_end}
{synopt:{opt legend(string)}}legend options{p_end}
{synopt:{it:{help twoway_options}}}any additional options documented in {manhelp twoway_options G-3}{p_end}

{synoptline}
{p2colreset}{...}

{pstd}
{cmd:fweight}s and {cmd:aweight}s are allowed; see {help weight}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:raincloud} produces raincloud plots (Allen et al. 2019), which combine
three complementary views of a distribution into a single figure:

{phang2}
{bf:Cloud} — a half-violin (kernel density) showing the shape of the distribution

{phang2}
{bf:Rain} — jittered raw data points showing every observation

{phang2}
{bf:Box} — a box-and-whisker summary showing median, IQR, and whisker range

{pstd}
Any element can be toggled off. Groups are supported via {opt over()}, and the
plot can be oriented horizontally (default) or vertically.


{marker options}{...}
{title:Options}

{dlgtab:Elements}

{phang}
{opt nocloud} suppresses the half-violin kernel density shape. Useful when
only the scatter and box are desired.

{phang}
{opt norain} suppresses jittered data points. Useful for large datasets
where individual points would be overplotted.

{phang}
{opt nobox} suppresses the box-and-whisker element. {opt noumbrella} is a
synonym.

{dlgtab:Cloud}

{phang}
{opt bandwidth(#)} sets the kernel density bandwidth. The default value of 0
uses Stata's optimal bandwidth selector.

{phang}
{opt kernel(string)} specifies the kernel function. Default is
{cmd:epanechnikov}. Any kernel accepted by {helpb kdensity} is valid.

{phang}
{opt n(#)} specifies the number of points at which the density is evaluated.
Default is 200.

{phang}
{opt opacity(#)} sets the fill opacity of the cloud from 0 (transparent) to
100 (opaque). Default is 50.

{phang}
{opt cloudwidth(#)} controls the maximum width of the density shape in axis
units. Default is 0.4.

{phang}
{opt cloudopts(string)} passes options directly to the underlying {cmd:rarea}
command for the cloud.

{dlgtab:Rain}

{phang}
{opt jitter(#)} controls the amount of scatter-point jitter from 0 (no jitter)
to 1 (maximum). Default is 0.4.

{phang}
{opt seed(#)} sets the random number seed for reproducible jitter positioning.

{phang}
{opt pointsize(string)} controls the marker size. Default is {cmd:vsmall}.
Any Stata marker size is valid.

{phang}
{opt pointopts(string)} passes options directly to the underlying {cmd:scatter}
command for the rain points.

{dlgtab:Box}

{phang}
{opt boxwidth(#)} controls the width of the IQR box. Default is 0.08.

{phang}
{opt boxopts(string)} passes options directly to the box whisker line.

{phang}
{opt nomedian} suppresses the median line inside the box. By default, a line
is drawn at the median across the width of the IQR box.

{phang}
{opt mean} adds a filled circle at the group mean.

{dlgtab:Layout}

{phang}
{opt horizontal} produces a horizontal raincloud (default). The data variable
is on the x-axis and groups are on the y-axis.

{phang}
{opt vertical} produces a vertical raincloud. The data variable is on the
y-axis and groups are on the x-axis.

{phang}
{opt over(varname)} stratifies the plot by groups defined by {it:varname}.
Both numeric and string variables are accepted. Value labels are used when
available.

{phang}
{opt gap(#)} controls the spacing between groups. Default is 1.0.

{phang}
{opt overlap} positions the jittered scatter points on top of the box plot
rather than offset to the side. This produces a more compact plot at the cost
of some overplotting.

{phang}
{opt mirror} draws the cloud on both sides of center, producing a split
violin shape. When {opt mirror} is specified, the box is centered inside the
violin and rain points are automatically jittered around the center. The total
visual width of each cloud is {cmd:2 * cloudwidth()}.

{phang}
{opt colors(string)} specifies a custom color palette as a space-separated
list of Stata color names. Colors cycle if fewer colors are given than groups.
Default palette is {cmd:navy cranberry forest_green dkorange purple teal maroon olive_teal}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Edge cases}

{pstd}
Groups with a single observation or zero variance skip the cloud element and
show only the data point and box. Groups with fewer than 5 observations
produce a density estimate that may be unreliable.

{pstd}
When more groups are specified than colors in the palette, colors cycle back
to the beginning. The default palette has 8 colors.

{pstd}
{bf:Performance}

{pstd}
The kernel density is estimated separately for each group. For very large
datasets, consider {opt norain} to avoid rendering thousands of scatter
points, or reduce {opt n()} to speed density estimation.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic raincloud}

{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "raincloud mpg":. raincloud mpg}{p_end}

{pstd}
{bf:Example 2: By groups}

{phang2}{stata "raincloud mpg, over(foreign)":. raincloud mpg, over(foreign)}{p_end}

{pstd}
{bf:Example 3: Vertical orientation}

{phang2}{stata "raincloud price, over(foreign) vertical":. raincloud price, over(foreign) vertical}{p_end}

{pstd}
{bf:Example 4: Customized elements}

{phang2}{stata "raincloud mpg, over(foreign) opacity(70) jitter(0.6) mean":. raincloud mpg, over(foreign) opacity(70) jitter(0.6) mean}{p_end}

{pstd}
{bf:Example 5: Density only (no scatter or box)}

{phang2}{stata "raincloud mpg, over(foreign) norain nobox":. raincloud mpg, over(foreign) norain nobox}{p_end}

{pstd}
{bf:Example 6: Reproducible jitter}

{phang2}{stata "raincloud mpg, over(foreign) seed(12345)":. raincloud mpg, over(foreign) seed(12345)}{p_end}

{pstd}
{bf:Example 7: Split violin (mirror)}

{phang2}{stata "raincloud mpg, over(foreign) mirror mean":. raincloud mpg, over(foreign) mirror mean}{p_end}

{pstd}
{bf:Example 8: Custom colors}

{phang2}{stata `"raincloud mpg, over(foreign) colors(red blue)"':. raincloud mpg, over(foreign) colors(red blue)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:raincloud} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_groups)}}number of groups{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}variable plotted{p_end}
{synopt:{cmd:r(over)}}grouping variable (if specified){p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(stats)}}(n_groups x 8) matrix with n, mean, sd, median, q25, q75, iqr, bandwidth{p_end}


{marker references}{...}
{title:References}

{phang}
Allen M, Poggiali D, Whitaker K, Marshall TR, Kievit RA. 2019.
Raincloud plots: a multi-platform tool for robust data visualization.
{it:Wellcome Open Research} 4:63.
{browse "https://doi.org/10.12688/wellcomeopenres.15191.1"}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-03-14{p_end}


{title:Also see}

{psee}
Online:  {helpb kdensity}, {helpb twoway rarea}, {helpb graph box}

{hline}
