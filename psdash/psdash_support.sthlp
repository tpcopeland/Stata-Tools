{smcl}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "psdash_support##syntax"}{...}
{viewerjumpto "Description" "psdash_support##description"}{...}
{viewerjumpto "Options" "psdash_support##options"}{...}
{viewerjumpto "Examples" "psdash_support##examples"}{...}
{viewerjumpto "Stored results" "psdash_support##results"}{...}
{viewerjumpto "Author" "psdash_support##author"}{...}
{title:Title}

{p2colset 5 27 29 2}{...}
{p2col:{cmd:psdash support} {hline 2}}Assess and optionally mark common support{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:psdash support} [{it:treatment}] [{it:psvar}] {ifin}
[{cmd:,} {it:options}]

{pstd}
See {help psdash##subcommands:Subcommand syntax} for the full signature and
{help psdash##options:Options} for every option, default, and interaction.

{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash support} reports common-support bounds and can mark observations
retained by a trimming rule. Binary treatments support Crump's
variance-oriented rule; multi-valued treatments use a full-vector generalized
propensity-score floor. The Crump search selects the first empirical
inequality crossing on an ascending 0.001 grid from 0.001 through 0.500,
including retained endpoints. No nonempty crossing on the grid produces error
498. It can return alpha = 0 only when every assessed score is strictly inside
(0,1) and the full-sample inequality holds; exact boundary scores instead
require positive-threshold handling. A sample with no interior score fails the
retained-sample guard.

{pstd}
The complete return contract, including {cmd:r(crump_alpha)} and the
multi-group {cmd:r(gps_means)} matrix, is listed under
{help psdash##results:Stored results}.

{pstd}
Detailed multi-group graphs use one data-driven x axis per GPS component. A
practical-positivity floor line is drawn only when it lies within that
component's observed range, and three-component graphs occupy one filled
row. For a binary treatment, the dashed lines for the common-support and
trimming bounds each carry a legend key.

{marker options}{...}
{title:Options}

{phang}
{opt cov:ariates(varlist)} supplies covariates for comparison diagnostics and
accepts factor-variable and interaction notation.

{phang}
{opt crump} requests Crump's binary-treatment trimming rule. It cannot be
combined with {opt threshold()} and is available for binary treatment only. If
no propensity score lies strictly inside (0,1), the rule is undefined and
the command exits with error 459.

{phang}
{opt thr:eshold(#)} sets a fixed PS or GPS trimming threshold. It must be
strictly between 0 and 0.5; any other value is an error. It cannot be combined
with {opt crump}.

{phang}
{opt qtrim(#)} sets within-group quantile-based common-support bounds. It is
binary-only, has no effect unless specified, and must be strictly between 0
and 50; any other value is an error.

{phang}
{opt gpsfloor(#)} sets the multi-group practical-positivity floor; default is
{cmd:0.01}, and the value must be strictly between 0 and 1.

{phang}
{opt gen:erate(newvar)} marks observations retained by the selected rule. It
may not name a variable in {opt covariates()} (or, with {opt compare}, a
detected covariate), including the base variable of a factor-variable term. The
variable is created only after the support and {opt compare}
computations succeed, so an error there leaves an existing {opt replace}
target untouched and creates no new variable.

{phang}
{opt replace} permits replacing the requested generated variable.

{phang}
{opt comp:are} compares diagnostics before and after trimming. It requires
{opt crump} or {opt threshold()} and is available for binary treatment only. When
covariates are supplied or detected, the trimmed sample must keep at
least two observations per arm; otherwise the command exits with error 459. The
pre/post ESS uses estimand-specific IPTW weights. An observation whose
weight is undefined (a treated observation with PS exactly 0 under ATE or ATC,
a control with PS exactly 1 under ATE or ATT) is left out of the ESS, and a
note reports how many were excluded.

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
{opt xlsx(filename)} exports support statistics to Excel.

{phang}
{opt sheet(string)} sets the Excel sheet name: at most 31 bytes (a multibyte
character counts each byte), none of {cmd::} {cmd:\} {cmd:/} {cmd:?} {cmd:*} {cmd:[} {cmd:]} or a double quote, no
leading or trailing apostrophe, and not the reserved name {cmd:History} (in any
case). It is checked before any computation; an invalid name is an error
({cmd:r(198)}).

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc}.

{phang}
{opt ref:erence(#)} selects the multi-group reference arm. For a treatment coded 0/1
only {cmd:reference(0)} is allowed.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{phang}
{opt compact} replaces the detailed multi-group component density panels with
one box-plot region of the minimum GPS component by observed treatment arm, with
one box colour per arm (the same colours as the density graphs) and a note that
names the dashed red positivity floor line. It has no effect for binary
treatments.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash support foreign ps, crump nograph}{p_end}
{phang2}{cmd:. psdash support foreign ps, threshold(.05) compare covariates(i.rep78 c.weight##c.length) nograph}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations assessed{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(lower_bound)}}lower common-support bound{p_end}
{synopt:{cmd:r(upper_bound)}}upper common-support bound{p_end}
{synopt:{cmd:r(qtrim)}}quantile percentage, when specified{p_end}
{synopt:{cmd:r(n_outside)}}observations outside support{p_end}
{synopt:{cmd:r(pct_outside)}}percent outside support{p_end}
{synopt:{cmd:r(n_outside_treated)}}treated outside support{p_end}
{synopt:{cmd:r(n_outside_control)}}controls outside support{p_end}
{synopt:{cmd:r(trim_lower)}}lower trimming bound or GPS floor{p_end}
{synopt:{cmd:r(trim_upper)}}upper bound, binary trimming{p_end}
{synopt:{cmd:r(n_trimmed)}}observations trimmed{p_end}
{synopt:{cmd:r(pct_trimmed)}}percent trimmed{p_end}
{synopt:{cmd:r(N_remaining)}}observations retained{p_end}
{synopt:{cmd:r(crump_alpha)}}Crump alpha, when crump{p_end}
{synopt:{cmd:r(n_ps_boundary)}}PS values exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}PS values near 0 or 1{p_end}
{synopt:{cmd:r(n_post)}}post-trimming observations{p_end}
{synopt:{cmd:r(pct_outside_pre)}}pre-trimming percent outside{p_end}
{synopt:{cmd:r(pct_outside_post)}}post-trimming percent outside{p_end}
{synopt:{cmd:r(ess_pct_pre)}}pre-trimming ESS percentage{p_end}
{synopt:{cmd:r(ess_pct_post)}}post-trimming ESS percentage{p_end}
{synopt:{cmd:r(max_smd_pre)}}pre-trimming maximum SMD{p_end}
{synopt:{cmd:r(max_smd_post)}}post-trimming maximum SMD{p_end}
{synopt:{cmd:r(K)}}number of treatment groups{p_end}
{synopt:{cmd:r(N_group_{it:<level>})}}observations in each group{p_end}
{synopt:{cmd:r(n_outside_group_{it:<level>})}}outside-support count by group{p_end}
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
{synopt:{cmd:r(estimand)}}target estimand, lowercase{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels{p_end}
{synopt:{cmd:r(reference)}}reference treatment group{p_end}
{synopt:{cmd:r(warnings)}}finding labels{p_end}

{p2col 5 32 34 2: Matrices}{p_end}
{synopt:{cmd:r(gps_means)}}mean GPS by observed arm and component{p_end}

{pstd}
{cmd:r(max_smd_pre)} and {cmd:r(max_smd_post)} are missing when no covariate
has a defined SMD.
{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_overlap}, {helpb psdash_weights}

{hline}
