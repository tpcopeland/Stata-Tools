{smcl}
{* *! version 1.0.3  01mar2026}{...}
{viewerjumpto "Syntax" "tte_report##syntax"}{...}
{viewerjumpto "Description" "tte_report##description"}{...}
{viewerjumpto "Examples" "tte_report##examples"}{...}
{viewerjumpto "Author" "tte_report##author"}{...}

{title:Title}

{phang}
{bf:tte_report} {hline 2} Publication-quality results tables


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_report}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth for:mat(string)}}display (default), csv, or excel{p_end}
{synopt:{opth export(filename)}}export to file{p_end}
{synopt:{opt dec:imals(#)}}decimal places; default is {cmd:3}{p_end}
{synopt:{opt eform}}exponentiate coefficients (OR/HR){p_end}
{synopt:{opth ci_separator(string)}}CI separator; default is {cmd:" to "}{p_end}
{synopt:{opth title(string)}}table title{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synopt:{opt pre:dictions(name)}}matrix of predictions from {cmd:tte_predict}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_report} generates formatted results tables suitable for
manuscripts. It summarizes the analysis configuration, weight
diagnostics, and outcome model coefficients with robust standard
errors, confidence intervals, and p-values.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_report}{p_end}
{phang2}{cmd:. tte_report, eform export(results.xlsx) replace}{p_end}
{phang2}{cmd:. tte_report, format(csv) export(results.csv)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet
