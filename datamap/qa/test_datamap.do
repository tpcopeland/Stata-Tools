clear all
set more off
version 16.0

* test_datamap.do - Functional tests for datamap package (datamap + datadict)
* Generated: 2026-03-13
* Tests: 65

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

local pkg_dir "/home/tpcopeland/Stata-Tools/datamap"
local qa_dir  "`pkg_dir'/qa"
local tmp_dir "`qa_dir'/data"

* Create data directory for test outputs
capture mkdir "`tmp_dir'"

* Uninstall any existing version
capture ado uninstall datamap

* Install from local directory
quietly net install datamap, from("`pkg_dir'") force

* ============================================================
* Create Test Datasets
* ============================================================

* Dataset 1: Mixed variable types (cohort-like)
clear
set seed 12345
set obs 100
gen double id = _n
gen double age = 20 + int(60*runiform())
gen byte sex = cond(runiform() > 0.5, 1, 0)
label define sexlbl 0 "Female" 1 "Male"
label values sex sexlbl
gen double bmi = 18 + 15*runiform()
gen byte region = 1 + int(4*runiform())
label define reglbl 1 "North" 2 "South" 3 "East" 4 "West"
label values region reglbl
gen double entry_date = td(01jan2020) + int(365*runiform())
format entry_date %td
gen double exit_date = entry_date + 30 + int(335*runiform())
format exit_date %td
gen str20 name = "Person" + string(_n)
label data "Test cohort dataset"
label variable id "Unique identifier"
label variable age "Age in years"
label variable sex "Sex of participant"
label variable bmi "Body mass index"
label variable region "Geographic region"
label variable entry_date "Study entry date"
label variable exit_date "Study exit date"
label variable name "Participant name"
note: This is a synthetic test dataset
save "`tmp_dir'/test_cohort.dta", replace

* Dataset 2: With missing values
replace age = . in 1/10
replace bmi = . in 5/15
replace region = . in 20/25
save "`tmp_dir'/test_cohort_miss.dta", replace

* Dataset 3: Panel data
clear
set seed 54321
set obs 200
gen patient_id = 1 + int((_n - 1) / 4)
bysort patient_id: gen visit = _n
gen outcome = runiform()
gen double visit_date = td(01jan2020) + (visit - 1) * 90
format visit_date %td
label data "Panel test dataset"
save "`tmp_dir'/test_panel.dta", replace

* Dataset 4: Small dataset for edge cases
clear
set obs 5
gen x = _n
gen y = _n * 2
label data "Small test dataset"
save "`tmp_dir'/test_small.dta", replace

* Dataset 5: Single observation
clear
set obs 1
gen x = 42
save "`tmp_dir'/test_single.dta", replace

* ============================================================
* datamap: Basic Functionality
* ============================================================

* Test: datamap single dataset
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out.txt")
    confirm file "`tmp_dir'/_out.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - single dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - single dataset (error `=_rc')"
    local ++fail_count
}

* Test: datamap with .dta extension
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort.dta") output("`tmp_dir'/_out2.txt")
    confirm file "`tmp_dir'/_out2.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - .dta extension"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - .dta extension (error `=_rc')"
    local ++fail_count
}

* Test: datamap return values
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out_rv.txt")
    assert r(nfiles) == 1
    assert "`r(format)'" == "text"
    assert regexm("`r(output)'", "_out_rv\.txt")
}
if _rc == 0 {
    display as result "  PASS: datamap - return values r(nfiles) r(format) r(output)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - return values (error `=_rc')"
    local ++fail_count
}

* Test: datamap custom output filename
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_custom_name.txt")
    confirm file "`tmp_dir'/_custom_name.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - custom output filename"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - custom output filename (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Privacy Options
* ============================================================

* Test: exclude variables
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") exclude(id name) ///
        output("`tmp_dir'/_out_excl.txt")
    confirm file "`tmp_dir'/_out_excl.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - exclude(id name)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - exclude (error `=_rc')"
    local ++fail_count
}

* Test: datesafe mode
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") datesafe ///
        output("`tmp_dir'/_out_ds.txt")
    confirm file "`tmp_dir'/_out_ds.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - datesafe"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - datesafe (error `=_rc')"
    local ++fail_count
}

* Test: combined privacy (exclude + datesafe)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") exclude(id name) datesafe ///
        output("`tmp_dir'/_out_priv.txt")
    confirm file "`tmp_dir'/_out_priv.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - combined privacy (exclude + datesafe)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - combined privacy (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Content Control Options
* ============================================================

* Test: nostats
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") nostats ///
        output("`tmp_dir'/_out_ns.txt")
    confirm file "`tmp_dir'/_out_ns.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - nostats"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - nostats (error `=_rc')"
    local ++fail_count
}

* Test: nofreq
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") nofreq ///
        output("`tmp_dir'/_out_nf.txt")
    confirm file "`tmp_dir'/_out_nf.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - nofreq"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - nofreq (error `=_rc')"
    local ++fail_count
}

* Test: nolabels
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") nolabels ///
        output("`tmp_dir'/_out_nl.txt")
    confirm file "`tmp_dir'/_out_nl.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - nolabels"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - nolabels (error `=_rc')"
    local ++fail_count
}

* Test: nonotes
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") nonotes ///
        output("`tmp_dir'/_out_nn.txt")
    confirm file "`tmp_dir'/_out_nn.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - nonotes"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - nonotes (error `=_rc')"
    local ++fail_count
}

* Test: all content suppression combined
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") nostats nofreq nolabels nonotes ///
        output("`tmp_dir'/_out_allsup.txt")
    confirm file "`tmp_dir'/_out_allsup.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - all content suppression combined"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - all content suppression (error `=_rc')"
    local ++fail_count
}

* Test: custom maxcat
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") maxcat(10) ///
        output("`tmp_dir'/_out_mc.txt")
    confirm file "`tmp_dir'/_out_mc.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - maxcat(10)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - maxcat(10) (error `=_rc')"
    local ++fail_count
}

* Test: custom maxfreq
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") maxfreq(5) ///
        output("`tmp_dir'/_out_mf.txt")
    confirm file "`tmp_dir'/_out_mf.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - maxfreq(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - maxfreq(5) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Detection Features
* ============================================================

* Test: autodetect
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") autodetect ///
        output("`tmp_dir'/_out_ad.txt")
    confirm file "`tmp_dir'/_out_ad.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - autodetect"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - autodetect (error `=_rc')"
    local ++fail_count
}

* Test: detect(panel) with panelid
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_panel") detect(panel) panelid(patient_id) ///
        output("`tmp_dir'/_out_panel.txt")
    confirm file "`tmp_dir'/_out_panel.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - detect(panel) + panelid"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - detect(panel) (error `=_rc')"
    local ++fail_count
}

* Test: detect(binary)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") detect(binary) ///
        output("`tmp_dir'/_out_bin.txt")
    confirm file "`tmp_dir'/_out_bin.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - detect(binary)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - detect(binary) (error `=_rc')"
    local ++fail_count
}

* Test: detect(survival)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") detect(survival) ///
        output("`tmp_dir'/_out_surv.txt")
    confirm file "`tmp_dir'/_out_surv.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - detect(survival)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - detect(survival) (error `=_rc')"
    local ++fail_count
}

* Test: detect(common)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") detect(common) ///
        output("`tmp_dir'/_out_com.txt")
    confirm file "`tmp_dir'/_out_com.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - detect(common)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - detect(common) (error `=_rc')"
    local ++fail_count
}

* Test: survivalvars
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") survivalvars(entry_date exit_date) ///
        output("`tmp_dir'/_out_sv.txt")
    confirm file "`tmp_dir'/_out_sv.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - survivalvars()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - survivalvars() (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Quality and Missing Options
* ============================================================

* Test: quality
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") quality ///
        output("`tmp_dir'/_out_q.txt")
    confirm file "`tmp_dir'/_out_q.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - quality"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - quality (error `=_rc')"
    local ++fail_count
}

* Test: quality2(strict)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") quality2(strict) ///
        output("`tmp_dir'/_out_q2.txt")
    confirm file "`tmp_dir'/_out_q2.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - quality2(strict)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - quality2(strict) (error `=_rc')"
    local ++fail_count
}

* Test: missing(detail)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort_miss") missing(detail) ///
        output("`tmp_dir'/_out_md.txt")
    confirm file "`tmp_dir'/_out_md.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - missing(detail)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - missing(detail) (error `=_rc')"
    local ++fail_count
}

* Test: missing(pattern)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort_miss") missing(pattern) ///
        output("`tmp_dir'/_out_mp.txt")
    confirm file "`tmp_dir'/_out_mp.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - missing(pattern)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - missing(pattern) (error `=_rc')"
    local ++fail_count
}

* Test: samples
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") samples(5) ///
        output("`tmp_dir'/_out_samp.txt")
    confirm file "`tmp_dir'/_out_samp.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - samples(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - samples(5) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Multi-file and Directory Modes
* ============================================================

* Test: filelist mode
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/test_cohort" "`tmp_dir'/test_small") ///
        output("`tmp_dir'/_out_fl.txt")
    confirm file "`tmp_dir'/_out_fl.txt"
    assert r(nfiles) == 2
}
if _rc == 0 {
    display as result "  PASS: datamap - filelist mode (2 files)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - filelist mode (error `=_rc')"
    local ++fail_count
}

* Test: directory mode
local ++test_count
capture noisily {
    datamap, directory("`tmp_dir'") output("`tmp_dir'/_out_dir.txt")
    confirm file "`tmp_dir'/_out_dir.txt"
    assert r(nfiles) >= 1
}
if _rc == 0 {
    display as result "  PASS: datamap - directory mode"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - directory mode (error `=_rc')"
    local ++fail_count
}

* Test: directory with recursive
local ++test_count
capture noisily {
    capture mkdir "`tmp_dir'/_subdir"
    use "`tmp_dir'/test_small.dta", clear
    save "`tmp_dir'/_subdir/_sub.dta", replace

    datamap, directory("`tmp_dir'") recursive output("`tmp_dir'/_out_rec.txt")
    confirm file "`tmp_dir'/_out_rec.txt"

    capture erase "`tmp_dir'/_subdir/_sub.dta"
    capture rmdir "`tmp_dir'/_subdir"
}
if _rc == 0 {
    display as result "  PASS: datamap - directory + recursive"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - directory + recursive (error `=_rc')"
    local ++fail_count
    capture erase "`tmp_dir'/_subdir/_sub.dta"
    capture rmdir "`tmp_dir'/_subdir"
}

* Test: separate output files
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/test_cohort" "`tmp_dir'/test_small") ///
        output("`tmp_dir'/_out_sep.txt") separate
    * separate creates <basename>_map.txt files
    confirm file "`tmp_dir'/test_cohort_map.txt"
    confirm file "`tmp_dir'/test_small_map.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - separate output files"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - separate output (error `=_rc')"
    local ++fail_count
}

* Test: append mode
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out_app.txt")
    datamap, single("`tmp_dir'/test_small") output("`tmp_dir'/_out_app.txt") append
    confirm file "`tmp_dir'/_out_app.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - append mode"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - append mode (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Comprehensive Combination
* ============================================================

* Test: full comprehensive analysis
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort_miss") ///
        output("`tmp_dir'/_out_full.txt") ///
        exclude(id) datesafe quality missing(detail) ///
        samples(3) autodetect maxcat(15) maxfreq(20)
    confirm file "`tmp_dir'/_out_full.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - full comprehensive analysis"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - full comprehensive (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Edge Cases
* ============================================================

* Test: single observation dataset
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_single") output("`tmp_dir'/_out_1obs.txt")
    confirm file "`tmp_dir'/_out_1obs.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - single observation dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - single observation (error `=_rc')"
    local ++fail_count
}

* Test: small dataset (5 obs)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_small") output("`tmp_dir'/_out_5obs.txt")
    confirm file "`tmp_dir'/_out_5obs.txt"
}
if _rc == 0 {
    display as result "  PASS: datamap - small dataset (5 obs)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - small dataset (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Data Preservation
* ============================================================

* Test: user data preserved after datamap
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    local k_before = c(k)
    datasignature
    local sig_before "`r(datasignature)'"

    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out_pres.txt")

    assert _N == `N_before'
    assert c(k) == `k_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: datamap - data preservation (N, k, signature)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Error Handling
* ============================================================

* Test: no input specified
local ++test_count
capture noisily {
    capture datamap, output("`tmp_dir'/_err.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap - error on no input (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - error on no input (error `=_rc')"
    local ++fail_count
}

* Test: multiple input options
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/test_cohort") directory("`tmp_dir'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap - error on multiple inputs (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - error on multiple inputs (error `=_rc')"
    local ++fail_count
}

* Test: invalid maxcat (negative)
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/test_cohort") maxcat(-1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap - error on maxcat(-1)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - error on maxcat(-1) (error `=_rc')"
    local ++fail_count
}

* Test: invalid maxfreq (zero)
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/test_cohort") maxfreq(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap - error on maxfreq(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - error on maxfreq(0) (error `=_rc')"
    local ++fail_count
}

* Test: nonexistent file
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/nonexistent_file")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: datamap - error on nonexistent file"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - error on nonexistent file (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Basic Functionality
* ============================================================

* Test: datadict single dataset
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_out.md")
    confirm file "`tmp_dir'/_dd_out.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - single dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - single dataset (error `=_rc')"
    local ++fail_count
}

* Test: datadict return values
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_rv.md")
    assert r(nfiles) == 1
    assert regexm("`r(output)'", "_dd_rv\.md")
}
if _rc == 0 {
    display as result "  PASS: datadict - return values r(nfiles) r(output)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - return values (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Metadata Options
* ============================================================

* Test: title
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_title.md") ///
        title("Custom Title")
    confirm file "`tmp_dir'/_dd_title.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - title()"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - title() (error `=_rc')"
    local ++fail_count
}

* Test: subtitle
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_sub.md") ///
        title("Test") subtitle("A subtitle")
    confirm file "`tmp_dir'/_dd_sub.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - subtitle()"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - subtitle() (error `=_rc')"
    local ++fail_count
}

* Test: version
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_ver.md") ///
        version("1.0")
    confirm file "`tmp_dir'/_dd_ver.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - version()"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - version() (error `=_rc')"
    local ++fail_count
}

* Test: author
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_auth.md") ///
        author("Test Author")
    confirm file "`tmp_dir'/_dd_auth.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - author()"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - author() (error `=_rc')"
    local ++fail_count
}

* Test: date
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_date.md") ///
        date("2026-01-01")
    confirm file "`tmp_dir'/_dd_date.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - date()"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - date() (error `=_rc')"
    local ++fail_count
}

* Test: notes
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_notes.md") ///
        notes("Test notes for the data dictionary.")
    confirm file "`tmp_dir'/_dd_notes.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - notes()"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - notes() (error `=_rc')"
    local ++fail_count
}

* Test: changelog
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_cl.md") ///
        changelog("v1.0: Initial release")
    confirm file "`tmp_dir'/_dd_cl.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - changelog()"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - changelog() (error `=_rc')"
    local ++fail_count
}

* Test: full metadata combination
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_fullmeta.md") ///
        title("MS Cohort") subtitle("Data Dictionary") ///
        version("2.0") author("Test Author") date("2026-01-01") ///
        notes("Comprehensive dataset.") changelog("v2.0: Added outcomes")
    confirm file "`tmp_dir'/_dd_fullmeta.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - full metadata combination"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - full metadata (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Content Options
* ============================================================

* Test: missing column
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort_miss") output("`tmp_dir'/_dd_miss.md") ///
        missing
    confirm file "`tmp_dir'/_dd_miss.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - missing"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - missing (error `=_rc')"
    local ++fail_count
}

* Test: stats column
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_stats.md") ///
        stats
    confirm file "`tmp_dir'/_dd_stats.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - stats"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - stats (error `=_rc')"
    local ++fail_count
}

* Test: missing + stats combined
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort_miss") output("`tmp_dir'/_dd_both.md") ///
        missing stats
    confirm file "`tmp_dir'/_dd_both.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - missing + stats combined"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - missing + stats (error `=_rc')"
    local ++fail_count
}

* Test: custom maxcat
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_mc.md") ///
        maxcat(10)
    confirm file "`tmp_dir'/_dd_mc.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - maxcat(10)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - maxcat(10) (error `=_rc')"
    local ++fail_count
}

* Test: custom maxfreq
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_mf.md") ///
        maxfreq(5)
    confirm file "`tmp_dir'/_dd_mf.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - maxfreq(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - maxfreq(5) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Multi-file and Directory Modes
* ============================================================

* Test: filelist mode
local ++test_count
capture noisily {
    datadict, filelist("`tmp_dir'/test_cohort" "`tmp_dir'/test_small") ///
        output("`tmp_dir'/_dd_fl.md")
    confirm file "`tmp_dir'/_dd_fl.md"
    assert r(nfiles) == 2
}
if _rc == 0 {
    display as result "  PASS: datadict - filelist mode (2 files)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - filelist mode (error `=_rc')"
    local ++fail_count
}

* Test: directory mode
local ++test_count
capture noisily {
    datadict, directory("`tmp_dir'") output("`tmp_dir'/_dd_dir.md")
    confirm file "`tmp_dir'/_dd_dir.md"
    assert r(nfiles) >= 1
}
if _rc == 0 {
    display as result "  PASS: datadict - directory mode"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - directory mode (error `=_rc')"
    local ++fail_count
}

* Test: directory with recursive
local ++test_count
capture noisily {
    capture mkdir "`tmp_dir'/_subdir2"
    use "`tmp_dir'/test_small.dta", clear
    save "`tmp_dir'/_subdir2/_sub.dta", replace

    datadict, directory("`tmp_dir'") recursive output("`tmp_dir'/_dd_rec.md")
    confirm file "`tmp_dir'/_dd_rec.md"

    capture erase "`tmp_dir'/_subdir2/_sub.dta"
    capture rmdir "`tmp_dir'/_subdir2"
}
if _rc == 0 {
    display as result "  PASS: datadict - directory + recursive"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - directory + recursive (error `=_rc')"
    local ++fail_count
    capture erase "`tmp_dir'/_subdir2/_sub.dta"
    capture rmdir "`tmp_dir'/_subdir2"
}

* Test: separate output files
local ++test_count
capture noisily {
    datadict, filelist("`tmp_dir'/test_cohort" "`tmp_dir'/test_small") ///
        output("`tmp_dir'/_dd_sep.md") separate
    * separate creates <basename>_dictionary.md in cwd, not in data/
    confirm file "`qa_dir'/test_cohort_dictionary.md"
    confirm file "`qa_dir'/test_small_dictionary.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - separate output files"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - separate output (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Data Preservation
* ============================================================

* Test: user data preserved after datadict
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    local k_before = c(k)
    datasignature
    local sig_before "`r(datasignature)'"

    datadict, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_pres.md")

    assert _N == `N_before'
    assert c(k) == `k_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: datadict - data preservation (N, k, signature)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Error Handling
* ============================================================

* Test: no input specified
local ++test_count
capture noisily {
    capture datadict, output("`tmp_dir'/_err.md")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datadict - error on no input (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - error on no input (error `=_rc')"
    local ++fail_count
}

* Test: multiple input options
local ++test_count
capture noisily {
    capture datadict, single("`tmp_dir'/test_cohort") directory("`tmp_dir'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datadict - error on multiple inputs (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - error on multiple inputs (error `=_rc')"
    local ++fail_count
}

* Test: invalid maxcat (zero)
local ++test_count
capture noisily {
    capture datadict, single("`tmp_dir'/test_cohort") maxcat(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datadict - error on maxcat(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - error on maxcat(0) (error `=_rc')"
    local ++fail_count
}

* Test: nonexistent file
local ++test_count
capture noisily {
    capture datadict, single("`tmp_dir'/nonexistent_file")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: datadict - error on nonexistent file"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - error on nonexistent file (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Full Comprehensive
* ============================================================

* Test: datadict with all options
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/test_cohort_miss") ///
        output("`tmp_dir'/_dd_complete.md") ///
        title("Complete Test") subtitle("All Options") ///
        version("1.0") author("Test") date("2026-01-01") ///
        notes("Full test.") changelog("v1.0: Init") ///
        missing stats maxcat(15) maxfreq(20)
    confirm file "`tmp_dir'/_dd_complete.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - full comprehensive"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - full comprehensive (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

* Remove all temp output files
local txt_files : dir "`tmp_dir'" files "_out*.txt"
foreach f of local txt_files {
    capture erase "`tmp_dir'/`f'"
}
local txt_files : dir "`tmp_dir'" files "_custom*.txt"
foreach f of local txt_files {
    capture erase "`tmp_dir'/`f'"
}
local md_files : dir "`tmp_dir'" files "_dd_*.md"
foreach f of local md_files {
    capture erase "`tmp_dir'/`f'"
}
capture erase "`tmp_dir'/test_cohort_map.txt"
capture erase "`tmp_dir'/test_small_map.txt"
capture erase "`qa_dir'/test_cohort_dictionary.md"
capture erase "`qa_dir'/test_small_dictionary.md"

* ============================================================
* Summary
* ============================================================

display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
