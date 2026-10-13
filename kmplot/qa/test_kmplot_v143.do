* test_kmplot_v143.do
* Regression tests for kmplot 1.4.3: medianannotate note wording
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-13
*
* Through 1.4.2 medianannotate with by() printed "Placebo: 8  Drug A: 22" with
* no "Median" label, while a single curve printed "Median: x". The note is now
* "Median: Placebo: 8; Drug A: 22; Drug B: 33" for by() and unchanged for one
* curve. These tests read the exported SVG text.
*
* Run from kmplot/qa:  stata-mp -b do test_kmplot_v143.do

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# A1: by() note carries the Median label, group labels and values
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local svg "`c(tmpdir)'/kmplot_v143_a1.svg"
    capture erase "`svg'"
    kmplot, by(drug) median medianannotate export("`svg'", replace) name(v143, replace)
    local m1 = r(median_1)
    local m2 = r(median_2)
    local m3 = r(median_3)
    local l1 : label (drug) 1
    local l2 : label (drug) 2
    local l3 : label (drug) 3
    _kmplot_assert_file_contains using "`svg'", ///
        pattern("Median: `l1': `m1'; `l2': `m2'; `l3': `m3'")
    _kmplot_assert_file_not_contains using "`svg'", pattern("`l1' `m1',")
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A1 by() median note wording"
}
else {
    local ++fail_count
    display as error "FAIL: A1 by() median note wording (rc=" _rc ")"
}

**# A2: medianformat() is applied inside the by() note
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local svg "`c(tmpdir)'/kmplot_v143_a2.svg"
    capture erase "`svg'"
    kmplot, by(drug) median medianannotate medianformat(%5.1f) ///
        export("`svg'", replace) name(v143, replace)
    local l1 : label (drug) 1
    local m1 : display %5.1f r(median_1)
    local m1 = strtrim("`m1'")
    _kmplot_assert_file_contains using "`svg'", pattern("Median: `l1': `m1'; ")
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A2 medianformat() in by() note"
}
else {
    local ++fail_count
    display as error "FAIL: A2 medianformat() in by() note (rc=" _rc ")"
}

**# A3: a group whose median is not reached prints NR in the same note
local ++test_count
capture noisily {
    sysuse cancer, clear
    replace died = 0 if drug == 3
    stset studytime, failure(died)
    local svg "`c(tmpdir)'/kmplot_v143_a3.svg"
    capture erase "`svg'"
    kmplot, by(drug) median medianannotate export("`svg'", replace) name(v143, replace)
    assert missing(r(median_3))
    local l3 : label (drug) 3
    _kmplot_assert_file_contains using "`svg'", pattern("Median: ")
    _kmplot_assert_file_contains using "`svg'", pattern("; `l3': NR")
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A3 NR in by() note"
}
else {
    local ++fail_count
    display as error "FAIL: A3 NR in by() note (rc=" _rc ")"
}

**# A4: a single curve keeps "Median: x"
* guard: expected green at pre-fix ref; single-curve wording is unchanged.
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local svg "`c(tmpdir)'/kmplot_v143_a4.svg"
    capture erase "`svg'"
    kmplot, median medianannotate export("`svg'", replace) name(v143, replace)
    local m = r(median_1)
    _kmplot_assert_file_contains using "`svg'", pattern("Median: `m'<")
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A4 single-curve note unchanged"
}
else {
    local ++fail_count
    display as error "FAIL: A4 single-curve note (rc=" _rc ")"
}

**# A5: labels ending in a digit or containing a comma or a double quote
* Through 1.4.2 a by() label containing a double quote stopped the run at the
* console display (r(198)); the note must also stay unambiguous for labels
* such as "Arm 1" (a value separator is a colon, a group separator a semicolon).
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    label define q143 1 `"Drug "X""' 2 "Arm 1" 3 "A, B"
    label values drug q143
    local svg "`c(tmpdir)'/kmplot_v143_a5.svg"
    capture erase "`svg'"
    kmplot, by(drug) median medianannotate export("`svg'", replace) name(v143, replace)
    local m1 = r(median_1)
    local m2 = r(median_2)
    local m3 = r(median_3)
    _kmplot_assert_file_contains using "`svg'", ///
        pattern(`"Median: Drug "X": `m1'; Arm 1: `m2'; A, B: `m3'"')
    erase "`svg'"
    * the risk-table path displays the same labels
    kmplot, by(drug) risktable median medianannotate name(v143, replace)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A5 digit, comma and quote labels"
}
else {
    local ++fail_count
    display as error "FAIL: A5 digit, comma and quote labels (rc=" _rc ")"
}

**# Summary
display "RESULT: test_kmplot_v143 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    exit 1
}
