/*  demo_datamap.do - Demo output for datamap

    Produces:
      1. Console output (privacy + capped counts)  -> .log -> .md via logdoc
      2. Console output (privacy-safe text map)    -> .log -> .md via logdoc
      3. Console output (JSON + compact output)    -> .log -> .md via logdoc
      4. Console output (Markdown dictionary)      -> .log -> .md via logdoc
      5. Console output (datacheck QC + gates)     -> .log -> .md via logdoc
      6. Console output (datamvp missing patterns) -> .log -> .md via logdoc
      7. In-memory datasignature checks            -> console output
      8. Text maps                                 -> .txt
      9. JSON map                                  -> .json
     10. Markdown dictionaries                     -> .md
     11. Missingness bar graph (datamvp)           -> .png
*/

version 16.0
set more off
set varabbrev off
set linesize 120

**# Paths
local pkg_dir "datamap/demo"
capture mkdir "`pkg_dir'"

foreach f in datamap_auto.txt datamap_clinical.txt datamap_missing.txt ///
    datamap_warning.txt datamap_compact.txt datamap_metadata.json ///
    datadict_auto.md datadict_clinical.md missingness_bar.png ///
    _demo_auto.dta _demo_cohort.dta _demo_missing.dta ///
    console_datamap_privacy.log console_datamap_privacy.md ///
    console_datamap_json.log console_datamap_json.md ///
    console_datamap_compact.log console_datamap_compact.md ///
    console_datamap_missing.log console_datamap_missing.md ///
    console_datadict.log console_datadict.md ///
    console_datacheck.log console_datacheck.md ///
    console_datamvp.log console_datamvp.md {
    capture erase "`pkg_dir'/`f'"
}

**# Install package from local source
capture ado uninstall datamap
quietly net install datamap, from("`c(pwd)'/datamap") replace
discard

**# Graph scheme (datamvp missingness graph)
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`c(pwd)'/tc_schemes") replace
set scheme plotplainblind

**# Demo helper programs
capture program drop _demo_type_head
program define _demo_type_head
    version 16.0
    syntax using/ [, Lines(integer 60)]

    tempname fh
    local n 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 & `n' < `lines' {
        local ++n
        display as text `"`macval(line)'"'
        file read `fh' line
    }
    if r(eof) == 0 display as text "... [output truncated]"
    file close `fh'
end

capture program drop _demo_type_matches
program define _demo_type_matches
    version 16.0
    syntax using/ , Text(string) [Lines(integer 12)]

    tempname fh
    local n 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 & `n' < `lines' {
        if strpos(`"`macval(line)'"', `"`macval(text)'"') > 0 {
            local ++n
            display as text `"`macval(line)'"'
        }
        file read `fh' line
    }
    if `n' == 0 display as text "(no matching lines)"
    file close `fh'
end

capture program drop _demo_assert_contains
program define _demo_assert_contains
    version 16.0
    syntax using/ , Text(string)

    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`macval(text)'"') > 0 local found 1
        file read `fh' line
    }
    file close `fh'

    if !`found' {
        display as error `"expected text not found in `using': `text'"'
        exit 459
    }
end

capture program drop _demo_strip_trailing_spaces
program define _demo_strip_trailing_spaces
    version 16.0
    syntax using/

    tempname in out
    tempfile trimmed
    file open `in' using `"`using'"', read text
    file open `out' using "`trimmed'", write text replace
    file read `in' line
    while r(eof) == 0 {
        local clean = ustrregexra(`"`macval(line)'"', "[ \t]+$", "")
        file write `out' `"`macval(clean)'"' _n
        file read `in' line
    }
    file close `in'
    file close `out'
    copy "`trimmed'" `"`using'"', replace
end

**# Build synthetic clinical cohort
quietly {
    clear
    set seed 20260226
    set obs 1200

    gen double patient_id = 100000 + _n
    gen double subject_id = 5000 + _n
    gen str32 patient_name = "Patient " + string(_n, "%03.0f")

    gen double age = max(18, round(rnormal(58, 12), 0.1))
    gen double sex = rbinomial(1, 0.52)
    label define sex_lbl 0 "Female" 1 "Male"
    label values sex sex_lbl

    gen double smoking = floor(runiform() * 3)
    label define smoke_lbl 0 "Never" 1 "Former" 2 "Current"
    label values smoking smoke_lbl

    gen double bmi = round(rnormal(27.5, 5.2), 0.1)
    gen double sbp = round(rnormal(135, 20))
    gen double creatinine = round(rnormal(1.05, 0.35), 0.01)
    gen double pct_adherence = round(rnormal(78, 18), 0.1)

    gen double enroll_date = mdy(1, 1, 2021) + floor(runiform() * 900)
    format enroll_date %td
    gen double birth_date = enroll_date - round(age * 365.25)
    format birth_date %td

    gen double follow_up_time = round(rexponential(1/3.5), 0.01)
    gen double event = rbinomial(1, 0.30)
    label define event_lbl 0 "Censored" 1 "Event"
    label values event event_lbl

    gen double treatment = rbinomial(1, 0.50)
    label define treat_lbl 0 "Control" 1 "Active"
    label values treatment treat_lbl

    gen double site = ceil(runiform() * 6)
    replace site = 9 in 1/3
    label define site_lbl 1 "Stockholm" 2 "Gothenburg" 3 "Malmo" ///
        4 "Uppsala" 5 "Linkoping" 6 "Lund" 9 "Satellite clinic"
    label values site site_lbl

    gen double rare_marker = (_n <= 3)
    label define rare_lbl 0 "Absent" 1 "Present"
    label values rare_marker rare_lbl

    replace age = -3 in 1
    replace pct_adherence = 115.2 in 5

    replace bmi = . if runiform() < 0.08
    replace sbp = . if runiform() < 0.05
    replace creatinine = . if runiform() < 0.12
    replace smoking = . if runiform() < 0.15
    replace pct_adherence = . if runiform() < 0.20

    label variable patient_id "Patient identifier"
    label variable subject_id "Study subject identifier"
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
    label variable rare_marker "Rare clinical marker"

    label data "Synthetic Clinical Trial Cohort (N=1200)"
    save "`pkg_dir'/_demo_cohort.dta", replace
}

**# Build missingness dataset
quietly {
    clear
    set seed 20260227
    set obs 80

    gen double id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()
    gen double x4 = rnormal()
    gen double outcome = rbinomial(1, 0.40)

    replace x1 = . if _n > 60
    replace x2 = . if mod(_n, 4) == 0
    replace x3 = . if x1 == . | runiform() < 0.10
    replace x4 = . if _n > 70

    label variable id "Subject ID"
    label variable x1 "Biomarker A"
    label variable x2 "Biomarker B"
    label variable x3 "Biomarker C"
    label variable x4 "Biomarker D"
    label variable outcome "Binary outcome"
    label define yn 0 "No" 1 "Yes"
    label values outcome yn

    label data "Biomarker Study with Missing Data Patterns"
    save "`pkg_dir'/_demo_missing.dta", replace
}

**# Build auto output artifacts
sysuse auto, clear
quietly save "`pkg_dir'/_demo_auto.dta", replace

quietly datamap, single("`pkg_dir'/_demo_auto.dta") ///
    output("`pkg_dir'/datamap_auto.txt") ///
    exclude(make)
quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_auto.txt"

quietly datadict, single("`pkg_dir'/_demo_auto.dta") ///
    output("`pkg_dir'/datadict_auto.md") ///
    missing stats

**# Privacy controls and identifier warnings
capture log close _all
log using "`pkg_dir'/console_datamap_privacy.log", replace text name(privacy) nomsg

* # Likely identifier warning

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_warning.txt") ///
    mincell(5) noguidance compact
quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_warning.txt"

noisily display as text "Disclosure-risk summary excerpt:"
noisily _demo_type_head using "`pkg_dir'/datamap_warning.txt", lines(32)
noisily display as text "Capped unique-count excerpt:"
noisily _demo_type_matches using "`pkg_dir'/datamap_warning.txt", ///
    text(">1000") lines(6)

* # Privacy-safe text map

use "`pkg_dir'/_demo_cohort.dta", clear
quietly datasignature
local map_signature "`r(datasignature)'"
tempfile map_integrity

quietly datamap, ///
    output("`map_integrity'.txt") ///
    exclude(patient_id subject_id patient_name) ///
    datesafe mincell(5) autodetect quality samples(3) missing(detail)
quietly datasignature
assert "`map_signature'" == "`r(datasignature)'"
noisily display as result ///
    "In-memory integrity check: datamap left the datasignature unchanged"

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_clinical.txt") ///
    exclude(patient_id subject_id patient_name) ///
    datesafe mincell(5) autodetect quality samples(3) missing(detail)
quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_clinical.txt"

noisily display as text "Privacy-safe map excerpt:"
noisily _demo_type_head using "`pkg_dir'/datamap_clinical.txt", lines(72)
noisily display as text "Suppressed frequency cells:"
noisily _demo_type_matches using "`pkg_dir'/datamap_clinical.txt", ///
    text("suppressed (<5)") lines(8)
noisily display as text "Date-safe sample rows:"
noisily _demo_type_matches using "`pkg_dir'/datamap_clinical.txt", ///
    text("[DATE SUPPRESSED]") lines(6)

log close privacy

**# JSON metadata output
capture log close _all
log using "`pkg_dir'/console_datamap_json.log", replace text name(json) nomsg

* # JSON output for metadata pipelines

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_metadata.json") ///
    format(json) exclude(patient_id subject_id patient_name) ///
    datesafe mincell(5) quality missing(detail) uniqcap(100)

noisily _demo_type_head using "`pkg_dir'/datamap_metadata.json", lines(70)
noisily display as text "Censored unique-count flags:"
noisily _demo_type_matches using "`pkg_dir'/datamap_metadata.json", ///
    text("unique_values_capped") lines(8)
noisily display as text "Suppressed JSON cells:"
noisily _demo_type_matches using "`pkg_dir'/datamap_metadata.json", ///
    text("suppressed") lines(8)

log close json

**# Compact map output
capture log close _all
log using "`pkg_dir'/console_datamap_compact.log", replace text name(compact) nomsg

* # Compact text map

noisily datamap, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datamap_compact.txt") ///
    compact exclude(patient_id subject_id patient_name) datesafe mincell(5)
quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_compact.txt"

noisily _demo_type_head using "`pkg_dir'/datamap_compact.txt", lines(56)

log close compact

**# Missing-data pattern output
capture log close _all
log using "`pkg_dir'/console_datamap_missing.log", replace text name(missing) nomsg

* # Missing-data pattern output

noisily datamap, single("`pkg_dir'/_demo_missing.dta") ///
    output("`pkg_dir'/datamap_missing.txt") ///
    exclude(id) missing(pattern) quality mincell(5) noguidance
quietly _demo_strip_trailing_spaces using "`pkg_dir'/datamap_missing.txt"

noisily _demo_type_head using "`pkg_dir'/datamap_missing.txt", lines(80)

log close missing

**# Markdown dictionary with shared classification
capture log close _all
log using "`pkg_dir'/console_datadict.log", replace text name(datadict) nomsg

* # Markdown dictionary with shared classification

use "`pkg_dir'/_demo_cohort.dta", clear
quietly datasignature
local dict_signature "`r(datasignature)'"
tempfile dict_integrity

quietly datadict, ///
    output("`dict_integrity'.md") ///
    missing stats dateformat(%tdDD/NN/CCYY)
quietly datasignature
assert "`dict_signature'" == "`r(datasignature)'"
noisily display as result ///
    "In-memory integrity check: datadict left the datasignature unchanged"

noisily datadict, single("`pkg_dir'/_demo_cohort.dta") ///
    output("`pkg_dir'/datadict_clinical.md") ///
    title("SYNTH-01 Clinical Trial Data Dictionary") ///
    subtitle("Synthetic cohort for demonstration purposes") ///
    version("1.1") ///
    author("Timothy P Copeland, Karolinska Institutet") ///
    missing stats dateformat(%tdDD/NN/CCYY)

noisily _demo_type_head using "`pkg_dir'/datadict_clinical.md", lines(76)
noisily display as text "Capped dictionary rows:"
noisily _demo_type_matches using "`pkg_dir'/datadict_clinical.md", ///
    text(">1000") lines(6)

log close datadict

**# datacheck: console QC profile and expectation gates
capture log close _all
log using "`pkg_dir'/console_datacheck.log", replace text name(datacheck) nomsg

* # Console QC profile

* datacheck profiles the data in memory: per-class distributions, missingness,
* key structure, and quality flags. The cohort carries a deliberate age = -3
* outlier, a 115% adherence value, a rare "Satellite clinic" site, and missing
* biomarkers. Its 1,200 distinct IDs also exercise v1.6.0's capped count display.

use "`pkg_dir'/_demo_cohort.dta", clear
noisily datacheck patient_id age sex smoking bmi pct_adherence site, ///
    id(patient_id) outliers(3) rare(5)

* # Expectation gate (warn mode)

* The same expectations run as a gate. With warn, violations are reported and
* execution continues; drop warn to halt the do-file with r(9) instead.

noisily datacheck age pct_adherence, expectn(1200) isid(patient_id) ///
    notmissing(age sex) inrange(age 18 110 \ pct_adherence 0 100) warn

log close datacheck

**# datamvp: missing-value pattern analysis
capture log close _all
log using "`pkg_dir'/console_datamvp.log", replace text name(datamvp) nomsg

* # Missing-value pattern table

* datamvp (datacheck's patterns engine) tabulates which variables are jointly
* missing. The biomarker dataset has nested missingness (x1 absent after obs 60,
* x4 after obs 70), so a few patterns dominate.

use "`pkg_dir'/_demo_missing.dta", clear
noisily datamvp x1 x2 x3 x4, percent sort

* # Monotone-missingness test

* Monotone missingness is the key precondition for sequential multiple
* imputation; datamvp tests for it directly.

noisily datamvp x1 x2 x3 x4, monotone

log close datamvp

**# datamvp missingness bar graph
use "`pkg_dir'/_demo_missing.dta", clear
datamvp x1 x2 x3 x4, graph(bar) ///
    title("Missingness by variable") nodraw gname(dmvp_bar)
graph display dmvp_bar
graph export "`pkg_dir'/missingness_bar.png", as(png) width(1400) replace
capture graph close _all

**# Verify generated artifact content
_demo_assert_contains using "`pkg_dir'/datamap_warning.txt", ///
    text("Likely identifiers not excluded")
_demo_assert_contains using "`pkg_dir'/datamap_warning.txt", ///
    text(">1000")
_demo_assert_contains using "`pkg_dir'/datamap_clinical.txt", ///
    text("suppressed (<5)")
_demo_assert_contains using "`pkg_dir'/datamap_clinical.txt", ///
    text("[DATE SUPPRESSED]")
_demo_assert_contains using "`pkg_dir'/datamap_metadata.json", ///
    text("suppressed")
_demo_assert_contains using "`pkg_dir'/datamap_metadata.json", ///
    text("mincell")
_demo_assert_contains using "`pkg_dir'/datamap_metadata.json", ///
    text(`""unique_values_capped": true"')
_demo_assert_contains using "`pkg_dir'/datamap_compact.txt", ///
    text("QUICK REFERENCE")
_demo_assert_contains using "`pkg_dir'/datamap_missing.txt", ///
    text("Missing Data Summary")
_demo_assert_contains using "`pkg_dir'/datadict_clinical.md", ///
    text("| Variable | Label | Type | Missing | Statistics/Values |")
_demo_assert_contains using "`pkg_dir'/datadict_clinical.md", ///
    text(">1000")
_demo_assert_contains using "`pkg_dir'/console_datacheck.log", ///
    text("QUICK REFERENCE")
_demo_assert_contains using "`pkg_dir'/console_datacheck.log", ///
    text(">1000")
_demo_assert_contains using "`pkg_dir'/console_datacheck.log", ///
    text("WARNINGS (2)")
_demo_assert_contains using "`pkg_dir'/console_datamap_privacy.log", ///
    text("In-memory integrity check: datamap left the datasignature unchanged")
_demo_assert_contains using "`pkg_dir'/console_datadict.log", ///
    text("In-memory integrity check: datadict left the datasignature unchanged")
_demo_assert_contains using "`pkg_dir'/console_datamvp.log", ///
    text("Missing value patterns")
_demo_assert_contains using "`pkg_dir'/console_datamvp.log", ///
    text("Monotone missingness test")

**# Convert console logs to markdown via logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`c(pwd)'/logdoc") replace

foreach section in datamap_privacy datamap_json datamap_compact datamap_missing ///
    datadict datacheck datamvp {
    logdoc using "`pkg_dir'/console_`section'.log", ///
        output("`pkg_dir'/console_`section'.md") ///
        format(md) replace quiet
    capture erase "`pkg_dir'/console_`section'.log"
}

**# Cleanup: erase only the trivially reproducible auto copy. Keep the synthetic
**# cohort and missing-data fixtures as shipped demo assets — the README demo
**# transcripts reference demo/_demo_cohort.dta and demo/_demo_missing.dta, so
**# those paths must resolve for a reader re-running the documented commands.
capture erase "`pkg_dir'/_demo_auto.dta"
clear
