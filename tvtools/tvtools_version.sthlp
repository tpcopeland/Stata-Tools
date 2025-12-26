{smcl}
{* *! version 1.0.0  26dec2025}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:tvtools_version} {hline 2}}Display version information for tvtools commands{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 20 2}
{cmd:tvtools_version} [{cmd:,} {opt q:uiet}]


{marker options}{...}
{title:Options}

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt q:uiet}}suppress display output; only set return values{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvtools_version} displays version information for all installed tvtools commands
(tvexpose, tvmerge, tvevent). This is useful for:

{p 8 12 2}1. Verifying installed versions before running analyses{p_end}
{p 8 12 2}2. Including version information in methods sections of papers{p_end}
{p 8 12 2}3. Debugging potential version mismatches{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Display version information:{p_end}
{phang2}{cmd:. tvtools_version}{p_end}

{pstd}Get versions programmatically:{p_end}
{phang2}{cmd:. tvtools_version, quiet}{p_end}
{phang2}{cmd:. display "tvexpose version: " r(tvexpose)}{p_end}

{pstd}Include in do-file header for reproducibility:{p_end}
{phang2}{cmd:. log using "analysis.log", replace}{p_end}
{phang2}{cmd:. tvtools_version}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvtools_version} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(tvexpose)}}tvexpose version string (e.g., "1.2.0"){p_end}
{synopt:{cmd:r(tvmerge)}}tvmerge version string (e.g., "1.0.5"){p_end}
{synopt:{cmd:r(tvevent)}}tvevent version string (e.g., "1.4.0"){p_end}
{synopt:{cmd:r(package_date)}}package distribution date (YYYYMMDD){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
timothy.copeland@ki.se


{marker also}{...}
{title:Also see}

{psee}
{space 2}Help: {helpb tvexpose}, {helpb tvmerge}, {helpb tvevent}
