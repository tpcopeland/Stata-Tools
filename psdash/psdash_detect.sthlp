{smcl}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "psdash_detect##syntax"}{...}
{viewerjumpto "Description" "psdash_detect##description"}{...}
{viewerjumpto "Options" "psdash_detect##options"}{...}
{viewerjumpto "Examples" "psdash_detect##examples"}{...}
{viewerjumpto "Stored results" "psdash_detect##results"}{...}
{viewerjumpto "Author" "psdash_detect##author"}{...}
{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:psdash detect} {hline 2}}Inspect the resolved diagnostic inputs{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:psdash detect} [{it:treatment}] [{it:psvar}] {ifin}
[{cmd:,} {it:options}]

{pstd}
See {help psdash##subcommands:Subcommand syntax} for the full signature and
{help psdash##options:Options} for every option and detection rule.

{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash detect} resolves treatment, propensity score, covariates, weights,
estimand, multi-group metadata, and longitudinal producer metadata without
running diagnostic calculations. It is the inspection form of
{cmd:psdash combined, dryrun}.

{pstd}
The complete return contract is listed under
{help psdash##results:Stored results}.

{marker options}{...}
{title:Options}

{phang}
{opt cov:ariates(varlist)} supplies covariates instead of auto-detecting them.

{phang}
{opt w:var(varname)} supplies an existing diagnostic weight variable.

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc}.

{phang}
{opt ref:erence(#)} selects the multi-group reference arm.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash detect foreign ps, covariates(mpg weight length)}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(n_covariates)}}number of covariates resolved{p_end}
{synopt:{cmd:r(psvar_auto)}}automatic-PS indicator{p_end}
{synopt:{cmd:r(multigroup)}}multi-group treatment indicator{p_end}
{synopt:{cmd:r(longitudinal)}}longitudinal-contract indicator{p_end}
{synopt:{cmd:r(K)}}number of treatment groups{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}
{synopt:{cmd:r(psvar)}}propensity-score variable{p_end}
{synopt:{cmd:r(covariates)}}covariates resolved{p_end}
{synopt:{cmd:r(wvar)}}diagnostic weight variable{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels{p_end}
{synopt:{cmd:r(reference)}}reference treatment group{p_end}
{synopt:{cmd:r(iivwcomponent)}}selected iivw component{p_end}
{synopt:{cmd:r(id)}}longitudinal identifier{p_end}
{synopt:{cmd:r(period)}}longitudinal period variable{p_end}
{synopt:{cmd:r(regime)}}longitudinal regime metadata{p_end}
{synopt:{cmd:r(method)}}producer method metadata{p_end}
{synopt:{cmd:r(contract_version)}}producer contract version{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_combined}

{hline}
