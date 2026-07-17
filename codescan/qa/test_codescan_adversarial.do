* test_codescan_adversarial.do - Adversarial behavior tests for codescan

clear all
version 16.0
set seed 98765

capture log close _all
log using "test_codescan_adversarial.log", text replace nomsg

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


**# State Preservation

local _orig_va = c(varabbrev)
local ++test_count
capture noisily {
    clear
    input byte seq str10 dx1 str10 dx2
    5 "Z00"  ""
    2 "E110" ""
    4 "I10"  "E119"
    1 ""     ""
    3 "E116" "E110"
    end
    gen str10 before_dx1 = dx1
    gen str10 before_dx2 = dx2
    local N_before = _N

    * Signature over the input columns only — the scan legitimately ADDS dm2
    * and htn, so a whole-dataset signature would fire on a correct run.
    * datasignature takes no varlist (a leading name parses as a subcommand),
    * hence the keep-inside-preserve.
    preserve
    keep seq dx1 dx2
    quietly datasignature
    local sig_before `r(datasignature)'
    restore

    set varabbrev on
    codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I10")

    assert _N == `N_before'
    preserve
    keep seq dx1 dx2
    quietly datasignature
    assert "`r(datasignature)'" == "`sig_before'"
    restore
    forvalues i = 1/`=_N' {
        assert dx1[`i'] == before_dx1[`i']
        assert dx2[`i'] == before_dx2[`i']
    }
    * The input is deliberately unsorted: row order is part of the contract.
    assert seq[1] == 5
    assert seq[2] == 2
    assert seq[3] == 4
    assert seq[4] == 1
    assert seq[5] == 3
    assert "`c(varabbrev)'" == "on"
}
local _sp_rc = _rc
* Restore unconditionally, outside the captured block, so an assertion failure
* above cannot leak varabbrev=on into every later test in this suite.
set varabbrev `_orig_va'
if `_sp_rc' == 0 {
    display as result "  PASS: row-level data and varabbrev preserved on success"
    local ++pass_count
}
else {
    display as error "  FAIL: row-level data and varabbrev preserved on success (error `_sp_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "Z00"
    end
    gen byte sentinel = 42

    set varabbrev off
    capture codescan dx1, define(dm2 "E11") mode(not_a_mode)
    assert _rc == 198
    assert "`c(varabbrev)'" == "off"
    capture confirm variable dm2
    assert _rc != 0
    assert sentinel == 42
}
if _rc == 0 {
    display as result "  PASS: varabbrev and data preserved after parse error"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev and data preserved after parse error (error `=_rc')"
    local ++fail_count
}

**# Cross-variable Exclusion and Count Paths

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3 byte exp_bin byte exp_count str10 exp_mc
    "E116" "E110" ""     1 1 "E110"
    "E110" "E116" "E119" 1 2 "E110"
    "E116" ""     ""     0 0 ""
    "E119" "E118" "E116" 1 2 "E119"
    "Z00"  "E116" "I10"  0 0 ""
    end

    codescan dx1 dx2 dx3, define(dm2 "E11" ~ "E116") matched_code(mc)
    rename dm2 got_bin
    rename mc got_mc

    codescan dx1 dx2 dx3, define(dm2 "E11" ~ "E116") countmode replace
    rename dm2 got_count

    forvalues i = 1/`=_N' {
        assert got_bin[`i'] == exp_bin[`i']
        assert got_count[`i'] == exp_count[`i']
        assert got_mc[`i'] == exp_mc[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: excluded code in one variable does not cancel valid code in another"
    local ++pass_count
}
else {
    display as error "  FAIL: cross-variable exclusion behavior (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 byte exp_dm2
    1 "E116" "E110" 1
    1 "Z00"  ""     1
    2 "E116" ""     0
    2 "Z00"  ""     0
    3 "E119" "E116" 1
    3 ""     ""     1
    end

    codescan dx1 dx2, define(dm2 "E11" ~ "E116") id(pid) merge
    forvalues i = 1/`=_N' {
        assert dm2[`i'] == exp_dm2[`i']
    }

    clear
    input long pid str10 dx1 str10 dx2 byte exp_dm2
    1 "E116" "E110" 1
    1 "Z00"  ""     1
    2 "E116" ""     0
    2 "Z00"  ""     0
    3 "E119" "E116" 1
    3 ""     ""     1
    end
    codescan dx1 dx2, define(dm2 "E11" ~ "E116") id(pid) collapse
    sort pid
    assert dm2[1] == 1
    assert dm2[2] == 0
    assert dm2[3] == 1
}
if _rc == 0 {
    display as result "  PASS: cross-variable exclusion survives merge and collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: cross-variable exclusion merge/collapse (error `=_rc')"
    local ++fail_count
}

**# Filters, Missing IDs, and Output Semantics

local ++test_count
capture noisily {
    * exp_unmatched follows the v3.0.0 I4 contract: 1 = analyzed and nothing
    * matched, 0 = analyzed and something matched, . = outside the analysis
    * sample. The two keepme==0 rows are filtered out by the if, so they are not
    * analyzed and must be missing -- previously they were 0, which was
    * indistinguishable from the row that genuinely matched.
    clear
    input byte keepme str10 dx1 byte exp_dm2 byte exp_unmatched str10 exp_mc
    1 "E110" 1 0 "E110"
    0 "E110" 0 . ""
    1 "Z00"  0 1 ""
    0 "Z00"  0 . ""
    end

    codescan dx1 if keepme, define(dm2 "E11") unmatched(nohit) matched_code(mc)
    forvalues i = 1/`=_N' {
        assert dm2[`i'] == exp_dm2[`i']
        assert nohit[`i'] == exp_unmatched[`i']
        assert mc[`i'] == exp_mc[`i']
    }
}
if _rc == 0 {
    display as result "  PASS: unmatched and matched_code respect if filter"
    local ++pass_count
}
else {
    display as error "  FAIL: unmatched and matched_code respect if filter (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input double pid str10 dx1 double visit_dt
    1 "E110" 21900
    . "E110" 21910
    2 "Z00"  21900
    . "Z00"  21920
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate countrows
    sort pid

    assert _N == 2
    assert pid[1] == 1
    assert dm2[1] == 1
    assert dm2_count[1] == 1
    assert dm2_nrows[1] == 1
    assert pid[2] == 2
    assert dm2[2] == 0
    assert dm2_count[2] == 0
    assert dm2_nrows[2] == 0
}
if _rc == 0 {
    display as result "  PASS: missing ids excluded from collapse without phantom group"
    local ++pass_count
}
else {
    display as error "  FAIL: missing ids excluded from collapse (error `=_rc')"
    local ++fail_count
}

**# Name Collisions and Cleanup

local ++test_count
capture noisily {
    clear
    input str10 dx1 byte dm2
    "E110" 9
    "Z00"  8
    end

    capture codescan dx1, define(dm2 "E11")
    assert _rc == 110
    assert dm2[1] == 9
    assert dm2[2] == 8

    codescan dx1, define(dm2 "E11") replace
    assert dm2[1] == 1
    assert dm2[2] == 0
}
if _rc == 0 {
    display as result "  PASS: output collision requires replace and replace is targeted"
    local ++pass_count
}
else {
    display as error "  FAIL: output collision/replace behavior (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dm2
    "E110" "source"
    "Z00"  "source"
    end

    capture codescan dx1 dm2, define(dm2 "E11") replace
    assert _rc == 198
    assert dm2[1] == "source"
    assert dm2[2] == "source"
}
if _rc == 0 {
    display as result "  PASS: replace cannot clobber scanned input variable"
    local ++pass_count
}
else {
    display as error "  FAIL: replace cannot clobber scanned input variable (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "Z00"
    end

    capture codescan dx1, define(dm2 "E11") matched_code(dm2)
    assert _rc == 198
    capture confirm variable dm2
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: duplicate output names rejected before partial variables"
    local ++pass_count
}
else {
    display as error "  FAIL: duplicate output names rejected before partial variables (error `=_rc')"
    local ++fail_count
}

**# Preserve and Frame

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "Z00"  21910
    2 "I10"  21900
    2 "Z00"  21920
    end
    format visit_dt %td
    gen byte original_order = _n

    capture frame drop _adv_frame
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) date(visit_dt) ///
        collapse alldates frame(_adv_frame) replace

    assert _N == 4
    assert original_order[1] == 1
    capture confirm variable dm2
    assert _rc != 0

    frame _adv_frame {
        sort pid
        assert _N == 2
        assert dm2[1] == 1
        assert dm2_first[1] == 21900
        assert htn[1] == 0
        assert dm2[2] == 0
        assert htn[2] == 1
        assert htn_first[2] == 21900
    }
    capture frame drop _adv_frame
}
if _rc == 0 {
    display as result "  PASS: frame output preserves caller data and stores collapsed result"
    local ++pass_count
}
else {
    display as error "  FAIL: frame output preservation (error `=_rc')"
    local ++fail_count
    capture frame drop _adv_frame
}

**# Return Contract Under Adversarial Options

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt double index_dt
    1 "E110" "I10" 21900 21915
    1 "Z00"  ""    21910 21915
    2 "E116" "I13" 21900 21915
    2 "E119" ""    21915 21915
    3 "Z00"  ""    21900 21915
    end
    format visit_dt index_dt %td

    codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I1[0-35]") ///
        id(pid) date(visit_dt) refdate(index_dt) lookback(30) inclusive ///
        merge countrows cooccurrence matched_code(mc) unmatched(nohit) detail

    local rN = r(N)
    local rvars "`r(varlist)'"
    local rcond "`r(conditions)'"
    local rnew "`r(newvars)'"
    local rid "`r(id)'"
    local rdate "`r(date)'"
    local rref "`r(refdate)'"
    local rlb = r(lookback)
    matrix S = r(summary)
    matrix C = r(cooccurrence)
    matrix V = r(varcounts)

    assert `rN' == 3
    assert "`rvars'" == "dx1 dx2"
    assert "`rcond'" == "dm2 htn"
    assert strpos("`rnew'", "dm2_nrows") > 0
    assert strpos("`rnew'", "mc") > 0
    assert strpos("`rnew'", "nohit") > 0
    assert "`rid'" == "pid"
    assert "`rdate'" == "visit_dt"
    assert "`rref'" == "index_dt"
    assert `rlb' == 30
    assert S[1,1] == 2
    assert S[2,1] == 2
    assert C[1,1] == 2
    assert C[2,2] == 2
    assert C[1,2] == 2
    assert V[1,1] == 2
    assert V[2,1] == 0
    assert V[2,2] == 2
}
if _rc == 0 {
    display as result "  PASS: return contract with merge, filters, detail, and cooccurrence"
    local ++pass_count
}
else {
    display as error "  FAIL: return contract with adversarial options (error `=_rc')"
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
display "RESULT: test_codescan_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
log close _all
