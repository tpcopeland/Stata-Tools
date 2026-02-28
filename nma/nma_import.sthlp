{smcl}
{* *! version 1.0.2  28feb2026}{...}
{viewerjumpto "Syntax" "nma_import##syntax"}{...}
{viewerjumpto "Description" "nma_import##description"}{...}
{viewerjumpto "Options" "nma_import##options"}{...}
{viewerjumpto "Examples" "nma_import##examples"}{...}
{viewerjumpto "Stored results" "nma_import##results"}{...}
{viewerjumpto "Author" "nma_import##author"}{...}

{title:Title}

{phang}
{bf:nma_import} {hline 2} Import pre-computed effect sizes for network meta-analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_import}
{it:effect} {it:se}
{ifin}{cmd:,}
{opth study:var(varname)}
{opt treat1(varname)}
{opt treat2(varname)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent :* {opth study:var(varname)}}study identifier{p_end}
{p2coldent :* {opt treat1(varname)}}first treatment in comparison{p_end}
{p2coldent :* {opt treat2(varname)}}second treatment in comparison{p_end}
{synopt:{opt ref(string)}}reference treatment{p_end}
{synopt:{opt mea:sure(string)}}effect measure label{p_end}
{synopt:{opth cov:ariance(varname)}}within-study covariance for multi-arm studies{p_end}
{synopt:{opt force}}proceed with disconnected network{p_end}
{synoptline}
{p 4 6 2}* {opt studyvar()}, {opt treat1()}, and {opt treat2()} are required.


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_import} imports pre-computed effect sizes (e.g., log odds ratios,
log hazard ratios, mean differences) with their standard errors for
network meta-analysis. Each row should represent one pairwise comparison
within a study.


{marker options}{...}
{title:Options}

{phang}
{opth studyvar(varname)} specifies the study identifier variable.

{phang}
{opt treat1(varname)} and {opt treat2(varname)} specify the two treatments
being compared in each row.

{phang}
{opt ref(string)} specifies the reference treatment. Default is the most
connected treatment.

{phang}
{opt measure(string)} labels the effect measure for display purposes.

{phang}
{opth covariance(varname)} specifies within-study covariance for multi-arm
studies. If not provided, zero covariance is assumed.

{phang}
{opt force} allows analysis with disconnected networks.


{marker examples}{...}
{title:Examples}

{pstd}Import log odds ratios{p_end}
{phang2}{cmd:. nma_import log_or se_log_or, studyvar(study) treat1(treat_a) treat2(treat_b) measure(or)}{p_end}

{pstd}Import hazard ratios{p_end}
{phang2}{cmd:. nma_import log_hr se, studyvar(trial) treat1(arm1) treat2(arm2) measure(hr) ref(Placebo)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:nma_import} stores the same results as {helpb nma_setup}.


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
