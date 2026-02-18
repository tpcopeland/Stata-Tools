{smcl}
{* *! version 1.0.1  18feb2026}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{vieweralsosee "tvplot" "help tvplot"}{...}
{viewerjumpto "Syntax" "tvbalance##syntax"}{...}
{viewerjumpto "Description" "tvbalance##description"}{...}
{viewerjumpto "Options" "tvbalance##options"}{...}
{viewerjumpto "Examples" "tvbalance##examples"}{...}
{viewerjumpto "Stored results" "tvbalance##results"}{...}
{viewerjumpto "Author" "tvbalance##author"}{...}

{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:tvbalance} {hline 2}}Balance diagnostics for time-varying exposure data{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvbalance}
{varlist}
{cmd:,} {opt exp:osure(varname)}
[{it:options}]


{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{it:varlist}}covariates to assess balance{p_end}
{synopt:{opt exp:osure(varname)}}exposure variable (binary or categorical){p_end}

{syntab:Options}
{synopt:{opt w:eights(varname)}}IPTW or other weights for weighted balance{p_end}
{synopt:{opt thr:eshold(#)}}SMD threshold for imbalance flag; default is 0.1{p_end}
{synopt:{opt id(varname)}}person identifier variable{p_end}
{synopt:{opt love:plot}}generate Love plot of SMD values{p_end}
{synopt:{opt sav:ing(filename)}}save Love plot to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvbalance} calculates standardized mean differences (SMD) to assess
covariate balance between exposure groups in time-varying exposure data.
It is useful for:

{phang2}
1. Checking baseline balance between treatment groups

{phang2}
2. Assessing the quality of inverse probability of treatment weights (IPTW)

{phang2}
3. Identifying covariates that require adjustment in analysis

{pstd}
The standardized mean difference is calculated as:

{p 8 8 2}
SMD = (mean_exposed - mean_reference) / pooled_SD

{pstd}
where pooled_SD is the square root of the average of the two group variances.
An |SMD| greater than the threshold (default 0.1) is conventionally
considered indicative of meaningful imbalance.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{it:varlist} specifies the numeric covariates for which balance should be
assessed. These are typically potential confounders.

{phang}
{opt exposure(varname)} specifies the exposure variable. For binary exposures,
the lower value is treated as the reference group. For categorical exposures
with more than 2 levels, all non-reference levels are pooled.

{dlgtab:Options}

{phang}
{opt weights(varname)} specifies inverse probability of treatment weights
(IPTW) or other weights. When specified, both unweighted and weighted
SMD values are reported, along with effective sample sizes.

{phang}
{opt threshold(#)} specifies the SMD threshold above which imbalance is
flagged. The default is 0.1 (10% of a standard deviation), which is a
commonly used threshold in propensity score literature.

{phang}
{opt id(varname)} specifies the person identifier variable. This is
currently reserved for future features involving person-level summaries.

{phang}
{opt loveplot} generates a Love plot showing SMD values for each covariate.
Vertical dashed lines indicate the threshold boundaries.

{phang}
{opt saving(filename)} saves the Love plot to the specified file.
The file extension determines the format (e.g., .png, .pdf).

{phang}
{opt replace} allows an existing file to be overwritten when using
{opt saving()}.


{marker examples}{...}
{title:Examples}

{pstd}Setup: Create time-varying exposure dataset with covariates{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using medications, id(id) start(rx_start) stop(rx_stop) exposure(drug) reference(0) entry(study_entry) exit(study_exit)}{p_end}

{pstd}Basic balance check{p_end}
{phang2}{cmd:. tvbalance age sex comorbidity_score, exposure(tv_exposure)}{p_end}

{pstd}Balance with IPTW weights{p_end}
{phang2}{cmd:. * First create IPTW weights (external to tvbalance)}{p_end}
{phang2}{cmd:. logit tv_exposure age sex comorbidity_score}{p_end}
{phang2}{cmd:. predict ps, pr}{p_end}
{phang2}{cmd:. gen iptw = cond(tv_exposure==1, 1/ps, 1/(1-ps))}{p_end}
{phang2}{cmd:. tvbalance age sex comorbidity_score, exposure(tv_exposure) weights(iptw)}{p_end}

{pstd}Generate Love plot with stricter threshold{p_end}
{phang2}{cmd:. tvbalance age sex comorbidity_score, exposure(tv_exposure) weights(iptw) threshold(0.05) loveplot}{p_end}

{pstd}Save Love plot{p_end}
{phang2}{cmd:. tvbalance age sex, exposure(tv_exposure) loveplot saving(balance.png) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvbalance} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_ref)}}number of observations in reference group{p_end}
{synopt:{cmd:r(n_exp)}}number of observations in exposed group{p_end}
{synopt:{cmd:r(n_covariates)}}number of covariates assessed{p_end}
{synopt:{cmd:r(n_imbalanced)}}number of imbalanced covariates (unweighted){p_end}
{synopt:{cmd:r(threshold)}}SMD threshold used{p_end}
{synopt:{cmd:r(n_imbalanced_wt)}}number of imbalanced covariates (weighted; if weights specified){p_end}
{synopt:{cmd:r(ess_ref)}}effective sample size, reference group (if weights specified){p_end}
{synopt:{cmd:r(ess_exp)}}effective sample size, exposed group (if weights specified){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(exposure)}}name of exposure variable{p_end}
{synopt:{cmd:r(weights)}}name of weights variable (if specified){p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}matrix of balance statistics (Mean_Ref, Mean_Exp, SMD_Unwt, SMD_Wt){p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}
Timothy Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}


{marker references}{...}
{title:References}

{pstd}
Austin PC. Balance diagnostics for comparing the distribution of baseline
covariates between treatment groups in propensity-score matched samples.
Statistics in Medicine. 2009;28(25):3083-3107.

{pstd}
Stuart EA. Matching methods for causal inference: A review and a look forward.
Statistical Science. 2010;25(1):1-21.


{marker alsosee}{...}
{title:Also see}

{psee}
{help tvexpose}, {help tvdiagnose}, {help tvplot}
{p_end}
