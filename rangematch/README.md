# rangematch

Version 1.3.1, 02jul2026

`rangematch` performs a range join between the dataset in memory and a using dataset or frame. It emits the joined rows themselves, using Stata frames and a Mata binary-search backend. Two match modes are supported: **point-in-interval** (a using `keyvar` point falls in the master `[low, high]` interval) and **interval-overlap** (`overlap()`, where the master `[low, high]` interval overlaps the using `[ulow, uhigh]` interval).

## Installation

```stata
capture ado uninstall rangematch
net install rangematch, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/rangematch") replace
```

## Requirements

- Stata 16.1+
- No external dependencies

## Quick Start

This example is copy-paste runnable after installation and does not rely on repo-local files.

```stata
clear
input str1 site int id double event_date
"A" 1 21915
"B" 2 21946
end
format event_date %td
tempfile master events
save `master'

clear
input str1 site int eid double event_date
"A" 101 21890
"A" 102 21920
"B" 103 21950
"B" 104 21990
end
format event_date %td
save `events'

use `master', clear
rangematch event_date -30 30 using `events', frame(matches) replace stats
frame matches: list
```

## Worked Example: Exposure Windows and Events

This example matches adverse events to patient-specific drug exposure windows. It is self-contained and uses only temporary files.

```stata
clear
input int patient_id str10 start_string byte exposure_days
101 "2020-01-15" 30
101 "2020-03-01" 14
102 "2020-02-10" 21
end
generate double exposure_start = daily(start_string, "YMD")
generate double exposure_end = exposure_start + exposure_days
format exposure_start exposure_end %td
drop start_string exposure_days
tempfile exposures adverse_events
save `exposures'

clear
input int patient_id str10 event_string str18 event_type
101 "2020-01-20" "rash"
101 "2020-02-20" "headache"
101 "2020-03-10" "nausea"
102 "2020-02-15" "dizziness"
102 "2020-03-20" "fatigue"
end
generate double event_date = daily(event_string, "YMD")
format event_date %td
drop event_string
save `adverse_events'

use `exposures', clear
rangematch event_date exposure_start exposure_end using `adverse_events', ///
    by(patient_id) keepusing(event_date event_type) ///
    generate(_merge) frame(exposure_events) replace stats
frame exposure_events: list patient_id exposure_start exposure_end ///
    event_date event_type _merge, sepby(patient_id)
```

## Worked Example: Interval Overlap

This example matches cohort follow-up windows to overlapping treatment episodes within patient, using `overlap()`. It is self-contained and uses only temporary files.

```stata
clear
input int id str10 entry_s str10 exit_s
1 "2020-01-01" "2020-06-30"
2 "2020-02-01" "2020-08-31"
end
generate double entry = daily(entry_s, "YMD")
generate double exit  = daily(exit_s, "YMD")
format entry exit %td
drop entry_s exit_s
tempfile cohort episodes
save `cohort'

clear
input int id str10 start_s str10 stop_s str10 drug
1 "2019-12-15" "2020-01-20" "drugA"
1 "2020-03-01" "2020-03-31" "drugB"
2 "2020-09-15" "2020-10-15" "drugA"
end
generate double rx_start = daily(start_s, "YMD")
generate double rx_stop  = daily(stop_s, "YMD")
format rx_start rx_stop %td
drop start_s stop_s
save `episodes'

use `cohort', clear
rangematch entry exit using `episodes', overlap(rx_start rx_stop) ///
    by(id) keepusing(rx_start rx_stop drug) frame(exposed) replace stats
frame exposed: list id entry exit rx_start rx_stop drug, sepby(id)
```

## Demo

The demo script (`rangematch/demo/demo_rangematch.do`) installs the local package, runs an exposure-window workflow, and regenerates the benchmark output used below.

```bash
stata-mp -b do rangematch/demo/demo_rangematch.do
```

## Syntax

Point-in-interval mode:

```stata
rangematch keyvar low high using filename_or_framename [if] [in]
    [, by(varlist) keepusing(varlist) prefix(string) suffix(string)
       all unmatched(master|none|using|both) generate(name) distance(name)
       masterid(name) usingid(name) maxpairs(#)
       frame(name) replace saving(filename[, replace]) stats
       closed(both|left|right|none) nearest(before|after|both)
       tolerance(#) missing(wildcard|drop|error)
       ties(all|first|last) assert(match|using)
       sort nosort dryrun count verbose]
```

Interval-overlap mode (the master `[low, high]` interval overlaps the using `[ulow, uhigh]` interval):

```stata
rangematch low high using filename_or_framename [if] [in],
    overlap(ulow uhigh)
    [, by(varlist) keepusing(varlist) prefix(string) suffix(string)
       all unmatched(master|none|using|both) generate(name)
       masterid(name) usingid(name) maxpairs(#)
       frame(name) replace saving(filename[, replace]) stats
       closed(both|none) tolerance(#) missing(wildcard|drop|error)
       assert(match|using) sort nosort dryrun count verbose]
```

## Positional Arguments

| Argument | Description |
|----------|-------------|
| `keyvar` | Numeric key variable in the using dataset. Required in master too when `low` or `high` is a scalar offset, or when `nearest()` is specified. |
| `low` | Numeric master variable defining the lower bound, numeric scalar offset from master `keyvar`, or literal `.` for open-ended below. |
| `high` | Numeric master variable defining the upper bound, numeric scalar offset from master `keyvar`, or literal `.` for open-ended above. |

Examples:

```stata
* Variable bounds, after creating lo and hi in the Quick Start master data
generate double lo = event_date - 14
generate double hi = event_date + 14
rangematch event_date lo hi using `events'

* Scalar offsets from master event_date
rangematch event_date -30 30 using `events'

* Open-ended lower bound through 30 days after master event_date
rangematch event_date . 30 using `events'
```

Output preserves variable labels, value-label attachments and definitions, and the master dataset label for both master and carried using variables, as `merge` does. If master and using data define the same value-label name with different mappings, the master definition wins.

## Options

| Option | Description |
|--------|-------------|
| `overlap(ulow uhigh)` | Switch to interval-overlap mode: match where the master `[low, high]` interval overlaps the using `[ulow, uhigh]` interval. With `closed(both)` (default) touching endpoints count; with `closed(none)` comparisons are strict. Not combinable with `nearest()`, `ties()`, `distance()`, scalar offset bounds, or `closed(left|right)`. `r(backend)` reports `overlap`. |
| `by(varlist)` | Restrict matches to groups with identical values in master and using. `strL` by-variables are not allowed; recast to `str#` first. |
| `keepusing(varlist)` | Variables to carry from the using dataset. |
| `prefix(string)` | Prefix for renamed using variables. |
| `suffix(string)` | Suffix for renamed using variables; default conflict suffix is `_U` when no prefix or suffix is specified. |
| `all` | Rename all using variables with the requested prefix/suffix, not just conflicts. |
| `unmatched(master|none|using|both)` | Keep unmatched rows from the master side, using side, both sides, or neither; default is `master`. |
| `generate(name)` | Create a value-labeled match indicator variable: `1` = unmatched master, `2` = unmatched using, `3` = matched pair. |
| `distance(name)` | Create signed distance, using `keyvar` minus master `keyvar`, for matched pairs. |
| `masterid(name)` | Create an original master row-number variable. |
| `usingid(name)` | Create an original using row-number variable. |
| `maxpairs(#)` | Abort if output rows exceed `#`; `0` means no guard. |
| `frame(name)` | Write output to named frame and leave current data unchanged. Existing target frames require `replace`. |
| `replace` | Allow replacement of an existing target frame; valid only with `frame()`. |
| `saving(filename[, replace])` | Save output to a dataset on disk instead of replacing the current data. Cannot be combined with `frame()`, `dryrun`, or `count`. |
| `stats` | Display match-density diagnostics, including p50/p90/p99 matches per master row, and post match-density stored results. Core count results are posted even without `stats`. |
| `closed(both|left|right|none)` | Control endpoint closure: `both` = `[lo,hi]`, `left` = `[lo,hi)`, `right` = `(lo,hi]`, `none` = `(lo,hi)`. |
| `tolerance(#)` | Apply a nonnegative boundary-comparison tolerance for floating-point keys; default is `0`. |
| `missing(wildcard|drop|error)` | Policy for master rows with a missing variable bound: `wildcard` (default) treats missing as open-ended on that side; `drop` removes those rows before matching; `error` aborts. Applies only to bound variables; literal `.` is unaffected. If `drop` empties an entire `by()` group from master, the corresponding using rows still surface under `unmatched(using|both)` and trip `assert(using)`. `r(N_master)` is the post-drop count; `r(N_master) + r(N_missing_bounds)` recovers the post-`if`/`in`, pre-drop master count. |
| `nearest(before|after|both)` | Keep nearest using observations within the interval relative to the master key. |
| `ties(all|first|last)` | Tie handling for `nearest()`; default is `all`. |
| `assert(match|using)` | Abort if every master row must match (`match`), every using row must match (`using`), or both. |
| `sort` | Sort output by original master row and using row; default. |
| `nosort` | Skip the final output sort and leave rows in backend materialization order. |
| `dryrun` | Validate and report output counts without replacing data or writing a frame; any `frame()` target is ignored. Alias: `count`. |
| `count` | Synonym for `dryrun`. |
| `verbose` | Display diagnostics plus elapsed seconds for load, match, and materialize phases. Very large joins also display matching progress. |

## Stored Results

`rangematch` stores core count results in `r()` after successful runs, including `dryrun`, `count`, and runs without `stats`. Match-density results are computed and posted only when `stats` is specified.

| Core scalar | Description |
|-------------|-------------|
| `r(N_master)` | Master observations considered |
| `r(N_using)` | Using observations loaded |
| `r(N_pairs)` | Total output rows, including unmatched rows |
| `r(N_unmatched)` | Unmatched output rows |
| `r(N_matched_pairs)` | Matched output rows |
| `r(N_missing_bounds)` | Master rows with a missing variable bound for `low` or `high` |
| `r(tolerance)` | Boundary-comparison tolerance used |

| Match-density scalar, only with `stats` | Description |
|-----------------------------------------|-------------|
| `r(N_matched_master)` | Master observations with at least one match |
| `r(N_matched_using)` | Using observations with at least one match |
| `r(N_unmatched_master)` | Unmatched master observations |
| `r(N_unmatched_using)` | Unmatched using observations |
| `r(max_matches)` | Maximum matches for any one master observation |
| `r(mean_matches)` | Mean matches per master observation |
| `r(median_matches)` | Median matches per master observation |
| `r(p50_matches)` | p50 matches per master observation |
| `r(p90_matches)` | p90 matches per master observation |
| `r(p99_matches)` | p99 matches per master observation |
| `r(N_empty_groups)` | By-groups with no using observations |
| `r(N_master_groups)` | Master by-groups considered |

| Macro | Description |
|-------|-------------|
| `r(cmd)` | `rangematch` |
| `r(cmdline)` | Command as typed |
| `r(using)` | Using filename or frame name |
| `r(using_source)` | `file` or `frame` |
| `r(key)` | Parsed key variable |
| `r(low)` | Parsed lower bound |
| `r(high)` | Parsed upper bound |
| `r(by)` | Parsed `by()` variables |
| `r(keepusing)` | Parsed `keepusing()` variables |
| `r(prefix)` | Parsed `prefix()` string |
| `r(suffix)` | Parsed `suffix()` string |
| `r(unmatched)` | Parsed `unmatched()` mode |
| `r(closed)` | Parsed `closed()` mode |
| `r(missing)` | Parsed `missing()` mode |
| `r(frame)` | Target frame name, when `frame()` is used |
| `r(saving)` | Output filename, when `saving()` is used |
| `r(nearest)` | Parsed nearest mode |
| `r(ties)` | Parsed tie mode |
| `r(sort)` | `sort`, when final output sorting is active |
| `r(nosort)` | `nosort`, when specified |
| `r(assert)` | Parsed `assert()` tokens |
| `r(generate)` | Parsed `generate()` variable |
| `r(distance)` | Parsed `distance()` variable |
| `r(masterid)` | Parsed `masterid()` variable |
| `r(usingid)` | Parsed `usingid()` variable |
| `r(maxpairs)` | Parsed `maxpairs()` limit |
| `r(all)` | `all`, when specified |
| `r(stats)` | `stats`, when specified |
| `r(dryrun)` | `dryrun`, when specified |
| `r(count)` | `count`, when specified |
| `r(verbose)` | `verbose`, when specified |
| `r(backend)` | Pair-generation backend selected: `sweep` or `binary` |

## Notes

- Missing using keys never match.
- Literal `.` as a positional bound is open-ended.
- Missing values in variable bounds are treated as open-ended on that side.
- `frame(name)` is the safe exploratory mode: it preserves the current frame and writes output elsewhere.
- If the token after `using` names an existing frame, `rangematch` copies that frame internally and leaves it unchanged; otherwise it treats the token as a filename.
- `saving()` writes the output to disk and leaves the current data unchanged.
- `nearest()` still respects the supplied interval; it does not match observations outside the bounds.
- `tolerance(#)` expands lower and upper boundary comparisons by `#` to absorb floating-point representation noise; it is not a statistical matching rule.
- Output is sorted by original master row and original using row by default; `nosort` skips this final sort.
- `dryrun` and `count` are aliases. They never replace data and never write a frame.
- With `by()` and `stats`, `rangematch` warns when more than half of master by-groups have no using rows.

## Performance

The generic binary-search matching path scales approximately as `O(M log U + K)`, where `M` is the number of master rows considered, `U` is the number of using rows, and `K` is the number of emitted output pairs. For compatible all-match workloads, `rangematch` can use a sweep/two-pointer backend that establishes a safe internal master-interval order before matching, reducing the matching step toward `O(M + U + K)`. This internal ordering is not an output-order promise: default output is still sorted by original master row and original using row, while `nosort` leaves the backend materialization order.

The backend is selected conservatively. Compatible non-`nearest()` workloads can use the sweep backend while preserving `stats`, `assert(using)`, and `unmatched(using|both)` bookkeeping. `nearest()` uses the generic path. Check `r(backend)` after a run to see which backend generated the pairs. Total runtime also includes loading the using data, grouping, carrying variables into the output, and any final output sort. `by()` helps when it partitions the using keys into smaller relevant groups. Wide using datasets are more expensive to materialize, so specify `keepusing()` when only selected using variables are needed.

## Migrating from `rangejoin`

Most `rangejoin` calls translate directly:

```stata
rangejoin key lo hi using file
rangematch key lo hi using file
```

`rangematch` adds `frame()` output, using-from-frame input, scalar-offset bounds such as `-30 30`, `unmatched()` control, `nearest()`, `distance()`, and `saving()`.

## Migrating from `joinby`

The common `joinby`+filter pattern

```stata
joinby id using events.dta, unmatched(none)
keep if inrange(event_date, lo, hi)
```

becomes

```stata
rangematch event_date lo hi using events.dta, by(id) unmatched(none)
```

Three things change when porting:

1. **Master/using direction may flip.** `joinby` treats the in-memory dataset as master regardless of which side carries the join key. With `rangematch`, master holds the bounds and using holds the key. For a typical "narrow registry rows to a wide cohort" pipeline, put the cohort (with bounds) in memory and the registry on the using side.

2. **`unmatched()` defaults differ.** `joinby` drops unmatched rows; `rangematch` defaults to `unmatched(master)`. Specify `unmatched(none)` to reproduce `joinby` semantics.

3. **Missing variable bounds are handled differently.** When a `joinby` is followed by `keep if inrange(date, lo, hi)`, rows with missing `lo` or `hi` are silently dropped because every comparison against missing returns false. `rangematch` treats a missing bound as open-ended on that side, consistent with the literal `.` positional bound, so those rows wildcard-match every using row in the same `by()` group. **If your bound variables can be missing and you are porting from `joinby`+filter, drop missing-bound rows upstream or specify `missing(drop)`; otherwise output may contain spurious wildcard matches.** Use `missing(error)` to make `rangematch` refuse to run when missing-bound rows are present — the recommended setting for production registry pipelines.

```stata
* joinby pattern: missing bounds silently dropped by the inrange() filter
joinby id using events.dta, unmatched(none)
keep if inrange(event_date, lo, hi)

* Direct rangematch port: missing lo/hi become open-ended (wildcard matches)
rangematch event_date lo hi using events.dta, by(id) unmatched(none)

* Equivalent rangematch port: missing(drop) preserves joinby+filter behavior
rangematch event_date lo hi using events.dta, by(id) unmatched(none) missing(drop)
```

`rangematch` also avoids the Cartesian blow-up of `joinby`+`keep if`, which materializes the full within-`by()` Cartesian product before filtering. `rangematch` emits matched pairs directly through binary search or sweep, which is a substantial memory and time win on registry-scale datasets with selective intervals (see the benchmark table below).

The same win applies to **interval-overlap** joins. The common pattern

```stata
joinby id using episodes.dta
keep if (entry <= rx_stop) & (rx_start <= exit)
```

becomes

```stata
rangematch entry exit using episodes.dta, by(id) overlap(rx_start rx_stop) unmatched(none)
```

which never materializes the full Cartesian product of cohort windows and episodes.

## Quality Assurance

Run the full release gate from `rangematch/qa`:

```bash
stata-mp -b do run_all.do
```

The `qa/` directory contains 888 counted assertions across 30 QA files:
27 functional test files and 3 validation files.

- `test_documentation_examples.do` - 28 tests
- `test_install.do` - 5 tests
- `test_rangematch_abbrev.do` - 1 test
- `test_rangematch_adversarial.do` - 64 tests
- `test_rangematch_backend_equivalence.do` - 15 tests
- `test_rangematch_basic.do` - 26 tests
- `test_rangematch_by.do` - 17 tests
- `test_rangematch_display_contract.do` - 1 test
- `test_rangematch_missing.do` - 16 tests
- `test_rangematch_missing_option.do` - 18 tests
- `test_rangematch_missing_option_extra.do` - 31 tests
- `test_rangematch_overlap.do` - 44 tests
- `test_rangematch_return_contract.do` - 79 tests
- `test_rangematch_routing_contract.do` - 33 tests
- `test_rangematch_saving_matrix.do` - 22 tests
- `test_rangematch_v101.do` - 4 tests
- `test_rangematch_v110.do` - 98 tests
- `test_rangematch_v120.do` - 47 tests
- `test_rangematch_v130.do` - 45 tests
- `test_rangematch_v140.do` - 49 tests
- `test_rangematch_v141.do` - 21 tests
- `test_rangematch_v144.do` - 33 tests
- `test_rangematch_v145.do` - 84 tests
- `test_rangematch_v147.do` - 15 tests
- `test_rangematch_v148.do` - 24 tests
- `test_rangematch_v16compat.do` - 0 tests
- `test_release_integrity.do` - 9 tests
- `validation_rangematch_manual.do` - 26 validations
- `validation_rangematch_nearest.do` - 7 validations
- `validation_rangematch_oracle.do` - 26 validations

## Benchmark

The demo benchmark compares the overlapping grouped range-join case:
`key lo hi using file, by(group)`. `rangematch` uses `unmatched(none)` and
`nosort` so both commands emit matched pairs without a final order guarantee.
The demo installs `rangestat` and `rangejoin` from SSC into a temporary PLUS
directory for the comparison run. Results are machine-dependent and depend on
which backend the installed build selects. The timings below reflect the sweep-backend path on 2026-05-12; `rangejoin`
timings are from the same-day comparison run.

| Scenario | Master rows | Using rows | Groups | Half-width | Output pairs | rangematch sec | rangejoin sec | rangejoin/rangematch |
|----------|-------------|------------|--------|------------|--------------|----------------|---------------|----------------------|
| sparse_10k | 10,000 | 10,000 | 20 | 0 | 10,000 | 0.072 | 0.154 | 2.139 |
| dense_10k | 10,000 | 10,000 | 20 | 10 | 207,800 | 0.161 | 0.152 | 0.944 |
| sparse_100k | 100,000 | 100,000 | 50 | 0 | 100,000 | 0.382 | 0.435 | 1.139 |
| dense_100k | 100,000 | 100,000 | 50 | 5 | 1,098,500 | 0.772 | 1.081 | 1.400 |
| sparse_1m | 1,000,000 | 1,000,000 | 100 | 0 | 1,000,000 | 2.953 | 4.245 | 1.438 |
| dense_1m | 1,000,000 | 1,000,000 | 100 | 1 | 2,999,800 | 3.937 | 5.781 | 1.468 |

Values below 1 in the final column mean `rangejoin` was faster in this
pure-overlap benchmark. `rangematch` adds features not covered by this
comparison, including frame output, using-frame input, unmatched-row modes,
nearest matching, distance variables, explicit output saving, and deterministic
default output sorting.

The package also ships `bench_rangematch.do`, a self-contained timing script that always benchmarks `rangematch` and optionally compares SSC `rangejoin` when it is installed. After installation, retrieve the ancillary benchmark file with `net get`:

```stata
net get rangematch, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/rangematch")
do bench_rangematch.do
```

## Version History

### 1.3.1 (2026-07-02)

- **Fixed: `saving()` silently ignored with a compound-quoted filename.** With
  `` saving(`"path"') `` (the standard idiom for tempfiles and paths built in
  macros), the internal quote-stripping left a bare `` `...' `` wrapper that
  downstream macro expansion swallowed as an undefined macro reference. The
  filename became empty, no file was written, no error was raised, and the
  output was rerouted to the default in-place path -- replacing the data in
  memory. Filenames are now unquoted with `gettoken`, which strips one binding
  layer of either quote style. Plain-quoted and unquoted filenames were
  unaffected.
- **Fixed: variable labels, value labels, and the dataset label were dropped
  from output.** The output materializer copied storage types and display
  formats but not labels, and value-label definitions did not survive the
  output-frame swap. Output now preserves variable labels, value-label
  attachments and definitions (for master and carried using variables, on
  every output route: in-place, `frame()`, and `saving()`), and the master
  dataset label, matching `merge` behavior. If master and using data define
  the same value-label name differently, the master definition wins.
- **Fixed: `by()` with a strL variable failed mid-run with a misleading
  error.** The internal group-catalog merge rejected strL keys with
  "key variable ... is strL" (r(106)), misattributing the problem to the match
  key. strL `by()` variables are now rejected upfront on both the master and
  using side with a clear message (r(109)); recast to str# first.
- QA: added a label-preservation suite (all output routes, using-as-frame,
  `keepusing()`, label-name collision, extended-missing labels, dataset
  label), compound-quoted `saving()` regression cells, and strL `by()` guard
  tests.

### 1.3.0 (2026-07-01)

- **`ties(random)` for unbiased tie-breaking.** With `nearest()`, `ties(random)`
  keeps one of the equally nearest using rows chosen uniformly at random, rather
  than by original row order. In a matched design, breaking ties by row order
  (`ties(first)`/`ties(last)`) can induce selection bias when that order is
  correlated with enrollment date, ID assignment, or site. New `seed(#)` option
  makes the random draw reproducible; the caller's random-number state is
  restored afterwards, so `seed()` does not disturb other random draws in the
  session. New stored result `r(seed)`.
- **Inverted using-interval screen (overlap mode).** A using interval with
  `ulow > uhigh` (a common registry data-quality defect from swapped start/stop)
  is not screened by the overlap backend and can emit matches reflecting the
  swapped bounds. `rangematch` now counts such intervals, posts the count in the
  new stored result `r(N_using_inverted)` (0 outside overlap mode), and prints a
  non-fatal warning. Master intervals with `low > high` remain treated as empty.
- QA: added a `ties(random)` reproducibility/seed-restore suite and an
  inverted-overlap-interval known-truth suite.

### 1.2.0 (2026-06-30)

- **Symmetric `missing()` policy.** `missing(wildcard|drop|error)` now governs the
  using side as well as the master side: a missing point `keyvar` (point mode) or a
  missing `ulow`/`uhigh` bound (overlap mode). `wildcard` (the default) preserves
  historical behavior exactly -- missing using keys never match and missing using
  bounds stay open-ended -- so existing scripts are unaffected; `drop` and `error`
  now extend to using rows. New stored result `r(N_using_missing)`.
- **Float-precision warning.** A non-fatal warning is printed when a matching
  variable (master bound, using key, or using interval bound) is stored as `float`
  with values beyond float's exact-integer range (2^24, e.g. `%tc` clocks), where
  boundary equality can fail after the internal `double` cast. Recast to `double`
  or use `tolerance()`. `%td` dates and small magnitudes are not flagged.
- Clarified that `ties(first|last)` selects the tied using row with the
  lowest/highest original observation number.
- QA: added a sweep-vs-binary backend differential harness (320 cells across
  `closed()` x `tolerance()` x open-ended bounds x `by()` x `unmatched()`),
  using-side `missing()` known-truth tests, a float-warning suite, and an
  edge-case top-up (zero-obs using, all-missing master per policy, `maxpairs`
  boundary-exact, restore-after-error).

### 1.1.1 (2026-06-26)

- Fixed internal `__rm_*` workspace handling so user variables with names such
  as `__rm_obs`, `__rm_low`, `__rm_high`, `__rm_key`, and `__rm_gid` are
  preserved in output instead of colliding with or being removed by cleanup.
- Expanded QA coverage for internal-name regressions and the complete
  stored-result local contract.

### 1.1.0 (2026-06-25)

- Added **interval-overlap mode** via `overlap(ulow uhigh)`: matches where the master `[low, high]` interval overlaps the using `[ulow, uhigh]` interval (`low <= uhigh & ulow <= high`), reusing the Mata pair-generation backend so the full within-`by()` Cartesian product is never materialized. Supports `closed(both|none)`, `tolerance()`, `by()`, `unmatched()`, `keepusing()`, `frame()`/`saving()`, `stats`, `generate()`, `masterid()`/`usingid()`, `maxpairs()`, and `missing()`. Point-only options (`nearest()`, `ties()`, `distance()`, scalar offsets) and `closed(left|right)` are rejected in this mode.
- New stored macro `r(overlap)`; `r(backend)` now also reports `overlap`.
- Mata backend version contract bumped to 1.1.0.

### 1.0.3 (2026-06-19)

- Added `bench_rangematch.do` to the package manifest so `net get rangematch` retrieves the shipped benchmark script.
- Synchronized release metadata and the Mata backend version contract for the 1.0.3 release.
- Lowered the release-integrity QA harness floor to Stata 16.1 and removed a dev-repo path reference from the demo conversion step.

### 1.0.2 (2026-05-28)

- Aligned the code's declared `version` floor with the documented and packaged minimum: `rangematch.ado` and `_rangematch_mata.ado` now declare `version 16.1` (was `16.0`), matching the `Stata 16.1+` requirement in the help file, README, and `.pkg`. No change to behavior on Stata 16.1 or later.

### 1.0.1 (2026-05-13)

- `using` filename now auto-appends `.dta` when no extension is supplied, matching Stata's `use` behavior (e.g. `... using antibiotics` works the same as `... using antibiotics.dta`).

### 1.0.0 (2026-05-12)

- Initial release.
- Mata binary-search pair generation with sweep/two-pointer fast path.
- Frame-based workspace with `frame()` output and `saving()` on disk.
- `by()`, `keepusing()`, `prefix()`/`suffix()`, `unmatched()`, `generate()`, `maxpairs()`.
- Scalar-offset bounds (`-30 30`), literal `.` open-ended bounds.
- `distance()`, `nearest()`/`ties()`, `masterid()`/`usingid()`, `assert()`.
- `tolerance()` for floating-point boundary comparisons.
- `stats` match-density diagnostics with p50/p90/p99.
- `closed()`, `sort`/`nosort`, `dryrun`/`count`, `verbose`.
- Shipped benchmark do-file for comparison with `rangejoin`.

## Author

Timothy P Copeland, Karolinska Institutet
