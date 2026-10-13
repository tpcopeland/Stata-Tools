{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "psdash" "help psdash"}{...}
{vieweralsosee "eplot" "help eplot"}{...}
{vieweralsosee "swimlane" "help swimlane"}{...}
{viewerjumpto "Syntax" "msm_plot##syntax"}{...}
{viewerjumpto "Description" "msm_plot##description"}{...}
{viewerjumpto "Examples" "msm_plot##examples"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_plot} {hline 2}}Removed in msm 2.0.0 (was: weight, balance, survival, trajectory and positivity graphs){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_plot} [{it:anything}]

{pstd}
Any arguments are ignored; the command prints its replacement and exits with
return code 199.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_plot} was removed in msm 2.0.0, when msm became the estimator core
(prepare, weight, diagnose, fit, predict). Running it prints the replacement
and exits with return code 199. The stub ships for all of msm 2.x so that an
upgrade with {cmd:net install msm, replace} cannot leave the 1.4.x command
running against the 2.0 core.


{title:Replacement}

{p 4 8 2}
{bf:weights}: {cmd:psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) graph}{p_end}
{p 4 8 2}
{bf:balance}: {cmd:psdash balance treatment _msm_ps if _msm_decision_risk, covariates(...) wvar(_msm_weight) loveplot}{p_end}
{p 4 8 2}
{bf:survival}: {cmd:msm_predict, ... frame(F)} then {cmd:twoway} (see {help msm_predict##curve:help msm_predict}){p_end}
{p 4 8 2}
{bf:trajectory}: {cmd:gen pstop = period + 1} then {cmd:swimlane, id(id) start(period) stop(pstop) state(treatment)}{p_end}
{p 4 8 2}
{bf:positivity}: {cmd:psdash combined, wvar(_msm_weight)} and {cmd:msm_diagnose}{p_end}

{pstd}
See {help msm##companions:help msm} for the full map from each removed command
to its replacement.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) graph}{p_end}
{phang2}{cmd:. msm_predict, times(1 3 5 7 9) difference samples(500) seed(1) frame(pred, replace)}{p_end}
{phang2}{cmd:. eplot if strategy == "rd", frame(pred) values}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
