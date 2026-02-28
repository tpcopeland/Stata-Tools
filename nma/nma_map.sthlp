{smcl}
{* *! version 1.0.4  28feb2026}{...}
{viewerjumpto "Syntax" "nma_map##syntax"}{...}
{viewerjumpto "Description" "nma_map##description"}{...}
{viewerjumpto "Options" "nma_map##options"}{...}
{viewerjumpto "Examples" "nma_map##examples"}{...}
{viewerjumpto "Author" "nma_map##author"}{...}

{title:Title}

{phang}
{bf:nma_map} {hline 2} Network geometry visualization


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_map}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt nodes:ize(string)}}size nodes by: studies (default){p_end}
{synopt:{opt edges:ize(string)}}weight edges by: studies (default){p_end}
{synopt:{opt nola:bels}}suppress treatment labels{p_end}
{synopt:{opt scheme(string)}}graph scheme; default is plotplainblind{p_end}
{synopt:{opt saving(filename)}}save graph{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt title(string)}}custom title{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_map} draws a network geometry plot. Treatments are shown as
nodes arranged in a circle, and direct comparisons as edges connecting
them. Node sizes reflect the number of studies involving each treatment,
and edge widths reflect the number of studies making each comparison.

{pstd}
This command only requires {cmd:nma_setup}; it does not require a
fitted model.


{marker examples}{...}
{title:Examples}

{pstd}Basic network map{p_end}
{phang2}{cmd:. nma_map}{p_end}

{pstd}Without labels{p_end}
{phang2}{cmd:. nma_map, nolabels}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
