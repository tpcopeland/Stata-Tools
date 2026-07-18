*! _rangematch_mata Version 1.4.1  2026/07/18
*! Mata backend for rangematch: binary-search pair generation and output materialization
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.1

capture mata: mata drop _rm_build_pairs()
capture mata: mata drop _rm_build_pairs_sweep()
capture mata: mata drop _rm_build_pairs_overlap()
capture mata: mata drop _rm_overlap_count_group()
capture mata: mata drop _rm_overlap_emit_group()
capture mata: mata drop _rm_interval_nonempty()
capture mata: mata drop _rm_prepare_sweep_master()
capture mata: mata drop _rm_compute_match_stats()
capture mata: mata drop _rm_post_pair_results()
capture mata: mata drop _rm_mata_version()
capture mata: mata drop _rm_blank_quoted()
capture mata: mata drop _rm_first_empty_opt()
capture mata: mata drop _rm_dta_name()
capture mata: mata drop _rm_bsearch_left()
capture mata: mata drop _rm_bsearch_right()
capture mata: mata drop _rm_bsearch_first_gt()
capture mata: mata drop _rm_bsearch_last_lt()
capture mata: mata drop _rm_key_block_uobs()
capture mata: mata drop _rm_store_indexed()
capture mata: mata drop _rm_vl_same()
capture mata: mata drop _rm_vl_candidate()
capture mata: mata drop _rm_vl_resolve()
capture mata: mata drop _rm_materialize()
capture mata: mata drop _rm_fill_using_only()
capture mata: mata drop _rm_generate_distance()
capture mata: mata drop _rm_copy_output()

mata: mata set matastrict on
mata:

string scalar _rm_mata_version()
{
    return("1.4.1")
}

// ============================================================================
// Empty-option-argument scanner.
//
// Stata's `syntax' treats `missing()' as NOT SUPPLIED: an explicitly empty
// option argument is indistinguishable from an omitted option, so an option
// whose grammar requires content silently becomes its default or a no-op.
// (`missing(`policy')' with an empty `policy' would quietly disable the
// requested check.) The parser therefore cannot make this distinction and the
// raw argument list is scanned instead.
//
// _rm_blank_quoted() first masks every double-quoted payload so that a path,
// label, or expression containing "()" cannot be misread as an empty option.
// Quote characters are written as char(34): Mata has no backslash escape for a
// double quote, and embedding one silently kills the whole mata block.
//
// The mask character is "x", NOT a space: masking with spaces would turn
// saving("/path/out.dta") into saving(        ), which reads as an EMPTY
// argument and rejects a perfectly valid call. The mask must keep a quoted
// payload looking like content while destroying any option-like text inside it.
// ============================================================================
string scalar _rm_blank_quoted(string scalar s0)
{
    string scalar out, ch, dq, mask
    real scalar i, n, inq

    dq = char(34)
    mask = "x"
    out = ""
    n = strlen(s0)
    inq = 0
    for (i = 1; i <= n; i++) {
        ch = substr(s0, i, 1)
        if (ch == dq) {
            inq = !inq
            out = out + mask
        }
        else {
            out = out + (inq ? mask : ch)
        }
    }
    return(out)
}

// Return the full name of the first option found written with an empty
// argument, or "" if none. Abbreviations are honoured exactly as `syntax'
// defines them: for each option every prefix from its minimum abbreviation up
// to the full name is tested, so miss(), missi(), missin() and missing() are
// all caught. prefix()/suffix() are excluded by design -- an empty prefix is a
// meaningful value, not a missing argument -- as are the numeric-typed
// tolerance()/maxpairs(), which `syntax' already rejects when empty.
string scalar _rm_first_empty_opt(string scalar cmdline)
{
    string colvector fulls
    real colvector mins
    string scalar s, cand
    real scalar i, j, L

    fulls = ("by"       \ "keepusing" \ "unmatched" \ "generate" \
             "distance" \ "masterid"  \ "usingid"   \ "overlap"  \
             "frame"    \ "closed"    \ "nearest"   \ "ties"     \
             "seed"     \ "missing"   \ "assert"    \ "saving")
    // Minimum abbreviation length, matching the capitals in the syntax line:
    // BY KEEPUsing UNMATCHed GENerate DISTance MASTERID USINGID OVERLAP
    // FRAME CLOSED NEARest TIES SEED MISSing ASsert SAVing
    mins  = (2 \ 5 \ 7 \ 3 \
             4 \ 8 \ 7 \ 7 \
             5 \ 6 \ 4 \ 4 \
             4 \ 4 \ 2 \ 3)

    s = strlower(_rm_blank_quoted(cmdline))
    for (i = 1; i <= rows(fulls); i++) {
        L = strlen(fulls[i])
        for (j = mins[i]; j <= L; j++) {
            cand = substr(fulls[i], 1, j)
            // <abbrev> ( ) at a token boundary, allowing internal blanks.
            if (ustrregexm(s, "(^|[ ,])" + cand + " *\( *\)")) {
                return(fulls[i])
            }
        }
    }
    return("")
}

// ============================================================================
// Resolve a dataset path the way Stata's own `save' resolves it.
//
// Stata appends .dta only when the FILE NAME carries no extension. Measured
// with save:
//     "plain"       -> plain.dta
//     "dotted.foo"  -> dotted.foo    (left alone)
//     "St99.000002" -> St99.000002   (left alone -- a tempfile already has an
//                                     ".<seq>" extension)
// so the rule is "no extension -> append .dta", NOT "does not end in .dta ->
// append .dta". saving("/tmp/out") wrote /tmp/out.dta while r(saving) and the
// console both reported the nonexistent /tmp/out, so automation that confirmed
// or reused r(saving) failed after a successful command.
//
// pathsuffix() is used rather than a strpos(".") test because it confines
// itself to the file name: a dot in a DIRECTORY component (as in
// "~/my.dir/out") must not count as an extension.
// ============================================================================
string scalar _rm_dta_name(string scalar fname)
{
    if (pathsuffix(fname) == "") return(fname + ".dta")
    return(fname)
}

void _rm_prepare_sweep_master(
    string scalar master_frame,
    real scalar sort_allowed
)
{
    string scalar oldframe
    real matrix M
    real scalar nm, i, gid_i, last_gid, last_lo, last_hi
    real scalar ready, lo_ready, hi_ready, sweep_mode

    oldframe = st_framecurrent()
    sort_allowed = (sort_allowed != 0)
    ready = 1
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
    }

    st_framecurrent(oldframe)
    st_local("_rm_sweep_ready", strofreal(ready))
    st_local("_rm_sweep_mode", strofreal(sweep_mode))
}

real rowvector _rm_compute_match_stats(
    real colvector match_counts,
    real scalar nm,
    real scalar max_gid,
    real colvector gstart_map,
    real matrix M,
    real scalar compute_stats
)
{
    real colvector sorted_counts, seen_master
    real scalar max_matches, mean_matches, median_matches, p50_matches
    real scalar p90_matches, p99_matches, p90_pos, p99_pos
    real scalar n_empty_groups, n_master_groups, i, gid_i

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

    return((max_matches, mean_matches, median_matches, p50_matches, ///
        p90_matches, p99_matches, n_empty_groups, n_master_groups))
}

void _rm_post_pair_results(
    real scalar n_pairs,
    real scalar n_matched_pairs,
    real scalar n_matched_master,
    real scalar n_matched_using,
    real scalar n_unmatched_master,
    real scalar n_unmatched_using,
    real rowvector match_stats
)
{
    st_local("_rm_n_pairs", strofreal(n_pairs))
    st_local("_rm_n_matched_pairs", strofreal(n_matched_pairs))
    st_local("_rm_n_matched_master", strofreal(n_matched_master))
    st_local("_rm_n_matched_using", strofreal(n_matched_using))
    st_local("_rm_n_unmatched_master", strofreal(n_unmatched_master))
    st_local("_rm_n_unmatched_using", strofreal(n_unmatched_using))
    st_local("_rm_max_matches", strofreal(match_stats[1]))
    st_local("_rm_mean_matches", strofreal(match_stats[2], "%21.17g"))
    st_local("_rm_median_matches", strofreal(match_stats[3], "%21.17g"))
    st_local("_rm_p50_matches", strofreal(match_stats[4], "%21.17g"))
    st_local("_rm_p90_matches", strofreal(match_stats[5], "%21.17g"))
    st_local("_rm_p99_matches", strofreal(match_stats[6], "%21.17g"))
    st_local("_rm_n_empty_groups", strofreal(match_stats[7]))
    st_local("_rm_n_master_groups", strofreal(match_stats[8]))
    st_local("_rm_err_maxpairs", "0")
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
    real scalar sweep_mode,
    string scalar mi_var,
    string scalar ui_var
)
{
    string scalar oldframe
    real matrix M, U, Usorted
    real colvector mi, ui, perm, ukeys, uobs, ugid, match_counts
    real colvector gstart_map, gend_map
    real colvector matched_using
    real rowvector match_stats
    real scalar nm, nu, i, pos, n_pairs, nmatch, outcap, needed
    real scalar lo, hi, lo_search, hi_search, mobs, g, gid_i
    real scalar max_gid, u, target, n_matched_pairs, n_matched_master
    real scalar n_unmatched_master, n_matched_using, n_unmatched_using
    real scalar gstart, gend, cur_gid, left, right
    real scalar progress_next, progress_step
    real scalar progress_pct, progress_last
    real scalar nu_all, track_using
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
        outcap = max((nm, 1024))
        mi = J(outcap, 1, .)
        ui = J(outcap, 1, .)
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
        // Clamp the tolerance shift to the finite double range. Without this,
        // mindouble() - tolerance (or maxdouble() + tolerance) overflows to
        // missing for tolerance >~ 1e290; a missing lo_search sorts above every
        // key and silently drops all matches (max/min ignore the missing).
        lo_search = max((lo - tolerance, mindouble()))
        hi_search = min((hi + tolerance, maxdouble()))
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
                if (maxpairs > 0 & (n_pairs + 1) > maxpairs) {
                    st_framecurrent(oldframe)
                    st_local("_rm_err_maxpairs", "1")
                    st_local("_rm_n_pairs", strofreal(n_pairs + 1))
                    return
                }
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

    match_stats = _rm_compute_match_stats(match_counts, nm, max_gid, ///
        gstart_map, M, compute_stats)

    if (!dryrun) {
        st_framecurrent(out_frame)
        if (n_pairs > 0) {
            st_addobs(n_pairs)
        }
        (void) st_addvar("double", mi_var)
        (void) st_addvar("double", ui_var)
        if (n_pairs > 0) {
            st_store(., mi_var, mi[1..n_pairs])
            st_store(., ui_var, ui[1..n_pairs])
        }
    }

    st_framecurrent(oldframe)
    _rm_post_pair_results(n_pairs, n_matched_pairs, n_matched_master, ///
        n_matched_using, n_unmatched_master, n_unmatched_using, match_stats)
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
    real scalar assert_using,
    string scalar mi_var,
    string scalar ui_var
)
{
    string scalar oldframe
    real matrix M, U, Usorted
    real colvector mi, ui, perm, ukeys, uobs, ugid, match_counts
    real colvector gstart_map, gend_map
    real colvector selected, allties, matched_using
    real rowvector match_stats
    real scalar nm, nu, nu_all, i, lo, hi, jlo, jhi, kk, n_pairs
    real scalar gstart, gend, mobs, g, outcap, nmatch, u
    real scalar mkey, before_pos, after_pos, before_dist, after_dist
    real scalar n_matched_pairs, n_matched_master
    real scalar n_unmatched_master, n_matched_using, n_unmatched_using
    real scalar progress_next, progress_step, progress_pct
    real scalar progress_last, lo_search, hi_search
    real scalar max_gid, gid_i, pos, target, needed
    real scalar track_using, ridx

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

    // Sort using by (gid, key, uobs). The trailing uobs (col 3, unique) is a
    // tiebreaker that makes the order of equal-key rows deterministic: Mata's
    // sort() does not order ties reproducibly across calls, so without it
    // ties(random) would pick a different row each run even under a fixed
    // seed(), and nosort output order would be unstable. Keys stay sorted, so
    // binary search is unaffected.
    if (nu > 0) {
        Usorted = sort(U, (1, 2, 3))
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
        outcap = max((nm, 1024))
        mi = J(outcap, 1, .)
        ui = J(outcap, 1, .)
    }

    for (i = 1; i <= nm; i++) {
        g    = M[i, 1]
        lo   = M[i, 2]
        hi   = M[i, 3]
        // Clamp the tolerance shift to the finite double range (see the sweep
        // backend): an unclamped shift overflows to missing for a large
        // tolerance and drops every match. max/min ignore the missing operand.
        lo_search = max((lo - tolerance, mindouble()))
        hi_search = min((hi + tolerance, maxdouble()))
        mobs = M[i, 4]
        mkey = (nearest_code == 0 ? . : M[i, 5])

        if (lo > hi) {
            if (keep_unmatched_master) {
                if (maxpairs > 0 & (n_pairs + 1) > maxpairs) {
                    st_framecurrent(oldframe)
                    st_local("_rm_err_maxpairs", "1")
                    st_local("_rm_n_pairs", strofreal(n_pairs + 1))
                    return
                }
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
                    if (ties_code == 2) {
                        // first: lowest original using obs number
                        selected = min(allties)
                    }
                    else if (ties_code == 3) {
                        // last: highest original using obs number
                        selected = max(allties)
                    }
                    else {
                        // random: one tied row drawn from Stata's RNG stream
                        // (seeded in the .ado when seed() is given). runiform()
                        // is in [0,1), so 1 + trunc(u*n) is uniform on 1..n;
                        // the clamp guards the FP edge only. allties is ordered
                        // by original using obs (the col-3 sort tiebreaker
                        // below), so the pick is reproducible under a given
                        // seed -- Mata sort() does NOT order ties determin-
                        // istically, so the tiebreaker is required here.
                        ridx = 1 + trunc(runiform(1, 1) * rows(allties))
                        if (ridx > rows(allties)) ridx = rows(allties)
                        selected = allties[ridx]
                    }
                }
                nmatch = rows(selected)
            }
        }

        if (nmatch == 0) {
            if (keep_unmatched_master) {
                if (maxpairs > 0 & (n_pairs + 1) > maxpairs) {
                    st_framecurrent(oldframe)
                    st_local("_rm_err_maxpairs", "1")
                    st_local("_rm_n_pairs", strofreal(n_pairs + 1))
                    return
                }
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

    match_stats = _rm_compute_match_stats(match_counts, nm, max_gid, ///
        gstart_map, M, compute_stats)

    if (!dryrun) {
        st_framecurrent(out_frame)
        if (n_pairs > 0) {
            st_addobs(n_pairs)
        }
        (void) st_addvar("double", mi_var)
        (void) st_addvar("double", ui_var)
        if (n_pairs > 0) {
            st_store(., mi_var, mi[1..n_pairs])
            st_store(., ui_var, ui[1..n_pairs])
        }
    }

    st_framecurrent(oldframe)
    _rm_post_pair_results(n_pairs, n_matched_pairs, n_matched_master, ///
        n_matched_using, n_unmatched_master, n_unmatched_using, match_stats)
}


// ============================================================================
// _rm_build_pairs_overlap()
//
// Interval-overlap pair generation. Emits master x using pairs where the
// master interval [mlo, mhi] overlaps the using interval [ulo, uhi]:
//   closed(both): ulo <= mhi & uhi >= mlo  (touching endpoints count)
//   closed(none): ulo <  mhi & uhi >  mlo  (strict; touching excluded)
// tolerance shifts the comparison boundaries (mhi+tol, mlo-tol).
//
// Master work frame columns: 1=gid, 2=low, 3=high, 4=obs.
// Using  work frame columns: 1=gid, 2=ulo, 3=uhi, 4=obs.
//
// Reuses the same group-map, stats, unmatched-row, and output (__rm_mi/__rm_ui)
// contract as _rm_build_pairs.
//
// ALGORITHM: forward-scan plane sweep, run per by()-group over both sides
// sorted by lower bound. It is output sensitive -- O((M+U) log U + K) -- which
// the previous design was not: that one binary-searched a candidate prefix on
// ulo and then LINEARLY RESCANNED the whole prefix to filter on uhi, so data
// whose using intervals all start early and end early put every using row in
// the prefix and none in the output. Measured 0.257/0.935/3.637/15.129s at
// 2k/4k/8k/16k rows while returning zero pairs: quadratic comparison work for
// an empty result, which maxpairs() cannot guard because the pair count is 0.
//
// The sweep advances whichever side opens next and reports from the other:
//
//   master i opens first (mlo_s[i] < ulo[j])
//       every using k >= j with ulo[k] inside master i overlaps it
//   using j opens first (mlo_s[i] >= ulo[j])
//       every master k >= i with mlo_s[k] inside using j overlaps it
//
// Each branch tests ONE inequality; the other holds for free. When master i
// opens first, ulo[k] >= ulo[j] > mlo_s[i], and a nonempty using interval ends
// at or after it starts, so uhi[k] > mlo_s[i] without being compared. That is
// why the closure-aware nonemptiness screen below is load-bearing rather than
// cosmetic: the free half of each test is only sound once both intervals are
// known nonempty, so invalid rows are compacted OUT of the swept arrays (they
// still surface as unmatched using rows, the same disposition as before).
// The scan end points come from binary search, so a branch that reports nothing
// costs O(log U) instead of a full prefix walk. Every inner iteration then
// yields exactly one output pair, which is what bounds the sweep by K.
//
// Two passes run: the first counts each master's matches WITHOUT enumerating
// them (the count is a binary-searched range width, so it carries no K term and
// needs no per-pair memory), which lets the second pass write pairs straight
// into slots reserved in original master-row order. That ordering is the public
// contract -- pairs grouped by master, ascending in sorted-using position --
// and it is also what keeps the maxpairs() trigger point and its reported count
// identical to the old row-at-a-time loop.
//
// Output pairs are streamed, so the full Cartesian product is never
// materialized.
//
// DRIFT GUARD: the tvtools package keeps a slimmed inner-join copy of this
// overlap logic (_tvm_build_pairs_overlap in tvtools/_tvmerge_mata.ado). The two
// must stay behaviourally identical for the closed-boundary, zero-tolerance,
// inner-join case; tvtools/qa/test_tvm_overlap_drift_guard.do pins them together.
// If you change overlap semantics here, update that copy and re-run its guard.
// ============================================================================

// Closure-aware interval-nonemptiness predicate, applied symmetrically to the
// master and using sides. An interval describes a genuine, nonempty region only
// if its bounds are ordered:
//   closed(both) -> [lo,hi] is nonempty iff lo <= hi; lo == hi is the valid
//                   degenerate single point.
//   closed(none) -> (lo,hi) is nonempty iff lo <  hi; the open degenerate
//                   interval (x,x) contains nothing.
// Inverted bounds (lo > hi) are empty under either closure, so an inverted
// using interval can never be a genuine overlap match.
//
// Validity is a property of the recorded data, so it is evaluated on the raw
// bounds (after open-ended missing->+/-inf substitution) and is deliberately
// NOT widened by tolerance(): tolerance fuzzes boundary comparisons between two
// genuine intervals; it does not promote an empty interval into a nonempty one.
// Screening the two cross-interval inequalities alone is insufficient, because
// those are sufficient only once both intervals are known to be nonempty.
real scalar _rm_interval_nonempty(
    real scalar lo,
    real scalar hi,
    real scalar both
)
{
    return(both ? (lo <= hi) : (lo < hi))
}

// Forward-scan sweep over one group, COUNTING pass. Adds each master's match
// count to cnt_point (a point add, when the master opens first) or to cnt_diff
// (a difference array, when a using row opens first and reports a contiguous
// RANGE of masters at once). Neither branch enumerates pairs -- the count is
// the width of a binary-searched range -- so this pass costs O((m+u) log u)
// with no K term and no per-pair storage. cnt_diff is prefix-summed by the
// caller; every +1 at i has its -1 at e+1 within the same group, so the running
// sum returns to zero at each group boundary and one global pass suffices.
//
// Indices are positions in the caller's compacted, group-sorted valid arrays.
void _rm_overlap_count_group(
    real colvector vmlo,
    real colvector vmhi,
    real colvector vulo,
    real colvector vuhi,
    real scalar ms,
    real scalar me,
    real scalar us,
    real scalar ue,
    real scalar both,
    real colvector cnt_point,
    real colvector cnt_diff
)
{
    real scalar i, j, e

    i = ms
    j = us
    while (i <= me & j <= ue) {
        if (vmlo[i] < vulo[j]) {
            e = (both ? _rm_bsearch_right(vulo, vmhi[i], j, ue)
                      : _rm_bsearch_last_lt(vulo, vmhi[i], j, ue))
            if (e >= j) cnt_point[i] = cnt_point[i] + (e - j + 1)
            i++
        }
        else {
            e = (both ? _rm_bsearch_right(vmlo, vuhi[j], i, me)
                      : _rm_bsearch_last_lt(vmlo, vuhi[j], i, me))
            if (e >= i) {
                cnt_diff[i] = cnt_diff[i] + 1
                cnt_diff[e + 1] = cnt_diff[e + 1] - 1
            }
            j++
        }
    }
}

// Forward-scan sweep over one group, EMITTING pass. Same traversal as the
// counting pass, but walks each reported range and writes one pair per step.
//
// cursor holds, per ORIGINAL master row, the next output slot reserved for that
// master; the caller sized those blocks from the counting pass. Writing through
// cursor is what restores original master-row order from a sweep that visits
// masters in lower-bound order. Within one master the pairs still land
// ascending in sorted-using position, because a master's range-reported pairs
// (using j opens first) all precede its own opening event, and both branches
// walk ascending.
void _rm_overlap_emit_group(
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
    real scalar both,
    real colvector mobs_all,
    real colvector cursor,
    real colvector mi,
    real colvector ui,
    real colvector matched_using,
    real scalar track_using,
    real scalar dryrun
)
{
    real scalar i, j, e, k, idx, target, slot

    i = ms
    j = us
    while (i <= me & j <= ue) {
        if (vmlo[i] < vulo[j]) {
            e = (both ? _rm_bsearch_right(vulo, vmhi[i], j, ue)
                      : _rm_bsearch_last_lt(vulo, vmhi[i], j, ue))
            idx = vmidx[i]
            for (k = j; k <= e; k++) {
                target = vuobs[k]
                if (track_using) matched_using[target] = 1
                if (!dryrun) {
                    slot = cursor[idx]
                    mi[slot] = mobs_all[idx]
                    ui[slot] = target
                }
                cursor[idx] = cursor[idx] + 1
            }
            i++
        }
        else {
            e = (both ? _rm_bsearch_right(vmlo, vuhi[j], i, me)
                      : _rm_bsearch_last_lt(vmlo, vuhi[j], i, me))
            target = vuobs[j]
            for (k = i; k <= e; k++) {
                idx = vmidx[k]
                if (track_using) matched_using[target] = 1
                if (!dryrun) {
                    slot = cursor[idx]
                    mi[slot] = mobs_all[idx]
                    ui[slot] = target
                }
                cursor[idx] = cursor[idx] + 1
            }
            j++
        }
    }
}

void _rm_build_pairs_overlap(
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
    string scalar mi_var,
    string scalar ui_var
)
{
    string scalar oldframe
    real matrix M, U, Usorted, VM
    real colvector mi, ui, ulo, uhi, uobs, ugid, match_counts, uvalid
    real colvector gstart_map, gend_map, matched_using, mobs_all
    real colvector vmgid, vmlo, vmhi, vmidx, vugid, vulo, vuhi, vuobs
    real colvector vgstart_map, vgend_map, cnt_point, cnt_diff, counts_all
    real colvector cursor
    real rowvector match_stats
    real scalar nm, nu, nu_all, i, n_pairs
    real scalar outcap, nmatch, u, p, needed
    real scalar n_matched_pairs, n_matched_master
    real scalar n_unmatched_master, n_matched_using, n_unmatched_using
    real scalar progress_next, progress_step, progress_pct, progress_last
    real scalar max_gid, gid_i, track_using, both
    real scalar nvm, nvu, a, b, g, us, ue, running, need_emit

    oldframe = st_framecurrent()
    keep_unmatched_using = (keep_unmatched_using != 0)
    compute_stats = (compute_stats != 0)
    assert_match = (assert_match != 0)
    assert_using = (assert_using != 0)
    track_using = (compute_stats | assert_using | keep_unmatched_using)
    both = (closed_code == 1)

    st_framecurrent(master_frame)
    M = st_data(., .)
    nm = rows(M)

    st_framecurrent(using_frame)
    U = st_data(., .)
    nu = rows(U)
    nu_all = nu
    matched_using = (track_using ? J(nu_all, 1, 0) : J(0, 1, 0))

    // Open-ended using bounds: missing ulo -> -inf, missing uhi -> +inf
    for (u = 1; u <= nu; u++) {
        if (U[u, 2] >= .) U[u, 2] = mindouble()
        if (U[u, 3] >= .) U[u, 3] = maxdouble()
    }

    // Open-ended master bounds
    for (i = 1; i <= nm; i++) {
        if (M[i, 2] >= .) M[i, 2] = mindouble()
        if (M[i, 3] >= .) M[i, 3] = maxdouble()
    }

    // Sort using by (gid, ulo, uobs). The trailing uobs (col 4, unique) is a
    // tiebreaker that makes the order of equal-(gid, ulo) rows deterministic:
    // Mata's sort() does not order ties reproducibly across calls, so without
    // it the pair order emitted for a master row (and hence nosort output
    // order) would be unstable. Keys stay sorted, so binary search is
    // unaffected.
    if (nu > 0) {
        Usorted = sort(U, (1, 2, 4))
        ugid = Usorted[., 1]
        ulo  = Usorted[., 2]
        uhi  = Usorted[., 3]
        uobs = Usorted[., 4]
        // Screen using intervals for closure-aware nonemptiness. Invalid
        // (inverted or open-degenerate) rows stay in the arrays so the binary
        // search and group map are untouched, but they can never be emitted as
        // a match. Because matched_using is only set when a pair is emitted,
        // they surface as unmatched using rows under unmatched(using|both),
        // which is the correct disposition for an empty interval.
        uvalid = J(nu, 1, 0)
        for (u = 1; u <= nu; u++) {
            uvalid[u] = _rm_interval_nonempty(ulo[u], uhi[u], both)
        }
    }
    else {
        ugid = J(0, 1, .)
        ulo  = J(0, 1, .)
        uhi  = J(0, 1, .)
        uobs = J(0, 1, .)
        uvalid = J(0, 1, .)
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

    // ---- Compact the valid rows into the swept arrays ----------------------
    // The sweep's free half-test (see the algorithm note above) is sound only
    // for nonempty intervals, so invalid rows are removed rather than skipped
    // mid-scan. Their disposition is unchanged: an invalid using row is never
    // marked matched, so it still surfaces under unmatched(using|both), and an
    // invalid master row still reports zero matches.
    //
    // gstart_map/gend_map above are deliberately NOT rebuilt from the compacted
    // rows. _rm_compute_match_stats() reads them to decide whether a master's
    // group had any using rows at all, which is a property of the data, not of
    // interval validity: a group holding only inverted using rows is not an
    // empty group.
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
        vgstart_map = J(max_gid, 1, 0)
        vgend_map = J(max_gid, 1, 0)
        for (u = 1; u <= nvu; u++) {
            gid_i = trunc(vugid[u])
            if (gid_i >= 1 & gid_i <= max_gid) {
                if (vgstart_map[gid_i] == 0) vgstart_map[gid_i] = u
                vgend_map[gid_i] = u
            }
        }
    }
    else {
        vgstart_map = J(0, 1, 0)
        vgend_map = J(0, 1, 0)
    }

    // Valid master rows, tolerance-shifted, sorted by (gid, mlo_s, orig row).
    // Validity is judged on the RAW bounds, exactly as before: the shift cannot
    // rescue an empty interval.
    //
    // The sweep needs mlo_s <= mhi_s, and it gets that from tolerance being
    // NONNEGATIVE -- widening a nonempty interval leaves it nonempty. That is
    // enforced by the caller (rangematch.ado rejects a negative or nonfinite
    // tolerance()), not here. It is a real coupling, not a comment: a negative
    // tolerance would invert the shifted master interval, and the sweep would
    // then trust a free half-test that no longer holds and emit wrong pairs at
    // rc=0. The prefix-rescan this replaced tested both inequalities outright,
    // so it did not care. If that guard is ever relaxed, screen the SHIFTED
    // bounds here too.
    //
    // Column 4 carries the original master row index -- it makes ties
    // reproducible (Mata's sort() does not order them deterministically) and is
    // how the emit pass finds its way back to original row order.
    nvm = 0
    for (i = 1; i <= nm; i++) {
        if (_rm_interval_nonempty(M[i, 2], M[i, 3], both)) nvm++
    }
    VM = J(nvm, 4, .)
    p = 0
    for (i = 1; i <= nm; i++) {
        if (_rm_interval_nonempty(M[i, 2], M[i, 3], both)) {
            p++
            VM[p, 1] = M[i, 1]
            // Clamp the tolerance shift to the finite double range (see the
            // sweep backend): an unclamped shift overflows to missing for a
            // large tolerance and drops every match.
            VM[p, 2] = max((M[i, 2] - tolerance, mindouble()))
            VM[p, 3] = min((M[i, 3] + tolerance, maxdouble()))
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
        if (gid_i >= 1 & gid_i <= rows(vgstart_map)) {
            us = vgstart_map[gid_i]
            ue = vgend_map[gid_i]
        }
        if (us != 0) {
            _rm_overlap_count_group(vmlo, vmhi, vulo, vuhi, a, b, us, ue, ///
                both, cnt_point, cnt_diff)
        }
        a = b + 1
    }

    counts_all = J(nm, 1, 0)
    running = 0
    for (a = 1; a <= nvm; a++) {
        running = running + cnt_diff[a]
        counts_all[vmidx[a]] = cnt_point[a] + running
    }

    // ---- Reserve output slots, walking masters in ORIGINAL row order -------
    // Counts are known before a single pair is written, so the maxpairs() limit
    // trips at the same master row, with the same reported count, as the old
    // row-at-a-time loop did.
    n_pairs = 0
    n_matched_pairs = 0
    n_matched_master = 0
    match_counts = (compute_stats ? J(nm, 1, 0) : J(0, 1, 0))
    cursor = J(nm, 1, 0)
    progress = (progress != 0 & nm > 100000)
    if (progress) {
        progress_step = ceil(nm / 10)
        progress_next = progress_step
        progress_last = 0
        printf("{txt}    Matching progress:")
    }
    if (!dryrun) {
        outcap = max((nm, 1024))
        mi = J(outcap, 1, .)
        ui = J(outcap, 1, .)
    }
    else {
        // Assigned even though a dry run writes no pairs: the emit pass still
        // runs when using-side tracking is on, and Mata cannot pass an
        // unassigned variable.
        mi = J(0, 1, .)
        ui = J(0, 1, .)
    }

    for (i = 1; i <= nm; i++) {
        nmatch = counts_all[i]

        if (nmatch == 0) {
            if (keep_unmatched_master) {
                if (maxpairs > 0 & (n_pairs + 1) > maxpairs) {
                    st_framecurrent(oldframe)
                    st_local("_rm_err_maxpairs", "1")
                    st_local("_rm_n_pairs", strofreal(n_pairs + 1))
                    return
                }
                n_pairs++
                if (!dryrun) {
                    if (n_pairs > rows(mi)) {
                        mi = mi \ J(rows(mi), 1, .)
                        ui = ui \ J(rows(ui), 1, .)
                    }
                    mi[n_pairs] = M[i, 4]
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
            cursor[i] = n_pairs + 1
            n_pairs = n_pairs + nmatch
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

    // ---- Sweep pass 2: write the pairs into the reserved slots -------------
    // Skipped only when nothing could observe it: a dry run that tracks no
    // using-side state neither writes mi/ui nor reads matched_using.
    need_emit = ((!dryrun) | track_using)
    if (need_emit & n_matched_pairs > 0) {
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
            if (gid_i >= 1 & gid_i <= rows(vgstart_map)) {
                us = vgstart_map[gid_i]
                ue = vgend_map[gid_i]
            }
            if (us != 0) {
                _rm_overlap_emit_group(vmlo, vmhi, vmidx, vulo, vuhi, vuobs, ///
                    a, b, us, ue, both, mobs_all, cursor, mi, ui, ///
                    matched_using, track_using, dryrun)
            }
            a = b + 1
        }
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

    match_stats = _rm_compute_match_stats(match_counts, nm, max_gid, ///
        gstart_map, M, compute_stats)

    if (!dryrun) {
        st_framecurrent(out_frame)
        if (n_pairs > 0) {
            st_addobs(n_pairs)
        }
        (void) st_addvar("double", mi_var)
        (void) st_addvar("double", ui_var)
        if (n_pairs > 0) {
            st_store(., mi_var, mi[1..n_pairs])
            st_store(., ui_var, ui[1..n_pairs])
        }
    }

    st_framecurrent(oldframe)
    _rm_post_pair_results(n_pairs, n_matched_pairs, n_matched_master, ///
        n_matched_using, n_unmatched_master, n_unmatched_using, match_stats)
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


// Copy a value column from a thin work frame back to arbitrary observation
// positions in a destination frame. The group catalog avoids merge entirely:
// Stata's merge uses __000000-style internals that are global across frames and
// can delete a legal same-named user variable even when merge runs elsewhere.
void _rm_store_indexed(
    string scalar src_frame,
    string scalar obs_var,
    string scalar value_var,
    string scalar dest_frame,
    string scalar out_var)
{
    string scalar oldframe
    real colvector idx, values

    oldframe = st_framecurrent()
    st_framecurrent(src_frame)
    idx = st_data(., obs_var)
    values = st_data(., value_var)

    st_framecurrent(dest_frame)
    if (rows(idx) > 0) {
        if (any(idx :< 1) | any(idx :> st_nobs()) | any(idx :!= floor(idx))) {
            st_framecurrent(oldframe)
            _error(498)
        }
        st_store(idx, out_var, values)
    }
    st_framecurrent(oldframe)
}


// ============================================================================
// Value-label collision resolution.
//
// Value-label definitions are frame-scoped and keyed by name, so a using
// variable whose label name is already defined in the output frame (by a master
// variable materialized earlier) used to silently inherit the master's map: a
// carried code kept its number but acquired the master's meaning, or lost its
// meaning entirely. That is silent semantic corruption at rc=0 -- decode on the
// carried variable returns the wrong text.
//
// Definitions are therefore compared by value/text pairs. An identical
// definition is shared (the common case: both sides labelled from one codebook,
// which must NOT produce a rename). A genuine conflict gets the incoming
// definition copied under a collision-free name, and any later variable
// carrying that same map reuses the copy rather than minting another.
// ============================================================================

// Is the definition already stored under `nm' identical to (vals, txt)?
// Compared as ordered sets: st_vlload's row order is not part of the contract,
// but label codes are unique within a name, so order(vals, 1) has no ties and
// the comparison is deterministic.
real scalar _rm_vl_same(string scalar nm, real colvector vals,
    string colvector txt)
{
    real colvector evals, o1, o2
    string colvector etxt

    st_vlload(nm, evals, etxt)
    if (rows(evals) != rows(vals)) return(0)
    if (rows(vals) == 0) return(1)
    o1 = order(vals, 1)
    o2 = order(evals, 1)
    if (vals[o1] != evals[o2]) return(0)
    if (txt[o1] != etxt[o2]) return(0)
    return(1)
}

// The k-th collision-free candidate name derived from `base'. Stata caps label
// names at 32 characters, so the base is truncated to make room for the suffix
// rather than producing an over-long name that st_vlmodify would reject.
string scalar _rm_vl_candidate(string scalar base, real scalar k)
{
    string scalar sfx, b

    sfx = (k == 1 ? "_U" : "_U" + strofreal(k))
    b = base
    if (strlen(b) + strlen(sfx) > 32) {
        b = substr(b, 1, 32 - strlen(sfx))
    }
    return(b + sfx)
}

// Return the label name to attach in the CURRENT frame for a variable whose
// source definition is (vals, txt) under the name `vvl', creating or reusing a
// renamed copy on conflict.
string scalar _rm_vl_resolve(string scalar vvl, real colvector vals,
    string colvector txt)
{
    string scalar cand
    real scalar k

    if (!st_vlexists(vvl)) {
        st_vlmodify(vvl, vals, txt)
        return(vvl)
    }
    if (_rm_vl_same(vvl, vals, txt)) return(vvl)

    for (k = 1; k <= 999; k++) {
        cand = _rm_vl_candidate(vvl, k)
        if (!st_vlexists(cand)) {
            st_vlmodify(cand, vals, txt)
            return(cand)
        }
        if (_rm_vl_same(cand, vals, txt)) return(cand)
    }
    // Never pad or fall back to the wrong map: an unresolvable name must error
    // rather than silently attach a definition that means something else.
    _error("unable to derive a collision-free value-label name from " + vvl)
}

void _rm_materialize(
    string scalar out_frame,
    string scalar src_frame,
    string scalar index_var,
    string rowvector src_vars,
    string rowvector out_vars,
    string scalar widen_frame,
    string rowvector widen_vars
)
{
    string scalar oldframe, vtype, widen_type, fmt, vlbl, vvl
    string rowvector num_types, num_fmts, num_out
    real scalar j, k, nv, nout, vidx_src, vidx_out, nnum, all_valid
    real scalar type_rank, widen_rank, type_width, widen_width
    real scalar c0, c1, chunk_cols, havedef
    real rowvector num_src_idx, num_out_idx, src_chunk, out_chunk
    real colvector idx, valid_idx, vlvals
    real matrix nummat
    string colvector strcol, vltxt

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

        // Equality keys in a full-outer join are first materialized from the
        // master side and then filled from using-only rows. Choose the wider
        // storage type before creating the output variable. Doing this here is
        // deliberately stronger than Stata's recast command: recast allocates
        // global __000000-style work variables and can silently delete a legal
        // same-named variable from another frame.
        if (widen_frame != "" & any(widen_vars :== src_vars[j])) {
            st_framecurrent(widen_frame)
            widen_type = st_vartype(src_vars[j])
            if (substr(vtype, 1, 3) == "str" &
                    substr(widen_type, 1, 3) == "str") {
                type_width = strtoreal(substr(vtype, 4, .))
                widen_width = strtoreal(substr(widen_type, 4, .))
                if (widen_width > type_width) vtype = widen_type
            }
            else if (substr(vtype, 1, 3) != "str" &
                    substr(widen_type, 1, 3) != "str") {
                type_rank = (vtype == "byte" ? 1 :
                    (vtype == "int" ? 2 :
                    (vtype == "long" ? 3 :
                    (vtype == "float" ? 4 : 5))))
                widen_rank = (widen_type == "byte" ? 1 :
                    (widen_type == "int" ? 2 :
                    (widen_type == "long" ? 3 :
                    (widen_type == "float" ? 4 : 5))))
                if (widen_rank > type_rank) vtype = widen_type
            }
            st_framecurrent(src_frame)
        }
        fmt = st_varformat(src_vars[j])
        vlbl = st_varlabel(src_vars[j])
        vvl = st_varvaluelabel(src_vars[j])
        havedef = 0
        if (vvl != "") {
            havedef = st_vlexists(vvl)
            if (havedef) st_vlload(vvl, vlvals, vltxt)
        }
        vidx_src = st_varindex(src_vars[j])

        st_framecurrent(out_frame)
        (void) st_addvar(vtype, out_vars[j])
        vidx_out = st_varindex(out_vars[j])
        st_varformat(out_vars[j], fmt)
        if (vlbl != "") st_varlabel(out_vars[j], vlbl)
        if (vvl != "") {
            // Value-label definitions are frame-scoped; recreate the source
            // definition in the output frame, renaming it if the name is
            // already taken by a different map. A name attached in the source
            // but never defined there (havedef == 0) carries the dangling name
            // through unchanged, as before.
            if (havedef) vvl = _rm_vl_resolve(vvl, vlvals, vltxt)
            st_varvaluelabel(out_vars[j], vvl)
        }

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
        // Read the full key columns and subscript in Mata. The explicit
        // (idx, 1) row-subscript forces colvector semantics even when
        // master_key_vals or using_key_vals has only one element, where
        // v[idx] would otherwise resolve to row/col matrix subscripting
        // (a scalar v with a vector idx errors). Duplicate indices in idx
        // correctly yield one value per duplicate, so a using observation
        // matched to multiple master rows is handled.
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
    string scalar oldframe, vtype, vlbl, vvl
    real scalar j, nv, vidx, havedef
    real colvector numcol, vlvals
    string colvector strcol, vltxt

    oldframe = st_framecurrent()
    nv = cols(varnames)

    st_framecurrent(src_frame)

    for (j = 1; j <= nv; j++) {
        vtype = st_vartype(varnames[j])
        vidx = st_varindex(varnames[j])
        vlbl = st_varlabel(varnames[j])
        vvl = st_varvaluelabel(varnames[j])
        havedef = 0
        if (vvl != "") {
            havedef = st_vlexists(vvl)
            if (havedef) st_vlload(vvl, vlvals, vltxt)
        }

        if (substr(vtype, 1, 3) == "str") {
            strcol = st_sdata(., vidx)
            st_framecurrent(oldframe)
            st_sstore(., varnames[j], strcol)
        }
        else {
            numcol = st_data(., vidx)
            st_framecurrent(oldframe)
            st_store(., varnames[j], numcol)
        }
        // The destination frame was just cleared, wiping its value-label
        // definitions; restore labels from the output frame's copies.
        if (vlbl != "") st_varlabel(varnames[j], vlbl)
        if (vvl != "") {
            if (havedef & !st_vlexists(vvl)) st_vlmodify(vvl, vlvals, vltxt)
            st_varvaluelabel(varnames[j], vvl)
        }
        st_framecurrent(src_frame)
    }

    st_framecurrent(oldframe)
}

end
