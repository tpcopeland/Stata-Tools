# tvtools Presentation Plan

## Presentation Overview

**Title:** The Time-Varying Problem in MS Research: How tvtools Prevents the Biases That Haunt Our Papers

**Duration:** 15-20 minutes (expandable to 30 with discussion)

**Target Audience:** PhD students, postdocs, and faculty in neuroepidemiology and MS research; familiar with Stata survival analysis and registry-based studies

**Key Message:** Time-varying exposure analysis isn't optional in MS pharmacoepidemiology—it's essential for avoiding immortal time bias and capturing treatment dynamics. tvtools makes it tractable.

---

## The Problem This Solves (Why Your Audience Should Care)

### For MS Researchers Specifically:

1. **Immortal Time Bias** - The silent killer of observational DMT studies
   - Patients must survive until treatment initiation to be "treated"
   - Naively assigning baseline exposure creates spurious protective effects
   - Published studies have been retracted or heavily criticized for this

2. **Treatment Switching is the Norm, Not the Exception**
   - Escalation therapy: Platform → High-efficacy after breakthrough
   - Lateral switching: Tolerability issues, pregnancy planning
   - De-escalation: Age, infection risk, stable disease
   - Registry data captures this complexity—our methods must too

3. **Cumulative Exposure Matters**
   - Is 5 years on natalizumab different from 2 years?
   - What about total time immunosuppressed?
   - Duration-response relationships require time-varying approaches

4. **Competing Risks are Ubiquitous**
   - Death competes with disability progression
   - Emigration, pregnancy, and treatment discontinuation
   - Ignoring competing risks biases effect estimates

---

## Presentation Structure

### Act 1: The Problem (4 minutes)

#### Slide 1: Title Slide (30 sec)
- **Title:** The Time-Varying Problem in MS Research
- **Subtitle:** How tvtools Prevents the Biases That Haunt Our Papers
- **Visual:** Brain with timeline showing DMT transitions

#### Slide 2: The Scenario We All Know (1.5 min)
- **Hook:** "Anna is diagnosed with RRMS at age 32. She starts on interferon, switches to fingolimod after two relapses, then escalates to natalizumab. She develops EDSS progression at year 8. Which treatment failed her?"
- **The uncomfortable truth:**
  - If we analyze by "ever-exposed to natalizumab" → natalizumab looks protective (she survived long enough to get it)
  - If we use baseline treatment → we're comparing different disease severities
  - If we ignore switching → we're not measuring what we think we're measuring
- **Visual:** Patient timeline showing the treatment journey

#### Slide 3: The Immortal Time Bias Problem (1.5 min)
- **The classic error:** Assigning treatment status based on eventual exposure
- **Diagram showing:**
  ```
  WRONG: Person starts as "treated" at study entry
  ┌─────────────────────────────────────────────────┐
  │ "Treated"                                       │
  │ t=0────────────────────────────────────────►    │
  └─────────────────────────────────────────────────┘

  RIGHT: Person is unexposed until treatment starts
  ┌───────────┬─────────────────────────────────────┐
  │ Unexposed │ Treated                             │
  │ t=0───────┼─────────────────────────────────────►
  └───────────┴─────────────────────────────────────┘
              ↑
         Treatment initiation (must survive to reach this)
  ```
- **Reference:** Suissa S. Immortal time bias in pharmacoepidemiology. AJE 2008.
- **MS-specific examples:** Multiple high-profile DMT studies criticized for this

#### Slide 4: What We Actually Need (30 sec)
- **Goal:** Transform registry data into analysis-ready time-varying datasets
- **Challenges:**
  - Multiple concurrent exposures (DMT + comorbidity treatments)
  - Event dates that split intervals
  - Competing risks (death, emigration)
  - Cumulative duration calculations
- **tvtools:** Three commands that handle all of this

---

### Act 2: The Solution (8-10 minutes)

#### Slide 5: The tvtools Workflow (1 min)
- **Three integrated commands:**

| Command | Purpose | MS Example |
|---------|---------|------------|
| `tvexpose` | Create time-varying intervals | DMT exposure periods → TV dataset |
| `tvmerge` | Combine multiple exposures | DMT + comorbidities → single dataset |
| `tvevent` | Integrate outcomes | EDSS progression + death → failure flags |

- **Visual:** Flowchart with Swedish MS Registry icon feeding into the pipeline

#### Slide 6: tvexpose - The Core Transformation (1.5 min)
- **Research scenario:** Analyzing DMT effectiveness from Swedish MS Registry
- **Input:** Raw prescription data

```
id │ dmt_start  │ dmt_stop   │ dmt
───┼────────────┼────────────┼─────────────────
 1 │ 2015-03-01 │ 2017-08-15 │ 1 (Interferon)
 1 │ 2018-01-10 │ 2022-06-30 │ 4 (Natalizumab)
```

- **Code:**

```stata
use ms_cohort, clear

tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date)
```

- **Output:** Complete timeline with gaps filled

```
id │ start      │ stop       │ tv_exposure
───┼────────────┼────────────┼─────────────────
 1 │ 2014-01-15 │ 2015-03-01 │ 0 (Unexposed)
 1 │ 2015-03-01 │ 2017-08-15 │ 1 (Interferon)
 1 │ 2017-08-15 │ 2018-01-10 │ 0 (Unexposed)
 1 │ 2018-01-10 │ 2022-06-30 │ 4 (Natalizumab)
 1 │ 2022-06-30 │ 2023-12-31 │ 0 (Unexposed)
```

#### Slide 7: tvexpose - Exposure Definitions for MS Research (1.5 min)
- **Different research questions need different exposure definitions:**

| Research Question | tvexpose Option | Output |
|-------------------|-----------------|--------|
| Ever-treated vs never-treated | `evertreated` | Binary 0/1, switches permanently at first exposure |
| Current vs former DMT use | `currentformer` | 0=Never, 1=Current, 2=Former |
| Cumulative years on DMT | `continuousunit(years)` | Continuous: 0, 0.5, 1.2, 2.8, ... |
| Duration categories | `duration(1 5)` | Categories: <1yr, 1-5yr, ≥5yr |
| Time since last exposure | `recency(1 5)` | Current, <1yr ago, 1-5yr ago, ≥5yr ago |

- **Example: Current/Former DMT analysis**

```stata
tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    currentformer generate(dmt_status)
```

- **Why this matters:** Distinguishes active treatment effect from residual protection

#### Slide 8: tvexpose - Handling Real-World Data Messiness (1 min)
- **Prescription gaps:** `grace(30)` - Treat 30-day gaps as continuous
- **Delayed onset:** `lag(30)` - DMT doesn't work instantly
- **Washout effects:** `washout(90)` - Effects persist after stopping
- **Treatment switching:** `switching switchingdetail` - Track patterns

```stata
tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    grace(30) lag(14) washout(90) ///
    switching switchingdetail
```

- **The switching pattern variable captures:** "0→1→4→0" (None → IFN → NTZ → None)

#### Slide 9: tvmerge - When Multiple Exposures Matter (1.5 min)
- **MS-relevant scenario:** DMT + Oral contraceptive use in pregnancy studies
- **Or:** DMT + Antidepressant for fatigue/depression outcomes
- **Or:** Multiple DMT types (high-efficacy vs platform categorization)

```stata
* Create separate time-varying datasets
use ms_cohort, clear
tvexpose using dmt, ... saveas(tv_dmt.dta) replace

use ms_cohort, clear
tvexpose using oc_prescriptions, ... saveas(tv_oc.dta) replace

* Merge them - creates all temporal intersections
tvmerge tv_dmt tv_oc, id(patient_id) ///
    start(start start) stop(stop stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(dmt oc_use)
```

- **Visual:** Two overlapping timelines → merged timeline with all boundaries

#### Slide 10: tvmerge - The Temporal Cartesian Product (1 min)
- **What happens:**

```
DMT:    |───None───|──IFN──|────None────|──NTZ──|
OC:     |────No────|────Yes─────|────No─────────|
        ↓ Merge at all boundaries ↓
Result: |─0,No─|─0,Yes─|─IFN,Yes─|─0,Yes─|─0,No─|─NTZ,No─|
```

- **Output:** Every possible combination, perfectly aligned
- **Key insight:** Exposure status is now defined for every moment of follow-up

#### Slide 11: tvevent - Integrating Outcomes (1.5 min)
- **The final step:** Add events and competing risks
- **MS-specific scenario:** EDSS progression with death as competing risk

```stata
tvevent using ms_cohort, ///
    id(patient_id) date(edss4_date) ///
    compete(death_date emigration_date) ///
    eventlabel(0 "Censored" 1 "EDSS Progression" 2 "Death" 3 "Emigration") ///
    generate(outcome)
```

- **What tvevent does:**
  1. Finds the earliest event (progression vs death vs emigration)
  2. Splits the interval if event occurs mid-period
  3. Flags the event type (outcome = 1, 2, or 3)
  4. Truncates follow-up at the event

#### Slide 12: tvevent - Interval Splitting (1 min)
- **Before tvevent:**

```
id │ start      │ stop       │ dmt
───┼────────────┼────────────┼────────
 1 │ 2020-01-01 │ 2023-12-31 │ 4 (NTZ)
```

- **Event occurs:** EDSS progression on 2022-06-15

- **After tvevent:**

```
id │ start      │ stop       │ dmt     │ outcome
───┼────────────┼────────────┼─────────┼────────
 1 │ 2020-01-01 │ 2022-06-15 │ 4 (NTZ) │ 1 (Progression)
```

- **Post-event follow-up dropped** (for single events)
- **Continuous variables adjusted** proportionally if specified

---

### Act 3: The Analysis (3-4 minutes)

#### Slide 13: The Complete Workflow (1 min)
- **Full pipeline:**

```stata
* Step 1: Create time-varying DMT
use ms_cohort, clear
tvexpose using dmt, id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    keepvars(age_at_onset sex ms_type edss_baseline) ///
    saveas(tv_dmt.dta) replace

* Step 2: Integrate events with competing risks
tvevent using ms_cohort, id(patient_id) ///
    date(edss4_date) compete(death_date) ///
    generate(outcome)

* Step 3: Survival analysis
stset stop, id(patient_id) failure(outcome==1) enter(start)
stcrreg i.tv_exposure age_at_onset i.sex i.ms_type edss_baseline, ///
    compete(outcome==2)
```

#### Slide 14: The Results That Matter (1.5 min)
- **Example results (clinically plausible effect sizes):**

```
Competing-risks regression                        No. of obs     = 45,832
                                                  No. failed     =  2,847
                                                  No. competing  =    612

──────────────────────────────────────────────────────────────────────────
                           │     SHR    [95% CI]           P>|z|
───────────────────────────┼──────────────────────────────────────────────
DMT (vs Unexposed)         │
  Platform therapies       │    0.82    [0.71, 0.95]       0.008
  Moderate-efficacy        │    0.68    [0.56, 0.82]      <0.001
  High-efficacy            │    0.51    [0.41, 0.63]      <0.001
                           │
Age at onset               │    1.02    [1.01, 1.03]      <0.001
Female                     │    0.89    [0.80, 0.99]       0.032
PPMS (vs RRMS)             │    1.74    [1.48, 2.05]      <0.001
Baseline EDSS              │    1.31    [1.25, 1.37]      <0.001
──────────────────────────────────────────────────────────────────────────
```

- **Key insight:** High-efficacy DMTs show ~50% reduction in progression risk
- **This is what proper time-varying analysis reveals**

#### Slide 15: What Goes Wrong Without This (1 min)
- **Common errors and their consequences:**

| Error | Consequence | Magnitude |
|-------|-------------|-----------|
| Baseline exposure only | Misclassification bias | Attenuates toward null |
| Ever-treated without time-varying | Immortal time bias | Spurious protection (can be 2-3x) |
| Ignoring switching | Treatment assigned to wrong periods | Direction unpredictable |
| No competing risks | Informative censoring | Overestimates effect |

- **Reference:** Example studies that got this wrong (don't name names, just cite methodology papers)

---

### Act 4: Wrap-up (2 minutes)

#### Slide 16: Key Takeaways (1 min)
1. **Time-varying analysis is mandatory** for DMT effectiveness studies
2. **tvtools handles the complexity** so you don't have to
3. **Three-command workflow:**
   - `tvexpose`: Raw data → time-varying intervals
   - `tvmerge`: Multiple exposures → synchronized dataset
   - `tvevent`: Add outcomes → analysis-ready data
4. **Integrates seamlessly** with stset, stcox, stcrreg

#### Slide 17: Installation & Resources (30 sec)

```stata
net install tvtools, from(https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools)

help tvexpose
help tvmerge
help tvevent

* GUI interfaces available
db tvexpose
db tvmerge
db tvevent
```

#### Slide 18: Questions / Discussion (flexible)
- **Contact info**
- **GitHub repository**
- **Offer to help with specific projects**

---

## Anticipated Questions & Answers

### Methodological Questions

**Q: How does this compare to manual stsplit?**
A: tvtools automates the entire pipeline and handles edge cases (gaps, overlaps, competing risks) that require significant manual coding with stsplit. It also preserves data integrity through the entire workflow.

**Q: What about time-varying confounders?**
A: tvmerge can combine any number of time-varying exposures. Create separate tvexpose outputs for each confounder, then merge them all together.

**Q: Can I do marginal structural models with this?**
A: Yes. tvtools creates the time-varying dataset structure needed for MSM. You'd then apply IPTW using the time-varying exposure and confounder values.

**Q: How does it handle missing data?**
A: Exposure periods with missing dates are excluded with warnings. You should handle missingness before running tvtools.

### MS-Specific Questions

**Q: Can I analyze treatment sequencing (first-line → second-line)?**
A: Yes. Use the `switching` and `switchingdetail` options to track patterns. You can also create separate exposure variables for each line of therapy.

**Q: What about analyzing by DMT class rather than individual drugs?**
A: Recode your exposure variable before running tvexpose, or use the output and recode afterward. The package is flexible about how you define exposure categories.

**Q: How do I handle patients who were on DMT before study entry?**
A: This is a left-truncation issue. Set your `entry()` date appropriately and consider using `evertreated` which captures prior exposure.

**Q: What about relapses as outcomes (recurrent events)?**
A: Use `tvevent` with `type(recurring)` to retain all follow-up time after events. This creates data suitable for recurrent event models.

### Practical Questions

**Q: How long does this take to run on large datasets?**
A: For typical registry datasets (10,000-50,000 patients), each command runs in seconds to a few minutes. The `batch()` option in tvmerge optimizes memory usage for very large datasets.

**Q: Can I use this with SMSreg data?**
A: Absolutely. The examples use data structures similar to Swedish MS Registry exports. You'll need to map your variable names to the command options.

**Q: Is there a dialog/GUI interface?**
A: Yes. Run `db tvexpose`, `db tvmerge`, or `db tvevent` for point-and-click interfaces.

---

## Visual Design Notes

### Color Scheme (MS-Friendly)
- **Unexposed:** Gray (#9CA3AF)
- **Platform DMTs:** Blue (#3B82F6) - interferon, glatiramer
- **Moderate-efficacy:** Purple (#8B5CF6) - fingolimod, dimethyl fumarate
- **High-efficacy:** Orange (#F97316) - natalizumab, alemtuzumab, ocrelizumab
- **Events:** Red (#EF4444)
- **Code blocks:** Dark background with syntax highlighting

### Key Visuals to Create
1. **Patient journey timeline** - Anna's story with treatment transitions
2. **Immortal time bias diagram** - Side-by-side comparison
3. **Timeline merge animation** - Two exposures combining
4. **Interval splitting animation** - Event cutting through a period
5. **Results forest plot** - DMT effectiveness estimates

### Typography
- **Headings:** Bold, clean (avoid clinical/sterile fonts)
- **Code:** Fira Code or similar monospace
- **Data tables:** Aligned monospace for clarity

---

## Timing Guide (20-minute version)

| Section | Slides | Duration |
|---------|--------|----------|
| The Problem (MS-specific) | 1-4 | 4:00 |
| tvexpose Demo | 5-8 | 5:00 |
| tvmerge Demo | 9-10 | 2:30 |
| tvevent Demo | 11-12 | 2:30 |
| Complete Workflow & Results | 13-15 | 4:00 |
| Wrap-up | 16-18 | 2:00 |
| **Total** | **18** | **20:00** |

---

## Speaker Notes Summary

### Key Points to Emphasize

1. **Slide 3 (Immortal Time Bias):** This is the "aha moment" - most of the audience will have encountered this problem. Make it concrete with the diagram.

2. **Slide 6 (tvexpose transformation):** The before/after is powerful. Emphasize that gaps are automatically handled.

3. **Slide 10 (Temporal Cartesian Product):** This is the unique value of tvmerge - no other tool does this easily.

4. **Slide 14 (Results):** These effect sizes are clinically plausible and match published literature on high-efficacy DMTs. The audience will recognize them as realistic.

5. **Slide 15 (What Goes Wrong):** This validates their concerns and shows the stakes.

### Phrases to Use

- "You've probably seen this in papers..." (creates recognition)
- "The registry captures this complexity..." (validates their data)
- "This is what the method papers recommend..." (appeals to authority)
- "You can reproduce published findings..." (practical value)

### Things to Avoid

- Don't be preachy about methodology - they know it matters
- Don't oversimplify the MS context - they're experts
- Don't pretend there are no limitations - acknowledge edge cases
- Don't dismiss other approaches - position as complementary

---

## Appendix: Complete Working Example

```stata
* ============================================
* tvtools Complete MS Analysis Demonstration
* ============================================

clear all
set more off
version 18.0

* Assume we have:
* - ms_cohort.dta: Patient-level data with dates and outcomes
* - dmt_prescriptions.dta: DMT prescription periods
* - Variables: patient_id, ms_diagnosis_date, study_exit_date,
*              edss4_date, death_date, age_at_onset, sex, ms_type, edss_baseline

* --------------------------------------------
* STEP 1: Create time-varying DMT exposure
* --------------------------------------------
use ms_cohort, clear

tvexpose using dmt_prescriptions, ///
    id(patient_id) ///
    start(dmt_start) ///
    stop(dmt_stop) ///
    exposure(dmt) ///
    reference(0) ///
    entry(ms_diagnosis_date) ///
    exit(study_exit_date) ///
    currentformer ///
    grace(30) ///
    generate(dmt_status) ///
    keepvars(age_at_onset sex ms_type edss_baseline edss4_date death_date) ///
    saveas(tv_dmt_analysis.dta) replace

* --------------------------------------------
* STEP 2: Integrate events and competing risks
* --------------------------------------------
tvevent using ms_cohort, ///
    id(patient_id) ///
    date(edss4_date) ///
    compete(death_date) ///
    eventlabel(0 "Censored" 1 "EDSS Progression" 2 "Death") ///
    generate(outcome) ///
    timegen(interval_years) ///
    timeunit(years)

* --------------------------------------------
* STEP 3: Descriptive statistics
* --------------------------------------------
* Exposure distribution
tab dmt_status, mi

* Events by exposure
tab dmt_status outcome, row

* Person-time by exposure
table dmt_status, statistic(sum interval_years) nformat(%9.1f)

* --------------------------------------------
* STEP 4: Survival analysis setup
* --------------------------------------------
stset stop, ///
    id(patient_id) ///
    failure(outcome==1) ///
    enter(start) ///
    scale(365.25) ///
    exit(time .)

* Descriptive
stdescribe
stsum

* Kaplan-Meier by exposure status
sts graph, by(dmt_status) ///
    title("EDSS Progression by DMT Status") ///
    legend(rows(1)) ///
    risktable

* --------------------------------------------
* STEP 5: Competing risks regression
* --------------------------------------------
* Primary analysis: DMT status effect on progression
stcrreg i.dmt_status ///
    age_at_onset ///
    i.sex ///
    i.ms_type ///
    edss_baseline, ///
    compete(outcome==2)

* Store results
estimates store main_model

* Display formatted table
estimates table main_model, ///
    b(%9.3f) se(%9.3f) ///
    stats(N ll chi2) ///
    keep(*.dmt_status)

* --------------------------------------------
* STEP 6: Sensitivity analyses
* --------------------------------------------

* Alternative: Ever-treated analysis
use ms_cohort, clear
tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    evertreated generate(ever_dmt) ///
    keepvars(age_at_onset sex ms_type edss_baseline edss4_date death_date)

tvevent using ms_cohort, id(patient_id) date(edss4_date) ///
    compete(death_date) generate(outcome)

stset stop, id(patient_id) failure(outcome==1) enter(start) scale(365.25)
stcrreg i.ever_dmt age_at_onset i.sex i.ms_type edss_baseline, compete(outcome==2)
estimates store ever_treated_model

* Alternative: Duration categories
use ms_cohort, clear
tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    duration(1 3 5) continuousunit(years) ///
    generate(dmt_duration) ///
    keepvars(age_at_onset sex ms_type edss_baseline edss4_date death_date)

tvevent using ms_cohort, id(patient_id) date(edss4_date) ///
    compete(death_date) generate(outcome)

stset stop, id(patient_id) failure(outcome==1) enter(start) scale(365.25)
stcrreg i.dmt_duration age_at_onset i.sex i.ms_type edss_baseline, compete(outcome==2)
estimates store duration_model

* Compare models
estimates table main_model ever_treated_model duration_model, ///
    b(%9.3f) star stats(N ll aic bic)
```

---

*End of Presentation Plan*
