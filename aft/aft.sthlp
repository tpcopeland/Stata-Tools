{smcl}
{* *! version 1.1.0  15mar2026}{...}
{vieweralsosee "[ST] streg" "help streg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "aft_select" "help aft_select"}{...}
{vieweralsosee "aft_fit" "help aft_fit"}{...}
{vieweralsosee "aft_diagnose" "help aft_diagnose"}{...}
{vieweralsosee "aft_compare" "help aft_compare"}{...}
{vieweralsosee "aft_split" "help aft_split"}{...}
{vieweralsosee "aft_pool" "help aft_pool"}{...}
{vieweralsosee "aft_rpsftm" "help aft_rpsftm"}{...}
{vieweralsosee "aft_counterfactual" "help aft_counterfactual"}{...}
{viewerjumpto "Syntax" "aft##syntax"}{...}
{viewerjumpto "Description" "aft##description"}{...}
{viewerjumpto "Options" "aft##options"}{...}
{viewerjumpto "Examples" "aft##examples"}{...}
{viewerjumpto "Stored results" "aft##results"}{...}
{viewerjumpto "Author" "aft##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:aft} {hline 2}}Accelerated Failure Time model selection and diagnostics{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft}
[{cmd:,} {opt l:ist} {opt d:etail}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft} is a suite of commands that automates the accelerated failure time
(AFT) model workflow in Stata. AFT models express covariate effects as time
ratios -- multiplicative changes in survival time -- which are often more
intuitive than hazard ratios from Cox models.

{pstd}
The package provides the following subcommands:

{p2colset 5 22 24 2}{...}
{p2col:{helpb aft_select}}compare AFT distributions and recommend best fit{p_end}
{p2col:{helpb aft_fit}}fit AFT model with selected distribution{p_end}
{p2col:{helpb aft_diagnose}}diagnostic plots and goodness-of-fit statistics{p_end}
{p2col:{helpb aft_compare}}side-by-side Cox PH vs AFT comparison{p_end}
{p2col:{helpb aft_split}}piecewise AFT: episode splitting and per-interval fitting{p_end}
{p2col:{helpb aft_pool}}meta-analytic pooling of piecewise AFT estimates{p_end}
{p2col:{helpb aft_rpsftm}}RPSFTM g-estimation for treatment switching{p_end}
{p2col:{helpb aft_counterfactual}}counterfactual survival curves from RPSFTM{p_end}
{p2colreset}{...}

{pstd}
The typical workflow is:

{phang2}1. {cmd:stset} your survival data

{phang2}2. {cmd:aft_select x1 x2} to compare distributions and pick the best fit

{phang2}3. {cmd:aft_fit x1 x2} to fit the AFT model with the recommended distribution

{phang2}4. {cmd:aft_diagnose, all} to assess model adequacy

{phang2}5. {cmd:aft_compare x1 x2} for a side-by-side Cox vs AFT comparison

{pstd}
For time-varying effects (piecewise AFT):

{phang2}6. {cmd:aft_split x1 x2, cutpoints(10 20)} to split and fit per-interval

{phang2}7. {cmd:aft_pool, method(random) plot} to pool and visualize

{pstd}
For treatment switching (structural AFT):

{phang2}8. {cmd:aft_rpsftm, randomization(arm) treatment(rx) recensor} for g-estimation

{phang2}9. {cmd:aft_counterfactual, plot} for counterfactual survival curves


{marker options}{...}
{title:Options}

{phang}
{opt list} displays only the names of available subcommands.

{phang}
{opt detail} displays detailed descriptions of each subcommand.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Display overview and workflow}

{phang2}{cmd:. aft}{p_end}

{pstd}
{bf:Full workflow with cancer data}

{phang2}{cmd:. sysuse cancer, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. aft_select drug age}{p_end}
{phang2}{cmd:. aft_fit drug age}{p_end}
{phang2}{cmd:. aft_diagnose, all}{p_end}
{phang2}{cmd:. aft_compare drug age}{p_end}

{pstd}
{bf:Piecewise AFT workflow}

{phang2}{cmd:. aft_split drug age, cutpoints(10 20)}{p_end}
{phang2}{cmd:. aft_pool, method(random) plot}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of subcommands{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(version)}}package version{p_end}
{synopt:{cmd:r(commands)}}list of subcommands{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Manual:  {manlink ST streg}, {manlink ST stcox}

{psee}
Online:  {helpb aft_select}, {helpb aft_fit}, {helpb aft_diagnose}, {helpb aft_compare},
{helpb aft_split}, {helpb aft_pool}, {helpb aft_rpsftm}, {helpb aft_counterfactual}

{hline}
