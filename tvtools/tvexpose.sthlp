{smcl}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "[ST] stsplit" "help stsplit"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{viewerjumpto "Syntax" "tvexpose##syntax"}{...}
{viewerjumpto "Description" "tvexpose##description"}{...}
{viewerjumpto "Required options" "tvexpose##required_options"}{...}
{viewerjumpto "Exposure definition options" "tvexpose##exposure_options"}{...}
{viewerjumpto "Data handling options" "tvexpose##data_handling"}{...}
{viewerjumpto "Competing exposures options" "tvexpose##competing"}{...}
{viewerjumpto "Lag and washout options" "tvexpose##lag_washout"}{...}
{viewerjumpto "Pattern tracking options" "tvexpose##pattern_tracking"}{...}
{viewerjumpto "Output options" "tvexpose##output"}{...}
{viewerjumpto "Diagnostic options" "tvexpose##diagnostic"}{...}
{viewerjumpto "Remarks" "tvexpose##remarks"}{...}
{viewerjumpto "Examples" "tvexpose##examples"}{...}
{viewerjumpto "Stored results" "tvexpose##results"}{...}
{viewerjumpto "Author" "tvexpose##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:tvexpose} {hline 2}}Create time-varying exposure variables for survival analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvexpose}
{cmd:using} {it:filename},
{cmd:id(}{varname}{cmd:)}
{cmd:start(}{varname}{cmd:)}
{cmd:exposure(}{varname}{cmd:)}
[{cmd:reference(}{it:#}{cmd:)}]
{cmd:entry(}{varname}{cmd:)}
{cmd:exit(}{varname}{cmd:)}
[{it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier linking to master dataset{p_end}
{synopt:{opt start(varname)}}start date of exposure period in using dataset{p_end}
{synopt:{opt exposure(varname)}}categorical exposure or dose variable{p_end}
{synopt:{opt reference(#)}}unexposed/reference value{p_end}
{synopt:{opt entry(varname)}}study entry date from master dataset{p_end}
{synopt:{opt exit(varname)}}study exit date from master dataset{p_end}

{syntab:Core options}
{synopt:{opt stop(varname)}}exposure-period end date{p_end}
{synopt:{opt pointtime}}data are point-in-time (start only, no stop date){p_end}

{syntab:Exposure definition}
{synopt:[none specified]}basic time-varying implementation of exposures{p_end}
{synopt:{opt ever:treated}}binary ever/never exposure{p_end}
{synopt:{opt cur:rentformer}}never/current/former exposure{p_end}
{synopt:{opt duration(numlist)}}cumulative-duration categories{p_end}
{synopt:{opt continuousunit(unit)}}cumulative-exposure unit{p_end}
{synopt:{opt expandunit(unit)}}continuous-exposure row granularity{p_end}
{synopt:{opt bytype}}create separate variables for each exposure type{p_end}
{synopt:{opt recency(numlist)}}time since last exposure categories{p_end}
{synopt:{opt recencyunit(unit)}}unit for {cmd:recency()}: days or years{p_end}
{synopt:{opt dose}}track cumulative dose{p_end}
{synopt:{opt dosecuts(numlist)}}cutpoints for dose categorization (use with {cmd:dose}){p_end}

{syntab:Data handling}
{synopt:{opt grace(#)}}days grace period to merge gaps (default: 0){p_end}
{synopt:{opt grace(exp=# exp=# ...)}}different grace periods by exposure category{p_end}
{synopt:{opt merge(#)}}merge nearby same-type periods{p_end}
{synopt:{opt fillgaps(#)}}assume exposure continues # days beyond last record{p_end}
{synopt:{opt carryforward(#)}}carry forward last exposure # days through gaps{p_end}
{synopt:{opt dropinvalid}}drop malformed rows and report exact counts{p_end}

{syntab:Competing exposures}
{synopt:{opt layer}}later exposures take precedence{p_end}
{synopt:{opt priority(numlist)}}priority order when periods overlap{p_end}
{synopt:{opt split}}split overlapping periods at all boundaries{p_end}
{synopt:{opt combine(newvar)}}create combined exposure variable for overlaps{p_end}

{syntab:Lag and washout}
{synopt:{opt lag(#)}}days lag before exposure becomes active{p_end}
{synopt:{opt washout(#)}}days exposure persists after stopping{p_end}
{synopt:{opt window(# #)}}minimum and maximum days for acute exposure window{p_end}

{syntab:Pattern tracking}
{synopt:{opt switching}}create binary indicator for any exposure switching{p_end}
{synopt:{opt switchingdetail}}create string variable showing switching pattern{p_end}
{synopt:{opt statetime}}create cumulative time in current exposure state{p_end}

{syntab:Output}
{synopt:{opt generate(newvar)}}output exposure variable name{p_end}
{synopt:{opt referencelabel(text)}}label for reference category (default: "Unexposed"){p_end}
{synopt:{opt label(text)}}custom variable label for output exposure variable{p_end}
{synopt:{opt saveas(filename)}}save time-varying dataset to file{p_end}
{synopt:{opt frameo:ut(name)}}place result in a frame; leave current data intact{p_end}
{synopt:{opt replace}}overwrite existing output file or frame{p_end}
{synopt:{opt keepvars(varlist)}}additional variables to keep from master dataset{p_end}
{synopt:{opt keepdates}}keep entry and exit dates in output{p_end}

{syntab:Diagnostics}
{synopt:{opt check}}display coverage diagnostics by person{p_end}
{synopt:{opt gaps}}show persons with gaps in coverage{p_end}
{synopt:{opt overlaps}}show overlapping exposure periods{p_end}
{synopt:{opt summarize}}display exposure distribution summary{p_end}
{synopt:{opt validate}}create validation dataset with coverage metrics{p_end}
{synopt:{opt flow}}report persons/records in vs out and return {cmd:r(flow)}{p_end}
{synopt:{opt verbose}}show diagnostic IDs and dates{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvexpose} creates time-varying exposure variables suitable for survival
analysis from a dataset containing exposure periods. The command merges
exposure data with a master cohort dataset, creating periods of time where
exposure status changes.

{pstd}
The typical workflow involves:

{phang2}1. A master dataset in memory containing person-level data with study entry
and exit dates

{phang2}2. An exposure dataset (specified via {cmd:using}) containing periods when exposures
occurred

{phang2}3. {cmd:tvexpose} merges these datasets and creates time-varying periods

{pstd}
The output is a long-format dataset with one row per person-time period, where
the exposure variable indicates exposure status during that period. This
format is compatible with {helpb stset} and {helpb stcox} for survival analysis.

{pstd}
Dates are closed, inclusive, whole-day intervals. For the shared date,
quantity, and survival-time contracts used by the package, see
{help tvtools##contracts:data contracts}.

{pstd}
{bf:Important}: {cmd:tvexpose} modifies the data in memory and changes the sort order
to id-start-stop. Always preserve your data or work with copies.


{marker required_options}{...}
{title:Required options}

{phang}
{cmd:using} {it:filename} specifies the dataset containing exposure periods. This
dataset must contain the variables specified in {cmd:id()}, {cmd:start()}, 
{cmd:exposure()}, and (unless {cmd:pointtime} is specified) {cmd:stop()}.

{phang}
{opt id(varname)} specifies the person identifier that links the exposure dataset
to the master dataset currently in memory. Must be present in both datasets. It
may be numeric or {cmd:str#}; {cmd:strL} identifiers are not allowed (recast to
{cmd:str#} first).

{phang}
{opt start(varname)} specifies the variable in the exposure dataset containing the
start date of each exposure period.

{phang}
{opt exposure(varname)} specifies the categorical exposure status variable in the
exposure dataset. This identifies what type of exposure occurred in each period.

{phang}
{opt reference(#)} specifies the value in the exposure variable that represents
the unexposed or reference state. This is typically 0. Required for all exposure
types except {cmd:dose}, where it defaults to 0 (the inherent reference).

{phang}
{opt entry(varname)} specifies the variable in the master dataset containing each
person's study entry date. Exposure periods are only counted from this date
forward.

{phang}
{opt exit(varname)} specifies the variable in the master dataset containing each
person's study exit date (e.g., end of follow-up, death, outcome
occurrence). Exposure periods are truncated at this date.


{marker exposure_options}{...}
{title:Exposure definition options}

{dlgtab:Core exposure definitions}

{phang}
{opt stop(varname)} specifies the variable in the exposure dataset containing the
end date of each exposure period. Required unless {cmd:pointtime} is specified.

{phang}
{opt pointtime} indicates that exposure data represent point-in-time events rather
than periods with duration. When specified, {cmd:stop()} is not required and
each record applies on its start date. With {cmd:carryforward(#)}, it persists
for exactly # inclusive days beginning on that date; the persistence is applied
once and is not applied again while gaps are constructed.

{phang}
{opt evertreated} creates a binary time-varying exposure that switches from 0 to 1
at the first exposure and remains 1 for all subsequent follow-up. Used for
immortal time bias correction in ever-treated analyses.

{phang}
{opt currentformer} creates a trichotomous time-varying exposure with values: 0 =
never exposed, 1 = currently exposed, 2 = formerly exposed. Returns to 1 if
re-exposed after a gap.

{phang}
{opt duration(numlist)} creates categorical time-varying exposure based on
cumulative duration. The numlist specifies category boundaries in the unit
defined by {cmd:continuousunit()} (defaults to years if not specified). For example,
{cmd:duration(1 5)} with default settings creates categories: 0=unexposed, 1=<1
year, 2=1 to <5 years, 3=≥5 years.

{phang}
{opt continuousunit(unit)} creates a continuous time-varying variable tracking
cumulative exposure in the specified unit. Options: days, weeks, months,
quarters, or years. Each row contains history accumulated before that row
starts, so it does not include exposure accrued during the current row. It can
be combined with {cmd:expandunit()} for period splitting.

{phang}
{opt expandunit(unit)} splits person-time into rows at regular calendar
intervals (days, weeks, months, quarters, or years). Used with
{cmd:continuousunit()} to create finely-grained time-varying data. If omitted,
it defaults to the unit named in {opt continuousunit()}; therefore requesting
continuous exposure can add regular boundary rows even when {opt expandunit()}
is not written explicitly. Specify a coarser or finer {opt expandunit()} to
control that row-count increase.

{phang}
{opt bytype} creates separate time-varying variables for each exposure type
instead of a single variable. Variable names append 1, 2, etc. for each
type. Useful when different exposure types have independent effects.

{phang}
{opt recency(numlist)} creates categories based on time since last exposure. {cmd:recencyunit(days|years)}
is required. Year cutpoints are converted once
with {cmd:round(365.25 * cutpoint)}; converted boundaries must be unique and
increasing whole days. For example, {cmd:recency(1 5) recencyunit(years)}
creates current exposure, <1 year since last, 1 to <5 years since last, and an
open-ended 5+ years category. Re-exposure resets recency for that exposure
type. With {cmd:bytype}, histories are tracked independently by type.

{phang}
{opt recencyunit(unit)} specifies whether {cmd:recency()} cutpoints are in
{cmd:days} or {cmd:years}. It may be specified only with {cmd:recency()}.

{phang}
{opt dose} enables cumulative dose tracking where the {cmd:exposure()} variable
contains the total dose for the source period rather than a categorical type. Dose
is apportioned across split segments at a constant daily rate. Each output
row contains cumulative dose known before that row starts; the current row's
dose is not included. The {cmd:reference()} option defaults to 0 for
{cmd:dose} mode and can be omitted. The {cmd:bytype} option is not supported
with dose.

{pmore}
{bf:Important:} The {cmd:dose} option is a modifier, not a container. The dose variable
is specified via {cmd:exposure()}, not {cmd:dose()}. Correct syntax
is: {cmd:exposure(myDoseVar) dose}, not {cmd:dose(myDoseVar)}.

{phang}
{opt dosecuts(numlist)} creates categorical dose output instead of continuous. The
numlist specifies ascending cutpoints for categorization. For example,
{cmd:dose dosecuts(5 10 20)} creates: 0=no dose, 1=<5, 2=5-<10, 3=10-<20,
4=20+. Requires the {cmd:dose} option.


{marker data_handling}{...}
{title:Data handling options}

{phang}
{opt grace(#)} specifies a grace period in days for merging small gaps between
episodes of the same exposure type. Same-type gaps of # or fewer days are
bridged. A gap between different exposure types is always reference
person-time, even when it is shorter than the grace period. Default is 0.

{phang}
{opt grace(exp=# exp=# ...)} specifies different grace periods for different
exposure categories. Format: {cmd:grace(1=30 2=60)} applies 30-day grace to
exposure type 1 and 60-day grace to type 2.

{phang}
{opt dropinvalid} removes malformed master or exposure rows instead of stopping
with error 498. Missing IDs, missing or non-whole daily dates, reversed bounds,
and missing exposure values are malformed. Exact reason-specific counts are
returned in {cmd:r()}, and {cmd:r(flow)} is returned automatically. Without
{cmd:dropinvalid}, malformed required input is rejected and the caller's data
remain unchanged.

{phang}
{opt merge(#)} merges consecutive periods of the same exposure type if they occur
within # days of each other. Default is 0 (no merging). Useful for treating
closely-spaced identical exposures as continuous.

{phang}
{opt fillgaps(#)} assumes exposure continues for # days beyond the last
recorded stop date. Useful when exposure records may be incomplete or delayed.

{phang}
{opt carryforward(#)} carries the most recent exposure forward through gaps
up to # days. Used when exposure is likely to persist beyond recorded periods.


{marker competing}{...}
{title:Competing exposures options}

{phang}
{opt layer} handles overlapping exposures by giving precedence to later exposures,
with earlier exposures resuming after the later one ends. This is the default
behavior. If records start on the same day, their order in the exposure dataset
breaks the tie: the later source record takes precedence.

{phang}
{opt priority(numlist)} specifies priority order when exposures overlap. The
numlist lists exposure values in priority order (highest first). For example,
{cmd:priority(2 1 0)} gives type 2 highest priority.

{phang}
{opt split} splits overlapping periods at all exposure boundaries, creating
separate rows for each combination. Used when overlapping exposures have
independent effects.

{phang}
{opt combine(newvar)} creates an additional variable containing a combined
exposure indicator when periods overlap. The new variable shows simultaneous
exposure to multiple types.


{marker lag_washout}{...}
{title:Lag and washout options}

{phang}
{opt lag(#)} specifies a lag period in days before exposure becomes active. Exposure
status changes # days after the start date rather than immediately. Used to
model delayed biological effects.

{phang}
{opt washout(#)} specifies that exposure effects persist for # days after the stop
date. Exposure status remains active until # days past the recorded end. Used
to model residual effects.

{phang}
{opt window(# #)} specifies minimum and maximum days for an acute exposure
window relative to each episode's original start. {cmd:window(a b)} keeps the
closed interval from start + a through start + b, clipped to the episode and
study bounds. It does not select episodes by their duration. The chosen offsets
are returned in {cmd:r(window_min)} and {cmd:r(window_max)}.


{marker pattern_tracking}{...}
{title:Pattern tracking options}

{phang}
{opt switching} creates a binary indicator variable ({cmd:has_switched}) that
equals 1 once a person has ever switched between exposure types, 0 otherwise.

{phang}
{opt switchingdetail} creates a string variable ({cmd:switching_pattern})
containing the complete sequence of exposure changes. For example, "0->1->2"
indicates starting unexposed, then type 1, then type 2.

{phang}
{opt statetime} creates a continuous variable tracking cumulative time (in days)
spent in the current exposure state. Resets to 0 when exposure changes.


{marker output}{...}
{title:Output options}

{phang}
{opt generate(newvar)} specifies the name for the output time-varying exposure
variable. When omitted, the name is derived from the {opt exposure()} varname
as {cmd:tv_}{it:exposure} (for example, {cmd:exposure(drug_class)} yields
{cmd:tv_drug_class}), so distinct exposures get distinct names and chain into
{help tvmerge} / {help tvevent} without manual renames. The name falls back to
a collision-safe generic name when the derived name would be illegal, exceed 32
characters, or collide with the {opt id()} or {opt combine()} variable. Always
read the chosen name from {cmd:r(genvar)} when scripting around this fallback.

{phang}
{opt referencelabel(text)} specifies the label for the reference category in
the output variable. Default is "Unexposed".

{phang}
{opt label(text)} specifies a custom variable label for the output exposure
variable. When specified, overrides the default behavior of using the original
exposure variable's label. For bytype variables, the label is applied with the
value label from the original exposure variable appended in parentheses to
distinguish each type (e.g., "(Estrogen only)"). For currentformer without
bytype, if not specified, the default label is "Never/current/former
exposure".

{phang}
{opt saveas(filename)} saves the time-varying dataset to the specified file. Include
.dta extension. Use with {cmd:replace} to overwrite existing files.

{phang}
{opt frameout(name)} places the time-varying result into a new frame named
{it:name} and leaves the data in the current frame unchanged. This enables a
disk-free pipeline ({cmd:tvexpose}{c -(} {cmd:tvmerge}{c -(} {cmd:tvevent}) in
which intermediate datasets are held in memory as frames rather than saved to
and reloaded from disk. The result is staged before the named frame is replaced; a
failed run leaves both the current data and any existing target unchanged. The frame
name is returned in {cmd:r(frameout)}. The target must differ from
the current frame. If it already exists, specify {cmd:replace}.

{phang}
{opt replace} allows {cmd:saveas()} to overwrite an existing file, or
{cmd:frameout()} to overwrite an existing frame.

{phang}
{opt keepvars(varlist)} specifies additional variables from the master dataset
to keep in the output. Baseline covariates like age, sex, etc.

{phang}
{opt keepdates} retains the study entry and exit date variables in the output
dataset. By default these are dropped to save space.


{marker diagnostic}{...}
{title:Diagnostic options}

{phang}
{opt check} displays diagnostic information about exposure coverage for each
person, including number of periods, total exposed time, and gaps.

{phang}
{opt gaps} identifies and lists persons with gaps in exposure coverage, showing
the location and duration of gaps.

{phang}
{opt overlaps} identifies and lists overlapping exposure periods, showing where
multiple exposures occur simultaneously.

{phang}
{opt summarize} displays summary statistics for the time-varying exposure
distribution, including frequencies of each category and person-time totals.

{phang}
{opt validate} creates a separate validation dataset ({cmd:tv_validation.dta}) containing
coverage metrics for each person, useful for quality control. {opt validate} is not
available together with {opt bytype} (the metrics require the single output exposure
variable); a note is displayed and no validation dataset is created.

{phang}
{opt flow} reports an attrition table of persons and records entering versus
leaving (persons can drop when the study window is invalid), returned in the
matrix {cmd:r(flow)} (rows {cmd:persons} and {cmd:records}; columns {cmd:in},
{cmd:out}, {cmd:dropped}). For records, {cmd:dropped} can be negative because
episodes expand into multiple intervals. It is a pure side channel and does not
change the output. The table is returned automatically with {cmd:dropinvalid}.

{phang}
{opt verbose} displays individual IDs and dates in diagnostic output from
{cmd:check}, {cmd:gaps}, {cmd:overlaps}, and warnings about invalid periods
or overlapping exposure categories. Without {cmd:verbose}, only summary
counts are shown and a hint to use {cmd:verbose} is displayed.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Typical analysis workflow}

{phang2}
1. Load master cohort dataset (with entry and exit dates)

{phang2}
2. Run {cmd:tvexpose} to create time-varying exposure data

{phang2}
3. Use {helpb stset} to declare survival-time data

{phang2}
4. Analyze with {helpb stcox}, {helpb streg}, or other survival commands

{pstd}
{bf:Choice of exposure definition}

{pstd}
Select the exposure definition option that matches your research question:

{phang2}
{cmd:[No option specified]}: For basic time-varying implementation of exposures

{phang2}
{cmd:evertreated}: For intent-to-treat analyses or immortal time bias correction

{phang2}
{cmd:currentformer}: For distinguishing active vs past exposure effects

{phang2}
{cmd:duration()}: For dose-response by cumulative duration

{phang2}
{cmd:continuousunit()}: For continuous dose-response models

{phang2}
{cmd:recency()}: For time-since-exposure effects

{pstd}
{bf:Grace periods and gap handling}

{pstd}
The {cmd:grace()}, {cmd:merge()}, and {cmd:fillgaps()} options address
common data quality issues. Use {cmd:grace()} when small gaps between
prescriptions should be considered continuous exposure. Use {cmd:merge()}
to consolidate multiple short periods of the same treatment. Use
{cmd:fillgaps()} when exposure likely extends beyond recorded dates.

{pstd}
{bf:Performance with large datasets}

{pstd}
For very large cohorts or complex exposure patterns, {cmd:tvexpose} may
take several minutes. The {cmd:expandunit()} option can dramatically
increase output size when splitting into fine time units. Consider using
coarser units (months instead of days) when fine granularity is not needed.


{marker examples}{...}
{title:Examples}

{pstd}
The following setup uses inline data and temporary files, so it is runnable
after installation from any working directory:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(entry_s exit_s) byte female}{p_end}
{phang3}{cmd:1 "01jan2020" "31dec2020" 1}{p_end}
{phang3}{cmd:2 "01jan2020" "31dec2020" 0}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double study_entry = date(entry_s, "DMY")}{p_end}
{phang2}{cmd:. generate double study_exit = date(exit_s, "DMY")}{p_end}
{phang2}{cmd:. format study_entry study_exit %td}{p_end}
{phang2}{cmd:. drop entry_s exit_s}{p_end}
{phang2}{cmd:. tempfile cohort episodes output}{p_end}
{phang2}{cmd:. save `cohort'}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(start_s stop_s) byte drug_class double daily_dose}{p_end}
{phang3}{cmd:1 "05jan2020" "20feb2020" 1 10}{p_end}
{phang3}{cmd:1 "01mar2020" "15apr2020" 2 20}{p_end}
{phang3}{cmd:2 "10jun2020" "31jul2020" 1 10}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double rx_start = date(start_s, "DMY")}{p_end}
{phang2}{cmd:. generate double rx_stop = date(stop_s, "DMY")}{p_end}
{phang2}{cmd:. format rx_start rx_stop %td}{p_end}
{phang2}{cmd:. drop start_s stop_s}{p_end}
{phang2}{cmd:. save `episodes'}{p_end}

{pstd}{bf:Categorical exposure with an explicit output contract}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:generate(tv_drug) keepvars(female) check}{p_end}

{pstd}{bf:Continuous cumulative exposure and expansion}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:continuousunit(months) generate(cum_months)}{p_end}

{pstd}
Because {opt expandunit()} is omitted, it defaults to months here and adds
monthly boundary rows. To report years on a monthly grid, specify
{cmd:continuousunit(years) expandunit(months)}.

{pstd}{bf:Duration and recency categories}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:duration(30 90) continuousunit(days) generate(duration_group)}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:recency(30 90) recencyunit(days) generate(recency_group)}{p_end}

{pstd}{bf:Cumulative dose}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(daily_dose) entry(study_entry) exit(study_exit) dose ///}{p_end}
{phang3}{cmd:dosecuts(300 900) generate(cum_dose)}{p_end}

{pstd}{bf:Temporary-file and frame outputs}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:generate(tv_drug) saveas(`output') replace flow}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. capture frame drop f_drug}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:generate(tv_drug) frameout(f_drug) flow}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvexpose} stores the following in {cmd:r()}:

{synoptset 28 tabbed}{...}
{p2col 5 28 32 2: Scalars}{p_end}
{synopt:{cmd:r(N_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(N_periods)}}number of time-varying periods{p_end}
{synopt:{cmd:r(total_time)}}total person-time in days{p_end}
{synopt:{cmd:r(exposed_time)}}exposed person-time in days{p_end}
{synopt:{cmd:r(unexposed_time)}}unexposed person-time in days{p_end}
{synopt:{cmd:r(pct_exposed)}}percentage of time exposed{p_end}
{synopt:{cmd:r(n_invalid_master)}}malformed master rows{p_end}
{synopt:{cmd:r(n_invalid_master_id)}}master rows with missing IDs{p_end}
{synopt:{cmd:r(n_invalid_master_dates)}}master rows with invalid daily dates{p_end}
{synopt:{cmd:r(n_invalid_master_order)}}master rows with entry after exit{p_end}
{synopt:{cmd:r(n_invalid_exposure)}}malformed exposure rows{p_end}
{synopt:{cmd:r(n_invalid_exposure_id)}}exposure rows with missing IDs{p_end}
{synopt:{cmd:r(n_invalid_exposure_dates)}}exposure rows with invalid daily dates{p_end}
{synopt:{cmd:r(n_invalid_exposure_order)}}exposure rows with reversed bounds{p_end}
{synopt:{cmd:r(n_invalid_exposure_value)}}exposure rows with missing values{p_end}
{synopt:{cmd:r(n_unmatched_exposure)}}exposure rows unmatched to the master{p_end}
{synopt:{cmd:r(n_outside_window)}}episodes outside study follow-up{p_end}
{synopt:{cmd:r(n_lag_removed)}}episodes made empty by {cmd:lag()}{p_end}
{synopt:{cmd:r(n_uncovered_days)}}uncovered study days; zero on success{p_end}
{synopt:{cmd:r(n_unresolved_overlaps)}}conflicting rows; zero on success{p_end}
{synopt:{cmd:r(window_min)}}minimum {cmd:window()} offset, if used{p_end}
{synopt:{cmd:r(window_max)}}maximum {cmd:window()} offset, if used{p_end}

{p2col 5 28 32 2: Macros}{p_end}
{synopt:{cmd:r(genvar)}}generated exposure variable or stub{p_end}
{synopt:{cmd:r(frameout)}}name of the output frame (if {opt frameout()} used){p_end}
{synopt:{cmd:r(overlap_ids)}}IDs with initially detected class conflicts{p_end}
{synopt:{cmd:r(recency_unit)}}normalized recency unit, if used{p_end}
{synopt:{cmd:r(recency_cutdays)}}recency cutpoints converted to days{p_end}

{p2col 5 28 32 2: Matrices}{p_end}
{synopt:{cmd:r(flow)}}persons/records attrition table{p_end}

{pstd}
{cmd:r(total_time)} is the union of each person's closed study window and does
not double-count simultaneous rows produced by {cmd:split}. The exposed and
unexposed returns are likewise union person-time. For {cmd:continuousunit()}
and {cmd:dose}, exposed time means time currently covered by a nonreference
source episode, not later unexposed time carrying a positive cumulative history.{p_end}

{pstd}
{cmd:r(overlap_ids)} is stored only when class conflicts are initially detected
and no overlap-handling option was specified. The default layer policy still
resolves those conflicts; a successful nonsplit result therefore returns
{cmd:r(n_unresolved_overlaps)} equal to zero.{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Manual: {manlink ST stset}, {manlink ST stsplit}, {manlink ST stcox}

{psee}
Online: {helpb tvmerge}, {helpb stset}, {helpb stsplit}, {helpb stcox}, {helpb sts}

{hline}
