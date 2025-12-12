/*******************************************************************************
* generate_test_data.do
*
* Purpose: Generate synthetic test datasets for testing tvtools, mvp, and
*          related Stata commands
*
* Instructions:
*   1. Run this file in Stata to generate all synthetic datasets
*   2. Datasets will be saved in _testing/data/
*   3. Use these datasets to run the test_*.do files
*
* Output datasets:
*   - cohort.dta: Base patient cohort with demographics and outcomes
*   - hrt.dta: HRT (hormone replacement therapy) prescription records
*   - dmt.dta: DMT (disease-modifying therapy) records
*   - steroids.dta: Steroid prescriptions with dose amounts (for dose testing)
*   - hospitalizations.dta: Hospitalization events
*   - migrations_wide.dta: Migration records (wide format)
*   - edss_long.dta: EDSS scores over time (long format)
*   - *_miss.dta: Versions with missing data patterns
*
* Author: Timothy P Copeland
* Date: 2025-12-06
* Updated: 2025-12-12 (added steroids dataset, reorganized paths)
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Local machine path (for Claude with stata-mcp access)
* Update this path if your local clone is in a different location
global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"

* Directory structure
global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* Change to the data directory
cd "${DATA_DIR}"

* Display setup information
display as text _n "{hline 70}"
display as text "SYNTHETIC DATA GENERATION FOR STATA-TOOLS TESTING"
display as text "{hline 70}"
display as text "Repository path: ${STATA_TOOLS_PATH}"
display as text "Output directory: ${DATA_DIR}"
display as text "{hline 70}"

* =============================================================================
* INSTALL PACKAGES FROM LOCAL REPOSITORY
* =============================================================================
display as text _n "Installing packages from local repository..."

* Install synthdata package (contains generate_test_data helper if available)
capture net uninstall synthdata
capture noisily net install synthdata, from("${STATA_TOOLS_PATH}/synthdata")

* Install tvtools for later testing
capture net uninstall tvtools
capture noisily net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

* =============================================================================
* CONFIGURATION PARAMETERS
* =============================================================================
local seed 12345
local n_patients 1000

set seed `seed'

display as text _n "Configuration:"
display as text "  Random seed: `seed'"
display as text "  Number of patients: `n_patients'"
display as text "{hline 70}"

* =============================================================================
* DATASET 1: COHORT (Base Patient Data)
* =============================================================================
display as text _n "Creating cohort.dta..."

clear
set obs `n_patients'

* Patient ID
gen long id = _n
label variable id "Patient ID"

* Demographics
gen byte female = runiform() < 0.65
label variable female "Female sex"
label define female_lbl 0 "Male" 1 "Female"
label values female female_lbl

gen byte age = round(25 + runiform() * 45)  // Age 25-70
label variable age "Age at study entry"

* MS type (for MS-related tests)
gen byte mstype = 1 + floor(runiform() * 4)
label variable mstype "MS type"
label define mstype_lbl 1 "RRMS" 2 "SPMS" 3 "PPMS" 4 "CIS"
label values mstype mstype_lbl

* Study dates
gen study_entry = date("2010-01-01", "YMD") + floor(runiform() * 1825)  // 5 years of entry
format study_entry %td
label variable study_entry "Study entry date"

* Follow-up duration (1-10 years)
gen double follow_up_days = 365 + floor(runiform() * 3285)

* Events: EDSS4 progression (30% rate)
gen byte has_edss4 = runiform() < 0.30
gen edss4_dt = study_entry + 30 + floor(runiform() * (follow_up_days - 60)) if has_edss4
format edss4_dt %td
label variable edss4_dt "Date reached EDSS 4.0"
drop has_edss4

* Events: Death (5% rate, always after EDSS4 if both occur)
gen byte has_death = runiform() < 0.05
gen death_dt = .
replace death_dt = study_entry + 30 + floor(runiform() * (follow_up_days - 60)) if has_death & missing(edss4_dt)
replace death_dt = edss4_dt + 30 + floor(runiform() * 365) if has_death & !missing(edss4_dt)
format death_dt %td
label variable death_dt "Date of death"
drop has_death

* Study exit date (min of: administrative end, death, or max follow-up)
gen study_exit = study_entry + follow_up_days
replace study_exit = death_dt if !missing(death_dt) & death_dt < study_exit
format study_exit %td
label variable study_exit "Study exit date"

* Ensure events are within study period
replace edss4_dt = . if edss4_dt > study_exit
replace edss4_dt = . if edss4_dt <= study_entry

drop follow_up_days

compress
save "cohort.dta", replace

quietly describe
display as text "  Created cohort.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASET 2: HRT (Hormone Replacement Therapy Prescriptions)
* =============================================================================
display as text _n "Creating hrt.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 40% of patients have HRT exposure
gen byte has_hrt = runiform() < 0.40

* Each patient can have 1-5 HRT periods
expand 1 + floor(runiform() * 5) if has_hrt
bysort id: gen rx_num = _n

* HRT type (1=Estrogen, 2=Combined, 3=Progestin)
gen byte hrt_type = 1 + floor(runiform() * 3)
label variable hrt_type "HRT type"
label define hrt_type_lbl 0 "None" 1 "Estrogen" 2 "Combined" 3 "Progestin"
label values hrt_type hrt_type_lbl

* Prescription dates
gen rx_start = study_entry + floor(runiform() * (study_exit - study_entry - 30))
gen rx_duration = 30 + floor(runiform() * 365)  // 30-395 days
gen rx_stop = rx_start + rx_duration
replace rx_stop = study_exit if rx_stop > study_exit

format rx_start rx_stop %td
label variable rx_start "Prescription start date"
label variable rx_stop "Prescription end date"

* Remove invalid records
drop if rx_stop <= rx_start
drop if missing(rx_start) | missing(rx_stop)

keep id hrt_type rx_start rx_stop
order id rx_start rx_stop hrt_type

compress
save "hrt.dta", replace

quietly describe
display as text "  Created hrt.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASET 3: DMT (Disease-Modifying Therapy Records)
* =============================================================================
display as text _n "Creating dmt.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 60% of MS patients have DMT exposure
gen byte has_dmt = runiform() < 0.60

* Each patient can have 1-4 DMT periods (switching is common)
expand 1 + floor(runiform() * 4) if has_dmt
bysort id: gen dmt_num = _n

* DMT type (1-6 representing different DMTs)
gen byte dmt = 1 + floor(runiform() * 6)
label variable dmt "DMT type"
label define dmt_lbl 0 "None" 1 "Interferon" 2 "Glatiramer" 3 "Natalizumab" 4 "Fingolimod" 5 "Dimethyl fumarate" 6 "Ocrelizumab"
label values dmt dmt_lbl

* DMT dates
gen dmt_start = study_entry + floor(runiform() * (study_exit - study_entry - 60))
gen dmt_duration = 60 + floor(runiform() * 730)  // 60-790 days
gen dmt_stop = dmt_start + dmt_duration
replace dmt_stop = study_exit if dmt_stop > study_exit

format dmt_start dmt_stop %td
label variable dmt_start "DMT start date"
label variable dmt_stop "DMT end date"

* Remove invalid records
drop if dmt_stop <= dmt_start
drop if missing(dmt_start) | missing(dmt_stop)

keep id dmt dmt_start dmt_stop
order id dmt_start dmt_stop dmt

compress
save "dmt.dta", replace

quietly describe
display as text "  Created dmt.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASET 4: STEROIDS (Steroid Prescriptions with Dose - for dose option testing)
* =============================================================================
display as text _n "Creating steroids.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 50% of patients have steroid exposure
gen byte has_steroids = runiform() < 0.50

* Each patient can have 1-8 steroid courses (often multiple short courses)
expand 1 + floor(runiform() * 8) if has_steroids
bysort id: gen steroid_num = _n

* Steroid dose in mg (methylprednisolone equivalent)
* Common doses: 500mg, 1000mg (1g), 1250mg courses
gen double steroid_dose = 0
replace steroid_dose = 500 if runiform() < 0.3
replace steroid_dose = 1000 if steroid_dose == 0 & runiform() < 0.6
replace steroid_dose = 1250 if steroid_dose == 0
label variable steroid_dose "Steroid dose (mg methylprednisolone)"

* Steroid course type
gen byte steroid_type = 1 + floor(runiform() * 3)
label variable steroid_type "Steroid administration type"
label define steroid_type_lbl 1 "IV pulse" 2 "Oral taper" 3 "IV + oral"
label values steroid_type steroid_type_lbl

* Course dates (steroids are typically short courses)
gen steroid_start = study_entry + floor(runiform() * (study_exit - study_entry - 14))
* Course duration: 3-14 days for IV, 14-28 days for oral/combined
gen steroid_duration = 3 + floor(runiform() * 12) if steroid_type == 1
replace steroid_duration = 14 + floor(runiform() * 15) if steroid_type == 2
replace steroid_duration = 7 + floor(runiform() * 21) if steroid_type == 3
gen steroid_stop = steroid_start + steroid_duration
replace steroid_stop = study_exit if steroid_stop > study_exit

format steroid_start steroid_stop %td
label variable steroid_start "Steroid course start date"
label variable steroid_stop "Steroid course end date"

* Remove invalid records
drop if steroid_stop <= steroid_start
drop if missing(steroid_start) | missing(steroid_stop)

* Create some intentional overlaps for testing proportional dose allocation
* About 20% of consecutive courses within same patient will have slight overlap
sort id steroid_start
by id: gen double prev_stop = steroid_stop[_n-1]
by id: gen byte create_overlap = runiform() < 0.20 if _n > 1 & !missing(prev_stop)
* Push start date back to create overlap
replace steroid_start = prev_stop - floor(runiform() * 5) - 1 if create_overlap == 1 & steroid_start > prev_stop
drop prev_stop create_overlap

keep id steroid_dose steroid_type steroid_start steroid_stop
order id steroid_start steroid_stop steroid_dose steroid_type

compress
save "steroids.dta", replace

quietly describe
display as text "  Created steroids.dta: `r(N)' observations, `r(k)' variables"

* Display summary of dose distribution
display as text "  Dose distribution:"
quietly tab steroid_dose
display as text "    500mg:  " _c
quietly count if steroid_dose == 500
display as result r(N)
display as text "    1000mg: " _c
quietly count if steroid_dose == 1000
display as result r(N)
display as text "    1250mg: " _c
quietly count if steroid_dose == 1250
display as result r(N)

* =============================================================================
* DATASET 5: HOSPITALIZATIONS
* =============================================================================
display as text _n "Creating hospitalizations.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 35% of patients have hospitalizations
gen byte has_hosp = runiform() < 0.35

* Each patient can have 1-4 hospitalizations
expand 1 + floor(runiform() * 4) if has_hosp
bysort id: gen hosp_num = _n

* Hospitalization dates
gen hosp_date = study_entry + floor(runiform() * (study_exit - study_entry - 7))
gen hosp_duration = 1 + floor(runiform() * 14)  // 1-14 days
gen hosp_end = hosp_date + hosp_duration
replace hosp_end = study_exit if hosp_end > study_exit

format hosp_date hosp_end %td
label variable hosp_date "Hospitalization start date"
label variable hosp_end "Hospitalization end date"

* Hospitalization type
gen byte hosp_type = 1 + floor(runiform() * 4)
label variable hosp_type "Hospitalization type"
label define hosp_type_lbl 1 "MS relapse" 2 "Infection" 3 "Other neuro" 4 "Non-neuro"
label values hosp_type hosp_type_lbl

* Remove invalid records
drop if hosp_end <= hosp_date
drop if missing(hosp_date) | missing(hosp_end)

keep id hosp_date hosp_end hosp_type
order id hosp_date hosp_end hosp_type

compress
save "hospitalizations.dta", replace

quietly describe
display as text "  Created hospitalizations.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASET 6: MIGRATIONS (Wide Format - for migrations command testing)
* =============================================================================
display as text _n "Creating migrations_wide.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 25% of patients migrate during follow-up
gen byte has_migration = runiform() < 0.25

* Up to 3 migration events per person
gen migration1_date = study_entry + floor(runiform() * (study_exit - study_entry)/3) if has_migration
gen migration2_date = migration1_date + 365 + floor(runiform() * 365) if has_migration & runiform() < 0.40
gen migration3_date = migration2_date + 365 + floor(runiform() * 365) if !missing(migration2_date) & runiform() < 0.20

* Ensure migration dates are within study period
replace migration1_date = . if migration1_date > study_exit - 30
replace migration2_date = . if migration2_date > study_exit - 30
replace migration3_date = . if migration3_date > study_exit - 30

format migration1_date migration2_date migration3_date %td
label variable migration1_date "First migration date"
label variable migration2_date "Second migration date"
label variable migration3_date "Third migration date"

* Region codes (Swedish counties 1-21)
gen byte region1 = 1 + floor(runiform() * 21) if !missing(migration1_date)
gen byte region2 = 1 + floor(runiform() * 21) if !missing(migration2_date)
gen byte region3 = 1 + floor(runiform() * 21) if !missing(migration3_date)

drop has_migration

compress
save "migrations_wide.dta", replace

quietly describe
display as text "  Created migrations_wide.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASET 7: EDSS_LONG (EDSS Scores Over Time)
* =============================================================================
display as text _n "Creating edss_long.dta..."

use "cohort.dta", clear
keep id study_entry study_exit edss4_dt

* Each patient has 3-10 EDSS assessments
expand 3 + floor(runiform() * 8)
bysort id: gen edss_num = _n

* Assessment dates (spread over follow-up)
bysort id: gen total_assessments = _N
bysort id: gen assessment_interval = (study_exit - study_entry) / total_assessments
gen edss_date = study_entry + floor((edss_num - 1) * assessment_interval + runiform() * assessment_interval * 0.5)
format edss_date %td
label variable edss_date "EDSS assessment date"

* EDSS scores (0-10 in 0.5 increments)
* Baseline EDSS 1.5-4.0, with progression over time
bysort id (edss_num): gen double baseline_edss = 1.5 + runiform() * 2.5 if _n == 1
bysort id (edss_num): replace baseline_edss = baseline_edss[1]

* Progression: small chance of 0.5-1.0 increase each assessment
gen double edss = baseline_edss
bysort id (edss_num): replace edss = edss[_n-1] + 0.5 * (runiform() < 0.15) + 0.5 * (runiform() < 0.05) if _n > 1

* Round to 0.5 increments and cap at 10
replace edss = round(edss * 2) / 2
replace edss = 10 if edss > 10
replace edss = 0 if edss < 0
label variable edss "EDSS score"

keep id edss_date edss
order id edss_date edss

compress
save "edss_long.dta", replace

quietly describe
display as text "  Created edss_long.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASETS WITH MISSING DATA (for robustness testing)
* =============================================================================
display as text _n "Creating datasets with missing data patterns..."

* Cohort with missingness
use "cohort.dta", clear
* Introduce 5% missing for age, 3% for mstype
replace age = . if runiform() < 0.05
replace mstype = . if runiform() < 0.03
save "cohort_miss.dta", replace
display as text "  Created cohort_miss.dta"

* HRT with missingness
use "hrt.dta", clear
* Introduce 2% missing dates
replace rx_start = . if runiform() < 0.02
replace rx_stop = . if runiform() < 0.02
drop if missing(rx_start) | missing(rx_stop)
save "hrt_miss.dta", replace
display as text "  Created hrt_miss.dta"

* DMT with missingness
use "dmt.dta", clear
* Introduce 2% missing dates
replace dmt_start = . if runiform() < 0.02
replace dmt_stop = . if runiform() < 0.02
drop if missing(dmt_start) | missing(dmt_stop)
save "dmt_miss.dta", replace
display as text "  Created dmt_miss.dta"

* =============================================================================
* DATA QUALITY VALIDATION
* =============================================================================
display as text _n "{hline 70}"
display as text "Validating data quality..."
display as text "{hline 70}"

local quality_ok = 1

* Check cohort.dta
quietly {
    use "cohort.dta", clear

    * 1. Verify study_exit > study_entry for all observations
    count if study_exit <= study_entry
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with study_exit <= study_entry"
        local quality_ok = 0
    }

    * 2. Verify event dates are strictly after study_entry (not on day 0)
    count if !missing(edss4_dt) & edss4_dt <= study_entry
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with edss4_dt <= study_entry"
        local quality_ok = 0
    }

    count if !missing(death_dt) & death_dt <= study_entry
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with death_dt <= study_entry"
        local quality_ok = 0
    }

    * 3. Verify death and EDSS4 are mutually consistent
    count if !missing(edss4_dt) & !missing(death_dt) & edss4_dt >= death_dt
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with edss4_dt >= death_dt"
        local quality_ok = 0
    }

    * 4. Verify event dates are within study period
    count if !missing(edss4_dt) & (edss4_dt < study_entry | edss4_dt > study_exit)
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with edss4_dt outside study period"
        local quality_ok = 0
    }
}

* Check hrt.dta
quietly {
    use "hrt.dta", clear
    count if rx_stop <= rx_start
    if r(N) > 0 {
        noisily display as error "  [FAIL] hrt.dta: " r(N) " obs with rx_stop <= rx_start"
        local quality_ok = 0
    }
}

* Check dmt.dta
quietly {
    use "dmt.dta", clear
    count if dmt_stop <= dmt_start
    if r(N) > 0 {
        noisily display as error "  [FAIL] dmt.dta: " r(N) " obs with dmt_stop <= dmt_start"
        local quality_ok = 0
    }
}

* Check steroids.dta
quietly {
    use "steroids.dta", clear
    count if steroid_stop <= steroid_start
    if r(N) > 0 {
        noisily display as error "  [FAIL] steroids.dta: " r(N) " obs with steroid_stop <= steroid_start"
        local quality_ok = 0
    }

    * Check for expected overlaps (should have some for dose testing)
    sort id steroid_start
    by id: gen byte has_overlap = (steroid_start <= steroid_stop[_n-1]) if _n > 1 & id == id[_n-1]
    count if has_overlap == 1
    local n_overlaps = r(N)
    noisily display as text "  [INFO] steroids.dta: `n_overlaps' overlapping periods (expected for dose testing)"
    drop has_overlap
}

* Check edss_long.dta
quietly {
    use "edss_long.dta", clear
    count if edss < 0 | edss > 10
    if r(N) > 0 {
        noisily display as error "  [FAIL] edss_long.dta: " r(N) " obs with invalid EDSS values"
        local quality_ok = 0
    }
}

if `quality_ok' == 1 {
    display as result "  [OK] All data quality checks passed"
}

* =============================================================================
* VERIFICATION: List all created files
* =============================================================================
display as text _n "{hline 70}"
display as text "Verifying created files..."
display as text "{hline 70}"

local files "cohort hrt dmt steroids hospitalizations migrations_wide edss_long cohort_miss hrt_miss dmt_miss"
local all_ok = 1

foreach f of local files {
    capture confirm file "${DATA_DIR}/`f'.dta"
    if _rc == 0 {
        quietly describe using "${DATA_DIR}/`f'.dta", short
        local nobs = r(N)
        local nvars = r(k)
        display as text "  [OK] `f'.dta : `nobs' observations, `nvars' variables"
    }
    else {
        display as error "  [MISSING] `f'.dta"
        local all_ok = 0
    }
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
if `all_ok' == 1 & `quality_ok' == 1 {
    display as result "Data generation complete - all files created and validated!"
}
else {
    display as error "Data generation completed with issues - review output above"
}
display as text "Output directory: ${DATA_DIR}"
display as text "Run the test_*.do files to test each command."
display as text "{hline 70}"
