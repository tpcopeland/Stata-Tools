# tvtools — Time-varying exposure workflow for survival analysis

**Version 1.13.0** | 2026-08-02

`tvtools` turns person-level follow-up and episode records into analysis-ready time-varying survival data. It provides a transactional build path, composable interval primitives, diagnostics, weighting, fixed-width panels, and exact calendar-timescale splitting.

## Quick Start

This end-to-end example uses inline data and temporary files, so it runs after public installation from any working directory:

~~~stata
clear
input long id str9(entry_s exit_s event_s) byte female
1 "01jan2020" "31dec2020" "20jan2020" 1
2 "01jan2020" "31dec2020" "" 0
end
generate double study_entry = date(entry_s, "DMY")
generate double study_exit = date(exit_s, "DMY")
generate double event_date = date(event_s, "DMY")
format study_entry study_exit event_date %td
drop entry_s exit_s event_s
tempfile cohort episodes
save `cohort'

clear
input long id str9(start_s stop_s) byte rx_class
1 "05jan2020" "20feb2020" 1
1 "01mar2020" "15apr2020" 2
2 "10jun2020" "31jul2020" 1
end
generate double rx_start = date(start_s, "DMY")
generate double rx_stop = date(stop_s, "DMY")
format rx_start rx_stop %td
drop start_s stop_s
save `episodes'

use `cohort', clear
tvbuild, sourceusing(`"`episodes'"') id(id) entry(study_entry) exit(study_exit) ///
    start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///
    generate(tv_drug) frameout(analysis) eventdate(event_date) ///
    eventgenerate(_failure) replace
frame analysis: tvdiagnose, id(id) start(start) stop(stop) ///
    entry(study_entry) exit(study_exit) exposure(tv_drug) all
frame change analysis
generate double analysis_t0 = start - 1
stset stop, id(id) failure(_failure == 1) time0(analysis_t0)
~~~

`tvbuild` leaves the person-level master unchanged, commits the interval result in frame `analysis`, and creates `analysis_manifest` unless `nomanifest` is specified. The subtraction of one day maps the package's closed [start, stop] intervals to Stata's open-left survival-time convention.

## Requirements

- Stata 16 or later.
- No required community package.
- Optional `psdash` for `tvweight, loveplot`; weighting, balance output, and the returned `r(balance)` matrix do not require it.
- Optional `msm` for downstream `msm_prepare` and `msm_weight` workflows after `tvpanel`.

## Installation

Install the released package from Stata-Tools:

~~~stata
capture ado uninstall tvtools
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace
~~~

Install optional integrations only when those workflows are needed:

~~~stata
net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace
net install msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace
~~~

The ancillary menu helper is available with `net get tvtools`; run `do tvtools_menu_setup.do` only if you want to add its Stata menu entry.

## Commands

| Command | Purpose | Help |
|---|---|---|
| `tvtools` | List and categorize the suite. | `help tvtools` |
| `tvbuild` | Build a committed interval frame from a cohort and one or more sources. | `help tvbuild` |
| `tvspec` | Create and inspect the multi-source specification frame consumed by `tvbuild`. | `help tvspec` |
| `tvexpose` | Convert raw episodes or point-time records into time-varying exposure intervals. | `help tvexpose` |
| `tvmerge` | Align two or more interval datasets and combine their exposure quantities. | `help tvmerge` |
| `tvevent` | Add single, competing, or recurrent events to interval data. | `help tvevent` |
| `tvdiagnose` | Report coverage, gaps, overlaps, exposure summaries, and swimlanes. | `help tvdiagnose` |
| `tvweight` | Estimate treatment and censoring weights and report balance and overlap diagnostics. | `help tvweight` |
| `tvage` | Expand one row per person into exact calendar-age intervals. | `help tvage` |
| `tvband` | Split existing intervals on one age, calendar, or elapsed-time axis. | `help tvband` |
| `tvsplit` | Split existing intervals on several Lexis timescales at once. | `help tvsplit` |
| `tvpanel` | Build a fixed-width, entry-anchored person-period grid for MSM work. | `help tvpanel` |

## How It Works

`tvbuild` is the recommended front door for a cohort plus one or more longitudinal sources: it normalizes a one-source shortcut or a typed `tvspec` frame, performs a read-only preflight, constructs intervals through the shared engines, optionally integrates events, and commits the destination frame and provenance manifest transactionally.

The primitive workflow is `tvexpose` → `tvmerge` → `tvevent` → `tvdiagnose` and/or `tvweight`. The primitives remain the right choice when the exposure definition, overlap rule, quantity algebra, or alignment must remain visible as a separate analytical decision.

Every interval in the construction commands is a closed, inclusive interval of integer Stata daily dates, `[start, stop]`. Abutting rows satisfy `next_start = prior_stop + 1`; a shared date is an overlap, not an abutment.

`tvage`, `tvband`, and `tvsplit` add exact birthday, calendar, and elapsed-time axes, while `tvpanel` creates a uniform entry-anchored grid and can carry cumulative exposure history into each period.

## Choosing a Workflow

| Need | Use | Result |
|---|---|---|
| One or several sources with a committed, auditable destination | `tvspec` + `tvbuild` | Named output frame, optional manifest, stage counts, and a verified signature. |
| An advanced exposure rule or custom interval alignment | `tvexpose`, `tvmerge`, and `tvevent` | Explicit primitive stages that can be inspected or chained through frames. |
| A uniform panel for time-varying treatment models | `tvpanel`, then `tvweight` | Entry-anchored periods, active class, and optional cumulative histories. |
| Age, calendar, or follow-up timescale splitting | `tvage`, `tvband`, or `tvsplit` | Inclusive sub-intervals with exact calendar boundaries. |

## Worked Examples

### 1. Plan before committing with tvbuild

With the `cohort` and `episodes` files from Quick Start, `dryrun` validates the plan and changes nothing; the second call commits the same plan to `analysis`:

~~~stata
use cohort, clear
tvbuild, sourceusing("episodes.dta") id(id) entry(study_entry) exit(study_exit) ///
    start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///
    generate(tv_drug) frameout(analysis) dryrun
tvbuild, sourceusing("episodes.dta") id(id) entry(study_entry) exit(study_exit) ///
    start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///
    generate(tv_drug) frameout(analysis) manifestframe(provenance) replace
frame provenance: list stage source_name n_input n_output, noobs
~~~

### 2. Describe multiple sources with tvspec

`tvspec` appends one typed row per source and preserves row order; `tvbuild` applies cross-source rules and performs the build:

~~~stata
tvspec create pipe_spec, replace
tvspec add pipe_spec, name(drug) frame(rx_frame) start(rx_start) stop(rx_stop) ///
    exposure(rx_class) generate(tv_drug) reference(0)
tvspec add pipe_spec, name(lab) frame(lab_frame) start(start) stop(stop) ///
    exposure(lab_level) generate(tv_lab) kind(intervals)
use cohort, clear
tvbuild, specframe(pipe_spec) id(id) entry(study_entry) exit(study_exit) ///
    frameout(analysis) manifestframe(provenance) replace
~~~

The first source is raw episodes and therefore needs a reference category; the second is already interval data and does not take `reference()`. `tvspec` validates the row being appended, while `tvbuild` validates the complete plan.

### 3. Keep a primitive pipeline in frames

`frameout()` leaves the current master untouched, and `frames()` lets `tvmerge` consume the named intermediate results without save/use round trips:

~~~stata
use cohort, clear
tvexpose using drug_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_drug) frameout(f_drug) replace
tvexpose using benzo_episodes.dta, id(id) start(bz_start) stop(bz_stop) ///
    exposure(benzo_class) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_benzo) frameout(f_benzo) replace
tvmerge, frames(f_drug f_benzo) id(id) start(rx_start bz_start) ///
    stop(rx_stop bz_stop) exposure(tv_drug tv_benzo) frameout(f_merged) replace
tvevent, frame(f_merged) id(id) date(event_date) start(start) stop(stop) ///
    generate(_failure)
~~~

The event master remains in memory while `tvevent` reads the interval frame; its default event indicator is `_failure`.

### 4. Track dose history on a regular exposure scale

In dose mode the `exposure()` variable is the dose amount, `reference()` defaults to zero, and the current row's dose is not included in its cumulative history:

~~~stata
use cohort, clear
tvexpose using dose_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose_mg) dose continuousunit(years) expandunit(months) ///
    entry(study_entry) exit(study_exit) generate(cum_dose) keepdates
tvdiagnose, id(id) start(rx_start) stop(rx_stop) exposure(cum_dose) summarize
~~~

Use `split` and `combine()` when simultaneous categorical exposures should remain separate and receive an explicit composition code instead of later exposure precedence.

### 5. Format recurrent events for total-time or gap-time models

For a recurring wide event stub such as `hosp1`, `hosp2`, and so on, use `eventtype(recurring)`; `enum()` creates the event-sequence stratum and `gaptime` adds a reset clock:

~~~stata
frame ev_frame: use recurrent_events.dta, clear
use cohort, clear
tvbuild, sourceusing("episodes.dta") id(id) entry(study_entry) exit(study_exit) ///
    start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///
    generate(tv_drug) frameout(analysis) replace eventframe(ev_frame) ///
    eventdate(hosp) eventtype(recurring) enum(_enum) gaptime
~~~

### 6. Build an MSM panel and estimate weights

`tvpanel` emits every entry-anchored period, including reference periods, and `tvweight` can use its period index for a cumulative treatment model:

~~~stata
tvpanel using episodes.dta, id(id) entry(study_entry) exit(study_exit) ///
    exposure(drug_class) width(91) period(period) generate(tv_class) ///
    keepvars(age sex comorbidity)
tvweight tv_class, covariates(age sex comorbidity) id(id) time(period) ///
    stabilized cumulative balance generate(iptw)
~~~

Add `ipcw(censored)`, `censorcovariates()`, and `combgenerate()` when a 0/1 censoring indicator and a combined treatment-by-censoring weight are required.

### 7. Split one interval on several time axes

`tvsplit` accepts at least one axis and carries the other variables onto every resulting row:

~~~stata
tvsplit, id(id) start(start) stop(stop) ///
    age(dob, width(5) generate(ageband)) ///
    calendar(, width(1) anchor(2020) generate(calband)) ///
    elapsed(study_entry, width(1) unit(year) generate(fuband))
~~~

For one axis with file output and restoration of the input data, use `tvband`; for one row per person and age-only output, use `tvage`.

## Key Options

### Dates, identifiers, and intervals

Use numeric Stata daily dates for all interval bounds and event dates; fractional dates, missing required dates, and reversed bounds are rejected unless a command explicitly offers `dropinvalid`. Most interval commands require the same identifier name and storage type across master and sources, reject `strL` identifiers, and never silently recast IDs.

The package's intervals are closed and inclusive, so duration is `stop - start + 1`. When declaring the result with `stset`, use `time0(start - 1)` to map each row to Stata's open-left convention.

### Output and transactions

`frameout()` stages a result in a named frame and leaves the current data untouched where that option is supported; `saveas()` writes a file and restores the caller's data for the commands that document that behavior. Without either option, the interval-building commands replace the current data.

`replace` is required before an existing file or frame is overwritten. `tvbuild` requires `frameout()`, leaves all input frames untouched, and builds a manifest named `<frameout>_manifest` by default; use `manifestframe()` or `nomanifest` to control it.

### Quantities and exposure definitions

`rate()` variables remain rates when intervals are split; `total()` variables are apportioned by inclusive overlap days; and `cumulative()` variables are row-start histories carried unchanged. `continuous()` is a deprecated alias for `total()` in `tvmerge` and `tvevent`.

In `tvexpose`, the default categorical output uses `reference()` for uncovered time, while `dose` mode defaults the reference to zero. `continuousunit()` accepts days, weeks, months, quarters, or years; `expandunit()` defaults to that unit when continuous exposure is requested and uses fixed average widths of 7, 30.4375, 91.3125, or 365.25 days anchored at each episode start.

## Command Reference

### tvtools

Syntax:

~~~stata
tvtools [, list detail category(string)]
~~~

`category()` defaults to `all` and accepts `all`, `prep`, `diag`, or `weight`. `list` prints command names; `detail` prints descriptions.

### tvspec

Syntax:

~~~stata
tvspec create framename [, replace]
tvspec add framename, name(name) (frame(name) | using(filename)) ///
    start(name) stop(name) exposure(namelist) generate(namelist) ///
    [reference(#) kind(episodes|intervals) referencelabel(string) ///
     label(string) description(string) rate(namelist) total(namelist) ///
     cumulative(namelist)]
tvspec list framename
~~~

`tvspec create` writes the empty typed schema; `tvspec add` defaults `kind(episodes)`, requires exactly one of `frame()` and `using()`, and maps `exposure()` to `generate()` positionally. Episode rows require `reference()`; interval rows use `kind(intervals)` and must not specify a reference. `rate()`, `total()`, and `cumulative()` are optional subsets of `exposure()`. `tvspec list` displays the rows without changing them.

### tvbuild

Syntax:

~~~stata
tvbuild, specframe(name) id(varname) entry(varname) exit(varname) ///
    frameout(name) [options]
tvbuild, (sourceframe(name) | sourceusing(filename)) id(varname) ///
    entry(varname) exit(varname) start(name) stop(name) exposure(name) ///
    reference(#) generate(name) frameout(name) [options]
~~~

The inline form requires exactly one source locator and describes one categorical episode source. The specification form takes all source rows from `specframe()`, which can mix `episodes` and ready-made `intervals` sources. The current frame is the one-row-per-person master; `frameout()` is required and the master is never replaced.

| Option group | Options and defaults |
|---|---|
| Inline source | `sourcename()` defaults to `generate()`; `referencelabel()` and `label()` are optional. |
| Output | `startname(start)`, `stopname(stop)`, and `dateformat(%tdCCYY/NN/DD)` default as shown; `keepvars()` carries master variables; `dropdates` omits entry and exit from output. |
| Coverage | `coverage(strict)` is the default; `coverage(allow)` permits the configured permissive coverage policy. |
| Events | `eventdate()` activates events; `eventframe()` and `eventusing()` are alternative event sources; `eventtype(single)`, `eventgenerate(_failure)`, and `timeunit(days)` default as shown. |
| Recurring events | With `eventtype(recurring)`, `enum()` is the event-sequence stratum and `gaptime` adds `gapstart(_t0)` and `gapstop(_t)` by default; `compete()` is for single events. |
| Transaction | `manifestframe()` defaults to `<frameout>_manifest`; `nomanifest` suppresses it; `dryrun` performs planning only; `replace` authorizes replacement of named destinations. |

### tvexpose

Syntax:

~~~stata
tvexpose using filename, id(varname) start(varname) exposure(varname) ///
    [reference(#)] entry(varname) exit(varname) [options]
~~~

The source is raw episodes unless `pointtime` is specified, in which case `stop()` is omitted and each record applies on its start date. Ordinary categorical definitions require `reference()`; `dose` mode treats `exposure()` as an amount and defaults the reference to zero.

| Option group | Options and defaults |
|---|---|
| Exposure definition | Basic categorical output is the default; `evertreated`, `currentformer`, `duration()`, `continuousunit()`, `expandunit()`, `bytype`, `recency()` with `recencyunit(days|years)`, `dose` with optional `dosecuts()` are alternatives or modifiers documented in the help. |
| Data handling | `grace(0)` and `merge(0)` are the defaults; `fillgaps()`, `carryforward()`, and `dropinvalid` are optional. |
| Overlaps | `layer` is the default later-exposure precedence rule; `priority()` changes precedence; `split` preserves overlapping strata; `combine()` adds a composition code. |
| Timing | `lag(0)` and `washout(0)` are the defaults; `window(min max)` restricts each episode to inclusive offsets. |
| History | `switching` creates `ever_switched`, `switchingdetail` creates `switching_pattern`, and `statetime` creates `state_time_years`. |
| Output | `generate()` defaults to a derived `tv_<exposure>` name with a collision-safe fallback; `referencelabel(Unexposed)` is the default; `keepdates` retains master entry and exit; `saveas()` and `frameout()` are optional; `replace` authorizes overwriting. |
| Diagnostics | `check`, `gaps`, `overlaps`, `summarize`, `validate`, `flow`, and `verbose` are report or validation options; `validate` is not combined with `bytype`. |

### tvmerge

Syntax:

~~~stata
tvmerge [dataset1 dataset2 ...], id(varname) start(namelist) ///
    stop(namelist) exposure(namelist) [options]
tvmerge, frames(namelist) id(varname) start(namelist) ///
    stop(namelist) exposure(namelist) [options]
~~~

Use either positional files or `frames()`, not both. The inputs must already be interval data. `start()`, `stop()`, and `exposure()` list one variable per input in the same order.

| Option group | Options and defaults |
|---|---|
| Quantity algebra | `rate()` preserves rates, `total()` apportions totals by inclusive overlap days, `cumulative()` carries row-start histories, and deprecated `continuous()` aliases `total()`. |
| Naming | `generate()` supplies one output exposure name per dataset; `prefix()` supplies a common prefix; `idname(id)`, `startname(start)`, `stopname(stop)`, and `dateformat(%tdCCYY/NN/DD)` are defaults. |
| Data management | `saveas()`, `frameout()`, `replace`, `keep()`, and `dropinvalid` control destinations, retained variables, and malformed rows. |
| Diagnostics | `check`, `validatecoverage`, `validateoverlap`, `summarize`, `flow`, and `verbose` report structure and attrition. |
| IDs and legacy options | By default ID sets must match; `force` keeps the intersection when they do not. `batch()` is deprecated and ignored. |

### tvevent

Syntax:

~~~stata
tvevent [using filename], id(varname) date(name) [options]
tvevent, frame(name) id(varname) date(name) [options]
~~~

The current frame is the event master and the interval data come from `using` or `frame()`. `date()` is an event-date variable for single events or a contiguous wide stub such as `hosp1`, `hosp2` for recurring events.

| Option group | Options and defaults |
|---|---|
| Events | `type(single)` and `generate(_failure)` are defaults; `compete()` supplies competing-event dates; `eventlabel()` customizes labels. |
| Quantities | `rate()`, `total()`, `cumulative()`, and deprecated `continuous()` use the same interval algebra as `tvmerge`. |
| Time | `timegen()` is optional; `timeunit(days)` is the default when it is used. |
| Recurring events | `enum(_enum)` is the default stratum under `type(recurring)`; `gaptime` adds `gapstart(_t0)` and `gapstop(_t)` by default. |
| Data and validation | `start(start)` and `stop(stop)` default to those names; `keepvars()`, `dropinvalid`, `replace`, `validate`, `flow`, and `verbose` are optional. |

Events on an interval start or interior date are included in that interval; an event on the stop date is flagged without creating a later segment. A terminal single event removes later person-time, while recurring output provides the event sequence and optional gap-time clock.

### tvdiagnose

Syntax:

~~~stata
tvdiagnose, id(varname) start(varname) stop(varname) [options]
~~~

Specify at least one report option or `all`. `coverage` requires `entry()` and `exit()`; `summarize` requires `exposure()`; `swimlane` accepts numeric or string exposure values and leaves the data unchanged.

| Option group | Options and defaults |
|---|---|
| Reports | `coverage`, `gaps`, `overlaps`, `summarize`, `all`, and `swimlane`. |
| Inputs | `exposure()` is used by summary and swimlane; `entry()` and `exit()` are used by coverage. |
| Display | `threshold(30)` flags gaps exceeding 30 days; `maxids(50)` limits swimlane persons; `verbose` prints IDs and dates. |

The swimlane graph is named `tvd_swimlane` when created. Coverage and summaries use interval unions, so overlap does not inflate global covered time; overlapping exposure categories can still have multi-membership shares.

### tvweight

Syntax:

~~~stata
tvweight exposure [if] [in], covariates(varlist) [options]
~~~

| Option group | Options and defaults |
|---|---|
| Weights | `generate(iptw)` and `wtype(iptw)` are defaults; alternatives are `wtype(ato)` and `wtype(matching)`; `stabilized` applies to IPTW; `truncate(lo hi)` uses strict percentile bounds between 0 and 100. |
| MSM history | `cumulative` creates a within-person product; `cumgenerate()` names it and requires `id()` and `time()`. |
| IPCW | `ipcw()` is a 0/1 censoring indicator and requires `id()` and `time()`; `censorcovariates()` selects the censoring model; `censgenerate(ipcw)` and `combgenerate(<weight>_ipcw)` are defaults. |
| Model | `model(logit)` is the default for binary exposure; multinomial exposure levels use `mlogit` as needed; `tvcovariates()` requires `id()` and `time()`; `estname()` stores the propensity model and `estreplace` authorizes replacement. |
| Diagnostics | `balance` returns standardized mean differences; `loveplot` delegates plotting to optional `psdash`; `histogram` draws a weight distribution. |
| Output | `denominator()` also stores the observed-treatment propensity; `replace` permits replacing output variables; `nolog` suppresses model iteration output. |

Truncation applies to the final combined weight when `ipcw()` is used. The command's diagnostics report effective sample size, overlap, extreme fitted probabilities, and weight concentration but do not establish causal assumptions.

### tvage

Syntax:

~~~stata
tvage, id(varname) dob(varname) entry(varname) exit(varname) [options]
~~~

`generate(age_tv)`, `startgen(age_start)`, and `stopgen(age_stop)` are the defaults. `groupwidth(1)` creates single-year ages and accepts 1–50; `minage(0)` and `maxage(120)` left- and right-truncate at exact anniversaries. `saveas()` saves the result and restores the input; without it, the output replaces memory. The legacy aliases `idvar()`, `dobvar()`, `entryvar()`, and `exitvar()` remain accepted, one spelling per slot.

`tvage` requires one row per person, a numeric identifier, and nonmissing daily dates. Its output retains only the ID, age, start, and stop variables, so save or merge baseline covariates separately.

### tvband

Syntax:

~~~stata
tvband, id(varname) start(varname) stop(varname) type(age|calendar|elapsed) [options]
~~~

`origin()` is required for age and elapsed axes and forbidden for calendar; `width(1)` is the default; elapsed `unit(day)` is the default; calendar `anchor()` defaults to the earliest year in the data. `min()` and `max()` filter lower band edges. `generate(ageband|calband|fuband)` defaults by axis, while `startgen()` and `stopgen()` default to overwriting the input bounds. `saveas()` restores the caller's data.

### tvsplit

Syntax:

~~~stata
tvsplit, id(varname) start(varname) stop(varname) ///
    [age(dobvar, width(#) min(#) max(#) generate(name)) ///
     calendar(, width(#) anchor(#) generate(name)) ///
     elapsed(refvar, width(#) unit(day|year) min(#) max(#) generate(name)) ///
     noisily]
~~~

At least one axis is required. Age and calendar widths default to one year, elapsed width defaults to one unit, calendar anchor defaults to the earliest year, elapsed unit defaults to days, and the default band variables are `ageband`, `calband`, and `fuband`. `tvsplit` overwrites `start()` and `stop()` in memory and carries all other variables forward.

### tvpanel

Syntax:

~~~stata
tvpanel [using filename], id(varname) entry(varname) exit(varname) ///
    exposure(name) [options]
~~~

The current frame is the one-row-per-person master; episodes come from `using` or `frame()`. `width(91)`, `reference(0)`, `start(start)`, `stop(stop)`, `period(period)`, `startgen(start)`, `stopgen(stop)`, and `generate(tv_class)` are defaults. `cumulative(days|weeks|months|quarters|years)` adds per-class histories with an optional `prefix()`. `keepvars()` carries master variables; `dropinvalid` opts into removal of malformed rows; `saveas()` restores the master; `replace` authorizes file replacement.

The grid is entry anchored, clips the last period at exit, and assigns the active class at each period start. Without `dropinvalid`, malformed master or episode rows stop the command and leave the master unchanged.

## Stored Results

Result names below are returned in `r()` after successful execution; option-dependent names are returned only when their option is used.

### tvtools and tvspec

- `tvtools` returns scalar `r(n_commands)` and local macros `r(commands)`, `r(categories)`, and `r(version)`.
- `tvspec create` returns scalar `r(n_sources)` and macro `r(specframe)`; `tvspec add` returns scalar `r(n_sources)` and macros `r(source_name)` and `r(specframe)`; `tvspec list` returns scalar `r(n_sources)` and macros `r(source_names)` and `r(specframe)`.

### tvbuild

- Scalars: `r(dryrun)`, `r(spec_version)`, `r(n_sources)`, `r(N_persons)`, `r(event_stage)`, `r(dates_kept)`, and, after a committed run, `r(N_periods)`, `r(n_gap_ids)`, and `r(uncovered_days)`.
- Macros: `r(idvar)`, `r(entryvar)`, `r(exitvar)`, `r(startvar)`, `r(stopvar)`, `r(source_names)`, `r(payload_vars)`, `r(exposure_vars)`, `r(rate_vars)`, `r(total_vars)`, `r(cumulative_vars)`, `r(specframe)`, `r(frameout)`, `r(coverage)`, `r(manifestframe)`, `r(eventvar)`, `r(timevar)`, `r(enumvar)`, `r(gapstartvar)`, `r(gapstopvar)`, and `r(datasignature)`.
- Matrices: `r(source_counts)` and `r(stage_counts)`.

### tvexpose

- Scalars: `r(N_persons)`, `r(N_periods)`, `r(total_time)`, `r(exposed_time)`, `r(unexposed_time)`, `r(pct_exposed)`, `r(n_invalid_master)`, `r(n_invalid_master_id)`, `r(n_invalid_master_dates)`, `r(n_invalid_master_order)`, `r(n_invalid_exposure)`, `r(n_invalid_exposure_id)`, `r(n_invalid_exposure_dates)`, `r(n_invalid_exposure_order)`, `r(n_invalid_exposure_value)`, `r(n_unmatched_exposure)`, `r(n_outside_window)`, `r(n_lag_removed)`, `r(n_uncovered_days)`, `r(n_unresolved_overlaps)`, `r(window_min)`, `r(window_max)`, `r(n_combined_states)`, and `r(n_bytype_vars)` when applicable.
- Macros: `r(genvar)`, `r(frameout)`, `r(overlap_ids)`, `r(recency_unit)`, `r(recency_cutdays)`, `r(combine_map)`, and `r(bytype_map)` when applicable.
- Matrix: `r(flow)` when `flow` or `dropinvalid` supplies attrition accounting.

### tvmerge

- Scalars: `r(N)`, `r(N_persons)`, `r(mean_periods)`, `r(max_periods)`, `r(N_datasets)`, `r(n_rate)`, `r(n_total)`, `r(n_cumulative)`, `r(n_continuous)`, `r(n_categorical)`, `r(n_invalid)`, `r(n_invalid_id)`, `r(n_invalid_dates)`, `r(n_invalid_order)`, `r(n_invalid_exposure)`, `r(n_invalid_ds#)`, `r(n_input_overlaps)`, `r(n_input_overlaps_ds#)`, `r(n_gaps)`, `r(n_overlaps)`, and `r(n_duplicates_dropped)`.
- Macros: `r(datasets)`, `r(exposure_vars)`, `r(rate_vars)`, `r(total_vars)`, `r(cumulative_vars)`, `r(continuous_vars)`, `r(categorical_vars)`, `r(idname)`, `r(startname)`, `r(stopname)`, `r(dateformat)`, `r(prefix)`, `r(generated_names)`, `r(output_file)`, and `r(frameout)`.
- Matrix: `r(flow)` when requested.

### tvevent

- Scalars: `r(N)`, `r(N_events)`, `r(n_rate)`, `r(n_total)`, `r(n_cumulative)`, `r(n_continuous)`, `r(n_invalid)`, `r(n_invalid_master)`, `r(n_invalid_master_id)`, `r(n_invalid_master_dates)`, `r(n_invalid_intervals)`, `r(n_invalid_interval_id)`, `r(n_invalid_interval_dates)`, `r(n_invalid_interval_order)`, `r(n_invalid_quantity)`, `r(v_outside_bounds)`, `r(v_multiple_events)`, and `r(v_same_date_compete)`.
- Macros: `r(generate)`, `r(startvar)`, `r(stopvar)`, `r(timegen)`, `r(enum)`, `r(gapstart)`, `r(gapstop)`, `r(rate_vars)`, `r(total_vars)`, `r(cumulative_vars)`, and `r(continuous_vars)`.
- Matrix: `r(flow)` when requested.

### tvdiagnose

- Scalars: `r(n_persons)`, `r(n_observations)`, `r(coverage_run)`, `r(gaps_run)`, `r(overlaps_run)`, `r(summarize_run)`, `r(mean_coverage)`, `r(min_coverage)`, `r(max_coverage)`, `r(n_with_gaps)`, `r(n_incomplete_coverage)`, `r(n_coverage_gaps)`, `r(n_gaps)`, `r(n_gap_ids)`, `r(mean_gap)`, `r(median_gap)`, `r(max_gap)`, `r(n_large_gaps)`, `r(n_large_gap_ids)`, `r(n_overlaps)`, `r(n_overlap_ids)`, `r(n_ids_affected)`, `r(total_person_time)`, `r(raw_interval_person_time)`, `r(overlap_excess_person_time)`, `r(n_crossexposure_overlap_days)`, `r(n_exposure_levels)`, `r(graph_requested)`, `r(graph_created)`, `r(graph_rc)`, `r(graph_ids_total)`, `r(graph_ids_plotted)`, and `r(graph_truncated)`.
- Macros: `r(id)`, `r(start)`, `r(stop)`, and `r(graph_name)` when a graph is created.
- Matrix: `r(exposure_summary)` when `summarize` runs; its columns are exposure, raw_days, person_days, percent, and n_periods.

### tvweight

- Scalars: `r(N)`, `r(n_levels)`, `r(ess)`, `r(ess_pct)`, `r(w_mean)`, `r(w_sd)`, `r(w_min)`, `r(w_max)`, `r(w_p1)`, `r(w_p5)`, `r(w_p25)`, `r(w_p50)`, `r(w_p75)`, `r(w_p95)`, `r(w_p99)`, `r(n_truncated)`, `r(trunc_lo)`, `r(trunc_hi)`, `r(overlap_lo)`, `r(overlap_hi)`, `r(pct_nonoverlap)`, `r(n_nonoverlap)`, `r(top1_wt_share)`, `r(n_top1_rows)`, `r(n_ps_extreme)`, `r(n_ps_boundary)`, `r(n_cens_extreme)`, `r(n_cens_boundary)`, `r(histogram_created)`, `r(loveplot_created)`, `r(graph_created)`, and `r(ess_combined)` when applicable.
- Macros: `r(exposure)`, `r(covariates)`, `r(model)`, `r(wtype)`, `r(generate)`, `r(stabilized)`, `r(denominator)`, `r(estname)`, `r(cumgenerate)`, `r(ipcw)`, `r(censgenerate)`, `r(combgenerate)`, `r(censorcovariates)`, `r(balance_terms)`, `r(balance_weight)`, and `r(numerator_model)`.
- Matrix: `r(balance)` when `balance` runs.

### tvage, tvband, tvsplit, and tvpanel

- `tvage` returns scalars `r(n_persons)`, `r(n_observations)`, and `r(groupwidth)`, plus macros `r(varname)`, `r(startvar)`, and `r(stopvar)`.
- `tvband` returns scalars `r(n_persons)`, `r(n_observations)`, and `r(width)`, plus macros `r(axistype)`, `r(varname)`, `r(startvar)`, and `r(stopvar)`.
- `tvsplit` returns scalars `r(n_axes)`, `r(n_persons)`, and `r(n_observations)`, plus macros `r(agevar)`, `r(calvar)`, `r(fuvar)`, `r(startvar)`, and `r(stopvar)` when applicable.
- `tvpanel` returns scalars `r(n_persons)`, `r(n_observations)`, `r(width)`, `r(n_invalid)`, `r(n_invalid_master)`, `r(n_invalid_master_id)`, `r(n_invalid_master_dates)`, `r(n_invalid_master_order)`, `r(n_invalid_episodes)`, `r(n_invalid_episode_id)`, `r(n_invalid_episode_dates)`, `r(n_invalid_episode_order)`, and `r(n_invalid_episode_exposure)`, plus macros `r(periodvar)`, `r(startvar)`, `r(stopvar)`, `r(classvar)`, and `r(cumvars)`.

## Assumptions and Limits

- Input dates are numeric, whole-number Stata daily dates; the suite does not interpret Stata datetime values as daily dates.
- Identifiers are structural keys, not analytical covariates: source names and storage types must agree, and commands never pad, guess, or silently remap them.
- `tvage`, `tvband`, and `tvsplit` require numeric identifiers; use `egen long newid = group(stringid)` or an equivalent deliberate mapping before calling them.
- `tvage` intentionally returns only the identifier and generated age interval variables; save or merge covariates separately.
- `tvmerge` expects interval inputs, and `force` restricts mismatched-ID inputs to their intersection rather than inventing missing records.
- `tvevent` treats single events as terminal and recurring event stubs as ordered `stub1` through `stubK` members; noncanonical or noncontiguous stubs are rejected.
- `tvdiagnose` counts global coverage by interval union, but category summaries can have multi-membership when exposure levels overlap.
- `tvbuild` coordinates construction and provenance but does not run `stset`, `tvdiagnose`, `tvweight`, an outcome model, an overlap-resolution choice, or a causal model.
- Weighting output is model-based: causal interpretation requires consistency, conditional exchangeability, positivity, and an adequate treatment model; IPCW additionally requires an adequate censoring model and conditional independent censoring.
- Fixed-width expansion and continuous exposure expansion can substantially increase row counts; month, quarter, and year bins in `tvexpose` use fixed average day widths anchored at each episode start, while age and year-unit axes use exact calendar anniversaries.
- `tvweight, loveplot` requires optional `psdash`; without it, use `r(balance)` to build a plot with another graphing workflow.

## Demo

The named demo script [demo/demo_tvtools.do](demo/demo_tvtools.do) creates a synthetic cohort, demonstrates the primitive and `tvbuild` routes, exercises weighting and recurrent-event formatting, and exports the two checked-in PNG assets below. Run it from any working directory by passing the checked-out demo directory as its first argument:

~~~stata
local demo_dir "/path/to/checked-out/tvtools/demo"
do "`demo_dir'/demo_tvtools.do" "`demo_dir'"
~~~

![Covariate balance love plot](demo/balance_loveplot.png)

![Exposure swimlane plot](demo/swimlane_plot.png)

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.13.0** (2026-08-02): Harmonized console-report layout and corrected display-only leaks and formatting defects without changing estimators, interval semantics, computed values, options, or stored results.
- **1.12.1** (2026-08-02): Hardened provenance-manifest replacement checks and improved diagnostics for damaged specification frames.
- **1.12.0** (2026-08-01): Added `tvspec`, made `tvbuild` provenance manifests default, and made catalog rendering derive from one command list.
- **1.11.0** (2026-07-31): Renamed the released front door from `tvpipe` to `tvbuild` and moved its specification and pipeline characteristics to the new command name.
- **1.10.2** (2026-07-31): Hardened front-door specification validation, recurring-event stub discovery, manifest return normalization, and specification-cell arity checks.
- **1.10.1** (2026-07-30): Repaired `eventlabel()` forwarding in the front door and removed duplicate help content.
- **1.10.0** (2026-07-30): Added the transactional front door for typed multi-source plans and introduced `tvmerge, idname()`.
- **1.9.1** (2026-07-30): Made frame-native merging preserve caller frame names and improved cumulative-weight and interval-segmentation internals without changing computed values.
- **1.9.0** (2026-07-25): Corrected panel-mode stabilized weighting, balance-weight selection under IPCW, censoring-indicator validation, and cross-exposure overlap reporting.
- **1.8.0** (2026-07-22): Added collision-safe output planning, explicit overlap composition codes, union-based coverage, date-first event placement, and stricter multiplicity checks.
- **1.7.1** (2026-07-17): Improved interval-overlap performance and deterministic ordering in `tvmerge`.
- **1.7.0** (2026-07-13): Consolidated interval, quantity, diagnostic, age-anniversary, and output-contract behavior across the suite.
- **1.6.9** (2026-07-10): Added failure-safe output rollback, collision-safe labels, clipped coverage diagnostics, and early identifier validation.
- **1.6.8** (2026-07-03): Corrected opt-in diagnostic paths, short-data error reporting, validation-file naming, and legitimate duplicate-interval handling.
- **1.6.7** (2026-07-02): Added early `strL` identifier rejection and clearer numeric-ID diagnostics.
- **1.6.6** (2026-07-02): Corrected exact-width panel endpoints, running-maximum gap logic, output-name collisions, truncation bounds, and estimation-sample IPCW validation.
- **1.6.5** (2026-07-02): Corrected by-type labels and summaries, validation-file collisions, empty-frame output, zero-overlap validation, and non-positional continuous quantities.
- **1.6.4** (2026-07-01): Corrected cumulative products across rows excluded from the estimation sample.
- **1.6.3** (2026-06-30): Consolidated the shared interval engine for panel lookup and event split-point placement.
- **1.6.2** (2026-06-29): Delegated `tvweight, loveplot` to optional `psdash` while preserving the balance table and matrix.
- **1.6.1** (2026-06-29): Added `tvband` and `tvsplit` to the public package documentation and harmonized help presentation.
- **1.6.0** (2026-06-29): Added IPCW and combined weights, positivity diagnostics, and recurrent-event sequence and gap-time formatting.
- **1.5.0** (2026-06-29): Added frame-first output, harmonized aliases, and scriptable output-name returns.
- **1.4.0** (2026-06-29): Added derived output names and collision-safe fallback naming in `tvexpose`.
- **1.3.0** (2026-06-28): Added single-axis and multi-axis age, calendar, and elapsed-time splitting with exact anniversaries.
- **1.2.0** (2026-06-28): Added Mata interval-overlap and continuous-expansion engines; deprecated `batch()` as an ignored compatibility option.
- **1.1.0** (2026-06-28): Added balance diagnostics, alternative weight types, cumulative weights, graphing, frame inputs, flow reporting, and swimlanes.
- **1.0.3** (2026-06-26): Hardened panel bookkeeping, value-label handling, and dose-overlap temporary names.
- **1.0.2** (2026-06-19): Standardized public help-file author sections and stored-result presentation.
- **1.0.1** (2026-06-15): Fixed suppressed parser errors, event reshaping bookkeeping, option aliases, and author metadata.
- **1.0.0** (2026-04-08): Initial Stata-Tools release.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License. See [LICENSE](../LICENSE).
