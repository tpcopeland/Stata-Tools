# tvtools - Time-varying exposure workflow for survival analysis

**Version 1.3.0** | 2026-06-28

`tvtools` is a workflow package for building analysis-ready time-varying survival data in Stata. It starts from person-level follow-up plus episode-format exposure records and helps you derive exposure intervals, align multiple time-varying sources, add outcomes and competing risks, diagnose gaps and overlaps, estimate IPTW weights, and create age-band intervals.

## Requirements

- Stata 16 or later
- Internet access if you want to run the public `_data/` examples directly from GitHub

## Installation

```stata
capture ado uninstall tvtools
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace
```

If you want the optional menu-setup helper that ships with the package, download the ancillary files separately:

```stata
net get tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
do tvtools_menu_setup.do
```

## Commands

| Command | Purpose | Help |
|---------|---------|------|
| `tvtools` | Package index: lists all commands and their categories | `help tvtools` |
| `tvexpose` | Create time-varying exposure intervals from episode data | `help tvexpose` |
| `tvmerge` | Merge multiple time-varying datasets into aligned person-time intervals | `help tvmerge` |
| `tvevent` | Add outcomes and competing risks to an interval dataset | `help tvevent` |
| `tvdiagnose` | Check coverage, gaps, overlaps, and exposure summaries | `help tvdiagnose` |
| `tvweight` | Estimate inverse probability of treatment weights for interval data | `help tvweight` |
| `tvage` | Create time-varying age intervals from dates of birth and follow-up dates | `help tvage` |
| `tvpanel` | Build a fixed-width, entry-anchored person-period panel for marginal structural models | `help tvpanel` |

## How It Works

The package follows a pipeline where each command produces output in a consistent id/start/stop format:

```
cohort.dta + episodes.dta
        |
     tvexpose  -->  person-period intervals (one exposure)
        |
     tvmerge   -->  aligned intervals (multiple exposures)
        |
     tvevent   -->  intervals with outcome/competing-risk flags
        |
     tvdiagnose -->  quality report (coverage, gaps, overlaps)
        |
     tvweight  -->  IPTW weights for causal inference
```

**Key conventions:**

- The **cohort or event data stay in memory**; exposure episodes are supplied through `using` files.
- All date variables must be **Stata daily dates** (integer days, `%td` format). Datetime variables (`%tc`/`%tC`) are rejected with a clear error.
- Intervals use a **closed [start, stop] convention** where both endpoints are inclusive.
- `tvmerge` operates on **tvexpose output**, not raw episode files.
- For `tvevent`, the **event data** is the master (in memory) and the **interval data** is the using file.

## Demo Output

Output below is generated from `tvtools/demo/demo_tvtools.do` (200-patient synthetic cohort, SSRI/SNRI antidepressant study design). Rendered with [logdoc](../logdoc/).

### Binary treatment pipeline

### Step 6: tvage — create age-band intervals

```stata
tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) ///
    groupwidth(5) minage(40) maxage(80) ///
    saveas(age_tv.dta) replace
```

The output has the same id/start/stop structure as `tvexpose`, so you can merge age bands with exposure intervals using `tvmerge`:

```stata
tvmerge tv_antidep.dta age_tv.dta, id(id) ///
    start(rx_start age_start) stop(rx_stop age_stop) ///
    exposure(tv_exposure age_tv)
```

### Multi-group treatment weighting

When the exposure has 3+ categories, `tvweight` automatically switches to multinomial logit (`mlogit`). This example uses the full drug variable (0=Unexposed, 1=SSRI, 2=SNRI) with stabilized weights and percentile truncation.

## Worked Examples

### Fitting a competing-risks model after the pipeline

After running Steps 1 and 4, the interval dataset is ready for `stset` and analysis:

```stata
stset rx_stop, id(id) failure(outcome==1) enter(rx_start)
stcrreg i.tv_exposure, compete(outcome==2)
```

The outcome variable uses `0` for censoring, `1` for the primary event, and `2` for the competing event.

## Command Reference

### tvexpose

Transforms episode-format exposure records into person-period intervals. Supports:

- **Default**: categorical time-varying exposure
- **evertreated**: binary ever/never (corrects immortal time bias)
- **currentformer**: three-level never/current/former
- **duration()**: cumulative duration categories
- **continuousunit()**: continuous cumulative exposure (days, weeks, months, quarters, years)
- **recency()**: time since last exposure
- **dose**: cumulative dose tracking with proportional overlap allocation
- **grace()**, **lag()**, **washout()**: exposure timing adjustments
- **priority()**, **layer**, **split**, **combine()**: overlap resolution

### tvmerge

Merges two or more `tvexpose` outputs into a single dataset with synchronized time periods. Uses Cartesian interval intersection. Continuous exposures are pro-rated when intervals are split. The `force` option handles non-matching IDs across datasets.

### tvevent

Integrates outcomes and competing risks into interval data. Splits intervals at event dates, adjusts continuous variables proportionally, and flags events (0=censored, 1=primary, 2+=competing). Supports `type(single)` (terminal first event) and `type(recurring)` (wide-format repeated events).

### tvdiagnose

Quality-control tool for interval datasets. Four reports: `coverage` (fraction of follow-up covered), `gaps` (unexposed intervals), `overlaps` (concurrent records), and `summarize` (exposure frequency and person-time). Use `all` to run everything. The `verbose` option shows individual records.

### tvweight

Estimates inverse probability of treatment weights (IPTW) for causal inference. Supports binary (`logit`) and multinomial (`mlogit`) propensity score models, stabilized weights, percentile truncation, and panel-aware weighting with cluster-robust SEs. Reports weight distribution, percentiles, and effective sample size (ESS).

### tvage

Creates time-varying age intervals from dates of birth and follow-up dates. Expands one-record-per-person data into one row per age (or age group). Output is compatible with `tvmerge` for merging age bands with other time-varying covariates.

## QA

Canonical QA lives in `qa/`; the full runner is:

```bash
cd tvtools/qa && stata-mp -b do run_all.do full
```

Functional suites: `test_tvage.do`, `test_tvevent.do`, `test_tvexpose.do`,
`test_tvmerge.do`, `test_tvpanel.do`, `test_tvweight.do`,
`test_tvdiagnose.do`, `test_tvtools.do`, `test_options.do`,
`test_integration.do`, `test_edge_cases.do`, `test_verbose.do`, and
`test_regressions.do`.

Validation and cross-validation suites: `validation_known_answers.do`,
`validation_tvage.do`, `validation_tvevent.do`, `validation_tvexpose.do`,
`validation_tvmerge.do`, `validation_tvweight.do`,
`validation_tvdiagnose.do`, `validation_boundary.do`,
`validation_pipeline.do`, `validation_supplemental.do`, and
`crossval_tvtools.do`.

## Version History

- **1.3.0** (2026-06-28): Feature release. New `tvband` splits follow-up intervals along a single date-derived axis — age (relative to date of birth), calendar period, or elapsed time since a reference date — generalizing `tvage` to any continuous time axis while preserving covariates on each split row. New `tvsplit` performs multi-timescale (Lexis) splitting on age, calendar period, and time-since-entry simultaneously, so every output sub-interval lies in exactly one band on every requested axis — equivalent to repeated Stata `stsplit` / R `Epi` multi-timescale splitting, ready for age- and period-adjusted Cox or Poisson models. Both share a single splitting engine (`_tvband_split`) and use the suite's inclusive abutting-interval convention, so output merges with `tvexpose`/`tvmerge` and feeds `stset`. New parity QA: `crossval_tvsplit_lexis.do` validates the Lexis grid against an independent cut-enumeration oracle, Stata `stsplit` (age axis), and day-exact R `Epi::splitLexis` (calendar + elapsed axes). Also fixes a `tvage` bug where `minage()`/`maxage()` mislabeled person-time: the first/last interval started/ended at the raw study entry/exit while carrying the clamped age band, so follow-up before `minage` (or after `maxage`) was counted under the boundary band. `tvage` now left/right-truncates that person-time at the age-band boundary. Output is unchanged when `minage`/`maxage` do not bind.
- **1.2.0** (2026-06-28): Performance release (behavior-preserving). `tvmerge` replaces its `joinby`/`batch()` Cartesian-then-filter core with a compiled Mata interval-overlap sweep that emits only the overlapping interval pairs per person, never materializing the within-person Cartesian product — substantially faster and lighter on memory at registry scale, with identical output. The `batch(#)` option is now deprecated and ignored (accepted as a no-op so existing scripts keep working). `tvexpose` consolidates its weeks/months/quarters/years `expandunit()` row generation into a single Mata routine (bit-identical bin boundaries). Both commands show a one-line matching/overlap progress indicator on very large runs (>100k rows), suppressed under `quietly`. New parity QA: `crossval_tvmerge_mata.do` (vs an independent day-by-day expansion oracle) and `crossval_tvexpose_expand.do` (vs the documented bin formula).
- **1.1.0** (2026-06-28): Feature release. `tvweight` gains covariate-balance diagnostics (`balance`, standardized mean differences before/after weighting in `r(balance)`), overlap (ATO) and matching weights (`wtype()`), an optional stored propensity model (`estname()`), within-person cumulative MSM weights (`cumulative`/`cumgenerate()`), and built-in love-plot and weight-distribution graphs (`loveplot`, `histogram`). It also fixes a bug where panel-aware weighting (`id()`+`time()`) without `nolog` failed with `invalid 'vce'`. `tvmerge`, `tvevent`, and `tvpanel` now accept inputs from named frames (`frames()`/`frame()`) instead of disk files, and `tvmerge` auto-suffixes duplicate `tv_exposure` output names instead of erroring. `tvexpose`, `tvmerge`, and `tvevent` gain an opt-in attrition/flow report (`flow`, returned in `r(flow)`). `tvdiagnose` gains an exposure `swimlane` plot. The `tvtools` package index now lists `tvpanel`.
- **1.0.3** (2026-06-26): Bug fixes and QA hardening. `tvpanel` now uses collision-safe temporary variables for internal row/class/cumulative bookkeeping and avoids stale value-label mappings when episode labels share names with labels already in memory. `tvexpose` dose-overlap handling now avoids internal `__seg_*` names that can collide with user `keepvars()`. Expanded `tvpanel` and dose-overlap regression QA and wired `test_tvpanel.do` into the canonical runner.
- **1.0.2** (2026-06-19): Documentation maintenance. Standardized public help-file Author sections and shortened the `tvexpose` `r(overlap_ids)` stored-results synopt.
- **1.0.1** (2026-06-15): Bug fixes. `tvmerge` now shows variable-not-found and option-parsing errors that were previously suppressed inside a `quietly` block (silent `exit` with no message). `tvevent` uses a tempvar for its reshape row-id instead of a hardcoded `_obs`. Internal `tvevent` helper option abbreviations aligned with the documented forms. Canonical author/affiliation standardized across all files.
- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet
