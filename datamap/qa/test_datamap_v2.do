clear all
set more off
version 16.0

* test_datamap_v2.do - Expanded functional tests for datamap package
* Generated: 2026-03-21
* Tests: 60
* Covers: edge cases, option interactions, content verification,
*         varabbrev restore, stored results, data types, detect features
*
* 2026-11-10 (datamap 2.0.0): datadict, the text layout and r(format) are
* removed.  The output is Markdown (_v2_*.md); the content tests that read the
* text layout ("DISTRIBUTION:", "Frequencies:", "VALUE LABEL DEFINITIONS",
* "SAMPLE OBSERVATIONS", "DATA QUALITY FLAGS", "Earliest:") now assert the
* Markdown equivalents through _qa_md.do (Mata): a document line may end in a
* backtick, and the old macro line reader stopped with r(132) on it.  Removed
* sections are asserted ABSENT where their absence is the point (a skeleton
* run, nofreq, nolabels).  The datadict tests are ported to datamap (they
* passed vacuously after the removal: "capture datadict" is rc 199, and
* varabbrev is trivially unchanged).  Port rules are in test_datamap.do.

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
do "`qa_dir'/_qa_md.do"

* ============================================================
* Create Additional Test Datasets
* ============================================================

* Dataset: all missing values
clear
set obs 20
gen double x = .
gen double y = .
gen str10 s = ""
label data "All missing dataset"
save "`tmp_dir'/v2_allmiss.dta", replace

* Dataset: constant variable (zero variance)
clear
set obs 50
gen double constant_var = 42
gen byte binary_var = cond(_n <= 25, 0, 1)
label data "Constant variable dataset"
save "`tmp_dir'/v2_constant.dta", replace

* Dataset: special characters in strings
clear
set obs 10
gen str50 special = "normal text"
replace special = "pipe|character" in 2
replace special = "backtick`here" in 3
replace special = "<angle>brackets" in 4
replace special = "line1" + char(10) + "line2" in 5
replace special = "" in 6/8
gen double x = _n
label variable special "Variable with special chars"
save "`tmp_dir'/v2_special.dta", replace

* Dataset: very large and very small values
clear
set obs 20
gen double big_val = 1e12 + _n
gen double small_val = 1e-12 * _n
gen double neg_val = -999999 + _n
save "`tmp_dir'/v2_extreme.dta", replace

* Dataset: long variable name (32 chars)
clear
set obs 10
gen double abcdefghijklmnopqrstuvwxyz123456 = _n
label variable abcdefghijklmnopqrstuvwxyz123456 "32-char variable name"
save "`tmp_dir'/v2_longname.dta", replace

* Dataset: no labels at all
clear
set obs 30
* Seed: 271828
set seed 271828
gen double x = _n
gen double y = runiform()
gen str5 z = "a"
save "`tmp_dir'/v2_nolabels.dta", replace

* Dataset: single variable
clear
set obs 15
gen double onlyvar = _n * 3.14
save "`tmp_dir'/v2_singlevar.dta", replace

* Dataset: duplicates
clear
set obs 20
gen double id = mod(_n - 1, 5) + 1
gen double val = runiform()
save "`tmp_dir'/v2_dupes.dta", replace

* Dataset: multiple date formats
clear
set obs 30
gen double td_date = td(01jan2020) + _n
format td_date %td
gen double tc_datetime = tc(01jan2020 12:00:00) + _n * 3600000
format tc_datetime %tc
gen double tm_month = tm(2020m1) + _n
format tm_month %tm
label data "Multiple date format dataset"
save "`tmp_dir'/v2_dates.dta", replace

* Dataset: all numeric storage types
clear
set obs 50
gen byte b_var = mod(_n, 100)
gen int i_var = _n * 100
gen long l_var = _n * 100000
gen float f_var = runiform()
gen double d_var = _n * 1.23456789012345
label data "All numeric storage types"
save "`tmp_dir'/v2_numtypes.dta", replace

* Dataset: survey-like
clear
set obs 100
set seed 77777
gen double psu_id = 1 + int(10 * runiform())
gen double strata = 1 + int(3 * runiform())
gen double sampling_weight = 0.5 + 2 * runiform()
gen double outcome = runiform() > 0.3
gen double age = 25 + int(50 * runiform())
label data "Survey-like dataset"
save "`tmp_dir'/v2_survey.dta", replace

* Dataset: quality flags (age > 100)
clear
set obs 50
set seed 88888
gen double age = 20 + int(60 * runiform())
replace age = 115 in 1
replace age = -5 in 2
gen double pct_complete = runiform() * 100
replace pct_complete = 110 in 3
gen double n_visits = int(10 * runiform())
replace n_visits = -1 in 4
label data "Quality flag test dataset"
save "`tmp_dir'/v2_quality.dta", replace

* Dataset: survival-like
clear
set obs 80
set seed 99999
gen double patient_id = _n
gen double followup_time = 1 + int(100 * runiform())
gen byte event_status = runiform() > 0.7
gen double entry_date = td(01jan2015) + int(365 * runiform())
format entry_date %td
gen double exit_date = entry_date + followup_time
format exit_date %td
label data "Survival-like dataset"
save "`tmp_dir'/v2_survival.dta", replace

* ============================================================
* Edge Cases
* ============================================================

* Test: all-missing dataset
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_allmiss") output("`tmp_dir'/_v2_allmiss.md")
    confirm file "`tmp_dir'/_v2_allmiss.md"
    assert r(nfiles) == 1
    foreach v in x y s {
        qa_md_rows using "`tmp_dir'/_v2_allmiss.md", var(`v') cell("All missing") miss("20 (100.0%)")
        assert r(n) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: Edge - all-missing dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - all-missing dataset (error `=_rc')"
    local ++fail_count
}

* Test: constant variable (zero variance)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_const.md")
    confirm file "`tmp_dir'/_v2_const.md"
    assert !missing(r(nvars))
    assert r(nvars) == 2
    assert strlen(fileread("`tmp_dir'/_v2_const.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Edge - constant variable dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - constant variable dataset (error `=_rc')"
    local ++fail_count
}

* Test: special characters in strings
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_special") output("`tmp_dir'/_v2_special.md")
    confirm file "`tmp_dir'/_v2_special.md"
    assert !missing(r(nvars))
    assert r(nvars) == 2
    assert strlen(fileread("`tmp_dir'/_v2_special.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Edge - special characters in strings"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - special characters in strings (error `=_rc')"
    local ++fail_count
}

* Test: very large values
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_extreme") output("`tmp_dir'/_v2_extreme.md")
    confirm file "`tmp_dir'/_v2_extreme.md"
    assert !missing(r(nvars))
    assert r(nvars) == 3
    assert strlen(fileread("`tmp_dir'/_v2_extreme.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Edge - extreme numeric values (1e12, 1e-12)"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - extreme numeric values (error `=_rc')"
    local ++fail_count
}

* Test: 32-character variable name
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_longname") output("`tmp_dir'/_v2_longname.md")
    confirm file "`tmp_dir'/_v2_longname.md"
    * the full 32-character name is the row key, untruncated
    qa_md_rows using "`tmp_dir'/_v2_longname.md", var(abcdefghijklmnopqrstuvwxyz123456)
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Edge - 32-char variable name"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - 32-char variable name (error `=_rc')"
    local ++fail_count
}

* Test: no variable or data labels
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_nolabels") output("`tmp_dir'/_v2_nolabels.md")
    confirm file "`tmp_dir'/_v2_nolabels.md"
    assert !missing(r(nvars))
    assert r(nvars) == 3
    assert strlen(fileread("`tmp_dir'/_v2_nolabels.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Edge - no labels dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - no labels dataset (error `=_rc')"
    local ++fail_count
}

* Test: single variable dataset
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_singlevar") output("`tmp_dir'/_v2_singlevar.md")
    confirm file "`tmp_dir'/_v2_singlevar.md"
    assert !missing(r(nvars))
    assert r(nvars) == 1
    assert strlen(fileread("`tmp_dir'/_v2_singlevar.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Edge - single variable dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - single variable dataset (error `=_rc')"
    local ++fail_count
}

* Test: dataset with duplicate observations
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_dupes") output("`tmp_dir'/_v2_dupes.md")
    confirm file "`tmp_dir'/_v2_dupes.md"
    assert !missing(r(nvars))
    assert r(nvars) == 2
    assert strlen(fileread("`tmp_dir'/_v2_dupes.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Edge - duplicate observations"
    local ++pass_count
}
else {
    display as error "  FAIL: Edge - duplicate observations (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Data Types
* ============================================================

* Test: %tc datetime format
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_dates") output("`tmp_dir'/_v2_dates.md")
    confirm file "`tmp_dir'/_v2_dates.md"
    * the three date families keep their format in the Type column (double %td/%tc/%tm)
    * 2026-11-10 (2.0.0 Phase 3, U4): the Type column names the family too
    * ("double %td daily"); the format code each family keeps is unchanged
    qa_md_contains using "`tmp_dir'/_v2_dates.md", needle("| double %td daily | 0 (0.0%) | N=30; range 2020/01/02 to 2020/01/31 |")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_dates.md", needle("`=char(96)'tc_datetime`=char(96)' |  | double %tc datetime |")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_dates.md", needle("`=char(96)'tm_month`=char(96)' |  | double %tm monthly | 0 (0.0%) | N=30; range 2020m2 to 2022m7 |")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Types - %td, %tc, %tm date formats"
    local ++pass_count
}
else {
    display as error "  FAIL: Types - date formats (error `=_rc')"
    local ++fail_count
}

* Test: all numeric storage types (byte, int, long, float, double)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_numtypes") output("`tmp_dir'/_v2_numtypes.md")
    confirm file "`tmp_dir'/_v2_numtypes.md"
    * each variable row carries its own storage type in the Type column
    foreach pair in b_var:byte i_var:int l_var:long f_var:float d_var:double {
        local v = substr("`pair'", 1, strpos("`pair'", ":") - 1)
        local t = substr("`pair'", strpos("`pair'", ":") + 1, .)
        qa_md_contains using "`tmp_dir'/_v2_numtypes.md", needle("`=char(96)'`v'`=char(96)' |  | `t' | 0 (0.0%) | N=50;")
        assert r(n) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: Types - byte/int/long/float/double storage types"
    local ++pass_count
}
else {
    display as error "  FAIL: Types - numeric storage types (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Option Interactions
* ============================================================

* Test: nostats + nofreq + nolabels (skeleton output)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") nostats nofreq nolabels ///
        output("`tmp_dir'/_v2_skeleton.md")
    confirm file "`tmp_dir'/_v2_skeleton.md"
    * the skeleton: each row is its distinct count only (no statistics, no
    * level list, no label text)
    qa_md_rows using "`tmp_dir'/_v2_skeleton.md", var(constant_var) cell("1 distinct")
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_v2_skeleton.md", var(binary_var) cell("2 distinct")
    assert r(n) == 1
    foreach t in "mean=" "SD=" "median=" "(50.0%)" "(100.0%)" "Frequencies" "VALUE LABEL" "DISTRIBUTION" {
        qa_md_contains using "`tmp_dir'/_v2_skeleton.md", needle("`t'")
        assert r(n) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Options - nostats+nofreq+nolabels suppresses all detail"
    local ++pass_count
}
else {
    display as error "  FAIL: Options - skeleton output (error `=_rc')"
    local ++fail_count
}

* Test: maxcat(1) makes most vars continuous
local ++test_count
capture noisily {
    * v2_constant has constant_var (1 unique) and binary_var (2 unique)
    * maxcat(1) should make binary_var continuous, constant_var categorical
    datamap, single("`tmp_dir'/v2_constant") maxcat(1) ///
        output("`tmp_dir'/_v2_maxcat1.md")
    confirm file "`tmp_dir'/_v2_maxcat1.md"
    assert !missing(r(nvars))
    assert r(nvars) == 2
    assert strlen(fileread("`tmp_dir'/_v2_maxcat1.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Options - maxcat(1)"
    local ++pass_count
}
else {
    display as error "  FAIL: Options - maxcat(1) (error `=_rc')"
    local ++fail_count
}

* Test: samples(N) where N > _N (should not crash)
local ++test_count
capture noisily {
    * v2_singlevar has 15 obs, request 100 samples
    datamap, single("`tmp_dir'/v2_singlevar") samples(100) ///
        output("`tmp_dir'/_v2_oversample.md")
    confirm file "`tmp_dir'/_v2_oversample.md"
    assert !missing(r(nvars))
    assert r(nvars) == 1
    assert strlen(fileread("`tmp_dir'/_v2_oversample.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Options - samples(100) with 15-obs dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Options - samples > N (error `=_rc')"
    local ++fail_count
}

* Test: append mode with two different datasets
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_append.md")
    datamap, single("`tmp_dir'/v2_singlevar") output("`tmp_dir'/_v2_append.md") append
    confirm file "`tmp_dir'/_v2_append.md"
    * both datasets appear, each in its own section and with its own row
    qa_md_contains using "`tmp_dir'/_v2_append.md", needle("- Source: `=char(96)'`tmp_dir'/v2_constant.dta`=char(96)'")
    qa_md_rows using "`tmp_dir'/_v2_append.md", var(constant_var)
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_v2_append.md", var(onlyvar)
    assert r(n) == 1
    qa_md_rows using "`tmp_dir'/_v2_append.md"
    assert r(n) == 3
    * append adds a dataset section only (no second title block)
    qa_md_contains using "`tmp_dir'/_v2_append.md", needle("### Variables") exact
    assert r(n) == 2
}
if _rc == 0 {
    display as result "  PASS: Options - append mode with two datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: Options - append mode (error `=_rc')"
    local ++fail_count
}

* Test: exclude + samples (excluded vars masked)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_survey") exclude(psu_id strata) ///
        samples(3) output("`tmp_dir'/_v2_excl_samp.md")
    confirm file "`tmp_dir'/_v2_excl_samp.md"
    * the sample rows hold [MASKED] for exactly the two excluded columns: 3 rows x 2
    qa_md_contains using "`tmp_dir'/_v2_excl_samp.md", needle("### Sample rows") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_excl_samp.md", needle("| [MASKED] | [MASKED] | ")
    assert r(n) == 3
}
if _rc == 0 {
    display as result "  PASS: Options - exclude + samples (MASKED appears)"
    local ++pass_count
}
else {
    display as error "  FAIL: Options - exclude + samples (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: datesafe
* ============================================================

* Test: datesafe suppresses exact dates
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_dates") datesafe ///
        output("`tmp_dir'/_v2_datesafe.md")
    confirm file "`tmp_dir'/_v2_datesafe.md"
    * spans, never a date: no yyyy/mm/dd in the document, "date-safe on" in the disclosure
    qa_md_contains using "`tmp_dir'/_v2_datesafe.md", needle("(exact dates withheld)")
    assert r(n) == 3
    qa_md_contains using "`tmp_dir'/_v2_datesafe.md", needle("date-safe on")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_datesafe.md", needle("2020/")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_v2_datesafe.md", needle(" to 20")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: Content - datesafe suppresses exact dates"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - datesafe (error `=_rc')"
    local ++fail_count
}

* Test: without datesafe, exact dates appear
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_dates") output("`tmp_dir'/_v2_dateexact.md")
    qa_md_contains using "`tmp_dir'/_v2_dateexact.md", needle("N=30; range 2020/01/02 to 2020/01/31")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_dateexact.md", needle("date-safe off")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_dateexact.md", needle("withheld")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: Content - exact dates appear without datesafe"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - exact dates without datesafe (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: nofreq
* ============================================================

* Test: nofreq suppresses frequency tables
local ++test_count
capture noisily {
    * Use a dataset with categorical vars
    clear
    set obs 30
    gen byte grp = mod(_n, 3) + 1
    label define grplbl 1 "A" 2 "B" 3 "C"
    label values grp grplbl
    save "`tmp_dir'/v2_cattest.dta", replace
    datamap, single("`tmp_dir'/v2_cattest") nofreq ///
        output("`tmp_dir'/_v2_nofreq.md")
    * no level list (no "A:" / "(33.3%)"), only the distinct count
    qa_md_rows using "`tmp_dir'/_v2_nofreq.md", var(grp) cell("3 distinct")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_nofreq.md", needle("(33.3%)")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: Content - nofreq suppresses Frequencies section"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - nofreq (error `=_rc')"
    local ++fail_count
}

* Test: without nofreq, frequencies appear for categorical
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_cattest") ///
        output("`tmp_dir'/_v2_withfreq.md")
    qa_md_rows using "`tmp_dir'/_v2_withfreq.md", var(grp) cell("1 A: 10 (33.3%)<br>2 B: 10 (33.3%)<br>3 C: 10 (33.3%)")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Content - frequencies appear without nofreq"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - frequencies without nofreq (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: nolabels
* ============================================================

* Test: nolabels suppresses VALUE LABEL DEFINITIONS section
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_cattest") nolabels ///
        output("`tmp_dir'/_v2_nolabels.md")
    * 2.0.0: there is no separate label section; nolabels removes the label
    * text from the level cells (the values and counts stay)
    qa_md_rows using "`tmp_dir'/_v2_nolabels.md", var(grp) cell("1: 10 (33.3%)<br>2: 10 (33.3%)<br>3: 10 (33.3%)")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_nolabels.md", needle("VALUE LABEL DEFINITIONS")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: Content - nolabels suppresses VALUE LABEL section"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - nolabels (error `=_rc')"
    local ++fail_count
}

* Test: without nolabels, VALUE LABEL DEFINITIONS appears
local ++test_count
capture noisily {
    * (2.0.0: no separate section; the labels are inline beside each level)
    datamap, single("`tmp_dir'/v2_cattest") ///
        output("`tmp_dir'/_v2_withlabels.md")
    qa_md_contains using "`tmp_dir'/_v2_withlabels.md", needle("1 A: 10 (33.3%)")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_withlabels.md", needle("VALUE LABEL DEFINITIONS")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: Content - VALUE LABEL section appears by default"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - VALUE LABEL section default (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: samples
* ============================================================

* Test: samples section appears
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") samples(3) ///
        output("`tmp_dir'/_v2_samples.md")
    qa_md_contains using "`tmp_dir'/_v2_samples.md", needle("### Sample rows") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_samples.md", needle("First 3 rows")
    assert r(n) == 1
    * three data rows, as in the fixture (constant_var 42, binary_var 0)
    qa_md_contains using "`tmp_dir'/_v2_samples.md", needle("| 42 | 0 |") exact
    assert r(n) == 3
}
if _rc == 0 {
    display as result "  PASS: Content - samples(3) creates SAMPLE OBSERVATIONS section"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - samples section (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: quality flags
* ============================================================

* Test: quality flags triggered by negative age
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_quality") quality ///
        output("`tmp_dir'/_v2_qflags.md")
    qa_md_contains using "`tmp_dir'/_v2_qflags.md", needle("### Flags") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_qflags.md", needle("- `=char(96)'age`=char(96)': negative age values") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_qflags.md", needle("negative count")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Content - quality flags triggered"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - quality flags (error `=_rc')"
    local ++fail_count
}

* Test: quality2(strict) flags age > 100
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_quality") quality2(strict) ///
        output("`tmp_dir'/_v2_qstrict.md")
    qa_md_contains using "`tmp_dir'/_v2_qstrict.md", needle("### Flags") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_qstrict.md", needle("negative age values")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Content - quality2(strict) flags age >100"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - quality2(strict) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: detect(survey)
* ============================================================

* Test: detect(survey) produces Survey Design section
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_survey") detect(survey) ///
        output("`tmp_dir'/_v2_survey.md")
    * 2026-11-10 (2.0.0 Phase 3, F2): detect() output is labelled inferred;
    * declared settings print in the dataset header
    qa_md_contains using "`tmp_dir'/_v2_survey.md", needle("### Structure (inferred)") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_survey.md", needle("- Survey clusters `=char(96)'psu_id`=char(96)': 10 primary sampling units") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_survey.md", needle("- Survey strata `=char(96)'strata`=char(96)': 3 strata") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_survey.md", needle("- Survey weight `=char(96)'sampling_weight`=char(96)':")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Content - detect(survey) finds survey design"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - detect(survey) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: detect(panel) auto-detection
* ============================================================

* Test: detect(panel) without panelid auto-detects id variable
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_survival") detect(panel) ///
        output("`tmp_dir'/_v2_paneldet.md")
    confirm file "`tmp_dir'/_v2_paneldet.md"
    assert !missing(r(nvars))
    assert r(nvars) == 5
    assert strlen(fileread("`tmp_dir'/_v2_paneldet.md")) > 0

    * patient_id should be detected but it's unique per obs (no panel),
    * so panel structure may not be reported — just verify no crash
}
if _rc == 0 {
    display as result "  PASS: Content - detect(panel) without panelid"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - detect(panel) auto (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: detect(binary)
* ============================================================

* Test: detect(binary) identifies binary variables
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") detect(binary) ///
        output("`tmp_dir'/_v2_binary.md")
    qa_md_contains using "`tmp_dir'/_v2_binary.md", needle("- Binary (two distinct values): `=char(96)'binary_var`=char(96)'") exact
    assert r(n) == 1
    * constant_var has one value: not binary
    qa_md_contains using "`tmp_dir'/_v2_binary.md", needle("constant_var`=char(96)', ")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: Content - detect(binary) identifies binary vars"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - detect(binary) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: detect(survival)
* ============================================================

* Test: detect(survival) identifies survival variables
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_survival") detect(survival) ///
        output("`tmp_dir'/_v2_survdet.md")
    qa_md_contains using "`tmp_dir'/_v2_survdet.md", needle("- Survival time variables: `=char(96)'followup_time`=char(96)'") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_survdet.md", needle("- Survival event indicators: `=char(96)'event_status`=char(96)'") exact
    assert r(n) == 1
    * 2026-11-10 (2.0.0 Phase 3): the rate names its denominator, the
    * indicator's nonmissing values (the document's shares are of N)
    qa_md_contains using "`tmp_dir'/_v2_survdet.md", needle("  - `=char(96)'event_status`=char(96)' rate: 27.5% of nonmissing values") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Content - detect(survival) finds survival vars"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - detect(survival) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: multiple detect options
* ============================================================

* Test: detect(panel binary survival) combined
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_survival") detect(panel binary survival) ///
        output("`tmp_dir'/_v2_multidet.md")
    confirm file "`tmp_dir'/_v2_multidet.md"
    assert !missing(r(nvars))
    assert r(nvars) == 5
    assert strlen(fileread("`tmp_dir'/_v2_multidet.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Content - detect(panel binary survival) combined"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - multiple detect options (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Content Verification: missing(detail) and missing(pattern)
* ============================================================

* Test: missing(detail) with dataset that has missing data
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_allmiss") missing(detail) ///
        output("`tmp_dir'/_v2_missdet.md")
    qa_md_contains using "`tmp_dir'/_v2_missdet.md", needle("### Missingness") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_missdet.md", needle("- Variables more than 50% missing: 3 (`=char(96)'x`=char(96)', `=char(96)'y`=char(96)', `=char(96)'s`=char(96)')") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_missdet.md", needle("- Complete rows: 0 (0.0%)") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Content - missing(detail) reports summary"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - missing(detail) (error `=_rc')"
    local ++fail_count
}

* Test: missing(pattern)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_allmiss") missing(pattern) ///
        output("`tmp_dir'/_v2_misspat.md")
    confirm file "`tmp_dir'/_v2_misspat.md"
    assert !missing(r(nvars))
    assert r(nvars) == 3
    * one pattern, all three variables missing in all 20 rows
    qa_md_contains using "`tmp_dir'/_v2_misspat.md", needle("1 distinct")
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_misspat.md", needle("  - `=char(96)'...`=char(96)': 20 (100.0%)") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Content - missing(pattern) runs"
    local ++pass_count
}
else {
    display as error "  FAIL: Content - missing(pattern) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Varabbrev Restoration
* ============================================================

* Test: varabbrev restored after successful run
local ++test_count
capture noisily {
    set varabbrev off
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_va1.md")
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: Varabbrev - restored to off after success"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev - restore after success (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}

* Test: varabbrev restored after error
local ++test_count
capture noisily {
    set varabbrev off
    capture datamap, single("`tmp_dir'/nonexistent_v2_file")
    * Should have errored, but varabbrev should still be off
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: Varabbrev - restored to off after error"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev - restore after error (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}

* Test: varabbrev on stays on after successful run
local ++test_count
capture noisily {
    set varabbrev on
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_va3.md")
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: Varabbrev - restored to on after success"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev - on restore after success (error `=_rc')"
    local ++fail_count
}

* Test: datamap varabbrev restored after success
local ++test_count
capture noisily {
    set varabbrev off
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_dd_va.md")
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: Varabbrev - datamap restored to off after success"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev - datamap restore (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}

* Test: datamap varabbrev restored after error
local ++test_count
capture noisily {
    set varabbrev off
    capture datamap, single("`tmp_dir'/nonexistent_v2_file")
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: Varabbrev - datamap restored to off after error"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev - datamap restore after error (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}

* ============================================================
* Stored Results
* ============================================================

* Test: r(nfiles) is numeric scalar
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_sr1.md")
    local nf = r(nfiles)
    assert `nf' == 1
    assert "`nf'" != ""
}
if _rc == 0 {
    display as result "  PASS: Stored - r(nfiles) is numeric == 1"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored - r(nfiles) (error `=_rc')"
    local ++fail_count
}

* Test: r(format) is gone (2.0.0)
local ++test_count
capture noisily {
    * 2.0.0: r(format) was removed with the text layout; it must be unset
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_sr2.md")
    assert "`r(format)'" == ""
}
if _rc == 0 {
    display as result "  PASS: Stored - r(format) unset (removed in 2.0.0)"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored - r(format) (error `=_rc')"
    local ++fail_count
}

* Test: r(output) matches provided filename
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_sr3.md")
    assert regexm("`r(output)'", "_v2_sr3\.md")
}
if _rc == 0 {
    display as result "  PASS: Stored - r(output) matches filename"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored - r(output) (error `=_rc')"
    local ++fail_count
}

* Test: r(nfiles) == 3 with filelist of 3 datasets
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/v2_constant" "`tmp_dir'/v2_singlevar" "`tmp_dir'/v2_dupes") ///
        output("`tmp_dir'/_v2_sr4.md")
    assert r(nfiles) == 3
}
if _rc == 0 {
    display as result "  PASS: Stored - r(nfiles) == 3 with 3-file filelist"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored - r(nfiles) 3-file (error `=_rc')"
    local ++fail_count
}

* Test: datamap r(nfiles) and r(output)
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_dd_sr.md")
    assert r(nfiles) == 1
    assert regexm("`r(output)'", "_v2_dd_sr\.md")
}
if _rc == 0 {
    display as result "  PASS: Stored - datamap r(nfiles) and r(output)"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored - datamap return values (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Error Handling (additional)
* ============================================================

* Test: invalid detect option
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/v2_constant") detect(bogus)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - invalid detect option (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - invalid detect option (error `=_rc')"
    local ++fail_count
}

* Test: invalid quality2 value
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/v2_constant") quality2(bogus)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - invalid quality2 value (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - invalid quality2 value (error `=_rc')"
    local ++fail_count
}

* Test: invalid missing value
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/v2_constant") missing(bogus)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - invalid missing option (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - invalid missing option (error `=_rc')"
    local ++fail_count
}

* Test: negative samples
local ++test_count
capture noisily {
    capture datamap, single("`tmp_dir'/v2_constant") samples(-1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - negative samples (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - negative samples (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Data Preservation
* ============================================================

* Test: datamap preserves current data
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    local k_before = c(k)
    datasignature
    local sig_before "`r(datasignature)'"

    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_pres.md")

    assert _N == `N_before'
    assert c(k) == `k_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: Preservation - datamap preserves user data"
    local ++pass_count
}
else {
    display as error "  FAIL: Preservation - datamap (error `=_rc')"
    local ++fail_count
}

* Test: datamap preserves current data
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    datasignature
    local sig_before "`r(datasignature)'"

    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_dd_pres.md")

    assert _N == `N_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: Preservation - datamap preserves user data"
    local ++pass_count
}
else {
    display as error "  FAIL: Preservation - datamap (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datamap: Additional Options (was datadict)
* ============================================================

* Test: datamap with missing + stats on all-missing data
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_allmiss") ///
        output("`tmp_dir'/_v2_dd_miss.md")
    confirm file "`tmp_dir'/_v2_dd_miss.md"
    assert !missing(r(nvars))
    assert r(nvars) == 3
    assert strlen(fileread("`tmp_dir'/_v2_dd_miss.md")) > 0
    * the Missing column and the all-missing cell (datadict needed missing/stats for these)
    qa_md_rows using "`tmp_dir'/_v2_dd_miss.md", var(x) cell("All missing") miss("20 (100.0%)")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap - missing+stats on all-missing dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - missing+stats all-missing (error `=_rc')"
    local ++fail_count
}

* Test: datamap with special chars in title
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") ///
        output("`tmp_dir'/_v2_dd_special.md") ///
        title("Title with <angle> & 'quotes'")
    confirm file "`tmp_dir'/_v2_dd_special.md"
    assert !missing(r(nvars))
    assert r(nvars) == 2
    assert strlen(fileread("`tmp_dir'/_v2_dd_special.md")) > 0
    * the title is escaped, never raw HTML: "<angle>" cannot reach the file as a tag
    qa_md_contains using "`tmp_dir'/_v2_dd_special.md", needle("<angle>")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_v2_dd_special.md", needle("# Title with &lt;angle&gt;")
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: datamap - special chars in title"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - special chars in title (error `=_rc')"
    local ++fail_count
}

* Test: datamap separate mode
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/v2_constant" "`tmp_dir'/v2_singlevar") ///
        separate
    local nf = r(nfiles)
    * separate creates <basename>_map.md next to each dataset (2.0.0 suffix; datadict's
    * was _dictionary).  The basename is derived from the full path without .dta
    confirm file "`tmp_dir'/v2_constant_map.md"
    assert strlen(fileread("`tmp_dir'/v2_constant_map.md")) > 0
    confirm file "`tmp_dir'/v2_singlevar_map.md"
    assert strlen(fileread("`tmp_dir'/v2_singlevar_map.md")) > 0
    qa_md_rows using "`tmp_dir'/v2_constant_map.md"
    assert r(n) == 2
    qa_md_rows using "`tmp_dir'/v2_singlevar_map.md"
    assert r(n) == 1
    assert !missing(`nf')
    assert `nf' == 2
}
if _rc == 0 {
    display as result "  PASS: datamap - separate mode creates individual files"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - separate mode (error `=_rc')"
    local ++fail_count
}

* Test: datamap filelist with 3 files
local ++test_count
capture noisily {
    datamap, filelist("`tmp_dir'/v2_constant" "`tmp_dir'/v2_singlevar" "`tmp_dir'/v2_dupes") ///
        output("`tmp_dir'/_v2_dd_3files.md")
    assert r(nfiles) == 3
}
if _rc == 0 {
    display as result "  PASS: datamap - filelist with 3 files"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap - filelist 3 files (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Datamap: datesafe + detect(survival) interaction
* ============================================================

local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_survival") datesafe detect(survival) ///
        output("`tmp_dir'/_v2_ds_surv.md")
    confirm file "`tmp_dir'/_v2_ds_surv.md"
    * Should suppress exact dates but still detect survival vars
    qa_md_contains using "`tmp_dir'/_v2_ds_surv.md", needle("(exact dates withheld)")
    assert r(n) == 2
    qa_md_contains using "`tmp_dir'/_v2_ds_surv.md", needle("2015/")
    assert r(n) == 0
    qa_md_contains using "`tmp_dir'/_v2_ds_surv.md", needle("- Survival time variables: `=char(96)'followup_time`=char(96)'") exact
    assert r(n) == 1
    qa_md_contains using "`tmp_dir'/_v2_ds_surv.md", needle("- Survival event indicators: `=char(96)'event_status`=char(96)'") exact
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: Interaction - datesafe + detect(survival)"
    local ++pass_count
}
else {
    display as error "  FAIL: Interaction - datesafe + detect(survival) (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Package Installation Verification
* ============================================================

* Test: which datamap and its Markdown renderer are discoverable
* 2.0.0 (2026-11-10): datadict is removed (test_datamap_errors asserts it is
* unrecognized, rc 199); its Markdown writer is _datamap_md_document
local ++test_count
* stata-dev-ignore: rc-only-test — installation probe: whether each command resolves on the adopath IS the whole content under test; `which' produces nothing else to assert
capture noisily {
    which datamap
    which _datamap_md_document
}
if _rc == 0 {
    display as result "  PASS: Install - which datamap and _datamap_md_document succeed"
    local ++pass_count
}
else {
    display as error "  FAIL: Install - which discovery (error `=_rc')"
    local ++fail_count
}

* ============================================================
* All-missing dataset with all options
* ============================================================

* Test: all-missing dataset with full options
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_allmiss") ///
        output("`tmp_dir'/_v2_allmiss_full.md") ///
        quality missing(detail) samples(3) autodetect
    confirm file "`tmp_dir'/_v2_allmiss_full.md"
    assert !missing(r(nvars))
    assert r(nvars) == 3
    assert strlen(fileread("`tmp_dir'/_v2_allmiss_full.md")) > 0
}
if _rc == 0 {
    display as result "  PASS: Comprehensive - all-missing with full options"
    local ++pass_count
}
else {
    display as error "  FAIL: Comprehensive - all-missing full (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

local v2_md : dir "`tmp_dir'" files "_v2_*.md"
foreach f of local v2_md {
    capture erase "`tmp_dir'/`f'"
}
capture erase "`tmp_dir'/v2_constant_map.md"
capture erase "`tmp_dir'/v2_singlevar_map.md"

* Clean up test datasets
capture erase "`tmp_dir'/v2_allmiss.dta"
capture erase "`tmp_dir'/v2_constant.dta"
capture erase "`tmp_dir'/v2_special.dta"
capture erase "`tmp_dir'/v2_extreme.dta"
capture erase "`tmp_dir'/v2_longname.dta"
capture erase "`tmp_dir'/v2_nolabels.dta"
capture erase "`tmp_dir'/v2_singlevar.dta"
capture erase "`tmp_dir'/v2_dupes.dta"
capture erase "`tmp_dir'/v2_dates.dta"
capture erase "`tmp_dir'/v2_numtypes.dta"
capture erase "`tmp_dir'/v2_survey.dta"
capture erase "`tmp_dir'/v2_quality.dta"
capture erase "`tmp_dir'/v2_survival.dta"
capture erase "`tmp_dir'/v2_cattest.dta"

* ============================================================
* Summary
* ============================================================

display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
}
else {
    display as result "ALL TESTS PASSED"
}
display "RESULT: test_datamap_v2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
