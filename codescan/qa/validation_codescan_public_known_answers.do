*! validation_codescan_public_known_answers.do - public-data and study oracles
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_codescan_public_known_answers.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Setup

local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"

* Fixed public fixture used by Stata's [D] icd10 examples.
* https://www.stata-press.com/data/r17/australia10.dta
tempfile australia10

local ++test_count
capture noisily {
    use "https://www.stata-press.com/data/r17/australia10.dta", clear
    assert _N == 3322
    quietly summarize deaths, meanonly
    assert r(sum) == 143473
    save `australia10'
}
if _rc == 0 {
    display as result "  PASS: K1 - public mortality fixture has pinned rows and deaths"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 - public fixture known answers (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K1"
}

**# Quan et al. (2005) totals

* Source: Quan et al., Medical Care 2005;43:1130-1139, Table 1.
* DOI: 10.1097/01.mlr.0000182534.19832.83
* Expected code-row counts and death totals were resolved independently with
* Stata's official icd10 generate on the fixed public fixture, then pinned here.
local ++test_count
capture noisily {
    use `australia10', clear
    codescan cause, mode(prefix) define( ///
        mi "I21|I22|I252" | ///
        chf "I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290" | ///
        pvd "I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959" | ///
        dm_u "E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149" | ///
        dm_c "E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147")

    quietly summarize mi, meanonly
    assert r(sum) == 7
    quietly summarize deaths if mi, meanonly
    assert r(sum) == 9951

    quietly summarize chf, meanonly
    assert r(sum) == 28
    quietly summarize deaths if chf, meanonly
    assert r(sum) == 4843

    quietly summarize pvd, meanonly
    assert r(sum) == 37
    quietly summarize deaths if pvd, meanonly
    assert r(sum) == 2293

    quietly summarize dm_u, meanonly
    assert r(sum) == 24
    quietly summarize deaths if dm_u, meanonly
    assert r(sum) == 3187

    quietly summarize dm_c, meanonly
    assert r(sum) == 26
    quietly summarize deaths if dm_c, meanonly
    assert r(sum) == 759
    assert dm_u + dm_c <= 1
}
if _rc == 0 {
    display as result "  PASS: K2 - five study definitions recover exact row and death totals"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 - Quan public-data totals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K2"
}

**# Sex-stratified collapse and counting

local ++test_count
capture noisily {
    use `australia10', clear
    codescan cause, id(sex) collapse countmode mode(prefix) define( ///
        mi "I21|I22|I252" | ///
        chf "I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290" | ///
        pvd "I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959" | ///
        dm_u "E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149" | ///
        dm_c "E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147")

    assert _N == 2
    decode sex, generate(sex_name)
    assert mi == 5 & chf == 14 & pvd == 17 & dm_u == 12 & dm_c == 12 ///
        if sex_name == "Male"
    assert mi == 2 & chf == 14 & pvd == 20 & dm_u == 12 & dm_c == 14 ///
        if sex_name == "Female"
}
if _rc == 0 {
    display as result "  PASS: K3 - collapsed study counts resolve exactly within sex"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 - sex-stratified collapsed counts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K3"
}

**# Official manual ranges

local ++test_count
capture noisily {
    use `australia10', clear
    codescan cause, define( ///
        cancer "C|D" | ///
        external "V0[1-9]|V[1-9]|W|X|Y0|Y1|Y2|Y3|Y4|Y5|Y6|Y7|Y8|Y9[0-8]")

    quietly summarize cancer, meanonly
    assert r(sum) == 650
    quietly summarize deaths if cancer, meanonly
    assert r(sum) == 43720

    quietly summarize external, meanonly
    assert r(sum) == 511
    quietly summarize deaths if external, meanonly
    assert r(sum) == 8981
    assert cancer + external <= 1
}
if _rc == 0 {
    display as result "  PASS: K4 - manual cancer and external-cause ranges recover pinned totals"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 - official-range known answers (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K4"
}

**# Wide records with an incomplete final group

local ++test_count
capture noisily {
    use `australia10', clear
    gen long record = ceil(_n / 3)
    bysort record: gen byte slot = _n
    keep record slot cause
    reshape wide cause, i(record) j(slot)

    codescan cause1-cause3, countmode define( ///
        cancer "C|D" | ///
        external "V0[1-9]|V[1-9]|W|X|Y0|Y1|Y2|Y3|Y4|Y5|Y6|Y7|Y8|Y9[0-8]")

    assert _N == 1108
    quietly summarize cancer, meanonly
    assert r(sum) == 650
    count if cancer > 0
    assert r(N) == 218
    quietly summarize external, meanonly
    assert r(sum) == 511
    count if external > 0
    assert r(N) == 171
    assert cause2[_N] == "" & cause3[_N] == ""
}
if _rc == 0 {
    display as result "  PASS: K5 - wide hits and positive records match pinned answers"
    local ++pass_count
}
else {
    display as error "  FAIL: K5 - wide-record known answers (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K5"
}

**# Public inventory description

local ++test_count
capture noisily {
    use `australia10', clear
    codescan_describe cause, top(5)
    assert r(n_vars) == 1
    assert r(n_entries) == 3322
    assert r(n_unique) == 2109
    assert "`r(top_code_1)'" == "A020"
    assert "`r(top_code_5)'" == "A084"
    assert "`r(chapter_1)'" == "C"
    assert "`r(chapter_22)'" == "H"
    matrix TOP = r(top_codes)
    matrix CH = r(chapters)
    assert TOP[1,1] == 2
    assert abs(TOP[1,2] - 100 * 2 / 3322) < 1e-10
    assert CH[1,1] == 267 & CH[1,2] == 457
    assert CH[22,1] == 5 & CH[22,2] == 5
}
if _rc == 0 {
    display as result "  PASS: K6 - describe resolves exact public inventory and chapter totals"
    local ++pass_count
}
else {
    display as error "  FAIL: K6 - public inventory known answers (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K6"
}

**# Published boundary cases

* Each adjacent pair crosses an inclusion boundary in Quan Table 1. This is
* intentionally inline rather than sampled from the mortality fixture so the
* suite covers rare definitions that may not occur there.
local ++test_count
capture noisily {
    clear
    input str5 cause byte want_mi byte want_chf byte want_pvd byte want_dm_u byte want_dm_c
    "I252" 1 0 0 0 0
    "I253" 0 0 0 0 0
    "I425" 0 1 0 0 0
    "I424" 0 0 0 0 0
    "I731" 0 0 1 0 0
    "I732" 0 0 0 0 0
    "E109" 0 0 0 1 0
    "E107" 0 0 0 0 1
    "E117" 0 0 0 0 1
    "E119" 0 0 0 1 0
    end

    codescan cause, mode(prefix) define( ///
        got_mi "I21|I22|I252" | ///
        got_chf "I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290" | ///
        got_pvd "I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959" | ///
        got_dm_u "E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149" | ///
        got_dm_c "E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147")

    assert got_mi == want_mi
    assert got_chf == want_chf
    assert got_pvd == want_pvd
    assert got_dm_u == want_dm_u
    assert got_dm_c == want_dm_c
}
if _rc == 0 {
    display as result "  PASS: K7 - adjacent published inclusion boundaries resolve correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: K7 - published boundary known answers (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K7"
}

**# Session hygiene

local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: K8 - session settings preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: K8 - session settings preserved (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K8"
}

**# Summary

display as result "Known-answer results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
}
display as text "RESULT: validation_codescan_public_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "validation_codescan_public_known_answers" `test_count' `pass_count' `fail_count'

capture log close _all
if `fail_count' > 0 exit 1
