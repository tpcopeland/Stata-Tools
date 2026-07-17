* test_documentation_examples.do - README/sthlp documentation reality tests
* Date: 2026-04-17

clear all
set seed 24680
version 16.0

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


capture program drop _load_codescan_setup
program define _load_codescan_setup
    clear
    set obs 5
    gen long pid = .
    gen str6 dx1 = ""
    gen str6 dx2 = ""
    gen str6 proc1 = ""
    gen double visit_dt = .
    gen double index_dt = .

    replace pid = 1 in 1/2
    replace pid = 2 in 3/4
    replace pid = 3 in 5

    replace dx1 = "E110" in 1
    replace dx1 = "Z00"  in 2
    replace dx1 = "I50"  in 3
    replace dx1 = "E102" in 4
    replace dx1 = "Z00"  in 5

    replace dx2 = "I10"  in 1
    replace dx2 = "E119" in 2

    replace proc1 = "XF001" in 1
    replace proc1 = "JFB10" in 3

    replace visit_dt = 21914 in 1
    replace visit_dt = 21880 in 2
    replace visit_dt = 21900 in 3
    replace visit_dt = 22020 in 4
    replace visit_dt = 21910 in 5

    replace index_dt = 21915 in 1/5
    format visit_dt index_dt %td
end

capture program drop _load_describe_setup
program define _load_describe_setup
    clear
    set obs 4
    gen str6 dx1 = ""
    gen str6 dx2 = ""

    replace dx1 = "E110" in 1
    replace dx1 = "E119" in 2
    replace dx1 = "I50"  in 3

    replace dx2 = "I10" in 1
    replace dx2 = "Z00" in 2
end

capture erase "`qa_dir'/dm_rules.csv"
capture erase "`qa_dir'/chapter_rules.csv"
capture erase "`qa_dir'/codescan_results.xlsx"
capture erase "`qa_dir'/codescan_results.dta"

* ============================================================
* README/sthlp examples for codescan
* ============================================================

local ++test_count
capture noisily {
    _load_codescan_setup
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]" | chf "I50")
    assert dm2 == 1 in 1
    assert htn == 1 in 1
    assert dm2 == 1 in 2
    assert chf == 1 in 3
    assert dm2 == 0 in 4
    assert htn == 0 in 5
}
if _rc == 0 {
    display as result "  PASS: README row-level indicators example"
    local ++pass_count
}
else {
    display as error "  FAIL: README row-level indicators example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str6 dx1 str6 dx2 str6 proc1
    "E110" "I10" "XF001"
    "E102" "I14" "JFB10"
    "C77"  "C80" ""
    "AE11" "I15" "XF002"
    end

    codescan dx*, define(dm "E1[01]" | htn "I1[0-35]" | metastatic "C7[7-9]|C80")
    assert dm == 1 in 1
    assert dm == 1 in 2
    assert dm == 0 in 3
    assert dm == 0 in 4
    assert htn == 1 in 1
    assert htn == 0 in 2
    assert htn == 0 in 3
    assert htn == 1 in 4
    assert metastatic == 1 in 3

    drop dm htn metastatic
    codescan dx1-dx2, define(dm "E1[01]" | htn "I1[0-35]" | metastatic "C7[7-9]|C80") detail
    assert "`r(varlist)'" == "dx1 dx2"
    matrix VC = r(varcounts)
    assert colsof(VC) == 2
    matrix drop VC

    codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
    assert mammo == 1 in 1
    assert mammo == 1 in 4
    assert colectomy == 1 in 2
}
if _rc == 0 {
    display as result "  PASS: README beginner regex and varlist examples"
    local ++pass_count
}
else {
    display as error "  FAIL: README beginner regex and varlist examples (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_setup
    codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///
        define(dm2 "E11" | htn "I1[0-35]" | chf "I50") ///
        lookback(365) inclusive collapse alldates
    assert _N == 3
    assert dm2 == 1 if pid == 1
    assert htn == 1 if pid == 1
    assert chf == 0 if pid == 1
    assert dm2_first == 21880 if pid == 1
    assert dm2_last == 21914 if pid == 1
    assert dm2_count == 2 if pid == 1
    assert chf == 1 if pid == 2
    assert chf_first == 21900 if pid == 2
    assert dm2 == 0 if pid == 2
    assert dm2 == 0 if pid == 3
    assert htn == 0 if pid == 3
    assert chf == 0 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: README collapse + window example"
    local ++pass_count
}
else {
    display as error "  FAIL: README collapse + window example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_setup
    codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)
    assert mammo == 1 in 1
    assert mammo == 0 in 3
    assert colectomy == 1 in 3
    assert colectomy == 0 in 1
}
if _rc == 0 {
    display as result "  PASS: README prefix example"
    local ++pass_count
}
else {
    display as error "  FAIL: README prefix example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_codescan_setup
    capture erase "`qa_dir'/codescan_results.xlsx"
    capture erase "`qa_dir'/codescan_results.dta"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
        export(codescan_results.xlsx) ///
        saving(codescan_results.dta, replace) ///
        format(%9.2f)

    confirm file "`qa_dir'/codescan_results.xlsx"
    confirm file "`qa_dir'/codescan_results.dta"

    preserve
    use "`qa_dir'/codescan_results.dta", clear
    assert _N == 3
    assert dm2 == 1 if pid == 1
    assert htn == 1 if pid == 1
    assert dm2 == 0 if pid == 2
    assert htn == 0 if pid == 2
    restore

    preserve
    import excel using "`qa_dir'/codescan_results.xlsx", firstrow clear
    confirm variable condition
    confirm variable matches
    confirm variable prevalence
    assert _N == 2
    sort condition
    assert matches == 1 if condition == "dm2"
    assert matches == 1 if condition == "htn"
    assert abs(prevalence - 33.33) < 0.01 if inlist(condition, "dm2", "htn")
    restore
}
if _rc == 0 {
    display as result "  PASS: README export + saving example"
    local ++pass_count
}
else {
    display as error "  FAIL: README export + saving example (error `=_rc')"
    local ++fail_count
}

* ============================================================
* README/sthlp examples for codescan_describe
* ============================================================

local ++test_count
capture noisily {
    _load_describe_setup
    codescan_describe dx1 dx2, top(10)
    assert r(n_unique) == 5
    assert r(n_entries) == 5
    assert r(n_vars) == 2
    matrix TC = r(top_codes)
    assert rowsof(TC) == 5
    assert colsof(TC) == 3
    matrix drop TC
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(10) example"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(10) example (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _load_describe_setup
    capture erase "`qa_dir'/chapter_rules.csv"
    codescan_describe dx1 dx2, save(chapter_rules.csv)
    confirm file "`qa_dir'/chapter_rules.csv"
    import delimited using "`qa_dir'/chapter_rules.csv", clear
    confirm variable name
    confirm variable pattern
    confirm variable exclusion
    confirm variable label
    count
    assert r(N) == 3
    count if name == "chapter_E" & pattern == "E"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save() example"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe save() example (error `=_rc')"
    local ++fail_count
}

* Regression: help Example 5 / README Example 7 run verbatim. The save() run
* leaves dm2/htn in memory; the codefile re-run on the SAME data must succeed
* (with the documented `replace`) and reproduce identical indicators. Without
* `replace` this stopped with r(110) "variable dm2 already exists".
local ++test_count
capture noisily {
    _load_codescan_setup
    capture erase "`qa_dir'/dm_rules.csv"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)
    confirm file "`qa_dir'/dm_rules.csv"
    * Capture the define()-pass indicators before re-running from the codefile
    tempvar dm2_def htn_def
    gen `dm2_def' = dm2
    gen `htn_def' = htn
    * Verbatim documented second line (same in-memory data, no reload)
    codescan dx1 dx2, codefile(dm_rules.csv) replace
    assert dm2 == `dm2_def'
    assert htn == `htn_def'
    capture erase "`qa_dir'/dm_rules.csv"
}
if _rc == 0 {
    display as result "  PASS: save() then codefile() reuse example (Example 5/7)"
    local ++pass_count
}
else {
    display as error "  FAIL: save() then codefile() reuse example (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Documented examples the suite previously omitted
* ============================================================
* The qa/README claimed "every documented example runs as shown" while the
* exclusion, frame, merge, multi-window, describe-nodots, if, and tostring
* examples were never exercised. Each block below is a documented example run
* as written, asserted against a hand-computed expectation.

* README Quick Start — the whole pasted block must run in one session, and the
* documented prevalences (row 40%, patient 33%) must be what it prints.
local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "E110" "I10"
    1 "Z00"  "E119"
    2 "I50"  ""
    2 "E102" ""
    3 "Z00"  ""
    end

    codescan_describe dx1 dx2

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]")
    assert r(N) == 5
    matrix _qs = r(summary)
    assert el(_qs, 1, 1) == 2
    assert reldif(el(_qs, 1, 2), 40) < 1e-8

    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse replace
    assert r(N) == 3
    matrix _qs2 = r(summary)
    assert el(_qs2, 1, 1) == 1
    assert reldif(el(_qs2, 1, 2), 100/3) < 1e-6
    matrix drop _qs _qs2
}
if _rc == 0 {
    display as result "  PASS: README Quick Start block (row 40% / patient 33%)"
    local ++pass_count
}
else {
    display as error "  FAIL: README Quick Start block (error `=_rc')"
    local ++fail_count
}

* Exclusion example: define(dm2 "E11" ~ "E116") — E11 codes except E116.
local ++test_count
capture noisily {
    clear
    input str6 dx1
    "E110"
    "E116"
    "E119"
    "Z00"
    end
    codescan dx1, define(dm2 "E11" ~ "E116")
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
    assert dm2 == 0 in 4
    assert r(N) == 4
}
if _rc == 0 {
    display as result "  PASS: documented exclusion example (~ E116)"
    local ++pass_count
}
else {
    display as error "  FAIL: documented exclusion example (error `=_rc')"
    local ++fail_count
}

* frame() example: original data untouched, collapsed result in the frame.
local ++test_count
capture noisily {
    _load_codescan_setup
    local n_before = _N
    capture frame drop results
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///
        frame(results) replace
    assert _N == `n_before'
    capture confirm variable dm2
    assert _rc != 0
    frame results {
        assert _N == 3
        assert dm2 == 1 in 1
    }
    frame drop results
}
if _rc == 0 {
    display as result "  PASS: documented frame() example (data untouched)"
    local ++pass_count
}
else {
    display as error "  FAIL: documented frame() example (error `=_rc')"
    local ++fail_count
    capture frame drop results
}

* merge example: every row of a pid carries the same patient-level value.
local ++test_count
capture noisily {
    _load_codescan_setup
    local n_before = _N
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) merge
    assert _N == `n_before'
    * pid 1 has E110 (row 1) and E119 (row 2) -> both rows get dm2 == 1
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    * pid 3 never matches
    assert dm2 == 0 in 5
}
if _rc == 0 {
    display as result "  PASS: documented merge example (broadcast to rows)"
    local ++pass_count
}
else {
    display as error "  FAIL: documented merge example (error `=_rc')"
    local ++fail_count
}

* Multi-window example: lookback(90 365) returns sensitivity + denominators.
local ++test_count
capture noisily {
    _load_codescan_setup
    codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///
        define(dm2 "E11" | htn "I1[0-35]") ///
        lookback(90 365) inclusive collapse
    matrix _sens = r(sensitivity)
    matrix _sensn = r(sensitivity_n)
    assert rowsof(_sens) == 2
    assert colsof(_sens) == 2
    assert rowsof(_sensn) == 1
    assert colsof(_sensn) == 2
    * Denominators must be positive and the wider window cannot analyze fewer.
    assert el(_sensn, 1, 1) > 0
    assert el(_sensn, 1, 2) >= el(_sensn, 1, 1)
    matrix drop _sens _sensn
}
if _rc == 0 {
    display as result "  PASS: documented multi-window example (+ r(sensitivity_n))"
    local ++pass_count
}
else {
    display as error "  FAIL: documented multi-window example (error `=_rc')"
    local ++fail_count
}

* codescan_describe nodots example: dotted and undotted forms merge.
local ++test_count
capture noisily {
    clear
    input str8 dx1
    "E11.9"
    "E119"
    "I10"
    end
    codescan_describe dx1, top(10) nodots
    matrix _tc = r(top_codes)
    * E11.9 and E119 collapse to one code with frequency 2
    assert rowsof(_tc) == 2
    assert el(_tc, 1, 1) == 2
    matrix drop _tc
}
if _rc == 0 {
    display as result "  PASS: documented codescan_describe nodots example"
    local ++pass_count
}
else {
    display as error "  FAIL: documented codescan_describe nodots example (error `=_rc')"
    local ++fail_count
}

* Documented `if` example: codescan_describe dx1 dx2 if dx1 != ""
local ++test_count
capture noisily {
    clear
    input str6 dx1 str6 dx2
    "E110" "I10"
    ""     "Z00"
    "I50"  ""
    end
    codescan_describe dx1 dx2 if dx1 != ""
    * Row 2 is excluded, so Z00 must not appear: 3 entries over 3 codes.
    assert r(n_unique) == 3
}
if _rc == 0 {
    display as result "  PASS: documented codescan_describe if example"
    local ++pass_count
}
else {
    display as error "  FAIL: documented codescan_describe if example (error `=_rc')"
    local ++fail_count
}

* Help Example 5: tostring on genuinely numeric codes, including a missing.
* The original numeric variables must survive unchanged and the numeric
* missing must not surface as a code.
local ++test_count
capture noisily {
    clear
    input icd9_1 icd9_2
    25000 4019
    25000 .
    4019  25001
    end
    quietly replace icd9_2 = .a in 2
    local t1 : type icd9_1
    codescan_describe icd9_1 icd9_2, tostring
    * 6 cells, 1 missing -> 5 entries; 3 distinct codes
    assert r(n_unique) == 3
    assert r(n_entries) == 5
    * Originals unchanged and still numeric
    local t2 : type icd9_1
    assert "`t1'" == "`t2'"
    assert icd9_1[1] == 25000
    assert icd9_2[2] == .a
}
if _rc == 0 {
    display as result "  PASS: documented tostring example (numeric codes + missing)"
    local ++pass_count
}
else {
    display as error "  FAIL: documented tostring example (error `=_rc')"
    local ++fail_count
}

* README example 12 / help example 10: hits vs cases, and slot attribution.
* The example's whole point is that the numbers differ, so the assertions here
* are the numbers a reader would compute from the two-slot patient it describes.
local ++test_count
capture noisily {
    * One patient with E11 in BOTH slots on one encounter, one with E11 in dx2
    * only: 3 slot hits, 2 cases.
    clear
    input long pid str6 dx1 str6 dx2
    1 "E110" "E119"
    1 "I10"  "Z00"
    2 "Z00"  "E118"
    end
    tempfile doc_slots
    quietly save `doc_slots'

    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countmode
    matrix S = r(summary)
    assert S[1,5] == 3      // total_hits: code slots
    assert S[1,6] == 2      // positive_units: patients
    assert reldif(S[1,2], 100) < 1e-6

    * detail credits the two-slot row to dx1 alone...
    quietly use `doc_slots', clear
    codescan dx1 dx2, define(dm2 "E11") detail
    matrix V = r(varcounts)
    assert V[1,1] == 1
    assert V[1,2] == 1
    assert r(detail_allslots) == 0

    * ... and allslots counts both of its slots.
    quietly use `doc_slots', clear
    codescan dx1 dx2, define(dm2 "E11") detail allslots
    matrix A = r(varcounts)
    assert A[1,1] == 1
    assert A[1,2] == 2
    assert r(detail_allslots) == 1
}
if _rc == 0 {
    display as result "  PASS: documented hits-vs-cases and allslots example"
    local ++pass_count
}
else {
    display as error "  FAIL: documented hits-vs-cases and allslots example (error `=_rc')"
    local ++fail_count
}

* README/help label() example: the demo block labels six conditions with the \
* separator, and the docs promise those labels reach the console and the export.
local ++test_count
capture noisily {
    _load_codescan_setup
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") ///
        label(dm2 "Type 2 diabetes" \ htn "Hypertension")
    local vl : variable label dm2
    assert "`vl'" == "Type 2 diabetes"
    * The identifier is unchanged by labelling -- the promise a do-file relies on.
    assert "`r(conditions)'" == "dm2 htn"
    matrix S = r(summary)
    local rn : rowfullnames S
    assert "`rn'" == "dm2 htn"
}
if _rc == 0 {
    display as result "  PASS: documented label() example"
    local ++pass_count
}
else {
    display as error "  FAIL: documented label() example (error `=_rc')"
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


display as result "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
