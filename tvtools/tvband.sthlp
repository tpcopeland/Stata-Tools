{smcl}
{vieweralsosee "tvsplit" "help tvsplit"}{...}
{vieweralsosee "tvage" "help tvage"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "[ST] stsplit" "help stsplit"}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{viewerjumpto "Syntax" "tvband##syntax"}{...}
{viewerjumpto "Description" "tvband##description"}{...}
{viewerjumpto "Options" "tvband##options"}{...}
{viewerjumpto "Remarks" "tvband##remarks"}{...}
{viewerjumpto "Examples" "tvband##examples"}{...}
{viewerjumpto "Stored results" "tvband##results"}{...}
{viewerjumpto "Author" "tvband##author"}{...}

{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:tvband} {hline 2}}Split follow-up intervals along a single date-derived axis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvband}{cmd:,}
{opt id(varname)}
{opt start(varname)}
{opt stop(varname)}
{opt type(axis)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier{p_end}
{synopt:{opt start(varname)}}interval start date (daily date){p_end}
{synopt:{opt stop(varname)}}interval stop date (daily date){p_end}
{synopt:{opt type(axis)}}axis to split on: {cmd:age}, {cmd:calendar}, or {cmd:elapsed}{p_end}

{syntab:Axis}
{synopt:{opt origin(varname)}}origin date for age or elapsed time{p_end}
{synopt:{opt width(#)}}band width; default {cmd:1}{p_end}
{synopt:{opt unit(day|year)}}elapsed-time unit; default {cmd:day}{p_end}
{synopt:{opt anchor(#)}}first calendar year of the band grid{p_end}
{synopt:{opt min(#)}}drop bands whose lower edge is below {it:#}{p_end}
{synopt:{opt max(#)}}drop bands whose lower edge is above {it:#}{p_end}

{syntab:Output}
{synopt:{opt gen:erate(name)}}name the generated band variable{p_end}
{synopt:{opt startg:en(name)}}name for the split interval start; default keeps {opt start()}{p_end}
{synopt:{opt stopg:en(name)}}name for the split interval stop; default keeps {opt stop()}{p_end}
{synopt:{opt save:as(filename)}}save the result to a file and restore the data in memory{p_end}
{synopt:{opt rep:lace}}overwrite the file in {opt saveas()}{p_end}
{synopt:{opt noi:sily}}display a summary{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvband} splits each {opt start()}-{opt stop()} interval in memory at the
band boundaries of one date-derived axis, producing one row per band the
interval traverses. It generalizes {helpb tvage} to any continuous axis derived
from dates:

{phang2}{cmd:age} {hline 1} time since a date of birth (boundaries at exact
birthdays);{p_end}
{phang2}{cmd:calendar} {hline 1} calendar period (boundaries at 1 January);{p_end}
{phang2}{cmd:elapsed} {hline 1} time since a reference date such as study entry
(boundaries at multiples of {opt width()} {opt unit()}s).{p_end}

{pstd}
All other variables are carried onto each split row, so covariates are
preserved. Intervals are inclusive integer Stata dates that abut as
{cmd:stop + 1 == next start}, matching the rest of the {help tvtools} suite, so
the output merges with {helpb tvexpose} and {helpb tvmerge} output and feeds
{helpb stset}. To split on several axes at once (a Lexis diagram), use
{helpb tvsplit}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier. It must be {bf:numeric}; string
identifiers are not accepted. Convert one first with {helpb encode} or
{cmd:egen long newid = group(stringid)}.

{phang}
{opt start(varname)} and {opt stop(varname)} specify the interval to split. Both must be
non-missing daily Stata dates with {cmd:stop >= start}.

{phang}
{opt type(axis)} selects the splitting axis: {cmd:age}, {cmd:calendar}, or
{cmd:elapsed}.

{dlgtab:Axis}

{phang}
{opt origin(varname)} gives the origin date. It is required for {cmd:type(age)}
(the date of birth) and {cmd:type(elapsed)} (the reference date) and is not
allowed for {cmd:type(calendar)}.

{phang}
{opt width(#)} sets the band width. For {cmd:age} and {cmd:calendar} the unit is years (for
example {cmd:width(10)} gives 10-year bands); for {cmd:elapsed} the unit is set by
{opt unit()}. Age, calendar, and elapsed-year widths must be positive whole
years. Default is {cmd:width(1)}.

{phang}
{opt unit(day|year)} sets the elapsed-time unit. Default is {cmd:day}. Used only
with {cmd:type(elapsed)}; specifying it for another axis is an error.

{phang}
{opt anchor(#)} fixes the first calendar year of the band grid (relevant when
{cmd:width()} exceeds 1). Default is the earliest year in the data. Used only with
{cmd:type(calendar)}. Specifying {opt anchor()} for another axis is an error.

{phang}
{opt min(#)} and {opt max(#)} drop bands whose lower-edge value falls below
{opt min()} or above {opt max()}. For example, with {cmd:type(age)} and
{cmd:min(40)} all person-time before age 40 is dropped (left truncation).

{dlgtab:Output}

{phang}
{opt generate(name)} names the band variable. Default depends on the axis: {cmd:ageband},
{cmd:calband}, or {cmd:fuband}.

{phang}
{opt startgen(name)} and {opt stopgen(name)} rename the split interval bounds. By default
the input {opt start()}/{opt stop()} variables are overwritten in place.

{phang}
{opt saveas(filename)} saves the split dataset to a file and restores the
original data in memory. Without {opt saveas()} the split data replaces the data
in memory.

{phang}
{opt replace} permits overwriting an existing {opt saveas()} file.

{phang}
{opt noisily} displays a short summary.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Interval convention.} Bands use inclusive integer dates: a band runs from
its first day to the day before the next band starts, so adjacent rows satisfy
{cmd:stop + 1 == next start} and tile follow-up without gaps or overlaps.

{pstd}
{bf:Exact anniversaries.} Age and year-unit elapsed boundaries are exact
calendar anniversaries. For a 29 February origin, the anniversary is 28
February in non-leap years and 29 February in leap years. This matches
{helpb tvage} and {helpb tvsplit}.

{pstd}
{bf:General input.} Unlike {helpb tvage}, {cmd:tvband} accepts data that already
has several rows per person (for example {helpb tvexpose} output); each interval
is split independently.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(birth_s start_s stop_s)}{p_end}
{phang3}{cmd:1 "29feb1960" "01jan2000" "31dec2005"}{p_end}
{phang3}{cmd:2 "15jun1975" "01jan2018" "31dec2022"}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double birth_date = date(birth_s, "DMY")}{p_end}
{phang2}{cmd:. generate double start = date(start_s, "DMY")}{p_end}
{phang2}{cmd:. generate double stop = date(stop_s, "DMY")}{p_end}
{phang2}{cmd:. generate double fu_origin = start}{p_end}
{phang2}{cmd:. format birth_date start stop fu_origin %td}{p_end}
{phang2}{cmd:. drop birth_s start_s stop_s}{p_end}
{phang2}{cmd:. tempfile intervals}{p_end}
{phang2}{cmd:. save `intervals'}{p_end}

{pstd}{bf:Age bands on an existing interval dataset}{p_end}
{phang2}{cmd:. tvband, id(id) start(start) stop(stop) type(age) ///}{p_end}
{phang3}{cmd:origin(birth_date) width(5) min(40) max(85) generate(age5)}{p_end}

{pstd}{bf:Calendar periods}{p_end}
{phang2}{cmd:. use `intervals', clear}{p_end}
{phang2}{cmd:. tvband, id(id) start(start) stop(stop) type(calendar) ///}{p_end}
{phang3}{cmd:width(5) anchor(2000) generate(period5)}{p_end}

{pstd}{bf:Exact years since study entry}{p_end}
{phang2}{cmd:. use `intervals', clear}{p_end}
{phang2}{cmd:. tvband, id(id) start(start) stop(stop) type(elapsed) ///}{p_end}
{phang3}{cmd:origin(fu_origin) width(1) unit(year) generate(fuyear)}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvband} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(n_observations)}}number of output rows{p_end}
{synopt:{cmd:r(width)}}band width used{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(axistype)}}axis type ({cmd:age}/{cmd:calendar}/{cmd:elapsed}){p_end}
{synopt:{cmd:r(varname)}}name of the band variable{p_end}
{synopt:{cmd:r(startvar)}}name of the interval start variable{p_end}
{synopt:{cmd:r(stopvar)}}name of the interval stop variable{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{space 2}Help: {help tvsplit}, {help tvage}, {help tvexpose}, {help tvmerge}, {help stsplit}
{p_end}

{hline}
