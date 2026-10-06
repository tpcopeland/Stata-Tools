* test_bugfix_2026_10_06_a.do - regtab stats(groups) is never silently dropped,
* the r() names regtab returns for the per-model statistics, and the
* fitcount record-storage capture
*
* Oracles are independent of the code under test: group counts come from
* egen tag() on e(sample), and the scalars regtab must return come from the
* estimation commands' own e() or from summarize.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _bfa
log using "test_bugfix_2026_10_06_a.log", replace text name(_bfa)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* the probe data of the bug report: 50 pairs, one positive outcome in each
capture program drop _bfa_probe
program define _bfa_probe
    clear
    set seed 20261006
    set obs 100
    gen pair = ceil(_n/2)
    gen y = mod(_n, 2)
    gen x = rnormal()
end

* does the text log of a command hold a needle? sets r(found)
capture program drop _bfa_logged
program define _bfa_logged, rclass
    args needle cmd
    tempfile lgb
    local lg "`lgb'.log"
    quietly log using `"`lg'"', text replace name(_bfacap)
    capture noisily `cmd'
    local crc = _rc
    quietly log close _bfacap
    local found = 0
    tempname fh
    file open `fh' using `"`lg'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local found = 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
    return scalar rc = `crc'
end

**# G1: clogit, stats(n groups): the table renders, no Groups row, a note says why
local ++test_count
capture noisily {
    _bfa_probe
    collect clear
    quietly collect: clogit y x, or group(pair)
    * hand count of the groups in the fit's own sample
    egen byte _tg = tag(pair) if e(sample)
    quietly count if _tg == 1
    assert r(N) == 50
    drop _tg
    _bfa_logged "Note: stats(groups) left out: no model stores a group count; model 1 (clogit, group variable pair)" "regtab, stats(n groups) frame(_bfa_g1, replace)"
    assert r(rc) == 0
    assert r(found) == 1
    _bfa_logged "tabtools fitcount, events(y) people(pair)" "regtab, stats(n groups) frame(_bfa_g1, replace)"
    assert r(rc) == 0
    assert r(found) == 1
    * the generic left-out note does not repeat the same row
    _bfa_logged "requested statistic(s), left out of the table" "regtab, stats(n groups) frame(_bfa_g1, replace)"
    assert r(found) == 0
    quietly regtab, stats(n groups) frame(_bfa_g1, replace)
    * no group count is returned and no Groups row is invented
    assert missing(r(groups_1))
    assert r(n_1) == 100
    quietly frame _bfa_g1: count if strtrim(A) == "Groups"
    assert r(N) == 0
    quietly frame _bfa_g1: count if strtrim(A) == "Observations"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: G1 clogit groups: rc 0, no Groups row, note names the estimator and the remedy"
    local ++pass_count
}
else {
    display as error "  FAIL: G1 clogit groups (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _bfa_g1

**# G2: the named remedy returns the hand-counted 50
local ++test_count
capture noisily {
    _bfa_probe
    collect clear
    quietly collect: clogit y x, or group(pair)
    egen byte _tg = tag(pair) if e(sample)
    quietly count if _tg == 1
    local want = r(N)
    drop _tg
    quietly tabtools fitcount, events(y) people(pair)
    regtab, stats(n people) statlabels(people "Groups") frame(_bfa_f, replace)
    assert `want' == 50
    assert r(people_1) == `want'
    assert r(n_1) == 100
    * the row the user reads is labelled Groups and holds 50
    quietly frame _bfa_f: count if A == "Groups"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: G2 fitcount people() + statlabels gives Groups = 50"
    local ++pass_count
}
else {
    display as error "  FAIL: G2 fitcount remedy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _bfa_f

**# G3: table with one model that has a count and clogit: blank cell + note
local ++test_count
capture noisily {
    sysuse auto, clear
    gen pair = ceil(_n/2)
    gen byte hi = price > 6000
    collect clear
    quietly collect: xtlogit hi weight, fe i(pair)
    egen byte _tg = tag(pair) if e(sample)
    quietly count if _tg == 1
    local want = r(N)
    drop _tg
    quietly collect: clogit hi weight, group(pair)
    assert `want' == 13
    _bfa_logged "stats(groups) is blank for model(s) 2" "regtab, stats(n groups)"
    assert r(rc) == 0
    assert r(found) == 1
    quietly regtab, stats(n groups)
    assert r(groups_1) == `want'
    assert missing(r(groups_2))
}
if _rc == 0 {
    display as result "  PASS: G3 mixed table: xtlogit count shown, clogit blank with a note"
    local ++pass_count
}
else {
    display as error "  FAIL: G3 mixed table (rc=`=_rc')"
    local ++fail_count
}

**# G4: a count another estimator posts is unchanged (xtreg, xtlogit fe, mixed)
local ++test_count
capture noisily {
    sysuse auto, clear
    gen pair = ceil(_n/2)
    collect clear
    quietly collect: xtreg mpg weight, re i(pair)
    egen byte _tg = tag(pair) if e(sample)
    quietly count if _tg == 1
    local want = r(N)
    drop _tg
    regtab, stats(n groups)
    assert r(groups_1) == `want'
    assert `want' == 37
    collect clear
    quietly collect: mixed mpg weight || pair:
    regtab, stats(groups)
    assert r(groups_1) == 37
}
if _rc == 0 {
    display as result "  PASS: G4 estimators that post N_g still report it"
    local ++pass_count
}
else {
    display as error "  FAIL: G4 N_g estimators (rc=`=_rc')"
    local ++fail_count
}

**# G5: a requested row no model reports is named on the console, not dropped
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight
    _bfa_logged "left out of the table: events groups" "regtab, stats(n events groups)"
    assert r(rc) == 0
    assert r(found) == 1
    quietly regtab, stats(n events groups)
    assert missing(r(events_1)) & missing(r(groups_1))
    assert r(n_1) == 74
    * a row that is shown produces no omission note
    _bfa_logged "left out of the table" "regtab, stats(n)"
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: G5 omitted rows are named; shown rows add no note"
    local ++pass_count
}
else {
    display as error "  FAIL: G5 omission note (rc=`=_rc')"
    local ++fail_count
}

**# R1: the r() names and values of the per-model statistics
local ++test_count
capture noisily {
    sysuse auto, clear
    gen pair = ceil(_n/2)
    gen ev = foreign
    gen pt = weight/1000
    gen grp5 = mod(_n, 5)
    collect clear
    quietly collect: regress mpg weight
    scalar _a_r2a = e(r2_a)
    scalar _a_rmse = e(rmse)
    scalar _a_F = e(F)
    quietly tabtools fitcount, events(ev) people(pair) exposure(pt)
    quietly collect: regress mpg weight length
    scalar _b_r2a = e(r2_a)
    scalar _b_rmse = e(rmse)
    scalar _b_F = e(F)
    quietly tabtools fitcount, events(ev) people(grp5) exposure(pt)
    quietly summarize ev
    local want_ev = r(sum)
    quietly summarize pt
    local want_pt = r(sum)
    egen byte _t1 = tag(pair)
    quietly count if _t1
    local want_p1 = r(N)
    egen byte _t2 = tag(grp5)
    quietly count if _t2
    local want_p2 = r(N)
    assert `want_ev' == 22 & `want_p1' == 37 & `want_p2' == 5
    assert !missing(`want_pt', _a_r2a, _b_r2a, _a_rmse, _b_rmse, _a_F, _b_F)
    quietly regtab, stats(n obs events people exposure r2_a rmse F)
    local names : r(scalars)
    foreach m in 1 2 {
        foreach s in obs events people exposure r2_a rmse F n {
            assert `: list posof "`s'_`m'" in names' > 0
        }
        assert r(obs_`m') == 74 & r(n_`m') == 74
        assert r(events_`m') == `want_ev'
        assert !missing(r(exposure_`m'))
        assert abs(r(exposure_`m') - `want_pt') < 1e-9 * max(1, abs(`want_pt'))
    }
    assert r(people_1) == `want_p1' & r(people_2) == `want_p2'
    assert !missing(r(r2_a_1), r(r2_a_2), r(rmse_1), r(rmse_2), r(F_1), r(F_2))
    assert abs(r(r2_a_1) - _a_r2a) < 1e-12 * max(1, abs(_a_r2a)) & abs(r(r2_a_2) - _b_r2a) < 1e-12 * max(1, abs(_b_r2a))
    assert abs(r(rmse_1) - _a_rmse) < 1e-12 * max(1, abs(_a_rmse)) & abs(r(rmse_2) - _b_rmse) < 1e-12 * max(1, abs(_b_rmse))
    assert abs(r(F_1) - _a_F) < 1e-12 * max(1, abs(_a_F)) & abs(r(F_2) - _b_F) < 1e-12 * max(1, abs(_b_F))
    * a statistic that was not requested is not returned
    quietly regtab, stats(n)
    assert missing(r(events_1)) & missing(r(rmse_1)) & missing(r(F_1))
}
if _rc == 0 {
    display as result "  PASS: R1 obs/events/people/exposure/r2_a/rmse/F returned by name, with values"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 return names (rc=`=_rc')"
    local ++fail_count
}

**# R2: mi_m_# and fmi_# after mi estimate
local ++test_count
capture noisily {
    webuse mheart1s20, clear
    collect clear
    quietly collect: mi estimate: regress bmi age
    local want_m = e(M_mi)
    local want_fmi = e(fmi_max_mi)
    assert `want_m' == 20
    quietly regtab, stats(n mi_m fmi)
    assert r(mi_m_1) == `want_m'
    assert !missing(r(fmi_1)) & !missing(`want_fmi')
    assert abs(r(fmi_1) - `want_fmi') < 1e-12 * max(1, abs(`want_fmi'))
}
if _rc == 0 {
    display as result "  PASS: R2 mi_m_1 and fmi_1 returned by name, with values"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 mi return names (rc=`=_rc')"
    local ++fail_count
}

**# F1: fitcount stores its record with two single captures
local ++test_count
capture noisily {
    * the failure path (a collect that cannot take the record) cannot be forced
    * from a test; the fix is asserted on the source and the happy path
    * stores the record
    local src "`pkg_dir'/_tabtools_fitcount.ado"
    mata: _bfa_L = ustrtrim(cat(st_local("src")))
    mata: st_local("has_old", strofreal(sum(_bfa_L :== "capture {")))
    mata: st_local("has_rc", strofreal(sum(substr(_bfa_L, 1, 30) :== "capture _tabtools_fitcount_rec")))
    capture mata: mata drop _bfa_L
    assert `has_old' == 0 & `has_rc' == 1
    sysuse auto, clear
    collect clear
    quietly collect: poisson foreign mpg
    quietly tabtools fitcount, events(foreign) people(headroom)
    * the stored record is readable by regtab (tt_cns is stored with the counts)
    quietly regtab, stats(events people)
    assert r(events_1) == 22
}
if _rc == 0 {
    display as result "  PASS: F1 fitcount record storage uses split captures and stores"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 fitcount capture (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "RESULT: test_bugfix_2026_10_06_a tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bfa
if `fail_count' > 0 exit 1
