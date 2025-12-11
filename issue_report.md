# Issue Report for tvtools `.ado` Files

## 1) `tvevent.ado` drops a frame name as if it were a variable
**Issue:** The cleanup step tries to `drop` the temporary frame name along with variables. Because `drop` only works on variables in the active frame, the statement throws “variable event_frame not found” after successful execution, aborting the program instead of exiting cleanly.

**Problematic snippet:**
```stata
        * Always clean up the frame
        capture frame drop `event_frame'

        * Exit if there was an error
        if `frame_rc' != 0 {
            exit `frame_rc'
        }

        drop `match_date' `imported_type' `event_frame'
```

**Suggested replacement:**
```stata
        * Always clean up the frame
        capture frame drop `event_frame'

        * Exit if there was an error
        if `frame_rc' != 0 {
            exit `frame_rc'
        }

        capture drop `match_date' `imported_type'   // only drop variables
```
This keeps the frame cleanup in place but limits `drop` to actual variables so post-processing doesn’t fail when the frame name isn’t present in the active dataset.

## 2) `tvexpose.ado` requires `reference()` even when using cumulative dose
**Issue:** The syntax block mandates a `reference()` value for every run, yet the dose mode forbids non-zero references and conceptually treats 0 cumulative dose as the baseline. Real-world dose data will often omit a reference option entirely; the current syntax will reject such calls with a 198 error instead of defaulting to 0.

**Problematic snippet:**
```stata
    syntax using/ , ///
        id(name) ///
        start(name) ///
        exposure(name) ///
        reference(numlist max=1) ///
        entry(varname) ///
        exit(varname) ///
        [ ...
        DOse ///
        ... ]
...
    if "`dose'" != "" {
        if `reference' != 0 {
            noisily display as error "reference() may not be used with dose"
            noisily display as error "For dose, 0 cumulative dose is the inherent reference"
            exit 198
        }
    }
```

**Suggested replacement:**
```stata
    syntax using/ , ///
        id(name) ///
        start(name) ///
        exposure(name) ///
        reference(numlist max=1) ///
        entry(varname) ///
        exit(varname) ///
        [ ...
        DOse ///
        ... ]
...
    if "`dose'" != "" {
        if "`reference'" == "" local reference 0   // default baseline for dose
        else if `reference' != 0 {
            noisily display as error "reference() must be 0 when dose is specified"
            exit 198
        }
    }
```
Making reference optional for dose runs prevents needless failures when users omit `reference(0)` while still enforcing a zero baseline when a value is provided.

## 3) `tvmerge.ado` quietly ignores extra exposure() variables beyond the dataset count
**Issue:** The validation only errors when `exposure()` has *fewer* entries than datasets. If the user supplies more exposure names than datasets (e.g., trying to merge two datasets with three exposures listed), the extra names are silently ignored because subsequent code only pulls one exposure per dataset via `word # of \`exposures_raw'`. Real-world merges with copied-and-pasted varlists can therefore drop intended exposures without any warning, yielding incomplete merged data.

**Problematic snippet:**
```stata
    local numsv: word count `start'
    local numst: word count `stop'
    local numexp: word count `exposure'

    if `numsv' != `numds' {
        di as error "Number of start() variables (`numsv') must equal number of datasets (`numds')"
        exit 198
    }
    if `numst' != `numds' {
        di as error "Number of stop() variables (`numst') must equal number of datasets (`numds')"
        exit 198
    }
    if `numexp' < `numds' {
        di as error "Number of exposure() variables (`numexp') must be at least the number of datasets (`numds')"
        exit 198
    }
```

**Suggested replacement:**
```stata
    local numsv: word count `start'
    local numst: word count `stop'
    local numexp: word count `exposure'

    if `numsv' != `numds' {
        di as error "Number of start() variables (`numsv') must equal number of datasets (`numds')"
        exit 198
    }
    if `numst' != `numds' {
        di as error "Number of stop() variables (`numst') must equal number of datasets (`numds')"
        exit 198
    }
    if `numexp' != `numds' {
        di as error "Number of exposure() variables (`numexp') must equal number of datasets (`numds')"
        exit 198
    }
```
This forces a one-to-one mapping between datasets and exposure variables so accidental trailing names no longer disappear silently.

## 4) `tvexpose.ado` silently drops exposure IDs missing from the master dataset
**Issue:** The merge that attaches study entry/exit dates uses `keep(3)`, which retains only exposure records whose IDs match the master dataset. Any exposure IDs absent from the master are discarded without notice—a common real-world situation when a pharmacy or registry file contains patients outside the analytic cohort. Analysts may assume the exposure file fully merged when, in fact, some IDs were filtered away.

**Problematic snippet:**
```stata
    preserve
    quietly use `master_dates', clear
    isid id
    restore
    quietly merge m:1 id using `master_dates', nogen keep(3)
```

**Suggested replacement:**
```stata
    preserve
    quietly use `master_dates', clear
    isid id
    restore
    quietly merge m:1 id using `master_dates', nogen keep(match master)
    quietly count if _merge == 2   // exposure IDs missing in master
    if r(N) {
        noisily di as error "`=r(N)' exposure records dropped: id not found in master dataset"
    }
    keep if _merge == 3            // keep only matched IDs
    drop _merge
```
This keeps the strict matched-only behavior but surfaces a warning when exposure records are discarded because the master lacks those IDs.

## Debugging plan for future passes
To proactively surface issues like the ones above, use a structured sweep each pass:
1) **Interface validation:** Review each `syntax` block against downstream expectations (e.g., option dependencies, defaults). Construct small synthetic calls that intentionally omit or over-specify options to see whether the error handling matches the intended contract.
2) **Data-shape assumptions:** Trace every `merge`, `joinby`, and `frame` operation to confirm cardinality assumptions are enforced. Add temporary `isid` checks and counts around joins when probing for silent row loss or duplication.
3) **Boundary conditions:** Create minimal toy datasets that trigger edge timelines (empty overlap, touching intervals, reversed dates, missing IDs) and run the commands under `set tracedepth 2` to observe where unexpected drops or errors occur.
4) **Cleanup safety:** Inspect teardown code (`drop`, `frame drop`, tempvar clearing) to ensure non-existent targets are guarded with `capture` and that datasets return to a clean state even after errors.
5) **Performance/scale probes:** For batching or iterative merges, run with extremely small and large batch settings on synthetic data to catch division-by-zero, infinite loops, or memory blow-ups.
6) **User messaging:** Whenever data are filtered or assumptions enforced, verify a warning is emitted so analysts are aware of lost rows or coerced values. Use `count` before/after key steps during review to identify silent changes.
