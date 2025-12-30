{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:tvcalendar} {hline 2}}Merge calendar-time external factors{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 18 2}
{cmd:tvcalendar} {cmd:using} {it:filename}{cmd:,} {opt datevar(varname)} [{opt merge(varlist)}]

{title:Description}

{pstd}
{cmd:tvcalendar} merges calendar-time factors (policy periods, seasonal effects,
environmental exposures) into person-time data based on date matching.

{title:Examples}

{phang2}{cmd:. tvcalendar using seasons.dta, datevar(start)}{p_end}

{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet
