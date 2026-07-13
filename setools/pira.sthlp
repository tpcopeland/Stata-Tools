{smcl}
{vieweralsosee "cdp" "help cdp"}{...}
{vieweralsosee "sustainedss" "help sustainedss"}{...}
{vieweralsosee "setools" "help setools"}{...}
{viewerjumpto "Syntax" "pira##syntax"}{...}
{viewerjumpto "Description" "pira##description"}{...}
{viewerjumpto "Options" "pira##options"}{...}
{viewerjumpto "Remarks" "pira##remarks"}{...}
{viewerjumpto "Examples" "pira##examples"}{...}
{viewerjumpto "Stored results" "pira##results"}{...}
{viewerjumpto "References" "pira##references"}{...}
{viewerjumpto "Author" "pira##author"}{...}

{title:Title}

{p2colset 5 13 15 2}{...}
{p2col:{cmd:pira} {hline 2}}Progression Independent of Relapse Activity{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:pira} {it:idvar} {it:edssvar} {it:datevar} {ifin}{cmd:,}
{opt dx:date(varname)}
{opt rel:apses(filename)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt dx:date(varname)}}diagnosis date variable; must be a daily {cmd:%td} date{p_end}
{synopt:{opt rel:apses(filename)}}relapse-event dataset path{p_end}

{syntab:Relapse file}
{synopt:{opt relapsei:dvar(varname)}}relapse-file ID variable{p_end}
{synopt:{opt relapsed:atevar(varname)}}relapse-file date variable{p_end}

{syntab:Relapse window}
{synopt:{opt windowb:efore(#)}}pre-relapse window; default 90 days{p_end}
{synopt:{opt windowa:fter(#)}}post-relapse window; default 30 days{p_end}

{syntab:CDP parameters}
{synopt:{opt gen:erate(name)}}PIRA date variable name{p_end}
{synopt:{opt raw:generate(name)}}name for the RAW date variable; default is {cmd:raw_date}{p_end}
{synopt:{opt conf:irmdays(#)}}days required for CDP confirmation; default is {cmd:180}{p_end}
{synopt:{opt confirmt:ype(type)}}confirmation rule: {cmd:sustained} (default) or {cmd:visit}{p_end}
{synopt:{opt base:linewindow(#)}}baseline window; default 730 days{p_end}
{synopt:{opt three:tier}}use three-tier EDSS thresholds{p_end}

{syntab:Baseline}
{synopt:{opt rebase:linerelapse}}reset the baseline EDSS after each relapse{p_end}

{syntab:Output}
{synopt:{opt event:var(name)}}0/1 PIRA event indicator{p_end}
{synopt:{opt exit(varname)}}per-person study-exit date{p_end}
{synopt:{opt keep:all}}retain persons without progression{p_end}
{synopt:{opt q:uietly}}suppress output messages{p_end}
{synoptline}
{p2colreset}{...}

{p 8 16 2}
{it:idvar} identifies patients. {it:edssvar} is the numeric EDSS score and
{it:datevar}, {opt dxdate()}, and the relapse date variable must all be Stata
daily dates with {cmd:%td} display formats and whole-number daily values.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:pira} identifies {bf:Progression Independent of Relapse Activity} (PIRA), a key
outcome in multiple sclerosis (MS) research. MS disability can worsen in two
distinct ways:

{phang2}{bf:PIRA} {hline 2} disability accumulation observed outside the selected
relapse windows.{p_end}

{phang2}{bf:RAW} (Relapse-Associated Worsening) {hline 2} disability accumulation
occurring during or shortly after a relapse.{p_end}

{pstd}
Distinguishing these two mechanisms is important because PIRA is increasingly
recognized as the dominant driver of long-term disability, even in relapsing MS,
and has implications for treatment selection and trial design.

{pstd}
The algorithm works in two steps:

{phang2}1. {bf:Identify the first confirmed disability progression (CDP)} using
the same first-event algorithm as {helpb cdp}. The default uses the two-tier
threshold and sustained-throughout confirmation; {opt threetier} and
{opt confirmtype(visit)} select the documented alternatives.{p_end}

{phang2}2. {bf:Classify that first CDP} by checking whether it falls within a
window around any relapse. The window extends from {opt windowbefore()} days
before a relapse to {opt windowafter()} days after. A first CDP outside every
window is classified as PIRA; one inside any window is classified as RAW.{p_end}

{pstd}
The mutually exclusive first-event class is returned in separate PIRA and RAW
date variables. The command does not classify recurrent CDP events.

{pstd}
{bf:Data requirements:} The command reads EDSS measurements from memory and relapse
dates from a separate file on disk ({opt relapses()}). The relapse file must
contain one row per relapse per person, with an ID variable and a relapse date
variable.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt dxdate(varname)} specifies the variable containing the MS diagnosis date for
each patient. This anchors the baseline window. It must be a Stata daily date
with a {cmd:%td} display format.

{phang}
{opt relapses(filename)} specifies the path to a dataset containing relapse
events. The file must contain an ID variable (see {opt relapseidvar()}) and a
relapse date variable (see {opt relapsedatevar()}). {cmd:pira} loads the file from
disk; it does not use relapse information already in memory.

{dlgtab:Relapse file}

{phang}
{opt relapseidvar(varname)} specifies the name of the ID variable in the relapse
file. Default is the same name as {it:idvar} in the master data. The type
(string vs. numeric) must match.

{phang}
{opt relapsedatevar(varname)} specifies the name of the relapse date variable in
the relapse file. Default is {cmd:relapse_date}. The variable must be a Stata
daily date with a {cmd:%td} display format. Rows with missing relapse dates or
missing/blank IDs are silently dropped.

{dlgtab:Relapse window}

{phang}
{opt windowbefore(#)} specifies how many days before a relapse onset a CDP event is
considered relapse-associated. Default is {cmd:90}.

{phang}
{opt windowafter(#)} specifies how many days after a relapse onset a CDP event is
considered relapse-associated. Default is {cmd:30}.

{pstd}
The combined window [{opt windowbefore()} days before, {opt windowafter()} days after]
forms the exclusion zone around each relapse. CDP events that fall outside {it:all}
relapse windows are classified as PIRA. Common configurations:

{phang2}Lublin 2014: {cmd:windowbefore(0) windowafter(30)}{p_end}
{phang2}EXPAND trial (default): {cmd:windowbefore(90) windowafter(30)}{p_end}

{dlgtab:CDP parameters}

{phang}
{opt generate(name)} specifies the name for the PIRA date variable. Default is
{cmd:pira_date}. Must differ from {opt rawgenerate()}.

{phang}
{opt rawgenerate(name)} specifies the name for the RAW date variable. Default is
{cmd:raw_date}.

{phang}
{opt confirmdays(#)} specifies the minimum number of days between the progression
event and the confirming measurement. Default is {cmd:180} (6 months).

{phang}
{opt confirmtype(type)} selects the CDP confirmation rule, exactly as in
{helpb cdp}. {cmd:sustained} (the default) requires the minimum EDSS across all
measurements at or after {opt confirmdays()} to meet the threshold. {cmd:visit}
requires only the EDSS at the first visit at least {opt confirmdays()} days after the
candidate to meet the threshold.

{phang}
{opt baselinewindow(#)} specifies how many days after diagnosis to look for the
baseline EDSS measurement. Default is {cmd:730} (2 years). If no measurement
exists within this window, the earliest available EDSS is used.

{phang}
{opt threetier} applies the canonical Lublin (2014) / Kappos three-tier
progression threshold ({ul:>}= 1.5 if baseline EDSS is 0, {ul:>}= 1.0 if 1.0-5.5,
{ul:>}= 0.5 if > 5.5), exactly as in {helpb cdp}. The default two-tier rule is
preserved for backward compatibility.

{dlgtab:Baseline}

{phang}
{opt rebaselinerelapse} specifies that the baseline EDSS should be reset after each
relapse. Specifically, after a relapse occurring after the current baseline,
the first EDSS measurement at least 30 days later becomes the new reference
point for subsequent progression detection. This prevents relapse-induced EDSS
fluctuations from inflating or suppressing the change-from-baseline
calculation.

{dlgtab:Output}

{phang}
{opt eventvar(name)} creates a 0/1 indicator equal to 1 for persons with a PIRA date
(matching {opt generate()}) and 0 otherwise, within the estimation sample, ready for
{helpb stset}. RAW-only progressors are coded 0. Most useful with {opt keepall}. The name
must be new and differ from {opt generate()} and {opt rawgenerate()}.

{phang}
{opt exit(varname)} names a per-person study-exit date (a numeric Stata daily date
with a {cmd:%td} format). Both the PIRA date and the RAW date are set to missing
when they fall strictly after a person's exit date, and {opt eventvar()} (if
requested) is recomputed from the censored PIRA date. This replaces the
hand-written post-exit clipping that follows most {cmd:pira} calls. Persons with a
missing exit date are left unchanged; observations are retained.

{phang}
{opt keepall} specifies that all observations should be retained in the output,
including patients without any CDP. By default, {cmd:pira} drops all rows for
patients who do not experience CDP (either PIRA or RAW). Patients without
progression will have missing values in the PIRA and RAW date variables.

{phang}
{opt quietly} suppresses the summary output that is displayed by default.

{pstd}
Names beginning {cmd:_pira_} or {cmd:_setools_}, plus {cmd:_relapse_dt}, are
reserved for internal working state. Positional, person-level, and output
variables using those names are rejected before the dataset is changed.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Relationship to cdp and sustainedss}

{pstd}
{cmd:pira} internally runs the same CDP algorithm as {helpb cdp}, so you do not
need to run {cmd:cdp} separately before running {cmd:pira}. If you only need CDP
dates without the PIRA/RAW classification, use {helpb cdp} directly. If you only
need a sustained threshold crossing without a baseline-referenced change, use
{helpb sustainedss}.

{pstd}
{bf:Preparing the relapse file}

{pstd}
If relapse dates are stored as a variable in the same dataset as EDSS visits,
you need to save a separate relapse-only file first. See Example 1 below.

{pstd}
{bf:Choosing a relapse window}

{pstd}
The default window ({cmd:windowbefore(90) windowafter(30)}) is used in several
recent pooled analyses (e.g., Kappos et al. 2020). A narrower
post-relapse-only window ({cmd:windowbefore(0) windowafter(30)}) follows Lublin
2014 definitions. For a sensitivity analysis, reload or restore the original
EDSS data before each {cmd:pira} call, then change the window parameters. A
default run creates output variables and may drop nonprogressors, so rerunning
directly on its returned data is not equivalent.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Prepare a relapse file from an in-memory dataset}

{pstd}
If relapse dates live alongside EDSS visits, extract them to a temporary file
before running {cmd:pira}.{p_end}

{phang2}{cmd:. preserve}{p_end}
{phang2}{cmd:. keep id relapse_date}{p_end}
{phang2}{cmd:. drop if missing(relapse_date)}{p_end}
{phang2}{cmd:. duplicates drop id relapse_date, force}{p_end}
{phang2}{cmd:. save "ms_relapses.dta", replace}{p_end}
{phang2}{cmd:. restore}{p_end}

{pstd}
{bf:Example 2: Basic PIRA analysis with example data}

{pstd}
Download the EDSS visits and relapse files from the package data repository,
then run {cmd:pira} with default parameters (90-day before / 30-day after window,
180-day confirmation, 730-day baseline window).{p_end}

{phang2}{stata `"copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta" "relapses_example.dta", replace"':. copy "https://.../relapses.dta" "relapses_example.dta", replace}{p_end}
{phang2}{stata `"copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses_only.dta" "relapses_only.dta", replace"':. copy "https://.../relapses_only.dta" "relapses_only.dta", replace}{p_end}
{phang2}{stata `"use "relapses_example.dta", clear"':. use "relapses_example.dta", clear}{p_end}
{phang2}{stata `"pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") keepall"':. pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") keepall}{p_end}

{pstd}
{bf:Example 3: Tabulate progression type}

{pstd}
After running with {opt keepall}, classify each patient's progression type and
tabulate.{p_end}

{phang2}{cmd:. gen str4 prog_type = cond(!missing(pira_date), "PIRA", ///}{p_end}
{phang3}{cmd:cond(!missing(raw_date), "RAW", "None"))}{p_end}
{phang2}{cmd:. tab prog_type}{p_end}

{pstd}
{bf:Example 4: Lublin 2014 window (30 days after relapse only)}

{phang2}{stata `"use "relapses_example.dta", clear"':. use "relapses_example.dta", clear}{p_end}
{phang2}{stata `"pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") windowbefore(0) windowafter(30)"':. pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") ///}{p_end}
{phang3}{cmd:windowbefore(0) windowafter(30)}{p_end}

{pstd}
{bf:Example 5: Re-baseline after relapse and keep all patients}

{pstd}
With {opt rebaselinerelapse}, the first EDSS at least 30 days after each relapse
becomes the new baseline for subsequent progression detection.{p_end}

{phang2}{stata `"use "relapses_example.dta", clear"':. use "relapses_example.dta", clear}{p_end}
{phang2}{stata `"pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") rebaselinerelapse keepall"':. pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") ///}{p_end}
{phang3}{cmd:rebaselinerelapse keepall}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:pira} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_cdp)}}first CDP count after exit censoring{p_end}
{synopt:{cmd:r(N_cdp_preexit)}}first CDP count before exit censoring{p_end}
{synopt:{cmd:r(N_pira)}}first CDPs outside relapse windows{p_end}
{synopt:{cmd:r(N_raw)}}first CDPs inside a relapse window{p_end}
{synopt:{cmd:r(windowbefore)}}days before relapse in the exclusion window{p_end}
{synopt:{cmd:r(windowafter)}}days after relapse in the exclusion window{p_end}
{synopt:{cmd:r(confirmdays)}}CDP confirmation period in days{p_end}
{synopt:{cmd:r(baselinewindow)}}baseline window in days{p_end}
{synopt:{cmd:r(converged)}}1 if the confirmation loop converged, 0 otherwise{p_end}
{synopt:{cmd:r(N_censored_exit)}}events censored after study exit{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(pira_varname)}}name of the generated PIRA date variable{p_end}
{synopt:{cmd:r(raw_varname)}}name of the generated RAW date variable{p_end}
{synopt:{cmd:r(confirmtype)}}{cmd:sustained} or {cmd:visit}{p_end}
{synopt:{cmd:r(threetier)}}{cmd:yes} or {cmd:no}{p_end}
{synopt:{cmd:r(rebaselinerelapse)}}{cmd:yes} or {cmd:no}{p_end}
{synopt:{cmd:r(event_scope)}}{cmd:first_confirmed_cdp}{p_end}
{synopt:{cmd:r(eventvar)}}event-indicator name, if requested{p_end}
{synopt:{cmd:r(exit)}}study-exit variable name, if requested{p_end}


{marker references}{...}
{title:References}

{phang}
Kappos L, et al. Contribution of relapse-independent progression vs
relapse-associated worsening to overall confirmed disability accumulation in
typical relapsing multiple sclerosis in a pooled analysis of 2 randomized
clinical trials. {it:JAMA Neurology}. 2020;77(9):1132{c -}1140.

{phang}
Lublin FD, et al. Defining the clinical course of multiple sclerosis: the 2013
revisions. {it:Neurology}. 2014;83(3):278{c -}286.

{phang}
University of California San Francisco MS-EPIC Team, et al. Silent progression
in disease activity-free relapsing multiple
sclerosis. {it:Annals of Neurology}. 2019;85(5):653{c -}666.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet

{pstd}
Part of the {help setools:setools} package for Swedish registry research.{p_end}


{title:Also see}

{pstd}
{help setools:setools} {hline 2} Swedish registry toolkit overview{p_end}
{pstd}
{help cdp:cdp} {hline 2} Confirmed Disability Progression from baseline EDSS{p_end}
{pstd}
{help sustainedss:sustainedss} {hline 2} Compute sustained EDSS progression date{p_end}

{psee}
Manual: {manlink ST stset}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

{hline}
