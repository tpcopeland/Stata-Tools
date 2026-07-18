*! _codescan_engine Version 4.0.1  2026/07/18
*! codescan Mata scanning engine (row-loop scan, co-occurrence, sensitivity)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: Mata function library for codescan

* =============================================================================
* MATA: Row-loop scanning engine with st_sview() + st_view()
* Kept in its own file (not inside codescan.ado) so codescan can recompile it
* after mata: mata clear / discard without re-running its own executing .ado.
* =============================================================================

mata:
// F7: cheap liveness ping. codescan calls this in a capture at start-up; if it
// is gone (mata: mata clear / discard dropped the engine while leaving the ado
// programs in place) codescan re-runs this file to recompile every function
// below. Kept out of codescan.ado because re-running the program's own
// executing .ado does not persist its freshly compiled Mata.
real scalar _codescan_mata_ready()
{
    return(1)
}

void _codescan_mata_scan()
{
    real scalar      ncond, nvars, N, i, j, k, len, npfx, enpfx
    real scalar      is_prefix, has_detail, has_excl, use_nocase, is_count, has_mcode
    real scalar      matched, excluded, strip_dots, all_slots, already
    string scalar    mode, touse_name, vcname, val, mcname, mc_name
    string rowvector scanvars, cond_names
    string colvector patterns, excl_patterns, anchored_pats, anchored_excl
    string colvector col
    string colvector mcode
    real matrix      indicators, varcounts
    real colvector   touse
    real rowvector   match_counts
    string rowvector pk, epk
    real rowvector   lk, elk
    transmorphic     A
    string colvector keys
    string scalar    dval
    real matrix      D
    real colvector   anymatch
    real scalar      didx, ndistinct, di

    // Read parameters from Stata locals
    ncond      = strtoreal(st_local("_mata_ncond"))
    mode       = st_local("_mata_mode")
    touse_name = st_local("_mata_touse")
    scanvars   = tokens(st_local("_mata_scanvars"))
    nvars      = cols(scanvars)
    N          = st_nobs()
    is_prefix  = (mode == "prefix")
    has_detail = (st_local("_mata_detail") != "")
    all_slots  = (st_local("_mata_allslots") != "")
    vcname     = st_local("_mata_vcname")
    use_nocase = (st_local("_mata_nocase") != "")
    strip_dots = (st_local("_mata_nodots") != "")
    is_count   = (st_local("_mata_countmode") != "")
    mcname     = st_local("_mata_matched_code")
    has_mcode  = (mcname != "")

    // Load condition definitions
    cond_names    = J(1, ncond, "")
    patterns      = J(ncond, 1, "")
    excl_patterns = J(ncond, 1, "")
    for (i = 1; i <= ncond; i++) {
        cond_names[i]    = st_local("_mata_name_" + strofreal(i))
        patterns[i]      = st_local("_mata_pat_" + strofreal(i))
        excl_patterns[i] = st_local("_mata_excl_" + strofreal(i))
    }

    // F1: prefix nocase uses unicode-aware case folding. Regex nocase is
    // implemented with ICU's inline (?i) flag below so escapes such as \d are
    // never corrupted by uppercasing the pattern to \D.
    if (use_nocase & is_prefix) {
        for (i = 1; i <= ncond; i++) {
            patterns[i] = ustrupper(patterns[i])
            if (excl_patterns[i] != "") {
                excl_patterns[i] = ustrupper(excl_patterns[i])
            }
        }
    }

    // Pre-build anchored regex patterns (avoid repeated string concat)
    if (!is_prefix) {
        anchored_pats = J(ncond, 1, "")
        anchored_excl = J(ncond, 1, "")
        for (i = 1; i <= ncond; i++) {
            anchored_pats[i] = (use_nocase ? "(?i)^(" : "^(") + patterns[i] + ")"
            if (excl_patterns[i] != "") {
                anchored_excl[i] = (use_nocase ? "(?i)^(" : "^(") + excl_patterns[i] + ")"
            }
        }
    }

    // Set up views: touse (read), indicators (read/write)
    touse = st_data(., touse_name)
    st_view(indicators, ., cond_names)

    // P1: Set up matched_code view for Mata-accelerated capture
    if (has_mcode) {
        st_sview(mcode, ., mcname)
    }

    // Check if any condition has exclusion patterns
    has_excl = 0
    for (i = 1; i <= ncond; i++) {
        if (excl_patterns[i] != "") {
            has_excl = 1
            break
        }
    }

    // Pre-parse prefix patterns (pipe-separated) into pointer arrays
    pointer(string rowvector) rowvector pfx_list, excl_pfx_list
    pointer(real rowvector) rowvector pfx_lens, excl_pfx_lens

    if (is_prefix) {
        pfx_list = J(1, ncond, NULL)
        pfx_lens = J(1, ncond, NULL)
        excl_pfx_list = J(1, ncond, NULL)
        excl_pfx_lens = J(1, ncond, NULL)
        for (i = 1; i <= ncond; i++) {
            pfx_list[i] = &_codescan_split_prefixes(patterns[i])
            pfx_lens[i] = &strlen(*pfx_list[i])
            if (excl_patterns[i] != "") {
                excl_pfx_list[i] = &_codescan_split_prefixes(excl_patterns[i])
                excl_pfx_lens[i] = &strlen(*excl_pfx_list[i])
            }
        }
    }

    // Initialize detail tracking
    if (has_detail) {
        varcounts = J(ncond, nvars, 0)
    }

    match_counts = J(1, ncond, 0)
    mc_name = st_local("_mata_mc_name")

    // ── DISTINCT-VALUE MEMOIZATION ──
    // A code's classification (matched AND NOT excluded, per condition) depends
    // ONLY on the string value, never on the row.  Registry data has millions of
    // cells but only a few thousand distinct codes, so we classify each distinct
    // (transformed) value once and reuse the result, turning the hot loop into a
    // hash lookup.  Results are byte-identical to a per-cell scan; only the cost
    // changes (O(distinct x ncond) pattern tests instead of O(N x nvars x ncond)).

    // Pass 1 — collect the distinct transformed values that will be scanned.
    A = asarray_create("string", 1)
    asarray_notfound(A, 0)
    for (j = 1; j <= nvars; j++) {
        st_sview(col, ., scanvars[j])
        for (i = 1; i <= N; i++) {
            if (!touse[i]) continue
            // Skip empty cells and bare "." placeholders (missing-value
            // convention in registry data).  This mirrors codescan_describe
            // so the exploration and scan tools agree on what is scannable.
            if (col[i] == "" | col[i] == ".") continue
            val = col[i]
            if (strip_dots) val = subinstr(val, ".", "", .)
            if (val == "") continue
            if (use_nocase & is_prefix) val = ustrupper(val)
            if (asarray(A, val) == 0) asarray(A, val, 1)
        }
    }

    // Pass 2 — classify each distinct value once into D[didx, k]; assign each
    // key its final index didx (1..ndistinct) in the asarray for O(1) lookup.
    keys      = asarray_keys(A)
    ndistinct = rows(keys)
    D         = J(ndistinct, ncond, 0)
    anymatch  = J(ndistinct, 1, 0)
    for (di = 1; di <= ndistinct; di++) {
        dval = keys[di]
        asarray(A, dval, di)
        for (k = 1; k <= ncond; k++) {
            // ── Inclusion check ──
            matched = 0
            if (is_prefix) {
                pk = *pfx_list[k]
                lk = *pfx_lens[k]
                npfx = cols(pk)
                for (len = 1; len <= npfx; len++) {
                    if (substr(dval, 1, lk[len]) == pk[len]) {
                        matched = 1
                        break
                    }
                }
            }
            else {
                // ustrregexm(): unicode-aware ICU engine. Returns 1/0 for valid
                // patterns (-1 only on an invalid pattern, which the validator
                // rejects up front); compare ==1 so any stray -1 is a non-match.
                if (ustrregexm(dval, anchored_pats[k]) == 1) matched = 1
            }
            if (!matched) continue

            // ── Exclusion check ──
            if (has_excl & excl_patterns[k] != "") {
                excluded = 0
                if (is_prefix) {
                    epk = *excl_pfx_list[k]
                    elk = *excl_pfx_lens[k]
                    enpfx = cols(epk)
                    for (len = 1; len <= enpfx; len++) {
                        if (substr(dval, 1, elk[len]) == epk[len]) {
                            excluded = 1
                            break
                        }
                    }
                }
                else {
                    // ==1 guard: a stray -1 must not exclude every value.
                    if (ustrregexm(dval, anchored_excl[k]) == 1) excluded = 1
                }
                if (excluded) continue
            }

            D[di, k] = 1
            anymatch[di] = 1
        }
    }

    // Pass 3 — apply.  Same j (variable) / i (row) / k (condition) nesting and
    // early-out as the original per-cell scan, so all ordering-dependent outputs
    // (matched_code first-hit, match_counts, varcounts) are preserved exactly.
    // The only change: the inline pattern test is now a D[didx, k] lookup.
    for (j = 1; j <= nvars; j++) {
        st_sview(col, ., scanvars[j])

        for (i = 1; i <= N; i++) {
            if (!touse[i]) continue
            // Guard MUST match Pass 1 exactly (same skip set), or a value
            // scanned here but absent from asarray A would return didx==0.
            if (col[i] == "" | col[i] == ".") continue

            val = col[i]
            if (strip_dots) val = subinstr(val, ".", "", .)
            if (val == "") continue
            if (use_nocase & is_prefix) val = ustrupper(val)
            didx = asarray(A, val)
            // Values that match no condition (common: codes in untargeted
            // chapters) skip the condition loop entirely.
            if (anymatch[didx] == 0) continue

            for (k = 1; k <= ncond; k++) {
                // Binary mode stops scanning a condition once it has matched
                // this row — the indicator cannot change again. That early exit
                // also hides the row's later slots from the detail tally, which
                // is why default detail attributes each row to the FIRST
                // matching scan variable in varlist order. all_slots keeps
                // walking the remaining slots for the tally only; the indicator
                // and match_counts are still written exactly once, so the
                // cohort is identical either way.
                already = (!is_count & indicators[i, k])
                if (already & !all_slots) continue
                if (!D[didx, k]) continue

                // ── Code passed inclusion and exclusion — record match ──
                if (is_count) {
                    if (indicators[i, k] == 0) match_counts[k] = match_counts[k] + 1
                    indicators[i, k] = indicators[i, k] + 1
                }
                else if (!already) {
                    match_counts[k] = match_counts[k] + 1
                    indicators[i, k] = 1
                }
                if (has_mcode & !already) {
                    if (mcode[i] == "") mcode[i] = col[i]
                }
                if (has_detail) varcounts[k, j] = varcounts[k, j] + 1
            }
        }
    }

    // Write detail matrix back to Stata
    if (has_detail) {
        st_matrix(vcname, varcounts)
    }
    if (mc_name != "") {
        st_matrix(mc_name, match_counts)
    }
}

// Helper: split pipe-separated prefix string into row vector of trimmed tokens
string rowvector _codescan_split_prefixes(string scalar s)
{
    string rowvector result
    string scalar    remaining, token
    real scalar      pos

    result = J(1, 0, "")
    remaining = s
    while (remaining != "") {
        pos = strpos(remaining, "|")
        if (pos > 0) {
            token = strtrim(substr(remaining, 1, pos - 1))
            remaining = substr(remaining, pos + 1, .)
        }
        else {
            token = strtrim(remaining)
            remaining = ""
        }
        if (token != "") {
            result = result, token
        }
    }
    return(result)
}

// P1: Compute co-occurrence matrix in a single Mata pass
void _codescan_mata_cooccurrence()
{
    string rowvector names
    string scalar    touse_name, coocname
    real scalar      ncond, N, i, j, is_count
    real matrix      ind, cooc, mask
    real colvector   touse

    names      = tokens(st_local("_mata_cooc_names"))
    ncond      = cols(names)
    touse_name = st_local("_mata_cooc_touse")
    coocname   = st_local("_mata_cooc_matname")
    is_count   = (st_local("_mata_cooc_countmode") != "")

    st_view(ind, ., names)
    N = rows(ind)

    // Binarize counts for co-occurrence (countmode stores counts, not 0/1)
    if (is_count) {
        mask = (ind :> 0)
    }
    else {
        mask = ind
    }

    if (touse_name != "") {
        touse = st_data(., touse_name)
        mask = mask :* touse
    }

    // cross(mask, mask) gives ncond × ncond co-occurrence counts
    cooc = cross(mask, mask)
    st_matrix(coocname, cooc)
}

// Multi-window sensitivity: count per-window matches in a single pass.
// For collapse/merge, counts at patient level (unique IDs per window).
// For row-level, counts observations per window.
// Reads primary indicators + supplementary indicators (from union scan).
void _codescan_mata_sensitivity_count()
{
    real scalar ncond, nwindows, N, i, j, k, w
    real scalar do_collapse, has_supp, id_is_str, new_patient
    string rowvector ind_names, supp_names
    string scalar id_name, counts_name, ns_name, primary_touse_name
    real matrix indicators, supp_ind, touse_w, counts
    real colvector primary_touse, sort_idx, num_ids
    real rowvector N_per_window, in_window
    real matrix matched
    string colvector str_ids

    ncond = strtoreal(st_local("_sens_ncond"))
    nwindows = strtoreal(st_local("_sens_nwindows"))
    N = st_nobs()
    do_collapse = strtoreal(st_local("_sens_do_collapse"))
    id_name = st_local("_sens_id")
    counts_name = st_local("_sens_counts_name")
    ns_name = st_local("_sens_ns_name")
    primary_touse_name = st_local("_sens_primary_touse")

    ind_names = tokens(st_local("_sens_ind_names"))
    st_view(indicators, ., ind_names)

    supp_names = tokens(st_local("_sens_supp_names"))
    has_supp = (cols(supp_names) > 0)
    if (has_supp) {
        if (supp_names[1] == "") has_supp = 0
    }
    if (has_supp) {
        st_view(supp_ind, ., supp_names)
    }

    primary_touse = st_data(., primary_touse_name)

    // Build touse matrix: column 1 = primary, columns 2..nwindows = secondary
    touse_w = J(N, nwindows, 0)
    touse_w[., 1] = primary_touse
    for (w = 2; w <= nwindows; w++) {
        touse_w[., w] = st_data(., st_local("_sens_touse_" + strofreal(w)))
    }

    counts = J(ncond, nwindows, 0)
    N_per_window = J(1, nwindows, 0)

    if (do_collapse && id_name != "") {
        // Patient-level counting: sort by ID, scan for unique patients
        id_is_str = st_isstrvar(id_name)

        if (id_is_str) {
            str_ids = st_sdata(., id_name)
            sort_idx = order(str_ids, 1)
        }
        else {
            num_ids = st_data(., id_name)
            sort_idx = order(num_ids, 1)
        }
        in_window = J(1, nwindows, 0)
        matched = J(nwindows, ncond, 0)

        for (j = 1; j <= N; j++) {
            i = sort_idx[j]

            // Detect new patient
            if (j == 1) {
                new_patient = 1
            }
            else if (id_is_str) {
                new_patient = (str_ids[i] != str_ids[sort_idx[j - 1]])
            }
            else {
                new_patient = (num_ids[i] != num_ids[sort_idx[j - 1]])
            }

            if (new_patient && j > 1) {
                for (w = 1; w <= nwindows; w++) {
                    if (in_window[w]) {
                        N_per_window[w] = N_per_window[w] + 1
                        for (k = 1; k <= ncond; k++) {
                            if (matched[w, k]) counts[k, w] = counts[k, w] + 1
                        }
                    }
                }
                in_window = J(1, nwindows, 0)
                matched = J(nwindows, ncond, 0)
            }

            for (w = 1; w <= nwindows; w++) {
                if (touse_w[i, w]) {
                    in_window[w] = 1
                    for (k = 1; k <= ncond; k++) {
                        if (!matched[w, k]) {
                            if (indicators[i, k] > 0) {
                                matched[w, k] = 1
                            }
                            else if (has_supp) {
                                if (supp_ind[i, k] > 0) matched[w, k] = 1
                            }
                        }
                    }
                }
            }
        }
        // Commit last patient
        if (N > 0) {
            for (w = 1; w <= nwindows; w++) {
                if (in_window[w]) {
                    N_per_window[w] = N_per_window[w] + 1
                    for (k = 1; k <= ncond; k++) {
                        if (matched[w, k]) counts[k, w] = counts[k, w] + 1
                    }
                }
            }
        }
    }
    else {
        // Row-level counting
        for (i = 1; i <= N; i++) {
            for (w = 1; w <= nwindows; w++) {
                if (touse_w[i, w]) {
                    N_per_window[w] = N_per_window[w] + 1
                    for (k = 1; k <= ncond; k++) {
                        if (indicators[i, k] > 0) {
                            counts[k, w] = counts[k, w] + 1
                        }
                        else if (has_supp) {
                            if (supp_ind[i, k] > 0) counts[k, w] = counts[k, w] + 1
                        }
                    }
                }
            }
        }
    }

    st_matrix(counts_name, counts)
    st_matrix(ns_name, N_per_window)
}
end
