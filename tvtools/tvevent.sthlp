{smcl}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "[ST] stcrreg" "help stcrreg"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{viewerjumpto "Syntax" "tvevent##syntax"}{...}
{viewerjumpto "Description" "tvevent##description"}{...}
{viewerjumpto "Options" "tvevent##options"}{...}
{viewerjumpto "Examples" "tvevent##examples"}{...}
{viewerjumpto "Stored results" "tvevent##results"}{...}
{viewerjumpto "Author" "tvevent##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:tvevent} {hline 2}}Integrate events and competing risks into time-varying datasets{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvevent}
[{cmd:using} {it:filename}],
{cmd:id(}{varname}{cmd:)}
{cmd:date(}{it:name}{cmd:)}
[{it:options}]

{pstd}
The interval data may be supplied as a {cmd:using} file {it:or} as a named frame
via {opt frame()}; supply one or the other.


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier in both datasets{p_end}
{synopt:{opt fr:ame(name)}}read interval data from a named frame{p_end}
{synopt:{opt date(name)}}event-date variable or recurring-event stub{p_end}

{syntab:Competing Risks}
{synopt:{opt com:pete(varlist)}}competing-event date variables{p_end}

{syntab:Event definition}
{synopt:{opt type(string)}}event type: {bf:single} (default) or {bf:recurring}{p_end}
{synopt:{opt gen:erate(newvar)}}event indicator; default {cmd:_failure}{p_end}
{synopt:{opt eventl:abel(string)}}custom value labels for the generated event variable{p_end}

{syntab:Interval quantities}
{synopt:{opt ra:te(varlist)}}rates; unchanged when intervals split{p_end}
{synopt:{opt tot:al(varlist)}}interval totals; apportioned by inclusive days{p_end}
{synopt:{opt cum:ulative(varlist)}}row-start cumulative histories; carried unchanged{p_end}
{synopt:{opt con:tinuous(varlist)}}deprecated alias for {cmd:total()}{p_end}

{syntab:Time generation}
{synopt:{opt timeg:en(newvar)}}time since the first interval start{p_end}
{synopt:{opt timeu:nit(string)}}unit for timegen: {bf:days} (default), {bf:months}, or {bf:years}{p_end}

{syntab:Recurrent-event formatting (PWP/AG; requires type(recurring))}
{synopt:{opt enum(name)}}event-sequence stratum (default: _enum){p_end}
{synopt:{opt gap:time}}add the gap-time clock that resets at each event{p_end}
{synopt:{opt gapstart(name)}}name for the gap-time start (default: _t0){p_end}
{synopt:{opt gapstop(name)}}name for the gap-time stop (default: _t){p_end}

{syntab:Data handling}
{synopt:{opt keep:vars(varlist)}}additional variables to keep from event dataset{p_end}
{synopt:{opt dropi:nvalid}}explicitly remove malformed required rows{p_end}
{synopt:{opt replace}}replace output variables if they already exist{p_end}
{synopt:{opt start(varname)}}interval-start variable; default {cmd:start}{p_end}
{synopt:{opt stop(varname)}}interval-stop variable; default {cmd:stop}{p_end}

{syntab:Diagnostics}
{synopt:{opt val:idate}}display event-data validation diagnostics{p_end}
{synopt:{opt flow}}report persons/records in vs out and return {cmd:r(flow)}{p_end}
{synopt:{opt verbose}}list examples of malformed rows before stopping{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvevent} is the third step in the {bf:tvtools} workflow. It processes
time-varying datasets (created by {helpb tvexpose} and {helpb tvmerge}) to
integrate outcomes and competing risks.

{pstd}
{bf:Data structure:} {break}{cmd:Master (in memory):} Event data containing {cmd:id()}, {cmd:date()}, and
optionally {cmd:compete()} variables. {break}{cmd:Using file:} Interval data from {helpb tvexpose} or
{helpb tvmerge} containing id, start, and stop variables.

{pstd}
The using file must contain variables for interval boundaries. By default,
these are named {cmd:start} and {cmd:stop} (as created by {helpb tvexpose} and {helpb tvmerge}). Use
{cmd:startvar()} and {cmd:stopvar()} to specify different names.

{pstd}
By default, {cmd:tvevent} keeps non-event variables from the master dataset (the
event data in memory before {cmd:tvevent} is run). It reports the exact variables
preserved and any protected output/interval names excluded from automatic
selection. Preserved variables must be constant within person. An explicitly
requested {cmd:keepvars()} collision is an error.

{pstd}
It performs the following key tasks:

{phang2}1. {bf:Resolves Event Dates:} Compares the primary {cmd:date()} and any
variables in {cmd:compete()}. The earliest occurring date becomes the effective
event date for that person.

{phang2}2. {bf:Splitting:} When an event satisfies start <= event < stop, the
event day becomes the endpoint of the first output piece and follow-up after
that day begins in a second piece. An event on stop is flagged without a split.

{pstd}
The exact closed-interval boundary contract is:

{phang2}{cmd:event < start}: no match to that interval;{p_end}
{phang2}{cmd:event == start}: flag the event day; retain later days in a second
piece when {cmd:start < stop};{p_end}
{phang2}{cmd:start < event < stop}: split after and flag the event day;{p_end}
{phang2}{cmd:event == stop}: flag without splitting;{p_end}
{phang2}{cmd:event > stop}: no match to that interval.{p_end}

{phang2}3. {bf:Quantity handling:} Rates remain unchanged, interval totals are
apportioned by inclusive duration, and row-start cumulative histories are carried
unchanged when an event splits a row.

{phang2}4. {bf:Flagging:} Creates a status variable (default {cmd:_failure}) coded as: {p_end}
{phang2}* 0 = Censored (No event){p_end}
{phang2}* 1 = Primary Event (from {cmd:date()}){p_end}
{phang2}* 2+ = Competing Events (corresponding to the order in {cmd:compete()}){p_end}

{pstd}
If {cmd:type(single)} is used (default), all data after the first occurring
event is dropped, making the data ready for standard survival analysis
({cmd:stset}, {cmd:stcrreg}).


{marker options}{...}
{title:Options}

{phang}
{opt id(varname)} names the person identifier present in both the event data and the
interval data. Numeric and {cmd:str#} identifiers are accepted; {cmd:strL} is not.

{phang}
{opt date(name)} names the event-date variable for {cmd:type(single)} or the
wide recurring-event stub for {cmd:type(recurring)}.

{phang}
{opt frame(name)} reads the interval data from a named {help frame:frame} held
in memory instead of from a {cmd:using} file. Supply either {cmd:using} or
{opt frame()}, not both. This lets callers supply interval data already held in
a frame rather than naming a source file.

{phang}
{opt compete(namelist)} specifies date variables in the master (event) dataset
that represent competing risks. If a competing date is earlier than the primary
date, the status is set to 2 (for the first variable in the list), 3 (for the
second), etc.

{phang}
{opt rate(namelist)} specifies amounts per day. A rate remains unchanged when an
event splits an interval.

{phang}
{opt total(namelist)} specifies amounts attributable to one closed
source row. When an event splits the row, each total is multiplied by the ratio of inclusive
output days to inclusive source-row days, so retained pieces preserve the
source-row allocation.

{phang}
{opt cumulative(namelist)} specifies histories known at row start. Values are
carried unchanged when the row splits. Each cumulative variable must carry
{cmd:char varname[tvtools_history_point] "start"}.

{phang}
{opt continuous(namelist)} is a deprecated compatibility alias for
{opt total()}. It retains the released proportional-allocation behavior and
prints a migration warning. A variable may appear in only one algebra
list. Variables carrying {cmd:[tvtools_quantity]} metadata must be declared in the
matching option; unknown, omitted, or conflicting metadata is rejected; quantity
names also cannot collide with structural, event, elapsed-time, enum,
or gap-time output names, even when {opt replace} is specified.

{phang}
{opt eventlabel(string)} specifies custom value labels for the outcome variable
categories. {break}
Use standard Stata syntax: {it:value "Label" value "Label"}. {break}
Example: {cmd:eventlabel(0 "Alive" 1 "Heart Failure" 2 "Death")} {break}
If not specified, labels default to "Censored" (0) and the variable labels of
the date variables from the master event dataset in memory. Labels never come
from the interval data supplied in {cmd:using} or {opt frame()}.

{phang}
{opt timegen(newvar)} creates a new variable containing the cumulative time
since each person's first interval start (study entry). For each row, this
calculates stop - first_start, giving the time elapsed from the person's entry
to the end of that interval. This is the analysis time typically used in
survival models.

{phang}
{opt timeunit(string)} specifies the unit for {cmd:timegen()}. Options are
{bf:days} (default), {bf:months} (days/30.4375), or {bf:years} (days/365.25).

{phang}
{opt type(string)} specifies the event logic. {break}{bf:single} (default): Treats the first
event as terminal. Drops all follow-up time after the first
event. {break}{bf:recurring}: Allows multiple events per person. Splits intervals as
needed but retains all follow-up time. {break}
{break}{bf:Important:} For {cmd:type(recurring)}, event dates must be in {bf:wide format} with the
variable name specified in {cmd:date()} serving as a stubname. For example, if you
specify {cmd:date(hosp)}, the command expects variables {cmd:hosp1}, {cmd:hosp2}, {cmd:hosp3}, etc. in
the event dataset. The numbered sequence must be contiguous from 1; a missing
suffix is rejected so later events cannot be silently ignored. This avoids many-to-many merge issues when your interval
data already has multiple rows per person. The {cmd:compete()} option is not
supported with recurring events and returns error 198 if combined with them.

{phang}
{opt enum(name)} (requires {cmd:type(recurring)}) adds an event-sequence
stratum: 1 until a person's first event, 2 thereafter, and so on. It is the
stratifier for Prentice-Williams-Peterson (PWP) recurrent-event models. The
default name is {cmd:_enum}.

{phang}
{opt gaptime} (requires {cmd:type(recurring)}) adds a gap-time clock that resets to 0 at
the start of each new stratum, written to {cmd:gapstart()}/{cmd:gapstop()} (defaults
{cmd:_t0}/{cmd:_t}). This is the time scale for the PWP gap-time model. The three standard
recurrent-event analyses are
then: first generate {cmd:double analysis_t0 = start - 1}. {break}
{bf:Andersen-Gill}: use
{cmd:stset stop, time0(analysis_t0) failure(`generate') id(id) exit(time .)}
so follow-up continues after each failure. {break}{bf:PWP total time}: use the
same declaration and add {cmd:strata(`enum')} to the model. {break}
{bf:PWP gap time}: generate {cmd:long id_stratum = group(id `enum')} and
{cmd:double gap_t0 = _t0 - 1}, then declare
{cmd:stset _t, time0(gap_t0) failure(`generate') id(id_stratum)} and add
{cmd:strata(`enum')} plus person-clustered standard errors to the model.

{phang}
{opt gapstart(name)} and {opt gapstop(name)} name the two gap-time clock
variables. Defaults are {cmd:_t0} and {cmd:_t}.

{phang}
{opt replace} permits output variables already present in the interval data to
be replaced.

{phang}
{opt generate(newvar)} names the new outcome variable. Default is {cmd:_failure}.

{phang}
{opt keepvars(namelist)} specifies additional variables to keep from the event
dataset (e.g., diagnosis codes, baseline covariates). These are merged by person
ID so all rows for each person receive the same values. Each variable must be
constant within ID. An explicitly requested keep variable that already exists in the interval data or
collides with ID, bounds, event date, event indicator, elapsed time, enum, or
gap-time output is rejected; {opt replace} does not authorize payload
overwrite. When {opt keepvars()} is omitted, non-event master variables are
selected automatically; protected output/interval names are excluded, and the
command prints the exact preserved and excluded lists. Uniqueness remains strict.

{phang}
{opt start(varname)} specifies the name of the start date variable in the using
(interval) dataset. Default is {cmd:start}. (Legacy synonym: {opt startvar()}.)

{phang}
{opt stop(varname)} specifies the name of the stop date variable in the using
(interval) dataset. Default is {cmd:stop}. (Legacy synonym: {opt stopvar()}.)

{phang}
{opt validate} displays validation diagnostics before processing. This option checks
for: {break}1. {bf:Events outside interval coverage}: Events with no match in the
actual union of a person's closed intervals, including events in internal gaps
(those events cannot be flagged)
{break}2. {bf:Multiple events per person}: With {cmd:type(single)}, affected IDs
are counted once rather than once per event row
{break}3. {bf:Competing events on same date}: When {cmd:compete()} is specified, cases
where the primary event and a competing event occur on the same date. {break}
{break}Validation results are also stored in {cmd:r(v_outside_bounds)},
{cmd:r(v_multiple_events)}, and {cmd:r(v_same_date_compete)}.

{phang}
{opt dropinvalid} explicitly removes event-source rows with a missing ID or a
fractional nonmissing event date and interval rows with a missing ID, missing or
fractional daily bound, reversed bounds, or missing declared quantity. The
default is strict and returns error 498 without changing caller data. Missing
event dates are valid censored observations. A successful dropinvalid run returns
exact reason-specific counts and {cmd:r(flow)}.

{phang}
{opt verbose} lists up to five malformed source rows with the strict-input
diagnostic. It does not alter the malformed-input policy.

{phang}
{opt flow} reports an attrition table of persons and records entering (the
interval/using data) versus leaving, returned in the matrix {cmd:r(flow)} (rows
{cmd:persons} and {cmd:records}; columns {cmd:in}, {cmd:out}, {cmd:dropped}). For
records, {cmd:dropped} can be negative because intervals split at events. It is a
pure side channel and does not change the
output. The same matrix is returned automatically when {opt dropinvalid} is specified.

{pmore}
{bf:Note on interval boundaries:} The command uses closed intervals [start, stop]
for event detection. An event is flagged when it falls anywhere within an
interval, including on the start or stop date. Interval splitting occurs when
start <= event < stop (the event falls at or after the start but before the
stop). An event exactly on the stop date is flagged but does not trigger
splitting (it ends that interval naturally).


{marker examples}{...}
{title:Examples}

{pstd}
Create closed interval data with rate, total, and row-start cumulative
quantities:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(start_s stop_s) byte tv_drug double dose_rate course_total cum_days}{p_end}
{phang3}{cmd:1 "01jan2020" "15jan2020" 0 2 30 0}{p_end}
{phang3}{cmd:1 "16jan2020" "31jan2020" 1 2 32 15}{p_end}
{phang3}{cmd:2 "01jan2020" "31jan2020" 2 1 31 0}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double start = date(start_s, "DMY")}{p_end}
{phang2}{cmd:. generate double stop = date(stop_s, "DMY")}{p_end}
{phang2}{cmd:. format start stop %td}{p_end}
{phang2}{cmd:. drop start_s stop_s}{p_end}
{phang2}{cmd:. char dose_rate[tvtools_quantity] "rate"}{p_end}
{phang2}{cmd:. char course_total[tvtools_quantity] "total"}{p_end}
{phang2}{cmd:. char cum_days[tvtools_quantity] "cumulative"}{p_end}
{phang2}{cmd:. char cum_days[tvtools_history_point] "start"}{p_end}
{phang2}{cmd:. tempfile intervals events}{p_end}
{phang2}{cmd:. save `intervals'}{p_end}

{pstd}{bf:Primary and competing events}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(event_s death_s) byte female}{p_end}
{phang3}{cmd:1 "16jan2020" "" 1}{p_end}
{phang3}{cmd:2 "" "31jan2020" 0}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double event_date = date(event_s, "DMY")}{p_end}
{phang2}{cmd:. generate double death_date = date(death_s, "DMY")}{p_end}
{phang2}{cmd:. format event_date death_date %td}{p_end}
{phang2}{cmd:. label variable event_date "Primary event"}{p_end}
{phang2}{cmd:. label variable death_date "Death"}{p_end}
{phang2}{cmd:. drop event_s death_s}{p_end}
{phang2}{cmd:. save `events'}{p_end}
{phang2}{cmd:. tvevent using `intervals', id(id) date(event_date) compete(death_date) ///}{p_end}
{phang3}{cmd:start(start) stop(stop) generate(outcome) keepvars(female) ///}{p_end}
{phang3}{cmd:rate(dose_rate) total(course_total) cumulative(cum_days) validate}{p_end}

{pstd}
The primary event is exactly on the second row's start and the competing event
is exactly on the interval stop; both endpoints are included. Default status
labels come from {cmd:event_date} and {cmd:death_date} in the event master.

{pstd}{bf:Declare the inclusive output as survival data}{p_end}
{phang2}{cmd:. generate double analysis_t0 = start - 1}{p_end}
{phang2}{cmd:. stset stop, id(id) failure(outcome==1) time0(analysis_t0)}{p_end}
{phang2}{cmd:. tabulate outcome}{p_end}

{pstd}{bf:Recurring events with total-time and gap-time clocks}{p_end}
{phang2}{cmd:. use `events', clear}{p_end}
{phang2}{cmd:. generate double hosp1 = date("10jan2020", "DMY") if id == 1}{p_end}
{phang2}{cmd:. generate double hosp2 = date("25jan2020", "DMY") if id == 1}{p_end}
{phang2}{cmd:. format hosp1 hosp2 %td}{p_end}
{phang2}{cmd:. tvevent using `intervals', id(id) date(hosp) type(recurring) ///}{p_end}
{phang3}{cmd:start(start) stop(stop) generate(hospitalized) enum(event_no) ///}{p_end}
{phang3}{cmd:gaptime gapstart(gap0) gapstop(gap1) rate(dose_rate) ///}{p_end}
{phang3}{cmd:total(course_total) cumulative(cum_days)}{p_end}
{phang2}{cmd:. generate double ag_t0 = start - 1}{p_end}
{phang2}{cmd:. stset stop, id(id) failure(hospitalized) time0(ag_t0) exit(time .)}{p_end}
{phang2}{cmd:. egen long id_stratum = group(id event_no)}{p_end}
{phang2}{cmd:. generate double pwp_t0 = gap0 - 1}{p_end}
{phang2}{cmd:. stset gap1, id(id_stratum) failure(hospitalized) time0(pwp_t0)}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvevent} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}Total number of observations in output{p_end}
{synopt:{cmd:r(N_events)}}Total number of events/failures flagged{p_end}
{synopt:{cmd:r(n_rate)}}number of rate variables{p_end}
{synopt:{cmd:r(n_total)}}number of interval-total variables{p_end}
{synopt:{cmd:r(n_cumulative)}}number of cumulative-history variables{p_end}
{synopt:{cmd:r(n_continuous)}}number of totals declared by legacy {cmd:continuous()}{p_end}
{synopt:{cmd:r(n_invalid)}}malformed event and interval rows detected{p_end}
{synopt:{cmd:r(n_invalid_master)}}malformed event-source rows{p_end}
{synopt:{cmd:r(n_invalid_master_id)}}event rows with missing IDs{p_end}
{synopt:{cmd:r(n_invalid_master_dates)}}event rows with fractional dates{p_end}
{synopt:{cmd:r(n_invalid_intervals)}}malformed interval rows{p_end}
{synopt:{cmd:r(n_invalid_interval_id)}}interval rows with missing IDs{p_end}
{synopt:{cmd:r(n_invalid_interval_dates)}}interval rows with invalid daily bounds{p_end}
{synopt:{cmd:r(n_invalid_interval_order)}}interval rows with reversed bounds{p_end}
{synopt:{cmd:r(n_invalid_quantity)}}interval rows with missing declared quantities{p_end}

{pstd}
When {cmd:validate} is specified, additional scalars are stored:

{synopt:{cmd:r(v_outside_bounds)}}Number of events outside interval boundaries{p_end}
{synopt:{cmd:r(v_multiple_events)}}persons with multiple terminal events{p_end}
{synopt:{cmd:r(v_same_date_compete)}}Number of competing events on same date as primary{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(generate)}}name of the event indicator variable{p_end}
{synopt:{cmd:r(startvar)}}name of the interval start variable{p_end}
{synopt:{cmd:r(stopvar)}}name of the interval stop variable{p_end}
{synopt:{cmd:r(timegen)}}name of the elapsed-time variable (if {cmd:timegen()} used){p_end}
{synopt:{cmd:r(enum)}}event-sequence stratum name{p_end}
{synopt:{cmd:r(gapstart)}}name of the gap-time start variable (if {cmd:gaptime} used){p_end}
{synopt:{cmd:r(gapstop)}}name of the gap-time stop variable (if {cmd:gaptime} used){p_end}
{synopt:{cmd:r(rate_vars)}}rate variable names{p_end}
{synopt:{cmd:r(total_vars)}}interval-total variable names{p_end}
{synopt:{cmd:r(cumulative_vars)}}cumulative-history variable names{p_end}
{synopt:{cmd:r(continuous_vars)}}legacy {cmd:continuous()} aliases (totals){p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(flow)}}persons/records attrition table{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{title:Also see}

{psee}
Online: {helpb tvexpose}, {helpb tvmerge}
{p_end}

{hline}
