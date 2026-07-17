* test_mata_opt.do - Semantic tests for the Mata scanner optimizations
*
* The scanner classifies each DISTINCT value once (asarray memoization), then
* replays the result per cell with an early exit. Those optimizations must not
* change any answer. Every block here therefore compares codescan against a
* naive Stata-level oracle: one ustrregexm() per cell, no memoization, no
* distinct-value cache, no early exit, no views.
*
* The oracle mirrors the scanner's documented semantics exactly (codescan.ado
* Pass 2/Pass 3): a value matches condition k when ustrregexm(val, "^(pat)")
* is 1; exclusion is evaluated PER VALUE, not per row; empty and "." cells are
* skipped. Anchoring is "^(pat)", or "(?i)^(pat)" under nocase.
*
* Every block reloads an immutable fixture, so no block can inherit variables
* or row order from the one before it.

clear all
set varabbrev off
version 16.0

capture log close
log using "test_mata_opt.log", replace nomsg

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


local test_count = 0
local pass_count = 0
local fail_count = 0


**# Oracles

* Row-level binary indicator: 1 when ANY scan variable holds a matching code.
capture program drop _oracle_ind
program define _oracle_ind
    syntax varlist(string), NAMe(name) PATtern(string) [EXClude(string) NOCase]
    local ci = cond("`nocase'" != "", "(?i)", "")
    quietly gen byte `name' = 0
    foreach v of local varlist {
        local hit `"`v' != "" & `v' != "." & ustrregexm(`v', "`ci'^(`pattern')") == 1"'
        if `"`exclude'"' != "" {
            local hit `"`hit' & ustrregexm(`v', "`ci'^(`exclude')") != 1"'
        }
        quietly replace `name' = 1 if `hit'
    }
end

* Row-level slot count: how many scan variables hold a matching code.
capture program drop _oracle_cnt
program define _oracle_cnt
    syntax varlist(string), NAMe(name) PATtern(string) [EXClude(string) NOCase]
    local ci = cond("`nocase'" != "", "(?i)", "")
    quietly gen long `name' = 0
    foreach v of local varlist {
        local hit `"`v' != "" & `v' != "." & ustrregexm(`v', "`ci'^(`pattern')") == 1"'
        if `"`exclude'"' != "" {
            local hit `"`hit' & ustrregexm(`v', "`ci'^(`exclude')") != 1"'
        }
        quietly replace `name' = `name' + 1 if `hit'
    }
end

* Prefix-mode oracle: anchored literal prefix, mirroring the scanner's
* substr(dval, 1, len) == prefix test rather than a regex.
capture program drop _oracle_pfx
program define _oracle_pfx
    syntax varlist(string), NAMe(name) PATtern(string)
    quietly gen byte `name' = 0
    foreach v of local varlist {
        quietly replace `name' = 1 if `v' != "" & `v' != "." & ///
            substr(`v', 1, `=length("`pattern'")') == "`pattern'"
    }
end


**# Immutable fixture

* Built once, reloaded per block. Values repeat heavily, which is what makes
* the distinct-value memoization actually engage.
clear
set seed 42
set obs 1000

gen str5 pid = "P" + string(ceil(runiform() * 200), "%04.0f")
gen double date = mdy(1,1,2020) + floor(runiform() * 365)
format date %td
gen double refdate = mdy(6,1,2020)
format refdate %td

gen str5 dx1 = ""
gen str5 dx2 = ""
gen str5 dx3 = ""

forvalues i = 1/`=_N' {
    if runiform() < 0.3 quietly replace dx1 = "E11" + string(floor(runiform()*10)) in `i'
    * E10 codes exist so that "E1[01]" is a STRICT superset of "E11". Without
    * them the overlap test below compares two identical cohorts and proves
    * nothing about how the scanner handles nested conditions.
    if runiform() < 0.08 quietly replace dx1 = "E10" + string(floor(runiform()*10)) in `i'
    if runiform() < 0.2 quietly replace dx2 = "I10" in `i'
    if runiform() < 0.1 quietly replace dx3 = "J44" + string(floor(runiform()*10)) in `i'
    if runiform() < 0.15 quietly replace dx1 = "E66" in `i'
}

* Row identity, so merge-mode output can be matched back row for row: pid and
* date do not uniquely identify a row in this fixture.
gen long rowid = _n

tempfile fx
quietly save `fx'

* The fixture must actually exercise every condition used below, or a block
* could "agree with the oracle" at zero on both sides.
_oracle_ind dx1 dx2 dx3, name(_chk_dm2) pattern(E11)
_oracle_ind dx1 dx2 dx3, name(_chk_htn) pattern(I10)
_oracle_ind dx1 dx2 dx3, name(_chk_copd) pattern(J44)
_oracle_ind dx1 dx2 dx3, name(_chk_obe) pattern(E66)
quietly count if _chk_dm2
assert r(N) > 0
quietly count if _chk_htn
assert r(N) > 0
quietly count if _chk_copd
assert r(N) > 0
quietly count if _chk_obe
assert r(N) > 0


**# Test 1: Basic row-level scan matches a naive per-cell scan

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(E11)
    _oracle_ind dx1 dx2 dx3, name(o_htn) pattern(I10)
    _oracle_ind dx1 dx2 dx3, name(o_copd) pattern(J44)
    _oracle_ind dx1 dx2 dx3, name(o_obesity) pattern(E66)

    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid)
    assert r(N) == 1000
    assert r(n_conditions) == 4

    * Every row of every indicator, not just the totals.
    foreach c in dm2 htn copd obesity {
        assert `c' == o_`c'
    }

    * r(summary) column 1 must equal the oracle's own row counts.
    matrix S = r(summary)
    local k = 0
    foreach c in dm2 htn copd obesity {
        local ++k
        quietly count if o_`c' == 1
        assert S[`k', 1] == r(N)
        * Prevalence is that count over N, as a percentage.
        quietly count if o_`c' == 1
        assert reldif(S[`k', 2], 100 * r(N) / 1000) < 1e-8
    }
    matrix drop S
}
if _rc == 0 {
    display as result "  PASS: basic row-level scan"
    local ++pass_count
}
else {
    display as error "  FAIL: basic row-level scan (error `=_rc')"
    local ++fail_count
}


**# Test 2: Collapse mode equals a patient-level oracle

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(E11)
    _oracle_ind dx1 dx2 dx3, name(o_htn) pattern(I10)
    _oracle_ind dx1 dx2 dx3, name(o_copd) pattern(J44)
    _oracle_ind dx1 dx2 dx3, name(o_obesity) pattern(E66)
    * Any-hit rollup to the patient, computed with egen — not with codescan.
    foreach c in dm2 htn copd obesity {
        quietly bysort pid: egen byte p_`c' = max(o_`c')
    }
    quietly bysort pid: keep if _n == 1
    keep pid p_dm2 p_htn p_copd p_obesity
    sort pid
    tempfile oracle_collapse
    quietly save `oracle_collapse'

    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
        id(pid) collapse replace
    assert r(collapsed) == 1
    sort pid
    quietly merge 1:1 pid using `oracle_collapse', assert(match) nogenerate
    foreach c in dm2 htn copd obesity {
        assert `c' == p_`c'
    }
}
if _rc == 0 {
    display as result "  PASS: collapse mode"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse mode (error `=_rc')"
    local ++fail_count
}


**# Test 3: Merge mode keeps rows and carries the patient-level flag

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(E11)
    quietly bysort pid: egen byte p_dm2 = max(o_dm2)
    keep rowid p_dm2
    sort rowid
    tempfile oracle_merge
    quietly save `oracle_merge'

    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
        id(pid) merge replace
    assert r(merged) == 1
    * merge keeps every input row...
    assert _N == 1000
    * ...in the caller's original order.
    assert rowid == _n
    sort rowid
    quietly merge 1:1 rowid using `oracle_merge', assert(match) nogenerate
    * ...and every row of a patient carries that patient's flag.
    assert dm2 == p_dm2
}
if _rc == 0 {
    display as result "  PASS: merge mode"
    local ++pass_count
}
else {
    display as error "  FAIL: merge mode (error `=_rc')"
    local ++fail_count
}


**# Test 4: Countmode counts slots, not rows

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_cnt dx1 dx2 dx3, name(c_dm2) pattern(E11)
    _oracle_cnt dx1 dx2 dx3, name(c_htn) pattern(I10)
    _oracle_cnt dx1 dx2 dx3, name(c_copd) pattern(J44)
    _oracle_cnt dx1 dx2 dx3, name(c_obesity) pattern(E66)
    * Each of the four conditions above can only ever match in ONE column of
    * this fixture, so for all of them total_hits == positive_units and the
    * two quantities I3 separated are indistinguishable. "multi" is broad
    * enough to match in several columns of the same row, which is the only
    * way this block can tell a slot count from a unit count.
    _oracle_cnt dx1 dx2 dx3, name(c_multi) pattern([EIJ])
    foreach c in dm2 htn copd obesity multi {
        quietly summarize c_`c', meanonly
        local tot_`c' = r(sum)
        quietly count if c_`c' > 0
        local pos_`c' = r(N)
    }

    * Scan the SAME data in memory — reloading the fixture here would drop the
    * oracle columns the row-by-row comparison below needs.
    codescan dx1-dx3, ///
        define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66" | multi "[EIJ]") ///
        id(pid) countmode replace
    matrix S = r(summary)

    local k = 0
    foreach c in dm2 htn copd obesity multi {
        local ++k
        * total_hits (col 5) counts every matching slot...
        assert S[`k', 5] == `tot_`c''
        * ...positive_units (col 6) counts rows with at least one.
        assert S[`k', 6] == `pos_`c''
        * The per-row counter itself must equal the oracle row by row.
        assert `c' == c_`c'
    }
    * The two must actually diverge, or this block would pass on a build that
    * conflates them. multi is row 5.
    assert S[5, 5] > S[5, 6]
    matrix drop S
}
if _rc == 0 {
    display as result "  PASS: countmode"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode (error `=_rc')"
    local ++fail_count
}


**# Test 5: Overlapping conditions are independent, not exclusive

local ++test_count
capture noisily {
    quietly use `fx', clear
    * "E1[01]" is a strict superset of "E11": the fixture carries E10 codes as
    * well as E11 ones, so the two cohorts differ.
    _oracle_ind dx1 dx2 dx3, name(o_diabetes) pattern(E1[01])
    _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(E11)

    codescan dx1-dx3, define(diabetes "E1[01]" | dm2 "E11") id(pid) replace
    assert diabetes == o_diabetes
    assert dm2 == o_dm2

    * A row matching the narrow condition must ALSO match the broad one: the
    * scanner classifies a value against every condition, it does not stop at
    * the first hit. This is the property the early exit could plausibly break.
    quietly count if dm2 == 1 & diabetes == 0
    assert r(N) == 0
    quietly count if dm2 == 1
    assert r(N) > 0
    * ...and the two must not be identical, or the assertion above is vacuous.
    quietly count if diabetes == 1 & dm2 == 0
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: co-occurrence overlap detection"
    local ++pass_count
}
else {
    display as error "  FAIL: co-occurrence overlap detection (error `=_rc')"
    local ++fail_count
}


**# Test 6: Multi-window sensitivity equals per-window oracles

local ++test_count
capture noisily {
    * Oracle: patient-level any-hit restricted to each lookback window.
    * include_ref is 0 here (neither inclusive nor lookforward is given), so
    * the scanner's window is date >= refdate - w AND date < refdate — the
    * reference date itself is excluded.
    *
    * Each window carries its OWN denominator: the patients with at least one
    * row inside it. Widening the window therefore moves the numerator AND the
    * denominator, which is exactly why r(sensitivity_n) exists (I2).
    foreach w in 30 90 180 365 {
        quietly use `fx', clear
        _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(E11)
        _oracle_ind dx1 dx2 dx3, name(o_htn) pattern(I10)
        _oracle_ind dx1 dx2 dx3, name(o_copd) pattern(J44)
        quietly gen byte inwin = (date >= refdate - `w') & (date < refdate) & ///
            !missing(date, refdate) & pid != ""
        foreach c in dm2 htn copd {
            quietly replace o_`c' = 0 if !inwin
            quietly bysort pid: egen byte p_`c' = max(o_`c')
        }
        quietly bysort pid: egen byte p_elig = max(inwin)
        quietly bysort pid: keep if _n == 1
        quietly count if p_elig == 1
        local nelig_`w' = r(N)
        assert `nelig_`w'' > 0
        foreach c in dm2 htn copd {
            quietly count if p_`c' == 1 & p_elig == 1
            local n_`c'_`w' = r(N)
        }
    }

    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") ///
        id(pid) date(date) refdate(refdate) lookback(30 90 180 365) collapse replace
    assert r(n_conditions) == 3
    matrix MW  = r(sensitivity)
    matrix MWN = r(sensitivity_n)
    assert rowsof(MW) == 3
    assert colsof(MW) == 4
    assert colsof(MWN) == 4

    * The denominators themselves, not just the percentages.
    local w_i = 0
    foreach w in 30 90 180 365 {
        local ++w_i
        assert MWN[1, `w_i'] == `nelig_`w''
    }

    local k = 0
    foreach c in dm2 htn copd {
        local ++k
        local w_i = 0
        foreach w in 30 90 180 365 {
            local ++w_i
            assert reldif(MW[`k', `w_i'], 100 * `n_`c'_`w'' / `nelig_`w'') < 1e-8
        }
    }

    * Counts are monotone in window width — a wider lookback can only add
    * patients to both numerator and denominator. The PERCENTAGE is not
    * monotone, precisely because the denominator moves too, so asserting
    * monotone prevalence here would be wrong.
    foreach c in dm2 htn copd {
        assert `n_`c'_30' <= `n_`c'_90'
        assert `n_`c'_90' <= `n_`c'_180'
        assert `n_`c'_180' <= `n_`c'_365'
    }
    assert `nelig_30' <= `nelig_90'
    assert `nelig_90' <= `nelig_180'
    assert `nelig_180' <= `nelig_365'
    * The denominator must actually move, or r(sensitivity_n) is untested.
    assert `nelig_30' < `nelig_365'
    matrix drop MW MWN
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window sensitivity (error `=_rc')"
    local ++fail_count
}


**# Test 7: The widest window agrees with a plain single-window scan

local ++test_count
capture noisily {
    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10") ///
        id(pid) date(date) refdate(refdate) lookback(30 90 180) collapse replace
    matrix MW = r(sensitivity)

    * Column 3 is the 180d window. A standalone lookback(180) scan analyzes
    * exactly those rows against exactly those patients, so it must reproduce
    * that column. (The multi-window PRIMARY is the first window listed — 30d
    * here — not the widest; the secondary windows are scanned supplementally.)
    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10") ///
        id(pid) date(date) refdate(refdate) lookback(180) collapse replace
    matrix S180 = r(summary)

    assert reldif(MW[1, 3], S180[1, 2]) < 1e-10
    assert reldif(MW[2, 3], S180[2, 2]) < 1e-10
    matrix drop MW S180
}
if _rc == 0 {
    display as result "  PASS: multi-window with collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window with collapse (error `=_rc')"
    local ++fail_count
}


**# Test 8: describe tabulation equals a Stata-native tabulation

local ++test_count
capture noisily {
    quietly use `fx', clear
    * Oracle: stack the three columns and count with Stata's own machinery.
    keep dx1 dx2 dx3
    quietly gen long _row = _n
    quietly reshape long dx, i(_row) j(_which)
    quietly drop if dx == "" | dx == "."
    quietly count
    local n_entries_oracle = r(N)
    quietly levelsof dx, local(uniq)
    local n_unique_oracle : word count `uniq'
    * Most frequent code, resolved independently.
    quietly bysort dx: gen long _f = _N
    quietly summarize _f, meanonly
    local top_freq = r(max)

    quietly use `fx', clear
    codescan_describe dx1-dx3
    assert r(n_unique)  == `n_unique_oracle'
    assert r(n_entries) == `n_entries_oracle'
    matrix T = r(top_codes)
    * top_codes is ordered most-frequent first.
    assert T[1, 1] == `top_freq'
    matrix drop T
}
if _rc == 0 {
    display as result "  PASS: codescan_describe"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe (error `=_rc')"
    local ++fail_count
}


**# Test 9: nodots changes nothing but the progress display

local ++test_count
capture noisily {
    quietly use `fx', clear
    codescan_describe dx1-dx3
    local u_dots = r(n_unique)
    local e_dots = r(n_entries)
    matrix T_dots = r(top_codes)

    quietly use `fx', clear
    codescan_describe dx1-dx3, nodots
    assert r(n_unique)  == `u_dots'
    assert r(n_entries) == `e_dots'
    matrix T_nodots = r(top_codes)
    assert rowsof(T_nodots) == rowsof(T_dots)
    assert mreldif(T_nodots, T_dots) < 1e-12
    matrix drop T_dots T_nodots
}
if _rc == 0 {
    display as result "  PASS: codescan_describe nodots"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe nodots (error `=_rc')"
    local ++fail_count
}


**# Test 10: detail attributes each row to exactly one variable

local ++test_count
capture noisily {
    quietly use `fx', clear
    * "multi" is the load-bearing condition here. dm2/htn/copd can each match
    * in only ONE column of this fixture, so for them a slot count and a row
    * count are the same number and detail is identical with or without
    * allslots — a build that ignored allslots entirely would still agree.
    _oracle_cnt dx1 dx2 dx3, name(c_multi) pattern([EIJ])
    quietly summarize c_multi, meanonly
    local slots_multi = r(sum)
    quietly count if c_multi > 0
    local rows_multi = r(N)
    * The two must differ, or every assertion below is vacuous.
    assert `slots_multi' > `rows_multi'

    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | multi "[EIJ]") ///
        id(pid) detail replace
    matrix V = r(varcounts)
    assert rowsof(V) == 4
    assert colsof(V) == 3
    assert r(detail_allslots) == 0

    * Binary detail credits each matching ROW once, to the first variable that
    * matched. The row total must therefore be the number of matching rows.
    local rowsum = V[4,1] + V[4,2] + V[4,3]
    assert `rowsum' == `rows_multi'

    * allslots credits every matching slot instead, so its total is the slot
    * count — strictly larger whenever a row matches in two columns.
    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | multi "[EIJ]") ///
        id(pid) detail allslots replace
    matrix VA = r(varcounts)
    assert r(detail_allslots) == 1
    local rowsum_a = VA[4,1] + VA[4,2] + VA[4,3]
    assert `rowsum_a' == `slots_multi'
    assert `rowsum_a' > `rowsum'
    matrix drop V VA
}
if _rc == 0 {
    display as result "  PASS: detail mode"
    local ++pass_count
}
else {
    display as error "  FAIL: detail mode (error `=_rc')"
    local ++fail_count
}


**# Test 11: prefix mode is a literal anchored prefix, not a regex

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_pfx dx1 dx2 dx3, name(o_dm2) pattern(E11)
    _oracle_pfx dx1 dx2 dx3, name(o_htn) pattern(I10)
    _oracle_pfx dx1 dx2 dx3, name(o_copd) pattern(J44)

    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") ///
        id(pid) mode(prefix) replace
    assert r(mode) == "prefix"
    foreach c in dm2 htn copd {
        assert `c' == o_`c'
    }
    quietly count if o_dm2 == 1
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix mode (error `=_rc')"
    local ++fail_count
}


**# Test 12: nocase folds case without changing which codes match

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(e11) nocase
    _oracle_ind dx1 dx2 dx3, name(o_htn) pattern(i10) nocase

    codescan dx1-dx3, define(dm2 "e11" | htn "i10") id(pid) nocase replace
    assert dm2 == o_dm2
    assert htn == o_htn
    quietly count if dm2 == 1
    local n_nocase = r(N)
    assert `n_nocase' > 0

    * The fixture holds only uppercase codes, so a lowercase pattern WITHOUT
    * nocase must match nothing. Without this, test 12 would pass on a build
    * that ignores the option entirely.
    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "e11") id(pid) replace
    quietly count if dm2 == 1
    assert r(N) == 0

    * ...and nocase must land on the same rows the uppercase pattern does.
    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11") id(pid) replace
    quietly count if dm2 == 1
    assert r(N) == `n_nocase'
}
if _rc == 0 {
    display as result "  PASS: nocase"
    local ++pass_count
}
else {
    display as error "  FAIL: nocase (error `=_rc')"
    local ++fail_count
}


**# Test 13: co-occurrence counts patients carrying both conditions

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(E11)
    _oracle_ind dx1 dx2 dx3, name(o_htn) pattern(I10)
    _oracle_ind dx1 dx2 dx3, name(o_copd) pattern(J44)
    _oracle_ind dx1 dx2 dx3, name(o_obesity) pattern(E66)
    foreach c in dm2 htn copd obesity {
        quietly bysort pid: egen byte p_`c' = max(o_`c')
    }
    quietly bysort pid: keep if _n == 1
    * Every diagonal and off-diagonal cell, counted with plain count if.
    local names dm2 htn copd obesity
    forvalues a = 1/4 {
        forvalues b = 1/4 {
            local na : word `a' of `names'
            local nb : word `b' of `names'
            quietly count if p_`na' == 1 & p_`nb' == 1
            local x_`a'_`b' = r(N)
        }
    }

    quietly use `fx', clear
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
        id(pid) collapse cooccurrence replace
    matrix C = r(cooccurrence)
    assert rowsof(C) == 4
    assert colsof(C) == 4
    assert "`: rownames C'" == "dm2 htn copd obesity"
    forvalues a = 1/4 {
        forvalues b = 1/4 {
            assert C[`a', `b'] == `x_`a'_`b''
        }
    }
    * At least one genuine co-occurrence, or every off-diagonal assert is 0==0.
    assert C[1, 2] > 0
    matrix drop C
}
if _rc == 0 {
    display as result "  PASS: co-occurrence option"
    local ++pass_count
}
else {
    display as error "  FAIL: co-occurrence option (error `=_rc')"
    local ++fail_count
}


**# Test 14: matched_code returns the first matching code in variable order

local ++test_count
capture noisily {
    quietly use `fx', clear
    _oracle_ind dx1 dx2 dx3, name(o_dm2) pattern(E11)
    _oracle_ind dx1 dx2 dx3, name(o_htn) pattern(I10)
    * First hit scanning dx1, then dx2, then dx3 — the scanner's j/i nesting.
    quietly gen str5 o_mc = ""
    foreach v in dx1 dx2 dx3 {
        quietly replace o_mc = `v' if o_mc == "" & `v' != "" & `v' != "." & ///
            (ustrregexm(`v', "^(E11)") == 1 | ustrregexm(`v', "^(I10)") == 1)
    }

    codescan dx1-dx3, define(dm2 "E11" | htn "I10") id(pid) matched_code(mc) replace
    * Exact string, every row — including the empty string on non-matching rows.
    assert mc == o_mc
    quietly count if mc != ""
    assert r(N) > 0
    quietly count if mc == "" & (dm2 == 1 | htn == 1)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: matched code capture"
    local ++pass_count
}
else {
    display as error "  FAIL: matched code capture (error `=_rc')"
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
_codescan_qa_publish "test_mata_opt" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_mata_opt tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
