{smcl}
{vieweralsosee "finegray" "help finegray"}{...}
{vieweralsosee "finegray_methods" "help finegray_methods"}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "finegray_phtest" "help finegray_phtest"}{...}
{vieweralsosee "stcurve" "help stcurve"}{...}
{viewerjumpto "Syntax" "finegray_cif##syntax"}{...}
{viewerjumpto "Description" "finegray_cif##description"}{...}
{viewerjumpto "Options" "finegray_cif##options"}{...}
{viewerjumpto "Baseline strata" "finegray_cif##bstratum"}{...}
{viewerjumpto "Time-varying effects" "finegray_cif##tvc"}{...}
{viewerjumpto "Remarks" "finegray_cif##remarks"}{...}
{viewerjumpto "Examples" "finegray_cif##examples"}{...}
{viewerjumpto "Stored results" "finegray_cif##results"}{...}
{viewerjumpto "Author" "finegray_cif##author"}{...}
{title:Title}

{phang}
{bf:finegray_cif} {hline 2} Cumulative incidence curves and fixed-horizon
cumulative incidence after {help finegray}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:finegray_cif}
[{cmd:,} {it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt at(var=# ...)}}covariate profile for the curve{p_end}
{synopt :{opt att:ime(numlist)}}table of the CIF at the listed horizons{p_end}
{synopt :{opt ti:mepoints(numlist)}}evaluate the curve at these times{p_end}
{synopt :{opt bstrat:um(#)}}baseline stratum; required after {cmd:bstrata()}{p_end}
{synopt :{opt ci}}add pointwise confidence limits{p_end}
{synopt :{opt boot:strap(#)}}bootstrap the confidence band with {it:#} resamples{p_end}
{synopt :{opt seed(#)}}random-number seed for {opt bootstrap()}{p_end}
{synopt :{opt l:evel(#)}}set confidence level; default is {cmd:c(level)}{p_end}
{synopt :{opt sav:ing(filename[, replace])}}save the numeric estimates{p_end}
{synopt :{opt nograph}}suppress the graph{p_end}
{synopt :{it:twoway_options}}any options documented in {help twoway_options}{p_end}
{synoptline}
{p 4 6 2}{cmd:finegray_cif} is for use after {helpb finegray}; see
{helpb finegray}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray_cif} computes the predicted cumulative incidence function (CIF)
for a chosen covariate profile after {helpb finegray}. The command uses
{cmd:e(basehaz)} when that opt-in matrix exists and otherwise resolves the
fit-specific cached or rebuilt baseline; the construction is in
{help finegray_methods##cif:Cumulative incidence}.

{pstd}
By default it plots the CIF as a right-continuous step function over the
event-time grid. When the baseline contains more than 400 distinct cause-event
times, the default grid is thinned to at most 401 points and always includes
the final cause-event time; use {opt timepoints()} to request an exact
grid. The plotted curve and confidence band begin at the exact (0,0) boundary,
and the plot region is anchored at zero on the analysis-time axis. This
display-only origin is not added to {cmd:r(table)} or {opt saving()}
output. With {opt attime()} the command instead reports the CIF at specific
horizons (for example the 5-year cumulative incidence).

{pstd}
{cmd:finegray_cif} is the {helpb finegray} analogue of {helpb stcurve}{cmd:, cif}
after {helpb stcrreg}, with two additions: it can plot a pointwise confidence
{it:band} (which {cmd:stcurve} cannot), and it can {opt saving()} the numeric
estimates behind the curve.

{pstd}
{bf:The covariate profile is always reported.} Both the table and the graph
state the profile the CIF was evaluated at, in the vocabulary {opt at()} takes -
an {cmd:at:} line above the table and a {cmd:note()} under the graph. When
{opt at()} is omitted the line reads {cmd:at (estimation-sample means):} and
lists the means used, so a default run is as self-describing as an explicit one. The
graph note is a default: your own {cmd:note()} in {it:twoway_options}
replaces it.

{pstd}
{bf:The plotted curve extends to the end of follow-up.} The estimation grid ends
at the last cause-event time, but the CIF is flat from there to the last observed
analysis time, and the graph draws that tail as {helpb sts graph} and
{helpb stcurve} do. Like the (0,0) origin, the terminal segment is display-only: it
is not in {cmd:r(table)} and not in the {opt saving()} dataset.

{pstd}
{bf:Times outside the estimated support are flagged.} With {opt attime()} or
{opt timepoints()}, a requested time past the last cause-event time repeats the
terminal estimate and a requested time before the first cause-event time returns
a CIF of exactly 0 with no confidence limits. Both are the correct step-function
answers, and {cmd:finegray_cif} prints a note naming the boundary time so that
neither is quoted as an estimate at the requested horizon. See
{help finegray_methods##cif:Cumulative incidence}.

{pstd}
The command requires the unchanged original {cmd:stset} estimation data in
memory. It verifies a signature of the estimation sample and the variables
used by the fit before resolving the baseline or reconstructing influence
functions. Re-run {cmd:finegray} after changing those data.

{pstd}
{bf:A converged fit is required.} {cmd:finegray_cif} exits with {cmd:r(430)}
when {cmd:e(converged)} is not 1; refit with a larger {opt iterate()} or a
different specification. Refits inside {opt bootstrap()} that fail to converge
are skipped and counted rather than treated as fatal. See
{help finegray_methods##estimator:The estimator}.


{pstd}
{bf:Not available after a fit on {cmd:mi} data.} A {cmd:finegray} fit made
on multiple-imputation data -- typed directly, or run by
{helpb mi estimate:mi estimate, cmdok:} -- leaves no design columns or
entry-time column behind, and pooled estimates have no single baseline
hazard to build a curve from. {cmd:finegray_cif} stops with {cmd:r(301)}
in that case. Refit on a single dataset ({cmd:mi extract 0, clear} for the
complete cases, or {cmd:mi extract} {it:#}{cmd:, clear} for one
imputation) and run {cmd:finegray} there; see
{help finegray##mi:Multiple imputation} in {helpb finegray}.

{marker options}{...}
{title:Options}

{phang}
{opt at(var=# ...)} sets the covariate profile at which the CIF is evaluated, for
example {cmd:at(age=60 male=1)}. Variables not listed are held at their
estimation-sample mean, which is also the default profile.

{phang2}
Factor variables are named directly by their level, for example
{cmd:at(pelnode=1)} after {cmd:finegray i.pelnode ...}; the reference level
({cmd:at(pelnode=0)}) leaves every indicator at 0. A variable that enters an
interaction may be set the same way: the setting is carried into every design
column the variable appears in, so after
{cmd:finegray i.pelnode c.ifp i.pelnode#c.ifp}, {cmd:at(pelnode=1 ifp=20)}
evaluates the interaction at {cmd:1 * 20 = 20}, and {cmd:at(pelnode=0 ifp=20)}
evaluates it at 0. Where a term mixes a variable you set with one you do not,
the unset part is held at its estimation-sample mean. A design column that
contains no variable you set keeps its own estimation-sample mean.

{phang2}
The package-owned design columns in {cmd:e(covariates)} may still be set by
name, for example {cmd:at(_fg_pelnode_1Xifp=0)}, and such a setting is applied
after, and therefore overrides, anything implied by the variables you named.

{phang}
{opt attime(numlist)} requests a table of the CIF at the listed time horizons
(for example {cmd:attime(1 5 10)}) instead of a plotted curve. Combine with
{opt ci} to include confidence limits. May not be combined with
{opt timepoints()}.

{phang}
{opt timepoints(numlist)} evaluates the curve at the specified times rather than
at the distinct cause-event times of the fitted baseline. May not be combined
with {opt attime()}: both name the times the CIF is evaluated at, and
{opt attime()} additionally selects table output over a plotted curve, so the
combination is refused rather than resolved silently. Unlike the default grid,
the requested grid is not thinned.

{marker tvc}{...}
{phang}
{bf:After a fit with} {helpb finegray##tvc:tvc()} the coefficient on the named
covariates is piecewise constant in analysis time, so
CIF({it:t}|{it:z}) is accumulated interval by interval: the part of the baseline
falling inside interval {it:j} is multiplied by that interval's
exp({it:z}'b_j). Point estimates, tables, curves, {opt saving()} and the graph
are unaffected in form -- {opt at()} still names one covariate profile, and
there is still one baseline.

{pmore}
{opt ci} on its own {bf:is} available as of version 1.3.0, from an influence
function derived for a piecewise b({it:t}); development builds refused it with
{cmd:r(198)}. See {help finegray_methods##tvc:Time-varying effects}.

{pmore}
{opt ci} {opt bootstrap(#)} remains available and is the arm the analytic route
is checked against. Each replication refits the whole model from
{cmd:e(refitcmd)}, which carries {opt tvc()} and {opt tsplit()}, so every
replication is the same estimator as the point estimate. {cmd:r(se_method)}
reports which route produced the interval: {cmd:analytic} or
{cmd:bootstrap}. Without {opt ci}, {cmd:r(table)}'s {cmd:lci} and {cmd:uci}
columns are missing, as they are for any point-estimate-only call.

{pmore}
{bf:The analytic route is fixed-weight}, here as on a proportional fit: it does
not propagate the uncertainty in the estimated censoring distribution, so it
returns the same standard errors after a
{help finegray_methods##nuisance:nuisance} fit as after a default one. Use
{opt bootstrap(#)} when the interval should include weight re-estimation.

{marker bstratum}{...}
{phang}
{opt bstratum(#)} names the baseline stratum the CIF belongs to, where {it:#} is
a value of the {cmd:bstrata()} variable used at fit time. It is
{bf:required} after a fit with more than one baseline stratum and is refused
after any other fit.

{pmore}
It is required rather than defaulted because under {opt bstrata()} a covariate
profile no longer identifies a curve; a stratum-{it:averaged} CIF is a
different estimand and is not implemented. See
{help finegray_methods##bstrata:Baseline strata}.

{pmore}
The stratum is printed on the {cmd:at:} line above the table and in the graph's
default {cmd:note()}, and returned in {cmd:r(bstratum)} and
{cmd:r(bstrata)}. The default (unthinned) time grid, the out-of-support notes
and the graph's flat right-hand tail are all taken within the requested
stratum, because those are properties of the curve being drawn and not of the
pooled sample.

{pmore}
A value that no estimation-sample subject holds is refused with {cmd:r(459)},
listing the fitted levels. So is a level that carried no cause-of-interest
event, whose Breslow baseline is identically zero; see
{help finegray_methods##refusals:What is refused, and why}.

{phang}
{opt ci} adds pointwise confidence limits. The standard error of the CIF is an
influence-function (sandwich) standard error; limits are formed on the
complementary log-log scale so that they remain inside (0,1). The standard error
treats the fitted weight functions as known, so under heavy censoring or delayed
entry it can omit weight-estimation variability; {opt bootstrap()}
re-estimates the weight functions in each replication. See
{help finegray_methods##cif:Cumulative incidence}.

{phang}
{opt bootstrap(#)} computes pointwise confidence limits by resampling
subjects with replacement and refitting the model. It requires
{opt ci}. If the original fit specified {opt cluster()}, whole clusters
are resampled. The resulting limits therefore follow the fitted resampling
unit and include variability from re-estimating the censoring
weights. Under delayed entry it also re-estimates the entry weights and
weight strata. Nonconverged refits, and refits whose resample loses a
factor level (so the coefficient vector no longer matches the stored
covariate profile), are skipped and counted in
{cmd:r(bootstrap_failed)}. At least 25 replications must be requested, and
at least 25 must succeed, or {cmd:finegray_cif} exits with an error; see
{help finegray_methods##cif:Cumulative incidence}. The refit is run on the
estimation sample, so any {cmd:if} or {cmd:in} qualifier used at fit time
does not apply to the replications. Point estimates are unchanged; only
the standard error and limits differ. The original estimation results and
{cmd:e(sample)} are preserved.

{phang}
{opt seed(#)} sets the random-number seed used by {opt bootstrap()} for
reproducibility. It requires {opt bootstrap()}, and must be an integer between
{cmd:0} and {cmd:2147483647}.

{phang}
{opt level(#)} sets the confidence level for {opt ci}; it requires {opt ci}. The
default is {cmd:c(level)}, which is initially 95 and can be changed by
{helpb set level}. The value must be between 10 and 99.99 inclusive, with at
most two decimal places -- the same rule {cmd:finegray} itself applies.

{phang}
{opt saving(filename[, replace])} writes a dataset containing {cmd:time},
{cmd:cif}, {cmd:se}, {cmd:lci}, and {cmd:uci} (one row per evaluated time) - the
analogue of {cmd:outfile} after {cmd:stcurve}. Only the optional suboption
{cmd:replace} is accepted. Shell metacharacters and embedded quote characters
are rejected in {it:filename}. Every variable is labelled, the dataset label
names the cause, and a dataset {helpb notes:note} records the covariate profile,
so the exported file documents itself. {cmd:finegray_cif} confirms the write
once, naming the path actually written (including a {cmd:.dta} extension it
supplied).

{phang}
{opt nograph} suppresses the graph (useful with {opt saving()}).

{phang}
{it:twoway_options} are any of the options documented in {help twoway_options},
for example {cmd:title()}, {cmd:xtitle()}, or {cmd:scheme()}. These pass through
to the CIF plot and override the defaults. In {opt attime()} mode no graph is
drawn, so these options are ignored with a note. The legend defaults to a
single
row; because repeated {cmd:legend()} options merge, you can adjust or suppress
it from here, for example {cmd:legend(off)}, {cmd:legend(pos(6))}, or
{cmd:legend(rows(2))}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Left truncation (delayed entry).} CIF points and standard errors use the
same Zhang-Zhang-Fine Weight-1 contract as the fit, so delayed-entry estimates
change relative to earlier versions and to {helpb stcrreg}, by design. The
estimation data must remain in memory and unmodified so the weight design can be
rebuilt. See {help finegray##lt:Left truncation} in {helpb finegray} for the
operational contract and {help finegray_methods##lt:Left truncation} in
{helpb finegray_methods} for the citations, assumptions, and support boundaries.

{pstd}
For a confidence interval on the cumulative incidence of {it:each subject} (or a
selected subset), see {helpb finegray_predict}{cmd:, cif ci}, which generates
per-observation CIF limits at each observation's own time or at a supplied
{opt timevar()}.

{pstd}
With {opt cluster()} in the original {helpb finegray} fit, the analytic band
uses the corresponding cluster-robust variance and {opt bootstrap()} resamples
whole clusters.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}
{phang2}{cmd:. finegray i.pelnode ifp tumsize, compete(status) cause(1)}{p_end}

{pstd}Plot the CIF curve at the covariate means, with a 95% band{p_end}
{phang2}{cmd:. finegray_cif, ci}{p_end}

{pstd}Curve for a specified covariate profile{p_end}
{phang2}{cmd:. finegray_cif, at(pelnode=1 ifp=20 tumsize=5) ci}{p_end}

{pstd}Fixed-horizon table: CIF at 1, 5, and 8 years with confidence limits{p_end}
{phang2}{cmd:. finegray_cif, attime(1 5 8) ci}{p_end}

{pstd}Curve for a profile of an interaction model{p_end}
{phang2}{cmd:. finegray i.pelnode c.ifp i.pelnode#c.ifp tumsize, compete(status) cause(1)}{p_end}
{phang2}{cmd:. finegray_cif, at(pelnode=1 ifp=20) attime(1 5) ci}{p_end}

{pstd}Curve evaluated on a custom time grid{p_end}
{phang2}{cmd:. finegray_cif, timepoints(1 2 3 4 5 6 7 8) ci}{p_end}

{pstd}Save the numeric estimates behind the curve{p_end}
{phang2}{cmd:. finegray_cif, ci nograph saving(cifcurve.dta,replace)}{p_end}

{pstd}
{bf:One curve per exposure group.} {cmd:finegray_cif} draws one profile per
call, so a grouped figure is built by exporting each profile with
{opt saving()} and combining them on a common grid. Here on
{cmd:webuse hiv_si}, the data of {bf:[ST] stcrreg} example 4.

{phang2}{cmd:. webuse hiv_si, clear}{p_end}
{phang2}{cmd:. gen byte any_event = status > 0}{p_end}
{phang2}{cmd:. stset time, failure(any_event==1) id(patnr)}{p_end}
{phang2}{cmd:. finegray ccr5, compete(status) cause(2)}{p_end}
{phang2}{cmd:. finegray_cif, at(ccr5=0) attime(2 5 10) ci}{p_end}
{phang2}{cmd:. finegray_cif, at(ccr5=1) attime(2 5 10) ci}{p_end}
{phang2}{cmd:. finegray_cif, at(ccr5=0) nograph saving(cif0.dta, replace)}{p_end}
{phang2}{cmd:. finegray_cif, at(ccr5=1) nograph saving(cif1.dta, replace)}{p_end}
{phang2}{cmd:. use cif0.dta, clear}{p_end}
{phang2}{cmd:. gen byte ccr5 = 0}{p_end}
{phang2}{cmd:. append using cif1.dta}{p_end}
{phang2}{cmd:. replace ccr5 = 1 if missing(ccr5)}{p_end}
{phang2}{cmd:. twoway (line cif time if ccr5==0, connect(J)) ///}{p_end}
{phang2}{cmd:.     (line cif time if ccr5==1, connect(J))}{p_end}

{pstd}
{cmd:connect(J)} is what makes the step function a step function; a plain
{cmd:line} interpolates between event times and draws a curve the estimator
never produced.

{pstd}Band by subject bootstrap{p_end}
{phang2}{cmd:. finegray_cif, attime(1 5 8) ci bootstrap(500) seed(12345)}{p_end}

{pstd}After a fit with baseline strata: one curve per stratum{p_end}
{phang2}{cmd:. finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode)}{p_end}
{phang2}{cmd:. finegray_cif, attime(1 5) bstratum(0) ci}{p_end}
{phang2}{cmd:. finegray_cif, attime(1 5) bstratum(1) ci}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray_cif} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(level)}}confidence level{p_end}
{synopt:{cmd:r(cause)}}cause of interest{p_end}
{synopt:{cmd:r(bootstrap_requested)}}requested replications; with {cmd:bootstrap()}{p_end}
{synopt:{cmd:r(bootstrap_success)}}converged replications used; with {cmd:bootstrap()}{p_end}
{synopt:{cmd:r(bootstrap_failed)}}skipped replications; with {cmd:bootstrap()}{p_end}
{synopt:{cmd:r(bstratum)}}baseline stratum evaluated; with {cmd:bstratum()}{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(profile_vars)}}model covariates, in column order of {cmd:r(at)}{p_end}
{synopt:{cmd:r(bstrata)}}baseline stratification variable; with {cmd:bstratum()}{p_end}
{synopt:{cmd:r(se_method)}}how column 3 of {cmd:r(table)} was computed{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}one row per evaluated time{p_end}
{synopt:{cmd:r(at)}}covariate profile used for the curve{p_end}

{pstd}
The columns of {cmd:r(table)} are {cmd:time}, {cmd:cif}, {cmd:se},
{cmd:lci}, and {cmd:uci}.

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb finegray}, {helpb finegray_methods}, {helpb finegray_predict},
{helpb finegray_phtest}, {helpb stcurve}, {helpb stcrreg}

{hline}
