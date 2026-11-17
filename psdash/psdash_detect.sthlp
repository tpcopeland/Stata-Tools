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

{pstd}
If the requested sample is empty, or no observation has usable resolved inputs,
the command exits with {cmd:r(2000)} instead of returning a partial detection.

{marker options}{...}
{title:Options}

{phang}
{opt cov:ariates(varlist)} supplies covariates instead of auto-detecting them and
accepts factor-variable and interaction notation.

{phang}
{opt w:var(varname)} supplies an existing diagnostic weight variable.

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc} (any case; {cmd:r(estimand)}
is returned in lower case); when omitted, the detector uses the
supported estimation or producer context. After {cmd:iivw_weight}, {cmd:msm_weight},
or {cmd:tte_weight} without {opt wvar()}, a value that disagrees with the producer's
estimand is an error, because the producer's weight targets its own estimand.

{phang}
{opt ref:erence(#)} selects the multi-group reference arm; it takes one level. For a
treatment coded 0/1 only {cmd:reference(0)} is allowed.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash detect foreign ps, covariates(mpg weight length)}{p_end}
{phang2}{cmd:. psdash detect ps, covariates(i.rep78 c.weight##c.length)}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(n_covariates)}}number of covariates resolved{p_end}
{synopt:{cmd:r(psvar_auto)}}automatic-PS indicator{p_end}
{synopt:{cmd:r(multigroup)}}multi-group treatment indicator{p_end}
{synopt:{cmd:r(longitudinal)}}longitudinal-contract indicator{p_end}
{synopt:{cmd:r(K)}}group count, multigroup{p_end}
{synopt:{cmd:r(n_estimation)}}estimation-sample observations{p_end}
{synopt:{cmd:r(n_excluded)}}observations outside {cmd:e(sample)}{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}
{synopt:{cmd:r(psvar)}}propensity-score variable{p_end}
{synopt:{cmd:r(covariates)}}covariates resolved{p_end}
{synopt:{cmd:r(wvar)}}diagnostic weight variable{p_end}
{synopt:{cmd:r(weight_role)}}role of {cmd:r(wvar)} after msm{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels, multigroup{p_end}
{synopt:{cmd:r(reference)}}reference group, multigroup{p_end}
{synopt:{cmd:r(iivwcomponent)}}selected iivw component{p_end}
{synopt:{cmd:r(id)}}longitudinal identifier{p_end}
{synopt:{cmd:r(riskvar)}}msm risk-set indicator{p_end}
{synopt:{cmd:r(period)}}period variable{p_end}
{synopt:{cmd:r(regime)}}regime metadata{p_end}
{synopt:{cmd:r(method)}}producer method metadata{p_end}
{synopt:{cmd:r(contract_version)}}producer contract version{p_end}

{pstd}
{cmd:r(n_estimation)} counts observations in the estimation sample and
{cmd:r(n_excluded)} counts requested observations outside {cmd:e(sample)}, both
after {cmd:teffects}/{cmd:logit}/{cmd:probit}/{cmd:mlogit} auto-detection.

{pstd}
{cmd:r(weight_role)} is {cmd:analysis}, {cmd:treatment}, or {cmd:user-supplied}. {cmd:r(riskvar)} is set
when the producer supplies a risk-set indicator (msm). {cmd:r(id)}, {cmd:r(period)},
{cmd:r(regime)}, {cmd:r(method)}, {cmd:r(contract_version)}, and {cmd:r(riskvar)} are
posted only for longitudinal contracts ({cmd:r(longitudinal)}=1).

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_combined}

{hline}
