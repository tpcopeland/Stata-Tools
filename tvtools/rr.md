# Peer Review: tvtools: A Stata Package for Time-Varying Exposure Analysis in Survival Studies

**Reviewer**: Statistical Methods Peer Review
**Date**: December 18, 2025
**Recommendation**: Accept with Minor Revisions

---

## Summary

This manuscript introduces tvtools, a Stata package for creating time-varying exposure datasets for survival analysis. The package addresses a genuine gap in the Stata ecosystem by automating the complex data manipulation required to transform raw exposure period data into analysis-ready datasets. The three-command workflow (tvexpose, tvmerge, tvevent) is well-designed and covers the major use cases in pharmacoepidemiology and related fields.

The manuscript is generally well-written and comprehensive. The examples are practical and the comparison with existing methods is fair. However, several areas require revision to strengthen the methodological exposition, improve code examples, and clarify certain technical details.

---

## Major Points

### 1. Missing Discussion of Proportional Hazards Assumption Testing

**Issue**: The manuscript mentions that tvtools "creates time-varying covariates, not time-varying coefficients" (Section 9.3) but does not discuss how researchers should test the proportional hazards assumption when using time-varying exposures, particularly for duration or cumulative dose analyses.

**Recommendation**: Add a subsection in Section 9 or Section 7 demonstrating how to test the PH assumption.

**Before** (Section 9.3):
```markdown
**No direct support for time-dependent coefficients.** tvtools creates time-varying covariates, not time-varying coefficients. Testing the proportional hazards assumption requires post-estimation diagnostics.
```

**After**:
```markdown
**No direct support for time-dependent coefficients.** tvtools creates time-varying covariates, not time-varying coefficients. Testing the proportional hazards assumption requires post-estimation diagnostics. After fitting a Cox model with time-varying exposures created by tvtools, researchers should examine Schoenfeld residuals:

```stata
stcox i.medication age female
estat phtest, detail
estat phtest, plot(1.medication)
```

If the PH assumption is violated for the time-varying exposure, researchers may consider stratification, time-partitioned models, or parametric alternatives such as flexible parametric survival models (stpm2).
```

---

### 2. Incomplete Explanation of Immortal Time Bias Example

**Issue**: Section 7.3 demonstrates the immortal time bias problem but the "incorrect analysis" code has a logical error. The merge command as written would only capture the first medication record, not classify patients as "ever-treated."

**Recommendation**: Clarify the incorrect analysis and explain precisely why it introduces bias.

**Before** (Section 7.3):
```stata
* Incorrect analysis (baseline exposure - introduces immortal time bias)
merge 1:1 id using medications, keep(master match) nogen keepusing(med_type)
replace med_type = 0 if missing(med_type)

stset study_exit, failure(outcome_dt != .) origin(study_entry) scale(365.25)
stcox i.med_type age female
* This analysis is BIASED - ever-treated appear protected due to immortal time
```

**After**:
```stata
* Incorrect analysis (baseline exposure - introduces immortal time bias)
* First, collapse to ever-treated indicator
preserve
use medications, clear
collapse (min) first_rx=rx_start, by(id)
tempfile ever_treated
save `ever_treated'
restore

merge 1:1 id using `ever_treated', keep(master match) nogen
generate byte treated = !missing(first_rx)

stset study_exit, failure(outcome_dt != .) origin(study_entry) scale(365.25)
stcox treated age female
* This analysis is BIASED - ever-treated appear protected because:
* 1. Time from study entry to first prescription is classified as "treated"
* 2. Patients must survive long enough to receive treatment
* 3. This "immortal time" artificially inflates apparent protective effects
```

---

### 3. Missing Standard Error Considerations for Clustered Data

**Issue**: The manuscript does not mention that the counting process formulation creates multiple records per person, which may require cluster-robust standard errors or frailty models when there is within-person correlation beyond what the time-varying exposure explains.

**Recommendation**: Add guidance on variance estimation.

**Before** (end of Section 2.2):
```markdown
The stcox and streg commands then correctly handle the time-varying covariates, updating risk sets appropriately at each failure time.

The key challenge is creating this properly structured data from raw exposure records. The tvtools package automates this transformation.
```

**After**:
```markdown
The stcox and streg commands then correctly handle the time-varying covariates, updating risk sets appropriately at each failure time.

**Note on variance estimation:** The counting process formulation creates multiple records per person. While stcox with the id() option correctly handles the partial likelihood contribution, researchers analyzing recurrent events or concerned about unmeasured within-person heterogeneity should consider:

```stata
* Cluster-robust standard errors
stcox i.medication age female, vce(cluster id)

* Shared frailty model for unmeasured heterogeneity
stcox i.medication age female, shared(id)
```

The key challenge is creating this properly structured data from raw exposure records. The tvtools package automates this transformation.
```

---

### 4. Clarify Competing Risks Interpretation

**Issue**: Section 7.2 uses stcrreg without explaining the subdistribution hazard interpretation, which differs importantly from cause-specific hazards.

**Recommendation**: Add interpretive guidance.

**Before** (Section 7.2):
```stata
* Step 5: Competing risks analysis
stcrreg i.medication age female, compete(status==2)
```

**After**:
```stata
* Step 5: Competing risks analysis using Fine-Gray subdistribution hazard
* Note: stcrreg models the subdistribution hazard, which accounts for the
* probability of experiencing the primary event in the presence of competing risks.
* Interpretation: The subdistribution hazard ratio quantifies the effect on
* cumulative incidence, not on cause-specific hazard.
stcrreg i.medication age female, compete(status==2)

* For cause-specific hazard ratios (alternative interpretation):
stcox i.medication age female if status != 2 | status == 1
```

---

## Minor Points

### 5. Syntax Table Formatting

**Issue**: The syntax tables in Sections 4.2, 5.2, and 6.2 would be clearer with consistent column alignment.

**Before** (Section 4.2):
```markdown
| Option | Description |
|--------|-------------|
| using *filename* | Dataset containing exposure periods |
| id(*varname*) | Person identifier linking to master dataset |
```

**After**:
```markdown
| Option | Description |
|:-------|:------------|
| `using` *filename* | Dataset containing exposure periods |
| `id(`*varname*`)` | Person identifier linking to master dataset |
```

---

### 6. Grace Period Example Incomplete

**Issue**: Section 7.9 demonstrates grace periods but doesn't show the effect on the data structure or hazard ratios, making it difficult to assess the impact.

**Recommendation**: Add output comparison.

**Before** (Section 7.9):
```stata
display "Percent exposed without grace: " r(pct_exposed) "%"
...
display "Percent exposed with 30-day grace: " r(pct_exposed) "%"
```

**After**:
```stata
display "Percent exposed without grace: " r(pct_exposed) "%"
local pct_no_grace = r(pct_exposed)
...
display "Percent exposed with 30-day grace: " r(pct_exposed) "%"
local pct_grace = r(pct_exposed)

display "Impact of grace period:"
display "  Without grace: " %5.1f `pct_no_grace' "% person-time exposed"
display "  With 30-day grace: " %5.1f `pct_grace' "% person-time exposed"
display "  Difference: " %5.1f (`pct_grace' - `pct_no_grace') " percentage points"
```

---

### 7. Missing Guidance on Choosing Between Exposure Definitions

**Issue**: Section 4.3 lists eight exposure definitions but provides limited guidance on when each is appropriate.

**Recommendation**: Add a decision framework.

**Before** (Section 4.3, after listing definitions):
```markdown
**Categorical dose**
Option: dosecuts(*numlist*)
...
```

**After** (add new subsection 4.3.1):
```markdown
### 4.3.1 Choosing an exposure definition

The choice of exposure definition should reflect the research question and biological mechanism:

| Research Question | Recommended Definition | Rationale |
|:-----------------|:----------------------|:----------|
| Does treatment vs. no treatment affect risk? | `evertreated` | Addresses immortal time bias; binary comparison |
| Do effects persist after treatment stops? | `currentformer` | Separates active from residual effects |
| Does longer treatment duration increase risk? | `duration()` | Cumulative exposure hypothesis |
| Is there a dose-response relationship? | `dose` with `dosecuts()` | Pharmacoepidemiologic dose-response |
| Do recent vs. remote exposures differ? | `recency()` | Recency hypothesis; waning effects |
| What is the instantaneous effect of being on treatment? | Default (time-varying) | Pure exposure-status effect |
```

---

### 8. Batch Processing Guidance

**Issue**: Section 5.4 explains batch processing but the guidance on choosing batch sizes is vague ("smaller batch sizes prevent memory exhaustion").

**Recommendation**: Provide concrete guidance.

**Before** (Section 5.4):
```markdown
Larger batches are faster but use more memory. For datasets with over 50,000 IDs, smaller batch sizes prevent memory exhaustion.
```

**After**:
```markdown
Larger batches are faster but use more memory. Approximate guidelines:

| Dataset Size (IDs) | Recommended batch() | Memory Usage |
|:------------------|:-------------------|:-------------|
| < 10,000 | 50–100 | Low |
| 10,000–50,000 | 20–50 | Moderate |
| 50,000–100,000 | 10–20 | High |
| > 100,000 | 5–10 | Very high |

For datasets exceeding available RAM, consider processing in separate chunks and appending results.
```

---

### 9. Incorrect Stored Results Documentation

**Issue**: The manuscript states tvexpose returns r(pct_exposed) but this appears to be stored differently in the actual implementation.

**Recommendation**: Verify stored results match implementation and add missing returns.

**Before** (Section 4.7):
```markdown
| r(pct_exposed) | Percentage of time exposed |
```

**After** (verify and expand):
```markdown
| r(pct_exposed) | Percentage of follow-up time exposed |
| r(reference) | Reference category value |
| r(exp_type) | Exposure definition used |
```

---

### 10. Synthetic Data Generation Could Be More Realistic

**Issue**: The synthetic data in Section 7.1 generates random exposure periods without ensuring they fall within study entry/exit dates, which may cause examples to produce fewer exposed periods than expected.

**Before** (Section 7.1):
```stata
* Generate medication exposure periods
clear
set obs 2000
generate id = ceil(_n / 2)
bysort id: generate period = _n
generate rx_start = mdy(1, 1, 2015) + floor(runiform() * 1095)
generate rx_stop = rx_start + 30 + floor(runiform() * 335)
```

**After**:
```stata
* Generate medication exposure periods (within study window)
clear
set obs 2000
generate id = ceil(_n / 2)
bysort id: generate period = _n

* Ensure prescriptions occur during follow-up by using cohort dates
* First, temporarily merge cohort dates
preserve
use cohort, clear
keep id study_entry study_exit
save _temp_dates, replace
restore

merge m:1 id using _temp_dates, nogen keep(match master)

* Generate prescription dates within each person's follow-up
generate followup_days = study_exit - study_entry
generate rx_start = study_entry + floor(runiform() * (followup_days - 365)) if followup_days > 365
replace rx_start = study_entry + floor(runiform() * followup_days) if followup_days <= 365
generate rx_stop = rx_start + 30 + floor(runiform() * min(335, study_exit - rx_start - 1))

drop study_entry study_exit followup_days
erase _temp_dates.dta
```

---

### 11. Reference List Expansion

**Issue**: The reference list is sparse for a methodological paper. Key references on time-varying covariates and competing risks methodology are missing.

**Recommendation**: Add foundational references.

**After** (add to References):
```markdown
Andersen, P. K., and R. D. Gill. 1982. Cox's regression model for counting processes: A large sample study. *Annals of Statistics* 10: 1100–1120.

Austin, P. C., D. S. Lee, and J. P. Fine. 2016. Introduction to the analysis of survival data in the presence of competing risks. *Circulation* 133: 601–609. https://doi.org/10.1161/CIRCULATIONAHA.115.017719

Lau, B., S. R. Cole, and S. J. Gange. 2009. Competing risk regression models for epidemiologic data. *American Journal of Epidemiology* 170: 244–256. https://doi.org/10.1093/aje/kwp107

Zhou, B., J. Fine, A. Latouche, and M. Labopin. 2012. Competing risks regression for clustered data. *Biostatistics* 13: 371–383.
```

---

### 12. Command Help File Cross-References

**Issue**: The manuscript could better reference the help files for complex option combinations.

**Recommendation**: Add cross-reference note.

**Before** (Section 3.1):
```markdown
This installs three commands (tvexpose, tvmerge, tvevent) along with their help files and optional dialog interfaces.
```

**After**:
```markdown
This installs three commands (tvexpose, tvmerge, tvevent) along with their help files and optional dialog interfaces. The help files contain additional examples and option combinations not covered in this article:

```stata
help tvexpose    // Comprehensive options including bytype, priority()
help tvmerge     // Batch processing and continuous exposure handling
help tvevent     // Recurring events and wide-format event data
```

---

## Code Corrections

### 13. Missing `quietly` in Example 7.7

**Issue**: The tvmerge example in Section 7.7 will produce verbose output during execution.

**Before**:
```stata
tvmerge tv_med1.dta tv_med2.dta, id(id) ///
    start(start start) stop(stop stop) ///
    exposure(med1 med2) ///
```

**After**:
```stata
quietly tvmerge tv_med1.dta tv_med2.dta, id(id) ///
    start(start start) stop(stop stop) ///
    exposure(med1 med2) ///
```

---

### 14. Example 7.4 Appears to Mix duration() and continuousunit()

**Issue**: Section 7.4 uses both `duration(0.5 1 2)` and `continuousunit(years)` in the same call. While the implementation supports this, the manuscript should clarify that duration() cutpoints are interpreted in the continuousunit() scale.

**Before**:
```stata
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(0.5 1 2) continuousunit(years) ///
    generate(duration_cat) keepvars(age female)

* Duration categories: 0=unexposed, 1=<0.5yr, 2=0.5-1yr, 3=1-2yr, 4=≥2yr
```

**After**:
```stata
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(0.5 1 2) continuousunit(years) ///
    generate(duration_cat) keepvars(age female)

* Note: duration() cutpoints are in continuousunit() scale (years here)
* Duration categories: 0=unexposed, 1=<0.5yr, 2=0.5–<1yr, 3=1–<2yr, 4=≥2yr
```

---

## Suggestions for the Commands

### 15. Consider Adding a Validation Option to tvevent

**Observation**: tvexpose has comprehensive diagnostic options (check, gaps, overlaps, summarize, validate) but tvevent has fewer. For a critical step like event integration, validation is important.

**Suggestion**: Consider adding a `validate` option to tvevent that checks:
- Events falling outside interval boundaries
- Multiple events per person when type(single) is expected
- Competing events occurring on the same date

---

### 16. Consider force Option Documentation

**Observation**: The tvmerge command has a `force` option for handling mismatched IDs across datasets, but this is not mentioned in the manuscript.

**Suggestion**: Document this option, as it's useful when merging exposure data that is a subset of the cohort.

**Add to Section 5** (new subsection):
```markdown
### 5.5 Handling ID mismatches

By default, tvmerge requires all datasets to contain the same set of IDs and will error if IDs don't match. When merging exposure datasets that may not cover all cohort members, use the force option:

```stata
tvmerge tv_med1.dta tv_med2.dta, id(id) ///
    start(start start) stop(stop stop) ///
    exposure(med1 med2) force
```

With force, mismatched IDs are dropped with a warning. This is appropriate when exposure data represents a subset of the cohort (e.g., only patients who received at least one prescription).
```

---

## Editorial Suggestions

### 17. Abstract Word Count

The abstract is 196 words, which is appropriate for the Stata Journal.

### 18. Consistent Terminology

The manuscript alternates between "time-varying exposure" and "time-varying covariate." While both are correct, consistency would improve readability. Suggest using "time-varying exposure" when referring to the exposure of interest and "time-varying covariate" for the general class.

### 19. Figure Suggestion

Consider adding a workflow diagram showing the data flow through the three commands. This would benefit readers who are visual learners.

---

## Conclusion

This is a valuable contribution to the Stata ecosystem. The tvtools package addresses a real need in pharmacoepidemiology and survival analysis. The manuscript is well-structured and the examples are practical. With the revisions suggested above—particularly the additions regarding proportional hazards testing, variance estimation, and clearer interpretive guidance—this paper will be a useful reference for applied researchers.

The commands themselves appear well-implemented based on the code review. The batch processing in tvmerge, the multiple exposure definitions in tvexpose, and the competing risks handling in tvevent demonstrate thoughtful design.

---

## Summary of Required Revisions

| Priority | Section | Issue | Action |
|:---------|:--------|:------|:-------|
| Major | 9.3 | PH assumption testing | Add guidance and code |
| Major | 7.3 | Immortal time bias example | Fix code logic |
| Major | 2.2 | Variance estimation | Add cluster/frailty guidance |
| Major | 7.2 | Competing risks interpretation | Clarify subdistribution hazard |
| Minor | 4.3 | Exposure definition guidance | Add decision table |
| Minor | 5.4 | Batch size guidance | Add concrete recommendations |
| Minor | 7.1 | Synthetic data | Ensure exposures within follow-up |
| Minor | References | Incomplete | Add foundational citations |

---

*Review completed December 18, 2025*
