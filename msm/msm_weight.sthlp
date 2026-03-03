{smcl}
{* *! version 1.0.0  03mar2026}{...}
{viewerjumpto "Syntax" "msm_weight##syntax"}{...}
{viewerjumpto "Description" "msm_weight##description"}{...}
{viewerjumpto "Options" "msm_weight##options"}{...}
{viewerjumpto "Examples" "msm_weight##examples"}{...}
{viewerjumpto "Stored results" "msm_weight##results"}{...}
{viewerjumpto "Author" "msm_weight##author"}{...}

{title:Title}

{phang}
{bf:msm_weight} {hline 2} Inverse probability of treatment weights for MSM


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_weight}
{cmd:,} {opth treat_d_cov(varlist)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth treat_d_cov(varlist)}}treatment denominator covariates{p_end}

{syntab:Optional}
{synopt:{opth treat_n_cov(varlist)}}treatment numerator covariates{p_end}
{synopt:{opth censor_d_cov(varlist)}}censoring denominator covariates{p_end}
{synopt:{opth censor_n_cov(varlist)}}censoring numerator covariates{p_end}
{synopt:{opth tru:ncate(numlist)}}truncation percentiles (e.g., 1 99){p_end}
{synopt:{opt replace}}replace existing weight variables{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_weight} calculates stabilized inverse probability of treatment
weights (IPTW) and optionally inverse probability of censoring weights
(IPCW). For each person-period, it fits logistic models:

{phang2}Denominator: P(A_t | A_{t-1}, L_t, V) - full model{p_end}
{phang2}Numerator: P(A_t | A_{t-1}, V) - baseline only{p_end}

{pstd}
Period-specific weight ratios are accumulated via cumulative product
within individuals using log-sum for numerical stability. Stabilized
weights should have mean approximately 1.

{pstd}
Creates variables: {cmd:_msm_weight} (cumulative combined),
{cmd:_msm_tw_weight} (treatment weight), and optionally
{cmd:_msm_cw_weight} (censoring weight).


{marker options}{...}
{title:Options}

{phang}
{opth treat_d_cov(varlist)} specifies covariates for the treatment
denominator model. Should include time-varying confounders and baseline
covariates. Required.

{phang}
{opth treat_n_cov(varlist)} specifies covariates for the treatment
numerator model (stabilization). Typically baseline covariates only.

{phang}
{opth censor_d_cov(varlist)} specifies covariates for the censoring
denominator model. Requires {opt censor()} in {cmd:msm_prepare}.

{phang}
{opth tru:ncate(numlist)} truncates weights at specified percentiles.
Common choice: {cmd:truncate(1 99)}.


{marker examples}{...}
{title:Examples}

{pstd}IPTW only{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}

{pstd}IPTW + IPCW{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) censor_d_cov(age sex biomarker)}{p_end}
{phang2}{cmd:    truncate(1 99) nolog}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}weight standard deviation{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(n_truncated)}}number of truncated observations{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
