# tvtools: Follow-up Items and Conceptual Notes

This document tracks conceptual issues, design decisions, and items requiring future consideration for the tvtools package.

---

## 1. Continuous Variable Splitting: The Core Problem (FIXED in v1.3.0)

### Background

When intervals are split at event dates, continuous variables (like cumulative dose) must be proportionally adjusted to preserve totals. The `continuous()` option in tvevent handles this.

### The Bug (Fixed)

**Version affected:** tvevent < 1.3.0

When multiple events occurred within the same original interval, the old algorithm created overlapping sub-intervals and **double-counted** continuous variables.

**Example of the bug:**
- Original interval: `[0, 100]` with `continuous = 500`
- Events at dates 40 and 70

**Old (buggy) result:**
| start | stop | continuous |
|-------|------|------------|
| 0     | 40   | 200        |
| 40    | 100  | 300        |
| 0     | 70   | 350        |
| 70    | 100  | 150        |

Total = 1000 (double the original!)

**Correct result (v1.3.0+):**
| start | stop | continuous |
|-------|------|------------|
| 0     | 40   | 200        |
| 40    | 70   | 150        |
| 70    | 100  | 150        |

Total = 500 (preserved)

### The Fix

Version 1.3.0 rewrote the splitting algorithm to:
1. Collect all split points for each original interval
2. Sort them in chronological order
3. Create sequential non-overlapping segments: `[start, s1], [s1, s2], ..., [sN, stop]`
4. Pro-rate continuous variables correctly using `(new_duration / original_duration)`

---

## 2. Default Behavior: Continuous Variables NOT Auto-Adjusted

### Current Design

Continuous variables are **only** adjusted when explicitly listed in `continuous()`. This is documented but easy to forget.

```stata
* Continuous variable NOT adjusted (will double-count if split)
tvevent using events, id(id) date(eventdate)

* Continuous variable correctly adjusted
tvevent using events, id(id) date(eventdate) continuous(cumulative_dose)
```

### Consideration for Future

Should tvevent auto-detect continuous variables? Arguments:

**Against auto-detection (current approach):**
- User explicitly controls which variables are modified
- Avoids unintended changes to variables that look continuous but shouldn't be pro-rated
- Clear and predictable behavior

**For auto-detection:**
- Prevents user error from forgetting the option
- Could warn if numeric variables exist that aren't in `continuous()`

**Decision:** Keep current explicit approach but consider adding a warning if numeric variables exist that might need pro-rating.

---

## 3. Boundary Events: Strict Inequality

### Current Behavior

Events are only split when `start < date < stop` (strict inequality). Events exactly on start or stop dates are NOT split.

From `tvtools_conceptual_audit.md`:
> Events on exact start/stop boundaries are dropped. Events that occur exactly on the start date or exactly on the stop date of an interval are ignored.

### Implications

- An event on `t=stop` is correctly flagged (the event ends that interval)
- An event on `t=start` is NOT flagged (it's considered before the interval begins)
- This matches standard survival analysis conventions where risk begins at `start`

### Consideration

This is probably correct for most survival analysis use cases, but users expecting inclusive boundaries may be surprised. Document clearly in help file.

---

## 4. tvmerge vs tvevent: Different Continuous Handling

### tvmerge Continuous Handling

tvmerge creates Cartesian products of intervals from different datasets. Its `continuous()` option pro-rates based on overlap between the original period and the merged intersection:

```
proportion = (intersection_duration + 1) / (original_duration + 1)
```

The `+1` accounts for inclusive date counting.

### tvevent Continuous Handling

tvevent splits intervals at event dates. Its `continuous()` option pro-rates based on:

```
ratio = new_duration / original_duration
```

No `+1` adjustment (uses raw day differences).

### Note

These are conceptually different operations:
- tvmerge: "How much of the exposure period overlaps with this merged interval?"
- tvevent: "How much of the cumulative amount belongs to this sub-interval?"

The different formulas are intentional, but this could be confusing to users.

---

## 5. Test Coverage Needed

The multiple-event splitting bug was found through code review, not testing. Consider adding tests for:

1. **Multiple events within one interval**
   - 2 events in same interval
   - 3+ events in same interval
   - Verify continuous variables sum correctly

2. **Edge cases**
   - Events exactly on interval boundaries
   - Zero-duration intervals
   - Missing continuous variable values

3. **Recurring events**
   - Multiple recurring events in same interval
   - Wide-format with varying numbers of events per person

---

## 6. Performance Considerations

The new splitting algorithm (v1.3.0) uses reshape wide/merge which may be slower for very large datasets with many split points. The old expand-based approach was faster but incorrect.

For most epidemiological datasets, the performance impact should be negligible. Monitor if users report slowdowns with very large datasets (>1M intervals with many splits).

---

## Version History

- **v1.3.0 (2025-12-13):** Fixed multiple-event interval splitting bug
- **v1.2.0 (2025-12-13):** Added startvar/stopvar options
- **v1.1.0 (2025-12-10):** Added recurring events support
