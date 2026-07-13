{smcl}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{viewerjumpto "Syntax" "tvdiagnose##syntax"}{...}
{viewerjumpto "Description" "tvdiagnose##description"}{...}
{viewerjumpto "Options" "tvdiagnose##options"}{...}
{viewerjumpto "Examples" "tvdiagnose##examples"}{...}
{viewerjumpto "Stored results" "tvdiagnose##results"}{...}
{viewerjumpto "Author" "tvdiagnose##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:tvdiagnose} {hline 2}}Diagnostic tools for time-varying exposure datasets{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvdiagnose}
{cmd:,}
{opt id(varname)}
{opt start(varname)}
{opt stop(varname)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier{p_end}
{synopt:{opt start(varname)}}period start date{p_end}
{synopt:{opt stop(varname)}}period end date{p_end}

{syntab:Report options}
{synopt:{opt cov:erage}}coverage diagnostics (requires entry/exit){p_end}
{synopt:{opt gaps}}gap analysis between periods{p_end}
{synopt:{opt over:laps}}overlap detection{p_end}
{synopt:{opt sum:marize}}exposure distribution summary (requires exposure){p_end}
{synopt:{opt all}}run coverage, gaps, overlaps, and summary when possible{p_end}
{synopt:{opt swim:lane}}plot an exposure swimlane (interval bars per person){p_end}

{syntab:Additional options}
{synopt:{opt exp:osure(varname)}}exposure variable (required for summarize){p_end}
{synopt:{opt entry(varname)}}study entry date (required for coverage){p_end}
{synopt:{opt exit(varname)}}study exit date (required for coverage){p_end}
{synopt:{opt thr:eshold(#)}}flag gaps exceeding # days (default: 30){p_end}
{synopt:{opt max:ids(#)}}maximum persons to draw in the swimlane (default: 50){p_end}
{synopt:{opt verbose}}display individual IDs and dates in diagnostic output{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvdiagnose} provides diagnostic tools for time-varying exposure datasets. It
can be used to assess data quality and identify potential issues in
time-varying datasets, whether created by {cmd:tvexpose}, {cmd:tvmerge}, or other methods.

{pstd}
The command provides four diagnostic reports:

{phang2}
{opt coverage} - Calculates the percentage of the study period covered by
the union of exposure records for each person, clipped to {opt entry()} and
{opt exit()} for that person. Overlapping records are counted once. Leading,
internal, trailing, and wholly uncovered segments are counted as coverage gaps.

{phang2}
{opt gaps} - Identifies and quantifies gaps between consecutive periods. Reports gap
durations and flags gaps exceeding the threshold.

{phang2}
{opt overlaps} - Detects overlapping periods within persons. Overlaps may indicate
data quality issues or intentional features.

{phang2}
{opt summarize} - Reports exposure frequencies, raw interval-days, and union
person-time by exposure category. Its overall denominator is the union of all
intervals within each person, so overlapping records are counted once.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier variable.

{phang}
{opt start(varname)} specifies the variable containing period start dates.

{phang}
{opt stop(varname)} specifies the variable containing period end dates.

{dlgtab:Report options}

{phang}
{opt coverage} runs coverage diagnostics, calculating the percentage of
each person's follow-up period covered by the union of records. Intervals are
clipped to the study window and overlapping days are counted once. Requires
person-constant numeric {opt entry()} and {opt exit()} variables. Coverage-gap
counts include uncovered time before the first covered interval, between
covered components, and after the last covered interval.

{phang}
{opt gaps} analyzes gaps between consecutive periods within each person. Reports gap
locations, durations, and summary statistics.

{phang}
{opt overlaps} detects overlapping periods within persons. Overlaps occur
when a period starts on or before the latest stop among prior periods. Dates
are inclusive.

{phang}
{opt summarize} displays exposure distribution statistics. Requires
numeric {opt exposure()}. {cmd:total_person_time} is the global interval union
within person; {cmd:raw_interval_person_time} is the unadjusted row sum. The
returned {cmd:r(exposure_summary)} matrix unions intervals separately within
person and exposure level. Consequently, person-time from concurrent different
levels appears in both level-specific rows, and their percentages may sum to
more than 100. Missing exposure is retained as its own level.

{phang}
{opt all} runs {opt coverage gaps overlaps}. When {opt exposure()} is supplied,
it also runs {opt summarize}; otherwise, the exposure summary is omitted.

{phang}
{opt swimlane} draws an exposure swimlane: a horizontal [start, stop] interval
bar for each person, colored by {opt exposure()} level when supplied. It is a
valid stand-alone action (no other report is required) and honors the active
graph scheme. Large datasets are capped at {opt maxids()} persons. The plot is
named {cmd:tvd_swimlane} and the data in memory is left unchanged. Numeric value
labels are used in the legend; unlabeled levels fall back to
{cmd:exposure=#}, and missing values are labeled {cmd:Missing}. Graph failure
at any preparation or rendering step does not suppress analytic diagnostics. Inspect
{cmd:r(graph_created)} and {cmd:r(graph_rc)} programmatically.

{dlgtab:Additional options}

{phang}
{opt exposure(varname)} specifies the exposure variable. A numeric variable is
required for {opt summarize}; numeric or string variables may color
{opt swimlane}.

{phang}
{opt entry(varname)} specifies the study entry date. Required for
{opt coverage} diagnostics.

{phang}
{opt exit(varname)} specifies the study exit date. Required for
{opt coverage} diagnostics.

{phang}
{opt threshold(#)} specifies the gap threshold in days. Gaps exceeding
this threshold are flagged in the output. Default is 30 days.

{phang}
{opt max:ids(#)} caps the number of persons drawn in the {opt swimlane} plot
(default 50). When the data has more persons, the first {it:#} (by grouped id)
are shown and a note is displayed.

{phang}
{opt verbose} displays individual IDs and dates in diagnostic output. Without
{cmd:verbose}, only summary counts are shown for coverage, gaps, and overlaps. When
issues are detected, a hint to use {cmd:verbose} is displayed.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(start_s stop_s) byte tv_drug str9(entry_s exit_s)}{p_end}
{phang3}{cmd:1 "01jan2020" "10jan2020" 0 "01jan2020" "31jan2020"}{p_end}
{phang3}{cmd:1 "10jan2020" "20jan2020" 1 "01jan2020" "31jan2020"}{p_end}
{phang3}{cmd:1 "25jan2020" "31jan2020" 0 "01jan2020" "31jan2020"}{p_end}
{phang3}{cmd:2 "01jan2020" "31jan2020" 2 "01jan2020" "31jan2020"}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. foreach v in start stop entry exit {c -(}}{p_end}
{phang3}{cmd:generate double `v' = date(`v'_s, "DMY")}{p_end}
{phang3}{cmd:format `v' %td}{p_end}
{phang3}{cmd:{c )-}}{p_end}
{phang2}{cmd:. drop *_s}{p_end}

{pstd}{bf:All applicable reports}{p_end}
{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) exposure(tv_drug) ///}{p_end}
{phang3}{cmd:entry(entry) exit(exit) all verbose}{p_end}

{pstd}
The equality at 10 January is an inclusive overlap; the running-maximum rule
detects it. The uncovered 21--24 January span is a four-day gap.

{pstd}{bf:Targeted checks}{p_end}
{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) gaps threshold(3) verbose}{p_end}
{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) overlaps verbose}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvdiagnose} stores the following in {cmd:r()}:

{synoptset 34 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(n_observations)}}number of observations{p_end}
{synopt:{cmd:r(coverage_run)}}1 if coverage was run; 0 otherwise{p_end}
{synopt:{cmd:r(gaps_run)}}1 if gap analysis was run; 0 otherwise{p_end}
{synopt:{cmd:r(overlaps_run)}}1 if overlap analysis was run; 0 otherwise{p_end}
{synopt:{cmd:r(summarize_run)}}1 if exposure summary was run; 0 otherwise{p_end}
{synopt:{cmd:r(mean_coverage)}}mean coverage percentage{p_end}
{synopt:{cmd:r(min_coverage)}}minimum coverage percentage{p_end}
{synopt:{cmd:r(max_coverage)}}maximum coverage percentage{p_end}
{synopt:{cmd:r(n_with_gaps)}}persons with incomplete coverage{p_end}
{synopt:{cmd:r(n_incomplete_coverage)}}alias of {cmd:r(n_with_gaps)}{p_end}
{synopt:{cmd:r(n_coverage_gaps)}}uncovered segments across study windows{p_end}
{synopt:{cmd:r(n_gaps)}}internal gaps between observed periods{p_end}
{synopt:{cmd:r(n_gap_ids)}}persons with internal gaps{p_end}
{synopt:{cmd:r(mean_gap)}}mean internal-gap duration in days{p_end}
{synopt:{cmd:r(median_gap)}}median internal-gap duration in days{p_end}
{synopt:{cmd:r(max_gap)}}maximum internal-gap duration in days{p_end}
{synopt:{cmd:r(n_large_gaps)}}gaps exceeding {opt threshold()}{p_end}
{synopt:{cmd:r(n_large_gap_ids)}}persons with a gap exceeding {opt threshold()}{p_end}
{synopt:{cmd:r(n_overlaps)}}number of overlapping periods{p_end}
{synopt:{cmd:r(n_overlap_ids)}}persons with overlapping periods{p_end}
{synopt:{cmd:r(n_ids_affected)}}alias of {cmd:r(n_overlap_ids)}{p_end}
{synopt:{cmd:r(total_person_time)}}global union person-time in days{p_end}
{synopt:{cmd:r(raw_interval_person_time)}}sum of inclusive row lengths{p_end}
{synopt:{cmd:r(overlap_excess_person_time)}}raw days minus union days{p_end}
{synopt:{cmd:r(n_exposure_levels)}}rows in {cmd:r(exposure_summary)}{p_end}
{synopt:{cmd:r(graph_requested)}}1 if {opt swimlane} was requested{p_end}
{synopt:{cmd:r(graph_created)}}1 if the swimlane graph was created{p_end}
{synopt:{cmd:r(graph_rc)}}swimlane return code{p_end}
{synopt:{cmd:r(graph_ids_total)}}persons available to the swimlane{p_end}
{synopt:{cmd:r(graph_ids_plotted)}}persons included in the swimlane{p_end}
{synopt:{cmd:r(graph_truncated)}}1 if {opt maxids()} truncated the swimlane{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(exposure_summary)}}exposure-level union summary matrix{p_end}

{pstd}
Its columns are {cmd:exposure raw_days person_days percent n_periods}.

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(id)}}name of ID variable{p_end}
{synopt:{cmd:r(start)}}name of start variable{p_end}
{synopt:{cmd:r(stop)}}name of stop variable{p_end}
{synopt:{cmd:r(graph_name)}}{cmd:tvd_swimlane} when a graph was created{p_end}

{pstd}
Report-specific scalars are returned as exact zero when a report was not run
or when a requested report found no events. Use the corresponding
{cmd:*_run} flag to distinguish those states.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
