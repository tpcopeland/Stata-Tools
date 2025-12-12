# tvtools Future Directions

This document outlines potential future enhancements to the tvtools package for time-varying exposure analysis in survival studies.

---

## Suggested Enhancements

### 1. Multiple Imputation Workflow Support

**Current limitation:** tvtools assumes complete data. Missing exposure dates, gaps in records, or uncertain exposure periods require manual handling before analysis.

**Proposed enhancement:**

- **`tvexpose, mi(#)`** - Generate multiple imputed exposure datasets
  - Impute missing start/stop dates based on distributional assumptions
  - Handle uncertain exposure classification probabilistically
  - Output: Multiple datasets suitable for `mi estimate` commands

- **Implementation approach:**
  ```stata
  * Generate 20 imputed exposure datasets
  tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
      exposure(drug_type) reference(0) entry(entry) exit(exit) ///
      mi(20) mimethod(pmm) miseed(12345)

  * Analyze across imputations
  mi estimate: stcox i.tv_exposure
  ```

- **Key features:**
  - Predictive mean matching for date imputation
  - Chained equations for multivariate missingness
  - Integration with Stata's `mi` prefix commands
  - Preserve within-person correlation structure

---

### 2. Causal Inference Framework Integration

**Current limitation:** tvtools creates datasets for traditional regression, but causal inference methods require additional data structures (weights, cumulative exposure histories, etc.).

**Proposed enhancements:**

#### A. Inverse Probability of Treatment Weighting (IPTW)

```stata
* New command: tvweight
tvweight using covariates, id(id) exposure(tv_exposure) ///
    confounders(age sex comorbidity) ///
    timevarying(bp_systolic bmi) ///
    generate(iptw) stabilized truncate(1 99)
```

- Calculate time-varying propensity scores
- Generate stabilized weights for marginal structural models
- Support for truncation at percentiles to handle extreme weights
- Diagnostic output: weight distributions, effective sample size

#### B. G-Estimation Support

```stata
* New option in tvevent or new command: tvestimate
tvestimate, method(gestimation) ///
    exposure(tv_exposure) outcome(outcome) ///
    confounders(age sex) timevarying(bp) ///
    snm(linear)    // Structural nested model type
```

- Implement structural nested mean models (SNMMs)
- Structural nested failure time models (SNFTMs)
- Handle continuous and binary exposures
- Output: causal effect estimates with appropriate standard errors

#### C. Marginal Structural Models

```stata
* MSM workflow helper
tvmsm, exposure(tv_exposure) outcome(outcome) ///
    baseline(age sex) timevarying(bp bmi) ///
    weights(iptw) robust cluster(id)
```

- Automated weight calculation
- Pooled logistic regression for discrete-time survival
- Cox MSM with robust variance
- Diagnostic tools: positivity assessment, weight diagnostics

#### D. Target Trial Emulation

```stata
* New command for target trial emulation
tvtrial using cohort, id(id) ///
    treatstart(rx_start) ///
    eligibility(age >= 18 & no_prior_exposure) ///
    clone generate(trial_id)
```

- Sequential trial emulation from observational data
- Clone-censor-weight approach
- Grace period handling
- Per-protocol and intention-to-treat comparisons

---

### 3. Mata Optimization for Large Datasets

**Current limitation:** Pure Stata ado implementation becomes slow with millions of observations or complex exposure patterns.

**Proposed enhancements:**

#### A. Core Algorithm Rewrite

- Reimplement interval splitting in Mata for O(n) instead of O(n²) complexity
- Use `st_view()` for memory-efficient data access
- Parallel processing for independent ID groups

```stata
* Example internal structure
mata:
void tv_split_intervals(string scalar varlist) {
    real matrix data, result
    st_view(data, ., tokens(varlist))

    // Mata-optimized interval arithmetic
    result = tv_interval_union(data)

    st_store(., tokens(varlist), result)
}
end
```

#### B. Batch Processing Improvements

- Automatic batch size optimization based on available memory
- Progress indicators for long-running operations
- Checkpoint/restart capability for very large jobs
- Memory-mapped file processing for datasets exceeding RAM

#### C. Performance Targets

| Dataset Size | Current Time | Target Time |
|--------------|--------------|-------------|
| 100K obs | ~30 sec | <5 sec |
| 1M obs | ~10 min | <30 sec |
| 10M obs | hours/fails | <5 min |

---

### 4. Dose-Response Analysis (Enhancement to Recent Dose Feature)

**Building on recently added dose functionality in tvexpose:**

#### A. Cumulative Dose Tracking

```stata
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug_type) reference(0) entry(entry) exit(exit) ///
    dose(daily_dose) dosecumulative(cumdose) ///
    dosecategories(0 100 500 1000)
```

- Track cumulative dose over time
- Create dose-duration categories (e.g., high dose for long duration)
- Time-weighted average dose calculations
- Biologically-based exposure metrics (AUC, peak concentration proxies)

#### B. Dose Intensity Patterns

```stata
tvexpose ..., doseintensity(avg max) dosewindow(90)
```

- Rolling average dose over configurable windows
- Maximum dose within periods
- Dose variability metrics
- Adherence patterns (proportion of days covered)

---

### 5. Visualization and Diagnostics

**Current limitation:** No built-in visualization of exposure patterns or diagnostic output.

**Proposed enhancements:**

#### A. Exposure Swimlane Plots

```stata
* New command: tvplot
tvplot id(id) start(start) stop(stop) exposure(tv_exposure), ///
    sample(50) sortby(total_exposed) ///
    colors(navy maroon forest_green) ///
    export(exposure_patterns.png)
```

- Individual-level exposure histories
- Color-coded by exposure type
- Timeline with events marked
- Aggregate summary panels

#### B. Diagnostic Output

```stata
tvdiagnose, exposure(tv_exposure) ///
    report(gaps overlaps transitions) ///
    threshold(30)  // Flag gaps > 30 days
```

- Gap analysis: distribution of unexposed intervals
- Transition matrices: exposure switching patterns
- Coverage statistics: person-time by exposure category
- Data quality flags: impossible dates, overlaps, etc.

#### C. Balance Diagnostics (for IPTW)

```stata
tvbalance, exposure(tv_exposure) ///
    covariates(age sex comorbidity) ///
    weights(iptw) smd threshold(0.1)
```

- Standardized mean differences over time
- Love plots at each time point
- Effective sample size by period

---

### 6. Additional Exposure Definition Options

#### A. Treatment Switching Analysis

```stata
tvexpose ..., switching(atoz zto a) generate(switch_pattern)
```

- Track switching between treatments
- Create indicator for treatment escalation/de-escalation
- Time to switch variables
- Per-protocol vs ITT exposure definitions

#### B. Exposure Patterns

```stata
tvexpose ..., pattern(continuous intermittent single) ///
    patternwindow(365)
```

- Classify individual exposure patterns
- Continuous users vs intermittent users vs single users
- Pattern-specific risk assessment
- Adherence trajectory groups

#### C. Time-Since-Last Exposure (Enhanced Recency)

```stata
tvexpose ..., recencycontinuous generate(time_since_last)
```

- Continuous time since last exposure (not just categories)
- Support for non-linear effects in regression
- Washout period identification

---

### 7. Integration with External Time-Varying Factors

**Use case:** Environmental exposures, policy changes, seasonal effects.

```stata
* New command: tvcalendar
tvcalendar using external_factors, ///
    datevars(start stop) ///
    merge(temperature policy_period flu_season)
```

- Merge calendar-time variables into person-time data
- Support for ecological exposures (air quality, temperature)
- Policy period indicators
- Seasonality adjustments

---

### 8. Sensitivity Analysis Utilities

#### A. Unmeasured Confounding

```stata
tvsensitivity, exposure(tv_exposure) outcome(outcome) ///
    method(evalue) rr(1.5)
```

- E-value calculations for time-varying exposures
- Bias analysis for unmeasured confounders
- Quantitative bias analysis integration

#### B. Exposure Misclassification

```stata
tvsensitivity, exposure(tv_exposure) ///
    sensitivity(0.8 0.9 1.0) specificity(0.95 0.99 1.0) ///
    method(misclassification)
```

- Sensitivity/specificity matrices for exposure classification
- Corrected effect estimates
- Probabilistic bias analysis

---

### 9. Output and Reporting Utilities

```stata
* Publication-ready tables
tvtable exposure(tv_exposure) outcome(outcome), ///
    events(1) persontime(years) ///
    export(table1.docx) format(nejm)

* Forest plots for subgroups
tvforest exposure(tv_exposure) outcome(outcome), ///
    subgroups(sex age_cat comorbidity) ///
    export(forest.png)
```

- Standardized Table 1 format
- Person-time calculations by exposure
- Event rates with confidence intervals
- Forest plots for stratified analyses

---

### 10. Validation and Testing Framework

```stata
* Data validation
tvvalidate, id(id) start(start) stop(stop) exposure(tv_exposure) ///
    checks(dates overlap gaps coverage)
```

- Automated data quality checks
- Identify impossible date sequences
- Flag potential data errors
- Coverage reports by calendar time

---

## Implementation Priority

| Enhancement | Complexity | Impact | Priority |
|-------------|------------|--------|----------|
| Mata optimization | High | High | 1 |
| IPTW/MSM support | High | High | 2 |
| Visualization | Medium | High | 3 |
| Multiple imputation | High | Medium | 4 |
| Dose-response enhancement | Medium | Medium | 5 |
| G-estimation | High | Medium | 6 |
| Diagnostics | Low | Medium | 7 |
| Sensitivity analysis | Medium | Medium | 8 |
| External factors | Low | Low | 9 |
| Output utilities | Low | Low | 10 |

---

## Technical Considerations

### Backward Compatibility

All enhancements should:
- Maintain existing syntax as default behavior
- Add new options without breaking existing workflows
- Provide clear deprecation warnings if changes needed

### Dependencies

Potential dependencies for advanced features:
- `moremata` - Extended Mata functions
- `gtools` - Fast group operations (optional, for speed)
- `coefplot` - Forest plot foundation
- `mi` - Multiple imputation framework (built-in)

### Documentation Requirements

Each new feature requires:
- Updated .sthlp file
- Dialog file (.dlg) for GUI access
- Examples in documentation
- Test suite additions
- Updates to tvtools_functionality.md

---

## Contributing

Suggestions and contributions welcome. Priority will be given to:
1. Features with demonstrated research need
2. Well-documented pull requests with tests
3. Enhancements that integrate with existing Stata ecosystem

---

**Document Version:** 1.0.0
**Created:** December 2025
