{smcl}
{* *! version 1.0.1  28feb2026}{...}
{viewerjumpto "Syntax" "nma_forest##syntax"}{...}
{viewerjumpto "Description" "nma_forest##description"}{...}
{viewerjumpto "Options" "nma_forest##options"}{...}
{viewerjumpto "Examples" "nma_forest##examples"}{...}
{viewerjumpto "Author" "nma_forest##author"}{...}

{title:Title}

{phang}
{bf:nma_forest} {hline 2} Forest plot for network meta-analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_forest}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt eform}}exponentiated scale (OR, RR, etc.){p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt xla:bel(numlist)}}custom x-axis labels{p_end}
{synopt:{opt scheme(string)}}graph scheme; default is plotplainblind{p_end}
{synopt:{opt saving(filename)}}save graph{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt title(string)}}custom title{p_end}
{synopt:{opt colors(string)}}marker and line color{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_forest} creates a forest plot showing network meta-analysis
treatment effect estimates with confidence intervals. Each treatment
is compared to the reference treatment.


{marker options}{...}
{title:Options}

{phang}
{opt eform} displays results on exponentiated scale. Appropriate for
log OR, log RR, log IRR, or log HR measures.

{phang}
{opt level(#)} specifies the confidence level. Default is 95.


{marker examples}{...}
{title:Examples}

{pstd}Standard forest plot{p_end}
{phang2}{cmd:. nma_forest}{p_end}

{pstd}Odds ratio scale{p_end}
{phang2}{cmd:. nma_forest, eform}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
