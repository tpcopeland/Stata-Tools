* gallery_codescan_prevalence.do - codescan's native prevalence chart (graph option)
* Run with the working directory set to the Stata-Tools repository root.
version 16.0
set linesize 120
set varabbrev off
set seed 20261012

local root "`c(pwd)'"
sysdir set PLUS "`c(tmpdir)'/gallery_plus"
sysdir set PERSONAL "`c(tmpdir)'/gallery_personal"
capture mkdir "`c(tmpdir)'/gallery_plus"
capture mkdir "`c(tmpdir)'/gallery_personal"
quietly net install codescan, from("`root'/codescan") replace
quietly net install tc_schemes, from("`root'/tc_schemes") replace
set scheme white_tableau
assert c(scheme) == "white_tableau"

* One row per hospital diagnosis, plus a blank-code row (day before entry) for each
* cohort member so that people with no recorded diagnosis stay in the denominator
tempfile dx
use "_data/cohort", clear
keep id study_entry
gen long visit_date = study_entry - 1
gen str4 icd = ""
save `dx'
use "_data/diagnoses", clear
merge m:1 id using "_data/cohort", nogen assert(match using) keep(match) keepusing(study_entry)
keep id visit_date icd study_entry
append using `dx'

* codescan: ICD-10 rules over the 5 years before cohort entry, whole cohort, native chart
codescan icd, id(id) date(visit_date) refdate(study_entry) lookback(1825) collapse preserve ///
    define(dep "F3[23]" | anx "F4[01]" | htn "I10" | back "M54" | dm "E1[0-4]" | ///
           ihd "I2[0-5]" | alc "F10" | copd "J44") ///
    label(dep "Depression" \ anx "Anxiety" \ htn "Hypertension" \ back "Back pain" \ ///
          dm "Diabetes" \ ihd "Ischaemic heart" \ alc "Alcohol use" \ copd "COPD") ///
    format(%9.0f) graph
* Size only (the package draws the chart but takes no size options)
graph display, xsize(6) ysize(4)
graph export "_resources/gallery/codescan_prevalence.png", replace width(1600)
