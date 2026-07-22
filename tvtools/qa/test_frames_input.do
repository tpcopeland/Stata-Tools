clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_frames_input.log", replace nomsg

* Shared scaffold: sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: frames I/O (input + frameout) -- $S_DATE $S_TIME"

* -------------------------------------------------------------------------
* Compare two saved datasets for byte-identical content (canonical row/col order)
* -------------------------------------------------------------------------
capture program drop _sig
program define _sig, rclass
    args fpath
    use "`fpath'", clear
    quietly ds
    sort `r(varlist)'
    order _all, alphabetic
    datasignature
    return local sig "`r(datasignature)'"
end

**# TEST 1: tvmerge frames() == using-files (byte-identical)
local ++test_count
capture noisily {
    * Build two interval datasets with distinct exposure names
    clear
    input id double(start stop) expa
        1 100 200 1
        1 200 300 2
        2 100 250 1
    end
    format start stop %td
    tempfile fa
    save "`fa'"
    frame create frA
    frame frA: use "`fa'", clear

    clear
    input id double(start stop) expb
        1 100 180 1
        1 180 300 0
        2 100 250 1
    end
    format start stop %td
    tempfile fb
    save "`fb'"
    frame create frB
    frame frB: use "`fb'", clear

    * File-based merge
    tvmerge "`fa'" "`fb'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) saveas($TVTOOLS_QA_RUN_DIR/m_files.dta) replace
    * Frame-based merge
    tvmerge, frames(frA frB) id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) saveas($TVTOOLS_QA_RUN_DIR/m_frames.dta) replace

    _sig "$TVTOOLS_QA_RUN_DIR/m_files.dta"
    local s1 "`r(sig)'"
    _sig "$TVTOOLS_QA_RUN_DIR/m_frames.dta"
    local s2 "`r(sig)'"
    assert "`s1'" == "`s2'" & "`s1'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvmerge frames() output identical to using-files"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge frames equivalence (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}
capture frame drop frA
capture frame drop frB

**# TEST 2: tvmerge auto-suffix when both inputs share tv_exposure
local ++test_count
capture noisily {
    clear
    input id double(start stop) tv_exposure
        1 100 200 1
        2 100 250 1
    end
    format start stop %td
    tempfile fc
    save "`fc'"
    clear
    input id double(start stop) tv_exposure
        1 120 220 1
        2 100 250 1
    end
    format start stop %td
    tempfile fd
    save "`fd'"

    tvmerge "`fc'" "`fd'", id(id) start(start start) stop(stop stop) ///
        exposure(tv_exposure tv_exposure) ///
        saveas($TVTOOLS_QA_RUN_DIR/m_suffix.dta) replace
    use "$TVTOOLS_QA_RUN_DIR/m_suffix.dta", clear
    confirm variable tv_exposure_1
    confirm variable tv_exposure_2
}
if _rc == 0 {
    display as result "  PASS: tvmerge auto-suffixes duplicate tv_exposure (tv_exposure_1/_2)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge auto-suffix (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# TEST 3: tvevent frame() == using-file
local ++test_count
capture noisily {
    * Interval data (the using source)
    clear
    input id double(start stop)
        1 100 400
        2 100 400
    end
    format start stop %td
    tempfile ivl
    save "`ivl'"
    frame create frIvl
    frame frIvl: use "`ivl'", clear

    * Events in memory
    clear
    input id double eventdate
        1 250
        2 .
    end
    format eventdate %td
    tempfile ev
    save "`ev'"

    use "`ev'", clear
    tvevent using "`ivl'", id(id) date(eventdate) replace
    save "$TVTOOLS_QA_RUN_DIR/e_file.dta", replace

    use "`ev'", clear
    tvevent, frame(frIvl) id(id) date(eventdate) replace
    save "$TVTOOLS_QA_RUN_DIR/e_frame.dta", replace

    _sig "$TVTOOLS_QA_RUN_DIR/e_file.dta"
    local s1 "`r(sig)'"
    _sig "$TVTOOLS_QA_RUN_DIR/e_frame.dta"
    local s2 "`r(sig)'"
    assert "`s1'" == "`s2'" & "`s1'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvevent frame() output identical to using-file"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent frame equivalence (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture frame drop frIvl

**# TEST 4: tvpanel frame() == using-file
local ++test_count
capture noisily {
    local e1 = mdy(1,1,2020)
    * Episode data (the using source)
    clear
    set obs 1
    gen long id = 1
    gen double start = `e1' + 50
    gen double stop  = `e1' + 300
    gen int eclass = 5
    format start stop %td
    tempfile epi
    save "`epi'"
    frame create frEpi
    frame frEpi: use "`epi'", clear

    * Person-level data in memory
    clear
    set obs 2
    gen long id = _n
    gen double entry = `e1'
    gen double exit  = `e1' + 364
    format entry exit %td
    tempfile persons
    save "`persons'"

    use "`persons'", clear
    tvpanel using "`epi'", id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(91)
    save "$TVTOOLS_QA_RUN_DIR/p_file.dta", replace

    use "`persons'", clear
    tvpanel, frame(frEpi) id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(91)
    save "$TVTOOLS_QA_RUN_DIR/p_frame.dta", replace

    _sig "$TVTOOLS_QA_RUN_DIR/p_file.dta"
    local s1 "`r(sig)'"
    _sig "$TVTOOLS_QA_RUN_DIR/p_frame.dta"
    local s2 "`r(sig)'"
    assert "`s1'" == "`s2'" & "`s1'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvpanel frame() output identical to using-file"
    local ++pass_count
}
else {
    display as error "  FAIL: tvpanel frame equivalence (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture frame drop frEpi

**# TEST 5: error paths for frames/frame input
local ++test_count
capture noisily {
    clear
    input id double(start stop) e
        1 100 200 1
    end
    tempfile fx
    save "`fx'"
    frame create frX
    frame frX: use "`fx'", clear

    * tvmerge: both files and frames
    capture tvmerge "`fx'" "`fx'", frames(frX frX) id(id) ///
        start(start start) stop(stop stop) exposure(e e)
    assert _rc == 198
    * tvmerge: nonexistent frame
    capture tvmerge, frames(frX nope) id(id) ///
        start(start start) stop(stop stop) exposure(e e)
    assert _rc == 111
    * tvevent: both using and frame
    clear
    input id double eventdate
        1 150
    end
    capture tvevent using "`fx'", frame(frX) id(id) date(eventdate)
    assert _rc == 198
    * tvevent: nonexistent frame
    capture tvevent, frame(nope) id(id) date(eventdate)
    assert _rc == 111
    * tvpanel: nonexistent frame
    clear
    set obs 1
    gen long id = 1
    gen double entry = 100
    gen double exit = 400
    capture tvpanel, frame(nope) id(id) entry(entry) exit(exit) exposure(e)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: frames/frame error guards (198 conflict, 111 missing)"
    local ++pass_count
}
else {
    display as error "  FAIL: frames error guards (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
capture frame drop frX

**# TEST 6: tvexpose frameout() is non-destructive and matches saveas output
local ++test_count
capture noisily {
    * master cohort in memory
    clear
    input id double(study_entry study_exit)
        1 100 400
        2 100 400
    end
    format study_entry study_exit %td
    tempfile cohort
    save "`cohort'"
    * exposure episodes (using)
    clear
    input id double(estart estop) ex
        1 150 250 1
        2 200 300 1
    end
    format estart estop %td
    tempfile epis
    save "`epis'"

    * saveas reference
    use "`cohort'", clear
    tvexpose using "`epis'", id(id) start(estart) stop(estop) exposure(ex) ///
        reference(0) entry(study_entry) exit(study_exit) generate(tv_ex) ///
        saveas("$TVTOOLS_QA_RUN_DIR/x_saveas.dta") replace

    * frameout: caller data must be untouched, frame must hold the result
    use "`cohort'", clear
    datasignature set
    tvexpose using "`epis'", id(id) start(estart) stop(estop) exposure(ex) ///
        reference(0) entry(study_entry) exit(study_exit) generate(tv_ex) ///
        frameout(fx_out)
    assert "`r(frameout)'" == "fx_out"
    datasignature confirm           // caller data unchanged
    frame fx_out: save "$TVTOOLS_QA_RUN_DIR/x_frame.dta", replace
    _sig "$TVTOOLS_QA_RUN_DIR/x_saveas.dta"
    local s1 "`r(sig)'"
    _sig "$TVTOOLS_QA_RUN_DIR/x_frame.dta"
    local s2 "`r(sig)'"
    assert "`s1'" == "`s2'" & "`s1'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvexpose frameout() non-destructive, matches saveas"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose frameout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture frame drop fx_out

**# TEST 7: tvmerge frameout() non-destructive + exists-without-replace guard
local ++test_count
capture noisily {
    clear
    input id double(start stop) expa
        1 100 200 1
        2 100 250 1
    end
    format start stop %td
    tempfile ma
    save "`ma'"
    clear
    input id double(start stop) expb
        1 100 180 1
        2 100 250 1
    end
    format start stop %td
    tempfile mb
    save "`mb'"

    * unrelated caller data in memory
    clear
    set obs 3
    gen long keepme = _n
    datasignature set
    tvmerge "`ma'" "`mb'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) frameout(fm_out)
    assert "`r(frameout)'" == "fm_out"
    datasignature confirm           // caller's keepme data unchanged
    frame fm_out: count
    assert r(N) > 0
    * exists-without-replace -> rc 110
    capture tvmerge "`ma'" "`mb'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) frameout(fm_out)
    assert _rc == 110
    * replace overwrites
    tvmerge "`ma'" "`mb'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) frameout(fm_out) replace
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge frameout() non-destructive + replace guard"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge frameout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture frame drop fm_out

* ===== Summary =====
display as result _newline "frames I/O (input + frameout) Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_frames_input tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
