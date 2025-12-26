{smcl}
{* *! version 1.0.0  2025/12/26}{...}
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

{syntab:Additional options}
{synopt:{opt exp:osure(varname)}}exposure variable (required for summarize){p_end}
{synopt:{opt entry(varname)}}study entry date (required for coverage){p_end}
{synopt:{opt exit(varname)}}study exit date (required for coverage){p_end}
{synopt:{opt thr:eshold(#)}}flag gaps exceeding # days (default: 30){p_end}
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


{marker examples}{...}
{title:Examples}

{pstd}
Check coverage after creating time-varying exposure data:

{phang2}{cmd:. tvexpose using medications, id(id) start(rx_start) stop(rx_stop) exposure(drug) reference(0) entry(entry) exit(exit)}{p_end}
{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) entry(study_entry) exit(study_exit) coverage}{p_end}

{pstd}
Run all diagnostics:

{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) exposure(tv_exposure) entry(study_entry) exit(study_exit) all}{p_end}

{pstd}
Check for gaps exceeding 90 days:

{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) gaps threshold(90)}{p_end}

{pstd}
Check for overlapping periods:

{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) overlaps}{p_end}


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

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
Email: timothy.copeland@ki.se
