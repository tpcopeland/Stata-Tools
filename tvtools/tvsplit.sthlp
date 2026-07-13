{smcl}
{vieweralsosee "tvband" "help tvband"}{...}
{vieweralsosee "tvage" "help tvage"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "[ST] stsplit" "help stsplit"}{...}
{viewerjumpto "Syntax" "tvsplit##syntax"}{...}
{viewerjumpto "Description" "tvsplit##description"}{...}
{viewerjumpto "Options" "tvsplit##options"}{...}
{viewerjumpto "Remarks" "tvsplit##remarks"}{...}
{viewerjumpto "Examples" "tvsplit##examples"}{...}
{viewerjumpto "Stored results" "tvsplit##results"}{...}
{viewerjumpto "Author" "tvsplit##author"}{...}

{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:tvsplit} {hline 2}}Multi-timescale Lexis splitting of follow-up intervals{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvsplit}{cmd:,}
{opt id(varname)}
{opt start(varname)}
{opt stop(varname)}
[{it:axis_options} {opt noi:sily}]

{pstd}
where at least one {it:axis_option} is required:

{synoptset 30 tabbed}{...}
{synopthdr:axis_options}
{synoptline}
{synopt:{opt age}{cmd:(}{it:dobvar}[{cmd:,} {it:asub}]{cmd:)}}split on age (relative to date of birth){p_end}
{synopt:{opt cal:endar}{cmd:(}[{cmd:,} {it:csub}]{cmd:)}}split on calendar period{p_end}
{synopt:{opt elap:sed}{cmd:(}{it:refvar}[{cmd:,} {it:esub}]{cmd:)}}split on time since a reference date{p_end}
{synoptline}

{pstd}
where the per-axis suboptions are

{p 8 12 2}{it:asub} {space 3}= {cmd:width(#)} {cmd:min(#)} {cmd:max(#)} {cmd:generate(name)}{p_end}
{p 8 12 2}{it:csub} {space 3}= {cmd:width(#)} {cmd:anchor(#)} {cmd:generate(name)}{p_end}
{p 8 12 2}{it:esub} {space 3}= {cmd:width(#)} {cmd:unit(day|year)} {cmd:min(#)} {cmd:max(#)} {cmd:generate(name)}{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvsplit} performs multi-timescale (Lexis) splitting: it splits each
{opt start()}-{opt stop()} interval in memory simultaneously on up to three time
axes so that every output sub-interval lies in exactly one band on every
requested axis. The result is ready for age- and period-adjusted Cox or Poisson
models and is equivalent to repeated Stata {helpb stsplit} or R
{cmd:Epi::splitLexis} calls, one timescale at a time.

{pstd}
Splitting is performed one axis at a time. Because interval splitting is
commutative over the union of cut points, the order of the axes does not affect
the result. Existing covariates are carried onto every split row.

{pstd}
For splitting on a single axis (and for {opt saveas()} convenience), see
{helpb tvband}; {helpb tvage} is the age-only special case.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier.

{phang}
{opt start(varname)} and {opt stop(varname)} specify the intervals to split. They are
overwritten in place with the split bounds (the number of rows grows). Both
must be non-missing daily Stata dates. The variables named by {opt id()},
{opt start()}, and {opt stop()} must be distinct.

{dlgtab:Axes (specify at least one)}

{phang}
{opt age}{cmd:(}{it:dobvar} [{cmd:,} {it:suboptions}]{cmd:)} splits on age relative to the
date-of-birth variable {it:dobvar}. It must be a non-missing numeric daily date
and must be distinct from {opt id()}, {opt start()}, and {opt stop()}; its
suboptions are {cmd:width(#)} (positive whole years, default 1), {cmd:min(#)}
and {cmd:max(#)} (drop age bands outside these bounds), and
{cmd:generate(name)} (band variable, default {cmd:ageband}).

{phang}
{opt cal:endar}{cmd:(} [{cmd:,} {it:suboptions}]{cmd:)} splits on calendar period at
1 January boundaries. Suboptions: {cmd:width(#)} (years, default 1),
{cmd:anchor(#)} (first calendar year of the grid, default = earliest year in the
data), and {cmd:generate(name)} (band variable, default {cmd:calband}).

{phang}
{opt elap:sed}{cmd:(}{it:refvar} [{cmd:,} {it:suboptions}]{cmd:)} splits on time since the reference-date
variable {it:refvar} (for example a copy of study entry). It must be a
non-missing numeric daily date and must be distinct from {opt id()},
{opt start()}, and {opt stop()}. Suboptions: {cmd:width(#)} (default 1),
{cmd:unit(day|year)} (default {cmd:day}), {cmd:min(#)}/{cmd:max(#)}, and
{cmd:generate(name)} (band variable, default {cmd:fuband}). Year-unit widths
must be positive whole years.

{dlgtab:General}

{phang}
{opt noisily} displays a short summary.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Interval convention.} Bands use inclusive integer dates that abut as
{cmd:stop + 1 == next start}, so the Lexis grid tiles each person's follow-up
without gaps or overlaps.

{pstd}
{bf:Band variable names} must be distinct across axes and cannot overwrite an
existing, structural, or origin variable; supply {opt generate()} in any axis
to override the defaults.

{pstd}
{bf:Exact anniversaries.} Age and year-unit elapsed boundaries are exact
calendar anniversaries. For a 29 February origin, the anniversary is 28
February in non-leap years and 29 February in leap years. Calendar and
day-unit elapsed boundaries are also exact.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(birth_s entry_s exit_s event_s)}{p_end}
{phang3}{cmd:1 "29feb1960" "01jan2000" "31dec2005" "31dec2005"}{p_end}
{phang3}{cmd:2 "15jun1975" "01jan2018" "31dec2022" ""}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double birth_date = date(birth_s, "DMY")}{p_end}
{phang2}{cmd:. generate double start = date(entry_s, "DMY")}{p_end}
{phang2}{cmd:. generate double stop = date(exit_s, "DMY")}{p_end}
{phang2}{cmd:. generate double event_date = date(event_s, "DMY")}{p_end}
{phang2}{cmd:. generate double fu_origin = start}{p_end}
{phang2}{cmd:. format birth_date start stop event_date fu_origin %td}{p_end}
{phang2}{cmd:. drop birth_s entry_s exit_s event_s}{p_end}

{pstd}{bf:Age + calendar + time-since-entry}{p_end}
{phang2}{cmd:. tvsplit, id(id) start(start) stop(stop) ///}{p_end}
{phang3}{cmd:age(birth_date, width(10)) calendar(, width(1)) ///}{p_end}
{phang3}{cmd:elapsed(fu_origin, width(1) unit(year))}{p_end}

{pstd}{bf:Declare the inclusive split grid as survival data}{p_end}
{phang2}{cmd:. generate byte event = stop == event_date if !missing(event_date)}{p_end}
{phang2}{cmd:. replace event = 0 if missing(event)}{p_end}
{phang2}{cmd:. generate double analysis_t0 = start - 1}{p_end}
{phang2}{cmd:. stset stop, id(id) failure(event) time0(analysis_t0)}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvsplit} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_axes)}}number of axes split on{p_end}
{synopt:{cmd:r(n_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(n_observations)}}number of output rows{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(agevar)}}age band variable (if {opt age()} used){p_end}
{synopt:{cmd:r(calvar)}}calendar band variable (if {opt calendar()} used){p_end}
{synopt:{cmd:r(fuvar)}}elapsed band variable (if {opt elapsed()} used){p_end}
{synopt:{cmd:r(startvar)}}name of the interval start variable{p_end}
{synopt:{cmd:r(stopvar)}}name of the interval stop variable{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{space 2}Help: {help tvband}, {help tvage}, {help tvexpose}, {help tvmerge}, {help stsplit}
{p_end}

{hline}
