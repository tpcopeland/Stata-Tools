{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{viewerjumpto "Syntax" "msm_report##syntax"}{...}
{viewerjumpto "Description" "msm_report##description"}{...}
{viewerjumpto "Examples" "msm_report##examples"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_report} {hline 2}}Removed in msm 2.0.0 (was: console, CSV and Excel results report){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_report} [{it:anything}]

{pstd}
Any arguments are ignored; the command prints its replacement and exits with
return code 199.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_report} was removed in msm 2.0.0, when msm became the estimator core
(prepare, weight, diagnose, fit, predict). Running it prints the replacement
and exits with return code 199. The stub ships for all of msm 2.x so that an
upgrade with {cmd:net install msm, replace} cannot leave the 1.4.x command
running against the 2.0 core.


{title:Replacement}

{pstd}
Use {cmd:collect: msm_fit ...} then {cmd:regtab} for the outcome model, and
{cmd:msm_predict, difference}, {cmd:matrix RD = r(rd)} and {cmd:effecttab, from(RD)} for
standardized risk differences (tabtools).

{pstd}
See {help msm##companions:help msm} for the full map from each removed command
to its replacement.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. regtab, coef(OR)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
