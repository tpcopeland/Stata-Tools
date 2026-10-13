{smcl}
{vieweralsosee "msm" "help msm"}{...}
{viewerjumpto "Syntax" "msm_protocol##syntax"}{...}
{viewerjumpto "Description" "msm_protocol##description"}{...}
{viewerjumpto "Examples" "msm_protocol##examples"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_protocol} {hline 2}}Removed in msm 2.0.0 (was: seven-component study protocol){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_protocol} [{it:anything}]

{pstd}
Any arguments are ignored; the command prints its replacement and exits with
return code 199.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_protocol} was removed in msm 2.0.0, when msm became the estimator core
(prepare, weight, diagnose, fit, predict). Running it prints the replacement
and exits with return code 199. The stub ships for all of msm 2.x so that an
upgrade with {cmd:net install msm, replace} cannot leave the 1.4.x command
running against the 2.0 core.


{title:Replacement}

{pstd}
There is no replacement: record the protocol in the manuscript, its
supplement, or a protocol document.

{pstd}
See {help msm##companions:help msm} for the full map from each removed command
to its replacement.


{marker examples}{...}
{title:Examples}

{pstd}
None; this command has no replacement.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
