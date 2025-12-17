{smcl}
{* *{* *! version 1.0.0  2025/12/02}{...}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "migrations" "help migrations"}{...}
{viewerjumpto "Syntax" "sustainedss##syntax"}{...}
{viewerjumpto "Description" "sustainedss##description"}{...}
{viewerjumpto "Options" "sustainedss##options"}{...}
{viewerjumpto "Remarks" "sustainedss##remarks"}{...}
{viewerjumpto "Examples" "sustainedss##examples"}{...}
{viewerjumpto "Stored results" "sustainedss##results"}{...}
{viewerjumpto "References" "sustainedss##references"}{...}
{viewerjumpto "Author" "sustainedss##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:sustainedss} {hline 2}}Compute sustained EDSS progression date{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:sustainedss}
{it:idvar} {it:edssvar} {it:datevar}
{ifin}
{cmd:,}
{opt th:reshold(#)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt th:reshold(#)}}EDSS threshold for progression (e.g., 4 or 6){p_end}

{syntab:Optional}
{synopt:{opt gen:erate(newvar)}}name for generated date variable; default is {it:sustained#_dt}{p_end}
{synopt:{opt conf:irmwindow(#)}}confirmation window in days; default is {bf:182}{p_end}
{synopt:{opt base:linethreshold(#)}}EDSS level for reversal check; default is {bf:4}{p_end}
{synopt:{opt keepall}}retain all observations; default keeps only patients with events{p_end}
{synopt:{opt q:uietly}}suppress iteration messages and summary output{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:sustainedss} computes sustained EDSS (Expanded Disability Status Scale) 
progression dates for multiple sclerosis research. An EDSS progression event 
is considered "sustained" if the disability level is maintained or confirmed 
within a specified window after the initial event.

{pstd}
The command implements an iterative algorithm that:

{phang2}1. Identifies the first date when EDSS reaches or exceeds the specified threshold{p_end}
{phang2}2. Examines EDSS measurements within the confirmation window{p_end}
{phang2}3. Rejects events where the lowest subsequent EDSS falls below the baseline threshold AND the last EDSS in the window is below the target threshold{p_end}
{phang2}4. For rejected events, replaces the EDSS value with the last observed value in the window and repeats{p_end}
{phang2}5. Continues until all remaining events are confirmed as sustained{p_end}

{pstd}
The input dataset must contain one record per EDSS measurement with variables 
for patient ID, EDSS score, and measurement date.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt threshold(#)} specifies the EDSS threshold that defines progression. 
Common values are 4 (moderate disability) or 6 (requires walking aid).
This option is required.

{dlgtab:Optional}

{phang}
{opt generate(newvar)} specifies the name of the new variable to be created 
containing the sustained progression date. The default name is 
{it:sustained#_dt} where # is the threshold value (with decimal points 
replaced by underscores).

{phang}
{opt confirmwindow(#)} specifies the number of days after the initial 
progression event during which EDSS must be sustained. The default is {bf:182} 
days (approximately 6 months), which is standard in MS research.

{phang}
{opt baselinethreshold(#)} specifies the EDSS level used to determine if 
a progression was reversed. If the lowest EDSS in the confirmation window 
falls below this value AND the last EDSS in the window is below the target 
threshold, the event is rejected as not sustained. The default is {bf:4}.

{phang}
{opt keepall} retains all observations from the original dataset, adding 
the sustained date variable (missing for patients without events). By default, 
only observations from patients who experienced a sustained event are kept.

{phang}
{opt quietly} suppresses the iteration progress messages and the summary 
output displayed after computation.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Data requirements:}

{pstd}
The command requires three variables in the specified order:

{phang2}{it:idvar} - Patient identifier (numeric or string){p_end}
{phang2}{it:edssvar} - EDSS score (numeric){p_end}
{phang2}{it:datevar} - Date of EDSS measurement (numeric, Stata date format){p_end}

{pstd}
{bf:Algorithm details:}

{pstd}
The sustained EDSS algorithm is commonly used in MS clinical trials and 
observational studies to identify confirmed disability progression. The 
rationale is that transient increases in EDSS (e.g., during relapses) 
should not be counted as true progression unless the disability level 
is maintained.

{pstd}
The iterative approach handles complex scenarios where multiple EDSS 
measurements may need to be evaluated before identifying the true 
sustained progression date.

{pstd}
{bf:Edge cases:}

{pstd}
If a patient reaches the threshold but has no subsequent EDSS measurements 
within the confirmation window, the event is considered sustained by default 
(cannot be disproven).

{pstd}
If multiple EDSS measurements occur on the same date for the same patient, 
behavior may be unpredictable. Consider resolving duplicates before running 
this command.

{pstd}
{bf:Exclusions:}

{pstd}
Patients whose baseline EDSS already equals or exceeds the threshold 
should typically be excluded before running this command. The command 
does not automatically exclude such patients.


{marker examples}{...}
{title:Examples}

{pstd}{bf:Synthetic data example (runnable):}{p_end}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. set obs 500}{p_end}
{phang2}{cmd:. gen id = ceil(_n/5)}{p_end}
{phang2}{cmd:. bysort id: gen visit = _n}{p_end}
{phang2}{cmd:. gen edss_dt = mdy(1,1,2020) + visit*90 + floor(runiform()*30)}{p_end}
{phang2}{cmd:. gen edss = floor(runiform()*10)}{p_end}
{phang2}{cmd:. format edss_dt %tdCCYY/NN/DD}{p_end}
{phang2}{cmd:. sustainedss id edss edss_dt, threshold(4)}{p_end}
{phang2}{cmd:. return list}{p_end}

{pstd}{bf:Basic usage:}{p_end}

{phang2}{cmd:. use edss_long, clear}{p_end}
{phang2}{cmd:. sustainedss id edss edss_dt, threshold(4)}{p_end}

{pstd}{bf:Compute sustained EDSS >= 6 with custom variable name:}{p_end}

{phang2}{cmd:. sustainedss id edss edss_dt, threshold(6) generate(edss6_sustained)}{p_end}

{pstd}{bf:Use 3-month (90 day) confirmation window:}{p_end}

{phang2}{cmd:. sustainedss id edss edss_dt, threshold(4) confirmwindow(90)}{p_end}

{pstd}{bf:Keep all patients (including those without events):}{p_end}

{phang2}{cmd:. sustainedss id edss edss_dt, threshold(4) keepall}{p_end}

{pstd}{bf:Typical workflow for MS disability outcomes:}{p_end}

{phang2}{cmd:. use edss_long, clear}{p_end}
{phang2}{cmd:. * Exclude patients with baseline EDSS >= 4}{p_end}
{phang2}{cmd:. merge m:1 id using edss_baseline, nogen}{p_end}
{phang2}{cmd:. drop if edss_baseline >= 4}{p_end}
{phang2}{cmd:. * Compute sustained EDSS 4}{p_end}
{phang2}{cmd:. sustainedss id edss edss_dt, threshold(4) keepall}{p_end}
{phang2}{cmd:. * Keep one row per patient}{p_end}
{phang2}{cmd:. duplicates drop id, force}{p_end}
{phang2}{cmd:. keep id sustained4_dt}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:sustainedss} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_events)}}number of sustained events identified{p_end}
{synopt:{cmd:r(iterations)}}number of iterations required{p_end}
{synopt:{cmd:r(threshold)}}EDSS threshold used{p_end}
{synopt:{cmd:r(confirmwindow)}}confirmation window in days{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of generated variable{p_end}


{marker references}{...}
{title:References}

{pstd}
Kappos L, et al. Inclusion of brain volume loss in a revised measure of 
'no evidence of disease activity' (NEDA-4) in relapsing-remitting 
multiple sclerosis. {it:Multiple Sclerosis Journal}. 2016;22(10):1297-1305.

{pstd}
Confavreux C, Vukusic S. Natural history of multiple sclerosis: a unifying 
concept. {it:Brain}. 2006;129(3):606-616.


{marker author}{...}
{title:Author}

{pstd}
Tim Copeland{p_end}
{pstd}
Questions, comments, or bug reports: contact author{p_end}


{marker alsosee}{...}
{title:Also see}

{pstd}
{help migrations:migrations} - Process Swedish migration registry data{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}
