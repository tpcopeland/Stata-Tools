{smcl}
{vieweralsosee "psdash" "help psdash"}{...}
{viewerjumpto "Syntax" "psdash_balance##syntax"}{...}
{viewerjumpto "Description" "psdash_balance##description"}{...}
{viewerjumpto "Options" "psdash_balance##options"}{...}
{viewerjumpto "Examples" "psdash_balance##examples"}{...}
{viewerjumpto "Stored results" "psdash_balance##results"}{...}
{viewerjumpto "Author" "psdash_balance##author"}{...}
{title:Title}

{p2colset 5 27 29 2}{...}
{p2col:{cmd:psdash balance} {hline 2}}Assess covariate balance before and after weighting{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:psdash balance} [{it:treatment}] [{it:psvar}] {ifin}
[{cmd:,} {it:options}]

{pstd}
See {help psdash##subcommands:Subcommand syntax} for the full signature and
{help psdash##options:Options} for every option, default, and interaction.

{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash balance} reports standardized mean differences, variance ratios,
and optional Kolmogorov-Smirnov distances. Binary-variable variances use the
Bernoulli definition, and weighted continuous variances use a scale-invariant
unbiased weighted estimator. See {help psdash##remarks:Remarks} for the method.

{pstd}
The complete stored-result contract, including {cmd:r(balance)} and
{cmd:r(smd)}, is listed under {help psdash##results:Stored results}.

{marker options}{...}
{title:Options}

{phang}
{opt cov:ariates(varlist)} specifies covariates to assess and accepts
factor-variable and interaction notation.

{phang}
{opt w:var(varname)} specifies existing adjustment weights.

{phang}
{opt match:ed} requests matched-sample standardization.

{phang}
{opt thr:eshold(#)} sets the absolute-SMD cutoff; default is {cmd:0.1}.

{phang}
{opt now:var} suppresses automatic weight construction.

{phang}
{opt now:eights} is a compatibility alias for {opt nowvar}.

{phang}
{opt ref:erence(#)} selects the multi-group reference arm.

{phang}
{opt xlsx(filename)} exports the balance table to an Excel workbook.

{phang}
{opt sheet(string)} sets the Excel sheet name.

{phang}
{opt love:plot} requests a Love plot.

{phang}
{opt sav:ing(filename)} saves the requested graph.

{phang}
{opt sch:eme(schemename)} sets the graph scheme.

{phang}
{opt graphopt:ions(string)} passes additional graph options.

{phang}
{opt f:ormat(string)} sets the displayed numeric format.

{phang}
{opt ti:tle(string)} sets the table or graph title.

{phang}
{opt name(string)} names the graph in memory.

{phang}
{opt ks} requests Kolmogorov-Smirnov distances.

{phang}
{opt esti:mand(string)} specifies {cmd:ate}, {cmd:att}, or {cmd:atc}.

{phang}
{opt smdm:atrix(name)} names a matrix that receives SMD results.

{phang}
{opt strat:egies(string)} selects displayed balance strategies.

{phang}
{opt dist:ribution(varlist)} selects covariates for distribution plots.

{phang}
{opt vrb:ounds(# #)} sets lower and upper variance-ratio cutoffs.

{phang}
{opt psv:ars(varlist)} supplies generalized propensity-score components.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash balance foreign ps, covariates(mpg weight length)}{p_end}
{phang2}{cmd:. psdash balance foreign ps, covariates(i.rep78 c.weight##c.length) nowvar}{p_end}

{marker results}{...}
{title:Stored results}

{synoptset 32 tabbed}{...}
{p2col 5 32 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations assessed{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(max_smd_raw)}}maximum raw absolute SMD{p_end}
{synopt:{cmd:r(max_smd_adj)}}maximum adjusted absolute SMD{p_end}
{synopt:{cmd:r(max_vr_raw)}}most deviant raw variance ratio{p_end}
{synopt:{cmd:r(max_vr_adj)}}most deviant adjusted variance ratio{p_end}
{synopt:{cmd:r(n_imbalanced)}}covariates above the SMD cutoff{p_end}
{synopt:{cmd:r(n_vr_imbalanced)}}variance-ratio findings{p_end}
{synopt:{cmd:r(n_vr_imbalanced_raw)}}raw variance-ratio findings{p_end}
{synopt:{cmd:r(n_vr_imbalanced_adj)}}adjusted variance-ratio findings{p_end}
{synopt:{cmd:r(n_binary_vr)}}binary covariates excluded from VR{p_end}
{synopt:{cmd:r(max_ks_raw)}}maximum raw KS distance{p_end}
{synopt:{cmd:r(max_ks_adj)}}maximum adjusted KS distance{p_end}
{synopt:{cmd:r(threshold)}}absolute-SMD cutoff used{p_end}
{synopt:{cmd:r(n_ps_boundary)}}PS values exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}PS values near 0 or 1{p_end}
{synopt:{cmd:r(n_wt_undefined)}}undefined generated weights{p_end}
{synopt:{cmd:r(n_wt_dropped)}}missing supplied weights dropped{p_end}
{synopt:{cmd:r(n_cov_incomplete)}}covariates with incomplete data{p_end}
{synopt:{cmd:r(n_cov_min)}}smallest covariate-specific sample{p_end}
{synopt:{cmd:r(K)}}number of treatment groups{p_end}
{synopt:{cmd:r(N_group_{it:<level>})}}observations in each treatment group{p_end}
{synopt:{cmd:r(n_vr_contrasts_imbalanced)}}multi-group VR findings{p_end}
{synopt:{cmd:r(n_warnings)}}machine-readable findings{p_end}
{synopt:{cmd:r(n_excluded)}}observations excluded{p_end}
{synopt:{cmd:r(n_estimation)}}estimation-sample observations assessed{p_end}

{p2col 5 32 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}input-detection source{p_end}
{synopt:{cmd:r(varlist)}}covariates assessed{p_end}
{synopt:{cmd:r(wvar)}}weight variable{p_end}
{synopt:{cmd:r(vr_na_vars)}}binary covariates excluded from VR{p_end}
{synopt:{cmd:r(cov_miss_vars)}}covariates with incomplete data{p_end}
{synopt:{cmd:r(levels)}}treatment-group levels{p_end}
{synopt:{cmd:r(reference)}}reference treatment group{p_end}
{synopt:{cmd:r(warnings)}}finding labels{p_end}

{p2col 5 32 34 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}complete balance results{p_end}
{synopt:{cmd:r(smd)}}raw and adjusted SMDs{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online:  {helpb psdash}, {helpb psdash_overlap}, {helpb psdash_weights}

{hline}
