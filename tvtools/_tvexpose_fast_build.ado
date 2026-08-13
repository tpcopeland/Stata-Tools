*! _tvexpose_fast_build Version 1.16.0  2026/08/13
*! Build the complete categorical person-time tiling in one in-memory pass
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Fast categorical constructor for tvexpose.
*
* Consumes the CLEANED episode data already in memory -- validated, merged
* against the master windows, and clipped to [study_entry, study_exit] -- plus
* the per-person master file, and leaves behind the complete tiling that the
* released engine produces by appending four separately built tempfiles.
*
* What it replaces, and why that is the part worth replacing: the released
* categorical path writes and re-reads the working dataset roughly sixteen
* times between clipping and the finished tiling -- gap discovery, the
* earliest-episode extraction, the baseline file, the post-exposure file, the
* append, and two m:1 re-merges of the master windows, each round-tripping
* through a tempfile and several sorts. None of that is arithmetic. Removing
* a warm-cache read buys nothing (Phase 1 measured exactly that), but removing
* sixteen full-dataset serialisations and two merges is removing an algorithm.
*
* The construction itself is one observation:
*
*   EVERY output reference row is the interval PRECEDING something.
*
*   - the baseline row precedes a person's first episode;
*   - a gap row precedes the next episode;
*   - the post-exposure row precedes the end of the window;
*   - a person with no episode at all has exactly one such interval, from
*     entry to exit.
*
* So each episode row contributes an optional preceding reference interval
* plus itself, and one appended per-person marker row contributes the
* trailing interval. Both are the same computation -- [previous stop + 1,
* this row's lower bound - 1] -- which is why there is a single `expand'
* rather than four constructed files.
*
* Preconditions the caller owns (tvexpose checks all of them before calling):
*   - the default categorical mode with no geometry-rewriting option;
*   - whole-number category codes, none equal to reference();
*   - no within-person overlap of any kind after clipping.
* This program re-asserts the structural ones it can see, and errors rather
* than emitting a tiling it cannot justify.
*
* Returns:
*   r(N_rows)     output rows built
*   r(N_persons)  persons represented

program define _tvexpose_fast_build, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , REFerence(string) MASTERfile(string)

    * --- preconditions -------------------------------------------------
    foreach v in id exp_start exp_stop exp_value {
        capture confirm variable `v', exact
        if _rc {
            noisily display as error ///
                "_tvexpose_fast_build: `v' not found in the episode data"
            exit 111
        }
    }
    capture confirm file "`masterfile'"
    if _rc {
        noisily display as error ///
            "_tvexpose_fast_build: master window file not found"
        exit 601
    }

    local _n_epi = _N
    if `_n_epi' > 0 {
        quietly count if missing(exp_start) | missing(exp_stop) | missing(exp_value)
        if r(N) > 0 {
            noisily display as error ///
                "_tvexpose_fast_build: `r(N)' episode row(s) carry a missing bound or category"
            exit 498
        }
        quietly count if exp_start > exp_stop
        if r(N) > 0 {
            noisily display as error ///
                "_tvexpose_fast_build: `r(N)' episode row(s) have start after stop"
            exit 498
        }
    }

    * --- coalesce abutting same-category episodes ----------------------
    * The released engine reaches this by default and it is easy to miss. With
    * no explicit overlap option, tvexpose falls through to layer resolution,
    * and the layer kernel extends its previous output row whenever the next
    * boundary segment abuts it and carries the same category. Two episodes
    * that merely touch -- [a,b] and [b+1,c] with equal codes -- therefore
    * leave the released command as ONE row, not two, even under merge(0),
    * whose own condition (next start - stop <= 0) does not fire on abutment.
    *
    * Section 11.2 item 6 of the single-pass plan states the opposite ("emit
    * each clipped episode row without collapsing adjacent equal categories").
    * The plan loses: Section 2's authority order puts executed QA and the
    * shipped source above it, and baseline case E10_adjacent_and_gap records
    * the released answer.
    *
    * Runs collapse transitively, exactly as the kernel's repeated extension
    * does: [1,10] [11,20] [21,30] with one category become [1,30].
    if `_n_epi' > 0 {
        tempvar newrun run runstop
        sort id exp_start exp_stop
        quietly by id: generate byte `newrun' = (_n == 1) | ///
            (exp_start != exp_stop[_n-1] + 1) | (exp_value != exp_value[_n-1])
        quietly by id: generate long `run' = sum(`newrun')
        sort id `run' exp_start
        * Read the run's closing bound into its own column before writing it
        * back: replacing exp_stop while still subscripting exp_stop would
        * make the result depend on the order Stata happens to visit rows in.
        quietly by id `run': generate double `runstop' = exp_stop[_N]
        quietly replace exp_stop = `runstop'
        quietly by id `run': keep if _n == 1
        drop `newrun' `run' `runstop'
        local _n_epi = _N
    }

    * --- build ---------------------------------------------------------
    tempvar mk k pres pree emit nrows orow slot

    * One marker row per person, appended after the episodes. It carries the
    * study window and nothing else; its lower bound for the "preceding
    * interval" computation is the window's own exit.
    quietly generate byte `mk' = 0
    quietly append using "`masterfile'"
    quietly replace `mk' = 1 if missing(`mk')

    quietly count if `mk' == 1
    local _n_persons = r(N)
    if `_n_persons' == 0 {
        noisily display as error ///
            "_tvexpose_fast_build: the master window file contributed no persons"
        exit 2000
    }
    quietly count if `mk' == 1 & (missing(study_entry) | missing(study_exit))
    if r(N) > 0 {
        noisily display as error ///
            "_tvexpose_fast_build: `r(N)' person(s) carry a missing study bound"
        exit 498
    }

    * The released path promotes these columns by appending double-typed gap,
    * baseline, and post-exposure files, and relies on the closing `compress'
    * to size them again. Promote them here for the same reason: a study bound
    * held in a wider type than the episode bound would otherwise overflow the
    * replace below with r(109). compress at the end of tvexpose restores the
    * released storage types.
    quietly recast double exp_start
    quietly recast double exp_stop
    quietly recast double exp_value

    * Episodes first, ascending, then the person's marker row. Missing sorts
    * last in Stata, but the sort keys `mk' first so the ordering does not
    * depend on that.
    sort id `mk' exp_start exp_stop
    quietly by id: generate long `k' = _n

    * The interval preceding this row: the window's start for the first row
    * of a person, otherwise the day after the previous row's stop. The upper
    * bound is the day before this episode starts, or the window's exit for a
    * marker row.
    quietly by id: generate double `pres' = ///
        cond(`k' == 1, study_entry, exp_stop[_n-1] + 1)
    quietly generate double `pree' = cond(`mk' == 1, study_exit, exp_start - 1)

    * A preceding reference interval exists only when it is non-empty. This
    * is the rule that must NOT collapse adjacent episodes: two episodes that
    * abut leave pres == pree + 1 and emit nothing, while a positive gap of
    * even one day emits a row.
    quietly generate byte `emit' = !missing(`pres', `pree') & `pree' >= `pres'

    * Rows this observation contributes: an episode always contributes itself
    * and may prepend a reference row; a marker row contributes only the
    * trailing reference row, if there is one.
    quietly generate byte `nrows' = cond(`mk' == 1, `emit', 1 + `emit')

    * expand does NOT delete observations whose count is zero -- it keeps one
    * copy -- so the empty marker rows have to be dropped explicitly. Doing
    * this the other way round silently doubles every person's trailing row
    * for people whose last episode already reaches their exit date.
    quietly drop if `nrows' == 0

    quietly generate long `orow' = _n
    quietly expand `nrows'
    sort `orow'
    quietly by `orow': generate byte `slot' = _n

    quietly replace exp_start = `pres'      if `slot' == 1 & `emit' == 1
    quietly replace exp_stop  = `pree'      if `slot' == 1 & `emit' == 1
    quietly replace exp_value = `reference' if `slot' == 1 & `emit' == 1

    drop `mk' `k' `pres' `pree' `emit' `nrows' `orow' `slot'

    * --- postconditions ------------------------------------------------
    * The caller runs the full union-coverage and row-time invariants later,
    * on the finished output. These are the cheap structural ones that
    * localise a defect to this program rather than to the finalisation
    * block a thousand lines away.
    quietly count if missing(exp_start) | missing(exp_stop) | missing(exp_value)
    if r(N) > 0 {
        noisily display as error ///
            "_tvexpose_fast_build: emitted `r(N)' row(s) with a missing bound or category"
        exit 498
    }
    quietly count if exp_start > exp_stop
    if r(N) > 0 {
        noisily display as error ///
            "_tvexpose_fast_build: emitted `r(N)' row(s) with start after stop"
        exit 498
    }

    sort id exp_start exp_stop exp_value

    local _n_out = _N
    return scalar N_rows = `_n_out'
    return scalar N_persons = `_n_persons'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
