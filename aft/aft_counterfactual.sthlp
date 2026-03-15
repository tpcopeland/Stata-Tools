{smcl}
{* *! version 1.1.0  15mar2026}{...}
{vieweralsosee "aft" "help aft"}{...}
{vieweralsosee "aft_rpsftm" "help aft_rpsftm"}{...}
{viewerjumpto "Syntax" "aft_counterfactual##syntax"}{...}
{viewerjumpto "Description" "aft_counterfactual##description"}{...}
{viewerjumpto "Options" "aft_counterfactual##options"}{...}
{viewerjumpto "Examples" "aft_counterfactual##examples"}{...}
{viewerjumpto "Stored results" "aft_counterfactual##results"}{...}
{viewerjumpto "Author" "aft_counterfactual##author"}{...}
{title:Title}

{p2colset 5 30 32 2}{...}
{p2col:{cmd:aft_counterfactual} {hline 2}}Counterfactual survival curves from RPSFTM{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:aft_counterfactual}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt pl:ot}}overlay observed and counterfactual KM curves{p_end}
{synopt:{opt tab:le}}display RMST comparison table{p_end}
{synopt:{opt timeh:orizons(numlist)}}time points for RMST calculation{p_end}
{synopt:{opt gen:erate(name)}}create counterfactual time variable{p_end}
{synopt:{opt sav:ing(filename)}}save counterfactual data to file{p_end}
{synopt:{opt sch:eme(schemename)}}graph scheme{p_end}
{synoptline}

{pstd}
Requires {cmd:aft_rpsftm} to have been run first.


{marker description}{...}
{title:Description}

{pstd}
{cmd:aft_counterfactual} uses the acceleration factor (psi) estimated by
{helpb aft_rpsftm} to compute counterfactual untreated survival times and
produce visualizations.

{pstd}
The {opt plot} option overlays three Kaplan-Meier curves: observed
experimental arm, observed control arm, and counterfactual untreated
(what would have happened if no one received treatment). The separation
between observed experimental and counterfactual curves represents the
treatment effect after adjusting for switching.

{pstd}
The {opt table} option computes restricted mean survival time (RMST) at
specified time horizons for each curve, providing a clinically interpretable
measure of the treatment benefit.


{marker options}{...}
{title:Options}

{phang}
{opt plot} overlays observed and counterfactual Kaplan-Meier survival curves.

{phang}
{opt table} displays a table of RMST values at specified time horizons.

{phang}
{opt timehorizons(numlist)} specifies the time points at which to compute
RMST. If omitted with {opt table}, uses the maximum observed time.

{phang}
{opt generate(name)} creates a new variable containing counterfactual
untreated survival times.

{phang}
{opt saving(filename)} saves counterfactual data (times, events, arm) to a
Stata dataset.

{phang}
{opt scheme(schemename)} specifies the graph scheme. Default is
{cmd:plotplainblind}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Counterfactual survival curves}

{phang2}{cmd:. aft_rpsftm, randomization(arm) treatment(treated) recensor}{p_end}
{phang2}{cmd:. aft_counterfactual, plot}{p_end}

{pstd}
{bf:Example 2: RMST comparison at multiple horizons}

{phang2}{cmd:. aft_counterfactual, table timehorizons(12 24 36)}{p_end}

{pstd}
{bf:Example 3: Generate counterfactual variable}

{phang2}{cmd:. aft_counterfactual, generate(cf_time)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:aft_counterfactual} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(psi)}}acceleration factor (log scale){p_end}
{synopt:{cmd:r(af)}}acceleration factor exp(psi){p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(randomization)}}randomization variable{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(rmst)}}RMST values (if {opt table} specified){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online:  {helpb aft}, {helpb aft_rpsftm}

{hline}
