{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "msm_table##syntax"}{...}
{viewerjumpto "Description" "msm_table##description"}{...}
{viewerjumpto "Examples" "msm_table##examples"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_table} {hline 2}}Removed in msm 2.0.0 (was: multi-sheet Excel tables of MSM results){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:msm_table} [{it:anything}]

{pstd}
Any arguments are ignored; the command prints its replacement and exits with
return code 199.


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_table} was removed in msm 2.0.0, when msm became the estimator core
(prepare, weight, diagnose, fit, predict). Running it prints the replacement
and exits with return code 199. The stub ships for all of msm 2.x so that an
upgrade with {cmd:net install msm, replace} cannot leave the 1.4.x command
running against the 2.0 core.


{title:Replacement}

{p 4 8 2}
{bf:coefficients}: {cmd:collect: msm_fit ...} then {cmd:regtab, xlsx() sheet()} (tabtools){p_end}
{p 4 8 2}
{bf:predictions}: {cmd:matrix RD = r(rd)} then {cmd:effecttab, from(RD) xlsx()} or {cmd:puttab using f.xlsx, matrix(r(predictions))}{p_end}
{p 4 8 2}
{bf:balance}: {cmd:psdash balance ..., xlsx()} or {cmd:puttab ..., matrix(r(treatment_balance))}{p_end}
{p 4 8 2}
{bf:weights}: {cmd:psdash weights ..., wvar(_msm_weight) xlsx()}{p_end}
{p 4 8 2}
{bf:E-values}: {cmd:qba_confound, from_model ... evalue} (qba){p_end}

{pstd}
See {help msm##companions:help msm} for the full map from each removed command
to its replacement.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. collect: msm_fit, model(logistic) outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet(fit) coef(OR)}{p_end}
{phang2}{cmd:. msm_predict, times(3 5 7 9) difference samples(500) seed(1)}{p_end}
{phang2}{cmd:. matrix RD = r(rd)}{p_end}
{phang2}{cmd:. effecttab, from(RD) effect("Risk difference") xlsx(results.xlsx) sheet(rd)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
