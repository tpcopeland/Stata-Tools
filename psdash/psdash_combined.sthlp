{smcl}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "psdash_combined##syntax"}{...}
{viewerjumpto "Description" "psdash_combined##description"}{...}
{viewerjumpto "Options" "psdash_combined##options"}{...}
{viewerjumpto "Examples" "psdash_combined##examples"}{...}
{viewerjumpto "Stored results" "psdash_combined##results"}{...}
{viewerjumpto "Author" "psdash_combined##author"}{...}
{title:Title}

{p2colset 5 28 30 2}{...}
{p2col:{cmd:psdash combined} {hline 2}}Run the coordinated diagnostics dashboard{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:psdash combined} [{it:treatment}] [{it:psvar}] {ifin}
[{cmd:,} {it:options}]

{pstd}
See {help psdash##subcommands:Subcommand syntax} for the full signature and
{help psdash##options:Options} for every option, default, and interaction.

{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash combined} coordinates overlap, balance, weight, and support panels
on a common analysis sample. Its verdict is driven by documented panel thresholds,
and its machine-readable findings identify the panel responsible. For longitudinal
producer contracts it routes to period-specific diagnostics.

{pstd}
The complete return contract, including {cmd:r(verdict)},
{cmd:r(n_warnings)}, and {cmd:r(warnings)}, is listed under
{help psdash##results:Stored results}.

{marker options}{...}
{title:Options}

{phang}
{opt cov:ariates(varlist)} specifies covariates for the balance panel.

{phang}
{opt w:var(varname)} specifies existing diagnostic weights.

{phang}
{opt thr:eshold(#)} sets the absolute-SMD cutoff; default is {cmd:0.1}.

{phang}
{opt overlap:max(#)} sets the maximum tolerated percent outside overlap.

{phang}
{opt ess:min(#)} sets the minimum tolerated ESS percentage.

{phang}
{opt imbal:max(#)} sets the tolerated number of imbalanced covariates.

{phang}
{opt noo:verlap} skips the overlap panel.

{phang}
{opt nob:alance} skips the balance panel.

{phang}
{opt now:eights} skips the weight panel.

{phang}
{opt nos:upport} skips the support panel.

{phang}
{opt dry:run} resolves inputs without running diagnostic panels.

{phang}
{opt rep:ort(filename)} writes the combined report workbook.

{phang}
{opt sav:ing(filename)} saves the combined graph.

{phang}
{opt sch:eme(schemename)} sets the graph scheme.

{phang}
{opt ti:tle(string)} sets the combined graph title.

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc}.

{phang}
{opt ref:erence(#)} selects the multi-group reference arm.

{phang}
{opt gpsfloor(#)} sets the multi-group practical-positivity floor.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash combined foreign ps, covariates(mpg weight length)}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(longitudinal)}}longitudinal-contract indicator{p_end}
{synopt:{cmd:r(n_warnings)}}total machine-readable findings{p_end}
{synopt:{cmd:r(n_panels)}}diagnostic panels run{p_end}
{synopt:{cmd:r(overlapmax)}}overlap threshold used{p_end}
{synopt:{cmd:r(essmin)}}ESS threshold used{p_end}
{synopt:{cmd:r(imbalmax)}}imbalance threshold used{p_end}
{synopt:{cmd:r(N_requested)}}observations requested{p_end}
{synopt:{cmd:r(N_analysis)}}common analysis observations{p_end}
{synopt:{cmd:r(n_common_excluded)}}observations excluded from all panels{p_end}
{synopt:{cmd:r(n_excluded)}}observations excluded{p_end}
{synopt:{cmd:r(n_estimation)}}estimation-sample observations assessed{p_end}
{synopt:{cmd:r(K)}}number of treatment groups{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}
{synopt:{cmd:r(psvar)}}propensity-score variable{p_end}
{synopt:{cmd:r(wvar)}}diagnostic weight variable{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(method)}}producer method metadata{p_end}
{synopt:{cmd:r(contract_version)}}producer contract version{p_end}
{synopt:{cmd:r(id)}}longitudinal identifier{p_end}
{synopt:{cmd:r(period)}}longitudinal period variable{p_end}
{synopt:{cmd:r(regime)}}longitudinal regime metadata{p_end}
{synopt:{cmd:r(verdict)}}overall PASS or FAIL verdict{p_end}
{synopt:{cmd:r(warnings)}}finding labels{p_end}
{synopt:{cmd:r(warning_panels)}}panels with findings{p_end}
{synopt:{cmd:r(report)}}report-workbook path{p_end}
{synopt:{cmd:r(iivwcomponent)}}selected iivw component{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels{p_end}
{synopt:{cmd:r(reference)}}reference treatment group{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_detect}

{hline}
