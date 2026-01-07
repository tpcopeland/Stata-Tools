{smcl}
{* *! version 1.1.0  07jan2026}{...}
{viewerjumpto "Syntax" "tvage##syntax"}{...}
{viewerjumpto "Description" "tvage##description"}{...}
{viewerjumpto "Options" "tvage##options"}{...}
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
{opt idvar(varname)}
{opt dobvar(varname)}
{opt entryvar(varname)}
{opt exitvar(varname)}
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
the day before their next birthday.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt idvar(varname)} specifies the person identifier variable.

{phang}
{opt dobvar(varname)} specifies the date of birth variable (Stata date format).

{phang}
{opt entryvar(varname)} specifies the study entry date variable (Stata date format).

{phang}
{opt exitvar(varname)} specifies the study exit date variable (Stata date format).

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


{marker examples}{...}
{title:Examples}

{pstd}Setup with cohort data{p_end}
{phang2}{cmd:. use analysis_cohort, clear}{p_end}
{phang2}{cmd:. keep id study_entry study_exit dob}{p_end}

{pstd}Create 5-year age groups for ages 40-80{p_end}
{phang2}{cmd:. tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) groupwidth(5) minage(40) maxage(80) noisily}{p_end}

{pstd}Create single-year ages and save to file{p_end}
{phang2}{cmd:. tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) groupwidth(1) saveas(age_tv_data) replace noisily}{p_end}

{pstd}Create 10-year age groups{p_end}
{phang2}{cmd:. tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) groupwidth(10) generate(age_group) startgen(age_start) stopgen(age_end) noisily}{p_end}


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

{pstd}Tim Copeland{break}
Karolinska Institutet{break}
Stockholm, Sweden{p_end}

{pstd}Part of the {cmd:tvtools} package for time-varying exposure analysis.{p_end}


{title:Also see}

{psee}
{space 2}Help:  {help tvexpose}, {help tvmerge}, {help stset}
{p_end}
