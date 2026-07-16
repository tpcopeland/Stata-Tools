{smcl}
{vieweralsosee "finegray" "help finegray"}{...}
{vieweralsosee "finegray_cif" "help finegray_cif"}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "finegray_phtest##syntax"}{...}
{viewerjumpto "Description" "finegray_phtest##description"}{...}
{viewerjumpto "Options" "finegray_phtest##options"}{...}
{viewerjumpto "Examples" "finegray_phtest##examples"}{...}
{viewerjumpto "Stored results" "finegray_phtest##results"}{...}
{viewerjumpto "References" "finegray_phtest##references"}{...}
{viewerjumpto "Author" "finegray_phtest##author"}{...}
{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:finegray_phtest} {hline 2}}Approximate proportional subdistribution hazards diagnostic{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 26 2}
{cmd:finegray_phtest}
[{cmd:,} {it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt time(function)}}time function: {cmd:rank} (default), {cmd:log}, or {cmd:identity}{p_end}
{synopt:{opt det:ail}}display scaled Schoenfeld residuals{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray_phtest} provides an approximate diagnostic for the proportional
subdistribution hazards (PSH) assumption after {helpb finegray}. It computes
diagonal-scaled Schoenfeld residuals at cause-event times and correlates each
residual series with a function of time.

{pstd}
Time patterns in the residuals suggest that a covariate's effect may change
over time. The reported chi-squared statistics and p-values are screening
summaries, not formally calibrated subdistribution-hazard tests; see
{it:Statistical scope} below.

{pstd}
{bf:Left truncation (delayed entry).} The weighted risk sets underlying the
Schoenfeld residuals use Zhang-Zhang-Fine Weight 1, not a censoring-only
weight. With one weight stratum this is the equivalent Geskus product-limit
factor A = G(t-)H(t-); with multiple strata it uses the equation-7 pooled
time-side stabilizer and stratum-specific subject denominators. Different
censoring and entry groupings use the package's factorized cross-classification,
and the finite-sample tie rule is package-defined. Under delayed entry the
residuals and diagnostic summaries differ from the right-censoring path and
from {helpb stcrreg}. See
{help finegray##lt:Left truncation} in {helpb finegray}.

{pstd}
{bf:A converged fit is required.} {cmd:finegray} reports a nonconverged model rather than
erroring, leaving {cmd:e(converged)} at 0, so {cmd:e(b)} exists but holds the last iterate
rather than a solution. Schoenfeld residuals taken at a non-solution do not
have the fitted score property, so the diagnostic is meaningless and
{cmd:finegray_phtest} exits with {cmd:r(430)} when {cmd:e(converged)} is not 1. Refit
with a larger {opt iterate()} or a different specification.

{pstd}
{bf:Statistical scope.} For each covariate, the command multiplies its raw
Schoenfeld residual by the corresponding diagonal element of the inverse
observed-information matrix. It then calculates the residual-time correlation
rho and reports n*rho^2 against a one-degree-of-freedom chi-squared
reference. Each row is a separate marginal test.

{pstd}
This construction is inspired by weighted-residual diagnostics for Cox models,
but it does not implement the full Grambsch-Therneau transformation or a
published subdistribution-hazard calibration. The marginal p-values are
therefore approximate. Use the residual pattern and sensitivity across
{opt time()} choices as diagnostic evidence, not as a stand-alone accept/reject
procedure.

{marker global}{...}
{pstd}
{bf:Global test.} {cmd:finegray_phtest} reports {bf:no omnibus test}, and has not
since version 1.2.0. Earlier versions printed a {it:Global test} row holding the
sum of the per-covariate 1-df statistics, referred to a chi-squared with {it:p}
degrees of freedom. That reference distribution is correct only if the
components are independent. Scaled Schoenfeld residuals are correlated whenever
the covariates are, so the sum is not chi-squared({it:p}): the printed
probability had no stated null distribution and its error ran in an unknown
direction. It was removed rather than relabeled.

{pstd}
The apparent repair does not transfer to this estimator. Grambsch and Therneau
(1994) build a joint statistic for the {it:Cox} model whose null covariance is
the Cox information -- an identity that holds because the Cox score is a
martingale integral. {cmd:finegray}'s score is IPCW-weighted with an {it:estimated}
censoring distribution, so its variance is a sandwich carrying an additional
term for that estimation (Fine and Gray 1999, eq. 7-8; Bellach et al. 2019,
sec. 3.3, "this additional variability cannot be ignored"). That is precisely why
{cmd:finegray} itself defaults to {opt vce(robust)} rather than the inverse
information. Reusing the information as a null covariance here would restate the
original defect -- an unstated reference distribution -- in a form that merely
looks rigorous.

{pstd}
No published omnibus test for the proportional {it:subdistribution} hazards
assumption is implemented. Candidates exist -- Zhou et al. (2013) give a score
test on modified Schoenfeld residuals, and Li, Scheike and Zhang (2015) a
cumulative-sums-of-residuals test with simulated p-values -- but neither is
implemented or validated here. PSHREG (Kohl et al. 2015), the closest reference
implementation for this model, likewise reports only per-covariate correlation
tests and residual plots. If a single global claim is needed, Bonferroni-adjust
across the {it:p} rows reported below, or fit the time-interaction model
directly and test the interaction terms.

{pstd}
The test is only defined where it can be computed. If every cause event occurs
at a single time, the time function is constant and no correlation
exists: {cmd:finegray_phtest} exits with {cmd:r(459)} rather than reporting a blank
chi-squared. The same applies to any individual term whose scaled residuals do
not vary across cause-event times.

{pstd}
{cmd:finegray_phtest} reads the package-owned {cmd:_fg_*} factor-variable columns by
name. If they have been {it:dropped}, they are rebuilt on demand and the test
proceeds as normal. If one is still present but has been {it:altered}, the test
would silently be computed against a design the model was never fitted to, so
{cmd:finegray_phtest} exits with {cmd:r(459)} and {cmd:finegray} must be re-run. Output and
{cmd:r(phtest)} rownames use the underlying factor term names, not the internal
{cmd:_fg_*} names.

{pstd}
{bf:Data requirement:} {cmd:finegray_phtest} computes Schoenfeld residuals on
the estimation sample and therefore requires the unchanged original {cmd:stset}
data. It verifies a signature covering {cmd:_t}, {cmd:_t0}, {cmd:_d}, the event
type, covariates, strata, cluster, and any persisted entry-time variable. If
those data have changed, it exits with {cmd:r(459)}; re-run
{cmd:finegray}. Unlike {cmd:finegray_predict, xb}, it cannot be run after
loading a new dataset.


{marker options}{...}
{title:Options}

{phang}
{opt time(function)} specifies the time function used in the correlation
test. {cmd:rank} (the default) uses the rank of event times. {cmd:log} uses
log(time). {cmd:identity} uses raw event times. The rank transformation is
less sensitive to extreme event times and is the default screening choice.

{phang}
{opt detail} displays the first 20 rows of the scaled Schoenfeld residual matrix.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup}

{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}
{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}

{pstd}
{bf:Default proportionality diagnostic (rank of time)}

{phang2}{cmd:. finegray_phtest}{p_end}

{pstd}
{bf:Log-time transformation}

{phang2}{cmd:. finegray_phtest, time(log)}{p_end}

{pstd}
{bf:Display residuals}

{phang2}{cmd:. finegray_phtest, detail}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray_phtest} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_fail)}}number of cause events{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(time)}}time function used{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(phtest)}}p x 3 matrix: marginal chi2, df, approximate p{p_end}

{pstd}
{bf:Changed in 1.2.0.} {cmd:r(chi2)}, {cmd:r(df)} and {cmd:r(p)} held the retired
omnibus statistic and are {bf:no longer stored}; see
{help finegray_phtest##global:Global test} above. Existing code that reads them
will now see them as empty rather than receive a wrong number. Per-covariate
statistics remain available in {cmd:r(phtest)}, whose columns and rownames are
unchanged.


{marker references}{...}
{title:References and citation scope}

{pstd}
Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a
competing risk. {it:JASA} 1999; 94(446): 496-509.

{pstd}{browse "https://doi.org/10.1080/01621459.1999.10474144":doi:10.1080/01621459.1999.10474144}{p_end}

{pstd}
Grambsch PM, Therneau TM. Proportional hazards tests and diagnostics based on
weighted residuals. {it:Biometrika} 1994; 81(3): 515-526.

{pstd}{browse "https://doi.org/10.1093/biomet/81.3.515":doi:10.1093/biomet/81.3.515}{p_end}

{pstd}
Grambsch PM, Therneau TM. Proportional hazards tests and diagnostics based on
weighted residuals [correction]. {it:Biometrika} 1995; 82(3): 668.

{pstd}{browse "https://doi.org/10.1093/biomet/82.3.668":doi:10.1093/biomet/82.3.668}{p_end}

{pstd}
Bellach A, Kosorok MR, Ruschendorf L, Fine JP. Weighted NPMLE for the
subdistribution of a competing risk. {it:JASA} 2019; 114(525): 259-270.

{pstd}{browse "https://doi.org/10.1080/01621459.2017.1401540":doi:10.1080/01621459.2017.1401540}{p_end}

{pstd}
Zhou B, Fine J, Laird G. Goodness-of-fit test for proportional subdistribution
hazards model. {it:Statistics in Medicine} 2013; 32(22): 3804-3811.

{pstd}{browse "https://doi.org/10.1002/sim.5815":doi:10.1002/sim.5815}{p_end}

{pstd}
Li J, Scheike TH, Zhang MJ. Checking Fine and Gray subdistribution hazards model
with cumulative sums of residuals. {it:Lifetime Data Analysis} 2015; 21(2): 197-217
(online 2014).

{pstd}{browse "https://doi.org/10.1007/s10985-014-9313-9":doi:10.1007/s10985-014-9313-9}{p_end}

{pstd}
Kohl M, Plischke M, Leffondre K, Heinze G. PSHREG: a SAS macro for
proportional and nonproportional subdistribution hazards
regression. {it:Computer Methods and Programs in Biomedicine} 2015; 118(2): 218-233.

{pstd}{browse "https://doi.org/10.1016/j.cmpb.2014.11.009":doi:10.1016/j.cmpb.2014.11.009}{p_end}

{pstd}
Fine and Gray (1999) support Schoenfeld-type residual plots for the
subdistribution model, and (eq. 7-8) ground the estimated-censoring variance
term that, with Bellach et al. (2019, sec. 3.3), rules out the inverse
information as a null covariance for a joint test here. Grambsch and Therneau
(1994, corrected 1995) concern the Cox model and are cited only as inspiration
for time-transformed weighted-residual diagnostics; their joint test is
{bf:not} implemented, and their null covariance does not transfer to this
estimator. No article cited here validates the marginal n*rho^2 statistics as
implemented. Zhou et al. (2013), Li et al. (2015) and Kohl et al. (2015) are
cited to document the state of omnibus testing for this model, not as
implemented methods.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:Also see}

{psee}
Online: {helpb finegray}, {helpb finegray_predict}, {helpb finegray_cif},
{helpb stcrreg}, {helpb stcox}, {helpb stset}

{hline}
