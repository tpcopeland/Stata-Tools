*******************************************************************************
* COMPREHENSIVE SYNTHETIC DATA GENERATOR FOR STATA-TOOLS TESTING
* Author: Timothy P. Copeland
* Created: 2025-11-17
* Purpose: Generate complete synthetic MS registry data for testing all packages
*
* GENERATES 11 DATASETS:
* Main registry datasets:
*   1. ccids.dta: Case-control identifiers (N=1000)
*   2. cohort.dta: Main cohort with demographics, study dates, outcomes
*   3. msreg_terapi.dta: Disease-modifying therapy (DMT) periods
*   4. msreg_skov.dta: MS relapses
*   5. msreg_besoksdata.dta: Clinic visits with assessments
*   6. msreg_edss.dta: EDSS functional system scores
*   7. msreg_sdmt.dta: SDMT cognitive assessments
*   8. msreg_smoking.dta: Smoking assessments
*
* Time-varying exposure datasets (for tvexpose/tvmerge):
*   9. hrt.dta: Hormone replacement therapy periods
*  10. dmt.dta: DMT periods (simplified version of msreg_terapi.dta)
*
* Testing dataset:
*  11. cohort_raw.dta: Uncleaned version for datefix/check testing
*
* DATA RELATIONSHIPS:
* - All datasets linked by 'id' variable
* - DMT and HRT periods used for tvexpose/tvmerge testing
* - EDSS progression for survival analysis (cstat_surv, stratetab)
* - Multiple variable types for table1_tc, datamap, check
* - Proper value labels and variable labels throughout
* - hrt.dta and dmt.dta match tvexpose/tvmerge help file examples exactly
*******************************************************************************

clear all
set more off
set seed 20251117

// Set directory for output - change this to your preferred location
global datadir "`c(pwd)'"
di as result "Saving synthetic data to: $datadir"

*******************************************************************************
**# DATASET 1: CASE-CONTROL IDs (ccids.dta)
*******************************************************************************
{
clear
set obs 1000

* Generate ID
gen id = _n

* Case status (60% cases, 40% controls for sufficient events)
gen case = (runiform() < 0.60)

* Match ID (controls matched to cases)
gen matchid = .
local cases = 1
forvalues i = 1/1000 {
	qui count if id == `i'
	if case[`i'] == 1 {
		qui replace matchid = `cases' if id == `i'
		local cases = `cases' + 1
	}
	else {
		local match_to = floor(runiform() * (`cases' - 1)) + 1
		qui replace matchid = `match_to' if id == `i'
	}
}

* Index date (MS diagnosis or matching date)
gen indexdate = mdy(1,1,2010) + floor(runiform()*3650)
format indexdate %tdCCYY/NN/DD

* Birth year
gen byear = 1950 + floor(runiform()*50)

* Sex
gen sex = cond(runiform() < 0.65, 2, 1)
label define sex_lbl 1 "Male" 2 "Female"
label values sex sex_lbl

* Region
gen region = ""
replace region = "01" if runiform() < 0.20
replace region = "03" if region == "" & runiform() < 0.25
replace region = "04" if region == "" & runiform() < 0.15
replace region = "06" if region == "" & runiform() < 0.15
replace region = "07" if region == "" & runiform() < 0.15
replace region = "08" if region == "" & runiform() < 0.10

* Variable labels
label var id "Anon Person ID"
label var case "Case=1/Control=0"
label var matchid "Match ID"
label var indexdate "Index date"
label var byear "Birth year"
label var sex "Sex"
label var region "Region Code"

* Data label
label data "Case-Control IDs for MS Registry Cohort"

compress
save "${datadir}/ccids.dta", replace
di as result "Created ccids.dta (N=1000)"
}

*******************************************************************************
**# DATASET 2: COHORT (cohort.dta)
*******************************************************************************
{
clear
set obs 1000

* Merge in case-control info
gen id = _n
merge 1:1 id using "${datadir}/ccids.dta", keep(match) nogen

* Date of birth (from byear + random month/day)
gen dob = mdy(floor(runiform()*12)+1, floor(runiform()*28)+1, byear)
format dob %tdCCYY/NN/DD

* MS type (for cases only, controls missing)
gen mstype = .
replace mstype = 3 if case == 1 & runiform() < 0.85  // 85% RRMS
replace mstype = 2 if case == 1 & mstype == . & runiform() < 0.60  // 10% SPMS
replace mstype = 1 if case == 1 & mstype == .  // 5% PPMS
label define mstype_lbl 1 "Primary Progressive" 2 "Secondary Progressive" 3 "Relapsing-Remitting"
label values mstype mstype_lbl

* Study entry (index date or later)
gen study_entry = indexdate + floor(runiform()*365)
format study_entry %tdCCYY/NN/DD

* Study exit (2-12 years after entry)
gen study_exit = study_entry + floor(runiform()*3650 + 730)
format study_exit %tdCCYY/NN/DD

* Age at study entry
gen age = floor((study_entry - dob)/365.25)

* Demographics
gen female = (sex == 2)

* Education level
gen educ_lev = ceil(runiform()*7)
replace educ_lev = 99 if runiform() < 0.05  // 5% unknown
label define educ_lbl 1 "Primary <9 yrs" 2 "Primary 9 yrs" 3 "Secondary <=2 yrs" ///
	4 "Secondary 3 yrs" 5 "Tertiary <2 yrs" 6 "Tertiary >=2 yrs" ///
	7 "Postgraduate" 99 "Unknown"
label values educ_lev educ_lbl

* Smoking status
gen smoking_status = ceil(runiform()*5)
replace smoking_status = . if runiform() < 0.05
label define smoking_lbl 1 "Never smoker" 2 "Former smoker" 3 "Daily smoker" ///
	4 "Non-daily smoker" 5 "Daily non-cigarette tobacco user"
label values smoking_status smoking_lbl

* Baseline EDSS (for cases)
gen edss_baseline = .
replace edss_baseline = runiform() * 3 if case == 1 & mstype == 3  // RRMS: 0-3
replace edss_baseline = runiform() * 2 + 3 if case == 1 & mstype == 2  // SPMS: 3-5
replace edss_baseline = runiform() * 2 + 3 if case == 1 & mstype == 1  // PPMS: 3-5
replace edss_baseline = round(edss_baseline, 0.5)

* Disease duration at entry (for cases, in years)
gen disease_duration = .
replace disease_duration = runiform() * 15 if case == 1

* Number of relapses in 24 months prior (for RRMS cases)
gen prior_relapses24 = .
replace prior_relapses24 = floor(runiform()*4) if case == 1 & mstype == 3

* Outcomes - EDSS progression
* EDSS 4+ (confirmed disability)
gen edss4_dt = .
replace edss4_dt = study_entry + floor(runiform()*(study_exit-study_entry)) ///
	if case == 1 & runiform() < 0.25  // 25% reach EDSS 4+
format edss4_dt %tdCCYY/NN/DD

* EDSS 6+ (requires walking aid) - subset of those with EDSS 4+
gen edss6_dt = .
replace edss6_dt = edss4_dt + floor(runiform()*730 + 365) ///
	if !missing(edss4_dt) & runiform() < 0.30  // 30% of EDSS 4+ progress to 6+
replace edss6_dt = . if edss6_dt > study_exit
format edss6_dt %tdCCYY/NN/DD

* First relapse during study (for RRMS)
gen relapse_dt = .
replace relapse_dt = study_entry + floor(runiform()*(study_exit-study_entry)) ///
	if case == 1 & mstype == 3 & runiform() < 0.40  // 40% have relapse
format relapse_dt %tdCCYY/NN/DD

* Truncate follow-up at first outcome for survival analysis
gen exit_reason = 0  // 0=censored
replace exit_reason = 1 if !missing(edss4_dt)  // 1=EDSS 4+
replace exit_reason = 2 if !missing(edss6_dt)  // 2=EDSS 6+
replace exit_reason = 3 if !missing(relapse_dt) & missing(edss4_dt) & missing(edss6_dt)  // 3=Relapse

gen first_outcome_dt = min(edss4_dt, edss6_dt, relapse_dt)
replace study_exit = first_outcome_dt if !missing(first_outcome_dt)
format first_outcome_dt %tdCCYY/NN/DD

* Total births (for women)
gen total_births = .
replace total_births = floor(runiform()*4) if female == 1 & age > 20

* Employment status
gen employed = cond(runiform() < 0.65, 1, 0) if age >= 18 & age <= 67

* Variable labels
label var id "Patient identifier"
label var case "MS Case (1) vs Control (0)"
label var matchid "Match ID"
label var indexdate "Index/diagnosis date"
label var byear "Birth year"
label var sex "Sex"
label var region "Healthcare region"
label var dob "Date of birth"
label var mstype "MS Type"
label var study_entry "Study entry date"
label var study_exit "Study exit date"
label var age "Age at study entry (years)"
label var female "Female (1=yes, 0=no)"
label var educ_lev "Highest education level"
label var smoking_status "Smoking status"
label var edss_baseline "Baseline EDSS score"
label var disease_duration "Disease duration at entry (years)"
label var prior_relapses24 "Relapses in 24 months prior to entry"
label var edss4_dt "Date of sustained EDSS 4+"
label var edss6_dt "Date of sustained EDSS 6+"
label var relapse_dt "Date of first relapse during study"
label var exit_reason "Exit reason (0=censored, 1=EDSS4, 2=EDSS6, 3=relapse)"
label var first_outcome_dt "Date of first outcome"
label var total_births "Number of births"
label var employed "Employed (1=yes, 0=no)"

* Data label
label data "MS Registry Cohort - Demographics and Study Dates"

* Notes
note: Synthetic data for testing Stata-Tools packages
note: id links to all other datasets

compress
save "${datadir}/cohort.dta", replace
di as result "Created cohort.dta (N=1000)"
}

*******************************************************************************
**# DATASET 3: DMT THERAPY (msreg_terapi.dta)
*******************************************************************************
{
clear
use "${datadir}/cohort.dta"
keep if case == 1  // Only MS cases receive DMT
keep id study_entry study_exit

local obs = 0
forvalues i = 1/1000 {
	qui count if id == `i'
	if r(N) == 0 continue

	preserve
	keep if id == `i'
	local entry = study_entry
	local exit = study_exit
	local followup = `exit' - `entry'

	restore, not

	* Determine treatment pattern based on ID
	* 20% never treated
	if mod(`i',5) == 0 {
		continue
	}

	* 30% single DMT throughout
	else if mod(`i',5) == 1 {
		clear
		set obs 1
		gen id = `i'
		gen start_date = `entry' + floor(runiform()*180)
		gen stop_date = `exit'
		gen tx_name = ""
		gen tx_category = ceil(runiform()*4)
		if tx_category == 1 replace tx_name = "Rituximab"
		if tx_category == 2 replace tx_name = "Natalizumab"
		if tx_category == 3 replace tx_name = "Interferon beta-1a"
		if tx_category == 4 replace tx_name = "Dimethyl fumarate"
	}

	* 30% sequential DMT (switching)
	else if mod(`i',5) == 2 {
		clear
		set obs 3
		gen id = `i'
		gen seq = _n
		gen start_date = `entry' + (seq-1)*floor(`followup'/3) + floor(runiform()*90)
		gen stop_date = start_date + floor(`followup'/3)
		replace stop_date = `exit' if stop_date > `exit'
		replace start_date = stop_date[_n-1] if _n > 1
		drop if start_date >= stop_date

		gen tx_name = ""
		gen tx_category = .
		replace tx_category = 3 if seq == 1  // Start platform
		replace tx_category = 4 if seq == 2  // Switch to oral
		replace tx_category = 2 if seq == 3  // Escalate to high-efficacy
		replace tx_name = "Interferon beta-1a" if tx_category == 3
		replace tx_name = "Dimethyl fumarate" if tx_category == 4
		replace tx_name = "Natalizumab" if tx_category == 2
		drop seq
	}

	* 20% with gaps between treatments
	else if mod(`i',5) == 3 {
		clear
		set obs 2
		gen id = `i'
		gen seq = _n
		gen start_date = `entry' + floor(`followup'*0.1) + (seq-1)*floor(`followup'*0.5)
		gen stop_date = start_date + floor(`followup'*0.3)
		replace stop_date = `exit' if stop_date > `exit'
		drop if start_date >= stop_date

		gen tx_name = ""
		gen tx_category = .
		replace tx_category = 3 if seq == 1
		replace tx_category = 1 if seq == 2
		replace tx_name = "Glatiramer acetate" if tx_category == 3
		replace tx_name = "Rituximab" if tx_category == 1
		drop seq
	}

	* 0% (already covered) remains

	if _N > 0 {
		gen tx_id = _n
		gen rituximab = (tx_category == 1)

		* Dates
		format start_date stop_date %tdCCYY/NN/DD

		* Reason codes for stopped treatments
		gen stop_reason_code = .
		replace stop_reason_code = . if stop_date == `exit'  // Ongoing
		replace stop_reason_code = 2 if stop_date < `exit' & runiform() < 0.4  // Adverse effects
		replace stop_reason_code = 3 if stop_date < `exit' & missing(stop_reason_code) & runiform() < 0.5  // Lack of efficacy
		replace stop_reason_code = 99 if stop_date < `exit' & missing(stop_reason_code)  // Other

		label define stop_reason_lbl 2 "Adverse effects" 3 "Lack of efficacy" ///
			4 "Pregnancy" 5 "Planned pregnancy" 99 "Other reason"
		label values stop_reason_code stop_reason_lbl

		* Value labels
		label define tx_cat_lbl 1 "Anti-CD20" 2 "High-efficacy" ///
			3 "Platform (injectable)" 4 "Moderate-efficacy oral"
		label values tx_category tx_cat_lbl

		* Variable labels
		label var id "Patient identifier"
		label var tx_id "Treatment record ID"
		label var tx_name "Treatment preparation name"
		label var tx_category "Treatment category"
		label var rituximab "Rituximab (0=No, 1=Yes)"
		label var start_date "Date treatment initiated/started"
		label var stop_date "Date treatment discontinued"
		label var stop_reason_code "Reason for discontinuation (coded)"

		local newobs = _N
		local obs = `obs' + `newobs'
		tempfile temp_`i'
		save `temp_`i''
	}
}

* Append all
clear
forvalues i = 1/1000 {
	capture confirm file `temp_`i''
	if !_rc {
		append using `temp_`i''
	}
}

if _N > 0 {
	sort id start_date
	label data "MS Registry - Disease-Modifying Therapy Periods"
	note: Linked to cohort.dta via id
	note: Time-varying exposure data for tvexpose/tvmerge testing

	compress
	save "${datadir}/msreg_terapi.dta", replace
	di as result "Created msreg_terapi.dta (N=" _N ")"
}
}

*******************************************************************************
**# DATASET 4: RELAPSES (msreg_skov.dta)
*******************************************************************************
{
clear
use "${datadir}/cohort.dta"
keep if case == 1 & mstype == 3  // Only RRMS cases have relapses
keep id study_entry study_exit

expand 4  // Up to 4 relapses per person
bysort id: gen relapse_num = _n

* Relapse date - distributed throughout follow-up
gen relapse_dt = study_entry + floor(runiform()*(study_exit - study_entry))
sort id relapse_dt

* Some people have fewer relapses - drop randomly
drop if runiform() > (0.7^(relapse_num-1))  // Decreasing probability

* Relapse characteristics
gen debut_relapse = (relapse_num == 1)
gen steroid_tx = cond(runiform() < 0.75, 1, 0)
gen plasmapheresis_tx = cond(runiform() < 0.05, 1, 0)
gen verified_by = ceil(runiform()*3)
label define verified_lbl 1 "Neurologist" 2 "Other physician" 3 "Anamnestic"
label values verified_by verified_lbl

gen isolated_on = cond(runiform() < 0.15, 1, 0)
gen afferent_only = cond(runiform() < 0.20, 1, 0) if isolated_on == 0
gen single_system = cond(runiform() < 0.30, 1, 0)
gen complete_remit_12mo = cond(runiform() < 0.60, 1, 0)

* Format
format relapse_dt %tdCCYY/NN/DD

* Variable labels
label var id "Patient identifier"
label var relapse_num "Relapse sequence number"
label var relapse_dt "Relapse date"
label var debut_relapse "Debut/first relapse"
label var steroid_tx "Steroid treatment given"
label var plasmapheresis_tx "Plasmapheresis treatment given"
label var verified_by "Relapse verified by"
label var isolated_on "Isolated optic neuritis"
label var afferent_only "Only afferent symptoms (non-ON)"
label var single_system "Only one functional system involved"
label var complete_remit_12mo "Complete remission within 12 months"

* Data label
label data "MS Registry - Relapses"
note: Linked to cohort.dta via id

compress
save "${datadir}/msreg_skov.dta", replace
di as result "Created msreg_skov.dta (N=" _N ")"
}

*******************************************************************************
**# DATASET 5: VISITS (msreg_besoksdata.dta)
*******************************************************************************
{
clear
use "${datadir}/cohort.dta"
keep if case == 1  // Only MS cases have visits
keep id study_entry study_exit edss_baseline

* Generate 2-8 visits per person
expand floor(runiform()*7 + 2)
bysort id: gen visit_num = _n

* Visit dates distributed throughout follow-up
gen visit_dt = study_entry + floor(runiform()*(study_exit - study_entry))
sort id visit_dt
by id: replace visit_dt = visit_dt[_n-1] + floor(runiform()*180 + 90) if _n > 1

* Drop visits beyond study_exit
drop if visit_dt > study_exit

* Visit characteristics
gen gen_health = ceil(runiform()*5)
label define health_lbl 1 "Poor" 2 "Fair" 3 "Good" 4 "Very good" 5 "Excellent"
label values gen_health health_lbl

* EDSS at visit (progressive over time)
bysort id: gen time_prop = _n / _N
gen edss = edss_baseline + runiform() * time_prop * 2
replace edss = round(edss, 0.5)
replace edss = min(edss, 9.5)

* Relapse since last visit
gen relapse_since_last_visit = cond(runiform() < 0.10, 1, 0)

* Adverse events
gen adverse_event = cond(runiform() < 0.05, 1, 0)
gen malignancy = cond(runiform() < 0.01, 1, 0) if adverse_event == 1
gen treatment_infection = cond(runiform() < 0.15, 1, 0) if adverse_event == 1

* Rehabilitation and falls
gen rehab_12mo = cond(runiform() < 0.20, 1, 0)
gen falls_2mo = cond(runiform() < 0.15, 1, 0)

* Visit type
gen visit_type = ceil(runiform()*3)
label define visit_type_lbl 1 "Physician contact" 2 "Nurse contact" 3 "Physiotherapist"
label values visit_type visit_type_lbl

* Contact mode
gen contact_mode = ceil(runiform()*6)
label define contact_lbl 1 "Office visit" 2 "Phone contact" 3 "Video contact" ///
	4 "Admission" 5 "Emergency visit" 6 "Other"
label values contact_mode contact_lbl

* Format
format visit_dt %tdCCYY/NN/DD

* Variable labels
label var id "Patient identifier"
label var visit_num "Visit sequence number"
label var visit_dt "Visit date"
label var gen_health "General health status"
label var edss "EDSS score"
label var relapse_since_last_visit "Relapse since last visit"
label var adverse_event "Serious/unexpected adverse event since last visit"
label var malignancy "Malignancy"
label var treatment_infection "Treatment-related infection"
label var rehab_12mo "Rehabilitation period in last 12 months"
label var falls_2mo "Falls in last 2 months"
label var visit_type "Visit type"
label var contact_mode "How contact occurred"

drop edss_baseline time_prop study_entry study_exit

* Data label
label data "MS Registry - Clinic Visits"
note: Linked to cohort.dta via id

compress
save "${datadir}/msreg_besoksdata.dta", replace
di as result "Created msreg_besoksdata.dta (N=" _N ")"
}

*******************************************************************************
**# DATASET 6: EDSS DETAILED (msreg_edss.dta)
*******************************************************************************
{
clear
use "${datadir}/msreg_besoksdata.dta"
keep id visit_dt edss

* Keep subset of visits for detailed EDSS (not all visits have detailed FS scores)
keep if runiform() < 0.6

rename visit_dt edss_dt

* Functional system scores (each 0-5 or 0-6)
* Higher EDSS should correlate with higher FS scores
gen edss_vis = min(floor(runiform() * (edss/2 + 1)), 6)  // Visual
gen edss_bst = min(floor(runiform() * (edss/2 + 1)), 5)  // Brainstem
gen edss_pyr = min(floor(runiform() * (edss/2 + 1)), 6)  // Pyramidal
gen edss_cer = min(floor(runiform() * (edss/2 + 1)), 5)  // Cerebellar
gen edss_sen = min(floor(runiform() * (edss/2 + 1)), 6)  // Sensory
gen edss_blbw = min(floor(runiform() * (edss/2 + 1)), 6)  // Bladder & Bowel
gen edss_men = min(floor(runiform() * (edss/2 + 1)), 5)  // Mental

* Walking score
gen edss_walk_score = .
replace edss_walk_score = 0 if edss < 4
replace edss_walk_score = floor((edss - 3.5) * 2) if edss >= 4 & edss < 8
replace edss_walk_score = min(edss_walk_score, 6)

* Walking aid
gen edss_walk_aid = (edss >= 6)

* Format
format edss_dt %tdCCYY/NN/DD

* Rename overall EDSS for clarity
rename edss edss_calc

* Variable labels
label var id "Patient identifier"
label var edss_dt "EDSS assessment date"
label var edss_calc "EDSS: Overall score (calculated)"
label var edss_vis "EDSS: Visual FS score"
label var edss_bst "EDSS: Brainstem FS score"
label var edss_pyr "EDSS: Pyramidal FS score"
label var edss_cer "EDSS: Cerebellar FS score"
label var edss_sen "EDSS: Sensory FS score"
label var edss_blbw "EDSS: Bladder & Bowel FS score"
label var edss_men "EDSS: Mental FS score"
label var edss_walk_score "EDSS: Ambulation/walking score"
label var edss_walk_aid "EDSS: Ambulation aid type"

* Data label
label data "MS Registry - EDSS Functional System Scores"
note: Linked to cohort.dta via id

compress
save "${datadir}/msreg_edss.dta", replace
di as result "Created msreg_edss.dta (N=" _N ")"
}

*******************************************************************************
**# DATASET 7: SDMT COGNITIVE ASSESSMENTS (msreg_sdmt.dta)
*******************************************************************************
{
clear
use "${datadir}/msreg_besoksdata.dta"
keep id visit_dt

* Keep subset of visits for SDMT (not done at every visit)
keep if runiform() < 0.4

rename visit_dt sdmt_dt

* SDMT score (number correct, typically 30-70)
* Generate age-appropriate scores with some cognitive decline over time
gen sdmt_score = floor(rnormal(50, 12))
replace sdmt_score = max(sdmt_score, 10)
replace sdmt_score = min(sdmt_score, 90)

* Some missing scores (patient unable/unwilling)
replace sdmt_score = . if runiform() < 0.05

* Format
format sdmt_dt %tdCCYY/NN/DD

* Variable labels
label var id "Patient identifier"
label var sdmt_dt "SDMT assessment date"
label var sdmt_score "SDMT score (number correct)"

* Data label
label data "MS Registry - Symbol Digit Modalities Test (SDMT)"
note: Linked to cohort.dta via id

compress
save "${datadir}/msreg_sdmt.dta", replace
di as result "Created msreg_sdmt.dta (N=" _N ")"
}

*******************************************************************************
**# DATASET 8: SMOKING ASSESSMENTS (msreg_smoking.dta)
*******************************************************************************
{
clear
use "${datadir}/cohort.dta"
keep if case == 1
keep id study_entry study_exit smoking_status

* Generate 1-3 smoking assessments per person
expand floor(runiform()*3 + 1)
bysort id: gen assessment_num = _n

* Assessment dates
gen assessment_date = study_entry + floor(runiform()*(study_exit - study_entry))
sort id assessment_date

* Status may change over time
gen current_status = smoking_status if assessment_num == 1
bysort id (assessment_date): replace current_status = current_status[_n-1] if assessment_num > 1

* Some people quit over time
replace current_status = 2 if current_status == 3 & assessment_num > 1 & runiform() < 0.20
replace current_status = 2 if current_status == 4 & assessment_num > 1 & runiform() < 0.30

* Quit date for former smokers
gen quit_date = .
replace quit_date = assessment_date - floor(runiform()*3650) if current_status == 2
format quit_date %tdCCYY/NN/DD

* Smoke free > 6 months
gen smoke_free_6mo = .
replace smoke_free_6mo = ((assessment_date - quit_date) > 180) if !missing(quit_date)

* Cigarettes per day for current smokers
gen cigs_per_day = .
replace cigs_per_day = floor(runiform()*20 + 5) if current_status == 3
replace cigs_per_day = floor(runiform()*10 + 1) if current_status == 4

* Format
format assessment_date %tdCCYY/NN/DD

* Value labels
label define smoking_lbl 1 "Never smoker" 2 "Former smoker" 3 "Daily smoker" ///
	4 "Non-daily smoker" 5 "Daily non-cigarette tobacco user"
label values current_status smoking_lbl

* Variable labels
label var id "Patient identifier"
label var assessment_num "Assessment sequence number"
label var assessment_date "Date of smoking assessment"
label var current_status "Smoking status"
label var quit_date "Date of smoking cessation"
label var smoke_free_6mo "Smoke-free more than 6 months"
label var cigs_per_day "Number of cigarettes per day"

drop smoking_status study_entry study_exit

* Data label
label data "MS Registry - Smoking Assessments"
note: Linked to cohort.dta via id

compress
save "${datadir}/msreg_smoking.dta", replace
di as result "Created msreg_smoking.dta (N=" _N ")"
}

*******************************************************************************
**# DATASET 9: COHORT_RAW (for datefix and check testing)
*******************************************************************************
{
clear
use "${datadir}/cohort.dta"

* Keep subset of variables
keep id case sex age female educ_lev smoking_status study_entry study_exit ///
	dob edss_baseline disease_duration edss4_dt edss6_dt relapse_dt

* Convert dates to various string formats (for datefix testing)
* dob - YYYY-MM-DD format
gen dob_str = string(year(dob)) + "-" + string(month(dob), "%02.0f") + "-" + string(day(dob), "%02.0f")

* study_entry - DD/MM/YYYY format (European)
gen entry_str = string(day(study_entry), "%02.0f") + "/" + ///
	string(month(study_entry), "%02.0f") + "/" + string(year(study_entry))

* study_exit - MM/DD/YYYY format (US)
gen exit_str = string(month(study_exit), "%02.0f") + "/" + ///
	string(day(study_exit), "%02.0f") + "/" + string(year(study_exit))

* edss4_dt - YYYY/MM/DD but with some inconsistencies
gen edss4_str = ""
replace edss4_str = string(year(edss4_dt)) + "/" + ///
	string(month(edss4_dt), "%02.0f") + "/" + ///
	string(day(edss4_dt), "%02.0f") if !missing(edss4_dt)

* Add some problematic values for check testing
* Introduce missing values in various patterns
replace age = . if mod(_n, 25) == 0
replace edss_baseline = . if mod(_n, 30) == 0
replace disease_duration = . if mod(_n, 20) == 0

* Introduce some impossible values (for check to catch)
replace age = -5 if _n == 1
replace age = 150 if _n == 2
replace edss_baseline = 12 if _n == 3  // EDSS only goes to 10

* Create a variable with all missing
gen all_missing = .

* Variable with very few unique values
gen few_unique = mod(_n, 3)

* String variable
gen patient_type = ""
replace patient_type = "Case" if case == 1
replace patient_type = "Control" if case == 0
replace patient_type = "" if mod(_n, 15) == 0  // Some missing

* Drop original date variables
drop dob study_entry study_exit edss4_dt edss6_dt relapse_dt

* Variable labels
label var id "Patient ID"
label var case "Case status"
label var sex "Sex (1=Male, 2=Female)"
label var age "Age (years) - HAS ERRORS"
label var female "Female indicator"
label var educ_lev "Education level"
label var smoking_status "Smoking status"
label var edss_baseline "Baseline EDSS - HAS ERRORS"
label var disease_duration "Disease duration (years)"
label var dob_str "Date of birth (string YYYY-MM-DD)"
label var entry_str "Study entry date (string DD/MM/YYYY)"
label var exit_str "Study exit date (string MM/DD/YYYY)"
label var edss4_str "EDSS 4+ date (string YYYY/MM/DD)"
label var all_missing "Variable with all missing"
label var few_unique "Variable with few unique values"
label var patient_type "Patient type (string)"

* Data label
label data "Cohort RAW - Uncleaned for datefix and check testing"
note: Contains string dates in various formats for datefix testing
note: Contains data quality issues for check testing
note: age and edss_baseline have intentional errors

compress
save "${datadir}/cohort_raw.dta", replace
di as result "Created cohort_raw.dta (N=" _N ")"
}

*******************************************************************************
**# DATASET 10: HRT EXPOSURES (hrt.dta) - For tvmerge testing
*******************************************************************************
{
clear
use "${datadir}/cohort.dta"
keep if female == 1  // Only women receive HRT
keep id study_entry study_exit

local obs = 0
forvalues i = 1/1000 {
	qui count if id == `i'
	if r(N) == 0 continue

	preserve
	keep if id == `i'
	local entry = study_entry
	local exit = study_exit
	local followup = `exit' - `entry'
	restore, not

	* Determine HRT pattern based on ID modulo
	* 40% never exposed
	if mod(`i',5) == 0 {
		continue
	}

	* 20% single continuous exposure
	else if mod(`i',5) == 1 {
		clear
		set obs 1
		gen rx_start = `entry' + floor(runiform()*`followup'*0.3)
		gen rx_stop = rx_start + floor(runiform()*`followup'*0.5 + 90)
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = ceil(runiform()*3)
		gen dose = runiform() * 50 + 0.5
	}

	* 20% multiple non-overlapping with gaps
	else if mod(`i',5) == 2 {
		clear
		set obs 3
		gen rx_start = `entry' + (_n-1)*floor(`followup'/3) + floor(runiform()*90)
		gen rx_stop = rx_start + floor(runiform()*180 + 60)
		replace rx_stop = `exit' if rx_stop > `exit'
		replace rx_start = rx_stop[_n-1] + 30 if _n==2
		replace rx_start = rx_stop[_n-1] + 45 if _n==3
		gen hrt_type = ceil(runiform()*3)
		gen dose = runiform() * 40 + 5
		drop if rx_start >= rx_stop
	}

	* 10% sequential exposures no gaps
	else if mod(`i',10) == 3 {
		clear
		set obs 4
		gen rx_start = `entry' + (_n-1)*floor(`followup'/4)
		gen rx_stop = rx_start + floor(`followup'/4)
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = mod(_n-1,3) + 1
		gen dose = 5 + _n * 7.5 + runiform() * 10
		drop if rx_start >= rx_stop
	}

	* 10% overlapping periods
	else if mod(`i',10) == 4 {
		clear
		set obs 3
		gen rx_start = `entry' + floor(runiform()*`followup'*0.4)
		replace rx_start = rx_start[_n-1] + 60 if _n > 1
		gen rx_stop = rx_start + 150
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = _n
		if `i' < 500 {
			gen dose = (_n==1) * 20 + (_n==2) * 35 + (_n==3) * 15
		}
		else {
			gen dose = runiform() * 40 + 5
		}
		drop if rx_start >= rx_stop
	}

	if _N > 0 {
		gen id = `i'
		format rx_start rx_stop %tdCCYY/NN/DD

		* Value labels for HRT type
		label define hrt_lbl 0 "None" 1 "Oral estrogen" 2 "Transdermal estrogen" 3 "Combined"
		label values hrt_type hrt_lbl

		* Variable labels
		label var id "Person ID"
		label var rx_start "HRT Start Date"
		label var rx_stop "HRT Stop Date"
		label var hrt_type "HRT Type"
		label var dose "Daily dose (mg)"

		local newobs = _N
		local obs = `obs' + `newobs'
		tempfile temp_`i'
		save `temp_`i''
	}
}

* Append all
clear
forvalues i = 1/1000 {
	capture confirm file `temp_`i''
	if !_rc {
		append using `temp_`i''
	}
}

if _N > 0 {
	sort id rx_start

	* Data label
	label data "Hormone Replacement Therapy (HRT) Exposure Periods"
	note: Linked to cohort.dta via id
	note: Time-varying exposure data for tvexpose/tvmerge testing
	note: Can be merged with DMT data to test tvmerge functionality

	compress
	save "${datadir}/hrt.dta", replace
	di as result "Created hrt.dta (N=" _N ")"
}
}

*******************************************************************************
**# DATASET 11: DMT SIMPLIFIED (dmt.dta) - For tvexpose/tvmerge examples
*******************************************************************************
{
* Create simplified DMT dataset matching help file examples
clear
use "${datadir}/msreg_terapi.dta"

* Rename variables to match tvexpose/tvmerge examples
rename start_date dmt_start
rename stop_date dmt_stop
rename tx_category dmt

* Keep only essential variables
keep id dmt_start dmt_stop dmt

* Add reference category (0 = unexposed) - this is implicit in gaps
* The data structure already has this via the time-varying nature

* Format dates
format dmt_start dmt_stop %tdCCYY/NN/DD

* Value labels
label define dmt_lbl 0 "Unexposed" 1 "Anti-CD20" 2 "High-efficacy" ///
	3 "Platform (injectable)" 4 "Moderate-efficacy oral"
label values dmt dmt_lbl

* Variable labels
label var id "Person ID"
label var dmt_start "DMT start date"
label var dmt_stop "DMT stop date"
label var dmt "DMT category"

* Data label
label data "Disease-Modifying Therapy (DMT) Exposure Periods - Simplified"
note: Linked to cohort.dta via id
note: Simplified version of msreg_terapi.dta for tvexpose/tvmerge examples
note: Variable names match help file examples exactly

compress
save "${datadir}/dmt.dta", replace
di as result "Created dmt.dta (N=" _N ")"
}

*******************************************************************************
**# SUMMARY
*******************************************************************************
{
di _n as result "{hline 78}"
di as result "SYNTHETIC DATA GENERATION COMPLETE"
di as result "{hline 78}"
di as text "Datasets created in: " as result "$datadir"
di _n as text "Main datasets (clean):"
di as text "  1. ccids.dta                - Case-control IDs (N=1000)"
di as text "  2. cohort.dta               - Main cohort with demographics"
di as text "  3. msreg_terapi.dta         - DMT treatment periods"
di as text "  4. msreg_skov.dta           - MS relapses"
di as text "  5. msreg_besoksdata.dta     - Clinic visits"
di as text "  6. msreg_edss.dta           - EDSS functional scores"
di as text "  7. msreg_sdmt.dta           - SDMT cognitive assessments"
di as text "  8. msreg_smoking.dta        - Smoking assessments"
di _n as text "Time-varying exposure datasets:"
di as text "  9. hrt.dta                  - HRT exposure periods (for tvmerge)"
di as text " 10. dmt.dta                  - DMT exposure periods (for tvmerge)"
di _n as text "Testing dataset (uncleaned):"
di as text " 11. cohort_raw.dta           - Uncleaned data for datefix/check"
di _n as text "Key features:"
di as text "  - All datasets linked by 'id' variable"
di as text "  - Realistic relationships between datasets"
di as text "  - Proper value labels and variable labels"
di as text "  - Data labels on all datasets"
di as text "  - DMT and HRT periods for tvexpose/tvmerge testing"
di as text "  - EDSS progression for survival analysis"
di as text "  - Multiple variable types for table1_tc, datamap"
di as text "  - cohort_raw.dta has string dates and data issues"
di _n as text "tvexpose/tvmerge workflow (matching help file examples):"
di as text "  use cohort, clear"
di as text "  tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///"
di as text "    exposure(hrt_type) reference(0) ///"
di as text "    entry(study_entry) exit(study_exit) saveas(tv_hrt.dta) replace"
di as text "  use cohort, clear"
di as text "  tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///"
di as text "    exposure(dmt) reference(0) ///"
di as text "    entry(study_entry) exit(study_exit) saveas(tv_dmt.dta) replace"
di as text "  tvmerge tv_hrt tv_dmt, id(id) ///"
di as text "    start(rx_start rx_start) stop(rx_stop rx_stop) ///"
di as text "    exposure(tv_exposure tv_exposure) generate(hrt dmt_type)"
di as result "{hline 78}"
}
