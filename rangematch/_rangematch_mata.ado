*! _rangematch_mata Version 1.0.1  2026/05/13
*! Mata backend for rangematch: binary-search pair generation and output materialization
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.1

capture mata: mata drop _rm_build_pairs()
capture mata: mata drop _rm_build_pairs_sweep()
capture mata: mata drop _rm_prepare_sweep_master()
capture mata: mata drop _rm_mata_version()
capture mata: mata drop _rm_bsearch_left()
capture mata: mata drop _rm_bsearch_right()
capture mata: mata drop _rm_bsearch_first_gt()
capture mata: mata drop _rm_bsearch_last_lt()
capture mata: mata drop _rm_key_block_uobs()
capture mata: mata drop _rm_materialize()
capture mata: mata drop _rm_fill_using_only()
capture mata: mata drop _rm_generate_distance()
capture mata: mata drop _rm_copy_output()

mata: mata set matastrict on
mata:

string scalar _rm_mata_version()
{
    return("1.0.1")
}

void _rm_prepare_sweep_master(
    string scalar master_frame,
    real scalar sort_allowed
)
{
    string scalar oldframe
    real matrix M
    real scalar nm, i, gid_i, last_gid, last_lo, last_hi
    real scalar ready, sorted, lo_ready, hi_ready, sweep_mode

    oldframe = st_framecurrent()
    sort_allowed = (sort_allowed != 0)
    ready = 1
    sorted = 0
    lo_ready = 1
    hi_ready = 1
    sweep_mode = 2

    st_framecurrent(master_frame)
    M = st_data(., .)
    nm = rows(M)

    for (i = 1; i <= nm; i++) {
        if (M[i, 2] >= .) M[i, 2] = mindouble()
        if (M[i, 3] >= .) M[i, 3] = maxdouble()
    }

    last_gid = .
    last_lo = .
    last_hi = .
    for (i = 1; i <= nm; i++) {
        gid_i = trunc(M[i, 1])
        if (i > 1) {
            if (gid_i < last_gid) {
                lo_ready = 0
                hi_ready = 0
                break
            }
            if (gid_i == last_gid) {
                if (M[i, 2] < last_lo) lo_ready = 0
                if (M[i, 3] < last_hi) hi_ready = 0
            }
        }
        last_gid = gid_i
        last_lo = M[i, 2]
        last_hi = M[i, 3]
    }
    ready = lo_ready
    sweep_mode = (hi_ready ? 2 : 1)

    if (!ready & sort_allowed) {
        M = sort(M, (1, 2, 3, 4))
        ready = 1
        sorted = 1
        lo_ready = 1
        hi_ready = 1
        last_gid = .
        last_lo = .
        last_hi = .
        for (i = 1; i <= nm; i++) {
            gid_i = trunc(M[i, 1])
            if (i > 1) {
                if (gid_i < last_gid) {
                    lo_ready = 0
                    hi_ready = 0
                    break
                }
                if (gid_i == last_gid) {
                    if (M[i, 2] < last_lo) lo_ready = 0
                    if (M[i, 3] < last_hi) hi_ready = 0
                }
            }
            last_gid = gid_i
            last_lo = M[i, 2]
            last_hi = M[i, 3]
        }
        ready = lo_ready
        sweep_mode = (hi_ready ? 2 : 1)
        if (ready & nm > 0) {
            st_store(., (1..cols(M)), M)
        }
        else {
            sorted = 0
        }
    }

    st_framecurrent(oldframe)
    st_local("_rm_sweep_ready", strofreal(ready))
    st_local("_rm_sweep_sorted", strofreal(sorted))
    st_local("_rm_sweep_mode", strofreal(sweep_mode))
}

void _rm_build_pairs_sweep(
    string scalar master_frame,
    string scalar using_frame,
    string scalar out_frame,
    real scalar keep_unmatched_master,
    real scalar keep_unmatched_using,
    real scalar maxpairs,
    real scalar closed_code,
    real scalar tolerance,
    real scalar dryrun,
    real scalar progress,
    real scalar compute_stats,
    real scalar assert_match,
    real scalar assert_using,
    real scalar sweep_mode
)
{
    string scalar oldframe
    real matrix M, U, Usorted
    real colvector mi, ui, perm, ukeys, uobs, ugid, match_counts
    real colvector gstart_map, gend_map
    real colvector matched_using, sorted_counts, seen_master
    real scalar nm, nu, i, pos, n_pairs, nmatch, cap, needed
    real scalar lo, hi, lo_search, hi_search, mobs, g, gid_i
    real scalar max_gid, u, target, n_matched_pairs, n_matched_master
    real scalar n_unmatched_master, n_matched_using, n_unmatched_using
    real scalar gstart, gend, cur_gid, left, right
    real scalar progress_next, progress_step
    real scalar progress_pct, progress_last
    real scalar nu_all, track_using, max_matches, mean_matches
    real scalar median_matches, p50_matches, p90_matches, p99_matches
    real scalar p90_pos, p99_pos, n_empty_groups, n_master_groups
    real scalar right_sweep, jhi

    oldframe = st_framecurrent()
    keep_unmatched_using = (keep_unmatched_using != 0)
    compute_stats = (compute_stats != 0)
    assert_match = (assert_match != 0)
    assert_using = (assert_using != 0)
    track_using = (compute_stats | assert_using | keep_unmatched_using)

    st_framecurrent(master_frame)
    M = st_data(., .)
    nm = rows(M)

    st_framecurrent(using_frame)
    U = st_data(., .)
    nu = rows(U)
    nu_all = nu
    matched_using = (track_using ? J(nu_all, 1, 0) : J(0, 1, 0))

    if (nu > 0) {
        perm = selectindex(U[., 2] :< .)
        if (length(perm) < nu) {
            U = U[perm, .]
            nu = rows(U)
        }
    }

    if (nu > 0) {
        Usorted = sort(U, (1, 2))
        ugid  = Usorted[., 1]
        ukeys = Usorted[., 2]
        uobs  = Usorted[., 3]
    }
    else {
        ugid  = J(0, 1, .)
        ukeys = J(0, 1, .)
        uobs  = J(0, 1, .)
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

    right_sweep = (sweep_mode == 2)

    n_pairs = 0
    n_matched_pairs = 0
    n_matched_master = 0
    match_counts = (compute_stats ? J(nm, 1, 0) : J(0, 1, 0))
    progress = (progress != 0 & nm > 100000)
    if (progress) {
        progress_step = ceil(nm / 10)
        progress_next = progress_step
        progress_last = 0
        printf("{txt}    Matching progress:")
    }
    if (!dryrun) {
        cap = max((nm, 1024))
        mi = J(cap, 1, .)
        ui = J(cap, 1, .)
    }

    cur_gid = .
    gstart = 0
    gend = -1
    left = 0
    right = 0

    for (i = 1; i <= nm; i++) {
        g = M[i, 1]
        gid_i = trunc(g)
        lo = (M[i, 2] >= . ? mindouble() : M[i, 2])
        hi = (M[i, 3] >= . ? maxdouble() : M[i, 3])
        lo_search = lo - tolerance
        hi_search = hi + tolerance
        mobs = M[i, 4]

        if (gid_i != cur_gid) {
            cur_gid = gid_i
            gstart = 0
            gend = -1
            if (gid_i >= 1 & gid_i <= rows(gstart_map)) {
                gstart = gstart_map[gid_i]
                gend = gend_map[gid_i]
            }
            left = gstart
            right = gstart
        }

        nmatch = 0
        if (!(lo > hi | gstart == 0)) {
            if (closed_code == 1 | closed_code == 2) {
                while (left <= gend) {
                    if (ukeys[left] >= lo_search) break
                    left++
                }
            }
            else {
                while (left <= gend) {
                    if (ukeys[left] > lo_search) break
                    left++
                }
            }
            if (right_sweep) {
                if (right < left) right = left
                if (closed_code == 1 | closed_code == 3) {
                    while (right <= gend) {
                        if (ukeys[right] > hi_search) break
                        right++
                    }
                }
                else {
                    while (right <= gend) {
                        if (ukeys[right] >= hi_search) break
                        right++
                    }
                }
            }
            else {
                if (closed_code == 1 | closed_code == 3) {
                    jhi = _rm_bsearch_right(ukeys, hi_search, gstart, gend)
                }
                else {
                    jhi = _rm_bsearch_last_lt(ukeys, hi_search, gstart, gend)
                }
                if (jhi == 0 | jhi < left) right = left
                else right = jhi + 1
            }
            nmatch = right - left
            if (nmatch < 0) nmatch = 0
        }

        if (nmatch == 0) {
            if (keep_unmatched_master) {
                n_pairs++
                if (!dryrun) {
                    if (n_pairs > rows(mi)) {
                        mi = mi \ J(rows(mi), 1, .)
                        ui = ui \ J(rows(ui), 1, .)
                    }
                    mi[n_pairs] = mobs
                    ui[n_pairs] = .
                }
            }
        }
        else {
            if (maxpairs > 0 & (n_pairs + nmatch) > maxpairs) {
                st_framecurrent(oldframe)
                st_local("_rm_err_maxpairs", "1")
                st_local("_rm_n_pairs", strofreal(n_pairs + nmatch))
                return
            }

            n_matched_pairs = n_matched_pairs + nmatch
            n_matched_master++
            if (compute_stats) match_counts[i] = nmatch
            if (!dryrun) {
                needed = n_pairs + nmatch
                while (needed > rows(mi)) {
                    mi = mi \ J(rows(mi), 1, .)
                    ui = ui \ J(rows(ui), 1, .)
                }
            }
            for (pos = left; pos < right; pos++) {
                target = uobs[pos]
                if (track_using) matched_using[target] = 1
                n_pairs++
                if (!dryrun) {
                    mi[n_pairs] = mobs
                    ui[n_pairs] = target
                }
            }
        }

        if (progress & i >= progress_next) {
            progress_pct = min((100, floor(100 * i / nm)))
            printf(" %g%%", progress_pct)
            progress_last = progress_pct
            progress_next = progress_next + progress_step
        }
    }
    if (progress) {
        if (progress_last < 100) printf(" 100%%")
        printf("\n")
    }

    n_unmatched_master = (compute_stats | assert_match ? nm - n_matched_master : .)
    if (track_using) {
        n_matched_using = (nu_all > 0 ? sum(matched_using :== 1) : 0)
        n_unmatched_using = (nu_all > 0 ? sum(matched_using :== 0) : 0)
    }
    else {
        n_matched_using = .
        n_unmatched_using = .
    }

    if (keep_unmatched_using & n_unmatched_using > 0) {
        if (maxpairs > 0 & (n_pairs + n_unmatched_using) > maxpairs) {
            st_framecurrent(oldframe)
            st_local("_rm_err_maxpairs", "1")
            st_local("_rm_n_pairs", strofreal(n_pairs + n_unmatched_using))
            return
        }
        for (u = 1; u <= nu_all; u++) {
            if (matched_using[u] == 0) {
                n_pairs++
                if (!dryrun) {
                    if (n_pairs > rows(mi)) {
                        mi = mi \ J(rows(mi), 1, .)
                        ui = ui \ J(rows(ui), 1, .)
                    }
                    mi[n_pairs] = .
                    ui[n_pairs] = u
                }
            }
        }
    }

    if (compute_stats) {
        max_matches = (nm > 0 ? max(match_counts) : 0)
        mean_matches = (nm > 0 ? mean(match_counts) : 0)
        if (nm > 0) {
            sorted_counts = sort(match_counts, 1)
            if (mod(nm, 2) == 1) {
                median_matches = sorted_counts[(nm + 1) / 2]
            }
            else {
                median_matches = (sorted_counts[nm / 2] +
                    sorted_counts[(nm / 2) + 1]) / 2
            }
            p50_matches = median_matches
            p90_pos = ceil(.90 * nm)
            p99_pos = ceil(.99 * nm)
            p90_matches = sorted_counts[p90_pos]
            p99_matches = sorted_counts[p99_pos]
        }
        else {
            median_matches = 0
            p50_matches = 0
            p90_matches = 0
            p99_matches = 0
        }
        n_empty_groups = 0
        n_master_groups = 0
        if (nm > 0 & max_gid > 0) {
            seen_master = J(max_gid, 1, 0)
            for (i = 1; i <= nm; i++) {
                gid_i = trunc(M[i, 1])
                if (gid_i >= 1 & gid_i <= max_gid) {
                    if (seen_master[gid_i] == 0) {
                        seen_master[gid_i] = 1
                        n_master_groups++
                        if (gid_i > rows(gstart_map) | gstart_map[gid_i] == 0) {
                            n_empty_groups++
                        }
                    }
                }
            }
        }
    }
    else {
        max_matches = .
        mean_matches = .
        median_matches = .
        p50_matches = .
        p90_matches = .
        p99_matches = .
        n_empty_groups = .
        n_master_groups = .
    }

    if (!dryrun) {
        st_framecurrent(out_frame)
        if (n_pairs > 0) {
            st_addobs(n_pairs)
        }
        (void) st_addvar("double", "__rm_mi")
        (void) st_addvar("double", "__rm_ui")
        if (n_pairs > 0) {
            st_store(., "__rm_mi", mi[1..n_pairs])
            st_store(., "__rm_ui", ui[1..n_pairs])
        }
    }

    st_framecurrent(oldframe)
    st_local("_rm_n_pairs", strofreal(n_pairs))
    st_local("_rm_n_matched_pairs", strofreal(n_matched_pairs))
    st_local("_rm_n_matched_master", strofreal(n_matched_master))
    st_local("_rm_n_matched_using", strofreal(n_matched_using))
    st_local("_rm_n_unmatched_master", strofreal(n_unmatched_master))
    st_local("_rm_n_unmatched_using", strofreal(n_unmatched_using))
    st_local("_rm_max_matches", strofreal(max_matches))
    st_local("_rm_mean_matches", strofreal(mean_matches, "%21.17g"))
    st_local("_rm_median_matches", strofreal(median_matches, "%21.17g"))
    st_local("_rm_p50_matches", strofreal(p50_matches, "%21.17g"))
    st_local("_rm_p90_matches", strofreal(p90_matches, "%21.17g"))
    st_local("_rm_p99_matches", strofreal(p99_matches, "%21.17g"))
    st_local("_rm_n_empty_groups", strofreal(n_empty_groups))
    st_local("_rm_n_master_groups", strofreal(n_master_groups))
    st_local("_rm_err_maxpairs", "0")
}

void _rm_build_pairs(
    string scalar master_frame,
    string scalar using_frame,
    string scalar out_frame,
    real scalar keep_unmatched_master,
    real scalar keep_unmatched_using,
    real scalar maxpairs,
    real scalar closed_code,
    real scalar nearest_code,
    real scalar ties_code,
    real scalar tolerance,
    real scalar dryrun,
    real scalar progress,
    real scalar compute_stats,
    real scalar assert_match,
    real scalar assert_using
)
{
    string scalar oldframe
    real matrix M, U, Usorted
    real colvector mi, ui, perm, ukeys, uobs, ugid, match_counts
    real colvector gstart_map, gend_map
    real colvector selected, allties, matched_using, sorted_counts, seen_master
    real scalar nm, nu, nu_all, i, lo, hi, jlo, jhi, kk, n_pairs
    real scalar gstart, gend, mobs, g, cap, nmatch, u
    real scalar mkey, before_pos, after_pos, before_dist, after_dist
    real scalar n_matched_pairs, n_matched_master, max_matches, mean_matches
    real scalar n_empty_groups, n_unmatched_master, n_matched_using
    real scalar n_unmatched_using, median_matches, p50_matches
    real scalar p90_matches, p99_matches, p90_pos, p99_pos
    real scalar n_master_groups, progress_next, progress_step, progress_pct
    real scalar progress_last, lo_search, hi_search
    real scalar max_gid, gid_i, pos, target, needed
    real scalar track_using

    oldframe = st_framecurrent()
    compute_stats = (compute_stats != 0)
    assert_match = (assert_match != 0)
    assert_using = (assert_using != 0)
    track_using = (compute_stats | assert_using | keep_unmatched_using)

    st_framecurrent(master_frame)
    M = st_data(., .)
    nm = rows(M)

    st_framecurrent(using_frame)
    U = st_data(., .)
    nu = rows(U)
    nu_all = nu
    matched_using = (track_using ? J(nu_all, 1, 0) : J(0, 1, 0))

    // Drop using rows with missing key
    if (nu > 0) {
        perm = selectindex(U[., 2] :< .)
        if (length(perm) < nu) {
            U = U[perm, .]
            nu = rows(U)
        }
    }

    // Replace missing bounds
    for (i = 1; i <= nm; i++) {
        if (M[i, 2] >= .) M[i, 2] = mindouble()
        if (M[i, 3] >= .) M[i, 3] = maxdouble()
    }

    // Sort using by (gid, key)
    if (nu > 0) {
        Usorted = sort(U, (1, 2))
        ugid  = Usorted[., 1]
        ukeys = Usorted[., 2]
        uobs  = Usorted[., 3]
    }
    else {
        ugid  = J(0, 1, .)
        ukeys = J(0, 1, .)
        uobs  = J(0, 1, .)
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

    // Pre-allocate with doubling strategy
    n_pairs = 0
    n_matched_pairs = 0
    n_matched_master = 0
    match_counts = (compute_stats ? J(nm, 1, 0) : J(0, 1, 0))
    progress = (progress != 0 & nm > 100000)
    if (progress) {
        progress_step = ceil(nm / 10)
        progress_next = progress_step
        progress_last = 0
        printf("{txt}    Matching progress:")
    }
    if (!dryrun) {
        cap = max((nm, 1024))
        mi = J(cap, 1, .)
        ui = J(cap, 1, .)
    }

    for (i = 1; i <= nm; i++) {
        g    = M[i, 1]
        lo   = M[i, 2]
        hi   = M[i, 3]
        lo_search = lo - tolerance
        hi_search = hi + tolerance
        mobs = M[i, 4]
        mkey = (nearest_code == 0 ? . : M[i, 5])

        if (lo > hi) {
            if (keep_unmatched_master) {
                n_pairs++
                if (!dryrun) {
                    if (n_pairs > rows(mi)) {
                        mi = mi \ J(rows(mi), 1, .)
                        ui = ui \ J(rows(ui), 1, .)
                    }
                    mi[n_pairs] = mobs
                    ui[n_pairs] = .
                }
            }
            continue
        }

        if (nu == 0) {
            jlo = 0
            jhi = -1
        }
        else {
            gstart = 0
            gend = 0
            gid_i = trunc(g)
            if (gid_i >= 1 & gid_i <= rows(gstart_map)) {
                gstart = gstart_map[gid_i]
                gend = gend_map[gid_i]
            }
            if (gstart == 0) {
                jlo = 0
                jhi = -1
            }
            else {
                if (closed_code == 1) {
                    jlo = _rm_bsearch_left(ukeys, lo_search, gstart, gend)
                    jhi = _rm_bsearch_right(ukeys, hi_search, gstart, gend)
                }
                else if (closed_code == 2) {
                    jlo = _rm_bsearch_left(ukeys, lo_search, gstart, gend)
                    jhi = _rm_bsearch_last_lt(ukeys, hi_search, gstart, gend)
                }
                else if (closed_code == 3) {
                    jlo = _rm_bsearch_first_gt(ukeys, lo_search, gstart, gend)
                    jhi = _rm_bsearch_right(ukeys, hi_search, gstart, gend)
                }
                else {
                    jlo = _rm_bsearch_first_gt(ukeys, lo_search, gstart, gend)
                    jhi = _rm_bsearch_last_lt(ukeys, hi_search, gstart, gend)
                }
            }
        }

        nmatch = 0
        if (!(jlo == 0 | jlo > jhi)) {
            if (nearest_code == 0) {
                nmatch = jhi - jlo + 1
            }
            else if (mkey < .) {
                selected = J(0, 1, .)
                before_pos = _rm_bsearch_right(ukeys, mkey, jlo, jhi)
                after_pos = _rm_bsearch_left(ukeys, mkey, jlo, jhi)

                if (nearest_code == 1) {
                    if (before_pos != 0) {
                        selected = _rm_key_block_uobs(ukeys, uobs,
                            before_pos, jlo, jhi)
                    }
                }
                else if (nearest_code == 2) {
                    if (after_pos != 0) {
                        selected = _rm_key_block_uobs(ukeys, uobs,
                            after_pos, jlo, jhi)
                    }
                }
                else {
                    if (before_pos != 0 & after_pos != 0) {
                        before_dist = mkey - ukeys[before_pos]
                        after_dist = ukeys[after_pos] - mkey
                        if (before_dist < after_dist) {
                            selected = _rm_key_block_uobs(ukeys, uobs,
                                before_pos, jlo, jhi)
                        }
                        else if (after_dist < before_dist) {
                            selected = _rm_key_block_uobs(ukeys, uobs,
                                after_pos, jlo, jhi)
                        }
                        else {
                            selected = _rm_key_block_uobs(ukeys, uobs,
                                before_pos, jlo, jhi)
                            if (ukeys[before_pos] != ukeys[after_pos]) {
                                selected = selected \ _rm_key_block_uobs(
                                    ukeys, uobs, after_pos, jlo, jhi)
                            }
                        }
                    }
                    else if (before_pos != 0) {
                        selected = _rm_key_block_uobs(ukeys, uobs,
                            before_pos, jlo, jhi)
                    }
                    else if (after_pos != 0) {
                        selected = _rm_key_block_uobs(ukeys, uobs,
                            after_pos, jlo, jhi)
                    }
                }

                if (ties_code != 1 & rows(selected) > 1) {
                    allties = selected
                    selected = (ties_code == 2 ? min(allties) : max(allties))
                }
                nmatch = rows(selected)
            }
        }

        if (nmatch == 0) {
            if (keep_unmatched_master) {
                n_pairs++
                if (!dryrun) {
                    if (n_pairs > rows(mi)) {
                        mi = mi \ J(rows(mi), 1, .)
                        ui = ui \ J(rows(ui), 1, .)
                    }
                    mi[n_pairs] = mobs
                    ui[n_pairs] = .
                }
            }
        }
        else {
            if (maxpairs > 0 & (n_pairs + nmatch) > maxpairs) {
                st_framecurrent(oldframe)
                st_local("_rm_err_maxpairs", "1")
                st_local("_rm_n_pairs", strofreal(n_pairs + nmatch))
                return
            }

            n_matched_pairs = n_matched_pairs + nmatch
            n_matched_master++
            if (compute_stats) match_counts[i] = nmatch
            if (nearest_code == 0) {
                if (!dryrun) {
                    needed = n_pairs + nmatch
                    while (needed > rows(mi)) {
                        mi = mi \ J(rows(mi), 1, .)
                        ui = ui \ J(rows(ui), 1, .)
                    }
                }
                for (pos = jlo; pos <= jhi; pos++) {
                    target = uobs[pos]
                    if (track_using) matched_using[target] = 1
                    n_pairs++
                    if (!dryrun) {
                        mi[n_pairs] = mobs
                        ui[n_pairs] = target
                    }
                }
            }
            else {
                for (kk = 1; kk <= nmatch; kk++) {
                    if (track_using) matched_using[selected[kk]] = 1
                    if (dryrun) {
                        n_pairs++
                    }
                    else {
                        n_pairs++
                        if (n_pairs > rows(mi)) {
                            mi = mi \ J(rows(mi), 1, .)
                            ui = ui \ J(rows(ui), 1, .)
                        }
                        mi[n_pairs] = mobs
                        ui[n_pairs] = selected[kk]
                    }
                }
            }
        }

        if (progress & i >= progress_next) {
            progress_pct = min((100, floor(100 * i / nm)))
            printf(" %g%%", progress_pct)
            progress_last = progress_pct
            progress_next = progress_next + progress_step
        }
    }
    if (progress) {
        if (progress_last < 100) printf(" 100%%")
        printf("\n")
    }

    n_unmatched_master = (compute_stats | assert_match ? nm - n_matched_master : .)
    if (track_using) {
        n_matched_using = (nu_all > 0 ? sum(matched_using :== 1) : 0)
        n_unmatched_using = (nu_all > 0 ? sum(matched_using :== 0) : 0)
    }
    else {
        n_matched_using = .
        n_unmatched_using = .
    }

    if (keep_unmatched_using & n_unmatched_using > 0) {
        if (maxpairs > 0 & (n_pairs + n_unmatched_using) > maxpairs) {
            st_framecurrent(oldframe)
            st_local("_rm_err_maxpairs", "1")
            st_local("_rm_n_pairs", strofreal(n_pairs + n_unmatched_using))
            return
        }
        for (u = 1; u <= nu_all; u++) {
            if (matched_using[u] == 0) {
                n_pairs++
                if (!dryrun) {
                    if (n_pairs > rows(mi)) {
                        mi = mi \ J(rows(mi), 1, .)
                        ui = ui \ J(rows(ui), 1, .)
                    }
                    mi[n_pairs] = .
                    ui[n_pairs] = u
                }
            }
        }
    }

    if (compute_stats) {
        max_matches = (nm > 0 ? max(match_counts) : 0)
        mean_matches = (nm > 0 ? mean(match_counts) : 0)
        if (nm > 0) {
            sorted_counts = sort(match_counts, 1)
            if (mod(nm, 2) == 1) {
                median_matches = sorted_counts[(nm + 1) / 2]
            }
            else {
                median_matches = (sorted_counts[nm / 2] +
                    sorted_counts[(nm / 2) + 1]) / 2
            }
            p50_matches = median_matches
            p90_pos = ceil(.90 * nm)
            p99_pos = ceil(.99 * nm)
            p90_matches = sorted_counts[p90_pos]
            p99_matches = sorted_counts[p99_pos]
        }
        else {
            median_matches = 0
            p50_matches = 0
            p90_matches = 0
            p99_matches = 0
        }
        n_empty_groups = 0
        n_master_groups = 0
        if (nm > 0 & max_gid > 0) {
            seen_master = J(max_gid, 1, 0)
            for (i = 1; i <= nm; i++) {
                gid_i = trunc(M[i, 1])
                if (gid_i >= 1 & gid_i <= max_gid) {
                    if (seen_master[gid_i] == 0) {
                        seen_master[gid_i] = 1
                        n_master_groups++
                        if (gid_i > rows(gstart_map) | gstart_map[gid_i] == 0) {
                            n_empty_groups++
                        }
                    }
                }
            }
        }
    }
    else {
        max_matches = .
        mean_matches = .
        median_matches = .
        p50_matches = .
        p90_matches = .
        p99_matches = .
        n_empty_groups = .
        n_master_groups = .
    }

    if (!dryrun) {
        st_framecurrent(out_frame)
        if (n_pairs > 0) {
            st_addobs(n_pairs)
        }
        (void) st_addvar("double", "__rm_mi")
        (void) st_addvar("double", "__rm_ui")
        if (n_pairs > 0) {
            st_store(., "__rm_mi", mi[1..n_pairs])
            st_store(., "__rm_ui", ui[1..n_pairs])
        }
    }

    st_framecurrent(oldframe)
    st_local("_rm_n_pairs", strofreal(n_pairs))
    st_local("_rm_n_matched_pairs", strofreal(n_matched_pairs))
    st_local("_rm_n_matched_master", strofreal(n_matched_master))
    st_local("_rm_n_matched_using", strofreal(n_matched_using))
    st_local("_rm_n_unmatched_master", strofreal(n_unmatched_master))
    st_local("_rm_n_unmatched_using", strofreal(n_unmatched_using))
    st_local("_rm_max_matches", strofreal(max_matches))
    st_local("_rm_mean_matches", strofreal(mean_matches, "%21.17g"))
    st_local("_rm_median_matches", strofreal(median_matches, "%21.17g"))
    st_local("_rm_p50_matches", strofreal(p50_matches, "%21.17g"))
    st_local("_rm_p90_matches", strofreal(p90_matches, "%21.17g"))
    st_local("_rm_p99_matches", strofreal(p99_matches, "%21.17g"))
    st_local("_rm_n_empty_groups", strofreal(n_empty_groups))
    st_local("_rm_n_master_groups", strofreal(n_master_groups))
    st_local("_rm_err_maxpairs", "0")
}


real scalar _rm_bsearch_left(
    real colvector keys,
    real scalar target,
    real scalar lo0,
    real scalar hi0
)
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


real scalar _rm_bsearch_right(
    real colvector keys,
    real scalar target,
    real scalar lo0,
    real scalar hi0
)
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


real scalar _rm_bsearch_first_gt(
    real colvector keys,
    real scalar target,
    real scalar lo0,
    real scalar hi0
)
{
    real scalar lo, hi, mid, result

    lo = lo0
    hi = hi0
    result = 0
    while (lo <= hi) {
        mid = trunc((lo + hi) / 2)
        if (keys[mid] > target) {
            result = mid
            hi = mid - 1
        }
        else {
            lo = mid + 1
        }
    }
    return(result)
}


real scalar _rm_bsearch_last_lt(
    real colvector keys,
    real scalar target,
    real scalar lo0,
    real scalar hi0
)
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


real colvector _rm_key_block_uobs(
    real colvector keys,
    real colvector obs,
    real scalar pos,
    real scalar lo,
    real scalar hi
)
{
    real scalar first, last, key

    if (pos == 0) return(J(0, 1, .))

    key = keys[pos]
    first = pos
    while (first > lo) {
        if (keys[first - 1] != key) break
        first--
    }

    last = pos
    while (last < hi) {
        if (keys[last + 1] != key) break
        last++
    }

    return(obs[first..last])
}


void _rm_materialize(
    string scalar out_frame,
    string scalar src_frame,
    string scalar index_var,
    string rowvector src_vars,
    string rowvector out_vars
)
{
    string scalar oldframe, vtype, fmt
    string rowvector num_types, num_fmts, num_out
    real scalar j, k, nv, nout, vidx_src, vidx_out, nnum, all_valid
    real scalar c0, c1, chunk_cols
    real rowvector num_src_idx, num_out_idx, src_chunk, out_chunk
    real colvector idx, valid_idx
    real matrix nummat
    string colvector strcol

    oldframe = st_framecurrent()
    nv = cols(src_vars)

    st_framecurrent(out_frame)
    nout = st_nobs()
    idx = (nout > 0 ? st_data(., index_var) : J(0, 1, .))
    all_valid = (nout == 0 ? 1 : !hasmissing(idx))
    if (!all_valid) valid_idx = selectindex(idx :< .)

    num_types = J(1, 0, "")
    num_fmts = J(1, 0, "")
    num_out = J(1, 0, "")
    num_src_idx = J(1, 0, .)
    num_out_idx = J(1, 0, .)

    for (j = 1; j <= nv; j++) {
        st_framecurrent(src_frame)
        vtype = st_vartype(src_vars[j])
        fmt = st_varformat(src_vars[j])
        vidx_src = st_varindex(src_vars[j])

        st_framecurrent(out_frame)
        (void) st_addvar(vtype, out_vars[j])
        vidx_out = st_varindex(out_vars[j])
        st_varformat(out_vars[j], fmt)

        if (substr(vtype, 1, 3) == "str") {
            if (nout > 0) {
                st_framecurrent(src_frame)
                if (all_valid) {
                    strcol = st_sdata(idx, vidx_src)
                }
                else {
                    strcol = J(nout, 1, "")
                    if (length(valid_idx) > 0) {
                        strcol[valid_idx] = st_sdata(idx[valid_idx], vidx_src)
                    }
                }
                st_framecurrent(out_frame)
                st_sstore(., vidx_out, strcol)
            }
            else {
                st_framecurrent(src_frame)
                st_framecurrent(out_frame)
            }
        }
        else {
            num_types = num_types, vtype
            num_fmts = num_fmts, fmt
            num_out = num_out, out_vars[j]
            num_src_idx = num_src_idx, vidx_src
            num_out_idx = num_out_idx, vidx_out
        }
    }

    nnum = cols(num_out)
    if (nnum > 0) {
        st_framecurrent(out_frame)
        if (nout > 0) {
            chunk_cols = 32
            for (c0 = 1; c0 <= nnum; c0 = c0 + chunk_cols) {
                c1 = min((nnum, c0 + chunk_cols - 1))
                src_chunk = num_src_idx[|1, c0 \ 1, c1|]
                out_chunk = num_out_idx[|1, c0 \ 1, c1|]

                st_framecurrent(src_frame)
                if (all_valid) {
                    nummat = st_data(idx, src_chunk)
                }
                else {
                    nummat = J(nout, cols(src_chunk), .)
                    if (length(valid_idx) > 0) {
                        nummat[valid_idx, .] = st_data(idx[valid_idx], src_chunk)
                    }
                }
                st_framecurrent(out_frame)
                st_store(., out_chunk, nummat)
            }
        }
    }

    st_framecurrent(oldframe)
}


void _rm_fill_using_only(
    string scalar out_frame,
    string scalar src_frame,
    string scalar master_index_var,
    string scalar using_index_var,
    string rowvector src_vars,
    string rowvector out_vars
)
{
    string scalar oldframe, vtype
    real scalar j, nv, nout, vidx_src, vidx_out
    real colvector mi, ui, using_only, numcol
    string colvector strcol

    oldframe = st_framecurrent()
    nv = cols(src_vars)

    st_framecurrent(out_frame)
    nout = st_nobs()
    if (nout == 0) {
        st_framecurrent(oldframe)
        return
    }

    mi = st_data(., master_index_var)
    ui = st_data(., using_index_var)
    using_only = selectindex(mi :>= . :& ui :< .)
    if (length(using_only) == 0) {
        st_framecurrent(oldframe)
        return
    }

    for (j = 1; j <= nv; j++) {
        st_framecurrent(src_frame)
        vtype = st_vartype(src_vars[j])
        vidx_src = st_varindex(src_vars[j])

        st_framecurrent(out_frame)
        vidx_out = st_varindex(out_vars[j])

        if (substr(vtype, 1, 3) == "str") {
            st_framecurrent(src_frame)
            strcol = st_sdata(ui[using_only], vidx_src)
            st_framecurrent(out_frame)
            st_sstore(using_only, vidx_out, strcol)
        }
        else {
            st_framecurrent(src_frame)
            numcol = st_data(ui[using_only], vidx_src)
            st_framecurrent(out_frame)
            st_store(using_only, vidx_out, numcol)
        }
    }

    st_framecurrent(oldframe)
}


void _rm_generate_distance(
    string scalar out_frame,
    string scalar master_frame,
    string scalar using_frame,
    string scalar master_index_var,
    string scalar using_index_var,
    string scalar master_key,
    string scalar using_key,
    string scalar out_var
)
{
    string scalar oldframe
    real scalar nout
    real colvector mi, ui, matched, master_key_vals, using_key_vals

    oldframe = st_framecurrent()

    st_framecurrent(out_frame)
    nout = st_nobs()
    (void) st_addvar("double", out_var)
    if (nout == 0) {
        st_framecurrent(oldframe)
        return
    }

    mi = st_data(., master_index_var)
    ui = st_data(., using_index_var)
    matched = selectindex(mi :< . :& ui :< .)

    if (length(matched) > 0) {
        // Read the full key columns and subscript in Mata. st_data() with a
        // row-index vector containing duplicate indices does not reliably
        // return one value per duplicate (it is row-selection semantics, not
        // subscript semantics), so the same using observation matched to
        // multiple master observations would yield wrong differences. The
        // explicit (idx, 1) row-subscript forces colvector semantics even
        // when master_key_vals or using_key_vals has only one element, where
        // v[idx] would otherwise resolve to row/col matrix subscripting.
        st_framecurrent(master_frame)
        master_key_vals = st_data(., master_key)
        st_framecurrent(using_frame)
        using_key_vals = st_data(., using_key)
        st_framecurrent(out_frame)
        st_store(matched, out_var,
            using_key_vals[ui[matched], 1] :- master_key_vals[mi[matched], 1])
    }
    st_framecurrent(oldframe)
}


void _rm_copy_output(string scalar src_frame, string rowvector varnames)
{
    string scalar oldframe, vtype
    real scalar j, nv, vidx
    real colvector numcol
    string colvector strcol

    oldframe = st_framecurrent()
    nv = cols(varnames)

    st_framecurrent(src_frame)

    for (j = 1; j <= nv; j++) {
        vtype = st_vartype(varnames[j])
        vidx = st_varindex(varnames[j])

        if (substr(vtype, 1, 3) == "str") {
            strcol = st_sdata(., vidx)
            st_framecurrent(oldframe)
            st_sstore(., varnames[j], strcol)
            st_framecurrent(src_frame)
        }
        else {
            numcol = st_data(., vidx)
            st_framecurrent(oldframe)
            st_store(., varnames[j], numcol)
            st_framecurrent(src_frame)
        }
    }

    st_framecurrent(oldframe)
}

end
