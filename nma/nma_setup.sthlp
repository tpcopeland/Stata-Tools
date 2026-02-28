{smcl}
{* *! version 1.0.1  28feb2026}{...}
{viewerjumpto "Syntax" "nma_setup##syntax"}{...}
{viewerjumpto "Description" "nma_setup##description"}{...}
{viewerjumpto "Options" "nma_setup##options"}{...}
{viewerjumpto "Examples" "nma_setup##examples"}{...}
{viewerjumpto "Stored results" "nma_setup##results"}{...}
{viewerjumpto "Author" "nma_setup##author"}{...}

{title:Title}

{phang}
{bf:nma_setup} {hline 2} Import arm-level data for network meta-analysis


{marker syntax}{...}
{title:Syntax}

{pstd}
Binary outcomes (events and totals)

{p 8 17 2}
{cmdab:nma_setup}
{it:events} {it:total}
{ifin}{cmd:,}
{opth study:var(varname)}
{opth trt:var(varname)}
[{it:options}]

{pstd}
Continuous outcomes (mean, SD, sample size)

{p 8 17 2}
{cmdab:nma_setup}
{it:mean} {it:sd} {it:n}
{ifin}{cmd:,}
{opth study:var(varname)}
{opth trt:var(varname)}
[{it:options}]

{pstd}
Rate outcomes (events and person-time)

{p 8 17 2}
{cmdab:nma_setup}
{it:events} {it:persontime}
{ifin}{cmd:,}
{opth study:var(varname)}
{opth trt:var(varname)}
{opt mea:sure(irr)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent :* {opth study:var(varname)}}study identifier{p_end}
{p2coldent :* {opth trt:var(varname)}}treatment identifier{p_end}
{synopt:{opt ref(string)}}reference treatment; default is most connected{p_end}
{synopt:{opt mea:sure(string)}}effect measure: or rr rd (binary), md smd (continuous), irr (rate){p_end}
{synopt:{opt zc:orrection(#)}}continuity correction for zero cells; default is 0.5{p_end}
{synopt:{opt force}}proceed with disconnected network{p_end}
{synoptline}
{p 4 6 2}* {opt studyvar()} and {opt trtvar()} are required.


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_setup} prepares arm-level summary data for network meta-analysis.
The data should be in long format with one row per arm per study. The command
auto-detects the outcome type from the number of variables specified, computes
treatment contrasts, builds within-study variance-covariance matrices, and
validates network connectivity.

{pstd}
The outcome type is detected as follows:

{phang2}2 variables + measure(irr) = rate data (events, person-time){p_end}
{phang2}2 variables (default) = binary data (events, totals){p_end}
{phang2}3 variables = continuous data (mean, sd, n){p_end}

{pstd}
By default, the most connected treatment (highest degree in the network graph)
is selected as the reference. This can be overridden with {opt ref()}.


{marker options}{...}
{title:Options}

{phang}
{opth studyvar(varname)} specifies the variable identifying studies.
Required. Can be string or numeric.

{phang}
{opth trtvar(varname)} specifies the variable identifying treatments.
Required. Can be string or numeric (with value labels).

{phang}
{opt ref(string)} specifies the reference treatment by label. Default
is the most connected treatment in the network.

{phang}
{opt measure(string)} specifies the effect measure. For binary data:
{opt or} (default), {opt rr}, or {opt rd}. For continuous: {opt md}
(default) or {opt smd}. For rate: {opt irr}.

{phang}
{opt zcorrection(#)} specifies the continuity correction added to zero
cells. Default is 0.5. Applied to all arms of affected studies.

{phang}
{opt force} allows analysis to proceed even if the network is disconnected.
Cross-component comparisons will be marked as not estimable.


{marker examples}{...}
{title:Examples}

{pstd}Binary outcome with auto-detected reference{p_end}
{phang2}{cmd:. nma_setup events total, studyvar(study) trtvar(treatment)}{p_end}

{pstd}Binary outcome with specified reference and risk ratio{p_end}
{phang2}{cmd:. nma_setup d n, studyvar(trial) trtvar(drug) ref(Placebo) measure(rr)}{p_end}

{pstd}Continuous outcome (mean difference){p_end}
{phang2}{cmd:. nma_setup mean sd samplesize, studyvar(study) trtvar(arm) measure(md)}{p_end}

{pstd}Rate data{p_end}
{phang2}{cmd:. nma_setup events pyears, studyvar(study) trtvar(arm) measure(irr)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:nma_setup} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_studies)}}number of studies{p_end}
{synopt:{cmd:r(n_treatments)}}number of treatments{p_end}
{synopt:{cmd:r(n_comparisons)}}number of direct comparisons{p_end}
{synopt:{cmd:r(n_direct)}}number of direct-only comparisons{p_end}
{synopt:{cmd:r(n_indirect)}}number of indirect-only comparisons{p_end}
{synopt:{cmd:r(n_mixed)}}number of mixed-evidence comparisons{p_end}
{synopt:{cmd:r(connected)}}1 if network is connected, 0 otherwise{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(treatments)}}space-separated list of treatments{p_end}
{synopt:{cmd:r(ref)}}reference treatment{p_end}
{synopt:{cmd:r(measure)}}effect measure used{p_end}
{synopt:{cmd:r(outcome_type)}}binary, continuous, or rate{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(evidence)}}k x k evidence classification matrix{p_end}
{synopt:{cmd:r(adjacency)}}k x k adjacency matrix{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}
