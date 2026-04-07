/*  demo_datamap.do - Generate screenshots for datamap package

    Produces 10 output files:
      1. datamap_auto.txt              — basic text documentation (sysuse auto)
      2. datamap_clinical.txt          — privacy + autodetect + quality + samples
      3. datamap_missing.txt           — missing data pattern analysis
      4. datadict_auto.md              — markdown dictionary with stats + missing
      5. datadict_clinical.md          — full metadata (title, author, version)
      6. console_datamap_basic.smcl    — screenshot of (1)
      7. console_datamap_clinical.smcl — screenshot of (2)
      8. console_datamap_missing.smcl  — screenshot of (3)
      9. console_datadict_basic.smcl   — screenshot of (4)
     10. console_datadict_clinical.smcl — screenshot of (5)
*/

version 16.0
set more off
set varabbrev off
set linesize 250

* --- Paths ---
local pkg_dir "datamap/demo"
capture mkdir "`pkg_dir'"

* --- Install tc_schemes and set default scheme ---
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("~/Stata-Tools/tc_schemes") replace
set scheme plotplainblind

* --- Reload all datamap/datadict programs ---
foreach prog in datamap datadict {
	capture program drop `prog'
}
foreach prog in _datamap_CollectFilelist _datamap_CollectFromDir           ///
    _datamap_RecursiveScan _datamap_ProcessCombined _datamap_ProcessSeparate ///
    _datamap_ProcessDataset _datamap_ProcessVariables                        ///
    _datamap_ProcessCategorical _datamap_ProcessContinuous                   ///
    _datamap_ProcessDate _datamap_ProcessString _datamap_ProcessExcluded     ///
    _datamap_ProcessValueLabels _datamap_ProcessBinary _datamap_ProcessQuality ///
    _datamap_ProcessSamples _datamap_DetectPanel _datamap_DetectSurvival     ///
    _datamap_DetectSurvey _datamap_DetectCommon _datamap_SummarizeMissing   ///
    _datamap_GenerateDatasetSummary                                          ///
    _datadict_CollectFilelist _datadict_CollectFromDir _datadict_RecursiveScan ///
    _datadict_ProcessCombined _datadict_ProcessSeparate                      ///
    _datadict_ProcessOneDataset _datadict_WriteVariableRow                   ///
    _datadict_FormatStatNumber _datadict_GetCategoricalStats                 ///
    _datadict_GetUnlabeledStats _datadict_GetValueLabelString               ///
    _datadict_EscapeMarkdown _datadict_CountFiles                            ///
    _datadict_CollectDatasetNames _datadict_MakeAnchor {
	capture program drop `prog'
}
quietly run datamap/datamap.ado
quietly run datamap/datadict.ado


**# Build synthetic clinical cohort
* Realistic longitudinal dataset with features for autodetect, quality, and missing

clear
set seed 20260226
set obs 200

* Patient IDs and demographics
gen int patient_id = _n
gen str30 patient_name = "Patient " + string(_n)
gen double age = round(rnormal(55, 14), 0.1)
replace age = -3 in 1                              // quality flag: negative age
gen byte sex = rbinomial(1, 0.48)
label define sex_lbl 0 "Female" 1 "Male"
label values sex sex_lbl

* Clinical measures
gen byte smoking = floor(runiform() * 3)
label define smoke_lbl 0 "Never" 1 "Former" 2 "Current"
label values smoking smoke_lbl
gen double bmi = round(rnormal(27.5, 5.2), 0.1)
gen double sbp = round(rnormal(135, 20))
gen double creatinine = round(rnormal(1.05, 0.35), 0.01)
gen double pct_adherence = round(rnormal(78, 18), 0.1)
replace pct_adherence = 115.2 in 5                 // quality flag: >100%

* Dates
gen double enroll_date = mdy(1, 1, 2018) + floor(runiform() * 730)
format enroll_date %td
gen double birth_date = enroll_date - round(age * 365.25)
format birth_date %td

* Survival variables
gen double follow_up_time = rexponential(1/3.5)
replace follow_up_time = round(follow_up_time, 0.01)
gen byte event = rbinomial(1, 0.3)
label define event_lbl 0 "Censored" 1 "Event"
label values event event_lbl

* Treatment group
gen byte treatment = rbinomial(1, 0.5)
label define treat_lbl 0 "Control" 1 "Active"
label values treatment treat_lbl

* Study site (higher cardinality categorical)
gen byte site = ceil(runiform() * 8)
label define site_lbl 1 "Stockholm" 2 "Gothenburg" 3 "Malmo"  ///
    4 "Uppsala" 5 "Linkoping" 6 "Lund" 7 "Umea" 8 "Orebro"
label values site site_lbl

* Introduce realistic missing data patterns
replace bmi = . if runiform() < 0.08
replace sbp = . if runiform() < 0.05
replace creatinine = . if runiform() < 0.12
replace smoking = . if runiform() < 0.15
replace pct_adherence = . if runiform() < 0.20

* Variable labels
label variable patient_id "Patient identifier"
label variable patient_name "Patient full name"
label variable age "Age at enrollment (years)"
label variable sex "Biological sex"
label variable smoking "Smoking status"
label variable bmi "Body mass index (kg/m2)"
label variable sbp "Systolic blood pressure (mmHg)"
label variable creatinine "Serum creatinine (mg/dL)"
label variable pct_adherence "Medication adherence (%)"
label variable enroll_date "Date of enrollment"
label variable birth_date "Date of birth"
label variable follow_up_time "Follow-up time (years)"
label variable event "Primary endpoint"
label variable treatment "Randomization arm"
label variable site "Study site"

label data "Synthetic Clinical Trial Cohort (N=200)"
quietly save "`pkg_dir'/_demo_cohort.dta", replace


**# Build small dataset with heavy missingness for pattern demo

clear
set seed 20260227
set obs 80

gen int id = _n
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen double x4 = rnormal()
gen byte outcome = rbinomial(1, 0.4)

* Create structured missing patterns (not random)
replace x1 = . if _n > 60                          // 25% missing, block pattern
replace x2 = . if mod(_n, 4) == 0                  // 25% missing, periodic
replace x3 = . if x1 == . | runiform() < 0.10      // correlated with x1
replace x4 = . if _n > 70                          // 12.5% missing

label variable id "Subject ID"
label variable x1 "Biomarker A"
label variable x2 "Biomarker B"
label variable x3 "Biomarker C"
label variable x4 "Biomarker D"
label variable outcome "Binary outcome"
label define yn 0 "No" 1 "Yes"
label values outcome yn

label data "Biomarker Study with Missing Data Patterns"
quietly save "`pkg_dir'/_demo_missing.dta", replace


**# Save auto data for basic demos

sysuse auto, clear
quietly save "`pkg_dir'/_demo_auto.dta", replace


**# 1. datamap — basic documentation (sysuse auto)
* Straightforward use case: document a well-known dataset

quietly datamap, single("`pkg_dir'/_demo_auto.dta") ///
    output("`pkg_dir'/datamap_auto.txt") ///
    exclude(make)

log using "`pkg_dir'/console_datamap_basic.smcl", replace smcl name(dm1) nomsg
noisily type "`pkg_dir'/datamap_auto.txt"
log close dm1


**# 2. datamap — clinical cohort with privacy + autodetect + quality + samples
* Real-world use case: share dataset documentation while protecting PHI

quietly datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_clinical.txt") ///
    exclude(patient_id patient_name) ///
    datesafe ///
    autodetect ///
    quality ///
    samples(3)

log using "`pkg_dir'/console_datamap_clinical.smcl", replace smcl name(dm2) nomsg
noisily type "`pkg_dir'/datamap_clinical.txt"
log close dm2


**# 3. datamap — missing data pattern analysis
* Analytical use case: understand missingness structure before imputation

quietly datamap, single("`pkg_dir'/_demo_missing.dta") ///
    output("`pkg_dir'/datamap_missing.txt") ///
    missing(pattern) ///
    quality

log using "`pkg_dir'/console_datamap_missing.smcl", replace smcl name(dm3) nomsg
noisily type "`pkg_dir'/datamap_missing.txt"
log close dm3


**# 4. datadict — markdown dictionary (sysuse auto)
* Quick data dictionary with stats and missing columns

quietly datadict, single("`pkg_dir'/_demo_auto.dta") ///
    output("`pkg_dir'/datadict_auto.md") ///
    missing stats

log using "`pkg_dir'/console_datadict_basic.smcl", replace smcl name(dd1) nomsg
noisily type "`pkg_dir'/datadict_auto.md"
log close dd1


**# 5. datadict — full clinical dictionary with metadata
* Publication-ready data dictionary with title, author, version

quietly datadict, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datadict_clinical.md") ///
    title("SYNTH-01 Clinical Trial Data Dictionary") ///
    subtitle("Synthetic cohort for demonstration purposes") ///
    version("1.0") ///
    author("T. Copeland, Karolinska Institutet") ///
    missing stats

log using "`pkg_dir'/console_datadict_clinical.smcl", replace smcl name(dd2) nomsg
noisily type "`pkg_dir'/datadict_clinical.md"
log close dd2


**# Cleanup temp data only — keep .txt and .md output files
capture erase "`pkg_dir'/_demo_auto.dta"
capture erase "`pkg_dir'/_demo_cohort.dta"
capture erase "`pkg_dir'/_demo_missing.dta"
clear
