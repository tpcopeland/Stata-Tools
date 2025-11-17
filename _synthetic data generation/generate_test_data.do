clear all
set seed 12345
cd "/Users/tcopeland/Google Drive/Statistics and Programming/Stata/Tim's Packages/tvtools/testing"

*******************************************************************************
* ENHANCED SYNTHETIC DATA GENERATOR FOR TVEXPOSE AND TVMERGE TESTING
* Created: 2025-11-04
* Updated: 2025-11-11 - Enhanced for comprehensive testing
* Purpose: Generate comprehensive test datasets covering ALL edge cases
*
* GENERATES:
* - cohort.dta: Master cohort (N=1000)
* - hrt.dta: HRT exposure dataset with enhanced patterns
* - dmt.dta: DMT exposure dataset with enhanced patterns
* - synthetic_data.xlsx: SUBSET of datasets (every 10th ID) for review
*
* TEST SCENARIOS COVERED:
* IDs 1-100:   No exposure (baseline reference)
* IDs 101-200: Single continuous exposure (simple case)
* IDs 201-300: Multiple non-overlapping with gaps (grace period testing)
* IDs 301-400: Sequential exposures, no gaps (continuous switching)
* IDs 401-500: Overlapping periods same type (priority/layer/split testing)
* IDs 501-600: Overlapping periods different types (merge strategy testing)
* IDs 601-700: Very short exposures 1-7 days (point-time approximation)
* IDs 701-800: Small gaps 5-20 days (grace period merging)
* IDs 801-900: Switching patterns (evertreated, currentformer testing)
* IDs 901-950: Pre-entry exposures (boundary testing)
* IDs 951-1000: Post-exit exposures (boundary testing)
*
* ENHANCEMENTS FOR COMPREHENSIVE TESTING:
* - Wide range of dose/intensity values for continuous exposure testing
* - Multiple overlap patterns for contoverlap testing
* - Enhanced switching patterns for pattern tracking
* - Better temporal variation for all time unit testing
*******************************************************************************

**# COHORT DATASET
{
clear
set obs 1000
gen id = _n

* Study dates covering 2010-2023 with staggered entry
gen study_entry = mdy(1,1,2010) + floor(runiform()*365*3)
gen study_exit = study_entry + floor(runiform()*365*10 + 365*2)

* Force some IDs to have specific boundary conditions
replace study_entry = mdy(1,1,2010) if inlist(id,1,100,200,300,400,500,600,700,800,900,1000)
replace study_exit = mdy(12,31,2020) if inlist(id,1,100,200,300,400,500,600,700,800,900,1000)

* IDs with very short follow-up (testing minimum duration)
replace study_exit = study_entry + 90 if mod(id,100)==10

* IDs with very long follow-up (testing maximum duration)
replace study_exit = study_entry + 365*12 if mod(id,100)==5

format study_entry study_exit %tdCCYY/NN/DD

* Demographics
gen age = floor(runiform()*20 + 40)
gen female = rbinomial(1,0.6)
gen mstype = ceil(runiform()*3)
gen edss_baseline = floor(runiform()*4)
gen duration = runiform()*15 + 1
gen region = ceil(runiform()*8)
gen period = ceil(runiform()*3)
gen smoking_status = ceil(runiform()*3)
gen educ = ceil(runiform()*3)
gen foreign = rbinomial(1,0.15)
gen total_births = floor(runiform()*4)
gen prior_relapses24 = floor(runiform()*3)

* Outcomes
gen edss4_dt = study_entry + floor(runiform()*(study_exit-study_entry)) if runiform()<0.3
gen edss6_dt = edss4_dt + floor(runiform()*365*2) if !missing(edss4_dt) & runiform()<0.4
replace edss6_dt = study_entry + floor(runiform()*(study_exit-study_entry)) if missing(edss6_dt) & runiform()<0.2
gen relapse_dt = study_entry + floor(runiform()*(study_exit-study_entry)) if runiform()<0.4

* Truncate follow-up at first outcome
replace study_exit = edss4_dt if !missing(edss4_dt) & edss4_dt < study_exit
replace study_exit = edss6_dt if !missing(edss6_dt) & edss6_dt < study_exit
replace study_exit = relapse_dt if !missing(relapse_dt) & relapse_dt < study_exit

format edss4_dt edss6_dt relapse_dt %tdCCYY/NN/DD

* Labels
label var id "Person ID"
label var study_entry "Study Entry Date"
label var study_exit "Study Exit Date"
label var age "Age at study entry (years)"
label var female "Female (1=yes, 0=no)"
label var mstype "MS Type (1=RRMS, 2=SPMS, 3=PPMS)"
label var edss_baseline "Baseline EDSS score (0-9)"
label var duration "Disease duration at entry (years)"
label var region "Geographic region (1-8)"
label var period "Calendar period of entry (1=2010-12, 2=2013-16, 3=2017-20)"
label var smoking_status "Smoking status (1=never, 2=former, 3=current)"
label var educ "Education level (1=primary, 2=secondary, 3=tertiary)"
label var foreign "Foreign-born (1=yes, 0=no)"
label var total_births "Number of births"
label var prior_relapses24 "Relapses in 24 months prior to entry"
label var edss4_dt "Date of sustained EDSS 4+"
label var edss6_dt "Date of sustained EDSS 6+"
label var relapse_dt "Date of first relapse"

strcompress * 
saveold cohort.dta, replace version(13)
disp as txt "Cohort dataset created (N=1000)"
}

**# HRT DATASET - ENHANCED
{
clear
local obs = 0
forval i = 1/1000 {
	use cohort.dta, clear
	keep if id == `i'
	local entry = study_entry
	local exit = study_exit
	local followup = `exit' - `entry'
	clear
	
	* NO EXPOSURE (IDs 1-100)
	if `i' <= 100 {
		set obs 0
	}
	
	* SINGLE CONTINUOUS EXPOSURE (IDs 101-200)
	else if `i' <= 200 {
		set obs 1
		gen rx_start = `entry' + floor(runiform()*`followup'*0.3)
		gen rx_stop = rx_start + floor(runiform()*`followup'*0.5 + 90)
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = ceil(runiform()*3)
		* Wide range of doses for continuous testing
		gen dose = runiform() * 50 + 0.5
		replace rx_start = `entry' if mod(`i',10)==1
		replace rx_stop = `exit' if mod(`i',10)==5
	}
	
	* MULTIPLE NON-OVERLAPPING WITH GAPS (IDs 201-300)
	else if `i' <= 300 {
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
	
	* SEQUENTIAL EXPOSURES NO GAPS (IDs 301-400)
	else if `i' <= 400 {
		set obs 4
		gen rx_start = `entry' + (_n-1)*floor(`followup'/4)
		gen rx_stop = rx_start + floor(`followup'/4)
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = mod(_n-1,3) + 1
		* Varied doses for continuous testing
		gen dose = 5 + _n * 7.5 + runiform() * 10
		drop if rx_start >= rx_stop
	}
	
	* OVERLAPPING SAME TYPE (IDs 401-500)
	else if `i' <= 500 {
		set obs 3
		gen rx_start = `entry' + floor(runiform()*`followup'*0.4)
		replace rx_start = rx_start[_n-1] + 45 if _n > 1
		gen rx_stop = rx_start + 120
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = ceil(runiform()*3)
		* Different doses for overlap testing
		gen dose = 10 * _n + runiform() * 15
		drop if rx_start >= rx_stop
	}
	
	* OVERLAPPING DIFFERENT TYPES (IDs 501-600)
	else if `i' <= 600 {
		set obs 3
		gen rx_start = `entry' + floor(runiform()*`followup'*0.4)
		replace rx_start = rx_start[_n-1] + 60 if _n > 1
		gen rx_stop = rx_start + 150
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = _n
		* Overlapping doses with variation for max/min/mean testing
		if `i' < 550 {
			gen dose = (_n==1) * 20 + (_n==2) * 35 + (_n==3) * 15
		}
		else {
			gen dose = runiform() * 40 + 5
		}
		drop if rx_start >= rx_stop
	}
	
	* VERY SHORT EXPOSURES (IDs 601-700)
	else if `i' <= 700 {
		local n = floor(runiform()*5) + 3
		set obs `n'
		gen rx_start = `entry' + (_n-1)*floor(`followup'/`n') + floor(runiform()*30)
		gen rx_stop = rx_start + floor(runiform()*7 + 1)
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = ceil(runiform()*3)
		gen dose = runiform() * 25 + 2
		drop if rx_start >= rx_stop
	}
	
	* SMALL GAPS (IDs 701-800)
	else if `i' <= 800 {
		set obs 4
		gen rx_start = `entry' + (_n-1)*floor(`followup'/3.5) + floor(runiform()*30)
		gen rx_stop = rx_start + floor(runiform()*90 + 60)
		replace rx_stop = `exit' if rx_stop > `exit'
		replace rx_start = rx_stop[_n-1] + floor(runiform()*15 + 5) if _n > 1
		gen hrt_type = ceil(runiform()*3)
		gen dose = 10 + runiform() * 30
		drop if rx_start >= rx_stop
	}
	
	* SWITCHING PATTERNS (IDs 801-900)
	else if `i' <= 900 {
		set obs 5
		gen rx_start = `entry' + (_n-1)*floor(`followup'/5)
		gen rx_stop = rx_start + floor(`followup'/5)
		replace rx_stop = `exit' if rx_stop > `exit'
		* Alternating types for switching detection
		gen hrt_type = mod(_n,3) + 1
		gen dose = 8 + _n * 4 + runiform() * 8
		drop if rx_start >= rx_stop
	}
	
	* PRE-ENTRY EXPOSURES (IDs 901-950)
	else if `i' <= 950 {
		set obs 2
		gen rx_start = `entry' - 180 + floor(runiform()*90)
		gen rx_stop = `entry' + floor(runiform()*`followup'*0.5)
		replace rx_start = `entry' + floor(`followup'*0.5) if _n==2
		replace rx_stop = `entry' + floor(`followup'*0.8) if _n==2
		replace rx_stop = `exit' if rx_stop > `exit'
		gen hrt_type = ceil(runiform()*3)
		gen dose = 12 + runiform() * 28
		drop if rx_start >= rx_stop
	}
	
	* POST-EXIT EXPOSURES (IDs 951-1000)
	else {
		set obs 2
		gen rx_start = `entry' + floor(runiform()*`followup'*0.4)
		gen rx_stop = `entry' + floor(runiform()*`followup'*0.7)
		replace rx_start = `exit' - 90 if _n==2
		replace rx_stop = `exit' + 180 if _n==2
		gen hrt_type = ceil(runiform()*3)
		gen dose = 15 + runiform() * 25
		drop if rx_start >= rx_stop
	}
	
	if _N > 0 {
		gen id = `i'
		local newobs = _N
		local obs = `obs' + `newobs'
		save temp_hrt_`i', replace
	}
}

* Append all
clear
forval i = 1/1000 {
	capture confirm file temp_hrt_`i'.dta
	if !_rc {
		append using temp_hrt_`i'
		erase temp_hrt_`i'.dta
	}
}

* Finalize
keep id rx_start rx_stop hrt_type dose
format rx_start rx_stop %tdCCYY/NN/DD
label var id "Person ID"
label var rx_start "HRT Start Date"
label var rx_stop "HRT Stop Date"
label var hrt_type "HRT Type (1=oral estrogen, 2=transdermal estrogen, 3=combined)"
label var dose "Daily dose (mg)"
label define hrt 0 "None" 1 "Oral estrogen" 2 "Transdermal estrogen" 3 "Combined"
label values hrt_type hrt

strcompress * 
order id 
saveold hrt.dta, replace version(13)
disp as txt "HRT dataset created with enhanced patterns"
}

**# DMT DATASET - ENHANCED
{
clear
local obs = 0
forval i = 1/1000 {
	use cohort.dta, clear
	keep if id == `i'
	local entry = study_entry
	local exit = study_exit
	local followup = `exit' - `entry'
	clear
	
	* NO EXPOSURE (IDs 1-80)
	if `i' <= 80 {
		set obs 0
	}
	
	* SINGLE DMT ENTIRE FOLLOW-UP (IDs 81-180)
	else if `i' <= 180 {
		set obs 1
		gen dmt_start = `entry'
		gen dmt_stop = `exit'
		gen dmt = ceil(runiform()*6)
		* Wide range for continuous testing
		gen intensity = 1 + runiform() * 4
	}
	
	* MULTIPLE SEQUENTIAL DMT (IDs 181-300)
	else if `i' <= 300 {
		set obs 4
		gen dmt_start = `entry' + (_n-1)*floor(`followup'/4)
		gen dmt_stop = dmt_start + floor(`followup'/4)
		replace dmt_stop = `exit' if dmt_stop > `exit'
		gen dmt = mod(_n-1,6) + 1
		gen intensity = _n + runiform() * 2
		drop if dmt_start >= dmt_stop
	}
	
	* GAPS BETWEEN DMT (IDs 301-440)
	else if `i' <= 440 {
		set obs 3
		gen dmt_start = `entry' + floor(`followup'*0.15)
		gen dmt_stop = dmt_start + floor(`followup'*0.2)
		replace dmt_start = dmt_stop[_n-1] + floor(`followup'*0.12) if _n == 2
		replace dmt_stop = dmt_start + floor(`followup'*0.2) if _n == 2
		replace dmt_start = dmt_stop[_n-1] + floor(`followup'*0.12) if _n == 3
		replace dmt_stop = dmt_start + floor(`followup'*0.2) if _n == 3
		replace dmt_stop = `exit' if dmt_stop > `exit'
		gen dmt = ceil(runiform()*6)
		gen intensity = ceil(runiform()*3) + runiform()
		drop if dmt_start >= dmt_stop
	}
	
	* OVERLAPPING DMT (IDs 441-560)
	else if `i' <= 560 {
		set obs 2
		gen dmt_start = `entry' + floor(runiform()*`followup'*0.5)
		replace dmt_start = dmt_start[_n-1] + 30 if _n > 1
		gen dmt_stop = dmt_start + floor(runiform()*365 + 180)
		replace dmt_stop = `exit' if dmt_stop > `exit'
		gen dmt = _n
		* Varied intensities for overlap testing
		if `i' < 505 {
			gen intensity = (_n==1) * 3.5 + (_n==2) * 1.5
		}
		else {
			gen intensity = runiform() * 4 + 0.5
		}
		drop if dmt_start >= dmt_stop
	}
	
	* LONG CONTINUOUS PERIODS (IDs 561-700)
	else if `i' <= 700 {
		set obs 2
		gen dmt_start = `entry' + (_n-1)*floor(`followup'/2)
		gen dmt_stop = dmt_start + floor(`followup'/2)
		replace dmt_stop = `exit' if dmt_stop > `exit'
		gen dmt = mod(_n-1,6) + 1
		gen intensity = 2 + runiform() * 2
		drop if dmt_start >= dmt_stop
	}
	
	* SHORT DMT PERIODS (IDs 701-840)
	else if `i' <= 840 {
		set obs 6
		gen dmt_start = `entry' + (_n-1)*floor(`followup'/6)
		gen dmt_stop = dmt_start + floor(runiform()*90 + 30)
		replace dmt_stop = `exit' if dmt_stop > `exit'
		gen dmt = ceil(runiform()*6)
		gen intensity = ceil(runiform()*4) + runiform() * 1.5
		drop if dmt_start >= dmt_stop
	}
	
	* LATE DMT START (IDs 841-940)
	else if `i' <= 940 {
		set obs 2
		gen dmt_start = `entry' + floor(`followup'*0.6) + floor(runiform()*`followup'*0.1)
		gen dmt_stop = dmt_start + floor(runiform()*`followup'*0.3)
		replace dmt_stop = `exit' if dmt_stop > `exit'
		gen dmt = ceil(runiform()*6)
		gen intensity = 2 + runiform() * 2.5
		drop if dmt_start >= dmt_stop
	}
	
	* RANDOM COMPLEX PATTERNS (IDs 941-1000)
	else {
		set obs 5
		gen dmt_start = `entry' + floor(runiform()*`followup')
		gen dmt_stop = dmt_start + floor(runiform()*365 + 90)
		replace dmt_stop = `exit' if dmt_stop > `exit'
		gen dmt = ceil(runiform()*6)
		gen intensity = ceil(runiform()*5) + runiform() * 2
		drop if dmt_start >= dmt_stop
	}
	
	if _N > 0 {
		gen id = `i'
		local newobs = _N
		local obs = `obs' + `newobs'
		save temp_dmt_`i', replace
	}
}

* Append all
clear
forval i = 1/1000 {
	capture confirm file temp_dmt_`i'.dta
	if !_rc {
		append using temp_dmt_`i'
		erase temp_dmt_`i'.dta
	}
}

* Finalize
keep id dmt_start dmt_stop dmt intensity
format dmt_start dmt_stop %tdCCYY/NN/DD
label var id "Person ID"
label var dmt_start "DMT Start Date"
label var dmt_stop "DMT Stop Date"
label var dmt "DMT Type"
label var intensity "Treatment Intensity (continuous)"
label define dmt 0 "No DMT" 1 "Interferon" 2 "Glatiramer" 3 "Dimethyl fumarate" ///
	4 "Fingolimod" 5 "Natalizumab" 6 "Rituximab"
label values dmt dmt

strcompress * 
order id 
saveold dmt.dta, replace version(13)
disp as txt "DMT dataset created with enhanced patterns"
}

**# EXPORT SUBSET TO EXCEL
{
use cohort.dta, clear
keep if mod(id,10)==0
export excel using "synthetic_data.xlsx", sheet("cohort", replace) firstrow(variables)

use hrt.dta, clear
merge m:1 id using cohort.dta, keepusing(id) keep(match)
drop _merge
keep if mod(id,10)==0
export excel using "synthetic_data.xlsx", sheet("hrt", replace) firstrow(variables)

use dmt.dta, clear
merge m:1 id using cohort.dta, keepusing(id) keep(match)
drop _merge
keep if mod(id,10)==0
export excel using "synthetic_data.xlsx", sheet("dmt", replace) firstrow(variables)

disp as txt _n "=========================================="
disp as txt "Enhanced synthetic data generation complete"
disp as txt "Total IDs in cohort: 1000"
disp as txt "IDs in Excel file: 100 (every 10th)"
disp as txt "Enhancements:"
disp as txt "  - Wide dose/intensity ranges"
disp as txt "  - Better overlap patterns"
disp as txt "  - Enhanced switching patterns"
disp as txt "  - Comprehensive temporal variation"
disp as txt "=========================================="
}
