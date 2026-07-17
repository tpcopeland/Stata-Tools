* validation_codescan_io.do - Exact dictionary and persistence validation for codescan
* Date: 2026-04-23

clear all
set seed 24680
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


* ============================================================
* V1: save() writes exact define() dictionary rows
* ============================================================

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E116" ""
    "I50"  ""
    end

    tempfile vio1_base
    local vio1_csv "`vio1_base'.csv"

    codescan dx1 dx2, ///
        define(dm2 "E11" ~ "E116" | htn "I1[0-35]" | chf "I50") ///
        label(cs_dm2 "Type 2 Diabetes" \ cs_htn "Hypertension" \ cs_chf "Heart Failure") ///
        generate(cs_) save("`vio1_csv'", replace)

    import delimited using "`vio1_csv'", clear stringcols(_all) varnames(1)

    assert _N == 3
    assert name[1] == "dm2"
    assert pattern[1] == "E11"
    assert exclusion[1] == "E116"
    assert label[1] == "Type 2 Diabetes"

    assert name[2] == "htn"
    assert pattern[2] == "I1[0-35]"
    assert exclusion[2] == ""
    assert label[2] == "Hypertension"

    assert name[3] == "chf"
    assert pattern[3] == "I50"
    assert exclusion[3] == ""
    assert label[3] == "Heart Failure"
}
if _rc == 0 {
    display as result "  PASS: V1 - save() writes exact define() dictionary"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 - save() exact dictionary rows (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: .dta codefile with mixed-case columns scans exactly
* ============================================================

local ++test_count
capture noisily {
    tempfile vio2_base
    local vio2_cf "`vio2_base'.dta"

    clear
    input str32 Name str244 PATTERN str80 LaBeL str244 ExClUsIoN
    "dm2" "E11" "Original DM" "E116"
    "htn" "I10" "Original HTN" ""
    end
    save "`vio2_cf'", replace

    clear
    input str10 dx1 str10 dx2 byte expected_dm2 byte expected_htn
    "E110" ""    1 0
    "E116" "I10" 0 1
    "E110" "I10" 1 1
    "Z00"  ""    0 0
    end

    codescan dx1 dx2, codefile("`vio2_cf'") ///
        label(dm2 "Override DM" \ htn "Override HTN")

    assert dm2 == expected_dm2
    assert htn == expected_htn

    local lbl_dm2 : variable label dm2
    local lbl_htn : variable label htn

    assert `"`lbl_dm2'"' == "Override DM"
    assert `"`lbl_htn'"' == "Override HTN"
}
if _rc == 0 {
    display as result "  PASS: V2 - mixed-case .dta codefile exact scan and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 - .dta codefile exact scan and labels (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V3: save() roundtrip to CSV preserves exact scan behavior
* ============================================================

local ++test_count
capture noisily {
    tempfile vio3_base
    local vio3_csv "`vio3_base'.csv"

    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E116" ""
    "I50"  "I10"
    "Z00"  ""
    end

    codescan dx1 dx2, ///
        define(dm2 "E11" ~ "E116" | htn "I1[0-35]" | chf "I50") ///
        label(dm2 "Type 2 Diabetes" \ htn "Hypertension" \ chf "Heart Failure") ///
        save("`vio3_csv'", replace)

    clear
    input str10 dx1 str10 dx2 byte expected_dm2 byte expected_htn byte expected_chf
    "E110" "I10" 1 1 0
    "E116" ""    0 0 0
    "I50"  "I10" 0 1 1
    "Z00"  ""    0 0 0
    end

    codescan dx1 dx2, codefile("`vio3_csv'")

    assert dm2 == expected_dm2
    assert htn == expected_htn
    assert chf == expected_chf

    local lbl_dm2 : variable label dm2
    local lbl_htn : variable label htn
    local lbl_chf : variable label chf

    assert `"`lbl_dm2'"' == "Type 2 Diabetes"
    assert `"`lbl_htn'"' == "Hypertension"
    assert `"`lbl_chf'"' == "Heart Failure"
}
if _rc == 0 {
    display as result "  PASS: V3 - save() roundtrip preserves exact behavior"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 - save() roundtrip exact behavior (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: saving() collapse writes exact patient-level dataset
* ============================================================

local ++test_count
capture noisily {
    tempfile vio4_save

    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" "I10" 21900
    1 "E112" ""    21910
    1 ""     "I10" 21910
    2 "E116" ""    21920
    2 "Z00"  "I10" 21930
    3 ""     ""    21940
    end
    format visit_dt %td

    codescan dx1 dx2, ///
        define(dm2 "E11" ~ "E116" | htn "I10") ///
        id(pid) date(visit_dt) collapse alldates countrows ///
        label(dm2 "Type 2 Diabetes" \ htn "Hypertension") ///
        saving("`vio4_save'", replace)

    use "`vio4_save'", clear
    sort pid

    assert _N == 3

    assert dm2[1] == 1
    assert dm2_first[1] == 21900
    assert dm2_last[1] == 21910
    assert dm2_count[1] == 2
    assert dm2_nrows[1] == 2
    assert htn[1] == 1
    assert htn_first[1] == 21900
    assert htn_last[1] == 21910
    assert htn_count[1] == 2
    assert htn_nrows[1] == 2

    assert dm2[2] == 0
    assert missing(dm2_first[2])
    assert missing(dm2_last[2])
    assert dm2_count[2] == 0
    assert dm2_nrows[2] == 0
    assert htn[2] == 1
    assert htn_first[2] == 21930
    assert htn_last[2] == 21930
    assert htn_count[2] == 1
    assert htn_nrows[2] == 1

    assert dm2[3] == 0
    assert missing(dm2_first[3])
    assert missing(dm2_last[3])
    assert dm2_count[3] == 0
    assert dm2_nrows[3] == 0
    assert htn[3] == 0
    assert missing(htn_first[3])
    assert missing(htn_last[3])
    assert htn_count[3] == 0
    assert htn_nrows[3] == 0

    local lbl_dm2 : variable label dm2
    local lbl_dm2_first : variable label dm2_first
    local lbl_dm2_count : variable label dm2_count
    local lbl_dm2_nrows : variable label dm2_nrows

    assert `"`lbl_dm2'"' == "Type 2 Diabetes"
    assert `"`lbl_dm2_first'"' == "Earliest Type 2 Diabetes Date"
    assert `"`lbl_dm2_count'"' == "Type 2 Diabetes Date Count"
    assert `"`lbl_dm2_nrows'"' == "Type 2 Diabetes Row Count"
}
if _rc == 0 {
    display as result "  PASS: V4 - saving() collapse exact values and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 - saving() collapse exact values and labels (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V5: saving() merge writes exact broadcast dataset
* ============================================================

local ++test_count
capture noisily {
    tempfile vio5_save

    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "E119" 21910
    1 "Z00"  21910
    2 "E110" 21930
    2 "E119" 21930
    3 "Z00"  21940
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        merge alldates countrows saving("`vio5_save'", replace)

    use "`vio5_save'", clear
    sort pid visit_dt dx1

    assert _N == 6
    assert dx1[1] == "E110"
    assert dx1[2] == "E119"
    assert dx1[3] == "Z00"
    assert dx1[4] == "E110"
    assert dx1[5] == "E119"
    assert dx1[6] == "Z00"

    assert dm2 == 1 if pid == 1
    assert dm2_first == 21900 if pid == 1
    assert dm2_last == 21910 if pid == 1
    assert dm2_count == 2 if pid == 1
    assert dm2_nrows == 2 if pid == 1

    assert dm2 == 1 if pid == 2
    assert dm2_first == 21930 if pid == 2
    assert dm2_last == 21930 if pid == 2
    assert dm2_count == 1 if pid == 2
    assert dm2_nrows == 2 if pid == 2

    assert dm2 == 0 if pid == 3
    assert missing(dm2_first) if pid == 3
    assert missing(dm2_last) if pid == 3
    assert dm2_count == 0 if pid == 3
    assert dm2_nrows == 0 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: V5 - saving() merge exact broadcast values"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 - saving() merge exact broadcast values (error `=_rc')"
    local ++fail_count
}

display ""

**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


_codescan_qa_publish "validation_codescan_io" `test_count' `pass_count' `fail_count'
display as result "RESULT: validation_codescan_io tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
