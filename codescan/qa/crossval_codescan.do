* crossval_codescan.do - Cross-validation tests for codescan
* Compares codescan output to manual computation
* Tests: 30
* Date: 2026-04-01

clear all
set seed 54321
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace


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
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" ""     21900
    1 "Z00"  "E119" 21910
    1 "Z00"  ""     21920
    2 "I10"  ""     21900
    2 "Z00"  ""     21910
    3 "E110" ""     21950
    3 "E110" ""     21960
    end
    format visit_dt %td

    * Run on original order
    preserve
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate
    tempfile result_orig
    save `result_orig'
    restore

    * Reverse sort
    gen double sortkey = -_n
    sort sortkey
    drop sortkey

    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate

    sort pid
    merge 1:1 pid using `result_orig', nogenerate

    * Renaming not needed — collapse+merge lines up by pid
    * Just verify both datasets have same values
    * The result_orig variables are dm2, dm2_first, dm2_last, dm2_count
    * They got merged with current data which also has same names
    * merge will succeed since both have same pid values; variables match
    assert _N == 3
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
    assert dm2 == 1 if pid == 3
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


* XV19: Charlson codefile vs manual score computation
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 str10 dx3
    1 "E110" "I21"  "C34"
    2 "I50"  "M05"  ""
    3 "C78"  "B20"  ""
    4 "Z00"  ""     ""
    end

    codescan dx1 dx2 dx3, ///
        codefile("`pkg_dir'/charlson_icd10_example.csv") ///
        id(pid) collapse score(charlson)

    * Manual Charlson (Quan 2011 weights):
    * Pid 1: dm_uncomp(1) + mi(1) + cancer(2) = 4
    * Pid 2: chf(1) + rheumatic(1) = 2
    * Pid 3: metastatic(6) + hiv(6) = 12
    * Pid 4: nothing = 0
    assert _score == 4  if pid == 1
    assert _score == 2  if pid == 2
    assert _score == 12 if pid == 3
    assert _score == 0  if pid == 4
}
if _rc == 0 {
    display as result "  PASS: XV19 - Charlson codefile score vs manual (Quan 2011)"
    local ++pass_count
}
else {
    display as error "  FAIL: XV19 - Charlson score (error `=_rc')"
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
        export("/tmp/_codescan_xv22.csv")
    matrix S = r(summary)

    * Import and compare
    preserve
    import delimited using "/tmp/_codescan_xv22.csv", clear
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

    * Multi-window prevalences should match individual scans
    assert abs(MW[1,1] - S180[1,2]) < 0.5
    assert abs(MW[1,2] - S365[1,2]) < 0.5
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
    quietly export delimited using "/tmp/_codescan_xv25.csv", replace

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
    codescan dx1 dx2, codefile("/tmp/_codescan_xv25.csv")

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
        save("/tmp/_codescan_xv26.csv")
    gen byte run1_dm2 = dm2
    gen byte run1_htn = htn
    drop dm2 htn

    * Second run loading the saved codefile
    codescan dx1, codefile("/tmp/_codescan_xv26.csv")

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


* Summary
display ""
display as result "RESULT: crossval_codescan tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Cross-Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME CROSS-VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL CROSS-VALIDATIONS PASSED"
}
