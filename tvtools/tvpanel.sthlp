{smcl}
{* *! version 1.0.2  19jun2026}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvage" "help tvage"}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{viewerjumpto "Syntax" "tvpanel##syntax"}{...}
{viewerjumpto "Description" "tvpanel##description"}{...}
{viewerjumpto "Options" "tvpanel##options"}{...}
{viewerjumpto "Active class and cumulative exposure" "tvpanel##semantics"}{...}
{viewerjumpto "tvexpose vs tvpanel" "tvpanel##compare"}{...}
{viewerjumpto "Stored results" "tvpanel##stored"}{...}
{viewerjumpto "Examples" "tvpanel##examples"}{...}
{viewerjumpto "Author" "tvpanel##author"}{...}

{title:Title}

{phang}
{bf:tvpanel} {hline 2} Fixed-width, entry-anchored person-period panel for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvpanel} {cmd:using} {it:filename}{cmd:,}
{opth id(varname)}
{opth entry(varname)}
{opth exit(varname)}
{opth exposure(name)}
[{it:options}]

{pstd}
The data in memory is the {bf:master}: one row per person with the study {opt entry()}
and {opt exit()} dates. {it:filename} is the {bf:episode} file: exposure periods with
{opt id()}, a start, a stop, and an integer exposure-class variable.

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opth id(varname)}}person identifier, present in master and episode file{p_end}
{synopt:{opth entry(varname)}}study entry date in the master (anchors the grid){p_end}
{synopt:{opth exit(varname)}}study exit date in the master{p_end}
{synopt:{opth exposure(name)}}integer exposure-class variable in the episode file{p_end}

{syntab:Grid}
{synopt:{opt width(#)}}interval width in days; default {cmd:width(91)}{p_end}
{synopt:{opt ref:erence(#)}}value marking unexposed/reference; default {cmd:reference(0)}{p_end}
{synopt:{opt start(name)}}episode start date in the using file; default {cmd:start}{p_end}
{synopt:{opt stop(name)}}episode stop date in the using file; default {cmd:stop}{p_end}

{syntab:Output names}
{synopt:{opt per:iod(name)}}0-based integer period index; default {cmd:period}{p_end}
{synopt:{opt startgen(name)}}interval start-date variable; default {cmd:start}{p_end}
{synopt:{opt stopgen(name)}}interval stop-date variable; default {cmd:stop}{p_end}
{synopt:{opt gen:erate(name)}}active exposure-class variable; default {cmd:tv_class}{p_end}
{synopt:{opt cum:ulative(unit)}}emit per-class cumulative exposure as of interval start, in {cmd:days}, {cmd:weeks}, {cmd:months}, {cmd:quarters}, or {cmd:years}{p_end}
{synopt:{opt pre:fix(string)}}prefix for the cumulative variable names (default none, giving {cmd:cum_}{it:class}){p_end}

{syntab:Other}
{synopt:{opth keepvars(varlist)}}master variables carried onto every period row{p_end}
{synopt:{opt saveas(filename)}}save the panel to disk instead of loading it into memory{p_end}
{synopt:{opt replace}}allow {opt saveas()} to overwrite{p_end}
{synopt:{opt noi:sily}}display a build summary{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvpanel} expands each person's follow-up into {bf:fixed-width intervals anchored at
study entry}: interval {it:k} runs from {cmd:entry + width*k} to
{cmd:entry + width*(k+1) - 1}, clipped at {opt exit()}. Every interval is emitted for
all person-time, exposed and unexposed, with a 0-based integer {opt period()} index
suitable for {helpb msm_prepare}'s {cmd:period()}. For each interval it reports the
{bf:active exposure class at the interval start} and, optionally, the {bf:per-class
cumulative exposure accrued as of the interval start}.

{pstd}
This is the grid that marginal structural models need: weights and the weighted outcome
model key off the integer period, and the exact uniform spacing keeps any lagged
cumulative-exposure derivation aligned to the day. {cmd:tvpanel} is the entry point for
building that grid before {helpb msm_prepare}/{helpb msm_weight}.


{marker options}{...}
{title:Options}

{phang}
{opth id(varname)}, {opth entry(varname)}, {opth exit(varname)} identify the person and
the study window in the master data (one row per person). {opt entry()} anchors the grid.

{phang}
{opth exposure(name)} is the integer exposure-class variable in the episode file. Values
must be integers (they become the suffix of the cumulative variables and the values of the
active-class variable); {opt cumulative()} additionally requires non-negative codes, since
class values become variable-name suffixes. Any value label on this variable is carried onto
{opt generate()}. Episode {opt start()}/{opt stop()} must be daily {bf:%td} dates, not
datetime ({bf:%tc}); interval arithmetic is in whole days.

{phang}
{opt width(#)} sets the interval width in days. {cmd:width(91)} (the default) gives the
quarterly grid used by most MSM pipelines. Unlike a calendar quarter, this is exactly 91
days, so interval starts never drift from {cmd:entry + width*k}.

{phang}
{opt reference(#)} is the value assigned to {opt generate()} on intervals with no covering
episode (unexposed person-time). Episodes whose class equals {opt reference()} are ignored
for cumulative exposure.

{phang}
{opt start(name)} and {opt stop(name)} name the episode start/stop dates in the using file
(defaults {cmd:start} and {cmd:stop}). Episodes are taken as supplied: bake any drug-class
carryover or washout into the episode stop before calling {cmd:tvpanel}.

{phang}
{opt cumulative(unit)} adds one variable per non-reference class, {cmd:cum_}{it:class}
(or {opt prefix()}{cmd:cum_}{it:class}), holding cumulative exposure in {it:unit} accrued
strictly before the interval start. See {help tvpanel##semantics:below}.


{marker semantics}{...}
{title:Active class and cumulative exposure}

{pstd}
{bf:Active class.} At each interval start, the active class is the episode with the latest
start date that covers the interval start (ties broken by the larger class value). Bake
carryover into the episode stop so a drug remains "active" through its carryover window.

{pstd}
{bf:Cumulative exposure} is evaluated {bf:as of the interval start} (non-anticipating): for
each class it sums exposure-days in {cmd:[episode start, interval start - 1]} and converts
to the requested unit. The current interval's own exposure is not yet counted, so the value
entering period {it:k} reflects only history before {it:k}.

{pstd}
{bf:Lagged cumulative exposure} (e.g. cumulative as of {cmd:interval start - 730 days}) is a
thin downstream step, not produced here: subtract the trailing-window exposure from the
running total, or difference the cumulative series. {cmd:tvexpose}'s {opt lag()} is an
induction/washout lag (front of episode), not an evaluation lag, and must not be used for
this.


{marker compare}{...}
{title:tvexpose vs tvpanel}

{pstd}
{helpb tvexpose} splits person-time at {bf:exposure-change boundaries} and, with
{opt expandunit()}, expands using {bf:calendar-average} widths anchored at each episode
(a "quarter" is ~91.31 days). That is right for episode-centric dose-response work but
drifts off a fixed grid and omits a uniform integer period.

{pstd}
{cmd:tvpanel} lays down a {bf:uniform grid anchored at study entry} with an exact width and
an integer period, over all person-time, with no exposure-change splits. Use {cmd:tvpanel}
when the downstream model is an MSM keyed by period; use {helpb tvexpose} when you want one
row per exposure episode or per calendar bin.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:tvpanel} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(n_persons)}}persons in the panel{p_end}
{synopt:{cmd:r(n_observations)}}period rows{p_end}
{synopt:{cmd:r(width)}}interval width in days{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(periodvar)}}name of the period variable{p_end}
{synopt:{cmd:r(startvar)}}name of the interval start variable{p_end}
{synopt:{cmd:r(stopvar)}}name of the interval stop variable{p_end}
{synopt:{cmd:r(classvar)}}name of the active-class variable{p_end}
{synopt:{cmd:r(cumvars)}}names of the cumulative variables{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Quarterly MSM grid with per-class cumulative exposure-years:{p_end}

{phang2}{cmd:. use cohort_master, clear}     {it:(id, index_date, study_exit per person)}{p_end}
{phang2}{cmd:. tvpanel using dmt_episodes, id(id) entry(index_date) exit(study_exit) ///}{p_end}
{phang2}{cmd:.     exposure(dmt_class) reference(0) width(91) period(qtr) cumulative(years)}{p_end}

{pstd}Then feed the grid to the MSM pipeline:{p_end}

{phang2}{cmd:. msm_prepare, id(id) period(qtr) treatment(...) outcome(...)}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
