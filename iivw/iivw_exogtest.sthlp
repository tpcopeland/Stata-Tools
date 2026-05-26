{smcl}
{* *! version 1.2.3  26may2026}{...}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "iivw_exogtest##syntax"}{...}
{viewerjumpto "Description" "iivw_exogtest##description"}{...}
{viewerjumpto "Options" "iivw_exogtest##options"}{...}
{viewerjumpto "Remarks" "iivw_exogtest##remarks"}{...}
{viewerjumpto "Interpreting results" "iivw_exogtest##interpreting"}{...}
{viewerjumpto "Examples" "iivw_exogtest##examples"}{...}
{viewerjumpto "Stored results" "iivw_exogtest##results"}{...}
{viewerjumpto "References" "iivw_exogtest##references"}{...}
{viewerjumpto "Author" "iivw_exogtest##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:iivw_exogtest} {hline 2}}Test whether lagged outcomes predict subsequent visit timing{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_exogtest}
{it:varlist}
{ifin}
{cmd:,}
{opt id(varname)}
{opt time(varname)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}subject identifier{p_end}
{synopt:{opt time(varname)}}visit or test time, numeric{p_end}

{syntab:Model}
{synopt:{opt adj:ust(varlist)}}baseline or design covariates to condition on{p_end}
{synopt:{opt by(varname)}}fit separate timing diagnostics within levels{p_end}
{synopt:{opt ent:ry(varname)}}subject-specific study entry time{p_end}

{syntab:Generated lags}
{synopt:{opt gen:erate(name)}}prefix for generated lag variables; default {cmd:_iivw_exog_}{p_end}
{synopt:{opt replace}}overwrite generated lag variables from a previous run{p_end}

{syntab:Estimation}
{synopt:{opt efr:on}}use Efron method for tied event times in {cmd:stcox}{p_end}
{synopt:{opt nolog}}suppress Cox iteration log{p_end}
{synopt:{opt l:evel(#)}}confidence level for hazard-ratio intervals; default {cmd:c(level)}{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_exogtest} is a diagnostic command for longitudinal data in which
visit or measurement timing may depend on recent outcome history.  It creates
one-visit lags of the variables in {it:varlist} and fits counting-process Cox
models for the timing of the next visit.  A small individual or joint p-value
is evidence that prior outcomes or disease activity predict the measurement
schedule.

{pstd}
This is a falsification or sensitivity diagnostic, not a proof of exogeneity.
If lagged outcomes predict visit timing, direct adjustment for cumulative test
number should be interpreted as potentially endogenous because the test count
lies on the visit pathway.

{pstd}
With {opt by()}, the command fits separate Cox models within levels of the
specified variable, commonly treatment arm.  Groups with too few usable
intervals, fewer than two subjects, or no variation in lagged predictors are
skipped with a note.  The command fails only if no model is estimable.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the subject identifier.  Each subject-time
combination used in the diagnostic must be unique.

{phang}
{opt time(varname)} specifies the visit or measurement time.  It must be
numeric.  Within subject, observations are sorted by this variable before lags
and counting-process intervals are constructed.

{dlgtab:Model}

{phang}
{opt adjust(varlist)} specifies covariates to include in the Cox timing model
alongside the lagged test variables.  These are usually baseline or design
covariates, such as age, sex, baseline severity, calendar period, or clinic.

{phang}
{opt by(varname)} fits one model per level of {it:varname}.  This is useful
when the scientific question is whether lagged outcomes predict visit timing
within treatment arm rather than only in the pooled cohort.

{phang}
{opt entry(varname)} specifies a subject-specific entry time.  The variable
must be nonmissing, constant within subject, and strictly less than the first
visit time used for that subject.

{dlgtab:Generated lags}

{phang}
{opt generate(name)} specifies the prefix for generated lag variables.  The
default is {cmd:_iivw_exog_}.  For a test variable {cmd:sdmt}, the default
lag variable is {cmd:_iivw_exog_sdmt_lag1}.  Generated lag variables remain
in the dataset after a successful command.

{phang}
{opt replace} allows overwriting generated lag variables from a previous
{cmd:iivw_exogtest} call.  Without {opt replace}, the command errors if any
target lag variable already exists.

{dlgtab:Estimation}

{phang}
{opt efron} uses the Efron method for tied event times in {cmd:stcox}.

{phang}
{opt nolog} suppresses the Cox iteration log.

{phang}
{opt level(#)} specifies the confidence level for displayed hazard-ratio
intervals.  The diagnostic alpha is {cmd:(100-level)/100}; for example,
{cmd:level(90)} uses alpha 0.10.


{marker remarks}{...}
{title:Remarks}

{pstd}
The command builds Andersen-Gill style recurrent-event intervals:
the start time is the previous visit time, or {opt entry()} for the first
record, and the stop time is the current visit time.  First observations for
each subject have no prior outcome history and are excluded from the timing
test.

{pstd}
The fitted model is:

{p 12 12 2}
{cmd:stcox} {it:lagged_test_variables} {it:adjustment_variables}{cmd:, vce(cluster id)}

{pstd}
The active estimation result is preserved.  Internally, the command uses
{cmd:_estimates hold} and {cmd:preserve} so the survival settings and active
{cmd:e()} results present before the diagnostic are restored afterward.

{pstd}
Interpretation language is deliberately cautious.  Use "no evidence in this
diagnostic that prior outcomes predict visit timing" when p-values are not
small, and "evidence that prior outcomes or disease activity predict visit
timing" when they are.  Avoid calling a cumulative-test adjustment simply
valid or invalid from this command alone.


{marker interpreting}{...}
{title:Interpreting results}

{pstd}
Read {cmd:iivw_exogtest} as a stress test for a measurement-process
adjustment, not as a hypothesis test that certifies causal assumptions.

{p2colset 5 28 62 2}{...}
{p2col:{bf:Output pattern}}{bf:Practical interpretation}{p_end}
{p2col:Small individual or joint p-value}
Lagged outcome or disease activity predicts future visit timing in the
specified model.  A direct adjustment for cumulative testing may be
endogenous because testing lies on a pathway affected by prior outcome
history.{p_end}
{p2col:No small p-values}
The diagnostic did not find evidence that the tested lagged variables predict
visit timing, conditional on the adjustment variables.  This is supportive,
but it is not proof that visit timing is exogenous.{p_end}
{p2col:Groups skipped}
Some by-groups lacked enough usable intervals, subjects, or variation.  Do
not treat skipped groups as negative evidence; report them and consider
coarser grouping or a pooled diagnostic.{p_end}
{p2col:Large hazard ratio}
A one-unit increase in the lagged predictor is associated with earlier or
more frequent observed visits in the counting-process model.  Check the
scale of the predictor before comparing hazard ratios across variables.
{p_end}
{p2colreset}{...}

{pstd}
For reporting, name the lagged variables tested, the adjustment variables,
whether diagnostics were pooled or run within groups, the number of models
fit and skipped, and the minimum individual and joint p-values.  When the
diagnostic is positive, pass {cmd:exogeneity(endogenous)} to
{helpb iivw_diagnose} and frame the adjusted model as a sensitivity bound.


{marker examples}{...}
{title:Examples}

{pstd}Create example longitudinal visit data.{p_end}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 240526}{p_end}
{phang2}{cmd:. set obs 240}{p_end}
{phang2}{cmd:. gen id = ceil(_n/4)}{p_end}
{phang2}{cmd:. bysort id: gen visit = _n}{p_end}
{phang2}{cmd:. gen treatment = mod(id,2)}{p_end}
{phang2}{cmd:. gen age = 35 + mod(id,20)}{p_end}
{phang2}{cmd:. gen female = mod(id,3)==0}{p_end}
{phang2}{cmd:. bysort id: gen double sdmt = 45 - .15*age + 1.5*treatment + rnormal() if visit==1}{p_end}
{phang2}{cmd:. bysort id: replace sdmt = sdmt[_n-1] + .3*treatment + rnormal() if visit>1}{p_end}
{phang2}{cmd:. gen recent_relapse = runiform() < invlogit(-2 + .04*(50-sdmt))}{p_end}
{phang2}{cmd:. bysort id (visit): gen double gap = 3 + .02*(50-sdmt[_n-1]) + runiform() if visit>1}{p_end}
{phang2}{cmd:. bysort id (visit): replace gap = 0 if visit==1}{p_end}
{phang2}{cmd:. bysort id (visit): gen double months = sum(gap)}{p_end}

{pstd}Run a pooled diagnostic.{p_end}

{phang2}{cmd:. iivw_exogtest sdmt recent_relapse, id(id) time(months) adjust(age female) efron nolog}{p_end}

{pstd}Run the diagnostic separately by treatment arm.{p_end}

{phang2}{cmd:. iivw_exogtest sdmt recent_relapse, id(id) time(months) adjust(age female) by(treatment) replace efron nolog}{p_end}

{pstd}Use a shorter generated-variable prefix.{p_end}

{phang2}{cmd:. iivw_exogtest sdmt, id(id) time(months) generate(x_) replace nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_exogtest} stores the following in {cmd:r()}:

{synoptset 28 tabbed}{...}
{p2col 5 28 32 2:Scalars}{p_end}
{synopt:{cmd:r(N)}}total usable intervals across fitted models{p_end}
{synopt:{cmd:r(n_ids)}}total subjects across fitted models{p_end}
{synopt:{cmd:r(n_models)}}number of fitted Cox models{p_end}
{synopt:{cmd:r(n_skipped)}}number of skipped groups{p_end}
{synopt:{cmd:r(min_p)}}minimum individual Wald p-value for lagged predictors{p_end}
{synopt:{cmd:r(joint_min_p)}}minimum joint p-value for lagged predictors{p_end}
{synopt:{cmd:r(alpha)}}diagnostic alpha, equal to {cmd:(100-level)/100}{p_end}
{synopt:{cmd:r(endogenous_flag)}}1 if any individual or joint p-value is below alpha; otherwise 0{p_end}

{p2col 5 28 32 2:Macros}{p_end}
{synopt:{cmd:r(id)}}subject identifier{p_end}
{synopt:{cmd:r(time)}}visit or measurement time variable{p_end}
{synopt:{cmd:r(testvars)}}original variables tested through lagged values{p_end}
{synopt:{cmd:r(lagvars)}}generated lag variables used in the Cox models{p_end}
{synopt:{cmd:r(adjust)}}adjustment variables{p_end}
{synopt:{cmd:r(by)}}by variable, if specified{p_end}
{synopt:{cmd:r(group_labels)}}pipe-separated labels for model groups{p_end}
{synopt:{cmd:r(skipped_labels)}}pipe-separated labels for skipped groups{p_end}
{synopt:{cmd:r(term_labels)}}lagged predictor labels used as result terms{p_end}
{synopt:{cmd:r(result_row_labels)}}row labels for {cmd:r(results)}{p_end}
{synopt:{cmd:r(result_columns)}}column labels for {cmd:r(results)}{p_end}
{synopt:{cmd:r(conclusion)}}short diagnostic conclusion{p_end}

{p2col 5 28 32 2:Matrices}{p_end}
{synopt:{cmd:r(results)}}numeric results matrix with columns {cmd:group_index term_index b se z p hr lb ub N n_ids}{p_end}
{p2colreset}{...}


{marker references}{...}
{title:References}

{phang}
Buzkova P, Lumley T. 2007.
Longitudinal data analysis for generalized linear models with follow-up
dependent on outcome-related variables.
{it:Canadian Journal of Statistics} 35(4): 485-500.
doi:10.1002/cjs.5550350402.

{phang}
Lin H, Scharfstein DO, Rosenheck RA. 2004.
Analysis of longitudinal data with irregular, outcome-dependent follow-up.
{it:Journal of the Royal Statistical Society: Series B (Statistical Methodology)}
66(3): 791-813.
doi:10.1111/j.1467-9868.2004.b5543.x.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.2.3, 2026-05-26{p_end}

{hline}
