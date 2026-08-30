{smcl}
{* *! version 1.0.1  30aug2026}{...}
{vieweralsosee "pyattach" "help pyattach"}{...}
{vieweralsosee "tvband" "help tvband"}{...}
{vieweralsosee "stsplit" "help stsplit"}{...}
{viewerjumpto "Syntax" "pygrid##syntax"}{...}
{viewerjumpto "Description" "pygrid##description"}{...}
{viewerjumpto "Options" "pygrid##options"}{...}
{viewerjumpto "Person-time conventions" "pygrid##conventions"}{...}
{viewerjumpto "Denominators" "pygrid##denominators"}{...}
{viewerjumpto "Examples" "pygrid##examples"}{...}
{viewerjumpto "Stored results" "pygrid##results"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:pygrid} {hline 2}}Build a person-period denominator grid with exact person-time{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:pygrid}
{ifin}
{cmd:,}
{opt id(varname)}
{opt start(varname)}
{opt end(varname)}
{opt axis(rule)}
[{it:options}]

{synoptset 31 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person or episode identifier{p_end}
{synopt:{opt start(varname)}}inclusive daily window start{p_end}
{synopt:{opt end(varname)}}inclusive daily window end{p_end}
{synopt:{opt axis(rule)}}{cmd:calendar}, {cmd:anniversary}, or {cmd:fixed}{p_end}

{syntab:Period rules}
{synopt:{opt ori:gin(varname)}}anniversary origin date{p_end}
{synopt:{opt wid:th(#)}}period width; default is {cmd:1}{p_end}
{synopt:{opt unit(unit)}}{cmd:day}, {cmd:month}, or {cmd:year}; default is {cmd:year}{p_end}
{synopt:{opt fir:st(#)}}retain periods numbered at least {it:#}{p_end}
{synopt:{opt las:t(#)}}retain periods numbered at most {it:#}{p_end}
{synopt:{opt part:ial(rule)}}{cmd:keep}, {cmd:drop}, or {cmd:flag}; default is {cmd:keep}{p_end}

{syntab:Window restrictions}
{synopt:{opt clamp(# #)}}hard study bounds{p_end}
{synopt:{opt cov:erage(#|varname)}}coverage-start truncation{p_end}

{syntab:Output}
{synopt:{opt gen:erate(name)}}period variable; default {cmd:period}{p_end}
{synopt:{opt rel:gen(name)}}relative-period variable name{p_end}
{synopt:{opt startg:en(name)}}observed start; default {cmd:period_start}{p_end}
{synopt:{opt stopg:en(name)}}observed stop; default {cmd:period_stop}{p_end}
{synopt:{opt pyt:ime(name)}}person-time; default {cmd:person_years}{p_end}
{synopt:{opt pyu:nit(unit)}}{cmd:year} or {cmd:day}; default is {cmd:year}{p_end}
{synopt:{opt noincl:usive}}exclude the terminal day{p_end}
{synopt:{opt keep(varlist)}}variables copied to period rows{p_end}
{synopt:{opt save:as(filename)}}save grid and preserve memory{p_end}
{synopt:{opt replace}}replace an existing {cmd:saveas()} file{p_end}
{synopt:{opt noi:sily}}display a compact build report{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:pygrid} starts from one row per person or person-episode and replaces the
data in memory with one row per observed period. Each row carries the exact
time contributed to that period. If {cmd:saveas()} is specified, the grid is
written to disk and the original data remain in memory.

{pstd}
For {cmd:axis(calendar)}, period boundaries follow calendar days, months, or
years. Multi-month periods are anchored at January 1960 and multi-year periods
at year zero. For {cmd:axis(anniversary)}, boundaries are measured from
{cmd:origin()}; year widths use 365.25 days and integer daily-date boundaries. {cmd:axis(fixed)}
produces one row spanning the resolved window.

{pstd}
Missing identifiers or window bounds are denominator errors and produce
{cmd:r(416)}. Daily-date inputs must be integer valued. A source window with
{cmd:end()} before {cmd:start()} is malformed and produces {cmd:r(459)}. Source
episodes for one identifier may not overlap. An otherwise valid window that
becomes empty after clamping or coverage restrictions is dropped and counted
in {cmd:r(N_empty_window)}.


{marker options}{...}
{title:Options}

{phang}
{opt id(varname)}, {opt start(varname)}, and {opt end(varname)} identify the
input episode and its inclusive integer daily-date bounds. Identifiers may be
numeric or fixed-width strings; {cmd:strL} identifiers are rejected. Datetime
variables formatted {cmd:%tc} are rejected.

{phang}
{opt axis(rule)} selects calendar, anniversary, or fixed periods. Calendar
period numbers are the calendar year for year units, the Stata monthly date for
month units, and the block-start daily date for day units. Anniversary periods
use 1 for the period beginning at {cmd:origin()}, 0 for the preceding period,
and so on.

{phang}
{opt origin(varname)} supplies an integer daily-date anniversary origin. With a
calendar axis it also enables relative-period output, where zero is the calendar
block containing the origin.

{phang}
{opt width(#)} and {opt unit(unit)} define period size. Calendar widths must be
positive integers. Anniversary widths may be positive real numbers.

{phang}
{opt first(#)} and {opt last(#)} filter on the generated period number before partial periods are handled.

{phang}
{opt partial(rule)} controls observed intervals shorter than the nominal
period. {cmd:keep} retains them, {cmd:drop} removes them, and {cmd:flag}
retains them and creates byte variable {cmd:_partial}. {cmd:r(N_partial)}
counts partial rows before {cmd:drop} is applied.

{phang}
{opt clamp(# #)} intersects each window with integer daily-date lower and upper
study bounds.

{phang}
{opt coverage(#|varname)} truncates each window at a constant or row-specific
integer daily-date data-source start, creates byte variable {cmd:_covered}, and
records the number of truncated source rows in {cmd:r(N_uncovered)}.

{phang}
{opt generate(name)}, {opt relgen(name)}, {opt startgen(name)},
{opt stopgen(name)}, and {opt pytime(name)} set output names. Names must be
distinct and may not overwrite variables already in memory.

{phang}
{opt pyunit(unit)} stores person-time in years or days. Years use a divisor of 365.25.

{phang}
{opt noinclusive} excludes the terminal day from each generated row. A one-day
interval therefore contributes zero. See
{help pygrid##conventions:Person-time conventions}.

{phang}
{opt keep(varlist)} carries selected input variables to every output row. {cmd:id()}
is always retained. Internal variable {cmd:_pygrid_episode} records
the source row so partition checks remain episode-specific.

{phang}
{opt saveas(filename)} saves the grid while restoring the original data in
memory. {opt replace} permits overwriting that file and is invalid without
{cmd:saveas()}.

{phang}
{opt noisily} displays persons, rows, dropped windows, partial rows, total person-time, and the resolved convention.


{marker conventions}{...}
{title:Person-time conventions}

{pstd}
The default is inclusive daily counting: {cmd:(period_stop - period_start + 1)/365.25}. Thus
a one-day interval
contributes one day and leap day is counted exactly once. {cmd:noinclusive}
removes the {cmd:+1} separately from every output row; zero-time one-day rows
are retained, and rates on such rows are missing because their denominator is
zero. {help pyattach} treats the stored stop as an exclusive attachment bound,
so an event on that terminal date is not assigned to the row.

{pstd}
For comparison with {help stsplit}, represent a pygrid interval
{cmd:[start, stop]} as the half-open survival interval
{cmd:[start, stop + 1)}. After
{cmd:stset stop_plus_one, enter(time start)}, {cmd:_t - _t0} equals pygrid's
inclusive day count. Split at each following period start, which is the prior
pygrid stop plus one. Without this mapping, the commands use different endpoint
conventions by one day.

{pstd}
After construction, {cmd:pygrid} verifies nonmissing person-time, valid per-row
bounds, nonoverlapping periods, and an episode-level partition identity to
tolerance {cmd:1e-9}. For {cmd:noinclusive}, the identity reflects removal of
one endpoint from every output row.


{marker denominators}{...}
{title:Denominators and zero filling}

{pstd}
Build the eligible denominator before attaching events. Then use
{help pyattach} to attach event counts, sums, indicators, or maxima. Unmatched
grid rows become zero by default, so a rate uses the full eligible person-time
rather than conditioning on people who had an event. Events outside the grid
are errors by default because silently discarding them drops the numerator.


{marker examples}{...}
{title:Examples}

{pstd}
Calendar-year grid around an index date:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id str9 s str9 e str9 index}{p_end}
{phang2}{cmd:. 1 "15jun2010" "20mar2012" "01jan2011"}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. generate double window_start = daily(s,"DMY")}{p_end}
{phang2}{cmd:. generate double window_end = daily(e,"DMY")}{p_end}
{phang2}{cmd:. generate double index_date = daily(index,"DMY")}{p_end}
{phang2}{cmd:. pygrid, id(id) start(window_start) end(window_end)}
{cmd:axis(calendar) origin(index_date) keep(index_date) relgen(rel_year)}{p_end}

{pstd}
Anniversary grid retaining only complete years:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id str9 index str9 followup}{p_end}
{phang2}{cmd:. 1 "01jan2010" "15apr2013"}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. generate double index_date = daily(index,"DMY")}{p_end}
{phang2}{cmd:. generate double followup_date = daily(followup,"DMY")}{p_end}
{phang2}{cmd:. pygrid, id(id) start(index_date) end(followup_date)}
{cmd:axis(anniversary) origin(index_date) partial(drop)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:pygrid} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_persons)}}distinct identifiers with a period{p_end}
{synopt:{cmd:r(N_rows)}}grid rows created{p_end}
{synopt:{cmd:r(N_empty_window)}}source rows dropped after resolving the window{p_end}
{synopt:{cmd:r(N_uncovered)}}rows truncated by {cmd:coverage()}{p_end}
{synopt:{cmd:r(N_partial)}}partial rows identified before {cmd:partial(drop)}{p_end}
{synopt:{cmd:r(pytotal)}}total person-time{p_end}
{synopt:{cmd:r(pymin)}}minimum row-level person-time{p_end}
{synopt:{cmd:r(pymax)}}maximum row-level person-time{p_end}
{synopt:{cmd:r(period_min)}}minimum period number{p_end}
{synopt:{cmd:r(period_max)}}maximum period number{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(axis)}}resolved axis{p_end}
{synopt:{cmd:r(width)}}resolved width{p_end}
{synopt:{cmd:r(unit)}}resolved period unit{p_end}
{synopt:{cmd:r(pyconvention)}}{cmd:inclusive} or {cmd:exclusive}{p_end}


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.0.1, 2026-08-30{p_end}


{title:Also see}

{psee}
Help: {helpb pyattach}, {helpb tvband}, {helpb tvsplit}, {helpb stsplit}

{pstd}
Use {cmd:pygrid} when starting from one inclusive window per person and needing
an analysis-ready denominator plus event attachment. Use {cmd:tvband} or
{cmd:tvsplit} when splitting an already long interval dataset for time-varying
covariates. {cmd:pygrid} is standalone and does not require {cmd:tvtools} at
runtime.

{hline}
