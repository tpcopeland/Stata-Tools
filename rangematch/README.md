# rangematch — Range joins for interval data

**Version 1.5.3** | 2026-08-13

`rangematch` joins an in-memory master dataset to a using file or frame by matching points to intervals or intervals to intervals. It is for workflows that need the joined rows themselves, with frame-safe output, unmatched-row controls, nearest matching, diagnostics, and stored results.

## Quick Start

Run a rolling date-window join and write the result to a separate frame so the current data remain unchanged.

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

## Requirements

- Stata 16.1 or later
- No external dependencies

## Installation

Install the released package from Stata-Tools:

```stata
capture ado uninstall rangematch
net install rangematch, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/rangematch") replace
```

The release installs the public command, its Mata backend, and the help file. The optional benchmark do-file can be retrieved separately with `net get`; it is not needed to run `rangematch`.

## Commands

| Command | Description |
|---------|-------------|
| `rangematch` | Join master intervals to using points or overlapping using intervals |

## How It Works

The in-memory dataset is always the master side. In point-in-interval mode, each master interval is matched to every using observation whose numeric key falls inside it. In interval-overlap mode, `overlap(ulow uhigh)` matches master intervals to using intervals that overlap them.

| Mode | Master arguments | Using input | Match rule |
|------|------------------|-------------|------------|
| Point-in-interval | `keyvar low high` | Numeric `keyvar` in a file or frame | `using.keyvar` falls within the master interval |
| Interval-overlap | `low high` plus `overlap(ulow uhigh)` | Numeric `ulow` and `uhigh` in a file or frame | The two intervals overlap under `closed()` |

The `using` token names an existing frame when one exists with that name; otherwise it is treated as a filename, with `.dta` appended when the filename has no extension. A using frame is copied internally and left unchanged. `by()` restricts matches to compatible group values on both sides, and `if`/`in` select master observations.

By default, successful output replaces the current data with matched pairs plus unmatched master observations. `frame(name)` writes the result to a named frame and preserves the current data, while `saving(filename[, replace])` writes a dataset to disk and preserves the current data. `dryrun` and its alias `count` validate the request and report counts without writing output.

The default output order is original master observation order followed by original using observation order. `nosort` leaves backend materialization order. Carried variables preserve storage types, formats, variable labels, value-label attachments and definitions, and the master dataset label; dataset notes and characteristics — both `_dta[]` and variable-level — are not carried.

The point backends use binary search and can select a sweep backend for compatible all-match calls. Overlap mode uses a streaming plane-sweep backend, so the full within-group Cartesian product is not materialized before filtering. Check `r(backend)` after a run: it is `binary`, `sweep`, or `overlap`.

## Worked Examples

Examples 1, 2, and 5 continue the Quick Start data; examples 3 and 4 are self-contained. Reload the master before each call because an in-place run replaces the data in memory.

### 1. Variable bounds and endpoint closure

Use master variables for the bounds and `closed(left)` for a half-open interval `[low, high)`; `unmatched(none)` keeps only matched pairs.

```stata
use `master', clear
generate double lo = event_date - 14
generate double hi = event_date + 14
rangematch event_date lo hi using `events', closed(left) unmatched(none)
list id eid event_date
```

### 2. Nearest matches with provenance and distance

Scalar offsets define the search window around the master key. `nearest(both)` keeps the nearest in-range using key on either side, while the ID and distance options expose provenance and signed separation.

```stata
use `master', clear
rangematch event_date -40 40 using `events', nearest(both) ties(first) ///
    masterid(master_row) usingid(using_row) distance(delta) unmatched(none)
list id eid event_date master_row using_row delta
```

### 3. Patient-specific exposure windows

This self-contained workflow carries selected using variables, creates a merge-style match indicator, and writes the joined rows to a frame.

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

### 4. Interval-overlap matching

Use `overlap(ulow uhigh)` when both datasets contain intervals. In this example, the unmatched second cohort interval is retained by the default `unmatched(master)` behavior.

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

### 5. Count before materializing or save to disk

Use `count` to inspect output size without changing the data, then use `saving()` when the joined dataset should be written instead of becoming the current data.

```stata
use `master', clear
rangematch event_date . 30 using `events', count
return list

tempfile matches
rangematch event_date -30 30 using `events', saving("`matches'", replace)
return list
```

## Demo

The repository-only [`demo/demo_rangematch.do`](demo/demo_rangematch.do) installs the local package into temporary ado trees, runs an exposure-window workflow, and generates workflow and benchmark logs that it converts to Markdown with `logdoc`. Run it from a Stata-Tools checkout; it is not delivered by `net install` and requires the sibling `logdoc` package in that checkout, while SSC `rangestat` and `rangejoin` are optional comparison packages.

The shipped [`bench_rangematch.do`](bench_rangematch.do) script runs six synthetic point-in-interval scenarios with analytic expected pair counts and optionally compares an installed `rangejoin`. Retrieve it into the current directory with:

```stata
net get rangematch, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/rangematch") replace
do bench_rangematch.do
```

## Command Reference

### Syntax

Point-in-interval mode:

```stata
rangematch keyvar low high using filename_or_framename [if] [in]
    [, by(varlist) keepusing(varlist) prefix(string) suffix(string)
       all unmatched(master|none|using|both) generate(name) distance(name)
       masterid(name) usingid(name) maxpairs(#) frame(name) replace stats
       nosort closed(both|left|right|none) nearest(before|after|both)
       ties(all|first|last|random) seed(#) tolerance(#)
       missing(wildcard|drop|error) assert(match|using)
       saving(filename[, replace]) dryrun count verbose]
```

Interval-overlap mode:

```stata
rangematch low high using filename_or_framename [if] [in]
    , overlap(ulow uhigh)
      [by(varlist) keepusing(varlist) prefix(string) suffix(string)
       all unmatched(master|none|using|both) generate(name)
       masterid(name) usingid(name) maxpairs(#) frame(name) replace stats
       nosort closed(both|none) tolerance(#) missing(wildcard|drop|error)
       assert(match|using) saving(filename[, replace]) dryrun count verbose]
```

### Positional arguments

| Argument | Contract |
|----------|----------|
| `keyvar` | Numeric using key in point mode. It must also be numeric in master when scalar offset bounds, `nearest()`, or `distance()` is used. It is omitted in overlap mode. |
| `low` | Numeric master lower-bound variable, numeric scalar offset from master `keyvar`, or literal `.` for an open lower bound. In overlap mode it is the master lower interval bound and cannot be a scalar offset. |
| `high` | Numeric master upper-bound variable, numeric scalar offset from master `keyvar`, or literal `.` for an open upper bound. In overlap mode it is the master upper interval bound and cannot be a scalar offset. |
| `using` | Existing frame name or dataset filename. Existing frame names take precedence; filenames without an extension are also tried with `.dta` appended. |

## Key Options

| Option | Default | Contract |
|--------|---------|----------|
| `overlap(ulow uhigh)` | Off | Select interval-overlap mode and name exactly two numeric using interval-bound variables. Point-only `nearest()`, `ties()`, `distance()`, scalar offsets, and `closed(left\|right)` are not allowed. |
| `by(varlist)` | None | Restrict matches to equal values in both datasets. Variables must have compatible types; `strL` by-variables are not allowed. |
| `keepusing(varlist)` | All using variables | Select using variables to carry into output. Matching keys and by-variables are loaded as needed, and by-variables appear once in the output. |
| `prefix(string)` | None | Prefix renamed using variables. If both `prefix()` and `suffix()` are omitted or explicitly empty, conflicting names use `_U`. |
| `suffix(string)` | None; `_U` for conflicts when both are omitted/empty | Suffix renamed using variables. If a prefix or suffix is supplied, it controls the requested names; `all` applies it to every carried using variable. |
| `all` | Off | Rename all carried using variables with the requested prefix and/or suffix, not only variables that conflict with master names. |
| `unmatched(master\|none\|using\|both)` | `master` | Keep unmatched master rows, neither side, unmatched using rows, or both sides. |
| `generate(name)` | None | Create a byte match indicator: 1 = master only, 2 = using only, and 3 = matched pair, with a value label. |
| `distance(name)` | None | Create `using.keyvar - master.keyvar` for matched pairs. Requires a numeric master `keyvar` and is not allowed in overlap mode. |
| `masterid(name)` | None | Create the original master observation number; it is missing on using-only rows. |
| `usingid(name)` | None | Create the original using observation number; it is missing on master-only rows and remains the pre-policy row number under `missing(drop)`. |
| `maxpairs(#)` | `0` | Abort before materialization if output would exceed `#`; `0` imposes no limit. |
| `frame(name)` | In-place output | Write output to a named frame and leave current data unchanged. The target must differ from the current and using source frames; an existing target requires `replace`. |
| `replace` | Off | Permit replacement of an existing `frame()` target. It is valid only with `frame()`. |
| `saving(filename[, replace])` | None | Save output to disk and leave current data unchanged. It cannot be combined with `frame()`, `dryrun`, or `count`; a filename without an extension is reported with the `.dta` extension in `r(saving)`. |
| `stats` | Off | Display match-density diagnostics and post the match-density results below. Core count results are posted on every successful run, including runs without `stats`. |
| `nosort` | Off | Skip the final sort by original master and using row. Internal key sorting still occurs for matching. |
| `dryrun` | Off | Validate and report counts without replacing data or creating/replacing a frame. It is an alias of `count`. |
| `count` | Off | Synonym for `dryrun`. |
| `verbose` | Off | Display loading, grouping, matching, output, and timing diagnostics; large joins also show matching progress. |
| `closed(both\|left\|right\|none)` | `both` | Choose inclusive `[low, high]`, `[low, high)`, `(low, high]`, or open `(low, high)` endpoint rules. Overlap mode accepts only `both` and `none`. |
| `tolerance(#)` | `0` | Expand lower and upper boundary comparisons by a nonnegative finite value to absorb floating-point representation noise; it is not a statistical matching rule. |
| `missing(wildcard\|drop\|error)` | `wildcard` | Treat missing variable bounds as open on that side, drop offending rows before matching, or abort. A literal positional `.` is an explicit open bound and is unaffected. |
| `nearest(before\|after\|both)` | Off | Keep only the nearest in-range using key before, after, or on both sides of the numeric master key. It is point-mode only. |
| `ties(all\|first\|last\|random)` | `all` | Resolve equally nearest using rows. `first` and `last` use original using row order; `random` samples one tied row. The option is allowed only with `nearest()`. |
| `seed(#)` | Not set | Set the random tie-breaking seed when `ties(random)` is used. A supplied seed is restored after the call; without it, the current RNG stream advances. |
| `assert(match\|using)` | Off | Abort if every considered master row must match, every using row must match, or both. Assertions are enforced under `dryrun` and `count` before counts are displayed or posted. |

## Stored Results

Core results are posted in `r()` after successful runs, including `dryrun`, `count`, and runs without `stats`. The counts reflect the selected master sample and the post-policy using sample.

| Core scalar | Meaning |
|-------------|---------|
| `r(N_master)` | Master observations considered |
| `r(N_using)` | Using observations loaded after any `missing(drop)` policy |
| `r(N_pairs)` | Total output rows, including unmatched rows |
| `r(N_unmatched)` | Total unmatched output rows |
| `r(N_matched_pairs)` | Matched output rows |
| `r(N_missing_bounds)` | Master rows with a missing variable bound; literal `.` bounds are not counted |
| `r(N_master_key_missing)` | Master rows with a missing matching key when scalar offsets or `nearest()` make the key an input; 0 otherwise |
| `r(N_using_missing)` | Using rows with a missing point key or interval bound |
| `r(N_using_inverted)` | Using overlap intervals with `ulow > uhigh`; 0 outside overlap mode |
| `r(tolerance)` | Boundary-comparison tolerance used |

The following scalars are posted only with `stats`:

| Match-density scalar | Meaning |
|----------------------|---------|
| `r(N_matched_master)` | Master observations with at least one match |
| `r(N_matched_using)` | Using observations with at least one match |
| `r(N_unmatched_master)` | Unmatched master observations |
| `r(N_unmatched_using)` | Unmatched using observations |
| `r(max_matches)` | Maximum matches for one master observation |
| `r(mean_matches)` | Mean matches per master observation |
| `r(median_matches)` | Median matches per master observation |
| `r(p50_matches)` | p50 matches per master observation |
| `r(p90_matches)` | p90 matches per master observation |
| `r(p99_matches)` | p99 matches per master observation |
| `r(N_empty_groups)` | Master by-groups with no using row at all; a group with unusable using rows is not empty |
| `r(N_master_groups)` | Master by-groups considered |

Percentiles use Stata's sample-percentile definition on the per-master match counts, so `p50`, `p90`, and `p99` agree with `_pctile` and `summarize, detail` for the same counts.

The command also returns parsing and routing macros. Macros marked as conditional are returned only when the corresponding mode or option is active and succeeds.

| Macro | Meaning |
|-------|---------|
| `r(cmd)` | `rangematch` |
| `r(cmdline)` | Command as typed |
| `r(using)` | Using filename or frame name |
| `r(using_source)` | `file` or `frame` |
| `r(frame)` | Successful `frame()` target, when used |
| `r(saving)` | Successful output filename, normalized with `.dta` when needed |
| `r(key)` | Parsed point-mode key variable; empty in overlap mode |
| `r(low)` | Parsed lower-bound variable or scalar |
| `r(high)` | Parsed upper-bound variable or scalar |
| `r(overlap)` | Using interval-bound variables when `overlap()` is used |
| `r(by)` | Parsed `by()` variables |
| `r(keepusing)` | Parsed `keepusing()` variables |
| `r(prefix)` | Parsed `prefix()` string |
| `r(suffix)` | Parsed `suffix()` string |
| `r(unmatched)` | Parsed `unmatched()` mode |
| `r(closed)` | Parsed `closed()` mode |
| `r(missing)` | Parsed `missing()` mode |
| `r(nearest)` | Parsed `nearest()` mode |
| `r(ties)` | Parsed tie mode, defaulting to `all` |
| `r(seed)` | Supplied seed token when used with `ties(random)` |
| `r(sort)` | `sort` when final output sorting is active |
| `r(nosort)` | `nosort` when requested |
| `r(assert)` | Parsed `assert()` tokens |
| `r(generate)` | Parsed `generate()` variable |
| `r(distance)` | Parsed `distance()` variable |
| `r(masterid)` | Parsed `masterid()` variable |
| `r(usingid)` | Parsed `usingid()` variable |
| `r(maxpairs)` | Parsed `maxpairs()` limit |
| `r(all)` | `all` when specified |
| `r(stats)` | `stats` when specified |
| `r(dryrun)` | `dryrun` when specified |
| `r(count)` | `count` when specified |
| `r(verbose)` | `verbose` when specified |
| `r(backend)` | Pair-generation backend selected: `sweep`, `binary`, or `overlap` |

## Assumptions and Limits

- Matching keys and interval bounds must be numeric. Scalar offsets and `nearest()` require a numeric master key; `distance()` also requires the master key even when the bounds are variables.
- Under the default `missing(wildcard)`, a missing lower or upper variable bound removes only that side's restriction. A row missing both bounds is fully open; a missing point key never matches. Use `missing(drop)` or `missing(error)` when missing values should not create open-ended matches.
- In overlap mode, inverted intervals and open-degenerate intervals are empty under the selected closure rule. Inverted using intervals are warned about and counted in `r(N_using_inverted)`; they never generate a match.
- `float` matching variables with nonmissing values beyond the exact-integer range `2^24` produce a precision warning. Recast values such as `%tc` clocks to `double`, or use a small `tolerance()` when representation noise is the issue.
- Large joins can produce many output rows. Use `by()`, `keepusing()`, and `maxpairs()` to limit work or stop before materialization; use `rangestat` instead when only range summaries are needed.
- `ties(first)` and `ties(last)` select by original using row order, which can be undesirable when row order is related to enrollment, site, or another selection process. Use `ties(random)` with `seed()` when an order-independent tie choice is needed.
- `frame()` cannot target the current frame, the using source frame, or a name beginning with `__rm_`; those private frame names are reserved for workspace management. `verbose` also requires three unused Stata timers.
- `saving()` cannot be combined with `frame()`, `dryrun`, or `count`, and `replace` is meaningful only for a `frame()` target or the `saving()` suboption.
- Failed `missing(error)` calls exit before posting `r()` results. `assert()` failures also abort before a successful result is available.

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.5.3** (2026-08-13): A using variable whose name runs to 31 or 32 characters no longer aborts the join. `prefix()`/`suffix()` are now validated only for the names they are actually applied to — under the default rules that is a carried variable whose name collides with a master variable — so a non-colliding long name is carried under its own name instead of failing `rc=198` on a decorated name the command never intended to use. `prefix()`/`suffix()` are still screened up front for illegal name characters, and a genuine collision that overflows Stata's 32-character limit now says so. A `prefix()` or `suffix()` containing a space is now rejected instead of silently mis-mapping the output: the decorated name was re-split into two words inside a space-delimited list, so every carried variable after the first renamed one landed under the *next* name in the list — `prefix("p q")` returned `rc=0` with a column named `qdup1` holding a different variable's values and a column named `zz` holding the match key.
- **1.5.2** (2026-08-10): A using filename is now resolved to the file `use` will actually read *before* it is confirmed, so an extensionless name is never confirmed under one name and loaded under another; `r(using)` reports the file that was read. The `.dta` fallback is restricted to extensionless filenames. The help now documents what `r()` holds after a *failed* run — nothing when the failure precedes matching, the counts (but never `r(saving)`/`r(frame)`) when `saving()` fails after matching — and its contracts for missing bounds, `keepusing()`, unmatched inverted master intervals, and explicit filename extensions were corrected.
- **1.5.1** (2026-08-09): Fixed the empty-master/empty-using `by()` edge case so a valid full-outer join returns an empty result instead of failing during group-catalog construction.
- **1.5.0** (2026-07-25): Match-density p50, p90, and p99 now use Stata's sample-percentile definition consistently, `r(N_empty_groups)` has the same using-row-presence meaning in point and overlap modes, and the documentation reflects the current diagnostics.
- **1.4.1** (2026-07-18): Clamped extreme tolerance shifts, extended float-precision warnings, and tightened output and session-state contracts.
- **1.4.0** (2026-07-17): Fixed provenance, interval-validity, frame-safety, missing-policy, value-label, output-routing, and overlap-sweep defects.
- **1.3.0** (2026-07-01): Added reproducible random tie-breaking with `ties(random)` and `seed()`, plus inverted using-interval diagnostics.
- **1.2.0** (2026-06-30): Added symmetric using-side `missing()` handling and float-precision warnings.
- **1.1.0** (2026-06-25): Added interval-overlap mode.
- **1.0.0** (2026-05-12): Initial release with frame workspaces, binary-search matching, unmatched controls, nearest matching, diagnostics, and output routing.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
