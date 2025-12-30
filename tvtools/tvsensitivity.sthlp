{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{viewerjumpto "Syntax" "tvsensitivity##syntax"}{...}
{viewerjumpto "Description" "tvsensitivity##description"}{...}
{viewerjumpto "Examples" "tvsensitivity##examples"}{...}
{viewerjumpto "Author" "tvsensitivity##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:tvsensitivity} {hline 2}}Sensitivity analysis for unmeasured confounding{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 20 2}
{cmd:tvsensitivity}{cmd:,} {opt rr(#)} [{opt method(string)} {opt rru(numlist)} {opt rrou(numlist)}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:tvsensitivity} calculates E-values and performs quantitative bias analysis
to assess sensitivity of causal estimates to unmeasured confounding.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tvsensitivity, rr(1.5)}{p_end}
{phang2}{cmd:. tvsensitivity, rr(2.0) method(bias)}{p_end}

{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet
