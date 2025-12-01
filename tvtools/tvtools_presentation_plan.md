# tvtools Presentation Plan

## Presentation Overview

**Title:** From Static to Dynamic: Time-Varying Exposure Analysis with tvtools

**Duration:** 15 minutes

**Target Audience:** Epidemiologists, biostatisticians, and health researchers familiar with Stata survival analysis

**Key Message:** tvtools transforms complex time-varying exposure data into analysis-ready datasets through an intuitive three-command workflow

---

## Presentation Structure

### Act 1: The Problem (3 minutes)

#### Slide 1: Title Slide (30 sec)
- **Title:** From Static to Dynamic: Time-Varying Exposure Analysis with tvtools
- **Subtitle:** A Stata toolkit for survival analysis with time-varying exposures
- **Visual:** Animated rows expanding/splitting

#### Slide 2: The Challenge (1 min)
- **Hook:** "Your patient starts Treatment A, switches to B, then back to A. How do you model this?"
- **Problem statement:** Traditional survival analysis assumes fixed exposures at baseline
- **Reality:**
  - Medications change over time
  - Comorbidities develop
  - Exposures accumulate
- **Visual:** Static single row → question mark

#### Slide 3: What We Need (1 min)
- **Goal:** Transform this...

```
ID | Entry    | Exit     | Treatment
1  | 2020-01  | 2025-01  | A
```

...into this:

```
ID | Start    | Stop     | Treatment | Event
1  | 2020-01  | 2021-06  | None      | 0
1  | 2021-06  | 2022-03  | A         | 0
1  | 2022-03  | 2023-01  | B         | 0
1  | 2023-01  | 2024-08  | A         | 0
1  | 2024-08  | 2025-01  | A         | 1
```

- **Visual:** Animated transition showing one row "exploding" into multiple time periods
- **Point:** This is what tvtools does automatically

#### Slide 4: The tvtools Solution (30 sec)
- **Three integrated commands:**
  1. `tvexpose` - Create time-varying exposures
  2. `tvmerge` - Combine multiple exposures
  3. `tvevent` - Integrate outcomes & competing risks

- **Visual:** Workflow diagram with arrows

---

### Act 2: The Workflow Demo (9 minutes)

#### Slide 5: Meet Our Data (1 min)
- **Dataset descriptions:**
  - `cohort.dta`: 1,000 MS patients with study entry/exit, demographics, outcomes
  - `hrt.dta`: Hormone replacement therapy periods (type, dates, dose)
  - `dmt.dta`: Disease-modifying therapy periods (6 treatment types)

- **Research question:** "Does DMT exposure reduce disability progression, accounting for death as a competing risk?"

- **Visual:** Three data icons representing the datasets

---

#### Slide 6: Step 1 - tvexpose Introduction (30 sec)
- **Purpose:** Transform raw exposure periods into time-varying format
- **Key insight:** Creates intervals where exposure status is constant

```stata
use cohort, clear

tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit)
```

- **Visual:** Code with syntax highlighting

#### Slide 7: tvexpose - The Transformation (1.5 min)
- **Before:** Raw DMT prescription data

```
ID | dmt_start | dmt_stop  | dmt
1  | 2020-03   | 2021-08   | 2 (Interferon)
1  | 2022-01   | 2024-06   | 4 (Natalizumab)
```

- **After:** Time-varying intervals

```
ID | start     | stop      | tv_exposure
1  | 2019-01   | 2020-03   | 0 (Unexposed)
1  | 2020-03   | 2021-08   | 2 (Interferon)
1  | 2021-08   | 2022-01   | 0 (Unexposed)
1  | 2022-01   | 2024-06   | 4 (Natalizumab)
1  | 2024-06   | 2025-01   | 0 (Unexposed)
```

- **Visual:** Animated transformation with rows appearing sequentially
- **Key point:** Gaps automatically filled with reference category

#### Slide 8: tvexpose - Exposure Definitions (1.5 min)
- **Multiple ways to define exposure:**

| Definition | Use Case | Code |
|------------|----------|------|
| Basic | Standard time-varying | `[no option]` |
| Ever-treated | Immortal time bias | `evertreated` |
| Current/Former | Active vs past effects | `currentformer` |
| Duration | Cumulative dose-response | `duration(1 5 10)` |
| Continuous | Continuous predictor | `continuousunit(years)` |

- **Example: Current vs Former DMT**

```stata
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(dmt_status)
```

- **Result:** 0=Never, 1=Currently on DMT, 2=Formerly on DMT
- **Visual:** Three-state diagram showing transitions

#### Slide 9: tvexpose - Advanced Features (1 min)
- **Grace periods:** Treat brief gaps as continuous exposure

```stata
grace(30)  // 30-day gaps become continuous
```

- **Lag/washout:** Model delayed onset and persistent effects

```stata
lag(30) washout(90)  // 30-day delay, 90-day persistence
```

- **Switching tracking:** Identify treatment changes

```stata
switching switchingdetail  // Creates pattern variable
```

- **Visual:** Timeline showing lag and washout visually

---

#### Slide 10: Step 2 - tvmerge Introduction (30 sec)
- **Purpose:** Combine multiple time-varying exposures
- **Challenge:** HRT and DMT periods don't align - how to merge?
- **Solution:** Temporal Cartesian product - creates all intersections

#### Slide 11: tvmerge - The Merge Process (1.5 min)
- **Setup:** Create two tvexpose outputs

```stata
* HRT time-varying dataset
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_hrt.dta) replace

* DMT time-varying dataset
use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas(tv_dmt.dta) replace
```

- **Merge:**

```stata
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(hrt dmt_type)
```

- **Visual:** Two timelines merging into one with intersection points highlighted

#### Slide 12: tvmerge - Result Visualization (1 min)
- **Before merge:** Two separate timelines

```
HRT:  |---None---|--Estrogen--|---None---|
DMT:  |--None--|---IFN---|---None---|--NTZ--|
```

- **After merge:** Combined intervals

```
      |--0,0--|--0,IFN--|--E,IFN--|--E,0--|--0,0--|--0,NTZ--|
```

- **Output structure:**

```
ID | start     | stop      | hrt | dmt_type
1  | 2020-01   | 2020-06   | 0   | 0
1  | 2020-06   | 2021-03   | 0   | 2
1  | 2021-03   | 2021-09   | 1   | 2
1  | 2021-09   | 2022-04   | 1   | 0
1  | 2022-04   | 2023-01   | 0   | 0
1  | 2023-01   | 2025-01   | 0   | 4
```

- **Visual:** Animated splitting showing how periods divide at boundaries

---

#### Slide 13: Step 3 - tvevent Introduction (30 sec)
- **Purpose:** Integrate outcomes and competing risks
- **Challenge:** Events occur mid-interval - need to split!
- **Key task:** Create analysis-ready failure indicator

#### Slide 14: tvevent - Event Integration (1.5 min)
- **Code:**

```stata
tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) ///
    generate(outcome) type(single)
```

- **What happens:**
  1. Identifies earliest event (progression vs death)
  2. Splits interval if event occurs mid-period
  3. Flags the event type
  4. Drops post-event follow-up (for `type(single)`)

- **Before tvevent:**

```
ID | start     | stop      | hrt | dmt
1  | 2023-01   | 2025-01   | 0   | 4
```

- **Event occurs:** 2024-03 (EDSS progression)

- **After tvevent:**

```
ID | start     | stop      | hrt | dmt | outcome
1  | 2023-01   | 2024-03   | 0   | 4   | 1 (Event!)
```

- **Visual:** Timeline with event marker, showing truncation

#### Slide 15: tvevent - Competing Risks (1 min)
- **Multiple competing events:**

```stata
tvevent using cohort, id(id) date(edss4_dt) ///
    compete(death_dt emigration_dt) ///
    eventlabel(0 "Censored" 1 "Progression" 2 "Death" 3 "Emigrated") ///
    generate(status)
```

- **Outcome coding:**
  - 0 = Censored
  - 1 = Primary event (EDSS progression)
  - 2 = Death (competing)
  - 3 = Emigration (competing)

- **Visual:** Branching tree showing possible outcomes

---

### Act 3: Analysis & Wrap-up (3 minutes)

#### Slide 16: Complete Workflow (1 min)
- **Full pipeline in one view:**

```stata
* Step 1: Create time-varying exposures
use cohort, clear
tvexpose using hrt, ... saveas(tv_hrt.dta) replace

use cohort, clear
tvexpose using dmt, ... saveas(tv_dmt.dta) replace

* Step 2: Merge exposures
tvmerge tv_hrt tv_dmt, ...
    generate(hrt dmt_type)

* Step 3: Integrate events
tvevent using cohort, id(id) date(edss4_dt) compete(death_dt) ///
    generate(outcome)

* Step 4: Survival analysis
stset stop, id(id) failure(outcome==1) enter(start)
stcrreg i.hrt i.dmt_type, compete(outcome==2)
```

- **Visual:** Flowchart with data transformation at each step

#### Slide 17: The Payoff - Results (1 min)
- **stcrreg output:** (example hazard ratios)

```
                        SHR    [95% CI]       P
hrt
  Estrogen only        0.89   [0.72-1.10]   0.284
  Combined HRT         0.76   [0.58-0.99]   0.042

dmt_type
  Interferon beta      0.65   [0.51-0.83]   0.001
  Glatiramer           0.71   [0.54-0.93]   0.013
  Natalizumab          0.42   [0.29-0.61]  <0.001
  Fingolimod           0.53   [0.38-0.74]  <0.001
```

- **Key insight:** Properly accounting for time-varying exposure reveals true effects
- **Visual:** Forest plot of hazard ratios

#### Slide 18: Key Takeaways (30 sec)
- **Three commands, one workflow:**
  - `tvexpose`: Raw data → time-varying intervals
  - `tvmerge`: Multiple exposures → synchronized dataset
  - `tvevent`: Add outcomes → analysis-ready data

- **Benefits:**
  - Handles complex exposure patterns automatically
  - Supports competing risks out of the box
  - Integrates seamlessly with `stset`/`stcox`/`stcrreg`

#### Slide 19: Installation & Resources (30 sec)

```stata
net install tvtools, from(https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools)

help tvexpose
help tvmerge
help tvevent

db tvexpose  // GUI interface
```

- **Documentation:** Full examples in help files
- **Visual:** QR code to GitHub repo

#### Slide 20: Thank You / Questions
- **Contact info**
- **Visual:** Animated tvtools logo

---

## Visual Design Notes

### Key Animations

1. **Row Explosion Effect** (Slides 3, 7, 12)
   - One static row transforms into multiple time-varying rows
   - Use fade-in with stagger effect
   - Color-code different exposure states

2. **Timeline Merge Animation** (Slides 11, 12)
   - Two parallel timelines
   - Vertical lines drop at intersection points
   - New combined timeline emerges below

3. **Event Splitting Animation** (Slide 14)
   - Timeline with event marker dropping in
   - Interval visibly "cuts" at event point
   - Post-event portion fades/drops away

### Color Scheme

- **Unexposed:** Light gray (#E0E0E0)
- **Exposure Type A:** Blue (#2196F3)
- **Exposure Type B:** Orange (#FF9800)
- **Events:** Red marker (#F44336)
- **Code blocks:** Dark background (#1E1E1E) with syntax highlighting

### Typography

- **Headings:** Bold, clean sans-serif
- **Code:** Monospace (Fira Code or similar)
- **Body:** Clear, readable at presentation distance

---

## Timing Guide

| Section | Slides | Duration |
|---------|--------|----------|
| The Problem | 1-4 | 3:00 |
| tvexpose Demo | 5-9 | 4:30 |
| tvmerge Demo | 10-12 | 3:00 |
| tvevent Demo | 13-15 | 2:30 |
| Wrap-up | 16-20 | 2:00 |
| **Total** | **20** | **15:00** |

---

## Speaker Notes Summary

### Key Points to Emphasize

1. **Slide 3:** The transformation visual is the "aha moment" - spend time here
2. **Slide 7:** Emphasize that gaps are automatically handled
3. **Slide 12:** The temporal Cartesian product is unique and powerful
4. **Slide 14:** Event splitting is automatic and preserves data integrity
5. **Slide 17:** The statistical results justify the methodology

### Potential Questions to Prepare For

1. "How does this compare to manual `stsplit`?"
   - Answer: tvtools automates the entire process and handles edge cases

2. "What about very large datasets?"
   - Answer: Batch processing option in tvmerge for memory efficiency

3. "Can it handle more than two exposures?"
   - Answer: Yes, tvmerge accepts multiple datasets

4. "What about continuous exposures (not categorical)?"
   - Answer: `continuousunit()` option and `continuous()` in tvmerge

---

## Appendix: Example Code Blocks

### Complete Working Example

```stata
* ============================================
* tvtools Complete Demonstration
* ============================================

clear all
set more off

* Load cohort data
use cohort, clear

* --------------------------------------------
* STEP 1: Create time-varying HRT exposure
* --------------------------------------------
tvexpose using hrt, ///
    id(id) ///
    start(rx_start) ///
    stop(rx_stop) ///
    exposure(hrt_type) ///
    reference(0) ///
    entry(study_entry) ///
    exit(study_exit) ///
    currentformer ///
    generate(hrt_status) ///
    keepvars(age female) ///
    saveas(tv_hrt.dta) replace

* --------------------------------------------
* STEP 2: Create time-varying DMT exposure
* --------------------------------------------
use cohort, clear

tvexpose using dmt, ///
    id(id) ///
    start(dmt_start) ///
    stop(dmt_stop) ///
    exposure(dmt) ///
    reference(0) ///
    entry(study_entry) ///
    exit(study_exit) ///
    generate(dmt_status) ///
    keepvars(mstype edss_baseline) ///
    saveas(tv_dmt.dta) replace

* --------------------------------------------
* STEP 3: Merge time-varying datasets
* --------------------------------------------
tvmerge tv_hrt tv_dmt, ///
    id(id) ///
    start(rx_start dmt_start) ///
    stop(rx_stop dmt_stop) ///
    exposure(hrt_status dmt_status) ///
    generate(hrt dmt) ///
    keep(age female mstype edss_baseline) ///
    check summarize ///
    saveas(tv_merged.dta) replace

* --------------------------------------------
* STEP 4: Integrate events and competing risks
* --------------------------------------------
tvevent using cohort, ///
    id(id) ///
    date(edss4_dt) ///
    compete(death_dt) ///
    eventlabel(0 "Censored" 1 "EDSS Progression" 2 "Death") ///
    generate(outcome) ///
    timegen(interval_years) ///
    timeunit(years)

* --------------------------------------------
* STEP 5: Survival analysis setup
* --------------------------------------------
stset stop, ///
    id(id) ///
    failure(outcome==1) ///
    enter(start) ///
    scale(365.25)

* Descriptive statistics
stdescribe
stsum

* --------------------------------------------
* STEP 6: Competing risks regression
* --------------------------------------------
stcrreg i.hrt i.dmt age_ds1 i.female_ds1 i.mstype_ds2 edss_baseline_ds2, ///
    compete(outcome==2)

* Save results
estimates store main_model
estimates table main_model, b(%9.3f) se(%9.3f) stats(N)
```

---

*End of Presentation Plan*
