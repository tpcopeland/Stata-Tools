* test_rangematch_frame_safety.do
* Regression coverage for RM-I01: frame() may not name the using source frame.
*
* Output routing drops the frame() target and renames the internal output frame
* over it. When the target IS the using source, that destroys the source -- at
* rc=0 -- contradicting the documented promise that a using frame is left
* unchanged. replace authorizes overwriting the DESTINATION, not the source.
*
* On the shipped 1.3.3 code T1 FAILS: the call returned rc=0 and the source
* frame silently became the joined output.

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1
set varabbrev off

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}


local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* A using source frame carrying a sentinel variable that exists ONLY in the
* source. If the source is overwritten by the joined output the sentinel and
* the original row count disappear.
capture program drop _rm_make_src
program define _rm_make_src
    args fname
    capture frame drop `fname'
    frame create `fname'
    frame `fname' {
        quietly set obs 3
        quietly gen double key = 5 * _n
        quietly gen double using_sentinel = 99
        quietly label data "rm source frame"
    }
end

capture program drop _rm_make_master
program define _rm_make_master
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 100
end

**# T1: source == target WITH replace must be rejected and leave source intact
local ++test_count
capture noisily {
    _rm_make_src rm_src
    _rm_make_master
    capture rangematch key mlow mhigh using rm_src, frame(rm_src) replace
    assert _rc == 198
    * The source frame must be untouched: sentinel, rows, and label all survive.
    frame rm_src {
        confirm variable using_sentinel
        confirm variable key
        quietly count
        assert r(N) == 3
        assert using_sentinel == 99
        local dlab : data label
        assert "`dlab'" == "rm source frame"
        * The joined output must not have been written here.
        capture confirm variable mlow
        assert _rc != 0
    }
    * The caller's own data must survive the rejected call.
    quietly count
    assert r(N) == 1
    confirm variable mlow
    capture frame drop rm_src
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: source==target with replace rejected, source intact"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T1_source_target_replace"
    display as error "FAIL: source==target with replace"
}

**# T2: source == target WITHOUT replace must also be rejected
*       (the pre-existing frame-exists check gives 110; either way the call
*        must fail and the source must survive)
local ++test_count
capture noisily {
    _rm_make_src rm_src
    _rm_make_master
    capture rangematch key mlow mhigh using rm_src, frame(rm_src)
    assert _rc != 0
    frame rm_src {
        confirm variable using_sentinel
        quietly count
        assert r(N) == 3
    }
    capture frame drop rm_src
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: source==target without replace rejected"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T2_source_target_noreplace"
    display as error "FAIL: source==target without replace"
}

**# T3: the current frame is unchanged and no workspace frames leak
local ++test_count
capture noisily {
    _rm_make_src rm_src
    _rm_make_master
    local before "`c(frame)'"
    capture rangematch key mlow mhigh using rm_src, frame(rm_src) replace
    assert _rc == 198
    assert "`c(frame)'" == "`before'"
    foreach f in __rm_master __rm_using __rm_uwork __rm_out __rm_grp __rm_grp_u {
        capture frame `f': describe
        assert _rc != 0
    }
    capture frame drop rm_src
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: current frame preserved, no workspace frames leak"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T3_cleanup"
    display as error "FAIL: frame cleanup after rejection"
}

**# T4: POSITIVE CONTROL -- a DIFFERENT target frame still works and the
*       using source frame is genuinely left unchanged
local ++test_count
capture noisily {
    _rm_make_src rm_src
    capture frame drop rm_out
    _rm_make_master
    rangematch key mlow mhigh using rm_src, frame(rm_out)
    * Output landed in the target.
    frame rm_out {
        quietly count
        assert r(N) == 3
        confirm variable mlow
        confirm variable key
    }
    * The documented promise: the using frame is left unchanged.
    frame rm_src {
        quietly count
        assert r(N) == 3
        confirm variable using_sentinel
        assert using_sentinel == 99
        capture confirm variable mlow
        assert _rc != 0
    }
    capture frame drop rm_src
    capture frame drop rm_out
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: distinct target works, using source unchanged"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T4_control_distinct"
    display as error "FAIL: distinct target control"
}

**# T5: POSITIVE CONTROL -- replace over an existing NON-source frame still
*       overwrites, as documented
local ++test_count
capture noisily {
    _rm_make_src rm_src
    capture frame drop rm_out
    frame create rm_out
    frame rm_out {
        quietly set obs 7
        quietly gen double stale = 1
    }
    _rm_make_master
    rangematch key mlow mhigh using rm_src, frame(rm_out) replace
    frame rm_out {
        quietly count
        assert r(N) == 3
        capture confirm variable stale
        assert _rc != 0
    }
    capture frame drop rm_src
    capture frame drop rm_out
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: replace over a non-source frame still overwrites"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T5_control_replace"
    display as error "FAIL: replace over non-source frame"
}

**# T6: dryrun with frame() naming the source must not touch the source
*       (dry run ignores the frame target and writes nothing)
local ++test_count
capture noisily {
    _rm_make_src rm_src
    _rm_make_master
    capture rangematch key mlow mhigh using rm_src, frame(rm_src) replace dryrun
    frame rm_src {
        confirm variable using_sentinel
        quietly count
        assert r(N) == 3
    }
    capture frame drop rm_src
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: dryrun leaves the using source frame intact"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T6_dryrun"
    display as error "FAIL: dryrun with frame()==source"
}

capture program drop _rm_make_src
capture program drop _rm_make_master

display as result _newline "FRAME SAFETY TEST SUMMARY"
display as result "Tests:  `test_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display "RESULT: test_rangematch_frame_safety tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display "RESULT: test_rangematch_frame_safety tests=`test_count' pass=`pass_count' fail=`fail_count'"
