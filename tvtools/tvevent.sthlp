{smcl}
{* *! version 1.4.1  2025/12/26}{...}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{viewerjumpto "Syntax" "tvevent##syntax"}{...}
{viewerjumpto "Description" "tvevent##description"}{...}
{viewerjumpto "Options" "tvevent##options"}{...}
{viewerjumpto "Examples" "tvevent##examples"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:tvevent} {hline 2}}Integrate events and competing risks into time-varying datasets{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvevent}
{cmd:using} {it:filename},
{cmd:id(}{varname}{cmd:)}
{cmd:date(}{it:name}{cmd:)}
[{it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier matching the master dataset{p_end}
{synopt:{opt date(name)}}variable name or stubname for event date(s); for {cmd:type(recurring)}, specifies the stub for {it:stub}1, {it:stub}2, etc.{p_end}

{syntab:Competing Risks}
{synopt:{opt com:pete(varlist)}}list of date variables in using file representing competing risks{p_end}

{syntab:Event definition}
{synopt:{opt type(string)}}event type: {bf:single} (default) or {bf:recurring}{p_end}
{synopt:{opt gen:erate(newvar)}}name for event indicator variable (default: _failure){p_end}
{synopt:{opt con:tinuous(varlist)}}cumulative exposure variables to adjust proportionally when splitting intervals{p_end}
{synopt:{opt eventl:abel(string)}}custom value labels for the generated event variable{p_end}

{syntab:Time generation}
{synopt:{opt timeg:en(newvar)}}create a variable representing the duration of each interval{p_end}
{synopt:{opt timeu:nit(string)}}unit for timegen: {bf:days} (default), {bf:months}, or {bf:years}{p_end}

{syntab:Data handling}
{synopt:{opt keep:vars(varlist)}}additional variables to keep from event dataset{p_end}
{synopt:{opt replace}}replace output variables if they already exist{p_end}
{synopt:{opt start:var(varname)}}name of start date variable in using file (default: start){p_end}
{synopt:{opt stop:var(varname)}}name of stop date variable in using file (default: stop){p_end}

{syntab:Diagnostics}
{synopt:{opt val:idate}}display validation diagnostics for event data quality{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvevent} is the third step in the {bf:tvtools} workflow. It processes time-varying datasets (created by {helpb tvexpose} and {helpb tvmerge}) to integrate outcomes and competing risks.

{pstd}
{bf:Data structure:}
{break}{cmd:Master (in memory):} Event data containing {cmd:id()}, {cmd:date()}, and optionally {cmd:compete()} variables.
{break}{cmd:Using file:} Interval data from {helpb tvexpose} or {helpb tvmerge} containing id, start, and stop variables.

{pstd}
The using file must contain variables for interval boundaries. By default, these are named {cmd:start} and {cmd:stop}
(as created by {helpb tvexpose} and {helpb tvmerge}). Use {cmd:startvar()} and {cmd:stopvar()} to specify different names.

{pstd}
By default, {cmd:tvevent} keeps all variables from the master dataset (the event data in memory before
{cmd:tvevent} is run). Variables are merged back based on id and event date.

{pstd}
It performs the following key tasks:

{phang2}1. {bf:Resolves Event Dates:} Compares the primary {cmd:date()} and any variables in {cmd:compete()}. The earliest occurring date becomes the effective event date for that person.

{phang2}2. {bf:Splitting:} If the event occurs in the middle of an existing exposure interval (start < event < stop), the interval is automatically split into two parts: pre-event and post-event.

{phang2}3. {bf:Continuous Adjustment:} If {cmd:continuous()} is specified, cumulative variables (like total dose) are proportionally reduced for split rows based on the new interval duration.

{phang2}4. {bf:Flagging:} Creates a status variable (default {cmd:_failure}) coded as:
{p_end}
{phang2}* 0 = Censored (No event){p_end}
{phang2}* 1 = Primary Event (from {cmd:date()}){p_end}
{phang2}* 2+ = Competing Events (corresponding to the order in {cmd:compete()}){p_end}

{pstd}
If {cmd:type(single)} is used (default), all data after the first occurring event is dropped, making the data ready for standard survival analysis ({cmd:stset}, {cmd:stcrreg}).


{marker options}{...}
{title:Options}

{phang}
{opt compete(varlist)} specifies date variables in the using dataset that represent competing risks. If a competing date is earlier than the primary date, the status is set to 2 (for the first variable in the list), 3 (for the second), etc.

{phang}
{opt continuous(varlist)} specifies variables representing cumulative exposure amounts (e.g., total mg of drug, total days exposed) calculated for the *original* interval. When an interval is split, the values of these variables are multiplied by the ratio of (new duration / old duration), preserving the correct rate and total sum.

{phang}
{opt eventlabel(string)} specifies custom value labels for the outcome variable categories. 
{break}Use standard Stata syntax: {it:value "Label" value "Label"}.
{break}Example: {cmd:eventlabel(0 "Alive" 1 "Heart Failure" 2 "Death")}
{break}If not specified, labels default to "Censored" (0) and the variable labels of the date variables from the using dataset.

{phang}
{opt timegen(newvar)} creates a new variable containing the duration of each interval. This is useful for Poisson regression offsets or descriptive statistics.

{phang}
{opt timeunit(string)} specifies the unit for {cmd:timegen()}. Options are {bf:days} (default), {bf:months} (days/30.4375), or {bf:years} (days/365.25).

{phang}
{opt type(string)} specifies the event logic.
{break}{bf:single} (default): Treats the first event as terminal. Drops all follow-up time after the first event.
{break}{bf:recurring}: Allows multiple events per person. Splits intervals as needed but retains all follow-up time.
{break}
{break}{bf:Important:} For {cmd:type(recurring)}, event dates must be in {bf:wide format} with the variable name
specified in {cmd:date()} serving as a stubname. For example, if you specify {cmd:date(hosp)}, the command
expects variables {cmd:hosp1}, {cmd:hosp2}, {cmd:hosp3}, etc. in the event dataset. This avoids many-to-many
merge issues when your interval data already has multiple rows per person. The {cmd:compete()} option is
not supported with recurring events.

{phang}
{opt generate(newvar)} names the new outcome variable. Default is {cmd:_failure}.

{phang}
{opt keepvars(varlist)} specifies additional variables to keep from the event dataset (e.g., diagnosis codes). These will be populated only on the rows where the event occurred. Note that all variables from the master dataset (in memory before {cmd:tvevent}) are kept by default.

{phang}
{opt startvar(varname)} specifies the name of the start date variable in the using (interval) dataset. Default is {cmd:start}.

{phang}
{opt stopvar(varname)} specifies the name of the stop date variable in the using (interval) dataset. Default is {cmd:stop}.

{phang}
{opt validate} displays validation diagnostics before processing. This option checks for:
{break}1. {bf:Events outside interval boundaries}: Events that occur before the earliest start or after the latest stop for each person (these will not be flagged in output).
{break}2. {bf:Multiple events per person}: When using {cmd:type(single)}, persons with multiple non-missing event dates.
{break}3. {bf:Competing events on same date}: When {cmd:compete()} is specified, cases where the primary event and a competing event occur on the same date.
{break}
{break}Validation results are also stored in {cmd:r(v_outside_bounds)}, {cmd:r(v_multiple_events)}, and {cmd:r(v_same_date_compete)}.

{pmore}
{bf:Note on interval boundaries:} The command uses open intervals (start, stop] for event detection.
An event is flagged when it matches the stop date of an interval (the event ends that interval).
Interval splitting only occurs when an event falls strictly inside: start < event < stop.
Events exactly on the start date are not flagged (risk begins at start, not before).


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
The standard workflow is: (1) create time-varying datasets using {cmd:tvexpose},
(2) optionally merge using {cmd:tvmerge}, then (3) integrate events using {cmd:tvevent}.


{pstd}
{bf:Example 1: Primary outcome with Competing Risk (Death)}

{pstd}
Study EDSS progression (disability worsening) with death as a competing risk. First create
time-varying data, then integrate events:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit)}{p_end}

{phang2}{cmd:. tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) generate(outcome)}{p_end}

{phang2}{cmd:. stset stop, id(id) failure(outcome==1) enter(start)}{p_end}

{phang2}{cmd:. stcrreg i.tv_exposure, compete(outcome==2)}{p_end}

{pstd}
The outcome variable is coded: 0=Censored, 1=EDSS progression, 2=Death.


{pstd}
{bf:Example 2: Custom Event Labels}

{pstd}
Explicitly label censored, primary, and competing events for clearer output:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit)}{p_end}

{phang2}{cmd:. tvevent using cohort, id(id) date(edss4_dt) ///}{p_end}
{phang3}{cmd:compete(death_dt emigration_dt) ///}{p_end}
{phang3}{cmd:eventlabel(0 "Censored" 1 "EDSS Progression" 2 "Death" 3 "Emigration") ///}{p_end}
{phang3}{cmd:generate(status)}{p_end}

{pstd}
The eventlabel() option overrides default labels derived from variable labels in the event dataset.


{pstd}
{bf:Example 3: Continuous Dose Adjustment}

{pstd}
When intervals contain cumulative exposure amounts (e.g., total mg of drug), these should be
proportionally reduced if an event splits the interval:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:continuousunit(years)}{p_end}

{phang2}{cmd:. tvevent using cohort, id(id) date(death_dt) type(single) continuous(tv_exposure)}{p_end}

{pstd}
If death occurs mid-interval, the continuous variable is adjusted by the ratio
(new duration / original duration).


{pstd}
{bf:Example 4: Recurring Events (Wide Format)}

{pstd}
For events that can occur multiple times (e.g., hospitalizations), use {cmd:type(recurring)}.
The event dataset must have dates in {bf:wide format} with numbered suffixes (hosp1, hosp2, etc.):

{phang2}{cmd:. * Event dataset structure (one row per person, multiple date columns):}{p_end}
{phang2}{cmd:. * id  hosp1       hosp2       hosp3}{p_end}
{phang2}{cmd:. * 1   2020-01-15  2020-06-20  .}{p_end}
{phang2}{cmd:. * 2   2020-04-01  .           .}{p_end}

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(tv_intervals.dta) replace}{p_end}

{phang2}{cmd:. * Load event data with wide-format recurring events}{p_end}
{phang2}{cmd:. use hospitalizations, clear}{p_end}

{phang2}{cmd:. * date(hosp) finds hosp1, hosp2, hosp3, etc.}{p_end}
{phang2}{cmd:. tvevent using tv_intervals, id(id) date(hosp) ///}{p_end}
{phang3}{cmd:type(recurring) generate(hospitalized)}{p_end}

{pstd}
The command automatically detects hosp1, hosp2, hosp3, etc. and processes all events.
Unlike {cmd:type(single)}, recurring events do not truncate follow-up after the first event.
Note that {cmd:compete()} is not supported with recurring events.


{pstd}
{bf:Example 5: Generate Time Duration Variable}

{pstd}
Create a variable for interval duration, useful for Poisson regression offsets:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit)}{p_end}

{phang2}{cmd:. tvevent using cohort, id(id) date(edss4_dt) ///}{p_end}
{phang3}{cmd:timegen(interval_years) timeunit(years)}{p_end}

{pstd}
The timegen() option creates a variable showing the duration of each interval in the
specified unit (days, months, or years).


{pstd}
{bf:Example 6: Complete Workflow with Merged Exposures}

{pstd}
Full pipeline showing tvexpose, tvmerge, and tvevent integration:

{phang2}{cmd:. * Step 1: Create time-varying HRT dataset}{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(tv_hrt.dta) replace}{p_end}

{phang2}{cmd:. * Step 2: Create time-varying DMT dataset}{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(tv_dmt.dta) replace}{p_end}

{phang2}{cmd:. * Step 3: Merge the two time-varying datasets}{p_end}
{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type)}{p_end}

{phang2}{cmd:. * Step 4: Integrate event data}{p_end}
{phang2}{cmd:. tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) ///}{p_end}
{phang3}{cmd:generate(outcome) type(single)}{p_end}

{phang2}{cmd:. * Step 5: Set up for survival analysis}{p_end}
{phang2}{cmd:. stset stop, id(id) failure(outcome==1) enter(start)}{p_end}

{phang2}{cmd:. stcrreg i.hrt i.dmt_type, compete(outcome==2)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvevent} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}Total number of observations in output{p_end}
{synopt:{cmd:r(N_events)}}Total number of events/failures flagged{p_end}

{pstd}
When {cmd:validate} is specified, additional scalars are stored:

{synopt:{cmd:r(v_outside_bounds)}}Number of events outside interval boundaries{p_end}
{synopt:{cmd:r(v_multiple_events)}}Number of persons with multiple events (type(single) only){p_end}
{synopt:{cmd:r(v_same_date_compete)}}Number of competing events on same date as primary{p_end}


{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.4.0, 2025-12-18{p_end}

{title:Also see}

{psee}
Online:  {helpb tvexpose}, {helpb tvmerge}
{p_end}
