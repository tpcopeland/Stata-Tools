*! test_datamap.do Version 1.0.0  2026/08/11
*! Functional tests for datamap (and, until 2.0.0, datadict)
*
* 2026-11-10 (datamap 2.0.0): datadict is removed and datamap writes one
* Markdown document, so the "datadict:" sections are ported to datamap's
* Markdown writer under the same test names.  Port rules, test by test:
*   r(nvars_total)/r(nobs_total) -> r(nvars)/r(nobs) (single and memory runs
*     only; directory, filelist and manifest runs have no successor, so those
*     tests count the Variables-table rows and the "- Observations:" lines of
*     the document instead)
*   date(2026-01-01) -> docdate(2026-01-01)
*   the "missing" and "stats" options -> the default table (the Missing column
*     and the statistics are always there); those two tests assert the cells
*   the "datasignature" option -> always printed ("- Data signature:")
*   separate default suffix _dictionary -> _map
*   the default "All date variables are displayed" note -> none (a Notes
*     section exists only with notes()), asserted absent
* The datamap tests no longer use the .txt extension: the file is Markdown.
* Documents are read through _qa_md.do (Mata): a line ending in a backtick
* breaks a Stata-macro line reader.
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  
tempfile test_workspace
local tmp_dir "`test_workspace'_data"

* Create data directory for test outputs
capture mkdir "`tmp_dir'"

* Uninstall any existing version

capture ado uninstall datamap

* Install from local directory
quietly net install datamap, from("`pkg_dir'") force
do "`qa_dir'/_qa_md.do"

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
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out.md")
    confirm file "`tmp_dir'/_out.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out.md")) > 0
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
    datamap, single("`tmp_dir'/test_cohort.dta") output("`tmp_dir'/_out2.md")
    confirm file "`tmp_dir'/_out2.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out2.md")) > 0
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
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out_rv.md")
    assert r(nfiles) == 1
    * r(format) was removed with the text layout (2.0.0): it must be unset
    assert "`r(format)'" == ""
    assert regexm("`r(output)'", "_out_rv\.md")
    assert "`r(mode)'" == "single"
    assert strpos("`r(files)'", "test_cohort") > 0
    assert "`r(outputs)'" != ""
}
if _rc == 0 {
    display as result "  PASS: datamap - return values r(nfiles) r(mode) r(files) r(outputs) r(output), r(format) gone"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - return values (error `=_rc')"
    local ++fail_count
}

* Test: datamap custom output filename
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_custom_name.md")
    confirm file "`tmp_dir'/_custom_name.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_custom_name.md")) > 0
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
        output("`tmp_dir'/_out_excl.md")
    confirm file "`tmp_dir'/_out_excl.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_excl.md")) > 0
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
        output("`tmp_dir'/_out_ds.md")
    confirm file "`tmp_dir'/_out_ds.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_ds.md")) > 0
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
        output("`tmp_dir'/_out_priv.md")
    confirm file "`tmp_dir'/_out_priv.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_priv.md")) > 0
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
        output("`tmp_dir'/_out_ns.md")
    confirm file "`tmp_dir'/_out_ns.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_ns.md")) > 0
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
        output("`tmp_dir'/_out_nf.md")
    confirm file "`tmp_dir'/_out_nf.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_nf.md")) > 0
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
        output("`tmp_dir'/_out_nl.md")
    confirm file "`tmp_dir'/_out_nl.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_nl.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: datamap - nolabels"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - nolabels (error `=_rc')"
    local ++fail_count
}

* Test: all content suppression combined (nonotes removed in v1.0.4)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") nostats nofreq nolabels ///
        output("`tmp_dir'/_out_allsup.md")
    confirm file "`tmp_dir'/_out_allsup.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_allsup.md")) > 0
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
        output("`tmp_dir'/_out_mc.md")
    confirm file "`tmp_dir'/_out_mc.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_mc.md")) > 0
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
        output("`tmp_dir'/_out_mf.md")
    confirm file "`tmp_dir'/_out_mf.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_mf.md")) > 0
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
        output("`tmp_dir'/_out_ad.md")
    confirm file "`tmp_dir'/_out_ad.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_ad.md")) > 0
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
        output("`tmp_dir'/_out_panel.md")
    confirm file "`tmp_dir'/_out_panel.md"
    assert !missing(r(nvars))
    assert r(nvars) == 4
    assert strlen(fileread("`tmp_dir'/_out_panel.md")) > 0
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
        output("`tmp_dir'/_out_bin.md")
    confirm file "`tmp_dir'/_out_bin.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_bin.md")) > 0
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
        output("`tmp_dir'/_out_surv.md")
    confirm file "`tmp_dir'/_out_surv.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_surv.md")) > 0
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
        output("`tmp_dir'/_out_com.md")
    confirm file "`tmp_dir'/_out_com.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_com.md")) > 0
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
        output("`tmp_dir'/_out_sv.md")
    confirm file "`tmp_dir'/_out_sv.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_sv.md")) > 0
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
        output("`tmp_dir'/_out_q.md")
    confirm file "`tmp_dir'/_out_q.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_q.md")) > 0
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
        output("`tmp_dir'/_out_q2.md")
    confirm file "`tmp_dir'/_out_q2.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_q2.md")) > 0
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
        output("`tmp_dir'/_out_md.md")
    confirm file "`tmp_dir'/_out_md.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_md.md")) > 0
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
        output("`tmp_dir'/_out_mp.md")
    confirm file "`tmp_dir'/_out_mp.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_mp.md")) > 0
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
        output("`tmp_dir'/_out_samp.md")
    confirm file "`tmp_dir'/_out_samp.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_samp.md")) > 0
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
        output("`tmp_dir'/_out_fl.md")
    confirm file "`tmp_dir'/_out_fl.md"
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
    datamap, directory("`tmp_dir'") output("`tmp_dir'/_out_dir.md")
    confirm file "`tmp_dir'/_out_dir.md"
    * Exactly 5 top-level .dta files exist in tmp_dir at this point: cohort,
    * cohort_miss, panel, small, single (no subdirectory yet).
    assert !missing(r(nfiles))
    assert r(nfiles) == 5
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

    datamap, directory("`tmp_dir'") recursive output("`tmp_dir'/_out_rec.md")
    confirm file "`tmp_dir'/_out_rec.md"
    * Directory mode never returns r(nvars)/r(nobs) (datamap.ado only sets
    * those for single() mode) -- r(nfiles) is the mode-appropriate oracle.
    * recursive must find the nested file too: 5 top-level + 1 in _subdir.
    assert !missing(r(nfiles))
    assert r(nfiles) == 6
    assert strlen(fileread("`tmp_dir'/_out_rec.md")) > 0

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
        output("`tmp_dir'/_out_sep.md") separate
    * separate creates <basename>_map.md files
    confirm file "`tmp_dir'/test_cohort_map.md"
    assert strlen(fileread("`tmp_dir'/test_cohort_map.md")) > 0
    confirm file "`tmp_dir'/test_small_map.md"
    assert strlen(fileread("`tmp_dir'/test_small_map.md")) > 0
    assert !missing(r(nfiles))
    assert r(nfiles) == 2
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
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out_app.md")
    datamap, single("`tmp_dir'/test_small") output("`tmp_dir'/_out_app.md") append
    confirm file "`tmp_dir'/_out_app.md"
    assert !missing(r(nvars))
    assert r(nvars) == 2
    assert strlen(fileread("`tmp_dir'/_out_app.md")) > 0
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
        output("`tmp_dir'/_out_full.md") ///
        exclude(id) datesafe quality missing(detail) ///
        samples(3) autodetect maxcat(15) maxfreq(20)
    confirm file "`tmp_dir'/_out_full.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_out_full.md")) > 0
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
    datamap, single("`tmp_dir'/test_single") output("`tmp_dir'/_out_1obs.md")
    confirm file "`tmp_dir'/_out_1obs.md"
    assert !missing(r(nvars))
    assert r(nvars) == 1
    assert strlen(fileread("`tmp_dir'/_out_1obs.md")) > 0
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
    datamap, single("`tmp_dir'/test_small") output("`tmp_dir'/_out_5obs.md")
    confirm file "`tmp_dir'/_out_5obs.md"
    assert !missing(r(nvars))
    assert r(nvars) == 2
    assert strlen(fileread("`tmp_dir'/_out_5obs.md")) > 0
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

    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out_pres.md")

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

* Test: no input with data in memory (should succeed — documents in-memory data)
local ++test_count
capture noisily {
    sysuse auto, clear
    datamap, output("`tmp_dir'/_mem.md")
    confirm file "`tmp_dir'/_mem.md"
    assert "`r(input_source)'" == "memory"
}
if _rc == 0 {
    display as result "  PASS: datamap - in-memory data (no input)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - in-memory data (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_mem.md"

* Test: no input with no data in memory (should error)
local ++test_count
capture noisily {
    clear
    capture datamap, output("`tmp_dir'/_err.md")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap - error on no input, no data (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - error on no input, no data (error `=_rc')"
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
    assert _rc == 601
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
* datamap Markdown: Basic Functionality
* ============================================================

* Test: datamap single dataset
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_out.md")
    confirm file "`tmp_dir'/_dd_out.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_out.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - single dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - single dataset (error `=_rc')"
    local ++fail_count
}

* Test: datamap return values
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_rv.md")
    assert r(nfiles) == 1
    assert regexm("`r(output)'", "_dd_rv\.md")
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - return values r(nfiles) r(output)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - return values (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap Markdown: Metadata Options
* ============================================================

* Test: title
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_title.md") ///
        title("Custom Title")
    confirm file "`tmp_dir'/_dd_title.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_title.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_title.md", needle("# Custom Title") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - title()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - title() (error `=_rc')"
    local ++fail_count
}

* Test: subtitle
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_sub.md") ///
        title("Test") subtitle("A subtitle")
    confirm file "`tmp_dir'/_dd_sub.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_sub.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_sub.md", needle("# Test") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_sub.md", needle("A subtitle") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - subtitle()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - subtitle() (error `=_rc')"
    local ++fail_count
}

* Test: version
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_ver.md") ///
        version("1.0")
    confirm file "`tmp_dir'/_dd_ver.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_ver.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_ver.md", needle("Version 1.0") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_ver.md", needle("**Document Version:** 1.0") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - version()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - version() (error `=_rc')"
    local ++fail_count
}

* Test: author
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_auth.md") ///
        author("Test Author")
    confirm file "`tmp_dir'/_dd_auth.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_auth.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_auth.md", needle("**Author:** Test Author") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - author()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - author() (error `=_rc')"
    local ++fail_count
}

* Test: date
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_date.md") ///
        docdate("2026-01-01")
    confirm file "`tmp_dir'/_dd_date.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_date.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_date.md", needle("**Last Updated:** 2026-01-01") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - date()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - date() (error `=_rc')"
    local ++fail_count
}

* Test: notes
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_notes.md") ///
        notes("Test notes for the data dictionary.")
    confirm file "`tmp_dir'/_dd_notes.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_notes.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_notes.md", needle("## Notes") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_notes.md", needle("Test notes for the data dictionary.") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - notes()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - notes() (error `=_rc')"
    local ++fail_count
}

* Test: changelog
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_cl.md") ///
        changelog("v1.0: Initial release")
    confirm file "`tmp_dir'/_dd_cl.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_cl.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_cl.md", needle("## Change Log") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_cl.md", needle("v1.0: Initial release") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - changelog()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - changelog() (error `=_rc')"
    local ++fail_count
}

* Test: full metadata combination
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_fullmeta.md") ///
        title("MS Cohort") subtitle("Data Dictionary") ///
        version("2.0") author("Test Author") docdate("2026-01-01") ///
        notes("Comprehensive dataset.") changelog("v2.0: Added outcomes")
    confirm file "`tmp_dir'/_dd_fullmeta.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_fullmeta.md")) > 0
    qa_md_contains using "`tmp_dir'/_dd_fullmeta.md", needle("# MS Cohort") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_fullmeta.md", needle("Data Dictionary") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_fullmeta.md", needle("Version 2.0") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_fullmeta.md", needle("**Author:** Test Author") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_fullmeta.md", needle("**Last Updated:** 2026-01-01") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_fullmeta.md", needle("Comprehensive dataset.") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_fullmeta.md", needle("v2.0: Added outcomes") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - full metadata combination"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - full metadata (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap Markdown: Content Options
* ============================================================

* Test: missing column
* 2026-11-10: datadict's "missing" option is the default Missing column of
* datamap's table (the option itself is removed: rc 198, test_datamap_v200_removed).
* Oracle: count if missing(var) on the fixture.
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort_miss") output("`tmp_dir'/_dd_miss.md")
    confirm file "`tmp_dir'/_dd_miss.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    preserve
    quietly use "`tmp_dir'/test_cohort_miss.dta", clear
    foreach v in id age bmi region {
        quietly count if missing(`v')
        local nm_`v' = r(N)
        local pm_`v' = string(100 * r(N) / _N, "%4.1f")
    }
    restore
    foreach v in id age bmi region {
        qa_md_rows using "`tmp_dir'/_dd_miss.md", var(`v') miss("`nm_`v'' (`pm_`v''%)")
        assert r(n) == 1
    }
    assert `nm_age' == 10 & `nm_bmi' == 11 & `nm_region' == 6 & `nm_id' == 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - missing"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - missing (error `=_rc')"
    local ++fail_count
}

* Test: stats column
* 2026-11-10: datadict's "stats" option is the default Values/Statistics cell.
* Oracle: -summarize- on the fixture.
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_stats.md")
    confirm file "`tmp_dir'/_dd_stats.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    preserve
    quietly use "`tmp_dir'/test_cohort.dta", clear
    quietly summarize bmi, detail
    local bm = string(r(mean), "%9.2f")
    local bs = string(r(sd), "%9.2f")
    local bmed = string(r(p50), "%9.2f")
    restore
    qa_md_rows using "`tmp_dir'/_dd_stats.md", var(bmi)
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_stats.md", needle("`=char(96)'bmi`=char(96)' | Body mass index | double | 0 (0.0%) | N=100; mean=`bm'; SD=`bs'; median=`bmed';")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - stats"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - stats (error `=_rc')"
    local ++fail_count
}

* Test: missing + stats combined
* 2026-11-10: both are always on; the statistics are over the NONMISSING values
* (age: 90 of 100) while the Missing cell counts the 10 missing.
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort_miss") output("`tmp_dir'/_dd_both.md")
    confirm file "`tmp_dir'/_dd_both.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    preserve
    quietly use "`tmp_dir'/test_cohort_miss.dta", clear
    quietly summarize age
    assert r(N) == 90
    local am = string(r(mean), "%9.2f")
    local asd = string(r(sd), "%9.2f")
    restore
    qa_md_contains using "`tmp_dir'/_dd_both.md", needle("`=char(96)'age`=char(96)' | Age in years | double | 10 (10.0%) | N=90; mean=`am'; SD=`asd';")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - missing + stats combined"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - missing + stats (error `=_rc')"
    local ++fail_count
}

* Test: custom maxcat
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_mc.md") ///
        maxcat(10)
    confirm file "`tmp_dir'/_dd_mc.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_mc.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - maxcat(10)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - maxcat(10) (error `=_rc')"
    local ++fail_count
}

* Test: custom maxfreq
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_mf.md") ///
        maxfreq(5)
    confirm file "`tmp_dir'/_dd_mf.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_mf.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - maxfreq(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - maxfreq(5) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap Markdown: Multi-file and Directory Modes
* ============================================================

* Test: filelist mode
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/test_cohort" "`tmp_dir'/test_small") ///
        output("`tmp_dir'/_dd_fl.md")
    confirm file "`tmp_dir'/_dd_fl.md"
    assert r(nfiles) == 2
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - filelist mode (2 files)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - filelist mode (error `=_rc')"
    local ++fail_count
}

* Test: directory mode
local ++test_count
capture noisily {
    datamap, directory("`tmp_dir'") output("`tmp_dir'/_dd_dir.md")
    confirm file "`tmp_dir'/_dd_dir.md"
    * 5 top-level .dta files exist at this point: cohort(8v), cohort_miss(8v),
    * panel(4v), small(2v), single(1v) -- no subdirectory yet.
    assert !missing(r(nfiles))
    assert r(nfiles) == 5
    * r(nvars) is set for single()/memory runs only (2.0.0, as datamap 1.x):
    * the 23 variables of the five files are the Variables-table rows
    qa_md_rows using "`tmp_dir'/_dd_dir.md"
    assert r(n) == 23
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - directory mode"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - directory mode (error `=_rc')"
    local ++fail_count
}

* Test: directory with recursive
local ++test_count
capture noisily {
    capture mkdir "`tmp_dir'/_subdir2"
    use "`tmp_dir'/test_small.dta", clear
    save "`tmp_dir'/_subdir2/_sub.dta", replace

    datamap, directory("`tmp_dir'") recursive output("`tmp_dir'/_dd_rec.md")
    confirm file "`tmp_dir'/_dd_rec.md"
    * recursive must find the nested file too: 6 .dta files total by this
    * point (cohort=8, cohort_miss=8, panel=4, small=2, single=1, plus the
    * nested _subdir2/_sub.dta copy of small=2 vars) -> nvars_total sums
    * each file's own var count; r(nvars) exists only for single()/memory runs,
    * so the total is the number of Variables-table rows in the document.
    assert !missing(r(nfiles))
    assert r(nfiles) == 6
    qa_md_rows using "`tmp_dir'/_dd_rec.md"
    assert r(n) == 25
    assert strlen(fileread("`tmp_dir'/_dd_rec.md")) > 0

    capture erase "`tmp_dir'/_subdir2/_sub.dta"
    capture rmdir "`tmp_dir'/_subdir2"
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - directory + recursive"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - directory + recursive (error `=_rc')"
    local ++fail_count
    capture erase "`tmp_dir'/_subdir2/_sub.dta"
    capture rmdir "`tmp_dir'/_subdir2"
}

* Test: separate output files
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/test_cohort" "`tmp_dir'/test_small") ///
        output("`tmp_dir'/_dd_sep.md") separate
    local nf = r(nfiles)
    * separate creates <basename>_map.md in same directory as source dataset
    * (2.0.0: the default suffix is _map; datadict's was _dictionary)
    confirm file "`tmp_dir'/test_cohort_map.md"
    assert strlen(fileread("`tmp_dir'/test_cohort_map.md")) > 0
    confirm file "`tmp_dir'/test_small_map.md"
    assert strlen(fileread("`tmp_dir'/test_small_map.md")) > 0
    qa_md_rows using "`tmp_dir'/test_cohort_map.md"
    assert r(n) == 8
    qa_md_rows using "`tmp_dir'/test_small_map.md"
    assert r(n) == 2
    assert !missing(`nf')
    assert `nf' == 2
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - separate output files"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - separate output (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap Markdown: Data Preservation
* ============================================================

* Test: user data preserved after datamap
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    local k_before = c(k)
    datasignature
    local sig_before "`r(datasignature)'"

    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_dd_pres.md")

    assert _N == `N_before'
    assert c(k) == `k_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - data preservation (N, k, signature)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap Markdown: Error Handling
* ============================================================

* Test: no input with data in memory (should succeed — documents in-memory data)
local ++test_count
capture noisily {
    sysuse auto, clear
    datamap, output("`tmp_dir'/_dd_mem.md")
    confirm file "`tmp_dir'/_dd_mem.md"
    * `sysuse auto' carries 12 variables, not the 8 of the synthetic
    * test_cohort fixture used elsewhere in this file.
    assert !missing(r(nvars))
    assert r(nvars) == 12
    assert strlen(fileread("`tmp_dir'/_dd_mem.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - in-memory data (no input)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - in-memory data (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_dd_mem.md"

* Test: no input with no data in memory (should error)
local ++test_count
capture noisily {
    clear
    capture datamap, output("`tmp_dir'/_err.md")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - error on no input, no data (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - error on no input, no data (error `=_rc')"
    local ++fail_count
}

* Test: multiple input options
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/test_cohort") directory("`tmp_dir'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - error on multiple inputs (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - error on multiple inputs (error `=_rc')"
    local ++fail_count
}

* Test: invalid maxcat (zero)
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/test_cohort") maxcat(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - error on maxcat(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - error on maxcat(0) (error `=_rc')"
    local ++fail_count
}

* Test: nonexistent file
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/nonexistent_file")
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - error on nonexistent file"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - error on nonexistent file (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap Markdown: Full Comprehensive
* ============================================================

* Test: datamap with all options
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort_miss") ///
        output("`tmp_dir'/_dd_complete.md") ///
        title("Complete Test") subtitle("All Options") ///
        version("1.0") author("Test") docdate("2026-01-01") ///
        notes("Full test.") changelog("v1.0: Init") ///
        maxcat(15) maxfreq(20)
    confirm file "`tmp_dir'/_dd_complete.md"
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert strlen(fileread("`tmp_dir'/_dd_complete.md")) > 0
    * every document part is present once
    foreach t in "# Complete Test" "Version 1.0" "**Author:** Test" "**Last Updated:** 2026-01-01" ///
        "## Notes" "Full test." "## Change Log" "v1.0: Init" {
        qa_md_contains using "`tmp_dir'/_dd_complete.md", needle("`t'")
        assert !missing(r(n))
        assert r(n) >= 1
    }
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - full comprehensive"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - full comprehensive (error `=_rc')"
    local ++fail_count
}

* Test: datamap selected variables, custom columns, metadata saving, datasignature
local ++test_count
capture noisily {
    datamap age bmi, single("`tmp_dir'/test_cohort") ///
        output("`tmp_dir'/_dd_subset.md") ///
        columns(variable label type stats) ///
        saving("`tmp_dir'/_dd_subset_meta.dta", replace)
    * (2.0.0: the data signature is always printed; the datasignature option is gone)
    assert r(nfiles) == 1
    * r(nvars) counts the variables of the FILE (8); the document says "8 (2 documented)"
    assert r(nvars) == 8
    assert r(nobs) == 100
    assert "`r(mode)'" == "single"
    assert strpos("`r(metadata)'", "_dd_subset_meta.dta") > 0
    confirm file "`tmp_dir'/_dd_subset.md"
    qa_md_contains using "`tmp_dir'/_dd_subset.md", needle("- Data signature: ")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_subset.md", needle("| Variable | Label | Type | Values/Statistics |") exact
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_dd_subset.md"
    assert r(n) == 2
    qa_md_contains using "`tmp_dir'/_dd_subset.md", needle("- Variables: 8 (2 documented)") exact
    assert r(n) == 1
    confirm file "`tmp_dir'/_dd_subset_meta.dta"
    preserve
    use "`tmp_dir'/_dd_subset_meta.dta", clear
    assert _N == 2
    confirm variable source
    confirm variable output
    confirm variable mean
    restore
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - varlist columns() saving() datasignature and totals"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - v1.4 metadata export (error `=_rc')"
    local ++fail_count
}
* Clean up this test's own artifact AFTER the verdict is recorded: it is a .dta
* written into tmp_dir and the later directory-mode scans count every top-level
* .dta there. Placing a `capture' before the `if _rc' would reset _rc to 0 and
* turn every failure of this test into a silent pass.
capture erase "`tmp_dir'/_dd_subset_meta.dta"

* Test: datamap manifest with separate outdir and custom suffix
local ++test_count
capture noisily {
    file open ddmf using "`tmp_dir'/_dd_manifest.txt", write text replace
    file write ddmf "`tmp_dir'/test_cohort.dta" _n
    file write ddmf "`tmp_dir'/test_small.dta" _n
    file close ddmf

    datamap, manifest("`tmp_dir'/_dd_manifest.txt") separate ///
        outdir("`tmp_dir'") suffix("_dict")
    * r(nvars)/r(nobs) are single()/memory-run returns in 2.0.0 (datadict's
    * r(nvars_total)=10 and r(nobs_total)=105 have no successor): the same
    * totals are asserted from the two output documents.
    assert r(nfiles) == 2
    assert "`r(mode)'" == "manifest"
    assert strpos("`r(files)'", "test_cohort.dta") > 0
    assert strpos("`r(outputs)'", "test_cohort_dict.md") > 0
    confirm file "`tmp_dir'/test_cohort_dict.md"
    confirm file "`tmp_dir'/test_small_dict.md"
    qa_md_rows using "`tmp_dir'/test_cohort_dict.md"
    assert r(n) == 8
    qa_md_rows using "`tmp_dir'/test_small_dict.md"
    assert r(n) == 2
    qa_md_contains using "`tmp_dir'/test_cohort_dict.md", needle("- Observations: 100") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/test_small_dict.md", needle("- Observations: 5") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - manifest separate outdir() suffix()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - manifest/outdir/suffix (error `=_rc')"
    local ++fail_count
}

* Test: datamap config file defaults
local ++test_count
capture noisily {
    file open ddcfg using "`tmp_dir'/_dd_config.conf", write text replace
    file write ddcfg "title = Configured Dictionary" _n
    file write ddcfg "columns = variable label type" _n
    file write ddcfg "datasignature = yes" _n
    file close ddcfg

    datamap, single("`tmp_dir'/test_small") config("`tmp_dir'/_dd_config.conf") ///
        output("`tmp_dir'/_dd_config.md")
    confirm file "`tmp_dir'/_dd_config.md"
    assert "`r(mode)'" == "single"

    * (2.0.0: the data signature is always printed, so the datasignature key is
    * ignored and the line is "- Data signature:" rather than "**Data signature:**")
    qa_md_contains using "`tmp_dir'/_dd_config.md", needle("# Configured Dictionary") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_config.md", needle("| Variable | Label | Type |") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_config.md", needle("- Data signature: ")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - config() defaults"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - config() defaults (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# v1.0.7 Feature Tests
* ============================================================

**## Richer r() results — nobs, nvars, input_source (single-file mode)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/test_cohort") output("`tmp_dir'/_out_rr.md")
    assert !missing(r(nobs))
    assert r(nobs) == 100
    assert !missing(r(nvars))
    assert r(nvars) == 8
    assert "`r(input_source)'" == "single"
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - r(nobs), r(nvars), r(input_source) in single mode"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - richer r() results (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_out_rr.md"

**## r(input_source) for directory mode
local ++test_count
capture noisily {
    datamap, directory("`tmp_dir'") output("`tmp_dir'/_out_rdir.md")
    assert "`r(input_source)'" == "directory"
    * Both earlier recursive-mode tests clean up their own subdirectory, and
    * the datamap saving() test below erases its own _dd_subset_meta.dta, so
    * exactly the same 5 top-level .dta fixtures remain: cohort, cohort_miss,
    * panel, small, single.
    assert !missing(r(nfiles))
    assert r(nfiles) == 5
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - r(input_source) = directory"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - r(input_source) directory (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_out_rdir.md"

**## r(input_source) for filelist mode
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/test_cohort `tmp_dir'/test_small") output("`tmp_dir'/_out_rfl.md")
    assert "`r(input_source)'" == "filelist"
    assert r(nfiles) == 2
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - r(input_source) = filelist"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - r(input_source) filelist (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_out_rfl.md"

**## In-memory mode: data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    local k_before = c(k)
    datasignature
    local sig_before "`r(datasignature)'"

    datamap, output("`tmp_dir'/_mem_pres.md")

    assert _N == `N_before'
    assert c(k) == `k_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - in-memory data preservation (N, k, signature)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - in-memory data preservation (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_mem_pres.md"

**## In-memory mode: r(nobs) and r(nvars) match data
local ++test_count
capture noisily {
    sysuse auto, clear
    local expected_N = _N
    local expected_k = c(k)
    datamap, output("`tmp_dir'/_mem_rv.md")
    assert r(nobs) == `expected_N'
    assert r(nvars) == `expected_k'
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - in-memory r(nobs)=74 r(nvars)=12"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - in-memory r(nobs)/r(nvars) (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_mem_rv.md"

**## In-memory mode: exclude option works
* 2026-11-10: was "Classification: excluded" in the text layout; the excluded
* variable is a structure-only row in the Markdown table
local ++test_count
capture noisily {
    sysuse auto, clear
    datamap, output("`tmp_dir'/_mem_exc.md") exclude(make)
    confirm file "`tmp_dir'/_mem_exc.md"
    qa_md_rows using "`tmp_dir'/_mem_exc.md", var(make) cell("excluded (structure only)")
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_mem_exc.md"
    assert r(n) == 12
    * the excluded string's values (make names) appear nowhere
    qa_md_contains using "`tmp_dir'/_mem_exc.md", needle("Buick")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - in-memory with exclude()"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - in-memory with exclude() (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_mem_exc.md"

**## Compact variable table in output
* 2026-11-10 (datamap 2.0.0): the QUICK REFERENCE block (Variable/Type/Class/
* Miss/Unique) was the text layout's compact table and is removed (plan O2: the
* per-variable block repeated it).  Its successor is the one Variables table
* with the default columns Variable | Label | Type | Missing | Values/Statistics
* (Class and Unique are columns() choices, not defaults), one row per variable.
local ++test_count
capture noisily {
    sysuse auto, clear
    datamap, output("`tmp_dir'/_out_qr.md")
    confirm file "`tmp_dir'/_out_qr.md"
    qa_md_contains using "`tmp_dir'/_out_qr.md", needle("| Variable | Label | Type | Missing | Values/Statistics |") exact
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_out_qr.md"
    assert r(n) == 12
    * the removed block's heading must be gone
    qa_md_contains using "`tmp_dir'/_out_qr.md", needle("QUICK REFERENCE")
    assert r(n) == 0
    * columns() reaches the removed block's two columns
    datamap, output("`tmp_dir'/_out_qr2.md") columns(variable type class missing unique)
    qa_md_contains using "`tmp_dir'/_out_qr2.md", needle("| Variable | Type | Class | Missing | Unique |") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - variable table present (QUICK REFERENCE successor)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - variable table (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_out_qr.md"
capture erase "`tmp_dir'/_out_qr2.md"

**## strL variable handling
* 2026-11-10 (datamap 2.0.0): the strL note and the "Long string ... strL"
* guidance sentence are removed with the guidance prose (O2).  The strL fact
* is the Type column: "strL", and the string summary cell.
local ++test_count
capture noisily {
    clear
    set obs 10
    gen strL longtext = "This is a test string for strL variable handling " + string(_n)
    gen x = _n
    quietly save "`tmp_dir'/_test_strl.dta", replace
    datamap, single("`tmp_dir'/_test_strl") output("`tmp_dir'/_out_strl.md")
    confirm file "`tmp_dir'/_out_strl.md"
    qa_md_rows using "`tmp_dir'/_out_strl.md", var(longtext) cell("N=10; 10 distinct; max length 51") miss("0 (0.0%)")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_out_strl.md", needle("| `=char(96)'longtext`=char(96)' |  | strL |")
    assert r(n) == 1
    * the x variable (float) is not typed strL
    qa_md_contains using "`tmp_dir'/_out_strl.md", needle("| `=char(96)'x`=char(96)' |  | float |")
    assert r(n) == 1
    * no string value reaches the document (10 distinct strings, all counts 1)
    qa_md_contains using "`tmp_dir'/_out_strl.md", needle("This is a test string")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - strL variable handling (Type strL, string summary)"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - strL handling (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_test_strl.dta"
capture erase "`tmp_dir'/_out_strl.md"

**## Tab >32K fallback -- never "(too many)"
* -tabulate- used to abort at ~12k levels and the report said "(too many)".
* It must still never say that.  From 1.6.0 the count is CENSORED at
* uniqcap (default 1000) rather than sorted, so a 40,000-distinct variable
* reports ">1000"; uniqcap(0) asks for the exact count and gets 40000 back.
* 2026-11-10 (datamap 2.0.0): the count is the Unique column (columns(unique)),
* no longer a "Unique Values:" line of the text layout.
local ++test_count
capture noisily {
    clear
    set obs 40000
    gen double bigvar = _n + runiform()
    quietly save "`tmp_dir'/_test_bigvar.dta", replace
    * (a) default: censored, rendered as ">1000", never "(too many)"
    datamap, single("`tmp_dir'/_test_bigvar") output("`tmp_dir'/_out_bigvar.md") columns(variable type unique)
    confirm file "`tmp_dir'/_out_bigvar.md"
    qa_md_contains using "`tmp_dir'/_out_bigvar.md", needle("(too many)")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_out_bigvar.md", needle("| `=char(96)'bigvar`=char(96)' | double | >1000 |") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_out_bigvar.md", needle("1001")
    assert r(n) == 0
    * (b) uniqcap(0): exact count restored
    datamap, single("`tmp_dir'/_test_bigvar") output("`tmp_dir'/_out_bigvar0.md") uniqcap(0) columns(variable type unique)
    confirm file "`tmp_dir'/_out_bigvar0.md"
    qa_md_contains using "`tmp_dir'/_out_bigvar0.md", needle("| `=char(96)'bigvar`=char(96)' | double | 40000 |") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - tab >32K fallback (censored by default, exact under uniqcap(0))"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - tab >32K fallback (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_test_bigvar.dta"
capture erase "`tmp_dir'/_out_bigvar.md"
capture erase "`tmp_dir'/_out_bigvar0.md"

**## Contextual ANALYSIS GUIDANCE — skewed continuous variable
* 2026-11-10 (datamap 2.0.0): REMOVED FEATURE.  The ANALYSIS GUIDANCE prose
* ("Right-skewed distribution ... skewness=") is gone with the text layout
* (plan O2, option noguidance removed).  This test now pins the replacement
* fact and the removal: the summary cell carries the exact mean, SD and median
* (computed here with -summarize-), and the guidance sentence never appears.
local ++test_count
capture noisily {
    clear
    set seed 4242
    set obs 1000
    gen double skewed = exp(rnormal())
    quietly save "`tmp_dir'/_test_skewed.dta", replace
    quietly summarize skewed, detail
    local m  = string(r(mean), "%9.2f")
    local sd = string(r(sd), "%9.2f")
    local md = string(r(p50), "%9.2f")
    datamap, single("`tmp_dir'/_test_skewed") output("`tmp_dir'/_out_skewed.md")
    confirm file "`tmp_dir'/_out_skewed.md"
    qa_md_contains using "`tmp_dir'/_out_skewed.md", needle("N=1000; mean=`m'; SD=`sd'; median=`md';")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_out_skewed.md", needle("skewness")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_out_skewed.md", needle("Right-skewed")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - skewed variable: exact summary cell, no guidance prose"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - skewed variable summary (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_test_skewed.dta"
capture erase "`tmp_dir'/_out_skewed.md"

**## Contextual ANALYSIS GUIDANCE — high missing percentage
* 2026-11-10 (datamap 2.0.0): REMOVED FEATURE (the "verify missingness"
* guidance sentence).  Pinned instead: the Missing cell counts and shares the
* 30 missing of 100 exactly, the summary is over the 70 observed values, and
* no guidance sentence is printed.
local ++test_count
capture noisily {
    clear
    set obs 100
    gen x = _n
    replace x = . if _n > 70
    quietly save "`tmp_dir'/_test_highmiss.dta", replace
    datamap, single("`tmp_dir'/_test_highmiss") output("`tmp_dir'/_out_highmiss.md")
    confirm file "`tmp_dir'/_out_highmiss.md"
    qa_md_rows using "`tmp_dir'/_out_highmiss.md", var(x) miss("30 (30.0%)") cell("N=70; mean=35.50; SD=20.35; median=35.50; IQR=18.00-53.00; range=1.00-70.00")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_out_highmiss.md", needle("verify missingness")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - high missing%: exact Missing cell, no guidance prose"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - high missing% (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_test_highmiss.dta"
capture erase "`tmp_dir'/_out_highmiss.md"

**## Contextual ANALYSIS GUIDANCE — discrete integer continuous
* 2026-11-10 (datamap 2.0.0): REMOVED FEATURE (the "Discrete integer ...
* ordinal" guidance sentence).  Pinned instead: with maxcat(5) and ten distinct
* integer values the variable is summarised as continuous (statistics, no
* level list), and no guidance sentence is printed.
local ++test_count
capture noisily {
    clear
    set obs 100
    set seed 99
    gen score = int(runiform() * 10) + 1
    * Ensure maxcat is lower so this is classified as continuous
    quietly save "`tmp_dir'/_test_discrete.dta", replace
    quietly summarize score
    local m = string(r(mean), "%9.2f")
    datamap, single("`tmp_dir'/_test_discrete") maxcat(5) output("`tmp_dir'/_out_discrete.md")
    confirm file "`tmp_dir'/_out_discrete.md"
    qa_md_contains using "`tmp_dir'/_out_discrete.md", needle("N=100; mean=`m'; SD=")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_out_discrete.md", needle("ordinal")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - discrete integer with maxcat(5): continuous summary, no guidance prose"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - discrete integer detection (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_test_discrete.dta"
capture erase "`tmp_dir'/_out_discrete.md"

**## datamap — in-memory mode with metadata options
local ++test_count
capture noisily {
    sysuse auto, clear
    datamap, output("`tmp_dir'/_dd_mem_meta.md") title("Auto Dataset") author("Test")
    confirm file "`tmp_dir'/_dd_mem_meta.md"
    * Verify title and author appear in output
    qa_md_contains using "`tmp_dir'/_dd_mem_meta.md", needle("# Auto Dataset") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_dd_mem_meta.md", needle("**Author:** Test") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - in-memory mode with title/author"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - in-memory with metadata (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_dd_mem_meta.md"

**## datamap — in-memory data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    local k_before = c(k)
    datasignature
    local sig_before "`r(datasignature)'"

    datamap, output("`tmp_dir'/_dd_mem_pres.md")

    assert _N == `N_before'
    assert c(k) == `k_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - in-memory data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - in-memory data preservation (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_dd_mem_pres.md"

**## datamap — removed hardcoded default notes
local ++test_count
capture noisily {
    sysuse auto, clear
    datamap, output("`tmp_dir'/_dd_notes.md")
    confirm file "`tmp_dir'/_dd_notes.md"
    * Old hardcoded notes stay gone
    qa_md_contains using "`tmp_dir'/_dd_notes.md", needle("anonymous identifiers")
    assert r(n) == 0
    * 2026-11-10 (datamap 2.0.0): datadict 1.x printed a generic note ("All date
    * variables are displayed ...") when notes() was not given.  datamap prints no
    * default note: there is no Notes section, no Change Log and no footer
    * without the document options.
    qa_md_contains using "`tmp_dir'/_dd_notes.md", needle("All date variables are displayed")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_dd_notes.md", needle("## Notes")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_dd_notes.md", needle("## Change Log")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: datamap Markdown - no hardcoded default notes"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap Markdown - hardcoded notes check (error `=_rc')"
    local ++fail_count
}
capture erase "`tmp_dir'/_dd_notes.md"

**## Varabbrev restore on in-memory error path
local ++test_count
capture noisily {
    set varabbrev on
    clear
    capture datamap
    assert _rc == 198
    assert c(varabbrev) == "on"
    set varabbrev off
    clear
    capture datamap
    assert _rc == 198
    assert c(varabbrev) == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: datamap - varabbrev restored on in-memory error path"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - varabbrev restore on error (error `=_rc')"
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
local meta_files : dir "`tmp_dir'" files "_dd_*.dta"
foreach f of local meta_files {
    capture erase "`tmp_dir'/`f'"
}
local conf_files : dir "`tmp_dir'" files "_dd_*.conf"
foreach f of local conf_files {
    capture erase "`tmp_dir'/`f'"
}
capture erase "`tmp_dir'/_dd_manifest.txt"
capture erase "`tmp_dir'/test_cohort_map.md"
capture erase "`tmp_dir'/test_small_map.md"
capture erase "`tmp_dir'/test_cohort_dict.md"
capture erase "`tmp_dir'/test_small_dict.md"
capture erase "`qa_dir'/test_cohort_dictionary.md"
capture erase "`qa_dir'/test_small_dictionary.md"
local generated_files : dir "`tmp_dir'" files "*"
foreach f of local generated_files {
    capture erase "`tmp_dir'/`f'"
}
capture rmdir "`tmp_dir'"

* ============================================================
* Summary
* ============================================================

display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
display "RESULT: test_datamap tests=`test_count' pass=`pass_count' fail=`fail_count'"
exit 0
