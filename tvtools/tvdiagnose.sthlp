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
{synopt:{opt all}}run all diagnostic reports{p_end}
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
{cmd:tvdiagnose} provides diagnostic tools for time-varying exposure datasets.
It can be used to assess data quality and identify potential issues in
time-varying datasets, whether created by {cmd:tvexpose}, {cmd:tvmerge},
or other methods.

{pstd}
The command provides four diagnostic reports:

{phang2}
{opt coverage} - Calculates the percentage of the study period covered by
exposure records for each person. Identifies persons with incomplete coverage.

{phang2}
{opt gaps} - Identifies and quantifies gaps between consecutive periods.
Reports gap durations and flags gaps exceeding the threshold.

{phang2}
{opt overlaps} - Detects overlapping periods within persons.
Overlaps may indicate data quality issues or intentional features.

{phang2}
{opt summarize} - Provides exposure distribution statistics including
frequencies and person-time by exposure category.


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
each person's follow-up period that is covered by records. Requires
{opt entry()} and {opt exit()} options.

{phang}
{opt gaps} analyzes gaps between consecutive periods within each person.
Reports gap locations, durations, and summary statistics.

{phang}
{opt overlaps} detects overlapping periods within persons. Overlaps occur
when a period starts before the previous period ends.

{phang}
{opt summarize} displays exposure distribution statistics. Requires
{opt exposure()} option.

{phang}
{opt all} runs all diagnostic reports. Equivalent to specifying
{opt coverage gaps overlaps summarize}.

{phang}
{opt swimlane} draws an exposure swimlane: a horizontal [start, stop] interval
bar for each person, colored by {opt exposure()} level when supplied. It is a
valid stand-alone action (no other report is required) and honors the active
graph scheme. Large datasets are capped at {opt maxids()} persons. The plot is
named {cmd:tvd_swimlane} and the data in memory is left unchanged.

{dlgtab:Additional options}

{phang}
{opt exposure(varname)} specifies the exposure variable. Required for
the {opt summarize} report.

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
{opt verbose} displays individual IDs and dates in diagnostic output.
Without {cmd:verbose}, only summary counts are shown for coverage, gaps,
and overlaps. When issues are detected, a hint to use {cmd:verbose} is
displayed.


{marker examples}{...}
{title:Examples}

{pstd}
The examples below follow a typical workflow: first create time-varying data
with {helpb tvexpose}, then diagnose the result with {cmd:tvdiagnose}.

{pstd}
{bf:Example 1: Coverage diagnostics}

{pstd}
Check what fraction of each person's follow-up is covered by exposure records:

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}

{phang2}{cmd:. tvexpose using _data/tv_antidep_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) keepdates}{p_end}

{phang2}{cmd:. tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) coverage}{p_end}

{pstd}
Reports mean/min/max coverage and the number of persons with gaps.
Add {cmd:verbose} to list per-person details.

{pstd}
{bf:Example 2: Run all diagnostics}

{pstd}
Combine all four reports in a single call:

{phang2}{cmd:. tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure) entry(study_entry) exit(study_exit) all verbose}{p_end}

{pstd}
{cmd:all} is equivalent to specifying {cmd:coverage gaps overlaps summarize}.
The {cmd:verbose} option shows individual IDs and dates for every issue found.

{pstd}
{bf:Example 3: Flag large gaps}

{pstd}
Identify gaps exceeding 90 days between consecutive exposure periods:

{phang2}{cmd:. tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:gaps threshold(90)}{p_end}

{pstd}
The default threshold is 30 days. Gaps below the threshold still appear in
the gap count but are not flagged as warnings.

{pstd}
{bf:Example 4: Check for overlapping periods}

{pstd}
Detect periods where a person has two overlapping records:

{phang2}{cmd:. tvdiagnose, id(id) start(rx_start) stop(rx_stop) overlaps verbose}{p_end}

{pstd}
Overlapping periods in {helpb tvexpose} output usually indicate that the input
episode data had concurrent exposures. Use {cmd:verbose} to inspect specific
records and decide whether to re-run {cmd:tvexpose} with overlap-handling
options such as {cmd:layer}, {cmd:priority()}, or {cmd:split}.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvdiagnose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(n_observations)}}number of observations{p_end}
{synopt:{cmd:r(mean_coverage)}}mean coverage percentage (if coverage){p_end}
{synopt:{cmd:r(n_with_gaps)}}persons with incomplete coverage (if coverage){p_end}
{synopt:{cmd:r(n_gaps)}}total number of gaps (if gaps){p_end}
{synopt:{cmd:r(mean_gap)}}mean gap duration in days (if gaps){p_end}
{synopt:{cmd:r(max_gap)}}maximum gap duration in days (if gaps){p_end}
{synopt:{cmd:r(n_large_gaps)}}gaps exceeding threshold (if gaps){p_end}
{synopt:{cmd:r(n_overlaps)}}number of overlapping periods (if overlaps){p_end}
{synopt:{cmd:r(n_ids_affected)}}persons with overlaps (if overlaps){p_end}
{synopt:{cmd:r(total_person_time)}}total person-time in days (if summarize){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(id)}}name of ID variable{p_end}
{synopt:{cmd:r(start)}}name of start variable{p_end}
{synopt:{cmd:r(stop)}}name of stop variable{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
