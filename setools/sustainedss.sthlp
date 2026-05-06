{smcl}
{* *! version 1.2.3  06may2026}{...}
{vieweralsosee "cdp" "help cdp"}{...}
{vieweralsosee "pira" "help pira"}{...}
{vieweralsosee "setools" "help setools"}{...}
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

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt th:reshold(#)}}EDSS threshold for progression (e.g., 4 or 6){p_end}

{syntab:Optional}
{synopt:{opt gen:erate(name)}}name for generated date variable; default is {it:sustained#_dt}{p_end}
{synopt:{opt conf:irmwindow(#)}}confirmation window in days; default is {cmd:182}{p_end}
{synopt:{opt base:linethreshold(#)}}EDSS level for reversal check; default equals {opt threshold()}{p_end}
{synopt:{opt keep:all}}retain all observations; default keeps only patients with events{p_end}
{synopt:{opt q:uietly}}suppress iteration messages and summary output{p_end}
{synoptline}
{p2colreset}{...}

{p 8 17 2}
{it:idvar} identifies patients (numeric or string).
{it:edssvar} is the numeric EDSS score.
{it:datevar} must be a Stata daily date stored as a whole-number value with a
{cmd:%td} display format.  Other time encodings ({cmd:%tm}, {cmd:%tq}, {cmd:%tc})
are rejected because {opt confirmwindow()} is interpreted in days.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:sustainedss} finds the first date each patient's EDSS (Expanded Disability
Status Scale) reaches or exceeds a user-specified threshold and stays there.
"Stays there" means the EDSS is not disconfirmed within the
{opt confirmwindow()}.

{pstd}
This is a {it:threshold crossing} measure: "When did the patient first reach EDSS
{ul:>}= 4 (or 6, etc.) and remain there?"  It does not reference a baseline EDSS or
compute a change score.  For a {it:change-from-baseline} progression measure, see
{helpb cdp}.

{pstd}
{bf:Algorithm:}

{phang2}1. Find the first date EDSS {ul:>}= {opt threshold()} for each patient.{p_end}

{phang2}2. Within the next {opt confirmwindow()} days, check whether the lowest
observed EDSS falls below {opt baselinethreshold()} {it:and} the last EDSS in the
window falls below {opt threshold()}.  If both conditions are true, the event is
rejected as not sustained.{p_end}

{phang2}3. For rejected events, replace the candidate EDSS with the last value
observed in the window and repeat from step 1.{p_end}

{phang2}4. Continue until all remaining threshold-crossing events are confirmed as
sustained (or no candidates remain).{p_end}

{pstd}
The input data must be in long format: one row per EDSS measurement per patient,
with a patient ID, an EDSS score, and a measurement date.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt threshold(#)} specifies the EDSS value that defines the progression milestone.
Common choices are {cmd:4} (moderate disability, ambulatory without aid) and
{cmd:6} (requires unilateral walking aid).  The value must be positive.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name of the new date variable.  The default
is {it:sustained#_dt} where {it:#} is the threshold value (decimal points are
replaced by underscores, so {cmd:threshold(3.5)} produces {cmd:sustained3_5_dt}).

{phang}
{opt confirmwindow(#)} specifies the number of days after the initial
threshold-crossing within which EDSS must be sustained.  The default is {cmd:182}
(approximately 6 months), standard in MS research.

{phang}
{opt baselinethreshold(#)} specifies the EDSS level used to check for reversal.
If the lowest EDSS in the confirmation window falls below this value AND the last
EDSS in the window falls below {opt threshold()}, the event is rejected.  The
default equals {opt threshold()}.  Setting this to a lower value (e.g.,
{cmd:baselinethreshold(3)} with {cmd:threshold(4)}) makes the algorithm more
tolerant of temporary dips: only a drop all the way below 3 would disqualify
the event.

{phang}
{opt keepall} retains all observations from the original dataset, adding the
sustained date variable with missing values for patients without sustained events.
By default, only rows for patients who experienced a sustained event are kept.

{phang}
{opt quietly} suppresses the iteration progress messages and the summary
output displayed after computation.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Choosing between sustainedss, cdp, and pira}

{pstd}
All three MS progression commands in {helpb setools} measure disability
worsening, but they answer different questions:

{phang2}{cmd:sustainedss} {hline 2} "When did EDSS first reach {ul:>}= X and stay
there?"  Absolute threshold crossing.  No baseline reference, no diagnosis date
needed.{p_end}

{phang2}{helpb cdp} {hline 2} "When did EDSS first worsen by {ul:>}= 1.0 (or 0.5)
points from baseline, confirmed at 6 months?"  Change from a patient-specific
baseline.  Requires diagnosis date.{p_end}

{phang2}{helpb pira} {hline 2} "Was that confirmed progression driven by
neurodegeneration or by a relapse?"  Classifies each CDP event.  Requires
both a diagnosis date and a relapse file.{p_end}

{pstd}
{bf:Edge case: no measurements in the confirmation window}

{pstd}
If a patient reaches the threshold but has no subsequent EDSS measurements within
{opt confirmwindow()} days, the event is treated as sustained (absence of evidence
is not evidence of reversal).  This differs from {helpb cdp}, which requires at
least one confirming measurement after {opt confirmdays()}.

{pstd}
{bf:Duplicate EDSS on the same date}

{pstd}
If multiple EDSS scores exist on the same date for the same patient, the lowest
value on that date is used for confirmation checks.  This conservative approach
reduces false positives.  Consider resolving duplicates before running the
command.

{pstd}
{bf:Patients already above threshold}

{pstd}
Patients whose first EDSS already meets the threshold will be reported as reaching
it on that date (assuming confirmation is not disconfirmed).  If these patients
should be excluded from your analysis, filter them before running {cmd:sustainedss}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Sustained EDSS {ul:>}= 4}

{pstd}
Find the first date each patient reached and sustained EDSS 4 or above, using the
default 182-day confirmation window.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(4)":. sustainedss id edss edss_date, threshold(4)}{p_end}
{phang2}{stata "return list":. return list}{p_end}

{pstd}
{bf:Example 2: Sustained EDSS {ul:>}= 6 with a custom variable name}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(6) generate(edss6_sustained)":. sustainedss id edss edss_date, threshold(6) generate(edss6_sustained)}{p_end}

{pstd}
{bf:Example 3: Three-month confirmation window}

{pstd}
Some study protocols use a 90-day confirmation rule.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(4) confirmwindow(90)":. sustainedss id edss edss_date, threshold(4) confirmwindow(90)}{p_end}

{pstd}
{bf:Example 4: Keep all patients and create a binary indicator}

{pstd}
Retain the full dataset, then create a 0/1 flag for downstream analysis.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(4) keepall":. sustainedss id edss edss_date, threshold(4) keepall}{p_end}
{phang2}{stata "gen byte reached_edss4 = !missing(sustained4_dt)":. gen byte reached_edss4 = !missing(sustained4_dt)}{p_end}
{phang2}{stata "tab reached_edss4":. tab reached_edss4}{p_end}

{pstd}
{bf:Example 5: Use sustained date in survival analysis}

{pstd}
After computing the sustained date, feed it into {cmd:stset} as the failure
date.{p_end}

{phang2}{cmd:. sustainedss id edss edss_date, threshold(6) keepall}{p_end}
{phang2}{cmd:. gen byte event = !missing(sustained6_dt)}{p_end}
{phang2}{cmd:. gen double end_date = cond(event, sustained6_dt, edss_date)}{p_end}
{phang2}{cmd:. bysort id (edss_date): replace end_date = end_date[_N]}{p_end}
{phang2}{cmd:. bysort id: keep if _n == 1}{p_end}
{phang2}{cmd:. stset end_date, failure(event) origin(dx_date)}{p_end}
{phang2}{cmd:. sts graph}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:sustainedss} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_events)}}number of patients with a sustained event{p_end}
{synopt:{cmd:r(iterations)}}number of iterations required by the algorithm{p_end}
{synopt:{cmd:r(converged)}}{cmd:1} if algorithm converged; {cmd:0} if iteration limit reached{p_end}
{synopt:{cmd:r(threshold)}}EDSS threshold used{p_end}
{synopt:{cmd:r(confirmwindow)}}confirmation window in days{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of the generated date variable{p_end}


{marker references}{...}
{title:References}

{phang}
Kappos L, et al. Inclusion of brain volume loss in a revised measure of
'no evidence of disease activity' (NEDA-4) in relapsing-remitting
multiple sclerosis. {it:Multiple Sclerosis Journal}. 2016;22(10):1297{c -}1305.

{phang}
Confavreux C, Vukusic S. Natural history of multiple sclerosis: a unifying
concept. {it:Brain}. 2006;129(3):606{c -}616.


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
{help pira:pira} {hline 2} Progression Independent of Relapse Activity{p_end}
{pstd}
{help migrations:migrations} {hline 2} Process Swedish migration registry data{p_end}

{psee}
Manual: {manlink ST stset}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

{hline}
