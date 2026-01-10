{smcl}
{* *! version 1.0.0  11jan2025}
{vieweralsosee "help scheme" "help scheme"}{...}
{vieweralsosee "help set scheme" "help set_scheme"}{...}
{vieweralsosee "help graph" "help graph"}{...}
{viewerjumpto "Syntax" "tc_schemes##syntax"}{...}
{viewerjumpto "Description" "tc_schemes##description"}{...}
{viewerjumpto "Options" "tc_schemes##options"}{...}
{viewerjumpto "Blindschemes" "tc_schemes##blindschemes"}{...}
{viewerjumpto "Schemepack" "tc_schemes##schemepack"}{...}
{viewerjumpto "Examples" "tc_schemes##examples"}{...}
{viewerjumpto "Stored results" "tc_schemes##results"}{...}
{viewerjumpto "Acknowledgments" "tc_schemes##acknowledgments"}{...}
{viewerjumpto "Author" "tc_schemes##author"}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:tc_schemes} {hline 2}}Consolidated Stata graph schemes from blindschemes and schemepack{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tc_schemes} [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt s:ource(string)}}filter schemes by source package; {it:all} (default), {it:blindschemes}, or {it:schemepack}{p_end}
{synopt:{opt l:ist}}display schemes as a simple list{p_end}
{synopt:{opt d:etail}}show detailed information with descriptions{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tc_schemes} is a consolidated package containing high-quality Stata graph schemes
from two excellent sources:

{p 8 12 2}
1. {bf:blindschemes} by Daniel Bischof - Clean, publication-ready schemes with
colorblind-friendly palettes, plus fixes from Mead Over's blindschemes_fix.

{p 8 12 2}
2. {bf:schemepack} by Asjad Naqvi - A comprehensive collection of 35+ schemes
organized by background style (white, black, ggplot2-style) and color palette.

{pstd}
This package solves the common issue where {cmd:capture which schemepack} fails
because schemepack contains only .scheme files without a .ado file, causing
unnecessary reinstallation checks. With {cmd:tc_schemes}, running
{cmd:which tc_schemes} will succeed, properly detecting the installed package.

{pstd}
Running {cmd:tc_schemes} without options displays an organized overview of all
available schemes. Use {opt detail} for complete descriptions.


{marker options}{...}
{title:Options}

{phang}
{opt source(string)} filters the displayed schemes by their original package.
Specify {it:blindschemes} to show only Bischof's schemes, {it:schemepack} for
Naqvi's schemes, or {it:all} (the default) for everything.

{phang}
{opt list} displays all scheme names as a simple list, suitable for programmatic
use or quick reference.

{phang}
{opt detail} shows comprehensive information about each scheme, including
descriptions, author information, and usage notes.


{marker blindschemes}{...}
{title:Blindschemes (Daniel Bischof)}

{pstd}
The blindschemes package provides four publication-quality schemes with excellent
colorblind accessibility. This consolidation includes fixes from Mead Over's
{it:blindschemes_fix} that resolve compatibility issues with recent Stata versions.

{p2colset 5 22 24 2}{...}
{p2col:{bf:Scheme}}{bf:Description}{p_end}
{p2line}
{p2col:{cmd:plotplain}}Minimalist scheme with white background, no grid lines,
and clean typography. Ideal for journal submissions requiring simple,
uncluttered figures.{p_end}

{p2col:{cmd:plotplainblind}}Same clean aesthetic as {cmd:plotplain} but with a
color palette specifically designed for readers with color vision deficiency.
Uses vermillion, sky, turquoise, and other distinguishable hues.{p_end}

{p2col:{cmd:plottig}}Inspired by R's ggplot2 default theme. Features a light
gray background with white gridlines, providing clear visual separation of
data from background while maintaining readability.{p_end}

{p2col:{cmd:plottigblind}}ggplot2-style with colorblind-friendly palette.
Combines the familiar ggplot2 aesthetic with accessible colors.{p_end}
{p2colreset}{...}

{pstd}
{bf:Custom Colors Included:}

{p 8 8 2}
{it:Primary colorblind-safe colors:} vermillion (RGB 213 94 0), sky (RGB 86 180 233),
turquoise (RGB 0 158 115), reddish (RGB 204 121 167), sea (RGB 0 114 178),
orangebrown (RGB 230 159 0), ananas (RGB 240 228 66)

{p 8 8 2}
{it:Additional tones:} plb1-plb3 (blues), plg1-plg3 (greens), plr1-plr2 (reds),
ply1-ply3 (yellows), pll1-pll3 (light tones)


{marker schemepack}{...}
{title:Schemepack (Asjad Naqvi)}

{pstd}
Schemepack provides a comprehensive collection of schemes organized in two ways:

{pstd}
{bf:Series Schemes} - Nine color palettes, each available with three backgrounds:

{p 8 12 2}
{it:white_*} - White background (clean, traditional){break}
{it:black_*} - Black background (dramatic, presentations){break}
{it:gg_*} - Gray background (ggplot2-style)

{p2colset 5 18 20 2}{...}
{p2col:{bf:Palette}}{bf:Schemes and Description}{p_end}
{p2line}
{p2col:{cmd:tableau}}{cmd:white_tableau}, {cmd:black_tableau}, {cmd:gg_tableau}{break}
Tableau Software's default palette. Excellent for categorical data.{p_end}

{p2col:{cmd:cividis}}{cmd:white_cividis}, {cmd:black_cividis}, {cmd:gg_cividis}{break}
Perceptually uniform, optimized for colorblind viewers. Based on viridis but
specifically tuned for deuteranopia and protanopia.{p_end}

{p2col:{cmd:viridis}}{cmd:white_viridis}, {cmd:black_viridis}, {cmd:gg_viridis}{break}
Matplotlib's perceptually uniform colormap. Excellent for continuous data,
prints well in grayscale.{p_end}

{p2col:{cmd:hue}}{cmd:white_hue}, {cmd:black_hue}, {cmd:gg_hue}{break}
ggplot2's default color scale based on hue spacing. Familiar to R users.{p_end}

{p2col:{cmd:brbg}}{cmd:white_brbg}, {cmd:black_brbg}, {cmd:gg_brbg}{break}
Brown-Blue-Green diverging palette. Ideal for data with meaningful midpoint.{p_end}

{p2col:{cmd:piyg}}{cmd:white_piyg}, {cmd:black_piyg}, {cmd:gg_piyg}{break}
Pink-Yellow-Green diverging palette. Strong visual contrast for diverging data.{p_end}

{p2col:{cmd:ptol}}{cmd:white_ptol}, {cmd:black_ptol}, {cmd:gg_ptol}{break}
Paul Tol's colorblind-safe palette. Scientifically designed for accessibility.{p_end}

{p2col:{cmd:jet}}{cmd:white_jet}, {cmd:black_jet}, {cmd:gg_jet}{break}
Classic rainbow/jet colormap. Note: Use cautiously as jet can be misleading
for continuous data; provided for legacy compatibility.{p_end}

{p2col:{cmd:w3d}}{cmd:white_w3d}, {cmd:black_w3d}, {cmd:gg_w3d}{break}
Web 3D inspired vibrant colors. High contrast for digital presentations.{p_end}
{p2colreset}{...}

{pstd}
{bf:Standalone Schemes} - Unique individual schemes:

{p2colset 5 18 20 2}{...}
{p2col:{bf:Scheme}}{bf:Description}{p_end}
{p2line}
{p2col:{cmd:tab1}}Qualitative color scheme #1. Good for categorical variables.{p_end}
{p2col:{cmd:tab2}}Qualitative color scheme #2. Alternative categorical palette.{p_end}
{p2col:{cmd:tab3}}Qualitative color scheme #3. Third categorical option.{p_end}
{p2col:{cmd:cblind1}}Colorblind-friendly scheme. Use when accessibility is critical.{p_end}
{p2col:{cmd:ukraine}}Ukraine flag colors (blue and yellow). Created March 2022.{p_end}
{p2col:{cmd:swift_red}}Taylor Swift "Red" album inspired palette. November 2021.{p_end}
{p2col:{cmd:neon}}High-contrast neon colors on dark background. Eye-catching presentations.{p_end}
{p2col:{cmd:rainbow}}Vibrant multicolor scheme. Bold, attention-grabbing visuals.{p_end}
{p2colreset}{...}


{marker examples}{...}
{title:Examples}

{pstd}List all available schemes:{p_end}
{phang2}{cmd:. tc_schemes}{p_end}

{pstd}Show detailed descriptions:{p_end}
{phang2}{cmd:. tc_schemes, detail}{p_end}

{pstd}List only blindschemes:{p_end}
{phang2}{cmd:. tc_schemes, source(blindschemes) list}{p_end}

{pstd}Use a scheme for all subsequent graphs:{p_end}
{phang2}{cmd:. set scheme plotplain}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. scatter mpg weight}{p_end}

{pstd}Use a scheme for a single graph:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. scatter mpg weight, scheme(white_tableau)}{p_end}

{pstd}Compare schemes visually:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. scatter mpg weight, scheme(plotplain) name(g1, replace)}{p_end}
{phang2}{cmd:. scatter mpg weight, scheme(gg_viridis) name(g2, replace)}{p_end}
{phang2}{cmd:. graph combine g1 g2}{p_end}

{pstd}Check if tc_schemes is installed (for do-file headers):{p_end}
{phang2}{cmd:. capture which tc_schemes}{p_end}
{phang2}{cmd:. if _rc != 0 net install tc_schemes, from("...")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tc_schemes} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(n_schemes)}}number of schemes in selected source{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(schemes)}}space-separated list of all scheme names{p_end}
{synopt:{cmd:r(sources)}}source packages included: "blindschemes schemepack"{p_end}
{synopt:{cmd:r(version)}}version of tc_schemes{p_end}
{p2colreset}{...}


{marker acknowledgments}{...}
{title:Acknowledgments}

{pstd}
This package consolidates work from three generous contributors to the Stata community:

{pstd}
{bf:Daniel Bischof} (University of Zurich) created the original {it:blindschemes}
package with its clean aesthetic and commitment to accessibility. His 2016 Stata
Conference presentation "Blindschemes: Stata Graph Schemes Sensitive to Color
Vision Deficiency" established best practices for accessible visualization in Stata.

{pmore}
Reference: Bischof, D. 2015. "Figure Schemes for Decent Stata Figures: plotplain & plottig."

{pstd}
{bf:Mead Over} (Center for Global Development) provided {it:blindschemes_fix},
which resolved compatibility issues between blindschemes and recent Stata versions.

{pstd}
{bf:Asjad Naqvi} (Vienna University of Economics and Business) created
{it:schemepack}, an impressive collection of 35+ schemes that bring modern color
science and design principles to Stata graphics. His "Stata Guide" blog on Medium
provides extensive documentation and visualization tutorials.

{pstd}
All original licenses and attributions are preserved. This consolidation is
provided under MIT license for the wrapper code only; individual scheme files
retain their original licensing.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet

{pstd}
Consolidation package only. Original scheme authors credited above.


{title:Also see}

{psee}
Online: {helpb scheme}, {helpb set scheme}, {helpb graph}, {helpb palette}
{p_end}
