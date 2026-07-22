# tvtools - Time-varying exposure workflow for survival analysis

**Version 1.8.0** | 2026-07-22

`tvtools` turns person-level follow-up and episode records into analysis-ready time-varying survival data. It supports exposure construction, interval alignment, event integration, diagnostics, weighting, fixed-width panels, and exact calendar-timescale splitting.

## Quick Start

This end-to-end example uses only inline data and temporary files, so it runs after a normal installation from any working directory:

```stata
clear
input long id str9(entry_s exit_s event_s)
1 "01jan2020" "31jan2020" "20jan2020"
2 "01jan2020" "31jan2020" ""
end
generate double study_entry = date(entry_s, "DMY")
generate double study_exit  = date(exit_s, "DMY")
generate double event_date  = date(event_s, "DMY")
format study_entry study_exit event_date %td
drop entry_s exit_s event_s
tempfile events episodes intervals
save `events'

clear
input long id str9(start_s stop_s) byte drug_class
1 "05jan2020" "15jan2020" 1
2 "10jan2020" "25jan2020" 2
end
generate double rx_start = date(start_s, "DMY")
generate double rx_stop  = date(stop_s, "DMY")
format rx_start rx_stop %td
drop start_s stop_s
save `episodes'

use `events', clear
tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_drug)
save `intervals'

use `events', clear
tvevent using `intervals', id(id) date(event_date) ///
    start(rx_start) stop(rx_stop) generate(outcome)
generate double analysis_t0 = rx_start - 1
stset rx_stop, id(id) failure(outcome==1) time0(analysis_t0)
tvdiagnose, id(id) start(rx_start) stop(rx_stop) exposure(tv_drug) summarize
```

The `analysis_t0 = start - 1` conversion preserves the package's inclusive `[start, stop]` day contract when declaring the data to Stata's elapsed-time survival format.

## Requirements

- Core: Stata 16 or later; `tvtools` has no required community-package dependency.
- Optional graphs: [`psdash`](../psdash/) for `tvweight, loveplot`; analytical weights and `r(balance)` do not require it.
- Optional downstream analysis: [`msm`](../msm/) for `msm_prepare` and `msm_weight` after `tvpanel`.
- Demo graph styling: the demo saves and restores `c(scheme)` but never sets one, so its plots use whatever scheme is selected beforehand (for example from [`tc_schemes`](../tc_schemes/)). No command's behavior depends on it.
- Release QA only: R plus the reference libraries used by the three external-oracle suites, and `rangematch` for its explicit integration contract.

## Installation

```stata
capture ado uninstall tvtools
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace
```

Optional integrations can be installed independently:

```stata
net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace
net install msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace
```

The ancillary menu helper is available through `net get tvtools`; run `do tvtools_menu_setup.do` only if you want a Stata menu entry.

## Commands

| Command | Purpose | Help |
|---------|---------|------|
| `tvtools` | List and categorize the suite | `help tvtools` |
| `tvexpose` | Convert episodes to time-varying exposure intervals | `help tvexpose` |
| `tvmerge` | Align two or more interval datasets | `help tvmerge` |
| `tvevent` | Add primary, competing, or recurrent events | `help tvevent` |
| `tvdiagnose` | Report coverage, gaps, overlaps, and exposure time | `help tvdiagnose` |
| `tvweight` | Estimate treatment and censoring weights | `help tvweight` |
| `tvage` | Expand person-level follow-up at exact birthdays | `help tvage` |
| `tvband` | Split intervals along one date-derived axis | `help tvband` |
| `tvsplit` | Split intervals on several Lexis timescales | `help tvsplit` |
| `tvpanel` | Build an entry-anchored fixed-width MSM panel | `help tvpanel` |

## Options

The `tvtools` catalog command accepts the following package-index options; command-specific options are documented in each command's help file.

| Option | Meaning |
|--------|---------|
| `list` | Print command names only |
| `detail` | Print command descriptions |
| `category(all|prep|diag|weight)` | Select a command category; default `all` |

## Stored Results

| Result | Meaning |
|--------|---------|
| `r(commands)` | Space-separated commands in the selected category |
| `r(n_commands)` | Number of selected commands |
| `r(version)` | Installed package version |
| `r(categories)` | Available non-`all` categories |

## How It Works

The core pipeline is `tvexpose` → `tvmerge` → `tvevent` → `tvdiagnose`/`tvweight`. Every interval uses closed, inclusive integer Stata daily dates. `tvmerge` consumes interval outputs rather than raw episodes; `tvevent` takes event records in memory and intervals through `using` or `frame()`.

`tvage`, `tvband`, and `tvsplit` add exact calendar-timescale bands. `tvpanel` instead creates a uniform entry-anchored grid and can report cumulative exposure in days, weeks, months, quarters, or years before each period starts.

## Worked Examples

### In-memory multi-exposure pipeline

Use `frameout()` and `frames()` to avoid intermediate output files. This example creates every input inline and removes its temporary frames when finished:

```stata
clear
input long id str9(entry_s exit_s)
1 "01jan2020" "31jan2020"
2 "01jan2020" "31jan2020"
end
generate double study_entry = date(entry_s, "DMY")
generate double study_exit = date(exit_s, "DMY")
format study_entry study_exit %td
drop entry_s exit_s
tempfile cohort drug_episodes benzo_episodes
save `cohort'

clear
input long id str9(start_s stop_s) byte drug_class
1 "05jan2020" "20jan2020" 1
2 "10jan2020" "25jan2020" 2
end
generate double rx_start = date(start_s, "DMY")
generate double rx_stop = date(stop_s, "DMY")
format rx_start rx_stop %td
drop start_s stop_s
save `drug_episodes'

clear
input long id str9(start_s stop_s) byte benzo_class
1 "12jan2020" "28jan2020" 1
2 "15jan2020" "18jan2020" 1
end
generate double bz_start = date(start_s, "DMY")
generate double bz_stop = date(stop_s, "DMY")
format bz_start bz_stop %td
drop start_s stop_s
save `benzo_episodes'

use `cohort', clear
foreach f in f_drug f_benzo f_merged {
    capture frame drop `f'
}
tvexpose using `drug_episodes', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_class) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_drug) frameout(f_drug)
tvexpose using `benzo_episodes', id(id) start(bz_start) stop(bz_stop) ///
    exposure(benzo_class) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_benzo) frameout(f_benzo)
tvmerge, frames(f_drug f_benzo) id(id) start(rx_start bz_start) ///
    stop(rx_stop bz_stop) exposure(tv_drug tv_benzo) frameout(f_merged)
frame f_merged: describe
foreach f in f_drug f_benzo f_merged {
    capture frame drop `f'
}
```

### Weighting and causal assumptions

`tvweight` supports binary and multinomial treatment models, stabilized and cumulative IPTW, IPCW, balance diagnostics, truncation, and overlap weights. Causal interpretation requires consistency, conditional exchangeability, positivity, and correctly specified treatment models; IPCW additionally requires conditional independent censoring and a correctly specified censoring model. Diagnostics reveal consequences of fitted models but cannot establish those assumptions.

```stata
clear
set seed 240713
set obs 400
generate long id = ceil(_n/4)
bysort id: generate int period = _n - 1
generate double age = 45 + mod(id, 30)
generate byte sex = mod(id, 2)
generate double comorbidity = rnormal()
generate double p_treat = invlogit(-1 + .02*age + .4*sex + .3*comorbidity)
generate byte treated = runiform() < p_treat
generate double rx_start = mdy(1, 1, 2020) + 91*period
generate int calendar_qtr = qofd(rx_start)
format calendar_qtr %tq
by id: generate byte will_censor = runiform() < .25 if _n == 1
by id: replace will_censor = will_censor[1]
by id: generate byte censor_period = floor(4*runiform()) if _n == 1
by id: replace censor_period = censor_period[1]
generate byte censored = will_censor & period == censor_period
drop if will_censor & period > censor_period
tvweight treated, covariates(age sex comorbidity) id(id) time(period) ///
    stabilized cumulative ipcw(censored) censorcovariates(age sex comorbidity) ///
    balance generate(iptw) combgenerate(msm_weight)
```

`qofd()` retains the year in the descriptive calendar-quarter variable. The model uses the unique entry-anchored `period` key because an exact 91-day grid can place two starts in the same calendar quarter.

## Command Reference

- `tvtools`: package catalog; accepts `list`, `detail`, and `category(all|prep|diag|weight)` and returns the selected commands and installed version.
- `tvexpose`: categorical, ever-treated, current/former, duration, continuous, recency, dose, state-time, overlap-resolution, frame, validation, and flow workflows. When continuous exposure is requested, omitted `expandunit()` defaults to `continuousunit()` and may add regular boundary rows.
- `tvmerge`: aligns multiple interval datasets, preserves rates, apportions interval totals by inclusive overlap days, carries row-start cumulative histories, and reports gaps/overlaps and attrition.
- `tvevent`: integrates single, competing, or recurrent events; event labels derive from event variables in the master data, and events on either interval endpoint are included.
- `tvdiagnose`: coverage, gap, overlap, summary, and swimlane diagnostics. Inclusive overlaps begin when a start is on or before the running maximum prior stop.
- `tvweight`: IPTW/ATO/matching weights, panel and time-varying covariates, cumulative MSM weights, IPCW, balance, overlap, ESS, and graphs.
- `tvage`: exact-anniversary age expansion with left/right person-time truncation through `minage()` and `maxage()`.
- `tvband`: one-axis age, calendar, or elapsed-time splitting.
- `tvsplit`: multi-axis age/calendar/elapsed splitting, equivalent to repeated `stsplit` or `Epi::splitLexis` calls.
- `tvpanel`: fixed-width entry-anchored periods with active class and optional cumulative exposure in days, weeks, months, quarters, or years.

## Demo Output

`demo/demo_tvtools.do` builds a synthetic workflow and produces the checked-in balance and swimlane figures. `psdash` is optional for the love plot; the returned balance matrix remains available without it. From any working directory, pass the checked-out demo directory explicitly:

```stata
local demo_dir "/path/to/checked-out/tvtools/demo"
do "`demo_dir'/demo_tvtools.do" "`demo_dir'"
```

![Covariate balance: love plot](demo/balance_loveplot.png)

![Exposure swimlane](demo/swimlane_plot.png)

## QA

The manifest [`qa/_tvtools_qa_manifest.do`](qa/_tvtools_qa_manifest.do) is the complete source of truth for lane membership, expected assertion counts, and skip policy. Run `cd tvtools/qa && stata-mp -b do run_all.do release` for functional, state, known-answer, external-oracle, optional-integration, and installed-user release checks with zero permitted skips.

The core known-answer inventory explicitly includes `validation_dgp_known_answers.do`, `validation_dgp_known_answers2.do`, and `validation_tvexpose_statetime.do`, alongside the command-specific `validation_*`, audit-regression, boundary, flow, pipeline, and supplemental suites. External QA comprises `crossval_tvsplit_lexis.do`, `crossval_tvweight_ipcw.do`, `crossval_tvevent_recurring.do`, the `rangematch` drift guard, and optional-package integration. The release lane adds install, shipped-file, help/README, dialog, menu-idempotence, and rerunnable-demo checks. See [`qa/README.md`](qa/README.md) for the exact commands and fixture policy.

## Version History

- **1.8.0** (2026-07-22): Correctness release addressing a pre-release clarity audit. **Behaviour changes.** `tvexpose` now resolves its complete output name set before mutating any data and rejects collisions up front, so `start(rx_start) generate(rx_start)` errors instead of silently committing a dataset whose start bound was still named `start`; the structural commit renames are checked rather than swallowed. `tvexpose, split` now isolates a shared inclusive boundary in both source episodes -- under the closed `[start, stop]` contract an episode ending on day *d* and one beginning on day *d* share that day -- so `combine()` yields the documented simultaneous class there instead of `r(498)`. `combine()` no longer encodes overlaps arithmetically as `value1*100 + value2`, a map that was not one-to-one (the pair `-1, 2` encoded to `-98`, also a valid single-exposure code); simultaneous states now receive codes allocated strictly above every observed value, with the composition in a value label and in new `r(combine_map)` / `r(n_combined_states)`. The two-way and `<100` limits are gone. `bytype` validates every derived variable and value-label name for legality, length, and uniqueness before creating anything, and returns `r(bytype_map)` / `r(n_bytype_vars)`. Coverage, gaps, `validate`, and `summarize` now share one clipped running-maximum interval-union engine, so coverage is the union of a person's rows and can no longer exceed 100% (a shared-day split fixture reported 105%, a nested one 140%); overlapping category time is reported as multi-membership with an explicit note. `tvevent, type(single)` identifies the first event by date rather than row position, so rows sharing `(id, start, stop)` -- per-stratum rows from `tvexpose, split` -- all carry the event and the result no longer depends on input row order; when the first event date falls in two *different* intervals the placement is ambiguous and the command errors. `tvevent` no longer force-drops same-person/same-day event multiplicity: it is rejected with counts, because the daily axis records at most one event per person-day. `tvage`, `tvband`, `tvsplit`, and `tvdiagnose` now enforce the suite-wide date contract through a shared validator, rejecting fractional days, `%tc`/`%tC` datetimes, and reversed bounds that were previously accepted at `rc=0`. `tvmerge` rejects an `exposure()` name that exists in no source dataset. **Documentation.** The `tvexpose` output-naming contract, the `combine()` allocator, the union basis of the diagnostics, the `tvevent` duplicate-interval and same-day event contracts, and the `tvmerge` exposure contract are all documented; the `tvage` catalog entry, the numeric-ID restriction in `tvage`/`tvband`/`tvsplit`, several enforced option ranges, four mis-rendering SMCL separators, and parent navigation links in eight subcommand help files were corrected. **QA.** The shared overlap oracle used a strict predecessor-only rule that scored equality and nested overlaps as clean, and the person-time helper used open-interval arithmetic that scored a one-day row as zero days; both were corrected and every affected known answer recomputed from the closed-interval definition.
- **1.7.2** (2026-07-19): Release-audit patch. Documentation was reconciled with the code in several `tvexpose` help entries: the `switching` indicator is `ever_switched` (not `has_switched`); `statetime` produces `state_time_years` measured in years and evaluated at each row's end (it does not reset to 0); `expandunit()` lays fixed average-width bins anchored at each episode start, not calendar boundaries; and the exact `merge()` vs `grace()` gap arithmetic (an off-by-one between them) is now spelled out. `tvexpose` value labels (`ever-treated`, `current/former`, `duration`, `dose`, `recency`) are now allocated through the package's collision-safe label helper, so a caller's same-named value label is never clobbered. Missing-ID rows are now rejected with an error by `tvband` and `tvage`, matching `tvsplit` and the core commands. `tvexpose, duration()` no longer silently drops legitimate pre-1960 (negative-date) exposure segments. Internal hygiene: removed 415 lines of unreachable diagnostic code, namespaced the temporary label-restore scripts to avoid cross-session collisions in a shared TMPDIR, added an obs tiebreak to the `tvmerge` point engine for engine-to-engine symmetry, and widened the `tvevent` stub-collision scan beyond a fixed 20-variable window. `tvage`'s discard of non-interval variables, the structural output-variable overwrites in `tvexpose`/`tvpanel`, and the marginal (form-only) stabilization of the `tvweight` IPCW numerator are now documented. No syntax, option, or stored-result contract changed.
- **1.7.1** (2026-07-17): Performance and determinism fix in the `tvmerge` interval-overlap engine. The backend binary-searched only the lower interval bound and then linearly rescanned the whole candidate prefix to filter the upper bound, which is quadratic in the number of rows rather than the advertised log-linear; it is now a forward-scan plane sweep that is output-sensitive in the number of pairs actually reported. On a 16,000-row fixture this reduces the join from roughly 23 seconds to under a fifth of a second. The engine's using-side sort now carries an explicit unique tiebreak, so the order of merged rows is reproducible across runs on data with tied interval start values; the set of merged rows is unchanged in every case. No syntax, option, or stored-result contract changed.
- **1.7.0** (2026-07-13): Comprehensive correctness and contract release. `tvexpose` now has explicit day/year recency units, materializes every recency threshold crossing, keeps the final category open-ended, applies point-time carry-forward once, and enforces consistent rate/total/cumulative semantics. `tvmerge` and `tvevent` preserve legitimate duplicate-interval payload rows, propagate interval quantities without silent remapping, enforce exact file/frame variable contracts, and return scriptable gap, overlap, attrition, boundary, and output metadata. `tvpanel`, `tvweight`, and `tvdiagnose` tighten inclusive person-time, sample/factor-level mapping, rollback, ordering, and overlap-aware diagnostics. `tvage`, `tvband`, and `tvsplit` now use exact calendar anniversaries, including 29-Feb transitions, rather than 365.25-day approximations. All help and installed-user examples were reconciled with the code; the three dialogs were rebuilt around the true data roles and are checked through graphical Stata with exact generated-command goldens. The demo is rerunnable and session-safe, menu setup is idempotent, and the manifest-driven release lane now performs an isolated install, external-oracle checks, graphical dialog compilation, documentation reality checks, and zero-skip full QA.
- **1.6.9** (2026-07-10): Deep-audit correctness and failure-safety release. `tvdiagnose, coverage` now measures the union of intervals clipped to each person's study window, so overlapping records no longer double-count covered time or hide real gaps. `tvage`, `tvband`, `tvevent`, and `tvpanel` allocate collision-safe value-label names instead of overwriting unrelated labels already used by caller or payload variables. `tvweight` rejects duplicate/protected output names, preserves input row order, and rolls back every generated or replaced output after any failure; panel diagnostics also count only in-sample IDs correctly. `tvexpose`, `tvmerge`, and `tvevent` restore the caller's pre-command dataset after late errors. Calendar `tvband` widths must now be whole years, and axis-specific options that would otherwise be ignored are rejected. Regression QA covers the reproduced failures and installed helper autoload.
- **1.6.8** (2026-07-03): Correctness release from a full-suite deep audit. **tvexpose**: (1) the internal gap-period tempfile was named `gaps`, filling the `gaps` display-option local, so the "Gaps in Coverage" diagnostic ran on every invocation whether or not `gaps` was specified (unwanted output plus a needless save/reload round-trip); the tempfile is renamed and the report is now opt-in as documented. (2) The reversed-dates error path (`exit < entry`) listed offending rows with `in 1/5`, which itself errors with r(198) when the master has fewer than 5 observations, masking the intended r(498) diagnostic; the range is now capped at `_N`. (3) The output summary created working variables literally named `time` and `tag`, so `keepvars(time)` or `keepvars(tag)` crashed with "already defined" (r 110); both are now tempvars. (4) `validate` combined with `bytype` silently created no validation dataset; a note is now displayed and the exclusion is documented. **tvevent**: (5) after splitting intervals at event dates, a `duplicates drop id start stop, force` collapsed legitimate rows that share an interval but differ on payload — e.g. per-stratum rows from `tvexpose, split` lost entire exposure strata silently; the dedup is now full-row only. (6) Re-running tvevent over its own saved output crashed with "label ... already defined" (r 110) whenever no interval needed splitting (and always via the empty-events path), because the event value label loaded from the using file was redefined without clearing it; both label sites now drop the stale definition first. **tvmerge**: (7) in the ID-mismatch report, the sample of IDs present only in dataset *k* was listed with `in 1/N` from the top of the sorted comparison data, where rows for IDs missing from dataset *k* sort first — with mismatches in both directions the second listing showed wrong or no IDs; the list range is now offset correctly (display-only). Regression coverage added in `qa/test_regressions.do`.
- **1.6.7** (2026-07-02): Upfront `strL` person-identifier screens, propagated from the same defect class found in `rangematch` v1.3.1. **tvmerge**, **tvexpose**, and **tvevent** merge internally on `id()`; a `strL` id failed mid-run with merge's cryptic "key variable id is strL" (r 106) instead of a clear message. All three now reject `strL` ids upfront on every input (master/using/each dataset) with r(109) and a recast hint. **tvpanel** already required a numeric id but reported a string id as "not found or not numeric (date format)", misattributing the problem to date formatting; the id check is now separate, states the numeric requirement, and suggests `egen group()`. Help files document the id-type requirements. No behavior change for valid inputs.
- **1.6.6** (2026-07-02): Bug-fix release for the companion commands, from a line-by-line audit of everything outside the three core commands. **tvpanel**: (1) when a person's `exit - entry` was an exact multiple of `width()`, the exit day itself fell in no interval (e.g. entry+364 with `width(91)` produced periods covering only entry..entry+363), silently dropping one day of follow-up for exactly those persons while everyone else got full inclusive `[entry, exit]` coverage; the grid now emits interval *k* whenever `entry + width*k <= exit`, so the last interval always ends on the exit day. **tvdiagnose**: (2) the coverage report's per-person gap count compared each interval only to the physically previous interval's stop, so nested or overlapping intervals produced phantom gaps that the gap-analysis report (which already used a running max of stop) correctly said did not exist — the two reports could contradict each other on the same data; the coverage gap count now uses the same running-max logic. (3) Coverage and gap reports crashed with "already defined" (r 110) when the data contained variables named like the display columns (`pct_covered`, `n_periods`, `n_gaps`, `gap_start`, `gap_end`, `gap_days` — plausible leftovers from a prior diagnostic export); the preserved working copy now drops clashing names before renaming, leaving the user's data untouched. **tvweight**: (4) `truncate()` accepted percentile bounds of 0 and 100 and then failed mid-run inside `_pctile` (after the propensity model had already been fit) with a cryptic "percentiles must be between 0 and 100"; bounds are now validated upfront (strictly between 0 and 100) with a clear message. (5) The `ipcw()` 0/1 coding check ran on the entire dataset before `marksample`, so censoring codes present only outside an `if`/`in` restriction (or on rows excluded for missing covariates) falsely rejected valid calls; the check now applies to the estimation sample. Regression coverage for all five fixes added to `qa/test_tvpanel.do`, `qa/test_tvdiagnose.do`, and `qa/test_tvweight.do`.
- **1.6.5** (2026-07-02): Bug-fix release across the three core commands, from a line-by-line audit. **tvexpose**: (1) with `bytype` and an exposure variable that has no value label, the per-type variable and value labels reused the previous type's text (e.g. `ever2` labeled "Ever exposed: 1" / "Never 1"); the label lookup now resets per type. (2) `summarize` with `bytype` and no `generate()` expanded to `tab1 *` and tabulated every variable (id, start/stop dates); it now tabulates exactly the per-type variables (and exactly the output variable without `bytype`). (3) `validate` with a `saveas()` filename lacking the `.dta` extension wrote the validation dataset to the same name as the main output, which then silently overwrote it; a `_validation` suffix is now always applied. (4) `frameout()` from a caller frame with no variables crashed with "no variables defined" while snapshotting; the snapshot is now skipped and the empty frame restored with `clear`. **tvmerge**: (5) `validatecoverage` crashed with a garbled ">0 invalid name" error when the merged result had zero overlapping intervals (`n_gaps` was never defined on the empty path); (6) same `frameout()` empty-caller crash as tvexpose; (7) in the documented advanced case with more `exposure()` variables than datasets, `continuous()` exposures that were not the positional exposure of their dataset were never proportioned to interval overlap (and never re-proportioned in later merges), silently producing unscaled values — all continuous exposures found in a dataset are now proportioned and tracked; a warning is also issued if extra exposure variables are found in dataset 1, where non-positional exposures are ignored. **tvevent**: (8) `validate` with an empty event dataset crashed (r(111)) before reaching the supported all-censored output path; validation checks are now skipped with a note and zeroed `r(v_*)` results; (9) the final summary leaked raw `levelsof` output ("0 1") and `validate` leaked reshape/merge/save tables; both are now quiet. Regression coverage for all nine fixes added to `qa/test_regressions.do`.
- **1.6.4** (2026-07-01): Bug fix in `tvweight`. The within-person running-product computations for `cumulative`/`cumgenerate`, the internal cumulative IPTW, and `censgenerate`/`combgenerate` (IPCW) indexed the physically previous row rather than the previous row that survived `touse`. A person with any single row excluded by `markout` (e.g. one missing covariate among several periods) had their cumulative/combined MSM weight silently reset at that point instead of continuing the product across the gap, understating the weight for every period after the gap with no warning. All three computations now chain the product across `touse==1` rows only. Regression coverage added for the gap scenario; all existing QA (86 checks across `test_tvweight.do`, `validation_tvweight*.do`, `crossval_tvweight_ipcw.do`) passes unchanged.
- **1.6.3** (2026-06-30): Internal engine consolidation, no user-facing behavior change. `tvpanel`'s active-episode lookup and `tvevent`'s split-point identification now use the shared Mata interval engine (`_tvmerge_mata.ado`) instead of a within-person `joinby` Cartesian-then-filter: `tvpanel` via the existing overlap sweep (each period start is a degenerate `[pstart, pstart]` interval) and `tvevent` via a new half-open `[start, stop)` point-in-interval routine (`_tvm_build_pairs_point`). Output is byte-identical to the prior `joinby` path on all regression, validation, and recurrent-event cross-validation fixtures. Adds a cross-package drift guard pinning the overlap engine to rangematch's `_rm_build_pairs_overlap` and a known-truth unit test for the point engine.
- **1.6.2** (2026-06-29): `tvweight`'s `loveplot` now delegates covariate-balance plotting to the dedicated propensity-score dashboard package [`psdash`](https://github.com/tpcopeland/Stata-Tools/tree/main/psdash) instead of drawing its own figure: it calls `psdash balance` with the exposure, the generated weight variable, and the balance covariates. When `psdash` is not installed, `tvweight` prints installation guidance (and a pointer to build the plot from the returned `r(balance)` matrix) rather than producing a redundant in-house plot. The balance table and `r(balance)` matrix are unchanged. No other command behavior changed.
- **1.6.1** (2026-06-29): Documentation maintenance. Added the `tvband` (single date-derived axis) and `tvsplit` (multi-timescale Lexis) commands to the README Commands table and intro, where they were previously omitted, and to the `tvtools` package-index `Also see` footer. Hard-wrapped long prose source lines in the `tvevent`, `tvexpose`, and `tvmerge` help files to ~80 columns so the GUI Viewer no longer drops characters at wrap boundaries. No command behavior changed.
- **1.6.0** (2026-06-29): Method-depth release. **IPCW censoring weights** complete the marginal structural model in `tvweight`: the new `ipcw()` option fits a pooled-logistic censoring model and produces a cumulative inverse-probability-of-censoring weight plus a combined weight equal to the (stabilized) cumulative IPTW times the cumulative IPCW (`censgenerate()`/`combgenerate()`, defaulting to `ipcw` and `{weight}_ipcw`; `censorcovariates()` selects the censoring-model covariates; requires `id()`/`time()`). With `truncate()`, truncation now targets the final combined weight. **Positivity / overlap diagnostic** (always on) reports the range of the propensity of the observed treatment, the share of near-violations (P < 0.05), per-arm PS ranges (binary), and the weight mass held by the top 1% of rows — returned in `r(overlap_lo)`, `r(overlap_hi)`, `r(pct_nonoverlap)`, `r(n_nonoverlap)`, `r(top1_wt_share)`, and `r(ess_combined)`. **Recurrent-event formatting** in `tvevent` adds, under `type(recurring)`, an event-sequence stratum (`enum()`) and an optional gap-time clock (`gaptime`, `gapstart()`/`gapstop()`) so the output feeds Andersen-Gill, PWP conditional (total-time), and PWP gap-time models directly. New parity QA: `crossval_tvweight_ipcw.do` (known-truth recovery of a censored population mean, plus row-for-row agreement with an independent R `glm` IPCW oracle) and `crossval_tvevent_recurring.do` (the stratum and gap-time clock validated against a first-principles event-date oracle and an independent R recomputation).
- **1.5.0** (2026-06-29): Ergonomics release (backward compatible). **Frames-first output:** `tvexpose` and `tvmerge` gain a `frameout(name)` option that places the result into a named frame and leaves the data in the current frame untouched, so a `tvexpose` → `tvmerge` → `tvevent` pipeline can run entirely in memory without the save/use round-trips it previously required (the output frame is returned in `r(frameout)`; `tvevent` already lands its result in memory and reads inputs via `frame()`). **Option-name harmonization:** `tvage` now accepts the suite-standard `id()`/`dob()`/`entry()`/`exit()` names, and `tvevent` accepts `start()`/`stop()`; the original `idvar()`/`dobvar()`/`entryvar()`/`exitvar()` and `startvar()`/`stopvar()` spellings remain accepted as synonyms (specifying both spellings for one slot errors). **Scriptable chaining:** `tvevent` now returns the chosen output-variable names in `r(generate)`, `r(startvar)`, `r(stopvar)`, and `r(timegen)` (matching `tvexpose`'s `r(genvar)` and `tvmerge`'s `r(startname)`/`r(stopname)`/`r(generated_names)`). New QA covers the frames-first pipeline (non-destructive, byte-identical to the `saveas` path) and the alias/return-macro surface.
- **1.4.0** (2026-06-29): Usability release. When `generate()` is omitted, `tvexpose` derives the output name from `exposure()` (for example, `drug_class` yields `tv_drug_class`) instead of using one fixed name for every exposure. Distinct outputs therefore chain into `tvmerge` and `tvevent` without a manual rename. Illegal, over-length, or protected derived names use a collision-safe generic fallback; `r(genvar)` always reports the chosen name. QA covers derived, explicit, fallback, and rename-free merge paths.
- **1.3.0** (2026-06-28): Feature release. New `tvband` splits follow-up intervals along a single date-derived axis — age (relative to date of birth), calendar period, or elapsed time since a reference date — generalizing `tvage` to any continuous time axis while preserving covariates on each split row. New `tvsplit` performs multi-timescale (Lexis) splitting on age, calendar period, and time-since-entry simultaneously, so every output sub-interval lies in exactly one band on every requested axis — equivalent to repeated Stata `stsplit` / R `Epi` multi-timescale splitting, ready for age- and period-adjusted Cox or Poisson models. Both share a single splitting engine (`_tvband_split`) and use the suite's inclusive abutting-interval convention, so output merges with `tvexpose`/`tvmerge` and feeds `stset`. New parity QA: `crossval_tvsplit_lexis.do` validates the Lexis grid against an independent cut-enumeration oracle, Stata `stsplit` (age axis), and day-exact R `Epi::splitLexis` (calendar + elapsed axes). Also fixes a `tvage` bug where `minage()`/`maxage()` mislabeled person-time: the first/last interval started/ended at the raw study entry/exit while carrying the clamped age band, so follow-up before `minage` (or after `maxage`) was counted under the boundary band. `tvage` now left/right-truncates that person-time at the age-band boundary. Output is unchanged when `minage`/`maxage` do not bind.
- **1.2.0** (2026-06-28): Performance release (behavior-preserving). `tvmerge` replaces its `joinby`/`batch()` Cartesian-then-filter core with a compiled Mata interval-overlap sweep that emits only the overlapping interval pairs per person, never materializing the within-person Cartesian product — substantially faster and lighter on memory at registry scale, with identical output. The `batch(#)` option is now deprecated and ignored (accepted as a no-op so existing scripts keep working). `tvexpose` consolidates its weeks/months/quarters/years `expandunit()` row generation into a single Mata routine (bit-identical bin boundaries). Both commands show a one-line matching/overlap progress indicator on very large runs (>100k rows), suppressed under `quietly`. New parity QA: `crossval_tvmerge_mata.do` (vs an independent day-by-day expansion oracle) and `crossval_tvexpose_expand.do` (vs the documented bin formula).
- **1.1.0** (2026-06-28): Feature release. `tvweight` gains covariate-balance diagnostics (`balance`), overlap and matching weights (`wtype()`), stored propensity models, cumulative MSM weights, and graphs. `tvmerge`, `tvevent`, and `tvpanel` gain frame inputs, while `tvmerge` auto-suffixes duplicate exposure names. `tvexpose`, `tvmerge`, and `tvevent` add flow reporting, and `tvdiagnose` adds a swimlane plot.
- **1.0.3** (2026-06-26): Bug fixes and QA hardening. `tvpanel` now uses collision-safe temporary variables for internal row/class/cumulative bookkeeping and avoids stale value-label mappings when episode labels share names with labels already in memory. `tvexpose` dose-overlap handling now avoids internal `__seg_*` names that can collide with user `keepvars()`. Expanded `tvpanel` and dose-overlap regression QA and wired `test_tvpanel.do` into the canonical runner.
- **1.0.2** (2026-06-19): Documentation maintenance. Standardized public help-file Author sections and shortened the `tvexpose` `r(overlap_ids)` stored-results synopt.
- **1.0.1** (2026-06-15): Bug fixes. `tvmerge` now shows variable-not-found and option-parsing errors that were previously suppressed inside a `quietly` block (silent `exit` with no message). `tvevent` uses a tempvar for its reshape row-id instead of a hardcoded `_obs`. Internal `tvevent` helper option abbreviations aligned with the documented forms. Canonical author/affiliation standardized across all files.
- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License. See [LICENSE](../LICENSE).
