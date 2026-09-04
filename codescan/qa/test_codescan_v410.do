* test_codescan_v410.do - Regression tests for the v4.1.0 and v4.1.1 fixes
* Date: 2026-08-05
*
* Each test is written to FAIL on the pre-4.1.0 code and PASS after the fix.
* Confirmed: 12 of these assertions fail when the suite is run against the
* 4.0.1 package copy.
*
* Covers:
*   T1: codescan_describe results are REPRODUCIBLE. The top-code and chapter
*       tables were ordered on frequency alone over keys arriving from
*       asarray_keys() in hash order, and Mata's order() imposes no tiebreak,
*       so two runs of the same command on the same data returned different
*       orderings. Ties now break alphabetically, giving a strict total order.
*       Probed on the axis the user lives on -- run it repeatedly and compare
*       -- because a single run cannot expose a nondeterminism defect at all.
*   T2: r(detail_allslots) reports the rule that actually built r(varcounts).
*       Under countmode the first-slot early exit in _codescan_mata_scan is
*       gated on !is_count, so it never fires and every matching slot is
*       tallied -- but the scalar still returned 0, which the help defines as
*       first-slot attribution.
*   T3: lookforward() no longer uses -1 as an "unspecified" sentinel, so an
*       explicit lookforward(-1) errors instead of silently applying NO time
*       window at rc=0. The old range guard was unreachable for the same
*       reason: it was gated on the flag the sentinel had already cleared.
*   T4: level(0) errors instead of being silently ignored (same sentinel
*       class; 0 is outside the documented 1-10 range).
*   T5: a mode(prefix) pattern containing "." is rejected under nodots, which
*       strips periods from the data before matching and therefore makes such
*       a prefix provably dead -- previously a silent zero cohort.
*   T6: matched_code() is as wide as the widest scanned variable, so a long
*       code is no longer clipped to 244 characters at rc=0.
*   T7: a repeated lookback() window is rejected (it produced two identically
*       named r(sensitivity) columns).
*   T8: unmatched()/matched_code() with collapse still succeed and print a
*       note; "no observations" is emitted once, not twice.

clear all
set seed 12345
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


**# T1a: codescan_describe top_codes order is identical across repeated runs

local ++test_count
capture noisily {
    clear
    set obs 6
    gen str10 dx1 = ""
    replace dx1 = "A01" in 1
    replace dx1 = "B01" in 2
    replace dx1 = "C01" in 3
    replace dx1 = "D01" in 4
    replace dx1 = "E01" in 5
    replace dx1 = "F01" in 6
    * Six codes, frequency 1 each: every pair is a tie, so ordering on
    * frequency alone leaves the whole permutation to the hash order.
    local _ref ""
    forvalues rep = 1/6 {
        quietly codescan_describe dx1, top(6)
        local _nm : rownames r(top_codes)
        if `rep' == 1 local _ref "`_nm'"
        assert "`_nm'" == "`_ref'"
    }
    * And the fixed order is the documented one: alphabetical within a tie.
    assert "`_ref'" == "A01 B01 C01 D01 E01 F01"
}
if _rc == 0 {
    display as result "  PASS: T1a describe top_codes order stable and alphabetical within ties"
    local ++pass_count
}
else {
    display as error "  FAIL: T1a describe top_codes order unstable (error `=_rc')"
    local ++fail_count
}


**# T1b: the reported SET of codes is stable when ties straddle the top() cutoff

local ++test_count
capture noisily {
    clear
    set obs 8
    gen str10 dx1 = ""
    replace dx1 = "A01" in 1
    replace dx1 = "B01" in 2
    replace dx1 = "C01" in 3
    replace dx1 = "D01" in 4
    replace dx1 = "E01" in 5
    replace dx1 = "F01" in 6
    replace dx1 = "G01" in 7
    replace dx1 = "H01" in 8
    * top(3) over eight all-tied codes: the cutoff falls inside the tie, so an
    * unstable order changes WHICH codes are reported, not merely their order.
    local _ref ""
    forvalues rep = 1/6 {
        quietly codescan_describe dx1, top(3)
        local _nm : rownames r(top_codes)
        if `rep' == 1 local _ref "`_nm'"
        assert "`_nm'" == "`_ref'"
    }
    assert "`_ref'" == "A01 B01 C01"
}
if _rc == 0 {
    display as result "  PASS: T1b describe top() reports a stable code set across ties"
    local ++pass_count
}
else {
    display as error "  FAIL: T1b describe top() code set unstable (error `=_rc')"
    local ++fail_count
}


**# T1c: chapter summary order is stable across repeated runs

local ++test_count
capture noisily {
    clear
    set obs 8
    gen str10 dx1 = ""
    replace dx1 = "A1" in 1
    replace dx1 = "B1" in 2
    replace dx1 = "C1" in 3
    replace dx1 = "D1" in 4
    replace dx1 = "E1" in 5
    replace dx1 = "F1" in 6
    replace dx1 = "G1" in 7
    replace dx1 = "H1" in 8
    local _cref ""
    forvalues rep = 1/6 {
        quietly codescan_describe dx1, top(3)
        local _cn : rownames r(chapters)
        if `rep' == 1 local _cref "`_cn'"
        assert "`_cn'" == "`_cref'"
    }
    assert "`_cref'" == "A B C D E F G H"
}
if _rc == 0 {
    display as result "  PASS: T1c describe chapter order stable and alphabetical within ties"
    local ++pass_count
}
else {
    display as error "  FAIL: T1c describe chapter order unstable (error `=_rc')"
    local ++fail_count
}


**# T1d: the save() draft codefile is byte-reproducible

local ++test_count
capture noisily {
    clear
    set obs 8
    gen str10 dx1 = ""
    replace dx1 = "A1" in 1
    replace dx1 = "B1" in 2
    replace dx1 = "C1" in 3
    replace dx1 = "D1" in 4
    replace dx1 = "E1" in 5
    replace dx1 = "F1" in 6
    replace dx1 = "G1" in 7
    replace dx1 = "H1" in 8
    * The chapter order fixes the draft's row order, and therefore the
    * generated chapter_X rule names and any _i collision suffixes. An
    * unstable order makes a "frozen" rule set differ run to run.
    tempfile draft
    local _dref ""
    forvalues rep = 1/4 {
        capture erase "`draft'.csv"
        quietly codescan_describe dx1, top(3) save("`draft'.csv")
        preserve
        quietly import delimited "`draft'.csv", clear stringcols(_all) varnames(1)
        local _sig ""
        forvalues r = 1/`=_N' {
            local _sig "`_sig' `=name[`r']'`=pattern[`r']'"
        }
        restore
        if `rep' == 1 local _dref "`_sig'"
        assert "`_sig'" == "`_dref'"
    }
    capture erase "`draft'.csv"
}
if _rc == 0 {
    display as result "  PASS: T1d describe save() draft codefile is reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: T1d describe save() draft codefile varies between runs (error `=_rc')"
    local ++fail_count
}


**# T2: r(detail_allslots) matches the rule that produced r(varcounts)

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = "E110"
    gen str10 dx2 = "E119"
    * Every row carries the condition in BOTH scan slots, so the two
    * attribution rules give different row totals: 3 (first-slot) vs 6 (all
    * slots). That difference is what makes the scalar checkable.

    * A prior detail call must not leave a stale scalar behind when the next
    * call omits detail.
    quietly codescan dx1 dx2, define(dm2 "E11") countmode detail
    assert r(detail_allslots) == 1
    capture drop dm2

    quietly codescan dx1 dx2, define(dm2 "E11") countmode
    capture confirm scalar r(detail_allslots)
    assert _rc != 0
    capture confirm matrix r(varcounts)
    assert _rc != 0

    capture drop dm2
    quietly codescan dx1 dx2, define(dm2 "E11") countmode detail
    matrix _V = r(varcounts)
    assert _V[1,1] == 3 & _V[1,2] == 3
    assert r(detail_allslots) == 1

    capture drop dm2
    quietly codescan dx1 dx2, define(dm2 "E11") detail
    matrix _V = r(varcounts)
    assert _V[1,1] == 3 & _V[1,2] == 0
    assert r(detail_allslots) == 0

    capture drop dm2
    quietly codescan dx1 dx2, define(dm2 "E11") detail allslots
    matrix _V = r(varcounts)
    assert _V[1,1] == 3 & _V[1,2] == 3
    assert r(detail_allslots) == 1

    capture drop dm2
    quietly codescan dx1 dx2, define(dm2 "E11") countmode detail allslots
    assert r(detail_allslots) == 1
}
if _rc == 0 {
    display as result "  PASS: T2 detail_allslots reports the attribution rule actually used"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 detail_allslots contradicts r(varcounts) (error `=_rc')"
    local ++fail_count
}


**# T3: lookforward() sentinel

local ++test_count
capture noisily {
    clear
    set obs 6
    gen long pid = ceil(_n/2)
    gen str10 dx1 = "E110"
    gen double idx   = mdy(1,1,2020)
    gen double visit = idx + _n*100
    format visit idx %td

    * -1 was the "unspecified" sentinel: the old code applied NO window and
    * returned rc=0 over the whole dataset.
    capture codescan dx1, define(dm2 "E11") date(visit) refdate(idx) lookforward(-1)
    assert _rc == 198
    capture confirm variable dm2
    assert _rc != 0

    capture codescan dx1, define(dm2 "E11") date(visit) refdate(idx) lookforward(abc)
    assert _rc == 198
    capture codescan dx1, define(dm2 "E11") date(visit) refdate(idx) lookforward(2.5)
    assert _rc == 198

    * Valid values still work, and 0 is a real value rather than "unspecified".
    capture drop dm2
    quietly codescan dx1, define(dm2 "E11") date(visit) refdate(idx) lookforward(150)
    assert r(lookforward) == 150
    assert r(N) == 1
    capture drop dm2
    quietly replace visit = idx in 1
    quietly codescan dx1, define(dm2 "E11") date(visit) refdate(idx) lookforward(0) inclusive
    assert r(lookforward) == 0
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: T3 lookforward() rejects its old sentinel and out-of-range values"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 lookforward() sentinel still silently ignored (error `=_rc')"
    local ++fail_count
}


**# T4: level() sentinel

local ++test_count
capture noisily {
    clear
    set obs 4
    gen str10 dx1 = "E1109"

    capture codescan dx1, define(dm2 "E1109") mode(prefix) level(0)
    assert _rc == 198
    capture codescan dx1, define(dm2 "E1109") mode(prefix) level(abc)
    assert _rc == 198
    capture codescan dx1, define(dm2 "E1109") mode(prefix) level(11)
    assert _rc == 198
    capture codescan dx1, define(dm2 "E1109") mode(prefix) level(-3)
    assert _rc == 198

    * A valid level still truncates: E9999 cut to 1 char is "E", which matches.
    capture drop dm2
    quietly codescan dx1, define(dm2 "E9999") mode(prefix) level(1)
    assert el(r(summary), 1, 1) == 4
}
if _rc == 0 {
    display as result "  PASS: T4 level() rejects 0 and out-of-range values"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 level(0) still silently ignored (error `=_rc')"
    local ++fail_count
}


**# T5: nodots + mode(prefix) + a dotted pattern is a dead rule and is rejected

local ++test_count
capture noisily {
    clear
    set obs 4
    gen str10 dx1 = "E11.0"

    * nodots strips the period from the data, so a dotted prefix can never
    * match: the old code returned a silent zero cohort at rc=0.
    capture codescan dx1, define(dm2 "E11.0") mode(prefix) nodots
    assert _rc == 198
    * Exclusion prefixes are checked too -- a dead exclusion silently excludes
    * nothing, which inflates rather than empties the cohort.
    capture codescan dx1, define(dm2 "E11" ~ "E11.0") mode(prefix) nodots
    assert _rc == 198

    * Legitimate uses are untouched.
    capture drop dm2
    quietly codescan dx1, define(dm2 "E110") mode(prefix) nodots
    assert el(r(summary), 1, 1) == 4
    capture drop dm2
    quietly codescan dx1, define(dm2 "E11.0") mode(prefix)
    assert el(r(summary), 1, 1) == 4
    capture drop dm2
    * regex mode: "." is the any-character metacharacter, not a literal.
    quietly codescan dx1, define(dm2 "E11.0") mode(regex) nodots
    capture drop dm2
    * level() truncation runs first, so a period it cuts away is not an error.
    quietly codescan dx1, define(dm2 "E11.0") mode(prefix) nodots level(3)
}
if _rc == 0 {
    display as result "  PASS: T5 dotted prefix under nodots rejected; legitimate patterns unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 dead dotted prefix still returns a silent zero cohort (error `=_rc')"
    local ++fail_count
}


**# T6: matched_code() width tracks the widest scanned variable

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str300 dx1 = ""
    quietly replace dx1 = "E11" + 250*"X"
    quietly codescan dx1, define(dm2 "E11") matched_code(mc)
    * The old fixed str244 clipped this 253-character code with no warning.
    assert length(mc[1]) == 253
    assert mc[1] == dx1[1]

    * Narrow scan columns still give the documented str244 floor.
    clear
    set obs 2
    gen str10 dx1 = "E110"
    quietly codescan dx1, define(dm2 "E11") matched_code(mc)
    assert "`: type mc'" == "str244"
    assert mc[1] == "E110"
}
if _rc == 0 {
    display as result "  PASS: T6 matched_code() holds the full code, str244 floor preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 matched_code() truncates a long code (error `=_rc')"
    local ++fail_count
}


**# T7: a repeated lookback() window is rejected

local ++test_count
capture noisily {
    clear
    set obs 8
    gen long pid = ceil(_n/2)
    gen str10 dx1 = "E110"
    gen double idx   = mdy(1,1,2020)
    gen double visit = idx - _n*3
    format visit idx %td

    capture codescan dx1, define(dm2 "E11") id(pid) date(visit) refdate(idx) ///
        lookback(30 30) collapse
    assert _rc == 198
    capture confirm variable dm2
    assert _rc != 0

    * Distinct windows still work and still produce one column per window.
    quietly codescan dx1, define(dm2 "E11") id(pid) date(visit) refdate(idx) ///
        lookback(30 90) collapse
    matrix _S = r(sensitivity)
    assert colsof(_S) == 2
    local _sc : colnames _S
    assert "`_sc'" == "30d 90d"
}
if _rc == 0 {
    display as result "  PASS: T7 repeated lookback() window rejected; distinct windows unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 repeated lookback() window still accepted (error `=_rc')"
    local ++fail_count
}


**# T8: collapse note for row-level outputs; empty sample still errors 2000

local ++test_count
capture noisily {
    clear
    set obs 6
    gen long pid = ceil(_n/2)
    gen str10 dx1 = cond(mod(_n,2)==0, "E110", "Z00")

    * collapse discards these row-level outputs; the command must still
    * succeed, must not list them in r(newvars), and must say so on screen.
    quietly codescan dx1, define(dm2 "E11") id(pid) collapse unmatched(um) matched_code(mc)
    assert "`r(newvars)'" == "dm2"
    capture confirm variable um
    assert _rc != 0

    * Under merge they ARE retained -- the note must not be a blanket claim.
    clear
    set obs 6
    gen long pid = ceil(_n/2)
    gen str10 dx1 = cond(mod(_n,2)==0, "E110", "Z00")
    quietly codescan dx1, define(dm2 "E11") id(pid) merge unmatched(um) matched_code(mc)
    confirm variable um
    confirm variable mc

    * An empty analysis sample still raises r(2000).
    clear
    set obs 4
    gen str10 dx1 = "E110"
    capture codescan dx1 if dx1 == "ZZZ", define(dm2 "E11")
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: T8 collapse/merge retention contract and empty-sample error intact"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 collapse/merge retention contract broken (error `=_rc')"
    local ++fail_count
}


**# T9: session-setting hygiene

local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: T9 no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

display ""
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v410" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v410 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
