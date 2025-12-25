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
set varabbrev off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/tpcopeland/Stata-Tools"
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

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

* Additional demographic and clinical variables (for synthdata/mvp tests)
gen double edss_baseline = round((runiform() * 6) * 2) / 2  // EDSS 0-6 in 0.5 increments
replace edss_baseline = 0 if edss_baseline < 0
label variable edss_baseline "Baseline EDSS score"

gen double bmi = 18 + runiform() * 17  // BMI 18-35
replace bmi = round(bmi, 0.1)
label variable bmi "Body mass index"

gen byte education = 1 + floor(runiform() * 4)  // 1-4 education levels
label variable education "Education level"
label define education_lbl 1 "Primary" 2 "Secondary" 3 "Tertiary" 4 "Postgraduate"
label values education education_lbl

gen byte income_q = 1 + floor(runiform() * 5)  // Income quintile 1-5
label variable income_q "Income quintile"

gen byte comorbidity = floor(runiform() * 4)  // 0-3 comorbidities
label variable comorbidity "Number of comorbidities"

gen byte smoking = floor(runiform() * 3)  // 0=never, 1=former, 2=current
label variable smoking "Smoking status"
label define smoking_lbl 0 "Never" 1 "Former" 2 "Current"
label values smoking smoking_lbl

gen byte region = 1 + floor(runiform() * 21)  // Swedish counties 1-21
label variable region "County of residence"

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

* Events: Emigration (8% rate, for multiple competing risks testing)
gen byte has_emigration = runiform() < 0.08
gen emigration_dt = .
* Emigration can only happen if patient hasn't died
replace emigration_dt = study_entry + 60 + floor(runiform() * (follow_up_days - 120)) if has_emigration & missing(death_dt)
format emigration_dt %td
label variable emigration_dt "Date of emigration"
drop has_emigration

* Ensure emigration doesn't happen on or after death (competing event)
* Note: Emigration can happen after EDSS4 - they are independent events
replace emigration_dt = . if !missing(death_dt) & emigration_dt >= death_dt

* Study exit date (min of: administrative end, death, emigration, or max follow-up)
gen study_exit = study_entry + follow_up_days
replace study_exit = death_dt if !missing(death_dt) & death_dt < study_exit
replace study_exit = emigration_dt if !missing(emigration_dt) & emigration_dt < study_exit
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

* Dose in mg (for dose testing - varies by HRT type)
* Estrogen: 0.3-1.25mg, Combined: 0.3-0.625mg estrogen equivalent, Progestin: 2.5-10mg
gen double dose = .
replace dose = 0.3 + runiform() * 0.95 if hrt_type == 1  // Estrogen
replace dose = 0.3 + runiform() * 0.325 if hrt_type == 2  // Combined
replace dose = 2.5 + runiform() * 7.5 if hrt_type == 3  // Progestin
label variable dose "Daily dose (mg)"

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

keep id hrt_type dose rx_start rx_stop
order id rx_start rx_stop hrt_type dose

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
* Common doses: 500mg (30%), 1000mg (42%), 1250mg (28%)
gen temp = runiform()
gen double steroid_dose = cond(temp < 0.3, 500, cond(temp < 0.72, 1000, 1250))
drop temp
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
* Push start date back to create overlap (1-5 days before previous stop)
replace steroid_start = prev_stop - floor(runiform() * 5) - 1 if create_overlap == 1
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
* DATASET 5b: HOSPITALIZATIONS_WIDE (Wide Format - for tvevent recurring events)
* =============================================================================
display as text _n "Creating hospitalizations_wide.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 40% of patients have hospitalizations (wide format: hosp_date1, hosp_date2, etc.)
gen byte has_hosp = runiform() < 0.40

* Generate up to 5 hospitalization dates per person (wide format)
gen hosp_date1 = study_entry + floor(runiform() * (study_exit - study_entry) * 0.2) if has_hosp
gen hosp_date2 = hosp_date1 + 60 + floor(runiform() * 180) if has_hosp & runiform() < 0.60
gen hosp_date3 = hosp_date2 + 60 + floor(runiform() * 180) if !missing(hosp_date2) & runiform() < 0.50
gen hosp_date4 = hosp_date3 + 60 + floor(runiform() * 180) if !missing(hosp_date3) & runiform() < 0.30
gen hosp_date5 = hosp_date4 + 60 + floor(runiform() * 180) if !missing(hosp_date4) & runiform() < 0.20

* Ensure dates are within study period
foreach v in hosp_date1 hosp_date2 hosp_date3 hosp_date4 hosp_date5 {
    replace `v' = . if `v' > study_exit - 7
    replace `v' = . if `v' <= study_entry
}

format hosp_date1 hosp_date2 hosp_date3 hosp_date4 hosp_date5 %td
label variable hosp_date1 "First hospitalization date"
label variable hosp_date2 "Second hospitalization date"
label variable hosp_date3 "Third hospitalization date"
label variable hosp_date4 "Fourth hospitalization date"
label variable hosp_date5 "Fifth hospitalization date"

drop has_hosp

compress
save "hospitalizations_wide.dta", replace

quietly describe
display as text "  Created hospitalizations_wide.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASET 5c: POINT_EVENTS (Point-in-time events - for pointtime option)
* =============================================================================
display as text _n "Creating point_events.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 50% of patients have point events (e.g., vaccinations, clinic visits)
gen byte has_event = runiform() < 0.50

* Each patient can have 1-6 point events
expand 1 + floor(runiform() * 6) if has_event
bysort id: gen event_num = _n

* Event dates (point in time, no duration)
gen event_date = study_entry + floor(runiform() * (study_exit - study_entry - 14))
format event_date %td
label variable event_date "Event date"

* Event type (1=Vaccination, 2=Clinic visit, 3=Lab test, 4=Imaging)
gen byte event_type = 1 + floor(runiform() * 4)
label variable event_type "Event type"
label define event_type_lbl 0 "None" 1 "Vaccination" 2 "Clinic visit" 3 "Lab test" 4 "Imaging"
label values event_type event_type_lbl

* Remove invalid records
drop if missing(event_date)
drop if event_date <= study_entry | event_date >= study_exit

keep id event_date event_type
order id event_date event_type

compress
save "point_events.dta", replace

quietly describe
display as text "  Created point_events.dta: `r(N)' observations, `r(k)' variables"

* =============================================================================
* DATASET 5d: OVERLAPPING_EXPOSURES (Deliberately overlapping - for split/combine/priority testing)
* =============================================================================
display as text _n "Creating overlapping_exposures.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Select 30% of patients to have overlapping exposures
gen byte has_overlap = runiform() < 0.30

* Create base exposure period
gen exp_start1 = study_entry + floor(runiform() * (study_exit - study_entry - 365))
gen exp_stop1 = exp_start1 + 90 + floor(runiform() * 180)
replace exp_stop1 = study_exit if exp_stop1 > study_exit
gen byte exp_type1 = 1  // Type A

* Create overlapping second exposure (starts during first, different type)
gen exp_start2 = exp_start1 + 30 + floor(runiform() * 60) if has_overlap
gen exp_stop2 = exp_start2 + 120 + floor(runiform() * 180) if has_overlap
replace exp_stop2 = study_exit if !missing(exp_stop2) & exp_stop2 > study_exit
gen byte exp_type2 = 2 if has_overlap  // Type B

* Create third exposure with possible triple overlap
gen exp_start3 = exp_start2 + floor(runiform() * 30) if has_overlap & runiform() < 0.40
gen exp_stop3 = exp_start3 + 60 + floor(runiform() * 120) if !missing(exp_start3)
replace exp_stop3 = study_exit if !missing(exp_stop3) & exp_stop3 > study_exit
gen byte exp_type3 = 3 if !missing(exp_start3)  // Type C

* Reshape to long format
preserve
keep id exp_start1 exp_stop1 exp_type1
rename (exp_start1 exp_stop1 exp_type1) (exp_start exp_stop exp_type)
drop if missing(exp_start) | missing(exp_stop) | exp_stop <= exp_start
tempfile part1
save `part1'

restore, preserve
keep id exp_start2 exp_stop2 exp_type2
rename (exp_start2 exp_stop2 exp_type2) (exp_start exp_stop exp_type)
drop if missing(exp_start) | missing(exp_stop) | exp_stop <= exp_start
tempfile part2
save `part2'

restore
keep id exp_start3 exp_stop3 exp_type3
rename (exp_start3 exp_stop3 exp_type3) (exp_start exp_stop exp_type)
drop if missing(exp_start) | missing(exp_stop) | exp_stop <= exp_start

append using `part1'
append using `part2'

format exp_start exp_stop %td
label variable exp_start "Exposure start date"
label variable exp_stop "Exposure end date"
label variable exp_type "Exposure type"
label define exp_type_lbl 0 "None" 1 "Type A" 2 "Type B" 3 "Type C"
label values exp_type exp_type_lbl

sort id exp_start exp_stop
compress
save "overlapping_exposures.dta", replace

quietly describe
display as text "  Created overlapping_exposures.dta: `r(N)' observations, `r(k)' variables"

* Check for actual overlaps
sort id exp_start
by id: gen byte has_overlap_flag = (exp_start <= exp_stop[_n-1]) if _n > 1
quietly count if has_overlap_flag == 1
local n_overlaps = r(N)
display as text "  [INFO] overlapping_exposures.dta: `n_overlaps' overlapping periods (expected for testing)"
drop has_overlap_flag

* =============================================================================
* DATASET 6: MIGRATIONS (Wide Format - for migrations command testing)
* Format: in_1, out_1, in_2, out_2, ... for immigration/emigration dates
* =============================================================================
display as text _n "Creating migrations_wide.dta..."

use "cohort.dta", clear
keep id study_entry study_exit

* Approximately 25% of patients have migration events during follow-up
gen byte has_migration = runiform() < 0.25

* Migration pattern: emigration (out_N) followed by immigration (in_N)
* in_N = immigration date (return to Sweden)
* out_N = emigration date (left Sweden)

* First migration event pair
gen out_1 = study_entry + floor(runiform() * (study_exit - study_entry)/4) if has_migration
gen in_1 = out_1 + 30 + floor(runiform() * 365) if !missing(out_1)

* Second migration event pair (40% of those with first)
gen out_2 = in_1 + 365 + floor(runiform() * 365) if !missing(in_1) & runiform() < 0.40
gen in_2 = out_2 + 30 + floor(runiform() * 365) if !missing(out_2)

* Third migration event pair (20% of those with second)
gen out_3 = in_2 + 365 + floor(runiform() * 365) if !missing(in_2) & runiform() < 0.20
gen in_3 = out_3 + 30 + floor(runiform() * 365) if !missing(out_3)

* Ensure migration dates are within study period
replace out_1 = . if out_1 > study_exit - 30
replace in_1 = . if in_1 > study_exit - 30 | missing(out_1)
replace out_2 = . if out_2 > study_exit - 30 | missing(in_1)
replace in_2 = . if in_2 > study_exit - 30 | missing(out_2)
replace out_3 = . if out_3 > study_exit - 30 | missing(in_2)
replace in_3 = . if in_3 > study_exit - 30 | missing(out_3)

format in_1 out_1 in_2 out_2 in_3 out_3 %td
label variable in_1 "First immigration date"
label variable out_1 "First emigration date"
label variable in_2 "Second immigration date"
label variable out_2 "Second emigration date"
label variable in_3 "Third immigration date"
label variable out_3 "Third emigration date"

drop has_migration study_entry study_exit

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
gen edss_dt = study_entry + floor((edss_num - 1) * assessment_interval + runiform() * assessment_interval * 0.5)
format edss_dt %td
label variable edss_dt "EDSS assessment date"

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

keep id edss_dt edss
order id edss_dt edss

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
* Introduce various missing rates for different variables
replace age = . if runiform() < 0.05
replace mstype = . if runiform() < 0.03
replace edss_baseline = . if runiform() < 0.08
replace bmi = . if runiform() < 0.10
replace education = . if runiform() < 0.06
replace income_q = . if runiform() < 0.12
replace comorbidity = . if runiform() < 0.04
replace smoking = . if runiform() < 0.07
replace region = . if runiform() < 0.02
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
* EDGE CASE DATASETS (for robustness testing)
* =============================================================================
display as text _n "Creating edge case datasets..."

* Edge case 1: Single observation cohort
clear
set obs 1
gen long id = 1
gen age = 45
gen byte female = 1
gen byte mstype = 1
gen study_entry = date("2015-01-01", "YMD")
gen study_exit = study_entry + 730
gen edss4_dt = study_entry + 365
gen death_dt = .
gen emigration_dt = .
format study_entry study_exit edss4_dt death_dt emigration_dt %td
compress
save "edge_single_obs.dta", replace
display as text "  Created edge_single_obs.dta (1 observation)"

* Edge case 2: Single observation exposure
clear
set obs 1
gen long id = 1
gen rx_start = date("2015-02-01", "YMD")
gen rx_stop = date("2015-08-01", "YMD")
gen byte hrt_type = 1
gen double dose = 0.5
format rx_start rx_stop %td
compress
save "edge_single_exp.dta", replace
display as text "  Created edge_single_exp.dta (1 exposure)"

* Edge case 3: Empty exposure dataset (matching ids in cohort but no exposures)
use "cohort.dta", clear
keep id
gen rx_start = .
gen rx_stop = .
gen byte hrt_type = .
gen double dose = .
format rx_start rx_stop %td
drop if _n > 0  // Empty dataset but with structure
compress
save "edge_empty_exp.dta", replace
display as text "  Created edge_empty_exp.dta (0 exposures)"

* Edge case 4: Very short follow-up (1-7 days per person)
use "cohort.dta", clear
keep id female age
gen study_entry = date("2015-01-01", "YMD") + floor(runiform() * 365)
gen study_exit = study_entry + 1 + floor(runiform() * 6)  // 1-7 days only
gen edss4_dt = .
gen death_dt = .
gen emigration_dt = .
format study_entry study_exit %td
* Keep only first 50 for testing
keep if _n <= 50
compress
save "edge_short_followup.dta", replace
display as text "  Created edge_short_followup.dta (50 obs, 1-7 day follow-up)"

* Edge case 5: Exposure matching short follow-up
* Generate exposures that align with the short follow-up cohort
use "edge_short_followup.dta", clear
keep id study_entry study_exit
* Create exposure that falls within the short study period
gen rx_start = study_entry
gen rx_stop = study_exit - 1  // Exposure ends 1 day before exit
replace rx_stop = rx_start + 1 if rx_stop <= rx_start  // Ensure at least 1 day
gen byte hrt_type = 1 + floor(runiform() * 3)
gen double dose = 0.3 + runiform() * 0.5
format rx_start rx_stop %td
keep id rx_start rx_stop hrt_type dose
compress
save "edge_short_exp.dta", replace
display as text "  Created edge_short_exp.dta (50 short exposures matching cohort)"

* Edge case 6: All same exposure type (no variation)
use "cohort.dta", clear
keep id study_entry study_exit
keep if _n <= 100
expand 2  // Two exposures per person
bysort id: gen exp_num = _n
gen rx_start = study_entry + 30 * exp_num
gen rx_stop = rx_start + 90
replace rx_stop = study_exit if rx_stop > study_exit
gen byte hrt_type = 1  // All type 1
gen double dose = 0.5  // All same dose
drop if rx_stop <= rx_start
keep id rx_start rx_stop hrt_type dose
format rx_start rx_stop %td
compress
save "edge_same_type.dta", replace
display as text "  Created edge_same_type.dta (single exposure type)"

* Edge case 7: Person with no exposure at all (control group only)
use "cohort.dta", clear
keep if _n <= 50  // 50 persons
gen byte has_exp = 0  // No one has exposure
compress
save "edge_no_exposure_cohort.dta", replace
display as text "  Created edge_no_exposure_cohort.dta (unexposed cohort)"

* Edge case 8: Extreme long follow-up (30+ years)
clear
set obs 20
gen long id = _n
gen age = 25 + floor(runiform() * 20)
gen byte female = runiform() < 0.6
gen byte mstype = 1 + floor(runiform() * 4)
gen study_entry = date("1990-01-01", "YMD") + floor(runiform() * 365)
gen study_exit = study_entry + 10950 + floor(runiform() * 3650)  // 30-40 years
gen edss4_dt = .
gen death_dt = .
gen emigration_dt = .
format study_entry study_exit %td
compress
save "edge_long_followup.dta", replace
display as text "  Created edge_long_followup.dta (20 obs, 30-40 year follow-up)"

* Edge case 9: Matching long exposure periods
* Use the long follow-up cohort to create aligned exposures
use "edge_long_followup.dta", clear
keep id study_entry study_exit
* Create multiple exposures per person (3 exposure periods each)
expand 3
bysort id: gen exp_num = _n
* Create exposure periods within the study window
gen rx_start = study_entry + (exp_num - 1) * floor((study_exit - study_entry) / 4)
gen rx_stop = rx_start + 730 + floor(runiform() * 1095)  // 2-5 year exposures
replace rx_stop = study_exit if rx_stop > study_exit
gen byte hrt_type = 1 + floor(runiform() * 3)
gen double dose = 0.3 + runiform() * 0.7
keep id rx_start rx_stop hrt_type dose
format rx_start rx_stop %td
compress
save "edge_long_exp.dta", replace
display as text "  Created edge_long_exp.dta (long exposure periods)"

* Edge case 10: Exposures with exact same start/stop as study period
use "cohort.dta", clear
keep id study_entry study_exit
keep if _n <= 30
gen rx_start = study_entry  // Exactly at entry
gen rx_stop = study_exit    // Exactly at exit
gen byte hrt_type = 1
gen double dose = 0.5
keep id rx_start rx_stop hrt_type dose
format rx_start rx_stop %td
compress
save "edge_boundary_exp.dta", replace
display as text "  Created edge_boundary_exp.dta (exposure = study period)"

* =============================================================================
* LARGE SCALE TEST DATASETS (for stress testing)
* =============================================================================
display as text _n "{hline 70}"
display as text "Creating large-scale test datasets (5000 patients)..."
display as text "{hline 70}"

local n_large = 5000
set seed `seed'

* Large cohort (5000 patients)
clear
set obs `n_large'
gen long id = _n
label variable id "Patient ID"
gen byte female = runiform() < 0.65
label variable female "Female sex"
label define female_lbl_lg 0 "Male" 1 "Female", replace
label values female female_lbl_lg
gen byte age = round(25 + runiform() * 45)
label variable age "Age at study entry"
gen double edss_baseline = round((runiform() * 6) * 2) / 2
replace edss_baseline = 0 if edss_baseline < 0
label variable edss_baseline "Baseline EDSS score"
gen double bmi = 18 + runiform() * 17
replace bmi = round(bmi, 0.1)
label variable bmi "Body mass index"
gen byte education = 1 + floor(runiform() * 4)
label variable education "Education level"
gen byte income_q = 1 + floor(runiform() * 5)
label variable income_q "Income quintile"
gen byte comorbidity = floor(runiform() * 4)
label variable comorbidity "Number of comorbidities"
gen byte smoking = floor(runiform() * 3)
label variable smoking "Smoking status"
gen byte region = 1 + floor(runiform() * 21)
label variable region "County of residence"
gen byte mstype = 1 + floor(runiform() * 4)
label variable mstype "MS type"
gen study_entry = date("2010-01-01", "YMD") + floor(runiform() * 1825)
format study_entry %td
label variable study_entry "Study entry date"
gen double follow_up_days = 365 + floor(runiform() * 3285)
gen byte has_edss4 = runiform() < 0.30
gen edss4_dt = study_entry + 30 + floor(runiform() * (follow_up_days - 60)) if has_edss4
format edss4_dt %td
label variable edss4_dt "Date reached EDSS 4.0"
drop has_edss4
gen byte has_death = runiform() < 0.05
gen death_dt = .
replace death_dt = study_entry + 30 + floor(runiform() * (follow_up_days - 60)) if has_death & missing(edss4_dt)
replace death_dt = edss4_dt + 30 + floor(runiform() * 365) if has_death & !missing(edss4_dt)
format death_dt %td
label variable death_dt "Date of death"
drop has_death
gen byte has_emigration = runiform() < 0.08
gen emigration_dt = .
replace emigration_dt = study_entry + 60 + floor(runiform() * (follow_up_days - 120)) if has_emigration & missing(death_dt)
format emigration_dt %td
label variable emigration_dt "Date of emigration"
drop has_emigration
replace emigration_dt = . if !missing(death_dt) & emigration_dt >= death_dt
gen study_exit = study_entry + follow_up_days
replace study_exit = death_dt if !missing(death_dt) & death_dt < study_exit
replace study_exit = emigration_dt if !missing(emigration_dt) & emigration_dt < study_exit
format study_exit %td
label variable study_exit "Study exit date"
replace edss4_dt = . if edss4_dt > study_exit
replace edss4_dt = . if edss4_dt <= study_entry
drop follow_up_days
compress
save "cohort_large.dta", replace
quietly describe
display as text "  Created cohort_large.dta: `r(N)' observations, `r(k)' variables"

* Large HRT dataset
use "cohort_large.dta", clear
keep id study_entry study_exit
gen byte has_hrt = runiform() < 0.40
expand 1 + floor(runiform() * 5) if has_hrt
bysort id: gen rx_num = _n
gen byte hrt_type = 1 + floor(runiform() * 3)
label variable hrt_type "HRT type"
gen double dose = .
replace dose = 0.3 + runiform() * 0.95 if hrt_type == 1
replace dose = 0.3 + runiform() * 0.325 if hrt_type == 2
replace dose = 2.5 + runiform() * 7.5 if hrt_type == 3
label variable dose "Daily dose (mg)"
gen rx_start = study_entry + floor(runiform() * (study_exit - study_entry - 30))
gen rx_duration = 30 + floor(runiform() * 365)
gen rx_stop = rx_start + rx_duration
replace rx_stop = study_exit if rx_stop > study_exit
format rx_start rx_stop %td
label variable rx_start "Prescription start date"
label variable rx_stop "Prescription end date"
drop if rx_stop <= rx_start
drop if missing(rx_start) | missing(rx_stop)
keep id hrt_type dose rx_start rx_stop
order id rx_start rx_stop hrt_type dose
compress
save "hrt_large.dta", replace
quietly describe
display as text "  Created hrt_large.dta: `r(N)' observations, `r(k)' variables"

* Large DMT dataset
use "cohort_large.dta", clear
keep id study_entry study_exit
gen byte has_dmt = runiform() < 0.60
expand 1 + floor(runiform() * 4) if has_dmt
bysort id: gen dmt_num = _n
gen byte dmt = 1 + floor(runiform() * 6)
label variable dmt "DMT type"
gen dmt_start = study_entry + floor(runiform() * (study_exit - study_entry - 60))
gen dmt_duration = 60 + floor(runiform() * 730)
gen dmt_stop = dmt_start + dmt_duration
replace dmt_stop = study_exit if dmt_stop > study_exit
format dmt_start dmt_stop %td
label variable dmt_start "DMT start date"
label variable dmt_stop "DMT end date"
drop if dmt_stop <= dmt_start
drop if missing(dmt_start) | missing(dmt_stop)
keep id dmt dmt_start dmt_stop
order id dmt_start dmt_stop dmt
compress
save "dmt_large.dta", replace
quietly describe
display as text "  Created dmt_large.dta: `r(N)' observations, `r(k)' variables"

* Large hospitalizations dataset
use "cohort_large.dta", clear
keep id study_entry study_exit
gen byte has_hosp = runiform() < 0.35
expand 1 + floor(runiform() * 4) if has_hosp
bysort id: gen hosp_num = _n
gen hosp_date = study_entry + floor(runiform() * (study_exit - study_entry - 7))
gen hosp_duration = 1 + floor(runiform() * 14)
gen hosp_end = hosp_date + hosp_duration
replace hosp_end = study_exit if hosp_end > study_exit
format hosp_date hosp_end %td
label variable hosp_date "Hospitalization start date"
label variable hosp_end "Hospitalization end date"
gen byte hosp_type = 1 + floor(runiform() * 4)
label variable hosp_type "Hospitalization type"
drop if hosp_end <= hosp_date
drop if missing(hosp_date) | missing(hosp_end)
keep id hosp_date hosp_end hosp_type
order id hosp_date hosp_end hosp_type
compress
save "hospitalizations_large.dta", replace
quietly describe
display as text "  Created hospitalizations_large.dta: `r(N)' observations, `r(k)' variables"

* Very large dataset for memory stress testing (10000 patients, many exposures)
display as text _n "Creating very large stress test dataset (10000 patients)..."
local n_stress = 10000
clear
set obs `n_stress'
gen long id = _n
gen byte female = runiform() < 0.65
gen byte age = round(25 + runiform() * 45)
gen byte mstype = 1 + floor(runiform() * 4)
gen study_entry = date("2005-01-01", "YMD") + floor(runiform() * 3650)
gen double follow_up_days = 365 + floor(runiform() * 5475)
gen study_exit = study_entry + follow_up_days
gen byte has_edss4 = runiform() < 0.30
gen edss4_dt = study_entry + 30 + floor(runiform() * (follow_up_days - 60)) if has_edss4
gen byte has_death = runiform() < 0.05
gen death_dt = .
replace death_dt = study_entry + 30 + floor(runiform() * (follow_up_days - 60)) if has_death & missing(edss4_dt)
replace death_dt = edss4_dt + 30 + floor(runiform() * 365) if has_death & !missing(edss4_dt)
replace study_exit = death_dt if !missing(death_dt) & death_dt < study_exit
replace edss4_dt = . if edss4_dt > study_exit | edss4_dt <= study_entry
format study_entry study_exit edss4_dt death_dt %td
drop follow_up_days has_edss4 has_death
compress
save "cohort_stress.dta", replace
quietly describe
display as text "  Created cohort_stress.dta: `r(N)' observations, `r(k)' variables"

* Stress test exposures (many per patient)
use "cohort_stress.dta", clear
keep id study_entry study_exit
gen byte has_exp = runiform() < 0.70
expand 1 + floor(runiform() * 10) if has_exp
bysort id: gen exp_num = _n
gen byte exp_type = 1 + floor(runiform() * 6)
gen exp_start = study_entry + floor(runiform() * (study_exit - study_entry - 30))
gen exp_duration = 14 + floor(runiform() * 365)
gen exp_stop = exp_start + exp_duration
replace exp_stop = study_exit if exp_stop > study_exit
format exp_start exp_stop %td
drop if exp_stop <= exp_start
drop if missing(exp_start) | missing(exp_stop)
keep id exp_type exp_start exp_stop
order id exp_start exp_stop exp_type
compress
save "exposures_stress.dta", replace
quietly describe
display as text "  Created exposures_stress.dta: `r(N)' observations, `r(k)' variables"

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

local files "cohort hrt dmt steroids hospitalizations hospitalizations_wide point_events overlapping_exposures migrations_wide edss_long cohort_miss hrt_miss dmt_miss edge_single_obs edge_single_exp edge_empty_exp edge_short_followup edge_short_exp edge_same_type edge_no_exposure_cohort edge_long_followup edge_long_exp edge_boundary_exp cohort_large hrt_large dmt_large hospitalizations_large cohort_stress exposures_stress"
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
