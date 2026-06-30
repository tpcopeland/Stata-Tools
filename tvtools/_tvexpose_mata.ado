*! _tvexpose_mata Version 1.6.4  2026/07/01
*! Mata functions for tvexpose performance optimization
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: utility (called internally by tvexpose)

/*
This file contains Mata functions for performance-critical operations in tvexpose:
  - Priority-based overlap detection (O(n log n) instead of O(n²))
  - Interval resolution for overlapping periods
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

capture mata: mata drop tv_detect_overlaps_priority()
capture mata: mata drop tv_resolve_overlaps_priority()
capture mata: mata drop tv_process_priority_overlaps()
capture mata: mata drop tv_count_overlaps()
capture mata: mata drop tv_expand_units()

mata:
mata set matastrict on

// ============================================================================
// tv_detect_overlaps_priority()
//
// Detects overlapping intervals where a lower-priority interval overlaps
// with a higher-priority interval within the same ID group.
//
// Algorithm: O(k) per row within an ID group where k is group size.
// Overall O(n*k) where k is the max group size; O(n^2) worst case if all rows
// share one ID. Efficient in practice since groups are typically small.
// Data must be sorted by (id, priority_rank, start) before calling.
//
// Arguments:
//   data         - Matrix with columns: [id, start, stop, priority_rank]
//   id_col       - Column index for ID variable (1-based)
//   start_col    - Column index for start date (1-based)
//   stop_col     - Column index for stop date (1-based)
//   priority_col - Column index for priority rank (1-based, lower = higher priority)
//
// Returns:
//   Matrix with columns: [overlaps_higher, first_overlap_row]
// ============================================================================

real matrix tv_detect_overlaps_priority(real matrix data,
                                        real scalar id_col,
                                        real scalar start_col,
                                        real scalar stop_col,
                                        real scalar priority_col)
{
    real scalar n, i, j, curr_id, curr_start, curr_stop, curr_rank
    real scalar high_start, high_stop
    real scalar pshow, pstep, pnext, plast, ppct
    real matrix result
    real colvector id_vec, start_vec, stop_vec, rank_vec

    n = rows(data)
    if (n == 0) return(J(0, 2, 0))

    // Extract columns for faster access (avoids repeated indexing)
    id_vec = data[., id_col]
    start_vec = data[., start_col]
    stop_vec = data[., stop_col]
    rank_vec = data[., priority_col]

    // Result matrix: [overlaps_higher, first_overlap_row]
    result = J(n, 2, 0)

    // One-line progress for large inputs only (the caller invokes this noisily,
    // so the line surfaces on a normal run and is suppressed under `quietly').
    pshow = (n > 100000)
    if (pshow) {
        pstep = ceil(n / 10)
        pnext = pstep
        plast = 0
        printf("{txt}    Overlap-resolution progress:")
        displayflush()
    }

    // For each row, check if it overlaps with any EARLIER (higher priority) row
    // Data must be sorted by id, priority_rank, start before calling
    for (i = 2; i <= n; i++) {
        if (pshow & i >= pnext) {
            ppct = min((100, floor(100 * i / n)))
            printf(" %g%%", ppct)
            displayflush()
            plast = ppct
            pnext = pnext + pstep
        }
        curr_id = id_vec[i]
        curr_start = start_vec[i]
        curr_stop = stop_vec[i]
        curr_rank = rank_vec[i]

        // Scan backwards from current row
        for (j = i - 1; j >= 1; j--) {
            // Stop if we hit a different ID (data is sorted by ID)
            if (id_vec[j] != curr_id) break

            // Only consider higher priority (lower rank) rows
            if (rank_vec[j] < curr_rank) {
                high_start = start_vec[j]
                high_stop = stop_vec[j]

                // Check for overlap: intervals overlap if they share any time
                if (curr_start <= high_stop && curr_stop >= high_start) {
                    result[i, 1] = 1           // overlaps_higher = 1
                    result[i, 2] = j           // first_overlap_row
                    break                       // Found first overlap, stop searching
                }
            }
        }
    }

    if (pshow) {
        if (plast < 100) printf(" 100%%")
        printf("\n")
        displayflush()
    }

    return(result)
}


// ============================================================================
// tv_resolve_overlaps_priority()
//
// Resolves overlaps by adjusting lower-priority intervals.
// This implements the same logic as the Stata forvalues loop but much faster.
//
// Cases handled:
//   1. Higher covers lower completely -> mark lower as invalid (valid=0)
//   2. Higher starts after lower start -> truncate lower's stop
//   3. Higher ends before lower ends -> truncate lower's start
//   4. Higher is in middle of lower -> truncate lower's stop (keep pre-portion)
//
// Arguments:
//   data         - Matrix with columns: [id, start, stop, priority_rank]
//   overlap_info - Result from tv_detect_overlaps_priority() [overlaps_higher, first_overlap_row]
//   start_col    - Column index for start date (1-based)
//   stop_col     - Column index for stop date (1-based)
//
// Returns:
//   Matrix with columns: [adjusted_start, adjusted_stop, valid]
// ============================================================================

real matrix tv_resolve_overlaps_priority(real matrix data,
                                         real matrix overlap_info,
                                         real scalar start_col,
                                         real scalar stop_col)
{
    real scalar n, i, curr_start, curr_stop, overlap_row
    real scalar high_start, high_stop
    real matrix result
    real colvector start_vec, stop_vec

    n = rows(data)
    if (n == 0) return(J(0, 3, .))

    // Extract columns
    start_vec = data[., start_col]
    stop_vec = data[., stop_col]

    // Result: [adjusted_start, adjusted_stop, valid]
    result = J(n, 3, .)
    result[., 1] = start_vec        // default: no adjustment to start
    result[., 2] = stop_vec         // default: no adjustment to stop
    result[., 3] = J(n, 1, 1)       // all valid by default

    for (i = 1; i <= n; i++) {
        // Only process rows that overlap with higher priority
        if (overlap_info[i, 1] == 1) {
            curr_start = start_vec[i]
            curr_stop = stop_vec[i]
            overlap_row = overlap_info[i, 2]

            high_start = start_vec[overlap_row]
            high_stop = stop_vec[overlap_row]

            // Case 1: Higher-priority completely covers lower-priority
            if (high_start <= curr_start && high_stop >= curr_stop) {
                result[i, 3] = 0  // mark invalid
            }
            // Case 2: Higher starts after lower start, ends at or after lower end
            else if (high_start > curr_start && high_start <= curr_stop) {
                result[i, 2] = high_start - 1  // truncate stop to day before higher starts
            }
            // Case 3: Higher ends before lower ends, starts at or before lower start
            else if (high_stop >= curr_start && high_stop < curr_stop) {
                result[i, 1] = high_stop + 1   // truncate start to day after higher ends
            }
            // Case 4: Higher is in the middle (both start and end inside lower)
            // For simplicity, keep only the pre-portion
            else if (high_start > curr_start && high_stop < curr_stop) {
                result[i, 2] = high_start - 1  // keep only portion before higher starts
            }
        }
    }

    return(result)
}


// ============================================================================
// tv_process_priority_overlaps()
//
// Main entry point for priority-based overlap processing.
// Called from Stata via: mata: tv_process_priority_overlaps("varlist")
//
// This function:
// 1. Reads data from Stata variables
// 2. Detects overlaps using tv_detect_overlaps_priority()
// 3. Resolves overlaps using tv_resolve_overlaps_priority()
// 4. Creates result variables in Stata dataset
//
// Arguments:
//   varnames - String containing space-separated variable names:
//              "id exp_start exp_stop priority_rank"
//
// Creates Stata variables:
//   __overlaps_higher   - 1 if overlaps with higher priority interval
//   __first_overlap_row - row number of first overlapping higher-priority interval
//   __adj_start         - adjusted start date after resolution
//   __adj_stop          - adjusted stop date after resolution
//   __valid             - 1 if interval should be kept, 0 if fully covered
// ============================================================================

void tv_process_priority_overlaps(string scalar varnames)
{
    real matrix data, overlap_info, resolve_result
    string rowvector vars
    real scalar n

    // Parse variable names
    vars = tokens(varnames)
    if (length(vars) != 4) {
        errprintf("tv_process_priority_overlaps requires 4 variables: id start stop priority\n")
        exit(198)
    }

    // Get data as a matrix (copies data, needed for consistent indexing)
    data = st_data(., vars)
    n = rows(data)

    if (n == 0) return

    // Detect overlaps (columns: overlaps_higher, first_overlap_row)
    overlap_info = tv_detect_overlaps_priority(data, 1, 2, 3, 4)

    // Resolve overlaps (columns: adj_start, adj_stop, valid)
    resolve_result = tv_resolve_overlaps_priority(data, overlap_info, 2, 3)

    // Create result variables in Stata
    // Check if variables exist, drop them if they do, then create new
    // Note: _st_varindex() (with underscore) returns . for non-existent vars
    //       st_varindex() throws an error for non-existent vars
    if (_st_varindex("__overlaps_higher") != .) {
        stata("quietly drop __overlaps_higher")
    }
    if (_st_varindex("__first_overlap_row") != .) {
        stata("quietly drop __first_overlap_row")
    }
    if (_st_varindex("__adj_start") != .) {
        stata("quietly drop __adj_start")
    }
    if (_st_varindex("__adj_stop") != .) {
        stata("quietly drop __adj_stop")
    }
    if (_st_varindex("__valid") != .) {
        stata("quietly drop __valid")
    }

    (void) st_addvar("double", "__overlaps_higher")
    (void) st_addvar("double", "__first_overlap_row")
    (void) st_addvar("double", "__adj_start")
    (void) st_addvar("double", "__adj_stop")
    (void) st_addvar("double", "__valid")

    // Store results
    st_store(., "__overlaps_higher", overlap_info[., 1])
    st_store(., "__first_overlap_row", overlap_info[., 2])
    st_store(., "__adj_start", resolve_result[., 1])
    st_store(., "__adj_stop", resolve_result[., 2])
    st_store(., "__valid", resolve_result[., 3])

    // Store count in Stata scalar for easy access
    st_numscalar("r(n_overlaps)", sum(overlap_info[., 1]))
}


// ============================================================================
// tv_count_overlaps()
//
// Efficiently count overlaps without processing/resolving.
// Useful for quick check of whether iteration should continue.
//
// Arguments:
//   varnames - String containing: "id exp_start exp_stop priority_rank"
//
// Stores result in: r(n_overlaps)
// ============================================================================

void tv_count_overlaps(string scalar varnames)
{
    real matrix data, overlap_info
    string rowvector vars
    real scalar n_overlaps

    vars = tokens(varnames)
    if (length(vars) != 4) {
        errprintf("tv_count_overlaps requires 4 variables\n")
        exit(198)
    }

    data = st_data(., vars)

    if (rows(data) == 0) {
        st_numscalar("r(n_overlaps)", 0)
        return
    }

    overlap_info = tv_detect_overlaps_priority(data, 1, 2, 3, 4)
    n_overlaps = sum(overlap_info[., 1])

    st_numscalar("r(n_overlaps)", n_overlaps)
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

// Program to call Mata overlap processing from Stata
// Usage: _tvexpose_mata_overlaps id exp_start exp_stop priority_rank
capture program drop _tvexpose_mata_overlaps
program define _tvexpose_mata_overlaps, rclass
    version 16.0
    syntax varlist(min=4 max=4)

    // Call Mata function (creates __overlaps_higher, __first_overlap_row, __adj_start, __adj_stop, __valid)
    mata: tv_process_priority_overlaps("`varlist'")

    // Return count of overlaps from Mata
    return scalar n_overlaps = r(n_overlaps)
end

// Program to count overlaps without processing
// Usage: _tvexpose_mata_count id exp_start exp_stop priority_rank
capture program drop _tvexpose_mata_count
program define _tvexpose_mata_count, rclass
    version 16.0
    syntax varlist(min=4 max=4)

    mata: tv_count_overlaps("`varlist'")
    return scalar n_overlaps = r(n_overlaps)
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
