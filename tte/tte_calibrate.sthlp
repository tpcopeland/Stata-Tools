{smcl}
{* *! version 1.0.0  10mar2026}{...}
{viewerjumpto "Syntax" "tte_calibrate##syntax"}{...}
{viewerjumpto "Description" "tte_calibrate##description"}{...}
{viewerjumpto "Options" "tte_calibrate##options"}{...}
{viewerjumpto "Examples" "tte_calibrate##examples"}{...}
{viewerjumpto "Technical notes" "tte_calibrate##technical"}{...}
{viewerjumpto "Stored results" "tte_calibrate##results"}{...}
{viewerjumpto "References" "tte_calibrate##references"}{...}
{viewerjumpto "Author" "tte_calibrate##author"}{...}

{title:Title}

{phang}
{bf:tte_calibrate} {hline 2} Negative control outcome calibration


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_calibrate}{cmd:,}
{opth est:imate(#)}
{opth se(#)}
{opth nco_estimates(matname)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt est:imate(#)}}primary log-effect estimate (required){p_end}
{synopt:{opt se(#)}}standard error of primary estimate (required){p_end}
{synopt:{opth nco_estimates(matname)}}Nx2 matrix of NCO estimates (required){p_end}
{synopt:{opth met:hod(string)}}systematic error distribution; default is {cmd:normal}{p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt null(#)}}null hypothesis value; default is {cmd:0}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_calibrate} calibrates a treatment effect estimate using negative
control outcomes (NCOs). It implements the empirical calibration algorithm
described by Schuemie et al. (2014), as used in the OHDSI
EmpiricalCalibration R package.

{pstd}
Negative control outcomes are outcomes believed to have no causal relationship
with the treatment. Any observed association between the treatment and an NCO
is therefore attributable to systematic error (confounding, measurement error,
selection bias, etc.). By estimating the distribution of systematic error from
a set of NCOs, the primary estimate can be adjusted to account for this error,
and confidence intervals can be widened to reflect the additional uncertainty.

{pstd}
This command is standalone and does not require a {cmd:tte_expand}ed dataset.
It operates on summary statistics: the primary point estimate, its standard
error, and a matrix of NCO estimates and standard errors.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt estimate(#)} specifies the primary treatment effect estimate on the
log scale (e.g., log-odds ratio from pooled logistic regression or
log-hazard ratio from a Cox model).

{phang}
{opt se(#)} specifies the standard error of the primary estimate.

{phang}
{opth nco_estimates(matname)} specifies an Nx2 Stata matrix containing the
negative control outcome estimates. Column 1 holds the log-effect estimate
for each NCO, and column 2 holds the corresponding standard error. At least
3 NCOs are required.

{dlgtab:Optional}

{phang}
{opt method(string)} specifies the parametric family for the systematic
error distribution. Currently only {cmd:normal} is supported, which models
systematic error as N(bias, sigma^2).

{phang}
{opt level(#)} sets the confidence level for both calibrated and
uncalibrated intervals. The default is {cmd:95}.

{phang}
{opt null(#)} specifies the null hypothesis value for the p-value
calculation. The default is 0 (no effect on the log scale).


{marker examples}{...}
{title:Examples}

{pstd}Basic calibration with 5 negative controls{p_end}
{phang2}{cmd:. matrix nco = (0.02, 0.15 \ -0.05, 0.12 \ 0.08, 0.18 \ -0.01, 0.14 \ 0.03, 0.16)}{p_end}
{phang2}{cmd:. tte_calibrate, estimate(-0.35) se(0.12) nco_estimates(nco)}{p_end}

{pstd}With 90% confidence level{p_end}
{phang2}{cmd:. tte_calibrate, estimate(-0.35) se(0.12) nco_estimates(nco) level(90)}{p_end}

{pstd}Typical workflow after {cmd:tte_fit}{p_end}
{phang2}{cmd:. * Fit the primary outcome model}{p_end}
{phang2}{cmd:. tte_fit, outcome_cov(age sex) nolog}{p_end}
{phang2}{cmd:. local b_primary = _b[_tte_arm]}{p_end}
{phang2}{cmd:. local se_primary = _se[_tte_arm]}{p_end}
{phang2}{cmd:. * Run same model specification on each NCO and collect estimates}{p_end}
{phang2}{cmd:. * ... (store in matrix nco_results) ...}{p_end}
{phang2}{cmd:. tte_calibrate, estimate(`b_primary') se(`se_primary') nco_estimates(nco_results)}{p_end}


{marker technical}{...}
{title:Technical notes}

{dlgtab:Algorithm}

{pstd}
The algorithm models each negative control estimate b_k as drawn from a
normal distribution:

{pmore}
b_k ~ N(bias, se_k^2 + sigma^2)

{pstd}
where bias is the mean systematic error, se_k is the standard error of
the k-th NCO estimate, and sigma^2 is the variance of the systematic
error distribution. The parameters (bias, sigma^2) are estimated by
maximum likelihood.

{dlgtab:Profile likelihood optimization}

{pstd}
The log-likelihood is:

{pmore}
LL(bias, sigma^2) = -0.5 * sum_k [ log(se_k^2 + sigma^2) + (b_k - bias)^2 / (se_k^2 + sigma^2) ]

{pstd}
For any fixed sigma^2, the MLE for bias is the inverse-variance weighted
mean of the NCO estimates, with weights w_k = 1/(se_k^2 + sigma^2). This
closed-form solution allows profiling out bias, reducing the problem to a
one-dimensional optimization over sigma^2.

{pstd}
The profile likelihood for sigma^2 is maximized by first evaluating on a
grid of 1,000 equally spaced values over [0, Var(b_k)], then refining the
optimum via golden section search to a precision of 1e-8.

{dlgtab:Calibration}

{pstd}
Given the fitted (bias, sigma^2), the calibrated estimate and standard
error are:

{pmore}
calibrated estimate = primary estimate - bias{break}
calibrated SE = sqrt(primary SE^2 + sigma^2)

{pstd}
The calibrated confidence interval is symmetric on the log scale:

{pmore}
calibrated CI = calibrated estimate +/- z * calibrated SE

{pstd}
The calibrated p-value tests the null hypothesis (default: 0):

{pmore}
calibrated p = 2 * Phi(-|calibrated estimate - null| / calibrated SE)

{dlgtab:Interpretation}

{pstd}
If NCO estimates cluster near zero with no excess variance, the bias and
sigma will both be near zero, and calibrated results will be very close to
the uncalibrated results. If NCOs show systematic bias or excess dispersion,
the calibrated estimate will be shifted and the confidence interval widened.

{pstd}
At least 3 NCOs are required for identifiability. In practice, 30 or more
NCOs provide more stable estimates. The NCOs should span the range of
potential confounding structures present in the study.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_calibrate} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(estimate)}}primary estimate (uncalibrated){p_end}
{synopt:{cmd:r(se)}}primary SE (uncalibrated){p_end}
{synopt:{cmd:r(ci_lo)}}uncalibrated CI lower bound{p_end}
{synopt:{cmd:r(ci_hi)}}uncalibrated CI upper bound{p_end}
{synopt:{cmd:r(pvalue)}}uncalibrated p-value{p_end}
{synopt:{cmd:r(bias)}}estimated systematic bias{p_end}
{synopt:{cmd:r(sigma)}}estimated systematic error SD{p_end}
{synopt:{cmd:r(n_nco)}}number of negative control outcomes{p_end}
{synopt:{cmd:r(cal_estimate)}}calibrated estimate{p_end}
{synopt:{cmd:r(cal_se)}}calibrated SE{p_end}
{synopt:{cmd:r(cal_ci_lo)}}calibrated CI lower bound{p_end}
{synopt:{cmd:r(cal_ci_hi)}}calibrated CI upper bound{p_end}
{synopt:{cmd:r(cal_pvalue)}}calibrated p-value{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(method)}}systematic error distribution method{p_end}


{marker references}{...}
{title:References}

{phang}
Schuemie MJ, Ryan PB, DuMouchel W, Suchard MA, Madigan D. Interpreting
observational studies: why empirical calibration is needed to correct
p-values. {it:Statistics in Medicine}. 2014;33(2):209-218.
doi:10.1002/sim.5925
{p_end}

{phang}
Schuemie MJ, Hripcsak G, Ryan PB, Madigan D, Suchard MA. Empirical
confidence interval calibration for population-level effect estimation
studies in observational healthcare data. {it:Proceedings of the National}
{it:Academy of Sciences}. 2018;115(11):2571-2577.
doi:10.1073/pnas.1708282114
{p_end}

{phang}
OHDSI. EmpiricalCalibration: Routines for performing empirical calibration
of observational study estimates. R package.
{browse "https://ohdsi.github.io/EmpiricalCalibration/"}
{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet
