{smcl}
{* *! version 1.0.2  26apr2026}{...}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "[XT] xtgee" "help xtgee"}{...}
{vieweralsosee "[ME] mixed" "help mixed"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{viewerjumpto "Syntax" "iivw_fit##syntax"}{...}
{viewerjumpto "Description" "iivw_fit##description"}{...}
{viewerjumpto "Options" "iivw_fit##options"}{...}
{viewerjumpto "Remarks" "iivw_fit##remarks"}{...}
{viewerjumpto "Interpreting results" "iivw_fit##interpreting"}{...}
{viewerjumpto "Examples" "iivw_fit##examples"}{...}
{viewerjumpto "Stored results" "iivw_fit##results"}{...}
{viewerjumpto "References" "iivw_fit##references"}{...}
{viewerjumpto "Author" "iivw_fit##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:iivw_fit} {hline 2}}Fit weighted outcome model for IIW analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_fit}
{depvar}
{indepvars}
{ifin}
[{cmd:,} {it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Model}
{synopt:{opt mod:el(string)}}estimation method: {cmd:gee} (default) or {cmd:mixed}{p_end}
{synopt:{opt fam:ily(string)}}GEE family (default: {cmd:gaussian}){p_end}
{synopt:{opt lin:k(string)}}GEE link function (default: canonical){p_end}
{synopt:{opt time:spec(string)}}time specification: {cmd:linear} (default), {cmd:quadratic}, {cmd:cubic}, {cmd:ns(#)}, {cmd:none}{p_end}
{synopt:{opt int:eraction(varlist)}}create time x covariate interaction terms{p_end}
{synopt:{opt categ:orical(varlist)}}expand categorical predictors into labeled dummies{p_end}
{synopt:{opt base:cat(#)}}reference category for {opt categorical()} (default: lowest value){p_end}

{syntab:Standard errors}
{synopt:{opt cl:uster(varname)}}clustering variable (default: id from metadata){p_end}
{synopt:{opt boot:strap(#)}}bootstrap replicates (default: 0 = sandwich SE){p_end}

{syntab:Reporting}
{synopt:{opt l:evel(#)}}confidence level (default: 95){p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt replace}}overwrite existing time/categorical/interaction variables{p_end}
{synopt:{opt col:lect}}enable Stata's {cmd:collect} framework for table building{p_end}
{synopt:{opt gee:opts(string)}}additional options passed to {cmd:glm}{p_end}
{synopt:{opt mixed:opts(string)}}additional options passed to {cmd:mixed}{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_fit} fits a weighted outcome model using weights computed by
{helpb iivw_weight}.  It supports GEE-equivalent estimation via
{cmd:glm} with clustered standard errors, and mixed-effects models via
{cmd:mixed}.

{pstd}
For GEE models, {cmd:glm} with {cmd:vce(cluster)} is used, which is
equivalent to GEE with independence working correlation and robust standard
errors.  This is the estimation method required by IIW theory (Buzkova &
Lumley 2007).

{pstd}
The command automatically retrieves the weight variable, panel ID, time
variable, and weight type from dataset characteristics stored by
{cmd:iivw_weight}.  You do not need to re-specify panel structure.

{pstd}
{bf:What the command does.}  {cmd:iivw_fit} takes your outcome variable and
predictors, optionally builds time trend variables and interaction terms,
and fits a weighted regression.  It displays both the underlying model
output (from {cmd:glm} or {cmd:mixed}) and a formatted summary table of
the weighted effects with coefficients, standard errors, confidence
intervals, and p-values.


{marker options}{...}
{title:Options}

{dlgtab:Model}

{phang}
{opt model(string)} specifies the estimation method.  {cmd:gee} (the default)
fits a GLM with clustered robust standard errors via {cmd:glm}, equivalent to
independence working correlation GEE.  {cmd:mixed} fits a mixed-effects model
via {cmd:mixed} with a random intercept per subject (requires Stata 17+).

{phang}
{opt family(string)} specifies the GLM family distribution for GEE models.
Default is {cmd:gaussian} (identity link, for continuous outcomes).  Other
common choices: {cmd:binomial} for binary outcomes, {cmd:poisson} for count
outcomes.  Only used when {cmd:model(gee)} is specified.

{phang}
{opt link(string)} specifies the GLM link function.  If omitted, the canonical
link for the specified family is used (identity for gaussian, logit for
binomial, log for poisson).  Override when you need a non-canonical link (e.g.,
{cmd:family(binomial) link(log)} for risk ratios).

{phang}
{opt time:spec(string)} specifies how time enters the outcome model.
{cmd:linear} (default) includes the time variable as a single linear term.
{cmd:quadratic} adds time and time-squared.
{cmd:cubic} adds time, time-squared, and time-cubed.
{cmd:ns(#)} uses a natural cubic spline with {it:#} degrees of freedom,
which allows flexible nonlinear trends while remaining stable at the
boundaries.
{cmd:none} excludes time from the model entirely.

{pmore}
The time variables are built from the time variable stored by
{cmd:iivw_weight}.  For polynomial specifications, variables named
{it:prefix}{cmd:time_sq} and {it:prefix}{cmd:time_cu} are created.  For
natural splines, variables named {it:prefix}{cmd:tns1}, {it:prefix}{cmd:tns2},
etc. are created.

{phang}
{opt interaction(varlist)} creates product terms between each specified
covariate and every time variable from {opt timespec()}.  This allows
covariate effects to change over time.  For example, with
{cmd:timespec(linear)}, one interaction variable is created per covariate
(covariate x time).  With {cmd:timespec(quadratic)}, two are created
(covariate x time, covariate x time-squared).  With {cmd:ns(#)}, {it:#}
interaction variables are created per covariate.

{pmore}
Not compatible with {cmd:timespec(none)}, since there are no time variables
to interact with.

{pmore}
Interaction variables are named {cmd:_iivw_ix_{it:covar}_{it:suffix}} where
{it:suffix} is {cmd:time}, {cmd:tsq}, {cmd:tcu}, or {cmd:tnsN}.  Names
longer than 32 characters are truncated with a warning.

{pmore}
If a variable in {opt interaction()} is not included in {it:indepvars}, a
note is displayed (its main effect is absent from the model).

{phang}
{opt categorical(varlist)} specifies variables in {it:indepvars} to expand
into indicator (dummy) variables.  For each variable, one dummy is created per
non-reference level.  If the variable has value labels, dummies are named using
sanitized labels (e.g., {cmd:_iivw_cat_highdose} for "High dose") and labeled
with "High dose (vs. Placebo)".  Without value labels, numeric naming is used
(e.g., {cmd:_iivw_cat_region_2} labeled "region=2 (vs. 1)").

{pmore}
The original variable is replaced by its dummies in the predictor list.  If
the variable also appears in {opt interaction()}, its dummies are interacted
with time variables.  Interaction names strip the {cmd:_iivw_cat_} prefix for
readability (e.g., {cmd:_iivw_ix_highdose_time}).

{pmore}
Variables must have integer values and at least two unique levels.  If
sanitized labels produce name collisions, all levels of that variable fall
back to numeric naming.  Names longer than 32 characters are truncated with
a note.

{phang}
{opt basecat(#)} specifies the reference (base) category for all variables in
{opt categorical()}.  Must be an integer.  If the specified value is not found
in a variable's levels, the lowest value is used with a note.  Requires
{opt categorical()}.

{dlgtab:Standard errors}

{phang}
{opt cluster(varname)} specifies the clustering variable for sandwich standard
errors.  Default is the panel ID variable stored by {cmd:iivw_weight}.  You
rarely need to change this, but it is available for designs where the
clustering level differs from the panel ID (e.g., clustering at the clinic
level when patients are nested within clinics).

{phang}
{opt bootstrap(#)} specifies the number of bootstrap replicates.  When
{cmd:bootstrap(0)} (the default), sandwich standard errors are used.  When
positive, the {cmd:bootstrap} prefix is applied with clustering at the
subject level.

{pmore}
{bf:Important:} the bootstrap treats the IIW/IPTW weights as fixed
and does not re-estimate them in each draw.  Standard errors therefore
reflect outcome model uncertainty only, not weight estimation uncertainty.
This is the standard approach in the IIW literature (Buzkova & Lumley 2007).
If you need standard errors that account for weight estimation, implement a
custom bootstrap that re-runs both {cmd:iivw_weight} and {cmd:iivw_fit}
within each replicate.

{dlgtab:Reporting}

{phang}
{opt level(#)} specifies the confidence level for confidence intervals.
Default is 95.

{phang}
{opt nolog} suppresses the iteration log from the underlying {cmd:glm} or
{cmd:mixed} command.

{phang}
{opt replace} allows overwriting existing time, categorical, and interaction
variables created by a previous {cmd:iivw_fit} call.  Without {opt replace},
the command errors if any generated variable already exists.

{phang}
{opt col:lect} adds the {cmd:collect:} prefix to the underlying estimation
command, enabling Stata's {cmd:collect} framework for building multi-model
tables.  Use this when combining results from multiple {cmd:iivw_fit} calls
into a single table via {helpb collect} or {helpb regtab}.

{phang}
{opt gee:opts(string)} passes additional options directly to {cmd:glm}.

{phang}
{opt mixed:opts(string)} passes additional options directly to {cmd:mixed}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Independence working correlation}

{pstd}
The GEE model uses {cmd:glm} with {cmd:vce(cluster)}, which is mathematically
equivalent to GEE with independence working correlation and robust standard
errors.  This structure is required by IIW theory: the weights correct for
the informative visit process, and the independence assumption avoids
modeling within-subject correlation (which is already accounted for by the
weights).

{pstd}
{bf:Prerequisites}

{pstd}
{cmd:iivw_weight} must be run before {cmd:iivw_fit}.  The weight variable and
metadata are read from dataset characteristics set by {cmd:iivw_weight}.  If
you modify the dataset between the two commands (e.g., dropping observations
or replacing variables), the metadata may become stale.  In that case, re-run
{cmd:iivw_weight}.

{pstd}
{bf:Mixed vs. GEE}

{pstd}
The GEE model (default) estimates a marginal (population-averaged) treatment
effect: the average effect of treatment across all subjects.  This is what IIW
theory is designed for (Buzkova & Lumley 2007).

{pstd}
The mixed model ({cmd:model(mixed)}) adds a subject-specific random intercept
and estimates a conditional (subject-specific) treatment effect.  Use it only
when a conditional interpretation is specifically needed and you understand
that the IIW theoretical justification is for marginal models.  The mixed model
requires Stata 17 or later.

{pstd}
{bf:Choosing timespec}

{pstd}
The choice of time specification affects the estimated treatment effect.
{cmd:timespec(linear)} assumes a constant rate of change over time,
appropriate when the outcome trends linearly.  {cmd:timespec(ns(3))} or
{cmd:timespec(ns(4))} allows flexible nonlinear trends, preferable when
the outcome trajectory has curvature (e.g., rapid early change that
plateaus).

{pstd}
Practical guidance: start with {cmd:linear}, then compare to {cmd:ns(3)}.
If the treatment effect changes substantially, the relationship between
time and outcome is nonlinear and the spline specification is more
appropriate.  Quadratic and cubic specifications are available but natural
splines are generally more stable at the boundaries of the time range.

{pstd}
{bf:Convergence}

{pstd}
After fitting the GEE or mixed model, {cmd:iivw_fit} checks whether the
estimation converged.  If not, a warning is displayed.  Non-convergence
typically indicates model misspecification, collinear predictors, or
extreme weights.  This check is skipped when using {opt bootstrap()},
since the bootstrap wrapper does not expose convergence status.

{pstd}
{bf:Table export with collect and regtab}

{pstd}
{cmd:iivw_fit} is an {cmd:eclass} command and works with Stata's {cmd:collect}
framework.  Use the {opt collect} option or the {cmd:collect:} prefix to
accumulate results across models, then export with {helpb regtab} (from
the {cmd:tabtools} package; install separately if needed).

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_fit score drug age severity_bl, model(gee) collect}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet(IIW) coef(Coef.) title(IIW Model)}{p_end}

{pstd}
To compare multiple weighting strategies side by side:

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(t) visit_cov(x1) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. iivw_fit y treated age, model(gee) nolog collect}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(t) visit_cov(x1) treat(treated) treat_cov(age) truncate(1 99) replace nolog}{p_end}
{phang2}{cmd:. iivw_fit y treated age, model(gee) nolog collect}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet(Compare) models(IIW \ FIPTIW) coef(Coef.) stats(n)}{p_end}


{marker interpreting}{...}
{title:Interpreting results}

{pstd}
{bf:Coefficients.}  With {cmd:model(gee)} and the default {cmd:family(gaussian)},
coefficients are interpreted as the change in the outcome for a one-unit
change in the predictor, averaged over the population.  For example, a
coefficient of -0.7 on {cmd:treated} means that, after reweighting for
informative visit timing, treatment is associated with a 0.7-unit decrease
in the outcome on average.

{pstd}
{bf:Treatment effect.}  The coefficient on the treatment variable is the
primary quantity of interest.  With IIW or FIPTIW weights, this estimates
the causal treatment effect under the assumption that the visit intensity
model and (for FIPTIW) the propensity score model are correctly specified,
and that there is no unmeasured confounding.

{pstd}
{bf:Time variables.}  When {opt timespec()} is not {cmd:none}, the model
includes one or more time trend variables.  These capture the average
trajectory of the outcome over time, after removing the effect of treatment
and other covariates.  With {cmd:timespec(linear)}, the time coefficient is
the per-unit-time rate of change.

{pstd}
{bf:Interactions.}  When {opt interaction(treated)} is specified, the model
includes a treatment x time product term.  The coefficient on this interaction
represents how much the treatment effect changes per unit of time.  A
positive interaction means the treatment becomes less protective (or more
harmful) over time; a negative interaction means it becomes more protective.

{pstd}
{bf:Standard errors.}  By default, standard errors are sandwich (robust)
standard errors clustered at the subject level.  These are consistent even
under misspecification of the within-subject correlation structure, but they
do not account for uncertainty in the weight estimation.  If you need to
account for weight estimation uncertainty, use a custom bootstrap (see
{opt bootstrap()} in the Options section).


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup example data and weights}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 20260417}{p_end}
{phang2}{cmd:. set obs 320}{p_end}
{phang2}{cmd:. gen long id = ceil(_n/4)}{p_end}
{phang2}{cmd:. bysort id: gen byte visit = _n}{p_end}
{phang2}{cmd:. gen double days = (visit - 1) * 90 + runiform() * 20}{p_end}
{phang2}{cmd:. replace days = 0 if visit == 1}{p_end}
{phang2}{cmd:. gen double edss_bl = 2 + 3 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace edss_bl = edss_bl[1]}{p_end}
{phang2}{cmd:. gen double age = 35 + 15 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace age = age[1]}{p_end}
{phang2}{cmd:. gen byte sex = runiform() > 0.5}{p_end}
{phang2}{cmd:. bysort id: replace sex = sex[1]}{p_end}
{phang2}{cmd:. gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))}{p_end}
{phang2}{cmd:. bysort id: replace treated = treated[1]}{p_end}
{phang2}{cmd:. gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)}{p_end}
{phang2}{cmd:. gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))}{p_end}
{phang2}{cmd:. gen byte treatment = cond(treated == 0, 0, cond(edss_bl < 3.5, 1, 2))}{p_end}
{phang2}{cmd:. label define arm 0 "Placebo" 1 "Low dose" 2 "High dose"}{p_end}
{phang2}{cmd:. label values treatment arm}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog}{p_end}

{pstd}
{bf:Example 1: Basic GEE model with linear time}

{pstd}
The simplest specification: a continuous outcome with treatment, a baseline
covariate, and a linear time trend.

{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) timespec(linear)}{p_end}

{pstd}
{bf:Example 2: Quadratic time specification}

{pstd}
Allow the outcome trajectory to curve over time.  Adds a time-squared term.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(quadratic) replace}{p_end}

{pstd}
{bf:Example 3: Natural spline for time}

{pstd}
More flexible than polynomial time.  Natural splines with 3 degrees of freedom
allow the outcome trajectory to bend at internal knots while staying linear
beyond the boundaries.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(ns(3)) replace}{p_end}

{pstd}
{bf:Example 4: Treatment x time interaction}

{pstd}
Test whether the treatment effect changes over time.  The interaction term
captures the rate at which the treatment effect grows or shrinks per unit
of time.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(linear) interaction(treated) replace}{p_end}

{pstd}
{bf:Example 5: Bootstrap standard errors}

{pstd}
Use bootstrap standard errors (500 replicates) instead of sandwich SEs.
Note: the bootstrap does not re-estimate weights, so SEs reflect only
outcome model uncertainty.

{phang2}{cmd:. iivw_fit edss treated edss_bl, bootstrap(500) nolog replace}{p_end}

{pstd}
{bf:Example 6: Binary outcome (binomial family)}

{pstd}
Model a binary outcome (relapse) with logistic link.  Coefficients are log
odds ratios.

{phang2}{cmd:. iivw_fit relapse treated edss_bl, family(binomial) link(logit) replace}{p_end}

{pstd}
{bf:Example 7: Export results to Excel}

{pstd}
Use the {opt collect} option to accumulate results, then export with
{cmd:regtab}.

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) nolog replace collect}{p_end}
{phang2}{cmd:. regtab, xlsx(iivw_results.xlsx) sheet(Results) title(IIW Analysis) stats(n)}{p_end}

{pstd}
{bf:Example 8: Treatment x time interaction with natural spline}

{pstd}
Allow the treatment effect to vary flexibly over time.  With {cmd:ns(3)},
three interaction variables are created (one per spline basis), capturing
nonlinear treatment effect trajectories.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(ns(3)) interaction(treated) replace}{p_end}

{pstd}
{bf:Example 9: Multiple covariate interactions}

{pstd}
Allow both treatment and age effects to vary over time.

{phang2}{cmd:. iivw_fit edss treated age edss_bl, timespec(quadratic) interaction(treated age) replace}{p_end}

{pstd}
{bf:Example 10: Compare IIW vs FIPTIW in one table}

{pstd}
Run two weighting strategies and combine them in a single Excel table.

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) nolog collect}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) treat(treated) treat_cov(age sex edss_bl) truncate(1 99) replace nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) nolog replace collect}{p_end}
{phang2}{cmd:. regtab, xlsx(iivw_results.xlsx) sheet(Comparison) models(IIW \ FIPTIW) title(IIW vs FIPTIW) stats(n) noint}{p_end}

{pstd}
{bf:Example 11: Categorical predictor with value labels}

{pstd}
Expand a multi-level treatment variable into labeled dummy variables.  The
reference category is the lowest level by default.

{phang2}{cmd:. iivw_fit edss treatment edss_bl, categorical(treatment) replace}{p_end}

{pstd}
{bf:Example 12: Custom base category}

{pstd}
Set "High dose" (coded as 2) as the reference category instead of
"Placebo" (coded as 0).

{phang2}{cmd:. iivw_fit edss treatment edss_bl, categorical(treatment) basecat(2) replace}{p_end}

{pstd}
{bf:Example 13: Categorical with interaction}

{pstd}
Interact each treatment level with nonlinear time.  Each non-reference
level gets its own set of time interaction terms.

{phang2}{cmd:. iivw_fit edss treatment edss_bl, timespec(ns(3)) categorical(treatment) interaction(treatment) replace}{p_end}

{pstd}
{bf:Example 14: Exclude time from the model}

{pstd}
When the outcome has no time trend or when time is already included as a
predictor in {it:indepvars}, use {cmd:timespec(none)} to skip automatic
time variable creation.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(none) replace}{p_end}

{pstd}
{bf:Example 15: Mixed-effects model (Stata 17+)}

{pstd}
Fit a mixed model with a random intercept per subject.  This estimates
a conditional (subject-specific) treatment effect rather than the marginal
(population-averaged) effect.

{phang2}{cmd:. iivw_fit edss treated edss_bl, model(mixed) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_fit} stores the results from the underlying {cmd:glm} or
{cmd:mixed} command in {cmd:e()}, plus the following:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:e(iivw_cmd)}}{cmd:iivw_fit}{p_end}
{synopt:{cmd:e(iivw_model)}}estimation method (gee or mixed){p_end}
{synopt:{cmd:e(iivw_weighttype)}}weight type (iivw, iptw, or fiptiw){p_end}
{synopt:{cmd:e(iivw_timespec)}}time specification used{p_end}
{synopt:{cmd:e(iivw_weight_var)}}weight variable name{p_end}
{synopt:{cmd:e(iivw_cluster)}}clustering variable used{p_end}
{synopt:{cmd:e(iivw_interaction)}}variables specified in {opt interaction()}{p_end}
{synopt:{cmd:e(iivw_ix_vars)}}interaction variables created{p_end}
{synopt:{cmd:e(iivw_categorical)}}variables specified in {opt categorical()}{p_end}
{synopt:{cmd:e(iivw_cat_vars)}}categorical dummy variables created{p_end}

{pstd}
All standard post-estimation commands for {cmd:glm} or {cmd:mixed} are
available after {cmd:iivw_fit}.  For example, {cmd:predict}, {cmd:lincom},
{cmd:test}, and {cmd:margins} work as usual.


{marker references}{...}
{title:References}

{phang}
Buzkova P, Lumley T. 2007.
Longitudinal data analysis for generalized linear models with follow-up
dependent on outcome-related variables.
{it:Canadian Journal of Statistics} 35: 485-500.

{phang}
Lin H, Scharfstein DO, Rosenheck RA. 2004.
Analysis of longitudinal data with irregular, outcome-dependent follow-up.
{it:JRSS-B} 66: 791-813.

{phang}
Tompkins G, Dubin JA, Wallace M. 2025.
On flexible inverse probability of treatment and intensity weighting.
{it:Statistical Methods in Medical Research}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.2, 2026-04-26{p_end}


{title:Also see}

{psee}
Online:  {helpb iivw}, {helpb iivw_weight}, {helpb regtab}, {helpb glm}, {helpb xtgee}, {helpb mixed}

{hline}
