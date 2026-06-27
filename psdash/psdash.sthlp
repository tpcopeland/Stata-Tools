{smcl}
{* *! version 1.3.0  14jun2026}{...}
{vieweralsosee "[TE] teffects" "help teffects"}{...}
{vieweralsosee "[R] logit" "help logit"}{...}
{vieweralsosee "[TE] tebalance" "help tebalance"}{...}
{viewerjumpto "Syntax" "psdash##syntax"}{...}
{viewerjumpto "Description" "psdash##description"}{...}
{viewerjumpto "Subcommands" "psdash##subcommands"}{...}
{viewerjumpto "Options" "psdash##options"}{...}
{viewerjumpto "Remarks" "psdash##remarks"}{...}
{viewerjumpto "Examples" "psdash##examples"}{...}
{viewerjumpto "Stored results" "psdash##results"}{...}
{viewerjumpto "Author" "psdash##author"}{...}
{title:Title}

{phang}
{bf:psdash} {hline 2} Propensity score diagnostics dashboard


{marker syntax}{...}
{title:Syntax}

{phang}
{cmd:psdash} {it:subcommand} [{it:treatment}] [{it:psvar}] [{it:{help if}}] [{it:{help in}}] [{cmd:,} {it:options}]

{pstd}
For multi-group treatments (K > 2, or K = 2 with non-0/1 treatment levels),
treatment levels must be nonnegative integers. Supply one PS variable per level
via {opt psv:ars()}:

{phang}
{cmd:psdash} {it:subcommand} {it:treatment} [{it:{help if}}] [{it:{help in}}]
[{cmd:,} {opt psv:ars(varlist)} {opt ref:erence(#)} {it:options}]

{pstd}
where {it:subcommand} is one of:

{synoptset 14}{...}
{synopt:{opt overlap}}PS density/histogram by treatment group{p_end}
{synopt:{opt balance}}SMD and variance ratio balance table with Love plot{p_end}
{synopt:{opt weights}}Weight distribution, ESS, extreme weights{p_end}
{synopt:{opt support}}Common support assessment and trimming{p_end}
{synopt:{opt combined}}All diagnostics in a combined dashboard{p_end}
{synopt:{opt detect}}Report auto-detection results without running diagnostics{p_end}

{pstd}
After {cmd:teffects}, both {it:treatment} and {it:psvar} can be omitted and are auto-detected from {cmd:e()}.
After cross-sectional {cmd:tmle}, {it:treatment}, {cmd:_tmle_ps}, covariates,
and the estimand are read from the tmle contract state.
After {cmd:ltmle}, use {cmd:psdash combined} for longitudinal period-by-period
diagnostics; pooled subcommands require explicit variables.
After {cmd:msm_weight}, {cmd:psdash combined} reads the treatment propensity
{cmd:_msm_ps}, the treatment weight, and the id/period structure from the msm
contract for the same longitudinal diagnostic.
After {cmd:tte_weight} with {opt save_ps}, {cmd:psdash combined} reads the saved
switch/treatment propensity, IP weight, and trial/period structure from the tte
contract.
After {cmd:iivw_weight} with {opt treat()} and {opt treat_cov()}, treatment,
propensity-score, treatment-covariate, and treatment-weight variables are read
from the iivw dataset contract.
After {cmd:logit}/{cmd:probit}, {it:treatment} is auto-detected but {it:psvar} must be supplied explicitly.
In that setting, {cmd:psdash overlap ps} and {cmd:psdash overlap treatment ps}
are both valid; the one-argument form treats the argument as the propensity
score variable and uses the treatment from {cmd:e(depvar)}.
After {cmd:mlogit} with a multi-valued treatment, supply {opt psv:ars()} with K predicted probabilities
(one per treatment level, ordered by level value).


{marker subcommands}{...}
{title:Subcommand syntax}

{dlgtab:overlap}

{phang}
{cmd:psdash overlap} [{it:treatment}] [{it:psvar}] [{it:{help if}}] [{it:{help in}}]
[{cmd:,} {opt cov:ariates(varlist)} {opt hist:ogram} {opt bins(#)}
{opt bwid:th(#)} {opt nog:raph} {opt sav:ing(filename)} {opt sch:eme(schemename)}
{opt graphopt:ions(string)} {opt ti:tle(string)} {opt name(string)}
{opt xlsx(filename)} {opt sheet(string)}
{opt esti:mand(string)} {opt psv:ars(varlist)} {opt ref:erence(#)}]

{dlgtab:balance}

{phang}
{cmd:psdash balance} [{it:treatment}] [{it:psvar}] [{it:{help if}}] [{it:{help in}}]
[{cmd:,} {opt cov:ariates(varlist)} {opt w:var(varname)} {opt match:ed}
{opt thr:eshold(#)} {opt now:var} {opt now:eights} {opt xlsx(filename)} {opt sheet(string)}
{opt love:plot} {opt strat:egies(strategylist)} {opt dist:ribution(varlist)}
{opt smdm:atrix(name)} {opt sav:ing(filename)} {opt sch:eme(schemename)}
{opt graphopt:ions(string)} {opt f:ormat(string)} {opt ti:tle(string)}
{opt name(string)} {opt ks} {opt esti:mand(string)}
{opt psv:ars(varlist)} {opt ref:erence(#)}]

{dlgtab:weights}

{phang}
{cmd:psdash weights} [{it:treatment}] [{it:psvar}] [{it:{help if}}] [{it:{help in}}]
[{cmd:,} {opt w:var(varname)} {opt trim(#)} {opt trunc:ate(#)} {opt stab:ilize}
{opt gen:erate(name)} {opt replace} {opt det:ail} {opt gr:aph}
{opt sav:ing(filename)} {opt xlabel(numlist)} {opt sch:eme(schemename)}
{opt graphopt:ions(string)} {opt name(string)} {opt xlsx(filename)} {opt sheet(string)}
{opt esti:mand(string)}
{opt psv:ars(varlist)} {opt ref:erence(#)} {opt iivwcomponent(string)}]

{dlgtab:support}

{phang}
{cmd:psdash support} [{it:treatment}] [{it:psvar}] [{it:{help if}}] [{it:{help in}}]
[{cmd:,} {opt cov:ariates(varlist)} {opt crump} {opt thr:eshold(#)}
{opt gen:erate(name)} {opt replace} {opt comp:are} {opt nog:raph} {opt sav:ing(filename)}
{opt sch:eme(schemename)} {opt graphopt:ions(string)} {opt ti:tle(string)}
{opt name(string)} {opt xlsx(filename)} {opt sheet(string)} {opt esti:mand(string)}
{opt psv:ars(varlist)} {opt ref:erence(#)}]

{dlgtab:combined}

{phang}
{cmd:psdash combined} [{it:treatment}] [{it:psvar}] [{it:{help if}}] [{it:{help in}}]
[{cmd:,} {opt cov:ariates(varlist)} {opt w:var(varname)} {opt thr:eshold(#)}
{opt overlap:max(#)} {opt ess:min(#)} {opt imbal:max(#)}
{opt noo:verlap} {opt nob:alance} {opt now:eights} {opt nos:upport} {opt dry:run}
{opt rep:ort(filename)} {opt sav:ing(filename)} {opt sch:eme(schemename)} {opt ti:tle(string)}
{opt esti:mand(string)} {opt psv:ars(varlist)} {opt ref:erence(#)}]

{dlgtab:detect}

{phang}
{cmd:psdash detect} [{it:treatment}] [{it:psvar}] [{it:{help if}}] [{it:{help in}}]
[{cmd:,} {opt cov:ariates(varlist)} {opt w:var(varname)} {opt esti:mand(string)}
{opt psv:ars(varlist)} {opt ref:erence(#)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:psdash} provides a unified interface for propensity score diagnostics.
After estimating propensity scores (via {cmd:teffects}, {cmd:logit} + {cmd:predict},
cross-sectional {cmd:tmle}, or manually), users need to assess overlap, balance,
common support, and weight distribution. {cmd:psdash} consolidates these
diagnostics under a single command with consistent syntax.

{pstd}
{cmd:psdash} auto-detects the treatment variable, propensity score, covariates,
and weights from the most recent estimation context when possible. Users can
always override by providing explicit arguments.

{pstd}
For most analyses, start with {cmd:psdash combined}. It runs overlap, balance,
weight, and support diagnostics together. Then rerun the individual panel named
in any warning message when you need a graph, export, or modified weights.
After {cmd:ltmle}, {cmd:msm_weight}, or {cmd:tte_weight} (with {opt save_ps}),
{cmd:psdash combined} switches to longitudinal diagnostics: per-period PS overlap
plus contract-weight summaries.

{pstd}
The four diagnostics answer different practical questions: {cmd:overlap} asks
whether comparable treated and control observations exist; {cmd:balance} asks
whether observed covariates look similar after adjustment; {cmd:weights} asks
whether a small number of observations dominate the analysis; and {cmd:support}
asks which observations should be excluded before outcome estimation.


{marker options}{...}
{title:Options}

{dlgtab:Common options}

{phang}
{opt covariates(varlist)} specifies the covariates to assess. Auto-detected
from the estimation command if omitted.

{phang}
{opt wvar(varname)} specifies a pre-existing weight variable for subcommands
that use weights. If omitted and a propensity score is available, weights are
auto-generated based on the {opt estimand()} option.

{phang}
{opt estimand(string)} specifies the target estimand for auto-generated weights.
{opt ate} (default) generates standard IPTW weights: {cmd:1/ps} for treated and
{cmd:1/(1-ps)} for control. {opt att} generates ATT weights: {cmd:1} for treated
and {cmd:ps/(1-ps)} for control. {opt atc} generates ATC weights:
{cmd:(1-ps)/ps} for treated and {cmd:1} for control. After {cmd:teffects}, the estimand is auto-detected from {cmd:e(stat)}
when not specified by the user; if {opt estimand()} is given explicitly, it is
always respected regardless of {cmd:e(stat)}.

{pstd}
Auto-generated propensity scores and weights are temporary working variables.
They are not left behind in the user's dataset. Stored-result macros report
{cmd:auto-generated} when no persistent user variable exists.

{dlgtab:Multi-group options}

{phang}
{opt psvars(varlist)} specifies the generalized propensity score (GPS) variables
for multi-group treatments (K > 2, or K = 2 with non-0/1 treatment levels).
Provide one variable per treatment level, ordered by level value (ascending).
Each variable should contain P(A=a|X), the predicted probability of that
treatment level. Required for manual multi-group mode except the special
K = 2 non-0/1 case, where a single positional {it:psvar} is also accepted.
Auto-generated after {cmd:teffects} with a multi-valued treatment. For binary
0/1 treatment, the standard single {it:psvar} positional argument is sufficient.

{pstd}
Multi-group treatment values must be nonnegative integers because per-group
stored results use the observed level values in result names, such as
{cmd:r(N_group_2)}. Recode decimal or negative treatment values before running
multi-group diagnostics.

{phang}
{opt reference(#)} specifies the reference treatment level for pairwise
comparisons (balance, weights). Default is the smallest treatment level.
Must be one of the observed treatment values. For {cmd:balance}, SMD is
computed for each non-reference group vs the reference.

{dlgtab:Graph options}

{pstd}
Subcommands differ in whether a graph is drawn by default. {cmd:overlap} and
{cmd:support} draw a graph automatically; suppress it with {opt nograph}.
{cmd:balance} and {cmd:weights} draw none by default; request one with
{opt loveplot} and {opt graph} respectively. {cmd:combined} always assembles the
dashboard. The options below apply wherever a graph is produced.

{phang}
{opt scheme(schemename)} specifies the graph scheme.

{phang}
{opt saving(filename)} exports the graph to an image file. The format is
determined by the filename extension ({cmd:.png}, {cmd:.pdf}, {cmd:.eps}, etc.);
use Stata's {helpb graph save} for a {cmd:.gph} file.

{phang}
{opt title(string)} specifies a custom title for the output header and/or graph.

{phang}
{opt graphoptions(string)} specifies additional {help twoway_options:twoway options}
passed through to the graph command.

{phang}
{opt name(string)} specifies the graph name in memory.

{dlgtab:overlap options}

{phang}
{opt histogram} uses overlapping histograms instead of kernel density plots.

{phang}
{opt bins(#)} sets the number of histogram bins and must be positive. Default is 30.

{phang}
{opt bwidth(#)} sets the bandwidth for kernel density estimation.
If not specified, Stata's default bandwidth is used.

{phang}
{opt nograph} suppresses the graph and shows only the summary table.

{phang}
{opt xlsx(filename)} exports the overlap summary statistics to an Excel file
(a two-column Metric/Value sheet).

{phang}
{opt sheet(string)} specifies the Excel sheet name. Default is {cmd:"Overlap"}.

{dlgtab:balance options}

{phang}
{opt matched} indicates the data has been matched rather than weighted.
Mutually exclusive with {opt wvar()}.

{phang}
{opt threshold(#)} sets the SMD threshold for imbalance. Default is 0.1.

{phang}
{opt nowvar} suppresses automatic weight generation from the propensity score.
{opt noweights} is an alias for {opt nowvar}.

{phang}
{opt loveplot} generates a Love plot showing SMDs for each covariate.

{phang}
{opt strategies(strategylist)} overlays the SMD for several weighting strategies
in one Love plot, replacing the default raw/adjusted plot. {it:strategylist} is a
space-separated subset of {cmd:raw} (unadjusted), {cmd:ate}, {cmd:att}, and
{cmd:atc} (each IPTW-weighted under that estimand). Requires a propensity score
and binary treatment. This mirrors R {cmd:cobalt}'s multi-strategy {cmd:love.plot}.

{phang}
{opt distribution(varlist)} draws per-covariate distributional balance plots
(kernel densities by treatment group, with weighted overlays when weights are
present), one panel per covariate combined into a single graph. The covariates
must be among those assessed. Binary treatment only. This mirrors R
{cmd:cobalt}'s {cmd:bal.plot} and surfaces distributional differences that SMD
alone can miss.

{phang}
{opt smdmatrix(name)} saves a covariate-by-SMD matrix to the named matrix in the
caller, with one column for the unadjusted SMD and (when weighted) one for the
adjusted SMD; for multi-group treatment, one column per contrast. The same matrix
is returned in {cmd:r(smd)}. The matrix is keyed by covariate name so it can be
passed to {helpb puttab} or appended as a balance column in a {help table1_tc}
manuscript table.

{phang}
{opt ks} displays Kolmogorov-Smirnov statistics in the balance table. KS
statistics are always computed and stored in the {cmd:r(balance)} matrix
regardless of this option; {opt ks} controls display only.

{phang}
{opt xlsx(filename)} exports the balance table to an Excel file.

{phang}
{opt sheet(string)} specifies the Excel sheet name. Default is {cmd:"Balance"}.

{phang}
{opt format(string)} sets the numeric display format for SMD values. Default is {cmd:%6.3f}.

{pstd}
{bf:Interpretation:} An SMD below 0.1 in absolute value indicates adequate
balance (Austin 2009). Variance ratios between 0.5 and 2.0 are acceptable;
values outside this range indicate scale imbalances that SMD alone can miss.
KS statistics above 0.1 suggest meaningful distributional differences beyond
what means capture.

{dlgtab:weights options}

{phang}
{opt trim(#)} trims weights at the specified percentile (50-99.9).

{phang}
{opt truncate(#)} truncates weights at a fixed maximum value.

{phang}
{opt stabilize} creates stabilized weights by multiplying by the marginal
probability of treatment.

{phang}
{opt generate(name)} specifies the variable name for modified weights.
Required with {opt trim()}, {opt truncate()}, or {opt stabilize}.

{phang}
{opt replace} allows overwriting an existing variable.

{phang}
{opt detail} displays the full percentile distribution.

{phang}
{opt iivwcomponent(string)} selects which iivw weight variable to summarize
after {cmd:iivw_weight}.  Allowed values are {cmd:treatment} (the default
IPTW component, e.g. {cmd:_iivw_tw}), {cmd:final} (the final analysis weight,
e.g. {cmd:_iivw_weight}), and {cmd:visit} (the visit-intensity component,
e.g. {cmd:_iivw_iw}).  The visit component is descriptive only; overlap and
support diagnostics remain treatment-propensity diagnostics.

{phang}
{opt graph} displays a weight distribution histogram.

{phang}
{opt xlabel(numlist)} specifies custom x-axis labels for the weight histogram.
It is ignored unless {opt graph} is also specified.

{phang}
{opt xlsx(filename)} exports the weight summary statistics to an Excel file
(a two-column Metric/Value sheet).

{phang}
{opt sheet(string)} specifies the Excel sheet name. Default is {cmd:"Weights"}.

{pstd}
{bf:Interpretation:} An ESS above 50% of the original sample size is typical.
A coefficient of variation (CV) greater than 1 indicates substantial weight
variability that may inflate variance of treatment effect estimates.
Weights exceeding 10 are considered extreme; those exceeding 20 indicate
severe positivity violations. Consider trimming or truncating extreme weights.

{dlgtab:support options}

{phang}
{opt crump} applies Crump et al. (2009) optimal trimming to determine the
support region that minimizes variance. Uses a grid search to find the
optimal alpha threshold. Restricted to binary treatment; for multi-group
treatments, use {opt threshold()} instead.

{phang}
{opt threshold(#)} specifies a manual PS trimming threshold. Observations
with PS < threshold or PS > 1-threshold are considered outside support.
Must be strictly between 0 and 0.5.

{phang}
{opt generate(name)} creates an indicator variable equal to 1 for
observations within the support region. With {opt crump} or {opt threshold()},
the indicator marks the trimmed region; otherwise it marks the empirical common
support interval.

{phang}
{opt replace} allows overwriting an existing variable specified in
{opt generate()}.

{phang}
{opt compare} reports a pre/post-trimming comparison of key diagnostics:
observations retained, percentage outside common support, effective sample size
(ESS) as a percentage of N, and maximum |SMD| (when covariates are available).
Requires trimming ({opt crump} or {opt threshold()}); binary treatment only.
This closes the "did trimming help?" loop. The pre/post values are returned in
{cmd:r(*_pre)} and {cmd:r(*_post)}.

{phang}
{opt nograph} suppresses the PS density graph.

{phang}
{opt xlsx(filename)} exports the support summary statistics to an Excel file
(a two-column Metric/Value sheet).

{phang}
{opt sheet(string)} specifies the Excel sheet name. Default is {cmd:"Support"}.

{pstd}
{bf:Interpretation:} Observations outside common support lack counterparts
in the other treatment group, violating the positivity assumption. More than
10% outside support warrants attention. Crump et al. (2009) optimal trimming
identifies the subsample where treatment effect estimation is most efficient;
the optimal alpha is typically between 0.05 and 0.15.

{dlgtab:combined options}

{phang}
{opt nooverlap}, {opt nobalance}, {opt noweights}, {opt nosupport} suppress
the corresponding panel from the combined dashboard.

{phang}
{opt threshold(#)} sets the SMD imbalance threshold for the balance panel in
the combined dashboard. It is not passed to the support panel.

{phang}
{opt overlapmax(#)} sets the threshold (percent outside common support) above
which the overlap and support panels are flagged in the overall verdict. Default
is 10.

{phang}
{opt essmin(#)} sets the minimum effective sample size (percent of N) below which
the weight panel is flagged. Default is 50.

{phang}
{opt imbalmax(#)} sets the maximum number of imbalanced covariates tolerated
before the balance panel is flagged. Default is 0.

{phang}
{opt dryrun} reports the auto-detection result (treatment, PS, covariates,
weights, estimand, source, longitudinal flag) and exits without running any
panel. Equivalent to {cmd:psdash detect}.

{phang}
{opt report(filename)} writes a multi-sheet Excel workbook ({cmd:.xlsx}) bundling
each panel's table (Overlap, Balance, Weights, Support) plus a Summary sheet with
the overall verdict and thresholds. The path is returned in {cmd:r(report)}.

{phang}
{opt saving(filename)} exports the combined graph (not individual panels) to an
image file; the format is set by the filename extension ({cmd:.png}, {cmd:.pdf},
etc.). Use {helpb graph save} for a {cmd:.gph} file.

{dlgtab:detect options}

{phang}
{cmd:psdash detect} accepts the common detection options
({opt covariates()}, {opt wvar()}, {opt estimand()}, {opt psvars()},
{opt reference()}) and runs only the auto-detection layer, printing what it
resolved and returning it in {cmd:r()}. It runs no diagnostics and creates no
graphs, so it is a safe way to inspect the 9-mode detector before committing to a
full run. See {help psdash##detection:Detection sources} below.


{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:psdash} is designed to work in nine modes:

{phang2}
1. {bf:After teffects}: treatment, covariates, PS, and weights are fully
auto-detected. Just run {cmd:psdash combined}.

{phang2}
2. {bf:After tmle}: treatment, {cmd:_tmle_ps}, covariates, and estimand are
auto-detected from the tmle contract state. Run {cmd:psdash combined} or an
individual subcommand.

{phang2}
3. {bf:After ltmle}: run {cmd:psdash combined}. It reports period-by-period PS
overlap and contract-weight summaries instead of silently pooling person-period
rows as if they were cross-sectional observations.

{phang2}
4. {bf:After msm_weight}: treatment, the per-period treatment propensity
{cmd:_msm_ps}, the treatment weight {cmd:_msm_tw_weight}, and the id/period
structure are auto-detected from msm dataset metadata. Run {cmd:psdash combined}
for the longitudinal diagnostic; it complements {cmd:msm_diagnose} by adding the
per-period overlap panel.

{phang2}
5. {bf:After tte_weight ..., save_ps}: the trial arm, the saved switch/treatment
propensity, the IP weight, and the trial/period structure are auto-detected from
tte dataset metadata. Run {cmd:psdash combined}. The {opt save_ps} option is
required so the propensity score survives in the dataset.

{phang2}
6. {bf:After iivw_weight}: treatment, {cmd:_iivw_ps}, treatment-model
covariates, and {cmd:_iivw_tw} are auto-detected from iivw dataset metadata.
Run {cmd:psdash combined}. Use {cmd:psdash weights, iivwcomponent(final)}
when you want the final FIPTIW/IPTW analysis-weight distribution.

{phang2}
7. {bf:After logit/probit}: treatment and covariates are auto-detected from
{cmd:e()}. The user must provide the PS variable (from {cmd:predict}).

{phang2}
8. {bf:After mlogit (multi-group)}: for multi-valued treatments, treatment
and covariates are auto-detected from {cmd:e()}. The user runs
{cmd:predict ps1 ps2 ps3, pr} and passes the GPS variables via
{opt psvars(ps1 ps2 ps3)}.

{phang2}
9. {bf:Manual}: the user provides treatment and PS variables explicitly,
along with covariates and/or weights via options.

{marker detection}{...}
{pstd}
{bf:Detection sources.} The table below summarizes, for each detection source,
what {cmd:psdash} reads and how it routes. Run {cmd:psdash detect} (or
{cmd:psdash combined, dryrun}) to see which source fired for your data.

{synoptset 12 tabbed}{...}
{p2col 5 18 22 2: Source}{space 2}Reads{space 16}Routes to{p_end}
{synopt:{cmd:teffects}}treatment, PS, covariates, weight, estimand from {cmd:e()}{space 2}cross-sectional panels{p_end}
{synopt:{cmd:tmle}}treatment, {cmd:_tmle_ps}, covariates, estimand (contract){space 2}cross-sectional panels{p_end}
{synopt:{cmd:ltmle}}id/period, per-period PS and weights (contract){space 2}longitudinal diagnostics{p_end}
{synopt:{cmd:msm}}{cmd:_msm_ps}, {cmd:_msm_tw_weight}, id/period (metadata){space 2}longitudinal diagnostics{p_end}
{synopt:{cmd:tte}}saved switch/treatment PS, IP weight, trial/period (metadata){space 2}longitudinal diagnostics{p_end}
{synopt:{cmd:iivw}}{cmd:_iivw_ps}, treatment covariates, {cmd:_iivw_tw} (metadata){space 2}cross-sectional panels{p_end}
{synopt:{cmd:logit}/{cmd:probit}}treatment and covariates from {cmd:e()}; PS user-supplied{space 2}binary panels{p_end}
{synopt:{cmd:mlogit}}treatment and covariates from {cmd:e()}; GPS via {opt psvars()}{space 2}multi-group panels{p_end}
{synopt:{cmd:manual}}treatment and PS supplied as arguments; options for the rest{space 2}binary or multi-group panels{p_end}
{p2colreset}{...}

{pstd}
{bf:Default behavior of {cmd:balance}:} When a PS variable is available,
{cmd:psdash balance} auto-generates IPTW weights for the requested {opt estimand()}
and displays {it:adjusted} columns (SMD Adj, VR Adj) alongside the raw columns.
Pass {opt nowvar} to show raw balance only, or {opt wvar()} to supply a
pre-computed weight variable. The {opt estimand()} option (default {opt ate}) controls
which IPTW formula is used; after {cmd:teffects} it is auto-detected from
{cmd:e(stat)} when not specified explicitly.

{pstd}
Internally generated propensity scores and IPTW weights are temporary and are
removed automatically at command exit. Use {opt wvar()} for pre-computed weights
or {cmd:psdash weights, generate()} with a modification option when you want to
save a new weight variable.

{pstd}
{bf:Multi-group ATC note:} For multi-group treatments, the ATC estimand uses
the same generalized IPTW formula as ATE ({cmd:w = 1 / P(A=a|X)}). This is
standard practice; ATT and ATC are less commonly applied to multi-valued
treatments, and the ATE weights are the natural generalization.

{pstd}
{bf:Diagnostic workflow:} A typical PS analysis proceeds as follows:
(1) estimate propensity scores; (2) check PS overlap and AUC;
(3) trim if necessary using {cmd:psdash support, crump} for binary treatments
or {cmd:threshold()} for multi-group treatments; (4) check covariate
balance using SMD, variance ratios, and optionally KS statistics; (5) assess
weight distribution, ESS, and extreme weights; (6) proceed to outcome analysis
only when diagnostics are satisfactory. {cmd:psdash combined} runs steps 2-5
in a single command.

{pstd}
{bf:Reading the status lines:} {cmd:PASS} or {cmd:Adequate} means no diagnostic
crossed the package's default warning threshold. A warning does not make the
analysis invalid by itself; it identifies the next check to make. Poor overlap
usually calls for tighter eligibility criteria or trimming. Large SMDs point to
model revision or additional covariates. Low ESS or extreme weights point to
stabilization, trimming, truncation, or a different estimand.


{marker examples}{...}
{title:Examples}

{pstd}
All examples below use Stata's built-in {cmd:sysuse} or {cmd:webuse}
datasets, so they can be copied exactly as shown after installing
{cmd:psdash}. The {cmd:sysuse auto} examples use {cmd:foreign} as a
convenient binary treatment indicator. The {cmd:webuse cattaneo2} examples
show a more realistic treatment-effects workflow. They are intended to
illustrate syntax and diagnostics, not to endorse a final causal specification.

{pstd}
{bf:1. Manual propensity-score workflow with sysuse auto.}
Estimate the propensity score with {cmd:logit}, save the fitted probabilities
in {cmd:ps}, then run each diagnostic explicitly. Because this is a manual
workflow, {cmd:balance} is told which covariates to assess.

{pstd}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash overlap foreign ps}{p_end}
{phang2}{cmd:. psdash balance foreign ps, covariates(mpg weight length) loveplot}{p_end}
{phang2}{cmd:. psdash weights foreign ps}{p_end}
{phang2}{cmd:. psdash support foreign ps, crump generate(in_support)}{p_end}

{pstd}
{bf:2. Fully automatic workflow after teffects with webuse cattaneo2.}
Here {cmd:teffects ipw} estimates the propensity score internally. After that,
{cmd:psdash} reads the treatment ({cmd:mbsmoke}), the estimated PS, the
covariates, and the implied weighting scheme from {cmd:e()}, so the subcommands
can be called without retyping variable names.

{phang2}{cmd:. webuse cattaneo2, clear}{p_end}
{phang2}{cmd:. teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby)}{p_end}
{phang2}{cmd:. psdash combined}{p_end}
{phang2}{cmd:. psdash balance}{p_end}

{pstd}
{bf:3. Using pre-computed weights with sysuse auto.}
If weights were created outside {cmd:psdash}, pass them through {opt wvar()}
so that the weight and balance diagnostics use the same variable.

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. gen double ipw = cond(foreign == 1, 1/ps, 1/(1-ps))}{p_end}
{phang2}{cmd:. psdash weights foreign ps, wvar(ipw) detail graph}{p_end}
{phang2}{cmd:. psdash balance foreign ps, covariates(mpg weight length) wvar(ipw)}{p_end}

{pstd}
{bf:4. Using psdash after iivw_weight.}
After {cmd:iivw_weight} with a treatment model, {cmd:psdash combined}
auto-detects the iivw treatment propensity-score contract. The final weight
can be summarized explicitly with {opt iivwcomponent(final)}.

{phang2}{cmd:. iivw_weight, id(id) time(months) visit_cov(age sex bl_edss bl_sdmt) treat(treated) treat_cov(age sex bl_edss bl_sdmt) replace nolog}{p_end}
{phang2}{cmd:. psdash combined}{p_end}
{phang2}{cmd:. psdash weights, iivwcomponent(final) detail graph}{p_end}

{pstd}
{bf:5. ATT workflow after teffects, atet.}
When {cmd:teffects} is fit with {cmd:, atet}, {cmd:psdash} maps Stata's
ATET result to {cmd:estimand(att)} internally. That lets the balance and
weight diagnostics use ATT weights automatically.

{phang2}{cmd:. webuse cattaneo2, clear}{p_end}
{phang2}{cmd:. teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), atet}{p_end}
{phang2}{cmd:. psdash balance}{p_end}
{phang2}{cmd:. psdash weights, detail}{p_end}

{pstd}
{bf:6. Focused option examples on sysuse auto.}
These examples show a few common follow-up diagnostics once {cmd:ps} already
exists: add KS statistics to the balance table, create trimmed or stabilized
weights, and mark observations inside common support.

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight length}{p_end}
{phang2}{cmd:. predict double ps, pr}{p_end}
{phang2}{cmd:. psdash balance foreign ps, covariates(mpg weight length) ks}{p_end}
{phang2}{cmd:. psdash weights foreign ps, trim(99) generate(ipw_trimmed)}{p_end}
{phang2}{cmd:. psdash weights foreign ps, stabilize generate(ipw_stab)}{p_end}
{phang2}{cmd:. psdash support foreign ps, crump generate(in_support)}{p_end}

{pstd}
{bf:7. Multi-group treatment (3 arms) with mlogit.}
When the treatment has more than two levels, estimate the generalized propensity
score with {cmd:mlogit} and pass the K predicted probabilities via
{opt psvars()}. The generated example below creates a stable three-arm treatment
so the multinomial model converges in a small demonstration dataset.

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set obs 300}{p_end}
{phang2}{cmd:. set seed 20260506}{p_end}
{phang2}{cmd:. gen double age = rnormal(60, 10)}{p_end}
{phang2}{cmd:. gen byte female = runiform() > .5}{p_end}
{phang2}{cmd:. gen double bmi = rnormal(27, 4)}{p_end}
{phang2}{cmd:. gen double eta1 = -0.2 + 0.03*(age-60) + 0.25*female - 0.04*(bmi-27)}{p_end}
{phang2}{cmd:. gen double eta2 = 0.1 - 0.02*(age-60) + 0.02*(bmi-27)}{p_end}
{phang2}{cmd:. gen double den = 1 + exp(eta1) + exp(eta2)}{p_end}
{phang2}{cmd:. gen double p0 = 1/den}{p_end}
{phang2}{cmd:. gen double p1 = exp(eta1)/den}{p_end}
{phang2}{cmd:. gen double u = runiform()}{p_end}
{phang2}{cmd:. gen byte arm = cond(u < p0, 0, cond(u < p0 + p1, 1, 2))}{p_end}
{phang2}{cmd:. mlogit arm age female bmi}{p_end}
{phang2}{cmd:. predict double ps0 ps1 ps2, pr}{p_end}
{phang2}{cmd:. psdash overlap arm , psvars(ps0 ps1 ps2)}{p_end}
{phang2}{cmd:. psdash balance arm , psvars(ps0 ps1 ps2) covariates(age female bmi)}{p_end}
{phang2}{cmd:. psdash weights arm , psvars(ps0 ps1 ps2) detail}{p_end}
{phang2}{cmd:. psdash support arm , psvars(ps0 ps1 ps2) threshold(0.1)}{p_end}

{pstd}
{bf:8. Multi-group with explicit reference group.}
Specify {opt reference()} to change the comparator group for pairwise
SMD calculations.

{phang2}{cmd:. psdash balance arm , psvars(ps0 ps1 ps2) covariates(age female bmi) reference(1)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
Each subcommand stores results in {cmd:r()}.

{pstd}
{bf:Multi-group note:} For binary (0/1) treatment, stored results use
binary group names such as {cmd:r(N_treated)} and {cmd:r(N_control)}.
For multi-group treatment runs, per-group results use the naming convention
{cmd:r(N_group_{it:<level>})},
{cmd:r(ess_group_{it:<level>})}, etc. Additionally, {cmd:r(K)} returns the number
of groups, {cmd:r(levels)} lists the treatment values, and {cmd:r(reference)}
identifies the reference group.

{dlgtab:overlap}

{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total observations{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(mean_ps_treated)}}mean PS in treated group{p_end}
{synopt:{cmd:r(mean_ps_control)}}mean PS in control group{p_end}
{synopt:{cmd:r(min_ps_treated)}}min PS in treated group{p_end}
{synopt:{cmd:r(max_ps_treated)}}max PS in treated group{p_end}
{synopt:{cmd:r(min_ps_control)}}min PS in control group{p_end}
{synopt:{cmd:r(max_ps_control)}}max PS in control group{p_end}
{synopt:{cmd:r(overlap_lower)}}lower bound of overlap region{p_end}
{synopt:{cmd:r(overlap_upper)}}upper bound of overlap region{p_end}
{synopt:{cmd:r(n_outside)}}observations outside overlap{p_end}
{synopt:{cmd:r(pct_outside)}}percentage outside overlap{p_end}
{synopt:{cmd:r(auc)}}C-statistic (AUC) for PS model (omitted if {cmd:roctab} fails){p_end}
{synopt:{cmd:r(n_ps_boundary)}}observations with PS exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}observations with PS < 0.01 or > 0.99{p_end}

{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(psvar)}}PS variable name, or {cmd:auto-generated} for a temporary PS from {cmd:teffects}{p_end}
{synopt:{cmd:r(estimand)}}target estimand ({cmd:ate}, {cmd:att}, or {cmd:atc}){p_end}
{synopt:{cmd:r(source)}}detection source{p_end}

{dlgtab:balance}

{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total observations{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(max_smd_raw)}}maximum |SMD| before adjustment{p_end}
{synopt:{cmd:r(max_smd_adj)}}maximum |SMD| after adjustment (set when {opt wvar} is provided or auto-generated; unset with {opt nowvar} or matched weighting){p_end}
{synopt:{cmd:r(max_vr_raw)}}variance ratio with largest deviation from 1{p_end}
{synopt:{cmd:r(max_vr_adj)}}adjusted variance ratio with largest deviation from 1{p_end}
{synopt:{cmd:r(max_ks_raw)}}maximum KS statistic (raw){p_end}
{synopt:{cmd:r(n_imbalanced)}}covariates exceeding SMD threshold{p_end}
{synopt:{cmd:r(n_vr_imbalanced)}}covariates with VR outside [0.5, 2.0]{p_end}
{synopt:{cmd:r(threshold)}}threshold used{p_end}
{synopt:{cmd:r(n_ps_boundary)}}observations with PS exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}observations with PS < 0.01 or > 0.99{p_end}

{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(varlist)}}covariates assessed{p_end}
{synopt:{cmd:r(wvar)}}weight variable, or {cmd:auto-generated} for temporary weights{p_end}
{synopt:{cmd:r(source)}}detection source{p_end}

{p2col 5 30 34 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}balance-statistics matrix; rows are covariates{p_end}
{synopt:{cmd:r(smd)}}covariate-by-SMD matrix (unadjusted and, when weighted, adjusted; per-contrast for multi-group); also saved to {opt smdmatrix()}{p_end}

{pstd}
For binary treatments, the balance matrix columns are: {cmd:Mean_T}, {cmd:Mean_C}, {cmd:SMD_Raw},
{cmd:VR_Raw}, {cmd:KS_Raw}, {cmd:Mean_T_Adj}, {cmd:Mean_C_Adj}, {cmd:SMD_Adj},
{cmd:VR_Adj}, {cmd:KS_Adj}. Adjusted columns contain missing values if no
weights are applied. {cmd:KS_Adj} is reserved for future use.

{pstd}
For multi-group treatments, {cmd:r(balance)} contains one five-column block for
each non-reference group: mean in the comparison group, mean in the reference
group, SMD, variance ratio, and KS statistic. When weights are applied, a second
five-column adjusted block is added for each non-reference group. Column names
include the compared treatment levels.

{dlgtab:weights}

{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total observations{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(mean_wt)}}mean weight{p_end}
{synopt:{cmd:r(sd_wt)}}SD of weights{p_end}
{synopt:{cmd:r(min_wt)}}minimum weight{p_end}
{synopt:{cmd:r(max_wt)}}maximum weight{p_end}
{synopt:{cmd:r(cv)}}coefficient of variation{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(ess_pct)}}ESS as % of N{p_end}
{synopt:{cmd:r(ess_treated)}}ESS for treated group{p_end}
{synopt:{cmd:r(ess_control)}}ESS for control group{p_end}
{synopt:{cmd:r(ess_pct_treated)}}ESS % for treated group{p_end}
{synopt:{cmd:r(ess_pct_control)}}ESS % for control group{p_end}
{synopt:{cmd:r(n_extreme)}}weights > 10{p_end}
{synopt:{cmd:r(pct_extreme)}}percentage of extreme weights{p_end}
{synopt:{cmd:r(p1)}}1st percentile{p_end}
{synopt:{cmd:r(p5)}}5th percentile{p_end}
{synopt:{cmd:r(p95)}}95th percentile{p_end}
{synopt:{cmd:r(p99)}}99th percentile{p_end}
{synopt:{cmd:r(n_ps_boundary)}}observations with PS exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}observations with PS < 0.01 or > 0.99{p_end}

{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:r(wvar)}}weight variable name, or {cmd:auto-generated} for temporary weights{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}detection source{p_end}
{synopt:{cmd:r(iivwcomponent)}}selected iivw component, when applicable{p_end}
{synopt:{cmd:r(generate)}}generated variable name (if modification){p_end}

{pstd}
If {opt trim()}, {opt truncate()}, or {opt stabilize} is specified, also returns
{cmd:r(new_mean)}, {cmd:r(new_sd)}, {cmd:r(new_min)}, {cmd:r(new_max)},
{cmd:r(new_cv)}, {cmd:r(new_ess)}, {cmd:r(new_ess_pct)}.

{dlgtab:support}

{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total observations{p_end}
{synopt:{cmd:r(N_treated)}}treated observations{p_end}
{synopt:{cmd:r(N_control)}}control observations{p_end}
{synopt:{cmd:r(lower_bound)}}lower bound of common support{p_end}
{synopt:{cmd:r(upper_bound)}}upper bound of common support{p_end}
{synopt:{cmd:r(n_outside)}}observations outside support{p_end}
{synopt:{cmd:r(pct_outside)}}percentage outside support{p_end}
{synopt:{cmd:r(n_outside_treated)}}treated outside support{p_end}
{synopt:{cmd:r(n_outside_control)}}control outside support{p_end}
{synopt:{cmd:r(trim_lower)}}trimming lower bound (if trimming){p_end}
{synopt:{cmd:r(trim_upper)}}trimming upper bound (if trimming){p_end}
{synopt:{cmd:r(n_trimmed)}}observations trimmed (if trimming){p_end}
{synopt:{cmd:r(pct_trimmed)}}percentage trimmed (if trimming){p_end}
{synopt:{cmd:r(crump_alpha)}}Crump optimal alpha (if {opt crump}){p_end}
{synopt:{cmd:r(n_ps_boundary)}}observations with PS exactly 0 or 1{p_end}
{synopt:{cmd:r(n_ps_near_boundary)}}observations with PS < 0.01 or > 0.99{p_end}

{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(psvar)}}PS variable name, or {cmd:auto-generated} for a temporary PS from {cmd:teffects}{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}detection source{p_end}

{pstd}
With {opt compare} (and active trimming) the support command also returns
{cmd:r(n_post)} (observations retained after trimming),
{cmd:r(pct_outside_pre)}/{cmd:r(pct_outside_post)},
{cmd:r(ess_pct_pre)}/{cmd:r(ess_pct_post)}, and
{cmd:r(max_smd_pre)}/{cmd:r(max_smd_post)} (the last pair only when covariates
are available).

{dlgtab:combined}

{pstd}
{cmd:psdash combined} inherits all stored results from its subcommands
(via {cmd:return add}). In addition:

{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(psvar)}}PS variable name, or {cmd:auto-generated} for a temporary PS from {cmd:teffects}{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(source)}}detection source ({cmd:"manual"}, {cmd:"teffects"}, {cmd:"estimation"}, {cmd:"tmle"}, {cmd:"ltmle"}, {cmd:"iivw"}, {cmd:"msm"}, or {cmd:"tte"}){p_end}
{synopt:{cmd:r(wvar)}}weight variable name for combined diagnostics or longitudinal (ltmle/msm/tte) diagnostics{p_end}
{synopt:{cmd:r(iivwcomponent)}}selected iivw component, when applicable{p_end}
{synopt:{cmd:r(period)}}period variable for longitudinal (ltmle/msm/tte) diagnostics{p_end}
{synopt:{cmd:r(periods)}}period values included in longitudinal (ltmle/msm/tte) diagnostics{p_end}
{synopt:{cmd:r(id)}}ID variable for longitudinal (ltmle/msm/tte) diagnostics, when available{p_end}
{synopt:{cmd:r(regime)}}LTMLE regime metadata, when available{p_end}
{synopt:{cmd:r(method)}}LTMLE method metadata, when available{p_end}
{synopt:{cmd:r(contract_version)}}LTMLE contract version metadata, when available{p_end}
{synopt:{cmd:r(levels)}}multi-group treatment levels, if applicable{p_end}
{synopt:{cmd:r(reference)}}multi-group reference level, if applicable{p_end}
{synopt:{cmd:r(verdict)}}overall verdict, {cmd:"PASS"} or {cmd:"CAUTION"}{p_end}
{synopt:{cmd:r(warnings)}}space-separated list of flagged panels{p_end}
{synopt:{cmd:r(report)}}report workbook path, when {opt report()} is used{p_end}

{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:r(n_warnings)}}number of flagged panels{p_end}
{synopt:{cmd:r(overlapmax)}, {cmd:r(essmin)}, {cmd:r(imbalmax)}}verdict thresholds used{p_end}
{synopt:{cmd:r(K)}}number of treatment groups, if applicable{p_end}
{synopt:{cmd:r(N)}}observations in the LTMLE diagnostic sample{p_end}
{synopt:{cmd:r(longitudinal)}}1 for longitudinal (ltmle/msm/tte) diagnostics{p_end}
{synopt:{cmd:r(N_periods)}}number of periods for longitudinal (ltmle/msm/tte) diagnostics{p_end}
{synopt:{cmd:r(max_pct_outside)}}maximum period-specific percentage outside overlap, LTMLE only{p_end}
{synopt:{cmd:r(mean_wt)}, {cmd:r(sd_wt)}}mean and SD of LTMLE contract weights{p_end}
{synopt:{cmd:r(min_wt)}, {cmd:r(max_wt)}}minimum and maximum LTMLE contract weights{p_end}
{synopt:{cmd:r(cv)}}coefficient of variation of LTMLE contract weights{p_end}
{synopt:{cmd:r(ess)}, {cmd:r(ess_pct)}}effective sample size and ESS percentage for LTMLE contract weights{p_end}
{synopt:{cmd:r(p1)}, {cmd:r(p5)}, {cmd:r(p50)}, {cmd:r(p95)}, {cmd:r(p99)}}selected LTMLE contract-weight percentiles{p_end}
{synopt:{cmd:r(n_extreme)}, {cmd:r(pct_extreme)}}count and percentage of LTMLE contract weights above 10{p_end}

{p2col 5 30 34 2: Matrices}{p_end}
{synopt:{cmd:r(overlap_by_period)}}period-specific PS overlap table, LTMLE only{p_end}
{synopt:{cmd:r(weights_by_period)}}period-specific contract-weight table, LTMLE only{p_end}

{dlgtab:detect}

{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:r(source)}}detection source{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(psvar)}}PS variable, or {cmd:auto-generated}{p_end}
{synopt:{cmd:r(covariates)}}detected/supplied covariate list{p_end}
{synopt:{cmd:r(wvar)}}weight variable, if any{p_end}
{synopt:{cmd:r(estimand)}}target estimand{p_end}
{synopt:{cmd:r(levels)}, {cmd:r(reference)}}treatment levels and reference (multi-group){p_end}
{synopt:{cmd:r(id)}, {cmd:r(period)}, {cmd:r(regime)}, {cmd:r(method)}, {cmd:r(contract_version)}}longitudinal metadata, when applicable{p_end}

{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:r(n_covariates)}}number of covariates{p_end}
{synopt:{cmd:r(psvar_auto)}}1 if the PS is auto-generated{p_end}
{synopt:{cmd:r(multigroup)}}1 for multi-group treatment{p_end}
{synopt:{cmd:r(K)}}number of treatment groups (multi-group){p_end}
{synopt:{cmd:r(longitudinal)}}1 for longitudinal contract state{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{p_end}

{pstd}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}


{title:References}

{phang}
Austin, P. C. (2009). Balance diagnostics for comparing the distribution
of baseline covariates between treatment groups in propensity-score matched
samples. {it:Statistics in Medicine}, 28(25), 3083-3107.

{phang}
Austin, P. C. (2011). An introduction to propensity score methods for
reducing the effects of confounding in observational studies.
{it:Multivariate Behavioral Research}, 46(3), 399-424.

{phang}
Crump, R. K., Hotz, V. J., Imbens, G. W., & Mitnik, O. A. (2009).
Dealing with limited overlap in estimation of average treatment effects.
{it:Biometrika}, 96(1), 187-199.


{title:Also see}

{psee}
{space 2}Help:  {manhelp teffects TE}, {manhelp logit R}, {manhelp mlogit R},
{manhelp tebalance TE}, {help tebalance##summarize:tebalance summarize}, {manhelp teoverlap TE}
{p_end}

{hline}
