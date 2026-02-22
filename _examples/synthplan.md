# Synthetic Data Plan for Stata-Tools Examples

## Overview

Generate synthetic Swedish administrative register data to demonstrate all
commands in Stata-Tools. The data should resemble a pharmacoepidemiological
new-user cohort study of **two or more drug classes** for a chronic condition,
with longitudinal follow-up, outcomes, comorbidities, and time-varying
covariates.

**Clinical scenario (suggestion):** New users of SSRI vs SNRI antidepressants,
with outcomes including cardiovascular events, self-harm, and death. Any
therapeutically plausible comparison works — the key is the data structure.

---

## Datasets

All datasets are linked by a shared numeric person identifier (`id`).
All dates should be Stata date format (`%td`).

### 1. `cohort.dta` — Study population

One row per person. The analytic cohort after inclusion/exclusion criteria.

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `female` | byte 0/1 | Sex |
| `birth_date` | date | Date of birth |
| `death_date` | date | Date of death (`.` if alive) |
| `study_entry` | date | Cohort entry date (index date / first dispensing) |
| `study_exit` | date | End of follow-up (event, death, emigration, or censoring) |
| `index_age` | double | Age at cohort entry (years) |
| `education` | byte 1-3 | Education level (1=primary, 2=secondary, 3=tertiary) |
| `income_quintile` | byte 1-5 | Disposable income quintile at index |
| `born_abroad` | byte 0/1 | Born outside Sweden |
| `civil_status` | byte 1-4 | Marital status (1=single, 2=married, 3=divorced, 4=widowed) |
| `region` | byte 1-6 | Healthcare region (1-6) |

**Target:** ~10,000-20,000 persons. Mix of ages (18-85), ~60% female
(depression cohort).

**Notes:**
- `study_entry` is typically the first dispensing date
- `study_exit` should reflect a realistic mix of reasons: outcome event,
  death, emigration, end of study period
- Include enough deaths (~5-10%) and events (~8-15%) for meaningful analysis
- Ages should be plausible for the chosen condition

---

### 2. `prescriptions.dta` — Drug dispensing records

One row per dispensed prescription. This is the core exposure data for tvtools.

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `disp_date` | date | Dispensing date |
| `atc` | str7 | ATC code (e.g., N06AB04 for citalopram) |
| `drug_name` | str | Drug name (human-readable) |
| `ddd` | double | Defined daily doses dispensed |
| `package_size` | int | Number of tablets/units |
| `strength_mg` | double | Strength per unit in mg |
| `days_supply` | int | Estimated days supply |

**Requirements:**
- Multiple ATC codes within each class (e.g., 3-4 SSRIs, 2-3 SNRIs)
- Realistic dispensing patterns: initial fill, refills every 30-90 days
- Some patients switch between drugs or classes
- Some patients have gaps (non-adherence), then restart
- Some patients have overlapping prescriptions (early refills)
- Prescriptions both before and during follow-up
- Include a few concomitant medications from other classes (e.g.,
  benzodiazepines, antipsychotics) for tvmerge demonstrations
- `days_supply` is critical for tvexpose stop date calculation

---

### 3. `diagnoses.dta` — Hospital diagnoses (inpatient + outpatient)

One row per diagnosis episode. Resembles the Swedish National Patient Register.

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `visit_date` | date | Admission or visit date |
| `discharge_date` | date | Discharge date (same as visit_date for outpatient) |
| `icd` | str7 | ICD-10 code (e.g., I21, F32.1) — Swedish format, no dots |
| `diagnosis_type` | str1 | "H" (primary), "B" (secondary), "X" (external cause) |
| `care_type` | byte 1/2 | 1=inpatient, 2=outpatient |

**Requirements:**
- Diagnoses both before and during follow-up (comorbidity lookback)
- Include ICD-10 codes for:
  - **Outcomes:** cardiovascular events (I20-I25, I60-I69), self-harm
    (X60-X84), fractures (S72), GI bleeding (K92)
  - **Comorbidities:** depression (F32-F33), anxiety (F40-F41), diabetes
    (E10-E14), hypertension (I10), COPD (J44), alcohol-related (F10),
    prior MI (I21-I22), heart failure (I50), cerebrovascular (I60-I69),
    cancer (C00-C97), dementia (F00-F03), liver disease (K70-K77),
    renal disease (N17-N19), connective tissue (M05-M06, M32-M35)
  - **Charlson components:** enough variety for cci_se to produce a
    meaningful score distribution (0, 1, 2, 3+)
- Some patients have many diagnoses, some have few
- Codes should mix 3-character and 4-character ICD-10 (e.g., I21 and I211)

---

### 4. `procedures.dta` — Surgical/medical procedure codes

One row per procedure. Resembles KVA (Klassifikation av vardatgarder) data.

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `proc_date` | date | Procedure date |
| `kva_code` | str | KVA procedure code |
| `proc_description` | str | Procedure description |

**Requirements:**
- Include KVA codes for:
  - Cardiac procedures: FNG02 (coronary angiography), FNG05 (PCI)
  - ECT: DA024 (electroconvulsive therapy)
  - Other relevant procedures
- Some patients have procedures, many don't
- Enough for procmatch demonstrations

---

### 5. `migrations.dta` — Migration records

One row per migration event. Resembles RTB (Registret over totalbefolkningen).

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `migration_date` | date | Date of migration event |
| `migration_type` | str1 | "E" (emigration) or "I" (immigration) |

**Requirements:**
- Most people have no migration events
- ~3-5% of the cohort should have at least one emigration
- Some emigrate and return (emigration followed by immigration)
- A few emigrate permanently
- Dates must be within the study period
- Used by the `migrations` command to censor/exclude

---

### 6. `lisa.dta` — Longitudinal socioeconomic data

One row per person per year. Resembles LISA (Longitudinell integrationsdatabas
for sjukforsakrings- och arbetsmarknadsstudier).

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `year` | int | Calendar year |
| `disp_income` | double | Disposable income (SEK) |
| `employment` | byte 1-5 | Employment status |
| `education_level` | byte 1-7 | SUN2000 education level |
| `civil_status` | byte 1-4 | Marital status |

**Requirements:**
- One observation per person per year, spanning several years before and
  during follow-up (e.g., 2005-2023)
- Time-varying income, employment, and civil status
- Used by `covarclose` to extract values closest to an index date
- Some missingness in income/employment

---

### 7. `outcomes.dta` — Outcome event dates (derived, one row per person)

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `cv_event_date` | date | First cardiovascular event (`.` if none) |
| `selfharm_date` | date | First self-harm event (`.` if none) |
| `fracture_date` | date | First fracture event (`.` if none) |
| `gi_bleed_date` | date | First GI bleeding event (`.` if none) |

**Notes:** This can be derived from `diagnoses.dta`, but having a
pre-computed version is useful for tvevent demonstrations. The other repo
can generate this from the diagnoses or provide it directly.

---

### 8. `calendar.dta` — Calendar-time external factors

One row per time unit (month or quarter).

| Variable | Type | Description |
|---|---|---|
| `date` | date | First day of period |
| `season` | byte 1-4 | Season (1=winter, 2=spring, 3=summer, 4=fall) |
| `covid_period` | byte 0/1 | COVID-19 pandemic period (Mar 2020+) |
| `unemployment_rate` | double | National unemployment rate (%) |

**Requirements:**
- Monthly or quarterly records spanning the full study period
- Used by `tvcalendar` to merge time-varying external factors
- Include at least one binary and one continuous calendar variable

---

### 9. `relapses.dta` — Clinical events for MS-specific commands (optional)

Only needed if demonstrating cdp, pira, sustainedss. If the clinical scenario
is depression rather than MS, this can be omitted or replaced with a
small standalone MS dataset.

| Variable | Type | Description |
|---|---|---|
| `id` | long | Person identifier |
| `relapse_date` | date | Date of relapse |
| `edss` | double | EDSS score at visit |
| `edss_date` | date | Date of EDSS assessment |
| `dx_date` | date | MS diagnosis date |

---

## Command-to-Dataset Mapping

Below shows which dataset(s) each command needs and a brief usage sketch.

### setools package

| Command | Input Data | Usage |
|---|---|---|
| **cci_se** | `cohort.dta` + `diagnoses.dta` | Compute Charlson index from ICD codes in diagnoses with lookback before `study_entry` |
| **icdexpand** | `diagnoses.dta` | Expand ICD patterns (e.g., `I2*`), validate codes, create matching indicators |
| **procmatch** | `procedures.dta` | Match KVA codes, find first occurrence of cardiac procedures |
| **dateparse** | `cohort.dta` | Calculate lookback/follow-up windows from `study_entry`, validate date ranges |
| **covarclose** | `cohort.dta` + `lisa.dta` | Extract income/employment closest to `study_entry` from longitudinal LISA data |
| **migrations** | `cohort.dta` + `migrations.dta` | Censor or exclude patients who emigrate during follow-up |
| **cdp** | `relapses.dta` (optional) | Confirmed disability progression from EDSS scores |
| **pira** | `relapses.dta` (optional) | Progression independent of relapse activity |
| **sustainedss** | `relapses.dta` (optional) | Sustained EDSS progression |

### tvtools package

| Command | Input Data | Usage |
|---|---|---|
| **tvexpose** | `cohort.dta` + `prescriptions.dta` | Create time-varying exposure from dispensing records. Demonstrate: default (categorical switching), `evertreated`, `currentformer`, `duration()`, `dose`, `recency()`, `continuousunit()`, `bytype`, `grace()`, `priority()`, `layer` |
| **tvevent** | TV dataset + `outcomes.dta` | Add event/failure flags. Demonstrate: single outcome, competing risks, recurring events, time-to-event generation |
| **tvmerge** | Multiple TV datasets | Merge SSRI exposure + benzodiazepine exposure into one TV dataset |
| **tvage** | `cohort.dta` | Generate time-varying age intervals for age-adjusted survival models |
| **tvdiagnose** | TV dataset | Diagnostics: gap detection, overlap checks, coverage, person-time summary |
| **tvbalance** | TV dataset | SMD balance diagnostics across time-varying exposure groups |
| **tvweight** | TV dataset | Compute IPTW weights for time-varying treatment |
| **tvplot** | TV dataset | Swimlane plots, person-time bar charts |
| **tvtable** | TV dataset | Summary tables of person-time, events, incidence rates by exposure |
| **tvestimate** | TV dataset | G-estimation for causal effect of treatment |
| **tvdml** | TV dataset | Double/debiased ML for causal inference with high-dimensional confounders |
| **tvtrial** | `cohort.dta` + `prescriptions.dta` | Target trial emulation — sequential trial design with cloning |
| **tvsensitivity** | Post-estimation | E-value calculation from an estimated hazard ratio |
| **tvpipeline** | `cohort.dta` + `prescriptions.dta` | End-to-end workflow: tvexpose + tvevent + tvdiagnose + tvbalance |
| **tvpass** | `cohort.dta` + `prescriptions.dta` + `outcomes.dta` | PASS/PAES regulatory workflow |
| **tvreport** | TV dataset | Automated analysis report generation |
| **tvcalendar** | TV dataset + `calendar.dta` | Merge calendar-time factors (season, COVID period) into TV data |

### tabtools package

| Command | Input Data | Usage |
|---|---|---|
| **table1_tc** | `cohort.dta` | Baseline characteristics table (Table 1) by treatment group |
| **regtab** | Post-estimation | Export Cox/logistic regression results to Excel |
| **stratetab** | TV dataset | Stratified incidence rates and rate ratios to Excel |
| **effecttab** | Post-estimation | Format treatment effects (margins, contrasts) to Excel |
| **gformtab** | Post-estimation | Format g-formula mediation results to Excel |
| **tablex** | Any Stata table | Generic table-to-Excel exporter |

### Standalone packages

| Command | Input Data | Usage |
|---|---|---|
| **balancetab** | `cohort.dta` | PS balance diagnostics — SMD before/after matching/weighting |
| **iptw_diag** | `cohort.dta` | IPTW weight diagnostics — distribution, ESS, trimming |
| **consort** | `cohort.dta` (+ pre-exclusion data) | CONSORT-style flowchart of cohort inclusion/exclusion |
| **check** | Any dataset | Assertion-based variable checking |
| **validate** | Any dataset | Data validation rule suites |
| **outlier** | `cohort.dta` or `lisa.dta` | Outlier detection on continuous variables (income, age) |
| **mvp** | Any dataset | Missing value pattern analysis |
| **cstat_surv** | Post-stcox | C-statistic after Cox regression |
| **datamap** | Any dataset | Privacy-safe dataset documentation |
| **datefix** | Raw data | Fix messy date variables |
| **compress_tc** | Any dataset | Compress string variables |
| **massdesas** | Directory of .dta files | Bulk describe/tabulate across files |
| **eplot** | Post-estimation | Effect plots — forest plots, coefficient plots |
| **forestpy** | Post-estimation | Python-backed forest plots |
| **synthdata** | `cohort.dta` | Generate synthetic version of the cohort |
| **tc_schemes** | Any graph | Graph color schemes |
| **today** | Any session | Current date macro |

---

## Data Characteristics That Matter

### For tvexpose demonstrations

The prescription data must support all tvexpose modes:

1. **Categorical switching:** Patients who switch from drug A to drug B (and
   back). Requires at least 2-3 distinct exposure categories.
2. **Ever-treated:** Some patients never receive the drug of interest.
3. **Current/former:** Patients who stop treatment and have a former-exposed
   period before the next fill.
4. **Duration categories:** Long enough follow-up that cumulative exposure
   spans meaningful thresholds (e.g., <1 year, 1-5 years, 5+ years).
5. **Dose tracking:** Variable DDD amounts across dispensings for the same
   patient.
6. **Recency:** Patients who stop and have varying time since last exposure.
7. **Overlapping periods:** Some early refills creating overlapping
   prescriptions.
8. **Gaps:** Periods of non-adherence (no dispensing for 60+ days).
9. **Grace periods:** Near-continuous use with small gaps (7-14 days).
10. **Priority/layering:** Concomitant use of drugs from different classes.

### For cci_se demonstrations

- Diagnosis dates spanning ICD eras (mostly ICD-10, but a few ICD-9 codes
  from older records would be a bonus)
- Enough comorbidity variety for a non-trivial Charlson distribution
- Both 3-char and 4-char codes
- Codes with and without dots (cci_se strips dots internally)

### For table1_tc / balancetab

- Mix of continuous and categorical baseline covariates
- Some imbalance between treatment groups (so SMDs are informative)
- Include a few variables with missing values

### For consort

- The generating process should also produce (or the example can derive)
  intermediate counts: total candidates identified, excluded for various
  reasons, final analytic cohort. Could be stored in a `flowchart.dta` or
  simply documented as N at each step so the example can hard-code the
  consort init/step calls.

---

## Size and Performance

- **cohort.dta:** 10,000-20,000 rows
- **prescriptions.dta:** 100,000-300,000 rows (5-20 dispensings per person)
- **diagnoses.dta:** 200,000-500,000 rows (many diagnoses per person)
- **procedures.dta:** 5,000-15,000 rows (sparse)
- **migrations.dta:** 500-1,500 rows (rare events)
- **lisa.dta:** 100,000-300,000 rows (one per person per year, ~15 years)
- **outcomes.dta:** 10,000-20,000 rows (one per person)
- **calendar.dta:** 200-300 rows (monthly over study period)

These sizes are large enough for realistic demonstrations but small enough
to run quickly on any machine.

---

## Study Period

Suggested: **2006-2023** (covers ICD-10-SE era, allows long follow-up,
includes COVID period for tvcalendar).

---

## What NOT to Include

- No personally identifiable information (obviously — it is synthetic)
- No need for perfect clinical realism — the data just needs the right
  *structure* and plausible *patterns* for the commands to work
- No need for geographic coordinates or detailed addresses
- No need for free-text clinical notes

---

## Delivery Format

All files as Stata `.dta` format with:
- Proper variable labels
- Value labels on categorical variables
- Date formats on date variables
- Compressed storage types
- Dataset labels and notes documenting the synthetic nature
