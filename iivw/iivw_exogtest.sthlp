{smcl}
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
{synopt:{opt by(varname)}}separate diagnostics by level{p_end}
{synopt:{opt byst:art}}allow time-varying {opt by()} (start values){p_end}
{synopt:{opt ent:ry(varname)}}subject-specific study entry time{p_end}
{synopt:{opt cens:or(varname)}}subject-specific end of follow-up{p_end}
{synopt:{opt max:fu(#)}}common end of follow-up for all subjects{p_end}
{synopt:{opt endatlast:visit}}follow-up ends at each subject's last visit{p_end}

{syntab:Generated lags}
{synopt:{opt gen:erate(name)}}lag-variable prefix; default {cmd:_iivw_exog_}{p_end}
{synopt:{opt replace}}overwrite lag variables and worksheet{p_end}

{syntab:Estimation}
{synopt:{opt efr:on}}use Efron method for tied event times in {cmd:stcox}{p_end}
{synopt:{opt nolog}}suppress Cox iteration log{p_end}
{synopt:{opt l:evel(#)}}confidence level; default {cmd:c(level)}{p_end}

{syntab:Excel export}
{synopt:{opt xlsx(filename)}}write the exogeneity table to an Excel workbook{p_end}
{synopt:{opt sheet(sheetname)}}Excel worksheet name; default {cmd:Exogeneity}{p_end}
{synopt:{opt title(string)}}optional Excel title row{p_end}
{synopt:{opt footnote(string)}}optional Excel footnote row{p_end}
{synopt:{opt dec:imals(#)}}Excel decimal places (0-6, default 3){p_end}
{synopt:{opt open}}open the workbook after writing{p_end}
{synopt:{opt border:style(string)}}Excel border scheme; default {cmd:thin}{p_end}
{synopt:{opt headers:hade}}shade the header rows; off by default{p_end}
{synopt:{opt the:me(string)}}journal preset (e.g. {cmd:lancet}, {cmd:nejm}, {cmd:jama}, {cmd:apa}){p_end}
{synopt:{opt headerc:olor(string)}}header fill as {cmd:"R G B"} 0-255{p_end}
{synopt:{opt zebrac:olor(string)}}zebra fill as {cmd:"R G B"} 0-255; used with {opt zebra}{p_end}
{synopt:{opt zeb:ra}}shade alternating data rows{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_exogtest} is a diagnostic command for longitudinal data in which
visit or measurement timing may depend on recent outcome history. It creates
one-visit lags of the variables in {it:varlist} and fits counting-process Cox
models for the timing of the next visit. A small individual or joint p-value
is evidence that prior outcomes or disease activity predict the measurement
schedule.

{pstd}
This is a falsification or sensitivity diagnostic, not a proof of
exogeneity. If lagged outcomes predict visit timing, direct adjustment for
cumulative test number should be interpreted as potentially endogenous because
the test count lies on the visit pathway.

{pstd}
With {opt by()}, the command fits separate Cox models within levels of the
specified variable, commonly treatment arm. Groups with too few usable
intervals, fewer than two subjects, or no variation in lagged predictors are
skipped with a note. The command fails only if no model is estimable.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the subject identifier. Each subject-time
combination used in the diagnostic must be unique.

{phang}
{opt time(varname)} specifies the visit or measurement time. It must be
numeric and nonnegative: the counting process is at risk from time 0, so
visits at negative times are rejected rather than silently excluded from the
Cox model. Within subject, observations are sorted by this variable before
lags and counting-process intervals are constructed.

{dlgtab:Model}

{phang}
{opt adjust(varlist)} specifies covariates to include in the Cox timing model
alongside the lagged test variables. These are usually baseline or design
covariates, such as age, sex, baseline severity, calendar period, or clinic.

{phang}
{opt by(varname)} fits one model per level of {it:varname}. This is useful
when the scientific question is whether lagged outcomes predict visit timing
within treatment arm rather than only in the pooled cohort.

{phang2}
{it:varname} must be {bf:constant within subject}, which is what the
treatment-arm use means. If it changes within a subject, {cmd:iivw_exogtest}
exits with an error rather than guessing. The reason is that each risk interval
runs from the previous visit to the current one, so taking its group from the
current row would classify an interval by a value that was only realized at the
interval's own endpoint: a subject who switches arm at visit 4 would have the
interval that {it:ended} at visit 4 counted in the post-switch arm. That is
end-of-interval conditioning.

{phang}
{opt byst:art} allows a genuinely time-varying {opt by()} variable by assigning
each interval the group in force at its {bf:start} -- the value at the previous
visit. The first interval of each subject takes that subject's first observed
value, which is the value in force at study entry. Requires {opt by()}.

{phang}
{opt entry(varname)} specifies a subject-specific entry time. The variable must be
nonmissing, constant within subject, and strictly less than the first visit
time used for that subject. Negative entry times are accepted (useful when
first visits occur at time 0), but risk time before 0 is not counted; a note
is displayed when this applies.

{phang}
{bf:One of} {opt censor()}, {opt maxfu()} {bf:or} {opt endatlastvisit} {bf:is required},
and it must match the specification you gave {helpb iivw_weight} -- otherwise the
exogeneity test describes a different visit-intensity model than the one that
produced your weights.

{pmore}
{cmd:iivw_exogtest} fits the same Andersen-Gill visit-intensity model as
{helpb iivw_weight}, so it inherits the same requirement: the model needs each
subject's observation {it:window}, not merely the intervals between their
visits. Without a post-last-visit at-risk interval, every subject leaves the
risk set at their own last visit, and the test statistic is computed on a risk
set shaped by the very process it is testing. See {helpb iivw_weight##options:iivw_weight} for the full
discussion; the three options mean exactly what they mean there.

{dlgtab:Generated lags}

{phang}
{opt generate(name)} specifies the prefix for generated lag variables. The
default is {cmd:_iivw_exog_}. For a test variable {cmd:sdmt}, the default
lag variable is {cmd:_iivw_exog_sdmt_lag1}. Generated lag variables remain
in the dataset after a successful command.

{phang}
{opt replace} allows overwriting generated lag variables from a previous
{cmd:iivw_exogtest} call, and also overwrites the target Excel worksheet when
{opt xlsx()} writes to a sheet that already exists. Without
{opt replace}, the command errors if any target lag variable already exists,
and an existing worksheet of the same name is left untouched.

{dlgtab:Estimation}

{phang}
{opt efron} uses the Efron method for tied event times in {cmd:stcox}.

{phang}
{opt nolog} suppresses the Cox iteration log.

{phang}
{opt level(#)} specifies the confidence level for displayed hazard-ratio
intervals. The diagnostic alpha is {cmd:(100-level)/100}; for example,
{cmd:level(90)} uses alpha 0.10.

{dlgtab:Excel export}

{phang}
{opt xlsx(filename)} writes a {cmd:regtab}-style exogeneity table to an Excel
{cmd:.xlsx} workbook. The exported table uses the first label column for
readable lagged-predictor row labels, taking variable labels from {it:varlist}
and falling back to variable names when labels are absent. Each fitted group
gets a hazard-ratio, confidence-interval, and p-value column block, followed
by a joint-test row. The worksheet is formatted with a merged title row,
group headers, statistic headers, column widths, borders, and an explanatory
footnote.

{phang}
{opt sheet(sheetname)} sets the Excel worksheet name. The default is
{cmd:Exogeneity}. This option requires {opt xlsx()}.

{phang}
Excel output follows the tabtools workbook convention: only the named sheet is
cleared and rewritten; other sheets in the workbook are preserved. The
{opt replace} option overwrites both the target worksheet (when it already
exists) and any generated lag variables from a previous run. Without
{opt replace}, an existing worksheet of the same name is left untouched, the
export is skipped with a warning, and the diagnostic results are still
returned in {cmd:r()}.

{phang}
{opt open} opens the Excel workbook after writing it. This option requires
{opt xlsx()}.

{phang}
{opt title(string)} and {opt footnote(string)} add optional title and footnote
rows to Excel output.

{phang}
{opt decimals(#)} sets the number of decimal places used for exported hazard ratios,
confidence intervals, and p-values. The allowed range is 0 through 6; the
default is 3.

{phang}
{opt borderstyle(string)} selects the Excel border scheme and requires {opt xlsx()}. {cmd:thin}
(the default) draws the tabtools house style: an outer frame, horizontal rules in the
header band, and vertical separators after the label column and between column
groups. Data rows are not separated by interior horizontal rules. {cmd:medium} draws
the same layout with medium lines. {cmd:academic} uses a three-rule
(top/header/bottom) layout with no vertical rules at all. {cmd:default} is an alias
for {cmd:thin}.

{phang}
{opt headershade} shades the header rows. It is off by default so that output
matches the unshaded house style. {opt headercolor(string)} sets the header
fill as three space-separated 0-255 RGB values, for example
{cmd:headercolor("219 229 241")}.

{phang}
{opt zebra} shades alternating data rows, and {opt zebracolor(string)} sets
that fill as {cmd:"R G B"} values.

{phang}
{opt theme(string)} applies a journal preset ({cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos},
{cmd:nature}, {cmd:cell}, or {cmd:annals}) that sets the font, font size, and border scheme
together. Explicit {opt borderstyle()}, {opt headershade}, or {opt zebra} options override the
matching theme setting.


{marker remarks}{...}
{title:Remarks}

{pstd}
The command builds Andersen-Gill style recurrent-event intervals: the start
time is the previous visit time, or {opt entry()} for the first record, and the stop
time is the current visit time. First observations for each subject have no
prior outcome history and are excluded from the timing test.

{pstd}
The fitted model is:

{p 12 12 2}
{cmd:stcox} {it:lagged_test_variables} {it:adjustment_variables}{cmd:, vce(cluster id)}

{pstd}
The active estimation result is preserved. Internally, the command uses
{cmd:_estimates hold} and {cmd:preserve} so the survival settings and active
{cmd:e()} results present before the diagnostic are restored afterward.

{pstd}
Interpretation language is deliberately cautious. Use "no evidence in this
diagnostic that prior outcomes predict visit timing" when p-values are not
small, and "evidence that prior outcomes or disease activity predict visit
timing" when they are. Avoid calling a cumulative-test adjustment simply
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
specified model. A direct adjustment for cumulative testing may be
endogenous because testing lies on a pathway affected by prior outcome
history.{p_end}
{p2col:No small p-values}
The diagnostic did not find evidence that the tested lagged variables predict
visit timing, conditional on the adjustment variables. This is supportive,
but it is not proof that visit timing is exogenous.{p_end}
{p2col:Groups skipped}
Some by-groups lacked enough usable intervals, subjects, or variation. Do
not treat skipped groups as negative evidence; report them and consider
coarser grouping or a pooled diagnostic.{p_end}
{p2col:Large hazard ratio}
A one-unit increase in the lagged predictor is associated with earlier or
more frequent observed visits in the counting-process model. Check the
scale of the predictor before comparing hazard ratios across variables.
{p_end}
{p2colreset}{...}

{pstd}
For reporting, name the lagged variables tested, the adjustment variables,
whether diagnostics were pooled or run within groups, the number of models
fit and skipped, and the minimum individual and joint p-values. When the
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

{pstd}Export the by-arm diagnostic to an Excel worksheet.{p_end}

{phang2}{cmd:. iivw_exogtest sdmt recent_relapse, id(id) time(months) adjust(age female) by(treatment) replace efron nolog xlsx(iivw_results.xlsx) sheet("Move 2 Exogeneity")}{p_end}

{pstd}Use a shorter generated-variable prefix.{p_end}

{phang2}{cmd:. iivw_exogtest sdmt, id(id) time(months) generate(x_) replace nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_exogtest} stores the following in {cmd:r()}:

{synoptset 28 tabbed}{...}
{p2col 5 28 32 2:Scalars}{p_end}
{synopt:{cmd:r(N)}}total usable intervals across fitted models{p_end}
{synopt:{cmd:r(n_ids)}}subjects summed over fitted models (see note){p_end}
{synopt:{cmd:r(n_models)}}number of fitted Cox models{p_end}
{synopt:{cmd:r(n_skipped)}}number of skipped groups{p_end}
{synopt:{cmd:r(n_groups)}}number of groups examined, fitted and skipped{p_end}
{synopt:{cmd:r(n_terms)}}number of lagged terms tested{p_end}
{synopt:{cmd:r(min_p)}}minimum unadjusted Wald p-value{p_end}
{synopt:{cmd:r(joint_min_p)}}minimum raw within-group omnibus p-value{p_end}
{synopt:{cmd:r(holm_min_p)}}minimum omnibus p-value, Holm-adjusted across groups{p_end}
{synopt:{cmd:r(n_tests)}}number of omnibus tests in the Holm family{p_end}
{synopt:{cmd:r(alpha)}}diagnostic alpha, equal to {cmd:(100-level)/100}{p_end}
{synopt:{cmd:r(endogenous_flag)}}1 if {cmd:r(holm_min_p)} is below alpha; otherwise 0{p_end}
{synopt:{cmd:r(decimals)}}Excel decimals used (export only){p_end}

{p2col 5 28 32 2:Macros}{p_end}
{synopt:{cmd:r(id)}}subject identifier{p_end}
{synopt:{cmd:r(time)}}visit or measurement time variable{p_end}
{synopt:{cmd:r(testvars)}}original variables tested through lagged values{p_end}
{synopt:{cmd:r(lagvars)}}generated lag variables used in the Cox models{p_end}
{synopt:{cmd:r(adjust)}}adjustment variables{p_end}
{synopt:{cmd:r(by)}}by variable, if specified{p_end}
{synopt:{cmd:r(group_label_}{it:#}{cmd:)}}label of group {it:#}, for {it:#} = 1 to {cmd:r(n_groups)}{p_end}
{synopt:{cmd:r(skipped_label_}{it:#}{cmd:)}}label of skipped group {it:#}, for {it:#} = 1 to {cmd:r(n_skipped)}{p_end}
{synopt:{cmd:r(term_label_}{it:#}{cmd:)}}label of lagged term {it:#}, for {it:#} = 1 to {cmd:r(n_terms)}{p_end}
{synopt:{cmd:r(result_row_labels)}}row labels for {cmd:r(results)}{p_end}
{synopt:{cmd:r(result_columns)}}column labels for {cmd:r(results)}{p_end}
{synopt:{cmd:r(conclusion)}}short diagnostic conclusion{p_end}
{synopt:{cmd:r(xlsx)}}Excel workbook written; only when {opt xlsx()} succeeds{p_end}
{synopt:{cmd:r(sheet)}}Excel worksheet written (export only){p_end}

{p2col 5 28 32 2:Matrices}{p_end}
{synopt:{cmd:r(results)}}numeric model-by-term results matrix{p_end}
{p2colreset}{...}

{pstd}
{cmd:r(results)} has columns {cmd:group_index}, {cmd:term_index}, {cmd:b},
{cmd:se}, {cmd:z}, {cmd:p}, {cmd:hr}, {cmd:lb}, {cmd:ub}, {cmd:N}, and
{cmd:n_ids}.

{phang}
Labels are returned one per macro, indexed, rather than joined into a single
delimited macro. A variable or value label may legally contain a vertical bar or a
double quote, so a delimited macro cannot be parsed back reliably: the old
{cmd:r(group_labels)} could not distinguish two groups labelled {cmd:a} and {cmd:b}
from one group labelled {cmd:a|b}. Labels are now carried verbatim into
{cmd:r(group_label_}{it:#}{cmd:)}, {cmd:r(term_label_}{it:#}{cmd:)},
{cmd:r(skipped_label_}{it:#}{cmd:)}, and the Excel export.

{phang}
Note on {cmd:r(N)} and {cmd:r(n_ids)}: both are summed over the fitted models, and skipped
groups contribute nothing. Every row belongs to exactly one {opt by()} group, so
{cmd:r(N)} is also the distinct number of usable intervals. Subjects are not
partitioned that way: under {opt bystart} a subject whose group changes can
contribute usable intervals to two groups and is counted once per group, so
{cmd:r(n_ids)} exceeds the number of distinct subjects. With a subject-constant
{opt by()} variable, the usual case, the two coincide.


{marker multiplicity}{...}
{title:Multiplicity and the endogeneity flag}

{pstd}
{cmd:r(endogenous_flag)} is driven by {bf:one} family of tests: the within-group
omnibus (joint) test of all lagged predictors, one per fitted group,
{bf:Holm-adjusted across groups}. The flag is 1 when the smallest adjusted
omnibus p-value falls below alpha.

{pstd}
The individual term p-values in the table are {bf:exploratory}. They are reported
unadjusted and they do {it:not} set the flag. Flagging on "any term in any group is
significant" gives the flag an uncontrolled familywise error rate: with ten
independent null terms, the probability that at least one falls below 0.05 is
1 - 0.95^10 = 40%, before the group-wise omnibus tests are counted at all. A
diagnostic that fires on 40% of null data is not a diagnostic, and a workflow
that keys off it will discard good weights.

{pstd}
Holm is used rather than Bonferroni because it is uniformly more powerful and
requires no independence assumption. Both the raw ({cmd:r(joint_min_p)}) and
adjusted ({cmd:r(holm_min_p)}) values are returned so that the adjustment is
auditable.

{pstd}
Missing an association is still possible: this is a diagnostic with finite
power, and failing to flag is not evidence that visit timing is exogenous.


{marker references}{...}
{title:References}

{phang}
Buzkova P, Lumley T. 2007. Longitudinal data analysis for generalized linear
models with follow-up dependent on outcome-related
variables. {it:Canadian Journal of Statistics}
35(4): 485-500. doi:10.1002/cjs.5550350402.

{phang}
Lin H, Scharfstein DO, Rosenheck RA. 2004. Analysis of longitudinal data with
irregular, outcome-dependent follow-up. {it:Journal of the Royal Statistical}
{it:Society: Series B (Statistical Methodology)}
66(3): 791-813. doi:10.1111/j.1467-9868.2004.b5543.x.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
