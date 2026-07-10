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
{synopt:{opt age(dobvar}[{cmd:,} {it:asub}]{cmd:)}}split on age (relative to date of birth){p_end}
{synopt:{opt cal:endar(}[{cmd:,} {it:csub}]{cmd:)}}split on calendar period{p_end}
{synopt:{opt elap:sed(refvar}[{cmd:,} {it:esub}]{cmd:)}}split on time since a reference date{p_end}
{synoptline}

{pstd}
where the per-axis suboptions are

{p 8 12 2}{it:asub} {space 3}= {opt w:idth(#)} {opt min(#)} {opt max(#)} {opt gen:erate(name)}{p_end}
{p 8 12 2}{it:csub} {space 3}= {opt w:idth(#)} {opt anchor(#)} {opt gen:erate(name)}{p_end}
{p 8 12 2}{it:esub} {space 3}= {opt w:idth(#)} {opt unit(day|year)} {opt min(#)} {opt max(#)} {opt gen:erate(name)}{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvsplit} performs multi-timescale (Lexis) splitting: it splits each
{opt start()}-{opt stop()} interval in memory simultaneously on up to three time
axes so that every output sub-interval lies in exactly one band on every
requested axis. The result is ready for age- and period-adjusted Cox or Poisson
models and is equivalent to repeated Stata {helpb stsplit} or R
{cmd:Epi::splitMulti} multi-timescale splitting.

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
{opt start(varname)} and {opt stop(varname)} specify the intervals to split.{...}
They are overwritten in place with the split bounds (the number of rows grows).{...}
Both must be non-missing daily Stata dates.

{dlgtab:Axes (specify at least one)}

{phang}
{opt age(dobvar} [{cmd:,} {it:suboptions}]{cmd:)} splits on age relative to the
date-of-birth variable {it:dobvar}. Suboptions: {opt width(#)} (years, default 1),
{opt min(#)}/{opt max(#)} (drop age bands outside these bounds), and
{opt generate(name)} (band variable, default {cmd:ageband}).

{phang}
{opt calendar(} [{cmd:,} {it:suboptions}]{cmd:)} splits on calendar period at
1 January boundaries. Suboptions: {opt width(#)} (years, default 1),
{opt anchor(#)} (first calendar year of the grid, default = earliest year in the
data), and {opt generate(name)} (band variable, default {cmd:calband}).

{phang}
{opt elapsed(refvar} [{cmd:,} {it:suboptions}]{cmd:)} splits on time since the
reference-date variable {it:refvar} (for example study entry). Suboptions:
{opt width(#)} (default 1), {opt unit(day|year)} (default {cmd:day}),
{opt min(#)}/{opt max(#)}, and {opt generate(name)} (band variable, default
{cmd:fuband}).

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
{bf:Band variable names} must be distinct across axes; supply
{opt generate()} in any axis to override the defaults.

{pstd}
{bf:Age precision.} Age boundaries use {cmd:round(dob + age*365.25)} (see
{helpb tvband}); calendar and day-unit elapsed boundaries are exact.


{marker examples}{...}
{title:Examples}

{pstd}{bf:Example 1: age + calendar + time-since-entry}{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvsplit, id(id) start(study_entry) stop(study_exit) ///}{p_end}
{phang3}{cmd:age(dob, width(10)) calendar(, width(1)) elapsed(study_entry, width(1) unit(year))}{p_end}

{pstd}{bf:Example 2: split an existing time-varying dataset on two axes}{p_end}
{phang2}{cmd:. * tv_data already has id/start/stop intervals from tvexpose}{p_end}
{phang2}{cmd:. tvsplit, id(id) start(start) stop(stop) age(dob, width(5)) calendar(, width(1))}{p_end}

{pstd}{bf:Example 3: declare survival data on the split grid}{p_end}
{phang2}{cmd:. tvsplit, id(id) start(study_entry) stop(study_exit) calendar(, width(1))}{p_end}
{phang2}{cmd:. stset study_exit, id(id) failure(event) origin(time study_entry) enter(time study_entry)}{p_end}


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
{space 2}Help:  {help tvband}, {help tvage}, {help tvexpose}, {help tvmerge}, {help stsplit}
{p_end}

{hline}
