{smcl}
{* *! version 1.0.1  31dec2025}{...}
{vieweralsosee "[D] generate" "help generate"}{...}
{vieweralsosee "[D] dates and times" "help datetime"}{...}
{vieweralsosee "icdexpand" "help icdexpand"}{...}
{vieweralsosee "migrations" "help migrations"}{...}
{viewerjumpto "Syntax" "dateparse##syntax"}{...}
{viewerjumpto "Description" "dateparse##description"}{...}
{viewerjumpto "Subcommands" "dateparse##subcommands"}{...}
{viewerjumpto "Options" "dateparse##options"}{...}
{viewerjumpto "Examples" "dateparse##examples"}{...}
{viewerjumpto "Stored results" "dateparse##results"}{...}
{viewerjumpto "Author" "dateparse##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:dateparse} {hline 2}}Date utilities for Swedish registry cohort studies{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Parse date strings to Stata date format:

{p 8 17 2}
{cmd:dateparse parse}
{cmd:,} {opt datestring(string)} [{opt format(string)}]

{pstd}
Calculate lookback or followup windows:

{p 8 17 2}
{cmd:dateparse window}
{varname}
{cmd:,} {opt lookback(#)} | {opt followup(#)} [{it:window_options}]

{pstd}
Validate date range:

{p 8 17 2}
{cmd:dateparse validate}
{cmd:,} {opt start(string)} {opt end(string)} [{opt format(string)}]

{pstd}
Check if dates fall within window:

{p 8 17 2}
{cmd:dateparse inwindow}
{varname}
{cmd:,} {opt start(string)} {opt end(string)} {opt generate(name)} [{opt replace}]

{pstd}
Determine which year files are needed:

{p 8 17 2}
{cmd:dateparse filerange}
{cmd:,} {opt index_start(string)} {opt index_end(string)} [{it:filerange_options}]


{synoptset 24 tabbed}{...}
{synopthdr:window_options}
{synoptline}
{syntab:Required (one of)}
{synopt:{opt lookback(#)}}lookback window in days{p_end}
{synopt:{opt followup(#)}}followup window in days{p_end}

{syntab:Optional}
{synopt:{opt gen:erate(names)}}names for window start and end variables{p_end}
{synopt:{opt replace}}replace existing variables if they exist{p_end}
{synoptline}

{synoptset 24 tabbed}{...}
{synopthdr:filerange_options}
{synoptline}
{syntab:Required}
{synopt:{opt index_start(string)}}earliest index date (YYYY-MM-DD){p_end}
{synopt:{opt index_end(string)}}latest index date (YYYY-MM-DD){p_end}

{syntab:Optional}
{synopt:{opt lookback(#)}}lookback window in days; default is {cmd:0}{p_end}
{synopt:{opt followup(#)}}followup window in days; default is {cmd:0}{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:dateparse} provides utilities for date manipulation in Swedish registry-based cohort
studies. It handles five main operations:

{phang2}1. {bf:parse}: Convert date strings to Stata date values, with automatic detection
of Swedish ISO format (YYYY-MM-DD or YYYYMMDD).{p_end}

{phang2}2. {bf:window}: Calculate lookback or followup window dates from an index date
variable, essential for defining comorbidity assessment periods or followup intervals.{p_end}

{phang2}3. {bf:validate}: Ensure that start dates precede end dates and calculate time spans.{p_end}

{phang2}4. {bf:inwindow}: Create binary indicators for dates falling within specified
windows, useful for identifying events in time windows.{p_end}

{phang2}5. {bf:filerange}: Determine which year-specific registry files (e.g., out_2015.dta,
out_2016.dta) need to be loaded based on index dates and lookback/followup periods.{p_end}

{pstd}
{bf:Swedish registry considerations:}

{pstd}
Swedish health registries use ISO 8601 date format as standard:

{phang2}- Dashed format: {cmd:2020-01-15}{p_end}
{phang2}- Compact format: {cmd:20200115}{p_end}

{pstd}
The {cmd:parse} subcommand defaults to YMD (year-month-day) format to correctly handle
Swedish dates. Using DMY format by default would cause silent data corruption for dates
like "2025-09-26" where 2025 would be interpreted as day 2025 (invalid).


{marker subcommands}{...}
{title:Subcommands}

{dlgtab:parse}

{pstd}
Converts date strings to Stata numeric date values (%td format). Automatically detects
common date formats with preference for Swedish ISO format.

{pstd}
{bf:Format detection:}

{phang2}- {cmd:YYYY-MM-DD} (ISO with dashes): Detected as YMD{p_end}
{phang2}- {cmd:YYYYMMDD} (ISO compact): Detected as YMD{p_end}
{phang2}- {cmd:DD/MM/YYYY} (European): Detected as DMY{p_end}
{phang2}- {cmd:01jan2020} (Stata text): Detected as DMY{p_end}

{pstd}
If automatic detection fails, you can specify the format explicitly.

{dlgtab:window}

{pstd}
Calculates lookback or followup windows from an index date variable. For lookback windows,
creates dates before the index; for followup windows, creates dates after the index.

{pstd}
{bf:Lookback window:} From (indexdate - N) to (indexdate - 1)

{pstd}
Common use: Assessing comorbidities in the year before diagnosis.

{pstd}
{bf:Followup window:} From (indexdate + 1) to (indexdate + N)

{pstd}
Common use: Tracking outcomes in the years after treatment initiation.

{dlgtab:validate}

{pstd}
Parses and validates a date range. Ensures start date is before or equal to end date,
and calculates the span in days and years.

{pstd}
Useful for validating user input or checking study period definitions.

{dlgtab:inwindow}

{pstd}
Creates a binary indicator (0/1) for whether a date variable falls within a specified
window. The window boundaries can be either constants (date strings) or variables.

{pstd}
Missing dates are coded as missing in the indicator variable.

{dlgtab:filerange}

{pstd}
Determines which calendar years of registry files need to be loaded based on the index
date range and lookback/followup periods.

{pstd}
{bf:Context:} Swedish outpatient and prescription registries are split by year
(out_2015.dta, out_2016.dta, rx_2015.dta, etc.). This subcommand calculates the year
range needed for analysis.

{pstd}
{bf:Example:} If your cohort has index dates from 2015-2018 with a 365-day lookback,
you need files from 2014-2018 (accounting for lookback into 2014).


{marker options}{...}
{title:Options}

{dlgtab:parse}

{phang}
{opt datestring(string)} specifies the date string to parse. Can be in ISO format
(YYYY-MM-DD or YYYYMMDD), European format (DD/MM/YYYY), or Stata text format (01jan2020).
Required.

{phang}
{opt format(string)} explicitly specifies the date format: "YMD", "DMY", or "MDY".
If not specified, the format is automatically detected with preference for YMD (Swedish ISO).

{dlgtab:window}

{phang}
{opt lookback(#)} specifies the number of days to look back from the index date.
The resulting window runs from (indexdate - N) to (indexdate - 1). Either {opt lookback()}
or {opt followup()} must be specified.

{phang}
{opt followup(#)} specifies the number of days to follow up from the index date.
The resulting window runs from (indexdate + 1) to (indexdate + N). Either {opt lookback()}
or {opt followup()} must be specified.

{phang}
{opt generate(names)} specifies variable names for the window boundaries. Provide two
names: the first for window start, the second for window end. If only one name is provided,
only the start variable is created.

{phang}
{opt replace} allows existing variables to be replaced.

{dlgtab:validate}

{phang}
{opt start(string)} specifies the start date as a string. Required.

{phang}
{opt end(string)} specifies the end date as a string. Required.

{phang}
{opt format(string)} specifies the date format if not auto-detected.

{dlgtab:inwindow}

{phang}
{opt start(string)} specifies the window start. Can be a date string (e.g., "2015-01-01")
or a variable name containing dates. Required.

{phang}
{opt end(string)} specifies the window end. Can be a date string or variable name. Required.

{phang}
{opt generate(name)} specifies the name for the binary indicator variable. Required.

{phang}
{opt replace} allows an existing variable to be replaced.

{dlgtab:filerange}

{phang}
{opt index_start(string)} specifies the earliest index date in the cohort (YYYY-MM-DD).
Required.

{phang}
{opt index_end(string)} specifies the latest index date in the cohort (YYYY-MM-DD).
Required.

{phang}
{opt lookback(#)} specifies the lookback period in days. Default is 0.

{phang}
{opt followup(#)} specifies the followup period in days. Default is 0.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Parse Swedish ISO date}

{phang2}{cmd:. dateparse parse, datestring("2020-01-15")}{p_end}
{phang2}{cmd:. display r(date)}{p_end}
{phang2}{cmd:. display %td r(date)}{p_end}

{pstd}
{bf:Example 2: Parse compact ISO date}

{phang2}{cmd:. dateparse parse, datestring("20200115")}{p_end}
{phang2}{cmd:. local mydate = r(date)}{p_end}
{phang2}{cmd:. display "Date: " %td `mydate'}{p_end}

{pstd}
{bf:Example 3: Calculate 1-year lookback window for comorbidity assessment}

{phang2}{cmd:. * Assume indexdate is MS diagnosis date}{p_end}
{phang2}{cmd:. dateparse window indexdate, lookback(365) generate(comorb_start comorb_end)}{p_end}
{phang2}{cmd:. list id indexdate comorb_start comorb_end in 1/5}{p_end}

{pstd}
{bf:Example 4: Calculate 5-year followup window}

{phang2}{cmd:. dateparse window ms_onset_date, followup(1826) generate(fu_start fu_end)}{p_end}
{phang2}{cmd:. * 1826 days = 5 years * 365.25 days/year}{p_end}

{pstd}
{bf:Example 5: Validate study period}

{phang2}{cmd:. dateparse validate, start("2010-01-01") end("2020-12-31")}{p_end}
{phang2}{cmd:. display "Study span: " r(span_years) " years"}{p_end}
{phang2}{cmd:. display "Study span: " r(span_days) " days"}{p_end}

{pstd}
{bf:Example 6: Create indicator for events in lookback window}

{phang2}{cmd:. * Find hospitalizations in the year before MS diagnosis}{p_end}
{phang2}{cmd:. dateparse window ms_dx_date, lookback(365) generate(lb_start lb_end)}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Merge with hospitalization data (assume hosp_date exists)}{p_end}
{phang2}{cmd:. dateparse inwindow hosp_date, start(lb_start) end(lb_end) generate(in_lookback)}{p_end}
{phang2}{cmd:. tab in_lookback}{p_end}

{pstd}
{bf:Example 7: Find events within fixed calendar period}

{phang2}{cmd:. dateparse inwindow birth_date, start("1980-01-01") end("1989-12-31") ///}{p_end}
{phang2}{cmd:.     generate(born_1980s)}{p_end}
{phang2}{cmd:. tab born_1980s}{p_end}

{pstd}
{bf:Example 8: Determine which outpatient files to load}

{phang2}{cmd:. * Cohort with index dates 2015-2018, 2-year lookback}{p_end}
{phang2}{cmd:. dateparse filerange, index_start("2015-01-01") index_end("2018-12-31") ///}{p_end}
{phang2}{cmd:.     lookback(730)}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. display "Load files from " r(file_start_year) " to " r(file_end_year)}{p_end}
{phang2}{cmd:. * Result: Load files from 2013 to 2018}{p_end}

{pstd}
{bf:Example 9: Typical workflow for cohort study with comorbidities}

{phang2}{cmd:. * Load cohort with MS diagnosis dates}{p_end}
{phang2}{cmd:. use ms_cohort, clear}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Create 1-year lookback window for comorbidity assessment}{p_end}
{phang2}{cmd:. dateparse window ms_index_date, lookback(365) generate(comorb_start comorb_end)}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Determine which outpatient files are needed}{p_end}
{phang2}{cmd:. summarize ms_index_date, format}{p_end}
{phang2}{cmd:. local earliest = string(r(min), "%tdCCYY-NN-DD")}{p_end}
{phang2}{cmd:. local latest = string(r(max), "%tdCCYY-NN-DD")}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. dateparse filerange, index_start("`earliest'") index_end("`latest'") lookback(365)}{p_end}
{phang2}{cmd:. local year_start = r(file_start_year)}{p_end}
{phang2}{cmd:. local year_end = r(file_end_year)}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. display "Need to load outpatient files from `year_start' to `year_end'"}{p_end}

{pstd}
{bf:Example 10: Create multiple time windows for analysis}

{phang2}{cmd:. * Create multiple windows from index date}{p_end}
{phang2}{cmd:. dateparse window index_date, lookback(365) generate(year1_before_start year1_before_end)}{p_end}
{phang2}{cmd:. dateparse window index_date, followup(365) generate(year1_after_start year1_after_end)}{p_end}
{phang2}{cmd:. dateparse window index_date, followup(1826) generate(year5_after_start year5_after_end)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:dateparse parse} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(date)}}Stata numeric date value (%td){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(datestr)}}original date string{p_end}


{pstd}
{cmd:dateparse window} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(lookback)}}lookback period in days{p_end}
{synopt:{cmd:r(followup)}}followup period in days{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(startvar)}}name of window start variable (if generated){p_end}
{synopt:{cmd:r(endvar)}}name of window end variable (if generated){p_end}


{pstd}
{cmd:dateparse validate} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(start_date)}}Stata date value for start{p_end}
{synopt:{cmd:r(end_date)}}Stata date value for end{p_end}
{synopt:{cmd:r(span_days)}}number of days between dates (inclusive){p_end}
{synopt:{cmd:r(span_years)}}number of years (rounded to 0.1){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(start_str)}}original start date string{p_end}
{synopt:{cmd:r(end_str)}}original end date string{p_end}


{pstd}
{cmd:dateparse inwindow} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_inwindow)}}number of observations within window{p_end}


{pstd}
{cmd:dateparse filerange} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(index_start_year)}}year of earliest index date{p_end}
{synopt:{cmd:r(index_end_year)}}year of latest index date{p_end}
{synopt:{cmd:r(file_start_year)}}first year of files needed (accounting for lookback){p_end}
{synopt:{cmd:r(file_end_year)}}last year of files needed (accounting for followup){p_end}
{synopt:{cmd:r(lookback_years)}}lookback period in years (rounded up){p_end}
{synopt:{cmd:r(followup_years)}}followup period in years (rounded up){p_end}


{marker author}{...}
{title:Author}

{pstd}
Tim Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden

{pstd}
Part of the setools package for Swedish registry research.{p_end}


{marker alsosee}{...}
{title:Also see}

{pstd}
{help icdexpand:icdexpand} - ICD-10 code utilities for Swedish registry research{p_end}
{pstd}
{help migrations:migrations} - Process Swedish migration registry data{p_end}
{pstd}
{help sustainedss:sustainedss} - Compute sustained EDSS progression dates{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Swedish-Cohorts":Swedish-Cohorts on GitHub}{p_end}
