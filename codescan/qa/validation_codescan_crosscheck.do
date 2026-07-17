* validation_codescan_crosscheck.do - Cross-check validation for codescan
* Compares codescan output to hand-computed Stata oracles (regexm() loops,
* manual collapses). No external R/Python reference is involved, so this is
* validation, not cross-validation.
* Date: 2026-04-01

clear all
set seed 54321
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

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



* XV1: Regex row-level indicators vs manual regexm loop
* Build dataset, manually compute with regexm(), compare to codescan
local ++test_count
capture noisily {
    clear
    set obs 50
    gen long pid = ceil(_n / 5)
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""

    * Scatter codes across columns
    replace dx1 = "E110" if mod(_n, 7) == 0
    replace dx1 = "I10"  if mod(_n, 5) == 0
    replace dx1 = "E660" if mod(_n, 11) == 0
    replace dx2 = "E119" if mod(_n, 9) == 0
    replace dx2 = "I13"  if mod(_n, 6) == 0
    replace dx3 = "I21"  if mod(_n, 8) == 0
    replace dx1 = "Z00" if dx1 == "" & dx2 == "" & dx3 == ""

    * Manual computation
    gen byte manual_dm2 = 0
    gen byte manual_htn = 0
    gen byte manual_cvd = 0
    foreach v in dx1 dx2 dx3 {
        replace manual_dm2 = 1 if regexm(`v', "^(E11)") & manual_dm2 == 0
        replace manual_htn = 1 if regexm(`v', "^(I1[0-35])") & manual_htn == 0
        replace manual_cvd = 1 if regexm(`v', "^(I2[0-5])") & manual_cvd == 0
    }

    * codescan computation
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]" | cvd "I2[0-5]")

    * Compare row by row
    assert dm2 == manual_dm2
    assert htn == manual_htn
    assert cvd == manual_cvd
}
if _rc == 0 {
    display as result "  PASS: XV1 - Row-level regex vs manual regexm (50 rows x 3 conditions)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV1 - Row-level regex vs manual regexm (error `=_rc')"
    local ++fail_count
}


* XV2: Prefix row-level indicators vs manual substr loop
local ++test_count
capture noisily {
    clear
    set obs 30
    gen str10 dx1 = ""
    gen str10 dx2 = ""

    replace dx1 = "E110" if mod(_n, 4) == 0
    replace dx1 = "Z001" if mod(_n, 6) == 0
    replace dx2 = "E119" if mod(_n, 5) == 0
    replace dx2 = "Z010" if mod(_n, 7) == 0
    replace dx1 = "J45" if dx1 == "" & dx2 == ""

    * Manual prefix computation
    gen byte manual_dm2 = 0
    gen byte manual_z = 0
    foreach v in dx1 dx2 {
        replace manual_dm2 = 1 if substr(`v', 1, 3) == "E11" & manual_dm2 == 0
        replace manual_z = 1 if (substr(`v', 1, 3) == "Z00" | substr(`v', 1, 3) == "Z01") & manual_z == 0
    }

    * codescan prefix computation
    codescan dx1 dx2, define(dm2 "E11" | z_codes "Z00|Z01") mode(prefix)

    assert dm2 == manual_dm2
    assert z_codes == manual_z
}
if _rc == 0 {
    display as result "  PASS: XV2 - Prefix mode vs manual substr (30 rows)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV2 - Prefix mode vs manual substr (error `=_rc')"
    local ++fail_count
}


* XV3: Collapse vs manual bysort+egen max
local ++test_count
capture noisily {
    clear
    set obs 40
    gen long pid = ceil(_n / 4)
    gen str10 dx1 = ""
    replace dx1 = "E110" if mod(_n, 3) == 0
    replace dx1 = "I10"  if mod(_n, 5) == 0
    replace dx1 = "Z00" if dx1 == ""

    * Manual: create indicator, then collapse manually
    gen byte manual_dm2 = regexm(dx1, "^(E11)")
    gen byte manual_htn = regexm(dx1, "^(I10)")
    preserve
    collapse (max) manual_dm2 manual_htn, by(pid)
    tempfile manual_collapsed
    save `manual_collapsed'
    restore

    * codescan collapse
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse

    * Merge manual results
    merge 1:1 pid using `manual_collapsed', nogenerate
    assert dm2 == manual_dm2
    assert htn == manual_htn
}
if _rc == 0 {
    display as result "  PASS: XV3 - Collapse vs manual bysort+egen max (10 patients)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV3 - Collapse vs manual bysort+egen max (error `=_rc')"
    local ++fail_count
}


* XV4: Earliest/latest dates vs manual computation
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "Z00"  21910
    1 "E119" 21920
    1 "E110" 21905
    2 "Z00"  21900
    2 "Z01"  21910
    3 "E110" 21950
    3 "Z00"  21960
    end
    format visit_dt %td

    * Manual computation
    gen byte has_dm2 = regexm(dx1, "^(E11)")
    gen double match_dt = visit_dt if has_dm2 == 1
    preserve
    collapse (max) manual_dm2=has_dm2 (min) manual_first=match_dt ///
        (max) manual_last=match_dt, by(pid)
    tempfile manual
    save `manual'
    restore

    * codescan
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate

    merge 1:1 pid using `manual', nogenerate

    * Compare
    assert dm2 == manual_dm2
    assert dm2_first == manual_first if dm2 == 1
    assert dm2_last == manual_last if dm2 == 1
    assert missing(dm2_first) if dm2 == 0
    assert missing(manual_first) if dm2 == 0
}
if _rc == 0 {
    display as result "  PASS: XV4 - Earliest/latest dates vs manual min/max"
    local ++pass_count
}
else {
    display as error "  FAIL: XV4 - Earliest/latest dates vs manual min/max (error `=_rc')"
    local ++fail_count
}


* XV5: Countdate vs manual unique date count
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" ""     21900
    1 "E119" "E110" 21900
    1 "E110" ""     21910
    1 "Z00"  ""     21920
    2 "E110" ""     21900
    2 "E110" ""     21900
    2 "E110" ""     21905
    3 "Z00"  ""     21900
    end
    format visit_dt %td

    * Manual: for each (pid, date), is there any E11 match? Count unique dates
    gen byte has_dm2 = (regexm(dx1, "^(E11)") | regexm(dx2, "^(E11)"))
    bysort pid visit_dt: egen byte any_match = max(has_dm2)
    bysort pid visit_dt: gen byte tag = (_n == 1) & any_match == 1 & !missing(visit_dt)
    preserve
    collapse (sum) manual_count=tag (max) manual_dm2=has_dm2, by(pid)
    tempfile manual
    save `manual'
    restore

    * codescan
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    merge 1:1 pid using `manual', nogenerate

    assert dm2_count == manual_count
    assert dm2 == manual_dm2
}
if _rc == 0 {
    display as result "  PASS: XV5 - Countdate vs manual unique date count"
    local ++pass_count
}
else {
    display as error "  FAIL: XV5 - Countdate vs manual unique date count (error `=_rc')"
    local ++fail_count
}


* XV6: Time-windowed results vs manual date filtering + regexm
local ++test_count
capture noisily {
    clear
    set obs 30
    gen long pid = ceil(_n / 3)
    gen str10 dx1 = ""
    replace dx1 = "E110" if mod(_n, 2) == 0
    replace dx1 = "Z00" if dx1 == ""
    gen double index_dt = 22000
    gen double visit_dt = 21800 + _n * 10
    format visit_dt index_dt %td

    * Manual: lookback(100) exclusive of refdate → [21900, 22000)
    gen byte manual_dm2 = 0
    replace manual_dm2 = 1 if regexm(dx1, "^(E11)") & ///
        visit_dt >= index_dt - 100 & visit_dt < index_dt & ///
        !missing(visit_dt) & !missing(index_dt)

    * codescan
    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(100)

    assert dm2 == manual_dm2
}
if _rc == 0 {
    display as result "  PASS: XV6 - Time window vs manual date filter + regexm"
    local ++pass_count
}
else {
    display as error "  FAIL: XV6 - Time window vs manual date filter + regexm (error `=_rc')"
    local ++fail_count
}


* XV7: Summary matrix counts match manual tabulation
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str10 dx1 = ""
    replace dx1 = "E110" if mod(_n, 4) == 0
    replace dx1 = "I10"  if mod(_n, 5) == 0 & dx1 == ""
    replace dx1 = "E660" if mod(_n, 7) == 0 & dx1 == ""
    replace dx1 = "Z00" if dx1 == ""

    * Manual counts
    gen byte m_dm2 = regexm(dx1, "^(E11)")
    gen byte m_htn = regexm(dx1, "^(I10)")
    gen byte m_obe = regexm(dx1, "^(E66)")
    quietly count if m_dm2 == 1
    local manual_dm2 = r(N)
    quietly count if m_htn == 1
    local manual_htn = r(N)
    quietly count if m_obe == 1
    local manual_obe = r(N)
    drop m_dm2 m_htn m_obe

    * codescan
    codescan dx1, define(dm2 "E11" | htn "I10" | obesity "E66")
    matrix S = r(summary)

    assert S[1,1] == `manual_dm2'
    assert S[2,1] == `manual_htn'
    assert S[3,1] == `manual_obe'
    assert abs(S[1,2] - `manual_dm2' / 100 * 100) < 0.01
    assert abs(S[2,2] - `manual_htn' / 100 * 100) < 0.01
    assert abs(S[3,2] - `manual_obe' / 100 * 100) < 0.01
}
if _rc == 0 {
    display as result "  PASS: XV7 - Summary matrix vs manual tabulation"
    local ++pass_count
}
else {
    display as error "  FAIL: XV7 - Summary matrix vs manual tabulation (error `=_rc')"
    local ++fail_count
}


* XV8: Collapsed indicator==1 iff any pre-collapse row had match (preserve/restore)
local ++test_count
capture noisily {
    clear
    set obs 60
    gen long pid = ceil(_n / 6)
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    replace dx1 = "E110" if mod(_n, 4) == 0
    replace dx2 = "E119" if mod(_n, 7) == 0
    replace dx1 = "I10"  if mod(_n, 5) == 0 & dx1 == ""
    replace dx1 = "Z00" if dx1 == "" & dx2 == ""

    * Pre-collapse: manually flag which patients have matches
    gen byte any_dm2 = (regexm(dx1, "^(E11)") | regexm(dx2, "^(E11)"))
    bysort pid: egen byte patient_dm2 = max(any_dm2)

    preserve
    collapse (max) patient_dm2, by(pid)
    tempfile manual
    save `manual'
    restore

    drop any_dm2 patient_dm2

    * codescan collapse
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse

    merge 1:1 pid using `manual', nogenerate

    * Collapsed indicator must equal manual patient-level flag
    assert dm2 == patient_dm2
}
if _rc == 0 {
    display as result "  PASS: XV8 - Collapse iff any row matched (preserve/restore)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV8 - Collapse iff any row matched (error `=_rc')"
    local ++fail_count
}


* XV9: Sort invariance — reordering data produces same collapsed result
* The complete result dataset is compared across three permutations, plus an
* independent expectation so a bug that is identical under every order still
* fails. cf _all walks only the master's varlist, so a variable dropped under
* one ordering would slip past it; datasignature covers names and count.
capture program drop _xv9_data
program define _xv9_data
    clear
    quietly set obs 7
    quietly gen long pid = .
    quietly gen str10 dx1 = ""
    quietly gen str10 dx2 = ""
    quietly gen double visit_dt = .
    local pids 1 1 1 2 2 3 3
    local d1s E110 Z00 Z00 I10 Z00 E110 E110
    local d2s . E119 . . . . .
    local dts 21900 21910 21920 21900 21910 21950 21960
    forvalues i = 1/7 {
        quietly replace pid = `: word `i' of `pids'' in `i'
        quietly replace dx1 = "`: word `i' of `d1s''" in `i'
        local _d2 : word `i' of `d2s'
        if "`_d2'" != "." quietly replace dx2 = "`_d2'" in `i'
        quietly replace visit_dt = `: word `i' of `dts'' in `i'
    }
    format visit_dt %td
end

local ++test_count
capture noisily {
    _xv9_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate
    sort pid
    tempfile result_orig
    quietly save `result_orig'
    quietly ds
    local vars_orig `r(varlist)'
    quietly datasignature
    local sig_orig `r(datasignature)'

    * Hand-computed from the seven input rows above.
    assert _N == 3
    assert dm2[1] == 1 & dm2[2] == 0 & dm2[3] == 1
    assert dm2_count[1] == 2 & dm2_count[2] == 0 & dm2_count[3] == 2
    assert dm2_first[1] == 21900 & dm2_last[1] == 21910
    assert dm2_first[3] == 21950 & dm2_last[3] == 21960

    * p1 reverse, p2 grouped by code with pid descending, p3 seeded shuffle
    forvalues p = 1/3 {
        _xv9_data
        if `p' == 1 {
            gen double _k = -_n
            sort _k
            drop _k
        }
        else if `p' == 2 {
            gsort dx1 -pid
        }
        else {
            set seed 90210
            gen double _k = runiform()
            sort _k
            drop _k
        }
        codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
            earliestdate latestdate countdate
        sort pid
        quietly ds
        assert "`r(varlist)'" == "`vars_orig'"
        quietly datasignature
        assert "`r(datasignature)'" == "`sig_orig'"
        cf _all using `result_orig'
    }
}
if _rc == 0 {
    display as result "  PASS: XV9 - Sort invariance for collapsed results"
    local ++pass_count
}
else {
    display as error "  FAIL: XV9 - Sort invariance (error `=_rc')"
    local ++fail_count
}


* XV10: Idempotency — running twice with replace gives same results
local ++test_count
capture noisily {
    clear
    set obs 20
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    replace dx1 = "E110" if mod(_n, 3) == 0
    replace dx2 = "I10"  if mod(_n, 4) == 0
    replace dx1 = "Z00" if dx1 == ""

    * First run
    codescan dx1 dx2, define(dm2 "E11" | htn "I10")
    gen byte dm2_run1 = dm2
    gen byte htn_run1 = htn

    * Second run with replace
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") replace

    assert dm2 == dm2_run1
    assert htn == htn_run1
}
if _rc == 0 {
    display as result "  PASS: XV10 - Idempotency (replace gives same result)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV10 - Idempotency (error `=_rc')"
    local ++fail_count
}


* XV11: Bidirectional window vs manual computation
local ++test_count
capture noisily {
    clear
    set obs 20
    gen long pid = _n
    gen str10 dx1 = "E110"
    gen double index_dt = 22000
    gen double visit_dt = 21800 + _n * 20
    format visit_dt index_dt %td

    * Manual: lookback(100) + lookforward(50) → [21900, 22050] inclusive
    gen byte manual = 0
    replace manual = 1 if regexm(dx1, "^(E11)") & ///
        visit_dt >= index_dt - 100 & visit_dt <= index_dt + 50 & ///
        !missing(visit_dt) & !missing(index_dt)

    * codescan
    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(100) lookforward(50)

    assert dm2 == manual
}
if _rc == 0 {
    display as result "  PASS: XV11 - Bidirectional window vs manual"
    local ++pass_count
}
else {
    display as error "  FAIL: XV11 - Bidirectional window vs manual (error `=_rc')"
    local ++fail_count
}


* XV12: Windowed collapse with countdate vs manual end-to-end
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt double index_dt
    1 "E110" ""     21850 22000
    1 "E119" ""     21920 22000
    1 "Z00"  "E110" 21920 22000
    1 "E110" ""     21950 22000
    1 "Z00"  ""     22010 22000
    2 "E110" ""     21800 22000
    2 "E110" ""     21950 22000
    2 "Z00"  ""     22010 22000
    3 "Z00"  ""     21950 22000
    3 "Z00"  ""     22010 22000
    end
    format visit_dt index_dt %td

    * Manual: lookback(100) inclusive → [21900, 22000]
    * Pid 1: row 1 (21850) outside, row 2-3 (21920) inside match, row 4 (21950) inside match
    *   → dm2=1, first=21920, last=21950, count=2 unique dates (21920, 21950)
    * Pid 2: row 1 (21800) outside, row 2 (21950) inside match → dm2=1, count=1
    * Pid 3: no match → dm2=0

    * codescan
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(100) inclusive collapse earliestdate latestdate countdate

    assert _N == 3
    assert dm2 == 1 if pid == 1
    assert dm2_first == 21920 if pid == 1
    assert dm2_last == 21950 if pid == 1
    assert dm2_count == 2 if pid == 1
    assert dm2 == 1 if pid == 2
    assert dm2_first == 21950 if pid == 2
    assert dm2_last == 21950 if pid == 2
    assert dm2_count == 1 if pid == 2
    assert dm2 == 0 if pid == 3
    assert missing(dm2_first) if pid == 3
    assert dm2_count == 0 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: XV12 - Windowed collapse+countdate vs manual end-to-end"
    local ++pass_count
}
else {
    display as error "  FAIL: XV12 - Windowed collapse+countdate end-to-end (error `=_rc')"
    local ++fail_count
}


* XV13: Large-scale regex vs manual (200 rows, 8 conditions)
local ++test_count
capture noisily {
    clear
    set seed 77777
    set obs 200
    gen long pid = ceil(_n / 4)
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""
    gen str10 dx4 = ""
    * Scatter ICD codes
    quietly {
        replace dx1 = "E110" if runiform() < 0.12
        replace dx1 = "I10"  if dx1 == "" & runiform() < 0.10
        replace dx1 = "I21"  if dx1 == "" & runiform() < 0.08
        replace dx1 = "J45"  if dx1 == "" & runiform() < 0.06
        replace dx1 = "F32"  if dx1 == "" & runiform() < 0.05
        replace dx1 = "C34"  if dx1 == "" & runiform() < 0.04
        replace dx1 = "Z00" if dx1 == ""
        replace dx2 = "E119" if runiform() < 0.08
        replace dx2 = "I13"  if dx2 == "" & runiform() < 0.06
        replace dx2 = "I25"  if dx2 == "" & runiform() < 0.05
        replace dx3 = "E660" if runiform() < 0.05
        replace dx3 = "K21"  if dx3 == "" & runiform() < 0.04
        replace dx4 = "F33"  if runiform() < 0.03
    }

    * Manual regexm loop
    gen byte m_dm2 = 0
    gen byte m_htn = 0
    gen byte m_cvd = 0
    gen byte m_copd = 0
    gen byte m_dep = 0
    gen byte m_obe = 0
    gen byte m_can = 0
    gen byte m_gerd = 0
    foreach v in dx1 dx2 dx3 dx4 {
        quietly {
            replace m_dm2  = 1 if regexm(`v', "^(E11)") & m_dm2 == 0
            replace m_htn  = 1 if regexm(`v', "^(I1[0-35])") & m_htn == 0
            replace m_cvd  = 1 if regexm(`v', "^(I2[0-5])") & m_cvd == 0
            replace m_copd = 1 if regexm(`v', "^(J4[4-7])") & m_copd == 0
            replace m_dep  = 1 if regexm(`v', "^(F3[23])") & m_dep == 0
            replace m_obe  = 1 if regexm(`v', "^(E66)") & m_obe == 0
            replace m_can  = 1 if regexm(`v', "^(C[0-9])") & m_can == 0
            replace m_gerd = 1 if regexm(`v', "^(K21)") & m_gerd == 0
        }
    }

    codescan dx1-dx4, define(dm2 "E11" | htn "I1[0-35]" | cvd "I2[0-5]" | ///
        copd "J4[4-7]" | dep "F3[23]" | obe "E66" | can "C[0-9]" | gerd "K21")

    assert dm2 == m_dm2
    assert htn == m_htn
    assert cvd == m_cvd
    assert copd == m_copd
    assert dep == m_dep
    assert obe == m_obe
    assert can == m_can
    assert gerd == m_gerd
}
if _rc == 0 {
    display as result "  PASS: XV13 - Large-scale regex vs manual (200 rows x 8 conditions)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV13 - Large-scale regex (error `=_rc')"
    local ++fail_count
}


* XV14: Nocase vs manual strupper + standard scan
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "e110" "i10"
    "E119" "z00"
    "e11"  "I13"
    "Z00"  "e119"
    end

    * Manual: strupper everything, then regexm
    gen byte m_dm2 = 0
    gen byte m_htn = 0
    foreach v in dx1 dx2 {
        replace m_dm2 = 1 if regexm(strupper(`v'), "^(E11)") & m_dm2 == 0
        replace m_htn = 1 if regexm(strupper(`v'), "^(I1[0-35])") & m_htn == 0
    }

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") nocase

    assert dm2 == m_dm2
    assert htn == m_htn
}
if _rc == 0 {
    display as result "  PASS: XV14 - Nocase vs manual strupper"
    local ++pass_count
}
else {
    display as error "  FAIL: XV14 - Nocase vs strupper (error `=_rc')"
    local ++fail_count
}


* XV15: Exclusion vs manual regexm with negative filter
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E116"
    "E119"
    "E11"
    "I10"
    end

    * Manual: E11 match but NOT E116
    gen byte m_dm2 = 0
    replace m_dm2 = 1 if regexm(dx1, "^(E11)") & !regexm(dx1, "^(E116)")

    codescan dx1, define(dm2 "E11" ~ "E116")

    assert dm2 == m_dm2
}
if _rc == 0 {
    display as result "  PASS: XV15 - Exclusion vs manual negative filter"
    local ++pass_count
}
else {
    display as error "  FAIL: XV15 - Exclusion vs manual (error `=_rc')"
    local ++fail_count
}


* XV16: Countmode vs manual counting with multi-column
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E119" "I10"
    "E110" ""     "E110"
    "Z00"  "I10"  ""
    "I10"  "I10"  "I10"
    end

    * Manual count: count E11 matches across all columns
    gen int m_dm2 = 0
    gen int m_htn = 0
    foreach v in dx1 dx2 dx3 {
        replace m_dm2 = m_dm2 + (regexm(`v', "^(E11)"))
        replace m_htn = m_htn + (regexm(`v', "^(I10)"))
    }

    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") countmode

    assert dm2 == m_dm2
    assert htn == m_htn
}
if _rc == 0 {
    display as result "  PASS: XV16 - Countmode vs manual counting"
    local ++pass_count
}
else {
    display as error "  FAIL: XV16 - Countmode vs manual (error `=_rc')"
    local ++fail_count
}


* XV17: Merge vs collapse equivalence on patient-level indicators
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "I10"
    1 "Z00"  ""
    2 "I10"  ""
    2 "E119" "I13"
    3 "Z00"  "Z01"
    3 "Z02"  ""
    end

    * Run collapse
    preserve
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse
    tempfile collapsed
    rename dm2 c_dm2
    rename htn c_htn
    save `collapsed'
    restore

    * Run merge
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) merge
    merge m:1 pid using `collapsed', nogenerate

    * Merge indicators should match collapse indicators (broadcast)
    assert dm2 == c_dm2
    assert htn == c_htn
}
if _rc == 0 {
    display as result "  PASS: XV17 - Merge vs collapse equivalence"
    local ++pass_count
}
else {
    display as error "  FAIL: XV17 - Merge vs collapse (error `=_rc')"
    local ++fail_count
}


* XV18: Regex vs prefix mode equivalent for simple prefix patterns
local ++test_count
capture noisily {
    clear
    set seed 11111
    set obs 100
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    quietly {
        replace dx1 = "E110" if runiform() < 0.15
        replace dx1 = "I10"  if dx1 == "" & runiform() < 0.12
        replace dx1 = "J45"  if dx1 == "" & runiform() < 0.08
        replace dx1 = "Z00" if dx1 == ""
        replace dx2 = "E119" if runiform() < 0.10
        replace dx2 = "I13"  if dx2 == "" & runiform() < 0.08
    }

    * Run regex
    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | asthma "J45")
    gen byte regex_dm2 = dm2
    gen byte regex_htn = htn
    gen byte regex_asthma = asthma
    drop dm2 htn asthma

    * Run prefix with same patterns
    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | asthma "J45") mode(prefix)

    * Should be identical for simple prefix-like patterns
    assert dm2 == regex_dm2
    assert htn == regex_htn
    assert asthma == regex_asthma
}
if _rc == 0 {
    display as result "  PASS: XV18 - Regex vs prefix equivalent for simple patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: XV18 - Regex vs prefix (error `=_rc')"
    local ++fail_count
}


* XV20: Co-occurrence vs manual pairwise cross-tabulation
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E119" ""
    "I10"  ""
    "E110" "I10"
    "Z00"  ""
    end

    * Manual co-occurrence
    gen byte m_dm2 = (regexm(dx1, "^(E11)") | regexm(dx2, "^(E11)"))
    gen byte m_htn = (regexm(dx1, "^(I10)") | regexm(dx2, "^(I10)"))
    quietly count if m_dm2 == 1 & m_htn == 1
    local manual_overlap = r(N)
    quietly count if m_dm2 == 1
    local manual_dm2 = r(N)
    quietly count if m_htn == 1
    local manual_htn = r(N)
    drop m_dm2 m_htn

    codescan dx1 dx2, define(dm2 "E11" | htn "I10") cooccurrence
    matrix C = r(cooccurrence)

    assert C[1,1] == `manual_dm2'
    assert C[2,2] == `manual_htn'
    assert C[1,2] == `manual_overlap'
    assert C[2,1] == `manual_overlap'
}
if _rc == 0 {
    display as result "  PASS: XV20 - Co-occurrence vs manual cross-tabulation"
    local ++pass_count
}
else {
    display as error "  FAIL: XV20 - Co-occurrence (error `=_rc')"
    local ++fail_count
}


* XV21: Nodots vs manual subinstr + scan
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E11.0" "I.10"
    "E119"  ""
    "I1.3"  "E.119"
    "Z00"   ""
    end

    * Manual: strip dots, then regexm
    gen str10 clean_dx1 = subinstr(dx1, ".", "", .)
    gen str10 clean_dx2 = subinstr(dx2, ".", "", .)
    gen byte m_dm2 = 0
    gen byte m_htn = 0
    foreach v in clean_dx1 clean_dx2 {
        replace m_dm2 = 1 if regexm(`v', "^(E11)") & m_dm2 == 0
        replace m_htn = 1 if regexm(`v', "^(I1[0-35])") & m_htn == 0
    }
    drop clean_*

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") nodots

    assert dm2 == m_dm2
    assert htn == m_htn
}
if _rc == 0 {
    display as result "  PASS: XV21 - Nodots vs manual subinstr"
    local ++pass_count
}
else {
    display as error "  FAIL: XV21 - Nodots vs subinstr (error `=_rc')"
    local ++fail_count
}


* XV22: Export CSV round-trip (export → import → compare)
local ++test_count
capture noisily {
    clear
    set obs 30
    gen str10 dx1 = ""
    quietly {
        replace dx1 = "E110" if runiform() < 0.20
        replace dx1 = "I10"  if dx1 == "" & runiform() < 0.15
        replace dx1 = "Z00"  if dx1 == ""
    }

    codescan dx1, define(dm2 "E11" | htn "I10") ///
        export("_codescan_xv22.csv", replace)
    matrix S = r(summary)

    * Import and compare
    preserve
    import delimited using "_codescan_xv22.csv", clear
    assert condition[1] == "dm2"
    assert condition[2] == "htn"
    assert abs(matches[1] - S[1,1]) < 0.01
    assert abs(matches[2] - S[2,1]) < 0.01
    assert abs(prevalence[1] - S[1,2]) < 0.01
    assert abs(prevalence[2] - S[2,2]) < 0.01
    restore
}
if _rc == 0 {
    display as result "  PASS: XV22 - Export CSV round-trip"
    local ++pass_count
}
else {
    display as error "  FAIL: XV22 - Export CSV round-trip (error `=_rc')"
    local ++fail_count
}


* XV23: Frame output vs direct collapse (full equivalence)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" "I10"  21900
    1 "Z00"  ""     21910
    2 "I10"  ""     21920
    2 "E119" ""     21900
    3 "Z00"  ""     21910
    end
    format visit_dt %td

    * Direct collapse
    preserve
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") id(pid) ///
        date(visit_dt) collapse alldates
    local direct_N = _N
    local direct_dm2_1 = dm2[1]
    local direct_htn_2 = htn[2]
    local direct_dm2_count_1 = dm2_count[1]
    restore

    * Frame collapse
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") id(pid) ///
        date(visit_dt) collapse alldates frame(xv23_frame) replace

    frame xv23_frame {
        assert _N == `direct_N'
        assert dm2[1] == `direct_dm2_1'
        assert htn[2] == `direct_htn_2'
        assert dm2_count[1] == `direct_dm2_count_1'
    }
    capture frame drop xv23_frame
}
if _rc == 0 {
    display as result "  PASS: XV23 - Frame output vs direct collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: XV23 - Frame vs collapse (error `=_rc')"
    local ++fail_count
    capture frame drop xv23_frame
}


* XV24: Multi-window vs sequential single-window scans
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21550 21915
    1 "Z00"  21800 21915
    2 "E119" 21800 21915
    2 "Z00"  21900 21915
    3 "Z00"  21800 21915
    3 "Z00"  21900 21915
    end
    format visit_dt index_dt %td

    * Multi-window scan
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(180 365) collapse
    matrix MW = r(sensitivity)

    * Single-window 180d scan
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21550 21915
    1 "Z00"  21800 21915
    2 "E119" 21800 21915
    2 "Z00"  21900 21915
    3 "Z00"  21800 21915
    3 "Z00"  21900 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(180) collapse
    matrix S180 = r(summary)

    * Single-window 365d scan
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21550 21915
    1 "Z00"  21800 21915
    2 "E119" 21800 21915
    2 "Z00"  21900 21915
    3 "Z00"  21800 21915
    3 "Z00"  21900 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse
    matrix S365 = r(summary)

    * Multi-window prevalences should match individual scans. Both sides run
    * the same deterministic scan on the same rows, so this is exact equality —
    * a 0.5pp tolerance spans a whole patient in a 3-patient cohort.
    assert reldif(MW[1,1], S180[1,2]) < 1e-10
    assert reldif(MW[1,2], S365[1,2]) < 1e-10

    * Anchor both to hand-computed values: within 180d only pid 2 (21800) is in
    * window; within 365d pid 1 (21550) joins. 1/3 and 2/3 of the cohort.
    assert reldif(S180[1,2], 100/3) < 1e-8
    assert reldif(S365[1,2], 200/3) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: XV24 - Multi-window vs sequential single-window"
    local ++pass_count
}
else {
    display as error "  FAIL: XV24 - Multi-window vs sequential (error `=_rc')"
    local ++fail_count
}


* XV25: Codefile vs define() equivalence
local ++test_count
capture noisily {
    * Create codefile
    clear
    input str10 name str10 pattern str10 exclusion
    "dm2" "E11" "E116"
    "htn" "I10" ""
    end
    quietly export delimited using "_codescan_xv25.csv", replace

    * Test data
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E116" ""
    "E119" "I10"
    "Z00"  ""
    end

    * Run with define()
    codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I10")
    gen byte def_dm2 = dm2
    gen byte def_htn = htn
    drop dm2 htn

    * Run with codefile()
    codescan dx1 dx2, codefile("_codescan_xv25.csv")

    assert dm2 == def_dm2
    assert htn == def_htn
}
if _rc == 0 {
    display as result "  PASS: XV25 - Codefile vs define() equivalence"
    local ++pass_count
}
else {
    display as error "  FAIL: XV25 - Codefile vs define (error `=_rc')"
    local ++fail_count
}


* XV26: save() roundtrip equivalence (define → save → codefile)
local ++test_count
capture noisily {
    clear
    set obs 20
    gen str10 dx1 = ""
    quietly {
        replace dx1 = "E110" if runiform() < 0.2
        replace dx1 = "I10"  if dx1 == "" & runiform() < 0.15
        replace dx1 = "Z00"  if dx1 == ""
    }

    * First run with define + save
    codescan dx1, define(dm2 "E11" | htn "I10") ///
        save("_codescan_xv26.csv", replace)
    gen byte run1_dm2 = dm2
    gen byte run1_htn = htn
    drop dm2 htn

    * Second run loading the saved codefile
    codescan dx1, codefile("_codescan_xv26.csv")

    assert dm2 == run1_dm2
    assert htn == run1_htn
}
if _rc == 0 {
    display as result "  PASS: XV26 - save() roundtrip (define → CSV → codefile)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV26 - save() roundtrip (error `=_rc')"
    local ++fail_count
}


* XV27: Prefix level() vs manual substr truncation
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E120"
    "E210"
    "I10"
    "E11"
    end

    * Manual: level(2) truncates "E11" to "E1", so anything starting with E1 matches
    gen byte manual = (substr(dx1, 1, 2) == "E1")

    codescan dx1, define(dm2 "E11") mode(prefix) level(2)

    assert dm2 == manual
}
if _rc == 0 {
    display as result "  PASS: XV27 - Prefix level(2) vs manual substr truncation"
    local ++pass_count
}
else {
    display as error "  FAIL: XV27 - Prefix level truncation (error `=_rc')"
    local ++fail_count
}


* XV28: codescan_describe top codes vs manual tabulation
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" "E119"
    "I10"  "E110"
    "Z00"  ""
    "E110" ""
    end

    * Manual: count all codes
    * E110 appears in dx1 rows 1,2,3,5 = 4 times, dx2 rows 0 = 0 times → no wait
    * dx1: E110(row1), E110(row2), I10(row3), Z00(row4), E110(row5) → E110:3, I10:1, Z00:1
    * dx2: I10(row1), E119(row2), E110(row3) → I10:1, E119:1, E110:1
    * Combined: E110:4, I10:2, E119:1, Z00:1

    codescan_describe dx1 dx2, top(10)
    matrix T = r(top_codes)
    * Most frequent should be E110
    local rnames : rowfullnames T
    local first : word 1 of `rnames'
    assert "`first'" == "E110"
    assert T[1,1] == 4
    assert r(n_unique) == 4
    assert r(n_entries) == 8
}
if _rc == 0 {
    display as result "  PASS: XV28 - codescan_describe vs manual tabulation"
    local ++pass_count
}
else {
    display as error "  FAIL: XV28 - Describe vs manual (error `=_rc')"
    local ++fail_count
}


* XV29: Countmode collapse vs manual sum
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E119"
    1 "E113" ""
    1 "Z00"  ""
    2 "E110" ""
    2 "Z00"  "E110"
    3 "Z00"  ""
    end

    * Manual countmode collapse (sum)
    gen int m_dm2 = 0
    foreach v in dx1 dx2 {
        replace m_dm2 = m_dm2 + (regexm(`v', "^(E11)"))
    }
    preserve
    collapse (sum) m_dm2, by(pid)
    tempfile manual
    save `manual'
    restore

    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countmode

    merge 1:1 pid using `manual', nogenerate
    assert dm2 == m_dm2
}
if _rc == 0 {
    display as result "  PASS: XV29 - Countmode collapse vs manual sum"
    local ++pass_count
}
else {
    display as error "  FAIL: XV29 - Countmode collapse sum (error `=_rc')"
    local ++fail_count
}


* XV30: Tostring + prefix vs manual tostring + substr
local ++test_count
capture noisily {
    clear
    input double code1 double code2
    1100 100
    1190 130
    2100 450
    end

    * Manual: tostring then prefix match
    gen str10 s1 = string(code1)
    gen str10 s2 = string(code2)
    gen byte manual = (substr(s1,1,2) == "11" | substr(s2,1,2) == "11")
    drop s1 s2

    codescan code1 code2, define(cond_11 "11") mode(prefix) tostring

    assert cond_11 == manual
}
if _rc == 0 {
    display as result "  PASS: XV30 - Tostring + prefix vs manual"
    local ++pass_count
}
else {
    display as error "  FAIL: XV30 - Tostring + prefix (error `=_rc')"
    local ++fail_count
}


* XV34: Wilson score CI in r(summary) vs manual Wilson formula
local ++test_count
capture noisily {
    clear
    set obs 100
    gen str10 dx1 = "Z00"
    replace dx1 = "E110" in 1/20

    codescan dx1, define(dm2 "E11")
    matrix S = r(summary)
    local cnt = S[1, 1]
    local NN  = r(N)

    * Manual Wilson 95% CI (matches ado lines: max(0,..)*100, min(100,..)*100)
    local z      = invnormal(1 - (1 - c(level)/100)/2)
    local phat   = `cnt' / `NN'
    local z2n    = `z'^2 / `NN'
    local denom  = 1 + `z2n'
    local center = (`phat' + `z2n'/2) / `denom'
    local margin = `z' * sqrt((`phat'*(1 - `phat') + `z2n'/4) / `NN') / `denom'
    local lo     = max(0,   (`center' - `margin') * 100)
    local hi     = min(100, (`center' + `margin') * 100)

    assert S[1, 1] == 20
    assert reldif(S[1, 3], `lo') < 1e-8
    assert reldif(S[1, 4], `hi') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: XV34 - Wilson CI vs manual formula"
    local ++pass_count
}
else {
    display as error "  FAIL: XV34 - Wilson CI (error `=_rc')"
    local ++fail_count
}


* XV35: unmatched() vs manual no-condition-matched flag (strict 0/1)
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "I10"  "Z00"
    "Z00"  "Z01"  ""
    "I10"  ""     ""
    ""     ""     ""
    "Q99"  "R10"  "S20"
    end

    * Manual: row matches no condition iff neither dm2 nor htn hits any column
    gen byte m_dm2 = 0
    gen byte m_htn = 0
    foreach v in dx1 dx2 dx3 {
        replace m_dm2 = 1 if regexm(`v', "^(E11)")
        replace m_htn = 1 if regexm(`v', "^(I10)")
    }
    gen byte manual_unmatched = (m_dm2 == 0 & m_htn == 0)
    drop m_dm2 m_htn

    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") unmatched(nomatch)
    assert nomatch == manual_unmatched
}
if _rc == 0 {
    display as result "  PASS: XV35 - unmatched() vs manual no-match flag"
    local ++pass_count
}
else {
    display as error "  FAIL: XV35 - unmatched() (error `=_rc')"
    local ++fail_count
}


* XV36: matched_code() vs manual first-matched code (varlist order)
* Mata scans variable-by-variable, so the captured code is the first var
* (in varlist order) on that row that matches any condition.
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "Z00"  "E110" "I10"
    "E119" "I10"  ""
    "Z00"  "Z01"  "I10"
    "X99"  ""     ""
    end

    * Manual: first var in dx1,dx2,dx3 order matching any pattern
    gen str10 manual_mc = ""
    foreach v in dx1 dx2 dx3 {
        replace manual_mc = `v' if manual_mc == "" & ///
            (regexm(`v', "^(E11)") | regexm(`v', "^(I10)"))
    }

    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") matched_code(firstcode)
    assert firstcode == manual_mc
}
if _rc == 0 {
    display as result "  PASS: XV36 - matched_code() vs manual first-match"
    local ++pass_count
}
else {
    display as error "  FAIL: XV36 - matched_code() (error `=_rc')"
    local ++fail_count
}


* XV37: countrows vs manual per-patient row-match sum
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "I10"
    1 "E119" ""
    1 "Z00"  ""
    2 "E110" "E119"
    2 "Z00"  ""
    3 "Z00"  ""
    end

    * Manual: a row "matches dm2" if any column hits E11; sum matching rows per pid
    gen byte rowmatch = 0
    foreach v in dx1 dx2 {
        replace rowmatch = 1 if regexm(`v', "^(E11)")
    }
    collapse (sum) manual_nrows = rowmatch, by(pid)
    tempfile _nrows_manual
    save `_nrows_manual'

    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "I10"
    1 "E119" ""
    1 "Z00"  ""
    2 "E110" "E119"
    2 "Z00"  ""
    3 "Z00"  ""
    end
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countrows

    merge 1:1 pid using `_nrows_manual', nogenerate
    assert dm2_nrows == manual_nrows
    * Sanity: pid 1 has 2 matching rows, pid 2 has 1, pid 3 has 0
    assert dm2_nrows == 2 if pid == 1
    assert dm2_nrows == 1 if pid == 2
    assert dm2_nrows == 0 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: XV37 - countrows vs manual per-patient row sum"
    local ++pass_count
}
else {
    display as error "  FAIL: XV37 - countrows (error `=_rc')"
    local ++fail_count
}



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


* Summary
display ""
_codescan_qa_publish "validation_codescan_crosscheck" `test_count' `pass_count' `fail_count'
display as result "RESULT: validation_codescan_crosscheck tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Cross-check Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME CROSS-VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL CROSS-VALIDATIONS PASSED"
}
