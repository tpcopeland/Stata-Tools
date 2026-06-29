*! _tvmerge_mata Version 1.6.1  2026/06/29
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
*/

version 16.0

capture mata: mata drop _tvm_build_pairs_overlap()
capture mata: mata drop _tvm_bsearch_right()

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
// _tvm_build_pairs_overlap(): inner-join interval-overlap pair generation.
// Emits master x using pairs where the master interval [mlo, mhi] overlaps the
// using interval [ulo, uhi] under closed (inclusive) boundaries:
//     ulo <= mhi & uhi >= mlo
// Using rows are sorted by (gid, ulo); for each master interval a binary search
// bounds the candidate prefix on ulo and a linear scan filters on uhi.
// Complexity O(M log U + scan); near O(M log U + K) for selective by-person
// intervals. Writes __tvm_mi / __tvm_ui to out_frame and returns the pair count
// in the caller local _tvm_n_pairs.
// ----------------------------------------------------------------------------
void _tvm_build_pairs_overlap(
    string scalar master_frame,
    string scalar using_frame,
    string scalar out_frame,
    real scalar progress)
{
    string scalar oldframe
    real matrix M, U, Usorted
    real colvector mi, ui, ulo, uhi, uobs, ugid
    real colvector gstart_map, gend_map
    real scalar nm, nu, i, mlo, mhi, n_pairs
    real scalar gstart, gend, mobs, g, outcap, nmatch, u, pos, p, needed
    real scalar progress_next, progress_step, progress_pct, progress_last
    real scalar max_gid, gid_i, show

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

    // Sort using rows by (gid, ulo)
    if (nu > 0) {
        Usorted = sort(U, (1, 2))
        ugid = Usorted[., 1]
        ulo  = Usorted[., 2]
        uhi  = Usorted[., 3]
        uobs = Usorted[., 4]
    }
    else {
        ugid = J(0, 1, .)
        ulo  = J(0, 1, .)
        uhi  = J(0, 1, .)
        uobs = J(0, 1, .)
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

    n_pairs = 0
    show = (progress != 0 & nm > 100000)
    if (show) {
        progress_step = ceil(nm / 10)
        progress_next = progress_step
        progress_last = 0
        printf("{txt}    Matching progress:")
        displayflush()
    }

    outcap = max((nm, 1024))
    mi = J(outcap, 1, .)
    ui = J(outcap, 1, .)

    for (i = 1; i <= nm; i++) {
        g    = M[i, 1]
        mlo  = M[i, 2]
        mhi  = M[i, 3]
        mobs = M[i, 4]

        nmatch = 0
        gstart = 0
        gend = -1
        p = 0
        if (!(mlo > mhi)) {
            gid_i = trunc(g)
            if (gid_i >= 1 & gid_i <= rows(gstart_map)) {
                gstart = gstart_map[gid_i]
                gend = gend_map[gid_i]
            }
            if (gstart != 0) {
                // Candidate prefix: ulo <= mhi (closed/inclusive)
                p = _tvm_bsearch_right(ulo, mhi, gstart, gend)
                if (p != 0 & p >= gstart) {
                    for (pos = gstart; pos <= p; pos++) {
                        if (uhi[pos] >= mlo) nmatch++
                    }
                }
            }
        }

        if (nmatch > 0) {
            needed = n_pairs + nmatch
            while (needed > rows(mi)) {
                mi = mi \ J(rows(mi), 1, .)
                ui = ui \ J(rows(ui), 1, .)
            }
            for (pos = gstart; pos <= p; pos++) {
                if (uhi[pos] >= mlo) {
                    n_pairs++
                    mi[n_pairs] = mobs
                    ui[n_pairs] = uobs[pos]
                }
            }
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
