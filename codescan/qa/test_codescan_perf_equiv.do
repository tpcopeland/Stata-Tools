* test_codescan_perf_equiv.do
* Equivalence + determinism guard for the distinct-value memoization in
* _codescan_mata_scan (v2.0.4). The scan classifies each distinct code value
* once and reuses it; these tests prove the memoized result equals an independent
* brute-force reference and is independent of row (encounter) order.

clear all
version 16.0
set varabbrev off

capture log close _all
log using "test_codescan_perf_equiv.log", text replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

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

discard

* Adversarial code pool: heavy repetition, codes that differ only past the prefix
* length, codes matching multiple conditions, and codes hitting the exclusion.
program define _pe_build
    args nobs seed
    clear
    quietly set obs `nobs'
    set seed `seed'
    local pool E110 E119 E116 E11 e110 I10 I11 I15 I20 E660 E6601 Z000 R69 "" K210 N180 å250 Å251
    local npool : word count `pool'
    forvalues v = 1/6 {
        quietly gen str8 dx`v' = ""
        quietly replace dx`v' = word("`pool'", 1 + int(runiform() * `npool'))
    }
    quietly gen long pid = _n
end

**# 1. Equivalence vs independent brute-force reference (regex, exclusion, detail)

local ++test_count
capture noisily {
    _pe_build 4000 101
    * Reference (PER-CELL semantics, as documented): a row matches dm2 if ANY
    * single cell starts E11 and that same cell does NOT start E116 — a valid
    * code in one variable is not zeroed by an excluded code in another.
    quietly gen byte ref_dm2 = 0
    quietly gen byte ref_htn = 0
    forvalues v = 1/6 {
        quietly replace ref_dm2 = 1 if regexm(dx`v', "^(E11)") & !regexm(dx`v', "^(E116)")
        quietly replace ref_htn = 1 if regexm(dx`v', "^(I1[0-35])")
    }
    codescan dx1-dx6, define(dm2 "E11" ~ "E116" | htn "I1[0-35]") mode(regex)
    assert dm2 == ref_dm2
    assert htn == ref_htn
}
if _rc == 0 {
    display as result "  PASS: memoized regex+exclusion == brute-force reference"
    local ++pass_count
}
else {
    display as error "  FAIL: memoized regex+exclusion == brute-force reference (error `=_rc')"
    local ++fail_count
}

**# 2. Encounter-order independence (shuffle rows → identical per-pid results)

local ++test_count
capture noisily {
    _pe_build 4000 202
    codescan dx1-dx6, define(dm2 "E11" ~ "E116" | htn "I1[0-35]" | k "K2") mode(regex)
    quietly gen byte a_dm2 = dm2
    quietly gen byte a_htn = htn
    quietly gen byte a_k = k
    quietly keep pid a_dm2 a_htn a_k
    tempfile base
    quietly save "`base'"

    _pe_build 4000 202
    * Shuffle the row order; per-pid classification must be identical.
    set seed 999
    quietly gen double _u = runiform()
    sort _u
    codescan dx1-dx6, define(dm2 "E11" ~ "E116" | htn "I1[0-35]" | k "K2") mode(regex)
    quietly merge 1:1 pid using "`base'", assert(match) nogenerate
    assert dm2 == a_dm2
    assert htn == a_htn
    assert k   == a_k
}
if _rc == 0 {
    display as result "  PASS: results independent of row order"
    local ++pass_count
}
else {
    display as error "  FAIL: results independent of row order (error `=_rc')"
    local ++fail_count
}

**# 3. countmode total equals brute-force per-cell match count

local ++test_count
capture noisily {
    _pe_build 3000 303
    * Reference count: number of cells (over 6 vars) starting with E11, NOT E116.
    quietly gen int ref_cnt = 0
    forvalues v = 1/6 {
        quietly replace ref_cnt = ref_cnt + 1 if regexm(dx`v', "^(E11)") & !regexm(dx`v', "^(E116)")
    }
    codescan dx1-dx6, define(dm2 "E11" ~ "E116") mode(regex) countmode
    assert dm2 == ref_cnt
}
if _rc == 0 {
    display as result "  PASS: countmode total == brute-force cell count"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode total == brute-force cell count (error `=_rc')"
    local ++fail_count
}

**# 4. nocase + nodots equivalence (unicode fold + dot strip)

local ++test_count
capture noisily {
    _pe_build 3000 404
    * Insert dotted + mixed-case variants to exercise nodots + nocase.
    quietly replace dx1 = "e1.16" in 1/50
    quietly replace dx2 = "å2.50" in 1/50
    quietly gen byte ref = 0
    forvalues v = 1/6 {
        quietly replace ref = 1 if regexm(ustrupper(subinstr(dx`v', ".", "", .)), "^(E11)")
    }
    codescan dx1-dx6, define(g "E11") mode(regex) nocase nodots
    assert g == ref
}
if _rc == 0 {
    display as result "  PASS: nocase+nodots == brute-force reference"
    local ++pass_count
}
else {
    display as error "  FAIL: nocase+nodots == brute-force reference (error `=_rc')"
    local ++fail_count
}

**# 5. matched_code = first matching original code in variable order

local ++test_count
capture noisily {
    clear
    set obs 3
    gen long pid = _n
    gen str8 dx1 = ""
    gen str8 dx2 = ""
    gen str8 dx3 = ""
    * Row 1: dx2 is the first matching var (dx1 empty); mc must be the dx2 value.
    replace dx1 = ""     in 1
    replace dx2 = "E110" in 1
    replace dx3 = "E119" in 1
    * Row 2: dx1 matches first.
    replace dx1 = "I10"  in 2
    replace dx3 = "E11"  in 2
    codescan dx1 dx2 dx3, define(dm "E11" | htn "I1[0-35]") mode(regex) matched_code(mc)
    assert mc == "E110" in 1
    assert mc == "I10"  in 2
}
if _rc == 0 {
    display as result "  PASS: matched_code = first matching original code"
    local ++pass_count
}
else {
    display as error "  FAIL: matched_code = first matching original code (error `=_rc')"
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


**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_codescan_perf_equiv tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_codescan_perf_equiv tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
