{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:tvpass} {hline 2}}Post-authorization study workflow support{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 15 2}
{cmd:tvpass}{cmd:,} {opt cohort(filename)} {opt exposure(filename)} {opt outcomes(filename)} [{opt id(varname)}]

{title:Description}

{pstd}
{cmd:tvpass} provides workflow support for post-authorization safety studies (PASS)
and post-authorization efficacy studies (PAES), with structured guidance for
regulatory submissions.

{title:Examples}

{phang2}{cmd:. tvpass, cohort(cohort.dta) exposure(meds.dta) outcomes(events.dta)}{p_end}

{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet
