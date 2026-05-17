clear all
version 16.0

capture log close _all
log using "test_overlap_support_multigroup_adversarial.log", replace ///
    name(overlap_support_adv)

local _orig_varabbrev "`c(varabbrev)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

do "`c(pwd)'/_psdash_bootstrap.do"

capture program drop _os_binary_known
program define _os_binary_known
    clear
    set obs 12
    gen byte treat = _n > 6
    gen double ps = .
    replace ps = .20 in 1
    replace ps = .30 in 2
    replace ps = .40 in 3
    replace ps = .50 in 4
    replace ps = .60 in 5
    replace ps = .70 in 6
    replace ps = .30 in 7
    replace ps = .40 in 8
    replace ps = .50 in 9
    replace ps = .60 in 10
    replace ps = .70 in 11
    replace ps = .80 in 12
    gen double marker = 100 + _n
    gen long rowid = _n
end

capture program drop _os_binary_all_overlap
program define _os_binary_all_overlap
    clear
    set obs 8
    gen byte treat = _n > 4
    gen double ps = .
    replace ps = .20 in 1
    replace ps = .40 in 2
    replace ps = .60 in 3
    replace ps = .80 in 4
    replace ps = .20 in 5
    replace ps = .40 in 6
    replace ps = .60 in 7
    replace ps = .80 in 8
    gen long rowid = _n
end

capture program drop _os_binary_no_overlap
program define _os_binary_no_overlap
    clear
    set obs 8
    gen byte treat = _n > 4
    gen double ps = .
    replace ps = .10 in 1
    replace ps = .20 in 2
    replace ps = .30 in 3
    replace ps = .40 in 4
    replace ps = .60 in 5
    replace ps = .70 in 6
    replace ps = .80 in 7
    replace ps = .90 in 8
end

capture program drop _os_binary_extreme
program define _os_binary_extreme
    clear
    set obs 8
    gen byte treat = _n > 4
    gen double ps = .
    replace ps = 0 in 1
    replace ps = .005 in 2
    replace ps = .50 in 3
    replace ps = .60 in 4
    replace ps = .40 in 5
    replace ps = .50 in 6
    replace ps = .995 in 7
    replace ps = 1 in 8
end

capture program drop _os_multigroup_known
program define _os_multigroup_known
    clear
    set obs 6
    gen byte treat = .
    replace treat = 2 in 1/2
    replace treat = 4 in 3/4
    replace treat = 7 in 5/6
    gen double p2 = .
    gen double p4 = .
    gen double p7 = .
    replace p2 = .70 in 1
    replace p4 = .20 in 1
    replace p7 = .10 in 1
    replace p2 = .80 in 2
    replace p4 = .10 in 2
    replace p7 = .10 in 2
    replace p2 = .20 in 3
    replace p4 = .70 in 3
    replace p7 = .10 in 3
    replace p2 = .10 in 4
    replace p4 = .80 in 4
    replace p7 = .10 in 4
    replace p2 = .10 in 5
    replace p4 = .20 in 5
    replace p7 = .70 in 5
    replace p2 = .10 in 6
    replace p4 = .30 in 6
    replace p7 = .60 in 6
    capture label drop arm_lbl
    label define arm_lbl 2 "Dose 2" 4 "Dose 4" 7 "Dose 7" 9 "Absent"
    label values treat arm_lbl
    gen long rowid = _n
end

capture program drop _os_multigroup_bad_rowsum
program define _os_multigroup_bad_rowsum
    _os_multigroup_known
    replace p7 = p7 + .20 in 1/6
end

**# Binary overlap and support known answers
local ++test_count
capture noisily {
    _os_binary_known
    psdash overlap treat ps, nograph
    assert r(N) == 12
    assert r(N_treated) == 6
    assert r(N_control) == 6
    assert abs(r(overlap_lower) - .30) < 1e-10
    assert abs(r(overlap_upper) - .70) < 1e-10
    assert r(n_outside) == 2
    assert abs(r(pct_outside) - 100 * 2 / 12) < 1e-8
    assert abs(r(mean_ps_treated) - .55) < 1e-10
    assert abs(r(mean_ps_control) - .45) < 1e-10
    confirm scalar r(auc)
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T1 binary overlap stored results and bounds"
    local ++pass_count
}
else {
    display as error "FAIL: T1 binary overlap stored results and bounds (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

local ++test_count
capture noisily {
    _os_binary_known
    psdash support treat ps, nograph
    assert r(N) == 12
    assert abs(r(lower_bound) - .30) < 1e-10
    assert abs(r(upper_bound) - .70) < 1e-10
    assert r(n_outside) == 2
    assert r(n_outside_treated) == 1
    assert r(n_outside_control) == 1
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T2 binary support stored results and counts"
    local ++pass_count
}
else {
    display as error "FAIL: T2 binary support stored results and counts (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

local ++test_count
capture noisily {
    _os_binary_all_overlap
    psdash overlap treat ps, nograph
    assert abs(r(overlap_lower) - .20) < 1e-10
    assert abs(r(overlap_upper) - .80) < 1e-10
    assert r(n_outside) == 0
    psdash support treat ps, nograph
    assert abs(r(lower_bound) - .20) < 1e-10
    assert abs(r(upper_bound) - .80) < 1e-10
    assert r(n_outside) == 0
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T3 all-overlap binary data has zero outside support"
    local ++pass_count
}
else {
    display as error "FAIL: T3 all-overlap binary data (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

local ++test_count
capture noisily {
    _os_binary_no_overlap
    psdash overlap treat ps, nograph
    assert r(overlap_lower) > r(overlap_upper)
    assert r(n_outside) == r(N)
    assert r(pct_outside) == 100
    psdash support treat ps, nograph
    assert r(lower_bound) > r(upper_bound)
    assert r(n_outside) == r(N)
    assert r(pct_outside) == 100
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T4 no-overlap binary data reports all outside support"
    local ++pass_count
}
else {
    display as error "FAIL: T4 no-overlap binary data (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

local ++test_count
capture noisily {
    _os_binary_no_overlap
    psdash overlap treat ps, nograph
    assert abs(r(auc) - 1) < 1e-10
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T5 perfect separation returns AUC=1"
    local ++pass_count
}
else {
    display as error "FAIL: T5 perfect separation AUC (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

local ++test_count
capture noisily {
    _os_binary_extreme
    psdash overlap treat ps, nograph
    assert r(n_ps_boundary) == 2
    assert r(n_ps_near_boundary) == 2
    psdash support treat ps, nograph
    assert r(n_ps_boundary) == 2
    assert r(n_ps_near_boundary) == 2
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T6 extreme PS boundary counters are correct"
    local ++pass_count
}
else {
    display as error "FAIL: T6 extreme PS boundary counters (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# Missing and invalid inputs
local ++test_count
capture noisily {
    _os_binary_known
    replace treat = . in 1
    replace ps = . in 12
    psdash overlap treat ps, nograph
    assert r(N) == 10
    psdash support treat ps, nograph
    assert r(N) == 10
    assert _N == 12
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T7 missing treatment/PS are excluded without dropping rows"
    local ++pass_count
}
else {
    display as error "FAIL: T7 missing treatment/PS handling (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

local ++test_count
capture noisily {
    _os_binary_known
    replace ps = -.01 in 1
    psdash overlap treat ps, nograph
}
local rc = _rc
if `rc' == 198 {
    display as result "PASS: T8 overlap rejects PS below zero"
    local ++pass_count
}
else {
    display as error "FAIL: T8 overlap should reject PS below zero (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

local ++test_count
capture noisily {
    _os_binary_known
    replace ps = 1.01 in 12
    psdash support treat ps, nograph
}
local rc = _rc
if `rc' == 198 {
    display as result "PASS: T9 support rejects PS above one"
    local ++pass_count
}
else {
    display as error "FAIL: T9 support should reject PS above one (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# Threshold, Crump, and generate/replace behavior
local ++test_count
capture noisily {
    _os_binary_known
    psdash support treat ps, threshold(.25) nograph
    assert abs(r(trim_lower) - .25) < 1e-10
    assert abs(r(trim_upper) - .75) < 1e-10
    assert r(n_trimmed) == 2
    assert abs(r(pct_trimmed) - 100 * 2 / 12) < 1e-8
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T10 support threshold(.25) trims expected rows"
    local ++pass_count
}
else {
    display as error "FAIL: T10 support threshold(.25) (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

foreach bad_threshold in 0 -.01 .5 {
    local ++test_count
    capture noisily {
        _os_binary_known
        psdash support treat ps, threshold(`bad_threshold') nograph
    }
    local rc = _rc
    if `rc' == 198 {
        display as result "PASS: T`test_count' support rejects threshold(`bad_threshold')"
        local ++pass_count
    }
    else {
        display as error "FAIL: T`test_count' support should reject threshold(`bad_threshold') (rc=`rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T`test_count'"
    }
}

local ++test_count
capture noisily {
    _os_binary_known
    psdash support treat ps, crump threshold(.10) nograph
}
local rc = _rc
if `rc' == 198 {
    display as result "PASS: T14 support rejects crump with threshold()"
    local ++pass_count
}
else {
    display as error "FAIL: T14 support should reject crump with threshold() (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T14"
}

local ++test_count
capture noisily {
    _os_binary_known
    psdash support treat ps, crump nograph
    assert r(crump_alpha) > 0
    assert r(crump_alpha) < .5
    assert r(trim_lower) == r(crump_alpha)
    assert r(trim_upper) == 1 - r(crump_alpha)
    assert r(n_trimmed) >= 0
    assert r(n_trimmed) <= r(N)
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T15 Crump trimming returns coherent bounds"
    local ++pass_count
}
else {
    display as error "FAIL: T15 Crump trimming coherence (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T15"
}

local ++test_count
capture noisily {
    _os_binary_known
    psdash support treat ps, generate(in_support) nograph
    local lb = r(lower_bound)
    local ub = r(upper_bound)
    confirm variable in_support
    assert in_support == (ps >= `lb' & ps <= `ub')
    assert in_support[1] == 0
    assert in_support[2] == 1
    assert in_support[12] == 0
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T16 generate() common-support indicator is correct"
    local ++pass_count
}
else {
    display as error "FAIL: T16 generate() common-support indicator (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T16"
}

local ++test_count
capture noisily {
    _os_binary_known
    gen byte in_support = 9
    psdash support treat ps, generate(in_support) nograph
}
local rc = _rc
if `rc' == 110 {
    display as result "PASS: T17 generate() without replace rejects existing variable"
    local ++pass_count
}
else {
    display as error "FAIL: T17 generate() without replace should reject existing variable (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T17"
}

local ++test_count
capture noisily {
    _os_binary_known
    gen byte in_support = 9
    psdash support treat ps, generate(in_support) replace threshold(.25) nograph
    assert in_support == (ps >= .25 & ps <= .75)
    assert in_support[1] == 0
    assert in_support[2] == 1
    assert in_support[12] == 0
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T18 generate() replace rewrites support indicator"
    local ++pass_count
}
else {
    display as error "FAIL: T18 generate() replace support indicator (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T18"
}

**# Multi-group ordering, reference, and GPS validation
local ++test_count
capture noisily {
    _os_multigroup_known
    psdash overlap treat, psvars(p2 p4 p7) reference(4) nograph
    assert r(K) == 3
    assert "`r(levels)'" == "2 4 7"
    assert "`r(reference)'" == "4"
    assert r(N_group_2) == 2
    assert r(N_group_4) == 2
    assert r(N_group_7) == 2
    assert abs(r(mean_ps_group_2) - .75) < 1e-10
    assert abs(r(mean_ps_group_4) - .75) < 1e-10
    assert abs(r(mean_ps_group_7) - .65) < 1e-10
    assert abs(r(overlap_lower) - .70) < 1e-10
    assert abs(r(overlap_upper) - .70) < 1e-10
    assert r(n_outside) == 3
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T19 overlap maps psvars() by sorted treatment level"
    local ++pass_count
}
else {
    display as error "FAIL: T19 overlap psvars() ordering/reference behavior (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T19"
}

local ++test_count
capture noisily {
    _os_multigroup_known
    psdash support treat, psvars(p2 p4 p7) reference(7) threshold(.25) ///
        generate(mg_support) nograph
    assert r(K) == 3
    assert "`r(reference)'" == "7"
    assert abs(r(lower_bound) - .70) < 1e-10
    assert abs(r(upper_bound) - .70) < 1e-10
    assert r(n_outside) == 3
    assert r(n_outside_group_2) == 1
    assert r(n_outside_group_4) == 1
    assert r(n_outside_group_7) == 1
    assert r(n_trimmed) == 2
    assert mg_support == 1 in 1
    assert mg_support == 0 in 2
    assert mg_support == 1 in 3
    assert mg_support == 0 in 4
    assert mg_support == 1 in 5
    assert mg_support == 1 in 6
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T20 support uses observed group GPS for threshold indicator"
    local ++pass_count
}
else {
    display as error "FAIL: T20 support multigroup threshold/generate behavior (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T20"
}

local ++test_count
capture noisily {
    _os_multigroup_bad_rowsum
    psdash overlap treat, psvars(p2 p4 p7) nograph
}
local rc = _rc
if `rc' == 198 {
    display as result "PASS: T21 overlap rejects GPS rows that do not sum to 1"
    local ++pass_count
}
else {
    display as error "FAIL: T21 overlap should reject GPS rows that do not sum to 1 (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T21"
}

local ++test_count
capture noisily {
    _os_multigroup_bad_rowsum
    psdash support treat, psvars(p2 p4 p7) nograph
}
local rc = _rc
if `rc' == 198 {
    display as result "PASS: T22 support rejects GPS rows that do not sum to 1"
    local ++pass_count
}
else {
    display as error "FAIL: T22 support should reject GPS rows that do not sum to 1 (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T22"
}

local ++test_count
capture noisily {
    _os_multigroup_known
    psdash overlap treat, psvars(p2 p4 p7) nograph
    assert r(K) == 3
    assert "`r(levels)'" == "2 4 7"
    assert "`r(reference)'" == "2"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T23 absent value-label level is ignored"
    local ++pass_count
}
else {
    display as error "FAIL: T23 absent sample level handling (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T23"
}

local ++test_count
capture noisily {
    _os_multigroup_known
    psdash support treat, psvars(p2 p4 p7) reference(9) nograph
}
local rc = _rc
if `rc' == 198 {
    display as result "PASS: T24 support rejects absent reference level"
    local ++pass_count
}
else {
    display as error "FAIL: T24 support should reject absent reference level (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T24"
}

local ++test_count
capture noisily {
    _os_multigroup_known
    psdash overlap treat, psvars(p2 p4) nograph
}
local rc = _rc
if `rc' == 198 {
    display as result "PASS: T25 overlap rejects too few psvars()"
    local ++pass_count
}
else {
    display as error "FAIL: T25 overlap should reject too few psvars() (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T25"
}

**# Graph behavior and data preservation
local ++test_count
capture noisily {
    _os_binary_known
    capture graph drop _all
    psdash overlap treat ps, nograph name(_os_ng_overlap)
    capture graph describe _os_ng_overlap
    assert _rc != 0
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T26 nograph suppresses graph creation"
    local ++pass_count
}
else {
    display as error "FAIL: T26 nograph behavior (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T26"
}

local ++test_count
capture noisily {
    _os_binary_known
    capture graph drop _os_graph_support
    local graphfile "test_overlap_support_multigroup_adversarial_support.png"
    capture erase "`graphfile'"
    psdash support treat ps, name(_os_graph_support) saving("`graphfile'")
    graph describe _os_graph_support
    confirm file "`graphfile'"
    capture erase "`graphfile'"
    capture graph drop _os_graph_support
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T27 graph and saving() path creates named graph and file"
    local ++pass_count
}
else {
    display as error "FAIL: T27 graph/saving behavior (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T27"
}

local ++test_count
capture noisily {
    _os_binary_known
    tempfile before
    save `before'
    psdash overlap treat ps, nograph
    cf _all using `before'
    psdash support treat ps, nograph
    cf _all using `before'
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T28 overlap/support preserve data without generate()"
    local ++pass_count
}
else {
    display as error "FAIL: T28 data preservation without generate() (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T28"
}

**# Varabbrev restoration on success and error
local ++test_count
capture noisily {
    set varabbrev on
    _os_binary_known
    psdash overlap treat ps, nograph
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
    psdash support treat ps, nograph
    assert "`c(varabbrev)'" == "off"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T29 varabbrev restored after successful commands"
    local ++pass_count
}
else {
    display as error "FAIL: T29 varabbrev restoration on success (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T29"
}

local ++test_count
capture noisily {
    set varabbrev on
    _os_binary_known
    replace ps = -1 in 1
    capture noisily psdash overlap treat ps, nograph
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
    _os_binary_known
    capture noisily psdash support treat ps, threshold(.5) nograph
    assert _rc == 198
    assert "`c(varabbrev)'" == "off"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T30 varabbrev restored after command errors"
    local ++pass_count
}
else {
    display as error "FAIL: T30 varabbrev restoration on errors (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T30"
}

set varabbrev `_orig_varabbrev'

**# Summary
display as text ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_overlap_support_multigroup_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close overlap_support_adv
    _psdash_qa_cleanup
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_overlap_support_multigroup_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close overlap_support_adv
_psdash_qa_cleanup
