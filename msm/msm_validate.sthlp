{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_validate##syntax"}{...}
{viewerjumpto "Description" "msm_validate##description"}{...}
{viewerjumpto "Options" "msm_validate##options"}{...}
{viewerjumpto "Stored results" "msm_validate##results"}{...}
{viewerjumpto "Examples" "msm_validate##examples"}{...}
{viewerjumpto "Author" "msm_validate##author"}{...}

{title:Title}

{phang}
{bf:msm_validate} {hline 2} Data quality checks for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_validate}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt str:ict}}treat warnings as errors{p_end}
{synopt:{opt ver:bose}}show detailed diagnostics{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_validate} runs 10 data quality checks on prepared person-period
data. It must be run after {cmd:msm_prepare}, which sets the required data
characteristics (id, period, treatment, outcome, covariates).

{pstd}
The 10 checks are:

{phang2}1. {bf:Person-period format} {hline 2} exactly one row per id-period combination{p_end}
{phang2}2. {bf:No gaps in period sequences} {hline 2} consecutive periods within each individual{p_end}
{phang2}3. {bf:Outcome is terminal} {hline 2} no rows exist after the outcome event{p_end}
{phang2}4. {bf:Treatment variation} {hline 2} both treated and untreated observations exist{p_end}
{phang2}5. {bf:Missing data} {hline 2} checks id, period, treatment, outcome, censor, and covariates{p_end}
{phang2}6. {bf:Sufficient observations per period} {hline 2} warns if any period has fewer than 10 obs{p_end}
{phang2}7. {bf:Covariate completeness} {hline 2} all covariates have non-missing values and variation{p_end}
{phang2}8. {bf:Treatment history patterns} {hline 2} reports always-treated, never-treated, and switchers{p_end}
{phang2}9. {bf:Censoring patterns} {hline 2} checks censoring is terminal (no rows after censoring){p_end}
{phang2}10. {bf:Positivity by period} {hline 2} both treatment values exist in every period{p_end}

{pstd}
Checks 2, 3, 5, 9, and 10 produce warnings by default. With {opt strict},
these become errors and the command exits with error code 198 if any fail.


{marker options}{...}
{title:Options}

{phang}
{opt strict} treats warnings as errors. When specified, any check that would
normally produce a warning instead produces an error, and the command exits
with return code 198 if one or more errors are found. Use this to enforce
strict data quality before proceeding to {cmd:msm_weight}.

{phang}
{opt verbose} displays detailed diagnostics for checks that detect issues.
For example, it reports the number of individuals with gaps (check 2),
lists specific missing variables (check 5), and identifies periods that
violate positivity (check 10).


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_validate} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_checks)}}number of checks run (always 10){p_end}
{synopt:{cmd:r(n_errors)}}number of checks that failed{p_end}
{synopt:{cmd:r(n_warnings)}}number of checks that produced warnings{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(validation)}}{cmd:"passed"} if no errors, {cmd:"failed"} otherwise{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_validate}{p_end}
{phang2}{cmd:. msm_validate, strict verbose}{p_end}

{pstd}
Typical workflow:

{phang2}{cmd:. msm_prepare id period treatment outcome, covariates(age sex) censor(censored)}{p_end}
{phang2}{cmd:. msm_validate}{p_end}
{phang2}{cmd:. msm_validate, strict}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}
