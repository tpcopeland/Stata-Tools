*! _tabtools_smallcells Version 2.1.1  2026/09/04
*! Exact-disclosure suppression engine for tabtools count blocks
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_smallcells, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax, COUNTS(name) SMALLCells(integer) ///
            [ EXACT(name) SENSitive(name) ///
              ROWEXact(name) ROWSENsitive(name) ///
              COLEXact(name) COLSENsitive(name) ///
              GRANDExact(integer 0) GRANDSensitive(integer 0) ]

        if `smallcells' < 3 {
            display as error "smallcells() must be an integer greater than or equal to 3"
            exit 198
        }
        if !inlist(`grandexact', 0, 1) | !inlist(`grandsensitive', 0, 1) {
            display as error "grand-margin flags must be 0 or 1"
            exit 198
        }

        capture confirm matrix `counts'
        if _rc {
            display as error "counts() must name an existing matrix"
            exit 198
        }

        local nr = rowsof(`counts')
        local nc = colsof(`counts')
        if `nr' < 1 | `nc' < 1 {
            display as error "counts() must be a nonempty matrix"
            exit 198
        }

        tempname exact_m sensitive_m rowexact_m rowsens_m colexact_m colsens_m
        if "`exact'" == "" matrix `exact_m' = J(`nr', `nc', 1)
        else {
            capture confirm matrix `exact'
            if _rc {
                display as error "exact() must name an existing matrix"
                exit 198
            }
            matrix `exact_m' = `exact'
        }
        if "`sensitive'" == "" matrix `sensitive_m' = J(`nr', `nc', 1)
        else {
            capture confirm matrix `sensitive'
            if _rc {
                display as error "sensitive() must name an existing matrix"
                exit 198
            }
            matrix `sensitive_m' = `sensitive'
        }
        if "`rowexact'" == "" matrix `rowexact_m' = J(`nr', 1, 0)
        else {
            capture confirm matrix `rowexact'
            if _rc {
                display as error "rowexact() must name an existing matrix"
                exit 198
            }
            matrix `rowexact_m' = `rowexact'
        }
        if "`rowsensitive'" == "" matrix `rowsens_m' = J(`nr', 1, 0)
        else {
            capture confirm matrix `rowsensitive'
            if _rc {
                display as error "rowsensitive() must name an existing matrix"
                exit 198
            }
            matrix `rowsens_m' = `rowsensitive'
        }
        if "`colexact'" == "" matrix `colexact_m' = J(1, `nc', 0)
        else {
            capture confirm matrix `colexact'
            if _rc {
                display as error "colexact() must name an existing matrix"
                exit 198
            }
            matrix `colexact_m' = `colexact'
        }
        if "`colsensitive'" == "" matrix `colsens_m' = J(1, `nc', 0)
        else {
            capture confirm matrix `colsensitive'
            if _rc {
                display as error "colsensitive() must name an existing matrix"
                exit 198
            }
            matrix `colsens_m' = `colsensitive'
        }

        tempname mask rowmask colmask status totalmask nprimary nsecondary
        mata: st_numscalar("`status'", _ttsc_run( ///
            st_matrix("`counts'"), st_matrix("`exact_m'"), ///
            st_matrix("`sensitive_m'"), st_matrix("`rowexact_m'"), ///
            st_matrix("`rowsens_m'"), st_matrix("`colexact_m'"), ///
            st_matrix("`colsens_m'"), `grandexact', `grandsensitive', ///
            `smallcells', "`mask'", "`rowmask'", "`colmask'", ///
            "`totalmask'", "`nprimary'", "`nsecondary'"))

        if scalar(`status') == -1 {
            display as error "smallcells(): counts and masks must be conformable nonnegative integer/binary matrices"
            exit 198
        }
        if scalar(`status') == 0 {
            display as error "smallcells(): exact-disclosure protection could not be certified for this count block"
            exit 498
        }

        return scalar smallcells = `smallcells'
        return scalar N_primary_suppressed = scalar(`nprimary')
        return scalar N_secondary_suppressed = scalar(`nsecondary')
        return scalar totalmask = scalar(`totalmask')
        return matrix mask = `mask'
        return matrix rowmask = `rowmask'
        return matrix colmask = `colmask'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _ttsc_add_edge()
capture mata: mata drop _ttsc_maxflow()
capture mata: mata drop _ttsc_bounds()
capture mata: mata drop _ttsc_feasible()
capture mata: mata drop _ttsc_has_alternative()
capture mata: mata drop _ttsc_failures()
capture mata: mata drop _ttsc_valid_binary()
capture mata: mata drop _ttsc_run()

mata:
mata set matastrict on

void _ttsc_add_edge(
    real matrix capacity,
    real colvector balance,
    real scalar from,
    real scalar to,
    real scalar lower,
    real scalar upper)
{
    capacity[from, to] = capacity[from, to] + upper - lower
    balance[from] = balance[from] - lower
    balance[to] = balance[to] + lower
}

real scalar _ttsc_maxflow(real matrix capacity, real scalar source, real scalar sink)
{
    real scalar n, head, tail, u, v, aug, flow
    real colvector parent, queue

    n = rows(capacity)
    flow = 0
    while (1) {
        parent = J(n, 1, 0)
        queue = J(n, 1, 0)
        head = 1
        tail = 1
        queue[1] = source
        parent[source] = -1
        while (head <= tail & parent[sink] == 0) {
            u = queue[head]
            head++
            for (v = 1; v <= n; v++) {
                if (parent[v] == 0 & capacity[u, v] > 1e-9) {
                    parent[v] = u
                    tail++
                    queue[tail] = v
                    if (v == sink) break
                }
            }
        }
        if (parent[sink] == 0) break

        aug = .
        v = sink
        while (v != source) {
            u = parent[v]
            if (missing(aug) | capacity[u, v] < aug) aug = capacity[u, v]
            v = u
        }
        v = sink
        while (v != source) {
            u = parent[v]
            capacity[u, v] = capacity[u, v] - aug
            capacity[v, u] = capacity[v, u] + aug
            v = u
        }
        flow = flow + aug
    }
    return(flow)
}

real rowvector _ttsc_bounds(
    real scalar actual,
    real scalar state,
    real scalar k,
    real scalar upper)
{
    if (state == 0) return((actual, actual))
    if (state == 1) return((1, k - 1))
    if (state == 2) return((k, upper))
    return((0, upper))
}

real scalar _ttsc_feasible(
    real matrix counts,
    real matrix state,
    real colvector rowstate,
    real rowvector colstate,
    real scalar grandstate,
    real scalar k,
    real scalar target_kind,
    real scalar target_i,
    real scalar target_j,
    real scalar target_value)
{
    real scalar nr, nc, source, first_row, first_col, sink
    real scalar super_source, super_sink, n, i, j, total_need, flow, upper
    real rowvector bounds
    real matrix capacity
    real colvector balance, rowtotals
    real rowvector coltotals

    nr = rows(counts)
    nc = cols(counts)
    upper = sum(counts) + 2 * k * (nr * nc + nr + nc + 1) + 10
    if (upper < k + 1) upper = k + 1

    source = 1
    first_row = 2
    first_col = first_row + nr
    sink = first_col + nc
    super_source = sink + 1
    super_sink = sink + 2
    n = super_sink
    capacity = J(n, n, 0)
    balance = J(n, 1, 0)
    rowtotals = rowsum(counts)
    coltotals = colsum(counts)

    for (i = 1; i <= nr; i++) {
        bounds = _ttsc_bounds(rowtotals[i], rowstate[i], k, upper)
        if (target_kind == 1 & target_i == i) bounds = (target_value, target_value)
        _ttsc_add_edge(capacity, balance, source, first_row + i - 1, bounds[1], bounds[2])
    }
    for (i = 1; i <= nr; i++) {
        for (j = 1; j <= nc; j++) {
            bounds = _ttsc_bounds(counts[i, j], state[i, j], k, upper)
            if (target_kind == 0 & target_i == i & target_j == j) bounds = (target_value, target_value)
            _ttsc_add_edge(capacity, balance, first_row + i - 1, ///
                first_col + j - 1, bounds[1], bounds[2])
        }
    }
    for (j = 1; j <= nc; j++) {
        bounds = _ttsc_bounds(coltotals[j], colstate[j], k, upper)
        if (target_kind == 2 & target_j == j) bounds = (target_value, target_value)
        _ttsc_add_edge(capacity, balance, first_col + j - 1, sink, bounds[1], bounds[2])
    }
    bounds = _ttsc_bounds(sum(counts), grandstate, k, upper)
    if (target_kind == 3) bounds = (target_value, target_value)
    _ttsc_add_edge(capacity, balance, sink, source, bounds[1], bounds[2])

    total_need = 0
    for (i = 1; i <= sink; i++) {
        if (balance[i] > 1e-9) {
            capacity[super_source, i] = capacity[super_source, i] + balance[i]
            total_need = total_need + balance[i]
        }
        else if (balance[i] < -1e-9) {
            capacity[i, super_sink] = capacity[i, super_sink] - balance[i]
        }
    }
    flow = _ttsc_maxflow(capacity, super_source, super_sink)
    return(abs(flow - total_need) <= 1e-8)
}

real scalar _ttsc_has_alternative(
    real matrix counts,
    real matrix state,
    real colvector rowstate,
    real rowvector colstate,
    real scalar grandstate,
    real scalar k,
    real scalar target_kind,
    real scalar target_i,
    real scalar target_j,
    real scalar actual)
{
    if (actual > 1) {
        if (_ttsc_feasible(counts, state, rowstate, colstate, grandstate, ///
            k, target_kind, target_i, target_j, actual - 1)) return(1)
    }
    if (actual < k - 1) {
        if (_ttsc_feasible(counts, state, rowstate, colstate, grandstate, ///
            k, target_kind, target_i, target_j, actual + 1)) return(1)
    }
    return(0)
}

real scalar _ttsc_failures(
    real matrix counts,
    real matrix state,
    real colvector rowstate,
    real rowvector colstate,
    real scalar grandstate,
    real scalar k)
{
    real scalar i, j, failures
    real colvector rowtotals
    real rowvector coltotals

    failures = 0
    rowtotals = rowsum(counts)
    coltotals = colsum(counts)
    for (i = 1; i <= rows(counts); i++) {
        for (j = 1; j <= cols(counts); j++) {
            if (state[i, j] == 1) {
                if (!_ttsc_has_alternative(counts, state, rowstate, colstate, ///
                    grandstate, k, 0, i, j, counts[i, j])) failures++
            }
        }
    }
    for (i = 1; i <= rows(rowstate); i++) {
        if (rowstate[i] == 1) {
            if (!_ttsc_has_alternative(counts, state, rowstate, colstate, ///
                grandstate, k, 1, i, 0, rowtotals[i])) failures++
        }
    }
    for (j = 1; j <= cols(colstate); j++) {
        if (colstate[j] == 1) {
            if (!_ttsc_has_alternative(counts, state, rowstate, colstate, ///
                grandstate, k, 2, 0, j, coltotals[j])) failures++
        }
    }
    if (grandstate == 1) {
        if (!_ttsc_has_alternative(counts, state, rowstate, colstate, ///
            grandstate, k, 3, 0, 0, sum(counts))) failures++
    }
    return(failures)
}

real scalar _ttsc_valid_binary(real matrix x)
{
    if (any(x :>= .)) return(0)
    if (any((x :!= 0) :& (x :!= 1))) return(0)
    return(1)
}

real scalar _ttsc_run(
    real matrix counts,
    real matrix exact,
    real matrix sensitive,
    real colvector rowexact,
    real colvector rowsensitive,
    real rowvector colexact,
    real rowvector colsensitive,
    real scalar grandexact,
    real scalar grandsensitive,
    real scalar k,
    string scalar mask_name,
    string scalar rowmask_name,
    string scalar colmask_name,
    string scalar totalmask_name,
    string scalar nprimary_name,
    string scalar nsecondary_name)
{
    real scalar nr, nc, i, j, changed, free_count, candidate
    real scalar failures, trial_failures, chosen, idx, n_candidates
    real scalar grandstate, totalmask, nprimary, nsecondary
    real matrix state, trial, candidates
    real colvector rowstate, rowtotals
    real rowvector colstate, coltotals
    real matrix mask
    real colvector rowmask
    real rowvector colmask

    nr = rows(counts)
    nc = cols(counts)
    if (nr < 1 | nc < 1) return(-1)
    if (rows(exact) != nr | cols(exact) != nc) return(-1)
    if (rows(sensitive) != nr | cols(sensitive) != nc) return(-1)
    if (rows(rowexact) != nr | cols(rowexact) != 1) return(-1)
    if (rows(rowsensitive) != nr | cols(rowsensitive) != 1) return(-1)
    if (rows(colexact) != 1 | cols(colexact) != nc) return(-1)
    if (rows(colsensitive) != 1 | cols(colsensitive) != nc) return(-1)
    if (any(counts :>= .) | any(counts :< 0) | any(counts :!= floor(counts))) return(-1)
    if (!_ttsc_valid_binary(exact) | !_ttsc_valid_binary(sensitive)) return(-1)
    if (!_ttsc_valid_binary(rowexact) | !_ttsc_valid_binary(rowsensitive)) return(-1)
    if (!_ttsc_valid_binary(colexact) | !_ttsc_valid_binary(colsensitive)) return(-1)
    if ((grandexact != 0 & grandexact != 1) | ///
        (grandsensitive != 0 & grandsensitive != 1)) return(-1)

    rowtotals = rowsum(counts)
    coltotals = colsum(counts)
    state = J(nr, nc, -1)
    for (i = 1; i <= nr; i++) {
        for (j = 1; j <= nc; j++) {
            if (sensitive[i, j] & counts[i, j] > 0 & counts[i, j] < k) state[i, j] = 1
            else if (exact[i, j]) state[i, j] = 0
        }
    }
    rowstate = J(nr, 1, -1)
    for (i = 1; i <= nr; i++) {
        if (rowsensitive[i] & rowtotals[i] > 0 & rowtotals[i] < k) rowstate[i] = 1
        else if (rowexact[i]) rowstate[i] = 0
    }
    colstate = J(1, nc, -1)
    for (j = 1; j <= nc; j++) {
        if (colsensitive[j] & coltotals[j] > 0 & coltotals[j] < k) colstate[j] = 1
        else if (colexact[j]) colstate[j] = 0
    }
    if (grandsensitive & sum(counts) > 0 & sum(counts) < k) grandstate = 1
    else if (grandexact) grandstate = 0
    else grandstate = -1

    changed = 1
    while (changed) {
        changed = 0
        for (i = 1; i <= nr; i++) {
            if (rowstate[i] != 0 | !any(state[i, .] :== 1)) continue
            free_count = sum(state[i, .] :!= 0)
            if (free_count != 1) continue
            candidate = 0
            for (j = 1; j <= nc; j++) {
                if (state[i, j] == 0 & exact[i, j] & counts[i, j] >= k) {
                    if (candidate == 0) candidate = j
                    else if (counts[i, j] < counts[i, candidate]) candidate = j
                }
            }
            if (candidate > 0) {
                state[i, candidate] = 2
                changed = 1
            }
        }
        for (j = 1; j <= nc; j++) {
            if (colstate[j] != 0 | !any(state[, j] :== 1)) continue
            free_count = sum(state[, j] :!= 0)
            if (free_count != 1) continue
            candidate = 0
            for (i = 1; i <= nr; i++) {
                if (state[i, j] == 0 & exact[i, j] & counts[i, j] >= k) {
                    if (candidate == 0) candidate = i
                    else if (counts[i, j] < counts[candidate, j]) candidate = i
                }
            }
            if (candidate > 0) {
                state[candidate, j] = 2
                changed = 1
            }
        }
        if (grandstate == 0 & any(state :== 1) & sum(state :!= 0) == 1) {
            candidate = 0
            for (i = 1; i <= nr; i++) {
                for (j = 1; j <= nc; j++) {
                    if (state[i, j] == 0 & exact[i, j] & counts[i, j] >= k) {
                        if (candidate == 0) {
                            candidates = (counts[i, j], i, j)
                            candidate = 1
                        }
                        else if (counts[i, j] < candidates[1, 1]) {
                            candidates = (counts[i, j], i, j)
                        }
                    }
                }
            }
            if (candidate > 0) {
                state[candidates[1, 2], candidates[1, 3]] = 2
                changed = 1
            }
        }
    }

    failures = _ttsc_failures(counts, state, rowstate, colstate, grandstate, k)
    while (failures > 0) {
        candidates = J(0, 3, .)
        for (i = 1; i <= nr; i++) {
            for (j = 1; j <= nc; j++) {
                if (state[i, j] == 0 & exact[i, j] & counts[i, j] >= k) {
                    candidates = candidates \ (counts[i, j], i, j)
                }
            }
        }
        n_candidates = rows(candidates)
        if (n_candidates == 0) break
        candidates = candidates[order(candidates, (1, 2, 3)), .]
        chosen = 0
        for (idx = 1; idx <= n_candidates; idx++) {
            trial = state
            trial[candidates[idx, 2], candidates[idx, 3]] = 2
            trial_failures = _ttsc_failures(counts, trial, rowstate, colstate, grandstate, k)
            if (trial_failures < failures) {
                chosen = idx
                break
            }
        }
        if (chosen == 0) chosen = 1
        state[candidates[chosen, 2], candidates[chosen, 3]] = 2
        failures = _ttsc_failures(counts, state, rowstate, colstate, grandstate, k)
    }

    if (failures > 0) {
        for (i = 1; i <= nr; i++) {
            for (j = 1; j <= nc; j++) {
                if (state[i, j] == 0 & exact[i, j] & counts[i, j] > 0) {
                    state[i, j] = (counts[i, j] < k ? 1 : 2)
                }
            }
            if (rowstate[i] == 0 & rowexact[i] & rowtotals[i] > 0) {
                rowstate[i] = (rowtotals[i] < k ? 1 : 2)
            }
        }
        for (j = 1; j <= nc; j++) {
            if (colstate[j] == 0 & colexact[j] & coltotals[j] > 0) {
                colstate[j] = (coltotals[j] < k ? 1 : 2)
            }
        }
        if (grandstate == 0 & grandexact & sum(counts) > 0) {
            grandstate = (sum(counts) < k ? 1 : 2)
        }
        failures = _ttsc_failures(counts, state, rowstate, colstate, grandstate, k)
    }
    if (failures > 0) return(0)

    // Remove every individually redundant complementary marker. Candidate
    // cells and margins are revealed in a stable order; each reveal is kept
    // only when all primary suppressions remain non-exact.
    changed = 1
    while (changed) {
        changed = 0
        for (i = 1; i <= nr; i++) {
            for (j = 1; j <= nc; j++) {
                if (state[i, j] != 2) continue
                state[i, j] = 0
                failures = _ttsc_failures(counts, state, rowstate, ///
                    colstate, grandstate, k)
                if (failures == 0) changed = 1
                else state[i, j] = 2
            }
        }
        for (i = 1; i <= nr; i++) {
            if (rowstate[i] != 2) continue
            rowstate[i] = 0
            failures = _ttsc_failures(counts, state, rowstate, ///
                colstate, grandstate, k)
            if (failures == 0) changed = 1
            else rowstate[i] = 2
        }
        for (j = 1; j <= nc; j++) {
            if (colstate[j] != 2) continue
            colstate[j] = 0
            failures = _ttsc_failures(counts, state, rowstate, ///
                colstate, grandstate, k)
            if (failures == 0) changed = 1
            else colstate[j] = 2
        }
        if (grandstate == 2) {
            grandstate = 0
            failures = _ttsc_failures(counts, state, rowstate, ///
                colstate, grandstate, k)
            if (failures == 0) changed = 1
            else grandstate = 2
        }
    }
    failures = _ttsc_failures(counts, state, rowstate, colstate, grandstate, k)
    if (failures > 0) return(0)

    mask = (state :>= 0) :* state
    rowmask = (rowstate :>= 0) :* rowstate
    colmask = (colstate :>= 0) :* colstate
    totalmask = (grandstate < 0 ? 0 : grandstate)
    nprimary = sum(mask :== 1) + sum(rowmask :== 1) + sum(colmask :== 1) + (totalmask == 1)
    nsecondary = sum(mask :== 2) + sum(rowmask :== 2) + sum(colmask :== 2) + (totalmask == 2)

    st_matrix(mask_name, mask)
    st_matrix(rowmask_name, rowmask)
    st_matrix(colmask_name, colmask)
    st_numscalar(totalmask_name, totalmask)
    st_numscalar(nprimary_name, nprimary)
    st_numscalar(nsecondary_name, nsecondary)
    return(1)
}
end
