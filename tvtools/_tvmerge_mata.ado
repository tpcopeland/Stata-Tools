*! _tvmerge_mata Version 1.7.2  2026/07/19
*! Mata interval-overlap engine for tvmerge
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (wrapper)

/*
This file contains the compiled interval-overlap engine used by tvmerge to
intersect time-varying intervals within person, replacing the former
joinby/batch() Cartesian-then-filter approach.

The sweep/binary-search engine is adapted from the rangematch package's
interval-overlap backend (_rm_build_pairs_overlap). It is specialised for
tvmerge's needs: an inner join with closed (inclusive) [start, stop] interval
boundaries and zero tolerance, which is exactly equivalent to the old
    new_start = max(start, start_k); new_stop = min(stop, stop_k)
    keep if new_start <= new_stop
logic (two valid intervals overlap iff ulo <= mhi & uhi >= mlo).

Master work frame columns: 1=gid, 2=low, 3=high, 4=obs.
Using  work frame columns: 1=gid, 2=ulo, 3=uhi, 4=obs.
The engine emits master x using pairs (__tvm_mi, __tvm_ui) into the output
frame, where __tvm_mi / __tvm_ui are the original master / using row indices.
Output pairs are streamed, so the full Cartesian product is never materialised.

These functions are called internally by tvmerge and should not be called
directly.

DRIFT GUARD: this overlap logic is a hand-maintained mirror of rangematch's
_rm_build_pairs_overlap (different package, no runtime dependency). The two MUST
stay behaviourally identical for the inner-join, closed-boundary, zero-tolerance
case. qa/test_tvm_overlap_drift_guard.do pins tvm == rangematch == an independent
joinby oracle; if you edit either implementation, run that test.
*/

version 16.0

capture mata: mata drop _tvm_build_pairs_overlap()
capture mata: mata drop _tvm_overlap_count_group()
capture mata: mata drop _tvm_overlap_emit_group()
capture mata: mata drop _tvm_build_pairs_point()
capture mata: mata drop _tvm_bsearch_right()
capture mata: mata drop _tvm_bsearch_first_ge()
capture mata: mata drop _tvm_bsearch_last_lt()

mata:
mata set matastrict on

// ----------------------------------------------------------------------------
// _tvm_bsearch_right(): rightmost index in [lo0, hi0] with keys[idx] <= target
// (returns 0 when none). keys must be sorted ascending within [lo0, hi0].
// ----------------------------------------------------------------------------
real scalar _tvm_bsearch_right(
    real colvector keys,
    real scalar target,
    real scalar lo0,
    real scalar hi0)
{
    real scalar lo, hi, mid, result

    lo = lo0
    hi = hi0
    result = 0
    while (lo <= hi) {
        mid = trunc((lo + hi) / 2)
        if (keys[mid] <= target) {
            result = mid
            lo = mid + 1
        }
        else {
            hi = mid - 1
        }
    }
    return(result)
}

// ----------------------------------------------------------------------------
// Forward-scan sweep over one gid, COUNTING pass. Adds each master's match
// count to cnt_point (master opens first: a point add) or cnt_diff (a using row
// opens first and reports a contiguous RANGE of masters: a difference array).
// Neither branch enumerates pairs, so this pass carries no K term. cnt_diff is
// prefix-summed by the caller; every +1 at i has its -1 at e+1 inside the same
// gid, so the running sum returns to zero at each boundary.
// ----------------------------------------------------------------------------
void _tvm_overlap_count_group(
    real colvector vmlo,
    real colvector vmhi,
    real colvector vulo,
    real colvector vuhi,
    real scalar ms,
    real scalar me,
    real scalar us,
    real scalar ue,
    real colvector cnt_point,
    real colvector cnt_diff)
{
    real scalar i, j, e

    i = ms
    j = us
    while (i <= me & j <= ue) {
        if (vmlo[i] < vulo[j]) {
            e = _tvm_bsearch_right(vulo, vmhi[i], j, ue)
            if (e >= j) cnt_point[i] = cnt_point[i] + (e - j + 1)
            i++
        }
        else {
            e = _tvm_bsearch_right(vmlo, vuhi[j], i, me)
            if (e >= i) {
                cnt_diff[i] = cnt_diff[i] + 1
                cnt_diff[e + 1] = cnt_diff[e + 1] - 1
            }
            j++
        }
    }
}

// ----------------------------------------------------------------------------
// Forward-scan sweep over one gid, EMITTING pass. Same traversal; each reported
// range is walked and one pair written per step. cursor holds, per ORIGINAL
// master row, the next slot reserved for that master, which is what restores
// original row order from a sweep that runs in lower-bound order.
// ----------------------------------------------------------------------------
void _tvm_overlap_emit_group(
    real colvector vmlo,
    real colvector vmhi,
    real colvector vmidx,
    real colvector vulo,
    real colvector vuhi,
    real colvector vuobs,
    real scalar ms,
    real scalar me,
    real scalar us,
    real scalar ue,
    real colvector mobs_all,
    real colvector cursor,
    real colvector mi,
    real colvector ui)
{
    real scalar i, j, e, k, idx, target, slot

    i = ms
    j = us
    while (i <= me & j <= ue) {
        if (vmlo[i] < vulo[j]) {
            e = _tvm_bsearch_right(vulo, vmhi[i], j, ue)
            idx = vmidx[i]
            for (k = j; k <= e; k++) {
                slot = cursor[idx]
                mi[slot] = mobs_all[idx]
                ui[slot] = vuobs[k]
                cursor[idx] = slot + 1
            }
            i++
        }
        else {
            e = _tvm_bsearch_right(vmlo, vuhi[j], i, me)
            target = vuobs[j]
            for (k = i; k <= e; k++) {
                idx = vmidx[k]
                slot = cursor[idx]
                mi[slot] = mobs_all[idx]
                ui[slot] = target
                cursor[idx] = slot + 1
            }
            j++
        }
    }
}

// ----------------------------------------------------------------------------
// _tvm_build_pairs_overlap(): inner-join interval-overlap pair generation.
// Emits master x using pairs where the master interval [mlo, mhi] overlaps the
// using interval [ulo, uhi] under closed (inclusive) boundaries:
//     ulo <= mhi & uhi >= mlo
//
// ALGORITHM: forward-scan plane sweep, per gid, over both sides sorted by lower
// bound -- O((M+U) log U + K), output sensitive. The previous design binary
// searched a candidate prefix on ulo and then LINEARLY RESCANNED that prefix to
// filter on uhi, which is quadratic whenever the prefix is large and the answer
// is not: measured 1.5/5.7/22.6s at 4k/8k/16k rows for ZERO output pairs, a
// fourfold cost per doubling. See the same note in rangematch's
// _rm_build_pairs_overlap() for the full derivation.
//
// The sweep advances whichever side opens next and reports from the other. Each
// branch tests ONE inequality and gets the other free, which is sound only
// because empty intervals are screened out first -- when master i opens first,
// ulo[k] >= ulo[j] > mlo[i], and a nonempty using interval ends at or after it
// starts, so uhi[k] >= mlo[i] without being compared. Scan end points come from
// binary search, so a branch reporting nothing costs O(log U), and every inner
// iteration yields exactly one pair.
//
// Two passes: count each master's matches without enumerating them (a
// binary-searched range width, so no K term and no per-pair memory), then write
// pairs into slots reserved in original master-row order. The sweep visits
// masters in lower-bound order, so that reservation is what preserves the
// emitted order -- pairs grouped by master row, ascending in sorted-using
// position -- which the drift guard's peer implementation also produces.
//
// Writes __tvm_mi / __tvm_ui to out_frame and returns the pair count in the
// caller local _tvm_n_pairs.
// ----------------------------------------------------------------------------
void _tvm_build_pairs_overlap(
    string scalar master_frame,
    string scalar using_frame,
    string scalar out_frame,
    real scalar progress)
{
    string scalar oldframe
    real matrix M, U, Usorted, VM
    real colvector mi, ui, ulo, uhi, uobs, ugid, uvalid, mobs_all
    real colvector gstart_map, gend_map
    real colvector vmgid, vmlo, vmhi, vmidx, vugid, vulo, vuhi, vuobs
    real colvector cnt_point, cnt_diff, counts_all, cursor
    real scalar nm, nu, i, n_pairs
    real scalar g, u, p, pos
    real scalar progress_next, progress_step, progress_pct, progress_last
    real scalar max_gid, gid_i, show
    real scalar nvm, nvu, a, b, us, ue, running

    oldframe = st_framecurrent()

    st_framecurrent(master_frame)
    M = st_data(., .)
    nm = rows(M)

    st_framecurrent(using_frame)
    U = st_data(., .)
    nu = rows(U)

    // Open-ended bounds: missing -> -/+ infinity
    for (u = 1; u <= nu; u++) {
        if (U[u, 2] >= .) U[u, 2] = mindouble()
        if (U[u, 3] >= .) U[u, 3] = maxdouble()
    }
    for (i = 1; i <= nm; i++) {
        if (M[i, 2] >= .) M[i, 2] = mindouble()
        if (M[i, 3] >= .) M[i, 3] = maxdouble()
    }

    // Sort using rows by (gid, ulo, uobs). The trailing uobs (col 4, unique) is
    // a tiebreaker: Mata's sort() does not order equal-key rows reproducibly, so
    // without it the pair order emitted for a master row would vary between
    // runs on identical data. rangematch's copy has always carried it; this one
    // did not, which made the two agree on the pair SET (all the drift guard
    // compares) while disagreeing on order.
    if (nu > 0) {
        Usorted = sort(U, (1, 2, 4))
        ugid = Usorted[., 1]
        ulo  = Usorted[., 2]
        uhi  = Usorted[., 3]
        uobs = Usorted[., 4]
        // An inverted using interval (ulo > uhi) is empty and can never be a
        // genuine overlap. The two cross-interval inequalities below are
        // sufficient only once both intervals are known nonempty, so screen the
        // using side explicitly; the master side is screened at (mlo > mhi)
        // below. This mirrors _rm_interval_nonempty() in rangematch's
        // _rangematch_mata.ado for the closed-boundary case this copy supports
        // (see the drift guard note on _tvm_build_pairs_overlap).
        uvalid = J(nu, 1, 0)
        for (pos = 1; pos <= nu; pos++) {
            uvalid[pos] = (ulo[pos] <= uhi[pos])
        }
    }
    else {
        ugid = J(0, 1, .)
        ulo  = J(0, 1, .)
        uhi  = J(0, 1, .)
        uobs = J(0, 1, .)
        uvalid = J(0, 1, .)
    }

    // Per-gid contiguous [gstart, gend] ranges into the sorted using rows
    max_gid = (nm > 0 ? max(M[., 1]) : 0)
    if (nu > 0) max_gid = max((max_gid, max(ugid)))
    max_gid = (max_gid < . ? trunc(max_gid) : 0)
    if (max_gid > 0) {
        gstart_map = J(max_gid, 1, 0)
        gend_map = J(max_gid, 1, 0)
        for (u = 1; u <= nu; u++) {
            gid_i = trunc(ugid[u])
            if (gid_i >= 1 & gid_i <= max_gid) {
                if (gstart_map[gid_i] == 0) gstart_map[gid_i] = u
                gend_map[gid_i] = u
            }
        }
    }
    else {
        gstart_map = J(0, 1, 0)
        gend_map = J(0, 1, 0)
    }

    // ---- Compact the valid rows into the swept arrays ----------------------
    // The sweep's free half-test is sound only for nonempty intervals, so
    // invalid rows are removed rather than skipped mid-scan. An inverted using
    // row still matches nothing, which is the disposition it had before.
    //
    // gstart_map/gend_map are then REBUILT over the compacted rows, replacing
    // the all-rows version computed above. That is safe only because this
    // inner-join copy has no consumer of the all-rows map; rangematch's copy
    // keeps both, because its stats block reads the all-rows map to decide
    // whether a group had any using rows at all.
    nvu = 0
    for (u = 1; u <= nu; u++) {
        if (uvalid[u]) nvu++
    }
    vugid = J(nvu, 1, .)
    vulo  = J(nvu, 1, .)
    vuhi  = J(nvu, 1, .)
    vuobs = J(nvu, 1, .)
    p = 0
    for (u = 1; u <= nu; u++) {
        if (uvalid[u]) {
            p++
            vugid[p] = ugid[u]
            vulo[p]  = ulo[u]
            vuhi[p]  = uhi[u]
            vuobs[p] = uobs[u]
        }
    }

    // Per-gid ranges into the COMPACTED using rows. Compaction preserves the
    // (gid, ulo, uobs) order, so groups stay contiguous and no re-sort is needed.
    if (max_gid > 0) {
        gstart_map = J(max_gid, 1, 0)
        gend_map = J(max_gid, 1, 0)
        for (u = 1; u <= nvu; u++) {
            gid_i = trunc(vugid[u])
            if (gid_i >= 1 & gid_i <= max_gid) {
                if (gstart_map[gid_i] == 0) gstart_map[gid_i] = u
                gend_map[gid_i] = u
            }
        }
    }

    // Valid master rows sorted by (gid, mlo, orig row). Column 4 carries the
    // original master row index: it makes ties reproducible and is how the emit
    // pass finds its way back to original row order.
    nvm = 0
    for (i = 1; i <= nm; i++) {
        if (!(M[i, 2] > M[i, 3])) nvm++
    }
    VM = J(nvm, 4, .)
    p = 0
    for (i = 1; i <= nm; i++) {
        if (!(M[i, 2] > M[i, 3])) {
            p++
            VM[p, 1] = M[i, 1]
            VM[p, 2] = M[i, 2]
            VM[p, 3] = M[i, 3]
            VM[p, 4] = i
        }
    }
    if (nvm > 0) {
        VM = sort(VM, (1, 2, 4))
        vmgid = VM[., 1]
        vmlo  = VM[., 2]
        vmhi  = VM[., 3]
        vmidx = VM[., 4]
    }
    else {
        vmgid = J(0, 1, .)
        vmlo  = J(0, 1, .)
        vmhi  = J(0, 1, .)
        vmidx = J(0, 1, .)
    }
    VM = J(0, 0, .)

    // ---- Sweep pass 1: how many matches does each master have? -------------
    cnt_point = J(nvm, 1, 0)
    cnt_diff = J(nvm + 1, 1, 0)
    a = 1
    while (a <= nvm) {
        g = vmgid[a]
        b = a
        // Mata's & does not short-circuit, so the bound check cannot be folded
        // into the loop condition alongside vmgid[b+1].
        while (b < nvm) {
            if (vmgid[b + 1] != g) break
            b++
        }
        gid_i = trunc(g)
        us = 0
        ue = -1
        if (gid_i >= 1 & gid_i <= rows(gstart_map)) {
            us = gstart_map[gid_i]
            ue = gend_map[gid_i]
        }
        if (us != 0) {
            _tvm_overlap_count_group(vmlo, vmhi, vulo, vuhi, a, b, us, ue,
                cnt_point, cnt_diff)
        }
        a = b + 1
    }

    counts_all = J(nm, 1, 0)
    running = 0
    for (a = 1; a <= nvm; a++) {
        running = running + cnt_diff[a]
        counts_all[vmidx[a]] = cnt_point[a] + running
    }

    // ---- Reserve slots, walking masters in ORIGINAL row order --------------
    // Inner join: a master with no matches contributes nothing, so the reserved
    // blocks tile the output exactly and it can be sized once, up front.
    n_pairs = 0
    cursor = J(nm, 1, 0)
    show = (progress != 0 & nm > 100000)
    if (show) {
        progress_step = ceil(nm / 10)
        progress_next = progress_step
        progress_last = 0
        printf("{txt}    Matching progress:")
        displayflush()
    }
    for (i = 1; i <= nm; i++) {
        if (counts_all[i] > 0) {
            cursor[i] = n_pairs + 1
            n_pairs = n_pairs + counts_all[i]
        }
        if (show & i >= progress_next) {
            progress_pct = min((100, floor(100 * i / nm)))
            printf(" %g%%", progress_pct)
            displayflush()
            progress_last = progress_pct
            progress_next = progress_next + progress_step
        }
    }
    if (show) {
        if (progress_last < 100) printf(" 100%%")
        printf("\n")
        displayflush()
    }

    // ---- Sweep pass 2: write the pairs into the reserved slots -------------
    mi = J(max((n_pairs, 1)), 1, .)
    ui = J(max((n_pairs, 1)), 1, .)
    if (n_pairs > 0) {
        mobs_all = M[., 4]
        a = 1
        while (a <= nvm) {
            g = vmgid[a]
            b = a
            while (b < nvm) {
                if (vmgid[b + 1] != g) break
                b++
            }
            gid_i = trunc(g)
            us = 0
            ue = -1
            if (gid_i >= 1 & gid_i <= rows(gstart_map)) {
                us = gstart_map[gid_i]
                ue = gend_map[gid_i]
            }
            if (us != 0) {
                _tvm_overlap_emit_group(vmlo, vmhi, vmidx, vulo, vuhi, vuobs,
                    a, b, us, ue, mobs_all, cursor, mi, ui)
            }
            a = b + 1
        }
    }

    // Write pairs to the output frame
    st_framecurrent(out_frame)
    if (n_pairs > 0) st_addobs(n_pairs)
    (void) st_addvar("double", "__tvm_mi")
    (void) st_addvar("double", "__tvm_ui")
    if (n_pairs > 0) {
        st_store(., "__tvm_mi", mi[1..n_pairs])
        st_store(., "__tvm_ui", ui[1..n_pairs])
    }

    st_framecurrent(oldframe)
    st_local("_tvm_n_pairs", strofreal(n_pairs))
}

// ----------------------------------------------------------------------------
// _tvm_bsearch_first_ge(): leftmost index in [lo0, hi0] with keys[idx] >= target
// (returns 0 when none). keys sorted ascending within [lo0, hi0].
// ----------------------------------------------------------------------------
real scalar _tvm_bsearch_first_ge(
    real colvector keys, real scalar target, real scalar lo0, real scalar hi0)
{
    real scalar lo, hi, mid, result

    lo = lo0
    hi = hi0
    result = 0
    while (lo <= hi) {
        mid = trunc((lo + hi) / 2)
        if (keys[mid] >= target) {
            result = mid
            hi = mid - 1
        }
        else {
            lo = mid + 1
        }
    }
    return(result)
}

// ----------------------------------------------------------------------------
// _tvm_bsearch_last_lt(): rightmost index in [lo0, hi0] with keys[idx] < target
// (returns 0 when none). keys sorted ascending within [lo0, hi0].
// ----------------------------------------------------------------------------
real scalar _tvm_bsearch_last_lt(
    real colvector keys, real scalar target, real scalar lo0, real scalar hi0)
{
    real scalar lo, hi, mid, result

    lo = lo0
    hi = hi0
    result = 0
    while (lo <= hi) {
        mid = trunc((lo + hi) / 2)
        if (keys[mid] < target) {
            result = mid
            lo = mid + 1
        }
        else {
            hi = mid - 1
        }
    }
    return(result)
}

// ----------------------------------------------------------------------------
// _tvm_build_pairs_point(): half-open point-in-interval pair generation. Emits
// master-interval x using-point pairs where the point key falls in the master
// interval under the CLOSED-LEFT, OPEN-RIGHT convention:
//     low <= key < high
// which is exactly tvevent's `date >= start & date < stop` split rule, for any
// numeric (not only integer) dates. Missing master low -> -inf, missing high ->
// +inf, missing point key never matches (dropped). With keep_unmatched_master,
// master intervals with no point are emitted once with __tvm_ui = . (mirrors
// joinby ... , unmatched(master)).
//
// Master work frame columns: 1=gid, 2=low, 3=high, 4=obs.
// Using  work frame columns: 1=gid, 2=key, 3=obs.
// Emits __tvm_mi (master obs) / __tvm_ui (point obs) into out_frame; pair count
// in the caller local _tvm_n_pairs.
// ----------------------------------------------------------------------------
void _tvm_build_pairs_point(
    string scalar master_frame,
    string scalar using_frame,
    string scalar out_frame,
    real scalar keep_unmatched_master)
{
    string scalar oldframe
    real matrix M, U, Usorted
    real colvector mi, ui, ukeys, uobs, ugid, perm
    real colvector gstart_map, gend_map
    real scalar nm, nu, i, lo, hi, mobs, g, gid_i, gstart, gend
    real scalar jlo, jhi, nmatch, n_pairs, outcap, needed, pos, max_gid, u

    oldframe = st_framecurrent()
    keep_unmatched_master = (keep_unmatched_master != 0)

    st_framecurrent(master_frame)
    M = st_data(., .)
    nm = rows(M)

    st_framecurrent(using_frame)
    U = st_data(., .)
    nu = rows(U)

    // Drop points with missing key (never match)
    if (nu > 0) {
        perm = selectindex(U[., 2] :< .)
        if (length(perm) < nu) {
            U = U[perm, .]
            nu = rows(U)
        }
    }
    // Open-ended master bounds
    for (i = 1; i <= nm; i++) {
        if (M[i, 2] >= .) M[i, 2] = mindouble()
        if (M[i, 3] >= .) M[i, 3] = maxdouble()
    }

    if (nu > 0) {
        // Tiebreak on the unique obs column (3) for symmetry with the overlap
        // engine's (1,2,4) sort, so the two engines agree on emit order (F10a).
        Usorted = sort(U, (1, 2, 3))
        ugid  = Usorted[., 1]
        ukeys = Usorted[., 2]
        uobs  = Usorted[., 3]
    }
    else {
        ugid = J(0, 1, .)
        ukeys = J(0, 1, .)
        uobs = J(0, 1, .)
    }

    max_gid = (nm > 0 ? max(M[., 1]) : 0)
    if (nu > 0) max_gid = max((max_gid, max(ugid)))
    max_gid = (max_gid < . ? trunc(max_gid) : 0)
    if (max_gid > 0) {
        gstart_map = J(max_gid, 1, 0)
        gend_map = J(max_gid, 1, 0)
        for (u = 1; u <= nu; u++) {
            gid_i = trunc(ugid[u])
            if (gid_i >= 1 & gid_i <= max_gid) {
                if (gstart_map[gid_i] == 0) gstart_map[gid_i] = u
                gend_map[gid_i] = u
            }
        }
    }
    else {
        gstart_map = J(0, 1, 0)
        gend_map = J(0, 1, 0)
    }

    n_pairs = 0
    outcap = max((nm, 1024))
    mi = J(outcap, 1, .)
    ui = J(outcap, 1, .)

    for (i = 1; i <= nm; i++) {
        g    = M[i, 1]
        lo   = M[i, 2]
        hi   = M[i, 3]
        mobs = M[i, 4]

        nmatch = 0
        jlo = 0
        jhi = -1
        if (!(lo > hi)) {
            gid_i = trunc(g)
            gstart = 0
            gend = -1
            if (gid_i >= 1 & gid_i <= rows(gstart_map)) {
                gstart = gstart_map[gid_i]
                gend = gend_map[gid_i]
            }
            if (gstart != 0) {
                jlo = _tvm_bsearch_first_ge(ukeys, lo, gstart, gend)
                jhi = _tvm_bsearch_last_lt(ukeys, hi, gstart, gend)
                if (jlo != 0 & jhi != 0 & jlo <= jhi) nmatch = jhi - jlo + 1
                else nmatch = 0
            }
        }

        if (nmatch == 0) {
            if (keep_unmatched_master) {
                n_pairs++
                if (n_pairs > rows(mi)) {
                    mi = mi \ J(rows(mi), 1, .)
                    ui = ui \ J(rows(ui), 1, .)
                }
                mi[n_pairs] = mobs
                ui[n_pairs] = .
            }
        }
        else {
            needed = n_pairs + nmatch
            while (needed > rows(mi)) {
                mi = mi \ J(rows(mi), 1, .)
                ui = ui \ J(rows(ui), 1, .)
            }
            for (pos = jlo; pos <= jhi; pos++) {
                n_pairs++
                mi[n_pairs] = mobs
                ui[n_pairs] = uobs[pos]
            }
        }
    }

    st_framecurrent(out_frame)
    if (n_pairs > 0) st_addobs(n_pairs)
    (void) st_addvar("double", "__tvm_mi")
    (void) st_addvar("double", "__tvm_ui")
    if (n_pairs > 0) {
        st_store(., "__tvm_mi", mi[1..n_pairs])
        st_store(., "__tvm_ui", ui[1..n_pairs])
    }

    st_framecurrent(oldframe)
    st_local("_tvm_n_pairs", strofreal(n_pairs))
}
end

********************************************************************************
* ADO WRAPPER PROGRAM
********************************************************************************

// Run the interval-overlap sweep over two work frames.
// Usage: _tvmerge_overlap_pairs master_frame using_frame out_frame [, progress(0|1)]
//   master_frame cols: gid low  high obs
//   using_frame  cols: gid ulow uhigh obs
//   out_frame    receives __tvm_mi / __tvm_ui pair columns
// Returns: r(n_pairs)
capture program drop _tvmerge_overlap_pairs
program define _tvmerge_overlap_pairs, rclass
    version 16.0
    syntax namelist(min=3 max=3) [, PROGRESS(integer 0)]

    gettoken mf   rest : namelist
    gettoken uf   rest : rest
    gettoken outf rest : rest

    mata: _tvm_build_pairs_overlap("`mf'", "`uf'", "`outf'", `progress')

    return scalar n_pairs = `_tvm_n_pairs'
end

// Run the half-open point-in-interval sweep over two work frames.
// Usage: _tvmerge_point_pairs master_frame using_frame out_frame [, unmatched]
//   master_frame cols: gid low high obs   (intervals, matched [low, high) )
//   using_frame  cols: gid key obs        (points)
//   unmatched : also emit intervals with no point (mirrors joinby unmatched(master))
//   out_frame receives __tvm_mi (interval obs) / __tvm_ui (point obs)
// Returns: r(n_pairs)
capture program drop _tvmerge_point_pairs
program define _tvmerge_point_pairs, rclass
    version 16.0
    syntax namelist(min=3 max=3) [, UNMATCHed]

    gettoken mf   rest : namelist
    gettoken uf   rest : rest
    gettoken outf rest : rest

    local keepunm = ("`unmatched'" != "")
    mata: _tvm_build_pairs_point("`mf'", "`uf'", "`outf'", `keepunm')

    return scalar n_pairs = `_tvm_n_pairs'
end
