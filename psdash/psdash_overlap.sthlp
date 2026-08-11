{smcl}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "psdash_overlap##syntax"}{...}
{viewerjumpto "Description" "psdash_overlap##description"}{...}
{viewerjumpto "Options" "psdash_overlap##options"}{...}
{viewerjumpto "Examples" "psdash_overlap##examples"}{...}
{viewerjumpto "Stored results" "psdash_overlap##results"}{...}
{viewerjumpto "Author" "psdash_overlap##author"}{...}
{title:Title}

{p2colset 5 27 29 2}{...}
{p2col:{cmd:psdash overlap} {hline 2}}Assess propensity-score overlap and positivity{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:psdash overlap} [{it:treatment}] [{it:psvar}] {ifin}
[{cmd:,} {it:options}]

{pstd}
See {help psdash##subcommands:Subcommand syntax} for the full signature and
{help psdash##options:Options} for every option, default, and interaction.

{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash overlap} summarizes propensity-score distributions and common
overlap. For a multi-valued treatment it evaluates every generalized
propensity-score component in every observed arm and returns the resulting
K-by-K mean table in {cmd:r(gps_means)}.

{pstd}
Detailed multi-group graphs use one data-driven x axis per GPS component. A
practical-positivity floor line is drawn only when it lies within that
component's observed range, and three-component graphs occupy one filled
row. Histogram bins are aligned across observed arms within each component.

{pstd}
The complete stored-result contract and the distinction between the full-vector
positivity finding and descriptive observed-arm bounds are documented under
{help psdash##results:Stored results}.

{marker options}{...}
{title:Options}

{phang}
{opt cov:ariates(varlist)} supplies covariates for automatic PS estimation.

{phang}
{opt bins(#)} sets histogram bins; default is {cmd:30}.

{phang}
{opt hist:ogram} requests histograms instead of density plots.

{phang}
{opt bwid:th(#)} sets the kernel-density bandwidth.

{phang}
{opt nog:raph} suppresses the graph.

{phang}
{opt sav:ing(filename)} saves the graph.

{phang}
{opt sch:eme(schemename)} sets the graph scheme.

{phang}
{opt graphopt:ions(string)} passes additional graph options.

{phang}
{opt ti:tle(string)} sets the graph title.

{phang}
{opt name(string)} names the graph in memory.

{phang}
{opt xlsx(filename)} exports overlap statistics to Excel.

{phang}
{opt sheet(string)} sets the Excel sheet name.

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc}.

{phang}
{opt ref:erence(#)} selects the multi-group reference arm.

{phang}
{opt gpsfloor(#)} sets the multi-group practical-positivity floor.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{phang}
{opt compact} replaces the detailed multi-group component density panels with
one grouped box-plot region containing every GPS component. It has no effect
for binary treatments.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash overlap foreign ps}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations assessed{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(mean_ps_treated)}}mean PS among treated{p_end}
{synopt:{cmd:r(mean_ps_control)}}mean PS among controls{p_end}
{synopt:{cmd:r(min_ps_treated)}}minimum PS among treated{p_end}
{synopt:{cmd:r(max_ps_treated)}}maximum PS among treated{p_end}
{synopt:{cmd:r(min_ps_control)}}minimum PS among controls{p_end}
{synopt:{cmd:r(max_ps_control)}}maximum PS among controls{p_end}
{synopt:{cmd:r(overlap_lower)}}descriptive lower overlap bound{p_end}
{synopt:{cmd:r(overlap_upper)}}descriptive upper overlap bound{p_end}
{synopt:{cmd:r(n_outside)}}observations outside overlap{p_end}
{synopt:{cmd:r(pct_outside)}}percent outside overlap{p_end}
{synopt:{cmd:r(auc)}}PS-model C statistic{p_end}
{synopt:{cmd:r(n_ps_boundary)}}PS values exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}PS values near 0 or 1{p_end}
{synopt:{cmd:r(K)}}number of treatment groups{p_end}
{synopt:{cmd:r(N_group_{it:<level>})}}observations in each group{p_end}
{synopt:{cmd:r(mean_ps_group_{it:<level>})}}mean observed-arm GPS{p_end}
{synopt:{cmd:r(min_ps_group_{it:<level>})}}minimum observed-arm GPS{p_end}
{synopt:{cmd:r(max_ps_group_{it:<level>})}}maximum observed-arm GPS{p_end}
{synopt:{cmd:r(min_gps_group_{it:<level>})}}minimum arm-specific GPS{p_end}
{synopt:{cmd:r(min_gps)}}minimum over the full GPS vector{p_end}
{synopt:{cmd:r(n_gps_violate)}}units below the GPS floor{p_end}
{synopt:{cmd:r(pct_gps_violate)}}percent below the GPS floor{p_end}
{synopt:{cmd:r(gps_floor)}}GPS floor used{p_end}
{synopt:{cmd:r(n_warnings)}}machine-readable findings{p_end}
{synopt:{cmd:r(n_excluded)}}observations excluded{p_end}
{synopt:{cmd:r(n_estimation)}}estimation-sample observations assessed{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}
{synopt:{cmd:r(psvar)}}propensity-score variable{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels{p_end}
{synopt:{cmd:r(reference)}}reference treatment group{p_end}
{synopt:{cmd:r(warnings)}}finding labels{p_end}

{p2col 5 32 34 2: Matrices}{p_end}
{synopt:{cmd:r(gps_means)}}mean GPS by observed arm and component{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_support}, {helpb psdash_balance}

{hline}
