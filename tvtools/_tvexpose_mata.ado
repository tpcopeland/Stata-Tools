*! _tvexpose_mata Version 1.17.8  2026/10/09
*! Mata functions for tvexpose performance optimization
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: utility (called internally by tvexpose)

/*
This file contains Mata functions for performance-critical operations in tvexpose:
  - Layer and priority() overlap resolution by one exact boundary sweep
  - Memory-efficient processing

These functions are called internally by tvexpose and should not be called directly.
The main performance improvement comes from replacing Stata forvalues loops with
compiled Mata code, which is 50-100x faster for row-by-row operations.

Performance targets:
  - 10K observations: <1 second (vs ~30 seconds with pure Stata loops)
  - 100K observations: <10 seconds (vs hours with pure Stata loops)
  - 1M observations: <2 minutes (vs infeasible with pure Stata loops)
*/

version 16.0

********************************************************************************
* MATA LIBRARY: tvexpose_mata
********************************************************************************

capture mata: mata drop tv_count_conflicts()
capture mata: mata drop tv_resolve_layer()
capture mata: mata drop tv_expand_units()

mata:
mata set matastrict on

// Count rows that overlap any earlier row for the same ID with a different
// exposure value. Data must be sorted by ID and start. This is a final
// correctness guard after the selected resolution algorithm has run.
void tv_count_conflicts(string scalar varnames)
{
    string rowvector vars
    real matrix data
    real scalar n, i, conflicts, current_id, current_value, current_stop
    real scalar max1_stop, max2_stop, max1_value, max2_value, swap_stop, swap_value

    vars = tokens(varnames)
    if (cols(vars) != 4) {
        errprintf("tv_count_conflicts requires id start stop exposure\n")
        exit(198)
    }

    data = st_data(., vars)
    n = rows(data)
    conflicts = 0
    current_id = .
    max1_stop = -1e300
    max2_stop = -1e300
    max1_value = .
    max2_value = .

    for (i = 1; i <= n; i++) {
        if (i == 1 || data[i, 1] != current_id) {
            current_id = data[i, 1]
            max1_stop = -1e300
            max2_stop = -1e300
            max1_value = .
            max2_value = .
        }

        current_value = data[i, 4]
        current_stop = data[i, 3]
        if ((max1_value != current_value && max1_stop >= data[i, 2]) ||
            (max1_value == current_value && max2_stop >= data[i, 2])) {
            conflicts++
        }

        if (max1_value == current_value) {
            max1_stop = max((max1_stop, current_stop))
        }
        else if (max2_value == current_value) {
            max2_stop = max((max2_stop, current_stop))
            if (max2_stop > max1_stop) {
                swap_stop = max1_stop
                swap_value = max1_value
                max1_stop = max2_stop
                max1_value = max2_value
                max2_stop = swap_stop
                max2_value = swap_value
            }
        }
        else if (current_stop > max1_stop) {
            max2_stop = max1_stop
            max2_value = max1_value
            max1_stop = current_stop
            max1_value = current_value
        }
        else if (current_stop > max2_stop) {
            max2_stop = current_stop
            max2_value = current_value
        }
    }
    st_numscalar("r(n_conflicts)", conflicts)
}

// Resolve overlap precedence by an exact boundary sweep. At every elementary
// interval, the active source row with the largest precedence key wins; ties
// use the later source-order value. Lower-precedence rows resume when the
// winning row ends.
//
// Input columns: numeric ID group, start, stop, exposure, source order, and an
// optional precedence key. Without the key (layer) the key is the start date,
// i.e. latest-record precedence. priority() passes a rank with the highest-
// priority value largest. Output overwrites the first five columns; the
// caller sorts by group/start/source and keeps the first r(n_layer) rows.
void tv_resolve_layer(string scalar varnames)
{
    string rowvector vars
    real matrix data, result
    real colvector gstart, gstop, gvalue, gsource, gkey, bounds, heap
    real scalar n, i, j, ng, p, k, b, segstop, winner, outn
    real scalar h, parent, left, right, best, swap, group_value, extend

    vars = tokens(varnames)
    if (cols(vars) != 5 && cols(vars) != 6) {
        errprintf("tv_resolve_layer requires group start stop exposure source [key]\n")
        exit(198)
    }

    data = st_data(., vars)
    n = rows(data)
    if (n == 0) {
        st_numscalar("r(n_layer)", 0)
        return
    }

    result = J(2 * n, 5, .)
    outn = 0
    i = 1

    while (i <= n) {
        j = i
        // Mata's logical operators do not short-circuit. Keep every boundary
        // guard outside the expression that performs the guarded subscript.
        while (j < n) {
            if (data[j + 1, 1] == data[i, 1]) j++
            else break
        }

        group_value = data[i, 1]
        gstart = data[|i, 2 \ j, 2|]
        gstop = data[|i, 3 \ j, 3|]
        gvalue = data[|i, 4 \ j, 4|]
        gsource = data[|i, 5 \ j, 5|]
        if (cols(vars) == 6) gkey = data[|i, 6 \ j, 6|]
        else gkey = gstart
        ng = rows(gstart)
        bounds = uniqrows(sort((gstart \ (gstop :+ 1)), 1))
        heap = J(0, 1, .)
        p = 1

        for (k = 1; k < rows(bounds); k++) {
            b = bounds[k]
            segstop = bounds[k + 1] - 1

            // Add every interval that has started. The max-heap key is
            // (key, source); for layer the key is the start date.
            while (p <= ng) {
                if (gstart[p] > b) break
                heap = heap \ p
                h = rows(heap)
                while (h > 1) {
                    parent = floor(h / 2)
                    if (gkey[heap[h]] > gkey[heap[parent]] ||
                        (gkey[heap[h]] == gkey[heap[parent]] &&
                         gsource[heap[h]] > gsource[heap[parent]])) {
                        swap = heap[parent]
                        heap[parent] = heap[h]
                        heap[h] = swap
                        h = parent
                    }
                    else break
                }
                p++
            }

            // Lazy deletion: expired lower-priority rows may remain below the
            // root, but they cannot win and are removed if they reach it.
            while (rows(heap) > 0) {
                if (gstop[heap[1]] >= b) break
                if (rows(heap) == 1) heap = J(0, 1, .)
                else {
                    heap[1] = heap[rows(heap)]
                    heap = heap[|1 \ rows(heap) - 1|]
                    h = 1
                    while (1) {
                        left = 2 * h
                        right = left + 1
                        best = h
                        if (left <= rows(heap)) {
                            if (gkey[heap[left]] > gkey[heap[best]] ||
                                (gkey[heap[left]] == gkey[heap[best]] &&
                                 gsource[heap[left]] > gsource[heap[best]])) {
                                best = left
                            }
                        }
                        if (right <= rows(heap)) {
                            if (gkey[heap[right]] > gkey[heap[best]] ||
                                (gkey[heap[right]] == gkey[heap[best]] &&
                                 gsource[heap[right]] > gsource[heap[best]])) {
                                best = right
                            }
                        }
                        if (best == h) break
                        swap = heap[h]
                        heap[h] = heap[best]
                        heap[best] = swap
                        h = best
                    }
                }
            }

            if (rows(heap) > 0) {
                if (b > segstop) continue
                winner = heap[1]
                extend = 0
                if (outn > 0) {
                    if (result[outn, 1] == group_value &&
                        result[outn, 4] == gvalue[winner] &&
                        result[outn, 3] + 1 == b) extend = 1
                }
                if (extend) {
                    result[outn, 3] = segstop
                }
                else {
                    outn++
                    result[outn, .] = (group_value, b, segstop,
                        gvalue[winner], gsource[winner])
                }
            }
        }
        i = j + 1
    }

    if (outn > st_nobs()) st_addobs(outn - st_nobs())
    st_store((1::outn), vars[|1 \ 5|], result[|1, 1 \ outn, 5|])
    st_numscalar("r(n_layer)", outn)
}

// ============================================================================
// tv_expand_units()
//
// Continuous-exposure expandunit() row generation. After the caller has
// expand-duplicated each exposed period into n_units rows and numbered them
// 1..n_units within (id, __period_id) as unit_seq, this fills the per-bin
// interval boundaries, parameterized by the average bin length in days (ulen =
// 7 / 30.4375 / 91.3125 / 365.25). The arithmetic is bit-identical to the
// former per-unit Stata blocks:
//     unit_start = floor(exp_start + (unit_seq - 1) * ulen)
//     unit_stop  = unit_seq < n_units ? floor(exp_start + unit_seq*ulen) - 1
//                                     : exp_stop
//
// varnames columns (zero-copy view, in order):
//   1=exp_start 2=exp_stop 3=n_units 4=unit_seq 5=unit_start[w] 6=unit_stop[w]
// Columns 5 and 6 are written in place.
// ============================================================================

void tv_expand_units(string scalar varnames, real scalar ulen)
{
    real matrix V
    string rowvector vars
    real scalar n, i, es, ex, nu, sq

    vars = tokens(varnames)
    if (length(vars) != 6) {
        errprintf("tv_expand_units requires 6 variables\n")
        exit(198)
    }

    st_view(V, ., vars)
    n = rows(V)
    for (i = 1; i <= n; i++) {
        es = V[i, 1]
        ex = V[i, 2]
        nu = V[i, 3]
        sq = V[i, 4]
        V[i, 5] = floor(es + (sq - 1) * ulen)
        V[i, 6] = (sq < nu ? floor(es + sq * ulen) - 1 : ex)
    }
}

end

********************************************************************************
* ADO WRAPPER PROGRAMS
********************************************************************************

capture program drop _tvexpose_mata_conflicts
program define _tvexpose_mata_conflicts, rclass
    version 16.0
    syntax varlist(numeric min=4 max=4)
    mata: tv_count_conflicts("`varlist'")
    return scalar n_conflicts = r(n_conflicts)
end

capture program drop _tvexpose_mata_layer
program define _tvexpose_mata_layer, rclass
    version 16.0
    syntax varlist(numeric min=5 max=6)
    mata: tv_resolve_layer("`varlist'")
    return scalar n_layer = r(n_layer)
end

// Program to fill expandunit() per-bin interval boundaries.
// Usage: _tvexpose_expand_units exp_start exp_stop n_units unit_seq ///
//            unit_start unit_stop , ulen(#)
//   unit_start and unit_stop (cols 5-6) are written in place.
capture program drop _tvexpose_expand_units
program define _tvexpose_expand_units
    version 16.0
    syntax varlist(min=6 max=6 numeric), ULEN(real)

    mata: tv_expand_units("`varlist'", `ulen')
end
