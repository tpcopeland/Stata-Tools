{smcl}
{* *! version 1.8.0  22jul2026}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{vieweralsosee "tvweight" "help tvweight"}{...}
{vieweralsosee "tvage" "help tvage"}{...}
{vieweralsosee "tvband" "help tvband"}{...}
{vieweralsosee "tvsplit" "help tvsplit"}{...}
{vieweralsosee "tvpanel" "help tvpanel"}{...}
{viewerjumpto "Description" "tvtools##description"}{...}
{viewerjumpto "Syntax" "tvtools##syntax"}{...}
{viewerjumpto "Commands" "tvtools##commands"}{...}
{viewerjumpto "Workflow" "tvtools##workflow"}{...}
{viewerjumpto "Data contracts" "tvtools##contracts"}{...}
{viewerjumpto "Examples" "tvtools##examples"}{...}
{viewerjumpto "Remarks" "tvtools##remarks"}{...}
{viewerjumpto "Stored results" "tvtools##results"}{...}
{viewerjumpto "Installation" "tvtools##installation"}{...}
{viewerjumpto "Author" "tvtools##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tvtools} {hline 2}}A suite of commands for time-varying exposure analysis{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvtools} provides a set of commands for constructing, diagnosing, and analyzing
time-varying exposure data in survival analysis. The package supports the
workflow from data preparation through weighting and estimation.


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvtools} [{cmd:,} {opt list} {opt detail} {opt cat:egory(string)}]

{synoptset 22 tabbed}{...}
{synopt:{opt list}}display commands as a simple list{p_end}
{synopt:{opt detail}}show detailed information with descriptions{p_end}
{synopt:{opt cat:egory(string)}}filter by category: {cmd:prep}, {cmd:diag}, {cmd:weight}, {cmd:all}{p_end}

{marker options}{...}
{title:Options}

{phang}
{opt list} displays only the selected command names.

{phang}
{opt detail} displays command descriptions.

{phang}
{opt category(string)} filters the index to {cmd:prep}, {cmd:diag},
{cmd:weight}, or {cmd:all} (the default).


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Data Preparation}

{synoptset 16}{...}
{synopt:{helpb tvexpose}}Create time-varying exposure variables for survival analysis{p_end}
{synopt:{helpb tvmerge}}Merge multiple time-varying exposure datasets{p_end}
{synopt:{helpb tvevent}}Integrate events and competing risks into time-varying datasets{p_end}
{synopt:{helpb tvage}}Expand one-row-per-person follow-up into age bands{p_end}
{synopt:{helpb tvband}}Split intervals along one date-derived axis{p_end}
{synopt:{helpb tvsplit}}Multi-timescale (Lexis) splitting on several axes at once{p_end}
{synopt:{helpb tvpanel}}Build a fixed-width, entry-anchored person-period panel for MSMs{p_end}

{pstd}
{bf:Diagnostics}

{synopt:{helpb tvdiagnose}}Diagnostic tools for time-varying exposure datasets{p_end}

{pstd}
{bf:Weighting}

{synopt:{helpb tvweight}}Calculate inverse probability of treatment weights (IPTW){p_end}


{marker workflow}{...}
{title:Typical Workflow}

{pstd}
A typical time-varying exposure analysis follows these steps:

{p 4 8 2}1. {bf:Create exposure data}: Use {helpb tvexpose} to transform exposure records into
time-varying format{p_end}
{p 4 8 2}2. {bf:Merge exposures}: Use {helpb tvmerge} to combine multiple exposure sources{p_end}
{p 4 8 2}3. {bf:Add events}: Use {helpb tvevent} to integrate outcomes and competing risks{p_end}
{p 4 8 2}4. {bf:Diagnose}: Use {helpb tvdiagnose} to verify data structure{p_end}
{p 4 8 2}5. {bf:Compute weights}: Use {helpb tvweight} for IPTW estimation{p_end}
{p 4 8 2}6. {bf:Estimate effects}: Use Cox regression or other models with weighted data{p_end}


{marker contracts}{...}
{title:Data contracts}

{pstd}
The following contracts apply throughout {cmd:tvtools}. Command-specific help
may add restrictions but does not change these definitions.

{pstd}
{bf:Closed daily intervals.} Source rows use inclusive integer Stata daily
dates {cmd:[start, stop]}. Their duration is {cmd:stop - start + 1}, so
{cmd:start == stop} is a valid one-day row. Two rows abut when the later start
equals the running prior maximum stop plus one; a gap begins above that value. An
overlap begins on or below the running prior maximum stop. Equality at a
shared date is therefore an overlap, not abutment.

{pstd}
An event on date {it:d} belongs to the closed row containing {it:d}. When that
date creates a boundary, the event row ends on {it:d}; any continuing row
starts on {it:d}+1. Terminal-event output contains no later person-time.

{pstd}
{bf:Conversion to Stata survival time.} Stata survival records are open on the
left and closed on the right. Convert every closed source row by subtracting
one day from its lower bound, then use that row-specific value with
{cmd:time0()}:

{phang2}{cmd:. generate double start0 = start - 1}{p_end}
{phang2}{cmd:. stset stop, id(id) failure(event == 1) time0(start0)}{p_end}

{pstd}
This maps {cmd:[start, stop]} exactly to {cmd:(start-1, stop]} and preserves a
one-day row as one analysis-time unit. A single {cmd:enter()} value is safe only
when one entry applies to a guaranteed contiguous history. {cmd:time0()} is the
authoritative form for row-specific bounds and histories containing gaps.

{pstd}
{bf:Continuous quantities.} A rate is an amount per day and remains unchanged
when a row is split. An interval total is the amount attributable to one closed
source row and is apportioned by inclusive overlap days; pieces must sum to the
source total. A cumulative history is the amount known at the start of a model
row. It is non-anticipating and is carried unchanged when that row is split.

{pstd}
{cmd:tvmerge} and {cmd:tvevent} use {opt rate()}, {opt total()}, and
{opt cumulative()} for these three algebras. A variable may appear in only one
list. The legacy {opt continuous()} option is a deprecated alias for
{opt total()} because proportional allocation was its released behavior; the
command issues a migration warning. Quantity variables carry the characteristic
{cmd:[tvtools_quantity]} with value {cmd:rate}, {cmd:total}, or
{cmd:cumulative}. Cumulative output from {cmd:tvexpose} is measured at row
start and carries {cmd:[tvtools_history_point] = start}.

{pstd}
{bf:Recency.} {opt recency()} requires
{opt recencyunit(days|years)}; version 1.7 does not guess between the formerly
contradictory code and documentation. Day cutpoints must be positive whole
days. Year cutpoints are converted once to whole elapsed days as
{cmd:round(365.25 * cutpoint)}. Converted boundaries must be unique and
strictly increasing.

{pstd}
Let {it:s} be the inclusive stop of the most recent exposure and let
{it:d} be an unexposed date. Recency is {cmd:d-s}. A boundary {it:b} enters the
new category on the date where {cmd:d-s == b}; bands are left-closed and
right-open. Every crossing splits the output row. The final category is open
ended. Only time before a person's first exposure is {it:never exposed}; a
formerly exposed person never silently returns to that reference category.

{pstd}
{bf:Malformed required inputs.} IDs must be nonmissing. Required dates and
interval bounds must be numeric, finite, nonmissing whole daily dates, must not
have {cmd:%tc}/{cmd:%tC} formats, and must satisfy {cmd:start <= stop}. Required
exposure values must be nonmissing. Commands reject malformed inputs before
mutating caller data and report exact counts by reason.

{pstd}
Where documented, {opt dropinvalid} is the only opt-in escape hatch. It drops
the offending source rows without repairing or guessing their values, returns
the reason-specific counts and {cmd:r(flow)}, and errors if no valid analysis
rows remain. Options such as {opt force} that govern ID-set or overlap policy do
not authorize malformed-input deletion.


{marker examples}{...}
{title:Examples}

{pstd}
Every example below is self-contained: it builds its own data and needs no
external file. Run them in order in a scratch session.

{pstd}
{bf:Browse the suite}

{phang2}{cmd:. tvtools}{p_end}
{phang2}{cmd:. tvtools, detail}{p_end}
{phang2}{cmd:. tvtools, category(prep)}{p_end}
{phang2}{cmd:. tvtools, category(weight)}{p_end}

{pstd}
{bf:Create time-varying exposure from prescription episodes}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id rx_start rx_stop drug}{p_end}
{phang2}{cmd:. 1 21930 21990 1}{p_end}
{phang2}{cmd:. 1 22050 22100 1}{p_end}
{phang2}{cmd:. 2 21950 22000 1}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. tempfile rx}{p_end}
{phang2}{cmd:. save "`rx'"}{p_end}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id study_entry study_exit}{p_end}
{phang2}{cmd:. 1 21915 22280}{p_end}
{phang2}{cmd:. 2 21915 22280}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. format study_entry study_exit %td}{p_end}

{phang2}{cmd:. tvexpose using "`rx'", id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:generate(tv_drug) keepdates}{p_end}

{pstd}
The output carries the bounds under the names given in {opt start()} and
{opt stop()}. See {help tvexpose##naming:the output naming contract}.

{pstd}
{bf:Diagnose the constructed dataset}

{phang2}{cmd:. tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:coverage gaps entry(study_entry) exit(study_exit)}{p_end}

{pstd}
{bf:Add an event and a competing risk}

{phang2}{cmd:. tempfile intervals}{p_end}
{phang2}{cmd:. save "`intervals'"}{p_end}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id event_date death_date}{p_end}
{phang2}{cmd:. 1 22120 .}{p_end}
{phang2}{cmd:. 2 . 22200}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. format event_date death_date %td}{p_end}

{phang2}{cmd:. tvevent using "`intervals'", id(id) date(event_date) ///}{p_end}
{phang3}{cmd:compete(death_date) startvar(rx_start) stopvar(rx_stop)}{p_end}

{pstd}
{bf:Convert to Stata survival time and fit a model}

{phang2}{cmd:. generate double start0 = rx_start - 1}{p_end}
{phang2}{cmd:. stset rx_stop, id(id) failure(_failure == 1) time0(start0)}{p_end}

{pstd}
{bf:Calculate IPTW weights}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set obs 200}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. generate id = _n}{p_end}
{phang2}{cmd:. generate age = 40 + int(runiform() * 40)}{p_end}
{phang2}{cmd:. generate sex = runiform() < 0.5}{p_end}
{phang2}{cmd:. generate tv_drug = runiform() < invlogit(-2 + 0.03 * age + 0.4 * sex)}{p_end}
{phang2}{cmd:. tvweight tv_drug, covariates(age sex)}{p_end}

{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to use tvtools}

{pstd}
Use {cmd:tvtools} whenever you have exposure data recorded as episodes or
prescriptions and need to build a person-period dataset for time-to-event
analysis. The package handles the mechanics of aligning exposure windows
with follow-up intervals, splitting at event dates, and diagnosing common
data quality problems.

{pstd}
{bf:Data assumptions}

{pstd}
All date variables must be Stata daily dates (integer days since
01jan1960). Datetime variables ({cmd:%tc}/{cmd:%tC}) are not supported and will be
rejected with a clear error message. Convert datetimes first with
{cmd:gen daily = dofc(datetime_var)}.

{pstd}
Intervals use a closed [start, stop] convention where both endpoints are
inclusive. A period [2020-01-01, 2020-01-31] covers 31 days.

{pstd}
{bf:Choosing exposure definitions}

{pstd}
{helpb tvexpose} supports several exposure definitions for different
research questions:

{p 8 12 2}{cmd:[default]} — Categorical time-varying exposure (e.g., which drug a patient is
currently on){p_end}
{p 8 12 2}{cmd:evertreated} — Binary ever/never, for immortal-time-bias correction{p_end}
{p 8 12 2}{cmd:currentformer} — Three-level never/current/former{p_end}
{p 8 12 2}{cmd:duration()} — Cumulative duration categories{p_end}
{p 8 12 2}{cmd:continuousunit()} — Continuous cumulative exposure{p_end}
{p 8 12 2}{cmd:recency()} — Time since last exposure{p_end}
{p 8 12 2}{cmd:dose} — Cumulative dose with proportional overlap allocation{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvtools} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of commands listed{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(commands)}}space-separated list of command names{p_end}
{synopt:{cmd:r(version)}}package version string{p_end}
{synopt:{cmd:r(categories)}}available categories (prep diag weight){p_end}


{marker installation}{...}
{title:Installation}

{pstd}
To install or update tvtools:

{phang2}{cmd:. capture ado uninstall tvtools}{p_end}
{phang2}{cmd:. net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
