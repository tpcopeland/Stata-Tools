{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_plot##syntax"}{...}
{viewerjumpto "Description" "drest_plot##description"}{...}
{viewerjumpto "Options" "drest_plot##options"}{...}
{viewerjumpto "Examples" "drest_plot##examples"}{...}
{viewerjumpto "Author" "drest_plot##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:drest_plot} {hline 2}}Doubly robust diagnostic plots{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_plot}
[{cmd:,}
{opt over:lap}
{opt infl:uence}
{opt ite}
{opt all}
{opt sav:ing(string)}
{opt sch:eme(string)}
{opt name(string)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_plot} generates diagnostic visualizations after {cmd:drest_estimate}.


{marker options}{...}
{title:Options}

{phang}{opt overlap} plots propensity score density by treatment group.{p_end}
{phang}{opt influence} plots influence function distribution.{p_end}
{phang}{opt ite} plots distribution of individual treatment effects.{p_end}
{phang}{opt all} generates all plots (default).{p_end}
{phang}{opt saving(string)} file prefix for saving graphs.{p_end}
{phang}{opt scheme(string)} graph scheme; default is {cmd:plotplainblind}.{p_end}
{phang}{opt name(string)} graph name prefix.{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_plot, overlap influence}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
