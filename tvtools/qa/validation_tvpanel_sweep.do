clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvpanel_sweep.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

* ---------------------------------------------------------------------------
* Independent person-day oracle for tvpanel's active class and cumulative()
* columns, which 1.17.7 moved onto the single-pass _tvpanel_sweep kernel.
*
* The oracle shares no code with the kernel. It expands every episode to the
* days it covers and then, for each period start p,
*   active  = class of the covering episode with the latest start, ties to the
*             highest class; reference() when nothing covers p
*   cum_c   = number of distinct class-c days strictly before p, in the
*             requested unit
* Geometries are drawn to include nesting, crossing, abutting and duplicate
* episodes, tied starts across classes, episodes outside follow-up, episode
* ids absent from the master, and persons with no episode.
* ---------------------------------------------------------------------------

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvpanel sweep oracle -- $S_DATE $S_TIME"

capture program drop _tps_data
program define _tps_data
    args seed mas epi
    set seed `seed'
    clear
    quietly set obs 150
    generate long id = 2 * _n
    generate double entry = 1000 + floor(100 * runiform())
    generate double exit = entry + floor(300 * runiform())
    quietly save "`mas'", replace

    clear
    quietly set obs 900
    generate long id = 2 * (1 + floor(160 * runiform()))
    generate double rx_start = 950 + floor(450 * runiform())
    generate double rx_stop = rx_start + floor(40 * runiform())
    * Tied starts (any class) and long nesting episodes.
    quietly replace rx_start = rx_start[_n - 1] ///
        if _n > 1 & id == id[_n - 1] & runiform() < .2
    quietly replace rx_stop = rx_start + floor(40 * runiform())
    quietly replace rx_stop = rx_start + 150 if runiform() < .05
    * Abutting same-id successor.
    quietly replace rx_start = rx_stop[_n - 1] + 1 ///
        if _n > 1 & id == id[_n - 1] & runiform() < .1
    quietly replace rx_stop = max(rx_stop, rx_start)
    generate byte drug = floor(4 * runiform())
    * Exact duplicates.
    quietly expand 2 if runiform() < .03
    quietly save "`epi'", replace
end

* Expected panel from the person-day expansion. `spec' carries width, unit,
* and reference; result is saved to `want'.
capture program drop _tps_oracle
program define _tps_oracle
    args mas epi width div ref want
    tempfile days grid

    use "`epi'", clear
    generate long row = _n
    generate long nd = rx_stop - rx_start + 1
    quietly expand nd
    bysort row: generate double day = rx_start + _n - 1
    keep id day drug rx_start
    quietly levelsof drug if drug != `ref', local(classes)
    quietly save "`days'", replace

    use "`mas'", clear
    generate long np = ceil((exit - entry + 1) / `width')
    quietly expand np
    bysort id: generate long period = _n - 1
    generate double pstart = entry + `width' * period
    keep id period pstart
    quietly save "`grid'", replace

    * Active class at each period start.
    use "`days'", clear
    rename day pstart
    quietly merge m:1 id pstart using "`grid'", keep(match) nogenerate
    gsort id period -rx_start -drug
    quietly by id period: keep if _n == 1
    keep id period drug
    rename drug want_active
    quietly merge 1:1 id period using "`grid'", nogenerate
    quietly replace want_active = `ref' if missing(want_active)
    quietly save "`want'", replace

    * Cumulative distinct class days strictly before each period start.
    foreach c of local classes {
        use "`days'", clear
        quietly keep if drug == `c'
        keep id day
        quietly duplicates drop
        quietly joinby id using "`grid'"
        quietly keep if day < pstart
        quietly collapse (count) cd = day, by(id period)
        quietly generate double want_cum_`c' = cd / `div'
        drop cd
        quietly merge 1:1 id period using "`want'", nogenerate
        quietly replace want_cum_`c' = 0 if missing(want_cum_`c')
        quietly save "`want'", replace
    }
end

local seeds 11 22 33
local specs `" "1 days 1 0" "7 weeks 7 0" "30 years 365.25 2" "91 months 30.4375 1" "'

local cases 0
foreach seed of local seeds {
    foreach spec of local specs {
        local ++cases
        tokenize `"`spec'"'
        local width `1'
        local unit `2'
        local div `3'
        local ref `4'
        local ++test_count
        capture {
            tempfile mas epi want
            _tps_data `seed' "`mas'" "`epi'"
            _tps_oracle "`mas'" "`epi'" `width' `div' `ref' "`want'"

            use "`mas'", clear
            tvpanel using "`epi'", id(id) entry(entry) exit(exit) ///
                start(rx_start) stop(rx_stop) exposure(drug) reference(`ref') width(`width') ///
                cumulative(`unit') period(period) generate(active)
            local cv "`r(cumvars)'"
            quietly merge 1:1 id period using "`want'"
            assert _merge == 3
            assert active == want_active
            foreach v of local cv {
                local c = substr("`v'", 5, .)
                assert abs(`v' - want_cum_`c') < 1e-12
            }
            * Every class the oracle accrued must have a column.
            quietly ds want_cum_*
            foreach w in `r(varlist)' {
                local c = substr("`w'", 10, .)
                confirm variable cum_`c'
            }
        }
        if _rc == 0 {
            display as result "  PASS `cases': seed `seed' width(`width') cumulative(`unit') reference(`ref')"
            local ++pass_count
        }
        else {
            display as error "  FAIL `cases': seed `seed' width(`width') `unit' ref `ref' (error `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' `cases'"
        }
    }
}

**# Summary

display as result _newline "tvtools QA tvpanel sweep Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvpanel_sweep tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
