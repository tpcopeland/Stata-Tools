* test_refactor_doc_contract.do
* Documentation contract for psdash README/help de-duplication
* Usage: cd psdash/qa && stata-mp -b do test_refactor_doc_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_refactor_doc_contract.log", replace nomsg

local test_count = 0
global DOC_PASS_COUNT = 0
global DOC_FAIL_COUNT = 0
global DOC_FAILED_TESTS ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local _qa_plus_orig "`c(sysdir_plus)'"
local _qa_personal_orig "`c(sysdir_personal)'"
tempfile _qa_marker
local _qa_sysroot "`_qa_marker'_sysdir"
local _qa_plus "`_qa_sysroot'/plus"
local _qa_personal "`_qa_sysroot'/personal"
capture mkdir "`_qa_sysroot'"
capture mkdir "`_qa_plus'"
capture mkdir "`_qa_personal'"
sysdir set PLUS "`_qa_plus'"
sysdir set PERSONAL "`_qa_personal'"

capture ado uninstall psdash
capture noisily net install psdash, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit `install_rc'
}

capture program drop _doc_result
program define _doc_result
    args test_id rc
    if `rc' == 0 {
        display as result "  PASS: `test_id'"
        global DOC_PASS_COUNT = $DOC_PASS_COUNT + 1
    }
    else {
        display as error "  FAIL: `test_id' (rc=`rc')"
        global DOC_FAIL_COUNT = $DOC_FAIL_COUNT + 1
        global DOC_FAILED_TESTS "$DOC_FAILED_TESTS `test_id'"
    }
end

**# Static documentation contracts

local ++test_count
display as text _n "--- D1: README links curated demo transcripts instead of embedding them ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_overlap.md") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_balance_weights.md") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_support.md") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_mg_overlap.md") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_mg_balance.md") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_mg_weights.md") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_mg_support.md") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "<details>") == 0
    assert strpos(fileread("`pkg_dir'/README.md"), "----------------------------------------------------------------------") == 0
}
_doc_result "D1" `=_rc'

local ++test_count
display as text _n "--- D2: installed help remains self-contained for examples and returns ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "{title:Examples}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "{title:Stored results}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "psdash overlap foreign ps") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "psdash support foreign ps, crump generate(in_support)") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "psdash balance arm , psvars(ps0 ps1 ps2)") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "{cmd:r(balance)}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "{cmd:r(max_smd_adj)}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "{cmd:r(n_ps_near_boundary)}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "{cmd:r(levels)}") > 0
}
_doc_result "D2" `=_rc'

local ++test_count
display as text _n "--- D2b: README documents binary-only Crump trimming ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "Crump et al. (2009) optimal trimming for binary treatments") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "binary treatments; use") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "threshold()") > 0
}
_doc_result "D2b" `=_rc'

local ++test_count
display as text _n "--- D2c: ado headers use canonical author metadata ---"
capture noisily {
    local ado_files psdash.ado psdash_overlap.ado psdash_balance.ado ///
        psdash_weights.ado psdash_support.ado psdash_combined.ado ///
        _psdash_balance_binary.ado _psdash_balance_multigroup.ado ///
        _psdash_detect.ado _psdash_graph_export.ado ///
        _psdash_manual_detect.ado _psdash_mgps_map.ado ///
        _psdash_pscheck.ado _psdash_strip_fv.ado ///
        _psdash_support_stats.ado _psdash_validate_levels.ado ///
        _psdash_validate_psvars.ado _psdash_weights_modify.ado ///
        _psdash_weights_stats.ado
    foreach f of local ado_files {
        assert strpos(fileread("`pkg_dir'/`f'"), ///
            "*! Author: Timothy P Copeland, Karolinska Institutet") > 0
    }
}
_doc_result "D2c" `=_rc'

local ++test_count
display as text _n "--- D3: Stata can resolve installed help ---"
capture noisily {
    help psdash
}
_doc_result "D3" `=_rc'

**# Runnable README examples

local ++test_count
display as text _n "--- D4: README binary workflow runs after net install ---"
capture noisily {
    sysuse auto, clear
    logit foreign mpg weight length
    predict double ps, pr
    psdash overlap foreign ps, nograph
    assert "`r(treatment)'" == "foreign"
    assert "`r(psvar)'" == "ps"
    psdash balance foreign ps, covariates(mpg weight length) loveplot
    assert rowsof(r(balance)) == 3
    psdash weights foreign ps
    assert r(ess) > 0
    psdash support foreign ps, crump generate(in_support)
    assert "`r(treatment)'" == "foreign"
    confirm variable in_support
}
_doc_result "D4" `=_rc'

local ++test_count
display as text _n "--- D5: README multi-group workflow runs after net install ---"
capture noisily {
    clear
    set obs 300
    set seed 20260506
    gen double age = rnormal(60, 10)
    gen byte female = runiform() > .5
    gen double bmi = rnormal(27, 4)
    gen double eta1 = -0.2 + 0.03*(age-60) + 0.25*female - 0.04*(bmi-27)
    gen double eta2 = 0.1 - 0.02*(age-60) + 0.02*(bmi-27)
    gen double den = 1 + exp(eta1) + exp(eta2)
    gen double p0 = 1/den
    gen double p1 = exp(eta1)/den
    gen double u = runiform()
    gen byte arm = cond(u < p0, 0, cond(u < p0 + p1, 1, 2))

    mlogit arm age female bmi
    predict double ps0 ps1 ps2, pr
    psdash overlap arm, psvars(ps0 ps1 ps2) nograph
    assert r(K) == 3
    psdash balance arm, psvars(ps0 ps1 ps2) covariates(age female bmi)
    assert rowsof(r(balance)) == 3
    psdash weights arm, psvars(ps0 ps1 ps2) detail
    assert r(ess) > 0
    psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1) nograph
    assert r(K) == 3
    psdash balance arm, psvars(ps0 ps1 ps2) covariates(age female bmi) reference(1)
    assert "`r(reference)'" == "1"
}
_doc_result "D5" `=_rc'

**# Summary and cleanup

capture graph close _all
capture ado uninstall psdash
sysdir set PLUS "`_qa_plus_orig'"
sysdir set PERSONAL "`_qa_personal_orig'"
capture shell rm -rf "`_qa_sysroot'"

display as text _n "DOC CONTRACT TEST SUMMARY"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result $DOC_PASS_COUNT
display as text "Failed:    " as result $DOC_FAIL_COUNT
if $DOC_FAIL_COUNT > 0 {
    display as error "FAILED TESTS:$DOC_FAILED_TESTS"
    display "RESULT: test_refactor_doc_contract tests=`test_count' pass=$DOC_PASS_COUNT fail=$DOC_FAIL_COUNT"
    log close _all
    exit 9
}

display as result "ALL TESTS PASSED"
display "RESULT: test_refactor_doc_contract tests=`test_count' pass=$DOC_PASS_COUNT fail=$DOC_FAIL_COUNT"
log close _all
