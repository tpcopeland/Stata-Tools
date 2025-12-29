# tvtools Future Directions

This document outlines potential future enhancements to the tvtools package for time-varying exposure analysis in survival studies.

**Last updated:** 2025-12-29

---

## Recently Completed Enhancements ✓

The following items from previous versions of this document have been implemented:

### ✓ Visualization and Diagnostics (Completed December 2025)

**tvplot** - Exposure swimlane plots and person-time visualization
- Individual-level exposure histories with color coding
- Person-time bar charts by exposure category
- Sorting by entry, exit, or total person-time
- Export to PNG, PDF, and other formats

**tvdiagnose** - Comprehensive diagnostic output
- Coverage diagnostics: percentage of follow-up covered by exposure records
- Gap analysis: distribution and duration of unexposed intervals
- Overlap detection: identify overlapping exposure periods
- Exposure distribution summary: person-time by category

**tvbalance** - Balance diagnostics for causal inference
- Standardized mean differences (SMD) between exposure groups
- Support for IPTW weights with effective sample size calculation
- Love plots for visual balance assessment
- Configurable imbalance thresholds

---

## Suggested Enhancements (Active Roadmap)

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

### 5. Visualization and Diagnostics — ✓ COMPLETED

> **Status:** Implemented in tvtools v1.2+ (December 2025)
>
> See: `help tvplot`, `help tvdiagnose`, `help tvbalance`

The following have been implemented:

- **tvplot** - Swimlane plots and person-time visualization
- **tvdiagnose** - Coverage, gap, and overlap diagnostics
- **tvbalance** - SMD calculation and Love plots for balance assessment

#### Remaining enhancements for these commands:

**tvplot enhancements:**
- Event markers on swimlane plots (show where outcomes occurred)
- Calendar-time axis option (vs. time-from-entry)
- Aggregate summary panels showing population-level patterns
- Interactive HTML export option

**tvdiagnose enhancements:**
- Transition matrices showing exposure switching patterns
- Temporal trends in coverage over calendar time
- Export diagnostics to Excel/CSV

**tvbalance enhancements:**
- Time-varying balance assessment (SMD at each time point)
- Automated covariate selection based on SMD
- Variance ratio diagnostics

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

### 11. Workflow Integration Enhancements

**Current state:** Commands work independently; users must chain them manually.

**Proposed enhancements:**

#### A. Pipeline Command

```stata
* Single command for complete workflow
tvpipeline using exposure_data, ///
    id(id) start(start) stop(stop) exposure(drug) ///
    entry(entry) exit(exit) event(outcome_dt) ///
    compete(death_dt) ///
    diagnose balance(age sex) plot ///
    saveas(analysis_ready.dta)
```

- Chain tvexpose → tvmerge → tvevent in one call
- Automatic diagnostic output
- Generate standard visualizations
- Produce analysis-ready dataset

#### B. Reporting Suite

```stata
* Generate comprehensive analysis report
tvreport, id(id) start(start) stop(stop) exposure(tv_exposure) ///
    covariates(age sex comorbidity) ///
    event(outcome) compete(death) ///
    format(html) output(report.html)
```

- Automated report generation
- Exposure pattern summary
- Balance tables
- Preliminary hazard ratios
- Diagnostic plots

---

### 12. Machine Learning Integration

**Use case:** Modern causal inference methods using ML for nuisance parameter estimation.

```stata
* Double/debiased machine learning for causal effects
tvdml, exposure(tv_exposure) outcome(outcome) ///
    covariates(age sex comorbidity bp bmi) ///
    method(lasso) crossfit(5)
```

- LASSO/elastic net for high-dimensional confounding
- Cross-fitting for doubly robust estimation
- Integration with Stata's lasso commands
- Support for continuous and binary treatments

---

### 13. Real-World Evidence Workflows

**Use case:** Pharmacovigilance and regulatory submissions.

```stata
* PASS/PAES workflow support
tvpass, ///
    cohort(cohort.dta) ///
    exposure(drug_periods.dta) ///
    outcomes(adverse_events.dta) ///
    protocol(protocol.xlsx)
```

- Post-authorization safety/efficacy studies
- Structured output for regulatory submissions
- Standard safety endpoints (MACE, bleeding, etc.)
- Sensitivity analysis frameworks

---

## Implementation Priority

### Completed

| Enhancement | Complexity | Impact | Status |
|-------------|------------|--------|--------|
| Visualization (tvplot) | Medium | High | ✓ Complete |
| Diagnostics (tvdiagnose) | Low | Medium | ✓ Complete |
| Balance (tvbalance) | Medium | High | ✓ Complete |

### Active Roadmap

| Enhancement | Complexity | Impact | Priority | Status |
|-------------|------------|--------|----------|--------|
| Mata optimization | High | High | 1 | Planned |
| IPTW/MSM support (tvweight) | High | High | 2 | Planned |
| Workflow integration (tvpipeline) | Medium | High | 3 | Planned |
| Multiple imputation | High | Medium | 4 | Planned |
| tvplot/tvdiagnose enhancements | Low | Medium | 5 | Planned |

### Research Phase

| Enhancement | Complexity | Impact | Priority | Status |
|-------------|------------|--------|----------|--------|
| G-estimation (tvestimate) | High | Medium | 6 | Research |
| Target trial emulation (tvtrial) | High | High | 7 | Research |
| ML integration (tvdml) | High | Medium | 8 | Research |
| Sensitivity analysis (tvsensitivity) | Medium | Medium | 9 | Research |

### Backlog

| Enhancement | Complexity | Impact | Priority | Status |
|-------------|------------|--------|----------|--------|
| External factors (tvcalendar) | Low | Low | 10 | Backlog |
| Output utilities (tvtable) | Low | Low | 11 | Backlog |
| RWE workflows (tvpass) | Medium | Low | 12 | Backlog |
| Reporting suite (tvreport) | Medium | Medium | 13 | Backlog |

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

## Lessons Learned from Diagnostic Command Implementation

The development of tvdiagnose, tvbalance, and tvplot in December 2025 provided insights for future development:

### What Worked Well

1. **Modular design**: Making each report type optional (coverage, gaps, overlaps) allows users to run only what they need.

2. **Consistent interface patterns**: Using the same option names (id, start, stop) across all commands reduces learning curve.

3. **Standalone flexibility**: Commands work on any time-varying dataset, not just tvtools output, increasing utility.

4. **Graphics integration**: Using Stata's native graphics system (twoway, graph bar) ensures compatibility and familiar output.

### Challenges Encountered

1. **Time-varying SMD calculation**: Computing balance at each time point requires careful handling of the observation structure. Current implementation uses pooled SMD which may mask temporal imbalance.

2. **Swimlane plot scaling**: Large date ranges (decades) require intelligent axis scaling. Current implementation uses automatic Stata scaling.

3. **Memory efficiency**: Creating Love plots with many covariates can be memory-intensive. Consider Mata optimization for future versions.

### Recommendations for Future Commands

1. **Start with minimal viable options**, add complexity later
2. **Use consistent naming**: `id()`, `start()`, `stop()`, `exposure()` pattern
3. **Store results systematically**: All r() scalars and macros
4. **Provide both graphical and tabular output** where appropriate
5. **Test with edge cases early**: empty data, all same category, extreme values

---

## Implementation Notes for Priority Items

### Mata Optimization (Priority 1)

Key bottlenecks identified:
- `tvexpose`: O(n²) overlap detection loop in lines 450-520
- `tvmerge`: Cartesian product generation for large datasets
- `tvevent`: Multiple-event interval splitting

Recommended approach:
1. Profile with large datasets (>100K observations)
2. Identify top 3 performance bottlenecks
3. Rewrite in Mata with parallel hash-based lookups
4. Maintain Stata syntax wrapper for user interface

### tvweight Command (Priority 2)

Proposed implementation phases:

**Phase 1: Basic IPTW**
```stata
tvweight tv_exposure, covariates(age sex) model(logit) generate(iptw)
```

**Phase 2: Stabilized weights**
```stata
tvweight tv_exposure, covariates(age sex) stabilized generate(siptw)
```

**Phase 3: Time-varying confounders**
```stata
tvweight tv_exposure, covariates(age sex) tvcovariates(bp_control) ///
    model(pooled_logit) generate(tviptw)
```

---

## Changelog

- **v1.2.0 (2025-12-29):** Added lessons learned; implementation notes for priority items
- **v1.1.0 (2025-12-29):** Marked visualization/diagnostics as complete; updated priority table
- **v1.0.0 (2025-12):** Initial future directions document

---

**Document Version:** 1.2.0
**Last Updated:** 2025-12-29
