{smcl}
{* *! version 1.0.5  01mar2026}{...}
{viewerjumpto "Syntax" "nma_report##syntax"}{...}
{viewerjumpto "Description" "nma_report##description"}{...}
{viewerjumpto "Options" "nma_report##options"}{...}
{viewerjumpto "Examples" "nma_report##examples"}{...}
{viewerjumpto "Author" "nma_report##author"}{...}

{title:Title}

{phang}
{bf:nma_report} {hline 2} Publication-quality report export


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_report}
{cmd:using} {it:filename}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt for:mat(string)}}excel (default) or csv{p_end}
{synopt:{opt eform}}exponentiated effects{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt sec:tions(string)}}report sections: setup fit rank{p_end}
{synopt:{opt level(#)}}confidence level{p_end}
{synopt:{opt dig:its(#)}}decimal places in output; default is {cmd:digits(4)}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_report} exports a structured report with selected analysis
sections to Excel or CSV format.


{marker examples}{...}
{title:Examples}

{pstd}Export to Excel{p_end}
{phang2}{cmd:. nma_report using results.xlsx, replace}{p_end}

{pstd}Export specific sections{p_end}
{phang2}{cmd:. nma_report using results.xlsx, sections(fit rank) eform replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
