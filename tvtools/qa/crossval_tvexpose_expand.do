*! crossval_tvexpose_expand.do — parity gate for the tvexpose expandunit() Mata
*!
*! Improvement 2 replaced the four duplicated weeks/months/quarters/years
*! expand+bysort blocks in tvexpose with a single Mata routine
*! (tv_expand_units / _tvexpose_expand_units). This suite confirms the new
*! engine reproduces the documented bin formula exactly, for every unit:
*!
*!   n_units    = ceil((stop - start + 1) / ulen)
*!   bin k start = floor(start + (k-1)*ulen)
*!   bin k stop  = k < n_units ? floor(start + k*ulen) - 1 : stop
*!
*! The oracle re-derives these boundaries independently (a plain forvalues over
*! the formula) and compares row-by-row against tvexpose's expandunit() output
*! for a single subject whose exposure fully covers [entry, exit] (so every
*! output row is an expanded exposed bin). Units: weeks (7), months (30.4375),
*! quarters (91.3125), years (365.25).

clear all
set varabbrev off
version 16.0

capture log close
log using "crossval_tvexpose_expand.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_tvtools_qa_common.do"
quietly _tvtools_qa_bootstrap

tempfile cohort expdat got ref

* ---------------------------------------------------------------------------
* Parametrised parity check: one (unit, ulen, span) case
* ---------------------------------------------------------------------------
* args via locals: u (unit name), ulen (days), y0/y1 (entry/exit years)
foreach case in "weeks 7 2020 2020" "months 30.4375 2020 2020" ///
        "quarters 91.3125 2020 2020" "years 365.25 2018 2022" {

    gettoken u rest : case
    gettoken ulen rest : rest
    gettoken y0 y1 : rest

    local ++test_count

    local d1 = mdy(1, 1, `y0')
    local d2 = mdy(12, 31, `y1')

    * Single subject, exposure fully covering [entry, exit]
    clear
    set obs 1
    gen id = 1
    gen double study_entry = `d1'
    gen double study_exit  = `d2'
    format %td study_entry study_exit
    quietly save `cohort', replace

    clear
    set obs 1
    gen id = 1
    gen double start = `d1'
    gen double stop  = `d2'
    gen drug = 1
    format %td start stop
    quietly save `expdat', replace

    * Independent oracle: re-derive bins from the documented formula
    local nu = ceil((`d2' - `d1' + 1) / `ulen')
    clear
    quietly set obs `nu'
    gen long k = _n
    gen double start = floor(`d1' + (k - 1) * `ulen')
    gen double stop  = cond(k < `nu', floor(`d1' + k * `ulen') - 1, `d2')
    drop k
    sort start stop
    quietly save `ref', replace

    * tvexpose with expandunit(`u')
    use `cohort', clear
    capture noisily tvexpose using `expdat', ///
        id(id) start(start) stop(stop) exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        expandunit(`u') continuousunit(years) generate(cum_yrs)
    local _rc_run = _rc

    if `_rc_run' == 0 {
        keep id start stop
        sort start stop
        quietly save `got', replace
    }

    * Exact row-count + boundary comparison against the independent oracle
    capture {
        use `got', clear
        quietly count
        local n_got = r(N)
        use `ref', clear
        quietly count
        assert `n_got' == r(N)
        use `got', clear
        cf start stop using `ref'
    }
    local _rc_cmp = _rc

    if `_rc_run' == 0 & `_rc_cmp' == 0 {
        display as result "  PASS [`u']: expandunit bins match formula oracle (`nu' bins)"
        local ++pass_count
    }
    else {
        display as error "  FAIL [`u']: run rc=`_rc_run', compare rc=`_rc_cmp'"
        local ++fail_count
        local failed_tests "`failed_tests' `u'"
    }
}

* ---------------------------------------------------------------------------
* Invariant check: bins abut with no gaps and conserve the full span
* ---------------------------------------------------------------------------
local ++test_count
local d1 = mdy(1, 1, 2019)
local d2 = mdy(12, 31, 2021)

clear
set obs 1
gen id = 1
gen double study_entry = `d1'
gen double study_exit  = `d2'
format %td study_entry study_exit
quietly save `cohort', replace
clear
set obs 1
gen id = 1
gen double start = `d1'
gen double stop  = `d2'
gen drug = 1
format %td start stop
quietly save `expdat', replace

capture {
    use `cohort', clear
    tvexpose using `expdat', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        expandunit(months) continuousunit(years) generate(cum_yrs)
    sort id start
    * First bin starts at the exposure start; last bin stops at the exposure stop
    assert start[1] == `d1'
    assert stop[_N] == `d2'
    * No gaps / no overlaps: each bin starts the day after the previous stop
    quietly gen double _gap = start - stop[_n-1] if _n > 1
    quietly count if _n > 1 & _gap != 1
    assert r(N) == 0
    * Person-time conserved exactly
    quietly gen double _len = stop - start + 1
    quietly summarize _len, meanonly
    assert r(sum) == `d2' - `d1' + 1
}
if _rc == 0 {
    display as result "  PASS [invariants]: bins abut, no gaps, span conserved"
    local ++pass_count
}
else {
    display as error "  FAIL [invariants]: rc=`=_rc'"
    local ++fail_count
    local failed_tests "`failed_tests' invariants"
}

**# Summary

display as result _n "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "TESTS FAILED:`failed_tests'"
    display "RESULT: crossval_tvexpose_expand tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: crossval_tvexpose_expand tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
