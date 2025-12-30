{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tvtable} {hline 2}}Publication-ready summary tables{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 16 2}
{cmd:tvtable}{cmd:,} {opt exp:osure(varname)} [{opt outcome(varname)} {opt persontime(varname)}]

{title:Description}

{pstd}
{cmd:tvtable} creates summary tables showing person-time, events, and incidence
rates by exposure category for time-varying exposure analyses.

{title:Examples}

{phang2}{cmd:. tvtable, exposure(tv_exposure)}{p_end}
{phang2}{cmd:. tvtable, exposure(tv_exposure) outcome(_event) persontime(fu_time)}{p_end}

{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet
