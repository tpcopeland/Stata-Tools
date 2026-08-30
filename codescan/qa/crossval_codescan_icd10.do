*! crossval_codescan_icd10.do - codescan parity with official Stata ICD-10 tools
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all
log using "crossval_codescan_icd10.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Setup

local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"

* Public source: Australian mortality data used by [D] icd10.
* https://www.stata-press.com/data/r17/australia10.dta
* The fixed Release 17 URL prevents a future Stata release from silently
* changing the fixture. Stata's official icd10 command is the independent
* implementation used as the row-level oracle below.
tempfile australia10

local ++test_count
capture noisily {
    use "https://www.stata-press.com/data/r17/australia10.dta", clear
    assert _N == 3322
    confirm string variable cause
    confirm numeric variable sex deaths
    assert "`: data label'" == "Australian mortality data, 2010"
    save `australia10'
}
if _rc == 0 {
    display as result "  PASS: CV1 - fixed public ICD-10 fixture loads with expected contract"
    local ++pass_count
}
else {
    display as error "  FAIL: CV1 - public ICD-10 fixture contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CV1"
}

**# Official Stata ICD-10 examples

* The cancer range is the worked generate() example in [D] icd10. The official
* command validates and classifies each code; codescan independently scans the
* same source rows.
local ++test_count
capture noisily {
    use `australia10', clear
    icd10 generate ref_cancer = cause, range(C* D*)
    codescan cause, define(cancer "C|D")
    assert cancer == ref_cancer
    count if cancer == 1
    assert r(N) == 650
}
if _rc == 0 {
    display as result "  PASS: CV2 - manual cancer example agrees on every source row"
    local ++pass_count
}
else {
    display as error "  FAIL: CV2 - manual cancer example parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CV2"
}

**# Quan et al. (2005) study definitions

* Quan et al., Medical Care 2005;43:1130-1139, Table 1, pp. 1133-1134.
* DOI: 10.1097/01.mlr.0000182534.19832.83
* Five definitions exercise isolated prefixes, discontinuous lists, bounded
* ranges, and two mutually exclusive diabetes groups. icd10 generate resolves
* the published dotted codelists; codescan receives their compact no-dot form.
local ++test_count
capture noisily {
    use `australia10', clear

    icd10 generate ref_mi = cause, range(I21* I22* I25.2)
    icd10 generate ref_chf = cause, range(I09.9 I11.0 I13.0 I13.2 I25.5 ///
        I42.0 I42.5/I42.9 I43* I50* P29.0)
    icd10 generate ref_pvd = cause, range(I70* I71* I73.1 I73.8 I73.9 ///
        I77.1 I79.0 I79.2 K55.1 K55.8 K55.9 Z95.8 Z95.9)
    icd10 generate ref_dm_u = cause, range(E10.0 E10.1 E10.6 E10.8 E10.9 ///
        E11.0 E11.1 E11.6 E11.8 E11.9 E12.0 E12.1 E12.6 E12.8 E12.9 ///
        E13.0 E13.1 E13.6 E13.8 E13.9 E14.0 E14.1 E14.6 E14.8 E14.9)
    icd10 generate ref_dm_c = cause, range(E10.2/E10.5 E10.7 ///
        E11.2/E11.5 E11.7 E12.2/E12.5 E12.7 E13.2/E13.5 E13.7 ///
        E14.2/E14.5 E14.7)

    codescan cause, mode(prefix) define( ///
        mi "I21|I22|I252" | ///
        chf "I099|I110|I130|I132|I255|I420|I425|I426|I427|I428|I429|I43|I50|P290" | ///
        pvd "I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959" | ///
        dm_u "E100|E101|E106|E108|E109|E110|E111|E116|E118|E119|E120|E121|E126|E128|E129|E130|E131|E136|E138|E139|E140|E141|E146|E148|E149" | ///
        dm_c "E102|E103|E104|E105|E107|E112|E113|E114|E115|E117|E122|E123|E124|E125|E127|E132|E133|E134|E135|E137|E142|E143|E144|E145|E147")

    assert mi == ref_mi
    assert chf == ref_chf
    assert pvd == ref_pvd
    assert dm_u == ref_dm_u
    assert dm_c == ref_dm_c
    assert dm_u + dm_c <= 1
}
if _rc == 0 {
    display as result "  PASS: CV3 - five published Quan definitions agree row by row"
    local ++pass_count
}
else {
    display as error "  FAIL: CV3 - Quan definition parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CV3"
}

**# Dotted codes and nodots normalization

local ++test_count
capture noisily {
    use `australia10', clear
    icd10 clean cause, generate(cause_dot) dots
    icd10 generate ref_mi = cause_dot, range(I21* I22* I25.2)
    icd10 generate ref_pvd = cause_dot, range(I70* I71* I73.1 I73.8 I73.9 ///
        I77.1 I79.0 I79.2 K55.1 K55.8 K55.9 Z95.8 Z95.9)

    codescan cause_dot, mode(prefix) nodots define( ///
        mi "I21|I22|I252" | ///
        pvd "I70|I71|I731|I738|I739|I771|I790|I792|K551|K558|K559|Z958|Z959")

    assert mi == ref_mi
    assert pvd == ref_pvd
    count if strpos(cause_dot, ".") > 0
    assert r(N) > 1000 & r(N) < .
}
if _rc == 0 {
    display as result "  PASS: CV4 - official dotted codes agree through nodots normalization"
    local ++pass_count
}
else {
    display as error "  FAIL: CV4 - dotted-code parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CV4"
}

**# Wide multi-slot records

* Stata's icd10 works on one variable at a time. Three independent official
* indicators are summed to form the oracle for codescan's wide countmode path.
* The 3,322 source rows are deliberately grouped by threes, leaving an
* incomplete final record that checks blank trailing slots.
local ++test_count
capture noisily {
    use `australia10', clear
    gen long record = ceil(_n / 3)
    bysort record: gen byte slot = _n
    keep record slot cause
    reshape wide cause, i(record) j(slot)
    assert _N == 1108

    forvalues j = 1/3 {
        icd10 generate ref`j' = cause`j', range(C* D*)
    }
    egen byte ref_count = rowtotal(ref1 ref2 ref3)

    codescan cause1-cause3, define(cancer "C|D") countmode
    assert cancer == ref_count
    assert inrange(cancer, 0, 3)
    assert cause2[_N] == "" & cause3[_N] == ""
}
if _rc == 0 {
    display as result "  PASS: CV5 - wide slot counts agree with three official ICD passes"
    local ++pass_count
}
else {
    display as error "  FAIL: CV5 - wide multi-slot parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CV5"
}

**# Study codelist exclusion boundary

* Quan Table 1 includes C00-C26, C30-C34, C37-C41, C43, C45-C58,
* C60-C76, C81-C85, C88, and C90-C97 for any malignancy. Starting from all
* C-codes and excluding the documented gaps exercises codescan's negative-list
* path against icd10's explicit positive range oracle.
local ++test_count
capture noisily {
    use `australia10', clear
    icd10 generate ref_malignancy = cause, range( ///
        C00* C01* C02* C03* C04* C05* C06* C07* C08* C09* ///
        C10* C11* C12* C13* C14* C15* C16* C17* C18* C19* ///
        C20* C21* C22* C23* C24* C25* C26* ///
        C30* C31* C32* C33* C34* C37* C38* C39* C40* C41* C43* ///
        C45* C46* C47* C48* C49* C50* C51* C52* C53* C54* C55* ///
        C56* C57* C58* C60* C61* C62* C63* C64* C65* C66* C67* ///
        C68* C69* C70* C71* C72* C73* C74* C75* C76* C81* C82* ///
        C83* C84* C85* C88* C90* C91* C92* C93* C94* C95* C96* C97*)

    codescan cause, mode(prefix) define(malignancy "C" ~ ///
        "C27|C28|C29|C35|C36|C42|C44|C59|C77|C78|C79|C80|C86|C87|C89")

    assert malignancy == ref_malignancy
    count if substr(cause, 1, 1) == "C" & malignancy == 0
    assert r(N) > 0 & r(N) < .
}
if _rc == 0 {
    display as result "  PASS: CV6 - published malignancy gaps agree with explicit ICD ranges"
    local ++pass_count
}
else {
    display as error "  FAIL: CV6 - study codelist exclusion parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CV6"
}

**# Session hygiene

local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: CV7 - session settings preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: CV7 - session settings preserved (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CV7"
}

**# Summary

display as result "Cross-validation results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
}
display as text "RESULT: crossval_codescan_icd10 tests=`test_count' pass=`pass_count' fail=`fail_count'"
_codescan_qa_publish "crossval_codescan_icd10" `test_count' `pass_count' `fail_count'

capture log close _all
if `fail_count' > 0 exit 1
