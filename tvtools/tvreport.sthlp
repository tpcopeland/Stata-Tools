{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:tvreport} {hline 2}}Automated analysis report generation{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:tvreport}{cmd:,} {opt id(varname)} {opt start(varname)} {opt stop(varname)} {opt exp:osure(varname)}
[{opt cov:ariates(varlist)} {opt event(varname)}]

{title:Description}

{pstd}
{cmd:tvreport} generates comprehensive analysis reports for time-varying exposure
studies, including data overview, exposure distribution, covariate balance,
and event summaries.

{title:Examples}

{phang2}{cmd:. tvreport, id(id) start(start) stop(stop) exposure(tv_exposure)}{p_end}
{phang2}{cmd:. tvreport, id(id) start(start) stop(stop) exposure(tv_exposure) covariates(age sex) event(_event)}{p_end}

{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet
