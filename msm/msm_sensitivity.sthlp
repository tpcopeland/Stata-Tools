{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{viewerjumpto "Syntax" "msm_sensitivity##syntax"}{...}
{viewerjumpto "Description" "msm_sensitivity##description"}{...}
{viewerjumpto "Examples" "msm_sensitivity##examples"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_sensitivity} {hline 2}}Removed in msm 2.0.0 (was: E-values and confounding-strength bounds){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_sensitivity} [{it:anything}]

{pstd}
Any arguments are ignored; the command prints its replacement and exits with
return code 199.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_sensitivity} was removed in msm 2.0.0, when msm became the estimator core
(prepare, weight, diagnose, fit, predict). Running it prints the replacement
and exits with return code 199. The stub ships for all of msm 2.x so that an
upgrade with {cmd:net install msm, replace} cannot leave the 1.4.x command
running against the 2.0 core.


{title:Replacement}

{pstd}
Use {cmd:qba_confound, from_model coef(treatment) evalue measure(HR)} (qba)
after msm_fit. Add {cmd:commonoutcome} when the cumulative incidence at the
end of follow-up (from {cmd:msm_predict}) is 15% or more. {help qba_confound}
documents the rare/common choice and the bounding factor.

{pstd}
See {help msm##companions:help msm} for the full map from each removed command
to its replacement.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. qba_confound, from_model coef(treatment) evalue measure(HR)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
