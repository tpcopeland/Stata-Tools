clear all
set more off
version 16.0
set linesize 255

* benchmark_study.do - datamap 1.9.0 P3: a study-shaped QA section.  Benchmark
* lane only (timing depends on the machine): run from its own lane with
* set processors 1 in a profile.do in the working directory.  Timing only;
* never part of quick, core, or full, and never a correctness gate.
*
* Design: 1,000,000 interval rows (id start stop _d, x1-x3, year, a 300-level
* site key, a daily date) generated at runtime from seed 1, and 30 gate calls
* in the form the studies use: dataqa set maskrare mincell(5) ledger() run()
* collect replace, name() on every call, signature on 22 of the 30 (73%),
* three groupstat calls by the 300-level site, two keyset calls against a saved
* file, and inrange/isid/rule/byrule/stat/coverage(endq)/intervals gates; the
* three smallcells calls run on a 40-row results table.  Then dataqa compare,
* report, export, and assert.
*
* The assertion: the study-form section (30 calls plus compare, report, export,
* assert) stays within STUDY_MULT times the bare section (the same 30 gate
* calls as datacheck, gatesonly with no name, signature, ledger, collect, or
* maskrare).  The benchmark first verifies that every call ran: the ledger
* holds rows for all 30 declared names, no error rows, and no failed gates.
* Reported, not asserted: (a) the per-call cost of signature (datasignature on
* 1M rows), and (b) spec F3: one gate call with by(site) at 300 levels against
* the same call without by().
*
* Measured on the development machine (1 processor, 1M rows), seconds, two runs:
*                                               run 1    run 2
*   bare gatesonly path, 30 calls               30.77    28.92
*   study form, 30 calls                        35.00    32.65
*   compare + report + export + assert           0.04     0.04
*   study total / bare                           1.14     1.13  (an earlier run: 1.08)
*   (a) datasignature, per call (1M rows)        0.08     0.07
*   (a) isid gate per call: no signature / with  0.32/0.40  0.30/0.38
*   (b) 1 gate (rule), no by() / by(site)        0.12/12.79  0.12/12.21
*   (b) 3 gates (rule inrange stat), no by()/by  0.19/33.84  0.19/33.22
* STUDY_MULT = 2 leaves about 75% headroom over the measured 1.13-1.14 for
* machine noise, and still catches signature, ledger, or collect work
* that scales with the data (signature on every call alone would add ~2 s).
* The by(site) cost (about 100 x the ungrouped call) is reported, not asserted.

local STUDY_MULT = 2

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

local test_count = 0
local pass_count = 0
local fail_count = 0
local NG = 30

local W "`c(tmpdir)'/dq_bstudy"
capture mkdir "`W'"
foreach f in ledger.dta keys.dta results.dta export.dta report.md {
    capture erase "`W'/`f'"
}

* the gate list: r(spec) is the datacheck option text of gate k, r(res) is 1
* when the gate runs on the results table
capture program drop _bm_spec
program define _bm_spec, rclass
    args k
    local res 0
    local K "$BM_W/keys.dta"
    if `k' == 1 local s `"isid(id start)"'
    else if `k' == 2 local s `"rule("order": start < stop)"'
    else if `k' == 3 local s `"inrange(x1 -6 6)"'
    else if `k' == 4 local s `"inrange(year 2000 2019 \ site 1 300 \ x2 -6 6)"'
    else if `k' == 5 local s `"stat(mean x1 -0.05 0.05)"'
    else if `k' == 6 local s `"stat(sum _d 8000 12000 \ mean x2 -0.05 0.05)"'
    else if `k' == 7 local s `"coverage(dt 2015-01-01 2019-12-31, gap(30) endq(0.01) years)"'
    else if `k' == 8 local s `"intervals(id start stop, contiguous)"'
    else if `k' == 9 local s `"byrule(id (start): "seq": start == _n*100)"'
    else if `k' == 10 local s `"byrule(id (start): "last": _n == _N | stop == start[_n+1] \ (start): "pos": start > 0)"'
    else if `k' == 11 local s `"groupstat(mean x1, by(site) min(1) band(-0.5 0.5))"'
    else if `k' == 12 local s `"groupstat(n mean p1 median p99: x2, by(site))"'
    else if `k' == 13 local s `"groupstat(median x3, by(site year) min(1) band(-1 1))"'
    else if `k' == 14 local s `"keyset(id using "`K'")"'
    else if `k' == 15 local s `"keyset(id using "`K'", subset)"'
    else if `k' == 16 local s `"isid(id start) rule("pos": stop > 0)"'
    else if `k' == 17 local s `"inrange(x3 -6 6)"'
    else if `k' == 18 local s `"rule("dur": stop - start == 100)"'
    else if `k' == 19 local s `"stat(mean x3 -0.05 0.05)"'
    else if `k' == 20 local s `"stat(sd x1 0.9 1.1)"'
    else if `k' == 21 local s `"coverage(dt 2015-01-01 2019-12-31, gap(60))"'
    else if `k' == 22 local s `"intervals(id start stop)"'
    else if `k' == 23 local s `"notmissing(id start stop)"'
    else if `k' == 24 local s `"byrule(id (start): "incr": _n == 1 | start > start[_n-1])"'
    else if `k' == 25 local s `"groupstat(sd x1, by(site) min(1) band(0.5 1.5))"'
    else if `k' == 26 local s `"rule("yr": year >= 2000 & year <= 2019)"'
    else if `k' == 27 local s `"inrange(_d 0 1)"'
    else if `k' == 28 {
        local res 1
        local s `"smallcells(n1 n2) mincell(5)"'
    }
    else if `k' == 29 {
        local res 1
        local s `"smallcells(n1-e1 if !supp) mincell(5)"'
    }
    else if `k' == 30 {
        local res 1
        local s `"smallcells(n1 n2 n1-e1) mincell(5)"'
    }
    return local spec `"`s'"'
    return scalar res = `res'
end

* signature on 22 of the 30 calls
global BM_SIG " 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 "
global BM_W "`W'"
global BM_NG `NG'

* ---- data
timer clear

clear
set seed 1
set obs 1000000
gen long id = ceil(_n/5)
bysort id: gen long start = _n*100
gen long stop = start + 100
gen byte _d = runiform() < 0.01
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen int year = 2000 + floor(runiform()*20)
gen int site = 1 + floor(runiform()*300)
gen int dt = mdy(1,1,2015) + floor(runiform()*1826)
format dt %td
sort id start
preserve
keep id
quietly duplicates drop
quietly save "`W'/keys.dta", replace
restore
* the results table: 40 rows of released counts, none in 1..4, one suppressed
preserve
clear
set obs 40
gen long n1 = 10 + _n*7
gen long n2 = 25 + _n*3
gen long e1 = 2 + mod(_n, 3)
gen byte supp = 0
replace supp = 1 in 5
replace n1 = .p in 5
quietly save "`W'/results.dta", replace
restore

* run the 30 gates; arg 1: "bare" or "study"
capture program drop _bm_run
program define _bm_run
    args mode
    forvalues k = 1/$BM_NG {
        _bm_spec `k'
        local s `"`r(spec)'"'
        local onres = r(res)
        if "`mode'" == "study" {
            local extra "name(g`k')"
            if strpos("$BM_SIG", " `k' ") local extra "`extra' signature"
        }
        else local extra ""
        if `onres' {
            preserve
            quietly use "$BM_W/results.dta", clear
            datacheck, gatesonly `s' `extra'
            local nc = r(n_checks)
            local nf = r(n_failed)
            local ne = r(n_errors)
            restore
        }
        else {
            datacheck, gatesonly `s' `extra'
            local nc = r(n_checks)
            local nf = r(n_failed)
            local ne = r(n_errors)
        }
        global BM_calls = $BM_calls + 1
        global BM_chk = $BM_chk + `nc'
        global BM_fail = $BM_fail + `nf'
        global BM_err = $BM_err + `ne'
    }
end

capture program drop _bm_reset
program define _bm_reset
    global BM_calls 0
    global BM_chk 0
    global BM_fail 0
    global BM_err 0
end

* warm-up: load and compile the ado files outside the timers
preserve
quietly keep in 1/1000
capture quietly _bm_run study
restore
capture dataqa set clear

* ---- bare section: the same 30 gates, no name/signature/ledger/collect/maskrare
_bm_reset
timer on 1
_bm_run bare
timer off 1
local bare_calls = $BM_calls
local bare_chk   = $BM_chk
local bare_fail  = $BM_fail + $BM_err

* ---- baseline run b0 (untimed): the study form once, for dataqa compare
dataqa set maskrare mincell(5) ledger("`W'/ledger.dta") run(b0) collect replace
_bm_reset
_bm_run study

* ---- study section: set, 30 calls, compare, report, export, assert
_bm_reset
timer on 2
dataqa set maskrare mincell(5) ledger("`W'/ledger.dta") run(c1) collect
_bm_run study
timer off 2
local study_calls = $BM_calls
local study_chk   = $BM_chk
local study_fail  = $BM_fail + $BM_err

timer on 3
dataqa compare using "`W'/ledger.dta", run(c1) baseline(b0)
dataqa report using "`W'/ledger.dta", run(c1) markdown("`W'/report.md") replace
dataqa export using "`W'/ledger.dta", run(c1) saving("`W'/export.dta") replace
dataqa assert, run(c1)
timer off 3
dataqa set clear

* ---- (a) the cost of signature: datasignature on 1M rows, alone and inside a gate call
timer on 4
forvalues i = 1/3 {
    quietly datasignature
}
timer off 4
timer on 5
forvalues i = 1/3 {
    quietly datacheck, gatesonly isid(id start)
}
timer off 5
timer on 6
forvalues i = 1/3 {
    quietly datacheck, gatesonly isid(id start) signature
}
timer off 6

* ---- (b) spec F3: the same gates with by(site), 300 levels, and without by()
local f3 `"rule("order": start < stop) inrange(x1 -6 6) stat(mean x1 -1 1)"'
timer on 7
quietly datacheck, gatesonly rule("order": start < stop)
timer off 7
timer on 8
capture quietly datacheck, gatesonly rule("order": start < stop) by(site)
local rc_by1 = _rc
timer off 8
timer on 9
quietly datacheck, gatesonly `f3'
timer off 9
timer on 10
capture quietly datacheck, gatesonly `f3' by(site)
local rc_by3 = _rc
timer off 10

quietly timer list
local t_bare  = r(t1)
local t_study = r(t2) + r(t3)
local t_set   = r(t2)
local t_post  = r(t3)
local t_sig   = r(t4) / 3
local t_g0    = r(t5) / 3
local t_g1    = r(t6) / 3
local t_by1   = r(t8)
local t_nb1   = r(t7)
local t_nb3   = r(t9)
local t_by3   = r(t10)
display as text _newline "BENCHMARK study-shaped section (1M rows, 30 gate calls), seconds"
display as text "  bare gatesonly path:                 " %8.2f `t_bare'
display as text "  study form, 30 calls:                " %8.2f `t_set'
display as text "  compare+report+export+assert:        " %8.2f `t_post'
display as text "  study total:                         " %8.2f `t_study' "   ratio to bare " %5.2f `t_study'/`t_bare'
display as text "  (a) datasignature, per call:         " %8.2f `t_sig'
display as text "  (a) isid gate, per call, no sig/sig: " %8.2f `t_g0' " /" %8.2f `t_g1' "  (signature adds " %5.2f `t_g1'-`t_g0' ")"
display as text "  (b) 1 gate, no by / by(site):        " %8.2f `t_nb1' " /" %8.2f `t_by1' "  (rc by " `rc_by1' ")"
display as text "  (b) 3 gates, no by / by(site):       " %8.2f `t_nb3' " /" %8.2f `t_by3' "  (rc by " `rc_by3' ")"

* ---- test 1: every declared gate call ran
local ++test_count
capture noisily {
    assert `bare_calls' == `NG' & `study_calls' == `NG'
    assert `bare_fail' == 0 & `study_fail' == 0
    * the bare and study forms run the same gates
    assert `bare_chk' == `study_chk'
    preserve
    quietly use "`W'/ledger.dta", clear
    quietly keep if run == "c1"
    * one or more rows for each of the 30 declared names, and no other name
    forvalues k = 1/`NG' {
        quietly count if dataset == "g`k'"
        assert r(N) >= 1
    }
    quietly count if !regexm(dataset, "^g([1-9]|[12][0-9]|30)$")
    assert r(N) == 0
    * the ledger rows per call match the hand count of declared checks
    * (isid 1, inrange 1 per entry, coverage 3 or 4 with years, intervals 3 or 4
    * with contiguous, groupstat 1 per statistic, notmissing 1 per variable)
    local rows 1 1 1 3 1 2 4 4 1 2 2 5 2 1 1 2 1 1 1 1 3 3 3 1 2 1 1 1 1 1
    forvalues k = 1/`NG' {
        local w : word `k' of `rows'
        quietly count if dataset == "g`k'"
        assert r(N) == `w'
    }
    assert _N == 54
    * no error row, no failed gate
    quietly count if status == "error" | status == "fail"
    assert r(N) == 0
    * signature recorded on exactly the 22 declared calls, absent on the other 8
    forvalues k = 1/`NG' {
        local want = strpos("$BM_SIG", " `k' ") > 0
        quietly count if dataset == "g`k'" & signature != ""
        assert (r(N) > 0) == `want'
    }
    * the run family mix: every gate family of the study form is represented
    foreach fam in isid inrange rule byrule stat coverage intervals smallcells groupstat keyset {
        quietly count if family == "`fam'"
        assert r(N) >= 1
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: all 30 gate calls ran (ledger rows, names, signatures, no error or failed gate)"
    local ++pass_count
}
else {
    display as error "  FAIL: the benchmark did not run every declared gate (rc=`=_rc')"
    local ++fail_count
}

* ---- test 2: the study-form section stays within a fixed multiple of the bare path
local ++test_count
capture noisily {
    assert `t_study' <= `STUDY_MULT' * max(`t_bare', 1)
}
if _rc == 0 {
    display as result "  PASS: study-form section " %5.1f `t_study' "s <= `STUDY_MULT' x bare " %5.1f `t_bare' "s"
    local ++pass_count
}
else {
    display as error "  FAIL: study-form section " %5.1f `t_study' "s exceeds `STUDY_MULT' x bare " %5.1f `t_bare' "s"
    local ++fail_count
}

display "RESULT: benchmark_study tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
