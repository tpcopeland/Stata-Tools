{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_diagnose##syntax"}{...}
{viewerjumpto "Description" "drest_diagnose##description"}{...}
{viewerjumpto "Options" "drest_diagnose##options"}{...}
{viewerjumpto "Examples" "drest_diagnose##examples"}{...}
{viewerjumpto "Stored results" "drest_diagnose##results"}{...}
{viewerjumpto "Author" "drest_diagnose##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:drest_diagnose} {hline 2}}Diagnostics for doubly robust estimation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_diagnose}
[{cmd:,}
{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Diagnostics}
{synopt:{opt over:lap}}propensity score overlap and effective sample size{p_end}
{synopt:{opt prop:ensity}}propensity score summary statistics{p_end}
{synopt:{opt infl:uence}}influence function diagnostics{p_end}
{synopt:{opt bal:ance}}covariate balance before/after weighting{p_end}
{synopt:{opt all}}show all diagnostics (default){p_end}

{syntab:Output}
{synopt:{opt gr:aph}}generate diagnostic plots{p_end}
{synopt:{opt sav:ing(string)}}save graphs to file{p_end}
{synopt:{opt sch:eme(string)}}graph scheme; default is {cmd:plotplainblind}{p_end}
{synopt:{opt name(string)}}graph name prefix{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_diagnose} provides diagnostic assessments after running
{cmd:drest_estimate}. It checks propensity score overlap, effective
sample size, influence function behavior, and covariate balance.


{marker options}{...}
{title:Options}

{phang}
{opt overlap} reports effective sample size and C-statistic for the treatment model.

{phang}
{opt propensity} reports propensity score summary statistics by treatment group.

{phang}
{opt influence} reports influence function distribution, outliers, and shape statistics.

{phang}
{opt balance} reports standardized mean differences for treatment model covariates,
before and after IPW weighting.

{phang}
{opt graph} generates diagnostic plots (overlap histogram, IF distribution).


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_diagnose, all}{p_end}
{phang2}{cmd:. drest_diagnose, overlap balance graph}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:drest_diagnose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(ps_mean)}}mean propensity score{p_end}
{synopt:{cmd:r(ps_sd)}}SD of propensity score{p_end}
{synopt:{cmd:r(ps_min)}}minimum propensity score{p_end}
{synopt:{cmd:r(ps_max)}}maximum propensity score{p_end}
{synopt:{cmd:r(n_extreme)}}count of extreme PS values{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(ess_pct)}}ESS as percent of N{p_end}
{synopt:{cmd:r(c_stat)}}C-statistic{p_end}
{synopt:{cmd:r(max_smd)}}maximum raw standardized mean difference{p_end}
{synopt:{cmd:r(max_smd_wt)}}maximum weighted SMD{p_end}
{synopt:{cmd:r(if_mean)}}mean of influence function{p_end}
{synopt:{cmd:r(n_outliers)}}number of IF outliers{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}
