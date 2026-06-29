*! crossval_tvmerge_mata.do — parity gate for the tvmerge Mata interval engine
*!
*! Cross-validates the compiled Mata interval-overlap engine (v1.2.0) that
*! replaced the old joinby/batch() merge core. Two independent oracles:
*!
*!   (a) Categorical merges are checked against a DAY-BY-DAY expansion oracle:
*!       expand every interval to single days, inner-join on (id, day) across
*!       all datasets, then collapse consecutive identical-exposure days back
*!       into intervals. This is a completely different algorithm from both
*!       joinby and the Mata sweep, so agreement is strong evidence of
*!       correctness. Covers 2- and 3-dataset merges, disjoint / touching /
*!       nested intervals, and string vs numeric IDs.
*!
*!   (b) Continuous proportioning is checked against a joinby+intersection
*!       reference that re-derives the duration-prorated value by hand.
*!
*! force / ID-mismatch handling is checked by asserting only common IDs survive.

clear all
set varabbrev off
version 16.0

capture log close
quietly log using "crossval_tvmerge_mata.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Bootstrap: isolated install from the package root
local qa_dir "`c(pwd)'"
do "`qa_dir'/_tvtools_qa_common.do"
quietly _tvtools_qa_bootstrap

tempfile d1 d2 d3 got ref

* ---------------------------------------------------------------------------
* Oracle helpers
* ---------------------------------------------------------------------------

* Day-by-day categorical oracle. Each dataset file must hold: id, s, e, exp#k
* (start var `s', stop var `e', exposure var named exp`k'). Builds a single-day
* long form per dataset, inner-joins on (id, day), collapses identical-exposure
* runs into intervals, and saves to `target' with vars id start stop exp1[ exp2[ exp3]].
capture program drop _ref_daymerge
program define _ref_daymerge, rclass
    version 16.0
    syntax , Target(string) Files(string)

    local K : word count `files'

    * Build day-long form for each dataset
    forvalues k = 1/`K' {
        local f : word `k' of `files'
        use "`f'", clear
        quietly expand e - s + 1
        bysort id s e: gen long _day = s + _n - 1
        keep id _day exp`k'
        rename _day day
        tempfile _dl`k'
        quietly save `_dl`k''
    }
    * Inner-join all datasets on (id, day)
    use `_dl1', clear
    forvalues k = 2/`K' {
        quietly merge 1:1 id day using `_dl`k'', keep(match) nogenerate
    }
    * Collapse consecutive identical-exposure days into intervals
    local expvars
    forvalues k = 1/`K' {
        local expvars "`expvars' exp`k'"
    }
    sort id day
    by id (day): gen byte _newrun = (_n == 1) | (day != day[_n-1] + 1)
    foreach v of local expvars {
        by id (day): replace _newrun = 1 if `v' != `v'[_n-1] & _n > 1
    }
    by id: gen long _runid = sum(_newrun)
    collapse (min) start = day (max) stop = day (firstnm) `expvars', by(id _runid)
    drop _runid
    sort id start stop
    quietly save "`target'", replace
end

* ---------------------------------------------------------------------------
* TEST 1: 2-dataset categorical, overlapping intervals (numeric id)
* ---------------------------------------------------------------------------
local ++test_count
clear
input id s e exp1
1 1 10 1
1 11 20 2
2 1 15 1
3 5 25 1
end
quietly save `d1', replace
clear
input id s e exp2
1 5 15 1
1 16 25 2
2 1 10 2
3 1 30 3
end
quietly save `d2', replace

capture noisily {
    _ref_daymerge, target("`ref'") files(`"`d1' `d2'"')
    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) exposure(exp1 exp2)
    keep id start stop exp1 exp2
    sort id start stop
    quietly save `got', replace
    use `got', clear
    cf _all using `ref'
}
if _rc == 0 {
    display as result "  PASS [1]: 2-dataset categorical overlap parity"
    local ++pass_count
}
else {
    display as error "  FAIL [1]: 2-dataset categorical overlap (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* ---------------------------------------------------------------------------
* TEST 2: 3-dataset categorical merge
* ---------------------------------------------------------------------------
local ++test_count
clear
input id s e exp1
1 1 20 1
2 1 20 5
end
quietly save `d1', replace
clear
input id s e exp2
1 5 25 2
2 3 18 6
end
quietly save `d2', replace
clear
input id s e exp3
1 8 30 3
2 10 40 7
end
quietly save `d3', replace

capture noisily {
    _ref_daymerge, target("`ref'") files(`"`d1' `d2' `d3'"')
    use `d1', clear
    tvmerge "`d1'" "`d2'" "`d3'", id(id) start(s s s) stop(e e e) ///
        exposure(exp1 exp2 exp3)
    keep id start stop exp1 exp2 exp3
    sort id start stop
    quietly save `got', replace
    use `got', clear
    cf _all using `ref'
}
if _rc == 0 {
    display as result "  PASS [2]: 3-dataset categorical parity"
    local ++pass_count
}
else {
    display as error "  FAIL [2]: 3-dataset categorical (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

* ---------------------------------------------------------------------------
* TEST 3: disjoint intervals -> empty intersection (no rows)
* ---------------------------------------------------------------------------
local ++test_count
clear
input id s e exp1
1 1 10 1
end
quietly save `d1', replace
clear
input id s e exp2
1 20 30 2
end
quietly save `d2', replace

capture noisily {
    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) exposure(exp1 exp2)
    assert _N == 0
}
if _rc == 0 {
    display as result "  PASS [3]: disjoint intervals -> empty output"
    local ++pass_count
}
else {
    display as error "  FAIL [3]: disjoint intervals (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

* ---------------------------------------------------------------------------
* TEST 4: touching intervals (start == previous stop) count as overlap (inclusive)
* ---------------------------------------------------------------------------
local ++test_count
clear
input id s e exp1
1 1 10 1
end
quietly save `d1', replace
clear
input id s e exp2
1 10 20 2
end
quietly save `d2', replace

capture noisily {
    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) exposure(exp1 exp2)
    * inclusive [start,stop]: day 10 is shared -> exactly one output row [10,10]
    assert _N == 1
    assert start[1] == 10 & stop[1] == 10
    assert exp1[1] == 1 & exp2[1] == 2
}
if _rc == 0 {
    display as result "  PASS [4]: touching intervals share boundary day"
    local ++pass_count
}
else {
    display as error "  FAIL [4]: touching intervals (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

* ---------------------------------------------------------------------------
* TEST 5: nested intervals (one fully inside the other)
* ---------------------------------------------------------------------------
local ++test_count
clear
input id s e exp1
1 1 100 1
end
quietly save `d1', replace
clear
input id s e exp2
1 40 60 2
end
quietly save `d2', replace

capture noisily {
    _ref_daymerge, target("`ref'") files(`"`d1' `d2'"')
    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) exposure(exp1 exp2)
    keep id start stop exp1 exp2
    sort id start stop
    quietly save `got', replace
    use `got', clear
    cf _all using `ref'
    assert _N == 1
    assert start[1] == 40 & stop[1] == 60
}
if _rc == 0 {
    display as result "  PASS [5]: nested intervals parity"
    local ++pass_count
}
else {
    display as error "  FAIL [5]: nested intervals (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

* ---------------------------------------------------------------------------
* TEST 6: string IDs
* ---------------------------------------------------------------------------
local ++test_count
clear
input str8 id s e exp1
"alpha" 1 10 1
"bravo" 5 20 2
end
quietly save `d1', replace
clear
input str8 id s e exp2
"alpha" 5 15 3
"bravo" 1 12 4
end
quietly save `d2', replace

capture noisily {
    _ref_daymerge, target("`ref'") files(`"`d1' `d2'"')
    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) exposure(exp1 exp2)
    keep id start stop exp1 exp2
    sort id start stop
    quietly save `got', replace
    use `got', clear
    cf _all using `ref'
}
if _rc == 0 {
    display as result "  PASS [6]: string IDs parity"
    local ++pass_count
}
else {
    display as error "  FAIL [6]: string IDs (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

* ---------------------------------------------------------------------------
* TEST 7: force with ID mismatch -> only common IDs survive
* ---------------------------------------------------------------------------
local ++test_count
clear
input id s e exp1
1 1 10 1
2 1 10 1
3 1 10 1
end
quietly save `d1', replace
clear
input id s e exp2
2 5 15 2
3 5 15 2
4 5 15 2
end
quietly save `d2', replace

capture noisily {
    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) exposure(exp1 exp2) force
    * ids 1 (only d1) and 4 (only d2) dropped; 2 and 3 survive
    quietly levelsof id, local(survivors)
    assert "`survivors'" == "2 3"
}
if _rc == 0 {
    display as result "  PASS [7]: force keeps only common IDs"
    local ++pass_count
}
else {
    display as error "  FAIL [7]: force ID mismatch (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

* ---------------------------------------------------------------------------
* TEST 8: continuous proportioning parity vs joinby+intersection reference
* ---------------------------------------------------------------------------
local ++test_count
clear
input id s e drugA
1 1 20 1
2 1 30 2
end
quietly save `d1', replace
clear
input id s e doseB
1 5 14 100
1 16 25 200
2 10 40 75
end
quietly save `d2', replace

capture noisily {
    * Reference: joinby + intersection + duration proportioning of doseB
    use `d1', clear
    rename (s e) (start stop)
    joinby id using `d2'
    gen double ns = max(start, s)
    gen double nx = min(stop, e)
    keep if ns <= nx & !missing(ns, nx)
    replace start = ns
    replace stop  = nx
    gen double _p = cond(e > s, (stop - start + 1)/(e - s + 1), 1)
    replace _p = 1 if _p > 1 & !missing(_p)
    replace doseB = doseB * _p
    keep id start stop drugA doseB
    duplicates drop id start stop drugA doseB, force
    rename (drugA doseB) (drugA_ref doseB_ref)
    sort id start stop
    quietly save `ref', replace

    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) ///
        exposure(drugA doseB) continuous(doseB)
    keep id start stop drugA doseB
    sort id start stop
    * Align against the reference and assert exact id/start/stop/drugA + tol doseB
    merge 1:1 id start stop using `ref', nogenerate
    assert drugA == drugA_ref
    assert reldif(doseB, doseB_ref) < 1e-9
}
if _rc == 0 {
    display as result "  PASS [8]: continuous proportioning parity"
    local ++pass_count
}
else {
    display as error "  FAIL [8]: continuous proportioning (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

* ---------------------------------------------------------------------------
* TEST 9: larger numeric merge (scale parity vs day oracle)
* ---------------------------------------------------------------------------
local ++test_count
clear
set obs 500
gen id = _n
gen s = 1
gen e = 100 + mod(_n, 50)
gen exp1 = mod(_n, 3) + 1
quietly save `d1', replace
clear
set obs 500
gen id = _n
gen s = 20 + mod(_n, 30)
gen e = 200
gen exp2 = mod(_n, 4) + 1
quietly save `d2', replace

capture noisily {
    _ref_daymerge, target("`ref'") files(`"`d1' `d2'"')
    use `d1', clear
    tvmerge "`d1'" "`d2'", id(id) start(s s) stop(e e) exposure(exp1 exp2)
    keep id start stop exp1 exp2
    sort id start stop
    quietly save `got', replace
    use `got', clear
    cf _all using `ref'
}
if _rc == 0 {
    display as result "  PASS [9]: 500-person scale parity"
    local ++pass_count
}
else {
    display as error "  FAIL [9]: 500-person scale (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# Summary

display as result _n "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "TESTS FAILED:`failed_tests'"
    display "RESULT: crossval_tvmerge_mata tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: crossval_tvmerge_mata tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
