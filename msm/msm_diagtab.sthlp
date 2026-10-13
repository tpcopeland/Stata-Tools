{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{viewerjumpto "Syntax" "msm_diagtab##syntax"}{...}
{viewerjumpto "Description" "msm_diagtab##description"}{...}
{viewerjumpto "Examples" "msm_diagtab##examples"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_diagtab} {hline 2}}Removed in msm 2.0.0 (was: Excel export of accumulated diagnostics){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_diagtab} [{it:anything}]

{pstd}
Any arguments are ignored; the command prints its replacement and exits with
return code 199.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_diagtab} was removed in msm 2.0.0, when msm became the estimator core
(prepare, weight, diagnose, fit, predict). Running it prints the replacement
and exits with return code 199. The stub ships for all of msm 2.x so that an
upgrade with {cmd:net install msm, replace} cannot leave the 1.4.x command
running against the 2.0 core.


{title:Replacement}

{pstd}
There is no replacement. Post the {cmd:msm_diagnose} or {cmd:psdash} returns
you need with {cmd:frame post} and export the frame with
{cmd:puttab, frame()}.

{pstd}
See {help msm##companions:help msm} for the full map from each removed command
to its replacement.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_diagnose}{p_end}
{phang2}{cmd:. matrix S = r(support)}{p_end}
{phang2}{cmd:. puttab using diagnostics.xlsx, matrix(S) sheet(support)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
