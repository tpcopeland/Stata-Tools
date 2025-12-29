# tvtools: Follow-up Items and Conceptual Notes

This document tracks conceptual issues, design decisions, and items requiring future consideration for the tvtools package.

**Last Updated:** 2025-12-29

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

---

## 7. New Commands: Integration Considerations (December 2025)

Three new commands were added to the tvtools package:

### tvdiagnose

**Purpose:** Standalone diagnostic tool for time-varying datasets.

**Design decisions:**
- Works on any time-varying dataset, not just tvtools output
- Reports are modular (coverage, gaps, overlaps, summarize)
- Threshold-based gap flagging (default 30 days)

**Integration notes:**
- Shares diagnostic logic with tvexpose's built-in options
- Entry/exit required for coverage; exposure required for summarize
- Could potentially be called automatically by other commands with a `diagnose` option

**Future considerations:**
- Add transition matrix showing exposure switching patterns
- Export to CSV/Excel for external analysis
- Time-series coverage trends

---

### tvbalance

**Purpose:** Covariate balance assessment for causal inference workflows.

**Design decisions:**
- Works at observation level (not person level) - each row is weighted
- Supports IPTW weights with effective sample size calculation
- Uses pooled standard deviation for SMD calculation
- Love plot uses Stata graphics system

**Integration notes:**
- Pairs with external propensity score estimation (logit/probit)
- Future tvweight command would integrate directly
- Currently assumes binary exposure (reference vs exposed)

**Conceptual considerations:**
- Time-varying balance: Current implementation ignores temporal structure. SMD is calculated across all person-time, not at each time point. For marginal structural models, time-varying balance assessment would be more appropriate.
- Person-level clustering: SMD calculation doesn't account for clustering within persons. Consider robust variance estimation or cluster-aware summaries.

**Future considerations:**
- Time-varying SMD (at each calendar or follow-up time)
- Variance ratio diagnostics
- Automated covariate selection

---

### tvplot

**Purpose:** Visualization of exposure patterns.

**Design decisions:**
- Swimlane plot: horizontal bars per person, color by exposure
- Person-time plot: bar chart of total person-time by exposure
- Sample-based (default 30 individuals) to manage plot complexity
- Uses Stata's twoway bar and rbar graphics

**Integration notes:**
- Designed to work with tvexpose/tvmerge output
- Expects start/stop/id structure
- Exposure variable optional for swimlane (single color if not specified)

**Conceptual considerations:**
- Sorting affects interpretation: sortby(persontime) shows most complex patients first
- Large samples (>100) can be cluttered; consider aggregation options
- Event markers would enhance clinical interpretation

**Future considerations:**
- Event markers on swimlane plots (where outcomes occurred)
- Calendar-time axis option
- Interactive HTML export (using Stata's puthtml or external tools)
- Aggregate summary panels showing population-level patterns

---

## 8. Command Interoperability

The six tvtools commands are designed to work together:

```
[tvexpose] → [tvmerge] → [tvdiagnose] → [tvevent] → [tvbalance] → [tvplot] → [stset/stcox]
```

### Data Flow Assumptions

| From | To | Assumptions |
|------|-----|------------|
| tvexpose | tvdiagnose | Output has id, start, stop, exposure |
| tvexpose | tvmerge | Multiple tvexpose outputs with same id |
| tvmerge | tvdiagnose | Merged output has id, start, stop |
| tvdiagnose | tvevent | No data modification, diagnostic only |
| tvevent | tvbalance | Output has exposure variable, covariates |
| tvevent | tvplot | Output has id, start, stop, exposure |

### Missing Integrations

1. **tvdiagnose → automatic cleanup**: Could offer to fix identified issues
2. **tvbalance → tvweight**: Future command for weight generation
3. **tvplot → events**: Show outcome events on swimlane plots
4. **Pipeline command**: Single command to run full workflow

---

## 9. Test Coverage for New Commands

### Current gaps:

**tvdiagnose:**
- [ ] Empty dataset handling
- [ ] Missing entry/exit with coverage option
- [ ] Unicode variable names
- [ ] Very large datasets (>100K obs)

**tvbalance:**
- [ ] Categorical exposure with >2 levels
- [ ] Missing covariate values
- [ ] Extreme weights
- [ ] Zero-variance covariates

**tvplot:**
- [ ] Zero observations after filtering
- [ ] All same exposure category
- [ ] Very wide date ranges (decades)
- [ ] Missing exposure values

### Recommended test file:

Create `tvtools/_testing/test_diagnostic_commands.do` covering:
1. Basic functionality for each command
2. Edge cases listed above
3. Integration with core workflow
