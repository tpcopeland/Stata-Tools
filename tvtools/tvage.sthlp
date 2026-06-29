{smcl}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "[ST] stset" "help stset"}{...}
{viewerjumpto "Syntax" "tvage##syntax"}{...}
{viewerjumpto "Description" "tvage##description"}{...}
{viewerjumpto "Options" "tvage##options"}{...}
{viewerjumpto "Remarks" "tvage##remarks"}{...}
{viewerjumpto "Examples" "tvage##examples"}{...}
{viewerjumpto "Stored results" "tvage##results"}{...}
{viewerjumpto "Author" "tvage##author"}{...}

{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:tvage} {hline 2}}Generate time-varying age intervals for survival analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvage}{cmd:,}
{opt id(varname)}
{opt dob(varname)}
{opt entry(varname)}
{opt exit(varname)}
[{opt gen:erate(name)}
{opt startgen(name)}
{opt stopgen(name)}
{opt groupwidth(#)}
{opt minage(#)}
{opt maxage(#)}
{opt saveas(filename)}
{opt replace}
{opt noisily}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvage} creates a long-format dataset with time-varying age intervals for
survival analysis. Each observation represents a period where an individual was
at a specific age (or age group), enabling age-adjusted Cox models with
time-varying age.

{pstd}
The command expands person-level data into multiple records, with each record
covering the time period during which the person was at a given age. Age groups
can be specified using the {opt groupwidth()} option.

{pstd}
Start and stop dates are calculated to begin at the later of study entry or
the person's birthday at that age, and end at the earlier of study exit or
the day before their next birthday. Age is calculated using a 365.25-day
year approximation, which may differ from exact birthdays by ±1 day.

{pstd}
All date variables must be non-missing. The command will exit with an error
if any observation has missing values in {opt dob()}, {opt entry()},
or {opt exit()}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier variable.
(Legacy synonym: {opt idvar()}.)

{phang}
{opt dob(varname)} specifies the date of birth variable (Stata date format).
(Legacy synonym: {opt dobvar()}.)

{phang}
{opt entry(varname)} specifies the study entry date variable (Stata date format).
(Legacy synonym: {opt entryvar()}.)

{phang}
{opt exit(varname)} specifies the study exit date variable (Stata date format).
(Legacy synonym: {opt exitvar()}.)

{pstd}
The {opt idvar()}, {opt dobvar()}, {opt entryvar()}, and {opt exitvar()}
spellings remain accepted for backward compatibility; specify only one
spelling per option.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name for the generated age variable.
Default is {cmd:age_tv}.

{phang}
{opt startgen(name)} specifies the name for the interval start date variable.
Default is {cmd:age_start}.

{phang}
{opt stopgen(name)} specifies the name for the interval stop date variable.
Default is {cmd:age_stop}.

{phang}
{opt groupwidth(#)} specifies the width of age groups in years. For example,
{cmd:groupwidth(5)} creates 5-year age groups (40-44, 45-49, etc.).
Default is 1 (single-year continuous ages with no labels).

{phang}
{opt minage(#)} specifies the minimum age to include. Ages below this are set
to the minimum. Default is 0.

{phang}
{opt maxage(#)} specifies the maximum age to include. Ages above this are
truncated. Default is 120.

{phang}
{opt saveas(filename)} saves the expanded dataset to the specified file and
restores the original data. If not specified, the expanded data replaces
the current data in memory.

{phang}
{opt replace} allows overwriting an existing file when using {opt saveas()}.

{phang}
{opt noisily} displays progress and summary information.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to use tvage}

{pstd}
Use {cmd:tvage} when age itself should be a time-varying covariate in your
survival model. Instead of adjusting for age at baseline, {cmd:tvage} creates
intervals where each person's data is split at age boundaries, so a Cox
model can use age as a time-varying variable.

{pstd}
{bf:Integration with the tvtools workflow}

{pstd}
The output of {cmd:tvage} has the same id/start/stop structure as
{helpb tvexpose}, so you can merge age bands with exposure intervals using
{helpb tvmerge}. See Example 4 below.

{pstd}
{bf:Precision note}

{pstd}
Age is computed using a 365.25-day year approximation, which may differ from
exact birthdays by up to 1 day. Start and stop dates are rounded to integer
Stata dates for compatibility with interval-based survival analysis.

{pstd}
{bf:Input requirements}

{pstd}
{cmd:tvage} requires exactly one observation per person. All date variables
({opt dob()}, {opt entry()}, {opt exit()}) must be non-missing Stata
daily dates. Datetime formats ({cmd:%tc}/{cmd:%tC}) are not supported;
convert with {cmd:gen daily = dofc(datetime)}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: 5-year age groups}

{pstd}
Create 5-year age bands for persons aged 40-80, then merge with exposure data:

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}

{phang2}{cmd:. tvage, id(id) dob(dob) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:groupwidth(5) minage(40) maxage(80) ///}{p_end}
{phang3}{cmd:saveas(age_tv.dta) replace noisily}{p_end}

{pstd}
Each person is expanded into one row per 5-year age band they pass through
during follow-up (e.g., 40-44, 45-49, ...). The {cmd:saveas()} option saves
the result to a file and restores the original data in memory.


{pstd}
{bf:Example 2: Single-year ages (continuous)}

{pstd}
Create one row per person-year of age with no grouping labels:

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}

{phang2}{cmd:. tvage, id(id) dob(dob) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:groupwidth(1) noisily}{p_end}

{pstd}
With {cmd:groupwidth(1)} (the default), {cmd:age_tv} contains each integer age
traversed during follow-up. Suitable for continuous age adjustment in Cox models.


{pstd}
{bf:Example 3: Custom variable names and 10-year groups}

{pstd}
Specify output variable names and use wide age bands:

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}

{phang2}{cmd:. tvage, id(id) dob(dob) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:groupwidth(10) generate(age_group) startgen(age_start) stopgen(age_end) noisily}{p_end}

{pstd}
Creates variables {cmd:age_group}, {cmd:age_start}, and {cmd:age_end} instead of
the defaults ({cmd:age_tv}, {cmd:age_start}, {cmd:age_stop}).


{pstd}
{bf:Example 4: Integration with tvmerge}

{pstd}
Age bands have the same start/stop structure as {helpb tvexpose} output, so they
can be merged with other time-varying datasets using {helpb tvmerge}:

{phang2}{cmd:. * Step 1: Create exposure intervals}{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvexpose using _data/tv_antidep_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(tv_antidep.dta) replace}{p_end}
{phang2}{cmd:. use tv_antidep.dta, clear}{p_end}
{phang2}{cmd:. rename tv_exposure drug_class}{p_end}
{phang2}{cmd:. save tv_antidep.dta, replace}{p_end}

{phang2}{cmd:. * Step 2: Create age bands}{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvage, id(id) dob(dob) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:groupwidth(5) saveas(age_tv.dta) replace noisily}{p_end}

{phang2}{cmd:. * Step 3: Merge exposure intervals with age bands}{p_end}
{phang2}{cmd:. tvmerge tv_antidep.dta age_tv.dta, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start age_start) stop(rx_stop age_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class age_tv)}{p_end}

{pstd}
The merged dataset has one row per period where both exposure status and age
band are constant, ready for age-stratified or age-adjusted analysis.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvage} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(n_observations)}}total number of observations (person-age periods){p_end}
{synopt:{cmd:r(groupwidth)}}age group width used{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of age variable{p_end}
{synopt:{cmd:r(startvar)}}name of start date variable{p_end}
{synopt:{cmd:r(stopvar)}}name of stop date variable{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{space 2}Help:  {help tvexpose}, {help tvmerge}, {help stset}
{p_end}

{hline}
