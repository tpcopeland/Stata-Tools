# MVP Package Audit and Enhancement Plan

## Audit Date: 2025-12-03
## Current Version: 1.0.1
## Target Version: 1.1.0

---

## Executive Summary

This audit identifies key improvements for the mvp package, with particular focus on:
1. **Enhanced graph() functionality** - Adding stratified/by-group graphing capabilities
2. **Categorical variable analysis** - Compare missingness patterns across groups
3. **New graph options** - Stacked bars, faceted displays, improved customization

---

## Current State Analysis

### Existing Graph Types

| Graph Type | Purpose | Current Limitations |
|------------|---------|---------------------|
| `graph(bar)` | % missing per variable | No group comparison, no stacking |
| `graph(patterns)` | Pattern frequencies | No group stratification |
| `graph(matrix)` | Obs × var heatmap | No group-based coloring/faceting |
| `graph(correlation)` | Correlation heatmap | Works well, minor enhancements possible |

### Key Gaps Identified

1. **No by-group graphing** - Cannot compare missingness across categories (e.g., treatment vs control)
2. **No stacked bar option** - Cannot show composition of missingness
3. **No over() option** - Cannot overlay multiple categories in same graph
4. **Pattern comparison across groups** - No way to see if patterns differ by category
5. **Graph export improvements** - Direct format export would be helpful

---

## Proposed Enhancements

### 1. New Option: `by(varname)` for Graphs

Add a `by()` option that works with graph types to produce stratified visualizations.

**Syntax:**
```stata
mvp varlist, graph(bar) by(groupvar)
mvp varlist, graph(patterns) by(groupvar)
```

**Behavior:**
- `graph(bar) by(groupvar)`: Side-by-side or grouped bar charts comparing % missing across group levels
- `graph(patterns) by(groupvar)`: Faceted pattern displays by group

**Implementation Complexity:** Medium

### 2. New Option: `over(varname)` for Overlaid Comparison

**Syntax:**
```stata
mvp varlist, graph(bar) over(treatment)
```

**Behavior:**
- Creates grouped bar chart with bars for each level of the over() variable
- Shows % missing for each variable, grouped by category
- Enables direct visual comparison of missingness rates

**Implementation Complexity:** Medium

### 3. New Suboption: `stacked` for graph(bar)

**Syntax:**
```stata
mvp varlist, graph(bar) stacked
```

**Behavior:**
- Shows stacked bars where each segment represents a variable's contribution to total missingness
- Useful for seeing composition of missing data

**Implementation Complexity:** Low

### 4. Enhanced Pattern Analysis by Group

**Syntax:**
```stata
mvp varlist, by(groupvar) patterncompare
```

**Behavior:**
- Reports pattern frequencies separately for each group level
- Highlights patterns that differ significantly between groups
- Returns comparison statistics in r()

**Implementation Complexity:** Medium-High

### 5. New Graph Type: `graph(byvar)`

**Syntax:**
```stata
mvp varlist, graph(byvar) byvariables(var1 var2 var3)
```

**Behavior:**
- Creates a visualization showing % missing in the varlist, stratified by levels of each byvariable
- Useful for identifying if missingness varies by patient characteristics

**Implementation Complexity:** Medium

---

## Implementation Plan for Version 1.1.0

### Phase 1: Core by() and over() Options (Priority: High)

Add these new syntax options:
```stata
syntax [varlist] [if] [in] [, ///
    ... existing options ...
    BY(varname)             /// stratify graphs by this variable
    OVER(varname)           /// overlay comparison variable for bar graphs
    STacked                  /// stacked bar chart option
    GRoupgap(real 0)        /// gap between groups in grouped charts
    LEGendopts(string asis) /// pass-through legend options
]
```

### Phase 2: Implementation Details

#### A. graph(bar) with by() option

```stata
* When by() specified, create grouped bar chart
if "`by'" != "" & "`graphtype'" == "bar" {
    * Get levels of by variable
    qui levelsof `by' if `touse', local(bylevels)

    * For each level, compute % missing per variable
    * Create dataset with: varname, pctmiss, bylevel

    * Use graph bar with over(varname) by(bylevel)
    * or graph hbar (mean) pctmiss, over(varname) over(bylevel)
}
```

#### B. graph(bar) with over() option

```stata
* When over() specified, create overlaid grouped bars
if "`over'" != "" & "`graphtype'" == "bar" {
    * Create dataset with: varname, pctmiss, overlevel

    * Use: graph bar pctmiss, over(overlevel) over(varname)
    * This puts bars for each over() level side-by-side
}
```

#### C. graph(bar) stacked

```stata
* When stacked specified
if "`stacked'" != "" & "`graphtype'" == "bar" {
    * Restructure data for stacked display
    * Each variable becomes a "layer" in the stack
    * Use: graph bar (sum) pctmiss, over(varname) stack
}
```

### Phase 3: Documentation and Testing

1. Update mvp.sthlp with new options
2. Add examples for all new features
3. Update README.md
4. Update version numbers in all files
5. Test edge cases (empty groups, single observation groups, etc.)

---

## Detailed Code Changes Required

### mvp.ado Changes

1. **Add new syntax options** (lines 11-48):
   - `BY(varname)` - stratification variable
   - `OVER(varname)` - overlay variable
   - `STacked` - stacked bar option
   - `GRoupgap(real 0)` - visual spacing
   - `LEGendopts(string asis)` - legend customization

2. **Add validation for new options** (after line 96):
   - by() and over() are mutually exclusive
   - stacked only works with graph(bar)
   - by/over variables must be categorical

3. **Modify graph(bar) section** (lines 675-708):
   - Handle by() option - create grouped/faceted display
   - Handle over() option - create overlaid grouped bars
   - Handle stacked option - restructure for stacking

4. **Modify graph(patterns) section** (lines 713-758):
   - Handle by() option - create faceted pattern display

5. **Add new return values**:
   - `r(byvar)` - name of by variable if used
   - `r(bylevels)` - levels of by variable

### mvp.sthlp Changes

1. Add syntax documentation for new options
2. Add option descriptions in dlgtab sections
3. Add examples showing new functionality
4. Update stored results section

---

## Example Use Cases

### Use Case 1: Compare Missingness by Treatment Group

```stata
* Current limitation - must use by: prefix (separate analyses)
bysort treatment: mvp outcome1-outcome5

* New capability - single graph comparing groups
mvp outcome1-outcome5, graph(bar) by(treatment)
```

### Use Case 2: Compare Missingness by Multiple Categories

```stata
* Show how missingness varies by gender within variables
mvp income education occupation, graph(bar) over(gender)
```

### Use Case 3: Compositional View of Missingness

```stata
* See which variables contribute most to total missingness
mvp var1-var20, graph(bar) stacked vertical
```

### Use Case 4: Pattern Comparison Across Sites

```stata
* See if missingness patterns differ by study site
mvp *, graph(patterns) by(site) top(10)
```

---

## Risk Assessment

| Enhancement | Risk Level | Mitigation |
|-------------|------------|------------|
| by() option | Low | Well-established Stata pattern |
| over() option | Low | Standard graph bar syntax |
| stacked option | Low | Built-in Stata capability |
| Pattern comparison | Medium | Test thoroughly with edge cases |

---

## Version Update Checklist

- [ ] Update version in mvp.ado header (1.0.1 → 1.1.0)
- [ ] Update version in mvp.sthlp (1.0.0 → 1.1.0)
- [ ] Update Distribution-Date in mvp.pkg
- [ ] Update version in README.md
- [ ] Add changelog entry at end of mvp.ado

---

## Implementation Priority

1. **HIGH**: by() option for graph(bar) - most requested capability
2. **HIGH**: over() option for graph(bar) - essential for comparison
3. **MEDIUM**: stacked option - nice to have
4. **MEDIUM**: by() for graph(patterns) - useful but less common
5. **LOW**: Additional return values

---

## Acceptance Criteria

1. `mvp varlist, graph(bar) by(groupvar)` produces grouped bar chart
2. `mvp varlist, graph(bar) over(catvar)` produces overlaid comparison chart
3. All new options work with existing options (scheme, title, etc.)
4. Documentation is complete and examples run correctly
5. No regression in existing functionality

---

## Next Steps

1. Implement by() and over() options for graph(bar)
2. Test with various datasets and edge cases
3. Update documentation
4. Update version numbers
5. Commit and push changes
