/*******************************************************************************
* generate_synthdata.do
* Generate synthetic Swedish registry data for Stata-Tools examples
* Clinical scenario: New users of SSRI vs SNRI antidepressants
* Study period: 2006-2023
*******************************************************************************/

clear all
set seed 20260222
set more off

local outdir "/home/tpcopeland/Stata-Tools/_examples"

/*******************************************************************************
* 1. cohort.dta — Study population (N=15,000)
*******************************************************************************/
di as text "=== Generating cohort.dta ==="

clear
local N = 15000
set obs `N'

gen long id = _n

* Sex: ~60% female (depression cohort)
gen byte female = runiform() < 0.60

* Birth date: ages 18-85 at study entry, skewed toward 30-60
* Study entry between 2006-2020
gen double study_entry = td(01jan2006) + floor(runiform() * (td(31dec2020) - td(01jan2006)))
format study_entry %td

* Age at entry: beta distribution skewed toward middle ages
gen double _u = rbeta(3, 2)
gen double index_age = 18 + _u * 67
gen double birth_date = study_entry - floor(index_age * 365.25)
format birth_date %td
drop _u

* Treatment group (for generating correlated data): 60% SSRI, 40% SNRI
gen byte _treat = runiform() < 0.60

* Education: correlated with treatment slightly
gen double _p = runiform()
gen byte education = cond(_p < 0.25, 1, cond(_p < 0.65, 2, 3))
drop _p

* Income quintile: correlated with education
gen double _p = runiform()
gen byte income_quintile = 1
replace income_quintile = 2 if _p > 0.20
replace income_quintile = 3 if _p > 0.40
replace income_quintile = 4 if _p > 0.60
replace income_quintile = 5 if _p > 0.80
* Shift up for higher education
replace income_quintile = min(5, income_quintile + 1) if education == 3 & runiform() < 0.3
replace income_quintile = max(1, income_quintile - 1) if education == 1 & runiform() < 0.3
drop _p

* Born abroad: ~15%
gen byte born_abroad = runiform() < 0.15

* Civil status
gen double _p = runiform()
gen byte civil_status = cond(_p < 0.30, 1, cond(_p < 0.65, 2, cond(_p < 0.85, 3, 4)))
* Younger people more likely single
replace civil_status = 1 if index_age < 30 & runiform() < 0.4
drop _p

* Region (1-6)
gen byte region = ceil(runiform() * 6)

* Death and study exit
* ~7% die during follow-up, higher risk for older patients
gen double _death_prob = 0.03 + 0.10 * (index_age / 85)
gen byte _dies = runiform() < _death_prob

* Max follow-up from entry to 31dec2023
gen double _max_fu = td(31dec2023) - study_entry

* Time to death (exponential, median ~3 years for those who die)
gen double _time_death = -ln(runiform()) * 365.25 * 3 if _dies == 1

* Time to emigration (~4% emigrate)
gen byte _emigrates = runiform() < 0.04
gen double _time_emig = floor(runiform() * _max_fu) if _emigrates == 1

* Death date
gen double death_date = study_entry + floor(_time_death) if _dies == 1 & _time_death < _max_fu
format death_date %td

* Study exit: min of death, emigration, end of study, or event (events added later)
gen double study_exit = td(31dec2023)
replace study_exit = min(study_exit, death_date) if death_date < .
replace study_exit = min(study_exit, study_entry + floor(_time_emig)) if _emigrates == 1 & _time_emig < .
* Ensure at least 1 day of follow-up
replace study_exit = study_entry + 1 if study_exit <= study_entry
format study_exit %td

* Labels
label var id "Person identifier"
label var female "Female sex"
label var birth_date "Date of birth"
label var death_date "Date of death"
label var study_entry "Cohort entry date"
label var study_exit "End of follow-up"
label var index_age "Age at cohort entry (years)"
label var education "Education level"
label var income_quintile "Disposable income quintile"
label var born_abroad "Born outside Sweden"
label var civil_status "Marital status"
label var region "Healthcare region"

label define edu_lbl 1 "Primary" 2 "Secondary" 3 "Tertiary"
label values education edu_lbl

label define civil_lbl 1 "Single" 2 "Married" 3 "Divorced" 4 "Widowed"
label values civil_status civil_lbl

label define yn_lbl 0 "No" 1 "Yes"
label values female yn_lbl
label values born_abroad yn_lbl

label define region_lbl 1 "Stockholm" 2 "Uppsala/Orebro" 3 "Southeast" ///
    4 "South" 5 "West" 6 "North"
label values region region_lbl

* Save treatment assignment for use by other datasets
tempfile cohort_full
save `cohort_full'

* Drop internal vars for final dataset
drop _treat _dies _death_prob _max_fu _time_death _emigrates _time_emig
label data "Synthetic cohort: SSRI vs SNRI new users, 2006-2023"
note: Synthetic data for Stata-Tools demonstration. Not real patient data.
compress
save "`outdir'/cohort.dta", replace


/*******************************************************************************
* 2. prescriptions.dta — Drug dispensing records
*******************************************************************************/
di as text "=== Generating prescriptions.dta ==="

use `cohort_full', clear
keep id study_entry study_exit _treat

* SSRI ATC codes and properties
* N06AB04 citalopram 20mg DDD, N06AB10 escitalopram 10mg DDD
* N06AB06 sertraline 50mg DDD, N06AB03 fluoxetine 20mg DDD
* SNRI: N06AX16 venlafaxine 100mg DDD, N06AX21 duloxetine 60mg DDD
* Concomitant: N05BA01 diazepam, N05BA04 oxazepam, N05AH04 quetiapine

* Expand to create multiple dispensings per person (5-20)
gen int _ndisp = 5 + floor(runiform() * 16)
expand _ndisp
bysort id: gen int _seq = _n

* First dispensing = study_entry (index prescription)
gen double disp_date = study_entry if _seq == 1

* Subsequent dispensings: mostly 30-90 day intervals with some gaps
bysort id (disp_date _seq): replace disp_date = disp_date[_n-1] + ///
    30 + floor(runiform() * 60) if _seq > 1
* Add some gaps (non-adherence) ~10% of refills have 60-180 day gap
replace disp_date = disp_date + 60 + floor(runiform() * 120) if ///
    _seq > 2 & runiform() < 0.10
* Add some early refills (overlapping) ~8%
replace disp_date = disp_date - floor(runiform() * 20) if ///
    _seq > 2 & runiform() < 0.08

* Drop dispensings after study_exit + 30 (allow a few post-exit for realism)
drop if disp_date > study_exit + 30

* Assign drug: primarily from assigned class, with some switching
gen str7 atc = ""
gen str20 drug_name = ""
gen double ddd = .
gen double strength_mg = .

* Initial drug assignment based on treatment group
* SSRI group
replace atc = "N06AB04" if _treat == 1 & runiform() < 0.35
replace atc = "N06AB10" if _treat == 1 & atc == "" & runiform() < 0.40
replace atc = "N06AB06" if _treat == 1 & atc == "" & runiform() < 0.50
replace atc = "N06AB03" if _treat == 1 & atc == ""

* SNRI group
replace atc = "N06AX16" if _treat == 0 & runiform() < 0.55
replace atc = "N06AX21" if _treat == 0 & atc == ""

* Some patients switch class mid-treatment (~12%)
replace atc = "N06AX16" if _treat == 1 & _seq > 4 & runiform() < 0.12
replace atc = "N06AB04" if _treat == 0 & _seq > 4 & runiform() < 0.12

* Concomitant medications (~15% of patients get some benzos, ~5% quetiapine)
gen byte _concom_benzo = runiform() < 0.15
gen byte _concom_quet = runiform() < 0.05
* Replace some dispensings with concomitant meds
replace atc = cond(runiform() < 0.5, "N05BA01", "N05BA04") if ///
    _concom_benzo & _seq > 2 & mod(_seq, 4) == 0
replace atc = "N05AH04" if _concom_quet & _seq > 3 & mod(_seq, 5) == 0

* Drug names
replace drug_name = "citalopram"    if atc == "N06AB04"
replace drug_name = "escitalopram"  if atc == "N06AB10"
replace drug_name = "sertraline"    if atc == "N06AB06"
replace drug_name = "fluoxetine"    if atc == "N06AB03"
replace drug_name = "venlafaxine"   if atc == "N06AX16"
replace drug_name = "duloxetine"    if atc == "N06AX21"
replace drug_name = "diazepam"      if atc == "N05BA01"
replace drug_name = "oxazepam"      if atc == "N05BA04"
replace drug_name = "quetiapine"    if atc == "N05AH04"

* DDD and strength based on drug
replace ddd = 1 + floor(runiform() * 3) if inlist(atc, "N06AB04", "N06AB10", "N06AB06", "N06AB03")
replace ddd = 1 + floor(runiform() * 2) if inlist(atc, "N06AX16", "N06AX21")
replace ddd = 0.5 + runiform() * 1.5 if inlist(atc, "N05BA01", "N05BA04")
replace ddd = 0.5 + runiform() if atc == "N05AH04"

replace strength_mg = cond(runiform() < 0.5, 20, 40) if atc == "N06AB04"
replace strength_mg = cond(runiform() < 0.5, 10, 20) if atc == "N06AB10"
replace strength_mg = cond(runiform() < 0.6, 50, 100) if atc == "N06AB06"
replace strength_mg = 20 if atc == "N06AB03"
replace strength_mg = cond(runiform() < 0.5, 75, 150) if atc == "N06AX16"
replace strength_mg = cond(runiform() < 0.5, 30, 60) if atc == "N06AX21"
replace strength_mg = cond(runiform() < 0.5, 5, 10) if atc == "N05BA01"
replace strength_mg = cond(runiform() < 0.5, 10, 15) if atc == "N05BA04"
replace strength_mg = cond(runiform() < 0.5, 25, 100) if atc == "N05AH04"

* Package size and days supply
gen int package_size = cond(runiform() < 0.6, 30, cond(runiform() < 0.7, 60, 100))
replace package_size = cond(runiform() < 0.7, 20, 50) if inlist(atc, "N05BA01", "N05BA04")
gen int days_supply = ceil(package_size / max(ddd, 0.5))
* Cap days supply at reasonable range
replace days_supply = min(days_supply, 100)
replace days_supply = max(days_supply, 7)

format disp_date %td

* Clean up
drop _treat _seq _ndisp study_entry study_exit _concom_benzo _concom_quet

label var id "Person identifier"
label var disp_date "Dispensing date"
label var atc "ATC code"
label var drug_name "Drug name"
label var ddd "Defined daily doses dispensed"
label var package_size "Number of tablets/units"
label var strength_mg "Strength per unit (mg)"
label var days_supply "Estimated days supply"

label data "Synthetic prescription dispensing records"
note: Synthetic PDR-like data. SSRIs, SNRIs, benzodiazepines, quetiapine.
compress
save "`outdir'/prescriptions.dta", replace


/*******************************************************************************
* 3. diagnoses.dta — Hospital diagnoses (NPR-like)
*******************************************************************************/
di as text "=== Generating diagnoses.dta ==="

use `cohort_full', clear
keep id study_entry study_exit index_age _treat

* Each person gets 5-40 diagnosis records spanning lookback + follow-up
gen int _ndiag = 5 + floor(runiform() * 36)
* Older patients and SNRI users (sicker) get more
replace _ndiag = _ndiag + floor(index_age / 20)
expand _ndiag
bysort id: gen int _seq = _n

* Diagnosis dates: some before study_entry (lookback), some during follow-up
* Lookback period: up to 10 years before entry
gen double _lookback_start = max(study_entry - 3652, td(01jan2000))
gen double _range = study_exit - _lookback_start
gen double visit_date = _lookback_start + floor(runiform() * _range)
format visit_date %td

* Discharge date: same day for outpatient, 1-14 days for inpatient
gen byte care_type = cond(runiform() < 0.35, 1, 2)
gen double discharge_date = visit_date + cond(care_type == 1, ceil(runiform() * 14), 0)
format discharge_date %td

* Diagnosis type
gen str1 diagnosis_type = cond(runiform() < 0.60, "H", cond(runiform() < 0.85, "B", "X"))

* ICD-10 codes — weighted assignment
* Depression (very common in this cohort)
* Comorbidities, outcomes
gen str7 icd = ""

* Build a probability-based assignment
gen double _r = runiform()
local cum = 0

* Depression F32/F33 — 25%
local cum = 0.25
replace icd = cond(runiform()<0.5, "F32", "F33") if _r < `cum'
* Add subcodes sometimes
replace icd = icd + string(floor(runiform()*4)) if icd != "" & runiform() < 0.4

* Anxiety F40/F41 — 10%
replace icd = cond(runiform()<0.5, "F40", "F41") if _r >= `cum' & _r < `=`cum'+0.10'
local cum = `cum' + 0.10

* Hypertension I10 — 8%
replace icd = "I10" if _r >= `cum' & _r < `=`cum'+0.08'
local cum = `cum' + 0.08

* Diabetes E10-E14 — 5%
replace icd = "E1" + string(floor(runiform()*5)) if _r >= `cum' & _r < `=`cum'+0.05'
local cum = `cum' + 0.05

* Cardiovascular outcomes I20-I25 — 4%
replace icd = "I2" + string(floor(runiform()*6)) if _r >= `cum' & _r < `=`cum'+0.04'
local cum = `cum' + 0.04

* Cerebrovascular I60-I69 — 3%
replace icd = "I6" + string(floor(runiform()*10)) if _r >= `cum' & _r < `=`cum'+0.03'
local cum = `cum' + 0.03

* Heart failure I50 — 3%
replace icd = "I50" if _r >= `cum' & _r < `=`cum'+0.03'
local cum = `cum' + 0.03

* COPD J44 — 3%
replace icd = "J44" if _r >= `cum' & _r < `=`cum'+0.03'
replace icd = icd + string(floor(runiform()*2)) if icd == "J44" & runiform() < 0.5
local cum = `cum' + 0.03

* Alcohol F10 — 3%
replace icd = "F10" if _r >= `cum' & _r < `=`cum'+0.03'
local cum = `cum' + 0.03

* Cancer C00-C97 — 3%
replace icd = "C" + string(10 + floor(runiform()*88), "%02.0f") if _r >= `cum' & _r < `=`cum'+0.03'
local cum = `cum' + 0.03

* Self-harm X60-X84 — 2%
replace icd = "X" + string(60 + floor(runiform()*25)) if _r >= `cum' & _r < `=`cum'+0.02'
replace diagnosis_type = "X" if substr(icd,1,1) == "X"
local cum = `cum' + 0.02

* Fractures S72 — 2%
replace icd = "S72" if _r >= `cum' & _r < `=`cum'+0.02'
replace icd = icd + string(floor(runiform()*5)) if icd == "S72" & runiform() < 0.5
local cum = `cum' + 0.02

* GI bleeding K92 — 2%
replace icd = "K92" if _r >= `cum' & _r < `=`cum'+0.02'
local cum = `cum' + 0.02

* Dementia F00-F03 — 1%
replace icd = "F0" + string(floor(runiform()*4)) if _r >= `cum' & _r < `=`cum'+0.01'
local cum = `cum' + 0.01

* Liver disease K70-K77 — 2%
replace icd = "K7" + string(floor(runiform()*8)) if _r >= `cum' & _r < `=`cum'+0.02'
local cum = `cum' + 0.02

* Renal disease N17-N19 — 2%
replace icd = "N1" + string(7 + floor(runiform()*3)) if _r >= `cum' & _r < `=`cum'+0.02'
local cum = `cum' + 0.02

* Connective tissue M05/M06/M32-M35 — 1%
replace icd = cond(runiform()<0.5, "M05", cond(runiform()<0.5, "M06", ///
    "M3" + string(2 + floor(runiform()*4)))) if _r >= `cum' & _r < `=`cum'+0.01'
local cum = `cum' + 0.01

* Remaining: other common diagnoses (musculoskeletal, respiratory, etc.)
replace icd = "M54" if icd == "" & runiform() < 0.3
replace icd = "J06" if icd == "" & runiform() < 0.3
replace icd = "R10" if icd == "" & runiform() < 0.3
replace icd = "K21" if icd == "" & runiform() < 0.3
replace icd = "G43" if icd == "" & runiform() < 0.4
replace icd = "L40" if icd == ""

* Add 4-character subcodes to some 3-character codes
replace icd = icd + string(floor(runiform()*10)) if strlen(icd) == 3 & runiform() < 0.35

* Clean up
drop _seq _ndiag _lookback_start _range _r _treat study_entry study_exit index_age

label var id "Person identifier"
label var visit_date "Admission/visit date"
label var discharge_date "Discharge date"
label var icd "ICD-10 code"
label var diagnosis_type "Diagnosis type (H=primary, B=secondary, X=external)"
label var care_type "Care type"

label define care_lbl 1 "Inpatient" 2 "Outpatient"
label values care_type care_lbl

label data "Synthetic hospital diagnosis records (NPR-like)"
note: Synthetic NPR-like data with ICD-10 codes for comorbidities and outcomes.
compress
save "`outdir'/diagnoses.dta", replace


/*******************************************************************************
* 4. procedures.dta — KVA procedure codes
*******************************************************************************/
di as text "=== Generating procedures.dta ==="

use `cohort_full', clear
keep id study_entry study_exit

* ~20% of patients have any procedure, 1-5 procedures each
gen byte _has_proc = runiform() < 0.20
keep if _has_proc
gen int _nproc = 1 + floor(runiform() * 5)
expand _nproc
bysort id: gen int _seq = _n

* Procedure dates during follow-up
gen double proc_date = study_entry + floor(runiform() * (study_exit - study_entry))
format proc_date %td

* KVA codes
gen str10 kva_code = ""
gen str40 proc_description = ""

gen double _r = runiform()
replace kva_code = "FNG02" if _r < 0.20
replace proc_description = "Coronary angiography" if kva_code == "FNG02"

replace kva_code = "FNG05" if _r >= 0.20 & _r < 0.35
replace proc_description = "PCI" if kva_code == "FNG05"

replace kva_code = "DA024" if _r >= 0.35 & _r < 0.50
replace proc_description = "ECT" if kva_code == "DA024"

replace kva_code = "FNA00" if _r >= 0.50 & _r < 0.60
replace proc_description = "Echocardiography" if kva_code == "FNA00"

replace kva_code = "DT011" if _r >= 0.60 & _r < 0.70
replace proc_description = "Psychiatric assessment" if kva_code == "DT011"

replace kva_code = "FPE20" if _r >= 0.70 & _r < 0.80
replace proc_description = "Carotid endarterectomy" if kva_code == "FPE20"

replace kva_code = "JAB30" if _r >= 0.80 & _r < 0.90
replace proc_description = "Upper GI endoscopy" if kva_code == "JAB30"

replace kva_code = "TNX20" if _r >= 0.90
replace proc_description = "Physiotherapy" if kva_code == "TNX20"

drop _has_proc _nproc _seq _r study_entry study_exit

label var id "Person identifier"
label var proc_date "Procedure date"
label var kva_code "KVA procedure code"
label var proc_description "Procedure description"

label data "Synthetic procedure records (KVA-like)"
note: Synthetic surgical/medical procedure data.
compress
save "`outdir'/procedures.dta", replace


/*******************************************************************************
* 5. migrations.dta — Migration records
*******************************************************************************/
di as text "=== Generating migrations.dta ==="

use `cohort_full', clear
keep id study_entry study_exit

* ~4% emigrate
gen byte _emigrates = runiform() < 0.04
keep if _emigrates
drop _emigrates

* First event: emigration
gen double migration_date = study_entry + floor(runiform() * (study_exit - study_entry))
format migration_date %td
gen str1 migration_type = "E"

* ~30% of emigrants return (immigration event)
gen byte _returns = runiform() < 0.30
expand 2 if _returns
bysort id: gen int _seq = _n
replace migration_type = "I" if _seq == 2
replace migration_date = migration_date + 90 + floor(runiform() * 365) if _seq == 2

drop _returns _seq study_entry study_exit

label var id "Person identifier"
label var migration_date "Date of migration event"
label var migration_type "E=emigration, I=immigration"

label data "Synthetic migration records (RTB-like)"
note: Synthetic emigration/immigration data.
compress
save "`outdir'/migrations.dta", replace


/*******************************************************************************
* 6. lisa.dta — Longitudinal socioeconomic data
*******************************************************************************/
di as text "=== Generating lisa.dta ==="

use `cohort_full', clear
keep id study_entry education income_quintile civil_status

* Years 2005-2023
expand 19
bysort id: gen int year = 2004 + _n

* Disposable income: base from quintile, varies over time
gen double _base_income = 100000 + income_quintile * 50000 + rnormal() * 30000
gen double disp_income = _base_income + (year - 2005) * 3000 + rnormal() * 20000
replace disp_income = max(0, disp_income)
* Some missingness (~3%)
replace disp_income = . if runiform() < 0.03

* Employment status (1=employed, 2=self-employed, 3=unemployed, 4=student, 5=retired)
gen double _r = runiform()
gen byte employment = 1
replace employment = 2 if _r > 0.70
replace employment = 3 if _r > 0.80
replace employment = 4 if _r > 0.90
replace employment = 5 if _r > 0.95
* Some missingness
replace employment = . if runiform() < 0.02

* Education level (SUN2000 1-7): mostly stable but some increase
gen byte education_level = education * 2 + cond(runiform() < 0.3, 1, 0)
replace education_level = min(7, education_level)
replace education_level = max(1, education_level)
* Slight increase over time for younger
replace education_level = min(7, education_level + 1) if ///
    year > 2010 & runiform() < 0.05

* Civil status: mostly stable with occasional changes
gen byte civil_status_y = civil_status
replace civil_status_y = 2 if civil_status == 1 & year > 2010 & runiform() < 0.03
replace civil_status_y = 3 if civil_status == 2 & year > 2012 & runiform() < 0.02
drop civil_status
rename civil_status_y civil_status

drop _base_income _r education income_quintile study_entry

label var id "Person identifier"
label var year "Calendar year"
label var disp_income "Disposable income (SEK)"
label var employment "Employment status"
label var education_level "SUN2000 education level"
label var civil_status "Marital status"

label define emp_lbl 1 "Employed" 2 "Self-employed" 3 "Unemployed" ///
    4 "Student" 5 "Retired"
label values employment emp_lbl

label define sun_lbl 1 "Pre-primary" 2 "Primary" 3 "Lower secondary" ///
    4 "Upper secondary" 5 "Post-secondary <2yr" 6 "Post-secondary >=2yr" ///
    7 "Postgraduate"
label values education_level sun_lbl

label values civil_status civil_lbl

label data "Synthetic LISA longitudinal socioeconomic data"
note: Synthetic LISA-like data, 2005-2023, one row per person per year.
compress
save "`outdir'/lisa.dta", replace


/*******************************************************************************
* 7. outcomes.dta — Pre-computed outcome event dates
*******************************************************************************/
di as text "=== Generating outcomes.dta ==="

use "`outdir'/diagnoses.dta", clear
merge m:1 id using "`outdir'/cohort.dta", keepusing(study_entry study_exit) nogen keep(match)

* Keep only diagnoses during follow-up
keep if visit_date >= study_entry & visit_date <= study_exit

* Cardiovascular event: I20-I25
gen byte _cv = regexm(icd, "^I2[0-5]")
* Self-harm: X60-X84
gen byte _sh = regexm(icd, "^X[67][0-9]") | regexm(icd, "^X8[0-4]")
* Fracture: S72
gen byte _fx = regexm(icd, "^S72")
* GI bleeding: K92
gen byte _gi = regexm(icd, "^K92")

* First event date per person per outcome
foreach out in cv sh fx gi {
    gen double _date_`out' = visit_date if _`out' == 1
}
format _date_* %td

collapse (min) cv_event_date=_date_cv selfharm_date=_date_sh ///
    fracture_date=_date_fx gi_bleed_date=_date_gi, by(id)

* Merge back all cohort IDs to ensure one row per person
merge 1:1 id using "`outdir'/cohort.dta", keepusing(id) nogen keep(using match)

format cv_event_date selfharm_date fracture_date gi_bleed_date %td

label var id "Person identifier"
label var cv_event_date "First cardiovascular event date"
label var selfharm_date "First self-harm event date"
label var fracture_date "First fracture event date"
label var gi_bleed_date "First GI bleeding event date"

label data "Synthetic outcome event dates (one row per person)"
note: Derived from diagnoses.dta. First occurrence of each outcome during follow-up.
compress
save "`outdir'/outcomes.dta", replace


/*******************************************************************************
* 8. calendar.dta — Calendar-time external factors (monthly)
*******************************************************************************/
di as text "=== Generating calendar.dta ==="

clear
* Monthly from Jan 2005 to Dec 2023 = 228 months
local nmonths = 228
set obs `nmonths'

gen double date = td(01jan2005) + (_n - 1) * 30.4375
replace date = round(date)
* Snap to first of month
gen int _y = year(date)
gen int _m = month(date)
replace date = mdy(_m, 1, _y)
format date %td

* Season
gen byte season = cond(_m <= 2 | _m == 12, 1, ///
    cond(_m <= 5, 2, cond(_m <= 8, 3, 4)))

* COVID period
gen byte covid_period = date >= td(01mar2020)

* Unemployment rate: ~6-8% pre-COVID, spike to ~9-10% during COVID
gen double unemployment_rate = 6.5 + rnormal() * 0.5
replace unemployment_rate = unemployment_rate + 0.03 * (_n - 1)  // slow trend
replace unemployment_rate = unemployment_rate + 3 if ///
    date >= td(01mar2020) & date < td(01jan2022)
replace unemployment_rate = unemployment_rate + 1 if ///
    date >= td(01jan2022) & date < td(01jan2023)
replace unemployment_rate = max(3, min(12, unemployment_rate))

drop _y _m

label var date "First day of month"
label var season "Season"
label var covid_period "COVID-19 pandemic period"
label var unemployment_rate "National unemployment rate (%)"

label define season_lbl 1 "Winter" 2 "Spring" 3 "Summer" 4 "Fall"
label values season season_lbl
label values covid_period yn_lbl

label data "Synthetic calendar-time factors (monthly, 2005-2023)"
note: Synthetic calendar data for tvcalendar demonstrations.
compress
save "`outdir'/calendar.dta", replace


/*******************************************************************************
* 9. relapses.dta — MS clinical events (small standalone dataset)
*******************************************************************************/
di as text "=== Generating relapses.dta ==="

clear
* Small MS cohort: 500 patients
local N_ms = 500
set obs `N_ms'

gen long id = 100000 + _n  // separate ID range from main cohort

* MS diagnosis date: 2005-2018
gen double dx_date = td(01jan2005) + floor(runiform() * (td(31dec2018) - td(01jan2005)))
format dx_date %td

* Each patient has 3-15 EDSS assessments
gen int _nassess = 3 + floor(runiform() * 13)
expand _nassess
bysort id: gen int _seq = _n

* EDSS dates: starting around diagnosis, every 3-12 months
gen double edss_date = dx_date + (_seq - 1) * (90 + floor(runiform() * 270)) ///
    + floor(rnormal() * 30)
replace edss_date = max(dx_date, edss_date)
format edss_date %td

* EDSS score: starts low, gradually increases with noise
* Base EDSS: 0-3 at diagnosis, increases ~0.3/year
bysort id: gen double _base_edss = runiform() * 3 if _n == 1
bysort id: replace _base_edss = _base_edss[1] if _base_edss == .
gen double _years = (edss_date - dx_date) / 365.25
gen double edss = _base_edss + _years * 0.3 + rnormal() * 0.5
replace edss = max(0, min(9.5, round(edss * 2) / 2))  // EDSS in 0.5 steps

* Relapses: ~0.5/year, more in early disease
gen byte _is_relapse = runiform() < (0.5 * exp(-_years * 0.1))
gen double relapse_date = edss_date - floor(runiform() * 30) if _is_relapse
format relapse_date %td
* During relapses, EDSS is transiently higher
replace edss = min(9.5, edss + 1 + runiform()) if _is_relapse

* For non-relapse visits, set relapse_date to missing
replace relapse_date = . if !_is_relapse

drop _seq _nassess _base_edss _years _is_relapse

label var id "Person identifier"
label var relapse_date "Date of relapse"
label var edss "EDSS score at visit"
label var edss_date "Date of EDSS assessment"
label var dx_date "MS diagnosis date"

label data "Synthetic MS clinical events for cdp/pira/sustainedss"
note: Synthetic MS data with EDSS scores and relapses. Separate ID range (100001+).
compress
save "`outdir'/relapses.dta", replace


/*******************************************************************************
* Summary
*******************************************************************************/
di as text ""
di as text "============================================"
di as text "All synthetic datasets generated successfully"
di as text "============================================"
di as text "Output directory: `outdir'"
di as text ""

foreach f in cohort prescriptions diagnoses procedures migrations lisa outcomes calendar relapses {
    qui use "`outdir'/`f'.dta", clear
    di as text "  `f'.dta: " as result _N " obs, " as text c(k) " vars"
}

di as text ""
di as text "Done."
