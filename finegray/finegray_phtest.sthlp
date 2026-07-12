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
{viewerjumpto "Author" "finegray_phtest##author"}{...}
{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:finegray_phtest} {hline 2}}Test proportional subdistribution hazards assumption{p_end}
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
{cmd:finegray_phtest} tests the proportional subdistribution hazards (PSH)
assumption after {helpb finegray}. It computes scaled Schoenfeld residuals
at each cause-event time and tests their correlation with a function of time.

{pstd}
Under the PSH assumption, the scaled Schoenfeld residuals should be
uncorrelated with time. A significant test indicates that the effect of the
corresponding covariate changes over time, violating the PSH assumption.

{pstd}
{bf:A converged fit is required.} {cmd:finegray} reports a nonconverged model
rather than erroring, leaving {cmd:e(converged)} at 0, so {cmd:e(b)} exists but
holds the last iterate rather than a solution. Schoenfeld residuals taken at a
non-solution do not have mean zero and the test built on them is meaningless, so
{cmd:finegray_phtest} exits with {cmd:r(430)} when {cmd:e(converged)} is not 1.
Refit with a larger {opt iterate()} or a different specification.

{pstd}
The per-variable tests use scaled Schoenfeld residuals correlated with a time
function, similar in spirit to {cmd:estat phtest} after {cmd:stcox}. However,
the implementation differs in two ways: (1) scaling uses only the diagonal of
the inverse information matrix rather than the full matrix, and (2) the global
test is the sum of the per-variable chi-squared statistics.

{pstd}
{bf:The global test is not a joint test.} Summing the per-variable
chi-squared statistics and taking {it:df} = {it:p} ignores the covariance
{it:between} covariates, so the global statistic is an approximate PH diagnostic
only. It is most trustworthy when the covariates are close to orthogonal, and it
should not be read as a formal joint test of proportionality. The per-variable
tests are unaffected.

{pstd}
The test is only defined where it can be computed. If every cause event occurs
at a single time, the time function is constant and no correlation exists:
{cmd:finegray_phtest} exits with {cmd:r(459)} rather than reporting a blank
chi-squared. The same applies to any individual term whose scaled residuals do
not vary across cause-event times.

{pstd}
{cmd:finegray_phtest} reads the package-owned {cmd:_fg_*} factor-variable columns
by name. If they have been {it:dropped}, they are rebuilt on demand and the test
proceeds as normal. If one is still present but has been {it:altered}, the test
would silently be computed against a design the model was never fitted to, so
{cmd:finegray_phtest} exits with {cmd:r(459)} and {cmd:finegray} must be re-run.
Output and {cmd:r(phtest)} rownames use the underlying factor term names, not the
internal {cmd:_fg_*} names.

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
robust to outliers and is the standard choice.

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
{bf:Default PH test (rank of time)}

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
{synopt:{cmd:r(chi2)}}global chi-squared statistic{p_end}
{synopt:{cmd:r(df)}}degrees of freedom{p_end}
{synopt:{cmd:r(p)}}global p-value{p_end}
{synopt:{cmd:r(N_fail)}}number of cause events{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(time)}}time function used{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(phtest)}}p x 3 matrix: chi2, df, p for each variable{p_end}


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
