{smcl}
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
{synopt:{opt gen:erate(name)}}generated date variable name{p_end}
{synopt:{opt conf:irmwindow(#)}}bounded period; default 182 days{p_end}
{synopt:{opt conf:irmvisit(mode)}}require an observed confirming visit{p_end}
{synopt:{opt base:linethreshold(#)}}EDSS reversal floor{p_end}
{synopt:{opt event:var(name)}}0/1 sustained-event indicator{p_end}
{synopt:{opt exit(varname)}}per-person study-exit date{p_end}
{synopt:{opt keep:all}}retain observations without events{p_end}
{synopt:{opt q:uietly}}suppress iteration messages and summary output{p_end}
{synoptline}
{p2colreset}{...}

{p 8 17 2}
{it:idvar} identifies patients (numeric or string). {it:edssvar} is the numeric EDSS
score. {it:datevar} must be a Stata daily date stored as a whole-number value with
a {cmd:%td} display format. Other time encodings ({cmd:%tm}, {cmd:%tq},
{cmd:%tc}) are rejected because {opt confirmwindow()} is interpreted in days.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:sustainedss} finds the first date each patient's EDSS (Expanded Disability
Status Scale) reaches or exceeds a user-specified threshold without a later
observed EDSS below the reversal floor. By default, no later visit is required,
so an event with no subsequent assessment is sustained by implication. Use
{opt confirmvisit()} when the analysis requires an observed confirming visit.

{pstd}
This is a {it:threshold crossing} measure: "When did the patient first reach EDSS
{ul:>}= 4 (or 6, etc.) and remain there?"  It does not reference a baseline EDSS or
compute a change score. For a {it:change-from-baseline} progression measure, see
{helpb cdp}.

{pstd}
{bf:Algorithm:}

{phang2}1. Find the first date EDSS {ul:>}= {opt threshold()} for each patient.{p_end}

{phang2}2. Apply the selected confirmation mode. The default accepts the
candidate if no later observed EDSS is below {opt baselinethreshold()}, including
when there is no later visit. {cmd:confirmvisit(window)} requires the first later
visit within {opt confirmwindow()} to meet {opt threshold()} and no value through
the window to fall below the reversal floor. {cmd:confirmvisit(unlimited)}
requires the first later visit, however late, to meet {opt threshold()} and no
later value to fall below the floor.{p_end}

{phang2}3. Remove a rejected candidate and test that patient's next threshold
crossing. Continue until each patient has an accepted event or no candidate
remains.{p_end}

{pstd}
The input data must be in long format: one row per EDSS measurement per patient,
with a patient ID, an EDSS score, and a measurement date.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt threshold(#)} specifies the EDSS value that defines the progression
milestone. Common choices are {cmd:4} (moderate disability, ambulatory without aid)
and {cmd:6} (requires unilateral walking aid). The value must be positive.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name of the new date variable. The default
is {it:sustained#_dt} where {it:#} is the threshold value (decimal points are
replaced by underscores, so {cmd:threshold(3.5)} produces {cmd:sustained3_5_dt}).

{phang}
{opt confirmwindow(#)} specifies the number of days after the initial
threshold crossing used by {cmd:confirmvisit(window)}. The default is {cmd:182}
(approximately 6 months). It does not limit follow-up in the default or
{cmd:confirmvisit(unlimited)} modes.

{phang}
{opt confirmvisit(mode)} requires an observed later assessment. Specify
{cmd:window} to require the first later assessment on or before the candidate
date plus {opt confirmwindow()}. Specify {cmd:unlimited} to use the first later
assessment with no maximum delay. In either mode the first later assessment
must meet {opt threshold()}, so the command cannot skip a lower intervening
assessment to find a later high value. The default is no {opt confirmvisit()},
so no later assessment is required.

{phang}
{opt baselinethreshold(#)} specifies the EDSS reversal floor. The default equals
{opt threshold()}. Any observed later EDSS below the floor rejects a candidate
across all available follow-up in the default and unlimited modes, or through
the bounded period in window mode. A lower value explicitly permits that amount
of tolerance; for example, with {cmd:threshold(4) baselinethreshold(3)}, only a
later value below 3 reverses the candidate.

{phang}
{opt eventvar(name)} creates a 0/1 indicator equal to 1 for persons with a sustained
date and 0 otherwise, within the estimation sample, ready for {helpb stset}. It is
most useful together with {opt keepall}. The name must be new and differ from
{opt generate()}.

{phang}
{opt exit(varname)} names a per-person study-exit date (a numeric Stata daily date
with a {cmd:%td} format). When the computed sustained date falls strictly after a
person's exit date, the date is set to missing and {opt eventvar()} (if requested)
is set to 0 {hline 1} the event is censored as occurring outside the observation
window. This replaces the hand-written {cmd:replace sustained#_dt = . if}
{cmd:sustained#_dt > study_exit} that follows most {cmd:sustainedss} calls. Persons with a
missing exit date are left unchanged. The observation is retained; pair with
{opt eventvar()} for a clean {helpb stset}-ready indicator.

{phang}
{opt keepall} retains all observations from the original dataset, adding the
sustained date variable with missing values for patients without sustained
events. By default, only rows for patients who experienced a sustained event
are kept; the exception is exit-censored persons, who carry a valid (0)
{opt eventvar()} indicator and are therefore retained even without {opt keepall}.

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
there?"  Absolute threshold crossing. No baseline reference, no diagnosis date
needed.{p_end}

{phang2}{helpb cdp} {hline 2} "When did EDSS first worsen by {ul:>}= 1.0 (or 0.5)
points from baseline, confirmed at 6 months?"  Change from a patient-specific
baseline. Requires diagnosis date.{p_end}

{phang2}{helpb pira} {hline 2} "Was the first confirmed progression associated
with a relapse?" Requires both a diagnosis date and a relapse file.{p_end}

{pstd}
{bf:Default package convention and observed confirmation}

{pstd}
The default deliberately treats a threshold crossing with no later assessment
as sustained by implication. This is a package convention chosen for this
command, not a claim that an unobserved confirmation satisfies stricter
published endpoint definitions. Use {cmd:confirmvisit(window)} for bounded
observed confirmation or {cmd:confirmvisit(unlimited)} when a later confirming
visit is required but may occur at any subsequent time. {helpb cdp} always
requires an observed confirming assessment.

{pstd}
{bf:Duplicate EDSS on the same date}

{pstd}
If multiple EDSS scores exist on the same date for the same patient, the lowest
value on that date is used for confirmation checks. This conservative approach
reduces false positives. Consider resolving duplicates before running the
command.

{pstd}
{bf:Patients already above threshold}

{pstd}
Patients whose first EDSS already meets the threshold will be reported as
reaching it on that date (assuming confirmation is not disconfirmed). If these
patients should be excluded from your analysis, filter them before running
{cmd:sustainedss}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Sustained EDSS {ul:>}= 4}

{pstd}
Find the first date each patient reached EDSS 4 or above with no later observed
EDSS below 4. No confirming visit is required by default.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(4)":. sustainedss id edss edss_date, threshold(4)}{p_end}
{phang2}{stata "return list":. return list}{p_end}

{pstd}
{bf:Example 2: Sustained EDSS {ul:>}= 6 with a custom variable name}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(6) generate(edss6_sustained)":. sustainedss id edss edss_date, threshold(6) generate(edss6_sustained)}{p_end}

{pstd}
{bf:Example 3: Require confirmation within three months}

{pstd}
Require a later assessment within 90 days and no reversal through day 90.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(4) confirmvisit(window) confirmwindow(90)":. sustainedss id edss edss_date, threshold(4) ///}{p_end}
{phang3}{cmd:confirmvisit(window) confirmwindow(90)}{p_end}

{pstd}
{bf:Example 4: Require a later visit with unlimited follow-up}

{phang2}{stata "sustainedss id edss edss_date, threshold(4) confirmvisit(unlimited)":. sustainedss id edss edss_date, threshold(4) ///}{p_end}
{phang3}{cmd:confirmvisit(unlimited)}{p_end}

{pstd}
{bf:Example 5: Keep all patients and create a binary indicator}

{pstd}
Retain the full dataset, then create a 0/1 flag for downstream analysis.{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear"':. use "https://.../relapses.dta", clear}{p_end}
{phang2}{stata "sustainedss id edss edss_date, threshold(4) keepall":. sustainedss id edss edss_date, threshold(4) keepall}{p_end}
{phang2}{stata "gen byte reached_edss4 = !missing(sustained4_dt)":. gen byte reached_edss4 = !missing(sustained4_dt)}{p_end}
{phang2}{stata "tab reached_edss4":. tab reached_edss4}{p_end}

{pstd}
{bf:Example 6: Use sustained date in survival analysis}

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
{synopt:{cmd:r(converged)}}whether the algorithm converged{p_end}
{synopt:{cmd:r(threshold)}}EDSS threshold used{p_end}
{synopt:{cmd:r(confirmwindow)}}confirmation window in days{p_end}
{synopt:{cmd:r(N_censored_exit)}}events censored after study exit; only with {opt exit()}{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of the generated date variable{p_end}
{synopt:{cmd:r(confirmvisit)}}confirmation mode; blank, {cmd:window}, or {cmd:unlimited}{p_end}
{synopt:{cmd:r(eventvar)}}event-indicator name, if requested{p_end}
{synopt:{cmd:r(exit)}}study-exit variable name; only with {opt exit()}{p_end}


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
