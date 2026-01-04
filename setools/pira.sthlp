{smcl}
{* *! version 1.0.1  31dec2025}{...}
{viewerjumpto "Syntax" "pira##syntax"}{...}
{viewerjumpto "Description" "pira##description"}{...}
{viewerjumpto "Options" "pira##options"}{...}
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
{synopt:{opt dx:date(varname)}}diagnosis date variable{p_end}
{synopt:{opt rel:apses(filename)}}path to relapse dataset{p_end}

{syntab:Relapse file options}
{synopt:{opt relapseid:var(varname)}}ID variable in relapse file; default is {it:idvar}{p_end}
{synopt:{opt relapsedate:var(varname)}}relapse date variable; default is {cmd:relapse_date}{p_end}

{syntab:Relapse window}
{synopt:{opt windowb:efore(#)}}days before relapse to exclude; default is {cmd:90}{p_end}
{synopt:{opt windowa:fter(#)}}days after relapse to exclude; default is {cmd:30}{p_end}

{syntab:CDP parameters}
{synopt:{opt gen:erate(name)}}name for PIRA date variable; default is {cmd:pira_date}{p_end}
{synopt:{opt rawgen:erate(name)}}name for RAW date variable; default is {cmd:raw_date}{p_end}
{synopt:{opt conf:irmdays(#)}}days for confirmation; default is {cmd:180}{p_end}
{synopt:{opt base:linewindow(#)}}days from diagnosis for baseline; default is {cmd:730}{p_end}

{syntab:Baseline options}
{synopt:{opt rebase:linerelapse}}reset baseline EDSS after relapses{p_end}
{synopt:{opt roving}}use roving baseline after each progression{p_end}

{syntab:Output options}
{synopt:{opt alle:vents}}track all events, not just first{p_end}
{synopt:{opt keepall}}retain all observations{p_end}
{synopt:{opt q:uietly}}suppress output messages{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:pira} identifies Progression Independent of Relapse Activity (PIRA), a key
outcome in multiple sclerosis research that distinguishes disability worsening
due to underlying neurodegeneration from worsening associated with acute relapses.

{pstd}
The algorithm:

{phang2}1. Identifies confirmed disability progression (CDP) events using standard
criteria (see {help cdp}).

{phang2}2. For each CDP event, checks whether it falls within a window around any
relapse: [{opt windowbefore()} days before relapse, {opt windowafter()} days after].

{phang2}3. CDP events {bf:outside} the relapse window are classified as {bf:PIRA}
(progression independent of relapse activity).

{phang2}4. CDP events {bf:within} the relapse window are classified as {bf:RAW}
(relapse-associated worsening).

{pstd}
Both PIRA and RAW dates are returned, allowing researchers to analyze different
types of disability accumulation.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt dxdate(varname)} specifies the variable containing the MS diagnosis date.

{phang}
{opt relapses(filename)} specifies the path to a dataset containing relapse dates.
This file must contain an ID variable and a date variable for each relapse event.

{dlgtab:Relapse file options}

{phang}
{opt relapseidvar(varname)} specifies the name of the ID variable in the relapse
file. Default is the same as the {it:idvar} in the main dataset.

{phang}
{opt relapsedatevar(varname)} specifies the name of the relapse date variable.
Default is {cmd:relapse_date}.

{dlgtab:Relapse window}

{phang}
{opt windowbefore(#)} specifies how many days before a relapse to consider
progression as relapse-associated. Default is {cmd:90} days.

{phang}
{opt windowafter(#)} specifies how many days after a relapse to consider
progression as relapse-associated. Default is {cmd:30} days.

{pstd}
Common configurations:

{phang2}Lublin 2014: {cmd:windowbefore(0) windowafter(30)}{p_end}
{phang2}EXPAND trial: {cmd:windowbefore(90) windowafter(30)}{p_end}

{dlgtab:CDP parameters}

{phang}
{opt generate(name)} specifies the name for the PIRA date variable. Default is
{cmd:pira_date}.

{phang}
{opt rawgenerate(name)} specifies the name for the RAW date variable. Default is
{cmd:raw_date}.

{phang}
{opt confirmdays(#)} specifies the minimum days between progression and confirmation.
Default is {cmd:180} (6 months).

{phang}
{opt baselinewindow(#)} specifies the window (in days) from diagnosis within which
to identify the baseline EDSS. Default is {cmd:730} (2 years).

{dlgtab:Baseline options}

{phang}
{opt rebaselinerelapse} specifies that the baseline EDSS should be reset after
relapses. Specifically, for patients with relapses after their initial baseline,
the first EDSS measurement at least 30 days after the last relapse becomes the
new baseline. This accounts for residual disability from relapses.

{phang}
{opt roving} specifies that the baseline should be reset after each confirmed
progression event (whether PIRA or RAW), allowing detection of subsequent
progression events.

{dlgtab:Output options}

{phang}
{opt allevents} specifies that all progression events should be tracked, not just
the first. Requires {opt roving}.

{phang}
{opt keepall} specifies that all observations should be retained. By default,
only observations for patients with CDP (either PIRA or RAW) are kept.

{phang}
{opt quietly} suppresses output messages.


{marker examples}{...}
{title:Examples}

{pstd}Basic usage:{p_end}
{phang2}{cmd:. pira id edss edss_date, dxdate(dx_date) relapses(relapses.dta)}{p_end}

{pstd}Using Lublin 2014 definition (30 days after relapse only):{p_end}
{phang2}{cmd:. pira id edss edss_date, dxdate(dx_date) relapses(relapses.dta)} ///
{p_end}
{phang3}{cmd:windowbefore(0) windowafter(30)}{p_end}

{pstd}Re-baseline after relapses:{p_end}
{phang2}{cmd:. pira id edss edss_date, dxdate(dx_date) relapses(relapses.dta)} ///
{p_end}
{phang3}{cmd:rebaselinerelapse}{p_end}

{pstd}Keep all patients and compare PIRA vs RAW:{p_end}
{phang2}{cmd:. pira id edss edss_date, dxdate(dx_date) relapses(relapses.dta) keepall}{p_end}
{phang2}{cmd:. gen progression_type = cond(!missing(pira_date), "PIRA", ///}{p_end}
{phang3}{cmd:cond(!missing(raw_date), "RAW", "None"))}{p_end}
{phang2}{cmd:. tab progression_type}{p_end}

{pstd}Typical MS Registry workflow:{p_end}
{phang2}{cmd:. use msreg_besoksdata, clear}{p_end}
{phang2}{cmd:. merge m:1 id using msreg_basdata, keepusing(onset_date) nogen}{p_end}
{phang2}{cmd:. pira id edss visit_date, dxdate(onset_date)} ///
{p_end}
{phang3}{cmd:relapses(msreg_skov.dta) relapsedatevar(relapse_dt) keepall}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:pira} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_cdp)}}total number of CDP events{p_end}
{synopt:{cmd:r(N_pira)}}number of PIRA events{p_end}
{synopt:{cmd:r(N_raw)}}number of RAW events{p_end}
{synopt:{cmd:r(windowbefore)}}days before relapse in window{p_end}
{synopt:{cmd:r(windowafter)}}days after relapse in window{p_end}
{synopt:{cmd:r(confirmdays)}}confirmation period in days{p_end}
{synopt:{cmd:r(baselinewindow)}}baseline window in days{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(pira_varname)}}name of PIRA variable{p_end}
{synopt:{cmd:r(raw_varname)}}name of RAW variable{p_end}
{synopt:{cmd:r(rebaselinerelapse)}}yes/no for re-baseline option{p_end}


{marker references}{...}
{title:References}

{phang}
Kappos L, et al. Contribution of relapse-independent progression vs
relapse-associated worsening to overall confirmed disability accumulation in
typical relapsing multiple sclerosis in a pooled analysis of 2 randomized
clinical trials. {it:JAMA Neurology}. 2020;77(9):1132-1140.

{phang}
Lublin FD, et al. Defining the clinical course of multiple sclerosis: the 2013
revisions. {it:Neurology}. 2014;83(3):278-286.

{phang}
University of California San Francisco MS-EPIC Team, et al. Silent progression
in disease activity-free relapsing multiple sclerosis.
{it:Annals of Neurology}. 2019;85(5):653-666.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet


{title:Also see}

{psee}
{space 2}Help: {help cdp}, {help sustainedss}
{p_end}
