{smcl}
{* *! version 1.0.0  17dec2025}{...}
{viewerjumpto "Syntax" "cdp##syntax"}{...}
{viewerjumpto "Description" "cdp##description"}{...}
{viewerjumpto "Options" "cdp##options"}{...}
{viewerjumpto "Examples" "cdp##examples"}{...}
{viewerjumpto "Stored results" "cdp##results"}{...}
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

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt dx:date(varname)}}diagnosis date variable{p_end}

{syntab:Optional}
{synopt:{opt gen:erate(name)}}name for CDP date variable; default is {cmd:cdp_date}{p_end}
{synopt:{opt conf:irmdays(#)}}days required for confirmation; default is {cmd:180}{p_end}
{synopt:{opt base:linewindow(#)}}days from diagnosis for baseline EDSS; default is {cmd:730}{p_end}
{synopt:{opt roving}}use roving baseline (reset after each progression){p_end}
{synopt:{opt alle:vents}}track all CDP events, not just first{p_end}
{synopt:{opt keepall}}retain all observations{p_end}
{synopt:{opt q:uietly}}suppress output messages{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:cdp} computes confirmed disability progression (CDP) dates from longitudinal
EDSS measurements. CDP is a standard outcome in multiple sclerosis clinical trials
and observational studies.

{pstd}
The algorithm:

{phang2}1. Determines baseline EDSS as the first measurement within {opt baselinewindow()}
days of the diagnosis date. If no measurement exists within this window, the
earliest available EDSS is used.

{phang2}2. Calculates the progression threshold based on baseline EDSS:
{p_end}
{phang3}- Baseline EDSS <= 5.5: requires >= 1.0 point increase{p_end}
{phang3}- Baseline EDSS > 5.5: requires >= 0.5 point increase{p_end}

{phang2}3. Identifies progression events where EDSS increases by at least the threshold
amount from baseline.

{phang2}4. Confirms progression by verifying that EDSS remains at or above the
progression level at a subsequent measurement at least {opt confirmdays()} later.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt dxdate(varname)} specifies the variable containing the MS diagnosis date.
This is used to determine the baseline window.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name for the generated CDP date variable.
The default is {cmd:cdp_date}.

{phang}
{opt confirmdays(#)} specifies the minimum number of days between the progression
event and the confirming measurement. The default is {cmd:180} (approximately 6 months).

{phang}
{opt baselinewindow(#)} specifies the maximum number of days after diagnosis within
which to look for the baseline EDSS measurement. The default is {cmd:730} (2 years).
If no EDSS measurement exists within this window, the earliest available measurement
is used as baseline.

{phang}
{opt roving} specifies that the baseline should be reset after each confirmed
progression event. This allows detection of multiple progression events where
each uses the previous confirmed level as the new baseline. Without this option,
all progression is measured from the initial baseline.

{phang}
{opt allevents} specifies that all CDP events should be tracked, not just the first.
This option is only meaningful when {opt roving} is also specified. When used,
additional variables {cmd:event_num} and {cmd:baseline_edss_at_event} are created.

{phang}
{opt keepall} specifies that all observations should be retained in the output.
By default, only observations for patients who experience CDP are kept.

{phang}
{opt quietly} suppresses the display of results.


{marker examples}{...}
{title:Examples}

{pstd}Basic usage with default 6-month confirmation:{p_end}
{phang2}{cmd:. use edss_long, clear}{p_end}
{phang2}{cmd:. cdp id edss edss_date, dxdate(ms_diagnosis_date)}{p_end}

{pstd}Using 3-month confirmation window:{p_end}
{phang2}{cmd:. cdp id edss edss_date, dxdate(dx_date) confirmdays(90)}{p_end}

{pstd}Track multiple progression events with roving baseline:{p_end}
{phang2}{cmd:. cdp id edss edss_date, dxdate(dx_date) roving allevents}{p_end}

{pstd}Keep all patients (including those without progression):{p_end}
{phang2}{cmd:. cdp id edss edss_date, dxdate(dx_date) keepall}{p_end}

{pstd}Typical MS research workflow:{p_end}
{phang2}{cmd:. use msreg_besoksdata, clear}{p_end}
{phang2}{cmd:. merge m:1 id using msreg_basdata, keepusing(onset_date) nogen}{p_end}
{phang2}{cmd:. cdp id edss visit_date, dxdate(onset_date) keepall}{p_end}
{phang2}{cmd:. gen had_cdp = !missing(cdp_date)}{p_end}
{phang2}{cmd:. tab had_cdp}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:cdp} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_persons)}}number of persons with CDP{p_end}
{synopt:{cmd:r(N_events)}}total number of CDP events{p_end}
{synopt:{cmd:r(confirmdays)}}confirmation period in days{p_end}
{synopt:{cmd:r(baselinewindow)}}baseline window in days{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of generated variable{p_end}
{synopt:{cmd:r(roving)}}yes/no indicating roving baseline{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet


{title:Also see}

{psee}
Manual: {manlink ST stset}

{psee}
{space 2}Help: {manhelp stset ST}, {help sustainedss}, {help pira}
{p_end}
