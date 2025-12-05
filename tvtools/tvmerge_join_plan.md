# tvmerge Interval Join Optimization Plan

## Research Document: Replacing Cartesian Join with Linear-Time Algorithm

**Date:** 2025-12-05
**Status:** Research/Planning Phase
**Author:** Claude (AI Assistant)
**Warning:** Previous optimization attempts have broken the command. Proceed with extreme caution.

---

## 1. The Problem: Cartesian Explosion

### Current Implementation (tvmerge.ado lines 590-803)

The current `tvmerge` command uses Stata's `joinby` to merge time-varying intervals:

```stata
joinby id using `batch_k'
```

This creates a **Cartesian product** of all intervals for each person, then filters to overlapping intervals afterward:

```stata
* After joinby creates n*m rows per person:
generate double new_start = max(`startname', start_k)
generate double new_stop = min(`stopname', stop_k)
keep if new_start <= new_stop  // Filter to overlaps only
```

### Complexity Analysis

| Metric | Current (Cartesian) | Optimal Algorithm |
|--------|---------------------|-------------------|
| **Time Complexity** | O(n × m) per person | O((n + m) log(n + m)) |
| **Space Complexity** | O(n × m) temporary rows | O(n + m + k) where k = overlaps |
| **Example: 100 × 100** | 10,000 temporary rows | ~200 rows sorted |
| **Example: 1000 × 1000** | 1,000,000 temporary rows | ~2,000 rows sorted |

### Real-World Failure Scenario

For administrative health datasets (pharmacy claims, hospitalizations):
- Patient A: 500 prescription intervals
- Patient B: 300 hospitalization intervals
- **Cartesian:** 150,000 rows per patient before filtering
- **With 100,000 patients:** 15 billion temporary rows

Even with `batch()` processing, this can:
- Exhaust system memory
- Create massive temporary files
- Cause disk I/O bottlenecks
- Crash Stata entirely

---

## 2. Available Algorithms

### 2.1 Sweep Line Algorithm (Recommended)

**Concept:** Sort all interval endpoints by time, sweep through maintaining active intervals.

**Time Complexity:** O((n + m) log(n + m))

**Algorithm:**
```
1. Create events: (time, type, interval_id, dataset)
   - For each interval: START event at start_date, END event at stop_date
2. Sort events by time (breaks ties: START before END)
3. Sweep through events:
   - On START from dataset A: record overlap with all active intervals from B
   - On START from dataset B: record overlap with all active intervals from A
   - On END: remove interval from active set
4. For each recorded overlap pair, calculate intersection
```

**Pros:**
- Proven O(n log n) performance
- No memory explosion
- Well-documented algorithm
- Can be implemented in Mata

**Cons:**
- Requires Mata implementation for efficiency
- More complex code than current approach
- Edge cases require careful handling

### 2.2 Using SSC Package: `rangejoin`

**Package:** `rangejoin` by Robert Picard (requires `rangestat`)

**Concept:** Uses `rangestat` (Mata-based) to efficiently find observations within a range.

**Installation:**
```stata
ssc install rangejoin
ssc install rangestat
```

**Usage Pattern:**
```stata
rangejoin start_k stop_k using `ds_k', by(id) interval(`startname' `stopname')
```

**Pros:**
- Already implemented and tested
- Mata-optimized for performance
- Well-documented on SSC
- Active maintainer

**Cons:**
- Adds external package dependency
- Users must install separately
- May not perfectly match tvmerge requirements
- Different interface/options

### 2.3 Sort-Merge Interval Join

**Concept:** Sort both interval lists by start date, use two-pointer technique.

**Time Complexity:** O((n + m) log(n + m))

**Algorithm:**
```
1. Sort intervals from dataset A by start_date
2. Sort intervals from dataset B by start_date
3. For each interval in A:
   - Advance B pointer to first potentially overlapping interval
   - Check all B intervals that could overlap (stop when B.start > A.stop)
   - Record overlaps
```

**Pros:**
- Can be implemented in pure Stata (with sorting)
- Conceptually simpler than sweep line
- No external dependencies

**Cons:**
- Still O(n × k) in worst case where k = overlaps per interval
- More complex when intervals have many overlaps
- Requires careful pointer management

### 2.4 Interval Tree (Advanced)

**Concept:** Build a balanced tree structure for efficient interval queries.

**Time Complexity:** O(n log n) build, O(log n + k) per query

**Pros:**
- Theoretically optimal
- Excellent for repeated queries

**Cons:**
- Complex to implement in Mata
- Overkill for one-time merge operations
- Memory overhead for tree structure

---

## 3. Implementation Options for tvmerge

### Option A: Integrate `rangejoin` (Lowest Risk)

**Approach:** Use `rangejoin` as the core merge engine.

**Implementation:**
```stata
* Instead of joinby:
preserve
rangejoin start_k stop_k using `ds_k_clean', by(id) interval(`startname' `stopname')
* Process results...
restore
```

**Requirements:**
- Add dependency check at program start
- Update help file with installation requirements
- Add `ssc install` instructions to README

**Risk Assessment:** LOW
- `rangejoin` is mature, tested code
- Minimal changes to tvmerge logic
- Users may resist external dependency

**Code Changes:** ~50 lines

### Option B: Implement Sweep Line in Mata (Medium Risk)

**Approach:** Write efficient Mata code for sweep line algorithm.

**Implementation Sketch:**
```stata
mata:
void interval_overlap_join(
    string scalar id_var,
    string scalar start1, string scalar stop1,
    string scalar start2, string scalar stop2
) {
    // 1. Read data into Mata matrices
    real matrix data1, data2
    st_view(data1, ., (id_var, start1, stop1))
    st_view(data2, ., (id_var, start2, stop2))

    // 2. Create events array
    // 3. Sort events by (id, time, type)
    // 4. Sweep and record overlaps
    // 5. Store results back to Stata
}
end
```

**Risk Assessment:** MEDIUM
- Significant new code to write and test
- Mata debugging can be difficult
- Edge cases must be thoroughly tested

**Code Changes:** ~200-300 lines of Mata

### Option C: Pure Stata Sort-Merge (Medium-High Risk)

**Approach:** Use Stata's sorting and by-group processing.

**Implementation Concept:**
```stata
* Stack both datasets with markers
append using `ds_k_clean'
gen byte _source = (_n > _n_before)

* Sort within ID
sort id _source start stop

* Complex by-group processing to find overlaps
by id: ...
```

**Risk Assessment:** MEDIUM-HIGH
- Pure Stata may not be fast enough for large data
- Complex logic prone to bugs
- Harder to maintain

**Code Changes:** ~150 lines of Stata

### Option D: Hybrid Approach (Conservative)

**Approach:** Keep current joinby for small batches, switch to optimized algorithm for large ones.

**Implementation:**
```stata
* Count intervals per ID
quietly count if `touse'
local n_intervals = r(N)

* Use optimized algorithm only when Cartesian would explode
if `n_intervals' > 10000 {
    // Use sweep line or rangejoin
}
else {
    // Keep current joinby approach
}
```

**Risk Assessment:** LOW-MEDIUM
- Preserves current behavior for most cases
- Only applies optimization when needed
- Increases code complexity

---

## 4. Critical Risks and Concerns

### 4.1 Breaking Changes from Previous Attempt

> "last time I tried something like this it completely broke the command"

**Potential Causes of Previous Failures:**

1. **Output Order Changes:** New algorithms may produce rows in different order, breaking downstream code that assumes specific ordering.

2. **Floating-Point Precision:** Different calculation order can cause small differences in overlap boundaries.

3. **Edge Case Handling:**
   - Empty results (no overlaps)
   - Single-observation datasets
   - Identical start/stop dates
   - Negative duration intervals (already filtered, but algorithm must handle)

4. **Variable Type Preservation:** Must maintain double precision for dates.

5. **Missing Value Propagation:** Must handle missing values identically.

### 4.2 Specific Edge Cases to Test

| Edge Case | Current Behavior | Must Preserve |
|-----------|------------------|---------------|
| No overlaps | Empty result | Yes |
| Complete overlap | Single output row | Yes |
| Partial overlap | Correct intersection | Yes |
| Adjacent intervals (no gap) | No overlap | Yes |
| Same start/stop in both | Point overlap | Yes |
| All missing values | Excluded | Yes |
| Single ID | Works | Yes |
| Empty dataset | Error or empty | Check current |

### 4.3 Performance vs. Compatibility Trade-off

| Consideration | Recommendation |
|---------------|----------------|
| Backward compatibility | CRITICAL - must produce identical results |
| Performance improvement | IMPORTANT - but not at cost of correctness |
| External dependencies | AVOID if possible |
| Code maintainability | IMPORTANT - complex Mata harder to debug |

---

## 5. Detailed Recommendation

### Primary Recommendation: Option D (Hybrid) with Option B (Mata)

**Phase 1: Implement Detection and Fallback**
1. Add interval count estimation before joinby
2. Set threshold (e.g., estimated Cartesian > 100,000 rows)
3. If under threshold: use current joinby (safe, tested)
4. If over threshold: warn user, suggest batch size reduction

**Phase 2: Implement Mata Sweep Line**
1. Write and thoroughly test Mata interval overlap function
2. Create comprehensive test suite comparing outputs
3. Add as optional alternative with `algorithm(sweep)` option
4. Make default only after extensive testing

**Phase 3: Gradual Migration**
1. Monitor user feedback
2. If no issues after multiple releases, make sweep line default
3. Keep joinby as fallback with `algorithm(cartesian)` option

### Implementation Priority

```
1. [IMMEDIATE] Add warning when Cartesian product would be large
2. [SHORT-TERM] Implement Mata sweep line as optional algorithm
3. [MEDIUM-TERM] Add comprehensive test suite
4. [LONG-TERM] Consider making sweep line default
```

---

## 6. Mata Sweep Line Implementation Sketch

```stata
*! Sweep line interval overlap join
*! Returns matrix of (id, start_overlap, stop_overlap, row1, row2)

mata:
mata set matastrict on

real matrix sweep_line_overlap_join(
    real matrix data1,    // n1 x 3: (id, start, stop)
    real matrix data2     // n2 x 3: (id, start, stop)
) {
    real scalar n1, n2, n_events, i, j, k
    real matrix events, results, active_set
    real scalar cur_id, cur_time, event_type, source, row_idx

    n1 = rows(data1)
    n2 = rows(data2)

    // Create events: (id, time, type, source, row_idx)
    // type: 0 = START, 1 = END
    // source: 1 = data1, 2 = data2
    n_events = 2 * (n1 + n2)
    events = J(n_events, 5, .)

    k = 0
    for (i = 1; i <= n1; i++) {
        k++
        events[k, .] = (data1[i, 1], data1[i, 2], 0, 1, i)  // START
        k++
        events[k, .] = (data1[i, 1], data1[i, 3], 1, 1, i)  // END
    }
    for (i = 1; i <= n2; i++) {
        k++
        events[k, .] = (data2[i, 1], data2[i, 2], 0, 2, i)  // START
        k++
        events[k, .] = (data2[i, 1], data2[i, 3], 1, 2, i)  // END
    }

    // Sort by (id, time, type) - type ensures START before END at same time
    events = sort(events, (1, 2, 3))

    // Sweep and collect overlaps
    // ... (detailed implementation needed)

    return(results)
}

end
```

**Note:** This is a sketch. Full implementation requires:
- Proper active set management (possibly using associative arrays)
- Correct overlap calculation
- Handling of by-groups (multiple IDs)
- Memory-efficient result storage

---

## 7. Testing Strategy

### 7.1 Unit Tests

```stata
* Test 1: Simple overlap
clear
input id start1 stop1
1 0 10
end
tempfile d1
save `d1'

clear
input id start2 stop2
1 5 15
end
tempfile d2
save `d2'

* Expected result: id=1, start=5, stop=10
```

### 7.2 Comparison Tests

```stata
* Run both algorithms, compare results
preserve
tvmerge `d1' `d2', id(id) start(start1 start2) stop(stop1 stop2) ///
    exposure(exp1 exp2) algorithm(joinby)
tempfile result_joinby
save `result_joinby'
restore

preserve
tvmerge `d1' `d2', id(id) start(start1 start2) stop(stop1 stop2) ///
    exposure(exp1 exp2) algorithm(sweep)
tempfile result_sweep
save `result_sweep'
restore

* Compare
use `result_joinby', clear
cf _all using `result_sweep'
```

### 7.3 Stress Tests

```stata
* Create datasets with many intervals per person
clear
set obs 1000
gen id = ceil(_n / 100)  // 10 unique IDs, 100 intervals each
gen start1 = runiform() * 1000
gen stop1 = start1 + runiform() * 50
* ... similar for dataset 2

* Time both algorithms
timer clear
timer on 1
tvmerge ... algorithm(joinby)
timer off 1

timer on 2
tvmerge ... algorithm(sweep)
timer off 2

timer list
```

---

## 8. Source References

### Academic/Algorithmic

- [Sweep Line Algorithm - Wikipedia](https://en.wikipedia.org/wiki/Sweep_line_algorithm)
- [Interval Tree - Wikipedia](https://en.wikipedia.org/wiki/Interval_tree)
- [Interval Tree - GeeksforGeeks](https://www.geeksforgeeks.org/dsa/interval-tree/)
- [Line Sweep Algorithms - TopCoder](https://www.topcoder.com/thrive/articles/Line%20Sweep%20Algorithms)
- [Geometric Intersections - Princeton Algorithms](https://algs4.cs.princeton.edu/93intersection/)
- [USACO Guide - Sweep Line](https://usaco.guide/plat/sweep-line)

### Stata-Specific

- [RANGEJOIN: Stata module to form pairwise combinations if a key variable is within range](https://ideas.repec.org/c/boc/bocode/s458162.html)
- [RANGESTAT: Stata module to generate statistics using observations within range](https://ideas.repec.org/c/boc/bocode/s458161.html)
- [ftools: Fast Stata commands for large datasets](https://github.com/sergiocorreia/ftools)
- [Stata joinby manual](https://www.stata.com/manuals/djoinby.pdf)

### Performance Discussions

- [Joinby taking more time due to merge of 2 large datasets](https://www.statalist.org/forums/forum/general-stata-discussion/general/1393264-joinby-taking-more-time-due-to-merge-of-2-large-datasets-any-more-efficient-alternatives) (Statalist)
- [New on SSC: range join](https://www.statalist.org/forums/forum/general-stata-discussion/general/1333374-new-on-ssc-range-join-a-program-to-form-pairwise-combinations-using-a-range) (Statalist)

---

## 9. Conclusion

### Is the Recommendation Feasible?

**YES**, but with significant caveats:

1. **Algorithmic feasibility:** Linear-time interval overlap algorithms exist and are well-documented (sweep line, interval trees).

2. **Stata implementation feasibility:**
   - **Using `rangejoin`:** Immediately feasible, minimal code changes
   - **Mata implementation:** Feasible but requires ~200-300 lines of new code
   - **Pure Stata:** Feasible but likely slower, more error-prone

3. **Risk assessment:**
   - Previous failure suggests edge cases are tricky
   - Comprehensive testing is mandatory
   - Phased rollout recommended

### Final Recommendation

**DO NOT immediately replace the current algorithm.**

Instead:

1. **Add instrumentation** to detect when Cartesian explosion is likely
2. **Warn users** and suggest smaller batch sizes
3. **Implement optional `algorithm()` parameter** for testing
4. **Develop comprehensive test suite** before any default changes
5. **Consider `rangejoin` dependency** if acceptable to users

The current `batch()` system mitigates the problem for many use cases. A complete algorithm replacement should only proceed after thorough testing confirms identical results across all edge cases.

---

## 10. Next Steps (If Proceeding)

1. [ ] Create test suite with 20+ edge case scenarios
2. [ ] Run test suite against current implementation, save expected outputs
3. [ ] Implement warning for large Cartesian products
4. [ ] Prototype Mata sweep line in separate file
5. [ ] Validate prototype against test suite
6. [ ] Add `algorithm()` option with `joinby` (default) and `sweep` choices
7. [ ] Extensive real-world testing with administrative datasets
8. [ ] User feedback collection
9. [ ] Consider making sweep line default in future version

---

*End of Research Document*
