{smcl}
{vieweralsosee "finegray" "help finegray"}{...}
{vieweralsosee "finegray_phtest" "help finegray_phtest"}{...}
{vieweralsosee "finegray_cif" "help finegray_cif"}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{viewerjumpto "Syntax" "finegray_gof##syntax"}{...}
{viewerjumpto "Description" "finegray_gof##description"}{...}
{viewerjumpto "Options" "finegray_gof##options"}{...}
{viewerjumpto "Interpreting the p-value" "finegray_gof##pvalue"}{...}
{viewerjumpto "Scope and refusals" "finegray_gof##scope"}{...}
{viewerjumpto "Choosing between the tests" "finegray_gof##choosing"}{...}
{viewerjumpto "Comparison with crskdiag" "finegray_gof##crskdiag"}{...}
{viewerjumpto "Examples" "finegray_gof##examples"}{...}
{viewerjumpto "Stored results" "finegray_gof##results"}{...}
{viewerjumpto "References" "finegray_gof##references"}{...}
{viewerjumpto "Author" "finegray_gof##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:finegray_gof} {hline 2}}Cumulative-residual goodness-of-fit tests after finegray{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 22 2}
{cmd:finegray_gof}
[{cmd:,} {it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt prop:ortional}}test proportional subdistribution hazards (default){p_end}
{synopt:{opt func:form(terms)}}test the linear functional form of a covariate{p_end}
{synopt:{opt link}}test the link function{p_end}
{synopt:{opt nsim(#)}}bootstrap replications; default 1000{p_end}
{synopt:{opt seed(#|state)}}random-number seed or state{p_end}
{synopt:{opt graph}}plot the observed process against simulated null paths{p_end}
{synopt:{opt siml:ines(#)}}simulated paths overlaid; default 20{p_end}
{synopt:{opt sav:ing(filename[, replace])}}write the plotted paths as a dataset{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}
If none of {opt proportional}, {opt funcform()} or {opt link} is specified,
{opt proportional} is assumed.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray_gof} performs goodness-of-fit tests for the Fine-Gray model after
{helpb finegray}, based on cumulative sums of weighted martingale residuals
(Li, Scheike and Zhang 2015). Three families are available: proportionality of
the subdistribution hazards (per covariate and overall), the linear functional
form of a covariate, and the link function.

{pstd}
Unlike {helpb finegray_phtest}, this command {bf:does} report p-values. It can,
because the null distribution is not asserted from a table: it is obtained by a
Lin-Wei-Ying multiplier bootstrap in which the observed residual process is
resampled by redrawing standard normal multipliers, one per subject. The model
is fitted once and never refitted.

{pstd}
{bf:This is a separate command, not an extension of}
{helpb finegray_phtest}. The two implement different statistics from different
papers and give different answers to the question "may I report a
p-value?". Overloading the released diagnostic would have silently changed the
meaning of its output.


{marker options}{...}
{title:Options}

{phang}
{opt proportional} tests the null that each covariate's effect on the
subdistribution hazard is constant in time, using the standardized score
process. One test is reported per covariate, plus an {cmd:OVERALL} row (see
{it:Stored results} for why that row is not a chi-squared).

{phang}
{opt func:form(terms)} tests the null that each named covariate enters the
linear predictor linearly, by accumulating residuals along the covariate axis
rather than along time. Every term named must be a covariate in the last
{cmd:finegray} fit, spelled as that fit reports it -- for a factor-variable fit
that is the expanded term ({cmd:age}, {cmd:2.race#c.age}), which is what
{cmd:r(covariates)} lists.

{phang}
{opt link} tests the null that the linear predictor enters through the assumed
link, by accumulating residuals along the fitted linear predictor.

{phang}
{opt nsim(#)} sets the number of multiplier bootstrap replications; the default
is 1000 and the minimum accepted is 100. This is the direct determinant of
p-value resolution -- see {help finegray_gof##pvalue:Interpreting the p-value}.

{phang}
{opt seed(#|state)} sets the random-number seed. Because p-values are
simulation based, results are {bf:not} reproducible without it. Anything
{helpb set seed} accepts is accepted here, including a full random-number
state string.

{pmore}
{cmd:r(seed)} is set whether or not {opt seed()} was specified, so an unseeded
run can still be reproduced after the fact -- but note what it holds. When
{opt seed()} is given, {cmd:r(seed)} is that value. When it is not,
{cmd:r(seed)} is the complete random-number {it:state} as of entry
({cmd:c(rngstate)}), which is a string thousands of characters long, not a
short seed. Either form can be passed straight back to {opt seed()} on a later
run to reproduce the p-values exactly.


{phang}
{opt graph} plots each tested process against a sample of realizations drawn
from its own null distribution. One graph is produced per tested process, named
{cmd:fggof1}, {cmd:fggof2}, and so on in the order the results are tabled; see
{help finegray_gof##plot:Reading the plot} for what to look for.

{phang}
{opt simlines(#)} sets how many simulated realizations are overlaid; the default
is 20 and it may not exceed {opt nsim()}. This is a {it:display} choice and is
kept separate from {opt nsim()}, which is what the p-value is computed from: an
overlay of 1,000 paths is an unreadable black band, and a p-value from 20 draws
is not a p-value. Specifying it without {opt graph} or {opt saving()} is an
error rather than a silent no-op.

{phang}
{opt saving(filename[, replace])} writes the plotted paths as a dataset in
which {cmd:process} and {cmd:kind} identify the test, {cmd:x} is the process index
(analysis time, covariate value, or linear predictor), {cmd:observed} is the
observed standardized process, and {cmd:_fgsim1}...{cmd:_fgsim}{it:#} are the
simulated ones. Only the suboption {cmd:replace} is accepted, and shell
metacharacters and embedded quotes are rejected in {it:filename}. Use it to
build a plot this command does not draw.

{pmore}
Both options leave the data in memory untouched: the dataset is assembled in a
temporary {help frames:frame} that is dropped on every exit path.

{pmore}
{bf:Requesting a plot cannot change a p-value.} The overlaid paths are drawn
from the same multiplier bootstrap, but strictly {it:after} every replication
the test itself consumes, so the random-number stream the p-values are computed
from is untouched. For a given {opt seed()}, {cmd:r(gof)}, {cmd:r(p_overall)}
and every other stored result are bit-for-bit identical with and without
{opt graph}. Had the display draws been interleaved with the test draws — the
natural way to write it — they would have silently re-seeded every subsequent
replication and moved every p-value at {cmd:rc = 0}.

{pmore}
For display only, a process is thinned to at most 2,000 evenly spaced grid
points, endpoints retained. The link process has one grid point per distinct
linear predictor, so an unthinned path matrix would exceed Stata's matrix limits
on exactly the datasets people want to plot. Statistics and p-values are always
computed on the full grid, so thinning cannot move a reported number; it only
means the drawn line may not pass through the exact point where the supremum was
attained.


{marker plot}{...}
{title:Reading the plot}

{pstd}
The black line is the observed process; the grey lines are realizations drawn
under the null. This is the diagnostic the paper describes at p.202, and it
answers a question the p-value cannot: {it:where} and {it:how} the model fails.

{pstd}
Under the null the observed line is one grey line among many — wandering around
zero, no more extreme than its neighbours. A departure shows up as the observed
line being {bf:isolated} above or below the simulated band over some stretch of
the axis. For a proportionality plot, the stretch names {it:when} the effect
departs from proportional: an observed path that runs high early and crosses low
later is the signature of an effect that reverses, which a single number cannot
tell you. For a functional-form plot, it names {it:which range} of the covariate
is fitted badly, which is what points at the transformation to try.

{pstd}
A supremum statistic collapses all of that to the single largest excursion. The
plot and the p-value are the same object, scaled the same way, so they never
disagree; the plot simply retains the shape that the supremum discards.


{marker pvalue}{...}
{title:Interpreting the p-value}

{pstd}
{bf:The p-values are simulation based and seed dependent.} Two runs with
different seeds give different p-values for the same data and the same
model. This is a property of the method, not an instability in the
implementation. Fix {opt seed()} for any result that will be reported.

{pstd}
{bf:The resolution floor is 1/nsim.} The p-value is the proportion of simulated
suprema at least as large as the observed one, so with {cmd:nsim(1000)} it can
take only the values 0, 0.001, 0.002, and so on. An observed count of zero means
"below the floor", not "zero": the command therefore prints {cmd:< 0.0010}
rather than a bare {cmd:0.0000}, and {cmd:r()} carries the exact 0 for
programmatic use. If a p-value near a decision boundary matters, raise
{opt nsim()} rather than reading more precision into the printed digits than the
bootstrap supports.

{pstd}
{bf:The test is anticonservative at small samples}, by the authors' own
measurement. Table 1 of Li, Scheike and Zhang (2015) reports type I error of
0.0624 at n = 50 and 0.0536 at n = 300 against a nominal 0.05 for the
proportionality test; Table 4 reports 0.0568 and 0.0478 for the functional-form
test. This package's own Monte Carlo calibration reproduces those values (pooled
proportionality 0.0593 against the paper's 0.0585; pooled functional form 0.0531
against 0.0531). Treat a p-value just under 0.05 at small n as weaker evidence
than the number suggests, and note that the proportionality test is the more
anticonservative of the two.

{pstd}
{bf:Functional-form checking of a two-level covariate is meaningless.} With only
two distinct values the residual process is pinned to zero at both grid points
-- at the upper by construction, at the lower by the score equation -- so it is
identically zero and any p-value computed from it would be decided by rounding
error rather than by fit. The paper makes the same point (sec. 4.1,
p.209). {cmd:finegray_gof} therefore {bf:refuses} {opt funcform()} on a covariate with
two or fewer distinct values ({cmd:r(198)}) rather than returning a number that
would look like a result.


{marker scope}{...}
{title:Scope and refusals}

{pstd}
Each condition below is a regime {it:the paper does not cover}, not one that is
merely untested here. All are refused, and each refusal message names its own
reason.

{p2colset 8 46 48 2}{...}
{p2col:{it:Condition}}{it:Result}{p_end}
{p2line}
{p2col:not run after {cmd:finegray}}{cmd:r(301)}{p_end}
{p2col:{cmd:e(converged)} not 1}{cmd:r(430)}{p_end}
{p2col:delayed entry (left truncation)}{cmd:r(301)}{p_end}
{p2col:{cmd:strata()} used in the fit}{cmd:r(301)}{p_end}
{p2col:{cmd:cluster()} used in the fit}{cmd:r(301)}{p_end}
{p2line}
{p2colreset}{...}

{pstd}
{bf:Delayed entry.} There is no entry time anywhere in Li, Scheike and Zhang
(2015) -- not in the model, not in the appendix derivation, not in the
simulations, and not in either data example. The delayed-entry analogue of its
influence-function decomposition is not published, so extending the test to left
truncation would be a research contribution rather than an implementation
detail. Refit without {opt enter()}, or use {helpb finegray_phtest}, which does
support delayed entry as a diagnostic.

{pstd}
{bf:Strata.} The residual process is built on the {it:marginal} censoring
Kaplan-Meier. {cmd:finegray}'s {opt strata()} estimates a separate censoring
curve per stratum, which changes the weights the process is constructed
from. That is not a harmless generalization of the published test.

{pstd}
{bf:Clustering.} The multiplier bootstrap redraws one standard normal per
{it:subject} and relies on the influence contributions being independent across
subjects. Under clustering they are not.

{pstd}
{bf:A converged fit is required.} The residual process is evaluated at the
fitted coefficient vector, and every identity underpinning the decomposition
assumes that vector solves the score equation. {cmd:finegray} reports a
nonconverged model rather than erroring, leaving {cmd:e(b)} holding the last
iterate; {cmd:finegray_gof} exits with {cmd:r(430)} rather than returning
p-values computed at a non-solution.

{pstd}
{bf:Factor variables} are supported. A factor-variable fit stores its design in
package-owned {cmd:_fg_*} columns, and {cmd:finegray_gof} maps each one back to
the term you typed, so the table and {cmd:r(gof)} report {cmd:2.race}, not
{cmd:_fg_race_2}. If those columns have been dropped -- which is allowed -- the
design is reconstructed from the expansion recorded at estimation
({cmd:e(fvsemantic)}), with each indicator keyed to the level {it:value} rather
than to a position, so neither an {helpb fvset} base change nor a shift in the
level support after the fit can misalign a column against its coefficient. The
results are identical either way, and identical to fitting the same design as
ordinary variables. Interaction terms ({cmd:i.race##c.age}) are handled the same
way.

{pstd}
Two consequences worth knowing. {opt funcform()} takes the {it:term} name as
{cmd:fvexpand} spells it -- {cmd:funcform(age)} or
{cmd:funcform(2.race#c.age)}, not the internal column name -- and an indicator
term is refused like any other two-level covariate (see below). And reading
{cmd:r(gof)}'s rownames back with {cmd:{c 96}: rownames r(gof){c 39}} shows
Stata's canonical spelling of a factor token, which marks the first level of
each factor as base-none: {cmd:2.race 3.race} reads back as
{cmd:2bn.race 3.race}. {cmd:matrix list} and {cmd:r(covariates)} both give the
plain form.

{pstd}
{bf:Data requirement.} The residual process is recomputed from the estimation
data, so the unchanged original {cmd:stset} data must be in memory.

{pstd}
{bf:The estimated-weight correction is always applied here.} It does not matter
whether the fit used {opt nuisance}. On {helpb finegray} the correction is
opt-in, because it changes a reported variance. It is not optional here, since
the limiting distribution in the Appendix decomposition (eq. 17) carries the
influence function of {bf:beta-hat} itself, which is
{cmd:Omega^-1 (eta_i + psi_i)} -- the {cmd:psi} term accounts for having
estimated the censoring distribution rather than known it. Dropping it would
simulate the wrong null and mis-size every test. So the residual process is
built from the full influence function even after a default fit, and the test
is {it:not} conditional on the variance convention shown in {cmd:e(V)}. No
option is offered to disable it, because there is no correct reason to.


{marker choosing}{...}
{title:Choosing between the tests}

{pstd}
Where a specific alternative is suspected, a directly fitted model is the
stronger instrument; where it is not, this test is. Li, Scheike and Zhang (2015,
Tables 2-3) quantify the trade-off. Against a {it:correctly specified} time
interaction, fitting that interaction and testing it has power 0.9985 against
this test's 0.9590. Against a {it:misspecified} form of the same departure, the
ordering reverses: this test has power 0.9715 against 0.9125.

{pstd}
So: if there is a particular time-varying effect worth naming, name it and fit
it. If the question is the open-ended "does this model fit?", use
{cmd:finegray_gof}, which does not require the departure to be guessed in
advance.


{marker crskdiag}{...}
{title:Comparison with crskdiag}

{pstd}
{cmd:crskdiag} (the authors' own R implementation, in the {cmd:crskdiag}
package) will generally {bf:not} reproduce the numbers this command reports, and
the difference is not a defect here.

{pstd}
Two causes have been identified and documented. First, that implementation's
censoring Kaplan-Meier is identically 1 on continuous data, so the inverse
probability of censoring weights are effectively absent; this package estimates
the censoring distribution as the method specifies. Second, its default
{cmd:minor_included = 1} adds a defective nuisance term to the influence
contributions that feeds the test process itself and not merely the variance.

{pstd}
Because both implementations compare an observed supremum against simulated
suprema drawn under the {it:same} weights, a mis-specified weight can leave the
test correctly sized while changing every number it prints. That is what is
observed: this package's Monte Carlo type I error reproduces the paper's
published Tables 1 and 4 to within Monte Carlo error, while individual test
statistics on a given dataset differ.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup}

{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}
{phang2}{cmd:. finegray ifp tumsize pelnode, compete(status) cause(1)}{p_end}

{pstd}
{bf:Proportionality of the subdistribution hazards}

{phang2}{cmd:. finegray_gof, seed(20260720)}{p_end}

{pstd}
{bf:Functional form of a continuous covariate, and the link function}

{phang2}{cmd:. finegray_gof, funcform(ifp tumsize) link seed(20260720)}{p_end}

{pstd}
{bf:A finer p-value near a decision boundary}

{phang2}{cmd:. finegray_gof, nsim(10000) seed(20260720)}{p_end}

{pstd}
{bf:Plot the observed process against the null band}

{phang2}{cmd:. finegray_gof, seed(20260720) graph}{p_end}

{pstd}
{bf:A denser band, and the numbers behind it}

{phang2}{cmd:. finegray_gof, seed(20260720) graph simlines(50) saving(gofpaths.dta, replace)}{p_end}

{pstd}
{bf:The paths without the graph, to plot them your own way}

{phang2}{cmd:. finegray_gof, seed(20260720) funcform(ifp) saving(gofpaths.dta, replace)}{p_end}
{phang2}{cmd:. use gofpaths.dta, clear}{p_end}
{phang2}{cmd:. twoway line _fgsim1 _fgsim2 _fgsim3 observed x, legend(off)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray_gof} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(nsim)}}bootstrap replications performed{p_end}
{synopt:{cmd:r(sup_overall)}}observed overall proportionality supremum{p_end}
{synopt:{cmd:r(p_overall)}}p-value for the overall proportionality test{p_end}
{synopt:{cmd:r(sup_link)}}observed link-function supremum{p_end}
{synopt:{cmd:r(p_link)}}p-value for the link-function test{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(test)}}which test families were run{p_end}
{synopt:{cmd:r(seed)}}seed used{p_end}
{synopt:{cmd:r(covariates)}}model covariates{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:r(gof)}}per-covariate proportionality: {cmd:sup} and {cmd:p}{p_end}
{synopt:{cmd:r(funcform)}}per-covariate functional form: {cmd:sup} and {cmd:p}{p_end}

{pstd}
Only the results for the requested tests are set.

{pstd}
{bf:There is no} {cmd:r(chi2)} {bf:and no} {cmd:r(df)}{bf:, deliberately.} The
overall statistic is the supremum over time of a sum of absolute standardized
score processes. It is not a quadratic form and has no chi-squared null
distribution, so a degrees-of-freedom value would be meaningless and a
{cmd:chi2} label would invite exactly the misreading that version 1.2.0 removed
from {helpb finegray_phtest}. The p-value in {cmd:r(p_overall)} is obtained from
the same multiplier bootstrap as every other p-value here.


{marker references}{...}
{title:References}

{pstd}
Li J, Scheike TH, Zhang MJ. Checking Fine and Gray subdistribution hazards model
with cumulative sums of residuals. {it:Lifetime Data Analysis} 2015; 21(2): 197-217
(online 2014).

{pstd}{browse "https://doi.org/10.1007/s10985-014-9313-9":doi:10.1007/s10985-014-9313-9}{p_end}

{pstd}
Lin DY, Wei LJ, Ying Z. Checking the Cox model with cumulative sums of
martingale-based residuals. {it:Biometrika} 1993; 80(3): 557-572.

{pstd}{browse "https://doi.org/10.1093/biomet/80.3.557":doi:10.1093/biomet/80.3.557}{p_end}

{pstd}
Fine JP, Gray RJ. A proportional hazards model for the subdistribution of a
competing risk. {it:JASA} 1999; 94(446): 496-509.

{pstd}{browse "https://doi.org/10.1080/01621459.1999.10474144":doi:10.1080/01621459.1999.10474144}{p_end}

{pstd}
The implemented statistics, their influence-function decomposition, and the
multiplier bootstrap are those of Li, Scheike and Zhang (2015); Lin, Wei and
Ying (1993) is the source of the resampling device that paper adapts, and is
cited as such rather than as a separately implemented method.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:Also see}

{psee}
Online: {helpb finegray}, {helpb finegray_phtest}, {helpb finegray_predict},
{helpb finegray_cif}, {helpb stcrreg}, {helpb stset}

{hline}
