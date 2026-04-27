{smcl}
{* *! version 1.2.0  24apr2026}{...}
{vieweralsosee "cci_se" "help cci_se"}{...}
{vieweralsosee "migrations" "help migrations"}{...}
{vieweralsosee "setools" "help setools"}{...}
{viewerjumpto "Syntax" "procmatch##syntax"}{...}
{viewerjumpto "Description" "procmatch##description"}{...}
{viewerjumpto "Subcommands" "procmatch##subcommands"}{...}
{viewerjumpto "Options" "procmatch##options"}{...}
{viewerjumpto "Remarks" "procmatch##remarks"}{...}
{viewerjumpto "Examples" "procmatch##examples"}{...}
{viewerjumpto "Stored results" "procmatch##results"}{...}
{viewerjumpto "Author" "procmatch##author"}{...}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:procmatch} {hline 2}}Procedure code matching for Swedish registry research{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Match procedure codes and generate a binary indicator

{p 8 16 2}
{cmd:procmatch match}{cmd:,} {opt codes(codelist)} {opt procvars(varlist)}
[{opt gen:erate(name)} {opt replace} {opt pre:fix} {opt noi:sily}]

{pstd}
Extract the earliest date each person received a matching procedure

{p 8 16 2}
{cmd:procmatch first}{cmd:,} {opt codes(codelist)} {opt procvars(varlist)}
{opt datevar(varname)} {opt idvar(varname)}
[{opt gen:erate(name)} {opt gendatevar(name)} {opt replace} {opt pre:fix} {opt noi:sily}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required (both subcommands)}
{synopt:{opt codes(codelist)}}one or more KV{c a:} procedure codes to search for{p_end}
{synopt:{opt procvars(varlist)}}procedure-code variable(s) to search{p_end}

{syntab:Required (first only)}
{synopt:{opt datevar(varname)}}date of each procedure; must be a Stata daily date with {cmd:%td} format{p_end}
{synopt:{opt idvar(varname)}}patient identifier variable{p_end}

{syntab:Optional}
{synopt:{opt gen:erate(name)}}name for the indicator variable; default {cmd:_proc_match} ({cmd:match}) or {cmd:_proc_ever} ({cmd:first}){p_end}
{synopt:{opt gendatevar(name)}}({cmd:first} only) name for the date variable; default {cmd:_proc_first_dt}{p_end}
{synopt:{opt replace}}allow overwriting existing output variables{p_end}
{synopt:{opt pre:fix}}match codes as prefixes instead of exact strings{p_end}
{synopt:{opt noi:sily}}display progress and summary information{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:procmatch} searches one or more procedure-code variables for a specified set of
KV{c a:} (Klassifikation av v{c a:}rd{c a:}tg{c a:}rder) codes.  Swedish inpatient
and outpatient registry extracts typically contain up to 30 procedure fields per
visit (e.g., {it:proc1}{c -}{it:proc30}).  {cmd:procmatch} lets you query all of
them in a single call.

{pstd}
The command has two subcommands:

{phang2}{cmd:match} adds a binary (0/1) indicator variable to every observation.  No rows
are dropped.  Use this when you need a row-level flag (e.g., "does this visit
include a cardiac procedure?").{p_end}

{phang2}{cmd:first} adds a person-level binary indicator {it:and} the earliest matching
procedure date.  No rows are dropped; every row for a given person receives the
same first-date value.  Use this when you need the date a patient first underwent
a procedure (e.g., for defining index dates or time-to-event analysis).{p_end}

{pstd}
All code matching is case-insensitive.  Codes in {opt codes()} may be separated
by spaces or commas.


{marker subcommands}{...}
{title:Subcommands}

{dlgtab:procmatch match}

{pstd}
Generates a binary indicator variable equal to 1 wherever any of the specified
procedure codes appears in any of the {opt procvars()} variables.  By default the
indicator is named {cmd:_proc_match}; use {opt generate()} to choose another name.

{pstd}
Matching is exact by default: the entire content of each procedure variable is
compared against each code.  With {opt prefix}, the comparison uses only the first
{it:N} characters of the procedure variable, where {it:N} is the length of the
code.  For example, {cmd:codes("FNG")} with {opt prefix} matches {cmd:"FNG02"},
{cmd:"FNG05"}, etc.

{dlgtab:procmatch first}

{pstd}
First applies the same matching logic as {cmd:match}, then collapses the matches
to person level: for each unique {opt idvar()} value it finds the earliest
{opt datevar()} among all matched rows.  Two variables are created:

{phang2}1. A binary indicator ({cmd:_proc_ever} by default) equal to 1 for every row
belonging to a person who ever received a matching procedure.{p_end}

{phang2}2. A date variable ({cmd:_proc_first_dt} by default) containing that person's
earliest procedure date, formatted as {cmd:%tdCCYY/NN/DD}.{p_end}

{pstd}
{opt datevar()} must be a numeric Stata daily date with a {cmd:%td} display format.
Matched rows with missing {opt datevar()} or missing/blank {opt idvar()} values
cause an error.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt codes(codelist)} specifies the KV{c a:} procedure codes to search for.
Multiple codes may be separated by spaces or commas.  Codes are converted to
uppercase before matching.  Examples: {cmd:codes("FNG02 FNG05")},
{cmd:codes("DA024, DA025")}.

{phang}
{opt procvars(varlist)} specifies the string variable(s) that contain procedure
codes.  All listed variables are searched for every code.  Example:
{cmd:procvars(kva_code)} or {cmd:procvars(proc1-proc30)}.

{phang}
{opt datevar(varname)} ({cmd:first} only) specifies the date variable for each
procedure record.  It must be a numeric Stata daily date with a {cmd:%td} display
format; datetime variables ({cmd:%tc}) are rejected.  Matched procedure rows must
have nonmissing dates.

{phang}
{opt idvar(varname)} ({cmd:first} only) specifies the patient identifier variable.
Matched rows with missing numeric IDs or blank string IDs are rejected.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name for the indicator variable.  Default is
{cmd:_proc_match} for {cmd:match} and {cmd:_proc_ever} for {cmd:first}.  The name
must not duplicate an input variable.  In {cmd:first} it must also differ from
{opt gendatevar()}.

{phang}
{opt gendatevar(name)} ({cmd:first} only) specifies the name for the generated
first-occurrence date variable.  Default is {cmd:_proc_first_dt}.  Must not
duplicate an input variable or {opt generate()}.

{phang}
{opt replace} allows overwriting existing output variables.  In {cmd:match}, the
target must be a variable previously created by {cmd:procmatch}; the command
refuses to overwrite unrelated existing variables.

{phang}
{opt prefix} switches from exact matching to prefix matching.  With {opt prefix},
code {cmd:"FNG02"} matches any procedure variable value that starts with
{cmd:"FNG02"} (e.g., {cmd:"FNG020"}, {cmd:"FNG02X"}).  Without {opt prefix}, only
the exact string {cmd:"FNG02"} matches.

{phang}
{opt noisily} displays a summary showing how many matches were found and how many
procedure variables were searched.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Choosing between exact and prefix matching}

{pstd}
Most KV{c a:} registries store full procedure codes (e.g., {cmd:"FNG02"}).  Use
exact matching (the default) when your codes are complete.  Use {opt prefix} when
you want to match all codes that share a common stem — for example,
{cmd:codes("FNG")} with {opt prefix} catches every code in the FNG group.

{pstd}
{bf:Typical registry layout}

{pstd}
Swedish national patient register extracts often contain variables named
{it:proc1} through {it:proc30} (or {it:op1} through {it:op30}).  You can pass
them all at once: {cmd:procvars(proc1-proc30)}.

{pstd}
{bf:Interaction with cci_se}

{pstd}
{cmd:procmatch} works on procedure codes, while {helpb cci_se} works on diagnosis
codes.  Both can be run on the same registry extract: use {cmd:procmatch} for
surgical exposure variables and {cmd:cci_se} for comorbidity scores.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Flag rows that contain a cardiac procedure}

{pstd}
This loads procedure-level registry data and creates a binary variable
{cmd:cardiac_proc} equal to 1 for rows whose {cmd:kva_code} starts with
{cmd:"FNG02"} or {cmd:"FNG05"} (coronary angiography or PCI codes).{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear"':. use "https://.../procedures.dta", clear}{p_end}
{phang2}{stata `"procmatch match, codes("FNG02 FNG05") procvars(kva_code) generate(cardiac_proc) prefix noisily"':. procmatch match, codes("FNG02 FNG05") procvars(kva_code) generate(cardiac_proc) prefix noisily}{p_end}
{phang2}{stata "tab cardiac_proc":. tab cardiac_proc}{p_end}

{pstd}
{bf:Example 2: Exact matching for a single code}

{pstd}
Without {opt prefix}, only rows whose {cmd:kva_code} is exactly {cmd:"DA024"} are
flagged.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear"':. use "https://.../procedures.dta", clear}{p_end}
{phang2}{stata `"procmatch match, codes("DA024") procvars(kva_code) generate(diab_workup)"':. procmatch match, codes("DA024") procvars(kva_code) generate(diab_workup)}{p_end}

{pstd}
{bf:Example 3: First cardiac procedure date per patient}

{pstd}
{cmd:first} creates a person-level indicator ({cmd:cardiac_proc}) and the earliest
matching procedure date ({cmd:cardiac_proc_dt}).  Every row for a given patient
receives the same date.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear"':. use "https://.../procedures.dta", clear}{p_end}
{phang2}{stata `"procmatch first, codes("FNG02 FNG05") procvars(kva_code) datevar(proc_date) idvar(id) generate(cardiac_proc) gendatevar(cardiac_proc_dt) prefix noisily"':. procmatch first, codes("FNG02 FNG05") procvars(kva_code) ///}{p_end}
{phang3}{cmd:datevar(proc_date) idvar(id) ///}{p_end}
{phang3}{cmd:generate(cardiac_proc) gendatevar(cardiac_proc_dt) prefix noisily}{p_end}

{pstd}
{bf:Example 4: Use the first date in a survival-analysis setup}

{pstd}
After extracting the first procedure date, merge it into a cohort and use it
as a time-varying exposure or index date.{p_end}

{phang2}{cmd:. * Extract first cardiac procedure date}{p_end}
{phang2}{cmd:. procmatch first, codes("FNG02 FNG05") procvars(kva_code) ///}{p_end}
{phang3}{cmd:datevar(proc_date) idvar(id) generate(cardiac) gendatevar(cardiac_dt) prefix}{p_end}
{phang2}{cmd:. keep id cardiac cardiac_dt}{p_end}
{phang2}{cmd:. duplicates drop id, force}{p_end}
{phang2}{cmd:. save cardiac_dates.dta, replace}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Merge into cohort}{p_end}
{phang2}{cmd:. use cohort.dta, clear}{p_end}
{phang2}{cmd:. merge 1:1 id using cardiac_dates.dta, nogenerate keep(master match)}{p_end}
{phang2}{cmd:. replace cardiac = 0 if missing(cardiac)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:procmatch match} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_codes)}}number of procedure codes searched{p_end}
{synopt:{cmd:r(n_matches)}}number of matching observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of generated indicator variable{p_end}
{synopt:{cmd:r(codes)}}procedure codes searched (uppercase){p_end}

{pstd}
{cmd:procmatch first} stores all of the above plus:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_persons)}}number of unique persons with at least one match{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(datevarname)}}name of generated date variable{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden

{pstd}
Part of the {help setools:setools} package for Swedish registry research.{p_end}


{title:Also see}

{pstd}
{help setools:setools} {hline 2} Swedish registry toolkit overview{p_end}
{pstd}
{help cci_se:cci_se} {hline 2} Swedish Charlson Comorbidity Index{p_end}
{pstd}
{help migrations:migrations} {hline 2} Process Swedish migration registry data{p_end}

{psee}
{space 2}Help:  {manhelp inlist FN}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

{hline}
