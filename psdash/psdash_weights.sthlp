{smcl}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "psdash_weights##syntax"}{...}
{viewerjumpto "Description" "psdash_weights##description"}{...}
{viewerjumpto "Options" "psdash_weights##options"}{...}
{viewerjumpto "Examples" "psdash_weights##examples"}{...}
{viewerjumpto "Stored results" "psdash_weights##results"}{...}
{viewerjumpto "Author" "psdash_weights##author"}{...}
{title:Title}

{p2colset 5 27 29 2}{...}
{p2col:{cmd:psdash weights} {hline 2}}Assess propensity-score weight stability{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:psdash weights} [{it:treatment}] [{it:psvar}] {ifin}
[{cmd:,} {it:options}]

{pstd}
See {help psdash##subcommands:Subcommand syntax} for the full signature and
{help psdash##options:Options} for every option, default, and interaction.

{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash weights} reports weight location, dispersion, effective sample
size, tail counts, and arm-specific ESS. It can also trim, truncate, or
stabilize weights into a new variable while leaving the source weights
unchanged.

{pstd}
The complete stored-result contract, including modification diagnostics and
machine-readable positivity findings, is listed under
{help psdash##results:Stored results}.

{marker options}{...}
{title:Options}

{phang}
{opt w:var(varname)} specifies existing diagnostic weights.

{phang}
{opt trim(#)} caps weights at the requested percentile.

{phang}
{opt trunc:ate(#)} truncates weights at the requested upper value.

{phang}
{opt stab:ilize} requests stabilized weights.

{phang}
{opt gen:erate(newvar)} names the modified-weight variable.

{phang}
{opt replace} permits replacing the requested generated variable.

{phang}
{opt ref:erence(#)} selects the multi-group reference arm.

{phang}
{opt det:ail} displays percentile and arm-specific diagnostics.

{phang}
{opt gr:aph} requests a weight-distribution graph.

{phang}
{opt compact} scales each treatment arm's histogram to within-arm fractions
instead of raw frequencies. This is useful in compact dashboards and when arm
sample sizes differ.

{phang}
{opt sav:ing(filename)} saves the graph.

{phang}
{opt xlabel(numlist)} sets graph x-axis labels.

{phang}
{opt sch:eme(schemename)} sets the graph scheme.

{phang}
{opt graphopt:ions(string)} passes additional graph options.

{phang}
{opt name(string)} names the graph in memory.

{phang}
{opt xlsx(filename)} exports weight statistics to Excel.

{phang}
{opt sheet(string)} sets the Excel sheet name.

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc}.

{phang}
{opt ext:reme(# #)} sets the two extreme-weight cutoffs.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{phang}
{opt iivwc:omponent(string)} selects the iivw weight component.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash weights foreign ps, detail}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations assessed{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(mean_wt)}}mean weight{p_end}
{synopt:{cmd:r(sd_wt)}}weight standard deviation{p_end}
{synopt:{cmd:r(min_wt)}}minimum weight{p_end}
{synopt:{cmd:r(max_wt)}}maximum weight{p_end}
{synopt:{cmd:r(cv)}}weight coefficient of variation{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(ess_pct)}}ESS percentage{p_end}
{synopt:{cmd:r(ess_treated)}}treated-arm ESS{p_end}
{synopt:{cmd:r(ess_control)}}control-arm ESS{p_end}
{synopt:{cmd:r(ess_pct_treated)}}treated-arm ESS percentage{p_end}
{synopt:{cmd:r(ess_pct_control)}}control-arm ESS percentage{p_end}
{synopt:{cmd:r(n_extreme)}}weights above the lower cutoff{p_end}
{synopt:{cmd:r(pct_extreme)}}percent above the lower cutoff{p_end}
{synopt:{cmd:r(max_ratio)}}maximum-to-mean weight ratio{p_end}
{synopt:{cmd:r(extreme_hi)}}lower extreme-weight cutoff{p_end}
{synopt:{cmd:r(extreme_vhi)}}upper extreme-weight cutoff{p_end}
{synopt:{cmd:r(p1)}}first weight percentile{p_end}
{synopt:{cmd:r(p5)}}fifth weight percentile{p_end}
{synopt:{cmd:r(p95)}}95th weight percentile{p_end}
{synopt:{cmd:r(p99)}}99th weight percentile{p_end}
{synopt:{cmd:r(n_ps_boundary)}}PS values exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}PS values near 0 or 1{p_end}
{synopt:{cmd:r(n_wt_undefined)}}undefined generated weights{p_end}
{synopt:{cmd:r(n_wt_dropped)}}observations dropped from weights{p_end}
{synopt:{cmd:r(new_mean)}}modified-weight mean{p_end}
{synopt:{cmd:r(new_sd)}}modified-weight standard deviation{p_end}
{synopt:{cmd:r(new_min)}}modified-weight minimum{p_end}
{synopt:{cmd:r(new_max)}}modified-weight maximum{p_end}
{synopt:{cmd:r(new_cv)}}modified-weight coefficient of variation{p_end}
{synopt:{cmd:r(new_ess)}}modified-weight ESS{p_end}
{synopt:{cmd:r(new_ess_pct)}}modified-weight ESS percentage{p_end}
{synopt:{cmd:r(K)}}number of treatment groups{p_end}
{synopt:{cmd:r(N_group_{it:<level>})}}observations in each group{p_end}
{synopt:{cmd:r(ess_group_{it:<level>})}}ESS in each treatment group{p_end}
{synopt:{cmd:r(ess_pct_group_{it:<level>})}}ESS percentage in each group{p_end}
{synopt:{cmd:r(n_warnings)}}machine-readable findings{p_end}
{synopt:{cmd:r(n_excluded)}}observations excluded{p_end}
{synopt:{cmd:r(n_estimation)}}estimation-sample observations assessed{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(generate)}}generated weight variable{p_end}
{synopt:{cmd:r(wvar)}}weight variable{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(iivwcomponent)}}selected iivw component{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels{p_end}
{synopt:{cmd:r(reference)}}reference treatment group{p_end}
{synopt:{cmd:r(warnings)}}finding labels{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_balance}, {helpb psdash_support}

{hline}
