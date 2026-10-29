*! validation_asof_range_spells.do - range() bounds from A4 spell fixtures vs a joinby oracle
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+
clear all
set processors 1
set varabbrev off
version 16.0
capture log close _all
log using "validation_asof_range_spells.log", replace text nomsg
global ASOF_QA_STATUS "fail"
do "_asof_qa_common.do"
quietly _asof_qa_bootstrap
local qa_dir "`r(qa_dir)'"
do "`qa_dir'/_qa_fx_a4.do"
local test_count = 0
local pass_count = 0
local fail_count = 0

* Each generated spell becomes one master row: anchor = start + 1 and
* range(start stop). Spell perturbations give the observability bounds their
* structural edge cases: a zero-length range, an open (missing) upper bound,
* abutting and overlapping neighbours, bounds outside the base window, and a
* duplicated master key; one fixture also opens lower bounds by hand. The
* oracle is a Cartesian joinby with explicit eligibility filters and a
* sort-based pick, sharing no code with the scan.

**# Shared using data: even day offsets, an odd offset, a duplicate date,
**# a missing carried value, and one identifier with no records
capture program drop _rs_events
program define _rs_events
    version 16.0
    args base
    clear
    quietly {
        set obs 8
        generate long id = _n
        expand 17
        bysort id: generate double off = _n - 6
        keep if mod(off, 2) == 0 | off == 3
        expand 2 if off == 4
        drop if id == 2
        * Shuffle so original file order differs from date order.
        generate double shuffle = mod(id * 7919 + (off + 10) * 104729 + _n, 997)
        sort shuffle
        generate long ord = _n
        generate double visit = `base' + off
        generate double value = id * 1000 + ord
        replace value = . if id == 3 & off == 8
        format visit %td
        drop shuffle off
    }
end

**# Eligible master-event pairs for one rule, from the master in memory
capture program drop _rs_pairs
program define _rs_pairs
    version 16.0
    syntax , EVENTS(string) DIRection(string) [WINdow(real -1)]
    quietly {
        joinby id using `events'
        keep if !missing(value)
        keep if missing(start) | visit >= start
        keep if missing(stop) | visit <= stop
        if "`direction'" == "onorbefore" keep if visit <= anchor
        if "`direction'" == "onorafter" keep if visit >= anchor
        if `window' >= 0 keep if abs(visit - anchor) <= `window'
    }
end

**# Oracle pick: the documented rule, then one row per master row
capture program drop _rs_pick
program define _rs_pick
    version 16.0
    args rule
    quietly {
        generate double dist = abs(visit - anchor)
        generate double negvisit = -visit
        generate long negord = -ord
        if "`rule'" == "last" sort mid negvisit ord
        if "`rule'" == "first" sort mid visit ord
        if "`rule'" == "nearest_before" sort mid dist visit ord
        if "`rule'" == "nearest_after" sort mid dist negvisit ord
        if "`rule'" == "nearest_lastord" sort mid dist negord
        by mid: keep if _n == 1
        keep mid visit value
        rename (visit value) (exp_date exp_value)
    }
end

**# Master rows from the spell fixture in memory
capture program drop _rs_master
program define _rs_master
    version 16.0
    args ops openstart
    * Every perturbation must be present before the oracle can mean anything.
    foreach op of local ops {
        if "`op'" != "unsorted" {
            local hits : char _dta[qa_perturb_n_`op']
            assert `hits' >= 1 & `hits' < .
        }
    }
    local base_hex : char _dta[qa_truth_window_start]
    keep id start stop
    generate double anchor = start + 1
    format anchor %td
    generate long mid = _n
    if "`openstart'" == "openstart" {
        quietly replace start = . if mod(mid, 4) == 1
        quietly count if missing(start)
        assert r(N) >= 1 & r(N) < .
        quietly count if missing(start) & missing(stop)
        assert r(N) >= 1 & r(N) < .
    }
    char _dta[rs_base] "`base_hex'"
    char _dta[rs_ops] "`ops' `openstart'"
end

**# Five direction/selection/tie rules on the master in memory
capture program drop _rs_cells
program define _rs_cells, rclass
    version 16.0
    local tests = 0
    local pass = 0
    local fail = 0
    local base_hex : char _dta[rs_base]
    local base = `base_hex'
    local variant : char _dta[rs_ops]
    tempfile events
    preserve
    _rs_events `base'
    save `events'
    restore
    local rules `""onorbefore last last" "onorafter first first" "both nearest nearest_before" "both nearest_after nearest_after" "both nearest_lastord nearest_lastord""'
    foreach rulespec of local rules {
        local ++tests
        capture noisily {
            local direction : word 1 of `rulespec'
            local select : word 2 of `rulespec'
            local oracle_rule : word 3 of `rulespec'
            local ties_opt ""
            if "`select'" == "nearest_after" {
                local select "nearest"
                local ties_opt "ties(after)"
            }
            if "`select'" == "nearest_lastord" {
                local select "nearest"
                local ties_opt "ties(last)"
            }
            local win_opt ""
            local win_oracle ""
            if "`oracle_rule'" == "nearest_before" {
                local win_opt "window(-2 2)"
                local win_oracle "window(2)"
            }

            tempfile expected
            preserve
            _rs_pairs, events(`events') direction(`direction') `win_oracle'
            quietly bysort ord: generate byte first_use = _n == 1
            quietly count if first_use
            local exp_eligible = r(N)
            drop first_use
            _rs_pick `oracle_rule'
            save `expected'
            restore

            preserve
            asof value using `events', id(id) date(visit) anchor(anchor) ///
                range(start stop) direction(`direction') select(`select') ///
                `ties_opt' `win_opt' generate(got) datename(gotdate) ///
                gapname(gap) matchname(found) nowarn
            local got_matched = r(N_matched)
            local got_eligible = r(N_eligible)
            merge 1:1 mid using `expected', assert(master match) nogenerate
            assert found == !missing(exp_value)
            assert got == exp_value if found
            assert gotdate == exp_date if found
            assert gap == exp_date - anchor if found
            assert missing(got) & missing(gotdate) & missing(gap) if !found
            quietly count if found
            assert r(N) == `got_matched'
            quietly count if !missing(exp_value)
            assert r(N) == `got_matched'
            assert `got_eligible' == `exp_eligible'
            * The fixture must exercise both outcomes, or the cell proves little.
            quietly count if !found
            assert r(N) >= 1 & r(N) < .
            assert !missing(`got_matched') & `got_matched' >= 1
            restore
        }
        if _rc == 0 local ++pass
        else {
            local ++fail
            capture restore
            display as error "FAIL: perturb(`variant') rule(`rulespec')"
        }
    }
    return scalar tests = `tests'
    return scalar pass = `pass'
    return scalar fail = `fail'
end

* expect: EXACT
qa_fx_a4_spells, clear tier(unit) perturb(zero_length open_end)
_rs_master "zero_length open_end" openstart
_rs_cells
local test_count = `test_count' + r(tests)
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* expect: EXACT
qa_fx_a4_spells, clear tier(unit) perturb(abut dup_key unsorted)
_rs_master "abut dup_key unsorted"
_rs_cells
local test_count = `test_count' + r(tests)
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* expect: EXACT
qa_fx_a4_spells, clear tier(unit) perturb(overlap)
_rs_master "overlap"
_rs_cells
local test_count = `test_count' + r(tests)
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* expect: EXACT
qa_fx_a4_spells, clear tier(unit) perturb(boundary_values open_end)
_rs_master "boundary_values open_end"
_rs_cells
local test_count = `test_count' + r(tests)
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

display "RESULT: validation_asof_range_spells tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
