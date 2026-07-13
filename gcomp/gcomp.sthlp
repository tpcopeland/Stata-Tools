{smcl}
{* *! version 1.4.5  13jul2026}{...}
{vieweralsosee "[R] bootstrap" "help bootstrap"}{...}
{vieweralsosee "[R] logit" "help logit"}{...}
{vieweralsosee "[R] regress" "help regress"}{...}
{viewerjumpto "Syntax" "gcomp##syntax"}{...}
{viewerjumpto "Description" "gcomp##description"}{...}
{viewerjumpto "Concepts" "gcomp##concepts"}{...}
{viewerjumpto "Options" "gcomp##options"}{...}
{viewerjumpto "Remarks" "gcomp##remarks"}{...}
{viewerjumpto "Assumptions" "gcomp##assumptions"}{...}
{viewerjumpto "Examples" "gcomp##examples"}{...}
{viewerjumpto "Stored results" "gcomp##results"}{...}
{viewerjumpto "References" "gcomp##references"}{...}
{viewerjumpto "Author" "gcomp##author"}{...}
{viewerjumpto "Also see" "gcomp##seealso"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:gcomp} {hline 2}}G-computation formula via Monte Carlo simulation{p_end}
{p2colreset}{...}

{pstd}
Estimate causal effects in the presence of time-varying confounding or
causal mediation using the parametric g-computation formula with
bootstrap inference.


{marker syntax}{...}
{title:Syntax}

{pstd}
{bf:Time-varying confounding:}

{p 8 17 2}
{cmd:gcomp}
{varlist}
{ifin}
{cmd:,}
{opt out:come(varname)}
{opt com:mands(string)}
{opt eq:uations(string)}
{opt i:dvar(varname)}
{opt t:var(varname)}
{opt var:yingcovariates(varlist)}
{opt intvars(varlist)}
{opt interventions(string)}
[{it:options}]

{pstd}
{bf:Causal mediation:}

{p 8 17 2}
{cmd:gcomp}
{varlist}
{ifin}
{cmd:,}
{opt out:come(varname)}
{opt com:mands(string)}
{opt eq:uations(string)}
{opt mediation}
{opt ex:posure(varlist)}
{opt mediator(varlist)}
{opt base_confs(varlist)}
{it:effect_type}
[{it:options}]

{pstd}
where {it:effect_type} is one of: {opt obe}, {opt oce}, {opt linexp}, {opt specific},
or {opt baseline(string)}.


{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required (both modes)}
{synopt:{opt out:come(varname)}}outcome variable{p_end}
{synopt:{opt com:mands(string)}}model type for each variable{p_end}
{synopt:{opt eq:uations(string)}}prediction equations for each variable{p_end}

{syntab:Required (time-varying)}
{synopt:{opt i:dvar(varname)}}subject identifier variable{p_end}
{synopt:{opt t:var(varname)}}time variable{p_end}
{synopt:{opt var:yingcovariates(varlist)}}time-varying covariates{p_end}
{synopt:{opt intvars(varlist)}}intervention variables{p_end}
{synopt:{opt interventions(string)}}intervention specifications{p_end}

{syntab:Required (mediation)}
{synopt:{opt mediation}}mediation analysis mode{p_end}
{synopt:{opt ex:posure(varlist)}}exposure variable(s){p_end}
{synopt:{opt mediator(varlist)}}mediator variable(s){p_end}
{synopt:{opt base_confs(varlist)}}baseline confounders{p_end}

{syntab:Effect type (mediation)}
{synopt:{opt obe}}observed baseline exposure (binary exposure){p_end}
{synopt:{opt oce}}categorical-exposure contrasts{p_end}
{synopt:{opt linexp}}linear exposure effect{p_end}
{synopt:{opt specific}}specific exposure values{p_end}
{synopt:{opt baseline(string)}}baseline exposure level(s){p_end}
{synopt:{opt alternative(string)}}alternative exposure level(s){p_end}

{syntab:Time-varying options}
{synopt:{opt eofu}}outcome measured only at end of follow-up{p_end}
{synopt:{opt pooled}}pooled logistic regression across visits{p_end}
{synopt:{opt monotreat}}monotone treatment assumption{p_end}
{synopt:{opt dynamic}}dynamic treatment regime{p_end}
{synopt:{opt death(varname)}}competing death variable{p_end}
{synopt:{opt msm(string)}}marginal structural model specification{p_end}
{synopt:{opt fix:edcovariates(varlist)}}time-invariant covariates{p_end}
{synopt:{opt lag:gedvars(varlist)}}variables with lagged effects{p_end}
{synopt:{opt lagrules(string)}}lag specification rules{p_end}
{synopt:{opt derived(varlist)}}deterministically derived variables{p_end}
{synopt:{opt derrules(string)}}derivation rules{p_end}

{syntab:Mediation options}
{synopt:{opt control(string)}}controlled direct effect level(s){p_end}
{synopt:{opt post_confs(varlist)}}post-treatment confounders{p_end}
{synopt:{opt boceam}}single-mediator BOCE-AM with {opt msm()}{p_end}
{synopt:{opt logOR}}report log odds ratio{p_end}
{synopt:{opt logRR}}report log risk ratio{p_end}

{syntab:Imputation}
{synopt:{opt impute(varlist)}}variables to impute missing values{p_end}
{synopt:{opt imp_eq(string)}}imputation equations{p_end}
{synopt:{opt imp_cmd(string)}}imputation model commands{p_end}
{synopt:{opt imp_cycles(#)}}imputation cycles; default is {cmd:10}{p_end}

{syntab:Simulation}
{synopt:{opt sim:ulations(#)}}Monte Carlo sample size; default is sample size{p_end}
{synopt:{opt sam:ples(#)}}bootstrap replications; default is {cmd:1000}{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt minsim}}use expected values instead of random draws{p_end}
{synopt:{opt moreMC}}allow MC sample size > N{p_end}

{syntab:Output}
{synopt:{opt diag:nostics}}display model-fit diagnostics{p_end}
{synopt:{opt all}}report all four CI types{p_end}
{synopt:{opt graph}}graph potential outcomes{p_end}
{synopt:{opt saving(filename)}}save the simulated dataset{p_end}
{synopt:{opt replace}}overwrite existing saved file{p_end}

{syntab:Component models}
{synopt:{opt savem:odels}}store component-model refit approximations{p_end}
{synopt:{opt show:models}}store and display component-model refits{p_end}
{synopt:{opt models:tyle(string)}}{cmd:compact} or {cmd:native} display{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:gcomp} implements Robins' parametric g-computation formula (Robins 1986)
using Monte Carlo simulation. It estimates causal effects in two settings that
are common in epidemiology and the social sciences:

{phang}
{bf:1. Time-varying confounding.}{break}
When a time-varying exposure affects an outcome, but time-varying confounders
also change in response to prior exposure, standard regression adjusts away
part of the effect you want to estimate. G-computation avoids this by
simulating what would have happened to the entire population under each
hypothetical intervention, using parametric models fit to the observed
data. The method produces potential-outcome estimates under each
user-specified treatment regime and can optionally fit a marginal structural
model (MSM) to summarize the causal contrast.

{phang}
{bf:2. Causal mediation.}{break}
When an exposure affects an outcome both directly and through one or more
mediators, and the mediator-outcome confounders are themselves affected by the
exposure, standard mediation methods break down. {cmd:gcomp} decomposes the
total causal effect (TCE) into a natural direct effect (NDE), a natural
indirect effect (NIE), and the proportion mediated (PM). A controlled direct
effect (CDE) is available when you specify {opt control()}.

{pstd}
In both modes, inference is obtained by bootstrapping: the entire simulation
is repeated {opt samples()} times on resampled data, and confidence intervals are
constructed from the bootstrap distribution. Four CI types are
available: normal, percentile, bias-corrected, and bias-corrected and
accelerated (BCa).

{pstd}
Supported model types for the parametric models are {helpb logit} (binary),
{helpb regress} (continuous), {helpb mlogit} (multinomial), and
{helpb ologit} (ordinal). Each variable can use a different model type.


{marker concepts}{...}
{title:Key concepts}

{pstd}
{bf:What the varlist contains.}{break}
The {varlist} identifies the main analysis surface. Variables named in options
or referenced by legal factor-variable terms in {opt equations()} are retained
automatically, so a predictor need not be duplicated positionally. The command
uses collision-free internal aliases and restores the caller's data and sort
order on success and error.

{pstd}
{bf:The commands() and equations() pair.}{break}
These two options work together to define the parametric models. For each
variable that {cmd:gcomp} must simulate, {opt commands()} says {it:which model}
to fit, and {opt equations()} says {it:which predictors} to use. Both use the
same {it:var}{cmd::} {it:value} comma-separated syntax:

{phang2}{cmd:commands(m: logit, y: logit)}{p_end}
{phang2}{cmd:equations(m: x c, y: m x c)}{p_end}

{pstd}
This tells {cmd:gcomp} to fit a logistic regression for {cmd:m} on predictors
{cmd:x} and {cmd:c}, and another logistic regression for {cmd:y} on predictors
{cmd:m}, {cmd:x}, and {cmd:c}.

{pstd}
{bf:How Monte Carlo simulation works.}{break}
{cmd:gcomp} first fits parametric models to the observed data. It then
simulates a copy of the dataset ({opt simulations()} observations) and
generates counterfactual outcomes by stepping through the models in sequence,
drawing random values from the fitted distributions at each step. Under each
intervention, the procedure records the simulated outcomes and computes
contrasts. The bootstrap repeats this entire process {opt samples()} times to
construct confidence intervals.

{pstd}
{bf:Data layout.}{break}
Mediation analyses use {bf:cross-sectional} (wide) data: one row per
subject. Time-varying analyses use {bf:panel} (long) data: one row per subject per
time point, identified by {opt i:dvar()} and {opt t:var()}.


{marker options}{...}
{title:Options}

{dlgtab:Required (both modes)}

{phang}
{opt outcome(varname)} specifies the outcome variable. For mediation, this is
the final outcome (e.g. disease status). For time-varying analyses, this is the
outcome measured at each visit (or at end of follow-up with {opt eofu}).

{phang}
{opt commands(string)} specifies the model type used to simulate each variable. Use
the colon-separated syntax {it:var1}{cmd:: }{it:cmd1}{cmd:, }{it:var2}{cmd:: }{it:cmd2}. Supported model types:{break}
{cmd:logit} {hline 2} logistic regression (binary outcomes){break}
{cmd:regress} {hline 2} linear regression (continuous outcomes){break}
{cmd:mlogit} {hline 2} multinomial logit (unordered categorical outcomes){break}
{cmd:ologit} {hline 2} ordered logit (ordered categorical outcomes)

{phang}
{opt equations(string)} specifies the right-hand-side predictors for each
simulated variable, using the same colon-separated syntax. List only the
predictors, not the dependent variable. For example,
{cmd:equations(m: x c, y: m x c)} means the model for {cmd:m} includes
{cmd:x} and {cmd:c}, and the model for {cmd:y} includes {cmd:m}, {cmd:x},
and {cmd:c}.

{dlgtab:Required (time-varying)}

{phang}
{opt i:dvar(varname)} specifies the subject identifier. Your data must be in
long (panel) format with one row per subject per time point. Each unique value
of {opt i:dvar()} identifies a different subject.

{phang}
{opt t:var(varname)} specifies a numeric ordered visit variable. Gaps and
nonconsecutive values are allowed. Together, {opt idvar()} and {opt tvar()}
must uniquely identify every analytic row, with at least two visit values.

{phang}
{opt varyingcovariates(varlist)} specifies the time-varying confounders that are
both affected by prior exposure and predictive of future outcomes. These are
the variables that make standard regression adjustment biased: they lie on the
causal pathway between past exposure and future outcome, but they are also
confounders of the current exposure-outcome relationship. {cmd:gcomp} fits separate
models for these variables and re-simulates them at each time point under the
hypothetical intervention.

{phang}
{opt intvars(varlist)} specifies which variables receive the
interventions. Typically this is the time-varying exposure. The values
assigned under each intervention are defined in {opt interventions()}.

{phang}
{opt interventions(string)} defines the hypothetical treatment regimes. For
example, {cmd:interventions(A=1, A=0)} creates two scenarios: one where every
subject receives treatment at every time point, and one where no subject
receives treatment. {cmd:gcomp} simulates the population under each regime
and contrasts the outcomes.

{dlgtab:Required (mediation)}

{phang}
{opt mediation} activates the mediation analysis mode. This switches
{cmd:gcomp} from the time-varying confounding workflow to the causal mediation
workflow. The {opt exposure()}, {opt mediator()}, and {opt base_confs()} options
become required, and you must choose an effect type.

{phang}
{opt exposure(varlist)} specifies one or more exposure variables. The exposure
is the variable whose effect you want to decompose into direct and indirect
components. For binary-exposure analyses ({opt obe}), list a single 0/1
variable. For categorical analyses ({opt oce}) or multiple exposures, list the
relevant variables.

{phang}
{opt mediator(varlist)} specifies one or more mediator variables. Mediators are the
variables that lie on the causal pathway between exposure and outcome. The
indirect effect captures the part of the exposure's effect that operates
through the mediator(s).

{phang}
{opt base_confs(varlist)} specifies baseline confounders of both the
exposure-outcome and mediator-outcome relationships. These are variables
measured before the exposure that may bias the estimated effects if not
adjusted for (e.g. age, sex, socioeconomic status). Include all relevant
pre-exposure confounders here.

{dlgtab:Mediation effect types}

{pstd}
You must choose exactly one effect type for mediation analyses. The choice
depends on the nature of the exposure variable:

{phang}
{opt obe} ({bf:o}bserved {bf:b}aseline {bf:e}xposure) is the standard choice
when the exposure is {bf:binary} (0/1). It compares the setting where everyone
is exposed to the setting where no one is exposed, using the observed data
distribution of the exposure as the baseline. This produces the standard TCE,
NDE, NIE, and PM decomposition.

{phang}
{opt oce} ({bf:o}bserved {bf:c}onditional {bf:e}xposure) is for {bf:categorical} exposure variables with
more than two levels. The effect is estimated for each non-baseline level
versus the baseline. If {opt baseline()} is not specified, the lowest observed
exposure level is used as the reference
category. {it:Note: {helpb gcomptab} does not support formatting {opt oce} results.}

{phang}
{opt linexp} specifies a linear exposure effect model, appropriate when you
want to assume that the exposure-outcome relationship is linear on the
relevant scale.

{phang}
{opt specific} lets you define custom exposure comparisons via
{opt baseline()} and {opt alternative()}. Use this when you want to compare
two specific exposure levels that do not fit the {opt obe} or {opt oce}
patterns (e.g. comparing dose level 2 vs. dose level 0).

{phang}
{opt baseline(string)} specifies the reference (baseline) exposure value for
{opt specific} or {opt oce} comparisons. This is the value the exposure would
take in the counterfactual "control" scenario. For a binary exposure,
{cmd:baseline(0)} means unexposed is the reference.

{phang}
{opt alternative(string)} specifies the alternative exposure value for
{opt specific} comparisons. This is the value the exposure would take in the
counterfactual "treated" scenario.

{dlgtab:Time-varying options}

{phang}
{opt eofu} ({bf:e}nd {bf:o}f {bf:f}ollow-{bf:u}p) specifies that the outcome is measured only on the
final row for each subject, rather than at every time point. With this option,
{cmd:gcomp} uses only the last-period outcome value; any earlier nonmissing outcome
values are ignored with a warning. This is appropriate when the outcome is
assessed once at the end of the study (e.g. a cumulative disease diagnosis)
rather than at each visit.

{phang}
{opt pooled} fits a single logistic regression pooled across all visits
rather than separate visit-specific models. This assumes the coefficients are
constant over time, which increases statistical power but is a stronger
assumption.

{phang}
{opt monotreat} imposes a monotone treatment assumption: once a subject
initiates treatment, they cannot discontinue. This is relevant for exposures
like surgical procedures or irreversible policy changes.

{phang}
{opt dynamic} specifies a dynamic treatment regime, where treatment assignment
at each time point depends on the subject's covariate history up to that point
(e.g. "treat if blood pressure exceeds 140 at the current visit").

{phang}
{opt death(varname)} specifies a competing event (death or censoring)
variable. Subjects who experience this event are removed from the risk set in
subsequent time periods. The variable must be binary (0/1) and the model for
it must be specified as {cmd:logit} in {opt commands()}.

{phang}
{opt msm(string)} specifies a marginal structural model to summarize the
causal effect across intervention scenarios. The MSM is fit to the simulated
potential outcomes from the Monte Carlo runs. Useful when you have multiple
intervention levels and want a parsimonious summary.

{phang}
{opt fixedcovariates(varlist)} specifies covariates that are time-invariant
(constant across all visits for a given subject), such as sex or baseline
age. These are included in the parametric models but are {it:not} re-simulated
during the Monte Carlo procedure. They must be listed in the {varlist} but appear only
on the right-hand side of equations.

{phang}
{opt laggedvars(varlist)} specifies variables whose lagged values are used
as predictors. {cmd:gcomp} automatically computes within-subject lags by
time for these variables.

{phang}
{opt lagrules(string)} specifies the lag structure for
{opt laggedvars()}. Syntax: {cmd:lagrules(}{it:lagvar}{cmd:: }{it:sourcevar} {it:lagorder}{cmd:, ...)}. For example,
{cmd:lagrules(Alag: A 1, Llag: L 1)} means {cmd:Alag} is the 1-period lag of {cmd:A}, and {cmd:Llag}
is the 1-period lag of {cmd:L}.

{phang}
{opt derived(varlist)} specifies variables that are deterministic functions
of other variables (e.g. BMI = weight / height{c 178}). These are recomputed
from the simulated values at each Monte Carlo step rather than being modeled
stochastically.

{phang}
{opt derrules(string)} specifies the derivation rules for {opt derived()}.

{dlgtab:Mediation options}

{phang}
{opt control(string)} specifies mediator values for the controlled direct
effect (CDE). Use {cmd:control(0)} for one mediator. With multiple mediators,
use an exact keyed map, for example
{cmd:control(m1: 0, m2: 1)}; positional lists are rejected. Every requested
categorical value must occur in observed support.

{phang}
{opt post_confs(varlist)} specifies post-treatment confounders of the
mediator-outcome relationship. These are confounders that are affected by
the exposure but also confound the mediator-outcome path. Standard mediation
methods cannot handle these without bias; {cmd:gcomp} can, because it
simulates the full joint distribution under interventions.

{phang}
{opt boceam} specifies BOCE-AM (baseline odds conditional on exposure and all
mediators) estimation. It requires a supported {opt msm()} and a
{bf:single} mediator. Calls without {opt msm()} or with multiple mediators are
rejected before simulation. Adding BOCE-AM does not alter TCE/NDE/NIE arms.

{phang}
{opt logOR} reports mediation results on the {bf:log odds ratio} scale instead
of the default risk difference (RD) scale. This is useful when you want effect
estimates on a multiplicative scale.

{phang}
{opt logRR} reports mediation results on the {bf:log risk ratio} scale instead
of the default risk difference (RD) scale.

{dlgtab:Imputation}

{phang}
{opt impute(varlist)} specifies eligible covariates or mediators for single
stochastic imputation. Exposures, outcomes, panel keys, intervention variables,
and death indicators cannot be imputed. Rows are screened for predictor
availability only when the target is missing; target-specific needed,
eligible, and dropped counts are returned in {cmd:e()}.

{phang}
{opt imp_eq(string)} specifies the prediction equations for the imputation models,
using the same {it:var}{cmd::} {it:rhs} syntax as {opt equations()}. Each variable in {opt impute()}
should appear here.

{phang}
{opt imp_cmd(string)} specifies the model commands for imputation, using the
same {it:var}{cmd::} {it:cmd} syntax as {opt commands()}.

{phang}
{opt imp_cycles(#)} specifies the number of chained-equation imputation
cycles. Default is {cmd:10}. More cycles may improve convergence for complex
missing-data patterns. Cross-target cycles are valid fully conditional
specification and are iterated in {opt impute()} order; self-reference is
rejected. This is single imputation, not Rubin-style multiple imputation.

{dlgtab:Simulation}

{phang}
{opt simulations(#)} sets the Monte Carlo sample size — the number of
simulated observations used to estimate potential outcomes in each bootstrap
replicate. Default is the observed sample size. Larger values reduce Monte
Carlo variability but increase computation time. In time-varying mode values
above the number of subjects are capped; {opt moreMC} is not supported there.

{phang}
{opt samples(#)} sets the number of bootstrap replications. The value must be
at least {cmd:2}. Default is {cmd:1000}. This determines the precision of the
confidence intervals: more replications produce more stable intervals. For
exploratory analyses, 200-500 is often sufficient; for publication, 1000 or
more is recommended.

{phang}
{opt seed(#)} sets a positive legal Stata integer seed. Zero, negative,
noninteger, and out-of-domain values are rejected.

{phang}
{opt minsim} uses expected values (predicted probabilities) instead of random
draws for binary outcomes during Monte Carlo simulation. This eliminates Monte
Carlo simulation noise but replaces it with a deterministic approximation that
may introduce bias for nonlinear models.

{phang}
{opt moreMC} allows the Monte Carlo sample size ({opt simulations()}) to exceed
the observed sample size in mediation mode. Time-varying history replication
is not implemented, so {opt moreMC} is rejected in that mode.

{dlgtab:Output}

{phang}
{opt diagnostics} displays model-fit statistics for each parametric model
fitted during the initial (pre-bootstrap) estimation run. For each model the
output shows sample size, convergence status ({cmd:logit}/{cmd:mlogit}/{cmd:ologit}),
goodness of fit (R{c 178} for {cmd:regress}, pseudo-R{c 178} for logit models),
and RMSE ({cmd:regress}). Warnings flag non-convergence, small sample sizes
(N < 20), and poor model fit.{break}
The diagnostics matrix is always stored in {cmd:e(model_diagnostics)} regardless
of whether this option is specified; the option controls only the console
display.

{phang}
{opt all} reports all four confidence interval types: normal, percentile,
bias-corrected, and bias-corrected accelerated (BCa). By default only the
normal CI is reported. The additional CI matrices are stored in {cmd:e()} and
can be extracted after estimation.

{phang}
{opt graph} produces a uniquely named survival graph for non-{opt eofu}
time-varying analyses. It is rejected in mediation and with {opt eofu}; a
caller graph named {cmd:Graph} is never replaced. The created name is returned
in {cmd:e(graph)}.

{phang}
{opt saving(filename)} saves the exact stochastic point-estimate dataset,
including {cmd:_int}, {cmd:_id}, original analysis names, and time-varying
{cmd:_source_id}. Dataset characteristics contain the schema version, arm
mapping, run identifier, RNG state, and analysis type. Bootstrap replicates
are not saved; extended missing codes remain missing in retained observed rows.

{phang}
{opt replace} allows {opt saving()} to overwrite an existing file.

{dlgtab:Component models}

{phang}
{opt savemodels} refits available component specifications once on the
analytic sample and stores them under collision-free persistent names. These
are explicitly {bf:refit approximations}, not guaranteed copies of
simulation-loop fits: nonpooled time-varying models are pooled and loop-only
predictors may be listed in {cmd:e(model_skipped)}. The manifest includes
{cmd:e(model_capture)} and indexed equations. Optional refitting does not
advance the point-estimate simulation RNG stream.

{phang}
{opt showmodels} implies {opt savemodels} and additionally displays the fitted
component models in the Results window, after the parametric-model specification
summary and before the bootstrap progress.

{phang}
{opt modelstyle(style)} sets how {opt showmodels} renders the models: {cmd:compact} (default)
prints a gcomp-styled coefficient table per model with the scale applied
automatically (odds ratios for {cmd:logit}/{cmd:ologit}, relative risk ratios for {cmd:mlogit},
coefficients for {cmd:regress}); {cmd:native} replays each model with Stata's own output.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Before you begin}

{pstd}
Verify that your data are in the correct layout. For mediation analyses, each
subject should have exactly one row (cross-sectional / wide format). For
time-varying analyses, data must be in long format with one row per subject-
time observation, and the {opt i:dvar()} and {opt t:var()} variables must
uniquely identify each row.

{pstd}
Variables named by model/equation options are discovered and retained
automatically. Keep the main outcome, simulated variables, panel keys, and
intervention variables visible in the call for a readable specification.

{pstd}
{bf:Choosing simulation and bootstrap counts}

{pstd}
{opt simulations()} controls Monte Carlo noise in the point
estimate; {opt samples()} controls the precision of confidence intervals. As
a rough guide:{break}
{hline 40}{break}
Exploratory work: {cmd:sim(500) samples(200)}{break}
Moderate precision: {cmd:sim(5000) samples(500)}{break}
Publication quality: {cmd:sim(10000) samples(1000)}{break}
{hline 40}{break}
Computation time scales roughly linearly with {opt samples()}, because each
bootstrap replicate runs the full simulation. Start small and increase until
results stabilize.

{pstd}
{bf:Missing data}

{pstd}
{cmd:gcomp} drops observations with missing values on required variables
({opt i:dvar()}, {opt t:var()}, {opt intvars()}, etc.) and reports how many were
dropped. For intermittent missingness on covariates or mediators, use the
{opt impute()} option to apply single stochastic imputation under MAR.


{marker assumptions}{...}
{title:Estimands, assumptions, and diagnostics}

{pstd}
Causal interpretation requires consistency and well-defined interventions,
positivity for every modeled strategy and relevant history, sequential
exchangeability appropriate to the longitudinal or mediation estimand,
correct specification and temporal ordering of every component model, and no
relevant interference between subjects.

{pstd}
Natural mediation effects additionally require the cross-world assumptions
implied by the selected definition. With multiple ordered mediators, list
them in causal/simulation order; each later mediator is generated conditional
on earlier mediator draws from the same intervention arm. Post-treatment
mediator-outcome confounding requires especially careful scientific
justification.

{pstd}
Model diagnostics can identify nonconvergence and selected lack-of-fit
signals, but they cannot establish exchangeability, positivity, consistency,
causal order, or absence of interference. Single stochastic imputation does
not propagate between-imputation uncertainty. Monte Carlo and bootstrap
approximations also have finite-simulation error; a successful command
requires every requested replication and requested interval to be usable.

{pstd}
{bf:Relationship to SSC gformula}

{pstd}
{cmd:gcomp} is a maintained fork of SSC {cmd:gformula} v1.16 beta by Rhian Daniel. Key
changes include: bug fixes for {opt idvar()} handling and {opt baseline()} auto-detection
with {opt oce}; removal of SSC dependencies ({cmd:ice}); modernized RNG calls
({cmd:runiform()}/{cmd:rnormal()}); double-precision variable generation; {cmd:version 16.0} and
{cmd:set varabbrev off} for safety; refactored internal structure; input validation
and model-fit diagnostics; bundled Excel export via {helpb gcomptab}. The command
syntax is backward-compatible with {cmd:gformula} — existing scripts can usually be
updated by changing the command name.


{marker examples}{...}
{title:Examples}

    {hline}
{pstd}
{bf:Example 1: Mediation analysis with a binary exposure (OBE)}

{pstd}
The simplest mediation setup: a binary exposure {cmd:x}, a binary mediator
{cmd:m}, a binary outcome {cmd:y}, and a continuous confounder {cmd:c}. We
simulate data with known effects so you can verify the output.

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. set obs 1000}{p_end}
{phang2}{cmd:. gen double c = rnormal(50, 10)}{p_end}
{phang2}{cmd:. gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))}{p_end}
{phang2}{cmd:. gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))}{p_end}
{phang2}{cmd:. gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))}{p_end}

{pstd}
Now run {cmd:gcomp}. The {opt sim()} and {opt samples()} values are kept small
for speed; use larger values in real analyses.

{phang2}{cmd:. gcomp y m x c, outcome(y) mediation obe ///}{p_end}
{phang2}{cmd:      exposure(x) mediator(m) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) ///}{p_end}
{phang2}{cmd:      equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      base_confs(c) sim(500) samples(200) seed(42)}{p_end}

{pstd}
The output shows: TCE (total effect of {cmd:x} on {cmd:y}), NDE (direct effect
not through {cmd:m}), NIE (indirect effect through {cmd:m}), and PM (fraction
of the total effect that operates through {cmd:m}).

    {hline}
{pstd}
{bf:Example 2: Adding a controlled direct effect (CDE)}

{pstd}
Add {opt control(0)} to fix the mediator at 0 for all subjects and estimate
the controlled direct effect alongside the natural effects:

{phang2}{cmd:. gcomp y m x c, outcome(y) mediation obe ///}{p_end}
{phang2}{cmd:      exposure(x) mediator(m) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) ///}{p_end}
{phang2}{cmd:      equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      base_confs(c) control(0) sim(500) samples(200) seed(42)}{p_end}

{pstd}
The CDE appears as a fifth column in the output and in {cmd:e(b)}.

    {hline}
{pstd}
{bf:Example 3: Mediation with a categorical exposure (OCE)}

{pstd}
When the exposure has more than two levels, use {opt oce}. Here {cmd:x} takes
values 0, 1, and 2:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 54321}{p_end}
{phang2}{cmd:. set obs 1000}{p_end}
{phang2}{cmd:. gen double c = rnormal()}{p_end}
{phang2}{cmd:. gen double x = floor(runiform() * 3)}{p_end}
{phang2}{cmd:. gen double m = rbinomial(1, invlogit(-0.5 + 0.3 * x + 0.2 * c))}{p_end}
{phang2}{cmd:. gen double y = rbinomial(1, invlogit(-1 + 0.4 * m - 0.2 * x + 0.1 * c))}{p_end}
{phang2}{cmd:. gcomp y m x c, outcome(y) mediation oce ///}{p_end}
{phang2}{cmd:      exposure(x) mediator(m) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) ///}{p_end}
{phang2}{cmd:      equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      base_confs(c) sim(500) samples(200) seed(42)}{p_end}

{pstd}
Each non-baseline exposure level produces its own set of mediation
contrasts. Convenience scalars are stored as {cmd:e(tce_1)}, {cmd:e(nde_1)}, etc.

    {hline}
{pstd}
{bf:Example 4: Time-varying confounding with end-of-follow-up outcome}

{pstd}
Panel data with 120 subjects observed over 3 time points. {cmd:A} is the
time-varying treatment, {cmd:L} is the time-varying confounder affected by
prior treatment, and {cmd:outcome} is measured only on the final row.

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 20260421}{p_end}
{phang2}{cmd:. set obs 360}{p_end}
{phang2}{cmd:. gen long id = ceil(_n / 3)}{p_end}
{phang2}{cmd:. bysort id: gen int time = _n}{p_end}
{phang2}{cmd:. gen double L0 = rnormal()}{p_end}
{phang2}{cmd:. bysort id (time): replace L0 = L0[1]}{p_end}
{phang2}{cmd:. gen byte A = .}{p_end}
{phang2}{cmd:. gen double L = .}{p_end}
{phang2}{cmd:. gen byte Alag = 0}{p_end}
{phang2}{cmd:. gen double Llag = 0}{p_end}

{phang2}{cmd:. bysort id (time): replace L = 0.15 + 0.65 * L0 + rnormal(0, 0.35) if time == 1}{p_end}
{phang2}{cmd:. bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.70 * L + 0.20 * L0)) if time == 1}{p_end}
{phang2}{cmd:. bysort id (time): replace L = 0.10 + 0.60 * L[_n-1] - 0.55 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2}{p_end}
{phang2}{cmd:. bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2}{p_end}
{phang2}{cmd:. bysort id (time): replace L = 0.05 + 0.55 * L[_n-1] - 0.55 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3}{p_end}
{phang2}{cmd:. bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3}{p_end}
{phang2}{cmd:. bysort id (time): replace Alag = A[_n-1] if _n > 1}{p_end}
{phang2}{cmd:. bysort id (time): replace Llag = L[_n-1] if _n > 1}{p_end}
{phang2}{cmd:. gen byte outcome = 0}{p_end}
{phang2}{cmd:. bysort id (time): replace outcome = rbinomial(1, invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3}{p_end}

{phang2}{cmd:. gcomp outcome L0 A L Alag Llag id time, outcome(outcome) ///}{p_end}
{phang2}{cmd:      idvar(id) tvar(time) ///}{p_end}
{phang2}{cmd:      varyingcovariates(L) fixedcovariates(L0) ///}{p_end}
{phang2}{cmd:      laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///}{p_end}
{phang2}{cmd:      commands(A: logit, outcome: logit, L: regress) ///}{p_end}
{phang2}{cmd:      equations(A: L0 L, outcome: Alag Llag L0, L: Alag Llag L0) ///}{p_end}
{phang2}{cmd:      intvars(A) interventions(A=1, A=0) ///}{p_end}
{phang2}{cmd:      sim(120) samples(5) seed(20260421) eofu}{p_end}

{pstd}
This estimates potential outcomes under "always treat" ({cmd:A=1}) and
"never treat" ({cmd:A=0}), accounting for the time-varying confounder
{cmd:L} that is both a predictor of treatment and affected by past treatment.

    {hline}
{pstd}
{bf:Example 5: Model-fit diagnostics}

{pstd}
Add {opt diagnostics} to display model-fit statistics during the initial run:

{phang2}{cmd:. gcomp y m x c, outcome(y) mediation obe ///}{p_end}
{phang2}{cmd:      exposure(x) mediator(m) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) ///}{p_end}
{phang2}{cmd:      equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      base_confs(c) sim(500) samples(200) seed(42) diagnostics}{p_end}

{pstd}
The diagnostics table reports N, convergence, R{c 178}/pseudo-R{c 178}, and
RMSE for each model. The matrix is also stored in {cmd:e(model_diagnostics)}:

{phang2}{cmd:. mat list e(model_diagnostics)}{p_end}

    {hline}
{pstd}
{bf:Example 6: Export mediation results to Excel}

{pstd}
After running a supported mediation model (Examples 1-2), use {helpb gcomptab}
to produce a publication-ready Excel table:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Table 1") ///}{p_end}
{phang2}{cmd:      title("Causal Mediation: Smoking Effect via Inflammation")}{p_end}

    {hline}
{pstd}
{bf:Example 7: Extracting results after estimation}

{pstd}
All results are available in {cmd:e()} after estimation. Useful post-estimation
commands:

{phang2}{cmd:. * Point estimates and standard errors}{p_end}
{phang2}{cmd:. ereturn list}{p_end}
{phang2}{cmd:. mat list e(b)}{p_end}
{phang2}{cmd:. mat list e(se)}{p_end}
{phang2}{cmd:. mat list e(ci_normal)}{p_end}

{phang2}{cmd:. * Convenience scalars (mediation, non-oce)}{p_end}
{phang2}{cmd:. display "TCE = " e(tce) ", SE = " e(se_tce)}{p_end}
{phang2}{cmd:. display "NDE = " e(nde) ", SE = " e(se_nde)}{p_end}
{phang2}{cmd:. display "NIE = " e(nie) ", SE = " e(se_nie)}{p_end}
{phang2}{cmd:. display "PM  = " e(pm)  ", SE = " e(se_pm)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:gcomp} stores the following in {cmd:e()}:

{synoptset 29 tabbed}{...}
{p2col 5 29 33 2: Sample and resampling scalars}{p_end}
{synopt:{cmd:e(N)}}rows (mediation) or subjects (time-varying){p_end}
{synopt:{cmd:e(N_rows)}}analytic rows{p_end}
{synopt:{cmd:e(N_subjects)}}analytic subjects{p_end}
{synopt:{cmd:e(MC_sims)}}actual Monte Carlo size{p_end}
{synopt:{cmd:e(samples)}}requested bootstrap count (legacy name){p_end}
{synopt:{cmd:e(bootstrap_requested)}}requested bootstrap count{p_end}
{synopt:{cmd:e(bootstrap_attempted)}}attempted bootstrap count{p_end}
{synopt:{cmd:e(bootstrap_successful)}}successful bootstrap count{p_end}
{synopt:{cmd:e(bootstrap_failed)}}failed bootstrap count{p_end}
{synopt:{cmd:e(seed)}}supplied seed, when present{p_end}
{synopt:{cmd:e(N_impute_targets)}}number of imputation targets{p_end}
{synopt:{cmd:e(impute_needed_}{it:#}{cmd:)}}missing target rows before eligibility{p_end}
{synopt:{cmd:e(impute_eligible_}{it:#}{cmd:)}}eligible target rows{p_end}
{synopt:{cmd:e(impute_dropped_}{it:#}{cmd:)}}unusable target rows dropped{p_end}
{synopt:{cmd:e(N_models)}}stored refit count{p_end}

{p2col 5 29 33 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}named point-estimate vector{p_end}
{synopt:{cmd:e(V)}}full bootstrap covariance matrix{p_end}
{synopt:{cmd:e(se)}}standard-error vector{p_end}
{synopt:{cmd:e(ci_normal)}}normal CI; rows are lower, upper{p_end}
{synopt:{cmd:e(ci_percentile)}}percentile CI with {cmd:all}{p_end}
{synopt:{cmd:e(ci_bc)}}bias-corrected CI with {cmd:all}{p_end}
{synopt:{cmd:e(ci_bca)}}BCa CI with {cmd:all}{p_end}
{synopt:{cmd:e(effects)}}named mediation-effect table{p_end}
{synopt:{cmd:e(model_diagnostics)}}component diagnostic matrix{p_end}

{p2col 5 29 33 2: Replay and design macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:gcomp}{p_end}
{synopt:{cmd:e(cmdline)}}complete command line{p_end}
{synopt:{cmd:e(analysis_type)}}{cmd:mediation} or {cmd:time_varying}{p_end}
{synopt:{cmd:e(outcome)}}outcome name{p_end}
{synopt:{cmd:e(exposure)}}mediation exposure names{p_end}
{synopt:{cmd:e(mediator)}}mediation mediator names{p_end}
{synopt:{cmd:e(mediation_type)}}mediation estimand family{p_end}
{synopt:{cmd:e(scale)}}{cmd:RD}, {cmd:logOR}, or {cmd:logRR}{p_end}
{synopt:{cmd:e(idvar)}}panel identifier name{p_end}
{synopt:{cmd:e(tvar)}}panel time name{p_end}
{synopt:{cmd:e(intvars)}}intervention variable names{p_end}
{synopt:{cmd:e(interventions)}}intervention rules{p_end}
{synopt:{cmd:e(msm)}}MSM specification in either mode{p_end}
{synopt:{cmd:e(msm_colnames)}}full posted MSM parameter names{p_end}
{synopt:{cmd:e(run_id)}}point-estimate run identifier{p_end}
{synopt:{cmd:e(rngstate)}}initial point-estimate RNG state{p_end}
{synopt:{cmd:e(graph)}}created survival graph name{p_end}
{synopt:{cmd:e(saving)}}saved point-data path{p_end}
{synopt:{cmd:e(saved_schema_version)}}saved-file schema version{p_end}
{synopt:{cmd:e(saved_arm_schema)}}saved-file arm mapping{p_end}
{synopt:{cmd:e(impute_targets)}}ordered imputation targets{p_end}
{synopt:{cmd:e(impute_target_}{it:#}{cmd:)}}indexed imputation target name{p_end}
{synopt:{cmd:e(model_names)}}stored refit names{p_end}
{synopt:{cmd:e(model_cmds)}}stored refit commands{p_end}
{synopt:{cmd:e(model_depvars)}}stored refit dependent variables{p_end}
{synopt:{cmd:e(model_eq_}{it:#}{cmd:)}}stored refit equation{p_end}
{synopt:{cmd:e(model_skipped)}}unavailable refit targets{p_end}
{synopt:{cmd:e(model_capture)}}refit-approximation label{p_end}

{pstd}
{bf:Convenience scalars} (mediation without {cmd:oce}):

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:e(tce)}}total causal effect{p_end}
{synopt:{cmd:e(nde)}}natural direct effect{p_end}
{synopt:{cmd:e(nie)}}natural indirect effect{p_end}
{synopt:{cmd:e(pm)}}proportion mediated{p_end}
{synopt:{cmd:e(cde)}}controlled direct effect (only with {cmd:control()}){p_end}
{synopt:{cmd:e(se_tce)}}SE of total causal effect{p_end}
{synopt:{cmd:e(se_nde)}}SE of natural direct effect{p_end}
{synopt:{cmd:e(se_nie)}}SE of natural indirect effect{p_end}
{synopt:{cmd:e(se_pm)}}SE of proportion mediated{p_end}
{synopt:{cmd:e(se_cde)}}SE of controlled direct effect{p_end}

{pstd}
{bf:Convenience scalars} (mediation with {cmd:oce}, {it:j}=1,...,{it:K}-1):

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:e(tce_}{it:j}{cmd:)}}TCE for exposure level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(nde_}{it:j}{cmd:)}}NDE for exposure level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(nie_}{it:j}{cmd:)}}NIE for exposure level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(pm_}{it:j}{cmd:)}}PM for exposure level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(cde_}{it:j}{cmd:)}}CDE for exposure level {it:j} vs. baseline (with {cmd:control()}){p_end}

{pstd}
{bf:Time-varying mode:}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:e(obs_data)}}observed outcome mean{p_end}

{pstd}
{cmd:e(sample)} marks original analytic rows. Successful calls require
{cmd:e(bootstrap_successful)==e(bootstrap_requested)} and
{cmd:e(bootstrap_failed)==0}.

{pstd}
{cmd:e(model_diagnostics)} columns are {cmd:N}, {cmd:converged}, {cmd:ll},
{cmd:r2}, and {cmd:rmse}; inapplicable cells are missing. Rows identify the
modeled variable and, for visit-specific fits, the visit.

{pstd}
Saved data use {cmd:_int} for the arm and {cmd:_id} for simulation identity,
and time-varying output also contains {cmd:_source_id}. Arm {cmd:0} is observed
analytic data. Time-varying arms {cmd:1..K} follow {opt interventions()} order
and {cmd:K+1} is the simulated observed regime. The dataset characteristic
{cmd:gcomp_arm_schema} records the exact mediation mapping and auxiliary arms.


{marker references}{...}
{title:References}

{phang}
Daniel RM, De Stavola BL, Cousens SN (2011). gformula: Estimating causal
effects in the presence of time-varying confounding or mediation using the
g-computation formula. {it:The Stata Journal} 11(4):479-517.

{phang}
Daniel RM, De Stavola BL, Cousens SN, Vansteelandt S (2015). Causal
mediation analysis with multiple mediators. {it:Biometrics} 71(1):1-14.

{phang}
Robins JM (1986). A new approach to causal inference in mortality studies with
a sustained exposure period — application to control of the healthy worker
survivor effect. {it:Mathematical Modelling} 7(9-12):1393-1512.

{phang}
Taubman SL, Robins JM, Mittleman MA, Hernan MA (2009). Intervening on risk
factors for coronary heart disease: an application of the parametric
g-formula. {it:International Journal of Epidemiology} 38(6):1599-1611.

{phang}
VanderWeele TJ (2015). {it:Explanation in causal inference: methods for mediation}
{it:and interaction}. Oxford University Press.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.4.5, 2026-07-13{p_end}

{pstd}
This is a maintained fork of SSC {cmd:gformula} v1.16 beta (Rhian Daniel,
London School of Hygiene and Tropical Medicine).


{marker seealso}{...}
{title:Also see}

{psee}
Online: {helpb gcomptab}, {helpb bootstrap}, {helpb logit}, {helpb regress},
{helpb mlogit}, {helpb ologit}

{hline}
