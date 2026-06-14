{smcl}
{* *! version 1.3.0  14jun2026}{...}
{vieweralsosee "sustainedss" "help sustainedss"}{...}
{vieweralsosee "pira" "help pira"}{...}
{vieweralsosee "setools" "help setools"}{...}
{viewerjumpto "Syntax" "cdp##syntax"}{...}
{viewerjumpto "Description" "cdp##description"}{...}
{viewerjumpto "Options" "cdp##options"}{...}
{viewerjumpto "Remarks" "cdp##remarks"}{...}
{viewerjumpto "Examples" "cdp##examples"}{...}
{viewerjumpto "Stored results" "cdp##results"}{...}
{viewerjumpto "References" "cdp##references"}{...}
{viewerjumpto "Author" "cdp##author"}{...}

{title:Title}

{p2colset 5 12 14 2}{...}
{p2col:{cmd:cdp} {hline 2}}Confirmed Disability Progression from baseline EDSS{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:cdp} {it:idvar} {it:edssvar} {it:datevar} {ifin}{cmd:,}
{opt dx:date(varname)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt dx:date(varname)}}diagnosis date variable (Stata daily date with {cmd:%td} format){p_end}

{syntab:Optional}
{synopt:{opt gen:erate(name)}}name for CDP date variable; default is {cmd:cdp_date}{p_end}
{synopt:{opt conf:irmdays(#)}}days required for confirmation; default is {cmd:180}{p_end}
{synopt:{opt confirmt:ype(type)}}confirmation rule: {cmd:sustained} (default) or {cmd:visit}{p_end}
{synopt:{opt base:linewindow(#)}}days from diagnosis for baseline EDSS; default is {cmd:730}{p_end}
{synopt:{opt three:tier}}use the three-tier progression threshold (default two-tier){p_end}
{synopt:{opt event:var(name)}}create a 0/1 stset-ready CDP event indicator{p_end}
{synopt:{opt roving}}use roving baseline (reset after each confirmed progression){p_end}
{synopt:{opt all:events}}track all CDP events, not just the first; requires {opt roving}{p_end}
{synopt:{opt keep:all}}retain all observations (including patients without CDP){p_end}
{synopt:{opt q:uietly}}suppress output messages{p_end}
{synoptline}
{p2colreset}{...}

{p 8 16 2}
{it:idvar} identifies patients (numeric or string).
{it:edssvar} is the numeric EDSS score.
{it:datevar} and {opt dxdate()} must both be Stata daily dates stored as
whole-number values with {cmd:%td} display formats.  Other numeric time encodings
such as {cmd:%tm}, {cmd:%tq}, and {cmd:%tc} are rejected because the command uses
day arithmetic.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:cdp} computes confirmed disability progression (CDP) dates from longitudinal
EDSS (Expanded Disability Status Scale) measurements.  CDP is a standard primary
outcome in multiple sclerosis clinical trials and observational studies.

{pstd}
{bf:What the command does:}

{phang2}1. {bf:Determines baseline EDSS.}  The first EDSS measurement within
{opt baselinewindow()} days of the diagnosis date is used.  If no measurement
falls within this window, the patient's earliest available EDSS is used
instead.{p_end}

{phang2}2. {bf:Calculates the progression threshold} based on baseline EDSS.
By default a {bf:two-tier} rule is used:{p_end}
{phang3}{hline 2} Baseline EDSS {ul:<}= 5.5: requires {ul:>}= 1.0 point increase{p_end}
{phang3}{hline 2} Baseline EDSS > 5.5: requires {ul:>}= 0.5 point increase{p_end}
{phang2}With {opt threetier}, the canonical Lublin (2014) / Kappos three-tier rule
is used instead: {ul:>}= 1.5 if baseline is 0, {ul:>}= 1.0 if baseline is 1.0-5.5,
{ul:>}= 0.5 if baseline > 5.5.{p_end}

{phang2}3. {bf:Identifies progression events} where EDSS increases by at least the
threshold from baseline (after the baseline date).{p_end}

{phang2}4. {bf:Confirms progression}.  With the default {cmd:confirmtype(sustained)},
a {bf:sustained-throughout} definition is used: the {it:minimum} EDSS across all
measurements at or after {opt confirmdays()} days must still meet the progression
threshold, so any later EDSS that falls below baseline + threshold invalidates the
event.  With {cmd:confirmtype(visit)}, the looser {bf:next-confirmed-visit}
definition is used: only the EDSS at the first visit occurring at least
{opt confirmdays()} days after the candidate must meet the threshold (later dips are
ignored).{p_end}

{pstd}
{bf:Confirmation requirement:}  At least one EDSS measurement must exist at or
after {opt confirmdays()} days from the candidate progression date.  Patients whose
last measurement falls before this point do not receive confirmed CDP, even if no
regression was observed.  This differs from {helpb sustainedss}, which treats
events as sustained when no disconfirming evidence exists within its confirmation
window.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt dxdate(varname)} specifies the variable containing the MS diagnosis date.
This date anchors the baseline window.  It must be a Stata daily date with a
{cmd:%td} display format and whole-number daily values.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name for the generated CDP date variable.
The default is {cmd:cdp_date}.  The variable must not already exist.

{phang}
{opt confirmdays(#)} specifies the minimum number of days between the progression
event and the confirming measurement.  The default is {cmd:180} (approximately
6 months), which is standard in MS clinical trials.  Use {cmd:confirmdays(90)} for
a 3-month confirmation rule.

{phang}
{opt confirmtype(type)} selects the confirmation rule.  {cmd:sustained} (the
default) requires the minimum EDSS across all measurements at or after
{opt confirmdays()} days to meet the threshold.  {cmd:visit} requires only the EDSS
at the first visit at least {opt confirmdays()} days after the candidate to meet the
threshold (the "N-week confirmed" definition common in clinical trials).  The
default preserves the behavior of earlier versions.

{phang}
{opt baselinewindow(#)} specifies the maximum number of days after diagnosis within
which to search for the baseline EDSS measurement.  The default is {cmd:730}
(2 years).  If no EDSS measurement exists within this window, the earliest
available measurement is used.

{phang}
{opt threetier} applies the canonical Lublin (2014) / Kappos three-tier
progression threshold ({ul:>}= 1.5 if baseline EDSS is 0, {ul:>}= 1.0 if 1.0-5.5,
{ul:>}= 0.5 if > 5.5).  Without it, the two-tier rule ({ul:>}= 1.0 if {ul:<}= 5.5,
{ul:>}= 0.5 if > 5.5) is used.  The default is two-tier for backward compatibility;
choose {opt threetier} to match modern phase-3 MS trial protocols.

{phang}
{opt eventvar(name)} creates a 0/1 indicator equal to 1 for persons with a confirmed
CDP date and 0 otherwise (within the estimation sample), ready for
{helpb stset}.  It is most useful together with {opt keepall}.  The name must be new
and differ from {opt generate()}.

{phang}
{opt roving} specifies that the baseline should be reset after each confirmed
progression event.  The new baseline becomes the confirmed EDSS level, and the
algorithm looks for the next progression from that level.  Without this option,
all progression is measured against the initial baseline.

{phang}
{opt allevents} specifies that all CDP events should be tracked, not just the
first.  This option requires {opt roving}.  When used, additional variables
{cmd:event_num} (CDP event number, starting at 1) and
{cmd:baseline_edss_at_event} (the baseline EDSS used for each event) are created.
The output becomes event-level: one row per CDP event per person.

{phang}
{opt keepall} retains all observations from the original dataset.  By default,
only observations for patients who experience CDP are kept.  With {opt keepall},
patients without CDP have missing values in the CDP date variable.

{phang}
{opt quietly} suppresses the summary output displayed after computation.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Choosing between cdp, sustainedss, and pira}

{pstd}
All three MS progression commands in {helpb setools} measure disability worsening,
but they answer different clinical questions:

{phang2}{cmd:cdp} {hline 2} "When did the patient's EDSS first worsen by at least
1.0 (or 0.5) points from their baseline, confirmed at 6 months?"  Standard trial
endpoint.{p_end}

{phang2}{helpb sustainedss} {hline 2} "When did the patient first reach EDSS {ul:>}= X
and stay there?"  Threshold crossing, no baseline reference.{p_end}

{phang2}{helpb pira} {hline 2} "Was the confirmed progression (CDP) driven by
neurodegeneration or by a relapse?"  Classifies each CDP event as PIRA or RAW.{p_end}

{pstd}
{bf:Data layout}

{pstd}
{cmd:cdp} expects repeated EDSS measurements in long format: one row per EDSS
visit per patient.  Each patient must have at least one EDSS measurement and a
nonmissing diagnosis date.

{pstd}
{bf:Effect of keepall on output rows}

{pstd}
By default, {cmd:cdp} drops all rows for patients without confirmed CDP.  With
{opt keepall}, every original row is preserved.  This is useful when you want to
create a binary "had CDP" indicator (see Example 4 below).

{pstd}
{bf:Roving baseline and allevents}

{pstd}
With {opt roving allevents}, the command can detect multiple stepwise progression
events per patient.  Each event uses the previously confirmed EDSS as its baseline.
The output is reshaped to event level, with one row per CDP event.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Standard CDP with 6-month confirmation}

{pstd}
Load repeated EDSS visit data and compute the first confirmed disability
progression date for each patient.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "cdp id edss edss_date, dxdate(dx_date)":. cdp id edss edss_date, dxdate(dx_date)}{p_end}

{pstd}
{bf:Example 2: Three-month confirmation window}

{pstd}
Some protocols use a shorter 3-month confirmation rule.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "cdp id edss edss_date, dxdate(dx_date) confirmdays(90)":. cdp id edss edss_date, dxdate(dx_date) confirmdays(90)}{p_end}

{pstd}
{bf:Example 3: Multiple progression events with roving baseline}

{pstd}
Track all stepwise CDP events per patient.  After each confirmed event, the
baseline resets to the new EDSS level.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "cdp id edss edss_date, dxdate(dx_date) roving allevents":. cdp id edss edss_date, dxdate(dx_date) roving allevents}{p_end}

{pstd}
{bf:Example 4: Create a binary CDP indicator for the whole cohort}

{pstd}
Use {opt keepall} to retain all patients, then create a 0/1 flag for survival
analysis or logistic regression.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "cdp id edss edss_date, dxdate(dx_date) keepall":. cdp id edss edss_date, dxdate(dx_date) keepall}{p_end}
{phang2}{stata "gen byte had_cdp = !missing(cdp_date)":. gen byte had_cdp = !missing(cdp_date)}{p_end}
{phang2}{stata "tab had_cdp":. tab had_cdp}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:cdp} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_persons)}}number of persons with confirmed CDP{p_end}
{synopt:{cmd:r(N_events)}}total number of CDP events{p_end}
{synopt:{cmd:r(confirmdays)}}confirmation period in days{p_end}
{synopt:{cmd:r(baselinewindow)}}baseline window in days{p_end}
{synopt:{cmd:r(converged)}}1 if the confirmation loop converged, 0 otherwise{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of the generated CDP date variable{p_end}
{synopt:{cmd:r(confirmtype)}}{cmd:sustained} or {cmd:visit}{p_end}
{synopt:{cmd:r(threetier)}}{cmd:yes} or {cmd:no}{p_end}
{synopt:{cmd:r(roving)}}{cmd:yes} or {cmd:no}{p_end}
{synopt:{cmd:r(eventvar)}}name of the event indicator (if {opt eventvar()} specified){p_end}


{marker references}{...}
{title:References}

{pstd}
Lublin FD, Reingold SC, Cohen JA, et al. 2014.
Defining the clinical course of multiple sclerosis: the 2013 revisions.
{it:Neurology} 83: 278-286.

{pstd}
Kappos L, Butzkueven H, Wiendl H, et al. 2018.
Greater sensitivity to multiple sclerosis disability worsening and progression
events using a roving versus a fixed reference value in a prospective cohort study.
{it:Multiple Sclerosis Journal} 24: 963-973.

{pstd}
Kappos L, Wolinsky JS, Giovannoni G, et al. 2020.
Contribution of relapse-independent progression vs relapse-associated worsening to
overall confirmed disability accumulation in typical relapsing multiple sclerosis in
a pooled analysis of 2 randomized clinical trials.
{it:JAMA Neurology} 77: 1132-1140.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet


{title:Also see}

{pstd}
{help setools:setools} {hline 2} Swedish registry toolkit overview{p_end}
{pstd}
{help sustainedss:sustainedss} {hline 2} Compute sustained EDSS progression date{p_end}
{pstd}
{help pira:pira} {hline 2} Progression Independent of Relapse Activity{p_end}

{psee}
Manual: {manlink ST stset}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

{hline}
