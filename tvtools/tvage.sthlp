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
the day before their next birthday. Ages and boundaries use exact calendar
anniversaries. A 29 February birthday advances on 28 February in non-leap
years and on 29 February in leap years.

{pstd}
All date variables must be non-missing. The command will exit with an error
if any observation has missing values in {opt id()}, {opt dob()}, {opt entry()},
or {opt exit()}.

{pstd}
{bf:Important}: the output dataset retains only the identifier and the three
generated interval variables ({opt id()}, {opt generate()}, {opt startgen()},
and {opt stopgen()}). {bf:All other variables in memory -- sex and other}
{bf:baseline covariates -- are dropped.} Merge the age intervals back onto your
covariates by {opt id()}, or save the covariates before running {cmd:tvage}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier variable. (Legacy
synonym: {opt idvar()}.)

{phang}
{opt dob(varname)} specifies the date of birth variable (Stata date format). (Legacy
synonym: {opt dobvar()}.)

{phang}
{opt entry(varname)} specifies the study entry date variable (Stata date
format). (Legacy synonym: {opt entryvar()}.)

{phang}
{opt exit(varname)} specifies the study exit date variable (Stata date
format). (Legacy synonym: {opt exitvar()}.)

{pstd}
The {opt idvar()}, {opt dobvar()}, {opt entryvar()}, and {opt exitvar()}
spellings remain accepted for backward compatibility; specify only one
spelling per option.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name for the generated age variable. Default is
{cmd:age_tv}.

{phang}
{opt startgen(name)} specifies the name for the interval start date
variable. Default is {cmd:age_start}.

{phang}
{opt stopgen(name)} specifies the name for the interval stop date variable. Default
is {cmd:age_stop}.

{phang}
{opt groupwidth(#)} specifies the width of age groups in years. For example,
{cmd:groupwidth(5)} creates 5-year age groups (40-44, 45-49, etc.). Default is 1
(single-year continuous ages with no labels).

{phang}
{opt minage(#)} left-truncates follow-up at the exact anniversary on which the
person reaches this age. Earlier person-time is removed; a person whose exit is
before that boundary contributes no output rows. Default is 0.

{phang}
{opt maxage(#)} right-truncates follow-up at the day before the exact
anniversary after the requested maximum age. Later person-time is removed; a
person whose entry is after that boundary contributes no output rows. Default
is 120.

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
{bf:Anniversary convention}

{pstd}
Age is computed from exact calendar anniversaries. For a person born on 29
February, age advances on 28 February in non-leap years and 29 February in
leap years. Start and stop dates are integer Stata daily dates.

{pstd}
{bf:Input requirements}

{pstd}
{cmd:tvage} requires exactly one observation per person. All date variables ({opt dob()},
{opt entry()}, {opt exit()}) must be non-missing Stata daily dates. Datetime formats
({cmd:%tc}/{cmd:%tC}) are not supported; convert with {cmd:gen daily = dofc(datetime)}.


{marker examples}{...}
{title:Examples}

{pstd}
Create a reusable inline cohort; each example below starts from this tempfile:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(birth_s entry_s exit_s)}{p_end}
{phang3}{cmd:1 "29feb1960" "01jan2000" "31dec2005"}{p_end}
{phang3}{cmd:2 "15jun1975" "01jan2018" "31dec2022"}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double birth_date = date(birth_s, "DMY")}{p_end}
{phang2}{cmd:. generate double study_entry = date(entry_s, "DMY")}{p_end}
{phang2}{cmd:. generate double study_exit = date(exit_s, "DMY")}{p_end}
{phang2}{cmd:. format birth_date study_entry study_exit %td}{p_end}
{phang2}{cmd:. drop birth_s entry_s exit_s}{p_end}
{phang2}{cmd:. tempfile cohort agebands}{p_end}
{phang2}{cmd:. save `cohort'}{p_end}

{pstd}{bf:Exact five-year bands with age truncation}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvage, id(id) dob(birth_date) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:groupwidth(5) minage(40) maxage(80) generate(age_group)}{p_end}

{pstd}
The first row begins no earlier than the 40th birthday and the last ends no
later than the day before the 81st birthday. The 29 February birthday follows
the anniversary convention described above.

{pstd}{bf:Single-year bands saved without replacing the cohort in memory}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvage, id(id) dob(birth_date) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:generate(age) startgen(age_start) stopgen(age_stop) ///}{p_end}
{phang3}{cmd:saveas(`agebands') replace}{p_end}
{phang2}{cmd:. use `agebands', clear}{p_end}

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
{space 2}Help: {help tvexpose}, {help tvmerge}, {help stset}
{p_end}

{hline}
