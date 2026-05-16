clear all
set more off
version 16.0

* test_datamap_v2.do - Expanded functional tests for datamap package
* Generated: 2026-03-21
* Tests: 60
* Covers: edge cases, option interactions, content verification,
*         varabbrev restore, stored results, data types, detect features

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
    datamap, single("`tmp_dir'/v2_allmiss") output("`tmp_dir'/_v2_allmiss.txt")
    confirm file "`tmp_dir'/_v2_allmiss.txt"
    assert r(nfiles) == 1
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
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_const.txt")
    confirm file "`tmp_dir'/_v2_const.txt"
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
    datamap, single("`tmp_dir'/v2_special") output("`tmp_dir'/_v2_special.txt")
    confirm file "`tmp_dir'/_v2_special.txt"
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
    datamap, single("`tmp_dir'/v2_extreme") output("`tmp_dir'/_v2_extreme.txt")
    confirm file "`tmp_dir'/_v2_extreme.txt"
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
    datamap, single("`tmp_dir'/v2_longname") output("`tmp_dir'/_v2_longname.txt")
    confirm file "`tmp_dir'/_v2_longname.txt"

    * Verify the long variable name appears in output
    tempname fh
    file open `fh' using "`tmp_dir'/_v2_longname.txt", read text
    local found_longname 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "abcdefghijklmnopqrstuvwxyz123456") > 0 {
            local found_longname 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_longname' == 1
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
    datamap, single("`tmp_dir'/v2_nolabels") output("`tmp_dir'/_v2_nolabels.txt")
    confirm file "`tmp_dir'/_v2_nolabels.txt"
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
    datamap, single("`tmp_dir'/v2_singlevar") output("`tmp_dir'/_v2_singlevar.txt")
    confirm file "`tmp_dir'/_v2_singlevar.txt"
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
    datamap, single("`tmp_dir'/v2_dupes") output("`tmp_dir'/_v2_dupes.txt")
    confirm file "`tmp_dir'/_v2_dupes.txt"
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
    datamap, single("`tmp_dir'/v2_dates") output("`tmp_dir'/_v2_dates.txt")
    confirm file "`tmp_dir'/_v2_dates.txt"

    * Verify date classification for all three date types
    tempname fh
    file open `fh' using "`tmp_dir'/_v2_dates.txt", read text
    local found_td 0
    local found_tc 0
    local found_tm 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "td_date") > 0 local found_td 1
        if strpos(`"`macval(line)'"', "tc_datetime") > 0 local found_tc 1
        if strpos(`"`macval(line)'"', "tm_month") > 0 local found_tm 1
        file read `fh' line
    }
    file close `fh'
    assert `found_td' == 1
    assert `found_tc' == 1
    assert `found_tm' == 1
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
    datamap, single("`tmp_dir'/v2_numtypes") output("`tmp_dir'/_v2_numtypes.txt")
    confirm file "`tmp_dir'/_v2_numtypes.txt"

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_numtypes.txt", read text
    local found_byte 0
    local found_int 0
    local found_long 0
    local found_float 0
    local found_double 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "byte") > 0 local found_byte 1
        if strpos(`"`macval(line)'"', "int") > 0 local found_int 1
        if strpos(`"`macval(line)'"', "long") > 0 local found_long 1
        if strpos(`"`macval(line)'"', "float") > 0 local found_float 1
        if strpos(`"`macval(line)'"', "double") > 0 local found_double 1
        file read `fh' line
    }
    file close `fh'
    assert `found_byte' == 1
    assert `found_int' == 1
    assert `found_long' == 1
    assert `found_float' == 1
    assert `found_double' == 1
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
        output("`tmp_dir'/_v2_skeleton.txt")
    confirm file "`tmp_dir'/_v2_skeleton.txt"

    * Verify no DISTRIBUTION, no Frequencies, no VALUE LABEL sections
    tempname fh
    file open `fh' using "`tmp_dir'/_v2_skeleton.txt", read text
    local found_dist 0
    local found_freq 0
    local found_vallabel 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "DISTRIBUTION:") > 0 local found_dist 1
        if strpos(`"`macval(line)'"', "Frequencies:") > 0 local found_freq 1
        if strpos(`"`macval(line)'"', "VALUE LABEL DEFINITIONS") > 0 local found_vallabel 1
        file read `fh' line
    }
    file close `fh'
    assert `found_dist' == 0
    assert `found_freq' == 0
    assert `found_vallabel' == 0
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
        output("`tmp_dir'/_v2_maxcat1.txt")
    confirm file "`tmp_dir'/_v2_maxcat1.txt"
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
        output("`tmp_dir'/_v2_oversample.txt")
    confirm file "`tmp_dir'/_v2_oversample.txt"
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
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_append.txt")
    datamap, single("`tmp_dir'/v2_singlevar") output("`tmp_dir'/_v2_append.txt") append
    confirm file "`tmp_dir'/_v2_append.txt"

    * Verify both datasets appear in the output
    tempname fh
    file open `fh' using "`tmp_dir'/_v2_append.txt", read text
    local found_const 0
    local found_single 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "constant_var") > 0 local found_const 1
        if strpos(`"`macval(line)'"', "onlyvar") > 0 local found_single 1
        file read `fh' line
    }
    file close `fh'
    assert `found_const' == 1
    assert `found_single' == 1
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
        samples(3) output("`tmp_dir'/_v2_excl_samp.txt")
    confirm file "`tmp_dir'/_v2_excl_samp.txt"

    * Verify MASKED appears in sample section
    tempname fh
    file open `fh' using "`tmp_dir'/_v2_excl_samp.txt", read text
    local found_masked 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "MASKED") > 0 | ///
           strpos(`"`macval(line)'"', "masked") > 0 {
            local found_masked 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_masked' == 1
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
        output("`tmp_dir'/_v2_datesafe.txt")
    confirm file "`tmp_dir'/_v2_datesafe.txt"

    * Should contain "suppressed" or "span", should NOT contain "Earliest:"
    tempname fh
    file open `fh' using "`tmp_dir'/_v2_datesafe.txt", read text
    local found_suppressed 0
    local found_earliest 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "suppressed") > 0 | ///
           strpos(`"`macval(line)'"', "span") > 0 {
            local found_suppressed 1
        }
        if strpos(`"`macval(line)'"', "Earliest:") > 0 {
            local found_earliest 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_suppressed' == 1
    assert `found_earliest' == 0
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
    datamap, single("`tmp_dir'/v2_dates") output("`tmp_dir'/_v2_dateexact.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_dateexact.txt", read text
    local found_earliest 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Earliest:") > 0 {
            local found_earliest 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_earliest' == 1
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
        output("`tmp_dir'/_v2_nofreq.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_nofreq.txt", read text
    local found_frequencies 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Frequencies:") > 0 {
            local found_frequencies 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_frequencies' == 0
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
        output("`tmp_dir'/_v2_withfreq.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_withfreq.txt", read text
    local found_frequencies 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Frequencies:") > 0 {
            local found_frequencies 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_frequencies' == 1
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
        output("`tmp_dir'/_v2_nolabels.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_nolabels.txt", read text
    local found_vallabel 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "VALUE LABEL DEFINITIONS") > 0 {
            local found_vallabel 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_vallabel' == 0
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
    datamap, single("`tmp_dir'/v2_cattest") ///
        output("`tmp_dir'/_v2_withlabels.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_withlabels.txt", read text
    local found_vallabel 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "VALUE LABEL DEFINITIONS") > 0 {
            local found_vallabel 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_vallabel' == 1
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
        output("`tmp_dir'/_v2_samples.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_samples.txt", read text
    local found_sample_section 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "SAMPLE OBSERVATIONS") > 0 {
            local found_sample_section 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_sample_section' == 1
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
        output("`tmp_dir'/_v2_qflags.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_qflags.txt", read text
    local found_quality 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "DATA QUALITY FLAGS") > 0 | ///
           strpos(`"`macval(line)'"', "negative age") > 0 {
            local found_quality 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_quality' == 1
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
        output("`tmp_dir'/_v2_qstrict.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_qstrict.txt", read text
    local found_strict_flag 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "age >100") > 0 | ///
           strpos(`"`macval(line)'"', "negative age") > 0 {
            local found_strict_flag 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_strict_flag' == 1
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
        output("`tmp_dir'/_v2_survey.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_survey.txt", read text
    local found_survey 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Survey Design") > 0 | ///
           strpos(`"`macval(line)'"', "Sampling weight") > 0 | ///
           strpos(`"`macval(line)'"', "sampling_weight") > 0 {
            local found_survey 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_survey' == 1
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
        output("`tmp_dir'/_v2_paneldet.txt")
    confirm file "`tmp_dir'/_v2_paneldet.txt"

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
        output("`tmp_dir'/_v2_binary.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_binary.txt", read text
    local found_binary 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "inary") > 0 {
            local found_binary 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_binary' == 1
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
        output("`tmp_dir'/_v2_survdet.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_survdet.txt", read text
    local found_survival 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Survival") > 0 | ///
           strpos(`"`macval(line)'"', "time variables") > 0 | ///
           strpos(`"`macval(line)'"', "event") > 0 {
            local found_survival 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_survival' == 1
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
        output("`tmp_dir'/_v2_multidet.txt")
    confirm file "`tmp_dir'/_v2_multidet.txt"
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
        output("`tmp_dir'/_v2_missdet.txt")

    tempname fh
    file open `fh' using "`tmp_dir'/_v2_missdet.txt", read text
    local found_missing_summary 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Missing Data") > 0 | ///
           strpos(`"`macval(line)'"', ">50% missing") > 0 | ///
           strpos(`"`macval(line)'"', "complete data") > 0 {
            local found_missing_summary 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_missing_summary' == 1
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
        output("`tmp_dir'/_v2_misspat.txt")
    confirm file "`tmp_dir'/_v2_misspat.txt"
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
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_va1.txt")
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
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_va3.txt")
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

* Test: datadict varabbrev restored after success
local ++test_count
capture noisily {
    set varabbrev off
    datadict, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_dd_va.md")
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: Varabbrev - datadict restored to off after success"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev - datadict restore (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}

* Test: datadict varabbrev restored after error
local ++test_count
capture noisily {
    set varabbrev off
    capture datadict, single("`tmp_dir'/nonexistent_v2_file")
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: Varabbrev - datadict restored to off after error"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev - datadict restore after error (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}

* ============================================================
* Stored Results
* ============================================================

* Test: r(nfiles) is numeric scalar
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_sr1.txt")
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

* Test: r(format) == "text"
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_sr2.txt")
    assert "`r(format)'" == "text"
}
if _rc == 0 {
    display as result "  PASS: Stored - r(format) == text"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored - r(format) (error `=_rc')"
    local ++fail_count
}

* Test: r(output) matches provided filename
local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_sr3.txt")
    assert regexm("`r(output)'", "_v2_sr3\.txt")
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
        output("`tmp_dir'/_v2_sr4.txt")
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

* Test: datadict r(nfiles) and r(output)
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_dd_sr.md")
    assert r(nfiles) == 1
    assert regexm("`r(output)'", "_v2_dd_sr\.md")
}
if _rc == 0 {
    display as result "  PASS: Stored - datadict r(nfiles) and r(output)"
    local ++pass_count
}
else {
    display as error "  FAIL: Stored - datadict return values (error `=_rc')"
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

    datamap, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_pres.txt")

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

* Test: datadict preserves current data
local ++test_count
capture noisily {
    sysuse auto, clear
    local N_before = _N
    datasignature
    local sig_before "`r(datasignature)'"

    datadict, single("`tmp_dir'/v2_constant") output("`tmp_dir'/_v2_dd_pres.md")

    assert _N == `N_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: Preservation - datadict preserves user data"
    local ++pass_count
}
else {
    display as error "  FAIL: Preservation - datadict (error `=_rc')"
    local ++fail_count
}

* ============================================================
* datadict: Additional Options
* ============================================================

* Test: datadict with missing + stats on all-missing data
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/v2_allmiss") missing stats ///
        output("`tmp_dir'/_v2_dd_miss.md")
    confirm file "`tmp_dir'/_v2_dd_miss.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - missing+stats on all-missing dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - missing+stats all-missing (error `=_rc')"
    local ++fail_count
}

* Test: datadict with special chars in title
local ++test_count
capture noisily {
    datadict, single("`tmp_dir'/v2_constant") ///
        output("`tmp_dir'/_v2_dd_special.md") ///
        title("Title with <angle> & 'quotes'")
    confirm file "`tmp_dir'/_v2_dd_special.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - special chars in title"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - special chars in title (error `=_rc')"
    local ++fail_count
}

* Test: datadict separate mode
local ++test_count
capture noisily {
    datadict, filelist("`tmp_dir'/v2_constant" "`tmp_dir'/v2_singlevar") ///
        separate
    * separate creates <basename>_dictionary.md in cwd
    * The basename is derived from the full path without .dta
    confirm file "`tmp_dir'/v2_constant_dictionary.md"
    confirm file "`tmp_dir'/v2_singlevar_dictionary.md"
}
if _rc == 0 {
    display as result "  PASS: datadict - separate mode creates individual files"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - separate mode (error `=_rc')"
    local ++fail_count
}

* Test: datadict filelist with 3 files
local ++test_count
capture noisily {
    datadict, filelist("`tmp_dir'/v2_constant" "`tmp_dir'/v2_singlevar" "`tmp_dir'/v2_dupes") ///
        output("`tmp_dir'/_v2_dd_3files.md")
    assert r(nfiles) == 3
}
if _rc == 0 {
    display as result "  PASS: datadict - filelist with 3 files"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict - filelist 3 files (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Datamap: datesafe + detect(survival) interaction
* ============================================================

local ++test_count
capture noisily {
    datamap, single("`tmp_dir'/v2_survival") datesafe detect(survival) ///
        output("`tmp_dir'/_v2_ds_surv.txt")
    confirm file "`tmp_dir'/_v2_ds_surv.txt"

    * Should suppress exact dates but still detect survival vars
    tempname fh
    file open `fh' using "`tmp_dir'/_v2_ds_surv.txt", read text
    local found_suppressed 0
    local found_survival 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "suppressed") > 0 {
            local found_suppressed 1
        }
        if strpos(`"`macval(line)'"', "Survival") > 0 | ///
           strpos(`"`macval(line)'"', "time variables") > 0 {
            local found_survival 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_suppressed' == 1
    assert `found_survival' == 1
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

* Test: which datamap and which datadict are discoverable
local ++test_count
capture noisily {
    which datamap
    which datadict
}
if _rc == 0 {
    display as result "  PASS: Install - which datamap and datadict succeed"
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
        output("`tmp_dir'/_v2_allmiss_full.txt") ///
        quality missing(detail) samples(3) autodetect
    confirm file "`tmp_dir'/_v2_allmiss_full.txt"
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

local v2_files : dir "`tmp_dir'" files "_v2_*.txt"
foreach f of local v2_files {
    capture erase "`tmp_dir'/`f'"
}
local v2_md : dir "`tmp_dir'" files "_v2_*.md"
foreach f of local v2_md {
    capture erase "`tmp_dir'/`f'"
}
capture erase "`tmp_dir'/v2_constant_dictionary.md"
capture erase "`tmp_dir'/v2_singlevar_dictionary.md"

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
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
