*! test_package_state.do
*! Package-wide session-state restoration on success and error paths.

clear all
set varabbrev off
set more off
version 16.0

capture log close _all
quietly log using "test_package_state.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local public_commands tvtools tvage tvband tvsplit tvpanel tvexpose tvmerge ///
    tvevent tvweight tvdiagnose

capture program drop _state_success
program define _state_success
    args command

    if "`command'" == "tvtools" {
        clear
        tvtools, list
    }
    else if "`command'" == "tvage" {
        clear
        set obs 1
        generate long id = 1
        generate double dob = 0
        generate double entry = 10000
        generate double exitd = 10365
        format dob entry exitd %td
        tvage, id(id) dob(dob) entry(entry) exit(exitd)
    }
    else if "`command'" == "tvband" {
        clear
        set obs 1
        generate long id = 1
        generate double origin = 0
        generate double start = 0
        generate double stop = 30
        format origin start stop %td
        tvband, id(id) start(start) stop(stop) type(elapsed) origin(origin) ///
            unit(day) width(10)
    }
    else if "`command'" == "tvsplit" {
        clear
        set obs 1
        generate long id = 1
        generate double origin = 0
        generate double start = 0
        generate double stop = 30
        format origin start stop %td
        tvsplit, id(id) start(start) stop(stop) ///
            elapsed(origin, width(10) unit(day) generate(fu))
    }
    else if "`command'" == "tvpanel" {
        tempfile episodes
        clear
        set obs 1
        generate long id = 1
        generate double start = 5
        generate double stop = 20
        generate byte eclass = 1
        format start stop %td
        save `episodes'
        clear
        set obs 1
        generate long id = 1
        generate double entry = 0
        generate double exitd = 30
        format entry exitd %td
        tvpanel using `episodes', id(id) entry(entry) exit(exitd) ///
            exposure(eclass) reference(0) width(10)
    }
    else if "`command'" == "tvexpose" {
        tempfile episodes
        clear
        set obs 1
        generate long id = 1
        generate double rx_start = 5
        generate double rx_stop = 20
        generate byte drug = 1
        format rx_start rx_stop %td
        save `episodes'
        clear
        set obs 1
        generate long id = 1
        generate double entry = 0
        generate double exitd = 30
        format entry exitd %td
        tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///
            exposure(drug) reference(0) entry(entry) exit(exitd)
    }
    else if "`command'" == "tvmerge" {
        tempfile a b
        clear
        set obs 1
        generate long id = 1
        generate double s1 = 0
        generate double e1 = 20
        generate byte x1 = 1
        save `a'
        clear
        set obs 1
        generate long id = 1
        generate double s2 = 10
        generate double e2 = 30
        generate byte x2 = 1
        save `b'
        tvmerge "`a'" "`b'", id(id) start(s1 s2) stop(e1 e2) ///
            exposure(x1 x2)
    }
    else if "`command'" == "tvevent" {
        tempfile intervals
        clear
        set obs 1
        generate long id = 1
        generate double start = 0
        generate double stop = 30
        format start stop %td
        save `intervals'
        clear
        set obs 1
        generate long id = 1
        generate double eventdate = 15
        format eventdate %td
        tvevent using `intervals', id(id) date(eventdate) generate(ev) replace
    }
    else if "`command'" == "tvweight" {
        clear
        set seed 1201
        set obs 400
        generate double x = rnormal()
        generate byte a = runiform() < invlogit(0.4*x)
        tvweight a, covariates(x) generate(w) nolog
    }
    else if "`command'" == "tvdiagnose" {
        clear
        set obs 2
        generate long id = 1
        generate double start = cond(_n == 1, 0, 11)
        generate double stop = cond(_n == 1, 10, 20)
        tvdiagnose, id(id) start(start) stop(stop) gaps
    }
end

capture program drop _state_error
program define _state_error, rclass
    args command

    capture noisily {
        if "`command'" == "tvtools" {
            clear
            tvtools, category(bogus)
        }
        else if "`command'" == "tvage" {
            clear
            set obs 2
            generate long id = 1
            generate double dob = 0
            generate double entry = 10000
            generate double exitd = 10365
            format dob entry exitd %td
            tvage, id(id) dob(dob) entry(entry) exit(exitd)
        }
        else if "`command'" == "tvband" {
            clear
            set obs 1
            generate long id = 1
            generate double origin = 0
            generate double start = 0
            generate double stop = 30
            format origin start stop %td
            tvband, id(id) start(start) stop(stop) type(elapsed) ///
                origin(origin) unit(day) width(10) ///
                saveas("$TVTOOLS_QA_RUN_DIR/not_created/out.dta") replace
        }
        else if "`command'" == "tvsplit" {
            clear
            set obs 1
            generate long id = 1
            generate double start = 0
            generate double stop = 30
            tvsplit, id(id) start(start) stop(stop)
        }
        else if "`command'" == "tvpanel" {
            tempfile episodes
            clear
            set obs 1
            generate long id = 1
            generate double start = 5
            generate double stop = 20
            generate byte eclass = 1
            save `episodes'
            clear
            set obs 1
            generate long id = 1
            generate double entry = 0
            generate double exitd = 30
            tvpanel using `episodes', id(id) entry(entry) exit(exitd) ///
                exposure(eclass) width(0)
        }
        else if "`command'" == "tvexpose" {
            clear
            set obs 1
            generate long id = 1
            generate double entry = 0
            generate double exitd = 30
            tvexpose using "$TVTOOLS_QA_RUN_DIR/missing_exposure.dta", ///
                id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
                reference(0) entry(entry) exit(exitd)
        }
        else if "`command'" == "tvmerge" {
            clear
            set obs 1
            generate sentinel = 1
            tvmerge "$TVTOOLS_QA_RUN_DIR/missing_a.dta" ///
                "$TVTOOLS_QA_RUN_DIR/missing_b.dta", id(id) ///
                start(s1 s2) stop(e1 e2) exposure(x1 x2)
        }
        else if "`command'" == "tvevent" {
            clear
            set obs 1
            generate long id = 1
            generate double eventdate = 15
            tvevent using "$TVTOOLS_QA_RUN_DIR/missing_intervals.dta", ///
                id(id) date(eventdate)
        }
        else if "`command'" == "tvweight" {
            clear
            set obs 20
            generate byte x = _n > 10
            generate byte a = x
            tvweight a, covariates(x) generate(w) nolog
        }
        else if "`command'" == "tvdiagnose" {
            clear
            set obs 1
            generate long id = 1
            generate double start = 10
            generate double stop = 1
            tvdiagnose, id(id) start(start) stop(stop) gaps
        }
    }
    local cmd_rc = _rc
    return scalar cmd_rc = `cmd_rc'
end

**# Public-command success paths

foreach command of local public_commands {
    local ++test_count
    capture noisily {
        set varabbrev on
        set more on
        capture noisily _state_success `command'
        local cmd_rc = _rc
        assert "`c(varabbrev)'" == "on"
        assert "`c(more)'" == "on"
        assert `cmd_rc' == 0
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `command'_success"
    }
    set varabbrev off
    set more off
}

**# Public-command error paths

foreach command of local public_commands {
    local ++test_count
    capture noisily {
        set varabbrev on
        set more on
        _state_error `command'
        local cmd_rc = r(cmd_rc)
        assert `cmd_rc' != 0
        assert "`c(varabbrev)'" == "on"
        assert "`c(more)'" == "on"
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        local failed_tests "`failed_tests' `command'_error"
    }
    set varabbrev off
    set more off
}

**# Read-only state inventory

local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg weight
    matrix b_before = e(b)
    local cmd_before "`e(cmd)'"
    generate long qa_order = _n
    generate long id = ceil(_n/2)
    bysort id (qa_order): generate double start = 10*_n
    generate double stop = start + 9
    generate byte exp = mod(id, 2)
    label define qa_state_lbl 0 "Reference" 1 "Exposed"
    label values exp qa_state_lbl
    sort qa_order
    datasignature set
    local scheme_before "`c(scheme)'"
    local frame_before "`c(frame)'"
    capture frame drop qa_state_sentinel
    frame create qa_state_sentinel
    frame qa_state_sentinel: set obs 1

    tvdiagnose, id(id) start(start) stop(stop) exposure(exp) gaps summarize

    assert "`e(cmd)'" == "`cmd_before'"
    matrix b_after = e(b)
    assert mreldif(b_before, b_after) < 1e-12
    assert "`c(scheme)'" == "`scheme_before'"
    assert "`c(frame)'" == "`frame_before'"
    frame qa_state_sentinel: assert _N == 1
    assert "`: label (exp) 1'" == "Exposed"
    datasignature confirm
    capture frame drop qa_state_sentinel
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' readonly_inventory"
    capture frame drop qa_state_sentinel
}

**# Summary

display "RESULT: test_package_state tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "state-contract failures:`failed_tests'"
    exit 1
}
