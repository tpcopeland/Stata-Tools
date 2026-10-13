{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "msm_validate##syntax"}{...}
{viewerjumpto "Description" "msm_validate##description"}{...}
{viewerjumpto "Examples" "msm_validate##examples"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_validate} {hline 2}}Removed in msm 2.0.0 (was: person-period data-quality checks){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_validate} [{it:anything}]

{pstd}
Any arguments are ignored; the command prints its replacement and exits with
return code 199.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_validate} was removed in msm 2.0.0, when msm became the estimator core
(prepare, weight, diagnose, fit, predict). Running it prints the replacement
and exits with return code 199. The stub ships for all of msm 2.x so that an
upgrade with {cmd:net install msm, replace} cannot leave the 1.4.x command
running against the 2.0 core.


{title:Replacement}

{pstd}
Its checks moved into the core: {cmd:msm_prepare} refuses duplicates,
non-binary values and non-integer periods, and reports gaps, missing values,
constant covariates and sparse periods; {cmd:msm_weight} refuses gaps and
missing model inputs; post-event and post-censoring rows leave the risk set
(_msm_decision_risk); {cmd:msm_diagnose} flags periods without a treatment
contrast and the positivity floor.

{pstd}
See {help msm##companions:help msm} for the full map from each removed command
to its replacement.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:. return list}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity) nolog}{p_end}
{phang2}{cmd:. msm_diagnose}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
