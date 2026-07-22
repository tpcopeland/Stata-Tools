clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_help_examples.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: runnable help and README examples -- $S_DATE $S_TIME"

* This suite executes the examples that ship in the help files and README
* verbatim, from the sandboxed install and an arbitrary working directory.
* It exists because the release gate's runnable_examples check had no file to
* find, and because the flagship examples previously referenced four datasets
* the package does not ship (rx_episodes, drug_a, drug_b, intervals) -- they
* could not have run for any installed user.

* Run from a scratch directory so no example can depend on the QA folder.
local _origdir "`c(pwd)'"
capture mkdir "$TVTOOLS_QA_RUN_DIR/helpex"
quietly cd "$TVTOOLS_QA_RUN_DIR/helpex"

**# H1: tvtools catalog examples (tvtools; tvtools, detail; category filters)

local ++test_count
capture noisily {
    tvtools
    assert r(n_commands) == 9
    local _all "`r(commands)'"

    tvtools, detail
    assert r(n_commands) == 9

    tvtools, category(prep)
    assert r(n_commands) == 7

    tvtools, category(diag)
    assert r(n_commands) == 1

    tvtools, category(weight)
    assert r(n_commands) == 1

    * Every catalogued command must actually be installed.
    foreach c of local _all {
        capture which `c'
        assert _rc == 0
    }
}
if _rc == 0 {
    display as result "  PASS [H1]: tvtools catalog examples run and agree with the installed suite"
    local ++pass_count
}
else {
    display as error "  FAIL [H1]: tvtools catalog examples (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H1"
}

**# H2: flagship tvexpose example, verbatim from tvtools.sthlp

local ++test_count
capture noisily {
    clear
    input id rx_start rx_stop drug
    1 21930 21990 1
    1 22050 22100 1
    2 21950 22000 1
    end
    tempfile rx
    save "`rx'"

    clear
    input id study_entry study_exit
    1 21915 22280
    2 21915 22280
    end
    format study_entry study_exit %td

    tvexpose using "`rx'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug) keepdates

    * The documented naming contract: bounds carry the option names, and the
    * literal working name `start' must not survive into the output.
    confirm variable rx_start
    confirm variable rx_stop
    confirm variable tv_drug
    confirm variable study_entry
    confirm variable study_exit
    capture confirm variable start
    assert _rc != 0

    * Two persons, full closed-interval person-time in each study window.
    assert r(N_persons) == 2
    tempvar pt
    generate double `pt' = rx_stop - rx_start + 1
    quietly summarize `pt'
    assert r(sum) == 2 * (22280 - 21915 + 1)

    tempfile intervals
    save "`intervals'"
}
if _rc == 0 {
    display as result "  PASS [H2]: flagship tvexpose example runs and conserves person-time"
    local ++pass_count
}
else {
    display as error "  FAIL [H2]: flagship tvexpose example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H2"
}

**# H3: flagship tvdiagnose example

local ++test_count
capture noisily {
    tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
        coverage gaps entry(study_entry) exit(study_exit)

    * tvexpose emits complete coverage, so the documented diagnostic must
    * report exactly 100% and no gaps -- never the >100% the union defect
    * used to produce.
    assert reldif(r(mean_coverage), 100) < 1e-6
    assert r(max_coverage) <= 100 + 1e-6
    assert r(n_gaps) == 0
}
if _rc == 0 {
    display as result "  PASS [H3]: flagship tvdiagnose example reports exactly 100% coverage"
    local ++pass_count
}
else {
    display as error "  FAIL [H3]: flagship tvdiagnose example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H3"
}

**# H4: flagship tvevent example plus the documented stset conversion

local ++test_count
capture noisily {
    clear
    input id event_date death_date
    1 22120 .
    2 . 22200
    end
    format event_date death_date %td

    tvevent using "`intervals'", id(id) date(event_date) ///
        compete(death_date) startvar(rx_start) stopvar(rx_stop)

    * The documented conversion: closed [start, stop] -> (start-1, stop].
    generate double start0 = rx_start - 1
    stset rx_stop, id(id) failure(_failure == 1) time0(start0)

    quietly count if _st == 1 & _t0 != rx_start - 1
    assert r(N) == 0
    quietly count if _st == 1 & _t != rx_stop
    assert r(N) == 0

    * Person 1 fails at the event date; person 2's competing event is a
    * distinct type, so it is not a _failure==1 record.
    quietly count if _d == 1
    assert r(N) == 1
    quietly summarize _t if _d == 1
    assert r(mean) == 22120
}
if _rc == 0 {
    display as result "  PASS [H4]: flagship tvevent example and documented stset conversion"
    local ++pass_count
}
else {
    display as error "  FAIL [H4]: flagship tvevent example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H4"
}

**# H5: flagship tvweight example

local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 12345
    generate id = _n
    generate age = 40 + int(runiform() * 40)
    generate sex = runiform() < 0.5
    generate tv_drug = runiform() < invlogit(-2 + 0.03 * age + 0.4 * sex)
    tvweight tv_drug, covariates(age sex)

    * A usable weight on every analysis row, and a sane mean.
    quietly count if missing(iptw)
    assert r(N) == 0
    quietly summarize iptw
    assert r(min) > 0
    * Unstabilized IPTW for a binary exposure has expectation 2 -- each arm
    * contributes 1 -- not 1. Assert the value the estimator is actually
    * defined to produce.
    assert abs(r(mean) - 2) < 0.5
}
if _rc == 0 {
    display as result "  PASS [H5]: flagship tvweight example produces usable weights"
    local ++pass_count
}
else {
    display as error "  FAIL [H5]: flagship tvweight example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H5"
}

**# H6: documented combine() contract -- allocator, label, and r(combine_map)

local ++test_count
capture noisily {
    clear
    input id s e exp
    1 1 10 1
    1 5 20 2
    end
    tempfile ce
    save "`ce'"

    clear
    input id entry_d exit_d
    1 1 20
    end

    tvexpose using "`ce'", id(id) start(s) stop(e) ///
        exposure(exp) reference(0) entry(entry_d) exit(exit_d) ///
        generate(tv) combine(combo)

    local cmap `"`r(combine_map)'"'
    local cn = r(n_combined_states)

    * Exactly one simultaneous state, reported with its composition.
    assert `cn' == 1
    assert strpos(`"`cmap'"', "1 + 2") > 0

    * The allocated code must lie strictly above every original value, so it
    * can never be confused with a single-exposure code.
    local ccode = real(substr(`"`cmap'"', 1, strpos(`"`cmap'"', "=") - 1))
    assert `ccode' > 2 & `ccode' < .
    quietly count if combo == `ccode'
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS [H6]: documented combine() allocator and r(combine_map)"
    local ++pass_count
}
else {
    display as error "  FAIL [H6]: documented combine() contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H6"
}

**# H7: documented bytype naming contract and r(bytype_map)

local ++test_count
capture noisily {
    clear
    input id s e exp
    1 1 5 1
    1 8 12 2
    end
    tempfile be
    save "`be'"

    clear
    input id entry_d exit_d
    1 1 20
    end

    tvexpose using "`be'", id(id) start(s) stop(e) ///
        exposure(exp) reference(0) entry(entry_d) exit(exit_d) ///
        generate(ever) evertreated bytype

    assert r(n_bytype_vars) == 2
    local bmap `"`r(bytype_map)'"'
    assert strpos(`"`bmap'"', "1=ever1") > 0
    assert strpos(`"`bmap'"', "2=ever2") > 0
    confirm variable ever1
    confirm variable ever2

    * Negative and decimal values must map deterministically, and the map
    * must report the sanitized names rather than leaving callers to guess.
    clear
    input id s e double exp
    1 1 5 -1
    1 8 12 2.5
    end
    tempfile be2
    save "`be2'"

    clear
    input id entry_d exit_d
    1 1 20
    end

    tvexpose using "`be2'", id(id) start(s) stop(e) ///
        exposure(exp) reference(0) entry(entry_d) exit(exit_d) ///
        generate(ever) evertreated bytype

    assert r(n_bytype_vars) == 2
    local bmap2 `"`r(bytype_map)'"'
    assert strpos(`"`bmap2'"', "-1=everneg1") > 0
    assert strpos(`"`bmap2'"', "2.5=ever2p5") > 0
    confirm variable everneg1
    confirm variable ever2p5
}
if _rc == 0 {
    display as result "  PASS [H7]: documented bytype naming contract and r(bytype_map)"
    local ++pass_count
}
else {
    display as error "  FAIL [H7]: documented bytype contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H7"
}

**# H8: per-source overlap attribution, r(n_input_overlaps_ds#)
* The dynamic family had zero-path assertions but no positive per-dataset
* attribution: an overlap present only in source 2 must raise the aggregate
* and source 2's counter while leaving source 1's at zero, and the roles must
* swap when the sources are given in the other order.

local ++test_count
capture noisily {
    * Source 1: clean, non-overlapping intervals.
    clear
    input long id double(a_start a_stop) byte expA
    1 1 10 1
    1 11 20 1
    end
    tempfile ovA
    save "`ovA'"

    * Source 2: two intervals that overlap each other on days 5-10.
    clear
    input long id double(b_start b_stop) byte expB
    1 1 10 1
    1 5 20 2
    end
    tempfile ovB
    save "`ovB'"

    tvmerge "`ovA'" "`ovB'", id(id) start(a_start b_start) ///
        stop(a_stop b_stop) exposure(expA expB) generate(gA gB)

    assert r(n_input_overlaps_ds1) == 0
    assert r(n_input_overlaps_ds2) > 0
    assert r(n_input_overlaps) == r(n_input_overlaps_ds1) + r(n_input_overlaps_ds2)

    * Reversing source order must move the count to the other slot, not
    * change the total.
    local total_fwd = r(n_input_overlaps)

    tvmerge "`ovB'" "`ovA'", id(id) start(b_start a_start) ///
        stop(b_stop a_stop) exposure(expB expA) generate(gB gA)

    assert r(n_input_overlaps_ds1) > 0
    assert r(n_input_overlaps_ds2) == 0
    assert r(n_input_overlaps) == `total_fwd'
}
if _rc == 0 {
    display as result "  PASS [H8]: per-source overlap attribution is positive, zero, and order-symmetric"
    local ++pass_count
}
else {
    display as error "  FAIL [H8]: per-source overlap attribution (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H8"
}

**# H9: merge and containment postconditions hold on committed output
* The merge and containment loops carry a 10,000-iteration cap and used to
* warn and continue on exhaustion, returning a plausible partial dataset. The
* cap now checks its postcondition and errors transactionally when it is
* violated. The cap itself is not reachable with realistic data (both loops
* converge in O(log n) passes), so this test asserts the invariant the guard
* checks, on the success path: committed output must contain no mergeable
* same-value pair and no period contained in another of the same value.

local ++test_count
capture noisily {
    clear
    * Deeply nested and chained same-value episodes: the shapes that drive
    * both loops through multiple passes.
    input id s e exp
    1 1 30 1
    1 5 25 1
    1 10 20 1
    1 12 18 1
    1 31 40 1
    1 41 50 1
    1 60 70 2
    1 65 80 2
    end
    tempfile pc
    save "`pc'"

    clear
    input id entry_d exit_d
    1 1 100
    end

    tvexpose using "`pc'", id(id) start(s) stop(e) ///
        exposure(exp) reference(0) entry(entry_d) exit(exit_d) ///
        generate(tvpc)

    sort id s e
    * Postcondition 1: no two adjacent rows of the same value remain
    * mergeable (gap <= 0 with the default merge()).
    tempvar mleft
    quietly by id (s e): generate byte `mleft' = ///
        (s[_n+1] - e <= 0) & !missing(s[_n+1]) & ///
        (tvpc == tvpc[_n+1]) & (_n < _N)
    quietly count if `mleft' == 1
    assert r(N) == 0

    * Postcondition 2: no period is contained in a previous period of the
    * same exposure value.
    tempvar cleft
    quietly by id: generate byte `cleft' = ///
        (e <= e[_n-1]) & (s >= s[_n-1]) & (tvpc == tvpc[_n-1]) & _n > 1
    quietly count if `cleft' == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS [H9]: merge and containment postconditions hold on committed output"
    local ++pass_count
}
else {
    display as error "  FAIL [H9]: merge/containment postconditions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H9"
}

quietly cd "`_origdir'"

* ===== Summary =====
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA runnable help examples Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_help_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
