/*
 * test_regressions.do
 *
 * Focused regression coverage for the return gate: a failed optional graph
 * save must still leave the analytical payload available, while estimates and
 * frame state remain intact.
 */

version 16.0
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall eplot
capture noisily net install eplot, from("`pkg_dir'") replace
if _rc exit _rc
discard

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* The parent directory is deliberately absent; tempfile gives each run a
* unique path without relying on a machine-specific absolute directory.
tempfile missing_root
local badfile "`missing_root'_eplot_save_dir/eplot.gph"

* Data mode: r(table), r(N), and r(k) survive a saving() failure.
local ++test_count
capture noisily {
    clear
    input es lci uci
    1 .5 1.5
    2 1.5 2.5
    end
    return clear
    capture noisily eplot es lci uci, saving("`badfile'", replace)
    assert _rc != 0
    assert r(N) == 2
    assert r(k) == 2
    assert rowsof(r(table)) == 2
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Matrix mode: the analytical table and two-column p-values survive too.
local ++test_count
capture noisily {
    matrix M = (1, .1 \ 2, .2)
    matrix rownames M = X Y
    return clear
    capture noisily eplot, matrix(M) stars saving("`badfile'", replace)
    assert _rc != 0
    assert r(N) == 2
    assert rowsof(r(table)) == 2
    assert rowsof(r(pvalues)) == 2
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

* Estimates mode: returns survive and the active estimation results are kept.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    local before_cmd "`e(cmd)'"
    matrix before_b = e(b)
    return clear
    capture noisily eplot ., drop(_cons) saving("`badfile'", replace)
    assert _rc != 0
    assert r(n_models) == 1
    assert rowsof(r(table)) == 2
    assert "`e(cmd)'" == "`before_cmd'"
    matrix after_b = e(b)
    assert mreldif(before_b, after_b) < 1e-12
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

* Frame mode: returns survive and the caller's frame remains active.
local ++test_count
capture noisily {
    capture frame drop _ep_reg_frame
    frame create _ep_reg_frame
    frame _ep_reg_frame: set obs 2
    frame _ep_reg_frame: gen estimate = _n
    frame _ep_reg_frame: gen ll = estimate - .5
    frame _ep_reg_frame: gen ul = estimate + .5
    local before_frame "`c(frame)'"
    return clear
    capture noisily eplot, frame(_ep_reg_frame) saving("`badfile'", replace)
    assert _rc != 0
    assert r(N) == 2
    assert rowsof(r(table)) == 2
    assert "`c(frame)'" == "`before_frame'"
    capture confirm frame _ep_reg_frame
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture frame drop _ep_reg_frame
capture graph drop _all

display "RESULT: test_regressions tests=4 pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed regression cases:`failed_tests'"
    exit 1
}
