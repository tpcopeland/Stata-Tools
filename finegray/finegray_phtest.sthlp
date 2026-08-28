{smcl}
{vieweralsosee "finegray" "help finegray"}{...}
{vieweralsosee "finegray_methods" "help finegray_methods"}{...}
{vieweralsosee "finegray_cif" "help finegray_cif"}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "finegray_phtest##syntax"}{...}
{viewerjumpto "Description" "finegray_phtest##description"}{...}
{viewerjumpto "Options" "finegray_phtest##options"}{...}
{viewerjumpto "Global test" "finegray_phtest##global"}{...}
{viewerjumpto "Examples" "finegray_phtest##examples"}{...}
{viewerjumpto "Stored results" "finegray_phtest##results"}{...}
{viewerjumpto "Methods and formulas" "finegray_phtest##methods"}{...}
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
{synopt:{opt det:ail}}display the first 20 raw Schoenfeld residual rows{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray_phtest} provides an approximate diagnostic for the proportional
subdistribution hazards (PSH) assumption after {helpb finegray}. It computes
raw Schoenfeld residuals at cause-event times and correlates each
residual series with a function of time.

{pstd}
Time patterns in the residuals suggest that a covariate's effect may change
over time. The command reports, per covariate, the residual-time
{it:correlation} only: it deliberately reports
{bf:no chi-squared statistic and no p-value}. Treat a correlation far from zero
as a flag for follow-up, not as an accept/reject test. {opt detail} displays
the first 20 rows of those same raw residuals. Formal cumulative-residual and
score tests exist in the literature, but none ships with this package; see
{help finegray_methods##phtest:Proportionality diagnostic} for why the
statistic was withdrawn and what to use instead.

{pstd}
{bf:Left truncation (delayed entry).} The weighted risk sets underlying the
Schoenfeld residuals use Zhang-Zhang-Fine Weight 1, not a censoring-only
weight, so under delayed entry the residuals and diagnostic summaries differ
from the right-censoring path and from {helpb stcrreg}. See
{help finegray##lt:Left truncation} in {helpb finegray} and
{help finegray_methods##lt:Left truncation} in {helpb finegray_methods}.

{pstd}
{bf:A converged fit is required.} {cmd:finegray_phtest} exits with
{cmd:r(430)} when {cmd:e(converged)} is not 1, because Schoenfeld residuals
taken at a non-solution do not have the fitted score property. Refit with a
larger {opt iterate()} or a different specification.

{pstd}
{bf:Not available after a fit on {cmd:mi} data.} A {cmd:finegray} fit made
on multiple-imputation data -- typed directly, or run by
{helpb mi estimate:mi estimate, cmdok:} -- leaves no design columns or
entry-time column behind, and pooled estimates have no single baseline
hazard to run a diagnostic against. {cmd:finegray_phtest} stops with
{cmd:r(301)} in that case. Refit on a single dataset
({cmd:mi extract 0, clear} for the complete cases, or {cmd:mi extract}
{it:#}{cmd:, clear} for one imputation) and run {cmd:finegray} there; see
{help finegray##mi:Multiple imputation} in {helpb finegray}.

{marker global}{...}
{pstd}
{bf:Global test.} {cmd:finegray_phtest} reports {bf:no omnibus test}, and has
not since version 1.2.0. None is implemented elsewhere in the package
either. For a formal omnibus test use software that implements a published PSH
method. To model rather than test a departure from proportionality,
{cmd:finegray}'s {helpb finegray##tvc:tvc()} fits a piecewise-constant
beta({it:t}) and {cmd:test [tvc1]}{it:x} {cmd:= [tvc2]}{it:x} is the
corresponding Wald test. See
{help finegray_methods##phtest:Proportionality diagnostic}.

{pstd}
The diagnostic is only defined where it can be computed. If every cause event
occurs at a single time, the time function is constant and no correlation
exists: {cmd:finegray_phtest} exits with {cmd:r(459)} rather than reporting a blank
row. The same applies to any individual term whose raw residuals do
not vary across cause-event times.

{pstd}
{cmd:finegray_phtest} reads the package-owned {cmd:_fg_*} factor-variable
columns by name. If they have been {it:dropped}, they are rebuilt on
demand and the test proceeds as normal. If one is still present but has
been {it:altered}, the test would silently be computed against a design
the model was never fitted to, so {cmd:finegray_phtest} exits with
{cmd:r(459)} and {cmd:finegray} must be re-run. Output and {cmd:r(phtest)}
rownames use the underlying factor term names, not the internal
{cmd:_fg_*} names.

{pstd}
{bf:Data requirement:} {cmd:finegray_phtest} computes Schoenfeld residuals on
the estimation sample and therefore requires the unchanged original {cmd:stset}
data. It verifies a signature covering {cmd:_t}, {cmd:_t0}, {cmd:_d}, the event
type, the covariates, and every variable named in {opt strata()},
{opt truncstrata()}, {opt bstrata()} or {opt cluster()}, plus any persisted
entry-time variable; the list is {cmd:e(datasignaturevars)}. If
those data have changed, it exits with {cmd:r(459)}; re-run
{cmd:finegray}. Unlike {cmd:finegray_predict, xb}, it cannot be run after
loading a new dataset.


{pstd}
{bf:Not available after a fit with} {helpb finegray##tvc:tvc()}, and this is the
direction of the workflow rather than a gap. A {opt tvc()} fit no longer assumes
proportional subdistribution hazards for the covariates it names, so the
assumption this command tests is not one that fit makes; and the residuals it
consumes are defined interval by interval, with every other interval's block
zero by construction. Run {cmd:finegray_phtest} on the proportional fit, answer a
rejection with {opt tvc()}, and test whether the effect is in fact constant with
{cmd:test [tvc1]}{it:x} {cmd:= [tvc2]}{it:x} after that fit. Reaching here on a
{opt tvc()} fit is {cmd:r(198)}.


{marker options}{...}
{title:Options}

{phang}
{opt time(function)} specifies the time function used in the correlation
diagnostic. {cmd:rank} (the default) uses the rank of event times. {cmd:log} uses
log(time). {cmd:identity} uses raw event times. The rank transformation is
less sensitive to extreme event times and is the default screening choice.

{phang}
{opt detail} displays the first 20 rows of the raw Schoenfeld residual matrix.


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
{bf:Analysis time itself}

{phang2}{cmd:. finegray_phtest, time(identity)}{p_end}

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
{synopt:{cmd:r(residual_scale)}}{cmd:raw}{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(phtest)}}p x 2: residual-time {cmd:correlation}, event count{p_end}

{pstd}
{bf:Diagnostic-only surface.} {cmd:r(phtest)} holds one row per covariate with
columns {cmd:correlation} (the raw-Schoenfeld/time correlation) and
{cmd:events} (the number of cause-event times used). The {cmd:events} column is
printed only when it differs from the header's {cmd:Cause events} for some
covariate - it can, when the {opt time()} transform leaves a missing value (for
example {cmd:time(log)} at an event time of zero) - but it is returned in
{cmd:r(phtest)} either way. It does {bf:not} carry
{cmd:chi2}, {cmd:df}, or a p-value: those are not reported (see
{help finegray_methods##phtest:Proportionality diagnostic}). The omnibus
scalars {cmd:r(chi2)}, {cmd:r(df)} and
{cmd:r(p)} were retired earlier and remain unset; see
{help finegray_phtest##global:Global test}. Code written against the former
p x 3 {cmd:[chi2, df, p]} matrix must read the {cmd:correlation} column instead.


{marker methods}{...}
{title:Methods and formulas}

{pstd}
See {help finegray_methods##phtest:Proportionality diagnostic} in
{helpb finegray_methods} for the quantity this command computes, why the
chi-squared statistic and the omnibus test were withdrawn, and which published
methods to use for formal inference. The full reference list and its citation
scope are in {help finegray_methods##references:References}.

{pstd}
Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a
competing risk. {it:JASA} 1999; 94(446): 496-509.

{pstd}{browse "https://doi.org/10.1080/01621459.1999.10474144":doi:10.1080/01621459.1999.10474144}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:Also see}

{psee}
Online: {helpb finegray}, {helpb finegray_methods}, {helpb finegray_predict},
{helpb finegray_cif}, {helpb stcrreg}, {helpb stcox}, {helpb stset}

{hline}
