{smcl}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_fit" "help msm_fit"}{...}
{viewerjumpto "Syntax" "msm_diagnose##syntax"}{...}
{viewerjumpto "Description" "msm_diagnose##description"}{...}
{viewerjumpto "What to look for" "msm_diagnose##interpreting"}{...}
{viewerjumpto "Options" "msm_diagnose##options"}{...}
{viewerjumpto "Examples" "msm_diagnose##examples"}{...}
{viewerjumpto "Stored results" "msm_diagnose##stored"}{...}
{viewerjumpto "Author" "msm_diagnose##author"}{...}

{title:Title}

{phang}
{bf:msm_diagnose} {hline 2} Longitudinal covariate balance and positivity diagnostics for MSM


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_diagnose}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth bal:ance_covariates(varlist)}}covariates for SMD balance assessment{p_end}
{synopt:{opt thr:eshold(#)}}SMD balance threshold; default is {cmd:0.1}{p_end}
{synopt:{opt posit:ivity(#)}}positivity floor; default {cmd:0.01}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_diagnose} reports the diagnostics that are specific to a longitudinal
MSM and that pooled propensity-score tools cannot produce:

{phang2}1. {bf:Treatment balance within period and prior-treatment history},
with a {cmd:target} flag that separates denominator covariates (expected to
balance) from stabilized-numerator covariates (not expected to).{p_end}

{phang2}2. {bf:Censoring balance} by period in the censoring decision risk set,
when IPCW was fitted.{p_end}

{phang2}3. {bf:Positivity}: the smallest estimated probability of the treatment
actually observed in each period, against a floor, and the periods in which no
decision-risk row was treated or none untreated.{p_end}

{pstd}
A pooled person-period SMD table is kept as a secondary summary. Every summary
uses the decision risk set ({cmd:_msm_decision_risk}). The command reads
{cmd:_msm_weight} from {helpb msm_weight} and the mapping from
{helpb msm_prepare}; it creates no variables and writes nothing to the
dataset.

{pstd}
{bf:Weight distributions moved to psdash.} From msm 2.0.0 the pooled weight
summary (mean, SD, percentiles, ESS, extreme weights) and the per-period weight
table are produced by {cmd:psdash}, which reads the msm contract and restricts
to the risk set:

{phang2}{cmd:. psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) detail}{p_end}
{phang2}{cmd:. psdash combined}{p_end}

{pstd}
{cmd:msm_weight} also returns the risk-set ESS in {cmd:r(ess)}. The options
{cmd:by_period}, {cmd:accumulate()}, {cmd:contrast()} and {cmd:outcome()} were
removed in 2.0.0 and exit with return code 198 naming the replacement.

{pstd}
If {cmd:balance_covariates()} is omitted, the command uses all covariates
registered with {helpb msm_prepare} (time-varying and baseline). If none were
registered, it uses the treatment-denominator covariates given to
{helpb msm_weight}'s {cmd:treat_d_cov()}. With no covariates at all it exits
with return code 198.


{marker interpreting}{...}
{title:What to look for}

{pstd}
{bf:Longitudinal covariate balance:}

{phang2}{bf:Period and treatment history first:} The primary treatment-balance
matrix compares treated and untreated decisions separately at each period and,
after baseline, within prior-treatment strata. Opposite imbalances can cancel
in a pooled person-period SMD.{p_end}

{phang2}{bf:Balance targets:} A {cmd:target} value of 1 marks denominator-only
covariates expected to balance. Stabilized-numerator covariates have
{cmd:target=0}: the numerator intentionally retains their target distribution,
so they must also enter the outcome model rather than be declared balanced
away.{p_end}

{phang2}{bf:Positivity:} A period flagged by the {opt positivity()} floor holds
rows whose observed decision had a very small estimated probability; those rows
carry extreme weights. A period flagged in {cmd:r(n_support_violations)} has no
treated or no untreated decision at all, so its contrast rests entirely on the
model's period terms.{p_end}

{phang2}{bf:Censoring separately:} When IPCW is present, censoring SMDs are
reported by period in the censoring decision risk set. The diagnostic carries
forward prior uncensoring factors and replaces the current all-uncensored IPCW
factor with the stabilized factor for the observed censoring decision. This
permits a valid comparison of currently censored and uncensored groups. The
censoring SMDs are not folded into the treatment table.{p_end}

{phang2}{bf:SMD < 0.1:} The standard threshold for acceptable balance. SMDs
above 0.1 after weighting suggest residual confounding for that variable.{p_end}

{phang2}{bf:How the SMD is standardized:} SMD = (mean1 - mean0) /
sqrt((var1 + var0) / 2). The weighted SMD substitutes weighted means
{it:and} weighted variances, per Austin and Stuart (2015, section 4.1.1): "each
sample estimate can be replaced by its weighted equivalent". The
denominator of the weighted SMD is therefore the pooled SD of the
pseudo-population, not of the crude sample. Consequence: {cmd:raw_smd} and
{cmd:weighted_smd} are each standardized on their own sample's scale, so the
pair is not a single series rescaled by a common constant, and a weighted SMD
can move because the weights changed the spread rather than the location. The
alternative convention, one common unweighted denominator for both columns, is
the default in the R package {cmd:cobalt} (its {cmd:bal.tab()} help: the
spread is always that of the full, unadjusted sample) and in
{cmd:psdash balance}. The two conventions are both in use and are kept deliberately; on the
same weighted data they give slightly different weighted SMDs, so a covariate
near the threshold can be classified differently by the two commands. Report
which convention a table uses. For a continuous covariate, the weighted variance is the exact
reliability-weight estimator
sum(w)/[sum(w)^2-sum(w^2)] times sum[w(x-xbar_w)^2]. For a dichotomous
covariate, the denominator uses the weighted prevalence term p_w(1-p_w). Read
{cmd:pct_change} as a direction, and judge the weighted column against the
threshold on its own terms.{p_end}

{phang2}{bf:Secondary pooled % change:} A large negative change means weighting improved
balance. A positive change means weighting made balance worse for that
covariate, which warrants investigation.{p_end}

{phang2}The pooled table marks covariates exceeding the threshold with {cmd:*}
and stabilized-numerator covariates with {cmd:(numerator)}; numerator
covariates are shown but are not counted as balanced or imbalanced. Treat the
table as a secondary person-period summary, not the primary longitudinal
balance decision.{p_end}


{marker options}{...}
{title:Options}

{phang}
{opth balance_covariates(varlist)} specifies which covariates to assess for
balance. The command computes SMDs between treated and untreated groups both
without weights (raw) and with the IP weights. If omitted, all covariates
from {helpb msm_prepare} (both {cmd:covariates()} and
{cmd:baseline_covariates()}) are used, or, if none were registered, the
{cmd:treat_d_cov()} covariates from {helpb msm_weight}.

{phang}
{opt threshold(#)} sets the SMD threshold for declaring acceptable balance. The
default is {cmd:0.1}, following common epidemiological practice. Covariates with a
weighted absolute SMD exceeding this threshold are flagged in the output. The
balance summary reports how many covariates are balanced versus imbalanced.

{phang}
{opt positivity(#)} sets the operational positivity floor. A period whose
smallest estimated probability of the observed treatment ({cmd:obs_min} in
{cmd:r(support)}) falls below this value is flagged: such probabilities produce
extreme inverse-probability weights that a marginal treated/untreated count by
period cannot detect (Cole & Hernan 2008). The observed-treatment probability is
P(A=1) on treated rows and 1-P(A=1) on untreated rows, so the floor catches both
tails of the propensity distribution; the {cmd:ps_min} column, which bounds
P(A=1) only, is not used for this test. The default is {cmd:0.01} and the value
must lie strictly between {cmd:0} and {cmd:0.5}. The count of breaching periods
is returned in {cmd:r(n_positivity_violations)}, and the smallest
observed-treatment probability anywhere in the risk set is returned in
{cmd:r(min_obs_probability)}.

{pstd}
{opt by_period}, {opt accumulate()}, {opt contrast()} and {opt outcome()} were
removed in msm 2.0.0; see {help msm_diagnose##description:Description}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Basic diagnostics with default covariates.} Uses all covariates from
{cmd:msm_prepare}:{p_end}

{phang2}{cmd:. capture confirm file msm_example.dta}{p_end}
{phang2}{cmd:. if _rc net get msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace}{p_end}
{phang2}{cmd:. use msm_example.dta, clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. msm_weight, treat_d_cov(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:    treat_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. msm_diagnose}{p_end}

{pstd}
{bf:Explicit covariates and a stricter floor:}{p_end}

{phang2}{cmd:. msm_diagnose, balance_covariates(biomarker comorbidity) threshold(0.1) positivity(0.05)}{p_end}

{pstd}
{bf:Inspecting the matrices programmatically:}{p_end}

{phang2}{cmd:. msm_diagnose, balance_covariates(biomarker comorbidity age sex)}{p_end}
{phang2}{cmd:. display "`r(covariates)'"}{p_end}
{phang2}{cmd:. matrix list r(treatment_balance)}{p_end}
{phang2}{cmd:. matrix list r(support)}{p_end}
{phang2}{cmd:. capture matrix list r(censor_balance)}{p_end}
{phang2}{cmd:. matrix list r(balance)} {it:// secondary pooled summary}{p_end}

{pstd}
{bf:Pooled weights and a Love plot on the balance targets} (psdash):{p_end}

{phang2}{cmd:. psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) graph}{p_end}
{phang2}{cmd:. psdash balance treatment _msm_ps if _msm_decision_risk,}{p_end}
{phang2}{cmd:    covariates(biomarker comorbidity) wvar(_msm_weight) loveplot}{p_end}

{pstd}
{bf:Exporting a matrix} (tabtools):{p_end}

{phang2}{cmd:. msm_diagnose}{p_end}
{phang2}{cmd:. matrix S = r(support)}{p_end}
{phang2}{cmd:. puttab using diagnostics.xlsx, matrix(S) sheet(support)}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:msm_diagnose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(threshold)}}SMD threshold used{p_end}
{synopt:{cmd:r(n_imbalanced)}}balance targets above the threshold (pooled){p_end}
{synopt:{cmd:r(n_numerator)}}numerator covariates shown but not counted{p_end}
{synopt:{cmd:r(n_unavailable)}}targets whose weighted SMD is undefined{p_end}
{synopt:{cmd:r(positivity_threshold)}}operational positivity floor used{p_end}
{synopt:{cmd:r(n_positivity_violations)}}periods whose {cmd:obs_min} falls below the floor{p_end}
{synopt:{cmd:r(min_obs_probability)}}minimum P(observed treatment) in risk set{p_end}
{synopt:{cmd:r(n_support_violations)}}periods with no treated or no untreated row{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(covariates)}}balance covariates, in matrix index order{p_end}
{synopt:{cmd:r(support_violation_periods)}}periods counted in {cmd:r(n_support_violations)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(treatment_balance)}}primary period/history-specific treatment balance{p_end}
{synopt:{cmd:r(censor_balance)}}period-specific censoring balance, when available{p_end}
{synopt:{cmd:r(support)}}period-specific propensity overlap and ESS{p_end}
{synopt:{cmd:r(balance)}}secondary pooled person-period balance matrix{p_end}

{pstd}
{cmd:r(treatment_balance)} has columns {cmd:period}, {cmd:history},
{cmd:covariate}, {cmd:raw_smd}, {cmd:weighted_smd}, {cmd:n_treated},
{cmd:n_untreated}, {cmd:ess}, and {cmd:target}. At the common baseline,
{cmd:history=-1}; later rows use prior treatment 0 or 1. Covariate {it:k} is
word {it:k} of {cmd:r(covariates)}.

{pstd}
{cmd:r(censor_balance)} has columns {cmd:period}, {cmd:covariate},
{cmd:raw_smd}, {cmd:weighted_smd}, {cmd:n_censored}, {cmd:n_uncensored}, and
{cmd:ess}. Its weighted SMD and ESS use the cumulative observed-decision
censoring weight: prior periods retain their uncensoring factors and the
current period uses the stabilized probability of the observed censoring
status. {cmd:r(support)} has columns {cmd:period}, {cmd:N}, {cmd:treated},
{cmd:untreated}, {cmd:ps_min}, {cmd:ps_max}, {cmd:obs_min}, {cmd:common_lo},
{cmd:common_hi}, {cmd:n_outside}, and {cmd:ess}.

{pstd}
{cmd:ps_min} and {cmd:ps_max} bound the estimated P(A=1) in the period. {cmd:obs_min}
is the smallest estimated probability of the treatment each
subject was actually observed to take -- P(A=1) on treated rows and 1-P(A=1) on
untreated rows -- and it is the column the {opt positivity(#)} floor is applied
to. The two answer different questions: a period in which everyone is
comfortably untreated has a small {cmd:ps_min} and no positivity problem, while
a period in which untreated rows sit at P(A=1) near 1 has a large {cmd:ps_min}
and a severe one. Only {cmd:obs_min} tracks the inverse-probability weight the
estimator receives. A period containing a risk-set row for which no usable
treatment probability could be fitted reports {cmd:obs_min} as exactly
{cmd:0}: estimable probabilities are strictly inside (0,1), so {cmd:0} is an
unambiguous "no usable probability" sentinel and it trips the floor. That state
is reachable only under the explicit {cmd:probpolicy(clip)} opt-in in
{helpb msm_weight}; the default {cmd:probpolicy(error)} refuses earlier.

{pstd}
The secondary {cmd:r(balance)} has rows named by covariate and columns {cmd:raw_smd},
{cmd:weighted_smd}, and {cmd:pct_change}; it pools person-period rows and is
therefore secondary. Like every other summary this command reports, it is
computed on the risk set (rows flagged by {cmd:_msm_decision_risk}). Post-event
and post-censor rows carry the last cumulative weight forward and are never
seen by the outcome model, so including them could report large residual
imbalance for a correctly weighted analysis.


{marker references}{...}
{title:References}

{phang}
Adenyo D, Guertin JR, Candas B, Sirois C, Talbot D. 2024. Evaluation and
comparison of covariate balance metrics in studies with time-dependent
confounding. {it:Statistics in Medicine}. doi:10.1002/sim.10188.{p_end}

{phang}
Greifer N. cobalt: Covariate Balance Tables and Plots. R package version
5.0.0. doi:10.32614/CRAN.package.cobalt. Default unweighted SMD denominator.{p_end}

{phang}
Austin PC, Stuart EA. 2015. Moving towards best practice when using inverse
probability of treatment weighting (IPTW) using the propensity score to
estimate causal treatment effects in observational studies. {it:Statistics in Medicine}
34(28): 3661-3679. doi:10.1002/sim.6607. Grounds the weighted standardized
mean difference and its denominator convention.{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}
