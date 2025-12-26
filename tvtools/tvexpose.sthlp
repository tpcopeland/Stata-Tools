{smcl}
{* *! version 1.4.0  2025/12/26}{...}
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
{synopt:{opt exposure(varname)}}exposure variable: categorical status OR dose amount (with {cmd:dose}){p_end}
{synopt:{opt reference(#)}}value indicating unexposed/reference status; required except with {cmd:dose}{p_end}
{synopt:{opt entry(varname)}}study entry date from master dataset{p_end}
{synopt:{opt exit(varname)}}study exit date from master dataset{p_end}

{syntab:Core options}
{synopt:{opt stop(varname)}}end date of exposure period; required unless {cmd:pointtime} specified{p_end}
{synopt:{opt pointtime}}data are point-in-time (start only, no stop date){p_end}

{syntab:Exposure definition}
{synopt:[none specified]}basic time-varying implementation of exposures{p_end}
{synopt:{opt evert:reated}}binary ever/never exposed (switches at first exposure){p_end}
{synopt:{opt current:former}}trichotomous never/current/former exposed (0=never, 1=current, 2=former){p_end}
{synopt:{opt duration(numlist)}}cumulative duration categories (uses continuousunit if specified, defaults to years){p_end}
{synopt:{opt continuousunit(unit)}}cumulative exposure reporting unit (days, weeks, months, quarters, years){p_end}
{synopt:{opt expandunit(unit)}}row expansion granularity for continuous exposure (days, weeks, months, quarters, years){p_end}
{synopt:{opt bytype}}create separate variables for each exposure type{p_end}
{synopt:{opt recency(numlist)}}time since last exposure categories{p_end}
{synopt:{opt dose}}cumulative dose tracking (exposure contains dose amounts){p_end}
{synopt:{opt dosecuts(numlist)}}cutpoints for dose categorization (use with {cmd:dose}){p_end}

{syntab:Data handling}
{synopt:{opt grace(#)}}days grace period to merge gaps (default: 0){p_end}
{synopt:{opt grace(exp=# exp=# ...)}}different grace periods by exposure category{p_end}
{synopt:{opt merge(#)}}days within which to merge same-type periods (default: 0){p_end}
{synopt:{opt fillgaps(#)}}assume exposure continues # days beyond last record{p_end}
{synopt:{opt carryforward(#)}}carry forward last exposure # days through gaps{p_end}

{syntab:Competing exposures}
{synopt:{opt layer}}later exposures take precedence; earlier resume after (default){p_end}
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
{synopt:{opt generate(newvar)}}name for output exposure variable (default: tv_exposure){p_end}
{synopt:{opt referencelabel(text)}}label for reference category (default: "Unexposed"){p_end}
{synopt:{opt label(text)}}custom variable label for output exposure variable{p_end}
{synopt:{opt saveas(filename)}}save time-varying dataset to file{p_end}
{synopt:{opt replace}}overwrite existing output file{p_end}
{synopt:{opt keepvars(varlist)}}additional variables to keep from master dataset{p_end}
{synopt:{opt keepdates}}keep entry and exit dates in output{p_end}

{syntab:Diagnostics}
{synopt:{opt check}}display coverage diagnostics by person{p_end}
{synopt:{opt gaps}}show persons with gaps in coverage{p_end}
{synopt:{opt overlaps}}show overlapping exposure periods{p_end}
{synopt:{opt summarize}}display exposure distribution summary{p_end}
{synopt:{opt validate}}create validation dataset with coverage metrics{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvexpose} creates time-varying exposure variables suitable for survival analysis
from a dataset containing exposure periods. The command merges exposure data with a
master cohort dataset, creating periods of time where exposure status changes.

{pstd}
The typical workflow involves:

{phang2}1. A master dataset in memory containing person-level data with study entry and exit dates

{phang2}2. An exposure dataset (specified via {cmd:using}) containing periods when exposures occurred

{phang2}3. {cmd:tvexpose} merges these datasets and creates time-varying periods

{pstd}
The output is a long-format dataset with one row per person-time period, where the
exposure variable indicates exposure status during that period. This format is
compatible with {helpb stset} and {helpb stcox} for survival analysis.

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
to the master dataset currently in memory. Must be present in both datasets.

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
person's study entry date. Exposure periods are only counted from this date forward.

{phang}
{opt exit(varname)} specifies the variable in the master dataset containing each
person's study exit date (e.g., end of follow-up, death, outcome occurrence).
Exposure periods are truncated at this date.


{marker exposure_options}{...}
{title:Exposure definition options}

{dlgtab:Core exposure definitions}

{phang}
{opt stop(varname)} specifies the variable in the exposure dataset containing the
end date of each exposure period. Required unless {cmd:pointtime} is specified.

{phang}
{opt pointtime} indicates that exposure data represent point-in-time events rather
than periods with duration. When specified, {cmd:stop()} is not required.

{phang}
{opt evertreated} creates a binary time-varying exposure that switches from 0 to 1
at the first exposure and remains 1 for all subsequent follow-up. Used for
immortal time bias correction in ever-treated analyses.

{phang}
{opt currentformer} creates a trichotomous time-varying exposure with values:
0 = never exposed, 1 = currently exposed, 2 = formerly exposed. Returns to 1
if re-exposed after a gap.

{phang}
{opt duration(numlist)} creates categorical time-varying exposure based on
cumulative duration. The numlist specifies category boundaries in the unit defined
by {cmd:continuousunit()} (defaults to years if not specified). For
example, {cmd:duration(1 5)} with default settings creates categories: 0=unexposed, 1=<1 year,
2=1 to <5 years, 3=≥5 years.

{phang}
{opt continuousunit(unit)} creates a continuous time-varying variable tracking
cumulative exposure in the specified unit. Options: days, weeks, months,
quarters, or years. Can be combined with {cmd:expandunit()} for period splitting.

{phang}
{opt expandunit(unit)} splits person-time into rows at regular calendar
intervals (days, weeks, months, quarters, or years). Used with
{cmd:continuousunit()} to create finely-grained time-varying data.

{phang}
{opt bytype} creates separate time-varying variables for each exposure type
instead of a single variable. Variable names append 1, 2, etc. for each
type. Useful when different exposure types have independent effects.

{phang}
{opt recency(numlist)} creates categories based on time since last exposure.
The numlist specifies category boundaries in years. For example,
{cmd:recency(1 5)} creates: current exposure, <1 year since last,
1 to <5 years since last, ≥5 years since last.

{phang}
{opt dose} enables cumulative dose tracking where the {cmd:exposure()} variable
contains the dose amount per period (e.g., grams of medication) rather than
a categorical exposure type. When periods overlap, dose is allocated proportionally
based on daily dose rates. For example, if two 30-day prescriptions of 1 gram each
have a 10-day overlap, the overlap period receives ((10/30)*1) + ((10/30)*1) = 0.667 grams.
The {cmd:reference()} option defaults to 0 for {cmd:dose} mode (the inherent reference
category) and can be omitted. The {cmd:bytype} option is not supported with dose.

{pmore}
{bf:Important:} The {cmd:dose} option is a modifier, not a container. The dose variable
is specified via {cmd:exposure()}, not {cmd:dose()}. Correct syntax is:
{cmd:exposure(myDoseVar) dose}, not {cmd:dose(myDoseVar)}.

{phang}
{opt dosecuts(numlist)} creates categorical dose output instead of continuous.
The numlist specifies ascending cutpoints for categorization. For example,
{cmd:dose dosecuts(5 10 20)} creates: 0=no dose, 1=<5, 2=5-<10, 3=10-<20, 4=20+.
Requires the {cmd:dose} option.


{marker data_handling}{...}
{title:Data handling options}

{phang}
{opt grace(#)} specifies a grace period in days for merging small gaps between
exposure periods. Gaps of # or fewer days are filled. Default is 0 (no merging).

{phang}
{opt grace(exp=# exp=# ...)} specifies different grace periods for different
exposure categories. Format: {cmd:grace(1=30 2=60)} applies 30-day grace to
exposure type 1 and 60-day grace to type 2.

{phang}
{opt merge(#)} merges consecutive periods of the same exposure type if they
occur within # days of each other. Default is 0 (no merging). Useful for treating
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
{opt layer} handles overlapping exposures by giving precedence to
later exposures, with earlier exposures resuming after the later one ends.
This is the default behavior.

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
{opt lag(#)} specifies a lag period in days before exposure becomes active.
Exposure status changes # days after the start date rather than immediately.
Used to model delayed biological effects.

{phang}
{opt washout(#)} specifies that exposure effects persist for # days after the
stop date. Exposure status remains active until # days past the recorded end.
Used to model residual effects.

{phang}
{opt window(# #)} specifies minimum and maximum days for an acute exposure
window. Only exposure periods lasting between the specified minimum and maximum
are counted. Used for analyzing acute effects of brief exposures.


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
variable. Default is {cmd:tv_exposure}.

{phang}
{opt referencelabel(text)} specifies the label for the reference category in
the output variable. Default is "Unexposed".

{phang}
{opt label(text)} specifies a custom variable label for the output exposure
variable. When specified, overrides the default behavior of using the original
exposure variable's label. For bytype variables, the label is applied with
the value label from the original exposure variable appended in parentheses
to distinguish each type (e.g., "(Estrogen only)"). For currentformer without bytype,
if not specified, the default label is "Never/current/former exposure".

{phang}
{opt saveas(filename)} saves the time-varying dataset to the specified file.
Include .dta extension. Use with {cmd:replace} to overwrite existing files.

{phang}
{opt replace} allows {cmd:saveas()} to overwrite an existing file.

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
{opt validate} creates a separate validation dataset ({cmd:tv_validation.dta})
containing coverage metrics for each person, useful for quality control.


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
The examples below use synthetic datasets generated by {bf:generate_test_data.do}:

{phang2}
{bf:cohort.dta}: 1,000 persons with study entry/exit dates, demographics, and outcomes

{phang2}
{bf:hrt.dta}: Hormone replacement therapy periods (rx_start, rx_stop, hrt_type, dose)

{phang2}
{bf:dmt.dta}: Disease-modifying therapy periods (dmt_start, dmt_stop, dmt)


{pstd}
{bf:Example 1: Basic time-varying exposure}

{pstd}
Create categorical time-varying HRT exposure for survival analysis:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit)}{p_end}

{pstd}
This creates tv_exposure showing HRT type (0=unexposed, 1-3=HRT types) during each time period. The output has one row per person-time period.


{pstd}
{bf:Example 2: Ever-treated analysis}

{pstd}
Create binary indicator that switches permanently at first HRT exposure:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:evertreated generate(ever_hrt)}{p_end}

{pstd}
Variable ever_hrt = 0 before first exposure, = 1 from first exposure onward. Useful for correcting immortal time bias in ever-vs-never analyses.


{pstd}
{bf:Example 3: Current vs former exposure}

{pstd}
Distinguish between current and former DMT exposure:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:currentformer generate(dmt_status)}{p_end}

{pstd}
Variable dmt_status: 0=never exposed, 1=currently on DMT, 2=formerly on DMT. Returns to 1 if person restarts DMT after a gap.


{pstd}
{bf:Example 4: Duration categories}

{pstd}
Create exposure categories based on cumulative years of HRT use:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:duration(1 5 10) continuousunit(years)}{p_end}

{pstd}
Creates categories: 0=unexposed, 1=<1 year cumulative, 2=1 to <5 years, 3=5 to <10 years, 4=≥10 years. Useful for testing dose-response by duration.


{pstd}
{bf:Example 5: Continuous cumulative exposure}

{pstd}
Track cumulative months of DMT exposure as a continuous variable:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:continuousunit(months) generate(cumul_dmt_months)}{p_end}

{pstd}
Variable cumul_dmt_months shows cumulative months of DMT exposure at each time point. Use in regression models as a continuous predictor.


{pstd}
{bf:Example 6: Continuous exposure with row expansion}

{pstd}
Split person-time into calendar months with cumulative exposure in years:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:continuousunit(years) expandunit(months)}{p_end}

{pstd}
Creates one row per calendar month. Useful when you need to merge with other time-varying covariates measured monthly or for time-stratified analyses.


{pstd}
{bf:Example 7: Separate variables by type}

{pstd}
Create separate time-varying variables for each DMT type:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:continuousunit(years) bytype}{p_end}

{pstd}
Creates tv_exp1 through tv_exp6 showing cumulative years on each specific DMT type. Allows estimation of type-specific effects in a single model.


{pstd}
{bf:Example 8: Recency of exposure}

{pstd}
Categorize time since last HRT exposure:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:recency(1 5)}{p_end}

{pstd}
Creates categories: current exposure, <1 year since last, 1 to <5 years since last, ≥5 years since last. Useful for studying how quickly effects dissipate.


{pstd}
{bf:Example 9: Grace period for gaps}

{pstd}
Treat gaps ≤30 days as continuous HRT exposure:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:grace(30) currentformer}{p_end}

{pstd}
Gaps of 30 days or less are filled, treating brief interruptions as continuous exposure. Useful when short gaps represent prescription refill delays rather than true cessation.


{pstd}
{bf:Example 10: Type-specific grace periods}

{pstd}
Apply different grace periods to different HRT types:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:grace(1=30 2=60 3=90)}{p_end}

{pstd}
Type 1 gets 30-day grace, type 2 gets 60 days, type 3 gets 90 days. Useful when different treatments have different refill patterns.


{pstd}
{bf:Example 11: Lag and washout periods}

{pstd}
Model 30-day lag before DMT becomes active and 90-day washout after stopping:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:lag(30) washout(90)}{p_end}

{pstd}
Exposure begins 30 days after start date and continues 90 days after stop date. Models biological delay in onset and persistence of effects.


{pstd}
{bf:Example 12: Priority-based overlap resolution}

{pstd}
When DMT periods overlap, give priority to higher-efficacy treatments:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:priority(6 5 4 3 2 1)}{p_end}

{pstd}
DMT type 6 (highest efficacy) takes precedence over type 5, etc. Useful when overlapping periods represent treatment transitions.


{pstd}
{bf:Example 13: Track exposure switching}

{pstd}
Identify persons who switch between DMT types:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:switching switchingdetail}{p_end}

{pstd}
Creates has_switched (0/1 indicator) and switching_pattern (string showing sequence like "0->1->3->5"). Use to identify switchers vs stable users.


{pstd}
{bf:Example 14: Keep baseline covariates}

{pstd}
Bring demographic and clinical variables into the time-varying dataset:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(age female mstype edss_baseline region)}{p_end}

{pstd}
Baseline covariates are included in every row of the output. Ready for regression analysis without additional merging.


{pstd}
{bf:Example 15: Comprehensive diagnostics}

{pstd}
Run all diagnostic checks to verify data quality:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:check gaps overlaps summarize validate}{p_end}

{pstd}
Displays coverage diagnostics, identifies gaps and overlaps, summarizes exposure distribution, and creates validation dataset. Use before proceeding to analysis.


{pstd}
{bf:Example 16: Save output for later analysis}

{pstd}
Create time-varying dataset and save for repeated analyses:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:currentformer ///}{p_end}
{phang3}{cmd:keepvars(age female mstype edss_baseline) ///}{p_end}
{phang3}{cmd:saveas(tv_dmt_analysis.dta) replace}{p_end}

{pstd}
Output saved to tv_dmt_analysis.dta. Subsequently load this file for different analyses without re-running tvexpose.


{pstd}
{bf:Example 17: Complete workflow for survival analysis}

{pstd}
Full analysis pipeline from time-varying exposure to Cox regression:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:currentformer generate(dmt_status) ///}{p_end}
{phang3}{cmd:keepvars(age female mstype edss_baseline edss4_dt)}{p_end}

{phang2}{cmd:. gen failure = (!missing(edss4_dt) & edss4_dt <= rx_stop)}{p_end}

{phang2}{cmd:. stset rx_stop, failure(failure) entry(rx_start) id(id) scale(365.25)}{p_end}

{phang2}{cmd:. stcox i.dmt_status age i.female i.mstype edss_baseline}{p_end}

{pstd}
This creates time-varying DMT exposure, defines failure event, declares survival-time data, and estimates hazard ratios using Cox regression.


{pstd}
{bf:Example 18: Stratified by calendar period}

{pstd}
Create separate exposure variables for different calendar periods:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. keep if study_entry >= mdy(1,1,2015)}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:continuousunit(years) keepdates}{p_end}

{phang2}{cmd:. gen calendar_year = year(rx_start)}{p_end}

{phang2}{cmd:. table calendar_year, statistic(mean tv_exposure) statistic(count tv_exposure)}{p_end}

{pstd}
Restricts analysis to persons entering after 2015 and examines exposure trends by calendar year. Useful for assessing temporal changes in treatment patterns.


{pstd}
{bf:Example 19: Cumulative dose tracking}

{pstd}
Track cumulative medication dose for dose-response analysis:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(dose) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:dose generate(cumul_dose)}{p_end}

{pstd}
Creates cumul_dose showing cumulative dose at each time point. When prescriptions overlap, dose is allocated proportionally based on daily dose rates.


{pstd}
{bf:Example 20: Categorical dose for dose-response}

{pstd}
Create categorical cumulative dose for dose-response analysis:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(dose) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:dose dosecuts(5 10 20) generate(dose_cat)}{p_end}

{pstd}
Creates dose_cat with categories: 0=no dose, 1=<5, 2=5-<10, 3=10-<20, 4=20+. Useful for Cox regression with categorized dose-response.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvexpose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(N_periods)}}number of time-varying periods{p_end}
{synopt:{cmd:r(total_time)}}total person-time in days{p_end}
{synopt:{cmd:r(exposed_time)}}exposed person-time in days{p_end}
{synopt:{cmd:r(unexposed_time)}}unexposed person-time in days{p_end}
{synopt:{cmd:r(pct_exposed)}}percentage of time exposed{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2025-12-02{p_end}


{title:Also see}

{psee}
Manual:  {manlink ST stset}, {manlink ST stsplit}, {manlink ST stcox}

{psee}
Online:  {helpb tvmerge}, {helpb stset}, {helpb stsplit}, {helpb stcox}, {helpb sts}

{hline}
