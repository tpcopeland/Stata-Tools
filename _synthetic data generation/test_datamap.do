*! test_datamap.do - Comprehensive test suite for datamap.ado
*! Tests all features with 3 linked synthetic datasets
*! Run from directory containing datamap.ado

**#SETUP
{
version 14.0
clear all
set more off

capture global source "/Users/tcopeland/Google Drive/Statistics and Programming/Stata/Tim's Packages/datamap/"
capture global source2 "/Users/tcopeland/Google Drive/Statistics and Programming/Stata/Tim's Packages/datamap/test_datamap/"

noisily capture program drop datamap

do "$source`c(dirsep)'datamap.ado"

cd "$source2"
}
**#Synthetic Data
{
// ============================================================================
// Dataset 1: PATIENTS - Master patient registry
// ============================================================================
clear
set obs 150
set seed 20250101

gen patient_id = _n
gen clinic_id = mod(_n-1, 5) + 1
gen enrollment_date = mdy(1,1,2020) + floor(runiform()*1095)
format enrollment_date %td
gen date_of_birth = mdy(1,1,1950) + floor(runiform()*20000)
format date_of_birth %td
gen sex = cond(runiform() < 0.52, 1, 0)
label define sex_lbl 0 "Male" 1 "Female"
label values sex sex_lbl
gen race = ceil(runiform()*4)
label define race_lbl 1 "White" 2 "Black" 3 "Asian" 4 "Other"
label values race race_lbl
gen ethnicity = cond(runiform() < 0.15, 1, 0)
label define eth_lbl 0 "Non-Hispanic" 1 "Hispanic"
label values ethnicity eth_lbl
gen smoker = cond(runiform() < 0.18, 1, 0)
label define yn_lbl 0 "No" 1 "Yes"
label values smoker yn_lbl
gen baseline_weight = 120 + 80*runiform()
gen baseline_height = 150 + 30*runiform()
gen baseline_bmi = baseline_weight / ((baseline_height/100)^2)
gen patient_name = "Patient_" + string(_n)
replace patient_name = "" if mod(_n, 20) == 0
gen insurance_type = ceil(runiform()*3)
label define ins_lbl 1 "Private" 2 "Medicare" 3 "Medicaid"
label values insurance_type ins_lbl
replace race = . if mod(_n, 15) == 0
replace baseline_weight = . if mod(_n, 25) == 0
replace baseline_bmi = . if missing(baseline_weight)
label variable patient_id "Unique patient identifier"
label variable clinic_id "Clinic location identifier"
label variable enrollment_date "Date patient enrolled in study"
label variable date_of_birth "Patient date of birth"
label variable sex "Biological sex"
label variable race "Self-reported race"
label variable ethnicity "Hispanic/Latino ethnicity"
label variable smoker "Current smoking status"
label variable baseline_weight "Weight in kg at baseline"
label variable baseline_height "Height in cm at baseline"
label variable baseline_bmi "Body mass index at baseline"
label variable patient_name "Patient name (for testing string variables)"
label variable insurance_type "Primary insurance type"
label data "Patient Registry - Master Demographics"
note: Dataset created for datamap.ado testing
note patient_id: Primary key - links to visits and labs
note clinic_id: Foreign key - links to clinics dataset
compress
save patients.dta, replace

// ============================================================================
// Dataset 2: CLINICS - Clinic locations (links to patients)
// ============================================================================
clear
set obs 5
gen clinic_id = _n
gen clinic_name = "Clinic " + char(64 + _n)
gen clinic_city = ""
replace clinic_city = "Boston" if clinic_id == 1
replace clinic_city = "New York" if clinic_id == 2
replace clinic_city = "Philadelphia" if clinic_id == 3
replace clinic_city = "Baltimore" if clinic_id == 4
replace clinic_city = "Washington" if clinic_id == 5
gen clinic_state = ""
replace clinic_state = "MA" if clinic_id == 1
replace clinic_state = "NY" if clinic_id == 2
replace clinic_state = "PA" if clinic_id == 3
replace clinic_state = "MD" if clinic_id == 4
replace clinic_state = "DC" if clinic_id == 5
gen num_providers = ceil(5 + runiform()*15)
gen opened_date = mdy(1,1,2000) + floor(runiform()*7300)
format opened_date %td
gen teaching_hospital = _n <= 3
label values teaching_hospital yn_lbl
gen trauma_level = .
replace trauma_level = 1 if clinic_id <= 2
replace trauma_level = 2 if clinic_id == 3
label define trauma_lbl 1 "Level I" 2 "Level II"
label values trauma_level trauma_lbl
label variable clinic_id "Unique clinic identifier"
label variable clinic_name "Clinic facility name"
label variable clinic_city "City location"
label variable clinic_state "State/District"
label variable num_providers "Number of healthcare providers"
label variable opened_date "Date facility opened"
label variable teaching_hospital "Academic teaching hospital"
label variable trauma_level "Trauma center designation"
label data "Clinic Directory - Facility Information"
note: Links to patients via clinic_id
compress
save clinics.dta, replace

// ============================================================================
// Dataset 3: VISITS - Patient visits with measurements (long format)
// ============================================================================
clear
use patients.dta
keep patient_id clinic_id enrollment_date
expand 4
bysort patient_id: gen visit_num = _n
gen visit_date = enrollment_date + floor(runiform()*730)
format visit_date %td
sort patient_id visit_date
by patient_id: replace visit_date = visit_date[_n-1] + 60 + floor(runiform()*150) if _n > 1
drop enrollment_date
gen systolic_bp = 100 + 40*runiform()
gen diastolic_bp = 60 + 25*runiform()
gen heart_rate = 55 + 40*runiform()
gen temperature = 97 + 2.5*runiform()
gen weight = 120 + 80*runiform()
gen adverse_event = cond(runiform() < 0.08, 1, 0)
label values adverse_event yn_lbl
gen visit_type = ceil(runiform()*3)
label define visit_lbl 1 "Routine" 2 "Urgent" 3 "Follow-up"
label values visit_type visit_lbl
gen provider_id = ceil(runiform()*20)
gen visit_duration = 15 + floor(runiform()*60)
gen visit_notes = "Standard examination" if visit_type == 1
replace visit_notes = "Urgent care visit" if visit_type == 2
replace visit_notes = "Follow-up appointment" if visit_type == 3
replace visit_notes = "" if mod(_n, 30) == 0
replace systolic_bp = . if mod(_n, 40) == 0
replace diastolic_bp = . if missing(systolic_bp)
replace heart_rate = . if mod(_n, 50) == 0
replace weight = . if mod(_n, 35) == 0
label variable patient_id "Patient identifier (FK)"
label variable clinic_id "Clinic identifier (FK)"
label variable visit_num "Visit sequence number"
label variable visit_date "Date of visit"
label variable systolic_bp "Systolic blood pressure (mmHg)"
label variable diastolic_bp "Diastolic blood pressure (mmHg)"
label variable heart_rate "Heart rate (bpm)"
label variable temperature "Body temperature (F)"
label variable weight "Weight in kg"
label variable adverse_event "Any adverse event recorded"
label variable visit_type "Type of visit"
label variable provider_id "Healthcare provider ID"
label variable visit_duration "Visit length in minutes"
label variable visit_notes "Clinical notes"
label data "Patient Visits - Longitudinal Measurements"
note: Links to patients and clinics via patient_id and clinic_id
note: Multiple visits per patient (long format)
compress
save visits.dta, replace
}

// ============================================================================
// TEST 1: Basic single file with default options
// ============================================================================
di as text _n "TEST 1: Basic single file, default text output"
di as text "{hline 78}"
datamap, single("patients.dta")
assert r(nfiles) == 1
assert r(format) == "text"
assert r(output) == "datamap.txt"
confirm file datamap.txt
type datamap.txt
di as result "TEST 1 PASSED: Basic single file execution"

// ============================================================================
// TEST 2: Text format with custom output name
// ============================================================================
di as text _n "TEST 2: Text format with custom output name"
di as text "{hline 78}"
datamap, single(clinics.dta) format(text) output(clinics_map.txt)
assert r(nfiles) == 1
assert r(format) == "text"
confirm file clinics_map.txt
type clinics_map.txt
di as result "TEST 2 PASSED: Custom output file"

// ============================================================================
// TEST 3: Another single file test
// ============================================================================
di as text _n "TEST 3: Another single file test"
di as text "{hline 78}"
datamap, single(visits.dta) format(text) output(visits_map.txt)
assert r(nfiles) == 1
assert r(format) == "text"
confirm file visits_map.txt
di as result "TEST 3 PASSED: Text format"

// ============================================================================
// TEST 4: Exclude sensitive variables (privacy)
// ============================================================================
di as text _n "TEST 4: Exclude sensitive identifiers"
di as text "{hline 78}"
datamap, single(patients.dta) exclude(patient_id patient_name date_of_birth) ///
	output(patients_private.txt)
confirm file patients_private.txt
type patients_private.txt
di as result "TEST 4 PASSED: Variable exclusion for privacy"

// ============================================================================
// TEST 5: Date-safe mode
// ============================================================================
di as text _n "TEST 5: Date-safe mode (ranges only)"
di as text "{hline 78}"
datamap, single(patients.dta) datesafe output(patients_datesafe.txt)
confirm file patients_datesafe.txt
di as result "TEST 5 PASSED: Date-safe mode"

// ============================================================================
// TEST 6: Suppress statistics
// ============================================================================
di as text _n "TEST 6: Suppress summary statistics"
di as text "{hline 78}"
datamap, single(visits.dta) nostats output(visits_nostats.txt)
confirm file visits_nostats.txt
di as result "TEST 6 PASSED: Statistics suppression"

// ============================================================================
// TEST 7: Suppress frequency tables
// ============================================================================
di as text _n "TEST 7: Suppress frequency tables"
di as text "{hline 78}"
datamap, single(patients.dta) nofreq output(patients_nofreq.txt)
confirm file patients_nofreq.txt
di as result "TEST 7 PASSED: Frequency suppression"

// ============================================================================
// TEST 8: Suppress labels
// ============================================================================
di as text _n "TEST 8: Suppress value labels"
di as text "{hline 78}"
datamap, single(patients.dta) nolabels output(patients_nolabels.txt)
confirm file patients_nolabels.txt
di as result "TEST 8 PASSED: Label suppression"

// ============================================================================
// TEST 9: Suppress dataset notes
// ============================================================================
di as text _n "TEST 9: Suppress dataset notes"
di as text "{hline 78}"
datamap, single(patients.dta) nonotes output(patients_nonotes.txt)
confirm file patients_nonotes.txt
di as result "TEST 9 PASSED: Notes suppression"

// ============================================================================
// TEST 10: Custom maxfreq parameter
// ============================================================================
di as text _n "TEST 10: Custom maxfreq (show only up to 5 unique values)"
di as text "{hline 78}"
datamap, single(patients.dta) maxfreq(5) output(patients_maxfreq5.txt)
confirm file patients_maxfreq5.txt
di as result "TEST 10 PASSED: Custom maxfreq"

// ============================================================================
// TEST 11: Custom maxcat parameter
// ============================================================================
di as text _n "TEST 11: Custom maxcat (categorical threshold = 10)"
di as text "{hline 78}"
datamap, single(patients.dta) maxcat(10) output(patients_maxcat10.txt)
confirm file patients_maxcat10.txt
di as result "TEST 11 PASSED: Custom maxcat"

// ============================================================================
// TEST 12: Combined options
// ============================================================================
di as text _n "TEST 12: Combined options (exclude + datesafe + nostats)"
di as text "{hline 78}"
datamap, single(patients.dta) exclude(patient_id patient_name) ///
	datesafe nostats output(patients_combined.txt)
confirm file patients_combined.txt
di as result "TEST 12 PASSED: Combined options"

// ============================================================================
// TEST 13: Directory mode (all files in current directory)
// ============================================================================
di as text _n "TEST 13: Directory mode (scan current directory)"
di as text "{hline 78}"
datamap, directory(.) output(all_datasets.txt)
di as text "Found " as result r(nfiles) as text " files in directory"
assert r(nfiles) >= 3
confirm file all_datasets.txt
type all_datasets.txt
di as result "TEST 13 PASSED: Directory scanning"

// ============================================================================
// TEST 14: Create file list and use filelist mode
// ============================================================================
di as text _n "TEST 14: File list mode"
di as text "{hline 78}"
file open flist using test_filelist.txt, write text replace
file write flist "patients.dta" _n
file write flist "clinics.dta" _n
file write flist "visits.dta" _n
file close flist
datamap, filelist(test_filelist.txt) output(from_filelist.txt)
di as text "Found " as result r(nfiles) as text " files in filelist"
assert r(nfiles) == 3
confirm file from_filelist.txt
di as result "TEST 14 PASSED: File list mode"

// ============================================================================
// TEST 15: File list with comments and blank lines
// ============================================================================
di as text _n "TEST 15: File list with comments"
di as text "{hline 78}"
file open flist using test_filelist_comments.txt, write text replace
file write flist "* This is a comment" _n
file write flist "" _n
file write flist "patients.dta" _n
file write flist "  " _n
file write flist "* Another comment" _n
file write flist "clinics.dta" _n
file close flist
datamap, filelist(test_filelist_comments.txt) output(from_comments.txt)
assert r(nfiles) == 2
di as result "TEST 15 PASSED: File list with comments"

// ============================================================================
// TEST 16: Separate output files per dataset
// ============================================================================
di as text _n "TEST 16: Separate output files"
di as text "{hline 78}"
datamap, directory(.) separate format(text)
confirm file patients_map.txt
confirm file clinics_map.txt
confirm file visits_map.txt
di as result "TEST 16 PASSED: Separate output files"

// ============================================================================
// TEST 17: Append mode
// ============================================================================
di as text _n "TEST 17: Append mode"
di as text "{hline 78}"
datamap, single(patients.dta) output(append_test.txt)
datamap, single(clinics.dta) output(append_test.txt) append
confirm file append_test.txt
di as result "TEST 17 PASSED: Append mode"

// ============================================================================
// TEST 18: All suppression flags together
// ============================================================================
di as text _n "TEST 18: All suppression flags"
di as text "{hline 78}"
datamap, single(patients.dta) nostats nofreq nolabels nonotes ///
	output(all_suppressed.txt)
confirm file all_suppressed.txt
di as result "TEST 18 PASSED: All suppressions"

// ============================================================================
// TEST 19: Error handling - invalid format
// ============================================================================
di as text _n "TEST 19: Error handling - invalid format"
di as text "{hline 78}"
capture datamap, single(patients.dta) format(invalid)
assert _rc == 198
di as result "TEST 19 PASSED: Invalid format rejected"

// ============================================================================
// TEST 20: Error handling - multiple input modes
// ============================================================================
di as text _n "TEST 20: Error handling - multiple input modes"
di as text "{hline 78}"
capture datamap, single(patients.dta) directory(.) filelist(test_filelist.txt)
assert _rc == 198
di as result "TEST 20 PASSED: Multiple input modes rejected"

// ============================================================================
// TEST 21: Error handling - nonexistent file
// ============================================================================
di as text _n "TEST 21: Error handling - nonexistent file"
di as text "{hline 78}"
capture datamap, single(nonexistent.dta)
assert _rc == 601
di as result "TEST 21 PASSED: Nonexistent file rejected"

// ============================================================================
// TEST 22: Error handling - nonexistent filelist
// ============================================================================
di as text _n "TEST 22: Error handling - nonexistent filelist"
di as text "{hline 78}"
capture datamap, filelist(nonexistent.txt)
assert _rc == 601
di as result "TEST 22 PASSED: Nonexistent filelist rejected"

// ============================================================================
// TEST 23: Error handling - invalid maxfreq
// ============================================================================
di as text _n "TEST 23: Error handling - invalid maxfreq"
di as text "{hline 78}"
capture datamap, single(patients.dta) maxfreq(0)
assert _rc == 198
capture datamap, single(patients.dta) maxfreq(-5)
assert _rc == 198
di as result "TEST 23 PASSED: Invalid maxfreq rejected"

// ============================================================================
// TEST 24: Error handling - invalid maxcat
// ============================================================================
di as text _n "TEST 24: Error handling - invalid maxcat"
di as text "{hline 78}"
capture datamap, single(patients.dta) maxcat(0)
assert _rc == 198
capture datamap, single(patients.dta) maxcat(-10)
assert _rc == 198
di as result "TEST 24 PASSED: Invalid maxcat rejected"

// ============================================================================
// TEST 25: Edge case - empty directory (no .dta files)
// ============================================================================
di as text _n "TEST 25: Edge case - empty directory"
di as text "{hline 78}"
capture mkdir empty_dir
capture datamap, directory(empty_dir)
assert _rc == 601
di as result "TEST 25 PASSED: Empty directory handled"

// ============================================================================
// TEST 26: Variable types - all categorical
// ============================================================================
di as text _n "TEST 26: Dataset with only categorical variables"
di as text "{hline 78}"
use patients.dta, clear
keep patient_id sex race ethnicity smoker insurance_type
save test_categorical.dta, replace
datamap, single(test_categorical.dta) output(categorical_only.txt)
confirm file categorical_only.txt
di as result "TEST 26 PASSED: Categorical-only dataset"

// ============================================================================
// TEST 27: Variable types - all continuous
// ============================================================================
di as text _n "TEST 27: Dataset with only continuous variables"
di as text "{hline 78}"
use visits.dta, clear
keep visit_num systolic_bp diastolic_bp heart_rate temperature weight visit_duration
save test_continuous.dta, replace
datamap, single(test_continuous.dta) output(continuous_only.txt)
confirm file continuous_only.txt
di as result "TEST 27 PASSED: Continuous-only dataset"

// ============================================================================
// TEST 28: Variable types - all dates
// ============================================================================
di as text _n "TEST 28: Dataset with date variables"
di as text "{hline 78}"
use patients.dta, clear
keep patient_id enrollment_date date_of_birth
save test_dates.dta, replace
datamap, single(test_dates.dta) output(dates_only.txt)
confirm file dates_only.txt
di as result "TEST 28 PASSED: Date-only dataset"

// ============================================================================
// TEST 29: Variable types - all strings
// ============================================================================
di as text _n "TEST 29: Dataset with string variables"
di as text "{hline 78}"
use clinics.dta, clear
keep clinic_id clinic_name clinic_city clinic_state
save test_strings.dta, replace
datamap, single(test_strings.dta) output(strings_only.txt)
confirm file strings_only.txt
di as result "TEST 29 PASSED: String-only dataset"

// ============================================================================
// TEST 30: Edge case - dataset with all missing values
// ============================================================================
di as text _n "TEST 30: Edge case - variable with all missing"
di as text "{hline 78}"
use patients.dta, clear
gen all_missing = .
label variable all_missing "Test variable with all missing"
save test_missing.dta, replace
datamap, single(test_missing.dta) output(all_missing.txt)
confirm file all_missing.txt
di as result "TEST 30 PASSED: All-missing variable"

// ============================================================================
// TEST 31: Edge case - very high cardinality categorical
// ============================================================================
di as text _n "TEST 31: High cardinality variable"
di as text "{hline 78}"
use patients.dta, clear
keep patient_id
datamap, single(patients.dta) maxcat(200) output(high_card.txt)
confirm file high_card.txt
di as result "TEST 31 PASSED: High cardinality handling"

// ============================================================================
// TEST 32: Verify return values
// ============================================================================
di as text _n "TEST 32: Verify stored results"
di as text "{hline 78}"
datamap, single(patients.dta) output(test_returns.txt) format(text)
assert r(nfiles) == 1
assert r(format) == "text"
assert r(output) == "test_returns.txt"
return list
di as result "TEST 32 PASSED: All return values correct"

// ============================================================================
// TEST 33: Link validation - check datasets are properly linked
// ============================================================================
di as text _n "TEST 33: Verify dataset linkages"
di as text "{hline 78}"
use patients.dta, clear
merge m:1 clinic_id using clinics.dta
assert _merge == 3
drop _merge
tempfile merged
save `merged'
use visits.dta, clear
merge m:1 patient_id clinic_id using `merged'
assert _merge == 3
di as result "TEST 33 PASSED: All datasets properly linked"

// ============================================================================
// TEST 34: Performance - large dataset handling
// ============================================================================
di as text _n "TEST 34: Performance test with large dataset"
di as text "{hline 78}"
use visits.dta, clear
expand 5
gen obs_id = _n
save test_large.dta, replace
timer clear 1
timer on 1
datamap, single(test_large.dta) output(large_dataset.txt)
timer off 1
timer list 1
di as result "TEST 34 PASSED: Large dataset processed"

// ============================================================================
// TEST 35: Comprehensive multi-dataset documentation
// ============================================================================
di as text _n "TEST 35: Generate comprehensive documentation for all datasets"
di as text "{hline 78}"
datamap, directory(.) output(complete_documentation.txt) format(text)
confirm file complete_documentation.txt
type complete_documentation.txt, lines(50)
di as result "TEST 35 PASSED: Comprehensive documentation generated"

// ============================================================================
// NEW FEATURES TESTS
// ============================================================================

// ============================================================================
// TEST 36: Binary detection
// ============================================================================
di as text _n "TEST 36: Binary detection"
di as text "{hline 78}"
use patients.dta, clear
// sex, smoker, ethnicity are binary
datamap, single(patients.dta) detect(binary) output(test_binary.txt)
confirm file test_binary.txt
type test_binary.txt
di as result "TEST 36 PASSED: Binary detection"

// ============================================================================
// TEST 37: Panel detection (auto)
// ============================================================================
di as text _n "TEST 37: Panel detection (auto)"
di as text "{hline 78}"
datamap, single(visits.dta) detect(panel) output(test_panel_auto.txt)
confirm file test_panel_auto.txt
type test_panel_auto.txt
di as result "TEST 37 PASSED: Panel auto-detection"

// ============================================================================
// TEST 38: Panel detection (explicit panelid)
// ============================================================================
di as text _n "TEST 38: Panel detection (explicit panelid)"
di as text "{hline 78}"
datamap, single(visits.dta) panelid(patient_id) output(test_panel_explicit.txt)
confirm file test_panel_explicit.txt
di as result "TEST 38 PASSED: Panel explicit ID"

// ============================================================================
// TEST 39: Common variable pattern detection
// ============================================================================
di as text _n "TEST 39: Common variable pattern detection"
di as text "{hline 78}"
datamap, single(patients.dta) detect(common) output(test_common.txt)
confirm file test_common.txt
type test_common.txt
di as result "TEST 39 PASSED: Common pattern detection"

// ============================================================================
// TEST 40: Missing data summary
// ============================================================================
di as text _n "TEST 40: Missing data summary"
di as text "{hline 78}"
datamap, single(patients.dta) missing(detail) output(test_missing_detail.txt)
confirm file test_missing_detail.txt
type test_missing_detail.txt
di as result "TEST 40 PASSED: Missing data summary"

// ============================================================================
// TEST 41: Quality checks
// ============================================================================
di as text _n "TEST 41: Quality checks (basic)"
di as text "{hline 78}"
// Create dataset with quality issues
use patients.dta, clear
gen age = 2024 - year(date_of_birth)
replace age = -5 in 1
replace age = 125 in 2
save test_quality.dta, replace
datamap, single(test_quality.dta) quality output(test_quality_basic.txt)
confirm file test_quality_basic.txt
type test_quality_basic.txt
di as result "TEST 41 PASSED: Basic quality checks"

// ============================================================================
// TEST 42: Quality checks (strict)
// ============================================================================
di as text _n "TEST 42: Quality checks (strict)"
di as text "{hline 78}"
use test_quality.dta, clear
replace age = 105 in 3
save test_quality.dta, replace
datamap, single(test_quality.dta) quality(strict) output(test_quality_strict.txt)
confirm file test_quality_strict.txt
di as result "TEST 42 PASSED: Strict quality checks"

// ============================================================================
// TEST 43: Sample observations
// ============================================================================
di as text _n "TEST 43: Sample observations"
di as text "{hline 78}"
cls
set trace on 
datamap, single(patients.dta) samples(3) output(test_samples.txt)
confirm file test_samples.txt
type test_samples.txt
di as result "TEST 43 PASSED: Sample observations"

// ============================================================================
// TEST 44: Sample observations with exclusions
// ============================================================================
di as text _n "TEST 44: Sample observations with exclusions"
di as text "{hline 78}"
datamap, single(patients.dta) samples(5) exclude(patient_id patient_name) output(test_samples_exclude.txt)
confirm file test_samples_exclude.txt
type test_samples_exclude.txt
di as result "TEST 44 PASSED: Sample observations with exclusions"

// ============================================================================
// TEST 45: Autodetect (all detection features)
// ============================================================================
di as text _n "TEST 45: Autodetect (all features)"
di as text "{hline 78}"
datamap, single(visits.dta) autodetect output(test_autodetect.txt)
confirm file test_autodetect.txt
di as result "TEST 45 PASSED: Autodetect"

// ============================================================================
// TEST 46: Survey design detection
// ============================================================================
di as text _n "TEST 46: Survey design detection"
di as text "{hline 78}"
// Create survey-style dataset
use patients.dta, clear
gen sampweight = 0.5 + runiform()
gen strata = mod(_n, 5) + 1
gen psu = mod(_n, 20) + 1
save test_survey.dta, replace
datamap, single(test_survey.dta) detect(survey) output(test_survey.txt)
confirm file test_survey.txt
type test_survey.txt
di as result "TEST 46 PASSED: Survey design detection"

// ============================================================================
// TEST 47: Survival analysis detection (auto)
// ============================================================================
di as text _n "TEST 47: Survival analysis detection (auto)"
di as text "{hline 78}"
// Create survival dataset
use visits.dta, clear
collapse (max) visit_num, by(patient_id)
rename visit_num followup_time
gen died = cond(runiform() < 0.1, 1, 0)
save test_survival.dta, replace
datamap, single(test_survival.dta) detect(survival) output(test_survival_auto.txt)
confirm file test_survival_auto.txt
type test_survival_auto.txt
di as result "TEST 47 PASSED: Survival auto-detection"

// ============================================================================
// TEST 48: Survival analysis detection (explicit)
// ============================================================================
di as text _n "TEST 48: Survival analysis detection (explicit)"
di as text "{hline 78}"
datamap, single(test_survival.dta) survivalvars(followup_time died) output(test_survival_explicit.txt)
confirm file test_survival_explicit.txt
di as result "TEST 48 PASSED: Survival explicit specification"

// ============================================================================
// TEST 49: Combined detection options
// ============================================================================
di as text _n "TEST 49: Combined detection options"
di as text "{hline 78}"
datamap, single(visits.dta) detect(panel binary common) output(test_combined_detect.txt)
confirm file test_combined_detect.txt
di as result "TEST 49 PASSED: Combined detection options"

// ============================================================================
// TEST 50: Comprehensive feature test
// ============================================================================
di as text _n "TEST 50: Comprehensive feature test"
di as text "{hline 78}"
datamap, single(patients.dta) autodetect quality samples(3) ///
	missing(detail) exclude(patient_id) datesafe ///
	output(test_comprehensive.txt)
confirm file test_comprehensive.txt
type test_comprehensive.txt
di as result "TEST 50 PASSED: Comprehensive features"

// ============================================================================
// TEST SUMMARY
// ============================================================================
di as text _n _n "{hline 78}"
di as text "TEST SUITE SUMMARY"
di as text "{hline 78}"
di as result "ALL 50 TESTS PASSED SUCCESSFULLY"
di as text "{hline 78}"
di as text _n "Test datasets created:"
di as text "  - patients.dta  (n=150, 13 variables) - Master patient registry"
di as text "  - clinics.dta   (n=5, 8 variables)   - Clinic locations"
di as text "  - visits.dta    (n=600, 13 variables) - Patient visits (4 per patient)"
di as text "  - test_survey.dta - Survey design example"
di as text "  - test_survival.dta - Survival analysis example"
di as text "  - test_quality.dta - Quality check example"
di as text _n "Dataset linkages:"
di as text "  patients.clinic_id --> clinics.clinic_id"
di as text "  visits.patient_id  --> patients.patient_id"
di as text "  visits.clinic_id   --> clinics.clinic_id"
di as text _n "Key test coverage:"
di as text "  - Output format (text)"
di as text "  - All input modes (single, directory, filelist)"
di as text "  - Privacy controls (exclude, datesafe)"
di as text "  - Content controls (nostats, nofreq, nolabels, nonotes)"
di as text "  - Parameter customization (maxfreq, maxcat)"
di as text "  - Error handling (invalid inputs, missing files)"
di as text "  - Edge cases (empty dirs, missing data, high cardinality)"
di as text "  - Variable types (categorical, continuous, date, string)"
di as text "  - Performance (large datasets)"
di as text "  - Return values (r() results)"
di as text _n "NEW FEATURES (v2.0):"
di as text "  - Panel/longitudinal detection (auto and explicit)"
di as text "  - Binary variable detection"
di as text "  - Common variable pattern detection"
di as text "  - Survey design element detection"
di as text "  - Survival analysis structure detection"
di as text "  - Missing data summary (detail)"
di as text "  - Data quality checks (basic and strict)"
di as text "  - Sample observations output"
di as text "  - Autodetect mode (all detections)"
di as text "  - Directory path removed from output"
di as text "{hline 78}"
di as text _n "All test files remain in test_datamap/ directory for inspection"

// Return to original directory
cd ..
di as text _n "Test suite completed successfully - All 50 tests passed!"
