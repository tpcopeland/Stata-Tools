# tvtools: A Stata Package for Time-Varying Exposure Analysis in Survival Studies

**Timothy P. Copeland**
Department of Clinical Neuroscience
Karolinska Institutet
Stockholm, Sweden
timothy.copeland@ki.se

---

## Abstract

Time-varying exposures present significant analytical challenges in survival studies. Researchers must transform raw exposure period data—such as medication dispensing records or treatment episodes—into analysis-ready datasets suitable for Cox regression or competing risks models. This process is labor-intensive, error-prone, and poorly supported by existing tools. This article introduces tvtools, a Stata package comprising three integrated commands: tvexpose creates time-varying exposure variables from period-based data with support for eight exposure definitions (basic categorical, ever-treated, current/former, duration categories, continuous cumulative, recency, cumulative dose, and categorical dose); tvmerge performs temporal alignment when merging multiple exposures using efficient batch processing; and tvevent integrates outcome events and competing risks with automatic interval splitting. The package workflow produces datasets compatible with stset, stcox, and stcrreg. Comprehensive examples demonstrate applications in pharmacoepidemiology, including addressing immortal time bias, dose-response analyses, and competing risks analyses. The tvtools package is available for Stata 16.0 and later.

**Keywords:** st0001, tvexpose, tvmerge, tvevent, survival analysis, time-varying covariates, competing risks, pharmacoepidemiology, Cox regression, exposure assessment

---

## 1. Introduction

### 1.1 Motivation

Time-varying exposures are ubiquitous in medical and epidemiological research. Patients switch medications, occupational exposures change with job history, and risk factors evolve over the life course. Appropriately modeling these exposures as time-varying covariates is essential for valid causal inference (Hernán and Robins 2020).

Consider a study examining whether hormone replacement therapy (HRT) affects the risk of breast cancer. Raw prescription data might show that patient 1 received HRT from January 2015 to March 2016, then again from September 2016 to December 2018. To analyze this data using Cox regression, researchers must:

1. Create time intervals reflecting when the patient was exposed versus unexposed
2. Ensure the exposure variable changes appropriately at each interval boundary
3. Handle gaps, overlapping prescriptions, and study entry/exit dates
4. Integrate outcome events, potentially splitting intervals when events occur mid-exposure
5. Account for competing risks such as death

Performing these transformations manually is tedious and error-prone. A single mistake in date handling or interval construction can invalidate the entire analysis. Furthermore, naive approaches that treat exposure as a baseline characteristic introduce immortal time bias, artificially inflating apparent protective effects (Suissa 2007).

### 1.2 Existing approaches and their limitations

Stata provides stsplit for creating time-varying datasets, but this command operates on already-structured survival data and cannot directly process raw exposure period data. Researchers must first manually construct the required data structure—the very step that is most challenging. Other approaches involve complex merge operations, reshape commands, and careful date arithmetic that require substantial programming expertise.

The existing workflow typically involves:
1. Manual data manipulation using merge, reshape, and date functions
2. Use of stsplit to split at fixed time intervals
3. Post-processing to correctly assign time-varying exposure values
4. Additional steps to handle competing risks

This process can require hundreds of lines of code, even for straightforward analyses.

### 1.3 Contribution

The tvtools package addresses these challenges by providing three integrated commands that transform raw exposure data into analysis-ready datasets:

- **tvexpose** creates time-varying exposure variables from period-based exposure data
- **tvmerge** performs temporal alignment when merging multiple time-varying exposures
- **tvevent** integrates outcome events and competing risks

Together, these commands implement a complete workflow from raw data to survival analysis:

```
Raw exposure data → tvexpose → [tvmerge] → tvevent → stset → stcox/stcrreg
```

The package handles common complications including overlapping exposures, gaps in coverage, lag and washout periods, and competing risks—all through intuitive options rather than custom programming.

### 1.4 Paper organization

Section 2 provides background on time-varying covariates in survival analysis. Section 3 describes the tvtools workflow and data requirements. Sections 4–6 detail each command. Section 7 presents comprehensive examples. Section 8 compares tvtools with alternative approaches. Section 9 discusses design decisions and limitations. Section 10 concludes.

---

## 2. Background

### 2.1 Time-varying covariates in Cox regression

The Cox proportional hazards model with time-varying covariates takes the form:

$$h(t|\mathbf{x}(t)) = h_0(t) \exp(\boldsymbol{\beta}' \mathbf{x}(t))$$

where $h_0(t)$ is the baseline hazard and $\mathbf{x}(t)$ represents the covariate vector at time $t$. The partial likelihood is computed over risk sets at each failure time, with covariates evaluated at their values at those times (Therneau and Grambsch 2000).

In practice, Stata implements time-varying covariates using the counting process formulation with data in the form:

```
id    start    stop    exposure    failure
1     0        120     0           0
1     120      365     1           0
1     365      730     0           1
```

Each row represents an interval during which covariates remain constant. The stop time of one interval equals the start time of the next (within the same subject). The failure variable indicates whether an event occurred at the end of each interval.

### 2.2 The counting process formulation in Stata

Stata's stset command with the id() and enter() options implements the counting process approach:

```stata
stset stop, failure(failure) id(id) enter(start)
```

The stcox and streg commands then correctly handle the time-varying covariates, updating risk sets appropriately at each failure time.

The key challenge is creating this properly structured data from raw exposure records. The tvtools package automates this transformation.

### 2.3 Competing risks

Many studies involve competing risks—events that preclude the occurrence of the primary outcome. For example, in a study of disease progression, death is a competing risk that prevents the observation of progression.

The Fine and Gray (1999) subdistribution hazard model handles competing risks by modeling the cumulative incidence function directly. Stata implements this model in stcrreg.

For competing risks analysis, the data structure requires a categorical failure variable indicating which event occurred (or censoring):

```
status = 0: censored
status = 1: primary event
status = 2: competing event 1
status = 3: competing event 2
...
```

The tvevent command creates this structure, determining which event occurred first when multiple events are possible.

---

## 3. The tvtools Workflow

### 3.1 Installation

The tvtools package can be installed from GitHub:

```stata
net install tvtools, ///
    from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
```

This installs three commands (tvexpose, tvmerge, tvevent) along with their help files and optional dialog interfaces.

To access the dialog interfaces:

```stata
db tvexpose
db tvmerge
db tvevent
```

### 3.2 Design philosophy

The tvtools workflow separates the data preparation process into three distinct stages:

**Stage 1: Exposure creation (tvexpose)**
Transform raw exposure period data into time-varying exposure variables. This stage handles the temporal merging of exposure records with the study cohort, creating intervals where exposure status changes.

**Stage 2: Exposure merging (tvmerge, optional)**
When multiple exposures must be analyzed simultaneously (e.g., concurrent medications), tvmerge performs temporal alignment to create all possible combinations of exposure states.

**Stage 3: Event integration (tvevent)**
Integrate outcome events and competing risks into the time-varying dataset, splitting intervals when events occur mid-exposure and flagging the event type.

This separation provides flexibility: researchers can run tvexpose once and then use the output for multiple analyses with different event definitions. Similarly, tvmerge outputs can be reused with different outcome specifications.

### 3.3 Data requirements

The tvtools commands require:

**Master dataset (in memory)**
- Person-level cohort data
- Study entry and exit date variables
- Any baseline covariates to retain

**Exposure dataset (specified via using)**
- Exposure period records with start and stop dates
- Exposure type/status variable
- Identifier linking to master dataset

**Event dataset (for tvevent)**
- Event date variables (primary outcome and competing risks)
- Identifier linking to the exposure dataset

All date variables must be numeric Stata dates (not strings). The identifier variable must have consistent values across datasets.

---

## 4. tvexpose: Creating Time-Varying Exposures

### 4.1 Purpose

The tvexpose command transforms period-based exposure data into time-varying exposure variables suitable for survival analysis. It creates one row per person-time period where exposure status changes.

### 4.2 Syntax

```stata
tvexpose using filename, id(varname) start(varname) exposure(varname)
    reference(#) entry(varname) exit(varname) [options]
```

The required options are:

| Option | Description |
|--------|-------------|
| using *filename* | Dataset containing exposure periods |
| id(*varname*) | Person identifier linking to master dataset |
| start(*varname*) | Start date of exposure period in using dataset |
| exposure(*varname*) | Categorical exposure status variable |
| reference(*#*) | Value indicating unexposed/reference status |
| entry(*varname*) | Study entry date from master dataset |
| exit(*varname*) | Study exit date from master dataset |

Additionally, either stop(*varname*) or the pointtime option must be specified.

### 4.3 Exposure definition options

A key feature of tvexpose is the flexibility in defining how exposures are represented. Eight exposure definitions are available:

**Basic time-varying (default)**
No exposure definition option is specified. The exposure variable reflects actual exposure status at each point in time. This is the most straightforward representation.

**Ever-treated**
Option: evertreated
Creates a binary variable that switches from 0 to 1 at the first exposure and remains 1 for all subsequent follow-up. This definition is essential for addressing immortal time bias in ever-vs-never analyses (Suissa 2007).

**Current/former**
Option: currentformer
Creates a trichotomous variable: 0 = never exposed, 1 = currently exposed, 2 = formerly exposed. This allows separate estimation of effects during active exposure versus after exposure cessation.

**Duration categories**
Option: duration(*numlist*)
Creates categories based on cumulative exposure duration. For example, duration(1 5) creates categories for <1 year, 1–5 years, and ≥5 years of cumulative exposure.

**Continuous cumulative**
Option: continuousunit(*unit*)
Creates a continuous variable tracking cumulative exposure time in the specified unit (days, weeks, months, quarters, or years).

**Recency**
Option: recency(*numlist*)
Creates categories based on time since last exposure. For example, recency(1 5) distinguishes current exposure from <1 year since last exposure, 1–5 years since, and ≥5 years since.

**Cumulative dose**
Option: dose
Enables cumulative dose tracking where the exposure() variable contains the dose amount per period (e.g., grams of medication) rather than a categorical exposure type. When periods overlap, dose is allocated proportionally based on daily dose rates. For example, if two 30-day prescriptions of 1 gram each have a 10-day overlap, the overlap period receives ((10/30)×1) + ((10/30)×1) = 0.667 grams. The reference() option defaults to 0 for dose mode. This definition is essential for pharmacoepidemiological studies examining dose-response relationships.

**Categorical dose**
Option: dosecuts(*numlist*)
Used with the dose option to create categorical rather than continuous dose output. The numlist specifies ascending cutpoints for categorization. For example, dosecuts(5 10 20) creates categories: 0=no dose, 1=<5, 2=5–<10, 3=10–<20, 4=≥20. This enables dose-response analysis using categorical exposure levels while accounting for the temporal accumulation of dose.

### 4.4 Data handling options

tvexpose provides options for handling common data quality issues:

**Grace periods**
The grace(*#*) option fills gaps of *#* or fewer days between exposure periods. This is useful when short gaps represent prescription refill delays rather than true cessation. Type-specific grace periods can be specified as grace(1=30 2=60).

**Period merging**
The merge(*#*) option (default: 120 days) merges consecutive periods of the same exposure type if they occur within *#* days. This treats closely spaced identical exposures as continuous.

**Lag and washout**
The lag(*#*) option delays exposure onset by *#* days after the start date. The washout(*#*) option extends exposure effects for *#* days after the stop date. These model biological delays in effect onset and persistence.

### 4.5 Competing exposures

When multiple exposure periods overlap, tvtools must determine which exposure takes precedence:

**Layer (default)**
Later exposures take precedence; earlier exposures resume after the later one ends.

**Priority**
The priority(*numlist*) option specifies priority order. For example, priority(2 1 0) gives exposure type 2 highest priority.

**Split**
The split option creates separate rows for each exposure combination during overlapping periods.

### 4.6 Output options

The generate(*newvar*) option names the output exposure variable (default: tv_exposure). The saveas(*filename*) option saves the result to a file. The keepvars(*varlist*) option retains additional variables from the master dataset.

### 4.7 Stored results

tvexpose stores the following in r():

| Scalar | Description |
|--------|-------------|
| r(N_persons) | Number of unique persons |
| r(N_periods) | Number of time-varying periods |
| r(total_time) | Total person-time in days |
| r(exposed_time) | Exposed person-time in days |
| r(unexposed_time) | Unexposed person-time in days |
| r(pct_exposed) | Percentage of time exposed |

---

## 5. tvmerge: Merging Multiple Exposures

### 5.1 Purpose

When research questions involve multiple concurrent exposures, tvmerge performs temporal alignment to create all possible combinations of exposure states. Unlike standard Stata merge, tvmerge performs time-interval matching—it identifies overlapping periods and creates new intervals representing their intersections.

### 5.2 Syntax

```stata
tvmerge dataset1 dataset2 [dataset3 ...], id(varname) start(namelist)
    stop(namelist) exposure(namelist) [options]
```

The required options are:

| Option | Description |
|--------|-------------|
| id(*varname*) | Person identifier variable in all datasets |
| start(*namelist*) | Start date variables (one per dataset) |
| stop(*namelist*) | Stop date variables (one per dataset) |
| exposure(*namelist*) | Exposure variables (one per dataset) |

### 5.3 The Cartesian product approach

tvmerge creates all possible combinations of overlapping periods. If person A has 3 HRT periods overlapping with 2 DMT periods, the output contains up to 6 intervals representing all combinations.

This approach ensures that:
1. All exposure information is preserved
2. No artificial decisions about which exposure takes precedence
3. The data structure supports interaction analyses

### 5.4 Performance optimization

For large datasets, tvmerge uses batch processing to improve performance. The batch(*#*) option specifies what percentage of unique IDs to process together (default: 20, range: 1–100).

For a dataset with 10,000 unique IDs:
- batch(20) processes 5 batches of 2,000 IDs each
- batch(50) processes 2 batches of 5,000 IDs each
- batch(10) processes 10 batches of 1,000 IDs each

Larger batches are faster but use more memory. For datasets with over 50,000 IDs, smaller batch sizes prevent memory exhaustion.

### 5.5 Output naming

The generate(*namelist*) option provides custom names for output exposure variables. Alternatively, prefix(*string*) adds a common prefix. The startname() and stopname() options name the output date variables (defaults: start, stop).

### 5.6 Stored results

tvmerge stores the following in r():

| Result | Description |
|--------|-------------|
| r(N) | Number of observations |
| r(N_persons) | Number of unique persons |
| r(mean_periods) | Mean periods per person |
| r(max_periods) | Maximum periods for any person |
| r(N_datasets) | Number of datasets merged |
| r(exposure_vars) | Names of exposure variables |

---

## 6. tvevent: Events and Competing Risks

### 6.1 Purpose

The tvevent command is the final step in the tvtools workflow. It integrates outcome events and competing risks into time-varying datasets, preparing them for survival analysis with stset and stcrreg.

### 6.2 Syntax

```stata
tvevent using filename, id(varname) date(varname) [options]
```

The required options are:

| Option | Description |
|--------|-------------|
| using *filename* | Dataset containing event dates |
| id(*varname*) | Person identifier |
| date(*varname*) | Primary event date variable |

**Important:** The master dataset (in memory) must contain variables named start and stop. These are created automatically by tvexpose and tvmerge.

### 6.3 Event resolution

When both primary and competing events are specified via compete(*varlist*), tvevent determines which occurred first:

1. Compares the primary date() with all compete() dates
2. The earliest occurring date becomes the effective event date
3. Creates a status variable coded as:
   - 0 = censored (no event)
   - 1 = primary event
   - 2 = first competing risk
   - 3 = second competing risk, etc.

### 6.4 Interval splitting

If an event occurs in the middle of an exposure interval (start < event < stop), tvevent automatically splits the interval:

Before:
```
id=1, start=0, stop=365, exposure=1, status=0
```

After (if event at day 200):
```
id=1, start=0, stop=200, exposure=1, status=1
```

The post-event interval is dropped for type(single) (the default), which is appropriate for terminal events.

### 6.5 Continuous variable adjustment

When intervals are split, cumulative exposure variables should be proportionally adjusted. The continuous(*varlist*) option handles this automatically:

$$v_{\text{new}} = v_{\text{old}} \times \frac{d_{\text{new}}}{d_{\text{old}}}$$

where $v$ represents the cumulative variable value and $d$ represents duration. This preserves the correct rate and ensures that cumulative totals sum correctly.

### 6.6 Event types

**Single events (default)**
Option: type(single)
The first event is terminal. All follow-up after the event is dropped. This is appropriate for death, disease onset, or other non-repeatable outcomes.

**Recurring events**
Option: type(recurring)
Events can occur multiple times. All follow-up is retained. This requires wide-format event data with numbered variables (e.g., hosp1, hosp2, hosp3). The compete() option is not available with recurring events.

### 6.7 Stored results

tvevent stores the following in r():

| Scalar | Description |
|--------|-------------|
| r(N) | Total observations in output |
| r(N_events) | Total number of events flagged |

---

## 7. Examples

### 7.1 Generating synthetic data

For reproducibility, we first generate synthetic cohort and exposure data:

```stata
clear all
set seed 12345

* Generate cohort with 1,000 persons
set obs 1000
generate id = _n
generate study_entry = mdy(1, 1, 2015) + floor(runiform() * 730)
generate study_exit = study_entry + 365 + floor(runiform() * 1825)
generate age = 30 + floor(runiform() * 40)
generate female = runiform() < 0.55
format study_entry study_exit %tdCCYY-NN-DD

* Generate outcome dates (30% event rate)
generate followup = study_exit - study_entry
generate death_dt = study_entry + floor(runiform() * followup) ///
    if runiform() < 0.15
generate outcome_dt = study_entry + floor(runiform() * followup) ///
    if runiform() < 0.20 & missing(death_dt)
drop followup
format death_dt outcome_dt %tdCCYY-NN-DD

save cohort, replace

* Generate medication exposure periods
clear
set obs 2000
generate id = ceil(_n / 2)
bysort id: generate period = _n
generate rx_start = mdy(1, 1, 2015) + floor(runiform() * 1095)
generate rx_stop = rx_start + 30 + floor(runiform() * 335)
generate med_type = ceil(runiform() * 3)
format rx_start rx_stop %tdCCYY-NN-DD

save medications, replace
```

### 7.2 Basic time-varying exposure analysis

This example demonstrates the fundamental tvtools workflow:

```stata
use cohort, clear

* Step 1: Create time-varying exposure
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(medication) keepvars(age female)

* Step 2: Integrate events
tvevent using cohort, id(id) date(outcome_dt) compete(death_dt) ///
    generate(status)

* Step 3: Declare survival data
stset stop, id(id) failure(status==1) enter(start) scale(365.25)

* Step 4: Analyze
stcox i.medication age female

* Step 5: Competing risks analysis
stcrreg i.medication age female, compete(status==2)
```

The output shows hazard ratios for each medication type compared to unexposed, adjusted for age and sex, with death as a competing risk.

### 7.3 Addressing immortal time bias

Immortal time bias arises when time before first exposure is misclassified as exposed time. The evertreated option addresses this:

```stata
use cohort, clear

* Incorrect analysis (baseline exposure - introduces immortal time bias)
merge 1:1 id using medications, keep(master match) nogen keepusing(med_type)
replace med_type = 0 if missing(med_type)

stset study_exit, failure(outcome_dt != .) origin(study_entry) scale(365.25)
stcox i.med_type age female
* This analysis is BIASED - ever-treated appear protected due to immortal time

* Correct analysis using tvexpose with evertreated
use cohort, clear
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_treated)

tvevent using cohort, id(id) date(outcome_dt) generate(status)

stset stop, id(id) failure(status==1) enter(start) scale(365.25)
stcox ever_treated age female
* This analysis correctly accounts for immortal time
```

### 7.4 Duration-response analysis

To examine whether longer exposure duration increases or decreases risk:

```stata
use cohort, clear

tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(0.5 1 2) continuousunit(years) ///
    generate(duration_cat) keepvars(age female)

* Duration categories: 0=unexposed, 1=<0.5yr, 2=0.5-1yr, 3=1-2yr, 4=≥2yr

tvevent using cohort, id(id) date(outcome_dt) compete(death_dt) ///
    generate(status)

stset stop, id(id) failure(status==1) enter(start) scale(365.25)
stcox i.duration_cat age female

* Test for trend
generate duration_linear = duration_cat
stcox duration_linear age female
```

### 7.5 Cumulative dose tracking

For dose-response analyses where the exposure variable contains actual dose amounts:

```stata
* Add dose variable to medications dataset
use medications, clear
generate dose = runiform() * 2 + 0.5  // Random dose 0.5-2.5 units per prescription
save medications_dose, replace

use cohort, clear

* Continuous cumulative dose
tvexpose using medications_dose, id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose) ///
    entry(study_entry) exit(study_exit) ///
    dose generate(cumul_dose) keepvars(age female)

tvevent using cohort, id(id) date(outcome_dt) compete(death_dt) ///
    generate(status) continuous(cumul_dose)

stset stop, id(id) failure(status==1) enter(start) scale(365.25)
stcox cumul_dose age female
```

The cumul_dose variable accumulates over time. When prescriptions overlap, dose is allocated proportionally based on daily dose rates. This is essential for studies examining whether higher cumulative exposure increases risk.

### 7.6 Categorical dose for dose-response

To create dose categories for comparing risk across dose levels:

```stata
use cohort, clear

tvexpose using medications_dose, id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose) ///
    entry(study_entry) exit(study_exit) ///
    dose dosecuts(2 5 10) generate(dose_cat) keepvars(age female)

* dose_cat categories: 0=no dose, 1=<2, 2=2-<5, 3=5-<10, 4=≥10

tvevent using cohort, id(id) date(outcome_dt) compete(death_dt) ///
    generate(status)

stset stop, id(id) failure(status==1) enter(start) scale(365.25)
stcox i.dose_cat age female

* Test for dose-response trend
generate dose_linear = dose_cat
stcox dose_linear age female
```

This approach parallels duration-response analysis but uses actual dispensed quantities rather than time on treatment.

### 7.7 Multiple concurrent exposures

When patients may receive multiple treatments simultaneously:

```stata
* Create second medication dataset
clear
set obs 1500
generate id = ceil(_n / 1.5)
bysort id: generate period = _n
generate rx_start = mdy(1, 1, 2015) + floor(runiform() * 1095)
generate rx_stop = rx_start + 30 + floor(runiform() * 335)
generate drug2 = ceil(runiform() * 2)
format rx_start rx_stop %tdCCYY-NN-DD
save medications2, replace

* Create time-varying datasets for each exposure
use cohort, clear
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(med1) saveas(tv_med1.dta) replace

use cohort, clear
tvexpose using medications2, id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug2) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(med2) saveas(tv_med2.dta) replace

* Merge the two time-varying datasets
tvmerge tv_med1.dta tv_med2.dta, id(id) ///
    start(start start) stop(stop stop) ///
    exposure(med1 med2) ///
    generate(medication1 medication2) ///
    saveas(tv_merged.dta) replace

* Integrate events
tvevent using cohort, id(id) date(outcome_dt) compete(death_dt) ///
    generate(status)

* Merge baseline covariates
merge m:1 id using cohort, keepusing(age female) keep(match) nogen

* Analyze with interaction
stset stop, id(id) failure(status==1) enter(start) scale(365.25)
stcox i.medication1##i.medication2 age female
```

### 7.8 Current versus former exposure

Distinguishing active treatment effects from residual effects after cessation:

```stata
use cohort, clear

tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(exposure_status) keepvars(age female)

* exposure_status: 0=never, 1=currently exposed, 2=formerly exposed

tvevent using cohort, id(id) date(outcome_dt) compete(death_dt) ///
    generate(status)

stset stop, id(id) failure(status==1) enter(start) scale(365.25)
stcox i.exposure_status age female

* Reference is never-exposed
* Coefficient for 1 = effect of current exposure
* Coefficient for 2 = effect of former exposure
```

### 7.9 Grace periods and gap handling

When small gaps between prescriptions should be treated as continuous exposure:

```stata
use cohort, clear

* Without grace period - gaps count as unexposed
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(status_nograce)

display "Percent exposed without grace: " r(pct_exposed) "%"

* With 30-day grace period - gaps ≤30 days count as continuous exposure
use cohort, clear
tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(30) currentformer generate(status_grace30)

display "Percent exposed with 30-day grace: " r(pct_exposed) "%"
```

### 7.10 Diagnostic options

Verifying data quality before analysis:

```stata
use cohort, clear

tvexpose using medications, id(id) start(rx_start) stop(rx_stop) ///
    exposure(med_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    check gaps overlaps summarize ///
    generate(medication)
```

The diagnostic options display:
- check: Coverage statistics by person
- gaps: Persons with gaps in exposure coverage
- overlaps: Periods with overlapping exposures
- summarize: Exposure distribution summary

---

## 8. Comparison with Existing Methods

### 8.1 Manual data manipulation

Without tvtools, creating time-varying exposure data requires extensive manual programming. A typical workflow might include:

```stata
* Manual approach (simplified - actual code is more complex)
use cohort, clear
cross using medications   // Creates Cartesian product
keep if id == _id         // Match on ID
generate overlap = max(study_entry, rx_start)
generate end = min(study_exit, rx_stop)
keep if overlap < end     // Valid intervals only
* ... additional code for gap handling, event integration, etc.
```

This approach is:
- Error-prone (easy to mishandle date boundaries)
- Inefficient (creates unnecessary records)
- Inflexible (requires rewriting for different exposure definitions)
- Poorly documented (bespoke code varies across projects)

tvtools encapsulates these operations in tested, documented commands.

### 8.2 The stsplit approach

Stata's stsplit command splits survival data at fixed time points:

```stata
stset stop, failure(failure) id(id) enter(start)
stsplit time, at(0(30)3650)  // Split at 30-day intervals
```

However, stsplit requires data already structured in survival format. It cannot:
- Process raw exposure period data
- Handle multiple overlapping exposures
- Create ever-treated or duration-category exposures
- Integrate competing risks

stsplit complements tvtools—after tvtools creates the structured data, stsplit can add additional time splits if needed.

### 8.3 Summary comparison

| Feature | tvtools | Manual | stsplit |
|---------|---------|--------|---------|
| Process raw exposure data | Yes | Requires code | No |
| Multiple exposures | Yes (tvmerge) | Complex | No |
| Ever-treated definition | Yes | Manual | No |
| Duration categories | Yes | Manual | No |
| Competing risks | Yes | Complex | No |
| Batch processing | Yes | No | N/A |
| Validated, tested | Yes | No | Yes |
| Documentation | Help files | Project-specific | Help file |

---

## 9. Discussion

### 9.1 Design decisions

Several design decisions reflect the intended use cases:

**Separate commands for each stage.** This allows intermediate outputs to be saved and reused. For example, tvexpose output can be used in multiple analyses with different event definitions.

**Comprehensive exposure definitions.** The eight exposure definitions in tvexpose cover the most common analytical frameworks in pharmacoepidemiology and occupational health research, including dose-response analyses.

**Batch processing in tvmerge.** The Cartesian product operation can create very large datasets. Batch processing trades some speed for memory efficiency, making the package practical for large cohorts.

### 9.2 Performance considerations

For large datasets:
- tvexpose performance scales with the total number of exposure periods
- tvmerge performance depends on the number of overlapping periods
- Batch size should be decreased for datasets with >50,000 IDs
- The expandunit() option in tvexpose can dramatically increase dataset size

For a typical pharmacoepidemiology study with 50,000 patients and 200,000 prescription records, the full tvtools workflow completes in under 5 minutes on a modern computer.

### 9.3 Limitations

**Single event per interval.** The current implementation assumes at most one event per interval. For high-frequency recurring events, data may need pre-aggregation.

**No direct support for time-dependent coefficients.** tvtools creates time-varying covariates, not time-varying coefficients. Testing the proportional hazards assumption requires post-estimation diagnostics.

**Point-in-time data limitations.** While the pointtime option handles single-day exposures, complex point-process data may require custom preprocessing.

### 9.4 Future directions

Planned enhancements include:
- Support for multiple imputation workflows
- Integration with causal inference frameworks (g-estimation, marginal structural models)
- Optimization for very large datasets using Mata

---

## 10. Conclusions

The tvtools package provides a comprehensive, validated solution for creating time-varying exposure data in survival studies. The three-command workflow—tvexpose, tvmerge, tvevent—transforms raw exposure period data into analysis-ready datasets compatible with Stata's survival analysis suite.

Key advantages include:
- **Reduced programming burden:** Encapsulates complex date arithmetic and merge operations
- **Flexibility:** Eight exposure definitions cover common analytical frameworks
- **Validation:** Built-in diagnostics identify data quality issues
- **Performance:** Batch processing enables analysis of large cohorts
- **Reproducibility:** Documented commands with clear option specifications

The package addresses a critical gap in epidemiological data preparation, enabling researchers to focus on study design and interpretation rather than data manipulation.

---

## Acknowledgments

The author thanks Kyla McKay and Katharina Fink (Department of Clinical Neuroscience, Karolinska Institutet) for supporting the development of this package.

---

## About the Author

Timothy P. Copeland is a researcher at the Department of Clinical Neuroscience, Karolinska Institutet, Stockholm, Sweden. His research focuses on pharmacoepidemiology methods and outcomes in neurological diseases.

---

## References

Fine, J. P., and R. J. Gray. 1999. A proportional hazards model for the subdistribution of a competing risk. *Journal of the American Statistical Association* 94: 496–509. https://doi.org/10.1080/01621459.1999.10474144.

Hernán, M. A., and J. M. Robins. 2020. *Causal Inference: What If*. Boca Raton: Chapman & Hall/CRC.

Suissa, S. 2007. Immortal time bias in observational studies of drug effects. *Pharmacoepidemiology and Drug Safety* 16: 241–249. https://doi.org/10.1002/pds.1357.

Therneau, T. M., and P. M. Grambsch. 2000. *Modeling Survival Data: Extending the Cox Model*. New York: Springer.

---

## Supplementary Materials

### Installation requirements

The tvtools package requires Stata version 16.0 or later. No additional packages are required.

### Complete syntax

Full syntax details are available via Stata help files:

```stata
help tvexpose
help tvmerge
help tvevent
```

### Example data

Synthetic datasets used in this article can be generated using the code in Section 7.1.

---

*Manuscript prepared for submission to The Stata Journal*
